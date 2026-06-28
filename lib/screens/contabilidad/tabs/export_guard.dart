// Checks whether all cajas are closed before triggering an export.
// Shows a blocking dialog if any caja is still open.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/config_service.dart';

Future<bool> verificarReporteAntesDe(
  BuildContext context, {
  int? tiendaId,
}) async {
  final res = await ConfigService().verificarReporte(tiendaId: tiendaId);

  if (res['success'] != true) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['error'] ?? 'Error al verificar caja'),
        backgroundColor: const Color(0xFFBE123C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    return false;
  }

  final bool puedeReportar = res['puede_reportar'] as bool? ?? true;
  if (puedeReportar) return true;

  final cajas = res['cajas_abiertas'] as List? ?? [];
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.lock_clock_rounded,
              color: Color(0xFFBE123C), size: 20),
        ),
        const SizedBox(width: 10),
        Text('Caja aún abierta',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: const Color(0xFF111827))),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debes cerrar todas las cajas antes de exportar el reporte para evitar datos incompletos.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF374151)),
          ),
          if (cajas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Cajas pendientes:',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280))),
            const SizedBox(height: 6),
            ...cajas.map((c) {
              final tienda   = c['tienda']   as String? ?? '';
              final empleado = c['empleado'] as String? ?? '';
              final desde    = c['desde']    as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCCDD6)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.store_outlined,
                        size: 14, color: Color(0xFFBE123C)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$tienda — $empleado${desde.isNotEmpty ? ' (desde $desde)' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF7F1D1D)),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFBE123C)),
          child: Text('Entendido',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  return false;
}
