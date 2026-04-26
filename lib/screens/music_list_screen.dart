import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import '../widgets/mini_player.dart';
import '../widgets/music_list_body.dart';
import '../widgets/upside_config.dart';

/// 【表示層（メイン画面）】
/// 画面の全体構造（Scaffold）のみを定義し、具体的な中身やロジックは他に任せる。
class MusicListScreen extends StatefulWidget {
  const MusicListScreen({super.key});

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {
  // ロジックと状態を持つコントローラー
  late final MusicPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MusicPlayerController();
    // 初期データの読み込み
    _controller.loadFiles();
    // _controller.loadValues();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ConfigSetter(controller: _controller),
      // ボディ部分だけを監視するように移動
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return MusicListBody(controller: _controller);
        },
      ),

      // プレイヤー部分を分離
      bottomNavigationBar: ValueListenableBuilder<Duration>(
        valueListenable: _controller.durationNotifier,
        builder: (context, duration, _) {
          return ValueListenableBuilder<Duration>(
            valueListenable: _controller.positionNotifier,
            builder: (context, position, _) {
              return MiniPlayer(controller: _controller);
            },
          );
        },
      ),
    );
  }
}
