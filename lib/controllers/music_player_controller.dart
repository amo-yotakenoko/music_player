import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../classes/music.dart';
import '../services/audio_file_service.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:path/path.dart' as p;
import 'package:diffutil_dart/diffutil.dart' as diffutil;

class ShuffleCoonfig {
  String name;
  int frequency;
  bool shuffle = false;
  ShuffleCoonfig({
    required this.name,
    required this.frequency,
    this.shuffle = false,
  });

  Widget buildSpinBoxRow(VoidCallback onUpdate) {
    return Row(
      children: [
        Text(name),
        const SizedBox(width: 20),
        Expanded(
          child: SpinBox(
            min: 0,
            max: 5,
            value: frequency.toDouble(),
            onChanged: (value) {
              frequency = value.toInt();
              onUpdate();
            },
          ),
        ),
        const SizedBox(width: 20),
        // shuffle用
        Switch(
          value: shuffle,
          onChanged: (value) {
            shuffle = value;
            onUpdate();
          },
        ),
      ],
    );
  }
}

/// 【ロジック・状態管理層】
class MusicPlayerController extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- 状態（State） ---
  List<MusicFile> _playQueue = [];
  bool _isLoading = false;
  MusicFile? _selectedMusic;
  bool _isPlaying = false;
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);

  // --- 外部公開用のゲッター ---
  List<MusicFile> get musicFiles => _playQueue;
  bool get isLoading => _isLoading;
  MusicFile? get selectedMusic => _selectedMusic;
  bool get isPlaying => _isPlaying;
  ValueNotifier<Duration> get positionNotifier => _position;
  ValueNotifier<Duration> get durationNotifier => _duration;
  Duration get position => _position.value;
  Duration get duration => _duration.value;

  // イベント購読用
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _compSub;

  Map<String, ShuffleCoonfig> shuffleConfig = {
    'A': ShuffleCoonfig(name: 'A', frequency: 1),
    'B': ShuffleCoonfig(name: 'B', frequency: 0),
    'C': ShuffleCoonfig(name: 'C', frequency: 0),
    '配信': ShuffleCoonfig(name: '配信', frequency: 0),
  };

  MusicPlayerController() {
    _init();
  }

  void _init() {
    _posSub = _audioPlayer.onPositionChanged.listen((p) {
      _position.value = p;
    });
    _durSub = _audioPlayer.onDurationChanged.listen((d) {
      _duration.value = d;
    });
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    _compSub = _audioPlayer.onPlayerComplete.listen((_) => playNext());
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _compSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- 操作（Action） ---

  Future<void> loadFiles() async {
    _isLoading = true;
    notifyListeners();
    _playQueue = await AudioFileService.loadMusicFiles();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> play(MusicFile music) async {
    _selectedMusic = music;
    notifyListeners();
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(music.path));
  }

  void SetMusicFiles() async {
    // print(_musicFiles);
    // if (_selectedMusic == null) return;
    final now = _selectedMusic == null
        ? 0
        : _playQueue.indexOf(_selectedMusic!);

    // final activeDirNames = shuffleConfig.values
    //     .where((x) => x.frequency > 0)
    //     .map((x) => x.name)
    //     .toList();
    // print(activeDirNames);
    final targetDirs = dirIter().take(10).toList();
    print(targetDirs);

    final nowDirs = _playQueue.map((x) => x.directory.split('/').last).toList();
    print(nowDirs);

    diffutil.DiffResult<String> updates = diffutil.calculateListDiff(
      nowDirs,
      targetDirs,
    );
    // print(updates);
    List<MusicFile> musicfiles = await AudioFileService.loadMusicFiles();
    musicfiles.shuffle();

    for (final update in updates.getUpdates()) {
      if (update is diffutil.Insert) {
        // 挿入処理
        // update.position: 挿入位置
        // update.count: 挿入する個数
        print('${update.position}番目に${update.count}個追加します');

        // 例: 新しいリストから該当範囲を抜き出して挿入

        for (int i = 0; i < update.count; i++) {
          // 1. 追加すべきディレクトリ名を取得
          final dirName = targetDirs[update.position + i];

          // 2. その名前から MusicFile オブジェクト（仮）を生成
          final index = musicfiles.indexWhere(
            (x) => x.directory.split('/').last == dirName,
          );
          MusicFile newMusicFile;
          if (index != -1) {
            // 2. 見つかった場合、その番地を指定して削除＆取得
            newMusicFile = musicfiles.removeAt(index);
            musicfiles.add(newMusicFile);

            print('削除して取得完了: ${newMusicFile.path}');
          } else {
            print("未再生の物がないので前から持って来る");
            newMusicFile = _playQueue.firstWhere(
              (x) => x.directory.split('/').last == dirName,
              orElse: () => MusicFile(File('')),
            );
          }

          // 3. 実際のリストに挿入
          _playQueue.insert(update.position + i, newMusicFile);
        }

        // _yourList.insertAll(update.position, itemsToAdd);
      } else if (update is diffutil.Remove) {
        // 削除処理
        // update.position: 削除開始位置
        // update.count: 削除する個数
        print('${update.position}番目から${update.count}個削除します');
        _playQueue.removeRange(update.position, update.position + update.count);
        // _yourList.removeRange(update.position, update.position + update.count);
      } else if (update is diffutil.Move) {
        // 移動処理
        print('${update.from}番目を${update.to}番目へ移動します');
        _playQueue.insert(update.to, _playQueue.removeAt(update.from));
      }
    }

    notifyListeners();
  }

  Iterable<String> dirIter() sync* {
    while (true) {
      for (var entry in shuffleConfig.entries) {
        for (int i = 0; i < entry.value.frequency; i++) {
          yield entry.value.name;
        }
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  Future<void> seek(Duration pos) async {
    await _audioPlayer.seek(pos);
  }

  Future<void> skipSeconds(int seconds) async {
    final currentPos = await _audioPlayer.getCurrentPosition();
    if (currentPos == null) return;
    final newPos = currentPos + Duration(seconds: seconds);
    await _audioPlayer.seek(newPos);
  }

  Future<void> timeSkip(int time) async {
    final currentPosition =
        await _audioPlayer.getCurrentPosition() ?? Duration.zero;
    final targetPosition = currentPosition + Duration(seconds: time);
    await _audioPlayer.seek(targetPosition);
  }

  void playNext() {
    if (_playQueue.isEmpty || _selectedMusic == null) return;
    final index = _playQueue.indexOf(_selectedMusic!);
    final nextIndex = (index + 1) % _playQueue.length;
    play(_playQueue[nextIndex]);
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _playQueue.removeAt(oldIndex);
    _playQueue.insert(newIndex, item);
    notifyListeners();
  }

  void moveMusicUp(int index) {
    if (index <= 0) return;
    final item = _playQueue.removeAt(index);
    _playQueue.insert(index - 1, item);
    notifyListeners();
  }

  void moveMusicDown(int index) {
    if (index >= _playQueue.length - 1) return;
    final item = _playQueue.removeAt(index);
    _playQueue.insert(index + 1, item);
    notifyListeners();
  }

  void moveMusicNext(int index) {
    final now = _playQueue.indexOf(_selectedMusic!);
    final item = _playQueue.removeAt(index);
    _playQueue.insert(now + 1, item);
    notifyListeners();
  }

  void removeMusic(MusicFile music) {
    _playQueue.remove(music);
    notifyListeners();
  }

  Future<void> deleteMusicFile(BuildContext context, MusicFile music) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ファイルの削除'),
        content: Text('${music.title} をストレージから完全に削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      removeMusic(music);
      final file = File(music.path);
      if (await file.exists()) {
        await file.delete();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${music.title} をストレージから削除しました")),
        );
      }
    }
  }
}
