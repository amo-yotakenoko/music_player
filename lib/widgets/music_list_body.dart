import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import 'music_tile.dart';

import '../classes/music.dart';

/// 【表示部品層（ボディ）】
/// 読み込み中、空、リスト表示の切り替えロジックを担当。
class MusicListBody extends StatelessWidget {
  final MusicPlayerController controller;

  const MusicListBody({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.musicFiles.isEmpty) {
      return _buildEmptyView();
    }

    return ReorderableListView.builder(
      itemCount: controller.musicFiles.length,
      onReorder: controller.reorder,
      itemBuilder: (context, index) {
        final music = controller.musicFiles[index];
        return RepaintBoundary(
          key: ValueKey(music.path),
          child: MusicTile(
            key: ValueKey(music.path),
            music: music,
            onTap: () => controller.play(music),
            onLongPress: () {
              _openItemModal(context, music, controller);
            },
            isPlaying:
                controller.selectedMusic?.path == music.path &&
                controller.isPlaying,
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('音楽ファイルが見つかりませんでした'),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: controller.loadFiles,
            child: const Text('再読み込み'),
          ),
        ],
      ),
    );
  }

  void _openItemModal(
    BuildContext context,
    MusicFile music,
    MusicPlayerController controller,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          // ボタンを並べるためにColumnを使います
          child: Column(
            mainAxisSize: MainAxisSize.min, // 中身の高さに合わせる
            children: [
              Text(
                "${music.title} を操作", // 曲名を表示
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),

              // 削除ボタン
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "リストから削除",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  // 1. コントローラーの削除メソッドを呼ぶ
                  controller.removeMusic(music);

                  // 2. モーダルを閉じる
                  Navigator.pop(context);

                  // (任意) 削除完了を知らせるスナックバーを出す
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${music.title} を削除しました")),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
