// lib/screens/caja/caja_dashboard_admin.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../models/sesion_historial.dart';
import '../../services/caja_service.dart';
import '../../services/tienda_service.dart';
import '../../theme/app_colors.dart';
import '../../core/dashboard_cache.dart';
import 'widgets/pdf/cierre_pdf.dart';

// ── Widget principal ──────────────────────────────────────────────────────────
class CajaDashboardAdmin extends StatefulWidget {
  const CajaDashboardAdmin({super.key});
  @override
  State<CajaDashboardAdmin> createState() => _CajaDashboardAdminState();
}

class _CajaDashboardAdminState extends State<CajaDashboardAdmin> {
  final _svc       = CajaService();
  final _tiendaSvc = TiendaService();

  // Alias al caché compartido (se limpia en logout desde auth_provider)
  static List<Map<String, dynamic>>?             get _tiendasCache    => cajaTiendasCache;
  static set _tiendasCache(List<Map<String, dynamic>>? v)             => cajaTiendasCache = v;
  static Map<String, Map<String, dynamic>>       get _dashCache       => cajaDashboardCache;

  bool    _loadingDash = true;
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

  List<Map<String, dynamic>> _topCrecimiento = [];

  @override
  void initState() {
    super.initState();
    _loadTiendas();
    _cargarDashboard();
  }

  Future<void> _loadTiendas() async {
    if (_tiendasCache != null) {
      setState(() => _tiendas = _tiendasCache!);
      return;
    }
    final list = await _tiendaSvc.getTiendasSimple();
    _tiendasCache = list;
    if (mounted) setState(() => _tiendas = list);
  }

  // ── Dashboard KPIs ────────────────────────────────────────────────────────
  Future<void> _cargarDashboard() async {
    final key    = '${_periodo}_${_tiendaId ?? 'all'}';
    final cached = _dashCache[key];

    if (cached != null) {
      // Mostrar datos guardados al instante (sin spinner)
      _applyDashData(cached);
      // Refrescar silenciosamente en background
      _refreshDashBackground(key);
      return;
    }

    // Primera carga: spinner normal
    setState(() { _loadingDash = true; _error = null; });
    await _fetchDashAndStore(key);
  }

  // ignore: unawaited_futures
  void _refreshDashBackground(String key) => _fetchDashAndStore(key);

  Future<void> _fetchDashAndStore(String key) async {
    final dash = await _svc.getDashboardCaja(periodo: _periodo, tiendaId: _tiendaId);
    if (!mounted) return;
    if (dash['success'] != true) {
      if (_dashCache[key] == null) {
        setState(() {
          _loadingDash = false;
          _error       = dash['error']?.toString() ?? 'Error al cargar';
        });
      }
      return;
    }
    final d = dash['data'] as Map<String, dynamic>;
    _dashCache[key] = d;
    _applyDashData(d);
  }

  void _applyDashData(Map<String, dynamic> d) {
    final kpis   = d['kpis']   as Map<String, dynamic>;
    final topRaw = kpis['top_store'];
    final top    = (topRaw is Map) ? Map<String, dynamic>.from(topRaw) : <String, dynamic>{};
    setState(() {
      _loadingDash           = false;
      _totalCashFlow         = (kpis['total_cash_flow']          as num?)?.toDouble() ?? 0;
      _totalDiscrepancias    = (kpis['total_discrepancias']       as num?)?.toDouble() ?? 0;
      _numTiendasConFaltante = (kpis['num_tiendas_con_faltante']  as num?)?.toInt()   ?? 0;
      _netProfit             = (kpis['net_profit']                as num?)?.toDouble() ?? 0;
      _topStoreNombre        = (top['nombre']    as String?)  ?? '—';
      _topStoreTotalHoy      = (top['total_hoy'] as num?)?.toDouble() ?? 0;
      _topCrecimiento        = List<Map<String, dynamic>>.from(d['top_crecimiento']    ?? []);
    });
  }

  void _recargar() {
    // Al recargar manualmente (cambio de filtro): invalidar caché y recargar
    final key = '${_periodo}_${_tiendaId ?? 'all'}';
    _dashCache.remove(key);
    _cargarDashboard();
  }

  // ── Formatters ─────────────────────────────────────────────────────────────
  String _fmt(double v) {
    final abs    = v.abs();
    final prefix = v < 0 ? '-' : '';
    if (abs >= 1000000) return '$prefix\$${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000)    return '$prefix\$${(abs / 1000).toStringAsFixed(0)}K';
    return '$prefix\$${abs.toStringAsFixed(0)}';
  }

