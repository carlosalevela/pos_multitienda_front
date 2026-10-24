// lib/screens/caja/widgets/pdf/cierre_pdf.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../models/sesion_historial.dart';
import '../../../../services/caja_service.dart';
import '../../../../services/documento_service.dart';
import '../../../../services/thermal_printer_service.dart';
import '../../../../services/windows_printer_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

Future<void> _abrirPdf(List<int> bytes, String nombre) async {
  if (kIsWeb) {
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: nombre);
    return;
  }
  final printed = await WindowsPrinterService.printPdf(bytes, nombre);
  if (printed) return;

  final dir  = await getTemporaryDirectory();
  final safe = nombre.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${dir.path}${Platform.pathSeparator}$safe');
  await file.writeAsBytes(bytes);
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', file.path]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [file.path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [file.path]);
  } else {
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: nombre);
  }
}

// ── Palette ───────────────────────────────────────────────
const _pGreen      = PdfColor.fromInt(0xFF006C49);
const _pGreenLight = PdfColor.fromInt(0xFFB7F5D9);
const _pNavy       = PdfColor.fromInt(0xFF131B2E);
const _pNavyMuted  = PdfColor.fromInt(0xFF7C839B);
const _pRed        = PdfColor.fromInt(0xFFBA1A1A);
const _pRedCont    = PdfColor.fromInt(0xFFFFDAD6);
const _pOnSurf     = PdfColor.fromInt(0xFF191C1E);
const _pOnVar      = PdfColor.fromInt(0xFF45464D);
const _pOutline    = PdfColor.fromInt(0xFF76777D);
const _pOutVar     = PdfColor.fromInt(0xFFC6C6CD);
const _pSurfLow    = PdfColor.fromInt(0xFFF2F4F6);
const _pWhite      = PdfColors.white;

// ── Formatters ────────────────────────────────────────────
final _numFmt = NumberFormat('#,##0.00', 'en_US');
String _m(double v) => '\$${_numFmt.format(v.abs())}';

const _meses = [
  '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
];

String _fecha(String raw) {
  if (raw.isEmpty) return '--';
  try {
    final dt = DateTime.parse(raw.replaceAll(' ', 'T')).toLocal();
    return '${dt.day.toString().padLeft(2,'0')} ${_meses[dt.month]} ${dt.year}';
  } catch (_) { return raw.length >= 10 ? raw.substring(0, 10) : raw; }
}

String _hora(String raw) {
  if (raw.isEmpty) return '--';
  try {
    final dt = DateTime.parse(raw.replaceAll(' ', 'T')).toLocal();
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  } catch (_) { return '--'; }
}

// ════════════════════════════════════════════════════════
// ENTRY POINTS
// ════════════════════════════════════════════════════════

Future<Uint8List> generarBytesCierrePDF(SesionHistorial sesion) async {
  final doc = pw.Document(
    author:  sesion.empleadoNombre,
    title:   'Cierre de Caja #${sesion.id}',
    creator: 'POS Master',
  );

  final esExacto   = sesion.diferencia.abs() < 0.01;
  final esPositivo = sesion.diferencia >= 0;
  final difColor   = (esExacto || esPositivo) ? _pGreen : _pRed;
  final difBg      = (esExacto || esPositivo) ? _pGreenLight : _pRedCont;
  final difLabel   = esExacto ? 'CUADRE EXACTO' : esPositivo ? 'SOBRANTE' : 'FALTANTE';
  final difStr     = esExacto
      ? '\$0.00'
      : '${esPositivo ? '+' : '-'}${_m(sesion.diferencia)}';

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin:     const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
    header:     (_) => _header(sesion),
    footer:     (ctx) => _footer(sesion, ctx),
    build:      (_) => [
      pw.SizedBox(height: 16),

      // 1. Cuatro métricas clave
      _topMetrics4(sesion, difColor, difBg, difLabel, difStr),
      pw.SizedBox(height: 24),

      // 2. INGRESOS UNIFICADOS: ventas + abonos por cuenta/método
      _sectionLabel('Ingresos del Turno por Cuenta / Método de Pago'),
      pw.SizedBox(height: 8),
      _ingresosUnificadosTable(sesion),
      pw.SizedBox(height: 22),

      // 3. Acumulado histórico por cuenta bancaria (si hay)
      if (sesion.cuentasResumen.isNotEmpty) ...[
        _sectionLabel('Acumulado Histórico por Cuenta Bancaria'),
        pw.SizedBox(height: 8),
        _cuentasAcumuladoTable(sesion),
        pw.SizedBox(height: 22),
      ],

      // 4. Detalle de ventas individuales (si hay)
      if (sesion.ventasDetalle.isNotEmpty) ...[
        _sectionLabel('Detalle de Ventas del Turno'),
        pw.SizedBox(height: 8),
        _ventasDetalleTable(sesion),
        pw.SizedBox(height: 22),
      ],

      // 5. Gastos (si hay)
      if (sesion.gastosTotal > 0) ...[
        _sectionLabel('Gastos del Turno'),
        pw.SizedBox(height: 8),
        _gastosDetalleTable(sesion),
        pw.SizedBox(height: 22),
      ],

      // 6. Devoluciones (si hay)
      if (sesion.numDevoluciones > 0) ...[
        _sectionLabel('Devoluciones y Cambios'),
        pw.SizedBox(height: 8),
        _devolucionesDetail(sesion),
        pw.SizedBox(height: 22),
      ],

      // 7. Cuadre de efectivo
      _sectionLabel('Cuadre de Efectivo'),
      pw.SizedBox(height: 8),
      _cuadreCard(sesion, difColor, difBg, difLabel, difStr),
      pw.SizedBox(height: 22),

      // 8. Observaciones (si hay)
      if (sesion.observaciones.isNotEmpty) ...[
        _sectionLabel('Observaciones'),
        pw.SizedBox(height: 8),
        _notaSection(sesion.observaciones),
        pw.SizedBox(height: 22),
      ],

      // 9. Firmas
      pw.SizedBox(height: 20),
      _firmaRow(sesion.empleadoNombre),
    ],
  ));

  return await doc.save();
}

