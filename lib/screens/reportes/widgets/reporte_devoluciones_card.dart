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
    final impactoCaja = rep.impactoCajaDevoluciones;
    final tipoColor = impactoCaja > 0
        ? Colors.green.shade700
        : impactoCaja < 0
            ? kDevColor
            : Colors.blueGrey.shade600;

    final impactoTexto = impactoCaja > 0
        ? '+\$${fmtNum(impactoCaja)}'
        : impactoCaja < 0
            ? '-\$${fmtNum(impactoCaja.abs())}'
            : '\$0';

    return reporteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            sectionTitle(Icons.assignment_return_rounded, 'Devoluciones'),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tipoColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tipoColor.withOpacity(0.15)),
            ),
            child: Row(children: [
              Icon(
                impactoCaja > 0
                    ? Icons.add_circle_outline_rounded
                    : impactoCaja < 0
                        ? Icons.money_off_rounded
                        : Icons.swap_horiz_rounded,
                size: 16,
                color: tipoColor,
              ),
              const SizedBox(width: 8),
              Text(
                impactoCaja > 0
                    ? 'Cobrado en cambios'
                    : impactoCaja < 0
                        ? 'Impacto en caja'
                        : 'Cambio exacto',
                style: GoogleFonts.poppins(fontSize: 12, color: tipoColor),
              ),
              const Spacer(),
              Text(
                impactoTexto,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: tipoColor,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniChip(
                  'Devol. dinero',
                  '-\$${fmtNum(rep.totalDevolucionesDinero)}',
                  kDevColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniChip(
                  'Cambios exactos',
                  '${rep.numCambiosExactos}',
                  Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniChip(
                  'Cobrado cambios',
                  '+\$${fmtNum(rep.totalCobradoCambios)}',
                  Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniChip(
                  'Devuelto cambios',
                  '-\$${fmtNum(rep.totalDevueltoCambios)}',
                  Colors.deepOrange.shade600,
                ),
              ),
            ],
          ),
          if (devProductos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Productos devueltos',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 6),
            ...devProductos.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.undo_rounded, size: 12, color: kDevColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p['nombre'],
                        style: GoogleFonts.poppins(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'x${(p['cantidad'] as double).toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ]),
                )),
            if (devProductos.length > 3)
              Text(
                '+ ${devProductos.length - 3} más...',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
              ),
          ],
        ],
      ),
    );
  }

  Widget _miniChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}