import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/audio_service.dart';
import '../../domain/entities/content/content_block.dart';

/// Configuration for auto-play behavior
class AutoPlayConfig {
  const AutoPlayConfig({
    this.afterActivityDelayMs = 1000,
    this.afterAudioDelayMs = 500,
  });

  /// Delay after activity completion before playing next audio
  final int afterActivityDelayMs;

  /// Delay after audio completion before playing next audio
  final int afterAudioDelayMs;
}

/// Info for resuming chapter playback after word audio completes
class ChapterResumeInfo {
  const ChapterResumeInfo({
    required this.blockId,
    required this.globalPositionMs,
    required this.wasPlaying,
  });

  /// The block that was playing
  final String blockId;

  /// Global position in audio file (absolute, not relative to segment)
  final int globalPositionMs;

  /// Whether audio was playing when word tap occurred
  final bool wasPlaying;
}

/// State for audio sync playback
class AudioSyncState {
  const AudioSyncState({
    this.currentBlockId,
    this.isPlaying = false,
    this.isLoading = false,
    this.isPlayingWord = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.activeWordIndex,
    this.playbackSpeed = 1.0,
    this.error,
  });

  final String? currentBlockId;
  final bool isPlaying;
  final bool isLoading;
  final bool isPlayingWord;
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
    bool? isPlayingWord,
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
      isPlayingWord: isPlayingWord ?? this.isPlayingWord,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      activeWordIndex: clearActiveWord ? null : (activeWordIndex ?? this.activeWordIndex),
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for audio sync playback with integrated auto-play
class AudioSyncController extends StateNotifier<AudioSyncState> {
  AudioSyncController(
    this._audioService, {
    this.autoPlayConfig = const AutoPlayConfig(),
  }) : super(const AudioSyncState()) {
    _subscribeToStreams();
  }

  final AudioService _audioService;
  final AutoPlayConfig autoPlayConfig;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  List<WordTiming> _currentWordTimings = [];

  /// Segment boundaries for chapter-level audio
  int? _segmentStartMs;
  int? _segmentEndMs;
  String? _currentAudioUrl;

  /// Resume info for word playback (encapsulates all resume state)
  ChapterResumeInfo? _resumeInfo;

  // ============ Auto-Play State ============

  /// Stream for block completion events (replaces audioCompletedBlockProvider)
  final _completionController = StreamController<String>.broadcast();
  Stream<String> get onBlockCompleted => _completionController.stream;

  /// Auto-play configuration
  bool _autoPlayEnabled = true;
  Timer? _autoPlayTimer;
  List<ContentBlock> _blocks = [];

  /// Listening mode flag - true when user is actively in a listening session.
  /// This is different from isPlaying:
  /// - isPlaying: audio is currently playing right now
  /// - _isInListeningMode: user has started listening and hasn't paused/stopped
  ///
  /// Transitions:
  /// - play() → true
  /// - audio completes → stays true (flow continues)
  /// - pause() → false (user chose to stop listening)
  /// - stop() → false (user ended session)
  bool _isInListeningMode = false;

  /// Check if user is in listening mode (for external queries)
  bool get isInListeningMode => _isInListeningMode;

  /// Set content blocks for auto-play navigation
  void setBlocks(List<ContentBlock> blocks) {
    _blocks = blocks;
  }

  /// Enable or disable auto-play
  void setAutoPlayEnabled(bool enabled) {
    _autoPlayEnabled = enabled;
    if (!enabled) {
      _autoPlayTimer?.cancel();
    }
  }

  /// Check if auto-play is enabled
  bool get isAutoPlayEnabled => _autoPlayEnabled;

  void _subscribeToStreams() {
    _positionSubscription = _audioService.positionStream.listen(_onPositionChanged);
    _playerStateSubscription = _audioService.playerStateStream.listen(_onPlayerStateChanged);
  }

  /// Buffer added to segment end to allow last syllable to fully play out.
  /// TTS audio often has natural decay after the last word timestamp.
  static const int _segmentEndBufferMs = 300;

