// lib/screens/caja/caja_dashboard_admin.dart
// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/caja_service.dart';
import '../../services/tienda_service.dart';

// ── Design System Colors ───────────────────────────────────────────────────────
class _C {
  static const bg               = Color(0xFFF7F9FB);
  static const surface          = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFECEEF0);
  static const surfaceLow       = Color(0xFFF2F4F6);
  static const border           = Color(0xFFC6C6CD);
  static const divider          = Color(0xFFE0E3E5);
  static const textPrimary      = Color(0xFF191C1E);
  static const textSecond       = Color(0xFF45464D);
  static const textFaint        = Color(0xFF76777D);
  static const green            = Color(0xFF006C49);
  static const greenContainer   = Color(0xFF6CF8BB);
  static const greenOnContainer = Color(0xFF00714D);
  static const greenDim         = Color(0xFF4EDEA3);
  static const error            = Color(0xFFBA1A1A);
  static const errorContainer   = Color(0xFFFFDAD6);
  static const amber            = Color(0xFFB45309);
  static const amberLight       = Color(0xFFFEF3C7);
}

// ── Widget principal ──────────────────────────────────────────────────────────
class CajaDashboardAdmin extends StatefulWidget {
  const CajaDashboardAdmin({super.key});
  @override
  State<CajaDashboardAdmin> createState() => _CajaDashboardAdminState();
}

class _CajaDashboardAdminState extends State<CajaDashboardAdmin> {
  final _svc      = CajaService();
  final _tiendaSvc = TiendaService();

  bool    _loading = true;
  String? _error;
  String  _periodo  = 'mensual';
  int?    _tiendaId;

  List<Map<String, dynamic>> _tiendas = [];

  double _totalCashFlow         = 0;
  double _totalDiscrepancias    = 0;
  int    _numTiendasConFaltante = 0;
  double _netProfit             = 0;
  String _topStoreNombre        = '—';
  double _topStoreTotalHoy      = 0;

  List<Map<String, dynamic>> _ventasPorTienda  = [];
  List<Map<String, dynamic>> _alertasFaltantes = [];
  List<Map<String, dynamic>> _topCrecimiento   = [];
  List<Map<String, dynamic>> _historial        = [];

  @override
  void initState() {
    super.initState();
    _loadTiendas();
    _cargar();
  }

