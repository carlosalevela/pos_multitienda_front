// lib/screens/empresas/widgets/empresa_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../models/empresa_model.dart';
import '../../../widgets/app/status_chip.dart';

class EmpresaCard extends StatelessWidget {
  const EmpresaCard({
    super.key,
    required this.empresa,
    required this.onEdit,
    this.onTap,
    this.seleccionada = false,
  });

  final Empresa empresa;
  final VoidCallback onEdit;
  final VoidCallback? onTap;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: seleccionada
              ? const Color(Constants.primaryColor).withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada
                ? const Color(Constants.primaryColor).withOpacity(0.4)
                : empresa.activo
                    ? Colors.transparent
                    : Colors.red.shade100,
            width: seleccionada ? 1.5 : 1,
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          isThreeLine: true,
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: empresa.activo
                  ? const Color(Constants.primaryColor).withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.business_rounded,
              color: empresa.activo
                  ? const Color(Constants.primaryColor)
                  : Colors.grey.shade400,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  empresa.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(activo: empresa.activo),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (empresa.nit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'NIT: ${empresa.nit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                if (empresa.ciudad.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          empresa.ciudad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                if (empresa.telefono.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Tel: ${empresa.telefono}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ),
              ],
            ),
          ),
          trailing: IconButton(
            tooltip: 'Editar',
            icon: Icon(Icons.edit_rounded,
                color: Colors.orange.shade400, size: 20),
            onPressed: onEdit,
          ),
        ),
      ),
    );
  }
}