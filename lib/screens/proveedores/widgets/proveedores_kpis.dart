// lib/screens/proveedores/widgets/proveedores_kpis.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/proveedores_provider.dart';

class ProveedoresKpis extends StatelessWidget {
  final ProveedoresProvider prov;
  const ProveedoresKpis({super.key, required this.prov});

  static const _dark = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _kpiCard(
        icon:  Icons.store_rounded,
        label: 'Proveedores activos',
        valor: '${prov.totalProveedores}',
        color: const Color(0xFF1976D2),
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:  Icons.pending_actions_rounded,
        label: 'Órdenes pendientes',
        valor: '${prov.totalComprasPendientes}',
        color: const Color(0xFFE65100),
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:  Icons.check_circle_rounded,
        label: 'Total recibido',
        valor: '\$${_fmt(prov.totalComprasRecibidas)}',
        color: const Color(0xFF00897B),
      )),
    ]);
  }

  Widget _kpiCard({
    required IconData icon,
    required String   label,
    required String   valor,
    required Color    color,
  }) =>
    Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [
              Text(valor,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _dark)),
              Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ]),
    );

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
}