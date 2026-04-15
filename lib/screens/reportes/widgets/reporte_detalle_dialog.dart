// lib/screens/reportes/widgets/reporte_detalle_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'reporte_utils.dart';

class ReporteDetalleDialog extends StatelessWidget {
  final Map<String, dynamic> detalle;
  const ReporteDetalleDialog({super.key, required this.detalle});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.receipt_long_rounded, color: kAccent),
        const SizedBox(width: 10),
        Text(detalle['numero_factura'] ?? '',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold)),
      ]),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(Icons.person_rounded, 'Cliente',
                  detalle['cliente_nombre'] ?? 'Consumidor Final'),
              _row(Icons.badge_rounded, 'Empleado',
                  detalle['empleado_nombre'] ?? ''),
              _row(Icons.store_rounded, 'Tienda',
                  detalle['tienda_nombre'] ?? ''),
              _row(iconMetodo(detalle['metodo_pago'] ?? ''),
                  'Método',
                  labelMetodo(detalle['metodo_pago'] ?? '')),
              const Divider(height: 20),
              _row(Icons.shopping_bag_rounded, 'Subtotal',
                  '\$${fmtNum(double.tryParse(
                      detalle['subtotal'].toString()) ?? 0)}'),
              if ((double.tryParse(
                          detalle['descuento_total'].toString()) ?? 0) > 0)
                _row(Icons.discount_rounded, 'Descuento',
                    '-\$${fmtNum(double.tryParse(
                        detalle['descuento_total'].toString()) ?? 0)}',
                    color: Colors.orange),
              _row(Icons.attach_money_rounded, 'Total',
                  '\$${fmtNum(double.tryParse(
                      detalle['total'].toString()) ?? 0)}',
                  color: kAccent, bold: true),
              _row(Icons.payments_rounded, 'Recibido',
                  '\$${fmtNum(double.tryParse(
                      detalle['monto_recibido'].toString()) ?? 0)}'),
              _row(Icons.change_circle_rounded, 'Vuelto',
                  '\$${fmtNum(double.tryParse(
                      detalle['vuelto'].toString()) ?? 0)}',
                  color: Colors.green.shade600),
              const Divider(height: 20),
              Text('Productos',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
              const SizedBox(height: 8),
              ...(detalle['detalles'] as List? ?? []).map(
                (item) => Container(
                  margin:  const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.grey.shade200)),
                  child: Row(children: [
                    Expanded(child: Text(
                      item['producto_nombre'] ?? '',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 13))),
                    Text(
                      'x${double.tryParse(item['cantidad']
                          .toString())?.toStringAsFixed(0) ?? 0}  ',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600)),
                    Text(
                      '\$${fmtNum(double.tryParse(
                          item['subtotal'].toString()) ?? 0)}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: kAccent)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar',
              style: GoogleFonts.poppins())),
      ],
    );
  }

  Widget _row(IconData icon, String label, String valor,
      {Color? color, bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text('$label: ',
          style: GoogleFonts.poppins(
              fontSize: 13, color: Colors.grey.shade600)),
        Expanded(child: Text(valor,
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: bold
                  ? FontWeight.bold : FontWeight.w500,
              color: color ?? kDark))),
      ]),
    );
}