  void _onPositionChanged(Duration position) {
    final globalPositionMs = position.inMilliseconds;

    // Check if we've reached the end of the segment (chapter-level audio)
    // Add buffer to allow the last syllable to fully play out
    if (_segmentEndMs != null && globalPositionMs >= _segmentEndMs! + _segmentEndBufferMs) {
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
    // If playing a single word, handle word completion separately
    if (state.isPlayingWord) {
      _handleWordComplete();
      return;
    }

    final completedBlockId = state.currentBlockId;

    // Pause and reset state
    _audioService.pause();
    state = state.copyWith(
      isPlaying: false,
      positionMs: state.durationMs,
      clearActiveWord: true,
    );

    // Emit completion event and trigger auto-play
    if (completedBlockId != null) {
      _emitCompletionAndAutoPlay(completedBlockId);
    }
  }

  /// Emit completion event and schedule auto-play if enabled and in listening mode
  void _emitCompletionAndAutoPlay(String completedBlockId) {
    // Emit to stream for external listeners (scrolling, etc.)
    _completionController.add(completedBlockId);

    // Schedule auto-play if enabled AND in listening mode
    // Note: _isInListeningMode stays true after audio completes (flow continues)
    if (_autoPlayEnabled && _isInListeningMode && _blocks.isNotEmpty) {
      final currentIndex = _blocks.indexWhere((b) => b.id == completedBlockId);
      if (currentIndex != -1) {
        final nextBlock = _findNextAudioBlock(currentIndex);
        if (nextBlock != null) {
          _scheduleAutoPlay(nextBlock, autoPlayConfig.afterAudioDelayMs);
        }
      }
    }
  }

  /// Find the next audio block after given index
  ContentBlock? _findNextAudioBlock(int afterIndex) {
    for (int i = afterIndex + 1; i < _blocks.length; i++) {
      if (_blocks[i].hasAudio) {
        return _blocks[i];
      }
    }
    return null;
  }

  /// Schedule auto-play after a delay
  void _scheduleAutoPlay(ContentBlock block, int delayMs) {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_autoPlayEnabled && mounted) {
        loadBlock(block).then((_) => play());
      }
    });
  }

  /// Handle activity completion - play next audio block only if in listening mode.
  /// If user hasn't started listening (never pressed play), do nothing.
  /// If user paused/stopped, do nothing.
  void onActivityCompleted(String activityId, List<ContentBlock> visibleBlocks) {
    // Only auto-play if user is in listening mode
    // This prevents auto-play when user has never started listening
    // or when user explicitly paused/stopped
    if (!_autoPlayEnabled || !_isInListeningMode) return;

    // Update blocks with visible list
    _blocks = visibleBlocks;

    // Find the activity block
    final activityBlockIndex = visibleBlocks.indexWhere(
      (b) => b.isActivityBlock && b.activityId == activityId,
    );
    if (activityBlockIndex == -1) return;

    // Find and schedule next audio block
    final nextBlock = _findNextAudioBlock(activityBlockIndex);
    if (nextBlock != null) {
      _scheduleAutoPlay(nextBlock, autoPlayConfig.afterActivityDelayMs);
    }
  }

  /// Handle word playback completion - resume chapter audio if it was playing
  void _handleWordComplete() {
    _audioService.pause();
    state = state.copyWith(
      isPlaying: false,
      isPlayingWord: false,
      clearActiveWord: true,
    );

    // Resume chapter audio if it was playing before word tap
    if (_resumeInfo != null && _resumeInfo!.wasPlaying) {
      _resumeChapterPlayback();
    } else {
      _resumeInfo = null;
    }
  }

  /// Resume chapter playback from saved position
  Future<void> _resumeChapterPlayback() async {
    final resume = _resumeInfo;
    if (resume == null) return;

    await _audioService.seek(Duration(milliseconds: resume.globalPositionMs));

    if (resume.wasPlaying) {
      await _audioService.resume();
    }

    _resumeInfo = null;
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
      // Emit completion event and trigger auto-play
      if (completedBlockId != null) {
        _emitCompletionAndAutoPlay(completedBlockId);
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
        // Segment-based: duration is segment length + buffer for natural audio decay
        blockDurationMs = block.audioEndMs! - block.audioStartMs! + _segmentEndBufferMs;
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

  /// Play/resume audio - enters listening mode
  Future<void> play() async {
    if (state.currentBlockId == null) return;
    _isInListeningMode = true;
    await _audioService.resume();
  }

  /// Pause audio - exits listening mode (user chose to stop)
  Future<void> pause() async {
    _isInListeningMode = false;
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

  /// Stop and clear current audio - exits listening mode
  Future<void> stop() async {
    _isInListeningMode = false;
    await _audioService.stop();
    _currentWordTimings = [];
    _segmentStartMs = null;
    _segmentEndMs = null;
    _currentAudioUrl = null;
    _resumeInfo = null;
    state = const AudioSyncState();
  }

  /// Play a single word's audio segment.
  /// Saves current playback state to resume after word finishes.
  Future<void> playWord({
    required String audioUrl,
    required int startMs,
    required int endMs,
    required String blockId,
  }) async {
    // Save current playback state for resume
    if (state.isPlaying || state.currentBlockId != null) {
      final globalPositionMs = _segmentStartMs != null
          ? (_segmentStartMs! + state.positionMs)
          : state.positionMs;
      _resumeInfo = ChapterResumeInfo(
        blockId: state.currentBlockId ?? blockId,
        globalPositionMs: globalPositionMs,
        wasPlaying: state.isPlaying,
      );
      await pause();
    }

    // Set word segment boundaries - exact start and end, no buffer
    _segmentStartMs = startMs;
    _segmentEndMs = endMs;

    state = state.copyWith(
      currentBlockId: blockId,
      isPlayingWord: true,
      isLoading: true,
      positionMs: 0,
      clearActiveWord: true,
    );

    try {
      // Load audio if URL changed
      if (_currentAudioUrl != audioUrl) {
        _currentAudioUrl = audioUrl;
        await _audioService.player.setUrl(audioUrl);
      }

      // Seek to word start and play
      await _audioService.seek(Duration(milliseconds: startMs));

      state = state.copyWith(
        isLoading: false,
        durationMs: endMs - startMs,
      );

      await _audioService.resume();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isPlayingWord: false,
        error: 'Failed to play word: $e',
      );
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _autoPlayTimer?.cancel();
    _completionController.close();
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

  final controller = AudioSyncController(audioService);

  // Forward completion events to StateProvider for backwards compatibility
  final subscription = controller.onBlockCompleted.listen((blockId) {
    ref.read(audioCompletedBlockProvider.notifier).state = blockId;
  });

  ref.onDispose(() {
    subscription.cancel();
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
