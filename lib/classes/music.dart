import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:audiotags/audiotags.dart';
import 'package:audiotags/audiotags.dart' as Audiotags;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class MusicFile {
  FileSystemEntity fileEntry;
  final String path;
  String title;
  final String directory;
  String? artist;
  double? meanVolume;
  double? maxVolume;

  double get adjustedVolume {
    if (meanVolume == null) return 0.0;
    // 例: -14dBを基準にして、そこからの差分をボリューム調整に反映
    double adjustment = -14.0 - meanVolume!;
    // 調整値を適用（例: 1dBの差で10%の音量変化とする）
    return (adjustment / 10).clamp(-1.0, 1.0);
  }

  final Key key;

  // 初期化リスト（コロンの後ろで代入する）
  MusicFile(FileSystemEntity file)
    : fileEntry = file,
      path = file.path,
      title = p.basename(file.path),
      directory = p.dirname(file.path),
      key = UniqueKey();

  MusicFile.from(MusicFile other)
    : fileEntry = other.fileEntry,
      path = other.path,
      title = other.title,
      directory = other.directory,
      key = UniqueKey(),
      artist = other.artist,
      meanVolume = other.meanVolume,
      maxVolume = other.maxVolume;

  Future<void> loadTags() async {
    try {
      final tags = await AudioTags.read(path);
      if (tags != null) {
        artist = tags.trackArtist ?? tags.albumArtist ?? "Unknown Artist";
      }
    } catch (e) {
      debugPrint('タグの読み込みに失敗しました: $e');
    }
  }

  /// FFmpegのvolumedetectフィルターを使用して音量を検出する
  Future<void> detectVolume() async {
    try {
      // -vn: 映像なし, -sn: 字幕なし, -dn: データなし
      final session = await FFmpegKit.execute(
        '-i "$path" -af volumedetect -vn -sn -dn -f null -',
      );
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getLogs();
        for (final log in logs) {
          final message = log.getMessage();
          if (message.contains('mean_volume:')) {
            final match = RegExp(
              r'mean_volume:\s+(-?\d+\.?\d*)\s+dB',
            ).firstMatch(message);
            if (match != null) {
              meanVolume = double.tryParse(match.group(1)!);
            }
          }
          if (message.contains('max_volume:')) {
            final match = RegExp(
              r'max_volume:\s+(-?\d+\.?\d*)\s+dB',
            ).firstMatch(message);
            if (match != null) {
              maxVolume = double.tryParse(match.group(1)!);
            }
          }
        }
        print('音量検出完了 ($title): mean: $meanVolume dB, max: $maxVolume dB');
      } else {
        print('音量検出に失敗しました ($title): ${await session.getFailStackTrace()}');
      }
    } catch (e) {
      print('音量検出中にエラーが発生しました: $e');
    }
  }

  @override
  String toString() {
    // メンバ変数を分かりやすく整形
    return 'MusicFile(title: $title, directory: $directory, meanVolume: $meanVolume)';
  }
}
