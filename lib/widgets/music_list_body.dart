import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import 'music_tile.dart';

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
}
