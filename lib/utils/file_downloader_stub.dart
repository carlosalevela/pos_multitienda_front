import 'dart:io';

Future<String> guardarArchivoExcel(List<int> bytes, String fileName) async {
  String savePath;
  try {
    final env  = Platform.environment;
    final home = env['USERPROFILE'] ?? env['HOME'] ?? '';
    savePath   = home.isNotEmpty
        ? '$home\\Downloads\\$fileName'
        : '${Directory.systemTemp.path}\\$fileName';
  } catch (_) {
    savePath = '${Directory.systemTemp.path}\\$fileName';
  }
  await File(savePath).writeAsBytes(bytes, flush: true);
  return savePath;
}
