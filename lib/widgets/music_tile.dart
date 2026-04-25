import 'package:flutter/material.dart';
import '../classes/music.dart';

/// 【表示部品層（リストアイテム）】
/// 1つの音楽ファイルを表示するためのタイルウィジェット。
class MusicTile extends StatelessWidget {
  final MusicFile music;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isPlaying;

  const MusicTile({
    super.key,
    required this.music,
    required this.onTap,
    required this.onLongPress,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isPlaying ? Icons.play_arrow : Icons.music_note,
        color: isPlaying ? Colors.green : Colors.blue,
      ),
      trailing: isPlaying
          ? const Icon(Icons.equalizer, color: Colors.green)
          : null,
      title: Text(
        music.title,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
          color: isPlaying ? Colors.green : null,
        ),
      ),
      subtitle: Text(
        music.path,
        style: const TextStyle(fontSize: 10),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
