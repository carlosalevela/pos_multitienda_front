import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/reportes_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/reporte_pdf_service.dart';
import 'reporte_utils.dart';

class ReporteHeader extends StatelessWidget {
  final ReportesProvider rep;
  final AuthProvider auth;
  final String fechaStr;
  final bool cargando;
  final VoidCallback onFecha;
  final VoidCallback onRecargar;

  const ReporteHeader({
    super.key,
    required this.rep,
    required this.auth,
    required this.fechaStr,
    required this.cargando,
    required this.onFecha,
    required this.onRecargar,
  });

  @override
  Widget build(BuildContext context) {
    final impactoCaja = rep.impactoCajaDevoluciones;
    final impactoColor = impactoCaja > 0
        ? Colors.green.shade700
        : impactoCaja < 0
            ? kDevColor
            : Colors.blueGrey.shade600;

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

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: kAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reportes de ventas',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kDark,
                    ),
                  ),
                  Text(
                    auth.tiendaNombre,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (rep.numDevoluciones > 0) ...[
                reporteBadge(
                  '${rep.numDevoluciones} devolución${rep.numDevoluciones > 1 ? "es" : ""}',
                  kDevColor,
                  kDevColor.withOpacity(0.08),
                  kDevColor.withOpacity(0.3),
                ),
                const SizedBox(width: 10),
              ],
              OutlinedButton.icon(
                onPressed: onFecha,
                icon: const Icon(Icons.calendar_today_rounded, size: 15),
                label: Text(
                  fechaStr,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: const BorderSide(color: kAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Actualizar reportes',
                child: OutlinedButton(
                  onPressed: cargando ? null : onRecargar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(42, 42),
                    maximumSize: const Size(42, 42),
                    padding: EdgeInsets.zero,
                  ),
                  child: cargando
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade400,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: rep.ventas.isEmpty
                    ? null
                    : () => ReportePdfService.generarReporteDia(
                          rep: rep,
                          fecha: fechaStr,
                          tiendaNombre: auth.tiendaNombre,
                          empresaNombre: auth.empresaNombre,
                        ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                label: Text(
                  'Exportar PDF',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ResumenHeaderChip(
                label: 'Ventas',
                value: '\$${fmtNum(rep.totalDia)}',
                color: Colors.blue.shade700,
              ),
              _ResumenHeaderChip(
                label: 'Devoluciones',
                value: rep.totalDevoluciones == 0
                    ? '\$0'
                    : '-\$${fmtNum(rep.totalDevoluciones)}',
                color: kDevColor,
              ),
              _ResumenHeaderChip(
                label: 'Impacto devoluciones',
                value: impactoTexto,
                color: impactoColor,
                filled: true,
              ),
              _ResumenHeaderChip(
                label: 'Neto real',
                value: netoTexto,
                color: rep.totalNeto >= 0
                    ? Colors.green.shade700
                    : Colors.red.shade600,
              ),
              _ResumenHeaderChip(
                label: 'Cambios exactos',
                value: '${rep.numCambiosExactos}',
                color: Colors.blueGrey.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumenHeaderChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool filled;

  const _ResumenHeaderChip({
    required this.label,
    required this.value,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
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