Future<void> exportarCierrePDF(
  SesionHistorial sesion, {
  String tipoPapel = '80mm',
  BuildContext? context,
}) async {
  final fecha = sesion.fechaCierre.isNotEmpty
      ? sesion.fechaCierre.substring(0, 10)
      : sesion.fechaApertura.substring(0, 10);
  final filename =
      'CIERRE_${sesion.id}_${fecha}_${sesion.tiendaNombre.replaceAll(' ', '_')}.pdf';
  final bytes = await generarBytesCierrePDF(sesion);

  unawaited(CajaService().enviarPdfWhatsApp(sesion.id, bytes, filename));

  unawaited(DocumentoService.instance.guardarCierre(
    bytes: bytes,
    referencia: 'cierre_${sesion.id}_${fecha}_${sesion.tiendaNombre.replaceAll(' ', '_')}',
  ));

  if (tipoPapel != 'pdf') {
    final ps = tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;
    try {
      if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
        final tb = await ThermalPrinterService.buildCierreHistorial(
          sesion: sesion, paperSize: ps,
        );
        await WindowsPrinterService.printRaw(tb);
        return;
      }
      if (ThermalPrinterService.isWebUsbSupported) {
        final dev = await ThermalPrinterService.getOrRequestDevice();
        if (dev != null) {
          final tb = await ThermalPrinterService.buildCierreHistorial(
            sesion: sesion, paperSize: ps,
          );
          await ThermalPrinterService.printBytes(dev, tb);
          return;
        }
        if (context != null && context.mounted) {
          final savedName = await ThermalPrinterService.getSavedName();
          if (context.mounted) {
            final msg = savedName == null
                ? 'No hay impresora térmica configurada. '
                  'Ve a Configuración → Impresión y selecciona la impresora.'
                : 'Impresora "$savedName" no encontrada. Verifica que esté conectada por USB.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(msg),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 5),
            ));
          }
        }
      }
    } catch (_) {}
  }

  await _abrirPdf(bytes, filename);
}

// ════════════════════════════════════════════════════════
// HEADER  (se repite en cada página)
// ════════════════════════════════════════════════════════

pw.Widget _header(SesionHistorial sesion) => pw.Column(children: [
  pw.Row(
    mainAxisAlignment:  pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [

      // ── Izquierda: marca + tienda ─────────────────────
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: 48, height: 48,
          decoration: const pw.BoxDecoration(
            color: _pNavy,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text('POS',
              style: pw.TextStyle(
                  color: _pWhite, fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8)),
        ),
        pw.SizedBox(width: 12),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(sesion.tiendaNombre,
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold,
                  color: _pOnSurf)),
          pw.SizedBox(height: 4),
          pw.Text('Cajero: ${sesion.empleadoNombre}',
              style: pw.TextStyle(fontSize: 8.5, color: _pOnVar)),
          pw.SizedBox(height: 2),
          pw.Text(
            'Apertura: ${_fecha(sesion.fechaApertura)}  ${_hora(sesion.fechaApertura)}',
            style: pw.TextStyle(fontSize: 7.5, color: _pOutline),
          ),
        ]),
      ]),

      // ── Derecha: caja identificadora (estilo factura) ─
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _pNavy, width: 1.2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('REPORTE DE CIERRE',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold,
                    color: _pNavy, letterSpacing: 1.0)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const pw.BoxDecoration(
                color: _pNavy,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text('SESIÓN  #${sesion.id}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold,
                      color: _pWhite, letterSpacing: 0.5)),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Cierre: ${_fecha(sesion.fechaCierre)}  ${_hora(sesion.fechaCierre)}',
              style: pw.TextStyle(fontSize: 7.5, color: _pOnVar),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Generado: ${DateFormat('dd MMM yyyy  HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 7, color: _pOutline),
            ),
          ],
        ),
      ),
    ],
  ),
  pw.SizedBox(height: 12),
  pw.Divider(color: _pNavy, thickness: 1.5),
]);

