import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 【データ取得層】
/// 端末内のファイルシステムにアクセスし、音楽ファイルの情報を取得する役割。
/// このクラス自体は状態を保持せず、呼び出し元にデータを渡すだけの「静的サービス」として機能。
class AudioFileService {
  /// ストレージアクセスの権限を確認・要求する (Android用)
  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
      return true;
    }

    // 両方試みる
    await Permission.storage.request();
    final status = await Permission.audio.request();
    
    return status.isGranted;
  }

  /// 音楽ファイルのリストを取得する
  /// 返り値: 取得したファイルエンティティのリスト
  static Future<List<FileSystemEntity>> loadMusicFiles() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        debugPrint('ストレージの権限が拒否されました');
        return [];
      }

      final musicDir = await _getMusicDirectory();
      if (musicDir != null && await musicDir.exists()) {
        return await _listMusicFiles(musicDir);
      } else {
        debugPrint('音楽フォルダが見つかりませんでした: ${musicDir?.path}');
      }
    } catch (e) {
      debugPrint('エラーが発生しました: $e');
    }
    return [];
  }

  static Future<Directory?> _getMusicDirectory() async {
    if (Platform.isAndroid) {
      // Androidの標準的なMusicフォルダ
      final musicDir = Directory('/storage/emulated/0/Music');
      if (await musicDir.exists()) {
        return musicDir;
      }
      
      // 予備（外部ストレージディレクトリ）
      final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (externalDirs != null && externalDirs.isNotEmpty) {
        return externalDirs.first;
      }
    }
    return null;
  }

  static Future<List<FileSystemEntity>> _listMusicFiles(Directory dir) async {
    final List<FileSystemEntity> files = [];
    final allowedExtensions = ['.mp3', '.m4a', '.wav'];

    await for (FileSystemEntity file in dir.list(recursive: false, followLinks: false)) {
      final path = file.path.toLowerCase();
      if (allowedExtensions.any((ext) => path.endsWith(ext))) {
        files.add(file);
      }
    }
    return files;
  }
}