  Future<void> _loadTiendas() async {
    final list = await _tiendaSvc.getTiendasSimple();
    if (mounted) setState(() => _tiendas = list);
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });

    final results = await Future.wait([
      _svc.getDashboardCaja(periodo: _periodo, tiendaId: _tiendaId),
      _svc.getHistorialSesiones(estado: 'cerrada', tiendaId: _tiendaId),
    ]);

    if (!mounted) return;

    final dash = results[0] as Map<String, dynamic>;
    if (dash['success'] != true) {
      setState(() { _loading = false; _error = dash['error']?.toString() ?? 'Error al cargar'; });
      return;
    }

    final d    = dash['data'] as Map<String, dynamic>;
    final kpis = d['kpis']   as Map<String, dynamic>;
    final topRaw = kpis['top_store'];
    final top    = (topRaw is Map) ? Map<String, dynamic>.from(topRaw) : <String, dynamic>{};
    final hist   = results[1] as List<Map<String, dynamic>>;

    setState(() {
      _loading                = false;
      _totalCashFlow          = (kpis['total_cash_flow']          as num?)?.toDouble() ?? 0;
      _totalDiscrepancias     = (kpis['total_discrepancias']       as num?)?.toDouble() ?? 0;
      _numTiendasConFaltante  = (kpis['num_tiendas_con_faltante']  as num?)?.toInt()   ?? 0;
      _netProfit              = (kpis['net_profit']                as num?)?.toDouble() ?? 0;
      _topStoreNombre         = (top['nombre']    as String?)  ?? '—';
      _topStoreTotalHoy       = (top['total_hoy'] as num?)?.toDouble() ?? 0;
      _ventasPorTienda        = List<Map<String, dynamic>>.from(d['ventas_por_tienda']  ?? []);
      _alertasFaltantes       = List<Map<String, dynamic>>.from(d['alertas_faltantes']  ?? []);
      _topCrecimiento         = List<Map<String, dynamic>>.from(d['top_crecimiento']    ?? []);
      _historial              = hist.take(25).toList();
    });
  }

  String _fmt(double v) {
    final abs    = v.abs();
    final prefix = v < 0 ? '-' : '';
    if (abs >= 1000000) return '$prefix\$${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000)    return '$prefix\$${(abs / 1000).toStringAsFixed(0)}K';
    return '$prefix\$${abs.toStringAsFixed(0)}';
  }

  String _fmtFull(double v) {
    final prefix = v < 0 ? '-\$' : '\$';
    return '$prefix${v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _C.green));
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_rounded, size: 48, color: _C.textFaint),
        const SizedBox(height: 16),
        Text(_error!, style: GoogleFonts.inter(color: _C.textSecond, fontSize: 13)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(backgroundColor: _C.green, foregroundColor: Colors.white, elevation: 0),
        ),
      ]));
    }

    return Container(
      color: _C.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildKpis(),
          const SizedBox(height: 20),
          _buildMainRow(),
          if (_historial.isNotEmpty) ...[
            const SizedBox(height: 20),
            _HistorialCard(historial: _historial, fmtFull: _fmtFull),
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _C.greenContainer, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.payments_rounded, size: 20, color: _C.green),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Control de Caja', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('Flujo de efectivo, faltantes y cierres por tienda', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 12)),
      ]),
      const Spacer(),
      if (_tiendas.isNotEmpty) ...[
        _buildStoreSelector(),
        const SizedBox(width: 10),
      ],
      _PeriodToggle(value: _periodo, onChange: (v) { setState(() => _periodo = v); _cargar(); }),
    ]);
  }

  Widget _buildStoreSelector() {
    final label = _tiendaId == null
        ? 'Todas las tiendas'
        : (_tiendas.firstWhere(
              (t) => t['id'] == _tiendaId,
              orElse: () => {'nombre': '?'},
            )['nombre'] as String);

    return PopupMenuButton<int?>(
      onSelected: (id) {
        setState(() => _tiendaId = id);
        _cargar();
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: _C.border)),
      color: _C.surface,
      elevation: 4,
      itemBuilder: (_) => [
        PopupMenuItem<int?>(
          value: null,
          child: Row(children: [
            Icon(Icons.store_mall_directory_rounded, size: 16, color: _tiendaId == null ? _C.green : _C.textFaint),
            const SizedBox(width: 8),
            Text('Todas las tiendas',
              style: GoogleFonts.inter(
                color: _tiendaId == null ? _C.green : _C.textPrimary,
                fontSize: 13,
                fontWeight: _tiendaId == null ? FontWeight.w700 : FontWeight.w400,
              )),
          ]),
        ),
        ..._tiendas.map((t) {
          final id = t['id'] as int;
          final selected = _tiendaId == id;
          return PopupMenuItem<int?>(
            value: id,
            child: Row(children: [
              Icon(Icons.location_on_rounded, size: 16, color: selected ? _C.green : _C.textFaint),
              const SizedBox(width: 8),
              Text(t['nombre'] as String,
                style: GoogleFonts.inter(
                  color: selected ? _C.green : _C.textPrimary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                )),
            ]),
          );
        }),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _tiendaId != null ? _C.green : _C.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on_rounded, size: 15, color: _tiendaId != null ? _C.green : _C.textFaint),
          const SizedBox(width: 6),
          Text(label,
            style: GoogleFonts.inter(
              color: _tiendaId != null ? _C.green : _C.textPrimary,
              fontSize: 12,
              fontWeight: _tiendaId != null ? FontWeight.w700 : FontWeight.w500,
            )),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 16, color: _tiendaId != null ? _C.green : _C.textFaint),
        ]),
      ),
    );
  }

  // ── KPIs ───────────────────────────────────────────────────────────────────
  Widget _buildKpis() {
    final hasFaltante = _totalDiscrepancias < 0;
    final kpis = [
      _KpiData(
        title: 'Total Cash Flow',
        sub: _periodo == 'semanal' ? 'Esta semana' : 'Este mes',
        value: _fmt(_totalCashFlow),
        trend: 'Flujo de efectivo total',
        trendUp: _totalCashFlow >= 0,
        icon: Icons.payments_outlined,
        accent: _C.green,
        valueColor: _C.textPrimary,
      ),
      _KpiData(
        title: 'Top Tienda Hoy',
        sub: _fmtFull(_topStoreTotalHoy),
        value: _topStoreNombre,
        trend: 'Mayor facturación hoy',
        trendUp: true,
        icon: Icons.workspace_premium_outlined,
        accent: _C.green,
        valueColor: _C.textPrimary,
        isText: true,
      ),
      _KpiData(
        title: 'Total Faltantes',
        sub: '$_numTiendasConFaltante tienda(s) con faltante',
        value: _fmt(_totalDiscrepancias),
        trend: hasFaltante ? 'Revisar arqueos' : 'Sin faltantes',
        trendUp: !hasFaltante,
        icon: Icons.warning_amber_rounded,
        accent: hasFaltante ? _C.error : _C.green,
        valueColor: hasFaltante ? _C.error : _C.textPrimary,
      ),
      _KpiData(
        title: 'Net Profit',
        sub: 'Después de todos los gastos',
        value: _fmt(_netProfit),
        trend: _netProfit >= 0 ? 'Resultado positivo' : 'Resultado negativo',
        trendUp: _netProfit >= 0,
        icon: Icons.account_balance_wallet_outlined,
        accent: _C.green,
        valueColor: _C.greenOnContainer,
      ),
    ];

    return Wrap(spacing: 16, runSpacing: 16, children: kpis.map((k) => _KpiCard(data: k)).toList());
  }

  // ── Main row: chart left + side cards right ────────────────────────────────
  Widget _buildMainRow() {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 960;
    final hasSide = _alertasFaltantes.isNotEmpty || _topCrecimiento.isNotEmpty;

    if (_ventasPorTienda.isEmpty && !hasSide) return const SizedBox.shrink();

    final chart = _ventasPorTienda.isNotEmpty
        ? _TrendsCard(ventas: _ventasPorTienda, periodo: _periodo)
        : const SizedBox.shrink();

    final side = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_alertasFaltantes.isNotEmpty) _AlertasFaltantesCard(alertas: _alertasFaltantes, fmtFull: _fmtFull),
      if (_alertasFaltantes.isNotEmpty && _topCrecimiento.isNotEmpty) const SizedBox(height: 16),
      if (_topCrecimiento.isNotEmpty) _TopCrecimientoCard(top: _topCrecimiento, fmtFull: _fmtFull),
    ]);

    if (!hasSide) return chart;
    if (_ventasPorTienda.isEmpty) return side;

    if (isWide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 8, child: chart),
        const SizedBox(width: 20),
        SizedBox(width: 320, child: side),
      ]);
    }
    return Column(children: [
      chart,
      const SizedBox(height: 16),
      side,
    ]);
  }
}

