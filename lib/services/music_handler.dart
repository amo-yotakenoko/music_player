import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../classes/music.dart';
import 'device_button.dart';

enum DeviceButtonEvent { play, pause, skipNext, skipPrevious, seek }

class MusicHandler extends BaseAudioHandler {
  static MusicHandler? _instance;
  static MusicHandler get instance => _instance!;

  AudioPlayer player = AudioPlayer();

  VoidCallback? onCompleted;
  ValueChanged<Duration>? onPosition;
  ValueChanged<Duration>? onDuration;
  ValueChanged<PlayerState>? onPlayerState;

  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  ValueChanged<int>? onSkipToIndex;

  VoidCallback? onAddRandomNext;

  final StreamController<DeviceButtonEvent> _deviceButtonCtl =
      StreamController<DeviceButtonEvent>.broadcast();
  Stream<DeviceButtonEvent> get deviceButtonStream => _deviceButtonCtl.stream;

  late final DeviceButton _deviceButton;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<ProcessingState>? _processingStateSub;

  MusicHandler() {
    _instance = this;
    _deviceButton = DeviceButton(this);
    _deviceButton.start();
    _setupListeners();
  }

  void _setupListeners() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _processingStateSub?.cancel();

    _positionSub = player.positionStream.listen((p) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: p,
      ));
      onPosition?.call(p);
    });

    _durationSub = player.durationStream.listen((d) {
      if (d == null) return;
      mediaItem.add(mediaItem.value?.copyWith(
        duration: d,
      ));
      onDuration?.call(d);
    });

    _playerStateSub = player.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state.playing,
        processingState: state.processingState == ProcessingState.ready
            ? AudioProcessingState.ready
            : state.processingState == ProcessingState.buffering
                ? AudioProcessingState.buffering
                : state.processingState == ProcessingState.completed
                    ? AudioProcessingState.completed
                    : AudioProcessingState.ready,
      ));
      onPlayerState?.call(state);
    });

    _processingStateSub = player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        onCompleted?.call();
      }
    });
  }

  Future<void> recover() async {
    await player.dispose();
    player = AudioPlayer();
    _setupListeners();
  }

  /// システム（イヤホンボタン / ロック画面）から呼ばれる。
  /// バースト終了後に回数に応じたアクションを実行する。
  @override
  Future<void> play() {
    _deviceButtonCtl.add(DeviceButtonEvent.play);
    _deviceButton.handlePlayPause([
      _togglePlayPause,
      _triggerSkipNext,
      _triggerAddRandomNext,
    ]);
    return Future.value();
  }

  /// システム（イヤホンボタン / ロック画面）から呼ばれる。
  /// バースト終了後に回数に応じたアクションを実行する。
  @override
  Future<void> pause() {
    _deviceButtonCtl.add(DeviceButtonEvent.pause);
    _deviceButton.handlePlayPause([
      _togglePlayPause,
      _triggerSkipNext,
      _triggerAddRandomNext,
    ]);
    return Future.value();
  }

  @override
  Future<void> skipToNext() {
    _deviceButtonCtl.add(DeviceButtonEvent.skipNext);
    onSkipNext?.call();
    return Future.value();
  }

  @override
  Future<void> skipToPrevious() {
    _deviceButtonCtl.add(DeviceButtonEvent.skipPrevious);
    onSkipPrevious?.call();
    return Future.value();
  }

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> seek(Duration position) {
    _deviceButtonCtl.add(DeviceButtonEvent.seek);
    return player.seek(position);
  }

  @override
  Future<void> skipToQueueItem(int index) {
    onSkipToIndex?.call(index);
    return Future.value();
  }

  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  Future<void> playFromApp() => player.play();

  Future<void> pauseFromApp() => player.pause();

  Future<void> setVolume(double vol) => player.setVolume(vol);

  Future<void> load({
    required AudioSource source,
    Duration? initialPosition,
  }) async {
    await player.stop();
    await player.setAudioSource(source, initialPosition: initialPosition);
  }

  void updateNowPlaying(MusicItem music) {
    mediaItem.add(music.toMediaItem());
  }

  void _togglePlayPause() {
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  Future<void> _triggerSkipNext() async {
    _deviceButtonCtl.add(DeviceButtonEvent.skipNext);
    onSkipNext?.call();
    // PlaybackService.play() → _loadAndPlay() が handler.playFromApp() で
    // 再生を開始するので、ここで player.play() を呼ぶと競合する。
  }

  Future<void> _triggerAddRandomNext() async {
    _deviceButtonCtl.add(DeviceButtonEvent.skipNext);
    onAddRandomNext?.call();
  }
}
