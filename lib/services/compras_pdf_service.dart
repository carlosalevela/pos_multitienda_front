// lib/services/compras_pdf_service.dart
//
// Genera PDFs de Órdenes de Compra y Recibos de Recepción.
// Los guarda localmente en DocumentoService y los abre en el visor del sistema.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'documento_service.dart';

// ── Paleta (misma que el proyecto) ───────────────────────────
const _pGreen      = PdfColor.fromInt(0xFF006C49);
const _pGreenLight = PdfColor.fromInt(0xFFB7F5D9);
const _pMint       = PdfColor.fromInt(0xFF6CF8BB);
const _pNavy       = PdfColor.fromInt(0xFF131B2E);
const _pOnSurf     = PdfColor.fromInt(0xFF191C1E);
const _pOnVar      = PdfColor.fromInt(0xFF45464D);
const _pOutline    = PdfColor.fromInt(0xFF76777D);
const _pOutVar     = PdfColor.fromInt(0xFFC6C6CD);
const _pSurfLow    = PdfColor.fromInt(0xFFF2F4F6);
const _pSurfHigh   = PdfColor.fromInt(0xFFECEEF0);
const _pWhite      = PdfColors.white;
const _pRed        = PdfColor.fromInt(0xFFBA1A1A);
const _pRedCont    = PdfColor.fromInt(0xFFFFDAD6);
const _pAmber      = PdfColor.fromInt(0xFFF59E0B);
const _pAmberCont  = PdfColor.fromInt(0xFFFEF3C7);

// ── Formatters ────────────────────────────────────────────────
final _numFmt = NumberFormat('#,##0', 'en_US');
String _m(double v) => '\$${_numFmt.format(v.abs())}';
String _fmtFecha(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd/MM/yyyy').format(d);
  } catch (_) {
    return iso.length >= 10 ? iso.substring(0, 10) : iso;
  }
}

class ComprasPDFService {
  ComprasPDFService._();
  static final instance = ComprasPDFService._();

  // ── Orden de Compra ───────────────────────────────────────

  /// Genera, guarda y abre el PDF de una orden de compra.
  /// [compra] es el Map devuelto por la API después de crear la orden.
  Future<void> abrirOrdenCompra(Map<String, dynamic> compra) async {
    final bytes = await _buildOrdenCompra(compra);
    final numero = compra['numero_orden']?.toString() ?? 'OC';
    await DocumentoService.instance.guardarOrdenCompra(
      bytes: bytes, numeroOrden: numero);
    await _abrir(bytes, 'orden_compra_$numero.pdf');
  }

  // ── Recibo de Recepción ───────────────────────────────────

  /// Genera, guarda y abre el recibo de recepción.
  /// [compra] es el Map de la orden. [resultado] es el Map devuelto por
  /// RecibirCompraView (tiene 'productos', 'tienda', 'detail').
  Future<void> abrirRecepcion({
    required Map<String, dynamic> compra,
    required Map<String, dynamic> resultado,
  }) async {
    final bytes = await _buildRecepcion(compra, resultado);
    final numero = compra['numero_orden']?.toString() ?? 'OC';
    await DocumentoService.instance.guardarRecepcion(
      bytes: bytes, numeroOrden: numero);
    await _abrir(bytes, 'recepcion_$numero.pdf');
  }

  // ─────────────────────────── GENERADORES ─────────────────

