// lib/screens/empresas/widgets/tienda_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../models/tienda_model.dart';
import '../../../widgets/app/status_chip.dart';

class TiendaCard extends StatelessWidget {
  const TiendaCard({
    super.key,
    required this.tienda,
    required this.onEdit,
    required this.onVerEmpleados,
    this.onDesactivar,
  });

  final Tienda tienda;
  final VoidCallback onEdit;
  final VoidCallback onVerEmpleados;
  final VoidCallback? onDesactivar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tienda.activo ? Colors.transparent : Colors.red.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tienda.activo
                ? const Color(Constants.primaryColor).withOpacity(0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.store_rounded,
            color: tienda.activo
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade400,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                tienda.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(activo: tienda.activo),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (tienda.ciudad.isNotEmpty)
              Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tienda.ciudad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              ]),
            if (tienda.nit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'NIT: ${tienda.nit}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                Icon(Icons.people_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  '${tienda.totalEmpleados} empleado(s)',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Ver empleados',
              icon: Icon(Icons.people_rounded,
                  color: Colors.blue.shade400, size: 20),
              onPressed: onVerEmpleados,
            ),
            IconButton(
              tooltip: 'Editar',
              icon: Icon(Icons.edit_rounded,
                  color: Colors.orange.shade400, size: 20),
              onPressed: onEdit,
            ),
            if (tienda.activo && onDesactivar != null)
              IconButton(
                tooltip: 'Desactivar',
                icon: Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.red.shade300, size: 20),
                onPressed: onDesactivar,
              ),
          ],
        ),
      ),
    );
  }
}