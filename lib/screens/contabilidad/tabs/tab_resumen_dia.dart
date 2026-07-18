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

  // Azul para método de pago "transferencia" (sin token en AppColors)
  static const _transferBlue   = Color(0xFF3B82F6);
  static const _transferBlueBg = Color(0xFFEFF6FF);

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
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.secondary))
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
                            _kpiRow(r),
                            const SizedBox(height: 20),
                            if (r.ventasPorMetodo.isNotEmpty) ...[
                              _chartsRow(r.ventasPorMetodo),
                              const SizedBox(height: 20),
                            ],
                            _abonosSection(cont),
                            const SizedBox(height: 20),
                            _separadosSection(cont),
                            const SizedBox(height: 20),
                            _topClientesSection(cont),
                          ],
                        ),
                ),
              ),
      ),
    ]);
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
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
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
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: cont.cargando
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.secondary))
              : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.onSurfaceVariant),
        ),
      ),
    ]);
  }

  // ── 4 KPI cards ────────────────────────────────────────────

  Widget _kpiRow(dynamic r) {
    final util    = r.utilidadBruta as double;
    final utilPct = r.totalVentas > 0 ? (util / r.totalVentas * 100) : 0.0;

    return Row(children: [
      Expanded(child: _kpi(
        label:       'Total Ventas',
        value:       '\$${widget.fmt.format(r.totalVentas)}',
        sub:         '${r.numVentas} transacciones',
        icon:        Icons.trending_up_rounded,
        iconBg:      AppColors.mintLight,
        iconColor:   AppColors.secondary,
        subColor:    AppColors.secondary,
        subIcon:     Icons.arrow_upward_rounded,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpi(
        label:       'Gastos',
        value:       '\$${widget.fmt.format(r.totalGastos)}',
        sub:         'Del día',
        icon:        Icons.receipt_long_rounded,
        iconBg:      AppColors.errorContainer,
        iconColor:   AppColors.error,
        subColor:    AppColors.error,
        subIcon:     Icons.arrow_downward_rounded,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpi(
        label:       'Utilidad Bruta',
        value:       '\$${widget.fmt.format(util.abs())}',
        sub:         'Margen ${utilPct.abs().toStringAsFixed(1)}%',
        icon:        util >= 0
            ? Icons.show_chart_rounded
            : Icons.trending_down_rounded,
        iconBg:      util >= 0 ? AppColors.mintLight : AppColors.errorContainer,
        iconColor:   util >= 0 ? AppColors.secondary   : AppColors.error,
        subColor:    util >= 0 ? AppColors.secondary   : AppColors.error,
        subIcon:     util >= 0
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpi(
        label:       'Devoluciones',
        value:       '\$${widget.fmt.format(r.totalDevoluciones)}',
        sub:         '${r.numDevoluciones} devol.',
        icon:        Icons.assignment_return_rounded,
        iconBg:      AppColors.warningContainer,
        iconColor:   AppColors.warning,
        subColor:    AppColors.onSurfaceVariant,
        subIcon:     Icons.speed_rounded,
      )),
    ]);
  }

  Widget _kpi({
    required String   label,
    required String   value,
    required String   sub,
    required IconData icon,
    required Color    iconBg,
    required Color    iconColor,
    required Color    subColor,
    required IconData subIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant)),
          ),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ]),
        const SizedBox(height: 10),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(subIcon, size: 12, color: subColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(sub,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 11, color: subColor)),
          ),
        ]),
      ]),
    );
  }

  // ── Charts row ────────────────────────────────────────────

  Widget _chartsRow(List<Map<String, dynamic>> metodos) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final wide = constraints.maxWidth > 700;
      final bar  = _barChartCard(metodos);
      final pie  = _pieChartCard(metodos);
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: bar),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: pie),
          ],
        );
      }
      return Column(children: [
        bar,
        const SizedBox(height: 16),
        pie,
      ]);
    });
  }

  Widget _barChartCard(List<Map<String, dynamic>> metodos) {
    final maxVal = metodos
        .map((m) => _d(m, 'total'))
        .fold(0.0, (a, b) => a > b ? a : b);

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Ventas por Método',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface)),
          ),
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.secondary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('Ventas del día',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.onSurfaceVariant)),
          ]),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal > 0 ? maxVal * 1.3 : 100,
              barGroups: metodos.asMap().entries.map((e) {
                final m     = e.value;
                final total = _d(m, 'total');
                final color = _metodoPagoColor(m['metodo']?.toString() ?? '');
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: total,
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      width: 44,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxVal > 0 ? maxVal * 1.3 : 100,
                        color: AppColors.surfaceContainerLow,
                      ),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx >= metodos.length) return const SizedBox();
                      final label = _metodoPagoLabel(
                          metodos[idx]['metodo']?.toString() ?? '');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(label,
                            style: GoogleFonts.inter(
                                fontSize: 10, color: AppColors.onSurfaceVariant)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (value, _) {
                      if (value == 0) return const SizedBox();
                      return Text('\$${_shortNum(value)}',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.onSurfaceVariant));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.outlineVariant,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.onSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final m     = metodos[group.x];
                    final label = _metodoPagoLabel(
                        m['metodo']?.toString() ?? '');
                    final color = _metodoPagoColor(
                        m['metodo']?.toString() ?? '');
                    return BarTooltipItem(
                      '$label\n',
                      GoogleFonts.inter(
                          color: Colors.white, fontSize: 12),
                      children: [
                        TextSpan(
                          text: '\$${widget.fmt.format(rod.toY)}',
                          style: GoogleFonts.inter(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pieChartCard(List<Map<String, dynamic>> metodos) {
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
          height: 160,
          child: PieChart(
            PieChartData(
              sections: metodos.asMap().entries.map((e) {
                final m   = e.value;
                final val = _d(m, 'total');
                final pct = total > 0 ? val / total * 100 : 0.0;
                final col = _metodoPagoColor(m['metodo']?.toString() ?? '');
                return PieChartSectionData(
                  value: val,
                  color: col,
                  radius: 55,
                  title:  '${pct.toStringAsFixed(0)}%',
                  titleStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
              sectionsSpace:     3,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 6),
              Text('$label ($cant)',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }

  // ── Abonos table ──────────────────────────────────────────

  Widget _abonosSection(ContabilidadProvider cont) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.savings_rounded,
                size: 16, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Abonos ${_esHoy ? "de hoy" : _labelFecha}',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface),
            ),
          ),
          if (cont.abonosDia.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${cont.abonosDia.length}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary)),
            ),
        ]),
        const SizedBox(height: 16),
        if (cont.abonosDia.isEmpty)
          _emptyState('Sin abonos este día', Icons.savings_outlined)
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              _th('Hora',     flex: 1),
              _th('Cliente',  flex: 3),
              _th('Empleado', flex: 3),
              _th('Método',   flex: 2),
              _th('Monto',    flex: 2, right: true),
            ]),
          ),
          ...cont.abonosDia.map((a) {
            final monto    = _d(a, 'monto');
            final cliente  = a['cliente_nombre']?.toString()  ?? '—';
            final empleado = a['empleado_nombre']?.toString() ?? '—';
            final metodo   = a['metodo_pago']?.toString()     ?? 'efectivo';
            final hora     = _hora(a['created_at']?.toString() ?? '');
            final colorMet = _metodoPagoColor(metodo);

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: Row(children: [
                Expanded(
                  flex: 1,
                  child: Text(hora,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.onSurfaceVariant)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(cliente,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(empleado,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.onSurfaceVariant)),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorMet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _metodoPagoLabel(metodo),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colorMet),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '+\$${widget.fmt.format(monto)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary),
                  ),
                ),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  // ── Separados ─────────────────────────────────────────────

  Widget _separadosSection(ContabilidadProvider cont) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _transferBlueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                size: 16, color: _transferBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Separados ${_esHoy ? "de hoy" : _labelFecha}',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface),
            ),
          ),
          if (cont.separadosDia.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _transferBlueBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${cont.separadosDia.length}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(cliente,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.onSurface)),
              Text(empleado,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: colorEBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_estadoLabel(estado),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colorE)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: AppColors.outlineVariant,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
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
                  Container(
                    width: 4, height: 4,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                        shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      d['producto_nombre']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    'x${d['cantidad']}  \$${widget.fmt.format(_d(d, 'subtotal'))}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                ]),
              )),
          if (detalles.length > 3)
            Text('+ ${detalles.length - 3} más',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ]),
    );
  }

  // ── Top Clientes ──────────────────────────────────────────

  Widget _topClientesSection(ContabilidadProvider cont) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.star_rounded, size: 16, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Top Clientes ${_esHoy ? "de hoy" : _labelFecha}',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
          ),
          if (cont.topClientes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${cont.topClientes.length}',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: const Color(0xFF7C3AED))),
            ),
        ]),
        const SizedBox(height: 14),
        if (cont.topClientes.isEmpty)
          _emptyState('Sin clientes registrados este día', Icons.person_search_rounded)
        else
          ...cont.topClientes.asMap().entries.map((e) =>
              _topClienteRow(e.key, e.value)),
      ]),
    );
  }

  Widget _topClienteRow(int index, TopCliente c) {
    final iniciales = c.nombre.split(' ')
        .where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final avatarColor = _avatarColor(c.clienteId);
    final tierColor = c.tierColorHex != null
        ? Color(int.parse(c.tierColorHex!.replaceFirst('#', '0xFF')))
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // Posición
        SizedBox(
          width: 20,
          child: Text('${index + 1}',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant)),
        ),
        const SizedBox(width: 6),
        // Avatar
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(iniciales,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: avatarColor)),
          ),
        ),
        const SizedBox(width: 10),
        // Nombre + tier
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.nombre,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
            if (c.tierNombre != null && tierColor != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 10, color: tierColor),
                const SizedBox(width: 3),
                Text(c.tierNombre!,
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: tierColor)),
              ]),
          ]),
        ),
        // Stats
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${widget.fmt.format(c.totalPeriodo)}',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: AppColors.secondary)),
          Text('${c.numCompras} compra${c.numCompras != 1 ? 's' : ''}',
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.onSurfaceVariant)),
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
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _th(String label, {int flex = 1, bool right = false}) => Expanded(
        flex: flex,
        child: Text(label,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant)),
      );

  Widget _miniStat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      );

  Widget _emptyState(String msg, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(children: [
            Icon(icon, size: 36,
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
              Text('Sin datos para $_labelFecha',
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

  // ── Helpers ────────────────────────────────────────────────

  String _hora(String s) {
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
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