// ── KPI data model ─────────────────────────────────────────────────────────────
class _KpiData {
  final String title, sub, value, trend;
  final bool?  trendUp;
  final bool   isText;
  final IconData icon;
  final Color  accent;
  final Color  valueColor;
  const _KpiData({
    required this.title, required this.sub, required this.value,
    required this.trend, this.trendUp, this.isText = false,
    required this.icon, required this.accent, required this.valueColor,
  });
}

// ── KPI Card ───────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = w >= 1100 ? (w - 56 - 48) / 4 : w >= 700 ? (w - 56 - 16) / 2 : w - 56.0;
    final up = data.trendUp ?? true;
    return Container(
      width: cardW,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(
              data.title.toUpperCase(),
              style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(data.icon, size: 20, color: data.accent),
        ]),
        const SizedBox(height: 14),
        Text(
          data.value,
          style: data.isText
              ? GoogleFonts.inter(color: data.valueColor, fontSize: 18, fontWeight: FontWeight.w700)
              : GoogleFonts.inter(color: data.valueColor, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.01),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(data.sub, style: GoogleFonts.inter(color: _C.textFaint, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: up ? _C.green : _C.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              data.trend,
              style: GoogleFonts.inter(color: up ? _C.green : _C.error, fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Period Toggle ──────────────────────────────────────────────────────────────
class _PeriodToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChange;
  const _PeriodToggle({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _C.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _PeriodBtn(label: 'Semanal', active: value == 'semanal', onTap: () => onChange('semanal')),
        _PeriodBtn(label: 'Mensual', active: value == 'mensual', onTap: () => onChange('mensual')),
      ]),
    );
  }
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PeriodBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _C.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? _C.green : _C.textFaint,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Trends Card (Bar Chart) ────────────────────────────────────────────────────
class _TrendsCard extends StatelessWidget {
  final List<Map<String, dynamic>> ventas;
  final String periodo;
  const _TrendsCard({required this.ventas, required this.periodo});

  String _shortName(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return name;
    if (words.length == 1) return name.length > 9 ? '${name.substring(0, 8)}…' : name;
    return words.take(2).map((w) => w.length > 7 ? '${w.substring(0, 6)}.' : w).join('\n');
  }

  String _fmtY(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final totals = ventas.map((v) => (v['total'] as num).toDouble()).toList();
    final maxVal = totals.reduce(max);
    final maxIdx = totals.indexOf(maxVal);
    final barW   = ventas.length <= 4 ? 36.0 : ventas.length <= 7 ? 26.0 : 16.0;
    final interval = maxVal > 0 ? (maxVal / 4).ceilToDouble() : 1.0;

    final groups = ventas.asMap().entries.map((e) {
      final total = (e.value['total'] as num).toDouble();
      final isTop = e.key == maxIdx;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: total,
            color: isTop ? _C.green : _C.greenContainer,
            width: barW,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tendencias de Ventas por Tienda', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Comparativo ${periodo == 'semanal' ? 'semanal' : 'mensual'} entre tiendas', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _C.surfaceLow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _C.border),
            ),
            child: Text(
              periodo == 'semanal' ? 'Semanal' : 'Mensual',
              style: GoogleFonts.inter(color: _C.green, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.25,
              minY: 0,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(color: _C.divider, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    interval: interval,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(_fmtY(value), style: GoogleFonts.inter(color: _C.textFaint, fontSize: 9), textAlign: TextAlign.right),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= ventas.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _shortName(ventas[idx]['nombre'] as String),
                          style: GoogleFonts.inter(color: _C.textSecond, fontSize: 9),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => _C.textPrimary,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  getTooltipItem: (group, _, rod, r) {
                    final nombre = ventas[group.x]['nombre'] as String;
                    return BarTooltipItem(
                      nombre,
                      GoogleFonts.inter(color: Colors.white.withOpacity(0.75), fontSize: 10),
                      children: [
                        TextSpan(
                          text: '\n${_fmtY(rod.toY)}',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            swapAnimationDuration: const Duration(milliseconds: 600),
            swapAnimationCurve: Curves.easeInOutCubic,
          ),
        ),
      ]),
    );
  }
}

// ── Alertas de Faltantes ──────────────────────────────────────────────────────
class _AlertasFaltantesCard extends StatelessWidget {
  final List<Map<String, dynamic>> alertas;
  final String Function(double) fmtFull;
  const _AlertasFaltantesCard({required this.alertas, required this.fmtFull});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.emergency_rounded, size: 18, color: _C.error),
          const SizedBox(width: 8),
          Text('Alerta de Faltantes', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        ...alertas.take(6).map((a) {
          final diff     = (a['diferencia'] as num).toDouble();
          final tienda   = a['tienda']   as String;
          final empleado = a['empleado'] as String;
          final fecha    = (a['fecha']   as String).substring(0, 10);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border.withOpacity(0.5)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _C.errorContainer, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.money_off_rounded, size: 20, color: _C.error),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tienda, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('$empleado · $fecha', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 11)),
              ])),
              Text(fmtFull(diff), style: GoogleFonts.inter(color: _C.error, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          );
        }),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () {},
            child: Text('Ver todas las discrepancias', style: GoogleFonts.inter(color: _C.green, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── Top Crecimiento ───────────────────────────────────────────────────────────
class _TopCrecimientoCard extends StatelessWidget {
  final List<Map<String, dynamic>> top;
  final String Function(double) fmtFull;
  const _TopCrecimientoCard({required this.top, required this.fmtFull});

  @override
  Widget build(BuildContext context) {
    final maxTot = top.isEmpty ? 1.0 : top.map((x) => (x['total_actual'] as num).toDouble()).reduce(max);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.trending_up_rounded, size: 18, color: _C.green),
          const SizedBox(width: 8),
          Text('Top Tiendas por Crecimiento', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        ...top.asMap().entries.map((e) {
          final idx      = e.key;
          final t        = e.value;
          final pct      = (t['crecimiento_pct'] as num).toDouble();
          final tot      = (t['total_actual']    as num).toDouble();
          final progress = (tot / maxTot).clamp(0.0, 1.0);
          final up       = pct >= 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: idx == 0 ? _C.greenContainer : _C.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(
                  '${idx + 1}',
                  style: GoogleFonts.inter(color: idx == 0 ? _C.green : _C.textSecond, fontSize: 13, fontWeight: FontWeight.w700),
                )),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['nombre'] as String, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: _C.surfaceContainer,
                    color: idx == 0 ? _C.green : _C.greenDim,
                    minHeight: 6,
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: up ? _C.greenContainer.withOpacity(0.3) : _C.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(color: up ? _C.green : _C.error, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Historial de Cierres ──────────────────────────────────────────────────────
class _HistorialCard extends StatelessWidget {
  final List<Map<String, dynamic>> historial;
  final String Function(double) fmtFull;
  const _HistorialCard({required this.historial, required this.fmtFull});

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString().substring(0, 10);
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Row(children: [
            Expanded(
              child: Text('Historial Detallado de Cierres', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _C.surfaceLow, borderRadius: BorderRadius.circular(8), border: Border.all(color: _C.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.filter_list_rounded, size: 14, color: _C.textFaint),
                const SizedBox(width: 6),
                Text('Filtrar', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        Divider(color: _C.divider, height: 1),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(_C.surfaceLow),
            headingRowHeight: 42,
            dataRowMinHeight: 50,
            dataRowMaxHeight: 60,
            columnSpacing: 20,
            horizontalMargin: 20,
            headingTextStyle: GoogleFonts.inter(color: _C.textFaint, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            dataTextStyle: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12),
            columns: const [
              DataColumn(label: Text('FECHA & TIENDA')),
              DataColumn(label: Text('CAJERO')),
              DataColumn(label: Text('APERTURA'),  numeric: true),
              DataColumn(label: Text('VENTAS'),    numeric: true),
              DataColumn(label: Text('GASTOS'),    numeric: true),
              DataColumn(label: Text('ESPERADO'),  numeric: true),
              DataColumn(label: Text('REAL'),      numeric: true),
              DataColumn(label: Text('DIFERENCIA'),numeric: true),
              DataColumn(label: Text('ESTADO')),
            ],
            rows: historial.map((s) {
              final diff     = s['diferencia']       != null ? double.tryParse(s['diferencia'].toString())       ?? 0.0 : 0.0;
              final real     = s['monto_final_real']  != null ? double.tryParse(s['monto_final_real'].toString()) ?? 0.0 : 0.0;
              final esperado = s['monto_esperado']    != null ? double.tryParse(s['monto_esperado'].toString())   ?? 0.0 : 0.0;
              final ventas   = s['ventas_total']      != null ? double.tryParse(s['ventas_total'].toString())     ?? 0.0 : 0.0;
              final gastos   = s['gastos_total']      != null ? double.tryParse(s['gastos_total'].toString())     ?? 0.0 : 0.0;
              final apertura = s['saldo_inicial']     != null ? double.tryParse(s['saldo_inicial'].toString())    ?? 0.0 : 0.0;
              final tienda   = s['tienda_nombre']    ?? '—';
              final cajero   = s['empleado_nombre']  ?? '—';
              final fecha    = _fmtDate(s['fecha_apertura']);

              Color  diffColor;
              String diffLabel;
              Color  diffBg;
              if (diff == 0) {
                diffColor = _C.green; diffLabel = 'Exacto';   diffBg = _C.greenContainer.withOpacity(0.3);
              } else if (diff < 0) {
                diffColor = _C.error; diffLabel = 'Faltante'; diffBg = _C.errorContainer;
              } else {
                diffColor = _C.amber; diffLabel = 'Sobrante'; diffBg = _C.amberLight;
              }

              return DataRow(cells: [
                DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fecha,  style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(tienda, style: GoogleFonts.inter(color: _C.textFaint,   fontSize: 10)),
                ])),
                DataCell(Text(cajero,         style: GoogleFonts.inter(color: _C.textSecond,    fontSize: 11))),
                DataCell(Text(fmtFull(apertura), style: GoogleFonts.inter(color: _C.textSecond, fontSize: 11))),
                DataCell(Text(fmtFull(ventas),   style: GoogleFonts.inter(color: _C.green,      fontSize: 11, fontWeight: FontWeight.w600))),
                DataCell(Text(fmtFull(gastos),   style: GoogleFonts.inter(color: _C.error,      fontSize: 11))),
                DataCell(Text(fmtFull(esperado), style: GoogleFonts.inter(color: _C.textSecond, fontSize: 11))),
                DataCell(Text(fmtFull(real),     style: GoogleFonts.inter(color: _C.textPrimary,fontSize: 11, fontWeight: FontWeight.w600))),
                DataCell(Text(fmtFull(diff),     style: GoogleFonts.inter(color: diffColor,     fontSize: 11, fontWeight: FontWeight.w700))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: diffBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(diffLabel, style: GoogleFonts.inter(color: diffColor, fontSize: 10, fontWeight: FontWeight.w700)),
                )),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
