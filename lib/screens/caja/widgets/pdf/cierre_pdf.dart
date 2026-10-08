// lib/screens/caja/widgets/pdf/cierre_pdf.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../models/sesion_historial.dart';
import '../../../../services/documento_service.dart';
import '../../../../services/thermal_printer_service.dart';
import '../../../../services/windows_printer_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

Future<void> _abrirPdf(List<int> bytes, String nombre) async {
  if (kIsWeb) {
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: nombre);
    return;
  }
  // Exe: imprimir directo si hay impresora configurada
  final printed = await WindowsPrinterService.printPdf(bytes, nombre);
  if (printed) return;

  // Fallback: abrir con el visor del sistema
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

// ── Palette (Enterprise POS) ──────────────────────────────
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
// ENTRY POINT
// ════════════════════════════════════════════════════════

Future<void> exportarCierrePDF(SesionHistorial sesion, {String tipoPapel = '80mm'}) async {
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

      // 1. Tres metricas clave
      _topMetrics(sesion),
      pw.SizedBox(height: 22),

      // 2. Desglose por metodo de pago
      _sectionLabel('Desglose por Metodo de Pago'),
      pw.SizedBox(height: 8),
      _desgloseTable(sesion),
      pw.SizedBox(height: 22),

      // 3. Resumen flujo de caja (formato físico)
      _sectionLabel('Resumen de Flujo de Caja'),
      pw.SizedBox(height: 8),
      _flujoCajaCard(sesion, difColor, difBg, difLabel, difStr),
      pw.SizedBox(height: 22),

      // 4. Abonos separados (si hay)
      if (sesion.abonosTotal > 0) ...[
        _sectionLabel('Recaudacion de Separados'),
        pw.SizedBox(height: 8),
        _abonosCard(sesion),
        pw.SizedBox(height: 22),
      ],

      // 5. Detalle de gastos (si hay)
      if (sesion.gastosTotal > 0) ...[
        _sectionLabel('Detalle de Gastos'),
        pw.SizedBox(height: 8),
        _gastosDetalleTable(sesion),
        pw.SizedBox(height: 22),
      ],

      // 6. Detalle de devoluciones (si hay)
      if (sesion.numDevoluciones > 0) ...[
        _sectionLabel('Detalle de Devoluciones'),
        pw.SizedBox(height: 8),
        _devolucionesDetail(sesion),
        pw.SizedBox(height: 22),
      ],

      // 7. Observaciones (si hay)
      if (sesion.observaciones.isNotEmpty) ...[
        _sectionLabel('OBSERVACIONES'),
        pw.SizedBox(height: 8),
        _notaSection(sesion.observaciones),
        pw.SizedBox(height: 22),
      ],

      // 8. Firmas
      pw.SizedBox(height: 20),
      _firmaRow(sesion.empleadoNombre),
    ],
  ));

  final filename =
      'CIERRE_${sesion.id}_${sesion.tiendaNombre.replaceAll(' ', '_')}.pdf';
  final bytes = await doc.save();

  // Siempre guardar PDF en carpeta local
  unawaited(DocumentoService.instance.guardarCierre(
    bytes: bytes,
    referencia: 'cierre_${sesion.id}_${sesion.tiendaNombre.replaceAll(' ', '_')}',
  ));

  // Intentar imprimir en ESC/POS si hay impresora configurada
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
        final dev = await ThermalPrinterService.getAutoDevice();
        if (dev != null) {
          final tb = await ThermalPrinterService.buildCierreHistorial(
            sesion: sesion, paperSize: ps,
          );
          await ThermalPrinterService.printBytes(dev, tb);
          return;
        }
      }
    } catch (_) {}
  }

  // Fallback: abrir visor de PDF
  await _abrirPdf(bytes, filename);
}

// ════════════════════════════════════════════════════════
// HEADER  (se repite en cada pagina)
// ════════════════════════════════════════════════════════

