// lib/screens/devoluciones/widgets/devolucion_tipo_sheet.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DevolucionTipoSheet extends StatelessWidget {
  final double totalDevuelto;

  const DevolucionTipoSheet({
    super.key,
    required this.totalDevuelto,
  });

  /// Abre el sheet y retorna 'efectivo' | 'producto' | null
  static Future<String?> show(
      BuildContext context, double totalDevuelto) =>
    showModalBottomSheet<String>(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => DevolucionTipoSheet(totalDevuelto: totalDevuelto),
    );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // ── drag handle ───────────────────────────────
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),

        // ── título ────────────────────────────────────
        Text('¿Cómo procesar la devolución?',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text('Valor a devolver: \$${_fmt(totalDevuelto)}',
          style: GoogleFonts.poppins(
              fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 24),

        // ── opciones ──────────────────────────────────
        Row(children: [
          Expanded(
            child: _OpcionCard(
              icon:  Icons.payments_rounded,
              label: 'Efectivo',
              desc:  'Reembolso directo\nal cliente',
              color: const Color(0xFF2E7D32),
              onTap: () => Navigator.pop(context, 'efectivo'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _OpcionCard(
              icon:  Icons.swap_horiz_rounded,
              label: 'Cambio de\nproducto',
              desc:  'El cliente elige\notros artículos',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.pop(context, 'producto'),
            ),
          ),
        ]),

        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade500))),
      ]),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
}


class _OpcionCard extends StatelessWidget {
  final IconData     icon;
  final String       label, desc;
  final Color        color;
  final VoidCallback onTap;

  const _OpcionCard({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // ✅ withOpacity → withValues
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Column(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              // ✅ withOpacity → withValues
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 15, color: color)),
          const SizedBox(height: 4),
          Text(desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}