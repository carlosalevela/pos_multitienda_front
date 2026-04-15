// lib/screens/reportes/widgets/reporte_kpis.dart

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
    final kpis = [
      KpiData(
          icon:  Icons.attach_money_rounded,
          label: tieneDev ? 'Ventas brutas' : 'Total vendido',
          valor: '\$${fmtNum(rep.totalDia)}',
          color: kNetoColor),
      if (tieneDev) ...[
        KpiData(
            icon:  Icons.assignment_return_rounded,
            label: 'Devoluciones',
            valor: '-\$${fmtNum(rep.totalDevoluciones)}',
            color: kDevColor),
        KpiData(
            icon:  Icons.price_check_rounded,
            label: 'Total neto',
            valor: '\$${fmtNum(rep.totalNeto)}',
            color: const Color(0xFF1565C0)),
      ],
      KpiData(
          icon:  Icons.receipt_long_rounded,
          label: 'Ventas',
          valor: '${rep.totalVentas}',
          color: const Color(0xFF1976D2)),
      KpiData(
          icon:  Icons.trending_up_rounded,
          label: 'Ticket promedio',
          valor: '\$${fmtNum(rep.ticketPromedio)}',
          color: const Color(0xFF7B1FA2)),
      KpiData(
          icon:  Icons.discount_rounded,
          label: 'Descuentos',
          valor: '\$${fmtNum(rep.totalDescuentos)}',
          color: const Color(0xFFE65100)),
      if (rep.totalAbonos > 0)
        KpiData(
            icon:  Icons.bookmark_rounded,
            label: 'Abonos',
            valor: '\$${fmtNum(rep.totalAbonos)}',
            color: const Color(0xFF00796B)),
      if (rep.totalAnuladas > 0)
        KpiData(
            icon:  Icons.cancel_rounded,
            label: 'Anuladas',
            valor: '${rep.totalAnuladas}',
            color: Colors.red.shade700),
    ];

    return Row(
      children: kpis.asMap().entries.map((e) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(
              right: e.key < kpis.length - 1 ? 10 : 0),
          child: _KpiCard(data: e.value),
        ),
      )).toList(),
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
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
            left: BorderSide(color: data.color, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: data.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(data.icon, color: data.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [
              Text(data.valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kDark)),
              const SizedBox(height: 2),
              Text(data.label,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500)),
            ],
          ),
        ),
      ]),
    );
  }
}