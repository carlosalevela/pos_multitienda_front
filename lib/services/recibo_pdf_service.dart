// lib/services/recibo_pdf_service.dart

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/item_carrito.dart';

class ReciboPdfService {
  // ── Colores ──────────────────────────────────────────────────
  static const _green    = PdfColor.fromInt(0xFF006C49);
  static const _greenBg  = PdfColor.fromInt(0xFFE8FFF4);
  static const _dark     = PdfColor.fromInt(0xFF1A1A2E);
  static const _grey700  = PdfColors.grey700;
  static const _grey500  = PdfColors.grey500;
  static const _grey300  = PdfColors.grey300;

  // 80 mm receipt width
  static final _pageFormat = PdfPageFormat(
    80  * PdfPageFormat.mm,
    double.infinity,
    marginLeft:   4 * PdfPageFormat.mm,
    marginRight:  4 * PdfPageFormat.mm,
    marginTop:    5 * PdfPageFormat.mm,
    marginBottom: 8 * PdfPageFormat.mm,
  );

  static final _fmt = NumberFormat('#,##0', 'es_CO');

  // ── Punto de entrada ─────────────────────────────────────────

  static Future<void> imprimirRecibo({
    required List<ItemCarrito> items,
    required String            numeroFactura,
    required String            tiendaNombre,
    required String            empresaNombre,
    required String            cajeroNombre,
    required String            metodoPago,
    required double            descuento,
    required double            total,
    required double            montoRecibido,
    required double            vuelto,
    String                     nit       = '',
    String                     direccion = '',
    String                     telefono  = '',
  }) async {
    final fontReg  = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMono = await PdfGoogleFonts.sourceCodeProRegular();
    final now      = DateTime.now();

    final subtotal    = items.fold(0.0, (s, i) => s + i.subtotal);
    final totalItems  = items.fold(0,   (s, i) => s + i.cantidad);

    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: _pageFormat,
      build: (ctx) => [
        // ── 1. Encabezado empresa ──────────────────────────────
        _encabezado(fontBold, fontReg, empresaNombre, tiendaNombre,
            nit, direccion, telefono),
        _divider(),

        // ── 2. Título ─────────────────────────────────────────
        pw.Center(
          child: pw.Text('FACTURA DE VENTA',
            style: pw.TextStyle(
                font: fontBold, fontSize: 9, color: _dark,
                letterSpacing: 1.5)),
        ),
        _divider(),

        // ── 3. Info de la transacción ──────────────────────────
        _infoTransaccion(fontBold, fontReg, numeroFactura, cajeroNombre, now),
        _divider(),

        // ── 4. Tabla de productos ──────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(children: [
            pw.Text('DESCRIPCIÓN',
                style: pw.TextStyle(font: fontBold, fontSize: 7, color: _grey500)),
            pw.Spacer(),
            pw.Text('TOTAL',
                style: pw.TextStyle(font: fontBold, fontSize: 7, color: _grey500)),
          ]),
        ),
        pw.SizedBox(height: 2),
        ...items.map((item) => _itemRow(item, fontBold, fontReg)),
        pw.SizedBox(height: 4),
        _divider(),

        // ── 5. Totales ─────────────────────────────────────────
        _totalesSection(fontBold, fontReg, fontMono,
            subtotal, descuento, total, totalItems),
        _divider(),

        // ── 6. Pago ────────────────────────────────────────────
        _pagoSection(fontBold, fontReg, metodoPago, montoRecibido, vuelto),
        _divider(),

        // ── 7. Código de barras ────────────────────────────────
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data:    numeroFactura,
            width:   65 * PdfPageFormat.mm,
            height:  28,
            drawText: false,
            color:   _dark,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(numeroFactura,
            style: pw.TextStyle(font: fontMono, fontSize: 8, color: _grey700)),
        ),
        pw.SizedBox(height: 6),
        _divider(),

        // ── 8. Footer ─────────────────────────────────────────
        _footer(fontBold, fontReg, empresaNombre),
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'Recibo_$numeroFactura.pdf',
    );
  }


  // ── Secciones ────────────────────────────────────────────────

  static pw.Widget _encabezado(
    pw.Font fontBold, pw.Font fontReg,
    String empresa, String tienda,
    String nit, String dir, String tel,
  ) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Bloque verde con nombre empresa
        pw.Container(
          width:   double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: const pw.BoxDecoration(color: _green),
          child: pw.Column(children: [
            pw.Text(empresa.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 14, color: PdfColors.white,
                  letterSpacing: 1)),
            pw.SizedBox(height: 2),
            pw.Text(tienda,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  font: fontReg, fontSize: 9, color: PdfColors.white)),
          ]),
        ),
        // Info adicional (NIT / dirección / teléfono)
        if (nit.isNotEmpty || dir.isNotEmpty || tel.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          if (nit.isNotEmpty)
            pw.Text('NIT: $nit',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: _grey700)),
          if (dir.isNotEmpty)
            pw.Text(dir,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500)),
          if (tel.isNotEmpty)
            pw.Text('Tel: $tel',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500)),
          pw.SizedBox(height: 4),
        ] else
          pw.SizedBox(height: 6),
      ],
    );


  static pw.Widget _infoTransaccion(
    pw.Font fontBold, pw.Font fontReg,
    String factura, String cajero, DateTime now,
  ) {
    final fecha  = DateFormat('dd/MM/yyyy').format(now);
    final hora   = DateFormat('HH:mm:ss').format(now);

    return pw.Column(children: [
      _filaInfo(fontBold, fontReg, 'N° Factura:', factura, boldValue: true),
      _filaInfo(fontBold, fontReg, 'Fecha:',      fecha),
      _filaInfo(fontBold, fontReg, 'Hora:',       hora),
      _filaInfo(fontBold, fontReg, 'Cajero:',     cajero),
    ]);
  }


  static pw.Widget _itemRow(
    ItemCarrito item,
    pw.Font fontBold,
    pw.Font fontReg,
  ) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Datos del producto (nombre + detalles)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(item.producto.nombre,
                  style: pw.TextStyle(font: fontBold, fontSize: 9)),
                pw.Text(
                  '${item.cantidad} x \$${_fmt.format(item.precioUnitario)} c/u',
                  style: pw.TextStyle(
                      font: fontReg, fontSize: 7, color: _grey500)),
                if (item.aplicaMayoreo)
                  pw.Text('★ Precio mayoreo',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 7, color: _green)),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          // Subtotal
          pw.Text('\$${_fmt.format(item.subtotal)}',
            style: pw.TextStyle(font: fontBold, fontSize: 10)),
        ],
      ),
    );


  static pw.Widget _totalesSection(
    pw.Font fontBold, pw.Font fontReg, pw.Font fontMono,
    double subtotal, double descuento, double total, int totalItems,
  ) =>
    pw.Column(children: [
      _filaTotal(fontReg, fontMono, 'Artículos:', '$totalItems'),
      if (descuento > 0) ...[
        _filaTotal(fontReg, fontMono, 'Subtotal:',  '\$${_fmt.format(subtotal)}'),
        _filaTotal(fontReg, fontMono, 'Descuento:', '-\$${_fmt.format(descuento)}',
            color: PdfColors.orange700),
      ],
      pw.SizedBox(height: 4),
      // Fila TOTAL resaltada
      pw.Container(
        width:   double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: const pw.BoxDecoration(color: _greenBg),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL A PAGAR',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: _green)),
            pw.Text('\$${_fmt.format(total)}',
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: _green)),
          ],
        ),
      ),
    ]);


  static pw.Widget _pagoSection(
    pw.Font fontBold, pw.Font fontReg,
    String metodo, double recibido, double vuelto,
  ) =>
    pw.Column(children: [
      _filaInfo(fontBold, fontReg, 'Forma de pago:', _metodoLabel(metodo)),
      if (metodo == 'efectivo') ...[
        _filaInfo(fontBold, fontReg, 'Efectivo recibido:', '\$${_fmt.format(recibido)}'),
        pw.Container(
          width:   double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin:  const pw.EdgeInsets.only(top: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Su vuelto:',
                style: pw.TextStyle(font: fontBold, fontSize: 10, color: _dark)),
              pw.Text('\$${_fmt.format(vuelto)}',
                style: pw.TextStyle(font: fontBold, fontSize: 12, color: _dark)),
            ],
          ),
        ),
      ],
    ]);


  static pw.Widget _footer(
    pw.Font fontBold, pw.Font fontReg, String empresa,
  ) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 6),
        pw.Text('¡Gracias por su compra!',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontBold, fontSize: 11, color: _green)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Para cambios o devoluciones presente\n'
          'este recibo dentro de los próximos 30 días.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500)),
        pw.SizedBox(height: 6),
        pw.Text(empresa,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontBold, fontSize: 8, color: _grey700)),
        pw.SizedBox(height: 4),
      ],
    );


  // ── Helpers compartidos ──────────────────────────────────────

  static pw.Widget _divider() =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Divider(color: _grey300, thickness: 0.5),
    );

  static pw.Widget _filaInfo(
    pw.Font fontBold, pw.Font fontReg,
    String label, String value, {
    bool boldValue = false,
  }) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
            style: pw.TextStyle(font: fontReg, fontSize: 8, color: _grey700)),
          pw.Flexible(
            child: pw.Text(value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  font: boldValue ? fontBold : fontReg,
                  fontSize: 8,
                  color: boldValue ? _dark : _grey700)),
          ),
        ],
      ),
    );

  static pw.Widget _filaTotal(
    pw.Font fontReg, pw.Font fontMono,
    String label, String value, {
    PdfColor? color,
  }) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
            style: pw.TextStyle(font: fontReg, fontSize: 8, color: _grey500)),
          pw.Text(value,
            style: pw.TextStyle(
                font: fontMono, fontSize: 9,
                color: color ?? _grey700)),
        ],
      ),
    );

  static String _metodoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia bancaria';
      case 'tarjeta':       return 'Tarjeta débito / crédito';
      case 'nota_credito':  return 'Nota de crédito';
      default:              return 'Efectivo';
    }
  }
}
