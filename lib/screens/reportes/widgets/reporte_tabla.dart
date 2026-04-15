// lib/screens/reportes/widgets/reporte_tabla.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/reportes_provider.dart';
import 'reporte_utils.dart';

class ReporteTabla extends StatelessWidget {
  final ReportesProvider rep;
  final void Function(int ventaId) onTapVenta;

  const ReporteTabla({
    super.key,
    required this.rep,
    required this.onTapVenta,
  });

  @override
  Widget build(BuildContext context) {
    final hayDatos = rep.ventas.isNotEmpty
        || rep.abonos.isNotEmpty
        || rep.devoluciones.isNotEmpty;

    if (!hayDatos) {
      return reporteCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.receipt_long_rounded,
                  size: 48, color: Colors.grey.shade200),
              const SizedBox(height: 12),
              Text('Sin ventas para esta fecha',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                    fontSize: 14)),
            ]),
          ),
        ),
      );
    }

    return reporteCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              sectionTitle(
                  Icons.list_alt_rounded, 'Detalle de ventas'),
              const Spacer(),
              if (rep.devoluciones.isNotEmpty) ...[
                reporteBadge(
                  '${rep.numDevoluciones} dev.',
                  kDevColor,
                  kDevColor.withOpacity(0.08),
                  kDevColor.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
              ],
              if (rep.abonos.isNotEmpty)
                reporteBadge(
                  '${rep.cantidadAbonos} '
                  'abono${rep.cantidadAbonos > 1 ? "s" : ""}',
                  Colors.teal.shade700,
                  Colors.teal.shade50,
                  Colors.teal.shade200,
                ),
            ]),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft:  Radius.circular(14),
              bottomRight: Radius.circular(14)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor:
                    WidgetStateProperty.all(kDark),
                headingTextStyle: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
                dataTextStyle: GoogleFonts.poppins(fontSize: 12),
                columnSpacing:    20,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 44,
                dividerThickness: 0.5,
                columns: const [
                  DataColumn(label: Text('Factura')),
                  DataColumn(label: Text('Hora')),
                  DataColumn(label: Text('Cliente')),
                  DataColumn(label: Text('Empleado')),
                  DataColumn(label: Text('Método')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Vuelto')),
                  DataColumn(label: Text('Estado')),
                ],
                rows: [
                  ..._ventasRows(),
                  ..._separadorAbonos(),
                  ..._abonosRows(),
                  ..._separadorDevoluciones(),
                  ..._devolucionesRows(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ventas ─────────────────────────────────────────
  List<DataRow> _ventasRows() => rep.ventas.map((v) {
    final hora = (v['created_at']?.toString() ?? '').length >= 19
        ? v['created_at'].toString().substring(11, 16) : '';
    final esAnulada = v['estado'] == 'anulada';
    return DataRow(
      color: esAnulada
          ? WidgetStateProperty.all(Colors.red.shade50)
          : WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.hovered)
                  ? const Color(0xFFF0F4FF)
                  : Colors.white),
      onSelectChanged: (_) => onTapVenta(v['id']),
      cells: [
        DataCell(Text(v['numero_factura'] ?? '',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: kAccent, fontSize: 12))),
        DataCell(Text(hora)),
        DataCell(Text(
            v['cliente_nombre'] ?? 'Consumidor Final')),
        DataCell(Text(v['empleado_nombre'] ?? '')),
        DataCell(Row(children: [
          Icon(iconMetodo(v['metodo_pago'] ?? ''),
              size: 13,
              color: colorMetodo(v['metodo_pago'] ?? '')),
          const SizedBox(width: 5),
          Text(labelMetodo(v['metodo_pago'] ?? '')),
        ])),
        DataCell(Text(
          '\$${fmtNum(double.tryParse(
              v['total'].toString()) ?? 0)}',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600))),
        DataCell(Text(
          '\$${fmtNum(double.tryParse(
              v['vuelto'].toString()) ?? 0)}',
          style: GoogleFonts.poppins(
              color: Colors.grey.shade500))),
        DataCell(estadoBadge(v['estado'] ?? '')),
      ],
    );
  }).toList();

  // ── separadores y filas abonos ─────────────────────
  List<DataRow> _separadorAbonos() {
    if (rep.abonos.isEmpty) return [];
    return [
      DataRow(
        color: WidgetStateProperty.all(Colors.teal.shade700),
        cells: [
          DataCell(Text('ABONOS A SEPARADOS',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11))),
          ...List.generate(7, (_) => const DataCell(Text(''))),
        ],
      ),
    ];
  }

  List<DataRow> _abonosRows() => rep.abonos.map((a) {
    final hora = (a['created_at']?.toString() ?? '').length >= 19
        ? a['created_at'].toString().substring(11, 16) : '';
    return DataRow(
      color: WidgetStateProperty.all(Colors.teal.shade50),
      cells: [
        DataCell(Text('SEP-${a['separado_id']}',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade700,
              fontSize: 12))),
        DataCell(Text(hora)),
        DataCell(Text(a['cliente_nombre'] ?? '')),
        DataCell(Text(a['empleado_nombre'] ?? '')),
        DataCell(Row(children: [
          Icon(iconMetodo(a['metodo_pago'] ?? ''),
              size: 13,
              color: colorMetodo(a['metodo_pago'] ?? '')),
          const SizedBox(width: 5),
          Text(labelMetodo(a['metodo_pago'] ?? '')),
        ])),
        DataCell(Text(
          '\$${fmtNum(double.tryParse(
              a['monto'].toString()) ?? 0)}',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade700))),
        DataCell(Text('—',
          style: GoogleFonts.poppins(
              color: Colors.grey.shade400))),
        DataCell(abonoBadge()),
      ],
    );
  }).toList();

  // ── separadores y filas devoluciones ───────────────
  List<DataRow> _separadorDevoluciones() {
    if (rep.devoluciones.isEmpty) return [];
    return [
      DataRow(
        color: WidgetStateProperty.all(kDevColor),
        cells: [
          DataCell(Text('DEVOLUCIONES',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11))),
          ...List.generate(7, (_) => const DataCell(Text(''))),
        ],
      ),
    ];
  }

  List<DataRow> _devolucionesRows() => rep.devoluciones.map((d) {
    final hora = (d['created_at']?.toString() ?? '').length >= 19
        ? d['created_at'].toString().substring(11, 16) : '';
    final total    = double.tryParse(
        d['total_devuelto']?.toString() ?? '0') ?? 0;
    final metodo   = d['metodo_devolucion']?.toString() ?? '';
    final factura  = d['venta_numero'] ?? 'DEV-${d['id']}';
    final empleado = d['empleado_nombre'] ?? '';
    final productos = (d['productos_devueltos'] as List? ?? [])
        .map((p) =>
            '${p['producto']} x${(double.tryParse(
                p['cantidad'].toString()) ?? 0).toStringAsFixed(0)}')
        .join(', ');

    return DataRow(
      color: WidgetStateProperty.all(
          kDevColor.withOpacity(0.05)),
      cells: [
        DataCell(Text(factura,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: kDevColor, fontSize: 12))),
        DataCell(Text(hora)),
        DataCell(Text(productos,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 11))),
        DataCell(Text(empleado)),
        DataCell(Row(children: [
          Icon(iconMetodo(metodo),
              size: 13, color: colorMetodo(metodo)),
          const SizedBox(width: 5),
          Text(labelMetodo(metodo)),
        ])),
        DataCell(Text('-\$${fmtNum(total)}',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: kDevColor))),
        DataCell(Text('—',
          style: GoogleFonts.poppins(
              color: Colors.grey.shade400))),
        DataCell(devolucionBadge()),
      ],
    );
  }).toList();
}