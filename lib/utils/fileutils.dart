import 'dart:io' as Io; 
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class FileUtils {
  static Future<String> getDirPath() async {
    var dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static saveImage(Uint8List imageBytes, String fileName) async {
    String path = await getDirPath();
    Io.File("$path/$fileName.png").writeAsBytesSync(imageBytes.toList());
  }

  static Future<bool> isFileExist(String fileName) async {
    String path = await getDirPath();
    return await Io.File("$path/$fileName.png").exists();
  }

  static Future<Io.File> getImage(String fileName) async {
    String path = await getDirPath();
    return Io.File("$path/$fileName.png");
  }

  static Future<String> getFullPath(String fileName) async {
    String path = await getDirPath();
    return "$path/$fileName.png";
  }

  static getListFiles() async {
    String path = await getDirPath();
    List files = Io.Directory("$path").listSync();
  }

  static replaceFile(String fileName, Uint8List imageBytes) async {
    String path = await getDirPath();
    Io.File("$path/$fileName.png").delete();
    await saveImage(imageBytes, fileName);
  }
}