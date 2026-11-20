// lib/screens/reportes/widgets/reporte_detalle_dialog.dart

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
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

const _kVerde = Color(0xFF006C49);

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
    // Extraer desglose bono desde los pagos registrados
    final pagosR   = (detalle['pagos'] as List? ?? []).cast<Map<String, dynamic>>();
    double montoBono    = 0;
    double faltanteBono = 0;
    double efeRecibido  = montoRecibido;
    if (metodoPago.startsWith('bono')) {
      for (final p in pagosR) {
        final m = p['metodo']?.toString() ?? '';
        final v = double.tryParse(p['monto']?.toString() ?? '0') ?? 0;
        if (m == 'bono') montoBono = v;
        else faltanteBono = v;
      }
      if (metodoPago == 'bono_efectivo') efeRecibido = montoRecibido;
    }
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
          montoRecibido: efeRecibido, vuelto: vuelto,
          nit: config.nit, direccion: config.direccion, telefono: config.telefono,
          clienteNombre: cliente, paperSize: paperSize,
          montoBono: montoBono, faltanteBono: faltanteBono,
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
          montoRecibido: efeRecibido, vuelto: vuelto,
          nit: config.nit, direccion: config.direccion, telefono: config.telefono,
          clienteNombre: cliente, paperSize: paperSize,
          montoBono: montoBono, faltanteBono: faltanteBono,
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
        montoRecibido: efeRecibido,
        vuelto:        vuelto,
        montoBono:     montoBono,
        faltanteBono:  faltanteBono,
        nit:           config.nit,
        direccion:     config.direccion,
        telefono:      config.telefono,
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
    final factura     = detalle['numero_factura']?.toString() ?? '';
    final estado      = detalle['estado']?.toString() ?? '';
    final cliente     = detalle['cliente_nombre']?.toString() ?? 'Consumidor Final';
    final empleado    = detalle['empleado_nombre']?.toString() ?? '';
    final tienda      = detalle['tienda_nombre']?.toString() ?? '';
    final metodo      = detalle['metodo_pago']?.toString() ?? '';
    final subtotal    = double.tryParse(detalle['subtotal']?.toString() ?? '0') ?? 0;
    final descuento   = double.tryParse(detalle['descuento_total']?.toString() ?? '0') ?? 0;
    final total       = double.tryParse(detalle['total']?.toString() ?? '0') ?? 0;
    final recibido    = double.tryParse(detalle['monto_recibido']?.toString() ?? '0') ?? 0;
    final vuelto      = double.tryParse(detalle['vuelto']?.toString() ?? '0') ?? 0;
    final obs         = detalle['observaciones']?.toString() ?? '';
    final items       = (detalle['detalles'] as List? ?? []).cast<Map<String, dynamic>>();
    final pagos       = (detalle['pagos'] as List? ?? []).cast<Map<String, dynamic>>();
    final esBonoParcial = metodo.startsWith('bono_');

    // Fecha formateada
    String fechaStr = '';
    final rawFecha = detalle['created_at']?.toString();
    if (rawFecha != null && rawFecha.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawFecha).toLocal();
        fechaStr =
            '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'
            '  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) {}
    }

    // Agrupar items por categoría
    final porCategoria = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final cat = item['categoria_nombre']?.toString().trim();
      final key = (cat == null || cat.isEmpty) ? 'Sin categoría' : cat;
      porCategoria.putIfAbsent(key, () => []).add(item);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FBF9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE6E8EA))),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kVerde.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: _kVerde, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(factura,
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF1A2E1F),
                          fontWeight: FontWeight.w700,
                          fontSize: 17)),
                  if (fechaStr.isNotEmpty)
                    Text(fechaStr,
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF9CA3AF), fontSize: 11)),
                ],
              )),
              const SizedBox(width: 10),
              estadoBadge(estado),
            ]),
          ),

          // ── Cuerpo scrollable ────────────────────────────────────
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [

              // ── Información de la venta ─────────────────────────
              _seccion('Información de la venta'),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6E8EA)),
                ),
                child: Column(children: [
                  _filaInfo(Icons.person_rounded,   'Cliente',        cliente),
                  _divFila(),
                  _filaInfo(Icons.badge_rounded,    'Empleado',       empleado),
                  _divFila(),
                  _filaInfo(Icons.store_rounded,    'Tienda',         tienda),
                  _divFila(),
                  _filaInfo(iconMetodo(metodo),     'Método de pago', labelMetodo(metodo)),
                  if (obs.isNotEmpty) ...[
                    _divFila(),
                    _filaInfo(Icons.notes_rounded,  'Observaciones',  obs),
                  ],
                ]),
              ),
              const SizedBox(height: 18),

              // ── Resumen financiero ───────────────────────────────
              _seccion('Resumen financiero'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6E8EA)),
                ),
                child: Column(children: [
                  if (descuento > 0) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Column(children: [
                        _filaTotal('Subtotal', subtotal),
                        const SizedBox(height: 4),
                        _filaTotal('Descuento', -descuento,
                            color: Colors.orange.shade700),
                      ]),
                    ),
                    const Divider(height: 1, color: Color(0xFFE6E8EA)),
                  ],
                  // TOTAL destacado
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: _kVerde.withValues(alpha: .06),
                      borderRadius: descuento > 0
                          ? BorderRadius.zero
                          : const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(children: [
                      Expanded(child: Text('TOTAL',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: _kVerde))),
                      Text('\$${fmtNum(total)}',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: _kVerde)),
                    ]),
                  ),
                  const Divider(height: 1, color: Color(0xFFE6E8EA)),
                  // Pago recibido / vuelto
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(children: [
                      if (esBonoParcial && pagos.isNotEmpty) ...[
                        // Desglose: una fila por cada pago registrado
                        ...pagos.map((p) {
                          final pMetodo = p['metodo']?.toString() ?? '';
                          final pMonto  = double.tryParse(p['monto']?.toString() ?? '0') ?? 0;
                          final label   = switch (pMetodo) {
                            'bono'          => 'Bono',
                            'efectivo'      => 'Efectivo',
                            'tarjeta'       => 'Tarjeta',
                            'transferencia' => 'Transferencia',
                            _               => pMetodo,
                          };
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _filaTotal(label, pMonto),
                          );
                        }),
                        if (vuelto > 0) ...[
                          const SizedBox(height: 2),
                          _filaTotal('Cambio / vuelto', vuelto,
                              color: Colors.green.shade700),
                        ],
                        // Saldo restante del bono después del pago parcial
                        () {
                          final bi = detalle['bono_info'] as Map<String, dynamic>?;
                          if (bi == null) return const SizedBox.shrink();
                          final saldoDespues = double.tryParse(bi['saldo_despues']?.toString() ?? '0') ?? 0;
                          final codigo       = bi['codigo']?.toString() ?? '';
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Divider(height: 12, color: Color(0xFFE6E8EA)),
                            if (codigo.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('Bono: $codigo',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: const Color(0xFF6B7280))),
                              ),
                            _filaTotal('Saldo restante bono', saldoDespues,
                                color: Colors.blue.shade700),
                          ]);
                        }(),
                      ] else if (metodo == 'bono') ...[
                        // Pago puro con bono: mostrar saldo usado y restante
                        () {
                          final bi = detalle['bono_info'] as Map<String, dynamic>?;
                          final montoUsado   = bi != null ? (double.tryParse(bi['monto_usado']?.toString() ?? '0') ?? 0) : recibido;
                          final saldoDespues = bi != null ? (double.tryParse(bi['saldo_despues']?.toString() ?? '0') ?? 0) : 0.0;
                          final codigo       = bi?['codigo']?.toString() ?? '';
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (codigo.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('Bono: $codigo',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: const Color(0xFF6B7280))),
                              ),
                            _filaTotal('Bono utilizado', montoUsado),
                            const SizedBox(height: 4),
                            _filaTotal('Saldo restante', saldoDespues,
                                color: Colors.blue.shade700),
                          ]);
                        }(),
                      ] else if (metodo == 'mixto' && pagos.isNotEmpty) ...[
                        ...pagos.map((p) {
                          final pMetodo = p['metodo']?.toString() ?? '';
                          final pMonto  = double.tryParse(p['monto']?.toString() ?? '0') ?? 0;
                          final label   = switch (pMetodo) {
                            'efectivo'      => 'Efectivo',
                            'tarjeta'       => 'Tarjeta',
                            'transferencia' => 'Transferencia',
                            _               => pMetodo,
                          };
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _filaTotal(label, pMonto),
                          );
                        }),
                        if (vuelto > 0) ...[
                          const SizedBox(height: 2),
                          _filaTotal('Cambio / vuelto', vuelto,
                              color: Colors.green.shade700),
                        ],
                      ] else ...[
                        _filaTotal('Recibido', recibido),
                        if (vuelto > 0) ...[
                          const SizedBox(height: 4),
                          _filaTotal('Cambio / vuelto', vuelto,
                              color: Colors.green.shade700),
                        ],
                      ],
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 18),

              // ── Productos ────────────────────────────────────────
              _seccion('Productos (${items.length} ${items.length == 1 ? "item" : "items"})'),
              ...porCategoria.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 6, top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFB2DFCF)),
                    ),
                    child: Text(entry.key,
                        style: GoogleFonts.poppins(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: _kVerde, letterSpacing: .4)),
                  ),
                  ...entry.value.map((item) {
                    final nombre     = item['producto_nombre']?.toString() ?? '';
                    final cant       = double.tryParse(
                        item['cantidad']?.toString() ?? '1') ?? 1;
                    final precioUnit = double.tryParse(
                        item['precio_unitario']?.toString() ?? '0') ?? 0;
                    final descItem   = double.tryParse(
                        item['descuento']?.toString() ?? '0') ?? 0;
                    final subItem    = double.tryParse(
                        item['subtotal']?.toString() ?? '0') ?? 0;
                    final cantStr = cant == cant.roundToDouble()
                        ? cant.toInt().toString() : cant.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE6E8EA)),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(height: 3),
                            Row(children: [
                              Text('$cantStr uds × \$${fmtNum(precioUnit)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF76777D))),
                              if (descItem > 0) ...[
                                const SizedBox(width: 6),
                                Text('−\$${fmtNum(descItem)} desc.',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.orange.shade700)),
                              ],
                            ]),
                          ],
                        )),
                        const SizedBox(width: 10),
                        Text('\$${fmtNum(subItem)}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13, color: _kVerde)),
                      ]),
                    );
                  }),
                ],
              )),
              const SizedBox(height: 4),
            ]),
          )),

          // ── Acciones ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE6E8EA))),
            ),
            child: Row(children: [
              Expanded(child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE6E8EA))),
                ),
                child: Text('Cerrar',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF45464D))),
              )),
              if (estado != 'anulada') ...[
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: _reimprimir,
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text('Reimprimir',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kVerde,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                )),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(titulo.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF), letterSpacing: .9)),
  );

  Widget _divFila() => const Divider(
      height: 1, indent: 38, color: Color(0xFFEEF0F2));

  Widget _filaInfo(IconData icon, String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: const Color(0xFFADB5BD)),
      const SizedBox(width: 10),
      Expanded(
        flex: 5,
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, color: const Color(0xFF9CA3AF))),
      ),
      Expanded(
        flex: 6,
        child: Text(valor,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: const Color(0xFF1A2E1F))),
      ),
    ]),
  );

  Widget _filaTotal(String label, double valor,
      {Color? color, bool bold = false, double size = 12}) =>
    Row(children: [
      Expanded(child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: size,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: color ?? const Color(0xFF45464D)))),
      Text('${valor < 0 ? '−' : ''}\$${fmtNum(valor.abs())}',
          style: GoogleFonts.poppins(
              fontSize: size,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? const Color(0xFF191C1E))),
    ]);
}