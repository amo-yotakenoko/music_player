import 'dart:io';
import 'package:csv/csv.dart';

class AudioValueService {
  final Map<String, double> volumeMap = {};
  final String targetPath = "/storage/emulated/0/Music/volumes.csv";

  void loadVolumeCsv() async {
    // Androidの標準パスをデフォルトに

    try {
      final file = File(targetPath);
      if (!await file.exists()) {
        print("CSVファイルが見つかりません: $targetPath");
      }

      final input = await file.readAsString();

      // CsvDecoder を使用してパース
      // convert() メソッドに文字列を渡すと List<List<dynamic>> が返ります
      final List<List<dynamic>> rows = CsvDecoder().convert(input);

      for (var row in rows) {
        if (row.length >= 2) {
          String fileName = row[0].toString();
          // カンマ区切りの2番目の要素を数値に変換
          double volume = double.tryParse(row[1].toString()) ?? -14.0;
          volumeMap[fileName] = volume;
        }
      }
      print("CSVデコード成功: ${volumeMap.length}件");
    } catch (e) {
      print("CsvDecoderエラー: $e");
    }
  }
}
