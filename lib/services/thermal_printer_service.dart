// lib/services/thermal_printer_service.dart
//
// Comunicación directa ESC/POS con impresoras térmicas USB vía WebUSB API.
// Chrome/Edge únicamente. Firefox/Safari no soportan WebUSB.
//
// Flujo:
//   1. ThermalPrinterService.requestDevice() → muestra picker USB del browser
//   2. El browser recuerda el permiso; getGrantedDevices() lo recupera sin diálogo
//   3. printBytes(dev, bytes) → envía bytes ESC/POS directo sin diálogo
//   4. kickDrawer(dev) → abre caja de dinero vía pulso ESC/POS

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/devolucion_model.dart';
import '../models/item_carrito.dart';
import '../models/separado.dart';

// ─── WebUSB JS bindings ───────────────────────────────────────
// Accede a window.navigator.usb vía la ruta global de dart:js_interop

@JS('navigator.usb')
external JSAny? get _usbRaw;

extension type _USB._(JSObject _) implements JSObject {
  external JSPromise<JSArray<_UsbDev>> getDevices();
  external JSPromise<_UsbDev> requestDevice(JSObject options);
}

extension type _UsbDev._(JSObject _) implements JSObject {
  external String  get productName;
  external String? get manufacturerName;
  external int     get vendorId;
  external int     get productId;
  external JSPromise<JSAny?> open();
  external JSPromise<JSAny?> close();
  external JSPromise<JSAny?> selectConfiguration(int v);
  external JSPromise<JSAny?> claimInterface(int n);
  external JSPromise<JSAny?> releaseInterface(int n);
  external JSPromise<JSObject> transferOut(int ep, JSUint8Array data);
}

// ─── Modelo público ───────────────────────────────────────────

class ThermalDevice {
  final String   name;
  final String   manufacturer;
  final int      vendorId;
  final int      productId;
  // ignore: library_private_types_in_public_api
  final _UsbDev _raw;

  ThermalDevice._({
    required this.name,
    required this.manufacturer,
    required this.vendorId,
    required this.productId,
    required _UsbDev raw,
  }) : _raw = raw;

  String get displayName => name.isNotEmpty
      ? name
      : '${vendorId.toRadixString(16).padLeft(4, '0')}:'
        '${productId.toRadixString(16).padLeft(4, '0')}';
}

// ─── Servicio ─────────────────────────────────────────────────

class ThermalPrinterService {
  ThermalPrinterService._();

  static const _kVid  = 'thermal_vid';
  static const _kPid  = 'thermal_pid';
  static const _kName = 'thermal_name';

  // ── Detección ─────────────────────────────────────────────

  static bool get isWebUsbSupported {
    if (!kIsWeb) return false;
    try { return _usbRaw != null; } catch (_) { return false; }
  }

  static _USB? get _usb {
    final raw = _usbRaw;
    if (raw == null) return null;
    return _USB._(raw as JSObject);
  }

  // ── Dispositivos ──────────────────────────────────────────

  /// Devuelve los dispositivos que el usuario ya aprobó (sin diálogo).
  static Future<List<ThermalDevice>> getGrantedDevices() async {
    final usb = _usb;
    if (usb == null) return [];
    try {
      final arr = await usb.getDevices().toDart;
      return arr.toDart.map(_fromRaw).toList();
    } catch (_) {
      return [];
    }
  }

