import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../classes/music.dart';

/// プレイヤーの状態を保持するためのクラス
class PlaybackSession {
  MusicFile? selectedMusic;
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  bool isPlaying = false;
  double playbackSpeed = 1.0;

  void resetProgress() {
    position.value = Duration.zero;
  }
}

enum SessionType { music, media }

/// 【サービス層】
/// アプリ全体の「音の再生」を一手に引き受ける司令塔。
class PlaybackService extends ChangeNotifier {
  static final PlaybackService _instance = PlaybackService._internal();
  factory PlaybackService() => _instance;
  PlaybackService._internal() {
    _init();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // セッションごとの状態管理
  final Map<SessionType, PlaybackSession> _sessions = {
    SessionType.music: PlaybackSession(),
    SessionType.media: PlaybackSession(),
  };

  // UI上でどちらのタブを選択しているか
  SessionType _activeType = SessionType.music;
  // 実際にプレイヤーがどちらのタイプを再生しているか
  SessionType _playingType = SessionType.music;
  // 遷移中フラグ
  bool _isTransitioning = false;

  // 外部公開用のゲッター
  SessionType get activeType => _activeType;
  SessionType get playingType => _playingType;
  
  PlaybackSession get activeSession => _sessions[_activeType]!;
  PlaybackSession get playingSession => _sessions[_playingType]!;
  
  PlaybackSession getSession(SessionType type) => _sessions[type]!;
  AudioPlayer get player => _audioPlayer;

  void _init() {
    _audioPlayer.positionStream.listen((p) {
      if (_isTransitioning) return;
      playingSession.position.value = p;
    });
    _audioPlayer.durationStream.listen((d) {
      if (d == null) return;
      playingSession.duration.value = d;
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (_isTransitioning) return;
      playingSession.isPlaying = state.playing;
      
      // 再生が止まった（ポーズされた）タイミングで進捗を保存
      if (!state.playing && playingSession.selectedMusic != null) {
        playingSession.selectedMusic!.saveProgress(
          _audioPlayer.position,
          totalDuration: _audioPlayer.duration,
        );
      }
      
      notifyListeners(); 
    });
    _audioPlayer.speedStream.listen((speed) {
      playingSession.playbackSpeed = speed;
    });
  }

  /// セッションを切り替える
  Future<void> switchSession(SessionType newType) async {
    if (_activeType == newType) return;
    
    _activeType = newType;

    final targetSession = _sessions[newType]!;
    
    if (targetSession.selectedMusic != null && targetSession.isPlaying) {
      if (_playingType == newType && _audioPlayer.playing) {
        notifyListeners();
        return;
      }
      await _loadAndPlay(newType, targetSession);
    }

    notifyListeners();
  }

  /// 曲を再生する
  Future<void> play(SessionType type, MusicFile music) async {
    // 現在の曲の進捗を保存してから切り替える
    if (playingSession.selectedMusic != null) {
      await playingSession.selectedMusic!.saveProgress(
        _audioPlayer.position,
        totalDuration: _audioPlayer.duration,
      );
    }

    final session = _sessions[type]!;
    session.selectedMusic = music;
    session.isPlaying = true;
    
    // 保存されていた進捗を読み込む
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
      await _audioPlayer.stop();
      
      _playingType = type;
      // 読み込み開始時に時間をリセット（位置指定がある場合は後で上書きされる）
      session.duration.value = Duration.zero;

      await music.loadVolumeFromCache();
      await _audioPlayer.setVolume(music.integratedLoudness != null ? music.adjustedVolume : 0.8);

      // Musicセッションの場合は倍速再生を1.0に固定、Mediaセッションの場合は設定値を適用
      final effectiveSpeed = (type == SessionType.music) ? 1.0 : session.playbackSpeed;
      await _audioPlayer.setSpeed(effectiveSpeed);

      final source = AudioSource.uri(
        Uri.file(music.path),
        tag: music.toMediaItem(),
      );

      await _audioPlayer.setAudioSource(source, initialPosition: session.position.value);
      
      if (session.isPlaying) {
        _audioPlayer.play();
      }
    } catch (e) {
      print("Playback Error: $e");
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      if (playingSession.selectedMusic != null) {
        await playingSession.selectedMusic!.saveProgress(
          _audioPlayer.position,
          totalDuration: _audioPlayer.duration,
        );
      }
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> seek(Duration pos) async {
    await _audioPlayer.seek(pos);
    // シーク後も保存しておく
    if (playingSession.selectedMusic != null) {
      playingSession.selectedMusic!.saveProgress(
        pos,
        totalDuration: _audioPlayer.duration,
      );
    }
  }

  Future<void> setSpeed(double speed) async {
    playingSession.playbackSpeed = speed;
    // 再生中のセッションがMusicの場合は常に1.0、Mediaの場合は指定速度を適用
    final effectiveSpeed = (_playingType == SessionType.music) ? 1.0 : speed;
    await _audioPlayer.setSpeed(effectiveSpeed);
    notifyListeners();
  }
}
