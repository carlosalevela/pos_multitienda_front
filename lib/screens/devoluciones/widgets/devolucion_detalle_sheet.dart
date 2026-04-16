import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/devolucion_model.dart';

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
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _Handle(),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  _encabezado(),
                  const SizedBox(height: 16),
                  _infoGeneral(),
                  const Divider(height: 28),
                  _listaProductos(),
                  if (dev.tipo == 'cambio') ...[
                    const Divider(height: 20),
                    _seccionCambio(),
                  ],
                  const Divider(height: 20),
                  _totalRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DEV-${dev.id}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            Text(
              '${dev.tipo == 'cambio' ? 'Cambio' : 'Devolución'} | Venta: ${dev.ventaNumero}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
      _ChipEstado(estado: dev.estado),
    ]);
  }

  Widget _infoGeneral() {
    return Column(
      children: [
        _InfoRow(
          icon: Icons.person_outline_rounded,
          label: 'Empleado',
          value: dev.empleadoNombre,
        ),
        _InfoRow(
          icon: Icons.store_outlined,
          label: 'Tienda',
          value: dev.tiendaNombre,
        ),
        _InfoRow(
          icon: Icons.payment_rounded,
          label: 'Método',
          value: _metodoLabel(dev.metodoDevolucion),
        ),
        _InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Fecha',
          value: DateFormat('dd/MM/yyyy HH:mm').format(dev.createdAt),
        ),
        if (dev.observaciones.isNotEmpty)
          _InfoRow(
            icon: Icons.notes_rounded,
            label: 'Observaciones',
            value: dev.observaciones,
          ),
      ],
    );
  }

  Widget _seccionCambio() {
    final cantRep = dev.cantidadReemplazo ?? 0;
    final cantRepStr = cantRep % 1 == 0
        ? cantRep.toStringAsFixed(0)
        : cantRep.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Producto entregado',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dev.productoReemplazoNombre ?? 'Sin producto',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Cantidad: $cantRepStr',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _listaProductos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dev.tipo == 'cambio' ? 'Productos recibidos' : 'Productos devueltos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 10),
        ...dev.detalles.map((d) => _ProductoRow(detalle: d, fmt: fmt)),
      ],
    );
  }

  Widget _totalRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          dev.tipo == 'cambio' ? 'Valor reconocido' : 'Total devuelto',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          fmt.format(dev.totalDevuelto),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.orange.shade700,
          ),
        ),
      ],
    );
  }

  String _metodoLabel(String m) {
    switch (m) {
      case 'transferencia':
        return 'Transferencia';
      case 'tarjeta':
        return 'Tarjeta';
      case 'nota_credito':
        return 'Nota Crédito';
      default:
        return 'Efectivo';
    }
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ),
      ]),
    );
  }
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 18,
            color: Colors.orange.shade600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detalle.productoNombre,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detalle.motivo.isNotEmpty)
                Text(
                  detalle.motivo,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'x$cantStr',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            Text(
              fmt.format(detalle.subtotal),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cancelada ? Colors.grey.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cancelada ? Colors.grey.shade300 : Colors.green.shade200,
        ),
      ),
      child: Text(
        cancelada ? 'Cancelada' : 'Procesada',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cancelada ? Colors.grey.shade600 : Colors.green.shade700,
        ),
      ),
    );
  }
}
