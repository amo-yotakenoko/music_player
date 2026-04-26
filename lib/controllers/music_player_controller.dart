import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../classes/music.dart';
import '../services/audio_file_service.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
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

  void clearFiles() {
    _playQueue.clear();
    notifyListeners();
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

  void SetMusicFiles() async {
    // 1) 現在の再生キューとターゲットのディレクトリ順を比較して差分を計算
    // 2) Insert/Remove/Move に沿って queue を更新する
    // 3) 新規追加が必要な場合、未再生リストから優先的に取得し
    //    それでも足りない場合は既存キューの再利用を行う
    final targetDirs = dirIter().take(100).toList();
    final nowDirs = _playQueue.map((x) => x.directory.split('/').last).toList();
    final updates = diffutil.calculateListDiff(nowDirs, targetDirs);

    print('targetDirs: $targetDirs');
    print('nowDirs: $nowDirs');

    final musicfiles = await AudioFileService.loadMusicFiles();

    musicfiles.shuffle();

    final queue = List<MusicFile>.from(_playQueue);

    for (final update in updates.getUpdates()) {
      if (update is diffutil.Insert) {
        // insert は targetDirs の順序に従って追加する
        for (int i = 0; i < update.count; i++) {
          final dirName = targetDirs[update.position + i];
          final index = musicfiles.indexWhere(
            (x) => x.directory.split('/').last == dirName,
          );

          late final MusicFile newMusicFile;
          if (index != -1) {
            // 未再生リストから取得
            newMusicFile = musicfiles.removeAt(index);
          } else {
            // 未再生リストが足りない場合はすでに使ったものを再利用
            final candidates = queue
                .where((x) => x.directory.split('/').last == dirName)
                .toList();

            if (candidates.isNotEmpty) {
              candidates.shuffle();
              newMusicFile = MusicFile.from(candidates.first);
            } else if (musicfiles.isNotEmpty) {
              // それでも候補がなければ残り未再生リストから補填
              newMusicFile = musicfiles.removeAt(0);
            } else if (_playQueue.isNotEmpty) {
              // それでもダメなら古い再生キューから一つだけ流用
              final fallback = List.of(_playQueue)..shuffle();
              newMusicFile = MusicFile.from(fallback.first);
            } else {
              // 最後は空ファイルでフォールバック
              newMusicFile = MusicFile(File(''));
            }
          }

          queue.insert(update.position + i, newMusicFile);
        }
      } else if (update is diffutil.Remove) {
        // 不要になった項目を削除
        queue.removeRange(update.position, update.position + update.count);
      } else if (update is diffutil.Move) {
        // 順序変更を反映
        final item = queue.removeAt(update.from);
        queue.insert(update.to, item);
      }
    }

    _playQueue = queue;
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
