import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:audiotags/audiotags.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_background/just_audio_background.dart';

class MusicFile {
  FileSystemEntity fileEntry;
  final String path;
  String title;
  final String directory;
  String? artist;
  double? integratedLoudness;
  double? truePeak;
  DateTime? modified;

  double get adjustedVolume {
    if (integratedLoudness == null) return 1.0;
    // ターゲットを -14.0 LUFS とする
    const double targetLoudness = -14.0;
    // 必要なゲイン（dB）を計算
    double gainDb = targetLoudness - integratedLoudness!;

    // デシベルからリニアスケールへの変換: 10^(db/20)
    double linearGain = math.pow(10, gainDb / 20).toDouble();

    // 基準音量を 0.8 とし、そこから調整。1.0を超えないようにする。
    return (0.8 * linearGain).clamp(0.0, 1.0);
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
      integratedLoudness = other.integratedLoudness,
      truePeak = other.truePeak;

  MediaItem toMediaItem() {
    return MediaItem(
      id: path,
      album: p.basename(directory),
      title: title,
      artist: artist ?? "Unknown Artist",
    );
  }

  Future<void> loadTags() async {
    try {
      final tags = await AudioTags.read(path);
      if (tags != null) {
        artist = tags.trackArtist ?? tags.albumArtist ?? "Unknown Artist";
      }
    } catch (e) {
      debugPrint(' $path');
      debugPrint('タグの読み込みに失敗しました: $e');
      artist = "Unknown Artist";
    }
  }

  /// キャッシュから音量データを読み込む（FFmpegは実行しない）
  Future<void> loadVolumeFromCache() async {
    if (integratedLoudness != null) return;
    final prefs = await SharedPreferences.getInstance();
    double? storedVolume = prefs.getDouble('${title}_lufs');
    if (storedVolume != null) {
      integratedLoudness = storedVolume;
    }
  }

  /// FFmpegのloudnormフィルターを使用して音量を検出する
  Future<void> detectVolume() async {
    if (integratedLoudness != null) {
      print("既に音量が検出されているためスキップ: $title -> $integratedLoudness LUFS");
      return;
    }

    await loadVolumeFromCache();
    if (integratedLoudness != null) {
      print("保存済みデータから読み込み: $title -> $integratedLoudness LUFS");
      return;
    }

    try {
      // loudnormフィルターを使用して計測。print_format=json で詳細情報を取得
      final session = await FFmpegKit.execute(
        '-i "$path" -af loudnorm=print_format=json -vn -sn -dn -f null -',
      );
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getLogs();
        String fullLog = logs.map((l) => l.getMessage()).join();

        // JSON部分を抽出
        final matches = RegExp(r'\{[\s\S]*?\}').allMatches(fullLog);
        final jsonMatch = matches.isNotEmpty ? matches.last : null;
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          // 正規表現で値を抽出
          final iMatch = RegExp(
            r'"input_i"\s*:\s*"(-?\d+\.?\d*)"',
          ).firstMatch(jsonStr);
          final tpMatch = RegExp(
            r'"input_tp"\s*:\s*"(-?\d+\.?\d*)"',
          ).firstMatch(jsonStr);

          if (iMatch != null) {
            integratedLoudness = double.tryParse(iMatch.group(1)!);
          }
          if (tpMatch != null) {
            truePeak = double.tryParse(tpMatch.group(1)!);
          }
        }

        print('音量検出完了 ($title): I: $integratedLoudness LUFS, TP: $truePeak dB');
        if (integratedLoudness != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('${title}_lufs', integratedLoudness!);
        }
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
    return 'MusicFile(title: $title, directory: $directory, integratedLoudness: $integratedLoudness)';
  }
}
