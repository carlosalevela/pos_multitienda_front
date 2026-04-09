import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../core/constants.dart';

class TabMensual extends StatelessWidget {
  final ContabilidadProvider cont;
  final NumberFormat fmt;
  final int? tiendaId;
  final int anio;
  final int mes;
  final List<String> meses;
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

  double _d(Map m, String key) =>
      double.tryParse(m[key]?.toString() ?? '0') ?? 0.0;

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
              child: _contenido(data),
            ),
          ),
      ],
    );
  }

  // ── Contenido principal ────────────────────────────────────
  Widget _contenido(resumen) {
    final totalVentas   = resumen.totalVentas   as double;
    final totalGastos   = resumen.totalGastos   as double;
    final utilidadBruta = resumen.utilidadBruta as double;
    final dias = List<Map<String, dynamic>>.from(resumen.ventasPorDia);

    final maxTotal = dias.isEmpty
        ? 0.0
        : dias.map((d) => _d(d, 'total')).reduce((a, b) => a > b ? a : b);

    final mejorDia = dias.isEmpty
        ? null
        : dias.reduce((a, b) => _d(a, 'total') >= _d(b, 'total') ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kpis(totalVentas, totalGastos, utilidadBruta, dias.length),
        const SizedBox(height: 16),
        if (dias.isNotEmpty) ...[
          _tituloSeccion(Icons.bar_chart_rounded, 'Ventas por día'),
          const SizedBox(height: 12),
          _barChart(dias, maxTotal),
          const SizedBox(height: 20),
          if (mejorDia != null) ...[
            _tituloSeccion(Icons.emoji_events_rounded, 'Mejor día',
                color: Colors.amber),
            const SizedBox(height: 10),
            _mejorDiaCard(mejorDia),
            const SizedBox(height: 20),
          ],
          _tituloSeccion(Icons.table_rows_rounded, 'Detalle por día'),
          const SizedBox(height: 10),
          ...dias.map((d) => _diaCard(d, maxTotal)),
        ] else ...[
          _tituloSeccion(Icons.bar_chart_rounded, 'Ventas por día'),
          const SizedBox(height: 12),
          _sinVentas(),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Selector de mes ────────────────────────────────────────
  Widget _selectorMes() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            if (mes == 1) {
              onCambiarMes(anio - 1, 12);
            } else {
              onCambiarMes(anio, mes - 1);
            }
          },
        ),
        Expanded(child: Center(child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded, size: 18,
                color: Color(Constants.primaryColor)),
            const SizedBox(width: 8),
            Text(
              '${meses[mes - 1]} $anio',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF1A1A2E)),
            ),
          ],
        ))),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            if (mes == 12) {
              onCambiarMes(anio + 1, 1);
            } else {
              onCambiarMes(anio, mes + 1);
            }
          },
        ),
      ]),
    );
  }

  // ── Sin datos ──────────────────────────────────────────────
  Widget _sinDatos() {
    return Expanded(child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.calendar_month_rounded, size: 56,
            color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Sin datos para ${meses[mes - 1]} $anio',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 15)),
      ],
    )));
  }

  Widget _sinVentas() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Center(child: Column(children: [
        Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('Sin ventas registradas este mes',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 13)),
      ])),
    );
  }

  // ── KPIs ───────────────────────────────────────────────────
  Widget _kpis(double ventas, double gastos, double utilidad, int diasConVentas) {
    return Column(children: [
      Row(children: [
        Expanded(child: _kpi(
          Icons.trending_up_rounded, 'Total ventas',
          fmt.format(ventas),
          Colors.blue.shade700, Colors.blue.shade50,
        )),
        const SizedBox(width: 10),
        Expanded(child: _kpi(
          Icons.trending_down_rounded, 'Total gastos',
          fmt.format(gastos),
          Colors.orange.shade700, Colors.orange.shade50,
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _kpi(
          utilidad >= 0
              ? Icons.account_balance_wallet_rounded
              : Icons.warning_rounded,
          'Utilidad bruta',
          fmt.format(utilidad),
          utilidad >= 0 ? Colors.green.shade700 : Colors.red.shade700,
          utilidad >= 0 ? Colors.green.shade50  : Colors.red.shade50,
        )),
        const SizedBox(width: 10),
        Expanded(child: _kpi(
          Icons.receipt_long_rounded,
          'Días con ventas',
          '$diasConVentas días',
          Colors.purple.shade700,
          Colors.purple.shade50,
        )),
      ]),
    ]);
  }

  Widget _kpi(IconData icon, String label, String valor,
      Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 4),
        Text(valor,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ]),
    );
  }

  // ── Título sección ─────────────────────────────────────────
  Widget _tituloSeccion(IconData icon, String titulo, {Color? color}) {
    return Row(children: [
      Icon(icon, size: 18,
          color: color ?? const Color(Constants.primaryColor)),
      const SizedBox(width: 8),
      Text(titulo, style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: const Color(0xFF1A1A2E))),
    ]);
  }

  // ── Gráfico de barras por día ──────────────────────────────
  Widget _barChart(List<Map<String, dynamic>> dias, double maxTotal) {
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: dias.map((d) {
            final total    = _d(d, 'total');
            final cantidad = d['cantidad']?.toString() ?? '0';
            final dia      = d['dia']?.toString() ?? '';
            // extrae solo el número del día: "2026-04-15" → "15"
            final numDia   = dia.length >= 10 ? dia.substring(8, 10) : dia;
            final pct      = maxTotal > 0 ? total / maxTotal : 0.0;
            final isMax    = total == maxTotal && total > 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isMax)
                    Text(NumberFormat('#,##0').format(total),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: const Color(Constants.primaryColor)))
                  else
                    const SizedBox(height: 12),
                  Tooltip(
                    message:
                        'Día $numDia\nVentas: ${fmt.format(total)}\nTransacciones: $cantidad',
                    child: Container(
                      width: 22,
                      height: 130 * pct.clamp(0.04, 1.0),
                      decoration: BoxDecoration(
                        color: isMax
                            ? const Color(Constants.primaryColor)
                            : const Color(Constants.primaryColor)
                                .withOpacity(0.4),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(numDia,
                      style: GoogleFonts.poppins(
                          fontSize: 8.5, color: Colors.grey.shade500)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Mejor día ──────────────────────────────────────────────
  Widget _mejorDiaCard(Map<String, dynamic> d) {
    final dia      = d['dia']?.toString() ?? '';
    final numDia   = dia.length >= 10 ? dia.substring(8, 10) : dia;
    final total    = _d(d, 'total');
    final cantidad = d['cantidad'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.orange.shade500],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10)),
          child: const Text('🏆', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Día $numDia — ${meses[mes - 1]} $anio',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 12)),
          Text(fmt.format(total),
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22)),
          Text('$cantidad transacciones',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 11)),
        ]),
      ]),
    );
  }

  // ── Card de cada día ───────────────────────────────────────
  Widget _diaCard(Map<String, dynamic> d, double maxTotal) {
    final dia      = d['dia']?.toString() ?? '';
    final numDia   = dia.length >= 10 ? dia.substring(8, 10) : dia;
    final total    = _d(d, 'total');
    final cantidad = d['cantidad'] ?? 0;
    final pct      = maxTotal > 0 ? total / maxTotal : 0.0;
    final esMax    = total == maxTotal && total > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esMax ? Colors.amber.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: esMax ? Colors.amber.shade200 : Colors.grey.shade100),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Día $numDia',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: esMax
                      ? Colors.amber.shade700
                      : const Color(0xFF1A1A2E))),
          if (esMax) ...[
            const SizedBox(width: 6),
            const Text('🏆', style: TextStyle(fontSize: 14)),
          ],
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(total),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(Constants.primaryColor))),
            Text('$cantidad transacciones',
                style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(esMax
                ? Colors.amber.shade600
                : const Color(Constants.primaryColor).withOpacity(0.5)),
          ),
        ),
      ]),
    );
  }
}