pw.Widget _header(SesionHistorial sesion) => pw.Column(children: [
  pw.Row(
    mainAxisAlignment:  pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Izquierda: logo + tienda
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: 44, height: 44,
          decoration: const pw.BoxDecoration(
            color: _pNavy,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text('POS',
              style: pw.TextStyle(
                  color: _pWhite, fontSize: 13,
                  fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 12),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(sesion.tiendaNombre,
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold,
                  color: _pOnSurf)),
          pw.SizedBox(height: 4),
          pw.Text('Cajero: ${sesion.empleadoNombre}',
              style: pw.TextStyle(fontSize: 8, color: _pOnVar)),
        ]),
      ]),
      // Derecha: titulo + datos del cierre
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text('REPORTE DE CIERRE DE CAJA',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold,
                color: _pGreen, letterSpacing: 0.8)),
        pw.SizedBox(height: 4),
        _infoLine('ID SESION:', '#${sesion.id}'),
        _infoLine('FECHA:', _fecha(sesion.fechaCierre)),
        _infoLine('HORA:', _hora(sesion.fechaCierre)),
        _infoLine('CAJERO:', sesion.empleadoNombre),
      ]),
    ],
  ),
  pw.SizedBox(height: 12),
  pw.Divider(color: _pNavy, thickness: 1.2),
]);

pw.Widget _infoLine(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 2),
  child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
    pw.Text(label,
        style: pw.TextStyle(
            fontSize: 7, fontWeight: pw.FontWeight.bold, color: _pOutline)),
    pw.SizedBox(width: 4),
    pw.Text(value,
        style: pw.TextStyle(fontSize: 7, color: _pOnVar)),
  ]),
);

// ════════════════════════════════════════════════════════
// FOOTER
// ════════════════════════════════════════════════════════

pw.Widget _footer(SesionHistorial sesion, pw.Context ctx) => pw.Column(children: [
  pw.Divider(color: _pOutVar, thickness: 0.5),
  pw.SizedBox(height: 5),
  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
    pw.Text('Sesion #${sesion.id} - ${sesion.tiendaNombre}',
        style: pw.TextStyle(fontSize: 7, color: _pOutline)),
    pw.Text('Generado automaticamente por POS Master',
        style: pw.TextStyle(fontSize: 7, color: _pOutline)),
    pw.Text('Pag. ${ctx.pageNumber} / ${ctx.pagesCount}',
        style: pw.TextStyle(fontSize: 7, color: _pOutline)),
  ]),
]);

// ════════════════════════════════════════════════════════
// SECCION LABEL
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
// 1. TRES METRICAS CLAVE
// ════════════════════════════════════════════════════════

pw.Widget _topMetrics(SesionHistorial sesion) => pw.Row(children: [
  _metricCard('BASE INICIAL', _m(sesion.saldoInicial),
      sub: 'Apertura: ${_hora(sesion.fechaApertura)}',
      dark: false, color: _pOnSurf),
  pw.SizedBox(width: 10),
  _metricCard('VENTAS TOTALES', _m(sesion.ventasTotal),
      sub: '${sesion.numTransacciones} transacciones',
      dark: false, color: _pGreen),
  pw.SizedBox(width: 10),
  _metricCard('SALDO NETO EN CAJA', _m(sesion.montoFinalSistema),
      sub: 'Monto esperado en sistema',
      dark: true, color: _pWhite),
]);

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
              fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
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
// 2. TABLA DE DESGLOSE POR METODO (pw.Table)
// ════════════════════════════════════════════════════════