  String _fmtFull(double v) {
    final prefix = v < 0 ? '-\$' : '\$';
    return '$prefix${v.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDash) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.mintLight, shape: BoxShape.circle),
          child: const Icon(Icons.cloud_off_rounded, size: 32, color: AppColors.secondary),
        ),
        const SizedBox(height: 16),
        Text(_error!, style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _recargar,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary, foregroundColor: Colors.white, elevation: 0),
        ),
      ]));
    }

    final w = MediaQuery.of(context).size.width;
    if (w < 600) {
      return _MobileCajaDashboard(
        periodo:              _periodo,
        tiendaId:             _tiendaId,
        tiendas:              _tiendas,
        totalCashFlow:        _totalCashFlow,
        totalDiscrepancias:   _totalDiscrepancias,
        numTiendasConFaltante: _numTiendasConFaltante,
        netProfit:            _netProfit,
        topStoreNombre:       _topStoreNombre,
        topStoreTotalHoy:     _topStoreTotalHoy,
        topCrecimiento:       _topCrecimiento,
        onPeriodChange: (v) { setState(() => _periodo = v); _recargar(); },
        onTiendaChange: (id) { setState(() => _tiendaId = id); _recargar(); },
        fmt:     _fmt,
        fmtFull: _fmtFull,
      );
    }

    final isNarrow = w < 700;
    return Container(
      color: AppColors.surfaceContainerLow,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isNarrow ? 16 : 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildKpis(),
          const SizedBox(height: 20),
          _buildMainRow(),
          const SizedBox(height: 20),
          _buildHistorial(),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final isNarrow = MediaQuery.of(context).size.width < 700;

    final titleBlock = Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.mintLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.payments_rounded, size: 20, color: AppColors.secondary),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Control de Caja',
            style: GoogleFonts.inter(
                color: AppColors.onSurface, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('Flujo de efectivo, faltantes y cierres por tienda',
            style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 12),
            overflow: TextOverflow.ellipsis),
      ])),
    ]);

    final controls = Row(mainAxisSize: MainAxisSize.min, children: [
      if (_tiendas.isNotEmpty) ...[
        _buildStoreSelector(),
        const SizedBox(width: 10),
      ],
      _PeriodToggle(value: _periodo, onChange: (v) { setState(() => _periodo = v); _recargar(); }),
    ]);

    if (isNarrow) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        titleBlock,
        const SizedBox(height: 12),
        controls,
      ]);
    }
    return Row(children: [
      Expanded(child: titleBlock),
      const SizedBox(width: 12),
      controls,
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
      onSelected: (id) { setState(() => _tiendaId = id); _recargar(); },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      elevation: 4,
      itemBuilder: (_) => [
        PopupMenuItem<int?>(
          value: null,
          child: Row(children: [
            Icon(Icons.store_mall_directory_rounded,
                size: 16, color: _tiendaId == null ? AppColors.secondary : AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Text('Todas las tiendas',
                style: GoogleFonts.inter(
                    color: _tiendaId == null ? AppColors.secondary : AppColors.onSurface,
                    fontSize: 13,
                    fontWeight: _tiendaId == null ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
        ..._tiendas.map((t) {
          final id       = t['id'] as int;
          final selected = _tiendaId == id;
          return PopupMenuItem<int?>(
            value: id,
            child: Row(children: [
              Icon(Icons.location_on_rounded,
                  size: 16, color: selected ? AppColors.secondary : AppColors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(t['nombre'] as String,
                  style: GoogleFonts.inter(
                      color: selected ? AppColors.secondary : AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
            ]),
          );
        }),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: _tiendaId != null ? AppColors.secondary : Colors.grey.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on_rounded,
              size: 15,
              color: _tiendaId != null ? AppColors.secondary : AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: _tiendaId != null ? AppColors.secondary : AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: _tiendaId != null ? FontWeight.w700 : FontWeight.w500)),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded,
              size: 16,
              color: _tiendaId != null ? AppColors.secondary : AppColors.onSurfaceVariant),
        ]),
      ),
    );
  }

  // ── KPIs ───────────────────────────────────────────────────────────────────
  Widget _buildKpis() {
    final hasFaltante = _totalDiscrepancias < 0;
    final kpis = [
      _KpiData(
        label: 'Flujo de Caja',
        sub:   _periodo == 'semanal' ? 'Esta semana' : 'Este mes',
        value: _fmt(_totalCashFlow),
        trend: 'Flujo de efectivo total',
        trendUp: _totalCashFlow >= 0,
        icon:  Icons.payments_rounded,
        iconBg: AppColors.mintLight,
        iconColor: AppColors.secondary,
        valueColor: AppColors.onSurface,
      ),
      _KpiData(
        label: 'Top Tienda Hoy',
        sub:   _fmtFull(_topStoreTotalHoy),
        value: _topStoreNombre,
        trend: 'Mayor facturación hoy',
        trendUp: true,
        icon:  Icons.workspace_premium_rounded,
        iconBg: const Color(0xFFFFF7ED),
        iconColor: const Color(0xFFD97706),
        valueColor: AppColors.onSurface,
        isText: true,
      ),
      _KpiData(
        label: 'Total Faltantes',
        sub:   '$_numTiendasConFaltante tienda(s) con faltante',
        value: _fmt(_totalDiscrepancias),
        trend: hasFaltante ? 'Revisar arqueos' : 'Sin faltantes',
        trendUp: !hasFaltante,
        icon:  hasFaltante ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
        iconBg: hasFaltante ? const Color(0xFFFEF2F2) : AppColors.mintLight,
        iconColor: hasFaltante ? AppColors.error : AppColors.secondary,
        valueColor: hasFaltante ? AppColors.error : AppColors.onSurface,
      ),
      _KpiData(
        label: 'Resultado Neto',
        sub:   'Después de todos los gastos',
        value: _fmt(_netProfit),
        trend: _netProfit >= 0 ? 'Resultado positivo' : 'Resultado negativo',
        trendUp: _netProfit >= 0,
        icon:  Icons.account_balance_wallet_rounded,
        iconBg: AppColors.mintLight,
        iconColor: AppColors.secondary,
        valueColor: _netProfit >= 0 ? AppColors.secondary : AppColors.error,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final avail = c.maxWidth;
      if (avail >= 860) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (int i = 0; i < kpis.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: _KpiCard(data: kpis[i])),
            ],
          ]),
        );
      }
      if (avail >= 500) {
        return Column(children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _KpiCard(data: kpis[0])),
              const SizedBox(width: 16),
              Expanded(child: _KpiCard(data: kpis[1])),
            ]),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _KpiCard(data: kpis[2])),
              const SizedBox(width: 16),
              Expanded(child: _KpiCard(data: kpis[3])),
            ]),
          ),
        ]);
      }
      return Column(
        children: kpis
            .expand((k) => [_KpiCard(data: k), const SizedBox(height: 16)])
            .take(kpis.length * 2 - 1)
            .toList(),
      );
    });
  }

  // ── Main row: top crecimiento ──────────────────────────────────────────────
  Widget _buildMainRow() {
    if (_topCrecimiento.isEmpty) return const SizedBox.shrink();
    return _TopCrecimientoCard(top: _topCrecimiento, fmtFull: _fmtFull);
  }

  // ── Historial — solo muestra botón, carga al abrir el diálogo ───────────────
  Widget _buildHistorial() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.history_rounded, size: 18, color: AppColors.secondary),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Historial de Cierres',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.onSurface)),
          Text('Cierres de turno por tienda',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
        ])),
        FilledButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _HistorialDialog(tiendaId: _tiendaId, fmtFull: _fmtFull),
          ),
          icon: const Icon(Icons.visibility_rounded, size: 16),
          label: const Text('Ver Cierres'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );
  }
}

