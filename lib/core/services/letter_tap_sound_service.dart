import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// Generates and plays short ascending tones for letter tap feedback.
/// Uses a pentatonic scale so every note sounds pleasant.
class LetterTapSoundService {
  final AudioPlayer _player = AudioPlayer();

  // Pentatonic scale: C5 → A6 (always sounds nice, no dissonant intervals)
  static const _frequencies = [
    523.25, // C5
    587.33, // D5
    659.25, // E5
    783.99, // G5
    880.00, // A5
    1046.50, // C6
    1174.66, // D6
    1318.51, // E6
    1567.98, // G6
    1760.00, // A6
  ];

  /// Play a tap tone at the given letter index (0-based).
  /// Higher index = higher pitch. Capped at 10 steps.
  Future<void> playTap(int letterIndex) async {
    final freqIndex = letterIndex.clamp(0, _frequencies.length - 1);
    final frequency = _frequencies[freqIndex];
    final wavBytes = _generateTone(frequency, 0.1); // 100ms tone

    try {
      await _player.setAudioSource(_WavSource(wavBytes));
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {
      // Sound is enhancement, not critical — silently fail
    }
  }

  /// Generate a sine wave WAV with fade-out envelope (sounds like a "ding")
  Uint8List _generateTone(double frequency, double duration) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * duration).toInt();
    const bitsPerSample = 16;
    const blockAlign = bitsPerSample ~/ 8;
    final dataSize = numSamples * blockAlign;

    final buffer = ByteData(44 + dataSize);

    // WAV header
    _writeString(buffer, 0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    _writeString(buffer, 8, 'WAVE');

    // fmt chunk
    _writeString(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * blockAlign, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    _writeString(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    // Sine wave with exponential fade-out (more natural "ding" decay)
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = exp(-6.0 * i / numSamples); // fast decay
      final sample = sin(2 * pi * frequency * t) * envelope * 0.4;
      final intSample = (sample * 32767).toInt().clamp(-32768, 32767);
      buffer.setInt16(44 + i * 2, intSample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  void _writeString(ByteData buffer, int offset, String str) {
    for (int i = 0; i < str.length; i++) {
      buffer.setUint8(offset + i, str.codeUnitAt(i));
    }
  }

  void dispose() {
    _player.dispose();
  }
}

/// StreamAudioSource for playing in-memory WAV bytes
class _WavSource extends StreamAudioSource {
  final Uint8List _bytes;
  _WavSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
