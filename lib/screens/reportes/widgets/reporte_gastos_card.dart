import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../models/contabilidad_models.dart';

// Paleta amber consistente para gastos
const _kGastoFg    = Color(0xFFF57C00); // orange 700
const _kGastoDark  = Color(0xFFE65100); // deep orange 900
const _kGastoBg    = Color(0xFFFFF3E0); // orange 50
const _kGastoBdr   = Color(0xFFFFCC80); // orange 200

class ReporteGastosCard extends StatelessWidget {
  const ReporteGastosCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');

    return Consumer<ContabilidadProvider>(
      builder: (_, prov, __) {
        final gastos = prov.gastos;
        final total  = gastos.fold(0.0, (s, g) => s + g.monto);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECEFF1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Encabezado ──────────────────────────────
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kGastoBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      color: _kGastoFg, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Gastos del día',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                // Total badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGastoBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kGastoBdr),
                  ),
                  child: Text(
                    '\$${fmt.format(total)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _kGastoDark,
                    ),
                  ),
                ),
              ]),

              // ── Estado ──────────────────────────────────
              if (prov.cargando) ...[
                const SizedBox(height: 14),
                const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kGastoFg),
                ),
              ] else if (gastos.isEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(children: [
                    Icon(Icons.receipt_outlined,
                        size: 32,
                        color: Colors.grey.shade200),
                    const SizedBox(height: 6),
                    Text(
                      'Sin gastos registrados',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade400),
                    ),
                  ]),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF5F5F5)),
                const SizedBox(height: 12),
                ...gastos.map((g) => _GastoItem(gasto: g, fmt: fmt)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GastoItem extends StatelessWidget {
  final Gasto gasto;
  final NumberFormat fmt;
  const _GastoItem({required this.gasto, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // Ícono categoría
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kGastoBg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            _iconoCategoria(gasto.categoria),
            size: 17,
            color: _kGastoFg,
          ),
        ),
        const SizedBox(width: 10),

        // Descripción + chips
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gasto.descripcion,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 3),
              Row(children: [
                if (gasto.categoria.isNotEmpty) ...[
                  _Chip(gasto.categoria, _kGastoFg),
                  const SizedBox(width: 4),
                ],
                _Chip(_metodoLabel(gasto.metodoPago),
                    _metodoColor(gasto.metodoPago)),
                const SizedBox(width: 4),
                _Chip(gasto.empleadoNombre,
                    const Color(0xFF78909C)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Monto
        Text(
          '\$${fmt.format(gasto.monto)}',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _kGastoDark,
          ),
        ),
      ]),
    );
  }

  static Widget _Chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );

  static String _metodoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      case 'credito':       return 'Crédito';
      default:              return 'Efectivo';
    }
  }

  static Color _metodoColor(String m) {
    switch (m) {
      case 'transferencia': return const Color(0xFF1976D2);
      case 'tarjeta':       return const Color(0xFF7B1FA2);
      case 'credito':       return const Color(0xFF00796B);
      default:              return const Color(0xFF388E3C);
    }
  }

  static IconData _iconoCategoria(String cat) {
    switch (cat.toLowerCase()) {
      case 'arriendo':      return Icons.home_work_outlined;
      case 'servicios':     return Icons.electrical_services_rounded;
      case 'nomina':        return Icons.people_outline_rounded;
      case 'transporte':    return Icons.local_shipping_outlined;
      case 'insumos':       return Icons.inventory_2_outlined;
      case 'mantenimiento': return Icons.build_outlined;
      default:              return Icons.receipt_outlined;
    }
  }
}