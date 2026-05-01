import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/reportes_provider.dart';
import '../../../providers/contabilidad_provider.dart';
import 'reporte_utils.dart';

class ReporteKpis extends StatelessWidget {
  final ReportesProvider rep;
  const ReporteKpis({super.key, required this.rep});

  @override
  Widget build(BuildContext context) {
    final totalGastos = context
        .watch<ContabilidadProvider>()
        .gastos
        .fold(0.0, (s, g) => s + g.monto);

    final tieneDev    = rep.numDevoluciones > 0;
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
        ? const Color(0xFF2E7D32)
        : impactoCaja < 0
            ? kDevColor
            : const Color(0xFF546E7A);

    final netoColor = rep.totalNeto >= 0
        ? const Color(0xFF1565C0)
        : const Color(0xFFC62828);

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
        color: const Color(0xFF6A1B9A),
      ),
      KpiData(
        icon: Icons.discount_rounded,
        label: 'Descuentos',
        valor: '\$${fmtNum(rep.totalDescuentos)}',
        color: const Color(0xFFE65100),
      ),
      if (totalGastos > 0)
        KpiData(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Gastos del día',
          valor: '-\$${fmtNum(totalGastos)}',
          color: const Color(0xFFF57C00),
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
          color: const Color(0xFFC62828),
        ),
      if (rep.numCambiosExactos > 0)
        KpiData(
          icon: Icons.swap_horiz_rounded,
          label: 'Cambios exactos',
          valor: '${rep.numCambiosExactos}',
          color: const Color(0xFF546E7A),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols  = width >= 900 ? 4 : width >= 550 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.6,
          ),
          itemCount: kpis.length,
          itemBuilder: (_, i) => _KpiCard(data: kpis[i]),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECEFF1)),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF90A4AE),
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