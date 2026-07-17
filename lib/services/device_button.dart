import 'dart:async';
import 'package:flutter/foundation.dart';
import 'music_handler.dart';

class DeviceButton {
  final MusicHandler _handler;
  StreamSubscription? _sub;

  final ValueNotifier<String> lastEvent = ValueNotifier('');

  int _burstCount = 0;
  Timer? _burstTimer;
  static const _burstTimeout = Duration(milliseconds: 500);

  DeviceButton(this._handler);

  void start() {
    _sub = _handler.deviceButtonStream.listen((event) {
      final msg = _describe(event);
      debugPrint('[DeviceButton] $msg');
      lastEvent.value = msg;
    });
    debugPrint('[DeviceButton] monitoring started');
  }

  void stop() {
    _burstTimer?.cancel();
    _sub?.cancel();
    debugPrint('[DeviceButton] monitoring stopped');
  }

  /// 再生/停止ボタンの押下をバースト単位で管理する。
  /// 0.5秒の無入力後にバーストが確定し、回数に応じてアクションを実行する。
  /// [callbacks] の 0 番目 = 1回押し, 1 番目 = 2回押し, 2 番目 = 3回押し…
  void handlePlayPause(List<VoidCallback> callbacks) {
    _burstCount++;
    _burstTimer?.cancel();
    _burstTimer = Timer(_burstTimeout, () {
      final count = _burstCount;
      _burstCount = 0;
      _burstTimer = null;
      debugPrint('[DeviceButton] バースト終了: $count 回');
      final idx = (count - 1).clamp(0, callbacks.length - 1);
      callbacks[idx]();
    });
  }

  String _describe(DeviceButtonEvent event) {
    switch (event) {
      case DeviceButtonEvent.play:
        return '再生ボタン押下';
      case DeviceButtonEvent.pause:
        return '一時停止ボタン押下';
      case DeviceButtonEvent.skipNext:
        return '次へボタン押下';
      case DeviceButtonEvent.skipPrevious:
        return '前へボタン押下';
      case DeviceButtonEvent.seek:
        return 'シーク操作';
    }
  }
}
