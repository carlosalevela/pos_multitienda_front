// lib/screens/compras/widgets/resultado_recepcion_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../compras_theme.dart';

class ResultadoRecepcionDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const ResultadoRecepcionDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final productos = (data['productos'] as List?) ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(children: [
        Icon(Icons.check_circle_rounded,
            color: Colors.green.shade600, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(
          data['detail'] ?? 'Orden recibida',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 15))),
      ]),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Tienda
              Row(children: [
                Icon(Icons.store_rounded,
                    size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(data['tienda'] ?? '',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600)),
              ]),
              const SizedBox(height: 12),
              Text('Productos actualizados:',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),

              ...productos.map((p) => _itemProducto(p)),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Entendido',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _itemProducto(Map<String, dynamic> p) {
    final esNuevo = p['es_nuevo'] == true;
    final color   = esNuevo ? Colors.orange : Colors.green;

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        color.shade50,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.shade200),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:        color.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            esNuevo
                ? Icons.add_box_rounded
                : Icons.inventory_2_rounded,
            size:  16,
            color: color.shade700),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(p['producto'] ?? '',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 12))),
              if (esNuevo)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color:        Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('NUEVO',
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              // Stock anterior → nuevo
              _stockChip(
                Icons.remove_circle_outline_rounded,
                'Antes: ${p['stock_anterior'] ?? 0}',
                Colors.grey),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  size: 12, color: Colors.grey),
              const SizedBox(width: 6),
              _stockChip(
                Icons.add_circle_outline_rounded,
                'Ahora: ${p['stock_nuevo'] ?? 0}',
                Colors.green),
              const SizedBox(width: 8),
              Text(
                '+${p['cantidad_recibida'] ?? 0} uds',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.shade700)),
            ]),
          ],
        )),
      ]),
    );
  }

  Widget _stockChip(IconData icon, String texto, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.shade50,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.shade200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color.shade600),
        const SizedBox(width: 3),
        Text(texto,
          style: GoogleFonts.poppins(
              fontSize: 10, color: color.shade700)),
      ]),
    );
  }
}