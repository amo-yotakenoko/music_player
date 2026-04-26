import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../classes/music.dart';
import '../services/audio_file_service.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';

class ShuffleCoonfig {
  String name;
  int frequency;
  bool shuffle;
  ShuffleCoonfig({
    required this.name,
    required this.frequency,
    required this.shuffle,
  });

  Widget buildSpinBoxRow() {
    return Row(
      children: [
        Text(name),
        const SizedBox(width: 20),
        Expanded(
          child: SpinBox(
            min: 0,
            max: 5,
            value: frequency.toDouble(),
            onChanged: (value) => frequency = value.toInt(),
          ),
        ),
      ],
    );
  }
}

/// 【ロジック・状態管理層】
/// 再生に関する状態（State）と操作（Method）を一括管理するクラス。
/// ChangeNotifierを継承することで、状態が変わった時にUIに通知できる。
class MusicPlayerController extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- 状態（State） ---
  List<MusicFile> _musicFiles = [];
  bool _isLoading = false;
  MusicFile? _selectedMusic;
  bool _isPlaying = false;
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);

  // --- 外部公開用のゲッター ---
  List<MusicFile> get musicFiles => _musicFiles;
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
    'A': ShuffleCoonfig(name: 'A', frequency: 1, shuffle: true),
    'B': ShuffleCoonfig(name: 'B', frequency: 0, shuffle: false),
    '配信': ShuffleCoonfig(name: '配信', frequency: 0, shuffle: false),
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

  /// ファイルを読み込む
  Future<void> loadFiles() async {
    _isLoading = true;
    notifyListeners();
    _musicFiles = await AudioFileService.loadMusicFiles();
    _isLoading = false;
    notifyListeners();
  }

  /// 指定した曲を再生する
  Future<void> play(MusicFile music) async {
    _selectedMusic = music;
    notifyListeners();
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(music.path));
  }

  /// 再生・一時停止の切り替え
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  /// シーク操作
  Future<void> seek(Duration pos) async {
    await _audioPlayer.seek(pos);
  }

  /// 指定した秒数だけスキップする（正の値で進む、負の値で戻る）
  Future<void> skipSeconds(int seconds) async {
    final currentPos = await _audioPlayer.getCurrentPosition();
    if (currentPos == null) return;
    final newPos = currentPos + Duration(seconds: seconds);
    await _audioPlayer.seek(newPos);
  }

  /// 次の曲へ

  Future<void> timeSkip(int time) async {
    // 現在の再生位置を取得

    final currentPosition =
        await _audioPlayer.getCurrentPosition() ?? Duration.zero;
    // 指定された時間加算
    final targetPosition = currentPosition + Duration(seconds: time);
    await _audioPlayer.seek(targetPosition);
  }

  /// 次の曲へ
  void playNext() {
    if (_musicFiles.isEmpty || _selectedMusic == null) return;
    final index = _musicFiles.indexOf(_selectedMusic!);
    final nextIndex = (index + 1) % _musicFiles.length;
    play(_musicFiles[nextIndex]);
  }

  /// リストの並び替え
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _musicFiles.removeAt(oldIndex);
    _musicFiles.insert(newIndex, item);
    notifyListeners();
  }

  /// 1つ上に移動
  void moveMusicUp(int index) {
    if (index <= 0) return;
    final item = _musicFiles.removeAt(index);
    _musicFiles.insert(index - 1, item);
    notifyListeners();
  }

  /// 1つ下に移動
  void moveMusicDown(int index) {
    if (index >= _musicFiles.length - 1) return;
    final item = _musicFiles.removeAt(index);
    _musicFiles.insert(index + 1, item);
    notifyListeners();
  }

  /// 次の再生に移動
  void moveMusicNext(int index) {
    final now = _musicFiles.indexOf(_selectedMusic!);
    final item = _musicFiles.removeAt(index);
    _musicFiles.insert(now + 1, item);
    notifyListeners();
  }

  void removeMusic(MusicFile music) {
    musicFiles.remove(music);
    notifyListeners(); // リストの変更を通知
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
