import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/sesion_historial.dart';


class HistorialCard extends StatelessWidget {
  final SesionHistorial sesion;
  final VoidCallback    onTap;

  const HistorialCard({
    super.key,
    required this.sesion,
    required this.onTap,
  });

  static final _fmt = NumberFormat('#,##0', 'en_US');

  static String _formatFecha(String f) {
    final c = f.replaceAll('T', ' ');
    return c.length >= 16 ? c.substring(0, 16) : c;
  }

  @override
  Widget build(BuildContext context) {
    final esPositivo = sesion.diferencia >= 0;
    final difColor   = esPositivo
        ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final difBg      = esPositivo
        ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [

            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Colors.white, size: 21),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Cierre #${sesion.id}',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 14,
                            color: const Color(0xFF0F172A))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: difBg.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${esPositivo ? '+' : ''}\$${_fmt.format(sesion.diferencia)}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: difColor),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(sesion.empleadoNombre,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 7),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: Color(0xFFCBD5E1)),
                    const SizedBox(width: 4),
                    Text(_formatFecha(
                        sesion.fechaCierre.isNotEmpty
                            ? sesion.fechaCierre
                            : sesion.fechaApertura),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: const Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('Ventas: \$${_fmt.format(sesion.ventasTotal)}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569))),
                  ]),
                ],
              ),
            ),

            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1), size: 20),
          ]),
        ),
      ),
    );
  }
}