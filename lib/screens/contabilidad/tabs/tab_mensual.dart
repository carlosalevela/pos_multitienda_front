import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/contabilidad_models.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../theme/app_colors.dart';

class TabMensual extends StatefulWidget {
  final ContabilidadProvider             cont;
  final NumberFormat                     fmt;
  final int?                             tiendaId;
  final int                              anio;
  final int                              mes;
  final List<String>                     meses;
  final void Function(int anio, int mes) onCambiarMes;

  const TabMensual({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.anio,
    required this.mes,
    required this.meses,
    required this.onCambiarMes,
  });

  @override
  State<TabMensual> createState() => _TabMensualState();
}

class _TabMensualState extends State<TabMensual> {
  int _touchedPie = -1;

  ContabilidadProvider get cont  => widget.cont;
  NumberFormat         get fmt   => widget.fmt;
  int                  get anio  => widget.anio;
  int                  get mes   => widget.mes;
  List<String>         get meses => widget.meses;

  // ── Helpers ────────────────────────────────────────────────

  double _d(Map m, String key) =>
      double.tryParse(m[key]?.toString() ?? '0') ?? 0.0;

  String _compact(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  double _pct(double nuevo, double viejo) {
    if (viejo == 0) return 0;
    return ((nuevo - viejo) / viejo) * 100;
  }

  String _mesCorto(int m) {
    const n = ['','ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return n[m.clamp(1, 12)];
  }

  // "2026-11-09" → "Sáb 9 Nov"
  String _diaNombre(String diaStr) {
    if (diaStr.length < 10) return 'Día $diaStr';
    try {
      final d = DateTime.parse(diaStr);
      const dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
      const mss   = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${dias[d.weekday - 1]} ${d.day} ${mss[d.month]}';
    } catch (_) {
      return diaStr;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _avatarColor(String name) {
    const palette = [
      AppColors.secondary,
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (cont.cargando && cont.resumenMensual == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = cont.resumenMensual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _selectorMes(),
        const SizedBox(height: 16),
        if (data == null)
          _sinDatos()
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: _contenido(data),
            ),
          ),
      ],
    );
  }

  Widget _contenido(ResumenMensual r) {
    final ant       = r.mesAnterior;
    final antVentas = _d(ant, 'total_ventas');
    final antGastos = _d(ant, 'total_gastos');
    final antUtil   = _d(ant, 'utilidad_bruta');
    final antDev    = _d(ant, 'total_devoluciones');
    final numDias   = r.ventasPorDia.length;
    final ticket    = numDias > 0 ? r.totalVentas / numDias : 0.0;
    final antTicket = antVentas > 0 && numDias > 0 ? antVentas / numDias : 0.0;
    final vsLabel   = 'vs ${_mesCorto(mes == 1 ? 12 : mes - 1)}';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _kpisRow(r, antVentas, antGastos, antUtil, antDev,
               ticket, antTicket, numDias, vsLabel),
      const SizedBox(height: 16),
      if (r.ventasPorDia.isNotEmpty) ...[
        _lineaChart(r),
        const SizedBox(height: 16),
      ],
      _fila2(_semanalCard(r), _mejoresDiasCard(r)),
      const SizedBox(height: 12),
      _fila2(_topProductosCard(r), _vendedoresCard(r)),
      const SizedBox(height: 12),
      _fila2(_gastosCategoriaCard(r), _metodosPagoCard(r)),
      const SizedBox(height: 12),
      _balanceCard(r),
    ]);
  }

  // ── Fila 2 columnas con altura igualada ────────────────────

