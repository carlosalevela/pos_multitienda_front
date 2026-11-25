// lib/utils/xlsx_normalizar.dart
//
// Arregla dos detalles de algunos .xlsx antes de leerlos con el paquete
// `excel` (4.0.x), que si no revienta y la importación no puede mostrar la
// revisión.
//
// Un .xlsx es un zip. Excel y Google Sheets lo escriben de una forma que el
// paquete entiende, pero muchos programas que exportan a Excel (openpyxl,
// varios sistemas contables, etc.) hacen dos cosas distintas:
//
// 1. Ruta absoluta de la hoja. En `xl/_rels/workbook.xml.rels` ponen
//    "/xl/worksheets/sheet1.xml" en vez de "worksheets/sheet1.xml". El
//    paquete le antepone "xl/", busca "xl//xl/...", no la encuentra y
//    falla con "Null check operator used on a null value".
//
// 2. Celdas de texto vacías como `<c r="C9" t="inlineStr"/>`, sin `<t>`
//    adentro. El paquete hace `.first` sobre los `<t>` y falla con
//    "Bad state: No element".
//
// Si el archivo no necesita nada, o algo sale mal, se devuelven los bytes
// tal cual.

import 'dart:convert';

import 'package:archive/archive.dart';

const _rels = 'xl/_rels/workbook.xml.rels';

/// Celda autocerrada: `<c ... />`.
final _celdaVacia = RegExp(r'<c\b[^>]*/>');

/// `<is/>` o `<is></is>`: texto en línea sin `<t>`.
final _isVacio = RegExp(r'<is\s*/>|<is>\s*</is>');

String? _arreglarRels(String xml) =>
    xml.contains('Target="/xl/') ? xml.replaceAll('Target="/xl/', 'Target="') : null;

String? _arreglarHoja(String xml) {
  var cambio = false;
  var out = xml.replaceAllMapped(_celdaVacia, (m) {
    final c = m[0]!;
    if (!c.contains('t="inlineStr"')) return c;
    cambio = true;
    // Sin tipo y sin valor: el paquete la toma como celda vacía.
    return c.replaceFirst(RegExp(r'\s+t="inlineStr"'), '');
  });
  if (_isVacio.hasMatch(out)) {
    cambio = true;
    out = out.replaceAll(_isVacio, '<is><t></t></is>');
  }
  return cambio ? out : null;
}

List<int> normalizarXlsx(List<int> bytes) {
  try {
    final zip = ZipDecoder().decodeBytes(bytes);
    final reemplazos = <String, List<int>>{};

    for (final f in zip.files) {
      if (!f.isFile) continue;
      String? nuevo;
      if (f.name == _rels) {
        nuevo = _arreglarRels(utf8.decode(f.content as List<int>));
      } else if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
        nuevo = _arreglarHoja(utf8.decode(f.content as List<int>));
      }
      if (nuevo != null) reemplazos[f.name] = utf8.encode(nuevo);
    }

    if (reemplazos.isEmpty) return bytes;

    final salida = Archive();
    for (final f in zip.files) {
      final r = reemplazos[f.name];
      salida.addFile(r == null ? f : ArchiveFile(f.name, r.length, r));
    }
    return ZipEncoder().encode(salida) ?? bytes;
  } catch (_) {
    return bytes;
  }
}
