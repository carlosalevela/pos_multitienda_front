// lib/services/recibo_pdf_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/item_carrito.dart';
import '../models/devolucion_model.dart';
import '../models/separado.dart';
import 'documento_service.dart';
import 'windows_printer_service.dart';

class ReciboPdfService {
  // ── Abrir PDF: web → diálogo del navegador / exe → visor predeterminado ──
  static Future<void> _abrirPdf(List<int> bytes, String nombre) async {
    if (kIsWeb) {
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: nombre,
      );
      return;
    }
    // Exe nativo: intentar imprimir directo a la impresora configurada
    final printed = await WindowsPrinterService.printPdf(bytes, nombre);
    if (printed) return;

    // Sin impresora configurada → abrir con el visor PDF del sistema
    // (evita el diálogo nativo de Windows que congela el rendering de Flutter)
    final dir  = await getTemporaryDirectory();
    final safe = nombre.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
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

  // ── Colores ──────────────────────────────────────────────────
  static const _green    = PdfColor.fromInt(0xFF006C49);
  static const _greenBg  = PdfColor.fromInt(0xFFE8FFF4);
  static const _dark     = PdfColor.fromInt(0xFF1A1A2E);
  static const _grey700  = PdfColors.grey700;
  static const _grey500  = PdfColors.grey500;
  static const _grey300  = PdfColors.grey300;
  // Colores para separados
  static const _teal     = PdfColor.fromInt(0xFF01696F);
  static const _tealBg   = PdfColor.fromInt(0xFFCEDCD8);
  static const _amber    = PdfColor.fromInt(0xFFF59E0B);
  static const _amberBg  = PdfColor.fromInt(0xFFFEF3C7);

