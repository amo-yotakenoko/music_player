import 'package:flutter/material.dart';
import 'package:music_player/controllers/music_player_controller.dart';

class MediaProgress extends StatefulWidget {
  const MediaProgress({super.key, required this.controller});
  final MusicPlayerController controller;

  @override
  State<MediaProgress> createState() => _MediaProgressState();
}

class _MediaProgressState extends State<MediaProgress> {
  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 1,

      // color: Colors.red,
      child: ValueListenableBuilder<Duration>(
        // ① 総再生時間の変更を監視
        valueListenable: widget.controller.durationNotifier,
        builder: (context, duration, _) {
          return ValueListenableBuilder<Duration>(
            // ② 現在位置の変更を監視
            valueListenable: widget.controller.positionNotifier,
            builder: (context, position, _) {
              // ③ 位置と時間を元にSliderを構築
              return Slider(
                value: position.inMilliseconds
                    .clamp(0.0, duration.inMilliseconds)
                    .toDouble(),
                max: duration.inMilliseconds.toDouble() > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (value) {
                  widget.controller.seek(Duration(milliseconds: value.toInt()));
                },
              );
            },
          );
        },
      ),
    );
  }
}
