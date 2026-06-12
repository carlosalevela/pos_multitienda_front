// lib/screens/compras/widgets/compras_header.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../providers/auth_provider.dart';
import '../compras_theme.dart';

class ComprasHeader extends StatelessWidget {
  final ProveedoresProvider   prov;
  final AuthProvider          auth;
  final String?               filtroEstado;
  final ValueChanged<String?> onFiltroChanged;
  final VoidCallback          onNuevaOrden;

  const ComprasHeader({
    super.key,
    required this.prov,
    required this.auth,
    required this.filtroEstado,
    required this.onFiltroChanged,
    required this.onNuevaOrden,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        // ── Ícono + Título ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        ComprasTheme.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shopping_cart_rounded,
              color: ComprasTheme.accent, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Órdenes de compra',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: ComprasTheme.dark)),
          Text(
            ComprasTheme.esSuperAdmin(auth.rol)
                ? 'Todas las empresas'
                : auth.tiendaNombre,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade500)),
        ]),
        const Spacer(),

        // ── Filtro de estado ───────────────────────────
        _FiltroEstado(valor: filtroEstado, onChanged: onFiltroChanged),
        const SizedBox(width: 12),

        // ── Botón nueva orden ──────────────────────────
        ElevatedButton.icon(
          onPressed: onNuevaOrden,
          icon:  const Icon(Icons.add_rounded, size: 18),
          label: Text('Nueva orden',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ComprasTheme.accent,
            foregroundColor: Colors.white,
            elevation:       0,
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

// ── Dropdown de filtro (widget privado) ───────────────────────

class _FiltroEstado extends StatelessWidget {
  final String?               valor;
  final ValueChanged<String?> onChanged;

  const _FiltroEstado({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:        ComprasTheme.bg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: valor,
          hint: Text('Todos los estados',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500)),
          style: GoogleFonts.poppins(
              fontSize: 13, color: ComprasTheme.dark),
          icon: const Icon(
              Icons.keyboard_arrow_down_rounded, size: 18),
          onChanged: onChanged,
          items: [
            DropdownMenuItem(
              value: null,
              child: Text('Todos',
                  style: GoogleFonts.poppins(fontSize: 13)),
            ),
            ...['pendiente', 'recibida', 'cancelada'].map((e) =>
              DropdownMenuItem(
                value: e,
                child: Row(children: [
                  Icon(ComprasTheme.iconEstado(e),
                      size: 14,
                      color: ComprasTheme.colorEstado(e)),
                  const SizedBox(width: 6),
                  Text(ComprasTheme.labelEstado(e),
                      style: GoogleFonts.poppins(fontSize: 13)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}