// lib/screens/reportes/widgets/reporte_devoluciones_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/reportes_provider.dart';
import 'reporte_utils.dart';

class ReporteDevolucionesCard extends StatelessWidget {
  final ReportesProvider rep;
  const ReporteDevolucionesCard({super.key, required this.rep});

  @override
  Widget build(BuildContext context) {
    final devProductos = rep.productosDevueltos;
    return reporteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            sectionTitle(
                Icons.assignment_return_rounded, 'Devoluciones'),
            const Spacer(),
            reporteBadge(
              '${rep.numDevoluciones}',
              kDevColor,
              kDevColor.withOpacity(0.08),
              kDevColor.withOpacity(0.3),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kDevColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: kDevColor.withOpacity(0.15)),
            ),
            child: Row(children: [
              Icon(Icons.money_off_rounded,
                  size: 16, color: kDevColor),
              const SizedBox(width: 8),
              Text('Total devuelto',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: kDevColor)),
              const Spacer(),
              Text('-\$${fmtNum(rep.totalDevoluciones)}',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kDevColor)),
            ]),
          ),
          if (devProductos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Productos devueltos',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            ...devProductos.take(3).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.undo_rounded,
                    size: 12, color: kDevColor),
                const SizedBox(width: 6),
                Expanded(child: Text(p['nombre'],
                  style: GoogleFonts.poppins(fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
                Text(
                  'x${(p['cantidad'] as double).toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade500)),
              ]),
            )),
            if (devProductos.length > 3)
              Text('+ ${devProductos.length - 3} más...',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade400)),
          ],
        ],
      ),
    );
  }
}