// ════════════════════════════════════════════════════════
// FOOTER
// ════════════════════════════════════════════════════════

pw.Widget _footer(SesionHistorial sesion, pw.Context ctx) => pw.Column(children: [
  pw.Divider(color: _pOutVar, thickness: 0.5),
  pw.SizedBox(height: 5),
  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
    pw.Text('Sesión #${sesion.id} · ${sesion.tiendaNombre}',
        style: pw.TextStyle(fontSize: 7, color: _pOutline)),
    pw.Text('Generado automáticamente por POS Master',
        style: pw.TextStyle(fontSize: 7, color: _pOutline)),
    pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
        style: pw.TextStyle(fontSize: 7, color: _pOutline)),
  ]),
]);

// ════════════════════════════════════════════════════════
// SECCIÓN LABEL
// ════════════════════════════════════════════════════════

pw.Widget _sectionLabel(String title) => pw.Row(children: [
  pw.Container(
    width: 3, height: 12,
    decoration: const pw.BoxDecoration(
      color: _pGreen,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
  ),
  pw.SizedBox(width: 7),
  pw.Text(title,
      style: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold,
          color: _pOnVar, letterSpacing: 0.4)),
]);

// ════════════════════════════════════════════════════════
// 1. CUATRO MÉTRICAS CLAVE
// ════════════════════════════════════════════════════════

pw.Widget _topMetrics4(
  SesionHistorial s,
  PdfColor difColor, PdfColor difBg,
  String difLabel, String difStr,
) {
  final totalIngresos = s.ventasTotal + s.abonosTotal;
  return pw.Row(children: [
    // Base inicial
    _metricCard('BASE INICIAL', _m(s.saldoInicial),
        sub: 'Apertura: ${_hora(s.fechaApertura)}',
        dark: false, color: _pOnSurf),
    pw.SizedBox(width: 8),
    // Total ventas
    _metricCard('TOTAL VENTAS', _m(s.ventasTotal),
        sub: '${s.numTransacciones} transacciones',
        dark: false, color: _pGreen),
    pw.SizedBox(width: 8),
    // Total ingresos (ventas + abonos)
    _metricCard('TOTAL INGRESOS', _m(totalIngresos),
        sub: '+ ${s.numAbonos} abonos separados',
        dark: true, color: _pWhite),
    pw.SizedBox(width: 8),
    // Cuadre (coloreado según resultado)
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: pw.BoxDecoration(
          color: difBg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: difColor, width: 1.0),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('CUADRE DE CAJA',
                style: pw.TextStyle(
                    fontSize: 7, fontWeight: pw.FontWeight.bold,
                    color: difColor, letterSpacing: 0.4)),
            pw.SizedBox(height: 6),
            pw.Text(difLabel,
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold,
                    color: difColor)),
            if (difStr != '\$0.00') ...[
              pw.SizedBox(height: 3),
              pw.Text(difStr,
                  style: pw.TextStyle(fontSize: 9, color: difColor)),
            ],
            pw.SizedBox(height: 3),
            pw.Text('Ef. contado: ${_m(s.montoFinalReal)}',
                style: pw.TextStyle(fontSize: 7, color: difColor)),
          ],
        ),
      ),
    ),
  ]);
}

pw.Widget _metricCard(String label, String value, {
  String? sub,
  required bool dark,
  required PdfColor color,
}) => pw.Expanded(
  child: pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: pw.BoxDecoration(
      color: dark ? _pNavy : _pSurfLow,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: dark ? null : pw.Border.all(color: _pOutVar, width: 0.6),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label,
          style: pw.TextStyle(
              fontSize: 7, fontWeight: pw.FontWeight.bold,
              color: dark ? _pNavyMuted : _pOutline,
              letterSpacing: 0.4)),
      pw.SizedBox(height: 6),
      pw.Text(value,
          style: pw.TextStyle(
              fontSize: 15, fontWeight: pw.FontWeight.bold, color: color)),
      if (sub != null) ...[
        pw.SizedBox(height: 3),
        pw.Text(sub,
            style: pw.TextStyle(
                fontSize: 7, color: dark ? _pNavyMuted : _pOutline)),
      ],
    ]),
  ),
);

// ════════════════════════════════════════════════════════
// 2. TABLA UNIFICADA DE INGRESOS POR CUENTA
//    Columnas: FUENTE / CUENTA | TIPO | VENTAS | ABONOS | TOTAL
// ════════════════════════════════════════════════════════

