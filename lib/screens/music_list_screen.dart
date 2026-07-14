import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import '../widgets/mini_player.dart';
import '../widgets/music_list_body.dart';
import '../widgets/upside_config.dart';
import '../widgets/side_ui.dart';
import '../controllers/media_player_controller.dart';
import '../services/playback_service.dart';

/// 【表示層（メイン画面）】
/// 画面の全体構造（Scaffold）のみを定義し、具体的な中身やロジックは他に任せる。
class MusicListScreen extends StatefulWidget {
  const MusicListScreen({super.key});

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {
  // ロジックと状態を持つコントローラー
  late final MusicPlayerController _musicController;
  late final MediaPlayerController _mediaController;
  late final PageController _pageController;
  final PlaybackService _playbackService = PlaybackService();

  @override
  void initState() {
    super.initState();
    _musicController = MusicPlayerController(sessionType: SessionType.music);
    _mediaController = MediaPlayerController();
    _pageController = PageController(initialPage: 0);

    // 初期データの読み込み
    _musicController.loadFiles();
    _mediaController.loadFiles();
  }

  @override
  void dispose() {
    _musicController.dispose();
    _mediaController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int currentPage = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ConfigSetter(
        controller: currentPage == 0 ? _musicController : _mediaController,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            currentPage = index;
          });

          // サービスにセッションの切り替えを通知
          // 司令塔（Service）が、切り替え先を再生すべきかどうかを判断する
          final newType = index == 0 ? SessionType.music : SessionType.media;
          _playbackService.switchSession(newType);
        },
        children: [
          Row(
            children: [
              Expanded(flex: 1, child: SideUI(controller: _musicController)),
              Expanded(
                flex: 9,
                child: MusicListBody(
                  controller: _musicController,
                  isActive: currentPage == 0,
                ),
              ),
            ],
          ),

          Row(
            children: [
              // Expanded(
              //   flex: 1,
              //   child: MediaProgress(controller: _mediaController),
              // ),
              Expanded(
                flex: 10,
                child: MusicListBody(
                  controller: _mediaController,
                  isActive: currentPage == 1,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _playbackService,
        builder: (context, _) {
          // 実際に音が鳴っている方があればそれを優先表示し、
          // 鳴っていない（停止中）なら今見ている画面のコントローラを表示する
          final controllerToShow = (_playbackService.playingSession.isPlaying)
              ? (_playbackService.playingType == SessionType.music
                    ? _musicController
                    : _mediaController)
              : (_playbackService.activeType == SessionType.music
                    ? _musicController
                    : _mediaController);

          return MiniPlayer(controller: controllerToShow);
        },
      ),
    );
  }
}
