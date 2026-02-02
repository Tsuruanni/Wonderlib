import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/audio_service.dart';
import '../../domain/entities/content/content_block.dart';

/// State for audio sync playback
class AudioSyncState {
  const AudioSyncState({
    this.currentBlockId,
    this.isPlaying = false,
    this.isLoading = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.activeWordIndex,
    this.playbackSpeed = 1.0,
    this.error,
  });

  final String? currentBlockId;
  final bool isPlaying;
  final bool isLoading;
  final int positionMs;
  final int durationMs;
  final int? activeWordIndex;
  final double playbackSpeed;
  final String? error;

  /// Progress as 0.0 to 1.0
  double get progress {
    if (durationMs == 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  /// Formatted position string (mm:ss)
  String get positionFormatted => _formatDuration(positionMs);

  /// Formatted duration string (mm:ss)
  String get durationFormatted => _formatDuration(durationMs);

  static String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  AudioSyncState copyWith({
    String? currentBlockId,
    bool? isPlaying,
    bool? isLoading,
    int? positionMs,
    int? durationMs,
    int? activeWordIndex,
    double? playbackSpeed,
    String? error,
    bool clearBlockId = false,
    bool clearActiveWord = false,
    bool clearError = false,
  }) {
    return AudioSyncState(
      currentBlockId: clearBlockId ? null : (currentBlockId ?? this.currentBlockId),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      activeWordIndex: clearActiveWord ? null : (activeWordIndex ?? this.activeWordIndex),
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for audio sync playback
class AudioSyncController extends StateNotifier<AudioSyncState> {
  AudioSyncController(this._audioService, this._onComplete) : super(const AudioSyncState()) {
    _subscribeToStreams();
  }

  final AudioService _audioService;
  final void Function(String blockId)? _onComplete;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  List<WordTiming> _currentWordTimings = [];

  /// Segment boundaries for chapter-level audio
  int? _segmentStartMs;
  int? _segmentEndMs;
  String? _currentAudioUrl;

  void _subscribeToStreams() {
    _positionSubscription = _audioService.positionStream.listen(_onPositionChanged);
    _playerStateSubscription = _audioService.playerStateStream.listen(_onPlayerStateChanged);
  }

  void _onPositionChanged(Duration position) {
    final globalPositionMs = position.inMilliseconds;

    // Check if we've reached the end of the segment (chapter-level audio)
    if (_segmentEndMs != null && globalPositionMs >= _segmentEndMs!) {
      _handleSegmentComplete();
      return;
    }

    // Calculate position relative to segment start for UI display
    final relativePositionMs = _segmentStartMs != null
        ? (globalPositionMs - _segmentStartMs!).clamp(0, state.durationMs)
        : globalPositionMs;

    // Find active word using global position (word timings have global timestamps)
    final activeWordIndex = _findActiveWordIndex(globalPositionMs);

    state = state.copyWith(
      positionMs: relativePositionMs,
      activeWordIndex: activeWordIndex,
      clearActiveWord: activeWordIndex == null,
    );
  }

  void _handleSegmentComplete() {
    final completedBlockId = state.currentBlockId;

    // Pause and reset state
    _audioService.pause();
    state = state.copyWith(
      isPlaying: false,
      positionMs: state.durationMs,
      clearActiveWord: true,
    );

    // Notify completion callback
    if (completedBlockId != null) {
      _onComplete?.call(completedBlockId);
    }
  }

  void _onPlayerStateChanged(PlayerState playerState) {
    state = state.copyWith(
      isPlaying: playerState.playing,
      isLoading: playerState.processingState == ProcessingState.loading ||
          playerState.processingState == ProcessingState.buffering,
    );

    // When playback completes (only for per-block audio, not segment-based)
    // Segment-based completion is handled in _onPositionChanged
    if (playerState.processingState == ProcessingState.completed &&
        _segmentEndMs == null) {
      final completedBlockId = state.currentBlockId;
      state = state.copyWith(
        isPlaying: false,
        positionMs: 0,
        clearActiveWord: true,
      );
      // Notify completion callback
      if (completedBlockId != null) {
        _onComplete?.call(completedBlockId);
      }
    }
  }

  /// Binary search to find active word index at given position
  /// Returns null if no word is active
  int? _findActiveWordIndex(int positionMs) {
    if (_currentWordTimings.isEmpty) return null;

    int low = 0;
    int high = _currentWordTimings.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final timing = _currentWordTimings[mid];

      if (positionMs < timing.startMs) {
        high = mid - 1;
      } else if (positionMs >= timing.endMs) {
        low = mid + 1;
      } else {
        // positionMs is within this word's timing
        return mid;
      }
    }

    return null;
  }

  /// Load audio for a content block
  /// Supports both per-block audio and chapter-level audio segments
  Future<void> loadBlock(ContentBlock block) async {
    if (!block.hasAudio) return;

    state = state.copyWith(
      isLoading: true,
      currentBlockId: block.id,
      positionMs: 0,
      clearActiveWord: true,
      clearError: true,
    );

    _currentWordTimings = block.wordTimings;

    // Check if this is a segment of chapter-level audio
    final hasSegmentBounds = block.audioStartMs != null && block.audioEndMs != null;
    _segmentStartMs = block.audioStartMs;
    _segmentEndMs = block.audioEndMs;

    try {
      // Only reload audio if URL changed (optimization for chapter-level audio)
      final needsReload = _currentAudioUrl != block.audioUrl;
      if (needsReload) {
        _currentAudioUrl = block.audioUrl;
        await _audioService.player.setUrl(block.audioUrl!);
      }

      // Calculate duration for this block
      int blockDurationMs;
      if (hasSegmentBounds) {
        // Segment-based: duration is segment length
        blockDurationMs = block.audioEndMs! - block.audioStartMs!;
        // Seek to segment start
        await _audioService.seek(Duration(milliseconds: block.audioStartMs!));
      } else {
        // Per-block audio: use full audio duration
        final audioDuration = _audioService.duration;
        blockDurationMs = audioDuration?.inMilliseconds ?? block.audioDurationMs ?? 0;
      }

      state = state.copyWith(
        isLoading: false,
        durationMs: blockDurationMs,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load audio: $e',
      );
    }
  }

  /// Play/resume audio
  Future<void> play() async {
    if (state.currentBlockId == null) return;
    await _audioService.resume();
  }

  /// Pause audio
  Future<void> pause() async {
    await _audioService.pause();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to position (in milliseconds, relative to block start)
  Future<void> seekMs(int positionMs) async {
    // Add segment offset for chapter-level audio
    final globalPositionMs = _segmentStartMs != null
        ? (_segmentStartMs! + positionMs)
        : positionMs;

    // Clamp to segment bounds if applicable
    final clampedMs = _segmentEndMs != null
        ? globalPositionMs.clamp(_segmentStartMs ?? 0, _segmentEndMs!)
        : globalPositionMs;

    await _audioService.seek(Duration(milliseconds: clampedMs));
  }

  /// Seek to progress (0.0 to 1.0)
  Future<void> seekProgress(double progress) async {
    final positionMs = (progress * state.durationMs).round();
    await seekMs(positionMs);
  }

  /// Skip forward by specified milliseconds
  Future<void> skipForward({int ms = 10000}) async {
    final newPosition = (state.positionMs + ms).clamp(0, state.durationMs);
    await seekMs(newPosition);
  }

  /// Skip backward by specified milliseconds
  Future<void> skipBackward({int ms = 10000}) async {
    final newPosition = (state.positionMs - ms).clamp(0, state.durationMs);
    await seekMs(newPosition);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _audioService.setSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  /// Cycle through common playback speeds
  Future<void> cycleSpeed() async {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(state.playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    await setSpeed(speeds[nextIndex]);
  }

  /// Stop and clear current audio
  Future<void> stop() async {
    await _audioService.stop();
    _currentWordTimings = [];
    _segmentStartMs = null;
    _segmentEndMs = null;
    _currentAudioUrl = null;
    state = const AudioSyncState();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for audio sync controller
/// Uses autoDispose to clean up when not in use
final audioSyncControllerProvider =
    StateNotifierProvider.autoDispose<AudioSyncController, AudioSyncState>((ref) {
  final audioService = ref.watch(audioServiceProvider).valueOrNull;

  if (audioService == null) {
    // Return a dummy controller if audio service is not ready
    // This shouldn't happen in practice, but handles the async initialization
    throw StateError('AudioService not initialized');
  }

  // Callback when audio playback completes
  void onComplete(String blockId) {
    ref.read(audioCompletedBlockProvider.notifier).state = blockId;
  }

  final controller = AudioSyncController(audioService, onComplete);
  ref.onDispose(() {
    controller.stop();
  });

  return controller;
});

/// Provider for checking if a specific block is currently playing
final isBlockPlayingProvider = Provider.family<bool, String>((ref, blockId) {
  final state = ref.watch(audioSyncControllerProvider);
  return state.currentBlockId == blockId && state.isPlaying;
});

/// Provider for getting active word index for a specific block
/// Returns null if block is not active or no word is highlighted
final activeWordIndexProvider = Provider.family<int?, String>((ref, blockId) {
  final state = ref.watch(audioSyncControllerProvider);
  if (state.currentBlockId != blockId) return null;
  return state.activeWordIndex;
});

/// Provider for checking if a specific block is currently loading
final isBlockLoadingProvider = Provider.family<bool, String>((ref, blockId) {
  final state = ref.watch(audioSyncControllerProvider);
  return state.currentBlockId == blockId && state.isLoading;
});

/// Provider for audio completion events
/// Returns the blockId of the block that just completed
final audioCompletedBlockProvider = StateProvider<String?>((ref) => null);
