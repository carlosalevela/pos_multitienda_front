// lib/screens/empresas/widgets/empresa_resume_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../models/empresa_model.dart';
import '../../../widgets/app/status_chip.dart';

class EmpresaResumeCard extends StatelessWidget {
  const EmpresaResumeCard({
    super.key,
    required this.empresa,
    required this.onEdit,
  });

  final Empresa empresa;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: empresa.activo
                      ? const Color(Constants.primaryColor).withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.business_rounded,
                  color: empresa.activo
                      ? const Color(Constants.primaryColor)
                      : Colors.grey.shade400,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            empresa.nombre,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(activo: empresa.activo),
                      ],
                    ),
                    if (empresa.nit.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'NIT: ${empresa.nit}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Editar empresa',
                icon: Icon(Icons.edit_rounded,
                    color: Colors.orange.shade400, size: 20),
                onPressed: onEdit,
              ),
            ],
          ),

          // ── Divider ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.grey.shade100, height: 1),
          ),

          // ── Datos de contacto ────────────────────────
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              if (empresa.ciudad.isNotEmpty)
                _infoItem(
                  Icons.location_on_rounded,
                  empresa.ciudad,
                  Colors.blue,
                ),
              if (empresa.telefono.isNotEmpty)
                _infoItem(
                  Icons.phone_rounded,
                  empresa.telefono,
                  Colors.green,
                ),
              if (empresa.email.isNotEmpty)
                _infoItem(
                  Icons.email_rounded,
                  empresa.email,
                  Colors.orange,
                ),
              if (empresa.direccion.isNotEmpty)
                _infoItem(
                  Icons.map_rounded,
                  empresa.direccion,
                  Colors.purple,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String texto, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 5),
        Text(
          texto,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}