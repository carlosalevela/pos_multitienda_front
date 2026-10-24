// lib/screens/reportes/widgets/reporte_detalle_dialog.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/item_carrito.dart';
import '../../../models/producto.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../services/recibo_pdf_service.dart';
import '../../../services/windows_printer_service.dart';
import 'reporte_utils.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class ReporteDetalleDialog extends StatefulWidget {
  final Map<String, dynamic> detalle;
  const ReporteDetalleDialog({super.key, required this.detalle});

  @override
  State<ReporteDetalleDialog> createState() => _ReporteDetalleDialogState();
}

class _ReporteDetalleDialogState extends State<ReporteDetalleDialog> {
  Map<String, dynamic> get detalle => widget.detalle;

  Future<void> _reimprimir() async {
    final auth      = context.read<AuthProvider>();
    final config    = context.read<ConfigProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nav       = Navigator.of(context);

    final rawItems = (detalle['detalles'] as List? ?? []);
    final items = rawItems.map((item) {
      final precioBase = double.tryParse(
              (item['precio_unitario'] ?? 0).toString()) ?? 0.0;
      final descItem   = double.tryParse(
              (item['descuento'] ?? 0).toString()) ?? 0.0;
      final cantNum    = double.tryParse(
              (item['cantidad'] ?? 1).toString()) ?? 1.0;
      final prod = Producto(
        id:        0,
        nombre:    item['producto_nombre']?.toString() ?? '',
        precio:    precioBase,
        categoria: '',
      );
      return ItemCarrito(
        producto:  prod,
        cantidad:  cantNum.round(),
        descuento: descItem,
      );
    }).toList();

    final factura       = detalle['numero_factura']?.toString() ?? '';
    final metodoPago    = detalle['metodo_pago']?.toString() ?? 'efectivo';
    final descuento     = double.tryParse((detalle['descuento_total'] ?? 0).toString()) ?? 0.0;
    final total         = double.tryParse((detalle['total'] ?? 0).toString()) ?? 0.0;
    final montoRecibido = double.tryParse((detalle['monto_recibido'] ?? 0).toString()) ?? 0.0;
    final vuelto        = double.tryParse((detalle['vuelto'] ?? 0).toString()) ?? 0.0;
    final cliente       = detalle['cliente_nombre']?.toString() ?? '';
    final empleado      = detalle['empleado_nombre']?.toString() ?? '';
    final tienda        = detalle['tienda_nombre']?.toString() ?? auth.tiendaNombre;
    final tipoPapel     = config.tipoPapel;
    final paperSize     = tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;

    // Obtener dispositivo ANTES de cerrar el diálogo para que el
    // gesto de usuario (click del botón) siga activo cuando se muestre
    // el selector WebUSB.
    ThermalDevice? thermalDevice;
    if (tipoPapel != 'pdf' && ThermalPrinterService.isWebUsbSupported) {
      thermalDevice = await ThermalPrinterService.getOrRequestDevice();
    }

    // Cerrar el diálogo después de obtener el dispositivo
    nav.pop();

    try {
      // ── WebUSB (solo web) ──────────────────────────────────────
      if (thermalDevice != null) {
        final bytes = await ThermalPrinterService.buildRecibo(
          items: items, numeroFactura: factura,
          tiendaNombre: tienda, empresaNombre: auth.empresaNombre,
          cajeroNombre: empleado, metodoPago: metodoPago,
          descuento: descuento, total: total,
          montoRecibido: montoRecibido, vuelto: vuelto,
          clienteNombre: cliente, paperSize: paperSize,
          esCopia: true,
        );
        await ThermalPrinterService.printBytes(thermalDevice, bytes);
        return;
      }

      // ── Windows ESC/POS RAW ────────────────────────────────────
      if (tipoPapel != 'pdf' && !kIsWeb &&
                 await WindowsPrinterService.hasSavedPrinter()) {
        final bytes = await ThermalPrinterService.buildRecibo(
          items: items, numeroFactura: factura,
          tiendaNombre: tienda, empresaNombre: auth.empresaNombre,
          cajeroNombre: empleado, metodoPago: metodoPago,
          descuento: descuento, total: total,
          montoRecibido: montoRecibido, vuelto: vuelto,
          clienteNombre: cliente, paperSize: paperSize,
          esCopia: true,
        );
        await WindowsPrinterService.printRaw(bytes);
        return;
      }

      // ── Sin impresora térmica: mostrar error en lugar de caer al PDF ──
      // (Evita que el PDF se imprima de lado en drivers de impresoras térmicas)
      if (tipoPapel != 'pdf') {
        final savedName = ThermalPrinterService.isWebUsbSupported
            ? await ThermalPrinterService.getSavedName()
            : null;
        final msg = savedName != null
            ? 'Impresora "$savedName" no encontrada. Verifica que esté conectada.'
            : 'No hay impresora configurada. Ve a Configuración → Impresión.';
        messenger.showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
        ));
        return;
      }

      // ── Fallback PDF (solo cuando tipoPapel == 'pdf') ──────────
      await ReciboPdfService.imprimirRecibo(
        items:         items,
        numeroFactura: factura,
        tiendaNombre:  tienda,
        empresaNombre: auth.empresaNombre,
        cajeroNombre:  empleado,
        metodoPago:    metodoPago,
        descuento:     descuento,
        total:         total,
        montoRecibido: montoRecibido,
        vuelto:        vuelto,
        clienteNombre: cliente,
        esCopia:       true,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error al reimprimir: $e'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

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
          child: Text('Cerrar', style: GoogleFonts.poppins()),
        ),
        if (detalle['estado'] != 'anulada')
          ElevatedButton.icon(
            onPressed: _reimprimir,
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text('Reimprimir',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
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