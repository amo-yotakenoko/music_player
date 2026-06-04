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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        return AppBar(
          title: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: widget.controller.playbackSpeed,
                  min: 1.0,
                  max: 2.0,
                  divisions: 10,
                  label:
                      '${widget.controller.playbackSpeed.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    widget.controller.setPlaybackSpeed(value);
                  },
                ),
              ),
              Text(
                '${widget.controller.playbackSpeed.toStringAsFixed(1)}x',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
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
                // 明示的にクリアしてからセットすることで、diffutilに頼らず作り直す
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
      },
    );
  }

  void _openModal(BuildContext context, MusicPlayerController controller) {
    final initialDate = controller.filterDate;
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
                      subtitle: Row(
                        children: [
                          Text(
                            controller.filterDate != null
                                ? controller.filterDate.toString().split(' ')[0]
                                : '未設定',
                          ),
                          if (controller.filterDate != null) ...[
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                print("解除");
                                controller.filterDate = null;
                                setModalState(() {});
                              },
                              child: const Text('解除'),
                            ),
                          ],
                        ],
                      ),
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
                    // for (var item in controller.shuffleConfig.entries)
                    //   item.value.buildSpinBoxRow(() => setModalState(() {})),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        print("押された");
                        if (controller.filterDate != initialDate) {
                          print("フィルタ変更あり: 初期化して再読み込み");
                          controller.clearFiles();
                        }
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
