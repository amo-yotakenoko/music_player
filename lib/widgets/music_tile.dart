import 'package:flutter/material.dart';
import '../classes/music.dart';

/// 【共通命令】
/// リストを少しだけスクロールさせる
void music_list_move(BuildContext context, int scroll) {
  final scrollable = Scrollable.maybeOf(context);
  if (scrollable != null) {
    scrollable.position.jumpTo(scrollable.position.pixels + scroll * 72);
  }
}

/// 【表示部品層（リストアイテム）】
/// 1つの音楽ファイルを表示するためのタイルウィジェット。
class MusicTile extends StatelessWidget {
  final MusicFile music;
  final VoidCallback onTap;
  final VoidCallback onMenuPressed;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool isPlaying;

  const MusicTile({
    super.key,
    required this.music,
    required this.onTap,
    required this.onMenuPressed,
    this.onMoveUp,
    this.onMoveDown,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(isPlaying ? Icons.play_circle_filled : Icons.music_note),
            color: isPlaying ? Colors.green : Colors.blue,
            onPressed: onMenuPressed,
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上ボタン
              GestureDetector(
                onTap: () {
                  onMoveUp?.call();
                  music_list_move(context, -1);
                },
                child: const Icon(Icons.arrow_drop_up, size: 20),
              ),

              // 下ボタン
              GestureDetector(
                onTap: () {
                  onMoveDown?.call();
                  music_list_move(context, 1);
                },

                child: const Icon(Icons.arrow_drop_down, size: 20),
              ),
            ],
          ),
        ],
      ),

      title: Text(
        music.title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
          color: isPlaying ? Colors.green : null,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Text(
        music.artist ?? "Unknown Artist",
        style: const TextStyle(fontSize: 10),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
