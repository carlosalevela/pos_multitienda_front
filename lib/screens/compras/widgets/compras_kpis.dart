// lib/screens/compras/widgets/compras_kpis.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/proveedores_provider.dart';
import '../compras_theme.dart';

class ComprasKpis extends StatelessWidget {
  final ProveedoresProvider prov;

  const ComprasKpis({super.key, required this.prov});

  @override
  Widget build(BuildContext context) {
    final pendientes     = prov.compras.where((c) => c['estado'] == 'pendiente').length;
    final recibidas      = prov.compras.where((c) => c['estado'] == 'recibida').length;
    final canceladas     = prov.compras.where((c) => c['estado'] == 'cancelada').length;
    final totalInvertido = prov.totalComprasRecibidas;

    return Row(children: [
      Expanded(child: _KpiCard(
        icon:  Icons.receipt_long_rounded,
        label: 'Total órdenes',
        valor: '${prov.compras.length}',
        color: const Color(0xFF1976D2),
      )),
      const SizedBox(width: 12),
      Expanded(child: _KpiCard(
        icon:  Icons.pending_actions_rounded,
        label: 'Pendientes',
        valor: '$pendientes',
        color: const Color(0xFFE65100),
      )),
      const SizedBox(width: 12),
      Expanded(child: _KpiCard(
        icon:  Icons.check_circle_rounded,
        label: 'Recibidas',
        valor: '$recibidas',
        color: const Color(0xFF00897B),
      )),
      const SizedBox(width: 12),
      Expanded(child: _KpiCard(
        icon:  Icons.attach_money_rounded,
        label: 'Total invertido',
        valor: '\$${ComprasTheme.fmt(totalInvertido)}',
        color: const Color(0xFF7B1FA2),
      )),
      if (canceladas > 0) ...[
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          icon:  Icons.cancel_rounded,
          label: 'Canceladas',
          valor: '$canceladas',
          color: Colors.red.shade700,
        )),
      ],
    ]);
  }
}

// ── Tarjeta individual ────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   valor;
  final Color    color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
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
                    fontSize: 18, color: ComprasTheme.dark)),
              Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ]),
    );
  }
}