pw.Widget _ingresosUnificadosTable(SesionHistorial sesion) {
  // ── 1. Agrupar abonos no-efectivo por cuenta ──
  final Map<String, double> abonosPorCuenta = {};
  for (final a in sesion.abonosDetalle) {
    final metodo = a['metodo_pago']?.toString() ?? '';
    if (metodo == 'efectivo') continue;
    final cuenta = a['cuenta_nombre']?.toString() ?? '';
    final label  = cuenta.isNotEmpty
        ? cuenta
        : (metodo == 'tarjeta' ? 'Datáfono' : 'Transferencia');
    final monto = double.tryParse(a['monto']?.toString() ?? '0') ?? 0.0;
    abonosPorCuenta[label] = (abonosPorCuenta[label] ?? 0) + monto;
  }

  // ── 2. Construir filas ──
  final filas = <_IngFila>[];

  // Efectivo (incluye mixto ef., abonos ef., crédito ef., ingresos manuales)
  final efVentas  = sesion.ventasEfectivo + sesion.ventasMixtoEfectivo;
  final efAbonos  = sesion.abonosEfectivo
                  + sesion.abonosCreditoEfectivo
                  + sesion.ingresosManual
                  - sesion.cancelacionesEfectivo;
  if (efVentas > 0 || efAbonos > 0) {
    filas.add(_IngFila('Efectivo', 'Efectivo', efVentas, efAbonos));
  }

  // Cuentas bancarias (ventas agrupadas por cuenta en cuentasResumen)
  final cuentasVistas = <String>{};
  for (final c in sesion.cuentasResumen) {
    final nombre = c['nombre']?.toString() ?? '—';
    final tipo   = c['tipo_display']?.toString() ?? '';
    final turno  = double.tryParse(c['sesion_total']?.toString() ?? '0') ?? 0.0;
    final abonoCuenta = abonosPorCuenta[nombre] ?? 0.0;
    filas.add(_IngFila(nombre, tipo, turno, abonoCuenta));
    cuentasVistas.add(nombre);
  }

  // Abonos en cuentas que no están en cuentasResumen
  for (final e in abonosPorCuenta.entries) {
    if (!cuentasVistas.contains(e.key) && e.value > 0) {
      filas.add(_IngFila(e.key, 'Transferencia', 0.0, e.value));
    }
  }

  // ── 3. Totales ──
  final totVentas = filas.fold(0.0, (s, f) => s + f.ventas);
  final totAbonos = filas.fold(0.0, (s, f) => s + f.abonos);
  final totGrand  = totVentas + totAbonos;

  final tableBorder = pw.TableBorder(
    top:              pw.BorderSide(color: _pNavy,   width: 1.0),
    bottom:           pw.BorderSide(color: _pOutVar, width: 0.8),
    left:             pw.BorderSide(color: _pOutVar, width: 0.8),
    right:            pw.BorderSide(color: _pOutVar, width: 0.8),
    horizontalInside: pw.BorderSide(color: _pOutVar, width: 0.4),
    verticalInside:   pw.BorderSide(color: _pOutVar, width: 0.4),
  );

  // ── 4. Construir tabla ──
  final rows = <pw.TableRow>[
    // Cabecera
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _pNavy),
      children: [
        _th('FUENTE / CUENTA',  align: pw.TextAlign.left),
        _th('TIPO',             align: pw.TextAlign.center),
        _th('VENTAS',           align: pw.TextAlign.right),
        _th('ABONOS',           align: pw.TextAlign.right),
        _th('TOTAL TURNO',      align: pw.TextAlign.right),
      ],
    ),
    // Filas de datos
    for (int i = 0; i < filas.length; i++)
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isOdd ? _pSurfLow : _pWhite,
        ),
        children: [
          _tdLabel(filas[i].label),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Text(filas[i].tipo,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8.5, color: _pOutline)),
          ),
          _tdNum(filas[i].ventas > 0 ? filas[i].ventas : null),
          _tdNum(filas[i].abonos > 0 ? filas[i].abonos : null),
          _tdNum(filas[i].total, bold: true),
        ],
      ),
    // Fila total
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _pNavy),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text('TOTAL INGRESOS DEL TURNO',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold,
                  color: _pWhite)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text('',
              style: pw.TextStyle(fontSize: 9, color: _pWhite)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(_m(totVentas),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold,
                  color: _pGreenLight)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(_m(totAbonos),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold,
                  color: _pGreenLight)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(_m(totGrand),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold,
                  color: _pGreenLight)),
        ),
      ],
    ),
  ];

  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Table(
      border: tableBorder,
      columnWidths: const {
        0: pw.FlexColumnWidth(2.6),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
      },
      children: rows,
    ),
    if (sesion.ventasMixtoEfectivo > 0)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 5, left: 2),
        child: pw.Text(
          '* Ventas mixto: se registra solo el efectivo recibido; '
          'el resto fue tarjeta/transferencia.',
          style: pw.TextStyle(
              fontSize: 7, color: _pOutline,
              fontStyle: pw.FontStyle.italic),
        ),
      ),
    if (sesion.cancelacionesEfectivo > 0)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 3, left: 2),
        child: pw.Text(
          '* Efectivo incluye cancelaciones de separados descontadas '
          '(${_m(sesion.cancelacionesEfectivo)}).',
          style: pw.TextStyle(
              fontSize: 7, color: _pOutline,
              fontStyle: pw.FontStyle.italic),
        ),
      ),
  ]);
}

