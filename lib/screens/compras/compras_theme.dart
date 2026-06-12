// lib/screens/compras/compras_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';

class ComprasTheme {
  ComprasTheme._();

  static const Color dark   = Color(0xFF1A1A2E);
  static const Color accent = Color(Constants.primaryColor);
  static const Color bg     = Color(0xFFF4F6FA);

  // ── Estado ──────────────────────────────────────────────

  static Color colorEstado(String e) {
    switch (e) {
      case 'pendiente': return Colors.orange.shade600;
      case 'recibida':  return Colors.green.shade600;
      case 'cancelada': return Colors.red.shade600;
      default:          return Colors.grey.shade600;
    }
  }

  static IconData iconEstado(String e) {
    switch (e) {
      case 'pendiente': return Icons.pending_actions_rounded;
      case 'recibida':  return Icons.check_circle_rounded;
      case 'cancelada': return Icons.cancel_rounded;
      default:          return Icons.help_rounded;
    }
  }

  static String labelEstado(String e) {
    switch (e) {
      case 'pendiente': return 'Pendiente';
      case 'recibida':  return 'Recibida';
      case 'cancelada': return 'Cancelada';
      default:          return e;
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  static String fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  static double calcularTotal(List<Map<String, dynamic>> detalles) =>
      detalles.fold(0.0, (sum, d) =>
          sum +
          (double.tryParse(d['cantidad']?.toString() ?? '0') ?? 0) *
          (double.tryParse(d['precio_unitario']?.toString() ?? '0') ?? 0));

  // ── Roles ────────────────────────────────────────────────

  /// admin Y superadmin
  static bool esAdmin(String? rol) =>
      rol == 'admin' || rol == 'superadmin';

  /// solo superadmin (maneja múltiples empresas)
  static bool esSuperAdmin(String? rol) => rol == 'superadmin';

  // ── Decoraciones ─────────────────────────────────────────

  static InputDecoration dropdownDecoration(IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
    filled:     true,
    fillColor:  bg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:   const BorderSide(color: accent, width: 1.5),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
  );

  static InputDecoration miniInput(String label) => InputDecoration(
    labelText:  label,
    labelStyle: GoogleFonts.poppins(
        fontSize: 11, color: Colors.grey.shade500),
    filled:     true,
    fillColor:  Colors.white,
    isDense:    true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:   BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:   BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:   const BorderSide(color: accent, width: 1.5),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}