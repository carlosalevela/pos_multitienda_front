import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/reportes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../services/venta_service.dart';
import '../../services/reporte_pdf_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  DateTime _fecha = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  void _cargar() {
    final auth = context.read<AuthProvider>();
    context.read<ReportesProvider>().cargarVentas(
      tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
      fecha:    _fechaStr,
    );
  }

  String get _fechaStr =>
      '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final rep  = context.watch<ReportesProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(Constants.backgroundColor),
      body: Column(children: [
        // ── Header ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          color: Colors.white,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(Constants.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Color(Constants.primaryColor), size: 26),
            ),
            const SizedBox(width: 14),
            Text('Reportes de ventas',
              style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E))),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _seleccionarFecha,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(_fechaStr,
                  style: GoogleFonts.poppins(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(Constants.primaryColor),
                side: const BorderSide(color: Color(Constants.primaryColor)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: rep.ventas.isEmpty
                  ? null
                  : () => ReportePdfService.generarReporteDia(
                        rep:          rep,
                        fecha:        _fechaStr,
                        tiendaNombre: auth.tiendaNombre,
                      ),
              icon:  const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Text('Exportar PDF',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor:         Colors.red.shade600,
                foregroundColor:         Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ),

        // ── Contenido ─────────────────────────────────────
        Expanded(
          child: rep.cargando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildKpis(rep),
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 320,
                              child: Column(children: [
                                _buildMetodosPago(rep),
                                const SizedBox(height: 12),
                                Expanded(child: _buildTopProductos(rep)),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTabla(rep)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  // ── KPIs ──────────────────────────────────────────────

  Widget _buildKpis(ReportesProvider rep) {
    return Row(children: [
      Expanded(child: _kpiCard(
        icon:  Icons.attach_money_rounded,
        label: 'Total vendido',
        valor: '\$${_fmt(rep.totalDia)}',
        color: Colors.green.shade700,
        bg:    Colors.green.shade50,
      )),
      const SizedBox(width: 10),
      Expanded(child: _kpiCard(
        icon:  Icons.receipt_long_rounded,
        label: 'Ventas',
        valor: '${rep.totalVentas}',
        color: Colors.blue.shade700,
        bg:    Colors.blue.shade50,
      )),
      const SizedBox(width: 10),
      Expanded(child: _kpiCard(
        icon:  Icons.trending_up_rounded,
        label: 'Ticket promedio',
        valor: '\$${_fmt(rep.ticketPromedio)}',
        color: Colors.purple.shade700,
        bg:    Colors.purple.shade50,
      )),
      const SizedBox(width: 10),
      Expanded(child: _kpiCard(
        icon:  Icons.discount_rounded,
        label: 'Descuentos',
        valor: '\$${_fmt(rep.totalDescuentos)}',
        color: Colors.orange.shade700,
        bg:    Colors.orange.shade50,
      )),
      if (rep.totalAbonos > 0) ...[
        const SizedBox(width: 10),
        Expanded(child: _kpiCard(
          icon:  Icons.bookmark_rounded,
          label: 'Abonos separados',
          valor: '\$${_fmt(rep.totalAbonos)}',
          color: Colors.teal.shade700,
          bg:    Colors.teal.shade50,
        )),
      ],
      if (rep.totalAnuladas > 0) ...[
        const SizedBox(width: 10),
        Expanded(child: _kpiCard(
          icon:  Icons.cancel_rounded,
          label: 'Anuladas',
          valor: '${rep.totalAnuladas}',
          color: Colors.red.shade700,
          bg:    Colors.red.shade50,
        )),
      ],
    ]);
  }

  Widget _kpiCard({
    required IconData icon,
    required String   label,
    required String   valor,
    required Color    color,
    required Color    bg,
  }) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valor,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.grey.shade600)),
        ]),
      ]),
    );

  // ── Métodos de pago ───────────────────────────────────

  Widget _buildMetodosPago(ReportesProvider rep) {
    final metodos = rep.totalPorMetodo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Por método de pago',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          if (metodos.isEmpty)
            Text('Sin datos',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13))
          else
            ...metodos.entries.map((e) {
              final porcentaje = rep.totalDia == 0 ? 0.0 : e.value / rep.totalDia;
              final color = _colorMetodo(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(_iconMetodo(e.key), size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(_labelMetodo(e.key),
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${_fmt(e.value)}',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color)),
                          Text('${(porcentaje * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           porcentaje,
                        minHeight:       7,
                        backgroundColor: Colors.grey.shade100,
                        valueColor:      AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Top productos ─────────────────────────────────────

  Widget _buildTopProductos(ReportesProvider rep) {
    final top = rep.topProductos;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top productos',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          if (top.isEmpty)
            Text('Sin datos',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13))
          else
            ...top.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final colors = [
                Colors.blue.shade600,
                Colors.green.shade600,
                Colors.orange.shade600,
                Colors.purple.shade600,
                Colors.teal.shade600,
              ];
              final color = colors[i % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: color)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p['nombre'],
                      style:    GoogleFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${_fmt(p['subtotal'])}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: color)),
                      Text('x${(p['cantidad'] as double).toStringAsFixed(0)} uds',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }

  // ── Tabla ─────────────────────────────────────────────

  Widget _buildTabla(ReportesProvider rep) {
    final hayDatos = rep.ventas.isNotEmpty || rep.abonos.isNotEmpty;

    if (!hayDatos) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Center(child: Column(children: [
          Icon(Icons.receipt_long_rounded,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin ventas para esta fecha',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 15)),
        ])),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              Text('Detalle de ventas',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              if (rep.abonos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    '${rep.cantidadAbonos} abono${rep.cantidadAbonos > 1 ? "s" : ""}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: Colors.teal.shade700)),
                ),
              const SizedBox(width: 16),
            ]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF1A1A2E)),
                headingTextStyle: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600,
                  fontSize: 13),
                dataTextStyle:    GoogleFonts.poppins(fontSize: 12),
                columnSpacing:    24,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
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
                  // ── Ventas normales ──────────────────────
                  ...rep.ventas.map((v) {
                    final created   = v['created_at']?.toString() ?? '';
                    final hora      = created.length >= 19
                        ? created.substring(11, 16) : '';
                    final esAnulada = v['estado'] == 'anulada';
                    return DataRow(
                      color: esAnulada
                          ? WidgetStateProperty.all(Colors.red.shade50)
                          : null,
                      onSelectChanged: (_) =>
                          _abrirDetalleVenta(context, v['id']),
                      cells: [
                        DataCell(Text(v['numero_factura'] ?? '',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: const Color(Constants.primaryColor),
                              fontSize: 12))),
                        DataCell(Text(hora)),
                        DataCell(Text(v['cliente_nombre'] ?? 'Consumidor Final')),
                        DataCell(Text(v['empleado_nombre'] ?? '')),
                        DataCell(Row(children: [
                          Icon(_iconMetodo(v['metodo_pago'] ?? ''),
                              size: 13,
                              color: _colorMetodo(v['metodo_pago'] ?? '')),
                          const SizedBox(width: 4),
                          Text(_labelMetodo(v['metodo_pago'] ?? '')),
                        ])),
                        DataCell(Text(
                          '\$${_fmt(double.tryParse(v['total'].toString()) ?? 0)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                        DataCell(Text(
                          '\$${_fmt(double.tryParse(v['vuelto'].toString()) ?? 0)}',
                          style: GoogleFonts.poppins(color: Colors.grey.shade600))),
                        DataCell(_estadoBadge(v['estado'] ?? '')),
                      ],
                    );
                  }),

                  // ── Abonos separados ─────────────────────
                  ...rep.abonos.map((a) {
                    final created = a['created_at']?.toString() ?? '';
                    final hora    = created.length >= 19
                        ? created.substring(11, 16) : '';
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
                          Icon(_iconMetodo(a['metodo_pago'] ?? ''),
                              size: 13,
                              color: _colorMetodo(a['metodo_pago'] ?? '')),
                          const SizedBox(width: 4),
                          Text(_labelMetodo(a['metodo_pago'] ?? '')),
                        ])),
                        DataCell(Text(
                          '\$${_fmt(double.tryParse(a['monto'].toString()) ?? 0)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700))),
                        DataCell(Text('—',
                          style: GoogleFonts.poppins(
                              color: Colors.grey.shade400))),
                        DataCell(_abonoBadge()),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  Color _colorMetodo(String m) {
    switch (m.toLowerCase()) {
      case 'efectivo':      return Colors.green.shade600;
      case 'transferencia': return Colors.blue.shade600;
      case 'tarjeta':       return Colors.purple.shade600;
      default:              return Colors.grey.shade600;
    }
  }

  IconData _iconMetodo(String m) {
    switch (m.toLowerCase()) {
      case 'efectivo':      return Icons.payments_rounded;
      case 'transferencia': return Icons.account_balance_rounded;
      case 'tarjeta':       return Icons.credit_card_rounded;
      default:              return Icons.attach_money_rounded;
    }
  }

  String _labelMetodo(String m) {
    switch (m.toLowerCase()) {
      case 'efectivo':      return 'Efectivo';
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      default:              return m;
    }
  }

  Future<void> _seleccionarFecha() async {
    final nueva = await showDatePicker(
      context:     context,
      initialDate: _fecha,
      firstDate:   DateTime(2024),
      lastDate:    DateTime(2030),
    );
    if (nueva == null) return;
    setState(() => _fecha = nueva);
    _cargar();
  }

  Future<void> _abrirDetalleVenta(
      BuildContext context, int ventaId) async {
    final detalle = await VentaService().obtenerVenta(ventaId);
    if (!context.mounted || detalle == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.receipt_long_rounded,
              color: Color(Constants.primaryColor)),
          const SizedBox(width: 10),
          Text(detalle['numero_factura'] ?? '',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detalleRow(Icons.person_rounded,  'Cliente',
                    detalle['cliente_nombre'] ?? 'Consumidor Final'),
                _detalleRow(Icons.badge_rounded,   'Empleado',
                    detalle['empleado_nombre'] ?? ''),
                _detalleRow(Icons.store_rounded,   'Tienda',
                    detalle['tienda_nombre'] ?? ''),
                _detalleRow(
                    _iconMetodo(detalle['metodo_pago'] ?? ''),
                    'Método',
                    _labelMetodo(detalle['metodo_pago'] ?? '')),
                const Divider(height: 20),
                _detalleRow(Icons.shopping_bag_rounded, 'Subtotal',
                    '\$${_fmt(double.tryParse(detalle['subtotal'].toString()) ?? 0)}'),
                if ((double.tryParse(
                        detalle['descuento_total'].toString()) ?? 0) > 0)
                  _detalleRow(Icons.discount_rounded, 'Descuento',
                    '-\$${_fmt(double.tryParse(detalle['descuento_total'].toString()) ?? 0)}',
                    color: Colors.orange),
                _detalleRow(Icons.attach_money_rounded, 'Total',
                    '\$${_fmt(double.tryParse(detalle['total'].toString()) ?? 0)}',
                    color: const Color(Constants.primaryColor), bold: true),
                _detalleRow(Icons.payments_rounded, 'Recibido',
                    '\$${_fmt(double.tryParse(detalle['monto_recibido'].toString()) ?? 0)}'),
                _detalleRow(Icons.change_circle_rounded, 'Vuelto',
                    '\$${_fmt(double.tryParse(detalle['vuelto'].toString()) ?? 0)}',
                    color: Colors.green.shade600),
                const Divider(height: 20),
                Text('Productos',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...(detalle['detalles'] as List? ?? []).map((item) =>
                  Container(
                    margin:  const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(item['producto_nombre'] ?? '',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500, fontSize: 13)),
                      ),
                      Text(
                        'x${double.tryParse(item['cantidad'].toString())?.toStringAsFixed(0) ?? 0}  ',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade600)),
                      Text(
                        '\$${_fmt(double.tryParse(item['subtotal'].toString()) ?? 0)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: const Color(Constants.primaryColor))),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  Widget _detalleRow(IconData icon, String label, String valor,
      {Color? color, bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text('$label: ',
          style: GoogleFonts.poppins(
              fontSize: 13, color: Colors.grey.shade600)),
        Expanded(
          child: Text(valor,
            style: GoogleFonts.poppins(
              fontSize:   13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color:      color ?? const Color(0xFF1A1A2E),
            )),
        ),
      ]),
    );

  // ── Badges ────────────────────────────────────────────

  Widget _estadoBadge(String estado) {
    final esAnulada = estado == 'anulada';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: esAnulada ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: esAnulada ? Colors.red.shade200 : Colors.green.shade200),
      ),
      child: Text(estado,
        style: GoogleFonts.poppins(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color: esAnulada ? Colors.red.shade700 : Colors.green.shade700,
        )),
    );
  }

  Widget _abonoBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:        Colors.teal.shade50,
      borderRadius: BorderRadius.circular(20),
      border:       Border.all(color: Colors.teal.shade200),
    ),
    child: Text('abono',
      style: GoogleFonts.poppins(
        fontSize:   11,
        fontWeight: FontWeight.w600,
        color:      Colors.teal.shade700,
      )),
  );
}