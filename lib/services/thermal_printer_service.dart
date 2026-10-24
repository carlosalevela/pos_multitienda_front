// lib/services/thermal_printer_service.dart
//
// Comunicación directa ESC/POS con impresoras térmicas USB vía WebUSB API.
// Chrome/Edge únicamente para la parte USB. En desktop (Windows/exe) la
// impresión va por el paquete Printing (PDF → diálogo del sistema).
//
// Flujo web:
//   1. ThermalPrinterService.requestDevice() → muestra picker USB del browser
//   2. El browser recuerda el permiso; getGrantedDevices() lo recupera sin diálogo
//   3. printBytes(dev, bytes) → envía bytes ESC/POS directo sin diálogo
//   4. kickDrawer(dev) → abre caja de dinero vía pulso ESC/POS

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contabilidad_models.dart';
import '../models/devolucion_model.dart';
import '../models/item_carrito.dart';
import '../models/separado.dart';
import '../models/sesion_caja.dart';
import '../models/sesion_historial.dart';

// Importación condicional: web usa WebUSB real; desktop usa stubs vacíos.
import 'thermal_usb_web.dart' if (dart.library.io) 'thermal_usb_stub.dart' as _impl;
export 'thermal_usb_web.dart' if (dart.library.io) 'thermal_usb_stub.dart' show ThermalDevice;

class ThermalPrinterService {
  ThermalPrinterService._();

  // ── Detección ─────────────────────────────────────────────

  static bool get isWebUsbSupported => _impl.isWebUsbSupported;

  // ── Dispositivos ──────────────────────────────────────────

  static Future<List<_impl.ThermalDevice>> getGrantedDevices() =>
      _impl.getGrantedDevices();

  static Future<_impl.ThermalDevice?> requestDevice() =>
      _impl.requestDevice();

  static Future<_impl.ThermalDevice?> getAutoDevice() =>
      _impl.getAutoDevice();

  static Future<String?> getSavedName() =>
      _impl.getSavedName();

  static Future<_impl.ThermalDevice?> getOrRequestDevice() =>
      _impl.getOrRequestDevice();

  static Future<void> clearSaved() =>
      _impl.clearSaved();

  // ── Impresión ─────────────────────────────────────────────

  static Future<void> printBytes(_impl.ThermalDevice dev, List<int> bytes) =>
      _impl.printBytes(dev, bytes);

  static Future<void> kickDrawer(_impl.ThermalDevice dev) =>
      _impl.kickDrawer(dev);

  // ── Preferencia caja de dinero ────────────────────────────

  static const _kHasCaja = 'thermal_has_drawer';

  static Future<bool> hasCashDrawer() async =>
      (await SharedPreferences.getInstance()).getBool(_kHasCaja) ?? false;