  // 80 mm receipt — height finita requerida por MultiPage (pdf ≥3.12)
  static final _pageFormat = PdfPageFormat(
    80  * PdfPageFormat.mm,
    1500 * PdfPageFormat.mm,
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
    String                     nit           = '',
    String                     direccion     = '',
    String                     telefono      = '',
    String                     clienteNombre = '',
    bool                       soloGuardar   = false,
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
        _infoTransaccion(fontBold, fontReg, numeroFactura, cajeroNombre, now,
            clienteNombre: clienteNombre),
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

    final bytes = await doc.save();
    unawaited(DocumentoService.instance.guardarVenta(
      bytes: bytes, numeroFactura: numeroFactura,
    ));
    if (soloGuardar) return;
    await _abrirPdf(bytes, 'Recibo_$numeroFactura.pdf');
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
    String factura, String cajero, DateTime now, {
    String clienteNombre = '',
  }) {
    final fecha  = DateFormat('dd/MM/yyyy').format(now);
    final hora   = DateFormat('HH:mm:ss').format(now);

    return pw.Column(children: [
      _filaInfo(fontBold, fontReg, 'N° Factura:', factura, boldValue: true),
      _filaInfo(fontBold, fontReg, 'Fecha:',      fecha),
      _filaInfo(fontBold, fontReg, 'Hora:',       hora),
      _filaInfo(fontBold, fontReg, 'Cajero:',     cajero),
      if (clienteNombre.isNotEmpty)
        _filaInfo(fontBold, fontReg, 'Cliente:',  clienteNombre),
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

  // ─────────────────────────────────────────────────────────────────────
  //  COMPROBANTE DE DEVOLUCIÓN / CAMBIO
  // ─────────────────────────────────────────────────────────────────────

  static Future<void> imprimirComprobanteDevolucion({
    required DevolucionModel dev,
    required String          empresaNombre,
    String                   nit       = '',
    String                   direccion = '',
    String                   telefono  = '',
  }) async {
    final fontReg  = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMono = await PdfGoogleFonts.sourceCodeProRegular();

    final esCambio   = dev.tipo == 'cambio';
    final titulo     = esCambio ? 'COMPROBANTE DE CAMBIO' : 'COMPROBANTE DE DEVOLUCIÓN';
    final devId      = 'DEV-${dev.id}';
    final fecha      = DateFormat('dd/MM/yyyy').format(dev.createdAt);
    final hora       = DateFormat('HH:mm:ss').format(dev.createdAt);
    final tipoDif    = (dev.tipoDiferencia ?? 'exacto').toLowerCase();

    const orange   = PdfColor.fromInt(0xFFF59E0B);
    const orangeBg = PdfColor.fromInt(0xFFFEF3C7);

    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: _pageFormat,
      build: (ctx) => [
        // ── 1. Encabezado ─────────────────────────────────────
        _encabezado(fontBold, fontReg, empresaNombre, dev.tiendaNombre,
            nit, direccion, telefono),
        _divider(),

        // ── 2. Título ──────────────────────────────────────────
        pw.Center(
          child: pw.Text(titulo,
            style: pw.TextStyle(
                font: fontBold, fontSize: 9,
                color: esCambio ? _green : orange,
                letterSpacing: 1.2)),
        ),
        _divider(),

        // ── 3. Info comprobante ────────────────────────────────
        _filaInfo(fontBold, fontReg, 'N° Comprobante:', devId, boldValue: true),
        _filaInfo(fontBold, fontReg, 'Fact. original:', dev.ventaNumero),
        _filaInfo(fontBold, fontReg, 'Empleado:',       dev.empleadoNombre),
        _filaInfo(fontBold, fontReg, 'Fecha:',          fecha),
        _filaInfo(fontBold, fontReg, 'Hora:',           hora),
        _divider(),

        // ── 4. Productos devueltos ─────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            esCambio ? 'PRODUCTOS RECIBIDOS' : 'PRODUCTOS DEVUELTOS',
            style: pw.TextStyle(font: fontBold, fontSize: 7,
                color: orange, letterSpacing: 0.8),
          ),
        ),
        pw.SizedBox(height: 2),
        ...dev.detalles.map((d) => _detalleRow(d, fontBold, fontReg)),
        pw.SizedBox(height: 4),
        _divider(),

        // ── 5. Producto entregado (cambio) ─────────────────────
        if (esCambio && dev.productoReemplazoNombre != null) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('PRODUCTO ENTREGADO',
              style: pw.TextStyle(font: fontBold, fontSize: 7,
                  color: _green, letterSpacing: 0.8)),
          ),
          _reemplazoRow(dev, fontBold, fontReg),
          pw.SizedBox(height: 4),
          _divider(),
        ],

        // ── 6. Método y diferencia ─────────────────────────────
        _filaInfo(fontBold, fontReg, 'Método:', _metodoLabel(dev.metodoDevolucion)),
        if (esCambio && tipoDif != 'exacto' && (dev.diferencia ?? 0) > 0) ...[
          _filaInfo(fontBold, fontReg,
            tipoDif == 'cobrar' ? 'Cobrado al cliente:' : 'Devuelto al cliente:',
            '\$${_fmt.format(dev.diferencia ?? 0)}',
          ),
          if (dev.cambioEntregado != null && (dev.cambioEntregado ?? 0) > 0)
            _filaInfo(fontBold, fontReg, 'Cambio entregado:',
                '\$${_fmt.format(dev.cambioEntregado!)}'),
        ],
        if (dev.observaciones.isNotEmpty)
          _filaInfo(fontBold, fontReg, 'Obs.:', dev.observaciones),
        pw.SizedBox(height: 4),

        // ── 7. Total ───────────────────────────────────────────
        pw.Container(
          width:   double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            color: esCambio ? _greenBg : orangeBg,
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(esCambio ? 'VALOR RECONOCIDO' : 'TOTAL DEVUELTO',
                style: pw.TextStyle(font: fontBold, fontSize: 10,
                    color: esCambio ? _green : orange)),
              pw.Text('\$${_fmt.format(dev.totalDevuelto)}',
                style: pw.TextStyle(font: fontBold, fontSize: 13,
                    color: esCambio ? _green : orange)),
            ],
          ),
        ),
        _divider(),

        // ── 8. Código de barras (DEV-ID) ───────────────────────
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode:  pw.Barcode.code128(),
            data:     devId,
            width:    60 * PdfPageFormat.mm,
            height:   24,
            drawText: false,
            color:    _dark,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(devId,
            style: pw.TextStyle(font: fontMono, fontSize: 8, color: _grey700)),
        ),
        pw.SizedBox(height: 6),
        _divider(),

        // ── 9. Footer ──────────────────────────────────────────
        _footerDevolucion(fontBold, fontReg, empresaNombre, esCambio),
      ],
    ));

    final bytes = await doc.save();
    unawaited(DocumentoService.instance.guardarDevolucion(
      bytes: bytes, referencia: devId,
    ));
    await _abrirPdf(bytes, 'Comprobante_$devId.pdf');
  }

  static pw.Widget _detalleRow(
    DetalleDevolucionModel d,
    pw.Font fontBold,
    pw.Font fontReg,
  ) {
    final cantStr = d.cantidad % 1 == 0
        ? d.cantidad.toStringAsFixed(0)
        : d.cantidad.toStringAsFixed(2);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(d.productoNombre,
              style: pw.TextStyle(font: fontBold, fontSize: 9)),
            pw.Text('$cantStr × \$${_fmt.format(d.precioUnitario)} c/u',
              style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500)),
            if (d.motivo.isNotEmpty)
              pw.Text('Motivo: ${d.motivo}',
                style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500)),
          ]),
        ),
        pw.SizedBox(width: 6),
        pw.Text('\$${_fmt.format(d.subtotal)}',
          style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ]),
    );
  }

  static pw.Widget _reemplazoRow(
    DevolucionModel dev,
    pw.Font fontBold,
    pw.Font fontReg,
  ) {
    final cant = dev.cantidadReemplazo ?? 0;
    final cantStr = cant % 1 == 0 ? cant.toStringAsFixed(0) : cant.toStringAsFixed(2);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(dev.productoReemplazoNombre ?? '',
              style: pw.TextStyle(font: fontBold, fontSize: 9)),
            if (dev.precioReemplazo != null)
              pw.Text('$cantStr × \$${_fmt.format(dev.precioReemplazo!)} c/u',
                style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500)),
          ]),
        ),
        pw.SizedBox(width: 6),
        if (dev.subtotalReemplazo != null)
          pw.Text('\$${_fmt.format(dev.subtotalReemplazo!)}',
            style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ]),
    );
  }

  static pw.Widget _footerDevolucion(
    pw.Font fontBold, pw.Font fontReg,
    String empresa, bool esCambio,
  ) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 6),
        pw.Text(
          esCambio
              ? '¡Gracias por elegir nuestros productos!'
              : 'Devolución procesada exitosamente',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontBold, fontSize: 10, color: _green),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Conserve este comprobante como\nrespaldo de la transacción.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500),
        ),
        pw.SizedBox(height: 6),
        pw.Text(empresa,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontBold, fontSize: 8, color: _grey700)),
        pw.SizedBox(height: 4),
      ],
    );


  // ─────────────────────────────────────────────────────────────────────
  //  FACTURA COMPLETA DE SEPARADO
  // ─────────────────────────────────────────────────────────────────────

  static Future<void> imprimirSeparado({
    required Separado separado,
    required String   empresaNombre,
    bool              soloGuardar = false,
  }) async {
    final fontReg  = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMono = await PdfGoogleFonts.sourceCodeProRegular();
    final sepId    = 'SEP-${separado.id}';

    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: _pageFormat,
      build: (ctx) => [
        // ── 1. Encabezado ─────────────────────────────────────
        _encabezado(fontBold, fontReg, empresaNombre,
            separado.tiendaNombre, '', '', ''),
        _divider(),

        // ── 2. Título ──────────────────────────────────────────
        pw.Center(
          child: pw.Text('SEPARADO DE MERCANCÍA',
            style: pw.TextStyle(font: fontBold, fontSize: 9,
                color: _teal, letterSpacing: 1.5)),
        ),
        _divider(),

        // ── 3. Info del separado ───────────────────────────────
        _filaInfo(fontBold, fontReg, 'N° Separado:', sepId, boldValue: true),
        _filaInfo(fontBold, fontReg, 'Fecha:',
            DateFormat('dd/MM/yyyy HH:mm').format(separado.createdAt)),
        if (separado.fechaLimite != null)
          _filaInfo(fontBold, fontReg, 'Límite pago:', _formatFecha(separado.fechaLimite!)),
        if (separado.empleadoNombre != null)
          _filaInfo(fontBold, fontReg, 'Atendido por:', separado.empleadoNombre!),
        _divider(),

        // ── 4. Cliente ─────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text('CLIENTE',
            style: pw.TextStyle(font: fontBold, fontSize: 7,
                color: _grey500, letterSpacing: 0.8)),
        ),
        pw.Text(separado.clienteNombre,
          style: pw.TextStyle(font: fontBold, fontSize: 10, color: _dark)),
        if (separado.clienteCedulaNit != null &&
            separado.clienteCedulaNit!.isNotEmpty)
          pw.Text('C.C./NIT: ${separado.clienteCedulaNit}',
            style: pw.TextStyle(font: fontReg, fontSize: 8, color: _grey700)),
        if (separado.clienteTelefono != null &&
            separado.clienteTelefono!.isNotEmpty)
          pw.Text('Tel: ${separado.clienteTelefono}',
            style: pw.TextStyle(font: fontReg, fontSize: 8, color: _grey700)),
        _divider(),

        // ── 5. Productos ───────────────────────────────────────
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
        ...separado.detalles.map((d) => _detalleSeparadoRow(d, fontBold, fontReg)),
        pw.SizedBox(height: 4),

        // Total separado (verde)
        pw.Container(
          width:   double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(color: _tealBg),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL SEPARADO',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: _teal)),
              pw.Text('\$${_fmt.format(separado.total)}',
                style: pw.TextStyle(font: fontBold, fontSize: 13, color: _teal)),
            ],
          ),
        ),
        _divider(),

        // ── 6. Abonos ──────────────────────────────────────────
        if (separado.abonos.isNotEmpty) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('ABONOS REGISTRADOS',
              style: pw.TextStyle(font: fontBold, fontSize: 7,
                  color: _grey500, letterSpacing: 0.8)),
          ),
          ...separado.abonos.map((a) => _abonoRow(a, fontBold, fontReg)),
          pw.SizedBox(height: 2),
          _filaTotal(fontReg, fontMono, 'Total abonado:',
              '\$${_fmt.format(separado.abonoAcumulado)}',
              color: _teal),
          pw.SizedBox(height: 4),
        ],

        // Saldo pendiente
        pw.Container(
          width:   double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: separado.saldoPendiente > 0 ? _amberBg : _greenBg,
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                separado.saldoPendiente > 0 ? 'SALDO PENDIENTE' : '¡SEPARADO PAGADO!',
                style: pw.TextStyle(font: fontBold, fontSize: 10,
                    color: separado.saldoPendiente > 0 ? _amber : _green)),
              pw.Text('\$${_fmt.format(separado.saldoPendiente)}',
                style: pw.TextStyle(font: fontBold, fontSize: 13,
                    color: separado.saldoPendiente > 0 ? _amber : _green)),
            ],
          ),
        ),
        _divider(),

        // ── 7. Código de barras ────────────────────────────────
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data:    sepId,
            width:   65 * PdfPageFormat.mm,
            height:  28,
            drawText: false,
            color:   _dark,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(sepId,
            style: pw.TextStyle(font: fontMono, fontSize: 8, color: _grey700)),
        ),
        pw.SizedBox(height: 6),
        _divider(),

        // ── 8. Footer ──────────────────────────────────────────
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(height: 4),
            pw.Text('Conserve este comprobante',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: _teal)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Presente este documento al momento\n'
              'de realizar abonos o retirar su mercancía.',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500)),
            pw.SizedBox(height: 6),
            pw.Text(empresaNombre,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: _grey700)),
            pw.SizedBox(height: 4),
          ],
        ),
      ],
    ));

    final bytes = await doc.save();
    unawaited(DocumentoService.instance.guardarSeparado(
      bytes: bytes, numeroSeparado: sepId,
    ));
    if (soloGuardar) return;
    await _abrirPdf(bytes, 'Separado_$sepId.pdf');
  }


  // ─────────────────────────────────────────────────────────────────────
  //  RECIBO DE ABONO (compacto)
  // ─────────────────────────────────────────────────────────────────────

  static Future<void> imprimirReciboAbono({
    required Separado separado,
    required double   monto,
    required String   metodoPago,
    required String   empresaNombre,
  }) async {
    final fontReg  = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMono = await PdfGoogleFonts.sourceCodeProRegular();
    final sepId    = 'SEP-${separado.id}';
    final now      = DateTime.now();
    final nuevoSaldo = (separado.saldoPendiente - monto).clamp(0.0, double.infinity);

    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: _pageFormat,
      build: (ctx) => [
        // ── 1. Encabezado ─────────────────────────────────────
        _encabezado(fontBold, fontReg, empresaNombre,
            separado.tiendaNombre, '', '', ''),
        _divider(),

        // ── 2. Título ──────────────────────────────────────────
        pw.Center(
          child: pw.Text('RECIBO DE ABONO',
            style: pw.TextStyle(font: fontBold, fontSize: 9,
                color: _teal, letterSpacing: 1.5)),
        ),
        _divider(),

        // ── 3. Info ────────────────────────────────────────────
        _filaInfo(fontBold, fontReg, 'N° Separado:', sepId, boldValue: true),
        _filaInfo(fontBold, fontReg, 'Fecha:', DateFormat('dd/MM/yyyy').format(now)),
        _filaInfo(fontBold, fontReg, 'Hora:', DateFormat('HH:mm:ss').format(now)),
        _divider(),

        // ── 4. Cliente ─────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text('CLIENTE',
            style: pw.TextStyle(font: fontBold, fontSize: 7,
                color: _grey500, letterSpacing: 0.8)),
        ),
        pw.Text(separado.clienteNombre,
          style: pw.TextStyle(font: fontBold, fontSize: 10, color: _dark)),
        _divider(),

        // ── 5. Monto abonado ───────────────────────────────────
        pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('ABONO RECIBIDO',
                style: pw.TextStyle(font: fontBold, fontSize: 8,
                    color: _grey500, letterSpacing: 0.8)),
              pw.SizedBox(height: 6),
              pw.Text('\$${_fmt.format(monto)}',
                style: pw.TextStyle(font: fontBold, fontSize: 22, color: _teal)),
              pw.SizedBox(height: 4),
              pw.Text('Método: ${_metodoLabel(metodoPago)}',
                style: pw.TextStyle(font: fontReg, fontSize: 9, color: _grey700)),
            ],
          ),
        ),
        _divider(),

        // ── 6. Resumen saldo ───────────────────────────────────
        _filaTotal(fontReg, fontMono, 'Total separado:',
            '\$${_fmt.format(separado.total)}'),
        _filaTotal(fontReg, fontMono, 'Abono anterior:',
            '\$${_fmt.format(separado.abonoAcumulado)}'),
        _filaTotal(fontReg, fontMono, 'Este abono:',
            '\$${_fmt.format(monto)}', color: _teal),
        pw.SizedBox(height: 4),
        pw.Container(
          width:   double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: nuevoSaldo > 0 ? _amberBg : _greenBg,
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                nuevoSaldo > 0 ? 'NUEVO SALDO' : '¡SEPARADO PAGADO!',
                style: pw.TextStyle(font: fontBold, fontSize: 10,
                    color: nuevoSaldo > 0 ? _amber : _green)),
              pw.Text('\$${_fmt.format(nuevoSaldo)}',
                style: pw.TextStyle(font: fontBold, fontSize: 13,
                    color: nuevoSaldo > 0 ? _amber : _green)),
            ],
          ),
        ),
        _divider(),

        // ── 7. Código de barras ────────────────────────────────
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data:    sepId,
            width:   65 * PdfPageFormat.mm,
            height:  24,
            drawText: false,
            color:   _dark,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(sepId,
            style: pw.TextStyle(font: fontMono, fontSize: 8, color: _grey700)),
        ),
        _divider(),

        // ── 8. Footer ──────────────────────────────────────────
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(height: 4),
            pw.Text('Conserve este recibo de abono',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: _teal)),
            pw.SizedBox(height: 6),
            pw.Text(empresaNombre,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: _grey700)),
            pw.SizedBox(height: 4),
          ],
        ),
      ],
    ));

    final bytes = await doc.save();
    unawaited(DocumentoService.instance.guardarAbono(
      bytes: bytes, referencia: '${sepId}_${DateTime.now().millisecondsSinceEpoch}',
    ));
    await _abrirPdf(bytes, 'Abono_$sepId.pdf');
  }


  // ── Helpers para separados ───────────────────────────────────

  static pw.Widget _detalleSeparadoRow(
    DetalleSeparado d,
    pw.Font fontBold,
    pw.Font fontReg,
  ) {
    final cantStr = d.cantidad % 1 == 0
        ? d.cantidad.toStringAsFixed(0)
        : d.cantidad.toStringAsFixed(2);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(d.productoNombre,
              style: pw.TextStyle(font: fontBold, fontSize: 9)),
            pw.Text('$cantStr × \$${_fmt.format(d.precioUnitario)} c/u',
              style: pw.TextStyle(font: fontReg, fontSize: 7, color: _grey500)),
          ]),
        ),
        pw.SizedBox(width: 8),
        pw.Text('\$${_fmt.format(d.subtotal)}',
          style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ]),
    );
  }

  static pw.Widget _abonoRow(
    AbonoSeparado a,
    pw.Font fontBold,
    pw.Font fontReg,
  ) {
    final fechaStr = DateFormat('dd/MM/yy').format(a.createdAt);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Text('$fechaStr · ${_metodoLabel(a.metodoPago)}',
            style: pw.TextStyle(font: fontReg, fontSize: 8, color: _grey700)),
        ),
        pw.Text('\$${_fmt.format(a.monto)}',
          style: pw.TextStyle(font: fontBold, fontSize: 9)),
      ]),
    );
  }

  static String _formatFecha(String isoDate) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }
}
