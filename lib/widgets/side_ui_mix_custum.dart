import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';

class SideMixCustom extends StatelessWidget {
  const SideMixCustom({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final ShuffleConfig config;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // フォルダ名
        SizedBox(
          // width: 35,
          child: Text(
            config.name,
            // style: const TextStyle(, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // カスタムSpinBox部分（枠なしシンプル版）
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // マイナスボタン
            _buildStepperButton(
              icon: Icons.remove,
              onPressed: config.frequency > 0
                  ? () {
                      config.frequency--;
                      onChanged();
                    }
                  : null,
            ),

            // 数字表示
            SizedBox(
              width: 20, // 枠がないので幅を少し詰めました
              child: Center(
                child: Text(
                  '${config.frequency}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // プラスボタン
            _buildStepperButton(
              icon: Icons.add,
              onPressed: config.frequency < 5
                  ? () {
                      config.frequency++;
                      onChanged();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20), // タップ時の波紋を円形に
      child: Padding(
        padding: const EdgeInsets.all(6), // シンプルなので余白を均等に
        child: Icon(
          icon,
          size: 16,
          color: onPressed == null ? Colors.grey.shade300 : Colors.blue,
        ),
      ),
    );
  }
}
