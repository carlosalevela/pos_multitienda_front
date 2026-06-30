import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/devolucion_model.dart';

const _kGreen     = Color(0xFF006C49);
const _kMintLight = Color(0xFFE8FFF4);
const _kSurface   = Color(0xFFF7F9FB);
const _kText      = Color(0xFF191C1E);
const _kTextMuted = Color(0xFF76777D);
const _kBorder    = Color(0xFFE0E3E5);
const _kOrange    = Color(0xFFF59E0B);

class DevolucionDetalleSheet extends StatelessWidget {
  final DevolucionModel dev;
  final NumberFormat fmt;

  const DevolucionDetalleSheet({
    super.key,
    required this.dev,
    required this.fmt,
  });

  static void show(
    BuildContext context, {
    required DevolucionModel dev,
    required NumberFormat fmt,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DevolucionDetalleSheet(dev: dev, fmt: fmt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          _Handle(),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                _headerCard(),
                const SizedBox(height: 16),
                _seccionInfo(),
                const SizedBox(height: 16),
                _seccionProductos(),
                if (dev.tipo == 'cambio') ...[
                  const SizedBox(height: 16),
                  _seccionCambio(),
                ],
                const SizedBox(height: 16),
                _seccionTotal(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Header card
  // ─────────────────────────────────────────────────────

  Widget _headerCard() {
    final esCambio  = dev.tipo == 'cambio';
    final cancelada = dev.estado == 'cancelada';
    final color     = cancelada ? _kTextMuted : esCambio ? _kGreen : _kOrange;
    final bgColor   = cancelada
        ? _kSurface
        : esCambio
            ? _kGreen.withValues(alpha: 0.06)
            : _kOrange.withValues(alpha: 0.06);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              esCambio
                  ? Icons.swap_horiz_rounded
                  : Icons.assignment_return_rounded,
              color: color, size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DEV-${dev.id}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold,
                      fontSize: 17, color: _kText)),
              Text('${esCambio ? 'Cambio' : 'Devolución'} · ${dev.ventaNumero}',
                  style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
            ]),
          ),
          _ChipEstado(estado: dev.estado),
        ]),
        const SizedBox(height: 14),
        const Divider(color: _kBorder, height: 1),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _InfoCell(label: 'EMPLEADO', value: dev.empleadoNombre)),
          const SizedBox(width: 12),
          Expanded(child: _InfoCell(label: 'TIENDA',   value: dev.tiendaNombre)),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Sección info general
  // ─────────────────────────────────────────────────────

  Widget _seccionInfo() {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(dev.createdAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        _InfoRow(icon: Icons.payment_rounded,      label: 'Método',   value: _metodoLabel(dev.metodoDevolucion)),
        _InfoRow(icon: Icons.calendar_today_rounded, label: 'Fecha',   value: date),
        if (dev.observaciones.isNotEmpty)
          _InfoRow(icon: Icons.notes_rounded,      label: 'Notas',    value: dev.observaciones),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Productos devueltos
  // ─────────────────────────────────────────────────────

  Widget _seccionProductos() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SeccionTitle(
        label: dev.tipo == 'cambio' ? 'Productos recibidos' : 'Productos devueltos',
        icon: Icons.assignment_return_rounded,
        color: _kOrange,
      ),
      const SizedBox(height: 10),
      ...dev.detalles.map((d) => _ProductoRow(detalle: d, fmt: fmt)),
    ]);
  }

  // ─────────────────────────────────────────────────────
  //  Sección cambio (producto entregado + diferencia)
  // ─────────────────────────────────────────────────────

  Widget _seccionCambio() {
    final cantRep     = dev.cantidadReemplazo ?? 0;
    final cantRepStr  = cantRep % 1 == 0 ? cantRep.toStringAsFixed(0) : cantRep.toStringAsFixed(2);
    final tipoDif     = (dev.tipoDiferencia ?? 'exacto').toLowerCase();
    final dif         = dev.diferencia ?? 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SeccionTitle(
        label: 'Producto entregado',
        icon: Icons.shopping_bag_outlined,
        color: _kGreen,
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_rounded, size: 20, color: _kGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dev.productoReemplazoNombre ?? 'Sin producto',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('Cantidad: $cantRepStr',
                  style: GoogleFonts.inter(fontSize: 11, color: _kGreen)),
              if (dev.precioReemplazo != null)
                Text('Precio unitario: ${fmt.format(dev.precioReemplazo!)}',
                    style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted)),
            ]),
          ),
          if (dev.subtotalReemplazo != null)
            Text(fmt.format(dev.subtotalReemplazo!),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold,
                    color: _kGreen)),
        ]),
      ),

      // Diferencia
      if (tipoDif != 'exacto' && dif > 0) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tipoDif == 'cobrar'
                ? _kOrange.withValues(alpha: 0.08)
                : Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tipoDif == 'cobrar'
                  ? _kOrange.withValues(alpha: 0.3)
                  : Colors.blueGrey.shade200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(
                  tipoDif == 'cobrar' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 16,
                  color: tipoDif == 'cobrar' ? _kOrange : Colors.blueGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  tipoDif == 'cobrar' ? 'Cobrado al cliente' : 'Devuelto al cliente',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                      color: tipoDif == 'cobrar' ? _kOrange : Colors.blueGrey.shade700),
                ),
              ]),
              Text(fmt.format(dif),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold,
                      color: tipoDif == 'cobrar' ? _kOrange : Colors.blueGrey.shade700)),
            ],
          ),
        ),
      ],
    ]);
  }

  // ─────────────────────────────────────────────────────
  //  Total
  // ─────────────────────────────────────────────────────

  Widget _seccionTotal() {
    final esCambio = dev.tipo == 'cambio';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esCambio ? _kMintLight : _kOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: esCambio
                ? _kGreen.withValues(alpha: 0.2)
                : _kOrange.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              esCambio ? 'Valor reconocido' : 'Total devuelto',
              style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              esCambio ? 'Método: ${_metodoLabel(dev.metodoDevolucion)}' : '',
              style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
            ),
          ]),
          Text(
            fmt.format(dev.totalDevuelto),
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, fontSize: 22,
                color: esCambio ? _kGreen : _kOrange),
          ),
        ],
      ),
    );
  }

  String _metodoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      case 'nota_credito':  return 'Nota Crédito';
      default:              return 'Efectivo';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40, height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

