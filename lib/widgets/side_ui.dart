import 'package:flutter/material.dart';

class SideUI extends StatelessWidget {
  const SideUI({super.key});

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 1, // 1回で時計回りに90度、2回で180度、3回で270度（反時計回り90度）
      child: Container(
        // 渡すときは「=」ではなく「:」を使います
        color: Colors.grey[200],
        child: const Center(
          child: Text(
            'サイドUI（設定やプレイリストなど）',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
