import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/reportes_provider.dart';
import '../models/contabilidad_models.dart';
import 'documento_service.dart';


class ReportePdfService {
  static Future<File?> generarReporteDia({
    required ReportesProvider rep,
    required String fecha,
    required String tiendaNombre,
    required String empresaNombre,
    List<Gasto> gastos = const [],
    bool soloGuardar = false,
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

    final bytes = await pdf.save();
    File? archivo;
    try {
      archivo = await DocumentoService.instance.guardarReporte(
        bytes: bytes,
        nombre: fecha,
      );
    } catch (_) {}
    if (!soloGuardar) {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Reporte_$fecha.pdf',
      );
    }
    return archivo;
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
    final totalMetodos = metodos.values.fold(0.0, (s, v) => s + v);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Ingresos por método de pago',
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
                    '${(totalMetodos == 0 ? 0
                        : (e.value / totalMetodos * 100))
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
              final tipo = d['tipo']?.toString() ?? '';
              final productos = (d['detalles'] as List? ?? d['productos_devueltos'] as List? ?? [])
                  .map((p) {
                    final nombre = p['producto_nombre']?.toString()
                        ?? p['producto']?.toString() ?? '';
                    final cant = (double.tryParse(p['cantidad'].toString()) ?? 0)
                        .toStringAsFixed(0);
                    return '$nombre x$cant';
                  })
                  .join(', ');
              // Productos entregados en cambio
              final reemplazosRaw = d['reemplazos'] as List? ?? [];
              final entregados = reemplazosRaw.isNotEmpty
                  ? reemplazosRaw.map((r) {
                      final nombre = r['producto_nombre']?.toString()
                          ?? r['nombre']?.toString() ?? '';
                      final cant = (double.tryParse(
                              r['cantidad']?.toString() ?? '0') ?? 0)
                          .toStringAsFixed(0);
                      return '$nombre x$cant';
                    }).join(', ')
                  : '';

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isEven ? PdfColors.red50 : PdfColors.white),
                children: [
                  _td(factura, fontBold, color: PdfColors.red700),
                  _td(hora, font),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(productos,
                            style: pw.TextStyle(font: font, fontSize: 8)),
                        if (tipo == 'cambio' && entregados.isNotEmpty)
                          pw.Text('→ $entregados',
                              style: pw.TextStyle(
                                  font: fontMedium, fontSize: 7,
                                  color: PdfColors.green800)),
                      ],
                    ),
                  ),
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


  // ── Cierre de turno (cajero) ───────────────────────

  static Future<File?> generarCierreTurno({
    required dynamic sesion,          // SesionCaja
    required String fecha,
    required String tiendaNombre,
    required String empresaNombre,
    required Map<String, double> metodosPago,
    required List<Map<String, dynamic>> gastosSesion,
    required double totalGastos,
    List<TopProducto> topProductos           = const [],
    List<Map<String, dynamic>> separadosDia  = const [],
    List<Map<String, dynamic>> resumenCuentas = const [],
    List<Map<String, dynamic>> ventasDia     = const [],
    List<Map<String, dynamic>> abonosDia     = const [],
    bool soloGuardar = false,
  }) async {
    final pdf        = pw.Document();
    final font       = await PdfGoogleFonts.poppinsRegular();
    final fontBold   = await PdfGoogleFonts.poppinsBold();
    final fontMedium = await PdfGoogleFonts.poppinsMedium();

    final horaApertura = () {
      final dt = sesion.fecha_apertura as DateTime;
      return '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    }();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Comprobante de Cierre de Turno',
                      style: pw.TextStyle(font: fontBold, fontSize: 16,
                          color: const PdfColor.fromInt(0xFF0B7A53))),
                    pw.SizedBox(height: 2),
                    pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(tiendaNombre,
                        style: pw.TextStyle(font: fontBold, fontSize: 13,
                            color: const PdfColor.fromInt(0xFF1A1A2E))),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text('Cajero: ${sesion.empleadoNombre}  •  Turno #${sesion.id}',
                      style: pw.TextStyle(font: font, fontSize: 10,
                          color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Fecha: $fecha',
                    style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  pw.Text('Apertura: $horaApertura',
                    style: pw.TextStyle(font: font, fontSize: 10,
                        color: PdfColors.grey500)),
                ],
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sistema POS — $tiendaNombre',
                style: pw.TextStyle(font: font, fontSize: 9,
                    color: PdfColors.grey500)),
              pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 9,
                    color: PdfColors.grey500)),
            ],
          ),
        ),
        build: (ctx) {
          // Construir lista unificada FAC / SEP / ABO
          final ventas   = ventasDia.where((v) =>
              (v['estado']?.toString() ?? '') != 'anulada').toList();
          final sepDia   = separadosDia;
          final abonoLst = abonosDia;

          double totalFac = ventas.fold(0.0, (s, v) =>
              s + (double.tryParse(v['total']?.toString() ?? '0') ?? 0));
          double totalSep = sepDia.fold(0.0, (s, v) =>
              s + (double.tryParse(v['total']?.toString() ?? '0') ?? 0));
          double totalAbo = abonoLst.fold(0.0, (s, v) =>
              s + (double.tryParse(v['monto']?.toString() ?? '0') ?? 0));

          String _metLabel(String? m) => switch (m?.toLowerCase() ?? '') {
            'tarjeta'       => 'Tarjeta',
            'transferencia' => 'Transf.',
            'mixto'         => 'Mixto',
            'credito'       => 'Crédito',
            _               => 'Efectivo',
          };

          pw.Widget _buildTransactionRow(
              String num, String tipo, String desc,
              String metodo, String monto,
              PdfColor colorTipo, pw.Font fnt, pw.Font fntBold) =>
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Row(children: [
                pw.SizedBox(width: 28,
                  child: pw.Text(num,
                    style: pw.TextStyle(font: fnt, fontSize: 9,
                        color: PdfColors.grey500))),
                pw.Container(
                  width: 34, height: 16,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: colorTipo.shade(0.15),
                    borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text(tipo,
                    style: pw.TextStyle(font: fntBold, fontSize: 8,
                        color: colorTipo))),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(desc,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(font: fnt, fontSize: 9,
                        color: const PdfColor.fromInt(0xFF1A1A2E)))),
                pw.SizedBox(width: 6),
                pw.SizedBox(width: 60,
                  child: pw.Text(metodo,
                    style: pw.TextStyle(font: fnt, fontSize: 9,
                        color: PdfColors.grey600))),
                pw.SizedBox(width: 70,
                  child: pw.Text(monto,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: fntBold, fontSize: 9,
                        color: const PdfColor.fromInt(0xFF1A1A2E)))),
              ]),
            );

          pw.Widget _subtotalRow(String label, int count,
              double total, PdfColor color, pw.Font fntBold, pw.Font fnt) =>
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 4, left: 34),
              child: pw.Row(children: [
                pw.Container(
                  width: 34, height: 15,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: color.shade(0.15),
                    borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text(label,
                    style: pw.TextStyle(font: fntBold, fontSize: 8,
                        color: color))),
                pw.SizedBox(width: 8),
                pw.Text('$count operación${count != 1 ? "es" : ""}',
                  style: pw.TextStyle(font: fnt, fontSize: 9,
                      color: PdfColors.grey600)),
                pw.Expanded(child: pw.SizedBox()),
                pw.SizedBox(width: 70,
                  child: pw.Text('\$${_fmt(total)}',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: fntBold, fontSize: 9,
                        color: color))),
              ]),
            );

          return [
          // ── Disclaimer IVA ─────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFFFF8E1),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFFFCC02))),
            child: pw.Text(
              'Este comprobante no es válido como factura fiscal. Somos NO responsables de IVA.',
              style: pw.TextStyle(font: fontMedium, fontSize: 8,
                  color: const PdfColor.fromInt(0xFF856404))),
          ),
          pw.SizedBox(height: 14),

          // ── Balance de caja ────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFE8FFF4),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFF61DDAA)),
            ),
            child: pw.Row(
              children: [
                _turnoItem('Saldo apertura',
                    '\$${_fmt(sesion.saldo_inicial as double)}',
                    PdfColors.grey700, font, fontBold),
                _separadorV(),
                _turnoItem('Ventas del turno',
                    '+\$${_fmt(sesion.ventasTotal as double)}',
                    const PdfColor.fromInt(0xFF0B7A53), font, fontBold),
                _separadorV(),
                _turnoItem('Gastos del turno',
                    '-\$${_fmt(sesion.gastosTotal as double)}',
                    PdfColors.orange700, font, fontBold),
                _separadorV(),
                _turnoItem('Efectivo esperado',
                    '\$${_fmt(sesion.montoEsperado as double)}',
                    const PdfColor.fromInt(0xFF0B7A53), fontBold, fontBold,
                    grande: true),
                _separadorV(),
                _turnoItem(
                    'Valor a\nentregar',
                    '\$${_fmt((sesion.montoEsperado as double) - (sesion.saldo_inicial as double))}',
                    const PdfColor.fromInt(0xFF7C3AED), fontBold, fontBold,
                    grande: true),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ── Ventas por método ──────────────────
          if (metodosPago.isNotEmpty) ...[
            _sectionTitle('Ventas por método de pago',
                PdfColors.blueGrey700, fontBold, font),
            pw.SizedBox(height: 8),
            pw.Row(
              children: metodosPago.entries.map((e) => pw.Expanded(
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
                        '${(metodosPago.values.fold(0.0, (s, v) => s + v) == 0 ? 0
                            : (e.value / metodosPago.values.fold(0.0, (s, v) => s + v) * 100))
                            .toStringAsFixed(1)}%',
                        style: pw.TextStyle(font: font, fontSize: 9,
                            color: PdfColors.grey500)),
                    ],
                  ),
                ),
              )).toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Gastos del turno ───────────────────
          if (gastosSesion.isNotEmpty) ...[
            _sectionTitle('Gastos del turno',
                PdfColors.orange800, fontBold, font,
                badge: '${gastosSesion.length} registro${gastosSesion.length != 1 ? "s" : ""}'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.orange100, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.orange800),
                  children: ['Descripción', 'Categoría',
                    'Método', 'Monto']
                      .map((h) => _th(h, fontBold))
                      .toList(),
                ),
                ...gastosSesion.asMap().entries.map((entry) {
                  final i = entry.key;
                  final g = entry.value;
                  final monto = double.tryParse(
                      g['monto']?.toString() ?? '0') ?? 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? const PdfColor.fromInt(0xFFFFF8F0)
                          : PdfColors.white),
                    children: [
                      _td(g['descripcion']?.toString() ?? '', fontMedium,
                          color: PdfColors.orange900),
                      _td(g['categoria']?.toString() ?? '', font,
                          color: PdfColors.grey600),
                      _td(g['metodo_pago']?.toString() ?? '', fontMedium),
                      _td('-\$${_fmt(monto)}', fontBold,
                          color: PdfColors.orange800),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.orange100),
                  children: [
                    ...List.generate(2, (_) => _td('', font)),
                    _td('TOTAL', fontBold, color: PdfColors.orange900),
                    _td('-\$${_fmt(totalGastos)}', fontBold,
                        color: PdfColors.orange900, size: 11),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Cuentas destino del turno ─────────
          if (resumenCuentas.isNotEmpty) ...[
            _sectionTitle('Ingresos por cuenta',
                const PdfColor.fromInt(0xFF7B1FA2), fontBold, font,
                badge: '${resumenCuentas.length} cuenta${resumenCuentas.length != 1 ? "s" : ""}'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: const PdfColor.fromInt(0xFFE1BEE7), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FixedColumnWidth(90),
                3: const pw.FixedColumnWidth(110),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF7B1FA2)),
                  children: ['Cuenta', 'Tipo', 'Este turno', 'Acumulado total']
                      .map((h) => _th(h, fontBold))
                      .toList(),
                ),
                ...resumenCuentas.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  final sesionT = double.tryParse(c['sesion_total']?.toString()    ?? '0') ?? 0;
                  final acumT   = double.tryParse(c['total_acumulado']?.toString() ?? '0') ?? 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? const PdfColor.fromInt(0xFFF3E5F5)
                          : PdfColors.white),
                    children: [
                      _td(c['nombre']?.toString() ?? '—', fontMedium,
                          color: const PdfColor.fromInt(0xFF4A148C)),
                      _td(c['tipo_display']?.toString() ?? '—', font,
                          color: PdfColors.grey600),
                      _td('\$${_fmt(sesionT)}', fontBold,
                          color: const PdfColor.fromInt(0xFF7B1FA2)),
                      _td('\$${_fmt(acumT)}', fontBold,
                          color: const PdfColor.fromInt(0xFF4A148C)),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Abonos del turno ──────────────────
          if ((sesion.abonosTotal as double) > 0) ...[
            _sectionTitle('Abonos del turno',
                PdfColors.indigo700, fontBold, font,
                badge: '${sesion.numAbonos} abono${(sesion.numAbonos as int) != 1 ? "s" : ""}'),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _buildAbonoCard('Efectivo',
                    sesion.abonosEfectivo as double,
                    sesion.abonosTotal as double,
                    PdfColors.indigo700, font, fontBold),
                _buildAbonoCard('Tarjeta',
                    sesion.abonosTarjeta as double,
                    sesion.abonosTotal as double,
                    PdfColors.indigo700, font, fontBold),
                _buildAbonoCard('Transferencia',
                    sesion.abonosTransferencia as double,
                    sesion.abonosTotal as double,
                    PdfColors.indigo700, font, fontBold),
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 8),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFE8EAF6),
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.indigo200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL',
                          style: pw.TextStyle(font: fontBold, fontSize: 9,
                              color: PdfColors.indigo700)),
                        pw.SizedBox(height: 4),
                        pw.Text('\$${_fmt(sesion.abonosTotal as double)}',
                          style: pw.TextStyle(font: fontBold, fontSize: 14,
                              color: PdfColors.indigo700)),
                        pw.Text('100%',
                          style: pw.TextStyle(font: font, fontSize: 9,
                              color: PdfColors.grey500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Separados activos ──────────────────
          if (separadosDia.isNotEmpty) ...[
            _sectionTitle('Separados del día',
                PdfColors.teal700, fontBold, font,
                badge: '${separadosDia.length} separado${separadosDia.length != 1 ? "s" : ""}'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.teal100, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.teal700),
                  children: ['Cliente', 'Estado', 'Abonado', 'Total']
                      .map((h) => _th(h, fontBold))
                      .toList(),
                ),
                ...separadosDia.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final total   = double.tryParse(s['total']?.toString()   ?? '0') ?? 0;
                  final abonado = double.tryParse(s['abonado']?.toString() ?? '0') ?? 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? const PdfColor.fromInt(0xFFE0F2F1)
                          : PdfColors.white),
                    children: [
                      _td(s['cliente_nombre']?.toString()
                          ?? s['cliente']?.toString() ?? '—', fontMedium,
                          color: PdfColors.teal900),
                      _td(s['estado']?.toString() ?? '—', font,
                          color: PdfColors.grey600),
                      _td('\$${_fmt(abonado)}', font, color: PdfColors.teal700),
                      _td('\$${_fmt(total)}', fontBold, color: PdfColors.teal900),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Productos más vendidos ─────────────
          if (topProductos.isNotEmpty) ...[
            _sectionTitle('Productos vendidos',
                PdfColors.blue800, fontBold, font,
                badge: '${topProductos.length} producto${topProductos.length != 1 ? "s" : ""}'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.blue100, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(90),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.blue800),
                  children: ['Producto', 'Categoría', 'Cant.', 'Ingresos']
                      .map((h) => _th(h, fontBold))
                      .toList(),
                ),
                ...topProductos.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? const PdfColor.fromInt(0xFFE3F2FD)
                          : PdfColors.white),
                    children: [
                      _td(p.producto, fontMedium, color: PdfColors.blue900),
                      _td(p.categoria, font, color: PdfColors.grey600),
                      _td(p.totalVendido.toStringAsFixed(
                          p.totalVendido == p.totalVendido.roundToDouble() ? 0 : 1),
                          fontBold, color: PdfColors.blue700),
                      _td('\$${_fmt(p.totalIngresos)}', fontBold,
                          color: PdfColors.blue800),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Detalle FAC / SEP / ABO ────────────
          if (ventas.isNotEmpty || sepDia.isNotEmpty || abonoLst.isNotEmpty) ...[
            _sectionTitle(
              'Detalle de transacciones del turno',
              const PdfColor.fromInt(0xFF1A1A2E), fontBold, font,
              badge: '${ventas.length + sepDia.length + abonoLst.length} total',
            ),
            pw.SizedBox(height: 4),
            // Header de tabla
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1A1A2E)),
              child: pw.Row(children: [
                pw.SizedBox(width: 28,
                  child: pw.Text('#', style: pw.TextStyle(font: fontBold,
                      fontSize: 8, color: PdfColors.white))),
                pw.SizedBox(width: 34,
                  child: pw.Text('Tipo', style: pw.TextStyle(font: fontBold,
                      fontSize: 8, color: PdfColors.white))),
                pw.SizedBox(width: 6),
                pw.Expanded(child: pw.Text('Descripción',
                  style: pw.TextStyle(font: fontBold, fontSize: 8,
                      color: PdfColors.white))),
                pw.SizedBox(width: 66,
                  child: pw.Text('Método', style: pw.TextStyle(font: fontBold,
                      fontSize: 8, color: PdfColors.white))),
                pw.SizedBox(width: 70,
                  child: pw.Text('Monto', textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: fontBold, fontSize: 8,
                        color: PdfColors.white))),
              ]),
            ),
            // Ventas (FAC) — con desglose de productos
            ...ventas.asMap().entries.expand((e) {
              final v        = e.value;
              final total    = double.tryParse(v['total']?.toString() ?? '0') ?? 0;
              final id       = v['id']?.toString() ?? '${e.key + 1}';
              final met      = _metLabel(v['metodo_pago']?.toString());
              final desc     = 'FAC #$id  •  $met';
              final detalles = v['detalles'] is List
                  ? (v['detalles'] as List).cast<Map>() : <Map>[];
              return [
                _buildTransactionRow(
                  '${e.key + 1}', 'FAC', desc,
                  _metLabel(v['metodo_pago']?.toString()),
                  '\$${_fmt(total)}',
                  const PdfColor.fromInt(0xFF0B7A53), font, fontBold,
                ),
                ...detalles.map((d) {
                  final nombre  = d['producto_nombre']?.toString() ?? '';
                  final cant    = double.tryParse(d['cantidad']?.toString() ?? '1') ?? 1;
                  final sub     = double.tryParse(d['subtotal']?.toString()  ?? '0') ?? 0;
                  final cantStr = cant == cant.roundToDouble()
                      ? cant.toInt().toString() : cant.toStringAsFixed(1);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 68, top: 1, bottom: 1),
                    child: pw.Row(children: [
                      pw.Expanded(child: pw.Text(
                        '• $cantStr × $nombre',
                        style: pw.TextStyle(font: font, fontSize: 8,
                            color: PdfColors.grey600))),
                      pw.SizedBox(width: 70,
                        child: pw.Text('\$${_fmt(sub)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: font, fontSize: 8,
                              color: PdfColors.grey600))),
                    ]),
                  );
                }),
              ];
            }),
            if (ventas.isNotEmpty)
              _subtotalRow('FAC', ventas.length, totalFac,
                  const PdfColor.fromInt(0xFF0B7A53), fontBold, font),
            // Separados (SEP)
            ...sepDia.asMap().entries.map((e) {
              final s   = e.value;
              final tot = double.tryParse(s['total']?.toString() ?? '0') ?? 0;
              final cli = s['cliente_nombre']?.toString()
                       ?? s['cliente']?.toString() ?? '—';
              return _buildTransactionRow(
                '${ventas.length + e.key + 1}', 'SEP', cli,
                _metLabel(s['metodo_pago']?.toString()),
                '\$${_fmt(tot)}',
                const PdfColor.fromInt(0xFF0D7C8A), font, fontBold,
              );
            }),
            if (sepDia.isNotEmpty)
              _subtotalRow('SEP', sepDia.length, totalSep,
                  const PdfColor.fromInt(0xFF0D7C8A), fontBold, font),
            // Abonos (ABO)
            ...abonoLst.asMap().entries.map((e) {
              final a   = e.value;
              final mon = double.tryParse(a['monto']?.toString() ?? '0') ?? 0;
              final cli = a['cliente_nombre']?.toString() ?? '—';
              return _buildTransactionRow(
                '${ventas.length + sepDia.length + e.key + 1}', 'ABO', cli,
                _metLabel(a['metodo_pago']?.toString()),
                '\$${_fmt(mon)}',
                const PdfColor.fromInt(0xFF7C3AED), font, fontBold,
              );
            }),
            if (abonoLst.isNotEmpty)
              _subtotalRow('ABO', abonoLst.length, totalAbo,
                  const PdfColor.fromInt(0xFF7C3AED), fontBold, font),
            pw.SizedBox(height: 16),
          ],

          // ── Cuadre de caja detallado ────────────
          _sectionTitle('Cuadre de caja', const PdfColor.fromInt(0xFF0B7A53),
              fontBold, font),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFE8FFF4),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFF61DDAA)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Fila de KPIs principales
                pw.Row(children: [
                  _turnoItem('Saldo apertura',
                      '\$${_fmt(sesion.saldo_inicial as double)}',
                      PdfColors.grey700, font, fontBold),
                  _separadorV(),
                  _turnoItem('Ventas del turno',
                      '+\$${_fmt(sesion.ventasTotal as double)}',
                      const PdfColor.fromInt(0xFF0B7A53), font, fontBold),
                  _separadorV(),
                  _turnoItem('Gastos del turno',
                      '-\$${_fmt(sesion.gastosTotal as double)}',
                      PdfColors.orange700, font, fontBold),
                  _separadorV(),
                  _turnoItem('Efectivo esperado',
                      '\$${_fmt(sesion.montoEsperado as double)}',
                      const PdfColor.fromInt(0xFF0B7A53), fontBold, fontBold,
                      grande: true),
                ]),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                // Desglose efectivo
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Desglose efectivo en caja:',
                          style: pw.TextStyle(font: fontBold, fontSize: 10,
                              color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('Fondo base:  \$${_fmt(sesion.saldo_inicial as double)}',
                          style: pw.TextStyle(font: font, fontSize: 9,
                              color: PdfColors.grey600)),
                        pw.Text(
                          '+ Ingresos ef:  \$${_fmt(sesion.montoEsperado - sesion.saldo_inicial + gastosSesion.where((g) => (g['metodo_pago']?.toString() ?? '').toLowerCase() == 'efectivo').fold<double>(0, (s, g) => s + (double.tryParse(g['monto']?.toString() ?? '0') ?? 0)))}',
                          style: pw.TextStyle(font: font, fontSize: 9,
                              color: const PdfColor.fromInt(0xFF0B7A53))),
                        if (gastosSesion.any((g) =>
                            (g['metodo_pago']?.toString() ?? '').toLowerCase() == 'efectivo'))
                          pw.Text(
                            '− Gastos ef:  \$${_fmt(gastosSesion.where((g) =>
                              (g['metodo_pago']?.toString() ?? '').toLowerCase() == 'efectivo')
                              .fold<double>(0, (s, g) =>
                                s + (double.tryParse(g['monto']?.toString() ?? '0') ?? 0)))}',
                            style: pw.TextStyle(font: font, fontSize: 9,
                                color: PdfColors.orange700)),
                      ],
                    ),
                    // Efectivo a entregar (destacado)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFF7C3AED),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('EFECTIVO A ENTREGAR',
                            style: pw.TextStyle(font: fontBold, fontSize: 10,
                                color: PdfColors.white)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '\$${_fmt((sesion.montoEsperado as double) - (sesion.saldo_inicial as double))}',
                            style: pw.TextStyle(font: fontBold, fontSize: 20,
                                color: PdfColors.white)),
                          pw.Text('(sin contar la base)',
                            style: pw.TextStyle(font: font, fontSize: 8,
                                color: const PdfColor.fromInt(0xFFDDD6FE))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
        },
      ),
    );

    final bytes = await pdf.save();
    File? archivo;
    try {
      archivo = await DocumentoService.instance.guardarReporte(
        bytes: bytes,
        nombre: 'cierre_turno_$fecha',
      );
    } catch (_) {}
    if (!soloGuardar) {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Cierre_turno_$fecha.pdf',
      );
    }
    return archivo;
  }

  static pw.Widget _turnoItem(
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

  static pw.Widget _buildAbonoCard(
    String label, double monto, double total,
    PdfColor accentColor, pw.Font font, pw.Font fontBold,
  ) =>
    pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.indigo100),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(),
              style: pw.TextStyle(font: fontBold, fontSize: 9,
                  color: accentColor)),
            pw.SizedBox(height: 4),
            pw.Text('\$${_fmt(monto)}',
              style: pw.TextStyle(font: fontBold, fontSize: 13,
                  color: accentColor)),
            pw.Text(
              total > 0
                  ? '${(monto / total * 100).toStringAsFixed(1)}%'
                  : '0%',
              style: pw.TextStyle(font: font, fontSize: 9,
                  color: PdfColors.grey500)),
          ],
        ),
      ),
    );

  // ── Formato números ────────────────────────────────

  static final _nf = NumberFormat('#,##0', 'es_CO');
  static String _fmt(double v) => _nf.format(v.abs());
}