// ════════════════════════════════════════════════════════
// 3. ACUMULADO HISTÓRICO POR CUENTA BANCARIA
// ════════════════════════════════════════════════════════

pw.Widget _cuentasAcumuladoTable(SesionHistorial sesion) {
  final cuentas = sesion.cuentasResumen;

  final tableBorder = pw.TableBorder(
    top:              pw.BorderSide(color: _pNavy,   width: 1.0),
    bottom:           pw.BorderSide(color: _pOutVar, width: 0.8),
    left:             pw.BorderSide(color: _pOutVar, width: 0.8),
    right:            pw.BorderSide(color: _pOutVar, width: 0.8),
    horizontalInside: pw.BorderSide(color: _pOutVar, width: 0.4),
    verticalInside:   pw.BorderSide(color: _pOutVar, width: 0.4),
  );

  return pw.Table(
    border: tableBorder,
    columnWidths: const {
      0: pw.FlexColumnWidth(2.8),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _pNavy),
        children: [
          _th('CUENTA'),
          _th('TIPO',         align: pw.TextAlign.center),
          _th('ESTE TURNO',   align: pw.TextAlign.right),
          _th('ACUM. HISTÓRICO', align: pw.TextAlign.right),
        ],
      ),
      ...cuentas.asMap().entries.map((e) {
        final c     = e.value;
        final odd   = e.key.isOdd;
        final nombre = c['nombre']?.toString() ?? '—';
        final tipo   = c['tipo_display']?.toString() ?? '';
        final turno  = double.tryParse(c['sesion_total']?.toString()    ?? '0') ?? 0.0;
        final acum   = double.tryParse(c['total_acumulado']?.toString() ?? '0') ?? 0.0;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: odd ? _pSurfLow : _pWhite),
          children: [
            _tdLabel(nombre),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: pw.Text(tipo,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8.5, color: _pOutline)),
            ),
            _tdNum(turno, bold: true),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: pw.Text(_m(acum),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 9, color: _pOutline)),
            ),
          ],
        );
      }),
    ],
  );
}

// ════════════════════════════════════════════════════════
// 4. DETALLE DE VENTAS
// ════════════════════════════════════════════════════════

pw.Widget _ventasDetalleTable(SesionHistorial sesion) {
  final detalle = sesion.ventasDetalle;

  final tableBorder = pw.TableBorder(
    top:              pw.BorderSide(color: _pNavy,   width: 1.0),
    bottom:           pw.BorderSide(color: _pOutVar, width: 0.8),
    left:             pw.BorderSide(color: _pOutVar, width: 0.8),
    right:            pw.BorderSide(color: _pOutVar, width: 0.8),
    horizontalInside: pw.BorderSide(color: _pOutVar, width: 0.4),
    verticalInside:   pw.BorderSide(color: _pOutVar, width: 0.4),
  );

  String fmtMetodo(String m) {
    if (m == 'efectivo')      return 'Efectivo';
    if (m == 'tarjeta')       return 'Datáfono';
    if (m == 'transferencia') return 'Transf.';
    if (m == 'mixto')         return 'Mixto';
    return m;
  }

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _pNavy),
      children: [
        _th('FACTURA'),
        _th('HORA'),
        _th('CLIENTE'),
        _th('CUENTA / MÉTODO', align: pw.TextAlign.center),
        _th('PRODUCTOS'),
        _th('TOTAL',           align: pw.TextAlign.right),
      ],
    ),
  ];

  if (detalle.isEmpty) {
    rows.add(pw.TableRow(children: [
      _tdLabel('Sin ventas registradas'),
      _tdLabel(''), _tdLabel(''), _tdLabel(''), _tdLabel(''), _tdLabel(''),
    ]));
  } else {
    for (int i = 0; i < detalle.length; i++) {
      final v            = detalle[i];
      final factura      = v['numero_factura']?.toString() ?? '';
      final hora         = v['hora']?.toString() ?? '';
      final cliente      = v['cliente']?.toString() ?? 'Consumidor Final';
      final metodo       = v['metodo_pago']?.toString() ?? '';
      final cuentaNombre = v['cuenta_nombre']?.toString() ?? '';
      final metodoLabel  = cuentaNombre.isNotEmpty ? cuentaNombre : fmtMetodo(metodo);
      final total        = double.tryParse(v['total']?.toString() ?? '0') ?? 0.0;
      final productos    = (v['productos'] as List? ?? [])
          .map((p) => '${p['producto']} ×${(double.tryParse(p['cantidad'].toString()) ?? 0).toStringAsFixed(0)}')
          .join('\n');

      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: i.isOdd ? _pSurfLow : _pWhite),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(factura,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pGreen)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(hora,
                style: pw.TextStyle(fontSize: 8, color: _pOutline)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(cliente,
                style: pw.TextStyle(fontSize: 8, color: _pOnVar)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(metodoLabel,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8, color: _pOnVar)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(productos,
                style: pw.TextStyle(fontSize: 8, color: _pOnVar, lineSpacing: 1.3)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(_m(total),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pOnSurf)),
          ),
        ],
      ));
    }

    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: _pSurfLow),
      children: [
        _tdLabel('TOTAL  (${detalle.length} ventas)', bold: true),
        _tdLabel(''), _tdLabel(''), _tdLabel(''), _tdLabel(''),
        _tdNum(sesion.ventasTotal, bold: true),
      ],
    ));
  }

  return pw.Table(
    border: tableBorder,
    columnWidths: const {
      0: pw.FlexColumnWidth(1.4),
      1: pw.FlexColumnWidth(0.8),
      2: pw.FlexColumnWidth(1.6),
      3: pw.FlexColumnWidth(1.2),
      4: pw.FlexColumnWidth(2.6),
      5: pw.FlexColumnWidth(1.2),
    },
    children: rows,
  );
}

