import 'dart:io';
import 'package:flutter/material.dart';
import '../services/audio_file_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/music_tile.dart';

/// 【表示・管理層（メイン画面）】
/// アプリ全体の「状態（State）」を保持し、UIに反映させる役割。
class MusicListScreen extends StatefulWidget {
  const MusicListScreen({super.key});

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {
  // --- 状態管理（State） ---
  // 1. 音楽ファイルのリスト（並び替え可能なデータ本体）
  List<FileSystemEntity> _musicFiles = [];
  // 2. 読み込み中かどうか（UIの切り替えに使用）
  bool _isLoading = true;
  // 3. 現在選択されている曲名（nullの場合はプレイヤーを非表示）
  String? _selectedSongName;
  // 4. 再生中かどうか（プレイヤーのアイコン切り替えに使用）
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadMusicFiles();
  }

  /// サービスを利用してデータを取得し、自身の状態（State）を更新する
  Future<void> _loadMusicFiles() async {
    setState(() {
      _isLoading = true;
    });

    final files = await AudioFileService.loadMusicFiles();

    setState(() {
      _musicFiles = files;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android Music List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMusicFiles,
          ),
        ],
      ),
      // メインコンテンツ（リスト表示）
      body: _buildBody(),
      // 画面下部に常駐するプレイヤーウィジェット
      // 自身のState（曲名、再生状態）を引数として渡している
      bottomNavigationBar: MiniPlayer(
        songName: _selectedSongName,
        isPlaying: _isPlaying,
        onPlayPause: () {
          // 子ウィジェットからの通知を受けて自身の状態を更新
          setState(() {
            _isPlaying = !_isPlaying;
          });
        },
      ),
    );
  }

  /// 読み込み状態に応じて表示を切り替える
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_musicFiles.isEmpty) {
      return _buildEmptyView();
    }

    return _buildMusicList();
  }

  /// データがない時のUI
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('音楽ファイルが見つかりませんでした'),
          const SizedBox(height: 10),
          Text(
            'Androidの /Music フォルダに\nファイルを置いてください',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          ElevatedButton(
            onPressed: _loadMusicFiles,
            child: const Text('再読み込み'),
          ),
        ],
      ),
    );
  }

  /// リスト表示のUI（並び替え機能付き）
  Widget _buildMusicList() {
    return ReorderableListView.builder(
      itemCount: _musicFiles.length,
      onReorder: (int oldIndex, int newIndex) {
        // 並び替えが発生した時にリストの状態を更新
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _musicFiles.removeAt(oldIndex);
          _musicFiles.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final file = _musicFiles[index];
        final fileName = file.path.split('/').last;

        return MusicTile(
          key: ValueKey(file.path),
          fileName: fileName,
          filePath: file.path,
          isPlaying: _selectedSongName == fileName,
          onTap: () {
            // 曲を選択した時に状態を更新
            setState(() {
              _selectedSongName = fileName;
              _isPlaying = true;
            });
            print('Selected song: $fileName');
          },
        );
      },
    );
  }
}
