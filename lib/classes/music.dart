import 'dart:io';

class MusicFile {
  FileSystemEntity fileEntry;
  final String path;
  final String title;
  final String artist;

  // 初期化リスト（コロンの後ろで代入する）
  MusicFile(FileSystemEntity file)
    : fileEntry = file,
      path = file.path,
      title = _extractTitle(file),
      artist = _extractArtist(file);

  // コンストラクタから呼ぶ関数は static にする必要がある
  static String _extractTitle(FileSystemEntity file) {
    return file.path.split('/').last; // 例: ファイル名を取得
  }

  static String _extractArtist(FileSystemEntity file) => "Unknown Artist";
}
