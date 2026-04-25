import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/cliente.dart';  // ajusta el path si es diferente

class ClienteCard extends StatelessWidget {
  final Cliente  cliente;
  final VoidCallback?        onTap;
  final VoidCallback?        onEditar;
  final VoidCallback?        onDesactivar;
  final bool                 mostrarAcciones; // admin/supervisor

  const ClienteCard({
    super.key,
    required this.cliente,
    this.onTap,
    this.onEditar,
    this.onDesactivar,
    this.mostrarAcciones = false,
  });

  // ── Avatar con iniciales ──────────────────────────────
  Widget _avatar() {
    final iniciales = [
      cliente.nombre.isNotEmpty ? cliente.nombre[0] : '',
      cliente.apellido.isNotEmpty ? cliente.apellido[0] : '',
    ].join().toUpperCase();

    // Color determinista según el id — siempre el mismo por cliente
    final colores = [
      const Color(0xFF01696F), // teal
      const Color(0xFF437A22), // verde
      const Color(0xFF006494), // azul
      const Color(0xFF7A39BB), // púrpura
      const Color(0xFF964219), // naranja
      const Color(0xFFA12C7B), // rosa
    ];
    final color = colores[cliente.id % colores.length];

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      ),
      child: Center(
        child: Text(
          iniciales,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  // ── Chip de cédula/NIT ────────────────────────────────
  Widget _chipCedula() {
    if (cliente.cedulaNit == null || cliente.cedulaNit!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4D1CA), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_outlined, size: 11, color: Color(0xFF7A7974)),
          const SizedBox(width: 4),
          Text(
            cliente.cedulaNit!,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7A7974),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chip de info (teléfono, email) ────────────────────
  Widget _chipInfo(IconData icon, String texto) {
    if (texto.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF7A7974)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF7A7974),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [

              // ── Avatar ──────────────────────────────────
              _avatar(),
              const SizedBox(width: 12),

              // ── Info principal ───────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Nombre + estado activo
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cliente.nombreCompleto,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF28251D),
                            ),
                          ),
                        ),
                        if (!cliente.activo) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Inactivo',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Cédula
                    _chipCedula(),

                    const SizedBox(height: 6),

                    // Teléfono + email
                    Row(
                      children: [
                        Expanded(child: _chipInfo(Icons.phone_outlined, cliente.telefono)),
                        const SizedBox(width: 8),
                        Expanded(child: _chipInfo(Icons.email_outlined, cliente.email)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Acciones ─────────────────────────────────
              if (mostrarAcciones) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'editar',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: const Color(0xFF01696F)),
                        const SizedBox(width: 10),
                        Text('Editar',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'desactivar',
                      child: Row(children: [
                        Icon(
                          cliente.activo
                              ? Icons.person_off_outlined
                              : Icons.person_outlined,
                          size: 16,
                          color: cliente.activo
                              ? Colors.red.shade400
                              : const Color(0xFF437A22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          cliente.activo ? 'Desactivar' : 'Activar',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ]),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'editar')      onEditar?.call();
                    if (v == 'desactivar')  onDesactivar?.call();
                  },
                ),
              ] else ...[
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade300,
                  size: 22,
                ),
              ],

            ],
          ),
        ),
      ),
    );
  }
}