import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_service.g.dart';

/// Service for managing audio playback (audiobooks, vocabulary pronunciation)
class AudioService {
  AudioPlayer? _player;
  AudioSession? _session;

  Future<void> initialize() async {
    _player = AudioPlayer();
    _session = await AudioSession.instance;

    await _session!.configure(const AudioSessionConfiguration.speech());

    // Handle audio interruptions
    _session!.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player?.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _player?.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player?.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            _player?.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  AudioPlayer get player {
    if (_player == null) {
      throw StateError('AudioService not initialized. Call initialize() first.');
    }
    return _player!;
  }

  /// Play audio from URL
  Future<void> play(String url) async {
    await _player?.setUrl(url);
    await _player?.play();
  }

  /// Play audio from local file
  Future<void> playLocal(String filePath) async {
    await _player?.setFilePath(filePath);
    await _player?.play();
  }

  /// Pause playback
  Future<void> pause() async {
    await _player?.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await _player?.play();
  }

  /// Stop playback
  Future<void> stop() async {
    await _player?.stop();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _player?.setSpeed(speed);
  }

  /// Get current position stream
  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream.empty();

  /// Get current duration
  Duration? get duration => _player?.duration;

  /// Get current playback state
  Stream<PlayerState> get playerStateStream =>
      _player?.playerStateStream ?? const Stream.empty();

  /// Check if currently playing
  bool get isPlaying => _player?.playing ?? false;

  /// Dispose resources
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}

@Riverpod(keepAlive: true)
Future<AudioService> audioService(AudioServiceRef ref) async {
  final service = AudioService();
  await service.initialize();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