pw.Widget _desgloseTable(SesionHistorial sesion) {
  // Totales por columna
  final totalEf = sesion.ventasEfectivo
                + sesion.ventasMixtoEfectivo
                + sesion.abonosEfectivo
                + sesion.abonosCreditoEfectivo
                + sesion.ingresosManual
                - sesion.cancelacionesEfectivo
                - sesion.gastosTotal
                - sesion.devolucionesEfectivo;
  final totalTa = sesion.ventasTarjeta     + sesion.abonosTarjeta;
  final totalTr = sesion.ventasTransferencia + sesion.abonosTransferencia;

  // Filas condicionales
  final hasAbonos        = sesion.abonosTotal > 0;
  final hasAbonosCartera = sesion.abonosCreditoEfectivo > 0;
  final hasCancelaciones = sesion.cancelacionesEfectivo > 0;
  final hasIngManual     = sesion.ingresosManual > 0;
  final hasGastos        = sesion.gastosTotal > 0;
  final hasDev           = sesion.devolucionesEfectivo != 0;
  final hasMixto         = sesion.ventasMixtoEfectivo > 0;

  final tableBorder = pw.TableBorder(
    top:              pw.BorderSide(color: _pNavy,   width: 1.0),
    bottom:           pw.BorderSide(color: _pOutVar, width: 0.8),
    left:             pw.BorderSide(color: _pOutVar, width: 0.8),
    right:            pw.BorderSide(color: _pOutVar, width: 0.8),
    horizontalInside: pw.BorderSide(color: _pOutVar, width: 0.4),
    verticalInside:   pw.BorderSide(color: _pOutVar, width: 0.4),
  );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Table(
        border: tableBorder,
        columnWidths: const {
          0: pw.FlexColumnWidth(2.4),
          1: pw.FlexColumnWidth(1.4),
          2: pw.FlexColumnWidth(1.4),
          3: pw.FlexColumnWidth(1.4),
        },
        children: [
          // Cabecera
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _pNavy),
            children: [
              _th('CONCEPTO',       align: pw.TextAlign.left),
              _th('EFECTIVO',       align: pw.TextAlign.right),
              _th('TARJETA',        align: pw.TextAlign.right),
              _th('TRANSFERENCIA',  align: pw.TextAlign.right),
            ],
          ),
          // Ventas directas (siempre visible)
          _tRow('Ventas Directas',
              sesion.ventasEfectivo, sesion.ventasTarjeta, sesion.ventasTransferencia),
          // Ventas mixto — solo la parte en efectivo
          if (hasMixto)
            _tRow('Ventas Mixto (ef.)', sesion.ventasMixtoEfectivo, null, null),
          // Abonos separados
          if (hasAbonos)
            _tRow('Abonos Separados',
                sesion.abonosEfectivo, sesion.abonosTarjeta, sesion.abonosTransferencia),
          // Abonos cartera (crédito) — solo efectivo
          if (hasAbonosCartera)
            _tRow('Abonos Cartera', sesion.abonosCreditoEfectivo, null, null),
          // Ingresos manuales
          if (hasIngManual)
            _tRow('Ingresos Manuales', sesion.ingresosManual, null, null),
          // Cancelaciones separados (salida de efectivo)
          if (hasCancelaciones)
            _tRow('Cancelaciones Separados', -sesion.cancelacionesEfectivo, null, null),
          // Gastos
          if (hasGastos)
            _tRow('Gastos de Operacion', -sesion.gastosTotal, null, null),
          // Devoluciones efectivo (puede ser negativo si cobros > devoluciones)
          if (hasDev)
            _tRow('Devoluciones (ef.)', -sesion.devolucionesEfectivo, null, null),
          // Fila total (destacada)
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _pSurfLow),
            children: [
              _tdLabel('TOTAL POR METODO', bold: true),
              _tdNum(totalEf, bold: true),
              _tdNum(totalTa, bold: true),
              _tdNum(totalTr, bold: true),
            ],
          ),
        ],
      ),
      // Nota ventas mixto
      if (hasMixto) pw.Padding(
        padding: const pw.EdgeInsets.only(top: 5, left: 2),
        child: pw.Text(
          '* Ventas Mixto: se registra el efectivo recibido; el resto fue por transferencia o tarjeta.',
          style: pw.TextStyle(fontSize: 7, color: _pOutline,
              fontStyle: pw.FontStyle.italic),
        ),
      ),
    ],
  );
}

// Celda cabecera
pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold,
              color: _pWhite, letterSpacing: 0.3)),
    );

// Fila de datos (numeros nullable = muestra --)
pw.TableRow _tRow(String label, double? ef, double? ta, double? tr) =>
    pw.TableRow(children: [
      _tdLabel(label),
      _tdNum(ef),
      _tdNum(ta),
      _tdNum(tr),
    ]);

