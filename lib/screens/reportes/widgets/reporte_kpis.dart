import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/reportes_provider.dart';
import 'reporte_utils.dart';

class ReporteKpis extends StatelessWidget {
  final ReportesProvider rep;
  const ReporteKpis({super.key, required this.rep});

  @override
  Widget build(BuildContext context) {
    final tieneDev = rep.numDevoluciones > 0;
    final impactoCaja = rep.impactoCajaDevoluciones;

    final impactoTexto = impactoCaja > 0
        ? '+\$${fmtNum(impactoCaja)}'
        : impactoCaja < 0
            ? '-\$${fmtNum(impactoCaja.abs())}'
            : '\$0';

    final netoTexto = rep.totalNeto > 0
        ? '\$${fmtNum(rep.totalNeto)}'
        : rep.totalNeto < 0
            ? '-\$${fmtNum(rep.totalNeto.abs())}'
            : '\$0';

    final impactoColor = impactoCaja > 0
        ? Colors.green.shade700
        : impactoCaja < 0
            ? kDevColor
            : Colors.blueGrey.shade600;

    final netoColor = rep.totalNeto >= 0
        ? const Color(0xFF1565C0)
        : Colors.red.shade700;

    final kpis = <KpiData>[
      KpiData(
        icon: Icons.attach_money_rounded,
        label: tieneDev ? 'Ventas brutas' : 'Total vendido',
        valor: '\$${fmtNum(rep.totalDia)}',
        color: kNetoColor,
      ),
      if (tieneDev)
        KpiData(
          icon: Icons.assignment_return_rounded,
          label: 'Impacto devoluciones',
          valor: impactoTexto,
          color: impactoColor,
        ),
      if (tieneDev)
        KpiData(
          icon: Icons.price_check_rounded,
          label: 'Total neto',
          valor: netoTexto,
          color: netoColor,
        ),
      KpiData(
        icon: Icons.receipt_long_rounded,
        label: 'Ventas',
        valor: '${rep.totalVentas}',
        color: const Color(0xFF1976D2),
      ),
      KpiData(
        icon: Icons.trending_up_rounded,
        label: 'Ticket promedio',
        valor: '\$${fmtNum(rep.ticketPromedio)}',
        color: const Color(0xFF7B1FA2),
      ),
      KpiData(
        icon: Icons.discount_rounded,
        label: 'Descuentos',
        valor: '\$${fmtNum(rep.totalDescuentos)}',
        color: const Color(0xFFE65100),
      ),
      if (rep.totalAbonos > 0)
        KpiData(
          icon: Icons.bookmark_rounded,
          label: 'Abonos',
          valor: '\$${fmtNum(rep.totalAbonos)}',
          color: const Color(0xFF00796B),
        ),
      if (rep.totalAnuladas > 0)
        KpiData(
          icon: Icons.cancel_rounded,
          label: 'Anuladas',
          valor: '${rep.totalAnuladas}',
          color: Colors.red.shade700,
        ),
      if (rep.numCambiosExactos > 0)
        KpiData(
          icon: Icons.swap_horiz_rounded,
          label: 'Cambios exactos',
          valor: '${rep.numCambiosExactos}',
          color: Colors.blueGrey.shade600,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1400
            ? (width - 30) / 4
            : width >= 1000
                ? (width - 20) / 3
                : width >= 700
                    ? (width - 10) / 2
                    : width;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kpis
              .map(
                (kpi) => SizedBox(
                  width: cardWidth,
                  child: _KpiCard(data: kpi),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}