// ════════════════════════════════════════════════════════
// 5. DETALLE DE GASTOS
// ════════════════════════════════════════════════════════

pw.Widget _gastosDetalleTable(SesionHistorial sesion) {
  final detalle = sesion.gastosDetalle;
  final tableBorder = pw.TableBorder(
    top:              pw.BorderSide(color: _pNavy,   width: 1.0),
    bottom:           pw.BorderSide(color: _pOutVar, width: 0.8),
    left:             pw.BorderSide(color: _pOutVar, width: 0.8),
    right:            pw.BorderSide(color: _pOutVar, width: 0.8),
    horizontalInside: pw.BorderSide(color: _pOutVar, width: 0.4),
    verticalInside:   pw.BorderSide(color: _pOutVar, width: 0.4),
  );

  String fmtMetodo(String m) {
    if (m == 'efectivo') return 'Efectivo';
    if (m == 'tarjeta')  return 'Datáfono';
    return 'Transf.';
  }

  return pw.Table(
    border: tableBorder,
    columnWidths: const {
      0: pw.FlexColumnWidth(2.0),
      1: pw.FlexColumnWidth(3.0),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(1.4),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _pNavy),
        children: [
          _th('CATEGORÍA'),
          _th('DESCRIPCIÓN'),
          _th('MÉTODO',  align: pw.TextAlign.center),
          _th('MONTO',   align: pw.TextAlign.right),
        ],
      ),
      if (detalle.isEmpty)
        pw.TableRow(children: [
          _tdLabel('Sin detalle disponible'),
          _tdLabel(''), _tdLabel(''), _tdLabel(''),
        ])
      else
        ...detalle.asMap().entries.map((e) {
          final g   = e.value;
          final odd = e.key.isOdd;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: odd ? _pSurfLow : _pWhite),
            children: [
              _tdLabel((g['categoria'] ?? '').toString()),
              _tdLabel((g['descripcion'] ?? '').toString()),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(fmtMetodo((g['metodo_pago'] ?? '').toString()),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 9, color: _pOnVar)),
              ),
              _tdNum(double.tryParse(g['monto']?.toString() ?? '0') ?? 0.0),
            ],
          );
        }),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _pSurfLow),
        children: [
          _tdLabel('TOTAL GASTOS', bold: true),
          _tdLabel('', bold: false),
          _tdLabel('', bold: false),
          _tdNum(sesion.gastosTotal, bold: true),
        ],
      ),
    ],
  );
}

// ════════════════════════════════════════════════════════
// 6. DEVOLUCIONES
// ════════════════════════════════════════════════════════

