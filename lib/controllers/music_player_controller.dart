import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../classes/music.dart';
import '../services/audio_file_service.dart';
import '../services/playback_service.dart';
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
  final PlaybackService _playbackService = PlaybackService();
  final SessionType sessionType;

  void Function()? playcallBack;

  // --- 状態（State） ---
  @protected
  List<MusicItem> playQueue = [];
  @protected
  List<MusicItem> allLoadedFiles = [];
  @protected
  bool isLoading = false;

  // --- 外部公開用のゲッター ---
  List<MusicItem> get musicFiles => playQueue;
  List<MusicItem> get allMusicFiles => allLoadedFiles;

  // PlaybackServiceのセッションに委譲
  PlaybackSession get _session => _playbackService.getSession(sessionType);
  MusicItem? get selectedMusic => _session.selectedMusic;
  // 実際にプレイヤーがこのセッションタイプを鳴らしているかどうかで判定
  bool get isPlaying =>
      _session.isPlaying && _playbackService.playingType == sessionType;
  double get playbackSpeed => _session.playbackSpeed;

  // 通知用 (サービスが持っているNotifierを直接返す)
  ValueNotifier<Duration> get positionNotifier => _session.position;
  ValueNotifier<Duration> get durationNotifier => _session.duration;
  Duration get position => _session.position.value;
  Duration get duration => _session.duration.value;

  StreamSubscription? _serviceSub;

  MusicPlayerController({this.sessionType = SessionType.music}) {
    _init();
  }

  void _init() {
    // サービスからの通知（isPlayingの切り替えなど）を全体に通知
    _playbackService.addListener(notifyListeners);

    // 完了イベントは PlaybackService → MusicHandler 経由で受け取る
    if (sessionType == SessionType.music) {
      _playbackService.onMusicNext = playNext;
      _playbackService.onMusicAddRandomNext = _addRandomFromDirBOrC;
    } else {
      _playbackService.onMediaNext = playNext;
      _playbackService.onMediaAddRandomNext = _addRandomFromDirBOrC;
    }
  }

  @override
  void dispose() {
    _playbackService.removeListener(notifyListeners);
    if (sessionType == SessionType.music) {
      _playbackService.onMusicNext = null;
      _playbackService.onMusicAddRandomNext = null;
    } else {
      _playbackService.onMediaNext = null;
      _playbackService.onMediaAddRandomNext = null;
    }
    _serviceSub?.cancel();
    super.dispose();
  }

  // --- 操作（Action） ---

  Future<void> loadFiles() async {
    isLoading = true;
    notifyListeners();
    final files = await AudioFileService.loadMusicFiles(
      libraryTypeFilter: sessionType == SessionType.media
          ? LibraryType.media
          : LibraryType.music,
    );
    allLoadedFiles = List<MusicItem>.from(files);
    playQueue = files;
    isLoading = false;
    notifyListeners();
  }

  void clearFiles() {
    playQueue.clear();
    notifyListeners();
  }

  Future<void> play(MusicItem music) async {
    await _playbackService.play(sessionType, music);
    playcallBack?.call();
  }

  /// 指定した曲をキューの現在の位置に挿入（または移動）して即座に再生する
  Future<void> playNow(MusicItem music) async {
    playQueue.removeWhere((m) => m.path == music.path);

    int insertIdx = 0;
    if (selectedMusic != null) {
      final currentIdx = playQueue.indexWhere((m) => m.id == selectedMusic!.id);
      if (currentIdx != -1) {
        insertIdx = currentIdx;
      }
    }

    final newItem = MusicItem.from(music);
    playQueue.insert(insertIdx, newItem);
    notifyListeners();
    await play(newItem);
  }

  /// 指定した曲をキューの「次」に挿入（または移動）する
  void addNext(MusicItem music) {
    playQueue.removeWhere((m) => m.path == music.path);

    int insertIdx = 0;
    if (selectedMusic != null) {
      final currentIdx = playQueue.indexWhere((m) => m.id == selectedMusic!.id);
      if (currentIdx != -1) {
        insertIdx = currentIdx + 1;
      }
    }

    final newItem = MusicItem.from(music);
    playQueue.insert(insertIdx.clamp(0, playQueue.length), newItem);
    notifyListeners();
  }

  /// 3回押し時に呼ばれる。ディレクトリBまたはCの曲をランダムに1つ選び、
  /// 現在の曲の次に addNext で差し込む。
  void _addRandomFromDirBOrC() {
    final candidates = allLoadedFiles.where((m) {
      final dir = p.basename(m.directory);
      return dir == 'B' || dir == 'C';
    }).toList();
    if (candidates.isEmpty) return;
    final chosen = candidates[Random().nextInt(candidates.length)];
    addNext(chosen);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _playbackService.setSpeed(speed);
    notifyListeners();
  }

  Map<String, ShuffleConfig> shuffleConfig = {
    'A': ShuffleConfig(name: 'A', frequency: 1),
    'B': ShuffleConfig(name: 'B', frequency: 0),
    'C': ShuffleConfig(name: 'C', frequency: 0),
    '配信A': ShuffleConfig(name: '配信A', frequency: 0),
    '配信B': ShuffleConfig(name: '配信B', frequency: 0),
  };

  DateTime? filterDate;
  bool shuffleAll = false;

  void setMusicFiles() async {
    print("再ロード開始");
    isLoading = true;
    notifyListeners();

    try {
      List<MusicItem> musicfiles = await AudioFileService.loadMusicFiles(
        libraryTypeFilter: sessionType == SessionType.media
            ? LibraryType.media
            : LibraryType.music,
      );

      if (musicfiles.isEmpty) {
        isLoading = false;
        notifyListeners();
        return;
      }

      allLoadedFiles = List<MusicItem>.from(musicfiles);

      // 全体を日付順（新しい順）にソートしておく
      musicfiles.sort(
        (a, b) =>
            (b.modified ?? DateTime(0)).compareTo(a.modified ?? DateTime(0)),
      );

      if (filterDate != null) {
        final startOfDay = DateTime(
          filterDate!.year,
          filterDate!.month,
          filterDate!.day,
        );
        musicfiles = musicfiles.where((f) {
          return f.modified != null &&
              (f.modified!.isAfter(startOfDay) ||
                  f.modified!.isAtSameMomentAs(startOfDay));
        }).toList();
      }

      if (musicfiles.isEmpty) {
        isLoading = false;
        notifyListeners();
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
      if (configChanged) notifyListeners();

      final Map<String, List<MusicItem>> dirToFiles = {};
      for (final f in musicfiles) {
        final d = p.basename(f.directory);
        dirToFiles.putIfAbsent(d, () => []).add(f);
      }

      // 各ディレクトリ内でのソート（shuffle設定がある場合のみ）
      for (final entry in dirToFiles.entries) {
        final dirName = entry.key;
        final list = entry.value;
        final config = shuffleConfig[dirName];
        if (config != null && config.shuffle) {
          list.shuffle();
        }
        // shuffleでない場合は、元のソート（日付順）が維持されている
      }

      // フィルタ時は件数を制限し、無駄な重複を避ける
      int targetCount = filterDate != null ? musicfiles.length : 500;

      // 有効な（曲が存在する）ディレクトリのみを抽出
      final activeConfigKeys = shuffleConfig.entries
          .where((e) => e.value.frequency > 0 && dirToFiles.containsKey(e.key))
          .map((e) => e.key)
          .toList();

      if (activeConfigKeys.isEmpty && musicfiles.isNotEmpty) {
        // 設定が全滅している場合は、マッチした全曲をそのまま並べる
        playQueue = List<MusicItem>.from(musicfiles);
        if (shuffleAll) playQueue.shuffle();
        return;
      }

      final targetDirs = dirIterFiltered(
        activeConfigKeys,
      ).take(targetCount).toList();

      List<MusicItem> newQueue;

      if (playQueue.isEmpty) {
        newQueue = [];
        final Map<String, int> dirPoolIndices = {};
        final Set<String> usedPaths = {};

        for (final dirName in targetDirs) {
          final files = dirToFiles[dirName] ?? musicfiles;
          int startIdx = dirPoolIndices[dirName] ?? 0;
          MusicItem? selected;

          for (int i = 0; i < files.length; i++) {
            int currentIdx = (startIdx + i) % files.length;
            if (!usedPaths.contains(files[currentIdx].path)) {
              selected = files[currentIdx];
              dirPoolIndices[dirName] = (currentIdx + 1) % files.length;
              break;
            }
          }
          if (selected == null) {
            selected = files[startIdx % files.length];
            dirPoolIndices[dirName] = (startIdx + 1) % files.length;
          }
          newQueue.add(MusicItem.from(selected));
          usedPaths.add(selected.path);
        }
      } else {
        final nowDirs = playQueue.map((x) => p.basename(x.directory)).toList();
        final diffResult = diffutil.calculateListDiff(nowDirs, targetDirs);
        final updates = diffResult.getUpdatesWithData();

        final queue = List<MusicItem>.from(playQueue);
        final Set<String> usedPathsInQueue = queue.map((m) => m.path).toSet();
        final Map<String, int> dirPoolIndices = {};

        for (final update in updates) {
          if (update is diffutil.DataInsert<String>) {
            final dirName = update.data;
            final files = dirToFiles[dirName] ?? musicfiles;
            MusicItem? selected;
            int startIdx = dirPoolIndices[dirName] ?? 0;
            for (int i = 0; i < files.length; i++) {
              int currentIdx = (startIdx + i) % files.length;
              if (!usedPathsInQueue.contains(files[currentIdx].path)) {
                selected = files[currentIdx];
                dirPoolIndices[dirName] = (currentIdx + 1) % files.length;
                break;
              }
            }
            if (selected == null) {
              selected = files[startIdx % files.length];
              dirPoolIndices[dirName] = (startIdx + 1) % files.length;
            }
            final newItem = MusicItem.from(selected);
            queue.insert(update.position, newItem);
            usedPathsInQueue.add(newItem.path);
          } else if (update is diffutil.DataRemove<String>) {
            if (queue[update.position] == selectedMusic) continue;
            final removed = queue.removeAt(update.position);
            usedPathsInQueue.remove(removed.path);
          } else if (update is diffutil.DataMove<String>) {
            final item = queue.removeAt(update.from);
            queue.insert(update.to, item);
          }
        }
        newQueue = queue;
      }

      playQueue = newQueue;
      if (shuffleAll) playQueue.shuffle();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Iterable<String> dirIterFiltered(List<String> activeKeys) sync* {
    if (activeKeys.isEmpty) return;

    final activeConfigs = activeKeys.map((k) => shuffleConfig[k]!).toList();
    final totalFrequency = activeConfigs.fold<int>(
      0,
      (sum, e) => sum + e.frequency,
    );
    final Map<String, double> counters = {
      for (var e in activeConfigs) e.name: 0.0,
    };
    while (true) {
      for (var entry in activeConfigs) {
        counters[entry.name] =
            counters[entry.name]! + (entry.frequency / totalFrequency);
      }
      String bestName = activeConfigs.first.name;
      double maxVal = -1.0;
      counters.forEach((name, val) {
        if (val > maxVal) {
          maxVal = val;
          bestName = name;
        }
      });
      yield bestName;
      counters[bestName] = counters[bestName]! - 1.0;
    }
  }

  Iterable<String> dirIter() sync* {
    final activeConfigs = shuffleConfig.entries
        .where((e) => e.value.frequency > 0)
        .toList();
    if (activeConfigs.isEmpty) return;
    final totalFrequency = activeConfigs.fold<int>(
      0,
      (sum, e) => sum + e.value.frequency,
    );
    final Map<String, double> counters = {
      for (var e in activeConfigs) e.value.name: 0.0,
    };
    while (true) {
      for (var entry in activeConfigs) {
        counters[entry.value.name] =
            counters[entry.value.name]! +
            (entry.value.frequency / totalFrequency);
      }
      String bestName = activeConfigs.first.value.name;
      double maxVal = -1.0;
      counters.forEach((name, val) {
        if (val > maxVal) {
          maxVal = val;
          bestName = name;
        }
      });
      yield bestName;
      counters[bestName] = counters[bestName]! - 1.0;
    }
  }

  Future<void> togglePlayPause() async {
    await _playbackService.togglePlayPause();
  }

  Future<void> seek(Duration pos) async {
    await _playbackService.seek(pos);
  }

  Future<void> timeSkip(int time) async {
    final targetPosition = _session.position.value + Duration(seconds: time);
    await _playbackService.seek(targetPosition);
  }

  void playNext() {
    if (playQueue.isEmpty || selectedMusic == null) return;
    final index = playQueue.indexWhere((m) => m.id == selectedMusic!.id);
    if (index == -1) return;
    final nextIndex = (index + 1) % playQueue.length;
    play(playQueue[nextIndex]);
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = playQueue.removeAt(oldIndex);
    playQueue.insert(newIndex, item);
    notifyListeners();
  }

  void moveMusicUp(int index) {
    if (index <= 0) return;
    final item = playQueue.removeAt(index);
    playQueue.insert(index - 1, item);
    notifyListeners();
  }

  void moveMusicDown(int index) {
    if (index >= playQueue.length - 1) return;
    final item = playQueue.removeAt(index);
    playQueue.insert(index + 1, item);
    notifyListeners();
  }

  void moveMusicNext(int index) {
    final now = playQueue.indexWhere((m) => m.id == selectedMusic?.id);
    final item = playQueue.removeAt(index);
    playQueue.insert(now + 1, item);
    notifyListeners();
  }

  void removeMusic(MusicItem music) {
    playQueue.removeWhere((m) => m.id == music.id);
    notifyListeners();
  }

  Future<void> deleteMusicFile(BuildContext context, MusicItem music) async {
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
      if (await file.exists()) await file.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${music.title} をストレージから削除しました")),
        );
      }
    }
  }

  // 互換性のためのダミー
  void saveState() {}
  Future<void> restorePlayerState() async {}
}
