import 'dart:async';
import 'package:music_player/controllers/music_player_controller.dart';
import '../services/playback_service.dart';

class MediaPlayerController extends MusicPlayerController {
  MediaPlayerController() : super(sessionType: SessionType.media);
}