// ── KPI data model ─────────────────────────────────────────────────────────────
class _KpiData {
  final String   label, sub, value, trend;
  final bool?    trendUp;
  final bool     isText;
  final IconData icon;
  final Color    iconBg, iconColor, valueColor;
  const _KpiData({
    required this.label,  required this.sub,    required this.value,
    required this.trend,  this.trendUp,         this.isText = false,
    required this.icon,   required this.iconBg, required this.iconColor,
    required this.valueColor,
  });
}

// ── KPI Card ───────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final up = data.trendUp ?? true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: data.iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(data.icon, size: 15, color: data.iconColor),
        ),
        const SizedBox(height: 10),
        Text(data.label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.onSurfaceVariant, letterSpacing: 0.2)),
        const SizedBox(height: 4),
        Text(data.value,
            overflow: TextOverflow.ellipsis,
            style: data.isText
                ? GoogleFonts.inter(color: data.valueColor, fontSize: 16, fontWeight: FontWeight.w700)
                : GoogleFonts.inter(color: data.valueColor, fontSize: 24, fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
        const SizedBox(height: 3),
        Text(data.sub,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 10),
        Row(children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 13, color: up ? AppColors.secondary : AppColors.error),
          const SizedBox(width: 4),
          Expanded(child: Text(data.trend,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: up ? AppColors.secondary : AppColors.error,
                  fontSize: 11, fontWeight: FontWeight.w600))),
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
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Btn(label: 'Semanal', active: value == 'semanal', onTap: () => onChange('semanal')),
        _Btn(label: 'Mensual', active: value == 'mensual', onTap: () => onChange('mensual')),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: active ? AppColors.secondary : AppColors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

// ── Trends Card (Bar Chart) ────────────────────────────────────────────────────

// ── Top Crecimiento ───────────────────────────────────────────────────────────
class _TopCrecimientoCard extends StatelessWidget {
  final List<Map<String, dynamic>> top;
  final String Function(double) fmtFull;
  const _TopCrecimientoCard({required this.top, required this.fmtFull});

  @override
  Widget build(BuildContext context) {
    final maxTot = top.isEmpty
        ? 1.0
        : top.map((x) => (x['total_actual'] as num).toDouble()).reduce(max);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Text('Top Tiendas por Crecimiento',
              style: GoogleFonts.inter(
                  color: AppColors.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        ...top.asMap().entries.map((e) {
          final idx      = e.key;
          final t        = e.value;
          final pct      = (t['crecimiento_pct'] as num).toDouble();
          final tot      = (t['total_actual']    as num).toDouble();
          final progress = (tot / maxTot).clamp(0.0, 1.0);
          final up       = pct >= 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: idx == 0 ? AppColors.mintLight : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text('${idx + 1}',
                    style: GoogleFonts.inter(
                        color: idx == 0 ? AppColors.secondary : AppColors.onSurfaceVariant,
                        fontSize: 12, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['nombre'] as String,
                    style: GoogleFonts.inter(
                        color: AppColors.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade100,
                    color: idx == 0 ? AppColors.secondary : AppColors.secondary.withValues(alpha: 0.5),
                    minHeight: 5,
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: up ? AppColors.mintLight : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                        color: up ? AppColors.secondary : AppColors.error,
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Historial Dialog (dos columnas, verde y blanco) ───────────────────────────
class _HistorialDialog extends StatefulWidget {
  final int?                   tiendaId;
  final String Function(double) fmtFull;
  const _HistorialDialog({required this.fmtFull, this.tiendaId});
  @override
  State<_HistorialDialog> createState() => _HistorialDialogState();
}

class _HistorialDialogState extends State<_HistorialDialog> {
  static const _pageSize = 20;

  final _searchCtrl  = TextEditingController();
  final _listCtrl    = ScrollController();

  // Lista paginada
  final List<Map<String, dynamic>> _items = [];
  bool   _loadingInit = true;
  bool   _loadingMore = false;
  bool   _hasMore     = true;
  int    _offset      = 0;
  String _listError   = '';

  // Búsqueda local sobre items ya cargados
  String _query = '';

  // Detalle
  int?             _selId;
  bool             _loadingDet = false;
  String?          _detError;
  SesionHistorial? _sesion;

  @override
  void initState() {
    super.initState();
    _fetchPage();
    _listCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_listCtrl.position.pixels >= _listCtrl.position.maxScrollExtent - 60 &&
        !_loadingMore && _hasMore) {
      _fetchPage();
    }
  }

  Future<void> _fetchPage() async {
    if (_loadingMore || (!_hasMore && _offset > 0)) return;
    setState(() { _loadingMore = true; _listError = ''; });
    final r = await CajaService().getHistorialSesiones(
      estado: 'cerrada', tiendaId: widget.tiendaId,
      limit: _pageSize, offset: _offset,
    );
    if (!mounted) return;
    final newItems = r['items'] as List<Map<String, dynamic>>;
    setState(() {
      _items.addAll(newItems);
      _hasMore     = r['hasMore'] as bool;
      _offset      += newItems.length;
      _loadingInit  = false;
      _loadingMore  = false;
    });
  }

  void _seleccionar(int id) {
    setState(() { _selId = id; _loadingDet = true; _detError = null; _sesion = null; });
    _cargarDetalle(id);
  }

  Future<void> _cargarDetalle(int id) async {
    try {
      final r = await CajaService().getDetalleSesion(id);
      if (!mounted) return;
      if (r['success'] == true && r['data'] != null) {
        setState(() {
          _sesion     = SesionHistorial.fromJson(r['data'] as Map<String, dynamic>);
          _loadingDet = false;
        });
      } else {
        setState(() { _detError = 'No se pudo cargar el detalle.'; _loadingDet = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _detError = e.toString(); _loadingDet = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((s) =>
        (s['tienda_nombre']   ?? '').toString().toLowerCase().contains(q) ||
        (s['empleado_nombre'] ?? '').toString().toLowerCase().contains(q)
    ).toList();
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString().substring(0, 10);
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _fmtTime(String raw) {
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw.substring(0, min(16, raw.length));
    final local = dt.toLocal();
    final h    = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'p.m.' : 'a.m.';
    return '${h.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40, offset: const Offset(0, 20))],
        ),
        child: Column(children: [
          _buildDialogHeader(),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.history_rounded, size: 18, color: AppColors.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Historial de Cierres',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.onSurface)),
          Text(_loadingInit ? 'Cargando…' : '${_items.length} registros${_hasMore ? '+' : ''}',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ])),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade400),
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth < 580) {
        return Column(children: [
          SizedBox(height: 240, child: _buildList()),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(child: _buildDetail()),
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 300, child: _buildList()),
        VerticalDivider(width: 1, color: Colors.grey.shade200),
        Expanded(child: _buildDetail()),
      ]);
    });
  }

  Widget _buildList() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar tienda o cajero...',
            hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.secondary, width: 1.5)),
          ),
        ),
      ),
      Expanded(
        child: _loadingInit
            ? const Center(child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 2))
            : _filtered.isEmpty
                ? Center(child: Text(_query.isNotEmpty ? 'Sin resultados' : 'Sin cierres',
                    style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13)))
                : ListView.builder(
                    controller: _listCtrl,
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length + (_hasMore && _query.isEmpty ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _filtered.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: _loadingMore
                              ? const Center(child: SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary)))
                              : TextButton(
                                  onPressed: _fetchPage,
                                  child: Text('Cargar más',
                                      style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 12))),
                        );
                      }
                      return _buildListRow(_filtered[i]);
                    },
                  ),
      ),
    ]);
  }

  Widget _buildListRow(Map<String, dynamic> s) {
    final id     = s['id'] as int;
    final sel    = id == _selId;
    final diff   = s['diferencia'] != null ? double.tryParse(s['diferencia'].toString()) ?? 0.0 : 0.0;
    final ventas = s['ventas_total'] != null ? double.tryParse(s['ventas_total'].toString()) ?? 0.0 : 0.0;
    final tienda = (s['tienda_nombre']   ?? '—') as String;
    final cajero = (s['empleado_nombre'] ?? '—') as String;
    final fecha  = _fmtDate(s['fecha_apertura']);

    final Color  dc = diff == 0 ? AppColors.secondary : diff < 0 ? AppColors.error : const Color(0xFFD97706);
    final Color  db = diff == 0 ? AppColors.mintLight  : diff < 0 ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);
    final String dl = diff == 0 ? '• Exacto'
                   : diff < 0  ? '• ${widget.fmtFull(diff)}'
                   : '• +${widget.fmtFull(diff)}';

    return InkWell(
      onTap: () => _seleccionar(id),
      child: Container(
        decoration: BoxDecoration(
          color: sel ? AppColors.mintLight.withValues(alpha: 0.5) : Colors.transparent,
          border: Border(
            left:   BorderSide(color: sel ? AppColors.secondary : Colors.transparent, width: 3),
            bottom: BorderSide(color: Colors.grey.shade100),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(fecha, style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
            const Spacer(),
            Text(widget.fmtFull(ventas),
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ]),
          const SizedBox(height: 3),
          Text(tienda,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
          Text(cajero, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: db, borderRadius: BorderRadius.circular(10)),
            child: Text(dl,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: dc)),
          ),
        ]),
      ),
    );
  }

  Widget _buildDetail() {
    // Estado vacío antes de que cargue el primer item
    if (_selId == null || _loadingInit) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.mintLight, shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded, size: 32, color: AppColors.secondary),
        ),
        const SizedBox(height: 16),
        Text('Selecciona un cierre\npara ver el reporte',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13)),
      ]));
    }
    if (_loadingDet) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 2));
    }
    if (_detError != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Error al cargar',
            style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _cargarDetalle(_selId!),
          icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.secondary),
          label: const Text('Reintentar', style: TextStyle(color: AppColors.secondary)),
        ),
      ]));
    }
    // PDF inline en el panel derecho
    return PdfPreview(
      key: ValueKey(_sesion!.id),
      build: (_) => generarBytesCierrePDF(_sesion!),
      canChangeOrientation: false,
      canChangePageFormat:  false,
      canDebug:             false,
      allowPrinting:        true,
      allowSharing:         false,
      pdfFileName: 'cierre_${_sesion!.id}.pdf',
      actions: const [],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MOBILE CAJA — paleta, widgets y pantallas
// ══════════════════════════════════════════════════════════════════════════════

class _MC {
  static const bg     = Color(0xFFECFDF5);
  static const green  = Color(0xFF059669);
  static const teal   = Color(0xFF0D9488);
  static const dark   = Color(0xFF064E3B);
  static const mid    = Color(0xFF047857);
  static const light  = Color(0xFFD1FAE5);
  static const border = Color(0xFFA7F3D0);
  static const dim    = Color(0xFF6EE7B7);
}

// ── Etiqueta sección ──────────────────────────────────────────────────────────
class _MSectionLabel extends StatelessWidget {
  final String text;
  const _MSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.inter(
      color: _MC.green, fontSize: 11,
      fontWeight: FontWeight.w700, letterSpacing: 0.7),
  );
}

