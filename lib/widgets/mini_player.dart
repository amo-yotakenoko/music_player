import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';

/// 【表示部品層（プレイヤー）】
/// コントローラーの状態を監視し、再生バーと操作ボタンを表示する。
class MiniPlayer extends StatelessWidget {
  final MusicPlayerController controller;

  const MiniPlayer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.selectedMusic == null) return const SizedBox.shrink();

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
            // 再生バー (Slider) - 頻繁に更新されるためValueListenableBuilderを使用
            ValueListenableBuilder<Duration>(
              valueListenable: controller.durationNotifier,
              builder: (context, duration, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: controller.positionNotifier,
                  builder: (context, position, _) {
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
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
                          controller.seek(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            // 再生情報の表示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.selectedMusic!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        // 時間表示も監視
                        ValueListenableBuilder<Duration>(
                          valueListenable: controller.durationNotifier,
                          builder: (context, duration, _) {
                            return ValueListenableBuilder<Duration>(
                              valueListenable: controller.positionNotifier,
                              builder: (context, position, _) {
                                return Text(
                                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_left,
                      color: Colors.orange[700],
                    ),
                    iconSize: 40,
                    onPressed: () => controller.timeSkip(-5),
                  ),
                  IconButton(
                    icon: Icon(
                      controller.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    iconSize: 40,
                    onPressed: controller.togglePlayPause,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_right,
                      color: Colors.orange[700],
                    ),
                    iconSize: 40,
                    onPressed: () => controller.timeSkip(5),
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
