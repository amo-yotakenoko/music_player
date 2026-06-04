import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import '../classes/music.dart';

class MediaPlayerScreen extends StatelessWidget {
  final MusicPlayerController controller;

  const MediaPlayerScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final music = controller.selectedMusic;

        return Scaffold(
          backgroundColor: Colors.black,
          body: music == null
              ? const Center(child: Text('再生中のメディアはありません', style: TextStyle(color: Colors.white)))
              : RotatedBox(
                  quarterTurns: 1, // 90度回転
                  child: Stack(
                    children: [
                      // メインコンテンツ
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            // タイトル表示
                            Text(
                              music.title,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 30),

                            // 進捗バー
                            ListenableBuilder(
                              listenable: controller.positionNotifier,
                              builder: (context, _) {
                                final pos = controller.position;
                                final dur = controller.duration;
                                return Column(
                                  children: [
                                    Slider(
                                      value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                                      max: dur.inMilliseconds.toDouble(),
                                      activeColor: Colors.blue,
                                      inactiveColor: Colors.grey,
                                      onChanged: (value) {
                                        controller.seek(Duration(milliseconds: value.toInt()));
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(_formatDuration(pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                          Text(_formatDuration(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // コントロール：10秒戻る、10秒進む
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  iconSize: 64,
                                  icon: const Icon(Icons.replay_10, color: Colors.white),
                                  onPressed: () => controller.timeSkip(-10),
                                ),
                                const SizedBox(width: 60),
                                IconButton(
                                  iconSize: 64,
                                  icon: const Icon(Icons.forward_10, color: Colors.white),
                                  onPressed: () => controller.timeSkip(10),
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // 倍速バー
                            Row(
                              children: [
                                const Icon(Icons.speed, color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Slider(
                                    value: controller.playbackSpeed,
                                    min: 1.0,
                                    max: 2.0,
                                    divisions: 10,
                                    label: '${controller.playbackSpeed.toStringAsFixed(1)}x',
                                    activeColor: Colors.green,
                                    onChanged: (value) {
                                      controller.setPlaybackSpeed(value);
                                    },
                                  ),
                                ),
                                Text(
                                  '${controller.playbackSpeed.toStringAsFixed(1)}x',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // 左上の戻るボタン
                      Positioned(
                        top: 16,
                        left: 16,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'リストに戻る',
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }
}