// ── Period row (pills) ────────────────────────────────────────────────────────
class _MPeriodRow extends StatelessWidget {
  final String value;
  final void Function(String) onChange;
  const _MPeriodRow({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    _MPBtn(label: 'Sem', active: value == 'semanal', onTap: () => onChange('semanal')),
    const SizedBox(width: 6),
    _MPBtn(label: 'Mes', active: value == 'mensual', onTap: () => onChange('mensual')),
  ]);
}

class _MPBtn extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _MPBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF0D9488)])
            : null,
        color:  active ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? Colors.transparent : _MC.dim, width: 1.5),
      ),
      child: Text(label, style: GoogleFonts.inter(
        color: active ? Colors.white : _MC.mid,
        fontSize: 12, fontWeight: FontWeight.w700)),
    ),
  );
}

// ── Store chip ────────────────────────────────────────────────────────────────
class _StoreChip extends StatelessWidget {
  final int?   tiendaId;
  final List<Map<String, dynamic>> tiendas;
  final void Function(int?) onChange;
  const _StoreChip({required this.tiendaId, required this.tiendas, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final label = tiendaId == null
        ? 'Todas las tiendas'
        : (tiendas.firstWhere(
              (t) => t['id'] == tiendaId, orElse: () => {'nombre': '?'})['nombre'] as String);
    return PopupMenuButton<int?>(
      onSelected: onChange,
      offset: const Offset(0, 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      elevation: 4,
      itemBuilder: (_) => [
        PopupMenuItem<int?>(value: null,
          child: Text('Todas las tiendas', style: GoogleFonts.inter(
              color: tiendaId == null ? _MC.green : _MC.dark, fontSize: 13,
              fontWeight: tiendaId == null ? FontWeight.w700 : FontWeight.w400))),
        ...tiendas.map((t) => PopupMenuItem<int?>(value: t['id'] as int,
          child: Text(t['nombre'] as String, style: GoogleFonts.inter(
              color: tiendaId == t['id'] ? _MC.green : _MC.dark, fontSize: 13,
              fontWeight: tiendaId == t['id'] ? FontWeight.w700 : FontWeight.w400)))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _MC.dim, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_on_rounded, size: 14, color: _MC.green),
          const SizedBox(width: 5),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: _MC.mid, fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 15, color: _MC.dim),
        ]),
      ),
    );
  }
}

