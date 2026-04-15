// lib/screens/reportes/widgets/reporte_utils.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';

// ── Colores globales de la feature ────────────────────
const kDark      = Color(0xFF1A1A2E);
const kAccent    = Color(Constants.primaryColor);
const kDevColor  = Color(0xFFD32F2F);
const kNetoColor = Color(0xFF00897B);

// ── Formato numérico ───────────────────────────────────
String fmtNum(double v) => v
    .toStringAsFixed(0)
    .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

// ── Método de pago helpers ─────────────────────────────
Color colorMetodo(String m) {
  switch (m.toLowerCase()) {
    case 'efectivo':      return Colors.green.shade600;
    case 'transferencia': return Colors.blue.shade600;
    case 'tarjeta':       return Colors.purple.shade600;
    default:              return Colors.grey.shade600;
  }
}

IconData iconMetodo(String m) {
  switch (m.toLowerCase()) {
    case 'efectivo':      return Icons.payments_rounded;
    case 'transferencia': return Icons.account_balance_rounded;
    case 'tarjeta':       return Icons.credit_card_rounded;
    default:              return Icons.attach_money_rounded;
  }
}

String labelMetodo(String m) {
  switch (m.toLowerCase()) {
    case 'efectivo':      return 'Efectivo';
    case 'transferencia': return 'Transferencia';
    case 'tarjeta':       return 'Tarjeta';
    default:              return m;
  }
}

// ── Shared widgets ─────────────────────────────────────
Widget reporteCard({required Widget child, EdgeInsets? padding}) =>
    Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );

Widget sectionTitle(IconData icon, String title) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, size: 16, color: kDark.withOpacity(0.5)),
    const SizedBox(width: 7),
    Text(title,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: kDark)),
  ],
);

Widget emptyMsg(String msg) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Text(msg,
      style: GoogleFonts.poppins(
          color: Colors.grey, fontSize: 13)),
);

Widget reporteBadge(
    String text, Color fg, Color bg, Color border) =>
    Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border)),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg)),
    );

Widget estadoBadge(String estado) {
  final esAnulada = estado == 'anulada';
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: esAnulada
          ? Colors.red.shade50 : Colors.green.shade50,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: esAnulada
              ? Colors.red.shade200
              : Colors.green.shade200)),
    child: Text(estado,
      style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: esAnulada
              ? Colors.red.shade700
              : Colors.green.shade700)),
  );
}

Widget abonoBadge() => Container(
  padding: const EdgeInsets.symmetric(
      horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: Colors.teal.shade50,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.teal.shade200)),
  child: Text('abono',
    style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.teal.shade700)),
);

Widget devolucionBadge() => Container(
  padding: const EdgeInsets.symmetric(
      horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: kDevColor.withOpacity(0.08),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: kDevColor.withOpacity(0.3))),
  child: Text('devolución',
    style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: kDevColor)),
);

// ── Data class ─────────────────────────────────────────
class KpiData {
  final IconData icon;
  final String   label, valor;
  final Color    color;
  const KpiData({
    required this.icon,
    required this.label,
    required this.valor,
    required this.color,
  });
}