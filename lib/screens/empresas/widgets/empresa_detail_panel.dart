// lib/screens/empresas/widgets/empresa_detail_panel.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../models/empresa_model.dart';
import '../../../models/tienda_model.dart';
import 'empresa_resume_card.dart';
import 'tiendas_section.dart';

class EmpresaDetailPanel extends StatelessWidget {
  const EmpresaDetailPanel({
    super.key,
    required this.empresaSeleccionada,
    required this.tiendas,
    required this.cargandoTiendas,
    required this.onEditarEmpresa,
    required this.onNuevaTienda,
    required this.onEditarTienda,
    required this.onVerEmpleados,
    required this.onDesactivarTienda,
  });

  final Empresa? empresaSeleccionada;
  final List<Tienda> tiendas;
  final bool cargandoTiendas;
  final VoidCallback onEditarEmpresa;
  final VoidCallback onNuevaTienda;
  final void Function(Tienda) onEditarTienda;
  final void Function(Tienda) onVerEmpleados;
  final void Function(Tienda) onDesactivarTienda;

  @override
  Widget build(BuildContext context) {
    // ── Sin empresa seleccionada ─────────────────────
    if (empresaSeleccionada == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(Constants.primaryColor).withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.business_rounded,
                  size: 48,
                  color: const Color(Constants.primaryColor).withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona una empresa',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige una empresa de la lista\npara ver su detalle y sucursales',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Con empresa seleccionada ─────────────────────
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Resumen empresa ──────────────────────
            EmpresaResumeCard(
              empresa: empresaSeleccionada!,
              onEdit: onEditarEmpresa,
            ),
            const SizedBox(height: 20),

            // ── KPIs rápidos de tiendas ──────────────
            _kpisTiendas(),
            const SizedBox(height: 20),

            // ── Sección tiendas ──────────────────────
            TiendasSection(
              tiendas: tiendas,
              cargando: cargandoTiendas,
              onNuevaTienda: onNuevaTienda,
              onEditarTienda: onEditarTienda,
              onVerEmpleados: onVerEmpleados,
              onDesactivarTienda: onDesactivarTienda,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpisTiendas() {
    final activas = tiendas.where((t) => t.activo).length;
    final inactivas = tiendas.where((t) => !t.activo).length;

    return Row(
      children: [
        _kpiChip(
          '${tiendas.length}',
          'Total',
          Icons.store_rounded,
          Colors.blue,
        ),
        const SizedBox(width: 10),
        _kpiChip(
          '$activas',
          'Activas',
          Icons.check_circle_rounded,
          Colors.green,
        ),
        const SizedBox(width: 10),
        _kpiChip(
          '$inactivas',
          'Inactivas',
          Icons.cancel_rounded,
          Colors.red,
        ),
      ],
    );
  }

  Widget _kpiChip(
      String valor, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color.withOpacity(0.8)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}