  /// Genera los bytes ESC/POS para abrir el cajón sin enviarlos.
  /// Útil para enviarlo por otro canal (ej. WindowsPrinterService).
  static Future<List<int>> buildDrawerBytes() async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(PaperSize.mm80, profile);
    return gen.drawer(pin: PosDrawer.pin2);
  }

  // ── Builder página de prueba ──────────────────────────────

  static Future<List<int>> buildTestPage() async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(PaperSize.mm80, profile);
    final now     = DateFormat('dd/MM/yyyy  HH:mm:ss').format(DateTime.now());

    return [
      ...gen.setGlobalCodeTable('CP850'),
      ...gen.text(
        'POS MULTITIENDA',
        styles: PosStyles(
          align:  PosAlign.center,
          bold:   true,
          height: PosTextSize.size2,
          width:  PosTextSize.size2,
        ),
      ),
      ...gen.emptyLines(1),
      ...gen.text(
        'PAGINA DE PRUEBA',
        styles: PosStyles(align: PosAlign.center, bold: true),
      ),
      ...gen.hr(),
      ...gen.text(now, styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.emptyLines(1),
      ...gen.text(
        'Impresora funcionando',
        styles: PosStyles(align: PosAlign.center, bold: true),
      ),
      ...gen.text(
        'correctamente',
        styles: PosStyles(align: PosAlign.center, bold: true),
      ),
      ...gen.emptyLines(1),
      ...gen.text('Texto normal',       styles: const PosStyles()),
      ...gen.text('TEXTO EN NEGRITA',   styles: PosStyles(bold: true)),
      ...gen.row([
        PosColumn(text: 'Columna 1', width: 6, styles: const PosStyles()),
        PosColumn(text: 'Col 2',     width: 6, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  /// Genera bytes ESC/POS para un comprobante de devolución / cambio.
  static Future<List<int>> buildComprobanteDevolucion({
    required DevolucionModel dev,
    required String          empresaNombre,
    PaperSize                paperSize = PaperSize.mm80,
  }) async {
    final profile  = await CapabilityProfile.load();
    final gen      = Generator(paperSize, profile);
    final fmt      = NumberFormat('#,##0', 'es_CO');
    final fecha    = DateFormat('dd/MM/yyyy').format(dev.createdAt);
    final hora     = DateFormat('HH:mm:ss').format(dev.createdAt);
    final esCambio = dev.tipo == 'cambio';
    final titulo   = esCambio ? 'COMPROBANTE DE CAMBIO' : 'COMPROBANTE DE DEVOLUCION';
    final devId    = 'DEV-${dev.id}';
    final cantReemplazo = dev.cantidadReemplazo ?? 0;
    final cantReemplazoStr = cantReemplazo % 1 == 0
        ? cantReemplazo.toStringAsFixed(0)
        : cantReemplazo.toStringAsFixed(2);

    final bytes = <int>[
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(empresaNombre.toUpperCase(),
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.text(dev.tiendaNombre,
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text(titulo,
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info comprobante ────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Comprobante:', width: 5, styles: const PosStyles()),
        PosColumn(text: devId, width: 7, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Fact. orig.:', width: 5, styles: const PosStyles()),
        PosColumn(text: dev.ventaNumero, width: 7, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Empleado:', width: 4, styles: const PosStyles()),
        PosColumn(text: dev.empleadoNombre, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Fecha:', width: 4, styles: const PosStyles()),
        PosColumn(text: fecha, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Hora:', width: 4, styles: const PosStyles()),
        PosColumn(text: hora, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Productos devueltos ─────────────────────────────────
      ...gen.text(esCambio ? 'PRODUCTOS RECIBIDOS' : 'PRODUCTOS DEVUELTOS',
        styles: PosStyles(bold: true)),
      ...gen.emptyLines(1),
      ...dev.detalles.expand((d) {
        final cantStr = d.cantidad % 1 == 0
            ? d.cantidad.toStringAsFixed(0)
            : d.cantidad.toStringAsFixed(2);
        return <int>[
          ...gen.text(d.productoNombre, styles: PosStyles(bold: true)),
          ...gen.row([
            PosColumn(text: '$cantStr x \$${fmt.format(d.precioUnitario)}', width: 8, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(d.subtotal)}', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
          ]),
          if (d.motivo.isNotEmpty)
            ...gen.text('Motivo: ${d.motivo}', styles: const PosStyles()),
        ];
      }),
      ...gen.hr(),

      // ── Producto entregado (solo cambio) ────────────────────
      if (esCambio && dev.productoReemplazoNombre != null) ...[
        ...gen.text('PRODUCTO ENTREGADO', styles: PosStyles(bold: true)),
        ...gen.text(dev.productoReemplazoNombre!, styles: PosStyles(bold: true)),
        if (dev.precioReemplazo != null)
          ...gen.row([
            PosColumn(text: '$cantReemplazoStr x \$${fmt.format(dev.precioReemplazo!)}', width: 8, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(dev.subtotalReemplazo ?? 0)}', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
          ]),
        ...gen.hr(),
      ],

      // ── Método y diferencia ─────────────────────────────────
      if (!esCambio)
        ...gen.row([
          PosColumn(text: 'Metodo:', width: 4, styles: const PosStyles()),
          PosColumn(text: _metodoLabel(dev.metodoDevolucion), width: 8,
              styles: PosStyles(align: PosAlign.right)),
        ]),
      if (esCambio && (dev.diferencia ?? 0) > 0) ...[
        ...gen.row([
          PosColumn(
            text: dev.tipoDiferencia == 'cobrar' ? 'Cobrado al cliente:' : 'Devuelto al cliente:',
            width: 8, styles: PosStyles(bold: true)),
          PosColumn(text: '\$${fmt.format(dev.diferencia!)}', width: 4,
              styles: PosStyles(align: PosAlign.right, bold: true)),
        ]),
        if (dev.metodoPagoDiferencia != null)
          ...gen.row([
            PosColumn(text: 'Metodo pago:', width: 5, styles: const PosStyles()),
            PosColumn(text: _metodoLabel(dev.metodoPagoDiferencia!), width: 7,
                styles: PosStyles(align: PosAlign.right)),
          ]),
      ],
      if (dev.observaciones.isNotEmpty)
        ...gen.text('Obs: ${dev.observaciones}'),
      ...gen.hr(),

      // ── Total ──────────────────────────────────────────────
      ...gen.row([
        PosColumn(text: esCambio ? 'VALOR RECONOCIDO' : 'TOTAL DEVUELTO',
          width: 7, styles: PosStyles(bold: true)),
        PosColumn(text: '\$${fmt.format(dev.totalDevuelto)}',
          width: 5, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Código de barras (Code 39) ──────────────────────────
      ...gen.emptyLines(1),
      ...gen.barcode(
        Barcode.code39(devId.split('')),
        width: 2,
        height: 80,
        textPos: BarcodeText.below,
      ),
      ...gen.emptyLines(1),

      // ── Footer ──────────────────────────────────────────────
      ...gen.emptyLines(1),
      ...gen.text(
        esCambio ? 'Gracias por elegirnos!' : 'Devolucion procesada exitosamente',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.text('Conserve este comprobante',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];

    return bytes;
  }

  static String _metodoLabel(String m) => switch (m) {
    'transferencia' => 'Transferencia',
    'tarjeta'       => 'Tarjeta',
    'nota_credito'  => 'Nota credito',
    _               => 'Efectivo',
  };

  // ── Builder recibo de venta ───────────────────────────────

  static Future<List<int>> buildRecibo({
    required List<ItemCarrito> items,
    required String            numeroFactura,
    required String            tiendaNombre,
    required String            empresaNombre,
    required String            cajeroNombre,
    required String            metodoPago,
    required double            descuento,
    required double            total,
    required double            montoRecibido,
    required double            vuelto,
    String                     nit           = '',
    String                     direccion     = '',
    String                     telefono      = '',
    String                     clienteNombre = '',
    PaperSize                  paperSize     = PaperSize.mm80,
    bool                       esCopia       = false,
  }) async {
    final profile    = await CapabilityProfile.load();
    final gen        = Generator(paperSize, profile);
    final fmt        = NumberFormat('#,##0', 'es_CO');
    final now        = DateTime.now();
    final fecha      = DateFormat('dd/MM/yyyy').format(now);
    final hora       = DateFormat('HH:mm:ss').format(now);
    final subtotal   = items.fold(0.0, (s, i) => s + i.subtotal);
    final totalItems = items.fold(0,   (s, i) => s + i.cantidad);

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ──────────────────────────────────────────
      ...gen.text(empresaNombre.toUpperCase(),
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.text(tiendaNombre, styles: PosStyles(align: PosAlign.center)),
      if (nit.isNotEmpty)
        ...gen.text('NIT: $nit', styles: PosStyles(align: PosAlign.center)),
      if (direccion.isNotEmpty)
        ...gen.text(direccion, styles: PosStyles(align: PosAlign.center)),
      if (telefono.isNotEmpty)
        ...gen.text('Tel: $telefono', styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text('FACTURA DE VENTA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info transaccion ────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'N Factura:', width: 5, styles: const PosStyles()),
        PosColumn(text: numeroFactura, width: 7, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Fecha:', width: 4, styles: const PosStyles()),
        PosColumn(text: fecha, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Hora:', width: 4, styles: const PosStyles()),
        PosColumn(text: hora, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Cajero:', width: 4, styles: const PosStyles()),
        PosColumn(text: cajeroNombre, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      if (clienteNombre.isNotEmpty)
        ...gen.row([
          PosColumn(text: 'Cliente:', width: 4, styles: const PosStyles()),
          PosColumn(text: clienteNombre, width: 8, styles: PosStyles(align: PosAlign.right)),
        ]),
      ...gen.hr(),

      // ── Cabecera productos ──────────────────────────────────
      ...gen.row([
        PosColumn(text: 'DESCRIPCION', width: 8, styles: PosStyles(bold: true)),
        PosColumn(text: 'TOTAL',       width: 4, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.emptyLines(1),

      // ── Items ───────────────────────────────────────────────
      ...items.expand((item) => [
        ...gen.text(item.producto.nombre, styles: PosStyles(bold: true)),
        ...gen.row([
          PosColumn(text: '${item.cantidad} x \$${fmt.format(item.precioUnitario)}',
            width: 8, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(item.subtotal)}',
            width: 4, styles: PosStyles(align: PosAlign.right)),
        ]),
        if (item.aplicaMayoreo)
          ...gen.text('* Precio mayoreo', styles: PosStyles(bold: true)),
      ]),
      ...gen.hr(),

      // ── Totales ─────────────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Articulos:', width: 7, styles: const PosStyles()),
        PosColumn(text: '$totalItems', width: 5, styles: PosStyles(align: PosAlign.right)),
      ]),
      if (descuento > 0) ...[
        ...gen.row([
          PosColumn(text: 'Subtotal:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(subtotal)}', width: 5, styles: PosStyles(align: PosAlign.right)),
        ]),
        ...gen.row([
          PosColumn(text: 'Descuento:', width: 7, styles: const PosStyles()),
          PosColumn(text: '-\$${fmt.format(descuento)}', width: 5, styles: PosStyles(align: PosAlign.right)),
        ]),
      ],
      ...gen.emptyLines(1),
      ...gen.row([
        PosColumn(text: 'TOTAL A PAGAR', width: 7, styles: PosStyles(bold: true)),
        PosColumn(text: '\$${fmt.format(total)}', width: 5,
          styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Pago ────────────────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Forma de pago:', width: 6, styles: const PosStyles()),
        PosColumn(text: _metodoLabel(metodoPago), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]),
      if (metodoPago == 'efectivo') ...[
        ...gen.row([
          PosColumn(text: 'Recibido:', width: 6, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(montoRecibido)}', width: 6, styles: PosStyles(align: PosAlign.right)),
        ]),
        ...gen.row([
          PosColumn(text: 'Vuelto:', width: 6, styles: PosStyles(bold: true)),
          PosColumn(text: '\$${fmt.format(vuelto)}', width: 6,
            styles: PosStyles(bold: true, align: PosAlign.right)),
        ]),
      ],
      ...gen.hr(),

      // ── Código de barras (Code 39) ──────────────────────────
      ...gen.emptyLines(1),
      ...gen.barcode(
        Barcode.code39(numeroFactura.toUpperCase().split('')),
        width: 2,
        height: 80,
        textPos: BarcodeText.below,
      ),
      ...gen.emptyLines(1),

      // ── Copia ───────────────────────────────────────────────
      if (esCopia) ...[
        ...gen.hr(),
        ...gen.text('**** COPIA DE RECIBO ****',
          styles: PosStyles(align: PosAlign.center, bold: true)),
      ],

      // ── Footer ──────────────────────────────────────────────
      ...gen.emptyLines(1),
      ...gen.text('Gracias por su compra!',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.text('Para cambios presente este recibo',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('en los proximos 30 dias.',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  // ── Factura completa de separado ──────────────────────────

  static Future<List<int>> buildSeparadoRecibo(
    Separado separado, {
    required String empresaNombre,
    PaperSize       paperSize = PaperSize.mm80,
  }) async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(paperSize, profile);
    final fmt     = NumberFormat('#,##0', 'es_CO');
    final fecha   = DateFormat('dd/MM/yyyy').format(separado.createdAt);
    final hora    = DateFormat('HH:mm').format(separado.createdAt);
    final sepId   = 'SEP-${separado.id}';

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(empresaNombre.toUpperCase(),
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.text(separado.tiendaNombre,
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text('SEPARADO DE MERCANCIA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info separado ──────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'No. Separado:', width: 6, styles: const PosStyles()),
        PosColumn(text: sepId, width: 6, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Fecha:', width: 4, styles: const PosStyles()),
        PosColumn(text: '$fecha  $hora', width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      if (separado.fechaLimite != null)
        ...gen.row([
          PosColumn(text: 'Limite pago:', width: 5, styles: const PosStyles()),
          PosColumn(text: _formatFechaLimite(separado.fechaLimite!), width: 7,
            styles: PosStyles(align: PosAlign.right, bold: true)),
        ]),
      if (separado.empleadoNombre != null)
        ...gen.row([
          PosColumn(text: 'Atiende:', width: 4, styles: const PosStyles()),
          PosColumn(text: separado.empleadoNombre!, width: 8,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      ...gen.hr(),

      // ── Cliente ────────────────────────────────────────────
      ...gen.text('CLIENTE', styles: PosStyles(bold: true)),
      ...gen.text(separado.clienteNombre, styles: const PosStyles()),
      if (separado.clienteCedulaNit != null && separado.clienteCedulaNit!.isNotEmpty)
        ...gen.text('C.C./NIT: ${separado.clienteCedulaNit}', styles: const PosStyles()),
      if (separado.clienteTelefono != null && separado.clienteTelefono!.isNotEmpty)
        ...gen.text('Tel: ${separado.clienteTelefono}', styles: const PosStyles()),
      ...gen.hr(),

      // ── Productos ──────────────────────────────────────────
      ...gen.text('PRODUCTOS (${separado.detalles.length})',
        styles: PosStyles(bold: true)),
      ...gen.emptyLines(1),
      ...separado.detalles.expand((d) {
        final cantStr = d.cantidad % 1 == 0
            ? d.cantidad.toStringAsFixed(0)
            : d.cantidad.toStringAsFixed(2);
        return <int>[
          ...gen.text(d.productoNombre, styles: PosStyles(bold: true)),
          ...gen.row([
            PosColumn(text: '$cantStr x \$${fmt.format(d.precioUnitario)}',
              width: 8, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(d.subtotal)}',
              width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
          ]),
        ];
      }),
      ...gen.hr(),
      ...gen.row([
        PosColumn(text: 'TOTAL SEPARADO', width: 7, styles: PosStyles(bold: true)),
        PosColumn(text: '\$${fmt.format(separado.total)}', width: 5,
          styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Abonos ─────────────────────────────────────────────
      if (separado.abonos.isNotEmpty) ...[
        ...gen.text('ABONOS REGISTRADOS', styles: PosStyles(bold: true)),
        ...gen.emptyLines(1),
        ...separado.abonos.expand((a) {
          final fechaAbono = DateFormat('dd/MM/yy').format(a.createdAt);
          return <int>[
            ...gen.row([
              PosColumn(text: '$fechaAbono ${_metodoLabel(a.metodoPago)}',
                width: 8, styles: const PosStyles()),
              PosColumn(text: '\$${fmt.format(a.monto)}',
                width: 4, styles: PosStyles(align: PosAlign.right)),
            ]),
          ];
        }),
        ...gen.hr(),
        ...gen.row([
          PosColumn(text: 'TOTAL ABONADO', width: 7, styles: PosStyles(bold: true)),
          PosColumn(text: '\$${fmt.format(separado.abonoAcumulado)}', width: 5,
            styles: PosStyles(bold: true, align: PosAlign.right)),
        ]),
      ],

      // ── Saldo ──────────────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'SALDO PENDIENTE', width: 7, styles: PosStyles(bold: true)),
        PosColumn(text: '\$${fmt.format(separado.saldoPendiente)}', width: 5,
          styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Código de barras ────────────────────────────────────
      ...gen.emptyLines(1),
      ...gen.barcode(
        Barcode.code39(sepId.split('')),
        width: 2, height: 80,
        textPos: BarcodeText.below,
      ),
      ...gen.emptyLines(1),

      // ── Footer ─────────────────────────────────────────────
      ...gen.text('Conserve este comprobante',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Presente este doc. al abonar o retirar',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Muchas gracias!',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  /// Genera bytes ESC/POS para el recibo compacto de un abono individual.
  static Future<List<int>> buildReciboAbono({
    required Separado separado,
    required double   monto,
    required String   metodoPago,
    required String   empresaNombre,
    PaperSize         paperSize = PaperSize.mm80,
  }) async {
    final profile    = await CapabilityProfile.load();
    final gen        = Generator(paperSize, profile);
    final fmt        = NumberFormat('#,##0', 'es_CO');
    final now        = DateTime.now();
    final fecha      = DateFormat('dd/MM/yyyy').format(now);
    final hora       = DateFormat('HH:mm:ss').format(now);
    final sepId      = 'SEP-${separado.id}';
    final nuevoSaldo = (separado.saldoPendiente - monto).clamp(0.0, double.infinity);

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(empresaNombre.toUpperCase(),
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.text(separado.tiendaNombre,
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text('RECIBO DE ABONO',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info ───────────────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Separado:', width: 5, styles: const PosStyles()),
        PosColumn(text: sepId, width: 7,
          styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Fecha:', width: 4, styles: const PosStyles()),
        PosColumn(text: fecha, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Hora:', width: 4, styles: const PosStyles()),
        PosColumn(text: hora, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Cliente ────────────────────────────────────────────
      ...gen.text('CLIENTE', styles: PosStyles(bold: true)),
      ...gen.text(separado.clienteNombre, styles: const PosStyles()),
      ...gen.hr(),

      // ── Monto abonado (grande al centro) ───────────────────
      ...gen.text('ABONO RECIBIDO',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(1),
      ...gen.text('\$${fmt.format(monto)}',
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.emptyLines(1),
      ...gen.row([
        PosColumn(text: 'Metodo:', width: 5, styles: const PosStyles()),
        PosColumn(text: _metodoLabel(metodoPago), width: 7,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Resumen saldo ──────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Total separado:', width: 7, styles: const PosStyles()),
        PosColumn(text: '\$${fmt.format(separado.total)}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Abono anterior:', width: 7, styles: const PosStyles()),
        PosColumn(text: '\$${fmt.format(separado.abonoAcumulado)}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Este abono:', width: 7, styles: const PosStyles()),
        PosColumn(text: '\$${fmt.format(monto)}', width: 5,
          styles: PosStyles(align: PosAlign.right, bold: true)),
      ]),
      ...gen.hr(),
      if (nuevoSaldo > 0)
        ...gen.row([
          PosColumn(text: 'NUEVO SALDO:', width: 7, styles: PosStyles(bold: true)),
          PosColumn(text: '\$${fmt.format(nuevoSaldo)}', width: 5,
            styles: PosStyles(bold: true, align: PosAlign.right)),
        ])
      else
        ...gen.text('SEPARADO COMPLETAMENTE PAGADO',
          styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Código de barras ────────────────────────────────────
      ...gen.emptyLines(1),
      ...gen.barcode(
        Barcode.code39(sepId.split('')),
        width: 2, height: 60,
        textPos: BarcodeText.below,
      ),
      ...gen.emptyLines(1),

      // ── Footer ─────────────────────────────────────────────
      ...gen.text('Conserve este recibo de abono',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Muchas gracias!',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  /// Genera bytes ESC/POS para el recibo de cierre de turno.
  static Future<List<int>> buildCierreTurno({
    required SesionCaja                  sesion,
    required String                      empresaNombre,
    required Map<String, double>         metodosPago,
    required double                      totalGastos,
    PaperSize                            paperSize      = PaperSize.mm80,
    List<Map<String, dynamic>>           resumenCuentas = const [],
    List<Map<String, dynamic>>           gastosSesion   = const [],
    List<TopProducto>                    topProductos   = const [],
    List<Map<String, dynamic>>           separadosDia   = const [],
  }) async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(paperSize, profile);
    final fmt     = NumberFormat('#,##0', 'es_CO');
    final fechaAp = DateFormat('dd/MM/yy HH:mm').format(sesion.fecha_apertura);
    final fechaCi = sesion.fecha_cierre != null
        ? DateFormat('dd/MM/yy HH:mm').format(sesion.fecha_cierre!)
        : '---';

    String _ml(String m) => switch (m) {
      'tarjeta'       => 'Tarjeta',
      'transferencia' => 'Transf.',
      'mixto'         => 'Mixto',
      'credito'       => 'Credito',
      _               => 'Efectivo',
    };

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(empresaNombre.toUpperCase(),
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.text(sesion.tiendaNombre,
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text('CIERRE DE CAJA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info sesión ────────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Sesion #:', width: 5, styles: const PosStyles()),
        PosColumn(text: '${sesion.id}', width: 7,
          styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Cajero:', width: 4, styles: const PosStyles()),
        PosColumn(text: sesion.empleadoNombre, width: 8,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Apertura:', width: 4, styles: const PosStyles()),
        PosColumn(text: fechaAp, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Cierre:', width: 4, styles: const PosStyles()),
        PosColumn(text: fechaCi, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Ventas por método ──────────────────────────────────
      ...gen.text('--- VENTAS DEL TURNO ---',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...metodosPago.entries
          .where((e) => e.value > 0)
          .expand((e) => gen.row([
            PosColumn(text: '${_ml(e.key)}:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(e.value)}', width: 6,
              styles: PosStyles(align: PosAlign.right, bold: true)),
          ])),
      ...gen.row([
        PosColumn(text: 'TOTAL VENTAS:', width: 7, styles: PosStyles(bold: true)),
        PosColumn(text: '\$${fmt.format(sesion.ventasTotal)}', width: 5,
          styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Transacciones:', width: 7, styles: const PosStyles()),
        PosColumn(text: '${sesion.numTransacciones}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Ingresos por cuenta ────────────────────────────────
      if (resumenCuentas.isNotEmpty) ...[
        ...gen.text('-- INGRESOS POR CUENTA --',
          styles: PosStyles(align: PosAlign.center, bold: true)),
        ...resumenCuentas.expand((c) {
          final nombre = c['nombre']?.toString() ?? '—';
          final tipo   = c['tipo_display']?.toString() ?? '';
          final turno  = double.tryParse(c['sesion_total']?.toString() ?? '0') ?? 0;
          return [
            ...gen.row([
              PosColumn(text: nombre, width: 7, styles: const PosStyles()),
              PosColumn(text: '\$${fmt.format(turno)}', width: 5,
                styles: PosStyles(align: PosAlign.right, bold: true)),
            ]),
            if (tipo.isNotEmpty)
              ...gen.text('  $tipo', styles: const PosStyles()),
          ];
        }),
        ...gen.hr(),
      ],

      // ── Abonos de separados ────────────────────────────────
      if (sesion.abonosTotal > 0) ...[
        ...gen.text('---- ABONOS SEPARADOS ----',
          styles: PosStyles(align: PosAlign.center, bold: true)),
        if (sesion.abonosEfectivo > 0)
          ...gen.row([
            PosColumn(text: 'Efectivo:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(sesion.abonosEfectivo)}', width: 6,
              styles: PosStyles(align: PosAlign.right)),
          ]),
        if (sesion.abonosTarjeta > 0)
          ...gen.row([
            PosColumn(text: 'Tarjeta:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(sesion.abonosTarjeta)}', width: 6,
              styles: PosStyles(align: PosAlign.right)),
          ]),
        if (sesion.abonosTransferencia > 0)
          ...gen.row([
            PosColumn(text: 'Transf.:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(sesion.abonosTransferencia)}', width: 6,
              styles: PosStyles(align: PosAlign.right)),
          ]),
        ...gen.row([
          PosColumn(text: 'TOTAL ABONOS:', width: 7, styles: PosStyles(bold: true)),
          PosColumn(text: '\$${fmt.format(sesion.abonosTotal)}', width: 5,
            styles: PosStyles(bold: true, align: PosAlign.right)),
        ]),
        ...gen.row([
          PosColumn(text: '(${sesion.numAbonos} abono${sesion.numAbonos != 1 ? "s" : ""})',
            width: 12, styles: PosStyles(align: PosAlign.center)),
        ]),
        ...gen.hr(),
      ],

      // ── Gastos ─────────────────────────────────────────────
      if (totalGastos > 0) ...[
        ...gen.text('----- GASTOS DEL TURNO -----',
          styles: PosStyles(align: PosAlign.center, bold: true)),
        ...gastosSesion.expand((g) {
          final cat   = g['categoria']?.toString()   ?? '—';
          final desc  = g['descripcion']?.toString() ?? '';
          final monto = double.tryParse(g['monto']?.toString() ?? '0') ?? 0;
          final label = desc.isNotEmpty ? '$cat: $desc' : cat;
          return gen.row([
            PosColumn(text: label.length > 18 ? '${label.substring(0, 17)}.' : label,
              width: 7, styles: const PosStyles()),
            PosColumn(text: '-\$${fmt.format(monto)}', width: 5,
              styles: PosStyles(align: PosAlign.right)),
          ]);
        }),
        ...gen.row([
          PosColumn(text: 'TOTAL GASTOS:', width: 7, styles: PosStyles(bold: true)),
          PosColumn(text: '-\$${fmt.format(totalGastos)}', width: 5,
            styles: PosStyles(bold: true, align: PosAlign.right)),
        ]),
        ...gen.hr(),
      ],

      // ── Top productos ──────────────────────────────────────
      if (topProductos.isNotEmpty) ...[
        ...gen.text('----- TOP PRODUCTOS ------',
          styles: PosStyles(align: PosAlign.center, bold: true)),
        ...topProductos.take(5).toList().asMap().entries.expand((entry) {
          final i = entry.key + 1;
          final p = entry.value;
          return [
            ...gen.text('$i. ${p.producto}',
              styles: const PosStyles(bold: true)),
            ...gen.row([
              PosColumn(text: '   ${p.totalVendido.toStringAsFixed(0)} uds.',
                width: 6, styles: const PosStyles()),
              PosColumn(text: '\$${fmt.format(p.totalIngresos)}', width: 6,
                styles: PosStyles(align: PosAlign.right)),
            ]),
          ];
        }),
        ...gen.hr(),
      ],

      // ── Separados del día ──────────────────────────────────
      if (separadosDia.isNotEmpty) ...[
        ...gen.text('---- SEPARADOS DEL DIA ---',
          styles: PosStyles(align: PosAlign.center, bold: true)),
        ...separadosDia.expand((s) {
          final cliente = s['cliente_nombre']?.toString() ?? '—';
          final total   = double.tryParse(s['total']?.toString()           ?? '0') ?? 0;
          final abonado = double.tryParse(s['abono_acumulado']?.toString() ?? '0') ?? 0;
          final saldo   = double.tryParse(s['saldo_pendiente']?.toString() ?? '0') ?? 0;
          final estado  = (s['estado']?.toString() ?? 'pendiente').toUpperCase();
          return [
            ...gen.text(cliente, styles: const PosStyles(bold: true)),
            ...gen.row([
              PosColumn(text: 'Total:', width: 3, styles: const PosStyles()),
              PosColumn(text: '\$${fmt.format(total)}', width: 4,
                styles: PosStyles(align: PosAlign.right)),
              PosColumn(text: 'Abono:', width: 3, styles: const PosStyles()),
              PosColumn(text: '\$${fmt.format(abonado)}', width: 2,
                styles: PosStyles(align: PosAlign.right)),
            ]),
            ...gen.row([
              PosColumn(text: 'Saldo:', width: 4, styles: const PosStyles()),
              PosColumn(text: '\$${fmt.format(saldo)}', width: 4,
                styles: PosStyles(align: PosAlign.right)),
              PosColumn(text: estado, width: 4,
                styles: PosStyles(align: PosAlign.right, bold: true)),
            ]),
          ];
        }),
        ...gen.hr(),
      ],

      // ── Balance / Efectivo esperado ────────────────────────
      ...gen.text('------- BALANCE ---------',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.row([
        PosColumn(text: 'Fondo inicial:', width: 7, styles: const PosStyles()),
        PosColumn(text: '\$${fmt.format(sesion.saldo_inicial)}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Transacciones:', width: 7, styles: const PosStyles()),
        PosColumn(text: '${sesion.numTransacciones}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Efectivo esperado (destacado) ──────────────────────
      ...gen.text('EFECTIVO ESPERADO EN CAJA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(1),
      ...gen.text('\$${fmt.format(sesion.montoEsperado)}',
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.hr(),

      // ── Footer ─────────────────────────────────────────────
      ...gen.emptyLines(1),
      ...gen.text('Cierre procesado exitosamente',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  /// Genera bytes ESC/POS para el comprobante de cierre de caja con datos completos
  /// (montoFinalReal, diferencia, desglose por método, etc.).
  static Future<List<int>> buildCierreHistorial({
    required SesionHistorial sesion,
    PaperSize                paperSize = PaperSize.mm80,
  }) async {
    final profile  = await CapabilityProfile.load();
    final gen      = Generator(paperSize, profile);
    final fmt      = NumberFormat('#,##0', 'es_CO');
    final fechaAp  = _parseFechaHoraISO(sesion.fechaApertura);
    final fechaCi  = _parseFechaHoraISO(sesion.fechaCierre);
    final difAbs   = sesion.diferencia.abs();
    final difLabel = difAbs < 0.01
        ? 'CUADRE EXACTO'
        : sesion.diferencia > 0 ? 'SOBRANTE' : 'FALTANTE';

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(sesion.tiendaNombre.toUpperCase(),
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.hr(),
      ...gen.text('CIERRE DE CAJA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info sesión ────────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Sesion #:', width: 5, styles: const PosStyles()),
        PosColumn(text: '${sesion.id}', width: 7,
          styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Cajero:', width: 4, styles: const PosStyles()),
        PosColumn(text: sesion.empleadoNombre, width: 8,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Apertura:', width: 4, styles: const PosStyles()),
        PosColumn(text: fechaAp, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: 'Cierre:', width: 4, styles: const PosStyles()),
        PosColumn(text: fechaCi, width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Ventas ─────────────────────────────────────────────
      ...gen.text('VENTAS  (${sesion.numTransacciones} transacciones)',
        styles: PosStyles(bold: true)),
      if (sesion.ventasEfectivo > 0)
        ...gen.row([
          PosColumn(text: '  Efectivo:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.ventasEfectivo)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      if (sesion.ventasTarjeta > 0)
        ...gen.row([
          PosColumn(text: '  Tarjeta:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.ventasTarjeta)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      if (sesion.ventasTransferencia > 0)
        ...gen.row([
          PosColumn(text: '  Transferencia:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.ventasTransferencia)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      if (sesion.ventasMixtoEfectivo > 0)
        ...gen.row([
          PosColumn(text: '  Mixto (ef.):', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.ventasMixtoEfectivo)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      ...gen.row([
        PosColumn(text: 'TOTAL VENTAS:', width: 7, styles: PosStyles(bold: true)),
        PosColumn(text: '\$${fmt.format(sesion.ventasTotal)}', width: 5,
          styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Apartados / Abonos ─────────────────────────────────
      if (sesion.abonosTotal > 0) ...[
        ...gen.text('APARTADOS  (${sesion.numAbonos} folios)',
          styles: PosStyles(bold: true)),
        if (sesion.abonosEfectivo > 0)
          ...gen.row([
            PosColumn(text: '  Efectivo:', width: 7, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(sesion.abonosEfectivo)}', width: 5,
              styles: PosStyles(align: PosAlign.right)),
          ]),
        if (sesion.abonosTarjeta > 0)
          ...gen.row([
            PosColumn(text: '  Tarjeta:', width: 7, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(sesion.abonosTarjeta)}', width: 5,
              styles: PosStyles(align: PosAlign.right)),
          ]),
        if (sesion.abonosTransferencia > 0)
          ...gen.row([
            PosColumn(text: '  Transferencia:', width: 7, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(sesion.abonosTransferencia)}', width: 5,
              styles: PosStyles(align: PosAlign.right)),
          ]),
        ...gen.row([
          PosColumn(text: 'TOTAL APARTADOS:', width: 7, styles: PosStyles(bold: true)),
          PosColumn(text: '\$${fmt.format(sesion.abonosTotal)}', width: 5,
            styles: PosStyles(bold: true, align: PosAlign.right)),
        ]),
        ...gen.hr(),
      ],

      // ── Abonos Cartera (crédito) ───────────────────────────
      if (sesion.abonosCreditoEfectivo > 0) ...[
        ...gen.text('ABONOS CARTERA', styles: PosStyles(bold: true)),
        ...gen.row([
          PosColumn(text: '  Efectivo:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.abonosCreditoEfectivo)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
        ...gen.hr(),
      ],

      // ── Gastos ─────────────────────────────────────────────
      if (sesion.gastosTotal > 0) ...[
        ...gen.text('GASTOS', styles: PosStyles(bold: true)),
        ...gen.row([
          PosColumn(text: '  Total gastos:', width: 7, styles: const PosStyles()),
          PosColumn(text: '-\$${fmt.format(sesion.gastosTotal)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
        ...gen.hr(),
      ],

      // ── Devoluciones ───────────────────────────────────────
      if (sesion.numDevoluciones > 0) ...[
        ...gen.text('DEVOLUCIONES', styles: PosStyles(bold: true)),
        if (sesion.numDevoluciones - sesion.numCambiosProducto > 0) ...[
          ...gen.row([
            PosColumn(text: '  En efectivo:', width: 7, styles: const PosStyles()),
            PosColumn(
              text: '${sesion.numDevoluciones - sesion.numCambiosProducto} (-\$${fmt.format(sesion.devolucionesEfectivo)})',
              width: 5, styles: PosStyles(align: PosAlign.right)),
          ]),
        ],
        if (sesion.numCambiosProducto > 0)
          ...gen.row([
            PosColumn(text: '  Cambios:', width: 7, styles: const PosStyles()),
            PosColumn(text: '${sesion.numCambiosProducto}', width: 5,
              styles: PosStyles(align: PosAlign.right)),
          ]),
        ...gen.hr(),
      ],

      // ── Saldo inicial ──────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Saldo inicial:', width: 7, styles: const PosStyles()),
        PosColumn(text: '\$${fmt.format(sesion.saldoInicial)}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Arqueo ─────────────────────────────────────────────
      ...gen.text('EFECTIVO EN SISTEMA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.text('\$${fmt.format(sesion.montoFinalSistema)}',
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.emptyLines(1),
      ...gen.text('EFECTIVO CONTADO',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.text('\$${fmt.format(sesion.montoFinalReal)}',
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.hr(),

      // ── Diferencia ─────────────────────────────────────────
      ...gen.text(difLabel,
        styles: PosStyles(align: PosAlign.center, bold: true)),
      if (difAbs >= 0.01)
        ...gen.text('${sesion.diferencia > 0 ? '+' : '-'}\$${fmt.format(difAbs)}',
          styles: PosStyles(align: PosAlign.center, bold: true,
            height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.hr(),

      // ── Observaciones ──────────────────────────────────────
      if (sesion.observaciones.isNotEmpty) ...[
        ...gen.text('Obs: ${sesion.observaciones}',
          styles: const PosStyles()),
        ...gen.hr(),
      ],

      // ── Footer ─────────────────────────────────────────────
      ...gen.emptyLines(1),
      ...gen.text('Cierre procesado exitosamente',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  static String _parseFechaHoraISO(String iso) {
    try {
      final dt = DateTime.parse(iso.replaceAll(' ', 'T')).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
             '${dt.month.toString().padLeft(2, '0')}/'
             '${dt.year}  '
             '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length >= 16 ? iso.substring(0, 16) : iso;
    }
  }

  static String _formatFechaLimite(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
