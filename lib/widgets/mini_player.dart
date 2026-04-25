import 'package:flutter/material.dart';

/// 【表示部品層（プレイヤー）】
/// 親から渡されたデータを表示し、操作イベントを親に通知する役割。
/// 自身で状態を管理せず、渡されたデータ（曲名、再生状態）に従って表示を切り替える（ステートレス）。
class MiniPlayer extends StatelessWidget {
  // 親（MusicListScreen）から渡されるデータ
  final String? songName;
  final bool isPlaying;
  // 操作（再生/停止）が発生したことを親に伝えるためのコールバック
  final VoidCallback? onPlayPause;

  const MiniPlayer({
    super.key,
    this.songName,
    this.isPlaying = false,
    this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    // 曲が選択されていない場合は何も表示しない
    if (songName == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ListTile(
          leading: const Icon(Icons.music_note, color: Colors.blue),
          title: Text(
            songName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: const Text('再生中'),
          trailing: IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
            iconSize: 40,
            onPressed: onPlayPause, // タップされたら親に通知
          ),
        ),
      ),
    );
  }
}
