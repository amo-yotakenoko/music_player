import 'package:flutter/material.dart';

/// 【表示部品層（リストアイテム）】
/// 1つの音楽ファイルを表示するためのタイルウィジェット。
class MusicTile extends StatelessWidget {
  final String fileName;
  final String filePath;
  final VoidCallback onTap;
  final bool isPlaying;

  const MusicTile({
    super.key,
    required this.fileName,
    required this.filePath,
    required this.onTap,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      trailing: isPlaying ? Icon(Icons.equalizer, color: Colors.green) : null,
      title: Text(fileName),
      subtitle: Text(
        filePath,
        style: const TextStyle(fontSize: 10),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
