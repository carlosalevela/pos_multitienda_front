import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/contabilidad_models.dart';
import '../../../providers/contabilidad_provider.dart';

class TabResumenDia extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;

  const TabResumenDia({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
  });

  @override
  State<TabResumenDia> createState() => _TabResumenDiaState();
}

class _TabResumenDiaState extends State<TabResumenDia> {
  DateTime _fecha = DateTime.now();

  static const _transferBlue   = Color(0xFF3B82F6);
  static const _transferBlueBg = Color(0xFFEFF6FF);
  static const _amberColor     = Color(0xFFF59E0B);
  static const _purpleColor    = Color(0xFF8B5CF6);

  bool get _esHoy {
    final h = DateTime.now();
    return _fecha.year == h.year && _fecha.month == h.month && _fecha.day == h.day;
  }

  String get _labelFecha {
    if (_esHoy) return 'Hoy, ${_diaSemana(_fecha)}';
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    if (_fecha.year == ayer.year && _fecha.month == ayer.month && _fecha.day == ayer.day) {
      return 'Ayer, ${_diaSemana(_fecha)}';
    }
    return '${_fecha.day.toString().padLeft(2, '0')}/'
        '${_fecha.month.toString().padLeft(2, '0')}/'
        '${_fecha.year}';
  }

