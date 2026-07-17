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
      if (_isTransitioning) return;
      playingSession.position.value = p;
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

    handler.onCompleted = () {
      if (_playingType == SessionType.music) {
        onMusicNext?.call();
      } else {
        onMediaNext?.call();
      }
    };

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
    if (playingSession.selectedMusic != null) {
      await saveProgress();
    }

    final session = _sessions[type]!;
    session.selectedMusic = music;
    session.isPlaying = true;

    final savedPosition = await music.loadProgress();
    session.position.value = savedPosition;

    await _loadAndPlay(type, session);
    notifyListeners();
  }

  Future<void> _loadAndPlay(SessionType type, PlaybackSession session) async {
    final music = session.selectedMusic;
    if (music == null) return;

    _isTransitioning = true;
    try {
      final handler = MusicHandler.instance;
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

      Duration initialPosition = session.position.value;
      if (session.duration.value - initialPosition < Duration(seconds: 10)) {
        initialPosition -= Duration(seconds: 10);
      }

      await handler.load(
        source: source,
        initialPosition: initialPosition,
      );

      if (session.isPlaying) {
        await handler.playFromApp();
      }
    } catch (e) {
      print("Playback Error: $e");
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
