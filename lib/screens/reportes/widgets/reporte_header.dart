// lib/screens/reportes/widgets/reporte_header.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/reportes_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/reporte_pdf_service.dart';
import 'reporte_utils.dart';

class ReporteHeader extends StatelessWidget {
  final ReportesProvider rep;
  final AuthProvider     auth;
  final String           fechaStr;
  final bool             cargando;
  final VoidCallback     onFecha;
  final VoidCallback     onRecargar;

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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // ── ícono ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: kAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.bar_chart_rounded,
              color: kAccent, size: 24),
        ),
        const SizedBox(width: 14),

        // ── título ─────────────────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reportes de ventas',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kDark)),
          Text(auth.tiendaNombre,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade500)),
        ]),
        const Spacer(),

        // ── badge devoluciones ─────────────────────────
        if (rep.numDevoluciones > 0) ...[
          reporteBadge(
            '${rep.numDevoluciones} '
            'devolución${rep.numDevoluciones > 1 ? "es" : ""}',
            kDevColor,
            kDevColor.withOpacity(0.08),
            kDevColor.withOpacity(0.3),
          ),
          const SizedBox(width: 10),
        ],

        // ── selector fecha ─────────────────────────────
        OutlinedButton.icon(
          onPressed: onFecha,
          icon: const Icon(Icons.calendar_today_rounded, size: 15),
          label: Text(fechaStr,
              style: GoogleFonts.poppins(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: kAccent,
            side: const BorderSide(color: kAccent),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(width: 8),

        // ── botón recargar ─────────────────────────────
        Tooltip(
          message: 'Actualizar reportes',
          child: OutlinedButton(
            onPressed: cargando ? null : onRecargar,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(42, 42),
              maximumSize: const Size(42, 42),
              padding: EdgeInsets.zero,
            ),
            child: cargando
                ? SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.shade400))
                : const Icon(Icons.refresh_rounded, size: 18),
          ),
        ),
        const SizedBox(width: 8),

        // ── exportar PDF ───────────────────────────────
        ElevatedButton.icon(
          onPressed: rep.ventas.isEmpty
              ? null
              : () => ReportePdfService.generarReporteDia(
                    rep:           rep,
                    fecha:         fechaStr,
                    tiendaNombre:  auth.tiendaNombre,
                    empresaNombre: auth.empresaNombre),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
          label: Text('Exportar PDF',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor:         Colors.red.shade600,
            foregroundColor:         Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );
  }
}