pw.Widget _devolucionesDetail(SesionHistorial sesion) {
  final detalle = sesion.devolucionesDetalle;
  final netoMostrar = sesion.devolucionesEfectivo;

  final tableBorder = pw.TableBorder(
    top:              pw.BorderSide(color: _pNavy,   width: 1.0),
    bottom:           pw.BorderSide(color: _pOutVar, width: 0.8),
    left:             pw.BorderSide(color: _pOutVar, width: 0.8),
    right:            pw.BorderSide(color: _pOutVar, width: 0.8),
    horizontalInside: pw.BorderSide(color: _pOutVar, width: 0.4),
    verticalInside:   pw.BorderSide(color: _pOutVar, width: 0.4),
  );

  String fmtMetodo(String m) {
    if (m == 'efectivo')    return 'Efectivo';
    if (m == 'tarjeta')     return 'Datáfono';
    if (m == 'nota_credito') return 'N. Crédito';
    return 'Transf.';
  }

  String fmtTipo(String tipo, String tipoDif) {
    if (tipo == 'devolucion') return 'Devolución';
    if (tipoDif == 'cobrar')  return 'Cambio+Cobro';
    if (tipoDif == 'devolver') return 'Cambio+Dev.';
    return 'Cambio Exacto';
  }

  String fmtImpacto(Map<String, dynamic> d) {
    final tipo    = d['tipo']?.toString() ?? '';
    final tipoDif = d['tipo_diferencia']?.toString() ?? '';
    final dev     = double.tryParse(d['total_devuelto']?.toString() ?? '0') ?? 0;
    final dif     = double.tryParse(d['diferencia']?.toString() ?? '0') ?? 0;
    if (tipo == 'devolucion') return '-${_m(dev)}';
    if (tipoDif == 'cobrar')  return '+${_m(dif)}';
    if (tipoDif == 'devolver') return '-${_m(dif)}';
    return 'Exacto';
  }

  return pw.Table(
    border: tableBorder,
    columnWidths: const {
      0: pw.FlexColumnWidth(1.4),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.6),
      4: pw.FlexColumnWidth(1.2),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _pNavy),
        children: [
          _th('FACTURA'),
          _th('TIPO'),
          _th('MÉTODO'),
          _th('CUENTA / PRODUCTO'),
          _th('IMPACTO', align: pw.TextAlign.right),
        ],
      ),
      if (detalle.isEmpty)
        pw.TableRow(children: [
          _tdLabel('Sin detalle disponible'),
          _tdLabel(''), _tdLabel(''), _tdLabel(''), _tdLabel(''),
        ])
      else
        ...detalle.asMap().entries.map((e) {
          final d       = e.value;
          final odd     = e.key.isOdd;
          final tipo    = d['tipo']?.toString() ?? '';
          final tipoDif = d['tipo_diferencia']?.toString() ?? '';
          final metodo  = d['metodo']?.toString() ?? '';
          final cuenta  = d['cuenta_nombre']?.toString() ?? '';
          final reempl  = d['producto_reemplazo']?.toString() ?? '';
          final factura = d['venta_numero']?.toString() ?? 'DEV-${d['id']}';
          final cuentaLabel = cuenta.isNotEmpty ? cuenta : (reempl.isNotEmpty ? reempl : '—');

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: odd ? _pSurfLow : _pWhite),
            children: [
              _tdLabel(factura),
              _tdLabel(fmtTipo(tipo, tipoDif)),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(fmtMetodo(metodo),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 9, color: _pOnVar)),
              ),
              _tdLabel(cuentaLabel),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(fmtImpacto(d),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 9, color: _pOnSurf)),
              ),
            ],
          );
        }),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _pSurfLow),
        children: [
          _tdLabel('NETO EFECTIVO DEVOLUCIONES (${sesion.numDevoluciones})', bold: true),
          _tdLabel('', bold: false),
          _tdLabel('', bold: false),
          _tdLabel('', bold: false),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Text(_m(-netoMostrar),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pOnSurf)),
          ),
        ],
      ),
    ],
  );
}

// ════════════════════════════════════════════════════════
// 7. CUADRE DE EFECTIVO
// ════════════════════════════════════════════════════════

pw.Widget _cuadreCard(
  SesionHistorial s,
  PdfColor difColor, PdfColor difBg,
  String difLabel, String difStr,
) {
  pw.Widget fila(String label, double v, {bool suma = true, bool bold = false}) {
    final signo  = suma ? '+' : '-';
    final color  = bold ? (suma ? _pGreen : _pRed)
                       : (suma ? _pOnSurf : _pRed);
    final weight = bold ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: color, fontWeight: weight)),
        pw.Text('$signo ${_m(v)}',
            style: pw.TextStyle(fontSize: 9, color: color, fontWeight: weight)),
      ]),
    );
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      border:       pw.Border.all(color: _pOutVar, width: 0.8),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(children: [
      _cardTitle('Cálculo de Efectivo Esperado en Caja'),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

          // Flujo en efectivo
          pw.Text('Movimientos en efectivo',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold,
                  color: _pNavyMuted, letterSpacing: 0.4)),
          pw.SizedBox(height: 6),
          fila('(+) Base inicial',                   s.saldoInicial),
          fila('(+) Ventas en efectivo',             s.ventasEfectivo),
          if (s.ventasMixtoEfectivo > 0)
            fila('(+) Ventas mixto (ef.)',           s.ventasMixtoEfectivo),
          if (s.abonosEfectivo > 0)
            fila('(+) Abonos separados (ef.)',       s.abonosEfectivo),
          if (s.abonosCreditoEfectivo > 0)
            fila('(+) Abonos crédito clientes',      s.abonosCreditoEfectivo),
          if (s.ingresosManual > 0)
            fila('(+) Ingresos manuales',            s.ingresosManual),
          if (s.devolucionesEfectivo > 0)
            fila('(-) Devoluciones (ef.)',           s.devolucionesEfectivo, suma: false),
          if (s.cancelacionesEfectivo > 0)
            fila('(-) Cancelaciones separados',      s.cancelacionesEfectivo, suma: false),
          if (s.gastosTotal > 0)
            fila('(-) Gastos del turno',             s.gastosTotal, suma: false),

          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(color: _pNavy, thickness: 0.8),
          ),

          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('(=) EFECTIVO ESPERADO',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: _pOnSurf)),
            pw.Text(_m(s.montoFinalSistema),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: _pGreen)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('(=) EFECTIVO CONTADO',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: _pOnSurf)),
            pw.Text(_m(s.montoFinalReal),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: _pOnSurf)),
          ]),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
              color: difBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: difColor, width: 0.8),
            ),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('RESULTADO DEL CUADRE',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold,
                        color: difColor, letterSpacing: 0.3)),
                pw.SizedBox(height: 3),
                pw.Text(difLabel,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold,
                        color: difColor)),
              ]),
              pw.Text(difStr,
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold,
                      color: difColor)),
            ]),
          ),
        ]),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════════════
