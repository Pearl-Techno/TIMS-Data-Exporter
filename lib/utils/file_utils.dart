import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileUtils {
  static Future<String> getDocumentsDirectoryPath() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return documentsDirectory.path;
  }

  static Future<File> createFile(String fileName) async {
    String directoryPath = await getDocumentsDirectoryPath();
    String filePath = '$directoryPath/$fileName';
    return File(filePath);
  }

  static Future<void> writeToFile(File file, String data) async {
    await file.writeAsString(data);
  }
}
