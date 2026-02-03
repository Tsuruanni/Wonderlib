import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'audio_service.dart';

part 'word_pronunciation_service.g.dart';

/// Service for pronouncing individual words using device TTS
/// Ducks main audio during pronunciation and restores volume after
class WordPronunciationService {
  WordPronunciationService({required AudioService audioService})
      : _audioService = audioService;

  final FlutterTts _tts = FlutterTts();
  final AudioService _audioService;
  bool _isSpeaking = false;
  bool _wasAudioDucked = false;
  bool _isInitialized = false;
  Timer? _webFallbackTimer;

  Future<void> initialize() async {
    try {
      // Check available languages
      final languages = await _tts.getLanguages;
      debugPrint('TTS available languages: $languages');

      // Try to set English
      final result = await _tts.setLanguage('en-US');
      debugPrint('TTS setLanguage result: $result');

      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(_onSpeechComplete);
      _tts.setCancelHandler(_onSpeechCancel);
      _tts.setErrorHandler(_onSpeechError);

      _isInitialized = true;
      debugPrint('TTS initialized successfully (web: $kIsWeb)');
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      _isInitialized = false;
    }
  }

  /// Speak a word, ducking main audio if playing
  Future<void> speak(String word) async {
    if (!_isInitialized) {
      debugPrint('TTS not initialized, attempting to initialize...');
      await initialize();
    }

    // Stop any current speech
    if (_isSpeaking) {
      await _tts.stop();
      _webFallbackTimer?.cancel();
    }

    _isSpeaking = true;

    // Duck main audio if playing
    if (_audioService.isPlaying) {
      _wasAudioDucked = true;
      await _audioService.setVolume(0.2);
    }

    // Clean word (remove punctuation for cleaner pronunciation)
    final cleanWord = _cleanWord(word);
    debugPrint('TTS speaking: "$cleanWord"');

    try {
      // Speak the word
      final result = await _tts.speak(cleanWord);
      debugPrint('TTS speak result: $result');

      // Web fallback: completion handler may not fire, use timer
      if (kIsWeb) {
        _webFallbackTimer = Timer(const Duration(milliseconds: 1500), () {
          if (_isSpeaking) {
            debugPrint('TTS web fallback: restoring audio');
            _restoreAudio();
          }
        });
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _restoreAudio();
    }
  }

  /// Clean word for pronunciation (remove punctuation)
  String _cleanWord(String word) {
    // Remove common punctuation marks
    return word.replaceAll(RegExp(r"[.,!?;:'\-—()\[\]{}]"), '').trim();
  }

  void _onSpeechComplete() {
    _restoreAudio();
  }

  void _onSpeechCancel() {
    _restoreAudio();
  }

  void _onSpeechError(dynamic error) {
    _restoreAudio();
  }

  void _restoreAudio() {
    _isSpeaking = false;
    if (_wasAudioDucked) {
      _wasAudioDucked = false;
      _audioService.setVolume(1.0);
    }
  }

  /// Stop current speech and restore audio
  Future<void> stop() async {
    _webFallbackTimer?.cancel();
    await _tts.stop();
    _restoreAudio();
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Dispose resources
  Future<void> dispose() async {
    _webFallbackTimer?.cancel();
    await _tts.stop();
  }
}

@Riverpod(keepAlive: true)
Future<WordPronunciationService> wordPronunciationService(
  WordPronunciationServiceRef ref,
) async {
  final audioService = await ref.watch(audioServiceProvider.future);
  final service = WordPronunciationService(audioService: audioService);
  await service.initialize();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
