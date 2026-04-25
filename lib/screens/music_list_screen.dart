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
    // コントローラーの状態変化を監視して画面を更新する
    _controller.addListener(_onControllerUpdate);
    // 初期データの読み込み
    _controller.loadFiles();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ConfigSetter(controller: _controller),
      // ボディ部分を分離
      body: MusicListBody(controller: _controller),
      // プレイヤー部分を分離
      bottomNavigationBar: MiniPlayer(
        songName: _controller.selectedMusic?.title,
        isPlaying: _controller.isPlaying,
        position: _controller.position,
        duration: _controller.duration,
        onPlayPause: _controller.togglePlayPause,
        onSeek: (value) =>
            _controller.seek(Duration(milliseconds: value.toInt())),
      ),
    );
  }
}