// Celda etiqueta (columna concepto)
pw.Widget _tdLabel(String text, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  child: pw.Text(text,
      style: pw.TextStyle(
          fontSize: 9, color: bold ? _pOnSurf : _pOnVar,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
);

// Celda numerica derecha (null = "--", negativo = rojo)
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

// ════════════════════════════════════════════════════════
// 3. RESUMEN FLUJO DE CAJA (estilo reporte físico)
// ════════════════════════════════════════════════════════

pw.Widget _flujoCajaCard(
  SesionHistorial s,
  PdfColor difColor, PdfColor difBg,
  String difLabel, String difStr,
) {
  pw.Widget fila(String label, double v, {bool suma = true, bool total = false, bool bold = false}) {
    final signo  = suma ? '+' : '-';
    final color  = total ? _pGreen : (suma ? _pOnSurf : _pRed);
    final weight = (total || bold) ? pw.FontWeight.bold : pw.FontWeight.normal;
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
      _cardTitle('Cuadre de Efectivo'),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          // ── Ingresos ──
          fila('(+) Base inicial de caja',    s.saldoInicial),
          fila('(+) Ventas en efectivo',       s.ventasEfectivo),
          if (s.ventasMixtoEfectivo > 0)
            fila('(+) Ventas mixto (efectivo)', s.ventasMixtoEfectivo),
          if (s.abonosEfectivo > 0)
            fila('(+) Ingresos separados',     s.abonosEfectivo),
          if (s.abonosCreditoEfectivo > 0)
            fila('(+) Abonos pagos clientes',  s.abonosCreditoEfectivo),
          if (s.ingresosManual > 0)
            fila('(+) Ingresos manuales',      s.ingresosManual),
          // ── Egresos ──
          if (s.devolucionesEfectivo > 0)
            fila('(-) Devoluciones (neto ef.)', s.devolucionesEfectivo, suma: false),
          if (s.cancelacionesEfectivo > 0)
            fila('(-) Cancelaciones separados', s.cancelacionesEfectivo, suma: false),
          if (s.gastosTotal > 0)
            fila('(-) Gastos del turno',        s.gastosTotal, suma: false),
          // ── Divisor ──
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Divider(color: _pNavy, thickness: 0.8),
          ),
          // ── Total esperado ──
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('(=) EFECTIVO ESPERADO',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pOnSurf)),
            pw.Text(_m(s.montoFinalSistema),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pGreen)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('(=) EFECTIVO CONTADO',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pOnSurf)),
            pw.Text(_m(s.montoFinalReal),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pOnSurf)),
          ]),
          pw.SizedBox(height: 10),
          // ── Resultado ──
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: difBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('DIFERENCIA ($difLabel)',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: difColor)),
              pw.Text(difStr,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: difColor)),
            ]),
          ),
        ]),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════════════
// 4b. DETALLE DE GASTOS
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
          _th('CATEGORIA'),
          _th('DESCRIPCION'),
          _th('METODO',  align: pw.TextAlign.center),
          _th('MONTO',   align: pw.TextAlign.right),
        ],
      ),
      if (detalle.isEmpty)
        pw.TableRow(children: [
          _tdLabel('Sin detalle disponible'),
          _tdLabel(''), _tdLabel(''), _tdLabel(''),
        ])
      else
        ...detalle.map((g) => pw.TableRow(children: [
          _tdLabel((g['categoria'] ?? '').toString()),
          _tdLabel((g['descripcion'] ?? '').toString()),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Text(fmtMetodo((g['metodo_pago'] ?? '').toString()),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, color: _pOnVar)),
          ),
          _tdNum(double.tryParse(g['monto']?.toString() ?? '0') ?? 0.0),
        ])),
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
// SECCION INFERIOR: solo Abonos (Arqueo movido a FlujoCaja)
// ════════════════════════════════════════════════════════

// ─── Abonos card ──────────────────────────────────────