  String _diaSemana(DateTime d) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return dias[d.weekday - 1];
  }

  double _d(Map m, String key) =>
      double.tryParse(m[key]?.toString() ?? '0') ?? 0.0;

  String _shortNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  void _cargar() =>
      widget.cont.cargarResumenDiario(tiendaId: widget.tiendaId, fecha: _fecha);

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _fecha,
      firstDate:   DateTime(DateTime.now().year - 2),
      lastDate:    DateTime.now(),
      locale:      const Locale('es', 'CO'),
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   AppColors.secondary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _fecha) {
      setState(() => _fecha = picked);
      _cargar();
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cont = widget.cont;
    final r    = cont.resumenDiario;

    return Column(children: [
      _header(cont),
      const SizedBox(height: 16),
      Expanded(
        child: cont.cargando && r == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
            : RefreshIndicator(
                color: AppColors.secondary,
                onRefresh: () async => _cargar(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: r == null
                      ? _sinDatos()
                      : _dashboard(r, cont),
                ),
              ),
      ),
    ]);
  }

  Widget _dashboard(ResumenDiario r, ContabilidadProvider cont) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kpi6Row(r, cont),
        const SizedBox(height: 20),
        if (r.ventasPorHora.isNotEmpty || r.ventasPorMetodo.isNotEmpty) ...[
          _chartsHoraMetodo(r),
          const SizedBox(height: 20),
        ],
        _rankingsRow(r, cont),
        const SizedBox(height: 20),
        _movimientosRow(r, cont),
        const SizedBox(height: 20),
        if (r.cuadreEfectivo.isNotEmpty) ...[
          _cuadreEfectivo(r),
          const SizedBox(height: 20),
        ],
        _separadosSection(cont),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _header(ContabilidadProvider cont) {
    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: _seleccionarFecha,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.secondary),
              const SizedBox(width: 10),
              Text(_labelFecha,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.onSurface)),
              const Spacer(),
              if (!_esHoy)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Text('Histórico',
                      style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: AppColors.warning)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded, color: AppColors.onSurfaceVariant),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      InkWell(
        onTap: cont.cargando ? null : _cargar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: cont.cargando
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary))
              : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.onSurfaceVariant),
        ),
      ),
    ]);
  }

  // ── 6 KPI cards ───────────────────────────────────────────

  Widget _kpi6Row(ResumenDiario r, ContabilidadProvider cont) {
    final ticketProm  = r.numVentas > 0 ? r.totalVentas / r.numVentas : 0.0;
    final utilPct     = r.totalVentas > 0 ? (r.utilidadBruta / r.totalVentas * 100) : 0.0;
    final totalAbonos = cont.abonosDia.fold<double>(0.0, (s, a) => s + _d(a, 'monto'));

    final kpis = [
      _KpiData(label: 'Total Ventas',   value: '\$${widget.fmt.format(r.totalVentas)}',
               sub: '${r.numVentas} transacciones', subColor: AppColors.secondary, accent: true),
      _KpiData(label: 'Ticket Prom.',   value: '\$${widget.fmt.format(ticketProm)}',
               sub: 'por venta', subColor: AppColors.onSurfaceVariant),
      _KpiData(label: 'Utilidad Bruta', value: '\$${widget.fmt.format(r.utilidadBruta.abs())}',
               sub: 'Margen ${utilPct.abs().toStringAsFixed(1)}%',
               subColor: r.utilidadBruta >= 0 ? AppColors.secondary : AppColors.error),
      _KpiData(label: 'Gastos',         value: '\$${widget.fmt.format(r.totalGastos)}',
               sub: r.totalVentas > 0
                   ? '${(r.totalGastos / r.totalVentas * 100).toStringAsFixed(1)}% de ventas'
                   : 'Del día',
               subColor: _amberColor),
      _KpiData(label: 'Devoluciones',   value: '\$${widget.fmt.format(r.totalDevoluciones)}',
               sub: '${r.numDevoluciones} devol.',
               subColor: AppColors.error),
      _KpiData(label: 'Abonos Recib.',  value: '\$${widget.fmt.format(totalAbonos)}',
               sub: '${cont.abonosDia.length} cobros',
               subColor: _purpleColor),
    ];

    return LayoutBuilder(builder: (ctx, bc) {
      if (bc.maxWidth > 700) {
        return Row(
          children: kpis.map((k) => Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _kpiCard(k),
          ))).toList(),
        );
      }
      // 2 columnas en pantallas medianas/angostas
      return Column(children: [
        Row(children: kpis.take(2).map((k) => Expanded(child: Padding(
          padding: EdgeInsets.only(right: kpis.indexOf(k) == 0 ? 8 : 0),
          child: _kpiCard(k),
        ))).toList()),
        const SizedBox(height: 10),
        Row(children: kpis.skip(2).take(2).map((k) => Expanded(child: Padding(
          padding: EdgeInsets.only(right: kpis.indexOf(k) == 2 ? 8 : 0),
          child: _kpiCard(k),
        ))).toList()),
        const SizedBox(height: 10),
        Row(children: kpis.skip(4).map((k) => Expanded(child: Padding(
          padding: EdgeInsets.only(right: kpis.indexOf(k) == 4 ? 8 : 0),
          child: _kpiCard(k),
        ))).toList()),
      ]);
    });
  }

  Widget _kpiCard(_KpiData k) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (k.accent) Container(width: 3, color: AppColors.mint),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(k.accent ? 12 : 14, 14, 12, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.label,
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant, letterSpacing: 0.3)),
                const SizedBox(height: 6),
                Text(k.value,
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.onSurface, letterSpacing: -0.4)),
                const SizedBox(height: 3),
                Text(k.sub,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 10, color: k.subColor,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Charts: Hora + Método ─────────────────────────────────

  Widget _chartsHoraMetodo(ResumenDiario r) {
    return LayoutBuilder(builder: (ctx, bc) {
      final wide = bc.maxWidth > 700;
      final hora = _horasChart(r.ventasPorHora);
      final pie  = _pieMetodosCard(r.ventasPorMetodo);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: hora),
          const SizedBox(width: 14),
          Expanded(flex: 4, child: pie),
        ]);
      }
      return Column(children: [hora, const SizedBox(height: 14), pie]);
    });
  }

  Widget _horasChart(List<Map<String, dynamic>> horas) {
    if (horas.isEmpty) return const SizedBox.shrink();
    final maxVal = horas.fold<double>(0.0, (m, h) {
      final t = _d(h, 'total'); return t > m ? t : m;
    });

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ventas por hora',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                color: AppColors.onSurface)),
        const SizedBox(height: 4),
        Text('Monto por hora del día',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal > 0 ? maxVal * 1.3 : 100,
            barGroups: horas.asMap().entries.map((e) {
              final total = _d(e.value, 'total');
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: total,
                  gradient: LinearGradient(
                    colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.5)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal > 0 ? maxVal * 1.3 : 100,
                    color: AppColors.surfaceContainerLow,
                  ),
                ),
              ]);
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx >= horas.length) return const SizedBox();
                  final h = horas[idx]['hora'] as int? ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${h}h',
                        style: GoogleFonts.inter(fontSize: 10,
                            color: AppColors.onSurfaceVariant)),
                  );
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 50,
                getTitlesWidget: (v, _) {
                  if (v == 0) return const SizedBox();
                  return Text('\$${_shortNum(v)}',
                      style: GoogleFonts.inter(fontSize: 10,
                          color: AppColors.onSurfaceVariant));
                },
              )),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.outlineVariant, strokeWidth: 1, dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.onSurface,
                getTooltipItem: (group, _, rod, __) {
                  final h    = horas[group.x]['hora'] as int? ?? 0;
                  final cant = horas[group.x]['cantidad'] as int? ?? 0;
                  return BarTooltipItem(
                    '${h}:00\n',
                    GoogleFonts.inter(color: Colors.white, fontSize: 11),
                    children: [
                      TextSpan(
                        text: '\$${widget.fmt.format(rod.toY)} ($cant trx)',
                        style: GoogleFonts.inter(
                            color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            ),
          )),
        ),
        // Hora pico
        if (horas.isNotEmpty) ...[
          const SizedBox(height: 14),
          Builder(builder: (_) {
            final pico = horas.reduce((a, b) => _d(a, 'total') >= _d(b, 'total') ? a : b);
            final h    = pico['hora'] as int? ?? 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.secondary),
                const SizedBox(width: 6),
                Text('Hora pico',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.secondary)),
                const Spacer(),
                Text('$h:00 — \$${widget.fmt.format(_d(pico, "total"))}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800,
                        color: AppColors.secondary)),
              ]),
            );
          }),
        ],
      ],
    ));
  }

  Widget _pieMetodosCard(List<Map<String, dynamic>> metodos) {
    final total = metodos.fold<double>(0.0, (s, m) => s + _d(m, 'total'));
    if (metodos.isEmpty) return const SizedBox.shrink();

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Distribución por Método',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                color: AppColors.onSurface)),
        const SizedBox(height: 4),
        Text('% del total de ventas',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        SizedBox(height: 150, child: PieChart(PieChartData(
          sections: metodos.asMap().entries.map((e) {
            final val = _d(e.value, 'total');
            final pct = total > 0 ? val / total * 100 : 0.0;
            final col = _metodoPagoColor(e.value['metodo']?.toString() ?? '');
            return PieChartSectionData(
              value: val, color: col, radius: 50,
              title: '${pct.toStringAsFixed(0)}%',
              titleStyle: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
          sectionsSpace: 2, centerSpaceRadius: 42,
        ))),
        const SizedBox(height: 16),
        ...metodos.map((m) {
          final color = _metodoPagoColor(m['metodo']?.toString() ?? '');
          final label = _metodoPagoLabel(m['metodo']?.toString() ?? '');
          final cant  = m['cantidad'] ?? 0;
          final pct   = total > 0 ? _d(m, 'total') / total * 100 : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(child: Text(label,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.onSurface))),
              Text('$cant trx',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
              const SizedBox(width: 10),
              SizedBox(width: 72, child: Text('\$${widget.fmt.format(_d(m, "total"))}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.onSurface))),
              const SizedBox(width: 8),
              SizedBox(width: 32, child: Text('${pct.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant))),
            ]),
          );
        }),
      ],
    ));
  }

  // ── Rankings row ──────────────────────────────────────────

  Widget _rankingsRow(ResumenDiario r, ContabilidadProvider cont) {
    return LayoutBuilder(builder: (ctx, bc) {
      final wide   = bc.maxWidth > 850;
      final medium = bc.maxWidth > 500;
      final prods  = _topProductosCard(r.topProductosDia);
      final clientes = _topClientesCard(cont);
      final vendedores = _vendedoresCard(r.vendedoresDia);

      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: prods),
          const SizedBox(width: 14),
          Expanded(child: clientes),
          const SizedBox(width: 14),
          Expanded(child: vendedores),
        ]);
      }
      if (medium) {
        return Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: prods),
            const SizedBox(width: 14),
            Expanded(child: clientes),
          ]),
          const SizedBox(height: 14),
          vendedores,
        ]);
      }
      return Column(children: [
        prods, const SizedBox(height: 14),
        clientes, const SizedBox(height: 14),
        vendedores,
      ]);
    });
  }

  Widget _topProductosCard(List<Map<String, dynamic>> prods) {
    final maxIng = prods.fold<double>(0.0, (m, p) {
      final v = _d(p, 'ingresos'); return v > m ? v : m;
    });

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.mintLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.trending_up_rounded, size: 15, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Text('Top Productos', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
        ]),
        const SizedBox(height: 4),
        Text('por volumen de ventas del día',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (prods.isEmpty)
          _emptyState('Sin ventas este día', Icons.inventory_2_outlined)
        else
          ...prods.asMap().entries.map((e) {
            final p    = e.value;
            final ing  = _d(p, 'ingresos');
            final pct  = maxIng > 0 ? (ing / maxIng).clamp(0.0, 1.0) : 0.0;
            final cant = p['cantidad'] as int? ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('${e.key + 1}. ${p["nombre"] ?? ""}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.onSurface)),
                  ),
                  Text('\$${widget.fmt.format(ing)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.secondary)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 5,
                    backgroundColor: AppColors.outlineVariant,
                    valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 3),
                Text('$cant unidades',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
              ]),
            );
          }),
      ],
    ));
  }

  Widget _topClientesCard(ContabilidadProvider cont) {
    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.star_rounded, size: 15, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Top Clientes',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.onSurface))),
          if (cont.topClientes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(20)),
              child: Text('${cont.topClientes.length}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                      color: const Color(0xFF7C3AED))),
            ),
        ]),
        const SizedBox(height: 4),
        Text('mayor gasto en el día',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (cont.topClientes.isEmpty)
          _emptyState('Sin clientes registrados', Icons.person_search_rounded)
        else
          ...cont.topClientes.asMap().entries.map((e) => _topClienteRow(e.key, e.value)),
      ],
    ));
  }

  Widget _vendedoresCard(List<Map<String, dynamic>> vendedores) {
    final maxV = vendedores.fold<double>(0.0, (m, v) {
      final t = _d(v, 'total'); return t > m ? t : m;
    });
    const avatarColors = [
      AppColors.secondary, _transferBlue, _purpleColor,
      Color(0xFF059669), _amberColor, Color(0xFFDB2777),
    ];

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _transferBlueBg, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.people_rounded, size: 15, color: _transferBlue),
          ),
          const SizedBox(width: 10),
          Text('Vendedores del Día',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.onSurface)),
        ]),
        const SizedBox(height: 4),
        Text('ventas por empleado',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (vendedores.isEmpty)
          _emptyState('Sin datos de vendedores', Icons.person_off_outlined)
        else
          ...vendedores.asMap().entries.map((e) {
            final v    = e.value;
            final tot  = _d(v, 'total');
            final nv   = v['num_ventas'] as int? ?? 0;
            final pct  = maxV > 0 ? (tot / maxV).clamp(0.0, 1.0) : 0.0;
            final col  = avatarColors[e.key % avatarColors.length];
            final nom  = v['nombre']?.toString() ?? '—';
            final ini  = nom.split(' ').where((p) => p.isNotEmpty)
                .take(2).map((p) => p[0].toUpperCase()).join();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(ini,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                          color: col))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.onSurface)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 4,
                        backgroundColor: AppColors.outlineVariant,
                        valueColor: AlwaysStoppedAnimation(col),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$nv ventas',
                        style: GoogleFonts.inter(fontSize: 10,
                            color: AppColors.onSurfaceVariant)),
                  ],
                )),
                const SizedBox(width: 10),
                Text('\$${widget.fmt.format(tot)}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.secondary)),
              ]),
            );
          }),
      ],
    ));
  }

  // ── Movimientos row ───────────────────────────────────────

  Widget _movimientosRow(ResumenDiario r, ContabilidadProvider cont) {
    return LayoutBuilder(builder: (ctx, bc) {
      final wide   = bc.maxWidth > 850;
      final medium = bc.maxWidth > 500;
      final gastos    = _gastosCard(r.gastosPorCategoria);
      final abonos    = _abonosCard(cont);
      final devol     = _devolucionesCard(r);

      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: gastos),
          const SizedBox(width: 14),
          Expanded(child: abonos),
          const SizedBox(width: 14),
          Expanded(child: devol),
        ]);
      }
      if (medium) {
        return Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: gastos),
            const SizedBox(width: 14),
            Expanded(child: abonos),
          ]),
          const SizedBox(height: 14),
          devol,
        ]);
      }
      return Column(children: [
        gastos, const SizedBox(height: 14),
        abonos, const SizedBox(height: 14),
        devol,
      ]);
    });
  }

  Widget _gastosCard(List<Map<String, dynamic>> cats) {
    final maxV = cats.fold<double>(0.0, (m, c) {
      final v = _d(c, 'total'); return v > m ? v : m;
    });

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long_rounded, size: 15, color: _amberColor),
          ),
          const SizedBox(width: 10),
          Text('Gastos del Día',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.onSurface)),
        ]),
        const SizedBox(height: 4),
        Text('por categoría',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (cats.isEmpty)
          _emptyState('Sin gastos este día', Icons.receipt_outlined)
        else ...[
          ...cats.map((c) {
            final tot = _d(c, 'total');
            final pct = maxV > 0 ? (tot / maxV).clamp(0.0, 1.0) : 0.0;
            final cant = c['cantidad'] as int? ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_categoriaLabel(c['categoria']?.toString() ?? ''),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.onSurface))),
                  Text('\$${widget.fmt.format(tot)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                          color: _amberColor)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 5,
                    backgroundColor: const Color(0xFFFEF3C7),
                    valueColor: const AlwaysStoppedAnimation(_amberColor),
                  ),
                ),
                const SizedBox(height: 3),
                Text('$cant registro${cant != 1 ? "s" : ""}',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
              ]),
            );
          }),
          Divider(color: AppColors.outlineVariant),
          Row(children: [
            Text('Total Gastos',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant)),
            const Spacer(),
            Text('\$${widget.fmt.format(cats.fold<double>(0, (s, c) => s + _d(c, "total")))}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800,
                    color: _amberColor)),
          ]),
        ],
      ],
    ));
  }

  Widget _abonosCard(ContabilidadProvider cont) {
    final totalAb = cont.abonosDia.fold<double>(0.0, (s, a) => s + _d(a, 'monto'));

    return _card(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.mintLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.savings_rounded, size: 15, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Abonos Recibidos',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.onSurface))),
          if (cont.abonosDia.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.mintLight, borderRadius: BorderRadius.circular(20)),
              child: Text('${cont.abonosDia.length}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                      color: AppColors.secondary)),
            ),
        ]),
        const SizedBox(height: 4),
        Text('créditos y separados cobrados',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        // ── Lista scrolleable ──
        if (cont.abonosDia.isEmpty)
          _emptyState('Sin abonos este día', Icons.savings_outlined)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: cont.abonosDia.length,
              itemBuilder: (_, i) {
                final a       = cont.abonosDia[i];
                final monto   = _d(a, 'monto');
                final cliente = a['cliente_nombre']?.toString() ?? '—';
                final metodo  = a['metodo_pago']?.toString() ?? 'efectivo';
                final hora    = _hora(a['created_at']?.toString() ?? '');
                final tipo    = a['tipo']?.toString()?.contains('credito') == true
                    ? 'Crédito' : 'Separado';
                final col     = _metodoPagoColor(metodo);
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.outlineVariant))),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cliente, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                                color: AppColors.onSurface)),
                        Text('$hora · $tipo',
                            style: GoogleFonts.inter(fontSize: 10,
                                color: AppColors.onSurfaceVariant)),
                      ],
                    )),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('+\$${widget.fmt.format(monto)}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.secondary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(_metodoPagoLabel(metodo),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                                color: col)),
                      ),
                    ]),
                  ]),
                );
              },
            ),
          ),
        // ── Total fijo al fondo ──
        if (cont.abonosDia.isNotEmpty) ...[
          Divider(color: AppColors.outlineVariant),
          Row(children: [
            Text('Total abonos',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant)),
            const Spacer(),
            Text('\$${widget.fmt.format(totalAb)}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800,
                    color: AppColors.secondary)),
          ]),
        ],
      ],
    ));
  }

  Widget _devolucionesCard(ResumenDiario r) {
    final devEf = r.devolucionesPorMetodo
        .where((d) => d['metodo'] == 'efectivo')
        .fold<double>(0.0, (s, d) => s + _d(d, 'total'));
    final devTarjeta = r.devolucionesPorMetodo
        .where((d) => d['metodo'] == 'tarjeta')
        .fold<double>(0.0, (s, d) => s + _d(d, 'total'));
    final impactoPct = r.totalVentas > 0
        ? (r.totalDevoluciones / r.totalVentas * 100) : 0.0;

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.undo_rounded, size: 15, color: AppColors.error),
          ),
          const SizedBox(width: 10),
          Text('Devoluciones del Día',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.onSurface)),
        ]),
        const SizedBox(height: 4),
        Text('del período seleccionado',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        _cuadreLinea('Total devuelto',    '\$${widget.fmt.format(r.totalDevoluciones)}',
            AppColors.error),
        _cuadreLinea('# Devoluciones',    '${r.numDevoluciones}', AppColors.onSurface),
        if (devEf > 0)
          _cuadreLinea('Efectivo devuelto', '\$${widget.fmt.format(devEf)}', AppColors.error),
        if (devTarjeta > 0)
          _cuadreLinea('Tarjeta devuelta',  '\$${widget.fmt.format(devTarjeta)}', AppColors.error),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(child: Text('Impacto en ventas netas',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.error))),
            Text('−${impactoPct.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.error)),
          ]),
        ),
      ],
    ));
  }

  // ── Cuadre de efectivo ────────────────────────────────────

  Widget _cuadreEfectivo(ResumenDiario r) {
    final c          = r.cuadreEfectivo;
    final ventasEf   = _d(c, 'ventas_ef');
    final abonosEf   = _d(c, 'abonos_ef');
    final gastosEf   = _d(c, 'gastos_ef');
    final devEf      = _d(c, 'dev_ef');
    final esperado   = _d(c, 'efectivo_esperado');

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.mintLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.account_balance_wallet_rounded,
                size: 15, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Text('Cuadre de Efectivo',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.onSurface)),
        ]),
        const SizedBox(height: 4),
        Text('ingresos y egresos en efectivo del día',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        _cuadreLinea('+ Ventas en efectivo',  '+\$${widget.fmt.format(ventasEf)}',  AppColors.secondary),
        _cuadreLinea('+ Abonos en efectivo',  '+\$${widget.fmt.format(abonosEf)}',  AppColors.secondary),
        _cuadreLinea('– Gastos',              '−\$${widget.fmt.format(gastosEf)}',  AppColors.error),
        if (devEf > 0)
          _cuadreLinea('– Devoluciones ef.',  '−\$${widget.fmt.format(devEf)}',     AppColors.error),
        Divider(color: AppColors.outlineVariant, height: 20),
        Row(children: [
          Text('Efectivo esperado',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          const Spacer(),
          Text('\$${widget.fmt.format(esperado)}',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppColors.secondary)),
        ]),
      ],
    ));
  }

  Widget _cuadreLinea(String label, String value, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(child: Text(label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant))),
        Text(value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                color: valColor)),
      ]),
    );
  }

  // ── Separados (sección mantenida) ─────────────────────────

  Widget _separadosSection(ContabilidadProvider cont) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _transferBlueBg, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.inventory_2_rounded, size: 16, color: _transferBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Separados ${_esHoy ? "de hoy" : _labelFecha}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                    color: AppColors.onSurface)),
          ),
          if (cont.separadosDia.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _transferBlueBg, borderRadius: BorderRadius.circular(20)),
              child: Text('${cont.separadosDia.length}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                      color: _transferBlue)),
            ),
        ]),
        const SizedBox(height: 16),
        if (cont.separadosDia.isEmpty)
          _emptyState('Sin separados este día', Icons.inventory_2_outlined)
        else
          ...cont.separadosDia.map((s) => _separadoRow(s)),
      ]),
    );
  }

  Widget _separadoRow(Map<String, dynamic> s) {
    final cliente  = s['cliente_nombre']?.toString()  ?? '—';
    final empleado = s['empleado_nombre']?.toString() ?? '—';
    final total    = _d(s, 'total');
    final abonado  = _d(s, 'abono_acumulado');
    final saldo    = _d(s, 'saldo_pendiente');
    final estado   = s['estado']?.toString() ?? 'pendiente';
    final detalles = List<Map<String, dynamic>>.from(s['detalles'] ?? []);
    final pct      = total > 0 ? (abonado / total).clamp(0.0, 1.0) : 0.0;
    final colorE   = _colorEstado(estado);
    final colorEBg = _bgEstado(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cliente, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13,
                    color: AppColors.onSurface)),
            Text(empleado, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: colorEBg, borderRadius: BorderRadius.circular(20)),
            child: Text(_estadoLabel(estado),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                    color: colorE)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 5,
            backgroundColor: AppColors.outlineVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _miniStat('Abonado', '\$${widget.fmt.format(abonado)}', AppColors.secondary),
          const SizedBox(width: 16),
          _miniStat('Saldo', '\$${widget.fmt.format(saldo)}', AppColors.error),
          const Spacer(),
          _miniStat('Total', '\$${widget.fmt.format(total)}', AppColors.onSurfaceVariant),
        ]),
        if (detalles.isNotEmpty) ...[
          Divider(height: 20, color: AppColors.outlineVariant),
          ...detalles.take(3).map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(width: 4, height: 4,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                      shape: BoxShape.circle)),
              Expanded(child: Text(d['producto_nombre']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant))),
              Text('x${d['cantidad']}  \$${widget.fmt.format(_d(d, "subtotal"))}',
                  style: GoogleFonts.inter(fontSize: 11,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7))),
            ]),
          )),
          if (detalles.length > 3)
            Text('+ ${detalles.length - 3} más',
                style: GoogleFonts.inter(fontSize: 10,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ]),
    );
  }

  Widget _topClienteRow(int index, TopCliente c) {
    final iniciales = c.nombre.split(' ')
        .where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final avatarColor = _avatarColor(c.clienteId);
    final tierColor = c.tierColorHex != null
        ? Color(int.parse(c.tierColorHex!.replaceFirst('#', '0xFF'))) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 20, child: Text('${index + 1}',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant))),
        const SizedBox(width: 6),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(iniciales,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
                  color: avatarColor))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.nombre, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.onSurface)),
          if (c.tierNombre != null && tierColor != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_rounded, size: 10, color: tierColor),
              const SizedBox(width: 3),
              Text(c.tierNombre!,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                      color: tierColor)),
            ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${widget.fmt.format(c.totalPeriodo)}',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
                  color: AppColors.secondary)),
          Text('${c.numCompras} compra${c.numCompras != 1 ? "s" : ""}',
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
        ]),
      ]),
    );
  }

  Color _avatarColor(int id) {
    const palette = [
      Color(0xFF01696F), Color(0xFF5B4CF5), Color(0xFFD97706),
      Color(0xFF059669), Color(0xFFDB2777), Color(0xFF0284C7),
    ];
    return palette[id % palette.length];
  }

  // ── Micro widgets ──────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: child,
      );

  Widget _th(String label, {int flex = 1, bool right = false}) => Expanded(
        flex: flex,
        child: Text(label,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant)),
      );

  Widget _miniStat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7))),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
              color: color)),
        ],
      );

  Widget _emptyState(String msg, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Column(children: [
          Icon(icon, size: 36,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(msg, style: GoogleFonts.inter(fontSize: 12,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5))),
        ])),
      );

  Widget _sinDatos() => _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Column(children: [
            Icon(Icons.bar_chart_rounded, size: 52,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('Sin datos para $_labelFecha',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.secondary),
              label: Text('Reintentar',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                      color: AppColors.secondary)),
            ),
          ])),
        ),
      );

  // ── Helpers ────────────────────────────────────────────────

  String _hora(String s) {
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  String _metodoPagoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transfer.';
      case 'tarjeta':       return 'Tarjeta';
      default:              return 'Efectivo';
    }
  }

  Color _metodoPagoColor(String m) {
    switch (m) {
      case 'transferencia': return _transferBlue;
      case 'tarjeta':       return AppColors.warning;
      default:              return AppColors.secondary;
    }
  }

  String _categoriaLabel(String c) {
    final map = {
      'flete': 'Flete y transporte',
      'servicios': 'Servicios',
      'nomina': 'Nómina',
      'mercancia': 'Mercancía',
      'arriendo': 'Arriendo',
      'administrativo': 'Administrativo',
      'otros': 'Otros',
    };
    return map[c] ?? c;
  }

  String _estadoLabel(String e) {
    switch (e) {
      case 'completado': return 'Completado';
      case 'cancelado':  return 'Cancelado';
      default:           return 'Pendiente';
    }
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'completado': return AppColors.secondary;
      case 'cancelado':  return AppColors.error;
      default:           return AppColors.warning;
    }
  }

  Color _bgEstado(String e) {
    switch (e) {
      case 'completado': return AppColors.mintLight;
      case 'cancelado':  return AppColors.errorContainer;
      default:           return AppColors.warningContainer;
    }
  }
}

// ── Data class simple para KPI ─────────────────────────────

class _KpiData {
  final String label, value, sub;
  final Color  subColor;
  final bool   accent;
  const _KpiData({
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    this.accent = false,
  });
}