// OBSERVACIONES
// ════════════════════════════════════════════════════════

pw.Widget _notaSection(String nota) => pw.Row(children: [
  pw.Container(width: 4, color: _pGreen),
  pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      color: _pSurfLow,
      child: pw.Text('"$nota"',
          style: pw.TextStyle(
              fontSize: 9, color: _pOnVar,
              lineSpacing: 1.4, fontStyle: pw.FontStyle.italic)),
    ),
  ),
]);

// ════════════════════════════════════════════════════════
// FIRMAS
// ════════════════════════════════════════════════════════

pw.Widget _firmaRow(String empleado) => pw.Row(children: [
  pw.Expanded(child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(width: double.infinity, height: 0.5, color: _pOutline),
      pw.SizedBox(height: 5),
      pw.Text('FIRMA DEL CAJERO',
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold,
              color: _pOutline, letterSpacing: 0.4)),
      pw.SizedBox(height: 3),
      pw.Text(empleado,
          style: pw.TextStyle(
              fontSize: 8, color: _pOnVar, fontWeight: pw.FontWeight.bold)),
    ],
  )),
  pw.SizedBox(width: 60),
  pw.Expanded(child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(width: double.infinity, height: 0.5, color: _pOutline),
      pw.SizedBox(height: 5),
      pw.Text('FIRMA DEL SUPERVISOR / GERENTE',
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold,
              color: _pOutline, letterSpacing: 0.4)),
      pw.SizedBox(height: 3),
      pw.Text('______________________________',
          style: pw.TextStyle(fontSize: 8, color: _pOutline)),
    ],
  )),
]);

// ════════════════════════════════════════════════════════
// HELPERS DE TABLA
// ════════════════════════════════════════════════════════

pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold,
              color: _pWhite, letterSpacing: 0.3)),
    );

// ignore: unused_element
pw.TableRow _tRow(String label, double? ef, double? ta, double? tr) =>
    pw.TableRow(children: [
      _tdLabel(label),
      _tdNum(ef),
      _tdNum(ta),
      _tdNum(tr),
    ]);

pw.Widget _tdLabel(String text, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  child: pw.Text(text,
      style: pw.TextStyle(
          fontSize: 9, color: bold ? _pOnSurf : _pOnVar,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
);

pw.Widget _tdNum(double? v, {bool bold = false}) {
  if (v == null) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text('--',
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontSize: 9, color: _pOutVar)),
    );
  }
  final isNeg  = v < 0;
  final text   = isNeg ? '-${_m(v)}' : _m(v);
  final color  = bold ? (isNeg ? _pRed : _pGreen)
                      : (isNeg ? _pRed : _pOnSurf);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Text(text,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
            fontSize: 9, color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
}

pw.Widget _cardTitle(String title) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: const pw.BoxDecoration(
    color: _pSurfLow,
    borderRadius: pw.BorderRadius.only(
      topLeft:  pw.Radius.circular(8),
      topRight: pw.Radius.circular(8),
    ),
  ),
  child: pw.Text(title,
      style: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pOnSurf)),
);

// ignore: unused_element
pw.Widget _kvRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _pOnVar)),
      pw.Text(value, style: pw.TextStyle(fontSize: 9, color: _pOnSurf)),
    ],
  ),
);

// ════════════════════════════════════════════════════════
// MODELO INTERNO PARA TABLA DE INGRESOS
// ════════════════════════════════════════════════════════

class _IngFila {
  final String label;
  final String tipo;
  final double ventas;
  final double abonos;
  _IngFila(this.label, this.tipo, this.ventas, this.abonos);
  double get total => ventas + abonos;
}
