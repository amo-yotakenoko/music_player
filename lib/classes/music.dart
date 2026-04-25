import 'dart:io';

class MusicFile {
  FileSystemEntity fileEntry;
  final String path;
  final String title;
  final String directoory;

  // 初期化リスト（コロンの後ろで代入する）
  MusicFile(FileSystemEntity file)
    : fileEntry = file,
      path = file.path,
      title = _extractTitle(file),
      directoory = _extractDirectory(file);

  // コンストラクタから呼ぶ関数は static にする必要がある
  static String _extractTitle(FileSystemEntity file) {
    return file.path.split('/').last;
  }

  static String _extractDirectory(FileSystemEntity file) {
    return file.path
        .split('/')
        .sublist(0, file.path.split('/').length - 1)
        .join('/');
  }
}
