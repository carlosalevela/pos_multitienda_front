import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../utils/range_picker.dart';

class TabRango extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;
  final DateTime             fechaIni;
  final DateTime             fechaFin;

  const TabRango({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.fechaIni,
    required this.fechaFin,
  });

  @override
  State<TabRango> createState() => _TabRangoState();
}

class _TabRangoState extends State<TabRango> {
  late DateTime _ini;
  late DateTime _fin;

  static const _transferBlue   = Color(0xFF3B82F6);
  static const _purple         = Color(0xFF7C3AED);
  static const _purpleBg       = Color(0xFFF3E8FF);

  @override
  void initState() {
    super.initState();
    _ini = widget.fechaIni;
    _fin = widget.fechaFin;
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void didUpdateWidget(TabRango old) {
    super.didUpdateWidget(old);
    if (old.tiendaId != widget.tiendaId ||
        old.fechaIni != widget.fechaIni ||
        old.fechaFin != widget.fechaFin) {
      _ini = widget.fechaIni;
      _fin = widget.fechaFin;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargar();
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDateShort(DateTime d) =>
      '${d.day} ${_mesCorto(d.month)} ${d.year}';

  String _mesCorto(int m) {
    const ms = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return ms[m - 1];
  }

  String _fmtDateApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _cargar() => widget.cont.cargarResumenRango(
        fechaIni: _fmtDateApi(_ini),
        fechaFin: _fmtDateApi(_fin),
        tiendaId: widget.tiendaId,
      );

  Future<void> _seleccionarRango() async {
    final range = await showDateRangePicker(
      context:     context,
      initialDateRange: DateTimeRange(start: _ini, end: _fin),
      firstDate:   DateTime(DateTime.now().year - 2),
      lastDate:    DateTime.now(),
      locale:      const Locale('es', 'CO'),
      builder: (ctx, child) => rangePickerDialog(ctx, child!),
    );
    if (range != null) {
      setState(() { _ini = range.start; _fin = range.end; });
      _cargar();
    }
  }

  double _d(dynamic m, String key) =>
      double.tryParse(m[key]?.toString() ?? '0') ?? 0.0;

  String _shortNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cont = widget.cont;
    final r    = cont.resumenRango;

    return Column(children: [
      _header(cont),
      const SizedBox(height: 16),
      Expanded(
        child: cont.cargandoRango && r == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
            : RefreshIndicator(
                color: AppColors.secondary,
                onRefresh: () async => _cargar(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: r == null
                      ? _sinDatos()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _kpiRow6(r),
                            const SizedBox(height: 20),
                            _chartsRow(r),
                            const SizedBox(height: 20),
                            _rankingsRow(r),
                            const SizedBox(height: 20),
                            _movimientosRow(r),
                            const SizedBox(height: 20),
                            _comparativoTiendas(r),
                            const SizedBox(height: 20),
                            _cuadreEfectivo(r),
                          ],
                        ),
                ),
              ),
      ),
    ]);
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _header(ContabilidadProvider cont) {
    final mismo = _ini.year == _fin.year &&
                  _ini.month == _fin.month &&
                  _ini.day == _fin.day;
    final label = mismo
        ? _fmtDateShort(_ini)
        : '${_fmtDate(_ini)} – ${_fmtDate(_fin)}';
    final numDias = _fin.difference(_ini).inDays + 1;

    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: _seleccionarRango,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(children: [
              const Icon(Icons.date_range_rounded, size: 16, color: AppColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.onSurface)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.mintLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$numDias días',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded, color: AppColors.onSurfaceVariant),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      InkWell(
        onTap: cont.cargandoRango ? null : _cargar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: cont.cargandoRango
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.secondary))
              : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.onSurfaceVariant),
        ),
      ),
    ]);
  }

  // ── 6 KPI cards ────────────────────────────────────────────

  Widget _kpiRow6(Map<String, dynamic> r) {
    final comp   = r['comparativo'] as Map<String, dynamic>? ?? {};
    final ventas = _d(r, 'total_ventas');
    final gastos = _d(r, 'total_gastos');
    final util   = _d(r, 'utilidad_bruta');
    final devol  = _d(r, 'total_devoluciones');
    final ticket = _d(r, 'ticket_promedio');
    final nv     = (r['num_ventas'] ?? 0) as int;
    final abonos = r['abonos'] as Map<String, dynamic>? ?? {};
    final abTotal = _d(abonos, 'total');

    final kpis = [
      _kpi('Total Ventas',    '\$${widget.fmt.format(ventas)}',  '$nv transacciones',
          AppColors.secondary, comp['pct_ventas'], accent: true),
      _kpi('Ticket Promedio', '\$${widget.fmt.format(ticket)}',  'Por venta',
          AppColors.onSurfaceVariant, comp['pct_ticket']),
      _kpi('Utilidad Bruta',  '\$${widget.fmt.format(util.abs())}',
          'Margen ${ventas > 0 ? (util / ventas * 100).abs().toStringAsFixed(1) : 0}%',
          util >= 0 ? AppColors.secondary : AppColors.error, comp['pct_utilidad']),
      _kpi('Gastos',          '\$${widget.fmt.format(gastos)}',  'Del período',
          AppColors.warning, comp['pct_gastos']),
      _kpi('Devoluciones',    '\$${widget.fmt.format(devol)}',
          '${(r['num_devoluciones'] ?? 0)} devoluciones',
          AppColors.error, comp['pct_devoluciones']),
      _kpi('Abonos Recib.',   '\$${widget.fmt.format(abTotal)}', 'Créditos y separados',
          AppColors.secondary, null),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth > 900) {
        return Row(children: [
          for (int i = 0; i < kpis.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: kpis[i]),
          ],
        ]);
      }
      if (c.maxWidth > 500) {
        return Column(children: [
          Row(children: [
            Expanded(child: kpis[0]), const SizedBox(width: 10),
            Expanded(child: kpis[1]), const SizedBox(width: 10),
            Expanded(child: kpis[2]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: kpis[3]), const SizedBox(width: 10),
            Expanded(child: kpis[4]), const SizedBox(width: 10),
            Expanded(child: kpis[5]),
          ]),
        ]);
      }
      return Column(children: [
        Row(children: [
          Expanded(child: kpis[0]), const SizedBox(width: 10),
          Expanded(child: kpis[1]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: kpis[2]), const SizedBox(width: 10),
          Expanded(child: kpis[3]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: kpis[4]), const SizedBox(width: 10),
          Expanded(child: kpis[5]),
        ]),
      ]);
    });
  }

  Widget _kpi(String label, String value, String sub, Color subColor,
      dynamic pct, {bool accent = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (accent)
            Container(width: 3, color: AppColors.mint),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(accent ? 13 : 16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(label,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.3)),
                  ),
                  if (pct != null) _comparativoBadge(pct),
                ]),
                const SizedBox(height: 6),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(sub,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 10, color: subColor)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _comparativoBadge(dynamic raw) {
    final pct    = double.tryParse(raw?.toString() ?? '0') ?? 0.0;
    if (pct == 0) return const SizedBox.shrink();
    final sube   = pct > 0;
    final color  = sube ? AppColors.secondary : AppColors.error;
    final bgColor = sube
        ? AppColors.secondary.withValues(alpha: 0.1)
        : AppColors.error.withValues(alpha: 0.1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          sube ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 9, color: color,
        ),
        const SizedBox(width: 2),
        Text('${pct.abs().toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color)),
      ]),
    );
  }

  // ── Charts ─────────────────────────────────────────────────

  Widget _chartsRow(Map<String, dynamic> r) {
    final porDia    = List<Map<String, dynamic>>.from(r['ventas_por_dia']    ?? []);
    final porMetodo = List<Map<String, dynamic>>.from(r['ventas_por_metodo'] ?? []);

    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth > 700;
      final bar  = _barChartDia(porDia);
      final pie  = _pieMetodo(porMetodo);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: bar),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: pie),
        ]);
      }
      return Column(children: [bar, const SizedBox(height: 16), pie]);
    });
  }

  Widget _barChartDia(List<Map<String, dynamic>> dias) {
    if (dias.isEmpty) {
      return _card(child: _emptyState('Sin ventas en el período', Icons.bar_chart_rounded));
    }
    final values = dias.map((d) => _d(d, 'total')).toList();
    final maxVal  = values.fold(0.0, (a, b) => a > b ? a : b);

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ventas por Día',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface)),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal > 0 ? maxVal * 1.3 : 100,
            barGroups: dias.asMap().entries.map((e) {
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: values[e.key],
                  gradient: LinearGradient(
                    colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  width: dias.length <= 7 ? 24 : (dias.length <= 14 ? 14 : 8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal > 0 ? maxVal * 1.3 : 100,
                    color: AppColors.surfaceContainerLow,
                  ),
                ),
              ]);
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: dias.length <= 7 ? 1 : (dias.length <= 14 ? 2 : 7).toDouble(),
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx >= dias.length) return const SizedBox();
                    final fecha = dias[idx]['dia']?.toString() ?? '';
                    String label;
                    try {
                      final d = DateTime.parse(fecha);
                      label = dias.length <= 7
                          ? _diaSemanaCorto(d.weekday)
                          : '${d.day}/${d.month}';
                    } catch (_) {
                      label = '';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 9, color: AppColors.onSurfaceVariant)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (val, _) {
                    if (val == 0) return const SizedBox();
                    return Text('\$${_shortNum(val)}',
                        style: GoogleFonts.inter(
                            fontSize: 9, color: AppColors.onSurfaceVariant));
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.outlineVariant, strokeWidth: 1, dashArray: [4, 4]),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.onSurface,
                getTooltipItem: (group, _, rod, __) {
                  final fecha = dias[group.x]['dia']?.toString() ?? '';
                  String dl = '';
                  try {
                    final d = DateTime.parse(fecha);
                    dl = '${d.day} ${_mesCorto(d.month)}';
                  } catch (_) {}
                  return BarTooltipItem('$dl\n',
                      GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      children: [
                        TextSpan(
                          text: '\$${widget.fmt.format(rod.toY)}',
                          style: GoogleFonts.inter(
                              color: AppColors.mint,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ]);
                },
              ),
            ),
          )),
        ),
      ]),
    );
  }

  Widget _pieMetodo(List<Map<String, dynamic>> metodos) {
    if (metodos.isEmpty) {
      return _card(child: _emptyState('Sin datos de métodos de pago', Icons.pie_chart_outline_rounded));
    }
    final total = metodos.fold(0.0, (s, m) => s + _d(m, 'total'));

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Distribución de Pagos',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface)),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: PieChart(PieChartData(
            sections: metodos.asMap().entries.map((e) {
              final m   = e.value;
              final val = _d(m, 'total');
              final pct = total > 0 ? val / total * 100 : 0.0;
              final col = _metodoPagoColor(m['metodo']?.toString() ?? '');
              return PieChartSectionData(
                value:      val,
                color:      col,
                radius:     50,
                title:      '${pct.toStringAsFixed(0)}%',
                titleStyle: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              );
            }).toList(),
            sectionsSpace: 3,
            centerSpaceRadius: 36,
          )),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: metodos.map((m) {
            final color = _metodoPagoColor(m['metodo']?.toString() ?? '');
            final label = _metodoPagoLabel(m['metodo']?.toString() ?? '');
            final cant  = m['cantidad'] ?? 0;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 6),
              Text('$label ($cant)',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }

  // ── Rankings (Top Productos + Top Clientes) ─────────────────

  Widget _rankingsRow(Map<String, dynamic> r) {
    final prods    = List<Map<String, dynamic>>.from(r['top_productos'] ?? []);
    final clientes = List<Map<String, dynamic>>.from(r['top_clientes']  ?? []);
    if (prods.isEmpty && clientes.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth > 700;
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _topProductosCard(prods)),
          const SizedBox(width: 12),
          Expanded(child: _topClientesCard(clientes)),
        ]);
      }
      return Column(children: [
        _topProductosCard(prods),
        const SizedBox(height: 12),
        _topClientesCard(clientes),
      ]);
    });
  }

  Widget _topProductosCard(List<Map<String, dynamic>> lista) {
    final maxV = lista.map((p) => _d(p, 'ingresos')).fold(0.0, (a, b) => a > b ? a : b);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.inventory_2_rounded, AppColors.mintLight, AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(child: Text('Top 5 Productos', style: _sectionTitle())),
          if (lista.isNotEmpty) _badgeCont(lista.length, AppColors.mintLight, AppColors.secondary),
        ]),
        const SizedBox(height: 14),
        if (lista.isEmpty)
          _emptyState('Sin productos vendidos', Icons.inventory_2_outlined)
        else
          ...lista.take(5).toList().asMap().entries.map((e) {
            final p        = e.value;
            final ingresos = _d(p, 'ingresos');
            final pct      = maxV > 0 ? ingresos / maxV : 0.0;
            final iniciales = (p['nombre']?.toString() ?? '?')
                .split(' ').where((x) => x.isNotEmpty).take(2)
                .map((x) => x[0].toUpperCase()).join();
            final ac = _avatarColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                SizedBox(
                  width: 18,
                  child: Text('${e.key + 1}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                          color: AppColors.onSurfaceVariant)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text(iniciales,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: ac))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(p['nombre']?.toString() ?? '—',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                                color: AppColors.onSurface)),
                      ),
                      Text('\$${widget.fmt.format(ingresos)}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
                              color: AppColors.secondary)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 4,
                        backgroundColor: AppColors.outlineVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${(p['cantidad'] ?? 0).toString().replaceAll('.0', '')} unidades',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
                  ]),
                ),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _topClientesCard(List<Map<String, dynamic>> lista) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.star_rounded, _purpleBg, _purple),
          const SizedBox(width: 10),
          Expanded(child: Text('Top 5 Clientes', style: _sectionTitle())),
          if (lista.isNotEmpty) _badgeCont(lista.length, _purpleBg, _purple),
        ]),
        const SizedBox(height: 14),
        if (lista.isEmpty)
          _emptyState('Sin clientes registrados', Icons.person_search_rounded)
        else
          ...lista.take(5).toList().asMap().entries.map((e) {
            final c       = e.value;
            final nombre  = c['nombre']?.toString() ?? '—';
            final total   = _d(c, 'total');
            final compras = (c['num_compras'] ?? 0) as int;
            final ini     = nombre.split(' ').where((p) => p.isNotEmpty)
                .take(2).map((p) => p[0].toUpperCase()).join();
            final ac = _avatarColor(c['cliente_id'] as int? ?? e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 18,
                  child: Text('${e.key + 1}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                          color: AppColors.onSurfaceVariant)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(ini,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: ac))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nombre,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('\$${widget.fmt.format(total)}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
                          color: AppColors.secondary)),
                  Text('$compras compra${compras != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
                ]),
              ]),
            );
          }),
      ]),
    );
  }

  // ── Movimientos (Gastos + Abonos + Devoluciones) ────────────

  Widget _movimientosRow(Map<String, dynamic> r) {
    final abonos = r['abonos']       as Map<String, dynamic>? ?? {};
    final devol  = r['devoluciones'] as Map<String, dynamic>? ?? {};
    final gCats  = List<Map<String, dynamic>>.from(r['gastos_por_categoria'] ?? []);
    final gTotal = _d(r, 'total_gastos');

    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth > 700;
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _gastosCard(gCats, gTotal)),
          const SizedBox(width: 12),
          Expanded(child: _abonosCard(abonos)),
          const SizedBox(width: 12),
          Expanded(child: _devolCard(devol)),
        ]);
      }
      return Column(children: [
        _gastosCard(gCats, gTotal),
        const SizedBox(height: 12),
        _abonosCard(abonos),
        const SizedBox(height: 12),
        _devolCard(devol),
      ]);
    });
  }

  Widget _gastosCard(List<Map<String, dynamic>> cats, double total) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.receipt_long_rounded, AppColors.warningContainer, AppColors.warning),
          const SizedBox(width: 10),
          Text('Gastos del período', style: _sectionTitle()),
        ]),
        const SizedBox(height: 14),
        if (cats.isEmpty)
          _emptyState('Sin gastos en el período', Icons.receipt_long_outlined)
        else
          ...cats.take(5).map((cat) {
            final catTotal = _d(cat, 'total');
            final pct      = total > 0 ? catTotal / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(cat['categoria']?.toString() ?? 'Sin categoría',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.onSurface)),
                  ),
                  Text('\$${widget.fmt.format(catTotal)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
                          color: AppColors.warning)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 4,
                    backgroundColor: AppColors.outlineVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _abonosCard(Map<String, dynamic> a) {
    final rows = [
      ('Abonos efectivo',      _d(a, 'efectivo'),      AppColors.secondary),
      ('Abonos tarjeta',       _d(a, 'tarjeta'),       AppColors.warning),
      ('Abonos transferencia', _d(a, 'transferencia'), const Color(0xFF3B82F6)),
      ('Separados cobrados',   _d(a, 'separados'),     AppColors.secondary),
      ('Créditos cobrados',    _d(a, 'creditos'),      AppColors.secondary),
    ];
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.savings_rounded, AppColors.mintLight, AppColors.secondary),
          const SizedBox(width: 10),
          Text('Abonos recibidos', style: _sectionTitle()),
        ]),
        const SizedBox(height: 14),
        ...rows.where((r) => r.$2 > 0).map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Text(r.$1,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant))),
            Text('\$${widget.fmt.format(r.$2)}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: r.$3)),
          ]),
        )),
        if (rows.every((r) => r.$2 == 0))
          _emptyState('Sin abonos en el período', Icons.savings_outlined),
      ]),
    );
  }

  Widget _devolCard(Map<String, dynamic> d) {
    final totalDev = _d(d, 'efectivo') + _d(d, 'tarjeta') + _d(d, 'transferencia');
    final totalCam = _d(d, 'cambios_devolver');
    final nDir  = (d['num_devoluciones_directas'] ?? 0) as int;
    final nCam  = (d['num_cambios'] ?? 0) as int;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.undo_rounded, AppColors.errorContainer, AppColors.error),
          const SizedBox(width: 10),
          Text('Devoluciones', style: _sectionTitle()),
        ]),
        const SizedBox(height: 14),
        if (totalDev == 0 && totalCam == 0)
          _emptyState('Sin devoluciones en el período', Icons.undo_outlined)
        else ...[
          Row(children: [
            Expanded(child: Text('Total devuelto',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant))),
            Text('\$${widget.fmt.format(totalDev)}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
                    color: AppColors.error)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('# Devoluciones directas',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant))),
            Text('$nDir',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
                    color: AppColors.onSurface)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('# Cambios de producto',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant))),
            Text('$nCam',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
                    color: AppColors.onSurface)),
          ]),
          if (totalCam > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('Devoluc. en cambios',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant))),
              Text('\$${widget.fmt.format(totalCam)}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
                      color: AppColors.warning)),
            ]),
          ],
        ],
      ]),
    );
  }

  // ── Comparativo por tienda ──────────────────────────────────

  Widget _comparativoTiendas(Map<String, dynamic> r) {
    final tiendas = List<Map<String, dynamic>>.from(r['comparativo_tiendas'] ?? []);
    if (tiendas.length <= 1) return const SizedBox.shrink();

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.store_rounded, AppColors.mintLight, AppColors.secondary),
          const SizedBox(width: 10),
          Text('Comparativo por Tienda', style: _sectionTitle()),
        ]),
        const SizedBox(height: 16),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(flex: 4, child: _th('TIENDA')),
            Expanded(flex: 3, child: _th('VENTAS', right: true)),
            Expanded(flex: 2, child: _th('TICKET', right: true)),
            Expanded(flex: 2, child: _th('UTILIDAD', right: true)),
            Expanded(flex: 2, child: _th('MARGEN', right: true)),
          ]),
        ),
        ...tiendas.map((t) {
          final util   = _d(t, 'utilidad');
          final margen = _d(t, 'margen');
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: Row(children: [
              Expanded(
                flex: 4,
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.secondary, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(t['nombre']?.toString() ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.onSurface)),
                  ),
                ]),
              ),
              Expanded(
                flex: 3,
                child: Text('\$${widget.fmt.format(_d(t, 'ventas'))}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.onSurface)),
              ),
              Expanded(
                flex: 2,
                child: Text('\$${widget.fmt.format(_d(t, 'ticket'))}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ),
              Expanded(
                flex: 2,
                child: Text('\$${widget.fmt.format(util.abs())}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                        color: util >= 0 ? AppColors.secondary : AppColors.error)),
              ),
              Expanded(
                flex: 2,
                child: Text('${margen.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 11,
                        color: margen >= 0 ? AppColors.secondary : AppColors.error)),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Cuadre de efectivo + Discrepancias ──────────────────────

  Widget _cuadreEfectivo(Map<String, dynamic> r) {
    final cuadre  = r['cuadre_efectivo'] as Map<String, dynamic>? ?? {};
    final cierres = List<Map<String, dynamic>>.from(r['cierres_periodo'] ?? []);
    if (cuadre.isEmpty && cierres.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth > 700;
      final cuadreW = _cuadreCard(cuadre);
      final discW   = _discrepanciasCard(cierres);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: cuadreW),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: discW),
        ]);
      }
      return Column(children: [
        cuadreW,
        const SizedBox(height: 12),
        discW,
      ]);
    });
  }

  Widget _cuadreCard(Map<String, dynamic> c) {
    final vef  = _d(c, 'ventas_efectivo');
    final aef  = _d(c, 'abonos_efectivo');
    final gef  = _d(c, 'gastos_efectivo');
    final def_ = _d(c, 'devoluciones_efectivo');
    final esp  = _d(c, 'efectivo_esperado');

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.account_balance_wallet_rounded, AppColors.mintLight, AppColors.secondary),
          const SizedBox(width: 10),
          Text('Cuadre de Efectivo', style: _sectionTitle()),
        ]),
        const SizedBox(height: 14),
        _cuadreRow('+ Ventas en efectivo',  vef,  AppColors.secondary, '+'),
        _cuadreRow('+ Abonos en efectivo',  aef,  AppColors.secondary, '+'),
        if (gef > 0)   _cuadreRow('– Gastos en efectivo', gef, AppColors.error, '−'),
        if (def_ > 0)  _cuadreRow('– Devoluciones ef.',   def_, AppColors.error, '−'),
        const Divider(height: 20),
        Row(children: [
          Expanded(
            child: Text('Efectivo esperado',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
                    color: AppColors.onSurface)),
          ),
          Text('\$${widget.fmt.format(esp)}',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold,
                  color: AppColors.secondary)),
        ]),
      ]),
    );
  }

  Widget _cuadreRow(String label, double val, Color color, String prefix) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant))),
          Text('$prefix\$${widget.fmt.format(val)}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ]),
      );

  Widget _discrepanciasCard(List<Map<String, dynamic>> cierres) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.receipt_rounded, AppColors.warningContainer, AppColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text('Cierres del Período', style: _sectionTitle())),
          if (cierres.isNotEmpty)
            _badgeCont(cierres.length, AppColors.warningContainer, AppColors.warning),
        ]),
        const SizedBox(height: 14),
        if (cierres.isEmpty)
          _emptyState('Sin cierres en el período', Icons.receipt_outlined)
        else ...[
          ...cierres.map((c) {
            final dif    = _d(c, 'diferencia');
            final color  = dif < 0 ? AppColors.error
                         : dif > 0 ? AppColors.secondary
                         : AppColors.onSurfaceVariant;
            final fecha  = c['fecha_cierre']?.toString() ?? '';
            String dLabel = '';
            try {
              final d = DateTime.parse(fecha);
              const ds = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
              dLabel = '${ds[d.weekday - 1]} ${d.day} ${_mesCorto(d.month)}';
            } catch (_) {
              dLabel = fecha;
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Center(
                    child: Text(dLabel.substring(0, 3),
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold,
                            color: AppColors.secondary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(dLabel,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.onSurface)),
                    Text('${c['tienda']} · ${c['empleado']}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
                  ]),
                ),
                Text(dif == 0 ? '\$0'
                    : '${dif > 0 ? '+' : ''}\$${widget.fmt.format(dif.abs())}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
                        color: color)),
              ]),
            );
          }),
          // Discrepancia neta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(
                child: Text('Discrepancia neta',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
                        color: AppColors.onSurface)),
              ),
              Builder(builder: (_) {
                final neta = cierres.fold(0.0, (s, c) => s + _d(c, 'diferencia'));
                final col  = neta < 0 ? AppColors.error
                           : neta > 0 ? AppColors.secondary
                           : AppColors.onSurfaceVariant;
                return Text(
                  neta == 0 ? '\$0' : '${neta > 0 ? '+' : ''}\$${widget.fmt.format(neta.abs())}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: col),
                );
              }),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Micro widgets ───────────────────────────────────────────

  Widget _th(String label, {bool right = false}) => Text(label,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant, letterSpacing: 0.3));

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

  TextStyle _sectionTitle() => GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface);

  Widget _iconBox(IconData icon, Color bg, Color fg) => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: fg),
      );

  Widget _badgeCont(int count, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text('$count',
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
      );

  Widget _emptyState(String msg, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(children: [
            Icon(icon, size: 32,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(msg,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5))),
          ]),
        ),
      );

  Widget _sinDatos() => _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(children: [
              Icon(Icons.bar_chart_rounded,
                  size: 52,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              Text('Sin datos para el período seleccionado',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: AppColors.secondary),
                label: Text('Reintentar',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary)),
              ),
            ]),
          ),
        ),
      );

  // ── Helpers ─────────────────────────────────────────────────

  String _diaSemanaCorto(int weekday) {
    const ds = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    return ds[weekday - 1];
  }

  String _metodoPagoLabel(String m) {
    switch (m) {
      case 'efectivo':      return 'Efectivo';
      case 'transferencia': return 'Transfer.';
      case 'tarjeta':       return 'Tarjeta';
      case 'mixto':         return 'Mixto';
      case 'bono':          return 'Bono';
      default:              return m.isNotEmpty ? m : 'Efectivo';
    }
  }

  Color _metodoPagoColor(String m) {
    switch (m) {
      case 'efectivo':      return AppColors.secondary;
      case 'transferencia': return _transferBlue;
      case 'tarjeta':       return AppColors.warning;
      case 'mixto':         return _purple;
      case 'bono':          return const Color(0xFFF59E0B);
      default:              return AppColors.secondary;
    }
  }

  Color _avatarColor(int id) {
    const palette = [
      Color(0xFF01696F), Color(0xFF5B4CF5), Color(0xFFD97706),
      Color(0xFF059669), Color(0xFFDB2777), Color(0xFF0284C7),
    ];
    return palette[id % palette.length];
  }
}
