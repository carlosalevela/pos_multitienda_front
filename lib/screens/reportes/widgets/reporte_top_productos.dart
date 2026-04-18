import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/reportes_provider.dart';
import 'reporte_utils.dart';

class ReporteTopProductos extends StatelessWidget {
  final ReportesProvider rep;
  const ReporteTopProductos({super.key, required this.rep});

  static const _colors = [
    Color(0xFF1976D2),
    Color(0xFF00897B),
    Color(0xFFE65100),
    Color(0xFF7B1FA2),
    Color(0xFF00ACC1),
  ];

  @override
  Widget build(BuildContext context) {
    final top = rep.topProductos;
    final maxSubtotal = top.isEmpty
        ? 0.0
        : top
            .map((p) => (p['subtotal'] as num?)?.toDouble() ?? 0.0)
            .reduce((a, b) => a > b ? a : b);

    return reporteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(Icons.emoji_events_outlined, 'Top productos'),
          const SizedBox(height: 12),
          if (top.isEmpty)
            emptyMsg('Sin datos')
          else
            ...top.asMap().entries.map((e) {
              final color = _colors[e.key % _colors.length];
              final nombre = e.value['nombre']?.toString() ?? 'Sin nombre';
              final subtotal = (e.value['subtotal'] as num?)?.toDouble() ?? 0.0;
              final cantidad = (e.value['cantidad'] as num?)?.toDouble() ?? 0.0;
              final progress = maxSubtotal <= 0 ? 0.0 : (subtotal / maxSubtotal).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.10)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${e.key + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${fmtNum(subtotal)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                'x${cantidad.toStringAsFixed(0)} uds',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}