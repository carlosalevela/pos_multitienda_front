// lib/screens/reportes/widgets/reporte_top_productos.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/reportes_provider.dart';
import 'reporte_utils.dart';

class ReporteTopProductos extends StatelessWidget {
  final ReportesProvider rep;
  const ReporteTopProductos({super.key, required this.rep});

  static const _colors = [
    Color(0xFF1976D2), Color(0xFF00897B),
    Color(0xFFE65100), Color(0xFF7B1FA2),
    Color(0xFF00ACC1),
  ];

  @override
  Widget build(BuildContext context) {
    final top = rep.topProductos;
    return reporteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
              Icons.emoji_events_outlined, 'Top productos'),
          const SizedBox(height: 12),
          if (top.isEmpty)
            emptyMsg('Sin datos')
          else
            ...top.asMap().entries.map((e) {
              final color = _colors[e.key % _colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${e.key + 1}',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value['nombre'],
                    style: GoogleFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${fmtNum(e.value['subtotal'])}',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color)),
                      Text(
                        'x${(e.value['cantidad'] as double).toStringAsFixed(0)} uds',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade400)),
                    ],
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }
}