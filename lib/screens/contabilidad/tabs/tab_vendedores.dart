import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../core/api_client.dart';

class TabVendedores extends StatefulWidget {
  final int? tiendaId;
  const TabVendedores({super.key, required this.tiendaId});

  @override
  State<TabVendedores> createState() => _TabVendedoresState();
}

class _TabVendedoresState extends State<TabVendedores> {
  final _fmt     = NumberFormat('#,##0', 'es_CO');
  final _fmtDate = DateFormat('d MMM', 'es');

  List<Map<String, dynamic>> _empleados = [];
  bool   _cargando = false;
  String _error    = '';
  DateTime _desde  = DateTime.now().copyWith(day: 1);
  DateTime _hasta  = DateTime.now();

  static const _surface  = Colors.white;
  static const _border   = Color(0xFFE2E8F0);
  static const _text     = Color(0xFF1E293B);
  static const _muted    = Color(0xFF64748B);
  static const _card     = Color(0xFFF8FAFC);
  static const _green    = Color(0xFF16A34A);
  static const _greenBg  = Color(0xFFDCFCE7);
  static const _amber    = Color(0xFFD97706);
  static const _amberBg  = Color(0xFFFEF3C7);
  static const _blue     = Color(0xFF2563EB);
  static const _blueBg   = Color(0xFFEFF6FF);
  static const _red      = Color(0xFFDC2626);
  static const _redBg    = Color(0xFFFEE2E2);
  static const _purple   = Color(0xFF7C3AED);
  static const _purpleBg = Color(0xFFEDE9FE);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabVendedores old) {
    super.didUpdateWidget(old);
    if (old.tiendaId != widget.tiendaId) _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = ''; });
    try {
      final params = <String, String>{
        'fecha_ini': DateFormat('yyyy-MM-dd').format(_desde),
        'fecha_fin': DateFormat('yyyy-MM-dd').format(_hasta),
        if (widget.tiendaId != null) 'tienda_id': '${widget.tiendaId}',
      };
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/ventas-por-empleado/',
        queryParameters: params,
      );
      final data = r.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _empleados = (data['empleados'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error al cargar datos.'; _cargando = false; });
    }
  }

  Future<void> _elegirFecha(bool esDesde) async {
    final inicial = esDesde ? _desde : _hasta;
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (esDesde) {
        _desde = picked;
        if (_hasta.isBefore(_desde)) _hasta = _desde;
      } else {
        _hasta = picked;
        if (_desde.isAfter(_hasta)) _desde = _hasta;
      }
    });
    _cargar();
  }

  void _abrirDetalle(Map<String, dynamic> emp, int rank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleVendedorSheet(
        emp:  emp,
        rank: rank,
        fmt:  _fmt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildFiltros(),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildFiltros() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(children: [
        Expanded(child: _chipFecha('Desde', _desde, () => _elegirFecha(true))),
        const SizedBox(width: 8),
        Expanded(child: _chipFecha('Hasta', _hasta, () => _elegirFecha(false))),
        const SizedBox(width: 8),
        InkWell(
          onTap: _cargar,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _chipFecha(String label, DateTime fecha, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
          color: _card,
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 14, color: _muted),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: _muted)),
            Text(_fmtDate.format(fecha),
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(child: Text(_error,
          style: GoogleFonts.inter(color: Colors.red)));
    }
    if (_empleados.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 48, color: _muted),
          const SizedBox(height: 12),
          Text('Sin ventas en el período',
              style: GoogleFonts.inter(color: _muted, fontSize: 15)),
        ],
      ));
    }

    final totalVentas = _empleados.fold<double>(
        0, (s, e) => s + (e['total_ventas'] as num).toDouble());

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _empleados.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildKpis(totalVentas);
        final emp = _empleados[i - 1];
        return _buildEmpleadoCard(emp, i, totalVentas);
      },
    );
  }

  Widget _buildKpis(double totalVentas) {
    final totalTx = _empleados.fold<int>(0, (s, e) => s + (e['num_ventas'] as int));
    final promedio = totalTx > 0 ? totalVentas / totalTx : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        _kpi('Total período', '\$${_fmt.format(totalVentas)}', _green, _greenBg),
        const SizedBox(width: 12),
        _kpi('Transacciones', '$totalTx', _blue, _blueBg),
        const SizedBox(width: 12),
        _kpi('Ticket prom.', '\$${_fmt.format(promedio)}', _amber, _amberBg),
      ]),
    );
  }

  Widget _kpi(String label, String value, Color color, Color bg) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(
            fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis),
      ]),
    ));
  }

  Widget _buildEmpleadoCard(
      Map<String, dynamic> emp, int rank, double totalGlobal) {
    final total    = (emp['total_ventas'] as num).toDouble();
    final nVentas  = emp['num_ventas'] as int;
    final promedio = (emp['promedio_venta'] as num).toDouble();
    final descto   = (emp['total_descuentos'] as num).toDouble();
    final pct      = totalGlobal > 0 ? total / totalGlobal : 0.0;

    final rankColors = [
      const Color(0xFFD97706),
      const Color(0xFF64748B),
      const Color(0xFFB45309),
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : _muted;

    return GestureDetector(
      onTap: () => _abrirDetalle(emp, rank),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3 ? rankColor.withAlpha(25) : _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: rankColor.withAlpha(80)),
                ),
                child: Center(child: Text('$rank',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: rankColor))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(emp['nombre'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _text))),
              Text('\$${_fmt.format(total)}',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _green)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: _border,
                valueColor: AlwaysStoppedAnimation(
                    rank == 1 ? const Color(0xFFD97706) : AppColors.secondary),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _stat(Icons.receipt_long, '$nVentas ventas'),
              const SizedBox(width: 16),
              _stat(Icons.trending_up, 'Prom \$${_fmt.format(promedio)}'),
              const SizedBox(width: 16),
              if (descto > 0)
                _stat(Icons.local_offer, 'Dscto \$${_fmt.format(descto)}',
                    color: _amber),
              const Spacer(),
              Text('${(pct * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String text, {Color color = _muted}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.inter(
          fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — Detalle contable del vendedor
// ══════════════════════════════════════════════════════════════════

class _DetalleVendedorSheet extends StatelessWidget {
  final Map<String, dynamic> emp;
  final int rank;
  final NumberFormat fmt;

  const _DetalleVendedorSheet({
    required this.emp,
    required this.rank,
    required this.fmt,
  });

  static const _bg     = Color(0xFFF8FAFC);
  static const _card   = Colors.white;
  static const _border = Color(0xFFE2E8F0);
  static const _text   = Color(0xFF1E293B);
  static const _muted  = Color(0xFF64748B);
  static const _green  = Color(0xFF16A34A);
  static const _amber  = Color(0xFFD97706);
  static const _red    = Color(0xFFDC2626);
  static const _blue   = Color(0xFF2563EB);
  static const _teal   = Color(0xFF0D9488);
  static const _purple = Color(0xFF7C3AED);

  double _v(String key) => (emp[key] as num? ?? 0).toDouble();
  int    _i(String key) => (emp[key] as num? ?? 0).toInt();

  @override
  Widget build(BuildContext context) {
    final nombre        = emp['nombre'] as String? ?? '';
    final total         = _v('total_ventas');
    final nVentas       = _i('num_ventas');
    final promedio      = _v('promedio_venta');
    final descuentos    = _v('total_descuentos');
    final ventaMax      = _v('venta_max');
    final ventaMin      = _v('venta_min');
    final efectivo      = _v('ventas_efectivo');
    final tarjeta       = _v('ventas_tarjeta');
    final transferencia = _v('ventas_transferencia');
    final mixto         = _v('ventas_mixto');
    final credito       = _v('ventas_credito');
    final numDev        = _i('num_devoluciones');
    final totalDev      = _v('total_devoluciones');
    final porDia        = (emp['ventas_por_dia'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: _border, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          _buildHeader(nombre, total, nVentas, rank),
          const Divider(height: 1),
          // Scrollable body
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              _buildMetodosPago(efectivo, tarjeta, transferencia, mixto, credito, total),
              const SizedBox(height: 14),
              _buildDesempeno(promedio, descuentos, ventaMax, ventaMin, numDev, totalDev),
              if (porDia.length > 1) ...[
                const SizedBox(height: 14),
                _buildSparkline(porDia),
              ],
              const SizedBox(height: 24),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildHeader(String nombre, double total, int nVentas, int rank) {
    final rankColors = [
      const Color(0xFFD97706),
      const Color(0xFF64748B),
      const Color(0xFFB45309),
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : _muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: rankColor.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: rankColor.withAlpha(100), width: 2),
          ),
          child: Center(child: Text('$rank',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w800, color: rankColor))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w800, color: _text)),
          Text('$nVentas transacciones',
              style: GoogleFonts.inter(fontSize: 12, color: _muted)),
        ])),
        Text('\$${fmt.format(total)}',
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w900, color: _green)),
      ]),
    );
  }

  Widget _buildMetodosPago(double ef, double tj, double tr, double mx, double cr, double total) {
    final metodos = <_MetodoPago>[
      _MetodoPago('Efectivo',        ef, Icons.payments_outlined,    _green),
      _MetodoPago('Tarjeta',         tj, Icons.credit_card_outlined,  _blue),
      _MetodoPago('Transferencia',   tr, Icons.send_outlined,         _teal),
      _MetodoPago('Mixto',           mx, Icons.shuffle_outlined,      _purple),
      if (cr > 0)
        _MetodoPago('Crédito',       cr, Icons.schedule_outlined,     _amber),
    ].where((m) => m.monto > 0).toList();

    if (metodos.isEmpty) return const SizedBox.shrink();

    return _seccion(
      titulo: 'MÉTODO DE PAGO',
      child: Column(
        children: metodos.map((m) {
          final pct = total > 0 ? m.monto / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: m.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(m.icon, size: 15, color: m.color),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(m.label,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: _text, fontWeight: FontWeight.w600))),
                Text('\$${fmt.format(m.monto)}',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Text('${(pct * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 4,
                  backgroundColor: _border,
                  valueColor: AlwaysStoppedAnimation(m.color.withAlpha(180)),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDesempeno(double promedio, double descuentos,
      double ventaMax, double ventaMin, int numDev, double totalDev) {
    return _seccion(
      titulo: 'DESEMPEÑO',
      child: Column(children: [
        Row(children: [
          Expanded(child: _metricaTile(
            'Ticket promedio', '\$${fmt.format(promedio)}',
            Icons.trending_up_rounded, _blue, const Color(0xFFEFF6FF))),
          const SizedBox(width: 10),
          Expanded(child: _metricaTile(
            'Descuentos', '\$${fmt.format(descuentos)}',
            Icons.local_offer_outlined, _amber, const Color(0xFFFEF3C7))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _metricaTile(
            'Venta mayor', '\$${fmt.format(ventaMax)}',
            Icons.arrow_upward_rounded, _green, const Color(0xFFDCFCE7))),
          const SizedBox(width: 10),
          Expanded(child: _metricaTile(
            'Venta menor', '\$${fmt.format(ventaMin)}',
            Icons.arrow_downward_rounded, _muted, const Color(0xFFF1F5F9))),
        ]),
        if (numDev > 0) ...[
          const SizedBox(height: 10),
          _metricaTile(
            'Devoluciones', '$numDev · \$${fmt.format(totalDev)}',
            Icons.assignment_return_outlined, _red, const Color(0xFFFEE2E2),
            fullWidth: true,
          ),
        ],
      ]),
    );
  }

  Widget _metricaTile(String label, String valor, IconData icon,
      Color color, Color bg, {bool fullWidth = false}) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(valor, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
      ]),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: content) : content;
  }

  Widget _buildSparkline(List<Map<String, dynamic>> porDia) {
    final valores = porDia.map((d) => (d['total'] as num).toDouble()).toList();
    final maxVal  = valores.reduce((a, b) => a > b ? a : b);
    final fmtDia  = DateFormat('d/M');

    return _seccion(
      titulo: 'ACTIVIDAD POR DÍA',
      child: SizedBox(
        height: 80,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(porDia.length, (i) {
            final v   = valores[i];
            final pct = maxVal > 0 ? v / maxVal : 0.0;
            final fecha = DateTime.tryParse(porDia[i]['fecha'] as String? ?? '');
            final isMax = v == maxVal;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isMax)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('\$${fmt.format(v)}',
                            style: GoogleFonts.inter(
                                fontSize: 8, color: _green,
                                fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 4 + (60 * pct),
                      decoration: BoxDecoration(
                        color: isMax
                            ? _green
                            : const Color(0xFF16A34A).withAlpha(80),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    if (fecha != null) ...[
                      const SizedBox(height: 4),
                      Text(fmtDia.format(fecha),
                          style: GoogleFonts.inter(
                              fontSize: 8, color: _muted)),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _seccion({required String titulo, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: _muted, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _MetodoPago {
  final String label;
  final double monto;
  final IconData icon;
  final Color color;
  const _MetodoPago(this.label, this.monto, this.icon, this.color);
}
