// lib/screens/empresas/widgets/tiendas_section.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../models/tienda_model.dart';
import '../../../widgets/app/empty_state_card.dart';
import 'tienda_card.dart';

class TiendasSection extends StatelessWidget {
  const TiendasSection({
    super.key,
    required this.tiendas,
    required this.cargando,
    required this.onNuevaTienda,
    required this.onEditarTienda,
    required this.onVerEmpleados,
    required this.onDesactivarTienda,
  });

  final List<Tienda> tiendas;
  final bool cargando;
  final VoidCallback onNuevaTienda;
  final void Function(Tienda) onEditarTienda;
  final void Function(Tienda) onVerEmpleados;
  final void Function(Tienda) onDesactivarTienda;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado sección ───────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(Constants.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: Color(Constants.primaryColor),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Sucursales',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            if (tiendas.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(Constants.primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${tiendas.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(Constants.primaryColor),
                  ),
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                'Nueva sucursal',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: onNuevaTienda,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(Constants.primaryColor),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Contenido ────────────────────────────────
        if (cargando)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (tiendas.isEmpty)
          const EmptyStateCard(
            icon: Icons.store_rounded,
            title: 'Esta empresa no tiene sucursales',
            subtitle: 'Agrega la primera sucursal con el botón de arriba',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiendas.length,
            itemBuilder: (_, i) => TiendaCard(
              tienda: tiendas[i],
              onEdit: () => onEditarTienda(tiendas[i]),
              onVerEmpleados: () => onVerEmpleados(tiendas[i]),
              onDesactivar: () => onDesactivarTienda(tiendas[i]),
            ),
          ),
      ],
    );
  }
}