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
      // ドラッグ中の見た目を最適化（別のレイヤーで描画して軽くする）
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Material(
              elevation: 4.0,
              color: Colors.white.withOpacity(0.8),
              child: child,
            );
          },
        );
      },
      itemCount: controller.musicFiles.length,
      onReorder: controller.reorder,
      itemBuilder: (context, index) {
        final music = controller.musicFiles[index];
        return MusicTile(
          key: music.key,
          music: music,
          onTap: () => controller.play(music),
          onMenuPressed: () {
            _openItemModal(context, index, music, controller);
          },
          // ドラッグがあるので、ボタンでの移動はオプションとして残す
          onMoveUp: index > 0 ? () => controller.moveMusicUp(index) : null,
          onMoveDown: index < controller.musicFiles.length - 1
              ? () => controller.moveMusicDown(index)
              : null,
          isPlaying:
              controller.selectedMusic?.path == music.path &&
              controller.isPlaying,
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
    int index,
    MusicFile music,
    MusicPlayerController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${music.title} を操作",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),

                // 次に再生
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text("次に再生"),
                  onTap: () {
                    controller.moveMusicNext(index);
                    Navigator.pop(modalContext);
                  },
                ),

                // 上に移動
                if (index > 0)
                  ListTile(
                    leading: const Icon(Icons.arrow_upward),
                    title: const Text("上に移動"),
                    onTap: () {
                      controller.moveMusicUp(index);
                      Navigator.pop(modalContext);
                    },
                  ),

                // 下に移動
                if (index < controller.musicFiles.length - 1)
                  ListTile(
                    leading: const Icon(Icons.arrow_downward),
                    title: const Text("下に移動"),
                    onTap: () {
                      controller.moveMusicDown(index);
                      Navigator.pop(modalContext);
                    },
                  ),

                const Divider(),

                // 削除ボタン
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    "再生キューから削除",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    controller.removeMusic(music);
                    Navigator.pop(modalContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${music.title} を削除しました")),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    "ファイル削除",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    controller.deleteMusicFile(context, music);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
