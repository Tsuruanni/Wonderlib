import 'dart:convert';
import 'package:http/http.dart' as http;

/// ElevenLabs TTS service for generating audio with word-level timestamps.
class ElevenLabsService {
  ElevenLabsService({
    required this.apiKey,
    this.defaultVoiceId = '21m00Tcm4TlvDq8ikWAM', // Rachel voice
  });

  final String apiKey;
  final String defaultVoiceId;

  static const String _baseUrl = 'https://api.elevenlabs.io/v1';

  /// Available voices for TTS
  static const Map<String, String> voices = {
    '21m00Tcm4TlvDq8ikWAM': 'Rachel (Female)',
    'AZnzlk1XvdvUeBnXmlld': 'Domi (Female)',
    'EXAVITQu4vr4xnSDxMaL': 'Bella (Female)',
    'ErXwobaYiN019PkySvjV': 'Antoni (Male)',
    'MF3mGyEYCl7XYWbV9V6O': 'Elli (Female)',
    'TxGEqnHWrfWFTfGW9XjX': 'Josh (Male)',
    'VR6AewLTigWG4xSOukaG': 'Arnold (Male)',
    'pNInz6obpgDQGcFmaJgB': 'Adam (Male)',
  };

  /// Generate audio with word-level timestamps.
  /// Returns audio bytes and word timings.
  Future<TtsResult> generateWithTimestamps(
    String text, {
    String? voiceId,
    String modelId = 'eleven_multilingual_v2',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/text-to-speech/${voiceId ?? defaultVoiceId}/with-timestamps'),
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': modelId,
        'output_format': 'mp3_44100_128',
      }),
    );

    if (response.statusCode != 200) {
      throw ElevenLabsException(
        'Failed to generate audio: ${response.statusCode}',
        response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final audioBase64 = json['audio_base64'] as String;
    final alignment = json['alignment'] as Map<String, dynamic>;

    final audioBytes = base64Decode(audioBase64);
    final wordTimings = _convertToWordTimings(text, alignment);

    return TtsResult(
      audioBytes: audioBytes,
      wordTimings: wordTimings,
    );
  }

  /// Convert character-level timestamps to word-level timestamps.
  List<WordTiming> _convertToWordTimings(
    String text,
    Map<String, dynamic> alignment,
  ) {
    final charStarts = (alignment['character_start_times_seconds'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final charEnds = (alignment['character_end_times_seconds'] as List)
        .map((e) => (e as num).toDouble())
        .toList();

    final timings = <WordTiming>[];
    final wordRegex = RegExp(r'\S+');

    for (final match in wordRegex.allMatches(text)) {
      final word = match.group(0)!;
      final startIndex = match.start;
      final endIndex = match.end;

      // Get timestamps from character arrays
      final startMs = (charStarts[startIndex] * 1000).round();
      final endMs = (charEnds[endIndex - 1] * 1000).round();

      timings.add(WordTiming(
        word: word,
        startIndex: startIndex,
        endIndex: endIndex,
        startMs: startMs,
        endMs: endMs,
      ));
    }

    return timings;
  }

  /// Get available voices from ElevenLabs API.
  Future<List<Voice>> getVoices() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/voices'),
      headers: {'xi-api-key': apiKey},
    );

    if (response.statusCode != 200) {
      throw ElevenLabsException('Failed to get voices', response.body);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final voicesJson = json['voices'] as List;

    return voicesJson
        .map((v) => Voice(
              id: v['voice_id'] as String,
              name: v['name'] as String,
              category: v['category'] as String?,
            ))
        .toList();
  }
}

/// Result of TTS generation with timestamps.
class TtsResult {
  const TtsResult({
    required this.audioBytes,
    required this.wordTimings,
  });

  final List<int> audioBytes;
  final List<WordTiming> wordTimings;
}

/// Word timing data for audio synchronization.
class WordTiming {
  const WordTiming({
    required this.word,
    required this.startIndex,
    required this.endIndex,
    required this.startMs,
    required this.endMs,
  });

  final String word;
  final int startIndex;
  final int endIndex;
  final int startMs;
  final int endMs;

  Map<String, dynamic> toJson() => {
        'word': word,
        'startIndex': startIndex,
        'endIndex': endIndex,
        'startMs': startMs,
        'endMs': endMs,
      };
}

/// Voice information from ElevenLabs.
class Voice {
  const Voice({
    required this.id,
    required this.name,
    this.category,
  });

  final String id;
  final String name;
  final String? category;
}

/// Exception for ElevenLabs API errors.
class ElevenLabsException implements Exception {
  const ElevenLabsException(this.message, [this.details]);

  final String message;
  final String? details;

  @override
  String toString() => 'ElevenLabsException: $message${details != null ? '\n$details' : ''}';
}
