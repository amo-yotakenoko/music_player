import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import 'search_music_screen.dart';

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
          icon: const Icon(Icons.search),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SearchMusicScreen(controller: widget.controller),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            widget.controller.clearFiles();
            widget.controller.setMusicFiles();
          },
        ),
        IconButton(
          icon: const Icon(Icons.source),
          onPressed: () {
            _openModal(context, widget.controller);
          },
        ),
      ],
    );
  }

  void _openModal(BuildContext context, MusicPlayerController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('開始日フィルタ'),
                      subtitle: Text(
                          controller.filterDate?.toString().split(' ')[0] ??
                              'なし (全件)'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: controller.filterDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() {
                            controller.filterDate = picked;
                          });
                        }
                      },
                      onLongPress: () {
                        setModalState(() {
                          controller.filterDate = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('フィルタを解除しました')),
                        );
                      },
                    ),
                    const Divider(),
                    for (var item in controller.shuffleConfig.entries)
                      item.value.buildSpinBoxRow(() => setModalState(() {})),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        print("押された");
                        controller.setMusicFiles();
                        Navigator.pop(context);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