  Future<List<int>> _buildOrdenCompra(Map<String, dynamic> compra) async {
    final doc = pw.Document();
    final detalles = (compra['detalles'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final total =
        double.tryParse(compra['total']?.toString() ?? '0') ?? 0;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildHeaderOrden(compra),
          pw.SizedBox(height: 18),
          _buildInfoOrden(compra),
          pw.SizedBox(height: 18),
          _buildTablaProductos(detalles),
          pw.SizedBox(height: 10),
          _buildTotalRow(total),
          pw.SizedBox(height: 20),
          if ((compra['observaciones']?.toString() ?? '').isNotEmpty)
            _buildObservaciones(compra['observaciones'].toString()),
          pw.Spacer(),
          _buildFooterOrden(compra),
        ],
      ),
    ));
    return doc.save();
  }

  Future<List<int>> _buildRecepcion(
    Map<String, dynamic> compra,
    Map<String, dynamic> resultado,
  ) async {
    final doc = pw.Document();
    final productos = (resultado['productos'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final total =
        double.tryParse(compra['total']?.toString() ?? '0') ?? 0;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildHeaderRecepcion(compra),
          pw.SizedBox(height: 18),
          _buildInfoRecepcion(compra, resultado),
          pw.SizedBox(height: 18),
          _buildTablaRecepcion(productos),
          pw.SizedBox(height: 10),
          _buildTotalRow(total, label: 'Total costo'),
          pw.SizedBox(height: 20),
          _buildSellosRecepcion(),
          pw.Spacer(),
          _buildFooterRecepcion(),
        ],
      ),
    ));
    return doc.save();
  }

  // ─────────────────────────── WIDGETS PDF ─────────────────

  // ── Header orden de compra ────────────────────────────────

  pw.Widget _buildHeaderOrden(Map<String, dynamic> compra) {
    final numero  = compra['numero_orden']?.toString() ?? '—';
    final fecha   = _fmtFecha(compra['fecha_orden']?.toString());

    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _pNavy,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ORDEN DE COMPRA',
                  style: pw.TextStyle(
                    color: _pMint,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2.5,
                  )),
              pw.SizedBox(height: 4),
              pw.Text(numero,
                  style: pw.TextStyle(
                    color: _pWhite,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  )),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _estadoChipPdf('pendiente'),
              pw.SizedBox(height: 6),
              pw.Text(fecha,
                  style: pw.TextStyle(
                      color: _pOutVar, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildHeaderRecepcion(Map<String, dynamic> compra) {
    final numero = compra['numero_orden']?.toString() ?? '—';
    final fecha  = _fmtFecha(
        (compra['fecha_recepcion'] ?? compra['fecha_orden'])?.toString());

    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _pGreen,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('RECIBO DE RECEPCIÓN',
                  style: pw.TextStyle(
                    color: _pMint,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2.5,
                  )),
              pw.SizedBox(height: 4),
              pw.Text(numero,
                  style: pw.TextStyle(
                    color: _pWhite,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  )),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _estadoChipPdf('recibida'),
              pw.SizedBox(height: 6),
              pw.Text('Recepción: $fecha',
                  style: pw.TextStyle(
                      color: _pGreenLight, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sección info ──────────────────────────────────────────

  pw.Widget _buildInfoOrden(Map<String, dynamic> compra) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _pSurfLow,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _pOutVar),
      ),
      padding: const pw.EdgeInsets.all(14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoSection('PROVEEDOR'),
              _infoVal(compra['proveedor_nombre']),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoSection('SUCURSAL'),
              _infoVal(compra['tienda_nombre']),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoSection('SOLICITADO POR'),
              _infoVal(compra['empleado_nombre']),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoSection('FECHA'),
              _infoVal(_fmtFecha(compra['fecha_orden']?.toString())),
            ],
          )),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRecepcion(
    Map<String, dynamic> compra,
    Map<String, dynamic> resultado,
  ) {
    final tienda  = resultado['tienda']?.toString() ?? compra['tienda_nombre'] ?? '—';
    final fechaRec = _fmtFecha(
        (compra['fecha_recepcion'] ?? compra['fecha_orden'])?.toString());

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _pSurfLow,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _pOutVar),
      ),
      padding: const pw.EdgeInsets.all(14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoSection('PROVEEDOR'),
              _infoVal(compra['proveedor_nombre']),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoSection('SUCURSAL'),
              _infoVal(tienda),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoSection('RECIBIDO POR'),
              _infoVal(compra['empleado_nombre']),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoSection('FECHA RECEPCIÓN'),
              _infoVal(fechaRec),
            ],
          )),
        ],
      ),
    );
  }

  // ── Tabla productos (orden de compra) ─────────────────────

  pw.Widget _buildTablaProductos(List<Map<String, dynamic>> detalles) {
    const headerBg = _pNavy;
    const altBg    = _pSurfLow;

    return pw.Table(
      border: pw.TableBorder.all(color: _pOutVar, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(24),         // #
        1: pw.FlexColumnWidth(3.5),         // Producto
        2: pw.FlexColumnWidth(2),           // Categoría
        3: pw.FixedColumnWidth(50),         // Cant.
        4: pw.FixedColumnWidth(70),         // P. Costo
        5: pw.FixedColumnWidth(75),         // Subtotal
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: headerBg),
          children: [
            _th('#'),
            _th('PRODUCTO'),
            _th('CATEGORÍA'),
            _th('CANT.'),
            _th('P. COSTO'),
            _th('SUBTOTAL'),
          ],
        ),
        // Filas
        ...detalles.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          final nombre   = d['producto_nombre'] ?? d['nombre_libre'] ?? '—';
          final cat      = d['categoria_nombre']?.toString() ?? '—';
          final cantidad = double.tryParse(d['cantidad'].toString()) ?? 0;
          final precio   = double.tryParse(d['precio_unitario'].toString()) ?? 0;
          final sub      = double.tryParse(d['subtotal']?.toString() ?? '0') ?? (cantidad * precio);
          final bg = i.isOdd ? altBg : _pWhite;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _td('${i + 1}', align: pw.TextAlign.center),
              _td(nombre.toString()),
              _td(cat),
              _td(_fmtCant(cantidad), align: pw.TextAlign.center),
              _td(_m(precio), align: pw.TextAlign.right),
              _tdBold(_m(sub), align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  // ── Tabla recepción ───────────────────────────────────────

  pw.Widget _buildTablaRecepcion(List<Map<String, dynamic>> productos) {
    const headerBg = _pGreen;
    const altBg    = _pSurfLow;

    if (productos.isEmpty) {
      return pw.Container(
        color: _pSurfLow,
        padding: const pw.EdgeInsets.all(12),
        child: pw.Text('Sin detalle de productos disponible.',
            style: pw.TextStyle(color: _pOutline, fontSize: 10)),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _pOutVar, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),         // #
        1: pw.FlexColumnWidth(3.5),         // Producto
        2: pw.FixedColumnWidth(45),         // Cant.
        3: pw.FixedColumnWidth(68),         // P. Costo
        4: pw.FixedColumnWidth(68),         // P. Venta
        5: pw.FixedColumnWidth(68),         // Stock
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: headerBg),
          children: [
            _th('#'),
            _th('PRODUCTO'),
            _th('CANT.'),
            _th('P. COSTO'),
            _th('P. VENTA'),
            _th('STOCK'),
          ],
        ),
        ...productos.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final nombre   = p['producto']?.toString() ?? '—';
          final cantidad = double.tryParse(p['cantidad_recibida']?.toString() ?? '0') ?? 0;
          final costo    = double.tryParse(p['precio_compra']?.toString() ?? '0') ?? 0;
          final venta    = double.tryParse(p['precio_venta']?.toString() ?? '0') ?? 0;
          final stock    = double.tryParse(p['stock_actual']?.toString() ?? '0') ?? 0;
          final bg = i.isOdd ? altBg : _pWhite;
          final esNuevo  = p['es_nuevo'] as bool? ?? false;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _td('${i + 1}', align: pw.TextAlign.center),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(nombre,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _pOnSurf)),
                    if (esNuevo)
                      pw.Text('★ Producto nuevo',
                          style: pw.TextStyle(
                              fontSize: 7.5, color: _pGreen)),
                  ],
                ),
              ),
              _td(_fmtCant(cantidad), align: pw.TextAlign.center),
              _td(_m(costo), align: pw.TextAlign.right),
              _tdBold(_m(venta), align: pw.TextAlign.right),
              _td(_fmtCant(stock), align: pw.TextAlign.center),
            ],
          );
        }),
      ],
    );
  }

  // ── Total ─────────────────────────────────────────────────

  pw.Widget _buildTotalRow(double total, {String label = 'Total'}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _pNavy,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: pw.Row(children: [
            pw.Text('$label: ',
                style: pw.TextStyle(
                    color: _pOutVar, fontSize: 11)),
            pw.Text(_m(total),
                style: pw.TextStyle(
                    color: _pWhite,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      ],
    );
  }

  // ── Observaciones ─────────────────────────────────────────

  pw.Widget _buildObservaciones(String obs) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _pSurfLow,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _pOutVar),
      ),
      padding: const pw.EdgeInsets.all(10),
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoSection('OBSERVACIONES'),
          pw.SizedBox(height: 4),
          pw.Text(obs,
              style: pw.TextStyle(fontSize: 10, color: _pOnSurf)),
        ],
      ),
    );
  }

  // ── Sellos ────────────────────────────────────────────────

  pw.Widget _buildSellosRecepcion() {
    return pw.Row(children: [
      _sello(
        icon: '✓',
        label: 'RECIBIDA CORRECTAMENTE',
        bg: _pGreenLight,
        fg: _pGreen,
      ),
      pw.SizedBox(width: 12),
      _sello(
        icon: '📦',
        label: 'INVENTARIO ACTUALIZADO',
        bg: _pSurfHigh,
        fg: _pOnVar,
      ),
    ]);
  }

  pw.Widget _sello({
    required String icon,
    required String label,
    required PdfColor bg,
    required PdfColor fg,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: fg),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: pw.Row(children: [
        pw.Text(icon, style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(width: 6),
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: fg,
                letterSpacing: 0.5)),
      ]),
    );
  }

  // ── Footers ───────────────────────────────────────────────

  pw.Widget _buildFooterOrden(Map<String, dynamic> compra) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _pOutVar)),
      ),
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Sistema POS Multitienda',
              style: pw.TextStyle(color: _pOutline, fontSize: 8)),
          pw.Text(
              'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(color: _pOutline, fontSize: 8)),
          pw.Text(compra['numero_orden']?.toString() ?? '',
              style: pw.TextStyle(color: _pOutline, fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _buildFooterRecepcion() {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _pOutVar)),
      ),
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Sistema POS Multitienda',
              style: pw.TextStyle(color: _pOutline, fontSize: 8)),
          pw.Text(
              'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(color: _pOutline, fontSize: 8)),
          pw.Text('Este documento es un comprobante interno.',
              style: pw.TextStyle(color: _pOutline, fontSize: 8)),
        ],
      ),
    );
  }

  // ── Atom helpers ──────────────────────────────────────────

  pw.Widget _estadoChipPdf(String estado) {
    late PdfColor bg, fg;
    late String label;
    switch (estado) {
      case 'pendiente':
        bg = _pAmberCont; fg = _pAmber; label = 'PENDIENTE';
        break;
      case 'recibida':
        bg = _pGreenLight; fg = _pGreen; label = 'RECIBIDA';
        break;
      case 'cancelada':
        bg = _pRedCont; fg = _pRed; label = 'CANCELADA';
        break;
      default:
        bg = _pSurfLow; fg = _pOutline; label = estado.toUpperCase();
    }
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: pw.Text(label,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: fg,
              letterSpacing: 1)),
    );
  }

  pw.Widget _infoSection(String label) => pw.Text(label,
      style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: _pOutline,
          letterSpacing: 1));

  pw.Widget _infoVal(dynamic v) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 3),
    child: pw.Text(
        v?.toString().isNotEmpty == true ? v.toString() : '—',
        style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _pOnSurf)),
  );

  pw.Widget _th(String text, {PdfColor color = _pWhite}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: color,
            letterSpacing: 0.5)),
  );

  pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(fontSize: 9, color: _pOnSurf)),
      );

  pw.Widget _tdBold(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _pOnSurf)),
      );

  String _fmtCant(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(1);

  // ── Abrir en visor ────────────────────────────────────────

  Future<void> _abrir(List<int> bytes, String nombre) async {
    if (kIsWeb) {
      await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes), filename: nombre);
      return;
    }
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
}
