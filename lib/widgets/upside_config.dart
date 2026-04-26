import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';

class ConfigSetter extends StatefulWidget implements PreferredSizeWidget {
  const ConfigSetter({super.key, required this.controller});

  final MusicPlayerController controller;

  // AppBarの高さを指定するためにPreferredSizeWidgetが必要らしい
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<ConfigSetter> createState() => _ConfigSetterState();
}

class _ConfigSetterState extends State<ConfigSetter> {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Android Music List'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: widget.controller.loadFiles,
        ),
        IconButton(
          icon: const Icon(Icons.source),
          onPressed: () {
            _openModal(context);
          },
        ),
      ],
    );
  }

  void _openModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(children: [const Text('外部のボタンから呼ばれました！')]),
        );
        // Container(
        //   padding: const EdgeInsets.all(20),
        //   children: [const Text('外部のボタンから呼ばれました！')],
        // );
      },
    );
  }
}
