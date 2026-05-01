import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/reportes_provider.dart';
import '../models/contabilidad_models.dart';


class ReportePdfService {
  static Future<void> generarReporteDia({
    required ReportesProvider rep,
    required String fecha,
    required String tiendaNombre,
    required String empresaNombre,
    List<Gasto> gastos = const [],
  }) async {
    final pdf        = pw.Document();
    final font       = await PdfGoogleFonts.poppinsRegular();
    final fontBold   = await PdfGoogleFonts.poppinsBold();
    final fontMedium = await PdfGoogleFonts.poppinsMedium();

    final totalGastos = gastos.fold(0.0, (s, g) => s + g.monto);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          fecha: fecha, tiendaNombre: tiendaNombre,
          fontBold: fontBold, font: font,
        ),
        footer: (context) => _buildFooter(
          font: font, context: context,
          empresaNombre: empresaNombre,
        ),
        build: (context) => [
          _buildKpis(rep: rep, fontBold: fontBold,
              font: font, totalGastos: totalGastos),
          pw.SizedBox(height: 16),
          _buildMetodos(rep: rep, fontBold: fontBold, font: font),
          pw.SizedBox(height: 16),
          _buildTopProductos(rep: rep, fontBold: fontBold, font: font),
          pw.SizedBox(height: 16),
          _buildTabla(rep: rep, fontBold: fontBold,
              font: font, fontMedium: fontMedium),
          if (rep.devoluciones.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildDevoluciones(rep: rep, fontBold: fontBold,
                font: font, fontMedium: fontMedium),
          ],
          if (rep.abonos.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildAbonos(rep: rep, fontBold: fontBold,
                font: font, fontMedium: fontMedium),
          ],
          if (gastos.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildGastos(
              gastos: gastos,
              totalGastos: totalGastos,
              totalVentas: rep.totalDia,
              totalDevoluciones: rep.totalDevoluciones,
              fontBold: fontBold, font: font, fontMedium: fontMedium,
            ),
          ],
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
                style: pw.TextStyle(font: fontBold, fontSize: 18,
                    color: const PdfColor.fromInt(0xFF1A1A2E))),
              pw.Text(tiendaNombre,
                style: pw.TextStyle(font: font, fontSize: 11,
                    color: PdfColors.grey600)),
            ]),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Fecha: $fecha',
                style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.Text(
                'Generado: ${DateTime.now().toString().substring(0, 16)}',
                style: pw.TextStyle(font: font, fontSize: 10,
                    color: PdfColors.grey500)),
            ]),
        ],
      ),
    );


  // ── Footer ─────────────────────────────────────────

  static pw.Widget _buildFooter({
    required pw.Font font,
    required pw.Context context,
    required String empresaNombre,
  }) =>
    pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Sistema POS — $empresaNombre',
            style: pw.TextStyle(font: font, fontSize: 9,
                color: PdfColors.grey500)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 9,
                color: PdfColors.grey500)),
        ],
      ),
    );


  // ── KPIs — grid 4 por fila, sin números cortados ───

  static pw.Widget _buildKpis({
  required ReportesProvider rep,
  required pw.Font fontBold,
  required pw.Font font,
  double totalGastos = 0,
}) {
  final tieneDev = rep.numDevoluciones > 0;

  final items = <Map<String, dynamic>>[
    {
      'label': tieneDev ? 'Ventas brutas' : 'Total vendido',
      'valor': '\$${_fmt(rep.totalDia)}',
      'color': PdfColors.teal700,
    },
    if (tieneDev) ...[
      {
        'label': 'Devoluciones',
        'valor': '-\$${_fmt(rep.totalDevoluciones)}',
        'color': PdfColors.red700,
      },
      {
        'label': 'Total neto',
        'valor': '\$${_fmt(rep.totalNeto)}',
        'color': const PdfColor.fromInt(0xFF1565C0),
      },
    ],
    {
      'label': 'Nº ventas',
      'valor': '${rep.totalVentas}',
      'color': PdfColors.blue700,
    },
    {
      'label': 'Ticket promedio',
      'valor': '\$${_fmt(rep.ticketPromedio)}',
      'color': PdfColors.purple700,
    },
    {
      'label': 'Descuentos',
      'valor': '-\$${_fmt(rep.totalDescuentos)}',
      'color': PdfColors.orange700,
    },
    if (totalGastos > 0)
      {
        'label': 'Gastos del día',
        'valor': '-\$${_fmt(totalGastos)}',
        'color': PdfColors.orange900,
      },
    if (rep.totalAbonos > 0)
      {
        'label': 'Abonos',
        'valor': '\$${_fmt(rep.totalAbonos)}',
        'color': PdfColors.teal600,
      },
    if (rep.totalAnuladas > 0)
      {
        'label': 'Anuladas',
        'valor': '${rep.totalAnuladas}',
        'color': PdfColors.red700,
      },
  ];

  const perRow = 4;
  final rows   = <List<Map<String, dynamic>>>[];
  for (var i = 0; i < items.length; i += perRow) {
    rows.add(items.sublist(
        i, (i + perRow) > items.length ? items.length : i + perRow));
  }

  return pw.Column(
    children: rows.map((row) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          ...row.map((item) {
            final color = item['color'] as PdfColor;
            return pw.Expanded(
              child: pw.Container(
                height: 64,
                margin: const pw.EdgeInsets.only(right: 8),
                // ✅ Border.all uniforme → permite borderRadius
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(
                      color: PdfColors.grey200, width: 0.5),
                ),
                child: pw.Row(
                  children: [
                    // ✅ Barra izquierda como widget hijo, sin border
                    pw.Container(
                      width: 4,
                      decoration: pw.BoxDecoration(
                        color: color,
                        // borderRadius solo en las esquinas izquierdas
                        // sin border → no dispara el assertion
                        borderRadius: const pw.BorderRadius.only(
                          topLeft:    pw.Radius.circular(6),
                          bottomLeft: pw.Radius.circular(6),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          mainAxisAlignment:
                              pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(item['valor'] as String,
                              style: pw.TextStyle(
                                  font:     fontBold,
                                  fontSize: 13,
                                  color:    color)),
                            pw.SizedBox(height: 3),
                            pw.Text(item['label'] as String,
                              style: pw.TextStyle(
                                  font:     font,
                                  fontSize: 8,
                                  color:    PdfColors.grey600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          ...List.generate(perRow - row.length, (_) =>
            pw.Expanded(child: pw.Container(
                margin: const pw.EdgeInsets.only(right: 8)))),
        ],
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
        _sectionTitle('Ventas por método de pago',
            PdfColors.blueGrey700, fontBold, font),
        pw.SizedBox(height: 8),
        pw.Row(
          children: metodos.entries.map((e) => pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(e.key.toUpperCase(),
                    style: pw.TextStyle(font: fontBold, fontSize: 10,
                        color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text('\$${_fmt(e.value)}',
                    style: pw.TextStyle(font: fontBold, fontSize: 14,
                        color: PdfColors.blue700)),
                  pw.Text(
                    '${(rep.totalDia == 0 ? 0
                        : (e.value / rep.totalDia * 100))
                        .toStringAsFixed(1)}%',
                    style: pw.TextStyle(font: font, fontSize: 9,
                        color: PdfColors.grey500)),
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
        _sectionTitle('Top productos del día',
            PdfColors.purple700, fontBold, font),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey200, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(60),
            3: const pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['#', 'Producto', 'Unidades', 'Total']
                  .map((h) => _th(h, fontBold, color: PdfColors.grey800))
                  .toList(),
            ),
            ...top.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(
                color: e.key.isEven
                    ? PdfColors.grey50 : PdfColors.white),
              children: [
                _td('${e.key + 1}', font),
                _td(e.value['nombre'], font),
                _td((e.value['cantidad'] as double)
                    .toStringAsFixed(0), font),
                _td('\$${_fmt(e.value['subtotal'])}', fontBold,
                    color: PdfColors.blue700),
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
        _sectionTitle('Detalle de ventas',
            const PdfColor.fromInt(0xFF1A1A2E), fontBold, font),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey200, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(85),
            1: const pw.FixedColumnWidth(40),
            2: const pw.FlexColumnWidth(),
            3: const pw.FixedColumnWidth(65),
            4: const pw.FixedColumnWidth(70),
            5: const pw.FixedColumnWidth(58),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1A1A2E)),
              children: ['Factura', 'Hora', 'Cliente',
                'Método', 'Total', 'Estado']
                  .map((h) => _th(h, fontBold))
                  .toList(),
            ),
            ...rep.ventas.map((v) {
              final esAnulada = v['estado'] == 'anulada';
              final created   = v['created_at']?.toString() ?? '';
              final hora      = created.length >= 19
                  ? created.substring(11, 16) : '';
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: esAnulada
                      ? PdfColors.red50 : PdfColors.white),
                children: [
                  _td(v['numero_factura'] ?? '',
                      fontMedium, color: PdfColors.blue700),
                  _td(hora, font),
                  _td(v['cliente_nombre'] ?? 'Consumidor Final', font),
                  _td(v['metodo_pago'] ?? '', font),
                  _td('\$${_fmt(double.tryParse(
                      v['total'].toString()) ?? 0)}', fontBold),
                  _td(v['estado'] ?? '', fontMedium,
                      color: esAnulada
                          ? PdfColors.red700 : PdfColors.green700),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }


  // ── Devoluciones ───────────────────────────────────

  static pw.Widget _buildDevoluciones({
    required ReportesProvider rep,
    required pw.Font fontBold,
    required pw.Font font,
    required pw.Font fontMedium,
  }) {
    final total    = rep.totalDevoluciones;
    final cantidad = rep.numDevoluciones;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Devoluciones del día', PdfColors.red700,
            fontBold, font,
            badge: '$cantidad dev.'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.red100, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(75),
            1: const pw.FixedColumnWidth(38),
            2: const pw.FlexColumnWidth(),
            3: const pw.FlexColumnWidth(),
            4: const pw.FixedColumnWidth(72),
            5: const pw.FixedColumnWidth(72),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.red700),
              children: ['Referencia', 'Hora', 'Productos',
                'Empleado', 'Método', 'Devuelto']
                  .map((h) => _th(h, fontBold))
                  .toList(),
            ),
            ...rep.devoluciones.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              final created  = d['created_at']?.toString() ?? '';
              final hora     = created.length >= 19
                  ? created.substring(11, 16) : '';
              final devTotal = double.tryParse(
                  d['total_devuelto']?.toString() ?? '0') ?? 0;
              final factura  = d['venta_numero'] ?? 'DEV-${d['id']}';
              final metodo   = d['metodo_devolucion']?.toString() ?? '';
              final empleado = d['empleado_nombre'] ?? '';
              final productos = (d['productos_devueltos'] as List? ?? [])
                  .map((p) => '${p['producto']} x${(double.tryParse(
                      p['cantidad'].toString()) ?? 0).toStringAsFixed(0)}')
                  .join(', ');

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isEven ? PdfColors.red50 : PdfColors.white),
                children: [
                  _td(factura, fontBold, color: PdfColors.red700),
                  _td(hora, font),
                  _td(productos, font, size: 8),
                  _td(empleado, font),
                  _td(metodo, fontMedium),
                  _td('-\$${_fmt(devTotal)}', fontBold,
                      color: PdfColors.red700),
                ],
              );
            }),
            // Fila TOTAL
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.red100),
              children: [
                ...List.generate(4, (_) => _td('', font)),
                _td('TOTAL', fontBold, color: PdfColors.red900),
                _td('-\$${_fmt(total)}', fontBold,
                    color: PdfColors.red900, size: 11),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        // Resumen neto devoluciones
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFE3F2FD),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFF90CAF9))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Ventas brutas',
                style: pw.TextStyle(font: font, fontSize: 10,
                    color: PdfColors.grey700)),
              pw.Text('\$${_fmt(rep.totalDia)}',
                style: pw.TextStyle(font: fontBold, fontSize: 10,
                    color: PdfColors.grey800)),
              pw.Text('— Devoluciones',
                style: pw.TextStyle(font: font, fontSize: 10,
                    color: PdfColors.red700)),
              pw.Text('-\$${_fmt(rep.totalDevoluciones)}',
                style: pw.TextStyle(font: fontBold, fontSize: 10,
                    color: PdfColors.red700)),
              pw.Text('= Total neto',
                style: pw.TextStyle(font: fontBold, fontSize: 11,
                    color: const PdfColor.fromInt(0xFF1565C0))),
              pw.Text('\$${_fmt(rep.totalNeto)}',
                style: pw.TextStyle(font: fontBold, fontSize: 12,
                    color: const PdfColor.fromInt(0xFF1565C0))),
            ],
          ),
        ),
      ],
    );
  }


  // ── Abonos ─────────────────────────────────────────

  static pw.Widget _buildAbonos({
    required ReportesProvider rep,
    required pw.Font fontBold,
    required pw.Font font,
    required pw.Font fontMedium,
  }) {
    final totalAbonos = rep.totalAbonos;
    final cantidad    = rep.cantidadAbonos;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Abonos a separados del día',
            PdfColors.teal700, fontBold, font,
            badge: '$cantidad abono${cantidad != 1 ? "s" : ""}'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.teal100, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(70),
            1: const pw.FixedColumnWidth(40),
            2: const pw.FlexColumnWidth(),
            3: const pw.FlexColumnWidth(),
            4: const pw.FixedColumnWidth(72),
            5: const pw.FixedColumnWidth(72),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.teal700),
              children: ['Separado', 'Hora', 'Cliente',
                'Empleado', 'Método', 'Monto']
                  .map((h) => _th(h, fontBold))
                  .toList(),
            ),
            ...rep.abonos.asMap().entries.map((entry) {
              final i = entry.key;
              final a = entry.value;
              final created = a['created_at']?.toString() ?? '';
              final hora    = created.length >= 19
                  ? created.substring(11, 16) : '';
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isEven
                      ? PdfColors.teal50 : PdfColors.white),
                children: [
                  _td('SEP-${a['separado_id']}', fontBold,
                      color: PdfColors.teal700),
                  _td(hora, font),
                  _td(a['cliente_nombre'] ?? '', font),
                  _td(a['empleado_nombre'] ?? '', font),
                  _td(a['metodo_pago'] ?? '', fontMedium),
                  _td('\$${_fmt(double.tryParse(
                      a['monto'].toString()) ?? 0)}',
                      fontBold, color: PdfColors.teal700),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.teal100),
              children: [
                ...List.generate(4, (_) => _td('', font)),
                _td('TOTAL', fontBold, color: PdfColors.teal900),
                _td('\$${_fmt(totalAbonos)}', fontBold,
                    color: PdfColors.teal900, size: 11),
              ],
            ),
          ],
        ),
      ],
    );
  }


  // ── Gastos — con resumen neto final ────────────────

  static pw.Widget _buildGastos({
    required List<Gasto> gastos,
    required double totalGastos,
    required double totalVentas,
    required double totalDevoluciones,
    required pw.Font fontBold,
    required pw.Font font,
    required pw.Font fontMedium,
  }) {
    final utilidad      = totalVentas - totalDevoluciones - totalGastos;
    final utilidadColor = utilidad >= 0
        ? PdfColors.green800 : PdfColors.red800;
    final utilidadBg    = utilidad >= 0
        ? const PdfColor.fromInt(0xFFE8F5E9)
        : const PdfColor.fromInt(0xFFFFEBEE);
    final utilidadBorder = utilidad >= 0
        ? PdfColors.green300 : PdfColors.red300;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Gastos del día',
            PdfColors.orange800, fontBold, font,
            badge: '${gastos.length} registro${gastos.length != 1 ? "s" : ""}'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.orange100, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(38),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FixedColumnWidth(72),
            5: const pw.FixedColumnWidth(72),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.orange800),
              children: ['Hora', 'Descripción', 'Categoría',
                'Empleado', 'Método', 'Monto']
                  .map((h) => _th(h, fontBold))
                  .toList(),
            ),
            ...gastos.asMap().entries.map((entry) {
              final i = entry.key;
              final g = entry.value;
              final hora = g.createdAt.length >= 19
                  ? g.createdAt.substring(11, 16) : '';
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isEven
                      ? const PdfColor.fromInt(0xFFFFF8F0)
                      : PdfColors.white),
                children: [
                  _td(hora, font),
                  _td(g.descripcion, fontMedium,
                      color: PdfColors.orange900),
                  _td(g.categoria, font,
                      color: PdfColors.grey600),
                  _td(g.empleadoNombre, font),
                  _td(g.metodoPago, fontMedium),
                  _td('-\$${_fmt(g.monto)}', fontBold,
                      color: PdfColors.orange800),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.orange100),
              children: [
                ...List.generate(4, (_) => _td('', font)),
                _td('TOTAL', fontBold, color: PdfColors.orange900),
                _td('-\$${_fmt(totalGastos)}', fontBold,
                    color: PdfColors.orange900, size: 11),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 12),

        // ── Resumen neto final ─────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: utilidadBg,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: utilidadBorder),
          ),
          child: pw.Row(
            children: [
              _resumenItem('Ventas brutas',
                  '\$${_fmt(totalVentas)}',
                  PdfColors.teal700, font, fontBold),
              _separadorV(),
              _resumenItem('Devoluciones',
                  '-\$${_fmt(totalDevoluciones)}',
                  PdfColors.red700, font, fontBold),
              _separadorV(),
              _resumenItem('Gastos',
                  '-\$${_fmt(totalGastos)}',
                  PdfColors.orange700, font, fontBold),
              _separadorV(),
              _resumenItem(
                utilidad >= 0 ? 'Utilidad neta' : 'Pérdida neta',
                '\$${_fmt(utilidad.abs())}',
                utilidadColor, fontBold, fontBold,
                grande: true,
              ),
            ],
          ),
        ),
      ],
    );
  }


  // ── Helpers compartidos ────────────────────────────

  /// Título de sección con barra de color y badge opcional
  static pw.Widget _sectionTitle(
    String title, PdfColor color,
    pw.Font fontBold, pw.Font font, {
    String? badge,
  }) =>
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 4, height: 16,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(2)),
        ),
        pw.SizedBox(width: 8),
        pw.Text(title,
          style: pw.TextStyle(
              font: fontBold, fontSize: 13, color: color)),
        if (badge != null) ...[
          pw.SizedBox(width: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(20),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Text(badge,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 8,
                  color: color)),
          ),
        ],
      ],
    );

  /// Celda de cabecera
  static pw.Widget _th(String text, pw.Font fontBold,
      {PdfColor color = PdfColors.white}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 8, vertical: 6),
      child: pw.Text(text,
        style: pw.TextStyle(
            font: fontBold, fontSize: 9, color: color)),
    );

  /// Celda de dato
  static pw.Widget _td(String text, pw.Font font, {
    PdfColor? color,
    double size = 9,
  }) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 8, vertical: 5),
      child: pw.Text(text,
        style: pw.TextStyle(
            font: font, fontSize: size,
            color: color ?? PdfColors.grey800)),
    );

  /// Ítem del resumen neto final
  static pw.Widget _resumenItem(
    String label, String valor, PdfColor color,
    pw.Font font, pw.Font fontBold, {bool grande = false}
  ) =>
    pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(valor,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                font: fontBold,
                fontSize: grande ? 15 : 12,
                color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                font: font, fontSize: 8,
                color: PdfColors.grey600)),
        ],
      ),
    );

  /// Divisor vertical para el resumen
  static pw.Widget _separadorV() =>
    pw.Container(
      width: 1, height: 36,
      color: PdfColors.grey300,
      margin: const pw.EdgeInsets.symmetric(horizontal: 6),
    );


  // ── Formato números ────────────────────────────────

  static String _fmt(double v) => v.abs()
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
}