pw.Widget _abonosCard(SesionHistorial sesion) => pw.Container(
  decoration: pw.BoxDecoration(
    border:       pw.Border.all(color: _pOutVar, width: 0.8),
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
  ),
  child: pw.Column(children: [
    _cardTitle('Recaudacion de Apartados'),
    pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Breakdown por metodo si hay variedad
        if (sesion.abonosEfectivo > 0)
          _kvRow('Efectivo', _m(sesion.abonosEfectivo)),
        if (sesion.abonosTarjeta > 0)
          _kvRow('Tarjeta', _m(sesion.abonosTarjeta)),
        if (sesion.abonosTransferencia > 0)
          _kvRow('Transferencia', _m(sesion.abonosTransferencia)),
        pw.Divider(color: _pOutVar, thickness: 0.4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'SUBTOTAL APARTADOS (${sesion.numAbonos} folios)',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pOnSurf)),
            pw.Text(_m(sesion.abonosTotal),
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pGreen)),
          ],
        ),
        if (sesion.abonosTarjeta > 0 || sesion.abonosTransferencia > 0) ...[
          pw.SizedBox(height: 7),
          pw.Text(
            '* Tarjeta y transferencia no afectan el cajon de efectivo.',
            style: pw.TextStyle(
                fontSize: 7, color: _pOutline,
                fontStyle: pw.FontStyle.italic),
          ),
        ],
      ]),
    ),
  ]),
);

// ════════════════════════════════════════════════════════
// 6. DETALLE DE DEVOLUCIONES
// ════════════════════════════════════════════════════════

pw.Widget _devolucionesDetail(SesionHistorial sesion) {
  final tieneDirectas  = sesion.devolucionesDirectasEf > 0;
  final tieneCobrar    = sesion.cambiosCobrarEf > 0;
  final tieneDevolver  = sesion.cambiosDevEf > 0;
  final tieneCambiosSinEf = sesion.numCambiosProducto > 0 && !tieneDevolver && !tieneCobrar;
  final netoMostrar    = sesion.devolucionesEfectivo;

  const colWidths = {
    0: pw.FlexColumnWidth(3.2),
    1: pw.FlexColumnWidth(1.3),
    2: pw.FlexColumnWidth(1.5),
  };

  pw.TableRow fila(String label, String cant, double v) => pw.TableRow(children: [
    _tdLabel(label),
    _tdNumRight(cant),
    _tdNum(v),
  ]);

  return pw.Table(
    border: pw.TableBorder(
      top:              pw.BorderSide(color: _pNavy,   width: 1.0),
      bottom:           pw.BorderSide(color: _pOutVar, width: 0.8),
      left:             pw.BorderSide(color: _pOutVar, width: 0.8),
      right:            pw.BorderSide(color: _pOutVar, width: 0.8),
      horizontalInside: pw.BorderSide(color: _pOutVar, width: 0.4),
      verticalInside:   pw.BorderSide(color: _pOutVar, width: 0.4),
    ),
    columnWidths: colWidths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _pNavy),
        children: [
          _th('TIPO DE DEVOLUCION'),
          _th('CANT',           align: pw.TextAlign.right),
          _th('IMPACTO EF.',    align: pw.TextAlign.right),
        ],
      ),
      if (tieneDirectas)
        fila('Devolucion directa en efectivo\n(dinero devuelto al cliente)',
            '${sesion.numDevoluciones - sesion.numCambiosProducto}',
            -sesion.devolucionesDirectasEf),
      if (tieneDevolver)
        fila('Cambio con sobrante\n(se devuelve diferencia al cliente)',
            '—', -sesion.cambiosDevEf),
      if (tieneCobrar)
        fila('Cambio con cobro adicional\n(cliente pagó la diferencia)',
            '—', sesion.cambiosCobrarEf),
      if (tieneCambiosSinEf)
        fila('Cambio de producto\n(sin impacto en efectivo)',
            '${sesion.numCambiosProducto}', 0),
      // Total neto
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _pSurfLow),
        children: [
          _tdLabel('NETO EFECTIVO DEVOLUCIONES', bold: true),
          _tdNumRight('${sesion.numDevoluciones}', bold: true),
          _tdNum(-netoMostrar, bold: true),
        ],
      ),
    ],
  );
}

// Celda de texto numerica (sin color segun valor, solo texto)
pw.Widget _tdNumRight(String text, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  child: pw.Text(text,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(
          fontSize: 9, color: _pOnSurf,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
);

// ════════════════════════════════════════════════════════
// 5. NOTA DE CIERRE / OBSERVACIONES
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
// 6. FIRMAS
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
// HELPERS COMUNES
// ════════════════════════════════════════════════════════

// Barra de titulo dentro de una card
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

// Fila clave:valor simple
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
