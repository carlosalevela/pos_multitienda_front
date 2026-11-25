import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// true en Android/iOS: el archivo queda dentro de la app y hay que
/// ofrecer abrirlo, porque el usuario no tiene cómo llegar a esa carpeta.
bool get excelQuedaDentroDeLaApp => Platform.isAndroid || Platform.isIOS;

/// Dónde queda el archivo, dicho para el usuario.
String get lugarDelExcel =>
    excelQuedaDentroDeLaApp ? 'en el celular' : 'en Descargas';

Future<String> guardarArchivoExcel(List<int> bytes, String fileName) async {
  // En el celular no hay "Descargas" del usuario: antes se armaba una ruta
  // de Windows con HOME y el archivo terminaba donde nadie lo encontraba.
  // Se guarda en la carpeta de documentos de la app y se abre con
  // abrirArchivo().
  if (excelQuedaDentroDeLaApp) {
    final docs = await getApplicationDocumentsDirectory();
    final sep = Platform.pathSeparator;
    final dir = Directory('${docs.path}${sep}Exportes');
    await dir.create(recursive: true);
    final f = File('${dir.path}$sep$fileName');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

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

/// Abre el archivo con la app que tenga el equipo (Excel, Sheets, WPS…).
/// Devuelve null si abrió, o el motivo en español si no.
Future<String?> abrirArchivo(String path) async {
  try {
    final r = await OpenFilex.open(path);
    return switch (r.type) {
      ResultType.done             => null,
      ResultType.noAppToOpen      =>
        'No hay ninguna app para abrir Excel. Instala Excel, Google Sheets o WPS Office.',
      ResultType.fileNotFound     => 'No se encontró el archivo.',
      ResultType.permissionDenied => 'No hay permiso para abrir el archivo.',
      ResultType.error            => 'No se pudo abrir el archivo.',
    };
  } catch (_) {
    return 'No se pudo abrir el archivo.';
  }
}
