// lib/widgets/caja/pdf/cierre_pdf_v2.dart

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../models/sesion_historial.dart';

// ── Paleta "Modern Slate & Accent" ──────────────────────
const _cPrimary  = PdfColor.fromInt(0xFF0F172A); // Slate 900
const _cAccent   = PdfColor.fromInt(0xFF6366F1); // Indigo 500
const _cSuccess  = PdfColor.fromInt(0xFF10B981); // Emerald 500
const _cError    = PdfColor.fromInt(0xFFEF4444); // Red 500
const _cWarning  = PdfColor.fromInt(0xFFF59E0B); // Amber 500
const _cTextMain = PdfColor.fromInt(0xFF1E293B); // Slate 800
const _cTextSec  = PdfColor.fromInt(0xFF64748B); // Slate 500
const _cBgSoft   = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
const _cBorder   = PdfColor.fromInt(0xFFE2E8F0); // Slate 200
const _cWhite    = PdfColors.white;

final _fmt = NumberFormat('#,##0.00', 'en_US');
String _f(double v) => '\$${_fmt.format(v)}';

Future<void> exportarCierrePDF(SesionHistorial sesion) async {
  final doc = pw.Document();
  
  // Lógica de estado
  final bool esExacto = sesion.diferencia.abs() < 0.01;
  final bool esSobrante = sesion.diferencia > 0;
  final PdfColor estadoColor = esExacto ? _cSuccess : (esSobrante ? _cAccent : _cError);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => _buildHeader(sesion),
      footer: (ctx) => _buildFooter(sesion, ctx),
      build: (ctx) => [
        pw.SizedBox(height: 20),
        
        // 1. Resumen de Alto Nivel
        _buildMetricGrid(sesion, estadoColor),
        pw.SizedBox(height: 35),

        // 2. Desglose de Operaciones
        _buildSectionTitle('FLUJO DE CAJA'),
        _buildDataTable([
          _dataRow('Saldo Inicial (Apertura)', _f(sesion.saldoInicial), isBold: true),
          _dataRow('Ventas en Efectivo', '+ ${_f(sesion.ventasEfectivo)}'),
          _dataRow('Abonos en Efectivo', '+ ${_f(sesion.abonosEfectivo)}'),
          _dataRow('Gastos Registrados', '- ${_f(sesion.gastosTotal)}', color: _cError),
          _dataRow('Devoluciones Efectivo', '- ${_f(sesion.devolucionesEfectivo)}', color: _cError),
        ]),

        pw.SizedBox(height: 25),

        // 3. Otros Medios (No afectan efectivo)
        _buildSectionTitle('OTROS MEDIOS DE PAGO'),
        _buildDataTable([
          _dataRow('Ventas Tarjeta', _f(sesion.ventasTarjeta)),
          _dataRow('Ventas Transferencia', _f(sesion.ventasTransferencia)),
          _dataRow('Abonos (No Efectivo)', _f(sesion.abonosTarjeta + sesion.abonosTransferencia)),
        ], useBg: false),

        pw.SizedBox(height: 35),

        // 4. Resultado Final (Impacto Visual)
        _buildClosingCard(sesion, estadoColor, esExacto),
        
        if (sesion.observaciones.isNotEmpty) ...[
          pw.SizedBox(height: 25),
          _buildSectionTitle('OBSERVACIONES'),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(sesion.observaciones, 
              style: pw.TextStyle(color: _cTextSec, fontSize: 10, lineSpacing: 1.5)),
          ),
        ],
      ],
    ),
  );

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'CIERRE_${sesion.id}_${sesion.tiendaNombre}.pdf',
  );
}

// ── Componentes de Diseño ────────────────────────────────

pw.Widget _buildHeader(SesionHistorial sesion) => pw.Column(
  children: [
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(sesion.tiendaNombre, 
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _cPrimary)),
            pw.SizedBox(height: 4),
            pw.Text('CORTE DE CAJA DIARIO', 
              style: pw.TextStyle(fontSize: 10, color: _cAccent, letterSpacing: 1.2, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('ID SESIÓN: #${sesion.id}', 
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(sesion.fechaCierre)),
              style: pw.TextStyle(fontSize: 9, color: _cTextSec)),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: 15),
    pw.Divider(color: _cBorder, thickness: 1),
  ],
);

pw.Widget _buildMetricGrid(SesionHistorial sesion, PdfColor estadoColor) => pw.Row(
  children: [
    _metricItem('ENTRADAS', _f(sesion.ventasTotal + sesion.abonosTotal), _cSuccess),
    pw.SizedBox(width: 15),
    _metricItem('SALIDAS', _f(sesion.gastosTotal + sesion.devolucionesEfectivo), _cError),
    pw.SizedBox(width: 15),
    _metricItem('DIFERENCIA', _f(sesion.diferencia), estadoColor, isHighlight: true),
  ],
);

pw.Widget _metricItem(String label, String value, PdfColor color, {bool isHighlight = false}) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: isHighlight ? color : _cBgSoft,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(
            fontSize: 7, 
            fontWeight: pw.FontWeight.bold, 
            color: isHighlight ? _cWhite : _cTextSec
          )),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(
            fontSize: 13, 
            fontWeight: pw.FontWeight.bold, 
            color: isHighlight ? _cWhite : color
          )),
        ],
      ),
    ),
  );
}

pw.Widget _buildSectionTitle(String title) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 10),
  child: pw.Text(title, style: pw.TextStyle(
    fontSize: 9, fontWeight: pw.FontWeight.bold, color: _cTextSec, letterSpacing: 0.5
  )),
);

pw.Widget _buildDataTable(List<pw.Widget> rows, {bool useBg = true}) => pw.Container(
  decoration: pw.BoxDecoration(
    color: useBg ? _cBgSoft : null,
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
  ),
  child: pw.Column(children: rows),
);

pw.Widget _dataRow(String label, String value, {PdfColor? color, bool isBold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _cTextMain)),
      pw.Text(value, style: pw.TextStyle(
        fontSize: 9, 
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? _cTextMain
      )),
    ],
  ),
);

pw.Widget _buildClosingCard(SesionHistorial sesion, PdfColor color, bool esExacto) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.all(20),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: _cBorder, width: 1),
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SISTEMA: ${_f(sesion.montoFinalSistema)}', style: pw.TextStyle(fontSize: 10, color: _cTextSec)),
          pw.SizedBox(height: 4),
          pw.Text('CONTADO: ${_f(sesion.montoFinalReal)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
        ),
        child: pw.Text(
          esExacto ? 'CUADRE EXITOSO' : 'DIFERENCIA: ${_f(sesion.diferencia)}',
          style: pw.TextStyle(color: _cWhite, fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  ),
);

pw.Widget _buildFooter(SesionHistorial sesion, pw.Context ctx) => pw.Column(
  children: [
    pw.Divider(color: _cBorder),
    pw.SizedBox(height: 10),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Operado por: ${sesion.empleadoNombre}', style: pw.TextStyle(fontSize: 8, color: _cTextSec)),
        pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 8, color: _cTextSec)),
      ],
    ),
  ],
);