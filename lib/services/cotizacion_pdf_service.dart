// lib/services/cotizacion_pdf_service.dart
//
// Genera un PDF de cotización (A4) a partir del carrito del POS.
// No crea ninguna venta ni mueve stock — es solo un documento informativo.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/item_carrito.dart';

class CotizacionPdfService {
  static final _fmt     = NumberFormat('#,##0', 'es_CO');
  static final _fmtTs   = DateFormat('yyyyMMdd-HHmmss');
  static final _fmtDate = DateFormat('dd/MM/yyyy', 'es');

  // Palette
  static final _green    = PdfColor.fromInt(0xFF006C49);
  static final _greenBg  = PdfColor.fromInt(0xFFE8FFF4);
  static final _dark     = PdfColor.fromInt(0xFF1A1A2E);
  static final _greyBg   = PdfColor.fromInt(0xFFF8FAFC);
  static final _red      = PdfColor.fromInt(0xFFDC2626);

  // ── Punto de entrada ──────────────────────────────────────────────────────

  static Future<void> generarCotizacion({
    required List<ItemCarrito> items,
    required double            descuento,
    required double            total,
    required String            empresaNombre,
    required String            tiendaNombre,
    required String            cajeroNombre,
    String?                    clienteNombre,
  }) async {
    final fontBold = await PdfGoogleFonts.interBold();
    final fontReg  = await PdfGoogleFonts.interRegular();

    final now    = DateTime.now();
    final nroCot = 'COT-${_fmtTs.format(now)}';
    final fecha  = _fmtDate.format(now);
    final subtotal = items.fold<double>(0.0, (s, i) => s + i.subtotal);

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin:     const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
      build: (_) => [
        _header(fontBold, fontReg, empresaNombre, tiendaNombre, nroCot, fecha),
        pw.SizedBox(height: 20),
        if (clienteNombre != null && clienteNombre.isNotEmpty) ...[
          _clienteInfo(fontBold, fontReg, clienteNombre),
          pw.SizedBox(height: 14),
        ],
        _itemsTable(fontBold, fontReg, items),
        pw.SizedBox(height: 14),
        _totales(fontBold, fontReg, subtotal, descuento, total),
        pw.SizedBox(height: 28),
        _footer(fontBold, fontReg, cajeroNombre),
      ],
    ));

    final bytes = await doc.save();
    await _abrirPdf(bytes, '$nroCot.pdf');
  }

  // ── Open PDF ──────────────────────────────────────────────────────────────

  static Future<void> _abrirPdf(List<int> bytes, String nombre) async {
    if (kIsWeb) {
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: nombre,
      );
      return;
    }
    // La cotización es A4 — nunca va a la térmica, siempre abrir el visor del sistema
    final dir  = await getTemporaryDirectory();
    final safe = nombre.replaceAll(RegExp(r'[:*?"<>|]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}$safe');
    await file.writeAsBytes(bytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else {
      await Process.run('xdg-open', [file.path]);
    }
  }

  // ── Sección: encabezado ───────────────────────────────────────────────────

  static pw.Widget _header(
    pw.Font fontBold, pw.Font fontReg,
    String empresa, String tienda, String nroCot, String fecha,
  ) =>
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Izquierda — empresa + tienda
      pw.Expanded(child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _green,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(empresa.toUpperCase(),
              style: pw.TextStyle(
                  font: fontBold, fontSize: 15, color: PdfColors.white)),
          ),
          pw.SizedBox(height: 5),
          pw.Text(tienda,
            style: pw.TextStyle(
                font: fontReg, fontSize: 10, color: PdfColors.grey600)),
        ],
      )),
      pw.SizedBox(width: 20),
      // Derecha — badge COTIZACIÓN + número + fecha
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: pw.BoxDecoration(
            color: _greenBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: _green),
          ),
          child: pw.Text('COTIZACIÓN',
            style: pw.TextStyle(
                font: fontBold, fontSize: 13, color: _green, letterSpacing: 1)),
        ),
        pw.SizedBox(height: 5),
        pw.Text(nroCot,
          style: pw.TextStyle(font: fontBold, fontSize: 9, color: _dark)),
        pw.Text('Fecha: $fecha',
          style: pw.TextStyle(
              font: fontReg, fontSize: 9, color: PdfColors.grey600)),
        pw.Text('Válida por 30 días',
          style: pw.TextStyle(
              font: fontReg, fontSize: 9, color: PdfColors.grey600)),
      ]),
    ]);

  // ── Sección: cliente ──────────────────────────────────────────────────────

  static pw.Widget _clienteInfo(
    pw.Font fontBold, pw.Font fontReg, String clienteNombre,
  ) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _greyBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(children: [
        pw.Text('Cliente: ',
          style: pw.TextStyle(font: fontBold, fontSize: 10, color: _dark)),
        pw.Text(clienteNombre,
          style: pw.TextStyle(font: fontReg, fontSize: 10, color: _dark)),
      ]),
    );

  // ── Sección: tabla de items ───────────────────────────────────────────────

  static pw.Widget _itemsTable(
    pw.Font fontBold, pw.Font fontReg, List<ItemCarrito> items,
  ) {
    final hStyle = pw.TextStyle(font: fontBold, fontSize: 9,  color: PdfColors.white);
    final cStyle = pw.TextStyle(font: fontReg,  fontSize: 9,  color: _dark);
    final nStyle = pw.TextStyle(font: fontBold, fontSize: 9,  color: _dark);
    final sStyle = pw.TextStyle(font: fontReg,  fontSize: 7.5, color: _green);

    return pw.Table(
      border: pw.TableBorder(
        bottom:            const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        horizontalInside:  const pw.BorderSide(color: PdfColors.grey300, width: 0.3),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),   // Producto
        1: pw.FlexColumnWidth(1),   // Cant
        2: pw.FlexColumnWidth(1.8), // Precio Unit
        3: pw.FlexColumnWidth(1.8), // Subtotal
      },
      children: [
        // Cabecera
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _green),
          children: [
            _th('PRODUCTO',     hStyle),
            _thR('CANT.',       hStyle),
            _thR('PRECIO UNIT.', hStyle),
            _thR('SUBTOTAL',    hStyle),
          ],
        ),
        // Filas
        ...items.asMap().entries.map((e) {
          final i     = e.key;
          final item  = e.value;
          final odd   = i.isOdd;
          final cant  = item.cantidad % 1 == 0
              ? item.cantidad.toStringAsFixed(0)
              : item.cantidad.toStringAsFixed(2);
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: odd ? _greyBg : PdfColors.white),
            children: [
              // Producto (con sub-label mayoreo si aplica)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.producto.nombre, style: cStyle),
                    if (item.aplicaMayoreo)
                      pw.Text('Precio mayoreo', style: sStyle),
                  ],
                ),
              ),
              _tdR(cant,                                    nStyle),
              _tdR('\$${_fmt.format(item.precioUnitario)}', nStyle),
              _tdR('\$${_fmt.format(item.subtotal)}',       nStyle),
            ],
          );
        }),
      ],
    );
  }

  // ── Sección: totales ──────────────────────────────────────────────────────

  static pw.Widget _totales(
    pw.Font fontBold, pw.Font fontReg,
    double subtotal, double descuento, double total,
  ) =>
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        if (descuento > 0) ...[
          _filaTotal(fontReg, 'Subtotal:',   '\$${_fmt.format(subtotal)}'),
          pw.SizedBox(height: 3),
          _filaTotal(fontReg, 'Descuento:', '-\$${_fmt.format(descuento)}',
              valueColor: _red),
          pw.SizedBox(height: 8),
        ],
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _greenBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: _green, width: 0.5),
          ),
          child: pw.Row(children: [
            pw.Text('TOTAL: ',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: _green)),
            pw.Text('\$${_fmt.format(total)}',
              style: pw.TextStyle(font: fontBold, fontSize: 16, color: _green)),
          ]),
        ),
      ]),
    ]);

  // ── Sección: footer ───────────────────────────────────────────────────────

  static pw.Widget _footer(
    pw.Font fontBold, pw.Font fontReg, String cajeroNombre,
  ) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      pw.SizedBox(height: 8),
      pw.Text('Esta cotización no tiene validez fiscal.',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600)),
      pw.SizedBox(height: 3),
      pw.Text(
        'Precios sujetos a cambio sin previo aviso · '
        'Válida por 30 días a partir de la fecha de emisión.',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: fontReg, fontSize: 8, color: PdfColors.grey400)),
      pw.SizedBox(height: 5),
      pw.Text('Atendido por: $cajeroNombre',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: fontReg, fontSize: 8, color: PdfColors.grey600)),
    ]);

  // ── Helpers de tabla ──────────────────────────────────────────────────────

  static pw.Widget _th(String text, pw.TextStyle style) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(text, style: style),
    );

  static pw.Widget _thR(String text, pw.TextStyle style) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(text, style: style)),
    );

  static pw.Widget _tdR(String text, pw.TextStyle style) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(text, style: style)),
    );

  static pw.Widget _filaTotal(
    pw.Font fontReg, String label, String value, {PdfColor? valueColor}
  ) =>
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text(label,
        style: pw.TextStyle(font: fontReg, fontSize: 10, color: PdfColors.grey600)),
      pw.SizedBox(width: 16),
      pw.SizedBox(
        width: 100,
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(value,
            style: pw.TextStyle(
                font: fontReg, fontSize: 10,
                color: valueColor ?? _dark)),
        ),
      ),
    ]);
}
