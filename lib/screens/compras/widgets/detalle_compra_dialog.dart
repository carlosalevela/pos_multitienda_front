// lib/screens/compras/widgets/detalle_compra_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../compras_theme.dart'; // solo para fmt()
import 'compras_tabla.dart';   // EstadoBadge

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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
      titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(children: [
        const Icon(Icons.receipt_long_rounded,
            color: AppColors.secondary),
        const SizedBox(width: 10),
        Text(_detalle?['numero_orden'] ?? 'Detalle de orden',
            style: AppTextStyles.headlineSm),
        const Spacer(),
        if (_detalle != null)
          EstadoBadge(estado: _detalle!['estado'] ?? ''),
      ]),
      content: SizedBox(
        width: 560,
        child: _cargando
            ? const SizedBox(
                height: 160,
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.secondary)))
            : _detalle == null
                ? Center(child: Text('No se pudo cargar el detalle',
                    style: AppTextStyles.bodySm))
                : SingleChildScrollView(child: _buildContenido()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar',
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant))),
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
            d['tienda_nombre'] ?? 'Multi-tienda'),
        _infoRow(Icons.badge_rounded,    'Empleado',
            d['empleado_nombre'] ?? ''),
        _infoRow(Icons.calendar_today_rounded, 'Fecha orden',
            (d['fecha_orden']?.toString() ?? '').length >= 10
                ? d['fecha_orden'].toString().substring(0, 10)
                : ''),
        if (d['fecha_recepcion'] != null)
          _infoRow(Icons.check_circle_rounded, 'Fecha recepción',
            d['fecha_recepcion'].toString().substring(0, 10),
            color: AppColors.secondary),
        if ((d['observaciones'] ?? '').toString().isNotEmpty)
          _infoRow(Icons.notes_rounded, 'Observaciones',
              d['observaciones']),

        const Divider(height: 24, color: AppColors.outlineVariant),
        Text('Productos', style: AppTextStyles.headlineSm.copyWith(fontSize: 14)),
        const SizedBox(height: 10),

        ...items.map((item) => _itemProducto(item)),

        const Divider(height: 16, color: AppColors.outlineVariant),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Total: ',
                style: AppTextStyles.bodySm.copyWith(fontSize: 14)),
            Text(
              '\$${ComprasTheme.fmt(
                  double.tryParse(d['total'].toString()) ?? 0)}',
              style: AppTextStyles.numericData
                  .copyWith(color: AppColors.secondary)),
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
            color: color ?? AppColors.outline),
        const SizedBox(width: 8),
        Text('$label: ', style: AppTextStyles.bodySm),
        Expanded(child: Text(valor,
          style: AppTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.w500,
              color: color ?? AppColors.onSurface))),
      ]),
    );
  }

  Widget _itemProducto(Map<String, dynamic> item) {
    final distribuciones = (item['distribuciones'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
        border:       Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(
              item['producto_nombre'] ?? '',
              style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w500))),
            Text(
              'x${double.tryParse(item['cantidad'].toString())
                  ?.toStringAsFixed(0) ?? 0}  ',
              style: AppTextStyles.bodySm),
            Text(
              '\$${ComprasTheme.fmt(double.tryParse(
                  item['precio_unitario'].toString()) ?? 0)} c/u',
              style: AppTextStyles.bodySm),
            const SizedBox(width: 12),
            Text(
              '\$${ComprasTheme.fmt(double.tryParse(
                  item['subtotal'].toString()) ?? 0)}',
              style: AppTextStyles.bodyMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary)),
          ]),
          if (distribuciones.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...distribuciones.map((dist) => Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Row(children: [
                Icon(Icons.store_rounded,
                    size: 11, color: AppColors.outline),
                const SizedBox(width: 4),
                Text(dist['tienda_nombre'] ?? '—',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
                const Spacer(),
                Text(
                  'x${double.tryParse(dist['cantidad'].toString())
                      ?.toStringAsFixed(0) ?? 0}',
                  style: AppTextStyles.labelSm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary)),
              ]),
            )),
          ],
        ],
      ),
    );
  }
}
