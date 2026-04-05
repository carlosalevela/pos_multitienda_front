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

  static const _dark   = Color(0xFF1A1A2E);
  static const _accent = Color(Constants.primaryColor);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  void _cargar() {
    final auth = context.read<AuthProvider>();
    context.read<ReportesProvider>().cargarVentas(
      tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
      fecha: _fechaStr,
    );
  }

  String get _fechaStr =>
      '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-'
      '${_fecha.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final rep  = context.watch<ReportesProvider>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(children: [
        _buildHeader(rep, auth),
        Expanded(
          child: rep.cargando
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(rep),
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────

  Widget _buildHeader(ReportesProvider rep, AuthProvider auth) =>
    Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bar_chart_rounded, color: _accent, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reportes de ventas',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.bold, color: _dark)),
          Text(auth.tiendaNombre,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        ]),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _seleccionarFecha,
          icon: const Icon(Icons.calendar_today_rounded, size: 15),
          label: Text(_fechaStr, style: GoogleFonts.poppins(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: const BorderSide(color: _accent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: rep.ventas.isEmpty
              ? null
              : () => ReportePdfService.generarReporteDia(
                    rep: rep, fecha: _fechaStr,
                    tiendaNombre: auth.tiendaNombre),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
          label: Text('Exportar PDF',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );

  // ── Body ───────────────────────────────────────────────

  Widget _buildBody(ReportesProvider rep) =>
    SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
                  width: 300,
                  child: Column(children: [
                    _buildMetodosPago(rep),
                    const SizedBox(height: 12),
                    Expanded(child: _buildTopProductos(rep)),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildTabla(rep)),
              ],
            ),
          ),
        ],
      ),
    );

  // ── KPIs ───────────────────────────────────────────────

  Widget _buildKpis(ReportesProvider rep) {
    final kpis = [
      _KpiData(icon: Icons.attach_money_rounded,  label: 'Total vendido',
          valor: '\$${_fmt(rep.totalDia)}',         color: const Color(0xFF00897B)),
      _KpiData(icon: Icons.receipt_long_rounded,  label: 'Ventas',
          valor: '${rep.totalVentas}',              color: const Color(0xFF1976D2)),
      _KpiData(icon: Icons.trending_up_rounded,   label: 'Ticket promedio',
          valor: '\$${_fmt(rep.ticketPromedio)}',   color: const Color(0xFF7B1FA2)),
      _KpiData(icon: Icons.discount_rounded,      label: 'Descuentos',
          valor: '\$${_fmt(rep.totalDescuentos)}',  color: const Color(0xFFE65100)),
      if (rep.totalAbonos > 0)
        _KpiData(icon: Icons.bookmark_rounded,    label: 'Abonos',
            valor: '\$${_fmt(rep.totalAbonos)}',   color: const Color(0xFF00796B)),
      if (rep.totalAnuladas > 0)
        _KpiData(icon: Icons.cancel_rounded,      label: 'Anuladas',
            valor: '${rep.totalAnuladas}',          color: Colors.red.shade700),
    ];
    return Row(
      children: kpis.asMap().entries.map((e) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: e.key < kpis.length - 1 ? 10 : 0),
          child: _kpiCard(e.value),
        ),
      )).toList(),
    );
  }

  Widget _kpiCard(_KpiData d) => Container(
    height: 86,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border(left: BorderSide(color: d.color, width: 4)),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: d.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(d.icon, color: d.color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(d.valor,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 16, color: _dark)),
            const SizedBox(height: 2),
            Text(d.label,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    ]),
  );

  // ── Métodos de pago ────────────────────────────────────

  Widget _buildMetodosPago(ReportesProvider rep) {
    final metodos = rep.totalPorMetodo;
    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.payments_outlined, 'Por método de pago'),
        const SizedBox(height: 12),
        if (metodos.isEmpty)
          _empty('Sin datos')
        else
          ...metodos.entries.map((e) {
            final pct   = rep.totalDia == 0 ? 0.0 : e.value / rep.totalDia;
            final color = _colorMetodo(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_iconMetodo(e.key), size: 13, color: color),
                    const SizedBox(width: 6),
                    Text(_labelMetodo(e.key),
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('\$${_fmt(e.value)}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                      Text('${(pct * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: Colors.grey.shade400)),
                    ]),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    ));
  }

  // ── Top productos ──────────────────────────────────────

  Widget _buildTopProductos(ReportesProvider rep) {
    final top    = rep.topProductos;
    final colors = [
      const Color(0xFF1976D2), const Color(0xFF00897B),
      const Color(0xFFE65100), const Color(0xFF7B1FA2),
      const Color(0xFF00ACC1),
    ];
    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.emoji_events_outlined, 'Top productos'),
        const SizedBox(height: 12),
        if (top.isEmpty)
          _empty('Sin datos')
        else
          ...top.asMap().entries.map((e) {
            final color = colors[e.key % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(child: Text('${e.key + 1}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.bold, color: color))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value['nombre'],
                  style: GoogleFonts.poppins(fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('\$${_fmt(e.value['subtotal'])}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  Text('x${(e.value['cantidad'] as double).toStringAsFixed(0)} uds',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.grey.shade400)),
                ]),
              ]),
            );
          }),
      ],
    ));
  }

  // ── Tabla ──────────────────────────────────────────────

  Widget _buildTabla(ReportesProvider rep) {
    final hayDatos = rep.ventas.isNotEmpty || rep.abonos.isNotEmpty;

    if (!hayDatos) {
      return _card(child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text('Sin ventas para esta fecha',
              style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14)),
          ]),
        ),
      ));
    }

    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              _sectionTitle(Icons.list_alt_rounded, 'Detalle de ventas'),
              const Spacer(),
              if (rep.abonos.isNotEmpty)
                _badge(
                  '${rep.cantidadAbonos} abono${rep.cantidadAbonos > 1 ? "s" : ""}',
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
              bottomRight: Radius.circular(14),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor:    WidgetStateProperty.all(_dark),
                headingTextStyle:   GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                dataTextStyle:      GoogleFonts.poppins(fontSize: 12),
                columnSpacing:      20,
                dataRowMinHeight:   44,
                dataRowMaxHeight:   44,
                dividerThickness:   0.5,
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
                  // ── Ventas normales ───────────────────
                  ...rep.ventas.map((v) {
                    final hora      = (v['created_at']?.toString() ?? '').length >= 19
                        ? v['created_at'].toString().substring(11, 16) : '';
                    final esAnulada = v['estado'] == 'anulada';
                    return DataRow(
                      color: esAnulada
                          ? WidgetStateProperty.all(Colors.red.shade50)
                          : WidgetStateProperty.resolveWith((s) =>
                              s.contains(WidgetState.hovered)
                                  ? const Color(0xFFF0F4FF) : Colors.white),
                      onSelectChanged: (_) => _abrirDetalleVenta(context, v['id']),
                      cells: [
                        DataCell(Text(v['numero_factura'] ?? '',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _accent, fontSize: 12))),
                        DataCell(Text(hora)),
                        DataCell(Text(v['cliente_nombre'] ?? 'Consumidor Final')),
                        DataCell(Text(v['empleado_nombre'] ?? '')),
                        DataCell(Row(children: [
                          Icon(_iconMetodo(v['metodo_pago'] ?? ''),
                              size: 13, color: _colorMetodo(v['metodo_pago'] ?? '')),
                          const SizedBox(width: 5),
                          Text(_labelMetodo(v['metodo_pago'] ?? '')),
                        ])),
                        DataCell(Text(
                          '\$${_fmt(double.tryParse(v['total'].toString()) ?? 0)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                        DataCell(Text(
                          '\$${_fmt(double.tryParse(v['vuelto'].toString()) ?? 0)}',
                          style: GoogleFonts.poppins(color: Colors.grey.shade500))),
                        DataCell(_estadoBadge(v['estado'] ?? '')),
                      ],
                    );
                  }),

                  // ── Separador visual de abonos ────────
                  if (rep.abonos.isNotEmpty)
                    DataRow(
                      color: WidgetStateProperty.all(Colors.teal.shade700),
                      cells: [
                        DataCell(Text('ABONOS A SEPARADOS',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 11))),
                        ...List.generate(7, (_) => const DataCell(Text(''))),
                      ],
                    ),

                  // ── Filas de abonos ───────────────────
                  ...rep.abonos.map((a) {
                    final hora = (a['created_at']?.toString() ?? '').length >= 19
                        ? a['created_at'].toString().substring(11, 16) : '';
                    return DataRow(
                      color: WidgetStateProperty.all(Colors.teal.shade50),
                      cells: [
                        DataCell(Text('SEP-${a['separado_id']}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700, fontSize: 12))),
                        DataCell(Text(hora)),
                        DataCell(Text(a['cliente_nombre'] ?? '')),
                        DataCell(Text(a['empleado_nombre'] ?? '')),
                        DataCell(Row(children: [
                          Icon(_iconMetodo(a['metodo_pago'] ?? ''),
                              size: 13, color: _colorMetodo(a['metodo_pago'] ?? '')),
                          const SizedBox(width: 5),
                          Text(_labelMetodo(a['metodo_pago'] ?? '')),
                        ])),
                        DataCell(Text(
                          '\$${_fmt(double.tryParse(a['monto'].toString()) ?? 0)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700))),
                        DataCell(Text('—',
                          style: GoogleFonts.poppins(color: Colors.grey.shade400))),
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

  // ── Shared widgets ─────────────────────────────────────

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Widget _sectionTitle(IconData icon, String title) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: _dark.withOpacity(0.5)),
      const SizedBox(width: 7),
      Text(title, style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600, fontSize: 14, color: _dark)),
    ],
  );

  Widget _empty(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(msg,
        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
  );

  Widget _badge(String text, Color fg, Color bg, Color border) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Text(text, style: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
  );

  // ── Helpers ────────────────────────────────────────────

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  Color   _colorMetodo(String m) {
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
      context: context, initialDate: _fecha,
      firstDate: DateTime(2024), lastDate: DateTime(2030),
    );
    if (nueva == null) return;
    setState(() => _fecha = nueva);
    _cargar();
  }

  Future<void> _abrirDetalleVenta(BuildContext context, int ventaId) async {
    final detalle = await VentaService().obtenerVenta(ventaId);
    if (!context.mounted || detalle == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: _accent),
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
                _detalleRow(_iconMetodo(detalle['metodo_pago'] ?? ''), 'Método',
                    _labelMetodo(detalle['metodo_pago'] ?? '')),
                const Divider(height: 20),
                _detalleRow(Icons.shopping_bag_rounded, 'Subtotal',
                    '\$${_fmt(double.tryParse(detalle['subtotal'].toString()) ?? 0)}'),
                if ((double.tryParse(detalle['descuento_total'].toString()) ?? 0) > 0)
                  _detalleRow(Icons.discount_rounded, 'Descuento',
                      '-\$${_fmt(double.tryParse(detalle['descuento_total'].toString()) ?? 0)}',
                      color: Colors.orange),
                _detalleRow(Icons.attach_money_rounded, 'Total',
                    '\$${_fmt(double.tryParse(detalle['total'].toString()) ?? 0)}',
                    color: _accent, bold: true),
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
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(item['producto_nombre'] ?? '',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500, fontSize: 13))),
                      Text(
                        'x${double.tryParse(item['cantidad'].toString())?.toStringAsFixed(0) ?? 0}  ',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade600)),
                      Text(
                        '\$${_fmt(double.tryParse(item['subtotal'].toString()) ?? 0)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13, color: _accent)),
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
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
        Expanded(child: Text(valor,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color ?? _dark))),
      ]),
    );

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
          fontSize: 11, fontWeight: FontWeight.w600,
          color: esAnulada ? Colors.red.shade700 : Colors.green.shade700)),
    );
  }

  Widget _abonoBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.teal.shade50, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.teal.shade200),
    ),
    child: Text('abono',
      style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: Colors.teal.shade700)),
  );
}

// ── Data class KPI ─────────────────────────────────────

class _KpiData {
  final IconData icon;
  final String   label, valor;
  final Color    color;
  const _KpiData({required this.icon, required this.label,
      required this.valor, required this.color});
}