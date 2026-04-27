import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import '../classes/music.dart';
import '../services/audio_file_service.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:diffutil_dart/diffutil.dart' as diffutil;

class ShuffleConfig {
  String name;
  int frequency;
  bool shuffle = false;
  ShuffleConfig({
    required this.name,
    required this.frequency,
    this.shuffle = false,
  });

  AudioFileService audioFileService = AudioFileService();

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
  List<MusicFile> get allMusicFiles => _playQueue;
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

  Map<String, ShuffleConfig> shuffleConfig = {
    'A': ShuffleConfig(name: 'A', frequency: 1),
    'B': ShuffleConfig(name: 'B', frequency: 0),
    'C': ShuffleConfig(name: 'C', frequency: 0),
    '配信A': ShuffleConfig(name: '配信A', frequency: 0),
    '配信B': ShuffleConfig(name: '配信B', frequency: 0),
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

  void clearFiles() {
    _playQueue.clear();
    notifyListeners();
  }

  Future<void> addToQueueAndPlay(MusicFile music) async {
    final existingIndex = _playQueue.indexWhere((item) => item.path == music.path);
    final playTarget = existingIndex == -1 ? MusicFile.from(music) : _playQueue[existingIndex];

    if (existingIndex == -1) {
      _playQueue.add(playTarget);
      notifyListeners();
    }

    _selectedMusic = playTarget;
    notifyListeners();
    await play(playTarget);
  }

  Future<void> play(MusicFile music) async {
    _selectedMusic = music;
    notifyListeners();
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(music.path));
    await music.detectVolume();
    print(
      "Applying volume adjustment for ${music.title}: ${music.adjustedVolume}",
    );

    // 3. プレイヤーに適用（1.0を超えないように制限）
    await _audioPlayer.setVolume(music.adjustedVolume);
  }

  void setMusicFiles() async {
    // 1) 端末内の全音楽ファイルをロードし、新しいフォルダがあれば設定に追加
    final musicfiles = await AudioFileService.loadMusicFiles();
    if (musicfiles.isEmpty) {
      print('No music files found.');
      return;
    }

    final allDirs = musicfiles.map((x) => p.basename(x.directory)).toSet();
    bool configChanged = false;
    for (final dir in allDirs) {
      if (!shuffleConfig.containsKey(dir)) {
        shuffleConfig[dir] = ShuffleConfig(name: dir, frequency: 0);
        configChanged = true;
      }
    }
    if (configChanged) {
      notifyListeners();
    }

    // ディレクトリごとにファイルを分類して事前にシャッフル
    final Map<String, List<MusicFile>> dirToFiles = {};
    for (final f in musicfiles) {
      final d = p.basename(f.directory);
      dirToFiles.putIfAbsent(d, () => []).add(f);
    }
    for (final list in dirToFiles.values) {
      list.shuffle();
    }

    // 2) 現在の再生キューとターゲットのディレクトリ順を比較して差分を計算
    final targetDirs = dirIter().take(100).toList();
    final nowDirs = _playQueue.map((x) => p.basename(x.directory)).toList();
    final diffResult = diffutil.calculateListDiff(nowDirs, targetDirs);
    final updates = diffResult.getUpdatesWithData();

    print('Updating queue: target length ${targetDirs.length}, current length ${nowDirs.length}');

    final queue = List<MusicFile>.from(_playQueue);
    
    // 重複回避のためのトラッキング
    final Set<String> usedPathsInQueue = queue.map((m) => m.path).toSet();
    final Map<String, int> dirPoolIndices = {};

    for (final update in updates) {
      if (update is diffutil.DataInsert<String>) {
        final dirName = update.data;
        final files = dirToFiles[dirName] ?? musicfiles;
        
        MusicFile? selected;
        
        // 1. 未使用の曲（パス）を優先的に探す
        int startIdx = dirPoolIndices[dirName] ?? 0;
        for (int i = 0; i < files.length; i++) {
          int currentIdx = (startIdx + i) % files.length;
          final f = files[currentIdx];
          if (!usedPathsInQueue.contains(f.path)) {
            selected = f;
            dirPoolIndices[dirName] = (currentIdx + 1) % files.length;
            break;
          }
        }
        
        // 2. 全て使用済みなら、前後と被らないものを探す
        if (selected == null) {
          for (int i = 0; i < files.length; i++) {
            int currentIdx = (startIdx + i) % files.length;
            final f = files[currentIdx];
            
            final prevPath = update.position > 0 ? queue[update.position - 1].path : null;
            final nextPath = update.position < queue.length ? queue[update.position].path : null;
            
            if (f.path != prevPath && f.path != nextPath) {
              selected = f;
              dirPoolIndices[dirName] = (currentIdx + 1) % files.length;
              break;
            }
          }
        }
        
        // 3. どうしても見つからなければ順番通りに出す
        if (selected == null) {
          int currentIdx = startIdx % files.length;
          selected = files[currentIdx];
          dirPoolIndices[dirName] = (currentIdx + 1) % files.length;
        }

        final newFile = MusicFile.from(selected);
        queue.insert(update.position, newFile);
        usedPathsInQueue.add(newFile.path);

      } else if (update is diffutil.DataRemove<String>) {
        final removed = queue.removeAt(update.position);
        usedPathsInQueue.remove(removed.path);
      } else if (update is diffutil.DataMove<String>) {
        final item = queue.removeAt(update.from);
        queue.insert(update.to, item);
      }
    }

    _playQueue = queue;

    // 検証
    final finalDirs = _playQueue.map((x) => p.basename(x.directory)).toList();
    bool isMatch = finalDirs.length == targetDirs.length;
    if (isMatch) {
      for (int i = 0; i < finalDirs.length; i++) {
        if (finalDirs[i] != targetDirs[i]) {
          isMatch = false;
          break;
        }
      }
    }
    print('Queue sync complete. Match target: $isMatch, Final length: ${finalDirs.length}');

    notifyListeners();
  }

  Iterable<String> dirIter() sync* {
    // 1. 設定から有効な（頻度が1以上の）フォルダだけを抽出
    final activeConfigs = shuffleConfig.entries
        .where((e) => e.value.frequency > 0)
        .toList();

    if (activeConfigs.isEmpty) return;

    // 2. 合計頻度を計算
    final totalFrequency = activeConfigs.fold<int>(
      0,
      (sum, e) => sum + e.value.frequency,
    );

    // 3. 各フォルダの「出番待ち状態」を管理するカウンター（初期値は0）
    final Map<String, double> counters = {
      for (var e in activeConfigs) e.value.name: 0.0,
    };

    while (true) {
      // 4. 全てのフォルダのカウンターに、それぞれの「出現割合」を加算する
      for (var entry in activeConfigs) {
        final name = entry.value.name;
        final freq = entry.value.frequency;
        // 頻度を全体で割った値を足していく（例：Aが3、Cが2なら、Aには0.6、Cには0.4ずつ溜まる）
        counters[name] = counters[name]! + (freq / totalFrequency);
      }

      // 5. カウンターが最大（最も「溜まっている」）フォルダを探す
      String bestName = activeConfigs.first.value.name;
      double maxVal = -1.0;

      counters.forEach((name, val) {
        if (val > maxVal) {
          maxVal = val;
          bestName = name;
        }
      });

      // 6. 選ばれたフォルダ名を出力（yield）
      yield bestName;

      // 7. 出力したフォルダのカウンターを 1 減らす
      counters[bestName] = counters[bestName]! - 1.0;
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
