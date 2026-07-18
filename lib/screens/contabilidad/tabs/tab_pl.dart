import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';

import '../../../models/contabilidad_models.dart';
import '../../../providers/contabilidad_provider.dart';
import 'export_guard.dart';

enum _Periodo { semana, mes, anio, custom }

class TabPL extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;

  const TabPL({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
  });

  @override
  State<TabPL> createState() => _TabPLState();
}

class _TabPLState extends State<TabPL> {
  _Periodo _periodo   = _Periodo.mes;
  DateTime _customIni = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customFin = DateTime.now();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void didUpdateWidget(TabPL oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tiendaId != widget.tiendaId) {
      _cargar();
    }
  }

  (String, String) _rango() {
    final now = DateTime.now();
    switch (_periodo) {
      case _Periodo.semana:
        final ini = now.subtract(Duration(days: now.weekday - 1));
        return (_s(ini), _s(now));
      case _Periodo.mes:
        return (_s(DateTime(now.year, now.month, 1)), _s(now));
      case _Periodo.anio:
        return (_s(DateTime(now.year, 1, 1)), _s(now));
      case _Periodo.custom:
        return (_s(_customIni), _s(_customFin));
    }
  }

  String _s(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _cargar() {
    final (ini, fin) = _rango();
    widget.cont.cargarPL(fechaIni: ini, fechaFin: fin, tiendaId: widget.tiendaId);
  }

  String _labelPeriodo() {
    switch (_periodo) {
      case _Periodo.semana: return 'Esta semana';
      case _Periodo.mes:    return 'Este mes';
      case _Periodo.anio:   return 'Este año';
      case _Periodo.custom:
        return '${DateFormat('dd/MM/yy').format(_customIni)} – '
               '${DateFormat('dd/MM/yy').format(_customFin)}';
    }
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cont = widget.cont;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(cont),
        const SizedBox(height: 16),
        if (cont.cargandoPl)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (cont.estadoResultados == null)
          _vacio()
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kpiRow(cont.estadoResultados!, cont.puntoEquilibrio),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (ctx, constraints) {
                    if (constraints.maxWidth > 720) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 55,
                            child: _plCard(cont.estadoResultados!),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 45,
                            child: Column(children: [
                              if (cont.puntoEquilibrio != null) ...[
                                _peCard(cont.puntoEquilibrio!),
                                const SizedBox(height: 16),
                              ],
                              if (cont.vendedores.isNotEmpty) ...[
                                _vendedoresCard(cont.vendedores),
                                const SizedBox(height: 16),
                              ],
                              if (cont.topClientes.isNotEmpty)
                                _topClientesCard(cont.topClientes),
                            ]),
                          ),
                        ],
                      );
                    }
                    return Column(children: [
                      _plCard(cont.estadoResultados!),
                      if (cont.puntoEquilibrio != null) ...[
                        const SizedBox(height: 16),
                        _peCard(cont.puntoEquilibrio!),
                      ],
                      if (cont.vendedores.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _vendedoresCard(cont.vendedores),
                      ],
                      if (cont.topClientes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _topClientesCard(cont.topClientes),
                      ],
                    ]);
                  }),
                  if (cont.comparativo.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _comparativoCard(cont),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Header: chips de período + botón exportar ─────────

  Widget _buildHeader(ContabilidadProvider cont) {
    final (ini, fin) = _rango();
    return Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('Esta semana', _Periodo.semana),
            const SizedBox(width: 8),
            _chip('Este mes',    _Periodo.mes),
            const SizedBox(width: 8),
            _chip('Este año',    _Periodo.anio),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _elegirCustom,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _periodo == _Periodo.custom
                      ? AppColors.secondary
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.date_range_rounded,
                      size: 14,
                      color: _periodo == _Periodo.custom
                          ? Colors.white
                          : Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(
                    _periodo == _Periodo.custom ? _labelPeriodo() : 'Personalizado',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _periodo == _Periodo.custom
                            ? Colors.white
                            : Colors.grey.shade700),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      ElevatedButton.icon(
        onPressed: cont.exportando
            ? null
            : () async {
                final ok = await verificarReporteAntesDe(
                  context, tiendaId: widget.tiendaId);
                if (!ok || !mounted) return;
                await cont.exportarExcel(
                  tipo:     'estado-resultados',
                  fechaIni: ini,
                  fechaFin: fin,
                  tiendaId: widget.tiendaId,
                );
              },
        icon: cont.exportando
            ? const SizedBox(
                width: 15, height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.download_rounded, size: 16),
        label: Text('Exportar Reporte',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.onSurface,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    ]);
  }

  Widget _chip(String label, _Periodo p) {
    final sel = _periodo == p;
    return GestureDetector(
      onTap: () {
        setState(() => _periodo = p);
        _cargar();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.secondary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }

  // ── 4 KPI cards (estilo plantilla) ────────────────────

  Widget _kpiRow(EstadoResultados er, PuntoEquilibrio? pe) {
    final util      = er.utilidadOperativa;
    final alcanzado = pe?.alcanzado ?? false;
    final egresos   = er.costoVentas + er.totalGastos;
    final pctEgreso = er.ingresosNetos > 0
        ? egresos / er.ingresosNetos * 100
        : 0.0;

    return Row(children: [
      Expanded(child: _kpiCard(
        label:    'Ganancia Neta',
        value:    '\$${widget.fmt.format(util.abs())}',
        icon:     Icons.payments_rounded,
        iconColor: util >= 0 ? AppColors.secondary : Colors.red.shade700,
        subText:  util >= 0
            ? '+${er.utilidadOperativaPct.toStringAsFixed(1)}% margen operativo'
            : 'Pérdida operativa',
        subColor: util >= 0 ? AppColors.secondary : Colors.red.shade600,
        subIcon:  util >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        label:       'Punto de Equilibrio',
        value:       alcanzado ? 'Superado' : 'En progreso',
        icon:        Icons.balance_rounded,
        iconColor:   alcanzado ? AppColors.secondary : Colors.orange.shade700,
        subText:     pe != null
            ? 'Margen de seguridad: ${pe.margenContribucionPct.toStringAsFixed(1)}%'
            : '—',
        subColor:    alcanzado ? AppColors.secondary : Colors.orange.shade700,
        subIcon:     alcanzado ? Icons.check_circle_rounded : Icons.schedule_rounded,
        leftBorder:  alcanzado ? AppColors.secondary : null,
        isTextValue: true,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        label:    'Ingresos',
        value:    '\$${widget.fmt.format(er.ingresosNetos)}',
        icon:     Icons.add_business_rounded,
        iconColor: AppColors.secondary,
        subText:  '${er.numVentas} ventas registradas',
        subColor: Colors.grey.shade500,
        subIcon:  null,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        label:    'Egresos',
        value:    '\$${widget.fmt.format(egresos)}',
        icon:     Icons.receipt_long_rounded,
        iconColor: Colors.red.shade600,
        subText:  '+${pctEgreso.toStringAsFixed(1)}% en costos operativos',
        subColor: Colors.red.shade500,
        subIcon:  Icons.trending_up_rounded,
      )),
    ]);
  }

  Widget _kpiCard({
    required String   label,
    required String   value,
    required IconData icon,
    required Color    iconColor,
    required String   subText,
    required Color    subColor,
    IconData?         subIcon,
    Color?            leftBorder,
    bool              isTextValue = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leftBorder != null)
              Container(width: 4, color: leftBorder),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.3)),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.inter(
              fontSize: isTextValue ? 22 : 20,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface),
        ),
        const SizedBox(height: 8),
        Row(children: [
          if (subIcon != null) ...[
            Icon(subIcon, size: 14, color: subColor),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(subText,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: subColor,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ]),      // cierra Row subIcon/subText
      ]),        // cierra Column
    ),           // cierra Padding
  ),             // cierra Expanded
],               // cierra Row children
),               // cierra Row
),               // cierra IntrinsicHeight
);               // cierra Container
  }

  // ── Estado de Resultados ──────────────────────────────

  Widget _plCard(EstadoResultados er) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _seccionTitulo('Estado de Resultados', Icons.receipt_long_rounded, AppColors.secondary),
        const SizedBox(height: 16),

        _grupo('INGRESOS', AppColors.secondary),
        _fila('Ventas brutas',    er.ventasBrutas,          positivo: true),
        _fila('(-) Descuentos',  -er.menosDescuentos),
        _fila('(-) Devoluciones',-er.menosDevoluciones),
        _filaTotal('= Ingresos netos', er.ingresosNetos,    positivo: true),
        _fila('Impuestos cobrados', er.impuestosCobrados,   muted: true, positivo: true),
        const SizedBox(height: 12),

        _grupo('COSTO DE VENTAS', Colors.orange.shade700),
        _fila('Costo de ventas (COGS)', -er.costoVentas),
        _filaTotal('= Margen bruto', er.margenBruto,
            extra: '${er.margenBrutoPct.toStringAsFixed(1)}%',
            positivo: er.margenBruto >= 0),
        const SizedBox(height: 12),

        _grupo('GASTOS OPERATIVOS', Colors.purple.shade600),
        ...er.gastosDetalle.map((g) => _fila(
          '  ${_capFirst(g['categoria']?.toString() ?? '')}',
          -(g['total'] as num).toDouble(),
        )),
        _filaTotal('= Total gastos', -er.totalGastos),
        const SizedBox(height: 12),

        if (er.perdidasBrutas > 0) ...[
          _grupo('AVERÍAS / DAÑOS', Colors.red.shade600),
          _fila('Pérdidas brutas',      -er.perdidasBrutas),
          _fila('(+) Valor recuperado',  er.valorRecuperado, positivo: true),
          _filaTotal('= Pérdida neta',  -er.perdidaNeta),
          const SizedBox(height: 12),
        ],

        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text('UTILIDAD OPERATIVA',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.onSurface)),
          ),
          Text(
            '\$${widget.fmt.format(er.utilidadOperativa.abs())}',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: er.utilidadOperativa >= 0
                    ? AppColors.secondary
                    : Colors.red.shade600),
          ),
        ]),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Margen: ${er.utilidadOperativaPct.toStringAsFixed(2)}%  •  '
            '${er.numVentas} ventas  •  ${er.numDevoluciones} devoluciones',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
          ),
        ),
      ]),
    );
  }

  Widget _grupo(String label, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.8)),
    ),
  );

  Widget _fila(String label, double valor,
      {bool positivo = false, bool muted = false}) {
    final color = muted
        ? Colors.grey.shade500
        : valor >= 0
            ? (positivo ? Colors.green.shade700 : Colors.grey.shade700)
            : Colors.red.shade600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey.shade700))),
        Text(
          '${valor < 0 ? '-' : ''}\$${widget.fmt.format(valor.abs())}',
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w500, color: color),
        ),
      ]),
    );
  }

  Widget _filaTotal(String label, double valor,
      {bool positivo = false, String? extra}) {
    final color = positivo
        ? Colors.green.shade700
        : valor < 0
            ? Colors.red.shade600
            : Colors.grey.shade800;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface))),
        if (extra != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: (positivo ? Colors.green : Colors.orange).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(extra,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: positivo
                        ? Colors.green.shade700
                        : Colors.orange.shade700)),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          '${valor < 0 ? '-' : ''}\$${widget.fmt.format(valor.abs())}',
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ]),
    );
  }

  // ── Punto de Equilibrio ───────────────────────────────

  Widget _peCard(PuntoEquilibrio pe) {
    final alcanzado = pe.alcanzado;
    final peColor   = alcanzado ? AppColors.secondary : Colors.orange.shade700;
    final progreso  = pe.puntoEquilibrioIngresos != null && pe.ingresosNetos > 0
        ? (pe.ingresosNetos / pe.puntoEquilibrioIngresos!).clamp(0.0, 1.5)
        : 0.0;

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _seccionTitulo('Punto de Equilibrio',
            Icons.show_chart_rounded, Colors.teal.shade600),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: peColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: peColor.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              alcanzado ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              size: 14, color: peColor,
            ),
            const SizedBox(width: 6),
            Text(
              alcanzado ? 'Punto de equilibrio alcanzado' : 'Por debajo del punto de equilibrio',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: peColor),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        if (pe.puntoEquilibrioIngresos != null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Ingresos actuales',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
            Text('${(progreso * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.bold, color: peColor)),
          ]),
          const SizedBox(height: 6),
          Stack(children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progreso.clamp(0.0, 1.0),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: peColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('\$0',
                style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade400)),
            Text('PE: \$${widget.fmt.format(pe.puntoEquilibrioIngresos!)}',
                style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 14),
        ],

        Wrap(spacing: 12, runSpacing: 8, children: [
          _peKpi('Gastos fijos',     pe.gastosFijos,           const Color(0xFF6366F1)),
          _peKpi('Gastos variables', pe.gastosVariables,       Colors.orange.shade600),
          _peKpi('MC%', null,        Colors.teal.shade600,
              label2: '${pe.margenContribucionPct.toStringAsFixed(2)}%'),
          if (pe.excedenteDeficit != null)
            _peKpi(
              pe.excedenteDeficit! >= 0 ? 'Excedente' : 'Déficit',
              pe.excedenteDeficit!.abs(),
              pe.excedenteDeficit! >= 0 ? AppColors.secondary : Colors.red.shade600,
            ),
        ]),
      ]),
    );
  }

  Widget _peKpi(String label, double? valor, Color color, {String? label2}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
        Text(
          label2 ?? '\$${widget.fmt.format(valor!)}',
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ]),
    );
  }

  // ── Top Vendedores ────────────────────────────────────

  Widget _vendedoresCard(List<VentaEmpleado> lista) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _seccionTitulo('Top Vendedores',
            Icons.emoji_events_rounded, Colors.amber.shade700),
        const SizedBox(height: 12),
        ...lista.take(5).toList().asMap().entries.map((e) {
          final i   = e.key;
          final emp = e.value;
          final badgeColors = [
            Colors.amber.shade600,
            Colors.grey.shade500,
            const Color(0xFFCD7F32),
          ];
          final badgeColor = i < 3 ? badgeColors[i] : Colors.grey.shade400;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emp.nombre,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                  Text('${emp.numVentas} ventas  •  '
                      'promedio \$${widget.fmt.format(emp.promedioVenta)}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ),
              Text(
                '\$${widget.fmt.format(emp.totalVentas)}',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Top Clientes ──────────────────────────────────────

  Widget _topClientesCard(List<TopCliente> lista) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _seccionTitulo('Top Clientes', Icons.star_rounded,
            const Color(0xFF7C3AED)),
        const SizedBox(height: 12),
        ...lista.take(5).toList().asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          final iniciales = c.nombre.split(' ')
              .where((p) => p.isNotEmpty).take(2)
              .map((p) => p[0].toUpperCase()).join();
          const avatarPalette = [
            Color(0xFF01696F), Color(0xFF5B4CF5), Color(0xFFD97706),
            Color(0xFF059669), Color(0xFFDB2777), Color(0xFF0284C7),
          ];
          final avatarColor = avatarPalette[c.clienteId % avatarPalette.length];
          final tierColor = c.tierColorHex != null
              ? Color(int.parse(c.tierColorHex!.replaceFirst('#', '0xFF')))
              : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: avatarColor)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(iniciales,
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: avatarColor)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.nombre,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                  if (c.tierNombre != null && tierColor != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, size: 9, color: tierColor),
                      const SizedBox(width: 2),
                      Text(c.tierNombre!,
                          style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w600,
                              color: tierColor)),
                    ]),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$${widget.fmt.format(c.totalPeriodo)}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: AppColors.secondary)),
                Text('${c.numCompras} compra${c.numCompras != 1 ? "s" : ""}',
                    style: GoogleFonts.inter(
                        fontSize: 9, color: Colors.grey.shade500)),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Comparativo de Tiendas (rediseñado) ───────────────

  Widget _comparativoCard(ContabilidadProvider cont) {
    final tiendas = cont.comparativo;
    final maxIng  = tiendas.isNotEmpty
        ? tiendas.map((t) => t.ingresosNetos).reduce((a, b) => a > b ? a : b)
        : 1.0;

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Encabezado ─────────────────────────────────
        Row(children: [
          _seccionTitulo('Ventas por Sucursal',
              Icons.store_mall_directory_rounded, Colors.indigo.shade600),
          const Spacer(),
          Text('Desglose completo ↓',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade400)),
        ]),
        const SizedBox(height: 16),

        // ── Barras de progreso por tienda ───────────────
        ...tiendas.map((t) {
          final pct = maxIng > 0
              ? (t.ingresosNetos / maxIng).clamp(0.0, 1.0)
              : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(t.tiendaNombre,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface)),
                ),
                Text('\$${widget.fmt.format(t.ingresosNetos)}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey.shade600)),
              ]),
              const SizedBox(height: 6),
              Stack(children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ]),
            ]),
          );
        }),

        const Divider(height: 28),

        // ── Título tabla ────────────────────────────────
        Text('Desglose Financiero por Sucursal',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface)),
        const SizedBox(height: 12),

        // ── Cabecera tabla ──────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: _th('Sucursal')),
            Expanded(flex: 2, child: _th('Ventas Brutas', right: true)),
            Expanded(flex: 2, child: _th('Costos Op.',    right: true)),
            Expanded(flex: 2, child: _th('Ganancia Final',right: true)),
            Expanded(flex: 2, child: _th('Estado')),
          ]),
        ),

        // ── Filas de tiendas ────────────────────────────
        ...tiendas.map((t) {
          final status = _tiendaStatus(t);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(children: [
              Expanded(flex: 3, child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: status.$2,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.tiendaNombre,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface)),
                ),
              ])),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(t.ventasBrutas)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 12),
              )),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(t.gastos + t.costoVentas)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 12),
              )),
              Expanded(flex: 2, child: Text(
                '${t.utilidadOperativa >= 0 ? '+' : '-'}'
                '\$${widget.fmt.format(t.utilidadOperativa.abs())}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: t.utilidadOperativa >= 0 ? AppColors.secondary : Colors.red.shade600),
              )),
              Expanded(flex: 2, child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.$1,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: status.$2)),
                ),
              )),
            ]),
          );
        }),

        // ── Fila totales ────────────────────────────────
        if (cont.comparativoTotales != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(flex: 3, child: Text('TOTAL',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(cont.comparativoTotales!['ingresos_netos'] ?? 0)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              )),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(cont.comparativoTotales!['gastos'] ?? 0)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              )),
              Expanded(flex: 2, child: Text(
                '\$${widget.fmt.format(cont.comparativoTotales!['utilidad_operativa'] ?? 0)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary),
              )),
              const Expanded(flex: 2, child: SizedBox()),
            ]),
          ),
        ],
      ]),
    );
  }

  (String, Color) _tiendaStatus(TiendaComparativo t) {
    if (t.utilidadOperativa > 0 && t.margenBrutoPct > 20) {
      return ('Optimizado', AppColors.secondary);
    } else if (t.utilidadOperativa > 0) {
      return ('Estable', Colors.grey.shade600);
    } else {
      return ('Revisión', const Color(0xFFBA1A1A));
    }
  }

  Widget _th(String label, {bool right = false}) => Text(
    label,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500),
  );

  // ── Vacío ─────────────────────────────────────────────

  Widget _vacio() {
    return Expanded(
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin datos para el período',
              style: GoogleFonts.inter(
                  color: Colors.grey.shade400, fontSize: 15)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cargar,
            child: Text('Reintentar',
                style: GoogleFonts.inter(
                    color: AppColors.secondary, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
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

  Widget _seccionTitulo(String label, IconData icon, Color color) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.onSurface)),
    ],
  );

  String _capFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Diálogo de rango personalizado ────────────────────

  Future<void> _elegirCustom() async {
    DateTime? ini = _customIni;
    DateTime? fin = _customFin;
    bool selIni   = true;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: StatefulBuilder(
          builder: (ctx, setL) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.date_range_rounded, color: AppColors.secondary, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Rango personalizado',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: Colors.grey.shade400),
                  onPressed: () => Navigator.pop(ctx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _fechaBox(
                  label:  'Desde',
                  valor:  ini != null
                      ? DateFormat('dd/MM/yyyy').format(ini!)
                      : 'Selecciona',
                  activo: selIni,
                  onTap:  () => setL(() => selIni = true),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.grey.shade400),
                ),
                Expanded(child: _fechaBox(
                  label:  'Hasta',
                  valor:  fin != null
                      ? DateFormat('dd/MM/yyyy').format(fin!)
                      : 'Selecciona',
                  activo: !selIni,
                  onTap:  () => setL(() => selIni = false),
                )),
              ]),
              const SizedBox(height: 8),
              Text(
                selIni ? '👆 Selecciona inicio' : '👆 Selecciona fin',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 270,
                child: CalendarDatePicker(
                  initialDate: selIni
                      ? (ini ?? DateTime.now())
                      : (fin ?? ini ?? DateTime.now()),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  onDateChanged: (d) {
                    setL(() {
                      if (selIni) {
                        ini = d;
                        if (fin != null && fin!.isBefore(d)) fin = null;
                        selIni = false;
                      } else {
                        if (ini != null && d.isBefore(ini!)) {
                          ini = d; fin = null;
                        } else {
                          fin = d;
                        }
                      }
                    });
                  },
                ),
              ),
              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar',
                      style: GoogleFonts.inter(color: Colors.grey.shade600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: ini != null && fin != null
                      ? () {
                          setState(() {
                            _customIni = ini!;
                            _customFin = fin!;
                            _periodo   = _Periodo.custom;
                          });
                          Navigator.pop(ctx);
                          _cargar();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Aplicar',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _fechaBox({
    required String      label,
    required String      valor,
    required bool        activo,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: activo ? AppColors.secondary.withValues(alpha: 0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? AppColors.secondary : Colors.grey.shade200,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: activo ? AppColors.secondary : Colors.grey.shade500)),
            Text(valor,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: activo ? AppColors.secondary : AppColors.onSurface)),
          ]),
        ),
      );
}
