import 'package:flutter/material.dart';
import 'package:music_player/screens/media_screen.dart';
import '../controllers/music_player_controller.dart';
import './side_ui_mix_custum.dart';

class SideUI extends StatelessWidget {
  const SideUI({super.key, required this.controller});

  final MusicPlayerController controller;

  void mix_update() {
    print("更新");
    controller.setMusicFiles();
  }

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var entry in controller.shuffleConfig.entries.where(
              (entry) => !entry.value.name.contains("配信"),
            )) ...[
              SideMixCustom(config: entry.value, onChanged: mix_update),
              const SizedBox(
                height: 24, // 区切り線の長さ
                child: VerticalDivider(
                  color: Colors.grey, // 線の色
                  thickness: 1, // 線の太さ
                  width: 20, // 左右の余白（スペース）の合計
                ),
              ),
            ],
            ElevatedButton(
              onPressed: () {
                print("押された");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MediaScreen()),
                );
              },
              child: Text("配信"),
            ),
          ],
        ),
      ),
    );
  }
}
