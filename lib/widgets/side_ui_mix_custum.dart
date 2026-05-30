import 'package:flutter/material.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';

class SideMixCustom extends StatelessWidget {
  const SideMixCustom({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("A"),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: SpinBox(
            min: 0,
            max: 5,
            value: 1,
            onChanged: (value) {
              debugPrint("SpinBox value changed: $value");
            },
          ),
        ),
      ],
    );
  }
}