class _SeccionTitle extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  const _SeccionTitle({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
    const SizedBox(width: 8),
    Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700,
        fontSize: 14, color: _kText)),
  ]);
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
          color: _kTextMuted, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
          color: _kText), overflow: TextOverflow.ellipsis),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 15, color: _kTextMuted),
      const SizedBox(width: 8),
      Text('$label: ', style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
      Expanded(
        child: Text(value, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
      ),
    ]),
  );
}

class _ProductoRow extends StatelessWidget {
  final DetalleDevolucionModel detalle;
  final NumberFormat fmt;
  const _ProductoRow({required this.detalle, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cantStr = detalle.cantidad % 1 == 0
        ? detalle.cantidad.toStringAsFixed(0)
        : detalle.cantidad.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_outlined, size: 18, color: _kOrange),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(detalle.productoNombre,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
            if (detalle.motivo.isNotEmpty)
              Text(detalle.motivo, style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('×$cantStr', style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
          Text(fmt.format(detalle.subtotal),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _kOrange)),
        ]),
      ]),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final String estado;
  const _ChipEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final cancelada = estado == 'cancelada';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cancelada ? _kSurface : _kMintLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cancelada ? _kBorder : _kGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        cancelada ? 'Cancelada' : 'Procesada',
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
            color: cancelada ? _kTextMuted : _kGreen),
      ),
    );
  }
}
