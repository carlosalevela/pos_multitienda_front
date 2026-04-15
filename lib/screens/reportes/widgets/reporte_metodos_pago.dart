// lib/screens/reportes/widgets/reporte_metodos_pago.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/reportes_provider.dart';
import 'reporte_utils.dart';

class ReporteMetodosPago extends StatelessWidget {
  final ReportesProvider rep;
  const ReporteMetodosPago({super.key, required this.rep});

  @override
  Widget build(BuildContext context) {
    final metodos = rep.totalPorMetodo;
    return reporteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(Icons.payments_outlined, 'Por método de pago'),
          const SizedBox(height: 12),
          if (metodos.isEmpty)
            emptyMsg('Sin datos')
          else
            ...metodos.entries.map((e) {
              final pct   = rep.totalDia == 0
                  ? 0.0 : e.value / rep.totalDia;
              final color = colorMetodo(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(iconMetodo(e.key),
                          size: 13, color: color),
                      const SizedBox(width: 6),
                      Text(labelMetodo(e.key),
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text('\$${fmtNum(e.value)}',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color)),
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade400)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           pct,
                        minHeight:       6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor:
                            AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}