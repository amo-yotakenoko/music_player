import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../classes/music.dart';
import '../services/audio_file_service.dart';

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

  void removeMusic(MusicFile music) {
    musicFiles.remove(music);
    notifyListeners(); // リストの変更を通知
  }
}
