// lib/services/formato_pdf_service.dart
//
// Genera el PDF del Registro de Movimiento Diario (hoja landscape A4).

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../screens/caja/widgets/registro_movimiento_diario.dart';

// ── Colores ──────────────────────────────────────────────
const _ink    = PdfColors.black;
const _grey50 = PdfColor.fromInt(0xFFF9FAFB);

// ── Formato de número colombiano (puntos como miles) ─────
String _dinero(double? v) {
  if (v == null || v == 0) return '';
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '\$$b';
}

String _fecha(DateTime d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)} / ${dos(d.month)} / ${dos(d.year % 100)}';
}

// ─────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────

Future<List<int>> generarFormatoDiarioPdf(RegistroMovimientoData data) async {
  final pdf = pw.Document();

  // Columnas: flex relativo
  // Concepto | # | Efectivo | Datáfono | Davivienda | Daviplata | Bancolombia | Nequi | Bono | Total
  const cols = <double>[24, 4, 8, 8, 8, 8, 8, 8, 8, 8]; // 10 columnas

  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(18),
    build: (ctx) {
      pw.Widget celda(
        String txt, {
        double flex = 1,
        bool bold = false,
        bool center = false,
        bool header = false,
        PdfColor? bg,
        pw.Border? border,
      }) {
        return pw.Expanded(
          flex: (flex * 10).round(),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: bg,
              border: border ?? pw.Border.all(color: _ink, width: 0.4),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: pw.Text(
              txt,
              textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(
                fontSize: header ? 7.5 : 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: _ink,
              ),
            ),
          ),
        );
      }

      // ── Fila de encabezado de la tabla ──────────────────
      pw.Widget cabeceraTabla() => pw.Row(children: [
        celda('', flex: cols[0], bold: true, center: true,
            bg: _grey50, border: pw.Border.all(color: _ink, width: 0.6)),
        celda('#', flex: cols[1], bold: true, center: true,
            bg: _grey50, border: pw.Border.all(color: _ink, width: 0.6)),
        for (var i = 2; i < cols.length; i++)
          celda(
            [
              'EFECTIVO', 'DATÁFONO', 'DAVIVIENDA',
              'DAVIPLATA', 'BANCOLOMBIA', 'NEQUI', 'BONO', 'TOTAL',
            ][i - 2],
            flex: cols[i], bold: true, center: true,
            bg: _grey50,
            border: pw.Border.all(color: _ink, width: 0.6),
          ),
      ]);

      // ── Fila de movimiento ──────────────────────────────
      pw.Widget filaMovimiento(FilaRegistro f, {bool destacada = false}) {
        final bs = pw.FontWeight.bold;
        final bw = destacada ? pw.FontWeight.bold : pw.FontWeight.normal;
        final bg = destacada ? const PdfColor.fromInt(0xFFE6F4EE) : null;
        final border = pw.Border.all(
            color: _ink, width: destacada ? 0.8 : 0.4);

        final medios = MedioPago.values;

        return pw.Row(children: [
          // Concepto
          pw.Expanded(
            flex: (cols[0] * 10).round(),
            child: pw.Container(
              decoration: pw.BoxDecoration(color: bg, border: border),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(
                    text: '(${f.signo}) ',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: bs, color: _ink),
                  ),
                  pw.TextSpan(
                    text: f.concepto,
                    style: pw.TextStyle(
                        fontSize: destacada ? 8.5 : 7.5,
                        fontWeight: bw, color: _ink),
                  ),
                ]),
              ),
            ),
          ),
          // Cantidad
          pw.Expanded(
            flex: (cols[1] * 10).round(),
            child: pw.Container(
              decoration: pw.BoxDecoration(color: bg, border: border),
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Text(
                f.cantidad == 0 ? '' : '${f.cantidad}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: bw),
              ),
            ),
          ),
          // Medios de pago + total
          for (var idx = 0; idx < medios.length; idx++)
            pw.Expanded(
              flex: (cols[2 + idx] * 10).round(),
              child: pw.Container(
                decoration: pw.BoxDecoration(color: bg, border: border),
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 3, vertical: 3),
                child: pw.Text(
                  _dinero(f.montos[medios[idx]]),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 7.5, fontWeight: bw, color: _ink),
                ),
              ),
            ),
          // Total fila
          pw.Expanded(
            flex: (cols[9] * 10).round(),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                  color: destacada
                      ? const PdfColor.fromInt(0xFFB7F5D9) : bg,
                  border: border),
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 3, vertical: 3),
              child: pw.Text(
                f.total > 0 ? _dinero(f.total) : '',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink),
              ),
            ),
          ),
        ]);
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── ENCABEZADO ──────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _ink, width: 1.5),
            ),
            child: pw.Column(children: [
              // Fila 1: Almacén | Título
              pw.SizedBox(
                height: 48,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Expanded(
                      flex: 50,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            right: pw.BorderSide(color: _ink, width: 0.8),
                            bottom: pw.BorderSide(color: _ink, width: 0.8),
                          ),
                        ),
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text('NOMBRE DEL ALMACÉN / BODEGA',
                              style: pw.TextStyle(
                                  fontSize: 7, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text(data.almacen,
                              style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold)),
                        ]),
                      ),
                    ),
                    pw.Expanded(
                      flex: 50,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: _ink, width: 0.8),
                          ),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'REGISTRO DE MOVIMIENTO DIARIO',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Fila 2: Fecha | Encargado | Nº Ventas
              pw.Row(children: [
                pw.Container(
                  width: 100,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        right: pw.BorderSide(color: _ink, width: 0.8)),
                  ),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                    pw.Text('FECHA',
                        style: pw.TextStyle(
                            fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(_fecha(data.fecha),
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          right: pw.BorderSide(color: _ink, width: 0.8)),
                    ),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                      pw.Text('NOMBRE DE ENCARGADO',
                          style: pw.TextStyle(
                              fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(data.encargado,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold)),
                    ]),
                  ),
                ),
                pw.Container(
                  width: 160,
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                    pw.Text('(+) NÚMERO TOTAL DE VENTAS',
                        style: pw.TextStyle(
                            fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${data.numeroVentas}   ${_dinero(data.totalVentas)}',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ]),
                ),
              ]),
            ]),
          ),

          pw.SizedBox(height: 2),

          // ── TABLA ───────────────────────────────────────
          cabeceraTabla(),
          for (final f in data.filas) filaMovimiento(f),
          filaMovimiento(data.totalEntregado, destacada: true),

          pw.SizedBox(height: 2),

          // ── OBSERVACIONES ───────────────────────────────
          pw.Container(
            height: 48,
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _ink, width: 1)),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('OBSERVACIONES',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    data.observaciones,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 2),

          // ── FIRMAS ──────────────────────────────────────
          pw.SizedBox(
            height: 56,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _ink, width: 1)),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REALIZÓ',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 18),
                        pw.Divider(color: _ink, thickness: 0.8),
                        pw.SizedBox(height: 2),
                        pw.Text(data.realizo,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 2),
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _ink, width: 1)),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FECHA DE RECIBIDO',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 22),
                        pw.Divider(color: _ink, thickness: 0.8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 4),
          pw.Text(
            'Generado automáticamente — POS Multitienda',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
                fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      );
    },
  ));

  return pdf.save();
}
