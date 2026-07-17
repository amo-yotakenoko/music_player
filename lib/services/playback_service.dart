import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../classes/music.dart';
import 'music_handler.dart';

class PlaybackSession {
  MusicItem? selectedMusic;
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  bool isPlaying = false;
  double playbackSpeed = 1.0;

  void resetProgress() {
    position.value = Duration.zero;
  }
}

enum SessionType { music, media }

class PlaybackService extends ChangeNotifier {
  static final PlaybackService _instance = PlaybackService._internal();
  factory PlaybackService() => _instance;
  PlaybackService._internal() {
    _connectHandler();
  }

  final Map<SessionType, PlaybackSession> _sessions = {
    SessionType.music: PlaybackSession(),
    SessionType.media: PlaybackSession(),
  };

  SessionType _activeType = SessionType.music;
  SessionType _playingType = SessionType.music;
  bool _isTransitioning = false;
  bool _isPlaying = false;
  MusicItem? _pendingPlayMusic;
  String? _lastCompletedTrackId;

  SessionType get activeType => _activeType;
  SessionType get playingType => _playingType;

  PlaybackSession get activeSession => _sessions[_activeType]!;
  PlaybackSession get playingSession => _sessions[_playingType]!;

  PlaybackSession getSession(SessionType type) => _sessions[type]!;

  AudioPlayer get player => MusicHandler.instance.player;

  VoidCallback? onMusicNext;
  VoidCallback? onMediaNext;

  VoidCallback? onMusicAddRandomNext;
  VoidCallback? onMediaAddRandomNext;

  void _connectHandler() {
    final handler = MusicHandler.instance;

    handler.onPosition = (p) {
      playingSession.position.value = p;
      _checkTrackCompletion(p);
    };

    handler.onDuration = (d) {
      playingSession.duration.value = d;
    };

    handler.onPlayerState = (state) {
      if (_isTransitioning) return;
      playingSession.isPlaying = state.playing;

      if (!state.playing && playingSession.selectedMusic != null) {
        saveProgress();
      }

      notifyListeners();
    };

    handler.onCompleted = () => _onTrackCompleted();

    handler.onSkipNext = () {
      if (_playingType == SessionType.music) {
        onMusicNext?.call();
      } else {
        onMediaNext?.call();
      }
    };

    handler.onAddRandomNext = () {
      if (_playingType == SessionType.music) {
        onMusicAddRandomNext?.call();
      } else {
        onMediaAddRandomNext?.call();
      }
    };
  }

  void _checkTrackCompletion(Duration position) {
    final dur = playingSession.duration.value;
    final music = playingSession.selectedMusic;
    if (music == null) return;
    if (_lastCompletedTrackId == music.id) return;
    if (dur <= Duration.zero || !playingSession.isPlaying) return;
    if (dur - position > const Duration(milliseconds: 500)) return;
    _onTrackCompleted();
  }

  void _onTrackCompleted() {
    final music = playingSession.selectedMusic;
    if (music == null) return;
    _lastCompletedTrackId = music.id;
    if (_playingType == SessionType.music) {
      onMusicNext?.call();
    } else {
      onMediaNext?.call();
    }
  }

  Future<void> saveProgress() {
    if (playingSession.selectedMusic != null) {
      if (playingSession.selectedMusic?.directory.contains("配信") == true) {
        return playingSession.selectedMusic!.saveProgress(
          MusicHandler.instance.player.position,
          totalDuration: MusicHandler.instance.player.duration,
        );
      }
    }

    return Future.value();
  }

  Future<void> switchSession(SessionType newType) async {
    if (_activeType == newType) return;

    _activeType = newType;

    final targetSession = _sessions[newType]!;

    if (targetSession.selectedMusic != null && targetSession.isPlaying) {
      if (_playingType == newType && MusicHandler.instance.player.playing) {
        notifyListeners();
        return;
      }
      await _loadAndPlay(newType, targetSession);
    }

    notifyListeners();
  }

  Future<void> play(SessionType type, MusicItem music) async {
    if (_isPlaying) {
      _pendingPlayMusic = music;
      return;
    }
    _isPlaying = true;
    _pendingPlayMusic = null;
    try {
      if (playingSession.selectedMusic != null) {
        await saveProgress();
      }

      final session = _sessions[type]!;
      session.selectedMusic = music;
      session.isPlaying = true;
      _lastCompletedTrackId = null;
      session.position.value = Duration.zero;
      session.duration.value = Duration.zero;
      notifyListeners();

      final savedPosition = await music.loadProgress();
      final savedDuration = await music.loadTotalDuration();
      session.position.value = savedPosition;

      if (savedDuration != null &&
          savedDuration > Duration.zero &&
          savedPosition > Duration.zero &&
          savedDuration - savedPosition < const Duration(seconds: 10)) {
        final rewound = savedPosition - const Duration(seconds: 10);
        session.position.value =
            rewound < Duration.zero ? Duration.zero : rewound;
      }

      await _loadAndPlay(type, session);
      notifyListeners();
    } finally {
      _isPlaying = false;
      final pending = _pendingPlayMusic;
      _pendingPlayMusic = null;
      if (pending != null) {
        play(type, pending);
      }
    }
  }

  Future<void> _loadAndPlay(SessionType type, PlaybackSession session) async {
    final music = session.selectedMusic;
    if (music == null) return;

    _isTransitioning = true;
    final handler = MusicHandler.instance;
    final initialPos = session.position.value;
    try {
      await handler.stop();

      _playingType = type;
      session.duration.value = Duration.zero;

      await music.loadVolumeFromCache();
      await handler.setVolume(
        music.integratedLoudness != null ? music.adjustedVolume : 0.8,
      );

      final effectiveSpeed = (type == SessionType.music)
          ? 1.0
          : session.playbackSpeed;
      await handler.setSpeed(effectiveSpeed);

      final source = AudioSource.uri(
        Uri.file(music.path),
        tag: music.toMediaItem(),
      );

      handler.updateNowPlaying(music);

      await handler.load(
        source: source,
        initialPosition: initialPos,
      );

      if (session.isPlaying) {
        await handler.playFromApp();
      }
    } catch (e) {
      print("Playback Error: $e");
      try { await handler.player.stop(); } catch (_) {}
      await handler.recover();
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> togglePlayPause() async {
    final handler = MusicHandler.instance;
    if (handler.player.playing) {
      if (playingSession.selectedMusic != null) {
        await saveProgress();
      }
      await handler.pauseFromApp();
    } else {
      await handler.playFromApp();
    }
  }

  Future<void> seek(Duration pos) async {
    await MusicHandler.instance.player.seek(pos);
    if (playingSession.selectedMusic != null) {
      saveProgress();
    }
  }

  Future<void> setSpeed(double speed) async {
    playingSession.playbackSpeed = speed;
    final effectiveSpeed = (_playingType == SessionType.music) ? 1.0 : speed;
    await MusicHandler.instance.setSpeed(effectiveSpeed);
    notifyListeners();
  }
}
