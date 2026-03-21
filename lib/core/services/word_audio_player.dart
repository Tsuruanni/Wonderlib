import 'package:just_audio/just_audio.dart';

/// Lightweight player for vocabulary word audio segments.
/// Uses ClippingAudioSource to play only the word's portion of a batch audio file.
class WordAudioPlayer {
  AudioPlayer? _player;

  Future<void> play({
    required String audioUrl,
    required int startMs,
    required int endMs,
  }) async {
    await stop();
    _player = AudioPlayer();

    await _player!.setAudioSource(
      ClippingAudioSource(
        child: AudioSource.uri(Uri.parse(audioUrl)),
        start: Duration(milliseconds: startMs),
        end: Duration(milliseconds: endMs + 200),
      ),
    );
    await _player!.play();
  }

  Future<void> stop() async {
    await _player?.stop();
    await _player?.dispose();
    _player = null;
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
