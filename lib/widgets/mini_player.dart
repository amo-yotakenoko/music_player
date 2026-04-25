import 'package:flutter/material.dart';

/// 【表示部品層（プレイヤー）】
/// 親から渡されたデータを表示し、操作イベントを親に通知する役割。
/// 再生バー（Slider）を追加し、再生位置と曲の長さを表示するように拡張。
class MiniPlayer extends StatelessWidget {
  final String? songName;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback? onPlayPause;
  final ValueChanged<double>? onSeek;

  const MiniPlayer({
    super.key,
    this.songName,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.onPlayPause,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    if (songName == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 再生バー (Slider)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 2,
              ),
              child: Slider(
                value: position.inMilliseconds
                    .clamp(0.0, duration.inMilliseconds)
                    .toDouble(),
                max: duration.inMilliseconds.toDouble() > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (value) {
                  if (onSeek != null) onSeek!(value);
                },
              ),
            ),
            // 再生情報の表示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          songName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    iconSize: 40,
                    onPressed: onPlayPause,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Durationを「分:秒」の形式に変換
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