// ── KPI card mobile ───────────────────────────────────────────────────────────
class _MKpiCard extends StatelessWidget {
  final IconData icon;
  final Color    iconBg, iconColor;
  final String   label, value;
  final bool     isText, valueRed;
  final String   badge;
  final bool     badgeOk;
  final List<Color> stripe;

  const _MKpiCard({
    required this.icon,     required this.iconBg,  required this.iconColor,
    required this.label,    required this.value,    this.isText = false,
    this.valueRed = false,  required this.badge,    required this.badgeOk,
    required this.stripe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _MC.border),
        boxShadow: [BoxShadow(color: _MC.green.withValues(alpha:.08), blurRadius: 8, offset: const Offset(0,2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // gradient stripe
        Container(height: 4, decoration: BoxDecoration(
          gradient: LinearGradient(colors: stripe))),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.inter(
                color: _MC.mid, fontSize: 10, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
              overflow: TextOverflow.ellipsis,
              style: isText
                  ? GoogleFonts.inter(color: _MC.dark, fontSize: 13, fontWeight: FontWeight.w800)
                  : GoogleFonts.inter(
                      color: valueRed ? const Color(0xFFB91C1C) : _MC.dark,
                      fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.3),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeOk ? _MC.light : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge, style: GoogleFonts.inter(
                  color: badgeOk ? const Color(0xFF065F46) : const Color(0xFFB91C1C),
                  fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Top tiendas compact ───────────────────────────────────────────────────────
class _MTopTiendas extends StatelessWidget {
  final List<Map<String, dynamic>> top;
  final String Function(double) fmtFull;
  const _MTopTiendas({required this.top, required this.fmtFull});

  @override
  Widget build(BuildContext context) {
    final maxTot = top.isEmpty
        ? 1.0
        : top.map((x) => (x['total_actual'] as num).toDouble()).reduce(max);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _MC.border),
        boxShadow: [BoxShadow(color: _MC.green.withValues(alpha:.08), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(
        children: top.asMap().entries.map((e) {
          final idx  = e.key;
          final t    = e.value;
          final pct  = (t['crecimiento_pct'] as num).toDouble();
          final tot  = (t['total_actual']    as num).toDouble();
          final prog = (tot / maxTot).clamp(0.0, 1.0);
          final up   = pct >= 0;
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: idx < top.length - 1
                    ? const BorderSide(color: Color(0xFFF0FDF4))
                    : BorderSide.none,
              ),
            ),
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: idx == 0 ? _MC.light : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('${idx + 1}',
                    style: GoogleFonts.inter(
                      color: idx == 0 ? _MC.green : const Color(0xFF6B7280),
                      fontSize: 11, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['nombre'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: _MC.dark, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: prog,
                    backgroundColor: _MC.light,
                    color: idx == 0 ? _MC.green : _MC.dim,
                    minHeight: 4,
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: up ? _MC.light : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      color: up ? _MC.green : const Color(0xFFB91C1C),
                      fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Mobile dashboard principal ────────────────────────────────────────────────
class _MobileCajaDashboard extends StatelessWidget {
  final String  periodo;
  final int?    tiendaId;
  final List<Map<String, dynamic>> tiendas;
  final double  totalCashFlow, totalDiscrepancias, netProfit, topStoreTotalHoy;
  final int     numTiendasConFaltante;
  final String  topStoreNombre;
  final List<Map<String, dynamic>> topCrecimiento;
  final void Function(String)  onPeriodChange;
  final void Function(int?)    onTiendaChange;
  final String Function(double) fmt, fmtFull;

  const _MobileCajaDashboard({
    required this.periodo,            required this.tiendaId,
    required this.tiendas,            required this.totalCashFlow,
    required this.totalDiscrepancias, required this.numTiendasConFaltante,
    required this.netProfit,          required this.topStoreNombre,
    required this.topStoreTotalHoy,   required this.topCrecimiento,
    required this.onPeriodChange,     required this.onTiendaChange,
    required this.fmt,                required this.fmtFull,
  });

  @override
  Widget build(BuildContext context) {
    final hasFaltante = totalDiscrepancias < 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFECFDF5), Color(0xFFCCFBF1), Color(0xFFD1FAE5)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Filtros
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              Expanded(child: _StoreChip(
                tiendaId: tiendaId, tiendas: tiendas, onChange: onTiendaChange)),
              const SizedBox(width: 8),
              _MPeriodRow(value: periodo, onChange: onPeriodChange),
            ]),
          ),

          // KPIs 2×2
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(children: [
              const _MSectionLabel('Métricas clave'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MKpiCard(
                  icon: Icons.payments_rounded, iconBg: _MC.light, iconColor: _MC.green,
                  label: 'Flujo de Caja', value: fmt(totalCashFlow),
                  badge: periodo == 'semanal' ? '↗ Semana' : '↗ Mes', badgeOk: true,
                  stripe: const [Color(0xFF059669), Color(0xFF10B981)],
                )),
                const SizedBox(width: 10),
                Expanded(child: _MKpiCard(
                  icon: Icons.workspace_premium_rounded,
                  iconBg: const Color(0xFFCCFBF1), iconColor: _MC.teal,
                  label: 'Top Tienda', value: topStoreNombre, isText: true,
                  badge: fmtFull(topStoreTotalHoy), badgeOk: true,
                  stripe: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _MKpiCard(
                  icon: hasFaltante ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  iconBg: hasFaltante ? const Color(0xFFFEF2F2) : _MC.light,
                  iconColor: hasFaltante ? const Color(0xFFB91C1C) : _MC.green,
                  label: 'Faltantes', value: fmt(totalDiscrepancias),
                  valueRed: hasFaltante,
                  badge: hasFaltante ? '$numTiendasConFaltante tienda(s)' : 'Sin faltantes',
                  badgeOk: !hasFaltante,
                  stripe: hasFaltante
                      ? const [Color(0xFFF59E0B), Color(0xFFF97316)]
                      : const [Color(0xFF059669), Color(0xFF10B981)],
                )),
                const SizedBox(width: 10),
                Expanded(child: _MKpiCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconBg: _MC.light, iconColor: _MC.green,
                  label: 'Resultado Neto', value: fmt(netProfit), valueRed: netProfit < 0,
                  badge: netProfit >= 0 ? '✓ Positivo' : '↓ Negativo', badgeOk: netProfit >= 0,
                  stripe: const [Color(0xFF059669), Color(0xFF10B981)],
                )),
              ]),
            ]),
          ),

          const SizedBox(height: 14),

          // Top crecimiento
          if (topCrecimiento.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _MSectionLabel('Top tiendas'),
                const SizedBox(height: 8),
                _MTopTiendas(top: topCrecimiento, fmtFull: fmtFull),
                const SizedBox(height: 14),
              ]),
            ),

          // Faltantes resumen
          if (hasFaltante)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _MSectionLabel('Faltantes'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _MC.border),
                    boxShadow: [BoxShadow(color: _MC.green.withValues(alpha:.08), blurRadius: 8, offset: const Offset(0,2))],
                  ),
                  child: Row(children: [
                    Container(width: 10, height: 10,
                        decoration: const BoxDecoration(
                            color: Color(0xFFF87171), shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Tiendas con faltante', style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _MC.dark)),
                      Text('$numTiendasConFaltante tienda(s)', style: GoogleFonts.inter(
                          fontSize: 10, color: _MC.mid)),
                    ])),
                    Text(fmtFull(totalDiscrepancias), style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: const Color(0xFFB91C1C))),
                  ]),
                ),
                const SizedBox(height: 14),
              ]),
            ),

          // Botón historial
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _MSectionLabel('Historial de cierres'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _MobileHistorialSheet(
                    tiendaId: tiendaId, fmtFull: fmtFull),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _MC.border),
                    boxShadow: [BoxShadow(color: _MC.green.withValues(alpha:.08), blurRadius: 8, offset: const Offset(0,2))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: _MC.light, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.history_rounded, size: 22, color: _MC.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Historial de Cierres', style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _MC.dark)),
                      Text('Reportes PDF por cierre', style: GoogleFonts.inter(
                          fontSize: 11, color: _MC.mid)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF0D9488)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.visibility_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('Ver', style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ── Bottom sheet nivel 1: lista de cierres ────────────────────────────────────
class _MobileHistorialSheet extends StatefulWidget {
  final int?                   tiendaId;
  final String Function(double) fmtFull;
  const _MobileHistorialSheet({required this.fmtFull, this.tiendaId});
  @override
  State<_MobileHistorialSheet> createState() => _MobileHistorialSheetState();
}

class _MobileHistorialSheetState extends State<_MobileHistorialSheet> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  bool   _loadingInit = true;
  bool   _loadingMore = false;
  bool   _hasMore     = true;
  int    _offset      = 0;
  String _listError   = '';
  String _query       = '';

  int?    _loadingId;

  @override
  void initState() {
    super.initState();
    _fetchPage();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 60 &&
        !_loadingMore && _hasMore) {
      _fetchPage();
    }
  }

  Future<void> _fetchPage() async {
    if (_loadingMore || (!_hasMore && _offset > 0)) return;
    setState(() { _loadingMore = true; _listError = ''; });
    final r = await CajaService().getHistorialSesiones(
      estado: 'cerrada', tiendaId: widget.tiendaId,
      limit: _pageSize, offset: _offset,
    );
    if (!mounted) return;
    final newItems = r['items'] as List<Map<String, dynamic>>;
    setState(() {
      _items.addAll(newItems);
      _hasMore     = r['hasMore'] as bool;
      _offset      += newItems.length;
      _loadingInit  = false;
      _loadingMore  = false;
    });
  }

  Future<void> _abrirCierre(Map<String, dynamic> raw) async {
    final id = raw['id'] as int;
    setState(() => _loadingId = id);
    try {
      final r = await CajaService().getDetalleSesion(id);
      if (!mounted) return;
      if (r['success'] == true && r['data'] != null) {
        final sesion = SesionHistorial.fromJson(r['data'] as Map<String, dynamic>);
        if (!mounted) return;
        // Push pantalla PDF sobre el bottom sheet
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _MobilePdfScreen(sesion: sesion),
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingId = null);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((s) =>
        (s['tienda_nombre']   ?? '').toString().toLowerCase().contains(q) ||
        (s['empleado_nombre'] ?? '').toString().toLowerCase().contains(q)
    ).toList();
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString().substring(0, min(10, raw.toString().length));
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2,'0')}/${l.month.toString().padLeft(2,'0')}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    return Container(
      height: sh * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [

        // Handle
        Container(
          width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: _MC.border, borderRadius: BorderRadius.circular(2)),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _MC.light, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.history_rounded, size: 18, color: _MC.green),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Historial de Cierres', style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 16, color: _MC.dark)),
              Text(_loadingInit ? 'Cargando…' : '${_items.length} registros${_hasMore ? '+' : ''}',
                  style: GoogleFonts.inter(fontSize: 11, color: _MC.mid)),
            ])),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: _MC.light, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close_rounded, size: 16, color: _MC.green),
              ),
            ),
          ]),
        ),

        Divider(height: 1, color: Colors.grey.shade100),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.inter(color: _MC.dark, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar tienda o cajero...',
              hintStyle: GoogleFonts.inter(color: _MC.dim, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _MC.dim),
              filled: true,
              fillColor: const Color(0xFFF0FDF4),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _MC.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _MC.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _MC.green, width: 1.5)),
            ),
          ),
        ),

        // List
        Expanded(
          child: _loadingInit
              ? const Center(child: CircularProgressIndicator(
                    color: _MC.green, strokeWidth: 2))
              : _filtered.isEmpty
                  ? Center(child: Text(_query.isNotEmpty ? 'Sin resultados' : 'Sin cierres',
                      style: GoogleFonts.inter(color: _MC.mid, fontSize: 13)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length + (_hasMore && _query.isEmpty ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _filtered.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: _loadingMore
                                ? const Center(child: SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: _MC.green)))
                                : TextButton(
                                    onPressed: _fetchPage,
                                    child: Text('Cargar más', style: GoogleFonts.inter(
                                        color: _MC.green, fontSize: 12))),
                          );
                        }
                        return _buildRow(_filtered[i]);
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _buildRow(Map<String, dynamic> s) {
    final id     = s['id'] as int;
    final diff   = s['diferencia']   != null ? double.tryParse(s['diferencia'].toString())   ?? 0.0 : 0.0;
    final ventas = s['ventas_total'] != null ? double.tryParse(s['ventas_total'].toString()) ?? 0.0 : 0.0;
    final tienda = (s['tienda_nombre']   ?? '—') as String;
    final cajero = (s['empleado_nombre'] ?? '—') as String;
    final fecha  = _fmtDate(s['fecha_apertura']);
    final isLoading = _loadingId == id;

    final Color  dc = diff == 0 ? _MC.green : diff < 0 ? const Color(0xFFB91C1C) : const Color(0xFFD97706);
    final Color  db = diff == 0 ? _MC.light  : diff < 0 ? const Color(0xFFFEE2E2) : const Color(0xFFFFF7ED);
    final String dl = diff == 0 ? 'Exacto'
                   : diff < 0  ? widget.fmtFull(diff)
                   : '+${widget.fmtFull(diff)}';

    return InkWell(
      onTap: isLoading ? null : () => _abrirCierre(s),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: const Border(bottom: BorderSide(color: Color(0xFFF0FDF4))),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fecha, style: GoogleFonts.inter(
                fontSize: 10, color: _MC.dim, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(tienda, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _MC.green)),
            Text(cajero, style: GoogleFonts.inter(fontSize: 11, color: _MC.mid)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: db, borderRadius: BorderRadius.circular(10)),
              child: Text(dl, style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: dc)),
            ),
          ])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(widget.fmtFull(ventas), style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w800, color: _MC.dark)),
            const SizedBox(height: 8),
            isLoading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _MC.green))
                : const Icon(Icons.chevron_right_rounded,
                    size: 18, color: _MC.border),
          ]),
        ]),
      ),
    );
  }
}

// ── Pantalla nivel 2: visor PDF ───────────────────────────────────────────────
class _MobilePdfScreen extends StatelessWidget {
  final SesionHistorial sesion;
  const _MobilePdfScreen({required this.sesion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade700,
      appBar: AppBar(
        backgroundColor: _MC.dark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sesion.tiendaNombre,
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
          Text('Cajero: ${sesion.empleadoNombre}',
              style: GoogleFonts.inter(
                  color: _MC.border, fontSize: 10)),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: .3)),
            ),
            child: Text('SESIÓN #${sesion.id}',
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: PdfPreview(
        key: ValueKey(sesion.id),
        build: (_) => generarBytesCierrePDF(sesion),
        canChangeOrientation: false,
        canChangePageFormat:  false,
        canDebug:             false,
        allowPrinting:        true,
        allowSharing:         false,
        pdfFileName: 'cierre_${sesion.id}.pdf',
        actions: const [],
      ),
    );
  }
}
