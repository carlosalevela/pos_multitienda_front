import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/devolucion_model.dart';
import '../../../core/constants.dart';

class DevolucionCard extends StatelessWidget {
  final DevolucionModel dev;
  final NumberFormat fmt;
  final bool puedeCancel;
  final VoidCallback onTap;
  final VoidCallback? onCancelar;

  const DevolucionCard({
    super.key,
    required this.dev,
    required this.fmt,
    required this.puedeCancel,
    required this.onTap,
    this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final cancelada = dev.estado == 'cancelada';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cancelada ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: cancelada ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: cancelada
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _leading(cancelada),
        title: _title(cancelada),
        subtitle: _subtitle(),
        trailing: _trailing(cancelada),
      ),
    );
  }

  Widget _leading(bool cancelada) {
    final esCambio = dev.tipo == 'cambio';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cancelada
            ? Colors.grey.shade100
            : esCambio
                ? Colors.green.shade50
                : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        esCambio ? Icons.swap_horiz_rounded : Icons.assignment_return_rounded,
        size: 22,
        color: cancelada
            ? Colors.grey.shade400
            : esCambio
                ? Colors.green.shade600
                : Colors.orange.shade600,
      ),
    );
  }

  Widget _title(bool cancelada) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'DEV-${dev.id} • ${dev.ventaNumero}',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: cancelada ? Colors.grey.shade400 : const Color(0xFF1A1A2E),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _ChipEstado(estado: dev.estado),
        const SizedBox(width: 8),
        _buildImpactoMonto(cancelada),
      ],
    );
  }

  Widget _buildImpactoMonto(bool cancelada) {
    if (cancelada) {
      return Text(
        fmt.format(dev.totalDevuelto),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.grey.shade400,
        ),
      );
    }

    if (dev.tipo == 'devolucion') {
      return Text(
        '- ${fmt.format(dev.totalDevuelto)}',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.orange.shade700,
        ),
      );
    }

    final tipoDif = (dev.tipoDiferencia ?? 'exacto').toLowerCase();
    final diferencia = dev.diferencia ?? 0.0;

    if (tipoDif == 'cobrar') {
      return Text(
        '+ ${fmt.format(diferencia)}',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.green.shade700,
        ),
      );
    }

    if (tipoDif == 'devolver') {
      return Text(
        '- ${fmt.format(diferencia)}',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.deepOrange.shade600,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Exacto',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 10,
          color: Colors.blueGrey.shade600,
        ),
      ),
    );
  }

  Widget _subtitle() {
    final esCambio = dev.tipo == 'cambio';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Chip(
              label: esCambio ? 'Cambio' : 'Devolución',
              color: esCambio ? Colors.green.shade600 : Colors.orange.shade600,
            ),
            _Chip(
              label: _metodoLabel(dev.metodoDevolucion),
              color: _metodoColor(dev.metodoDevolucion),
            ),
            _Chip(
              label: dev.empleadoNombre,
              color: Colors.grey.shade600,
            ),
            _Chip(
              label: '${dev.detalles.length} producto${dev.detalles.length != 1 ? 's' : ''}',
              color: Colors.blueGrey.shade400,
            ),
          ],
        ),
        if (esCambio && (dev.productoReemplazoNombre?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 6),
          Text(
            'Cambio por: ${dev.productoReemplazoNombre}'
            '${dev.cantidadReemplazo != null ? ' x${_fmtCantidad(dev.cantidadReemplazo!)}' : ''}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ],
        if (esCambio) ...[
          const SizedBox(height: 4),
          Text(
            _detalleImpacto(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: _detalleImpactoColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (dev.observaciones.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            dev.observaciones,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }

  String _detalleImpacto() {
    final tipoDif = (dev.tipoDiferencia ?? 'exacto').toLowerCase();
    final diferencia = dev.diferencia ?? 0.0;

    if (tipoDif == 'cobrar') {
      return 'Cliente agregó ${fmt.format(diferencia)}';
    }
    if (tipoDif == 'devolver') {
      return 'Se devolvieron ${fmt.format(diferencia)}';
    }
    return 'Cambio exacto sin diferencia';
  }

  Color _detalleImpactoColor() {
    final tipoDif = (dev.tipoDiferencia ?? 'exacto').toLowerCase();
    if (tipoDif == 'cobrar') return Colors.green.shade700;
    if (tipoDif == 'devolver') return Colors.deepOrange.shade600;
    return Colors.blueGrey.shade600;
  }

  Widget? _trailing(bool cancelada) {
    if (!puedeCancel || cancelada) return null;
    return IconButton(
      icon: Icon(Icons.cancel_outlined, color: Colors.red.shade400, size: 20),
      tooltip: 'Cancelar devolución',
      onPressed: onCancelar,
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

  Color _metodoColor(String m) {
    switch (m) {
      case 'transferencia':
        return Colors.blue.shade600;
      case 'tarjeta':
        return Colors.purple.shade600;
      case 'nota_credito':
        return Colors.teal.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  String _fmtCantidad(double v) {
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cancelada ? Colors.grey.shade500 : Colors.green.shade700,
        ),
      ),
    );
  }
}