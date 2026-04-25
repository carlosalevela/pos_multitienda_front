// lib/screens/empresas/dialogs/confirmar_desactivar_tienda_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/tienda_model.dart';
import '../../../providers/tienda_provider.dart';
import 'package:provider/provider.dart';

class ConfirmarDesactivarTiendaDialog extends StatelessWidget {
  const ConfirmarDesactivarTiendaDialog({
    super.key,
    required this.tienda,
  });

  final Tienda tienda;

  static Future<void> show(BuildContext context, {required Tienda tienda}) {
    return showDialog(
      context: context,
      builder: (_) => ConfirmarDesactivarTiendaDialog(tienda: tienda),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      // ── Ícono de advertencia ─────────────────────
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.remove_circle_outline_rounded,
          color: Colors.red.shade400,
          size: 32,
        ),
      ),
      title: Text(
        '¿Desactivar sucursal?',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      content: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.poppins(
              fontSize: 14, color: Colors.grey.shade600),
          children: [
            const TextSpan(text: 'La sucursal '),
            TextSpan(
              text: '"${tienda.nombre}"',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const TextSpan(
                text: ' quedará inactiva.\n¿Deseas continuar?'),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
          ),
          child: Text('Cancelar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        ),
        Consumer<TiendaProvider>(
          builder: (_, prov, __) => ElevatedButton(
            onPressed: prov.guardando
                ? null
                : () async {
                    await context
                        .read<TiendaProvider>()
                        .desactivarTienda(tienda.id);
                    if (context.mounted) Navigator.pop(context);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
            child: prov.guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text('Desactivar',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}