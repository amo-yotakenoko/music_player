import 'package:flutter/material.dart';
import '../classes/music.dart';
import '../controllers/music_player_controller.dart';
import '../services/audio_file_service.dart';
import 'package:path/path.dart' as p;

class SearchMusicScreen extends StatefulWidget {
  const SearchMusicScreen({super.key, required this.controller});

  final MusicPlayerController controller;

  @override
  State<SearchMusicScreen> createState() => _SearchMusicScreenState();
}

class _SearchMusicScreenState extends State<SearchMusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<MusicItem> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _onSearchChanged('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String value) async {
    setState(() {
      _query = value;
      _isLoading = true;
    });

    try {
      final allFiles = await AudioFileService.loadMusicFiles();

      final rawQuery = value.trim();
      if (rawQuery.isEmpty) {
        if (mounted) {
          setState(() {
            _results = allFiles;
            _isLoading = false;
          });
        }
        return;
      }

      final query = _normalizePathSeparators(rawQuery.toLowerCase());
      final filtered = allFiles.where((music) {
        final title = music.title.toLowerCase();
        final artist = music.artist?.toLowerCase() ?? '';
        final directory = _normalizePathSeparators(music.directory.toLowerCase());
        final path = _normalizePathSeparators(music.path.toLowerCase());
        return title.contains(query) ||
            artist.contains(query) ||
            directory.contains(query) ||
            path.contains(query);
      }).toList();

      if (mounted) {
        setState(() {
          _results = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _normalizePathSeparators(String value) {
    return value.replaceAll('\\', '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '全曲検索（リアルタイム）',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          ),
        ],
      ),
      body: _results.isEmpty && !_isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _query.isEmpty ? '音楽ファイルが見つかりませんでした' : '検索に一致する曲がありませんでした',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    child: const Text('検索をクリア'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final music = _results[index];
                return _SearchResultTile(
                  music: music,
                  controller: widget.controller,
                );
              },
            ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final MusicItem music;
  final MusicPlayerController controller;

  const _SearchResultTile({
    required this.music,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final dirName = p.basename(music.directory);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            dirName,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      title: Text(
        music.title,
        style: const TextStyle(fontSize: 14, overflow: TextOverflow.ellipsis),
      ),
      subtitle: Text(
        music.artist ?? "Unknown Artist",
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: '今すぐ再生',
            onPressed: () async {
              await controller.playNow(music);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: '次に再生',
            onPressed: () {
              controller.addNext(music);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('次に再生する曲に追加しました')),
              );
            },
          ),
        ],
      ),
    );
  }
}
