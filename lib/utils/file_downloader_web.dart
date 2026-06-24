// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> guardarArchivoExcel(List<int> bytes, String fileName) async {
  // Uint8List is required — a plain List<int> becomes a comma-joined string in JS
  final blob = html.Blob(
    [Uint8List.fromList(bytes)],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
