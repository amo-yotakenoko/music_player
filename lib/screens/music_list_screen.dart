import 'package:flutter/material.dart';
import 'package:music_player/screens/media_screen.dart';
import '../controllers/music_player_controller.dart';
import '../widgets/mini_player.dart';
import '../widgets/music_list_body.dart';
import '../widgets/upside_config.dart';
import '../widgets/side_ui.dart';
import '../controllers/media_player_controller.dart';

/// 【表示層（メイン画面）】
/// 画面の全体構造（Scaffold）のみを定義し、具体的な中身やロジックは他に任せる。
class MusicListScreen extends StatefulWidget {
  const MusicListScreen({super.key});

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {
  // ロジックと状態を持つコントローラー
  late final MusicPlayerController _musicController;
  late final MediaPlayerController _mediaController;

  @override
  void initState() {
    super.initState();
    _musicController = MusicPlayerController();
    _mediaController = MediaPlayerController();
    // 初期データの読み込み
    _musicController.loadFiles();
    _mediaController.loadFiles();
    // _controller.loadValues();
  }

  @override
  void dispose() {
    _musicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ConfigSetter(controller: _musicController),
      // ボディ部分だけを監視するように移動
      body: ListenableBuilder(
        listenable: _musicController,
        builder: (context, _) {
          return PageView(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SideUI(controller: _musicController),
                  ),
                  Expanded(
                    flex: 9,
                    child: MusicListBody(controller: _musicController),
                  ),
                ],
              ),
              MusicListBody(controller: _mediaController),
            ],
          );
        },
      ),

      // プレイヤー部分を分離
      bottomNavigationBar: ValueListenableBuilder<Duration>(
        valueListenable: _musicController.durationNotifier,
        builder: (context, duration, _) {
          return ValueListenableBuilder<Duration>(
            valueListenable: _musicController.positionNotifier,
            builder: (context, position, _) {
              return MiniPlayer(controller: _musicController);
            },
          );
        },
      ),
    );
  }
}
