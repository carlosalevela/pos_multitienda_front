import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../core/constants.dart';

class TabAnual extends StatelessWidget {
  final ContabilidadProvider cont;
  final NumberFormat fmt;
  final int? tiendaId;
  final int anioSel;
  final void Function(int) onCambiarAnio;

  const TabAnual({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.anioSel,
    required this.onCambiarAnio,
  });

  double _d(Map m, String key) =>
      double.tryParse(m[key]?.toString() ?? '0') ?? 0.0;

  int _i(Map m, String key) =>
      int.tryParse(m[key]?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    if (cont.cargando && cont.resumenAnual == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = cont.resumenAnual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _selectorAnio(),
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

  Widget _contenido(Map<String, dynamic> data) {
    final totalVentas   = _d(data, 'total_ventas');
    final totalGastos   = _d(data, 'total_gastos');
    final utilidadBruta = _d(data, 'utilidad_bruta');
    final meses = List<Map<String, dynamic>>.from(data['meses'] ?? []);

    final maxVentas = meses.isEmpty
        ? 0.0
        : meses.map((m) => _d(m, 'ventas')).reduce((a, b) => a > b ? a : b);

    final mejorMes = meses.isEmpty
        ? null
        : meses.reduce((a, b) =>
            _d(a, 'ventas') >= _d(b, 'ventas') ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kpis(totalVentas, totalGastos, utilidadBruta),
        const SizedBox(height: 16),
        _tituloSeccion(Icons.bar_chart_rounded, 'Ventas mensuales'),
        const SizedBox(height: 12),
        _barChart(meses, maxVentas),
        const SizedBox(height: 20),
        if (totalVentas > 0 && mejorMes != null) ...[
          _tituloSeccion(Icons.emoji_events_rounded, 'Mejor mes',
              color: Colors.amber),
          const SizedBox(height: 10),
          _mejorMesCard(mejorMes),
          const SizedBox(height: 20),
        ],
        _tituloSeccion(Icons.table_rows_rounded, 'Detalle por mes'),
        const SizedBox(height: 10),
        ...meses.map((m) => _mesCard(m, maxVentas)),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Selector de año ────────────────────────────────────────
  Widget _selectorAnio() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onCambiarAnio(anioSel - 1),
        ),
        Expanded(
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 18, color: Color(Constants.primaryColor)),
              const SizedBox(width: 8),
              Text('Año $anioSel',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF1A1A2E))),
            ]),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => onCambiarAnio(anioSel + 1),
        ),
      ]),
    );
  }

  // ── Sin datos ──────────────────────────────────────────────
  Widget _sinDatos() {
    return Expanded(
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bar_chart_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin datos para $anioSel',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 15)),
        ]),
      ),
    );
  }

  // ── KPIs ───────────────────────────────────────────────────
  Widget _kpis(double ventas, double gastos, double utilidad) {
    return Row(children: [
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
      const SizedBox(width: 10),
      Expanded(child: _kpi(
        utilidad >= 0
            ? Icons.account_balance_wallet_rounded
            : Icons.warning_rounded,
        'Utilidad bruta',
        fmt.format(utilidad),
        utilidad >= 0 ? Colors.green.shade700 : Colors.red.shade700,
        utilidad >= 0 ? Colors.green.shade50 : Colors.red.shade50,
      )),
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
      Icon(icon,
          size: 18, color: color ?? const Color(Constants.primaryColor)),
      const SizedBox(width: 8),
      Text(titulo,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: const Color(0xFF1A1A2E))),
    ]);
  }

  // ── Gráfico de barras ──────────────────────────────────────
  Widget _barChart(List<Map<String, dynamic>> meses, double maxVentas) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: meses.map((m) {
          final ventas = _d(m, 'ventas');
          final gastos = _d(m, 'gastos');
          final nombre = m['nombre']?.toString() ?? '';
          final abrev  = nombre.length >= 3 ? nombre.substring(0, 3) : nombre;
          final pct    = maxVentas > 0 ? ventas / maxVentas : 0.0;
          final isMax  = ventas == maxVentas && ventas > 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isMax)
                    Text(NumberFormat('#,##0').format(ventas),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: const Color(Constants.primaryColor)))
                  else
                    const SizedBox(height: 12),
                  Tooltip(
                    message: ventas > 0 || gastos > 0
                        ? 'Ventas: ${fmt.format(ventas)}\nGastos: ${fmt.format(gastos)}'
                        : 'Sin datos',
                    child: Container(
                      height: 150 * pct.clamp(0.02, 1.0),
                      decoration: BoxDecoration(
                        color: isMax
                            ? const Color(Constants.primaryColor)
                            : ventas > 0
                                ? const Color(Constants.primaryColor)
                                    .withOpacity(0.4)
                                : Colors.grey.shade200,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(abrev,
                      style: GoogleFonts.poppins(
                          fontSize: 8.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Mejor mes ──────────────────────────────────────────────
  Widget _mejorMesCard(Map<String, dynamic> m) {
    final nombre = m['nombre']?.toString() ?? '';
    final ventas = _d(m, 'ventas');
    final util   = _d(m, 'utilidad');

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
          Text('$nombre $anioSel',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 12)),
          Text(fmt.format(ventas),
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22)),
          Text('Utilidad: ${fmt.format(util)}',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 11)),
        ]),
      ]),
    );
  }

  // ── Card de cada mes ───────────────────────────────────────
  Widget _mesCard(Map<String, dynamic> m, double maxVentas) {
    final nombre   = m['nombre']?.toString() ?? '';
    final ventas   = _d(m, 'ventas');
    final gastos   = _d(m, 'gastos');
    final utilidad = _d(m, 'utilidad');
    final cantidad = _i(m, 'cantidad');
    final pct      = maxVentas > 0 ? ventas / maxVentas : 0.0;
    final esMax    = ventas == maxVentas && ventas > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esMax ? Colors.amber.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: esMax ? Colors.amber.shade200 : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(nombre,
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
            Text(fmt.format(ventas),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(Constants.primaryColor))),
            Text('$cantidad ventas  •  Gastos: ${fmt.format(gastos)}',
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
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Utilidad: ${fmt.format(utilidad)}',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: utilidad >= 0
                      ? Colors.green.shade600
                      : Colors.red.shade600)),
          Text(
              ventas > 0
                  ? 'Margen: ${(utilidad / ventas * 100).toStringAsFixed(1)}%'
                  : 'Sin ventas',
              style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.grey.shade400)),
        ]),
      ]),
    );
  }
}