import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../models/contabilidad_models.dart';
import '../../../services/contabilidad_service.dart';

enum _Periodo { semana, mes, anio, custom }

class TabComparativo extends StatefulWidget {
  final NumberFormat fmt;

  const TabComparativo({super.key, required this.fmt});

  @override
  State<TabComparativo> createState() => _TabComparativoState();
}

class _TabComparativoState extends State<TabComparativo> {
  _Periodo _periodo   = _Periodo.mes;
  DateTime _customIni = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customFin = DateTime.now();

  List<TiendaComparativo> _tiendas  = [];
  Map<String, dynamic>?   _totales;
  bool                    _cargando = false;

  final _svc = ContabilidadService();

  // ── Lifecycle ──────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ── Helpers ────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (String, String) _rango() {
    final now = DateTime.now();
    switch (_periodo) {
      case _Periodo.semana:
        final lunes = now.subtract(Duration(days: now.weekday - 1));
        return (_fmtDate(lunes), _fmtDate(now));
      case _Periodo.mes:
        return (_fmtDate(DateTime(now.year, now.month, 1)), _fmtDate(now));
      case _Periodo.anio:
        return (_fmtDate(DateTime(now.year, 1, 1)), _fmtDate(now));
      case _Periodo.custom:
        return (_fmtDate(_customIni), _fmtDate(_customFin));
    }
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final (ini, fin) = _rango();
    final data = await _svc.getComparativoTiendas(fechaIni: ini, fechaFin: fin);
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _tiendas  = (data['tiendas'] as List<dynamic>? ?? [])
            .map((e) => TiendaComparativo.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.ingresosNetos.compareTo(a.ingresosNetos));
        _totales  = data['totales'] as Map<String, dynamic>?;
        _cargando = false;
      });
    } else {
      setState(() => _cargando = false);
    }
  }

  Future<void> _elegirCustom() async {
    final rango = await showDateRangePicker(
      context:          context,
      firstDate:        DateTime(2020),
      lastDate:         DateTime.now(),
      initialDateRange: DateTimeRange(start: _customIni, end: _customFin),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.secondary),
        ),
        child: child!,
      ),
    );
    if (rango == null) return;
    setState(() {
      _customIni = rango.start;
      _customFin = rango.end;
      _periodo   = _Periodo.custom;
    });
    _cargar();
  }

  (String, Color) _status(TiendaComparativo t) {
    if (t.utilidadOperativa > 0 && t.margenBrutoPct > 20) {
      return ('Optimizado', AppColors.secondary);
    } else if (t.utilidadOperativa > 0) {
      return ('Estable', Colors.grey.shade600);
    } else {
      return ('Revisión', const Color(0xFFBA1A1A));
    }
  }

  Color _colorTienda(int index) {
    const palette = [
      AppColors.secondary,
      Color(0xFF5B4CF5),
      Color(0xFFD97706),
      Color(0xFF0284C7),
      Color(0xFFDB2777),
      Color(0xFF059669),
    ];
    return palette[index % palette.length];
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 16),
        if (_cargando)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_tiendas.isEmpty)
          _sinDatos()
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kpiTotales(),
                  const SizedBox(height: 16),
                  _barChart(),
                  const SizedBox(height: 16),
                  _tabla(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.compare_arrows_rounded,
              color: AppColors.secondary, size: 20),
          const SizedBox(width: 8),
          Text('Comparativo de Tiendas',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.onSurface)),
          if (_tiendas.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_tiendas.length} tiendas',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary)),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('Semana', _Periodo.semana),
            const SizedBox(width: 6),
            _chip('Mes',    _Periodo.mes),
            const SizedBox(width: 6),
            _chip('Año',    _Periodo.anio),
            const SizedBox(width: 6),
            _chipCustom(),
          ]),
        ),
      ],
    );
  }

  Widget _chip(String label, _Periodo p) {
    final sel = _periodo == p;
    return GestureDetector(
      onTap: () {
        if (_periodo == p) return;
        setState(() => _periodo = p);
        _cargar();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.secondary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _chipCustom() {
    final sel = _periodo == _Periodo.custom;
    final label = sel
        ? '${_customIni.day}/${_customIni.month} – ${_customFin.day}/${_customFin.month}'
        : 'Rango';
    return GestureDetector(
      onTap: _elegirCustom,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.secondary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.date_range_rounded,
              size: 12, color: sel ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : Colors.grey.shade600)),
        ]),
      ),
    );
  }

  // ── KPIs totales ───────────────────────────────────────

  Widget _kpiTotales() {
    if (_totales == null) return const SizedBox.shrink();
    final ventas   = (_totales!['ventas_brutas']      ?? 0).toDouble();
    final ingresos = (_totales!['ingresos_netos']     ?? 0).toDouble();
    final gastos   = (_totales!['gastos']             ?? 0).toDouble();
    final utilidad = (_totales!['utilidad_operativa'] ?? 0).toDouble();

    return Row(children: [
      Expanded(child: _kpi('Ventas totales', ventas,
          Icons.trending_up_rounded, Colors.blue.shade700, Colors.blue.shade50)),
      const SizedBox(width: 10),
      Expanded(child: _kpi('Ingresos netos', ingresos,
          Icons.attach_money_rounded, AppColors.secondary, AppColors.mintLight)),
      const SizedBox(width: 10),
      Expanded(child: _kpi('Total gastos', gastos,
          Icons.receipt_long_rounded, Colors.orange.shade700, Colors.orange.shade50)),
      const SizedBox(width: 10),
      Expanded(child: _kpi('Utilidad', utilidad,
          utilidad >= 0 ? Icons.account_balance_wallet_rounded : Icons.warning_rounded,
          utilidad >= 0 ? Colors.green.shade700 : Colors.red.shade700,
          utilidad >= 0 ? Colors.green.shade50  : Colors.red.shade50)),
    ]);
  }

  Widget _kpi(String label, double valor, IconData icon,
      Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 4),
        Text('\$${widget.fmt.format(valor)}',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ]),
    );
  }

  // ── Gráfico de barras por tienda ───────────────────────

  Widget _barChart() {
    final maxIngresos = _tiendas
        .map((t) => t.ingresosNetos)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ingresos netos por sucursal',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.onSurface)),
        const SizedBox(height: 16),
        ..._tiendas.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;
          final pct = maxIngresos > 0
              ? (t.ingresosNetos / maxIngresos).clamp(0.0, 1.0)
              : 0.0;
          final color = _colorTienda(i);
          final isLider = i == 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              // Posición
              SizedBox(
                width: 22,
                child: Text('${i + 1}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLider
                            ? Colors.amber.shade700
                            : AppColors.onSurfaceVariant)),
              ),
              // Nombre
              SizedBox(
                width: 110,
                child: Text(t.tiendaNombre,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isLider ? FontWeight.bold : FontWeight.w500,
                        color: AppColors.onSurface)),
              ),
              const SizedBox(width: 10),
              // Barra
              Expanded(
                child: Stack(children: [
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isLider ? 1.0 : 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child: pct > 0.3
                          ? Text('\$${widget.fmt.format(t.ingresosNetos)}',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white))
                          : null,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              // Valor (si la barra es muy corta para mostrar texto dentro)
              if (pct <= 0.3)
                SizedBox(
                  width: 80,
                  child: Text('\$${widget.fmt.format(t.ingresosNetos)}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Tabla comparativa ──────────────────────────────────

  Widget _tabla() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Text('Desglose financiero por sucursal',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.onSurface)),
        ),

        // Cabecera
        Container(
          color: AppColors.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(children: [
            Expanded(flex: 3, child: _th('Sucursal')),
            Expanded(flex: 2, child: _th('Ventas', right: true)),
            Expanded(flex: 2, child: _th('Ingresos netos', right: true)),
            Expanded(flex: 2, child: _th('Gastos', right: true)),
            Expanded(flex: 2, child: _th('Utilidad', right: true)),
            Expanded(flex: 2, child: _th('Margen', right: true)),
            Expanded(flex: 2, child: _th('Estado')),
          ]),
        ),

        // Filas de tiendas
        ..._tiendas.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;
          final st = _status(t);
          final color = _colorTienda(i);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(children: [
              // Nombre con dot de color
              Expanded(flex: 3, child: Row(children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.tiendaNombre,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface)),
                ),
              ])),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(t.ventasBrutas)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurface),
              )),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(t.ingresosNetos)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurface),
              )),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(t.gastos)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.orange.shade700),
              )),
              Expanded(flex: 2, child: Text(
                '${t.utilidadOperativa >= 0 ? '+' : ''}\$${widget.fmt.format(t.utilidadOperativa)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: t.utilidadOperativa >= 0
                        ? AppColors.secondary
                        : Colors.red.shade600),
              )),
              Expanded(flex: 2, child: Text(
                '${t.margenBrutoPct.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.margenBrutoPct > 20
                        ? AppColors.secondary
                        : Colors.grey.shade600),
              )),
              Expanded(flex: 2, child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: st.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(st.$1,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: st.$2)),
                ),
              )),
            ]),
          );
        }),

        // Fila de totales
        if (_totales != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              Expanded(flex: 3, child: Text('TOTAL',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: AppColors.onSurface))),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(_totales!['ventas_brutas'] ?? 0)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: AppColors.onSurface),
              )),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(_totales!['ingresos_netos'] ?? 0)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: AppColors.onSurface),
              )),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(_totales!['gastos'] ?? 0)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700),
              )),
              Expanded(flex: 2, child: () {
                final u = (_totales!['utilidad_operativa'] ?? 0).toDouble();
                return Text(
                  '${u >= 0 ? '+' : ''}\$${widget.fmt.format(u)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: u >= 0 ? AppColors.secondary : Colors.red.shade600),
                );
              }()),
              const Expanded(flex: 2, child: SizedBox()),
              const Expanded(flex: 2, child: SizedBox()),
            ]),
          ),
      ]),
    );
  }

  // ── Empty state ────────────────────────────────────────

  Widget _sinDatos() {
    return Expanded(
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.store_mall_directory_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin datos en este período',
              style: GoogleFonts.inter(
                  color: Colors.grey.shade500, fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Registra ventas para comparar\nel rendimiento entre sucursales.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.grey.shade400, fontSize: 12)),
        ]),
      ),
    );
  }

  // ── Micro widgets ──────────────────────────────────────

  Widget _th(String label, {bool right = false}) => Text(
    label,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500),
  );
}
