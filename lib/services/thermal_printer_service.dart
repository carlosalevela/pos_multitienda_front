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
    String                   nit       = '',
    String                   direccion = '',
    String                   telefono  = '',
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

    final tNombre  = dev.tiendaNombre.toUpperCase();
    final _maxCh   = paperSize == PaperSize.mm58 ? 16 : 24;
    final _titleW  = tNombre.length <= _maxCh     ? PosTextSize.size2 : PosTextSize.size1;
    final _titleH  = tNombre.length <= _maxCh * 2 ? PosTextSize.size2 : PosTextSize.size1;

    final bytes = <int>[
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(tNombre,
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: _titleH, width: _titleW)),
      if (nit.isNotEmpty)
        ...gen.text('NIT: $nit', styles: PosStyles(align: PosAlign.center)),
      if (direccion.isNotEmpty)
        ...gen.text(direccion, styles: PosStyles(align: PosAlign.center)),
      if (telefono.isNotEmpty)
        ...gen.text('Tel: $telefono', styles: PosStyles(align: PosAlign.center)),
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

      // ── Producto(s) entregado(s) (solo cambio) ──────────────
      if (esCambio) ...[
        ...gen.text('PRODUCTOS ENTREGADOS', styles: PosStyles(bold: true)),
        // nuevo modelo: lista de reemplazos
        if (dev.reemplazos.isNotEmpty)
          ...dev.reemplazos.expand((r) {
            final cs = r.cantidad % 1 == 0
                ? r.cantidad.toStringAsFixed(0)
                : r.cantidad.toStringAsFixed(2);
            return <int>[
              ...gen.text(r.productoNombre, styles: PosStyles(bold: true)),
              ...gen.row([
                PosColumn(text: '$cs x \$${fmt.format(r.precioUnitario)}', width: 8, styles: const PosStyles()),
                PosColumn(text: '\$${fmt.format(r.subtotal)}', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
              ]),
            ];
          })
        // fallback legacy: un solo producto
        else if (dev.productoReemplazoNombre != null) ...[
          ...gen.text(dev.productoReemplazoNombre!, styles: PosStyles(bold: true)),
          if (dev.precioReemplazo != null)
            ...gen.row([
              PosColumn(text: '$cantReemplazoStr x \$${fmt.format(dev.precioReemplazo!)}', width: 8, styles: const PosStyles()),
              PosColumn(text: '\$${fmt.format(dev.subtotalReemplazo ?? 0)}', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
            ]),
        ],
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
      ...gen.text('Presente su factura para cambios.',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text('Facturado con SIS - POS Multitienda',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];

    return bytes;
  }

  static String _metodoLabel(String m) => switch (m) {
    'transferencia'      => 'Transferencia',
    'tarjeta'            => 'Tarjeta',
    'mixto'              => 'Pago mixto',
    'nota_credito'       => 'Nota credito',
    'bono'               => 'Bono de regalo',
    'bono_efectivo'      => 'Bono + Efectivo',
    'bono_tarjeta'       => 'Bono + Tarjeta',
    'bono_transferencia' => 'Bono + Transferencia',
    _                    => 'Efectivo',
  };

  // ── Builder recibo de venta ───────────────────────────────

  static Future<List<int>> buildRecibo({
    required List<ItemCarrito> items,
    required String            numeroFactura,
    required String            tiendaNombre,
    String                     empresaNombre = '',
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
    String                     sesionId      = '',
    double                     montoEfectivo = 0,
    double                     montoTarjeta  = 0,
    double                     montoBono     = 0,
    double                     faltanteBono  = 0,
    String                     mensajePie    = '',
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
    final tNombreR   = tiendaNombre.toUpperCase();
    final _maxChR    = paperSize == PaperSize.mm58 ? 16 : 24;
    final _titleWR   = tNombreR.length <= _maxChR     ? PosTextSize.size2 : PosTextSize.size1;
    final _titleHR   = tNombreR.length <= _maxChR * 2 ? PosTextSize.size2 : PosTextSize.size1;

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ──────────────────────────────────────────
      ...gen.text(tNombreR,
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: _titleHR, width: _titleWR)),
      if (nit.isNotEmpty)
        ...gen.text('NIT: $nit', styles: PosStyles(align: PosAlign.center)),
      if (direccion.isNotEmpty)
        ...gen.text(direccion, styles: PosStyles(align: PosAlign.center)),
      if (telefono.isNotEmpty)
        ...gen.text('Tel: $telefono', styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Somos NO responsables de IVA',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text('FACTURA DE VENTA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info transaccion ────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'N Factura:', width: 5, styles: const PosStyles()),
        PosColumn(text: numeroFactura, width: 7, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      if (sesionId.isNotEmpty)
        ...gen.row([
          PosColumn(text: 'Turno:', width: 4, styles: const PosStyles()),
          PosColumn(text: sesionId, width: 8, styles: PosStyles(align: PosAlign.right)),
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
      ] else if (metodoPago == 'bono' || metodoPago.startsWith('bono_')) ...[
        ...gen.row([
          PosColumn(text: 'Bono:', width: 6, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(montoBono)}', width: 6, styles: PosStyles(align: PosAlign.right)),
        ]),
        if (metodoPago == 'bono_efectivo' && faltanteBono > 0) ...[
          ...gen.row([
            PosColumn(text: 'Efectivo:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(faltanteBono)}', width: 6, styles: PosStyles(align: PosAlign.right)),
          ]),
          ...gen.row([
            PosColumn(text: 'Efectivo recibido:', width: 7, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(montoRecibido)}', width: 5, styles: PosStyles(align: PosAlign.right)),
          ]),
          if (vuelto > 0)
            ...gen.row([
              PosColumn(text: 'Vuelto:', width: 6, styles: PosStyles(bold: true)),
              PosColumn(text: '\$${fmt.format(vuelto)}', width: 6,
                styles: PosStyles(bold: true, align: PosAlign.right)),
            ]),
        ] else if (metodoPago == 'bono_tarjeta' && faltanteBono > 0)
          ...gen.row([
            PosColumn(text: 'Tarjeta:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(faltanteBono)}', width: 6, styles: PosStyles(align: PosAlign.right)),
          ])
        else if (metodoPago == 'bono_transferencia' && faltanteBono > 0)
          ...gen.row([
            PosColumn(text: 'Transferencia:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(faltanteBono)}', width: 6, styles: PosStyles(align: PosAlign.right)),
          ]),
      ] else if (metodoPago == 'mixto') ...[
        if (montoEfectivo > 0)
          ...gen.row([
            PosColumn(text: 'Efectivo:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(montoEfectivo)}', width: 6, styles: PosStyles(align: PosAlign.right)),
          ]),
        if (montoTarjeta > 0)
          ...gen.row([
            PosColumn(text: 'Tarjeta:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(montoTarjeta)}', width: 6, styles: PosStyles(align: PosAlign.right)),
          ]),
        if (vuelto > 0)
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
      ...gen.text('Presente su factura para cambios.',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Tiene 8 dias para realizar cambios.',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Garantia de 30 dias.',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Somos NO responsables de IVA.',
        styles: PosStyles(align: PosAlign.center)),
      if (mensajePie.isNotEmpty) ...[
        ...gen.emptyLines(1),
        ...gen.text(mensajePie,
          styles: PosStyles(align: PosAlign.center, bold: true)),
      ],
      ...gen.hr(),
      ...gen.text('Facturado con SIS - POS Multitienda',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  // ── Comprobante de bono de regalo ─────────────────────────

  static Future<List<int>> buildReciboBono({
    required String codigo,
    required double valor,
    required String metodoPago,
    double    montoRecibido    = 0,
    double    vuelta           = 0,
    String    fechaVencimiento = '',
    String    tiendaNombre     = '',
    String    cajeroNombre     = '',
    String    numeroFactura    = '',
    String    nit              = '',
    String    direccion        = '',
    String    telefono         = '',
    String    mensajePie       = '',
    PaperSize paperSize        = PaperSize.mm80,
  }) async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(paperSize, profile);
    final fmt     = NumberFormat('#,##0', 'es_CO');
    final now     = DateTime.now();
    final fecha   = DateFormat('dd/MM/yyyy').format(now);
    final hora    = DateFormat('HH:mm:ss').format(now);

    DateTime? fechaVenc;
    if (fechaVencimiento.isNotEmpty) {
      try { fechaVenc = DateTime.parse(fechaVencimiento); } catch (_) {}
    }
    final fechaVencStr = fechaVenc != null
        ? DateFormat('dd/MM/yyyy').format(fechaVenc)
        : fechaVencimiento;

    final tNombre = tiendaNombre.isNotEmpty ? tiendaNombre.toUpperCase() : 'BONO DE REGALO';
    final maxCh   = paperSize == PaperSize.mm58 ? 16 : 24;
    final titleW  = tNombre.length <= maxCh     ? PosTextSize.size2 : PosTextSize.size1;
    final titleH  = tNombre.length <= maxCh * 2 ? PosTextSize.size2 : PosTextSize.size1;

    final metodoDisplay = switch (metodoPago) {
      'tarjeta'       => 'Tarjeta',
      'transferencia' => 'Transferencia',
      'nequi'         => 'Nequi / Daviplata',
      'daviplata'     => 'Nequi / Daviplata',
      _               => 'Efectivo',
    };

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ──────────────────────────────────────────
      ...gen.text(tNombre,
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: titleH, width: titleW)),
      if (nit.isNotEmpty)
        ...gen.text('NIT: $nit', styles: PosStyles(align: PosAlign.center)),
      if (direccion.isNotEmpty)
        ...gen.text(direccion, styles: PosStyles(align: PosAlign.center)),
      if (telefono.isNotEmpty)
        ...gen.text('Tel: $telefono', styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Somos NO responsables de IVA',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text('COMPROBANTE DE BONO DE REGALO',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info transaccion ────────────────────────────────────
      if (numeroFactura.isNotEmpty)
        ...gen.row([
          PosColumn(text: 'Factura:', width: 5, styles: const PosStyles()),
          PosColumn(text: numeroFactura, width: 7,
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
      if (cajeroNombre.isNotEmpty)
        ...gen.row([
          PosColumn(text: 'Cajero:', width: 4, styles: const PosStyles()),
          PosColumn(text: cajeroNombre, width: 8,
              styles: PosStyles(align: PosAlign.right)),
        ]),
      ...gen.hr(),

      // ── Valor del bono (destacado) ──────────────────────────
      ...gen.text('VALOR DEL BONO',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(1),
      ...gen.text('\$${fmt.format(valor)}',
        styles: PosStyles(
          align:  PosAlign.center,
          bold:   true,
          height: PosTextSize.size2,
          width:  PosTextSize.size2,
        )),
      ...gen.emptyLines(1),
      ...gen.hr(),

      // ── Pago ────────────────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Forma de pago:', width: 7, styles: const PosStyles()),
        PosColumn(text: metodoDisplay, width: 5,
            styles: PosStyles(align: PosAlign.right)),
      ]),
      if (metodoPago == 'efectivo' && montoRecibido > 0) ...[
        ...gen.row([
          PosColumn(text: 'Recibido:', width: 6, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(montoRecibido)}', width: 6,
              styles: PosStyles(align: PosAlign.right)),
        ]),
        if (vuelta > 0)
          ...gen.row([
            PosColumn(text: 'Vuelto:', width: 6, styles: PosStyles(bold: true)),
            PosColumn(text: '\$${fmt.format(vuelta)}', width: 6,
                styles: PosStyles(bold: true, align: PosAlign.right)),
          ]),
      ],
      ...gen.hr(),

      // ── Código del bono / vencimiento ──────────────────────
      ...gen.row([
        PosColumn(text: 'Codigo:', width: 4, styles: const PosStyles()),
        PosColumn(text: codigo, width: 8,
            styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      if (fechaVencStr.isNotEmpty)
        ...gen.row([
          PosColumn(text: 'Vence:', width: 4, styles: const PosStyles()),
          PosColumn(text: fechaVencStr, width: 8,
              styles: PosStyles(align: PosAlign.right)),
        ]),
      ...gen.text('Valido por 1 anno',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),

      // ── Código de barras (Code 39) ──────────────────────────
      ...gen.emptyLines(1),
      ...gen.barcode(
        Barcode.code39(codigo.toUpperCase().split('')),
        width: 2,
        height: 80,
        textPos: BarcodeText.below,
      ),
      ...gen.emptyLines(1),
      ...gen.hr(),

      // ── Footer ──────────────────────────────────────────────
      ...gen.text('Conserve este comprobante',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('para redimir su bono en tienda.',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('El bono es transferible.',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.text('Gracias por su compra!',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      if (mensajePie.isNotEmpty) ...[
        ...gen.emptyLines(1),
        ...gen.text(mensajePie,
          styles: PosStyles(align: PosAlign.center, bold: true)),
      ],
      ...gen.hr(),
      ...gen.text('Facturado con SIS - POS Multitienda',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  // ── Factura completa de separado ──────────────────────────

  static Future<List<int>> buildSeparadoRecibo(
    Separado separado, {
    required String empresaNombre,
    String          nit       = '',
    String          direccion = '',
    String          telefono  = '',
    PaperSize       paperSize = PaperSize.mm80,
  }) async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(paperSize, profile);
    final fmt     = NumberFormat('#,##0', 'es_CO');
    final fecha   = DateFormat('dd/MM/yyyy').format(separado.createdAt);
    final hora    = DateFormat('HH:mm').format(separado.createdAt);
    final sepId    = 'SEP-${separado.id}';
    final tNombreS = separado.tiendaNombre.toUpperCase();
    final _maxChS  = paperSize == PaperSize.mm58 ? 16 : 24;
    final _titleWS = tNombreS.length <= _maxChS     ? PosTextSize.size2 : PosTextSize.size1;
    final _titleHS = tNombreS.length <= _maxChS * 2 ? PosTextSize.size2 : PosTextSize.size1;

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(tNombreS,
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: _titleHS, width: _titleWS)),
      if (nit.isNotEmpty)
        ...gen.text('NIT: $nit', styles: PosStyles(align: PosAlign.center)),
      if (direccion.isNotEmpty)
        ...gen.text(direccion, styles: PosStyles(align: PosAlign.center)),
      if (telefono.isNotEmpty)
        ...gen.text('Tel: $telefono', styles: PosStyles(align: PosAlign.center)),
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
      ...gen.hr(),
      ...gen.text('Facturado con SIS - POS Multitienda',
        styles: PosStyles(align: PosAlign.center)),
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
    String            nit       = '',
    String            direccion = '',
    String            telefono  = '',
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
    final tNombreA   = separado.tiendaNombre.toUpperCase();
    final _maxChA    = paperSize == PaperSize.mm58 ? 16 : 24;
    final _titleWA   = tNombreA.length <= _maxChA     ? PosTextSize.size2 : PosTextSize.size1;
    final _titleHA   = tNombreA.length <= _maxChA * 2 ? PosTextSize.size2 : PosTextSize.size1;

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(tNombreA,
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: _titleHA, width: _titleWA)),
      if (nit.isNotEmpty)
        ...gen.text('NIT: $nit', styles: PosStyles(align: PosAlign.center)),
      if (direccion.isNotEmpty)
        ...gen.text(direccion, styles: PosStyles(align: PosAlign.center)),
      if (telefono.isNotEmpty)
        ...gen.text('Tel: $telefono', styles: PosStyles(align: PosAlign.center)),
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
      ...gen.hr(),
      ...gen.text('Facturado con SIS - POS Multitienda',
        styles: PosStyles(align: PosAlign.center)),
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
    String                               nit              = '',
    String                               direccion        = '',
    String                               telefono         = '',
    PaperSize                            paperSize        = PaperSize.mm80,
    List<Map<String, dynamic>>           resumenCuentas   = const [],
    List<Map<String, dynamic>>           gastosSesion     = const [],
    List<TopProducto>                    topProductos     = const [],
    List<Map<String, dynamic>>           separadosDia     = const [],
    List<Map<String, dynamic>>           ventasDia        = const [],
    List<Map<String, dynamic>>           abonosDia        = const [],
    List<Map<String, dynamic>>           devolucionesDia  = const [],
  }) async {
    final profile = await CapabilityProfile.load();
    final gen     = Generator(paperSize, profile);
    final fmt     = NumberFormat('#,##0', 'es_CO');
    final fechaAp = DateFormat('dd/MM/yy HH:mm').format(sesion.fecha_apertura);
    final fechaCi = sesion.fecha_cierre != null
        ? DateFormat('dd/MM/yy HH:mm').format(sesion.fecha_cierre!)
        : '---';
    // Max chars for product name inside width-8 column (minus "  1 x " prefix)
    // 58mm: width-8=21ch, prefix 6ch → 15ch available → 14 fills col cleanly
    // 80mm: width-8=28ch, prefix 6ch → 22ch available → 20 fills col cleanly
    final maxNombre = paperSize == PaperSize.mm58 ? 14 : 20;

    String _ml(String m) => switch (m) {
      'tarjeta'            => 'Tarjeta',
      'transferencia'      => 'Transf.',
      'mixto'              => 'Mixto',
      'credito'            => 'Credito',
      'bono'               => 'Bono',
      'bono_efectivo'      => 'Bono+Ef.',
      'bono_tarjeta'       => 'Bono+Tar.',
      'bono_transferencia' => 'Bono+Tra.',
      _                    => 'Efectivo',
    };

    // Título adaptativo: size2x2 ≤16 chars, solo height >16, normal bold >24
    final tNombre     = sesion.tiendaNombre.toUpperCase();
    final maxLineCh   = paperSize == PaperSize.mm58 ? 16 : 24;
    final titleW      = tNombre.length <= maxLineCh ? PosTextSize.size2 : PosTextSize.size1;
    final titleH      = tNombre.length <= maxLineCh * 2 ? PosTextSize.size2 : PosTextSize.size1;

    // Desglose efectivo para el balance
    // Usamos montoEsperado (calculado por el backend, siempre correcto) para derivar
    // el total de ingresos en efectivo en lugar de metodosPago['efectivo'], que puede
    // omitir cambiosCobrarEf si ReportesProvider._devoluciones no estaba cargado.
    final gastosEfectivo = gastosSesion
        .where((g) => (g['metodo_pago']?.toString() ?? '').toLowerCase() == 'efectivo')
        .fold<double>(0.0, (s, g) =>
            s + (double.tryParse(g['monto']?.toString() ?? '0') ?? 0));
    final ventasEfectivo = sesion.montoEsperado - sesion.saldo_inicial + gastosEfectivo;

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(tNombre,
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: titleH, width: titleW)),
      if (nit.isNotEmpty)
        ...gen.text('NIT: $nit', styles: PosStyles(align: PosAlign.center)),
      if (direccion.isNotEmpty)
        ...gen.text(direccion, styles: PosStyles(align: PosAlign.center)),
      if (telefono.isNotEmpty)
        ...gen.text('Tel: $telefono', styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      ...gen.text('CIERRE DE CAJA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.hr(),

      // ── Info sesión ────────────────────────────────────────
      ...gen.row([
        PosColumn(text: 'Turno #:', width: 5, styles: const PosStyles()),
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
      ...gen.text('Somos NO responsables de IVA',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),

      // ── Detalle FAC / SEP / ABO ────────────────────────────
      if (ventasDia.isNotEmpty || separadosDia.isNotEmpty || abonosDia.isNotEmpty) ...[
        ...gen.text('---- DETALLE TRANSACCIONES ----',
          styles: PosStyles(align: PosAlign.center, bold: true)),
        // Ventas (FAC) — ordenadas DESC por ID para consistencia entre auto-print y reimpresión
        if (ventasDia.isNotEmpty) ...[
          ...gen.text('[ FACTURAS ]',
            styles: PosStyles(align: PosAlign.center, bold: true)),
          ...(([...ventasDia]
                ..sort((a, b) =>
                    (int.tryParse(b['id']?.toString() ?? '0') ?? 0)
                    .compareTo(int.tryParse(a['id']?.toString() ?? '0') ?? 0)))
              .where((v) =>
              (v['estado']?.toString() ?? '') != 'anulada').toList())
              .asMap().entries.expand((entry) {
            final v        = entry.value;
            final tot      = double.tryParse(v['total']?.toString() ?? '0') ?? 0;
            final met      = _ml(v['metodo_pago']?.toString() ?? '');
            final id       = v['id']?.toString() ?? '${entry.key + 1}';
            final headerTxt = 'FAC #$id  $met';
            final detalles  = v['detalles'] is List
                ? (v['detalles'] as List).cast<Map>() : <Map>[];
            return [
              ...gen.row([
                PosColumn(text: headerTxt, width: 8, styles: PosStyles(bold: true)),
                PosColumn(text: '\$${fmt.format(tot)}', width: 4,
                  styles: PosStyles(align: PosAlign.right, bold: true)),
              ]),
              ...detalles.expand((d) {
                final nombre  = d['producto_nombre']?.toString() ?? '';
                final cant    = double.tryParse(d['cantidad']?.toString() ?? '1') ?? 1;
                final sub     = double.tryParse(d['subtotal']?.toString()  ?? '0') ?? 0;
                final cantStr = cant == cant.roundToDouble()
                    ? cant.toInt().toString() : cant.toStringAsFixed(1);
                final prefix  = '  $cantStr x ';
                final maxN    = maxNombre - (cantStr.length - 1); // adjust for multi-digit qty
                final nombreCorto = nombre.length > maxN
                    ? '${nombre.substring(0, maxN - 1)}.' : nombre;
                return gen.row([
                  PosColumn(
                    text: '$prefix$nombreCorto',
                    width: 8, styles: PosStyles(bold: true)),
                  PosColumn(
                    text: '\$${fmt.format(sub)}',
                    width: 4,
                    styles: PosStyles(align: PosAlign.right, bold: true)),
                ]);
              }),
            ];
          }),
          ...gen.row([
            PosColumn(text: 'TOTAL FAC:', width: 8, styles: PosStyles(bold: true)),
            PosColumn(
              text: '\$${fmt.format(ventasDia.where((v) =>
                (v['estado']?.toString() ?? '') != 'anulada')
                .fold<double>(0, (s, v) =>
                  s + (double.tryParse(v['total']?.toString() ?? '0') ?? 0)))}',
              width: 4, styles: PosStyles(bold: true, align: PosAlign.right)),
          ]),
          ...gen.hr(),
        ],
        // Separados (SEP)
        if (separadosDia.isNotEmpty) ...[
          ...gen.text('[ SEPARADOS ]',
            styles: PosStyles(align: PosAlign.center, bold: true)),
          ...separadosDia.asMap().entries.expand((entry) {
            final s   = entry.value;
            final tot = double.tryParse(s['total']?.toString() ?? '0') ?? 0;
            final cli = s['cliente_nombre']?.toString()
                     ?? s['cliente']?.toString() ?? '—';
            final met = _ml(s['metodo_pago']?.toString() ?? '');
            final id  = s['id']?.toString() ?? '${entry.key + 1}';
            final cliCorto = cli.length > 20 ? '${cli.substring(0, 19)}.' : cli;
            return [
              ...gen.row([
                PosColumn(text: 'SEP #$id  $met',
                  width: 8, styles: PosStyles(bold: true)),
                PosColumn(text: '\$${fmt.format(tot)}', width: 4,
                  styles: PosStyles(align: PosAlign.right, bold: true)),
              ]),
              ...gen.row([
                PosColumn(text: '  $cliCorto', width: 12, styles: const PosStyles()),
              ]),
            ];
          }),
          ...gen.row([
            PosColumn(text: 'TOTAL SEP:', width: 8, styles: PosStyles(bold: true)),
            PosColumn(text: '\$${fmt.format(separadosDia.fold<double>(0, (s, v) =>
              s + (double.tryParse(v['total']?.toString() ?? '0') ?? 0)))}',
              width: 4, styles: PosStyles(bold: true, align: PosAlign.right)),
          ]),
          ...gen.hr(),
        ],
        // Abonos (ABO)
        if (abonosDia.isNotEmpty) ...[
          ...gen.text('[ ABONOS SEP ]',
            styles: PosStyles(align: PosAlign.center, bold: true)),
          ...abonosDia.expand((a) {
            final mon = double.tryParse(a['monto']?.toString() ?? '0') ?? 0;
            final cli = a['cliente_nombre']?.toString() ?? '—';
            final met = _ml(a['metodo_pago']?.toString() ?? '');
            return gen.row([
              PosColumn(text: '$cli ($met)', width: 8, styles: const PosStyles()),
              PosColumn(text: '\$${fmt.format(mon)}', width: 4,
                styles: PosStyles(align: PosAlign.right, bold: true)),
            ]);
          }),
          ...gen.row([
            PosColumn(text: 'TOTAL ABO:', width: 8, styles: PosStyles(bold: true)),
            PosColumn(text: '\$${fmt.format(abonosDia.fold<double>(0, (s, a) =>
              s + (double.tryParse(a['monto']?.toString() ?? '0') ?? 0)))}',
              width: 4, styles: PosStyles(bold: true, align: PosAlign.right)),
          ]),
          ...gen.hr(),
        ],
      ],

      // ── Ventas por método ──────────────────────────────────
      ...gen.text('--- VENTAS DEL TURNO ---',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      // Orden fijo: efectivo → transferencia → tarjeta → otros (consistente entre prints)
      ...([
            'efectivo', 'transferencia', 'tarjeta', 'mixto',
            'credito', 'bono', 'bono_efectivo', 'bono_tarjeta', 'bono_transferencia',
          ].where((k) => (metodosPago[k] ?? 0) > 0).map((k) => MapEntry(k, metodosPago[k]!))
          .followedBy(metodosPago.entries.where((e) =>
              e.value > 0 &&
              !['efectivo','transferencia','tarjeta','mixto','credito',
                 'bono','bono_efectivo','bono_tarjeta','bono_transferencia'].contains(e.key))))
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

      // ── Detalle devoluciones / cambios ────────────────────
      ..._devDetalleBytes(gen, devolucionesDia, fmt),

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
        ...gen.text('----- TOP PRODUCTOS -----',
          styles: PosStyles(align: PosAlign.center, bold: true)),
        ...topProductos.take(5).toList().asMap().entries.expand((entry) {
          final i = entry.key + 1;
          final p = entry.value;
          final maxNTop = paperSize == PaperSize.mm58 ? 17 : 24;
          final nombreTop = p.producto.length > maxNTop
              ? '${p.producto.substring(0, maxNTop - 1)}.'
              : p.producto;
          final qty = p.totalVendido.toStringAsFixed(0);
          return [
            ...gen.row([
              PosColumn(text: '$i. $nombreTop', width: 8,
                styles: PosStyles(bold: true)),
              PosColumn(text: '\$${fmt.format(p.totalIngresos)}', width: 4,
                styles: PosStyles(align: PosAlign.right, bold: true)),
            ]),
            ...gen.text('   $qty uds.',
              styles: PosStyles(align: PosAlign.left)),
          ];
        }),
        ...gen.hr(),
      ],

      // ── Resumen total del turno ────────────────────────────
      ...gen.text('------ RESUMEN DEL TURNO ------',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.row([
        PosColumn(text: '+ Ventas FAC:', width: 7, styles: const PosStyles()),
        PosColumn(text: '\$${fmt.format(sesion.ventasTotal)}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      if (sesion.abonosTotal > 0)
        ...gen.row([
          PosColumn(text: '+ Abonos ABO:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.abonosTotal)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      if (sesion.cambiosCobrarEf > 0)
        ...gen.row([
          PosColumn(text: '+ Cambios ef.:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.cambiosCobrarEf)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      if (sesion.netoCambiosTarjeta != 0)
        ...gen.row([
          PosColumn(text: '${sesion.netoCambiosTarjeta > 0 ? '+' : ''} Cambios tar.:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.netoCambiosTarjeta)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      if (sesion.netoCambiosTransferencia != 0)
        ...gen.row([
          PosColumn(text: '${sesion.netoCambiosTransferencia > 0 ? '+' : ''} Cambios tra.:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.netoCambiosTransferencia)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      if (separadosDia.isNotEmpty)
        ...gen.row([
          PosColumn(text: '+ Separados SEP:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(separadosDia.fold<double>(0, (s, v) =>
            s + (double.tryParse(v['total']?.toString() ?? '0') ?? 0)))}',
            width: 5, styles: PosStyles(align: PosAlign.right)),
        ]),
      if (totalGastos > 0)
        ...gen.row([
          PosColumn(text: '- Gastos:', width: 7, styles: const PosStyles()),
          PosColumn(text: '-\$${fmt.format(totalGastos)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      ...gen.row([
        PosColumn(text: 'TOTAL NETO:', width: 7, styles: PosStyles(bold: true)),
        PosColumn(
          text: '\$${fmt.format(sesion.ventasTotal + sesion.abonosTotal + sesion.cambiosCobrarEf + sesion.netoCambiosTarjeta + sesion.netoCambiosTransferencia - totalGastos)}',
          width: 5, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]),
      ...gen.hr(),

      // ── Balance / Desglose efectivo ────────────────────────
      ...gen.text('------ EFECTIVO EN CAJA ------',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.row([
        PosColumn(text: 'Fondo base:', width: 7, styles: const PosStyles()),
        PosColumn(text: '\$${fmt.format(sesion.saldo_inicial)}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      if (ventasEfectivo > 0)
        ...gen.row([
          PosColumn(text: '+ Ingresos ef.:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(ventasEfectivo)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      if (gastosEfectivo > 0)
        ...gen.row([
          PosColumn(text: '- Gastos ef.:', width: 7, styles: const PosStyles()),
          PosColumn(text: '-\$${fmt.format(gastosEfectivo)}', width: 5,
            styles: PosStyles(align: PosAlign.right)),
        ]),
      ...gen.row([
        PosColumn(text: 'Transacciones:', width: 7, styles: const PosStyles()),
        PosColumn(text: '${sesion.numTransacciones}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.hr(),
      ...gen.text('EFECTIVO ESPERADO EN CAJA',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(1),
      ...gen.text('\$${fmt.format(sesion.montoEsperado)}',
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.hr(),

      // ── Valor a entregar (sin base) ────────────────────────
      ...gen.text('===== EFECTIVO A ENTREGAR ====',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.row([
        PosColumn(text: 'Efectivo esperado:', width: 7, styles: const PosStyles()),
        PosColumn(text: '\$${fmt.format(sesion.montoEsperado)}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.row([
        PosColumn(text: '- Base caja:', width: 7, styles: const PosStyles()),
        PosColumn(text: '-\$${fmt.format(sesion.saldo_inicial)}', width: 5,
          styles: PosStyles(align: PosAlign.right)),
      ]),
      ...gen.emptyLines(1),
      ...gen.text('\$${fmt.format(sesion.montoEsperado - sesion.saldo_inicial)}',
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: PosTextSize.size2, width: PosTextSize.size2)),
      ...gen.text('(efectivo a entregar)',
        styles: PosStyles(align: PosAlign.center)),
      ...gen.hr(),

      // ── Observaciones ──────────────────────────────────────
      if (sesion.observaciones.isNotEmpty) ...[
        ..._obsBytes(gen, sesion.observaciones, paperSize),
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

  /// Genera bytes ESC/POS para el comprobante de cierre de caja con datos completos
  /// (montoFinalReal, diferencia, desglose por método, etc.).
  static Future<List<int>> buildCierreHistorial({
    required SesionHistorial sesion,
    String                   nit       = '',
    String                   direccion = '',
    String                   telefono  = '',
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

    final tNombreH = sesion.tiendaNombre.toUpperCase();
    final _maxChH  = paperSize == PaperSize.mm58 ? 16 : 24;
    final _titleWH = tNombreH.length <= _maxChH     ? PosTextSize.size2 : PosTextSize.size1;
    final _titleHH = tNombreH.length <= _maxChH * 2 ? PosTextSize.size2 : PosTextSize.size1;

    return [
      ...gen.setGlobalCodeTable('CP850'),
      // ── Encabezado ─────────────────────────────────────────
      ...gen.text(tNombreH,
        styles: PosStyles(align: PosAlign.center, bold: true,
          height: _titleHH, width: _titleWH)),
      if (nit.isNotEmpty)
        ...gen.text('NIT: $nit', styles: PosStyles(align: PosAlign.center)),
      if (direccion.isNotEmpty)
        ...gen.text(direccion, styles: PosStyles(align: PosAlign.center)),
      if (telefono.isNotEmpty)
        ...gen.text('Tel: $telefono', styles: PosStyles(align: PosAlign.center)),
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
      if (sesion.ventasBono > 0)
        ...gen.row([
          PosColumn(text: '  Bono regalo:', width: 7, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(sesion.ventasBono)}', width: 5,
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

      // ── Cambios cobrados/devueltos por método ──────────────
      if (sesion.cambiosCobrarEf > 0 || sesion.netoCambiosTarjeta != 0 ||
          sesion.netoCambiosTransferencia != 0) ...[
        ...gen.text('CAMBIOS DE PRODUCTO', styles: PosStyles(bold: true)),
        if (sesion.cambiosCobrarEf > 0)
          ...gen.row([
            PosColumn(text: '  Cobrado ef.:', width: 7, styles: const PosStyles()),
            PosColumn(text: '+\$${fmt.format(sesion.cambiosCobrarEf)}', width: 5,
              styles: PosStyles(align: PosAlign.right)),
          ]),
        if (sesion.netoCambiosTarjeta != 0)
          ...gen.row([
            PosColumn(text: '  Neto tarjeta:', width: 7, styles: const PosStyles()),
            PosColumn(
              text: '${sesion.netoCambiosTarjeta > 0 ? '+' : ''}\$${fmt.format(sesion.netoCambiosTarjeta)}',
              width: 5, styles: PosStyles(align: PosAlign.right)),
          ]),
        if (sesion.netoCambiosTransferencia != 0)
          ...gen.row([
            PosColumn(text: '  Neto transf.:', width: 7, styles: const PosStyles()),
            PosColumn(
              text: '${sesion.netoCambiosTransferencia > 0 ? '+' : ''}\$${fmt.format(sesion.netoCambiosTransferencia)}',
              width: 5, styles: PosStyles(align: PosAlign.right)),
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
              text: '${sesion.numDevoluciones - sesion.numCambiosProducto} '
                  '(${sesion.devolucionesEfectivo >= 0 ? '-' : '+'}'
                  '\$${fmt.format(sesion.devolucionesEfectivo.abs())})',
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
        ..._obsBytes(gen, sesion.observaciones, paperSize),
        ...gen.hr(),
      ],

      // ── Detalle devoluciones / cambios ────────────────────
      ..._devDetalleBytes(gen, sesion.devolucionesDetalle, fmt),

      // ── Footer ─────────────────────────────────────────────
      ...gen.emptyLines(1),
      ...gen.text('Cierre procesado exitosamente',
        styles: PosStyles(align: PosAlign.center, bold: true)),
      ...gen.emptyLines(3),
      ...gen.cut(),
    ];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Splits [text] at word boundaries so each chunk ≤ [maxLen] chars.
  static List<String> _wordWrap(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    var cur = '';
    for (final w in words) {
      if (cur.isEmpty) {
        cur = w;
      } else if (cur.length + 1 + w.length <= maxLen) {
        cur += ' $w';
      } else {
        lines.add(cur);
        cur = w;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines;
  }

  /// Builds observation bytes with word-wrapped lines.
  static List<int> _obsBytes(Generator gen, String obs, PaperSize paper) {
    final cols   = paper == PaperSize.mm58 ? 26 : 42;
    const prefix = 'Obs: ';
    final lines  = _wordWrap(obs, cols);
    final bytes  = <int>[];
    bool first   = true;
    for (final line in lines) {
      bytes.addAll(gen.text(
        first ? '$prefix$line' : '     $line',
        styles: const PosStyles(),
      ));
      first = false;
    }
    return bytes;
  }

  /// Builds detalle-devoluciones/cambios bytes (empty list → no output).
  static List<int> _devDetalleBytes(
    Generator gen, List<Map<String, dynamic>> devs, NumberFormat fmt) {
    if (devs.isEmpty) return [];

    String _fmtMetodo(String m) => switch (m.toLowerCase()) {
      'tarjeta'       => 'Tarjeta',
      'transferencia' => 'Transf.',
      'nota_credito'  => 'N.Crédito',
      _               => 'Efectivo',
    };

    String _fmtTipo(String tipo, String tipoDif, double dif) {
      if (tipo != 'cambio') return 'Devolución';
      if (tipoDif == 'cobrar'   && dif > 0) return 'Cambio+Cobro';
      if (tipoDif == 'devolver' && dif > 0) return 'Cambio+Dev.';
      return 'Cambio Exacto';
    }

    final bytes = <int>[];
    bytes.addAll(gen.text('- DEVOLUCIONES / CAMBIOS -',
        styles: PosStyles(align: PosAlign.center, bold: true)));

    for (final d in devs) {
      final tipo     = d['tipo']            as String? ?? '';
      final venta    = d['venta_numero']    as String? ?? '';
      final tipoDif  = d['tipo_diferencia'] as String? ?? '';
      final dif      = (d['diferencia']     as num?)?.toDouble() ?? 0.0;
      final metodo   = d['metodo']          as String? ?? '';
      final reempl   = d['producto_reemplazo'] as String? ?? '';
      final total    = (d['total_devuelto'] as num?)?.toDouble() ?? 0.0;

      final label = _fmtTipo(tipo, tipoDif, dif);
      bytes.addAll(gen.row([
        PosColumn(text: venta.isNotEmpty ? 'FAC #$venta' : '—',
            width: 6, styles: PosStyles(bold: true)),
        PosColumn(text: label,
            width: 6, styles: PosStyles(bold: true, align: PosAlign.right)),
      ]));

      // Productos devueltos con cantidad
      final productos = (d['productos_devueltos'] as List?)
              ?.cast<Map<String, dynamic>>() ?? [];
      for (final p in productos) {
        final nombre  = p['producto'] as String? ?? '';
        final cant    = (p['cantidad'] as num?)?.toDouble() ?? 1.0;
        final cantStr = cant == cant.roundToDouble()
            ? cant.toInt().toString() : cant.toStringAsFixed(1);
        if (tipo == 'cambio' && reempl.isNotEmpty) {
          // "1x Producto A → Reemplazo"
          final orig  = nombre.length > 12 ? '${nombre.substring(0, 11)}.' : nombre;
          final repla = reempl.length > 12 ? '${reempl.substring(0, 11)}.' : reempl;
          bytes.addAll(gen.text('  ${cantStr}x $orig -> $repla',
              styles: const PosStyles()));
        } else {
          bytes.addAll(gen.text('  ${cantStr}x $nombre', styles: const PosStyles()));
        }
      }

      // Impacto económico
      if (tipo == 'cambio') {
        if (tipoDif == 'cobrar' && dif > 0) {
          bytes.addAll(gen.row([
            PosColumn(text: '  + Cobrado:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(dif)} ${_fmtMetodo(metodo)}',
                width: 6, styles: PosStyles(bold: true, align: PosAlign.right)),
          ]));
        } else if (tipoDif == 'devolver' && dif > 0) {
          bytes.addAll(gen.row([
            PosColumn(text: '  - Devuelto:', width: 6, styles: const PosStyles()),
            PosColumn(text: '\$${fmt.format(dif)} ${_fmtMetodo(metodo)}',
                width: 6, styles: PosStyles(bold: true, align: PosAlign.right)),
          ]));
        } else {
          bytes.addAll(gen.text('  Mismo valor (sin cobro)',
              styles: const PosStyles()));
        }
      } else {
        // Devolución simple
        bytes.addAll(gen.row([
          PosColumn(text: '  - Dev.:', width: 6, styles: const PosStyles()),
          PosColumn(text: '\$${fmt.format(total)} ${_fmtMetodo(metodo)}',
              width: 6, styles: PosStyles(bold: true, align: PosAlign.right)),
        ]));
      }
    }
    bytes.addAll(gen.hr());
    return bytes;
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
