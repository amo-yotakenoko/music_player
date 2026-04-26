import 'dart:io';
import 'package:path/path.dart' as p;

class MusicFile {
  FileSystemEntity fileEntry;
  final String path;
  String title;
  final String directory;

  // 初期化リスト（コロンの後ろで代入する）
  MusicFile(FileSystemEntity file)
    : fileEntry = file,
      path = file.path,
      title = p.basename(file.path),
      directory = p.dirname(file.path);

  @override
  String toString() {
    // メンバ変数を分かりやすく整形
    return 'MusicFile(title: $title, directory: $directory)';
  }

  // コンストラクタから呼ぶ関数は static にする必要がある
  // （p.basename, p.dirname を使うようにしたので不要になりましたが、互換性のために残すか削除します。
  // 今回は完全に p.Context (pathパッケージ) に任せる形に修正します）
}
