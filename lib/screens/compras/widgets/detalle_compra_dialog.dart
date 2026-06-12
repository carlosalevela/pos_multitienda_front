// lib/screens/compras/widgets/detalle_compra_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/proveedores_provider.dart';
import '../compras_theme.dart';
import 'compras_tabla.dart'; // EstadoBadge

class DetalleCompraDialog extends StatefulWidget {
  final int id;
  const DetalleCompraDialog({super.key, required this.id});

  @override
  State<DetalleCompraDialog> createState() => _DetalleCompraDialogState();
}

class _DetalleCompraDialogState extends State<DetalleCompraDialog> {
  Map<String, dynamic>? _detalle;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final data = await context
        .read<ProveedoresProvider>()
        .obtenerCompra(widget.id);
    if (!mounted) return;
    setState(() { _detalle = data; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(children: [
        const Icon(Icons.receipt_long_rounded,
            color: ComprasTheme.accent),
        const SizedBox(width: 10),
        Text(_detalle?['numero_orden'] ?? 'Detalle de orden',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        if (_detalle != null)
          EstadoBadge(estado: _detalle!['estado'] ?? ''),
      ]),
      content: SizedBox(
        width: 560,
        child: _cargando
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()))
            : _detalle == null
                ? Center(child: Text('No se pudo cargar el detalle',
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade400)))
                : SingleChildScrollView(child: _buildContenido()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar', style: GoogleFonts.poppins())),
      ],
    );
  }

  Widget _buildContenido() {
    final d = _detalle!;
    final items = (d['detalles'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _infoRow(Icons.store_rounded,    'Proveedor',
            d['proveedor_nombre'] ?? ''),
        _infoRow(Icons.business_rounded, 'Tienda',
            d['tienda_nombre'] ?? ''),
        _infoRow(Icons.badge_rounded,    'Empleado',
            d['empleado_nombre'] ?? ''),
        _infoRow(Icons.calendar_today_rounded, 'Fecha orden',
            (d['fecha_orden']?.toString() ?? '').length >= 10
                ? d['fecha_orden'].toString().substring(0, 10)
                : ''),
        if (d['fecha_recepcion'] != null)
          _infoRow(Icons.check_circle_rounded, 'Fecha recepción',
            d['fecha_recepcion'].toString().substring(0, 10),
            color: Colors.green.shade600),
        if ((d['observaciones'] ?? '').toString().isNotEmpty)
          _infoRow(Icons.notes_rounded, 'Observaciones',
              d['observaciones']),

        const Divider(height: 24),
        Text('Productos',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),

        ...items.map((item) => _itemProducto(item)),

        const Divider(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Total: ',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.grey.shade600)),
            Text(
              '\$${ComprasTheme.fmt(
                  double.tryParse(d['total'].toString()) ?? 0)}',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ComprasTheme.accent)),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String valor,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 15,
            color: color ?? Colors.grey.shade400),
        const SizedBox(width: 8),
        Text('$label: ',
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade500)),
        Expanded(child: Text(valor,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color ?? ComprasTheme.dark))),
      ]),
    );
  }

  Widget _itemProducto(Map<String, dynamic> item) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Expanded(child: Text(
          item['producto_nombre'] ?? '',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, fontSize: 13))),
        Text(
          'x${double.tryParse(item['cantidad'].toString())
              ?.toStringAsFixed(0) ?? 0}  ',
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade500)),
        Text(
          '\$${ComprasTheme.fmt(double.tryParse(
              item['precio_unitario'].toString()) ?? 0)} c/u',
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(width: 12),
        Text(
          '\$${ComprasTheme.fmt(double.tryParse(
              item['subtotal'].toString()) ?? 0)}',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13, color: ComprasTheme.accent)),
      ]),
    );
  }
}