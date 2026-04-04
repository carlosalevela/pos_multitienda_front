import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/reportes_provider.dart';

class ReportePdfService {
  static Future<void> generarReporteDia({
    required ReportesProvider rep,
    required String fecha,
    required String tiendaNombre,
  }) async {
    final pdf = pw.Document();
    final font      = await PdfGoogleFonts.poppinsRegular();
    final fontBold  = await PdfGoogleFonts.poppinsBold();
    final fontMedium = await PdfGoogleFonts.poppinsMedium();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          fecha: fecha,
          tiendaNombre: tiendaNombre,
          fontBold: fontBold,
          font: font,
        ),
        footer: (context) => _buildFooter(font: font, context: context),
        build: (context) => [
          // ── KPIs ──────────────────────────────────────
          _buildKpis(rep: rep, fontBold: fontBold, font: font),
          pw.SizedBox(height: 16),

          // ── Métodos de pago ───────────────────────────
          _buildMetodos(rep: rep, fontBold: fontBold, font: font),
          pw.SizedBox(height: 16),

          // ── Top productos ─────────────────────────────
          _buildTopProductos(rep: rep, fontBold: fontBold, font: font),
          pw.SizedBox(height: 16),

          // ── Tabla de ventas ───────────────────────────
          _buildTabla(rep: rep, fontBold: fontBold, font: font,
              fontMedium: fontMedium),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Reporte_$fecha.pdf',
    );
  }

  // ── Header ─────────────────────────────────────────

  static pw.Widget _buildHeader({
    required String fecha,
    required String tiendaNombre,
    required pw.Font fontBold,
    required pw.Font font,
  }) =>
    pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reporte de Ventas',
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 18,
                    color: const PdfColor.fromInt(0xFF1A1A2E))),
              pw.Text(tiendaNombre,
                style: pw.TextStyle(
                    font: font, fontSize: 11,
                    color: PdfColors.grey600)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Fecha: $fecha',
                style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.Text('Generado: ${DateTime.now().toString().substring(0, 16)}',
                style: pw.TextStyle(
                    font: font, fontSize: 10, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );

  // ── Footer ─────────────────────────────────────────

  static pw.Widget _buildFooter({
    required pw.Font font,
    required pw.Context context,
  }) =>
    pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Sistema POS — Boutique Consentida',
            style: pw.TextStyle(
                font: font, fontSize: 9, color: PdfColors.grey500)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
                font: font, fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );

  // ── KPIs ───────────────────────────────────────────

  static pw.Widget _buildKpis({
    required ReportesProvider rep,
    required pw.Font fontBold,
    required pw.Font font,
  }) {
    final items = [
      {'label': 'Total vendido',    'valor': '\$${_fmt(rep.totalDia)}',        'color': PdfColors.green700},
      {'label': 'Ventas',           'valor': '${rep.totalVentas}',             'color': PdfColors.blue700},
      {'label': 'Ticket promedio',  'valor': '\$${_fmt(rep.ticketPromedio)}',  'color': PdfColors.purple700},
      {'label': 'Descuentos',       'valor': '\$${_fmt(rep.totalDescuentos)}', 'color': PdfColors.orange700},
      if (rep.totalAnuladas > 0)
        {'label': 'Anuladas', 'valor': '${rep.totalAnuladas}', 'color': PdfColors.red700},
    ];

    return pw.Row(
      children: items.map((item) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item['valor'] as String,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 16,
                    color: item['color'] as PdfColor)),
              pw.SizedBox(height: 4),
              pw.Text(item['label'] as String,
                style: pw.TextStyle(
                    font: font, fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  // ── Métodos de pago ────────────────────────────────

  static pw.Widget _buildMetodos({
    required ReportesProvider rep,
    required pw.Font fontBold,
    required pw.Font font,
  }) {
    final metodos = rep.totalPorMetodo;
    if (metodos.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Ventas por método de pago',
          style: pw.TextStyle(font: fontBold, fontSize: 13)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: metodos.entries.map((e) => pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(e.key.toUpperCase(),
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 10,
                        color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text('\$${_fmt(e.value)}',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 14,
                        color: PdfColors.blue700)),
                  pw.Text(
                    '${(rep.totalDia == 0 ? 0 : (e.value / rep.totalDia * 100)).toStringAsFixed(1)}%',
                    style: pw.TextStyle(
                        font: font, fontSize: 9, color: PdfColors.grey500)),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  // ── Top productos ──────────────────────────────────

  static pw.Widget _buildTopProductos({
    required ReportesProvider rep,
    required pw.Font fontBold,
    required pw.Font font,
  }) {
    final top = rep.topProductos;
    if (top.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Top productos del día',
          style: pw.TextStyle(font: fontBold, fontSize: 13)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(60),
            3: const pw.FixedColumnWidth(80),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['#', 'Producto', 'Unidades', 'Total']
                  .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h,
                      style: pw.TextStyle(font: fontBold, fontSize: 10))))
                  .toList(),
            ),
            // Filas
            ...top.asMap().entries.map((e) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('${e.key + 1}',
                    style: pw.TextStyle(font: font, fontSize: 10))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(e.value['nombre'],
                    style: pw.TextStyle(font: font, fontSize: 10))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    (e.value['cantidad'] as double).toStringAsFixed(0),
                    style: pw.TextStyle(font: font, fontSize: 10))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('\$${_fmt(e.value['subtotal'])}',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 10,
                        color: PdfColors.blue700))),
              ],
            )),
          ],
        ),
      ],
    );
  }

  // ── Tabla ventas ───────────────────────────────────

  static pw.Widget _buildTabla({
    required ReportesProvider rep,
    required pw.Font fontBold,
    required pw.Font font,
    required pw.Font fontMedium,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Detalle de ventas',
          style: pw.TextStyle(font: fontBold, fontSize: 13)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FixedColumnWidth(85),
            1: const pw.FixedColumnWidth(45),
            2: const pw.FlexColumnWidth(),
            3: const pw.FixedColumnWidth(65),
            4: const pw.FixedColumnWidth(70),
            5: const pw.FixedColumnWidth(60),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1A1A2E)),
              children: ['Factura', 'Hora', 'Cliente', 'Método', 'Total', 'Estado']
                  .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h,
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 9,
                          color: PdfColors.white))))
                  .toList(),
            ),
            // Filas
            ...rep.ventas.map((v) {
              final esAnulada = v['estado'] == 'anulada';
              final created = v['created_at']?.toString() ?? '';
              final hora = created.length >= 19
                  ? created.substring(11, 16) : '';
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: esAnulada ? PdfColors.red50 : PdfColors.white),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(v['numero_factura'] ?? '',
                      style: pw.TextStyle(
                          font: fontMedium, fontSize: 9,
                          color: PdfColors.blue700))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(hora,
                      style: pw.TextStyle(font: font, fontSize: 9))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      v['cliente_nombre'] ?? 'Consumidor Final',
                      style: pw.TextStyle(font: font, fontSize: 9))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(v['metodo_pago'] ?? '',
                      style: pw.TextStyle(font: font, fontSize: 9))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      '\$${_fmt(double.tryParse(v['total'].toString()) ?? 0)}',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 9))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(v['estado'] ?? '',
                      style: pw.TextStyle(
                          font: fontMedium, fontSize: 9,
                          color: esAnulada
                              ? PdfColors.red700
                              : PdfColors.green700))),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── Formato números ────────────────────────────────

  static String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
}