  Widget _fila2(Widget left, Widget right) {
    return LayoutBuilder(builder: (ctx, bc) {
      if (bc.maxWidth > 480) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ]),
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, const SizedBox(height: 12), right]);
    });
  }

  // ── Selector de mes ────────────────────────────────────────

  Widget _selectorMes() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: AppColors.onSurfaceVariant),
          onPressed: () => mes == 1
              ? widget.onCambiarMes(anio - 1, 12)
              : widget.onCambiarMes(anio, mes - 1),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.calendar_month_rounded,
                size: 14, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Text('${meses[mes - 1]} $anio',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                  fontSize: 15, color: AppColors.onSurface)),
        ]))),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
          onPressed: () => mes == 12
              ? widget.onCambiarMes(anio + 1, 1)
              : widget.onCambiarMes(anio, mes + 1),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  // ── KPI cards (5) ──────────────────────────────────────────

  Widget _kpisRow(ResumenMensual r,
      double antVentas, double antGastos, double antUtil, double antDev,
      double ticket, double antTicket, int numDias, String vsLabel) {

    final totalV = r.totalVentas;
    final kpis = [
      _KpiData(
        label: 'VENTAS TOTALES',
        value: fmt.format(totalV),
        sub: '$numDias días con ventas',
        color: AppColors.secondary,
        delta: _pct(totalV, antVentas),
        vsLabel: vsLabel,
      ),
      _KpiData(
        label: 'TICKET PROMEDIO',
        value: fmt.format(ticket),
        sub: 'por día con ventas',
        color: const Color(0xFF3B82F6),
        delta: _pct(ticket, antTicket),
        vsLabel: vsLabel,
      ),
      _KpiData(
        label: 'UTILIDAD BRUTA',
        value: fmt.format(r.utilidadBruta),
        sub: totalV > 0
            ? 'Margen ${(r.utilidadBruta / totalV * 100).toStringAsFixed(1)}%'
            : '—',
        color: r.utilidadBruta >= 0 ? AppColors.secondary : const Color(0xFFDC2626),
        delta: _pct(r.utilidadBruta, antUtil),
        vsLabel: vsLabel,
      ),
      _KpiData(
        label: 'GASTOS',
        value: fmt.format(r.totalGastos),
        sub: totalV > 0
            ? '${(r.totalGastos / totalV * 100).toStringAsFixed(1)}% de ventas'
            : '—',
        color: const Color(0xFFC2410C),
        delta: _pct(r.totalGastos, antGastos),
        vsLabel: vsLabel,
        invertDelta: true,
      ),
      _KpiData(
        label: 'DEVOLUCIONES',
        value: fmt.format(r.totalDevoluciones),
        sub: '${r.devolucionesPorDia.length} días con dev.',
        color: const Color(0xFFDC2626),
        delta: _pct(r.totalDevoluciones, antDev),
        vsLabel: vsLabel,
        invertDelta: true,
      ),
    ];

    return LayoutBuilder(builder: (ctx, bc) {
      final w         = bc.maxWidth;
      final perRow    = w > 700 ? 5 : w > 460 ? 3 : 2;
      final gap       = 8.0;
      final cardWidth = (w - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap, runSpacing: gap,
        children: kpis.map((k) =>
          SizedBox(width: cardWidth, child: _kpiCard(k))).toList(),
      );
    });
  }

  Widget _kpiCard(_KpiData k) {
    final bool isUp    = k.invertDelta ? k.delta < 0 : k.delta >= 0;
    final bool hasDelta = k.delta != 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 3, color: k.color),
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 10, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                Text(k.label,
                    style: GoogleFonts.inter(
                        fontSize: 8.5, fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text(k.value,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15, color: AppColors.onSurface)),
                const SizedBox(height: 1),
                Text(k.sub,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 9, color: AppColors.onSurfaceVariant)),
                if (hasDelta) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(
                      isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 9,
                      color: isUp ? const Color(0xFF059669) : const Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${k.delta.abs().toStringAsFixed(1)}% ${k.vsLabel}',
                      style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w600,
                        color: isUp ? const Color(0xFF059669) : const Color(0xFFE11D48),
                      ),
                    ),
                  ]),
                ],
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Línea chart ventas/gastos/devoluciones ─────────────────

  Widget _lineaChart(ResumenMensual r) {
    final Map<String, Map<String, double>> diasMap = {};
    for (final v in r.ventasPorDia) {
      final d = v['dia']?.toString() ?? '';
      (diasMap[d] ??= {})['v'] = _d(v, 'total');
    }
    for (final g in r.gastosPorDia) {
      final d = g['dia']?.toString() ?? '';
      (diasMap[d] ??= {})['g'] = _d(g, 'total');
    }
    for (final d in r.devolucionesPorDia) {
      final k = d['dia']?.toString() ?? '';
      (diasMap[k] ??= {})['d'] = _d(d, 'total');
    }

    final sorted = diasMap.keys.toList()..sort();
    if (sorted.isEmpty) return const SizedBox.shrink();

    FlSpot spot(int i, String key) =>
        FlSpot(i.toDouble(), diasMap[sorted[i]]?[key] ?? 0);

    final vSpots = List.generate(sorted.length, (i) => spot(i, 'v'));
    final gSpots = List.generate(sorted.length, (i) => spot(i, 'g'));
    final dSpots = List.generate(sorted.length, (i) => spot(i, 'd'));

    final allY = [...vSpots, ...gSpots, ...dSpots].map((s) => s.y);
    final maxY =
        (allY.fold(0.0, (a, b) => a > b ? a : b) * 1.25).clamp(1.0, double.infinity);

    final totalV = r.totalVentas;
    final totalG = r.totalGastos;
    final totalD = r.totalDevoluciones;

    Widget pill(Color c, String label, double total) => Expanded(child: Row(children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Expanded(child: Text(label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant))),
      Text(_compact(total),
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
    ]));

    return _card(
      icon: Icons.show_chart_rounded,
      iconBg: AppColors.mintLight,
      iconColor: AppColors.secondary,
      title: 'Tendencia del mes',
      subtitle: 'Ventas · Gastos · Devoluciones por día',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 190,
          child: LineChart(LineChartData(
            minX: 0, maxX: (sorted.length - 1).toDouble(),
            minY: 0, maxY: maxY,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 44,
                getTitlesWidget: (v, _) => Text(_compact(v),
                    style: GoogleFonts.inter(
                        fontSize: 8, color: Colors.grey.shade400)),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                interval: (sorted.length / 6).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                  final s = sorted[i];
                  return Text(s.length >= 10 ? s.substring(8, 10) : s,
                      style: GoogleFonts.inter(
                          fontSize: 8, color: Colors.grey.shade400));
                },
              )),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1E293B),
                getTooltipItems: (spots) {
                  final i      = spots.first.x.toInt();
                  final dayStr = i < sorted.length ? sorted[i] : '';
                  final dayNum = dayStr.length >= 10 ? dayStr.substring(8, 10) : dayStr;
                  return spots.asMap().entries.map((e) {
                    const labels = ['Ventas', 'Gastos', 'Dev.'];
                    const colors = [
                      Color(0xFF34D399), Color(0xFFFBBF24), Color(0xFFF87171),
                    ];
                    return LineTooltipItem(
                      e.key == 0 ? 'Día $dayNum\n' : '',
                      GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                      children: [
                        TextSpan(
                          text: '${labels[e.key]}: ${_compact(e.value.y)}',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: colors[e.key],
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: vSpots, isCurved: true,
                color: AppColors.secondary, barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.secondary.withValues(alpha: 0.08)),
              ),
              LineChartBarData(
                spots: gSpots, isCurved: true,
                color: const Color(0xFFF59E0B), barWidth: 2,
                dashArray: [5, 4],
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: dSpots, isCurved: true,
                color: const Color(0xFFEF4444), barWidth: 1.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                    radius: 3, color: const Color(0xFFEF4444), strokeWidth: 0,
                  ),
                ),
              ),
            ],
          )),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, thickness: 0.5),
        const SizedBox(height: 10),
        Row(children: [
          pill(AppColors.secondary, 'Ventas', totalV),
          const SizedBox(width: 10),
          pill(const Color(0xFFF59E0B), 'Gastos', totalG),
          const SizedBox(width: 10),
          pill(const Color(0xFFEF4444), 'Devoluciones', totalD),
        ]),
      ]),
    );
  }

  // ── Ventas por semana ──────────────────────────────────────

  Widget _semanalCard(ResumenMensual r) {
    final lastDay  = DateTime(anio, mes + 1, 0).day;
    final semanas  = <double>[0, 0, 0, 0];
    for (final v in r.ventasPorDia) {
      final s = v['dia']?.toString() ?? '';
      final n = s.length >= 10 ? int.tryParse(s.substring(8, 10)) ?? 1 : 1;
      semanas[((n - 1) ~/ 7).clamp(0, 3)] += _d(v, 'total');
    }
    final maxSem  = semanas.fold(0.0, (a, b) => a > b ? a : b);
    final semLabels = [
      'Sem 1\n(1-7)',
      'Sem 2\n(8-14)',
      'Sem 3\n(15-21)',
      'Sem 4\n(22-$lastDay)',
    ];

    return _card(
      icon: Icons.bar_chart_rounded,
      iconBg: AppColors.mintLight,
      iconColor: AppColors.secondary,
      title: 'Ventas por Semana',
      subtitle: 'distribución semanal del mes',
      child: SizedBox(
        height: 170,
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxSem > 0 ? maxSem * 1.3 : 100,
          barGroups: semanas.asMap().entries.map((e) =>
            BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: e.value,
                color: AppColors.secondary,
                width: 32,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxSem > 0 ? maxSem * 1.3 : 100,
                  color: Colors.grey.shade50,
                ),
              ),
            ]),
          ).toList(),
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= 4) return const SizedBox.shrink();
                return Text(semLabels[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 8, color: Colors.grey.shade400,
                        height: 1.3));
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 44,
              getTitlesWidget: (v, _) => Text(_compact(v),
                  style: GoogleFonts.inter(
                      fontSize: 8, color: Colors.grey.shade400)),
            )),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.white,
              tooltipBorder: BorderSide(color: Colors.grey.shade200),
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${semLabels[group.x].replaceAll('\n', ' ')}\n${fmt.format(rod.toY)}',
                GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                    color: AppColors.secondary),
              ),
            ),
          ),
        )),
      ),
    );
  }

  // ── Mejores días ───────────────────────────────────────────

  Widget _mejoresDiasCard(ResumenMensual r) {
    final sorted = List<Map<String, dynamic>>.from(r.ventasPorDia)
      ..sort((a, b) => _d(b, 'total').compareTo(_d(a, 'total')));
    final top5  = sorted.take(5).toList();
    final maxV  = top5.isNotEmpty ? _d(top5.first, 'total') : 1.0;
    const medals = ['🥇', '🥈', '🥉', '4', '5'];

    return _card(
      icon: Icons.emoji_events_rounded,
      iconBg: const Color(0xFFFFF7ED),
      iconColor: const Color(0xFFD97706),
      title: 'Mejores Días',
      subtitle: 'top ${top5.length} del mes',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: top5.asMap().entries.map((e) {
          final d       = e.value;
          final diaStr  = d['dia']?.toString() ?? '';
          final nombre  = _diaNombre(diaStr);
          final total   = _d(d, 'total');
          final cant    = d['cantidad'] ?? 0;
          final pct     = maxV > 0 ? total / maxV : 0.0;
          final isMedal = e.key < 3;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                isMedal
                    ? Text(medals[e.key],
                        style: const TextStyle(fontSize: 14))
                    : Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text('${e.key + 1}',
                            style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: AppColors.onSurfaceVariant))),
                      ),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                  Text('$cant transacciones',
                      style: GoogleFonts.inter(
                          fontSize: 9.5, color: AppColors.onSurfaceVariant)),
                ])),
                Text(_compact(total),
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.secondary)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFD97706)),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Top productos ──────────────────────────────────────────

  Widget _topProductosCard(ResumenMensual r) {
    final prods  = r.topProductosMes;
    final maxIng = prods.isNotEmpty ? _d(prods.first, 'ingresos') : 1.0;

    return _card(
      icon: Icons.inventory_2_rounded,
      iconBg: const Color(0xFFF0FDF4),
      iconColor: AppColors.secondary,
      title: 'Top Productos',
      subtitle: 'por ingresos del mes',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: prods.asMap().entries.map((e) {
          final p   = e.value;
          final pct = maxIng > 0 ? _d(p, 'ingresos') / maxIng : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${e.key + 1}. ',
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant)),
                Expanded(child: Text(
                  p['nombre']?.toString() ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.onSurface),
                )),
                Text(_compact(_d(p, 'ingresos')),
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.secondary)),
              ]),
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 2),
                child: Text('${p['cantidad'] ?? 0} unidades',
                    style: GoogleFonts.inter(
                        fontSize: 9.5, color: AppColors.onSurfaceVariant)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 5,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation(AppColors.secondary),
                  ),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Vendedores ─────────────────────────────────────────────

  Widget _vendedoresCard(ResumenMensual r) {
    final vends = r.vendedoresMes;
    final maxV  = vends.isNotEmpty ? _d(vends.first, 'total') : 1.0;

    return _card(
      icon: Icons.people_rounded,
      iconBg: const Color(0xFFF5F3FF),
      iconColor: const Color(0xFF8B5CF6),
      title: 'Vendedores del Mes',
      subtitle: 'ventas por empleado',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: vends.map((v) {
          final nombre   = v['nombre']?.toString() ?? '—';
          final total    = _d(v, 'total');
          final numVents = v['num_ventas'] ?? 0;
          final pct      = maxV > 0 ? total / maxV : 0.0;
          final initials = _initials(nombre);
          final avatarBg = _avatarColor(nombre);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: avatarBg.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: Center(child: Text(initials,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: avatarBg))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                  Text('$numVents ventas',
                      style: GoogleFonts.inter(
                          fontSize: 9.5, color: AppColors.onSurfaceVariant)),
                ])),
                Text(_compact(total),
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: avatarBg)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(avatarBg),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Gastos por categoría ───────────────────────────────────

  Widget _gastosCategoriaCard(ResumenMensual r) {
    final cats   = r.gastosPorCategoria;
    final maxCat = cats.isNotEmpty ? _d(cats.first, 'total') : 1.0;
    final totalG = cats.fold(0.0, (s, c) => s + _d(c, 'total'));

    const catColors = [
      Color(0xFFF59E0B), Color(0xFF3B82F6), AppColors.secondary,
      Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF6B7280),
    ];

    return _card(
      icon: Icons.pie_chart_rounded,
      iconBg: const Color(0xFFFFF7ED),
      iconColor: const Color(0xFFF59E0B),
      title: 'Gastos por Categoría',
      child: cats.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Sin gastos este mes',
                  style: GoogleFonts.inter(
                      color: AppColors.onSurfaceVariant, fontSize: 12)),
            ))
          : Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              ...cats.asMap().entries.map((e) {
                final pct   = maxCat > 0 ? _d(e.value, 'total') / maxCat : 0.0;
                final color = catColors[e.key % catColors.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        e.value['categoria']?.toString() ?? '—',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: AppColors.onSurface),
                      )),
                      Text(_compact(_d(e.value, 'total')),
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: color)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 5,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ]),
                );
              }),
              if (cats.isNotEmpty) ...[
                const Divider(height: 20, thickness: 0.5),
                Row(children: [
                  Text('Total Gastos',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  const Spacer(),
                  Text(fmt.format(totalG),
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.bold,
                          color: const Color(0xFFC2410C))),
                ]),
              ],
            ]),
    );
  }

  // ── Métodos de pago ────────────────────────────────────────

  Widget _metodosPagoCard(ResumenMensual r) {
    final metodos = r.metodosPagoMes;
    final totalM  = metodos.fold(0.0, (s, m) => s + _d(m, 'total'));

    const colMap = <String, Color>{
      'efectivo':      AppColors.secondary,
      'tarjeta':       Color(0xFF3B82F6),
      'transferencia': Color(0xFF8B5CF6),
      'nequi':         Color(0xFFF59E0B),
      'bono':          Color(0xFF6B7280),
    };
    Color metColor(String mp) =>
        colMap[mp.toLowerCase()] ?? const Color(0xFF9CA3AF);

    return _card(
      icon: Icons.credit_card_rounded,
      iconBg: const Color(0xFFEFF6FF),
      iconColor: const Color(0xFF3B82F6),
      title: 'Métodos de Pago',
      child: metodos.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Sin datos',
                  style: GoogleFonts.inter(
                      color: AppColors.onSurfaceVariant, fontSize: 12)),
            ))
          : Column(children: [
              SizedBox(
                height: 160,
                child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 46,
                  pieTouchData: PieTouchData(
                    touchCallback: (_, res) => setState(() {
                      _touchedPie =
                          res?.touchedSection?.touchedSectionIndex ?? -1;
                    }),
                  ),
                  sections: metodos.asMap().entries.map((e) {
                    final val     = _d(e.value, 'total');
                    final pct     = totalM > 0 ? val / totalM * 100 : 0.0;
                    final col     = metColor(e.value['metodo']?.toString() ?? '');
                    final touched = e.key == _touchedPie;
                    return PieChartSectionData(
                      value: val, color: col,
                      radius: touched ? 60 : 50,
                      title: touched ? '${pct.toStringAsFixed(0)}%' : '',
                      titleStyle: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: Colors.white),
                    );
                  }).toList(),
                )),
              ),
              const SizedBox(height: 10),
              ...metodos.map((m) {
                final col = metColor(m['metodo']?.toString() ?? '');
                final pct = totalM > 0 ? _d(m, 'total') / totalM * 100 : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: col, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      (m['metodo']?.toString() ?? '').capitalize(),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.onSurface),
                    )),
                    Text('${pct.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.onSurfaceVariant)),
                    const SizedBox(width: 10),
                    Text(_compact(_d(m, 'total')),
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: col)),
                  ]),
                );
              }),
            ]),
    );
  }

  // ── Balance neto ───────────────────────────────────────────

  Widget _balanceCard(ResumenMensual r) {
    final utilOper = r.utilidadBruta - r.totalGastos;

    Widget fila(String prefix, String label, double val,
        {Color? color, bool bold = false, bool divider = false,
         bool positive = true}) {
      final effectiveColor = color ??
          (val >= 0 ? AppColors.onSurface : const Color(0xFFDC2626));
      final sign = positive ? (val >= 0 ? '+' : '') : '−';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (divider) const Divider(height: 20, thickness: 0.5),
        Row(children: [
          Text('$prefix ',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade400)),
          Expanded(child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: bold ? AppColors.onSurface : AppColors.onSurfaceVariant))),
          Text('$sign${fmt.format(val.abs())}',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: effectiveColor)),
        ]),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.balance_rounded,
                size: 14, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Balance Neto del Mes',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: AppColors.onSurface)),
            Text('resultado financiero consolidado',
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.onSurfaceVariant)),
          ]),
        ]),
        const SizedBox(height: 14),
        fila('+', 'Ventas totales', r.totalVentas,
            color: AppColors.secondary, positive: true),
        const SizedBox(height: 6),
        fila('−', 'Devoluciones', r.totalDevoluciones,
            color: const Color(0xFFEF4444), positive: false),
        fila('=', 'Ventas netas', r.totalNeto,
            bold: true, divider: true, positive: true),
        const SizedBox(height: 6),
        fila('−', 'Gastos operativos', r.totalGastos,
            color: const Color(0xFFF59E0B), positive: false),
        fila('=', 'Utilidad operativa', utilOper,
            bold: true, divider: true,
            color: utilOper >= 0 ? AppColors.secondary : const Color(0xFFDC2626),
            positive: utilOper >= 0),
      ]),
    );
  }

  // ── Card container ─────────────────────────────────────────

  Widget _card({
    required IconData icon,
    required Color    iconBg,
    required Color    iconColor,
    required String   title,
    required Widget   child,
    String?           subtitle,
    Widget?           trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: AppColors.onSurface)),
            if (subtitle != null)
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.onSurfaceVariant)),
          ])),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  // ── Sin datos ──────────────────────────────────────────────

  Widget _sinDatos() {
    return Expanded(child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: AppColors.mintLight, shape: BoxShape.circle),
          child: const Icon(Icons.calendar_month_rounded,
              size: 38, color: AppColors.secondary),
        ),
        const SizedBox(height: 16),
        Text('Sin datos para ${meses[mes - 1]} $anio',
            style: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant,
                fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    )));
  }
}

// ── Helpers de extensión ───────────────────────────────────

extension _StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ── Modelo interno para KPI card ───────────────────────────

class _KpiData {
  final String label;
  final String value;
  final String sub;
  final Color  color;
  final double delta;
  final String vsLabel;
  final bool   invertDelta;

  const _KpiData({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.delta = 0,
    this.vsLabel = '',
    this.invertDelta = false,
  });
}
