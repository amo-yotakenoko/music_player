import 'package:flutter/material.dart';
import './side_ui_mix_custum.dart';

class SideUI extends StatelessWidget {
  const SideUI({super.key});

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 1, // 1回で時計回りに90度、2回で180度、3回で270度（反時計回り90度）
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [SideMixCustom(), SizedBox(width: 16), SideMixCustom()],
      ),
    );
  }
}
