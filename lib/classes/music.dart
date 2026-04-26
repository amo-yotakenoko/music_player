import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

class MusicFile {
  FileSystemEntity fileEntry;
  final String path;
  String title;
  final String directory;
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
      key = UniqueKey();

  @override
  String toString() {
    // メンバ変数を分かりやすく整形
    return 'MusicFile(title: $title, directory: $directory)';
  }
}
