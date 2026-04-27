import 'package:flutter/material.dart';
import '../classes/music.dart';
import '../controllers/music_player_controller.dart';
import 'music_tile.dart';

class SearchMusicScreen extends StatefulWidget {
  const SearchMusicScreen({super.key, required this.controller});

  final MusicPlayerController controller;

  @override
  State<SearchMusicScreen> createState() => _SearchMusicScreenState();
}

class _SearchMusicScreenState extends State<SearchMusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MusicFile> _filteredMusic() {
    final rawQuery = _query.trim();
    if (rawQuery.isEmpty) {
      return widget.controller.allMusicFiles;
    }

    final query = _normalizePathSeparators(rawQuery.toLowerCase());

    return widget.controller.allMusicFiles.where((music) {
      final title = music.title.toLowerCase();
      final artist = music.artist?.toLowerCase() ?? '';
      final directory = _normalizePathSeparators(music.directory.toLowerCase());
      final path = _normalizePathSeparators(music.path.toLowerCase());
      return title.contains(query) ||
          artist.contains(query) ||
          directory.contains(query) ||
          path.contains(query);
    }).toList();
  }

  String _normalizePathSeparators(String value) {
    return value.replaceAll('\\', '/');
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredMusic();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '全曲検索',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() {
            _query = value;
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _query = '';
              });
            },
          ),
        ],
      ),
      body: results.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _query.isEmpty
                        ? '音楽ファイルが見つかりませんでした'
                        : '検索に一致する曲がありませんでした',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                      });
                    },
                    child: const Text('検索をクリア'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final music = results[index];
                return MusicTile(
                  key: music.key,
                  music: music,
                  onTap: () async {
                    await widget.controller.addToQueueAndPlay(music);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  onMenuPressed: () {},
                  onMoveUp: null,
                  onMoveDown: null,
                  isPlaying: widget.controller.selectedMusic?.path == music.path &&
                      widget.controller.isPlaying,
                );
              },
            ),
    );
  }
}
