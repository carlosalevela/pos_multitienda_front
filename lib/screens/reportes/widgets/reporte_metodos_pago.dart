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
    final totalBase = rep.totalDia > 0 ? rep.totalDia : 0.0;

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
              final color = colorMetodo(e.key);
              final rawPct = totalBase == 0 ? 0.0 : (e.value / totalBase);
              final pct = rawPct.clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(iconMetodo(e.key), size: 13, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            labelMetodo(e.key),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${fmtNum(e.value)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            Text(
                              '${(rawPct * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
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