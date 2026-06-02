import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player/controllers/music_player_controller.dart';
import 'package:path/path.dart' as p;
import '../classes/music.dart';
import '../services/audio_file_service.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:diffutil_dart/diffutil.dart' as diffutil;

class MediaPlayerController extends MusicPlayerController {
  @override
  Future<void> loadFiles() async {
    isLoading = true;
    notifyListeners();
    final files = await AudioFileService.loadMusicFiles(
      libraryTypeFilter: LibraryType.media,
    );
    allLoadedFiles = List<MusicFile>.from(files);
    playQueue = files;
    isLoading = false;
    notifyListeners();
  }
}
