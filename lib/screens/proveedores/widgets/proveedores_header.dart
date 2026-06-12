// lib/screens/proveedores/widgets/proveedores_header.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';

class ProveedoresHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String>  onSearch;
  final VoidCallback          onClear;
  final VoidCallback          onNuevo;

  const ProveedoresHeader({
    super.key,
    required this.searchCtrl,
    required this.onSearch,
    required this.onClear,
    required this.onNuevo,
  });

  static const _dark   = Color(0xFF1A1A2E);
  static const _accent = Color(Constants.primaryColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // ── Ícono + título ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.local_shipping_rounded,
              color: _accent, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Proveedores',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _dark)),
          Text('Gestión de proveedores',
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade500)),
        ]),
        const Spacer(),

        // ── Buscador ───────────────────────────────────
        SizedBox(
          width: 260,
          child: TextField(
            controller: searchCtrl,
            onChanged:  onSearch,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText:  'Buscar proveedor...',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: Colors.grey),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: onClear)
                  : null,
              filled:    true,
              fillColor: const Color(0xFFF4F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ── Botón nuevo ────────────────────────────────
        ElevatedButton.icon(
          onPressed: onNuevo,
          icon:  const Icon(Icons.add_rounded, size: 18),
          label: Text('Nuevo proveedor',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }
}