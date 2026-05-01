import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Botón con gradiente ────────────────────────────────────────
Widget buildGradientButton({
  required String        label,
  required Widget        icon,
  required List<Color>   colors,
  required Color         shadowColor,
  required VoidCallback? onPressed,
}) =>
  Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: shadowColor.withOpacity(0.35),
        blurRadius: 12, offset: const Offset(0, 5))],
    ),
    child: ElevatedButton.icon(
      icon: icon,
      label: Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 15)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor:     Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

// ── Campo de texto ─────────────────────────────────────────────
Widget buildInputField({
  required TextEditingController  controller,
  required String                 label,
  String?                         prefixText,
  TextInputType?                  keyboardType,
  List<TextInputFormatter>?       inputFormatters,
  Color accentColor = const Color(0xFF6366F1),
}) =>
  TextField(
    controller:      controller,
    keyboardType:    keyboardType,
    inputFormatters: inputFormatters,
    style: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w700,
        color: const Color(0xFF0F172A)),
    decoration: InputDecoration(
      labelText:   label,
      prefixText:  prefixText,
      labelStyle:  GoogleFonts.plusJakartaSans(
          fontSize: 13, color: const Color(0xFF94A3B8)),
      prefixStyle: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A)),
      filled:    true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 2)),
    ),
  );

// ── Fila label/valor ───────────────────────────────────────────
Widget buildInfoRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8), fontSize: 13,
              fontWeight: FontWeight.w500)),
      Text(value,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 13,
              color: const Color(0xFF1E293B))),
    ],
  ),
);

// ── Banner éxito / error ───────────────────────────────────────
Widget buildBanner(String msg,
    {required bool isError, required VoidCallback onClose}) {
  final color = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
  return Container(
    margin:  const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border:       Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(msg,
          style: GoogleFonts.plusJakartaSans(
              color: color.withOpacity(0.9),
              fontSize: 13, fontWeight: FontWeight.w600))),
      InkWell(
        onTap: onClose,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.close_rounded,
              size: 16, color: color.withOpacity(0.5))),
      ),
    ]),
  );
}

// ── Estado de carga ────────────────────────────────────────────
Widget buildLoadingState({String mensaje = 'Verificando sesión de caja…'}) =>
  Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
        ),
      ),
      const SizedBox(height: 16),
      Text(mensaje,
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600, fontSize: 14)),
    ]),
  );