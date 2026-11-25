// lib/utils/numero_excel.dart
//
// Convierte el TEXTO de una celda de Excel en número, aceptando cómo lo
// escribe la gente: "$ 12.500", "1.234,56", "1,234.56", "12,5"...
// Las celdas numéricas no deben pasar por aquí: ya traen su número.
//
// Respeta el signo. Antes se limpiaba todo lo que no fuera dígito, punto
// o coma, y con eso se iba también el "-": un precio de -6.000 llegaba
// como 6.000, pasaba la revisión como si estuviera bien y se importaba
// con un valor que nadie escribió.

/// Negativo si hay un menos antes del primer dígito ("-6000", "$-6.000",
/// "-$ 6.000", "−5" con el signo tipográfico) o si viene entre paréntesis,
/// como lo muestra el formato contable: "(6.000)".
bool _esNegativo(String t) =>
    RegExp(r'^[^\d]*[-−]').hasMatch(t) ||
    (t.startsWith('(') && t.endsWith(')'));

double leerNumeroExcel(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;

  var limpio = t.replaceAll(RegExp(r'[^\d.,]'), '');
  if (limpio.isEmpty) return 0;

  if (limpio.contains(',') && limpio.contains('.')) {
    // El separador que va último es el decimal.
    if (limpio.lastIndexOf(',') > limpio.lastIndexOf('.')) {
      limpio = limpio.replaceAll('.', '').replaceAll(',', '.');
    } else {
      limpio = limpio.replaceAll(',', '');
    }
  } else if (limpio.contains(',')) {
    // "12,5" es decimal; "1,234" es miles.
    final partes = limpio.split(',');
    if (partes.length == 2 && partes.last.length <= 2) {
      limpio = limpio.replaceAll(',', '.');
    } else {
      limpio = limpio.replaceAll(',', '');
    }
  } else if (limpio.contains('.')) {
    // En Colombia el punto separa miles: "12.500" son doce mil quinientos,
    // no 12,5. Se toma como miles si hay varios puntos ("1.234.567") o si
    // al único punto le siguen exactamente 3 dígitos. "12.5" sigue siendo
    // decimal. Esto aplica solo a texto: las celdas numéricas de Excel no
    // pasan por aquí (ver importar_excel_dialog, cellNum).
    final partes = limpio.split('.');
    if (partes.length > 2 || partes.last.length == 3) {
      limpio = limpio.replaceAll('.', '');
    }
  }

  final valor = double.tryParse(limpio) ?? 0;
  return _esNegativo(t) ? -valor : valor;
}