  /// Muestra el picker USB del navegador para seleccionar una impresora.
  /// Filtra por clase USB 7 (impresoras).
  /// Retorna null si el usuario cancela.
  static Future<ThermalDevice?> requestDevice() async {
    final usb = _usb;
    if (usb == null) return null;
    try {
      final filter = JSObject();
      filter['classCode'] = 7.toJS;        // USB printer class
      final opts = JSObject();
      opts['filters'] = [filter].toJS;

      final raw = await usb.requestDevice(opts).toDart;
      final dev = _fromRaw(raw);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kVid, dev.vendorId);
      await prefs.setInt(_kPid, dev.productId);
      await prefs.setString(_kName, dev.displayName);
      return dev;
    } catch (_) {
      return null; // usuario canceló
    }
  }

  /// Auto-recupera el dispositivo guardado de los dispositivos aprobados.
  static Future<ThermalDevice?> getAutoDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVid = prefs.getInt(_kVid);
    final savedPid = prefs.getInt(_kPid);
    if (savedVid == null || savedPid == null) return null;

    final devices = await getGrantedDevices();
    try {
      return devices.firstWhere(
        (d) => d.vendorId == savedVid && d.productId == savedPid,
      );
    } catch (_) {
      return devices.isNotEmpty ? devices.first : null;
    }
  }

  static Future<String?> getSavedName() async =>
      (await SharedPreferences.getInstance()).getString(_kName);

  /// Igual que [getAutoDevice] pero, si el permiso de Chrome venció
  /// (HTTP no persiste entre sesiones), llama a [requestDevice]
  /// para re-autorizarlo sin que el usuario tenga que ir a Configuración.
  static Future<ThermalDevice?> getOrRequestDevice() async {
    // 1. Intento normal
    final dev = await getAutoDevice();
    if (dev != null) return dev;

    // 2. ¿Hay una impresora guardada pero sin permiso activo?
    final prefs = await SharedPreferences.getInstance();
    final savedVid = prefs.getInt(_kVid);
    if (savedVid == null) return null; // Sin configurar → no hacer nada

    // 3. Re-pedir permiso (válido porque venimos de un gesto del usuario)
    return requestDevice();
  }

  static Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kVid);
    await prefs.remove(_kPid);
    await prefs.remove(_kName);
  }

  // ── Impresión ─────────────────────────────────────────────

  /// Envía bytes ESC/POS directo al dispositivo USB.
  /// Intenta interfaz 0; si falla, intenta interfaz 1.
  static Future<void> printBytes(ThermalDevice dev, List<int> bytes) async {
    final d = dev._raw;
    await d.open().toDart;

    int iface = 0;
    try {
      await d.selectConfiguration(1).toDart;
      try {
        await d.claimInterface(0).toDart;
      } catch (_) {
        await d.claimInterface(1).toDart;
        iface = 1;
      }
      await d.transferOut(1, Uint8List.fromList(bytes).toJS).toDart;
    } finally {
      try { await d.releaseInterface(iface).toDart; } catch (_) {}
      try { await d.close().toDart; } catch (_) {}
    }
  }

  /// Abre la caja de dinero conectada al puerto RJ-11 de la impresora.
  static Future<void> kickDrawer(ThermalDevice dev) async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(PaperSize.mm80, profile);
    await printBytes(dev, gen.drawer(pin: PosDrawer.pin2));
  }

  /// Genera una página de prueba en formato ESC/POS 80 mm.
  static Future<List<int>> buildTestPage() async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(PaperSize.mm80, profile);
    final now     = DateFormat('dd/MM/yyyy  HH:mm:ss').format(DateTime.now());

    return [
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
      ...gen.row([
        PosColumn(text: 'Metodo:', width: 4, styles: const PosStyles()),
        PosColumn(text: _metodoLabel(dev.metodoDevolucion), width: 8, styles: PosStyles(align: PosAlign.right)),
      ]),
      if (esCambio && (dev.diferencia ?? 0) > 0)
        ...gen.row([
          PosColumn(
            text: dev.tipoDiferencia == 'cobrar' ? 'Cobrado:' : 'Devuelto:',
            width: 5, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(dev.diferencia!)}', width: 7, styles: PosStyles(align: PosAlign.right)),
        ]),
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

  // ── Preferencia caja de dinero ────────────────────────────

  static const _kHasCaja = 'thermal_has_drawer';

  static Future<bool> hasCashDrawer() async =>
      (await SharedPreferences.getInstance()).getBool(_kHasCaja) ?? false;

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
    String                     nit       = '',
    String                     direccion = '',
    String                     telefono  = '',
    PaperSize                  paperSize = PaperSize.mm80,
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

  /// Genera bytes ESC/POS para la factura completa de un separado.
  /// Incluye datos del cliente, productos, abonos y saldo pendiente.
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

  static String _formatFechaLimite(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  // ─────────────────────────────────────────────────────────

  static ThermalDevice _fromRaw(_UsbDev d) => ThermalDevice._(
    name:         d.productName,
    manufacturer: d.manufacturerName ?? '',
    vendorId:     d.vendorId,
    productId:    d.productId,
    raw:          d,
  );
}
