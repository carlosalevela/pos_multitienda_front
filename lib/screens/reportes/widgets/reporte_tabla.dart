import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/reportes_provider.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../models/contabilidad_models.dart';
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
    final gastos = context.watch<ContabilidadProvider>().gastos;

    final hayDatos = rep.ventas.isNotEmpty ||
        rep.abonos.isNotEmpty ||
        rep.devoluciones.isNotEmpty ||
        gastos.isNotEmpty;

    if (!hayDatos) {
      return reporteCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 48, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                Text('Sin ventas para esta fecha',
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade400, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    final rows = <DataRow>[
      ..._ventasRows(),
      ..._separadorAbonos(),
      ..._abonosRows(),
      ..._separadorDevoluciones(),
      ..._devolucionesRows(),
      ..._separadorGastos(gastos),
      ..._gastosRows(gastos),
    ];

    return reporteCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera de la card ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                sectionTitle(Icons.list_alt_rounded, 'Detalle de ventas'),
                const Spacer(),
                if (rep.devoluciones.isNotEmpty) ...[
                  reporteBadge(
                    '${rep.numDevoluciones} dev.',
                    kDevColor,
                    kDevColor.withOpacity(0.08),
                    kDevColor.withOpacity(0.25),
                  ),
                  const SizedBox(width: 8),
                ],
                if (rep.abonos.isNotEmpty) ...[
                  reporteBadge(
                    '${rep.cantidadAbonos} abono${rep.cantidadAbonos > 1 ? "s" : ""}',
                    const Color(0xFF00796B),
                    const Color(0xFFE0F2F1),
                    const Color(0xFF80CBC4),
                  ),
                  const SizedBox(width: 8),
                ],
                if (gastos.isNotEmpty)
                  reporteBadge(
                    '${gastos.length} gasto${gastos.length > 1 ? "s" : ""}',
                    const Color(0xFFF57C00),
                    const Color(0xFFFFF3E0),
                    const Color(0xFFFFCC80),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minWidth = 1100.0;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: constraints.maxWidth > minWidth
                            ? constraints.maxWidth
                            : minWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor:
                          WidgetStateProperty.all(kDark),
                      headingTextStyle: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      dataTextStyle:
                          GoogleFonts.poppins(fontSize: 12),
                      columnSpacing: 20,
                      horizontalMargin: 16,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 44,
                      dividerThickness: 0.5,
                      showBottomBorder: false,
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
                      rows: rows,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Ventas ────────────────────────────────────────────
  List<DataRow> _ventasRows() => rep.ventas.map((v) {
        final hora = (v['created_at']?.toString() ?? '').length >= 19
            ? v['created_at'].toString().substring(11, 16)
            : '';
        final esAnulada = v['estado'] == 'anulada';

        return DataRow(
          color: esAnulada
              ? WidgetStateProperty.all(
                  const Color(0xFFFFF5F5))
              : WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.hovered)
                      ? const Color(0xFFF0F4FF)
                      : Colors.white,
                ),
          onSelectChanged: (_) => onTapVenta(v['id']),
          cells: [
            DataCell(Text(v['numero_factura'] ?? '',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: kAccent,
                    fontSize: 12))),
            DataCell(Text(hora,
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500))),
            DataCell(
                Text(v['cliente_nombre'] ?? 'Consumidor Final')),
            DataCell(Text(v['empleado_nombre'] ?? '')),
            DataCell(Row(children: [
              Icon(iconMetodo(v['metodo_pago'] ?? ''),
                  size: 13,
                  color: colorMetodo(v['metodo_pago'] ?? '')),
              const SizedBox(width: 5),
              Flexible(
                  child: Text(
                      labelMetodo(v['metodo_pago'] ?? ''))),
            ])),
            DataCell(Text(
                '\$${fmtNum(double.tryParse(v['total'].toString()) ?? 0)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600))),
            DataCell(Text(
                '\$${fmtNum(double.tryParse(v['vuelto'].toString()) ?? 0)}',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400))),
            DataCell(estadoBadge(v['estado'] ?? '')),
          ],
        );
      }).toList();

  // ── Separador: borde izq + fondo suave ───────────────
  DataRow _separadorSeccion({
    required String label,
    required Color color,
  }) =>
      DataRow(
        color: WidgetStateProperty.all(color.withOpacity(0.06)),
        cells: [
          DataCell(
            Row(children: [
              Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ]),
          ),
          ...List.generate(7, (_) => const DataCell(Text(''))),
        ],
      );

  // ── Abonos ────────────────────────────────────────────
  List<DataRow> _separadorAbonos() {
    if (rep.abonos.isEmpty) return [];
    return [_separadorSeccion(
        label: 'ABONOS A SEPARADOS',
        color: const Color(0xFF00796B))];
  }

  List<DataRow> _abonosRows() => rep.abonos.map((a) {
        final hora = (a['created_at']?.toString() ?? '').length >= 19
            ? a['created_at'].toString().substring(11, 16)
            : '';
        return DataRow(
          color: WidgetStateProperty.all(
              const Color(0xFFE0F2F1).withOpacity(0.4)),
          cells: [
            DataCell(Text('SEP-${a['separado_id']}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00796B),
                    fontSize: 12))),
            DataCell(Text(hora,
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500))),
            DataCell(Text(a['cliente_nombre'] ?? '')),
            DataCell(Text(a['empleado_nombre'] ?? '')),
            DataCell(Row(children: [
              Icon(iconMetodo(a['metodo_pago'] ?? ''),
                  size: 13,
                  color: colorMetodo(a['metodo_pago'] ?? '')),
              const SizedBox(width: 5),
              Flexible(
                  child:
                      Text(labelMetodo(a['metodo_pago'] ?? ''))),
            ])),
            DataCell(Text(
                '\$${fmtNum(double.tryParse(a['monto'].toString()) ?? 0)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00796B)))),
            DataCell(Text('—',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400))),
            DataCell(abonoBadge()),
          ],
        );
      }).toList();

  // ── Devoluciones ──────────────────────────────────────
  List<DataRow> _separadorDevoluciones() {
    if (rep.devoluciones.isEmpty) return [];
    return [_separadorSeccion(
        label: 'DEVOLUCIONES', color: kDevColor)];
  }

  List<DataRow> _devolucionesRows() =>
      rep.devoluciones.map((d) {
        final hora = (d['created_at']?.toString() ?? '').length >= 19
            ? d['created_at'].toString().substring(11, 16)
            : '';
        final total =
            double.tryParse(d['total_devuelto']?.toString() ?? '0') ??
                0;
        final metodo =
            d['metodo_devolucion']?.toString() ?? '';
        final factura =
            d['venta_numero'] ?? 'DEV-${d['id']}';
        final empleado = d['empleado_nombre'] ?? '';
        final productos =
            (d['productos_devueltos'] as List? ?? [])
                .map((p) =>
                    '${p['producto']} x${(double.tryParse(p['cantidad'].toString()) ?? 0).toStringAsFixed(0)}')
                .join(', ');

        return DataRow(
          color: WidgetStateProperty.all(
              kDevColor.withOpacity(0.04)),
          cells: [
            DataCell(Text(factura,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: kDevColor,
                    fontSize: 12))),
            DataCell(Text(hora,
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500))),
            DataCell(Text(productos,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11))),
            DataCell(Text(empleado)),
            DataCell(Row(children: [
              Icon(iconMetodo(metodo),
                  size: 13,
                  color: colorMetodo(metodo)),
              const SizedBox(width: 5),
              Flexible(
                  child: Text(labelMetodo(metodo))),
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

  // ── Gastos ────────────────────────────────────────────
  List<DataRow> _separadorGastos(List<Gasto> gastos) {
    if (gastos.isEmpty) return [];
    return [_separadorSeccion(
        label: 'GASTOS', color: const Color(0xFFF57C00))];
  }

  List<DataRow> _gastosRows(List<Gasto> gastos) =>
      gastos.map((g) {
        final hora = g.createdAt.length >= 19
            ? g.createdAt.substring(11, 16)
            : '';

        return DataRow(
          color: WidgetStateProperty.all(
              const Color(0xFFFFF3E0).withOpacity(0.5)),
          cells: [
            DataCell(Text(g.descripcion,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF57C00),
                    fontSize: 12))),
            DataCell(Text(hora,
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500))),
            DataCell(
              g.categoria.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFFFFCC80)),
                      ),
                      child: Text(g.categoria,
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE65100))),
                    )
                  : const Text(''),
            ),
            DataCell(Text(g.empleadoNombre)),
            DataCell(Row(children: [
              Icon(iconMetodo(g.metodoPago),
                  size: 13,
                  color: colorMetodo(g.metodoPago)),
              const SizedBox(width: 5),
              Flexible(
                  child: Text(labelMetodo(g.metodoPago))),
            ])),
            DataCell(Text('-\$${fmtNum(g.monto)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF57C00)))),
            DataCell(Text('—',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400))),
            DataCell(gastosBadge()),
          ],
        );
      }).toList();
}