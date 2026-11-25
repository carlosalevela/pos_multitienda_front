import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/utils/xlsx_normalizar.dart';

/// Un .xlsx como lo dejan openpyxl y otros exportadores: con la ruta de la
/// hoja absoluta ("/xl/worksheets/...").
List<int> _conRutaAbsoluta(List<int> bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  final out = Archive();
  for (final f in zip.files) {
    if (f.name == 'xl/_rels/workbook.xml.rels') {
      final xml = utf8
          .decode(f.content as List<int>)
          .replaceAll('Target="worksheets/', 'Target="/xl/worksheets/');
      final b = utf8.encode(xml);
      out.addFile(ArchiveFile(f.name, b.length, b));
    } else {
      out.addFile(f);
    }
  }
  return ZipEncoder().encode(out)!;
}

List<int> _excelDePrueba() {
  final excel = Excel.createExcel();
  final hoja = excel[excel.getDefaultSheet()!];
  hoja.appendRow([TextCellValue('nombre'), TextCellValue('precio_venta')]);
  hoja.appendRow([TextCellValue('Aretes'), IntCellValue(32000)]);
  return excel.encode()!;
}

void main() {
  test('la ruta absoluta rompe la lectura y normalizar lo arregla', () {
    final roto = _conRutaAbsoluta(_excelDePrueba());

    // Así fallaba en el celular, y la app se saltaba la revisión.
    expect(() => Excel.decodeBytes(roto), throwsA(anything));

    final excel = Excel.decodeBytes(normalizarXlsx(roto));
    final filas = excel.tables.values.firstWhere((s) => s.rows.isNotEmpty).rows;
    expect(filas.length, 2);
    expect(filas[1][0]?.value.toString(), 'Aretes');
  });

  test('una celda de texto vacía ya no revienta la lectura', () {
    // Como la deja openpyxl cuando una celda de texto queda en blanco.
    final zip = ZipDecoder().decodeBytes(_excelDePrueba());
    final out = Archive();
    for (final f in zip.files) {
      if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
        final xml = utf8.decode(f.content as List<int>).replaceFirst(
            '</sheetData>',
            '<row r="3"><c r="A3" t="inlineStr"/><c r="B3"><v>5</v></c></row>'
                '</sheetData>');
        final b = utf8.encode(xml);
        out.addFile(ArchiveFile(f.name, b.length, b));
      } else {
        out.addFile(f);
      }
    }
    final roto = ZipEncoder().encode(out)!;

    expect(() => Excel.decodeBytes(roto), throwsA(anything));
    final filas = Excel.decodeBytes(normalizarXlsx(roto))
        .tables.values.firstWhere((s) => s.rows.isNotEmpty).rows;
    expect(filas.length, 3);
  });

  test('un xlsx normal pasa sin cambios', () {
    final bien = _excelDePrueba();
    expect(identical(normalizarXlsx(bien), bien), isTrue);
  });

  test('basura no revienta: devuelve los mismos bytes', () {
    final basura = [1, 2, 3, 4];
    expect(normalizarXlsx(basura), basura);
  });

  test('las plantillas de prueba del usuario se leen completas', () {
    const plantillas = {
      r'C:\Users\XzCar\Documents\plantilla_prueba_importar.xlsx': '99900001',
      r'C:\Users\XzCar\Documents\plantilla_prueba_importar_2.xlsx': '99900101',
    };
    for (final p in plantillas.entries) {
      final f = File(p.key);
      if (!f.existsSync()) continue; // solo en la máquina donde están
      final excel = Excel.decodeBytes(normalizarXlsx(f.readAsBytesSync()));
      final filas =
          excel.tables.values.firstWhere((s) => s.rows.isNotEmpty).rows;
      expect(filas.length, 11, reason: p.key); // encabezado + 10 filas
      expect(filas[0][0]?.value.toString(), 'nombre');
      expect(filas[1][1]?.value.toString(), p.value); // código como texto

      // La fila "Error precio negativo" (fila 10 del Excel) trae el precio
      // como número negativo: así la revisión puede marcarla como error.
      final precio = filas[9][4]?.value;
      expect(precio, isA<IntCellValue>(), reason: p.key);
      expect((precio as IntCellValue).value, lessThan(0), reason: p.key);
    }
  });
}
