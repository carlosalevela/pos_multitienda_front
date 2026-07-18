import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/venta_model.dart';
import '../../../models/producto.dart';
import '../../../models/cliente.dart';
import '../../../models/devolucion_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/devoluciones_provider.dart';
import '../../../services/venta_service.dart';
import '../../../services/inventario_service.dart';
import '../../../services/cliente_service.dart';

const _kGreen     = Color(0xFF006C49);
const _kMintLight = Color(0xFFE8FFF4);
const _kSurface   = Color(0xFFF7F9FB);
const _kText      = Color(0xFF191C1E);
const _kTextMuted = Color(0xFF76777D);
const _kBorder    = Color(0xFFE0E3E5);
const _kOrange    = Color(0xFFF59E0B);

// ─────────────────────────────────────────────────────────────────────────────
//  DevolucionFormSheet
// ─────────────────────────────────────────────────────────────────────────────

class DevolucionFormSheet extends StatefulWidget {
  final void Function(DevolucionModel?) onCreada;
  final String? initialNumeroOrden;

  const DevolucionFormSheet({
    super.key,
    required this.onCreada,
    this.initialNumeroOrden,
  });

  static void show(
    BuildContext context, {
    required void Function(DevolucionModel?) onCreada,
    String? initialNumeroOrden,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DevolucionFormSheet(
        onCreada: onCreada,
        initialNumeroOrden: initialNumeroOrden,
      ),
    );
  }

  @override
  State<DevolucionFormSheet> createState() => _DevolucionFormSheetState();
}

class _DevolucionFormSheetState extends State<DevolucionFormSheet> {
  // ── Servicios ─────────────────────────────────────────
  final _ventaService   = VentaService();
  final _inventarioSvc  = InventarioService();
  final _clienteService = ClienteService();

  // ── Controladores ─────────────────────────────────────
  final _formKey            = GlobalKey<FormState>();
  final _obsCtrl            = TextEditingController();
  final _busquedaCtrl       = TextEditingController();
  final _clienteCtrl        = TextEditingController();
  final _montoRecibidoCtrl  = TextEditingController();

  // ── Opciones de método ────────────────────────────────
  static const _metodos = [
    ('efectivo',      'Efectivo',       Icons.payments_rounded),
    ('transferencia', 'Transferencia',  Icons.swap_horiz_rounded),
    ('tarjeta',       'Tarjeta',        Icons.credit_card_rounded),
    ('nota_credito',  'Nota Crédito',   Icons.article_rounded),
  ];

  // ── Estado ────────────────────────────────────────────
  String _metodoPago            = 'efectivo';
  String _tipoOperacion         = 'devolucion';
  String _metodoPagoDiferencia  = 'efectivo';
  bool   _guardando             = false;
  bool   _cargandoVenta         = false;

  // ── Venta seleccionada ────────────────────────────────
  VentaResumenModel?    _ventaSel;
  VentaDisponibleModel? _ventaDisp;
  final List<_ItemCtrl> _items = [];

  // ── Producto nuevo (cambio) ───────────────────────────
  List<Producto>  _resultadosProducto = [];
  bool            _buscandoProducto   = false;
  _ItemNuevo?     _productoNuevo;

  // ── Cliente (cambio, opcional) ────────────────────────
  List<Cliente> _resultadosCliente = [];
  bool          _buscandoCliente   = false;
  Cliente?      _clienteSel;

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.initialNumeroOrden != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _buscarPorNumeroOrden(widget.initialNumeroOrden!);
      });
    }
  }

  Future<void> _buscarPorNumeroOrden(String numero) async {
    setState(() => _cargandoVenta = true);
    final auth     = context.read<AuthProvider>();
    final tiendaId = auth.tiendaId != 0 ? auth.tiendaId : null;
    final raw = await _ventaService.buscarPorNumeroOrden(
      numero, tiendaId: tiendaId,
    );
    if (!mounted) return;
    if (raw.isEmpty) {
      setState(() => _cargandoVenta = false);
      _showSnack('No se encontró la factura "$numero"', error: true);
      return;
    }
    final venta = VentaResumenModel.fromJson(raw.first);
    await _cargarDisponible(venta);
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    _busquedaCtrl.dispose();
    _clienteCtrl.dispose();
    _montoRecibidoCtrl.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  // ── Buscar y cargar venta ─────────────────────────────

  Future<void> _abrirBuscador() async {
    final auth     = context.read<AuthProvider>();
    final tiendaId = auth.tiendaId != 0 ? auth.tiendaId : null;
    if (!mounted) return;
    final sel = await _BuscadorVentasSheet.show(
      context, tiendaId: tiendaId, ventaService: _ventaService,
    );
    if (sel == null) return;
    await _cargarDisponible(sel);
  }

  Future<void> _cargarDisponible(VentaResumenModel venta) async {
    setState(() {
      _cargandoVenta      = true;
      _ventaSel           = venta;
      _ventaDisp          = null;
      _productoNuevo      = null;
      _resultadosProducto = [];
      _busquedaCtrl.clear();
      _montoRecibidoCtrl.clear();
      for (final i in _items) i.dispose();
      _items.clear();
    });

    final raw = await _ventaService.ventaDisponibleDevolucion(venta.id);
    if (!mounted) return;

    if (raw == null) {
      _showSnack('Error al cargar la venta', error: true);
      setState(() { _cargandoVenta = false; _ventaSel = null; });
      return;
    }

    final disp = VentaDisponibleModel.fromJson(raw);
    if (disp.todosDevueltos) {
      _showSnack('Esta venta ya fue devuelta completamente', error: true);
      setState(() { _cargandoVenta = false; _ventaSel = null; });
      return;
    }

    setState(() {
      _cargandoVenta = false;
      _ventaDisp     = disp;
      _items.addAll(disp.productos.map(_ItemCtrl.fromProducto));
    });
  }

  void _limpiarVenta() => setState(() {
    _ventaSel           = null;
    _ventaDisp          = null;
    _productoNuevo      = null;
    _resultadosProducto = [];
    _busquedaCtrl.clear();
    _montoRecibidoCtrl.clear();
    for (final i in _items) i.dispose();
    _items.clear();
  });

  // ── Búsqueda de producto nuevo ────────────────────────

  Future<void> _buscarProductos(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _resultadosProducto = []);
      return;
    }
    setState(() => _buscandoProducto = true);
    final auth     = context.read<AuthProvider>();
    final tiendaId = auth.tiendaId != 0 ? auth.tiendaId : null;
    final result   = await _inventarioSvc.getProductos(q: query, tiendaId: tiendaId);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _resultadosProducto = result['data'] as List<Producto>;
        _buscandoProducto   = false;
      });
    } else {
      setState(() { _resultadosProducto = []; _buscandoProducto = false; });
      _showSnack(result['error']?.toString() ?? 'Error al buscar productos', error: true);
    }
  }

  void _seleccionarProductoNuevo(Producto p) {
    setState(() {
      _productoNuevo      = _ItemNuevo(p);
      _busquedaCtrl.clear();
      _resultadosProducto = [];
    });
  }

  void _incrementarNuevo() {
    final item = _productoNuevo;
    if (item == null) return;
    if (item.cantidad >= item.producto.stockActual) {
      _showSnack('Stock máximo: ${item.producto.stockActual.toStringAsFixed(0)}', error: true);
      return;
    }
    setState(() => item.cantidad++);
  }

  void _decrementarNuevo() {
    final item = _productoNuevo;
    if (item == null) return;
    setState(() {
      if (item.cantidad > 1) item.cantidad--;
      else _productoNuevo = null;
    });
  }

  // ── Búsqueda de cliente ───────────────────────────────

  Future<void> _buscarClientes(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _resultadosCliente = []);
      return;
    }
    setState(() => _buscandoCliente = true);
    final lista = await _clienteService.getClientesSimple(q: query);
    if (!mounted) return;
    setState(() { _resultadosCliente = lista; _buscandoCliente = false; });
  }

  void _seleccionarCliente(Cliente c) {
    _clienteCtrl.text = c.nombreCompleto;
    setState(() { _clienteSel = c; _resultadosCliente = []; });
  }

  void _limpiarCliente() {
    _clienteCtrl.clear();
    setState(() { _clienteSel = null; _resultadosCliente = []; });
  }

  // ── Totales ───────────────────────────────────────────

  double get _totalDevuelto => _items
      .where((i) => i.seleccionado)
      .fold(0.0, (s, i) {
        final cant = double.tryParse(i.cantidadCtrl.text.trim()) ?? 0;
        return s + i.producto.precioUnitario * cant;
      });

  double get _totalNuevo      => _productoNuevo?.subtotal ?? 0.0;
  double get _diferenciaNeta  => _totalNuevo - _totalDevuelto;
  double get _saldoPendiente  => _diferenciaNeta > 0 ? _diferenciaNeta : 0.0;
  double get _saldoADevolver  => _diferenciaNeta < 0 ? _diferenciaNeta.abs() : 0.0;

  // ── Guardar ───────────────────────────────────────────

  Future<void> _guardar() async {
    if (_ventaDisp == null) {
      _showSnack('Selecciona una venta primero.', error: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final itemsSel = _items.where((i) => i.seleccionado).toList();
    if (itemsSel.isEmpty) {
      _showSnack('Selecciona al menos un producto a devolver.', error: true);
      return;
    }
    for (final item in itemsSel) {
      final cant = double.tryParse(item.cantidadCtrl.text.trim()) ?? 0;
      if (cant > item.producto.disponible) {
        _showSnack('${item.producto.productoNombre}: máximo ${item.producto.disponible}.', error: true);
        return;
      }
    }
    if (_tipoOperacion == 'cambio' && _productoNuevo == null) {
      _showSnack('Selecciona el producto de reemplazo.', error: true);
      return;
    }

    double? montoRecibido;
    if (_tipoOperacion == 'cambio' && _saldoPendiente > 0) {
      montoRecibido = double.tryParse(_montoRecibidoCtrl.text.trim());
      if (montoRecibido == null || montoRecibido <= 0) {
        _showSnack('Ingresa el monto recibido del cliente.', error: true);
        return;
      }
      if (montoRecibido < _saldoPendiente) {
        _showSnack('El monto recibido no cubre la diferencia.', error: true);
        return;
      }
    }

    setState(() => _guardando = true);

    final detallesDevueltos = itemsSel.map((i) => {
      'producto':        i.producto.productoId,
      'cantidad':        double.parse(i.cantidadCtrl.text.trim()),
      'precio_unitario': i.producto.precioUnitario,
      if (i.motivoCtrl.text.trim().isNotEmpty) 'motivo': i.motivoCtrl.text.trim(),
    }).toList();

    Map<String, dynamic> resp;
    if (_tipoOperacion == 'cambio') {
      resp = await context.read<DevolucionesProvider>().crearCambio(
        ventaId:              _ventaDisp!.ventaId,
        metodoPago:           _metodoPago,
        detalles:             detallesDevueltos,
        productoReemplazoId:  _productoNuevo!.producto.id,
        cantidadReemplazo:    _productoNuevo!.cantidad,
        observaciones:        _obsCtrl.text.trim(),
        metodoPagoDiferencia: _saldoPendiente > 0 ? _metodoPagoDiferencia : null,
        montoRecibido:        _saldoPendiente > 0 ? montoRecibido : null,
      );
    } else {
      resp = await context.read<DevolucionesProvider>().crearDevolucion(
        ventaId:       _ventaDisp!.ventaId,
        metodoPago:    _metodoPago,
        detalles:      detallesDevueltos,
        observaciones: _obsCtrl.text.trim(),
      );
    }

    setState(() => _guardando = false);
    if (!mounted) return;

    if (resp['success'] == true) {
      DevolucionModel? devCreada;
      try {
        final rawData = resp['data'];
        if (rawData is Map<String, dynamic>) {
          devCreada = DevolucionModel.fromJson(rawData);
        }
      } catch (_) {}

      Navigator.pop(context);
      widget.onCreada(devCreada);
    } else {
      _showSnack(resp['error']?.toString() ?? 'Error al registrar operación', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: error ? Colors.red.shade600 : _kGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            _headerBar(),
            const Divider(height: 1, color: _kBorder),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Tipo de operación
                    _selectorTipo(),
                    const SizedBox(height: 20),

                    // 2. Selector de venta
                    _FormLabel(label: 'Venta a devolver', child: _selectorVenta()),
                    const SizedBox(height: 4),

                    // 3. Tarjeta de transacción (una vez cargada)
                    if (_ventaSel != null) ...[
                      const SizedBox(height: 12),
                      _transaccionCard(),
                    ],

                    // 4. Productos a devolver
                    if (_ventaDisp != null) ...[
                      const SizedBox(height: 24),
                      _seccionProductosDevueltos(),
                    ],

                    // 5. Cliente y producto nuevo (cambio)
                    if (_tipoOperacion == 'cambio') ...[
                      const SizedBox(height: 20),
                      _seccionClienteCambio(),
                      const SizedBox(height: 20),
                      _seccionProductoNuevo(),
                    ],

                    // 6. Resumen de saldo (cambio con diferencia)
                    if (_tipoOperacion == 'cambio' &&
                        _items.any((i) => i.seleccionado) &&
                        _productoNuevo != null) ...[
                      const SizedBox(height: 16),
                      _resumenSaldo(),
                    ],

                    // 7. Método de reembolso (cards visuales)
                    const SizedBox(height: 24),
                    _seccionMetodoPago(),

                    // 8. Observaciones
                    const SizedBox(height: 20),
                    _FormLabel(
                      label: 'Observaciones (opcional)',
                      child: TextFormField(
                        controller: _obsCtrl,
                        maxLines: 2,
                        decoration: _inputDeco('Motivo general de la devolución...'),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom panel sticky
            _bottomPanel(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Widgets del header
  // ─────────────────────────────────────────────────────

  Widget _handle() => Center(
    child: Container(
      width: 40, height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _headerBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.assignment_return_rounded, color: _kGreen, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          _tipoOperacion == 'cambio' ? 'Nuevo cambio' : 'Nueva devolución',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      IconButton(
        icon: Icon(Icons.close_rounded, size: 20, color: _kTextMuted),
        onPressed: () => Navigator.pop(context),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ]),
  );

  // ─────────────────────────────────────────────────────
  //  Tarjeta de transacción
  // ─────────────────────────────────────────────────────

  Widget _transaccionCard() {
    final fmt  = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final date = DateFormat('dd/MM/yyyy HH:mm').format(_ventaSel!.createdAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: _kGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ventaSel!.numeroFactura,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: _kText),
                ),
                Text(date, style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kMintLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Verificada',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _kGreen),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _limpiarVenta,
            child: Icon(Icons.close_rounded, size: 16, color: _kTextMuted),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(color: _kBorder, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _infoCell('CLIENTE', _ventaSel!.clienteNombre)),
          const SizedBox(width: 12),
          Expanded(child: _infoCell('TOTAL VENTA', fmt.format(_ventaSel!.total))),
        ]),
      ]),
    );
  }

  Widget _infoCell(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
              color: _kTextMuted, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
          overflow: TextOverflow.ellipsis),
    ],
  );

  // ─────────────────────────────────────────────────────
  //  Selector de venta (botón)
  // ─────────────────────────────────────────────────────

  Widget _selectorVenta() => GestureDetector(
    onTap: _cargandoVenta ? null : _abrirBuscador,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _ventaSel != null ? Colors.white : _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _ventaSel != null ? _kGreen : _kBorder,
          width: _ventaSel != null ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Icon(
          Icons.search_rounded,
          size: 18,
          color: _ventaSel != null ? _kGreen : _kTextMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _cargandoVenta
              ? Row(children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
                  ),
                  const SizedBox(width: 8),
                  Text('Cargando venta...',
                      style: GoogleFonts.inter(fontSize: 13, color: _kTextMuted)),
                ])
              : Text(
                  _ventaSel == null ? 'Buscar venta por fecha o factura...' : 'Cambiar venta',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _ventaSel != null ? _kGreen : _kTextMuted),
                ),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: _kTextMuted),
      ]),
    ),
  );

  // ─────────────────────────────────────────────────────
  //  Tipo de operación
  // ─────────────────────────────────────────────────────

  Widget _selectorTipo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Tipo de operación',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
              color: Colors.grey.shade600)),
      const SizedBox(height: 8),
      Row(children: [
        _TipoBtn(
          label: 'Devolución',
          icon: Icons.arrow_circle_up_rounded,
          selected: _tipoOperacion == 'devolucion',
          color: _kOrange,
          onTap: () => setState(() {
            _tipoOperacion  = 'devolucion';
            _productoNuevo  = null;
            _resultadosProducto = [];
            _busquedaCtrl.clear();
            _montoRecibidoCtrl.clear();
            _limpiarCliente();
          }),
        ),
        const SizedBox(width: 10),
        _TipoBtn(
          label: 'Cambio',
          icon: Icons.swap_horiz_rounded,
          selected: _tipoOperacion == 'cambio',
          color: _kGreen,
          onTap: () => setState(() => _tipoOperacion = 'cambio'),
        ),
      ]),
    ],
  );

  // ─────────────────────────────────────────────────────
  //  Método de reembolso — card buttons
  // ─────────────────────────────────────────────────────

  Widget _seccionMetodoPago() {
    final esCambioConDiferencia = _tipoOperacion == 'cambio' && _saldoPendiente > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Método de reembolso',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
              color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _metodos.map((m) {
            final selected = _metodoPago == m.$1;
            return GestureDetector(
              onTap: () => setState(() => _metodoPago = m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _kGreen.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? _kGreen : _kBorder,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(m.$3, size: 16, color: selected ? _kGreen : _kTextMuted),
                  const SizedBox(width: 6),
                  Text(m.$2, style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: selected ? _kGreen : _kTextMuted,
                  )),
                ]),
              ),
            );
          }).toList(),
        ),

        // Para cambio con diferencia a cobrar: método de la diferencia
        if (esCambioConDiferencia) ...[
          const SizedBox(height: 20),
          _FormLabel(
            label: 'Método de pago de la diferencia',
            child: DropdownButtonFormField<String>(
              value: _metodoPagoDiferencia,
              isDense: true,
              decoration: _inputDeco(null),
              style: GoogleFonts.inter(fontSize: 14, color: _kText),
              items: _metodos
                  .where((m) => m.$1 != 'nota_credito')
                  .map((m) => DropdownMenuItem<String>(
                        value: m.$1,
                        child: Text(m.$2, style: GoogleFonts.inter(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _metodoPagoDiferencia = v!),
            ),
          ),
          const SizedBox(height: 12),
          _FormLabel(
            label: 'Monto recibido del cliente',
            child: TextFormField(
              controller: _montoRecibidoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: _inputDeco('Ej: 20000'),
              style: GoogleFonts.inter(fontSize: 14),
              validator: (_) {
                if (_tipoOperacion != 'cambio' || _saldoPendiente <= 0) return null;
                final v = double.tryParse(_montoRecibidoCtrl.text.trim());
                if (v == null || v <= 0) return 'Ingresa un monto válido';
                if (v < _saldoPendiente) return 'Debe cubrir la diferencia';
                return null;
              },
            ),
          ),
          // Cambio devuelto al cliente
          Builder(builder: (_) {
            final montoRaw = double.tryParse(_montoRecibidoCtrl.text.trim()) ?? 0;
            if (_metodoPagoDiferencia == 'efectivo' && montoRaw >= _saldoPendiente && montoRaw > 0) {
              final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Cambio: ${fmt.format(montoRaw - _saldoPendiente)}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                          color: Colors.green.shade800),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  //  Bottom panel sticky
  // ─────────────────────────────────────────────────────

  Widget _bottomPanel() {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    double totalDisplay;
    String labelTotal;
    Color  colorTotal;

    if (_tipoOperacion == 'devolucion') {
      totalDisplay = _totalDevuelto;
      labelTotal   = 'Total a devolver';
      colorTotal   = _kOrange;
    } else if (_saldoPendiente > 0) {
      totalDisplay = _saldoPendiente;
      labelTotal   = 'Diferencia a cobrar';
      colorTotal   = Colors.orange.shade700;
    } else if (_saldoADevolver > 0) {
      totalDisplay = _saldoADevolver;
      labelTotal   = 'A devolver al cliente';
      colorTotal   = Colors.blueGrey.shade700;
    } else {
      totalDisplay = _totalDevuelto;
      labelTotal   = 'Valor del cambio';
      colorTotal   = _kGreen;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(labelTotal,
                  style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                fmt.format(totalDisplay),
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold,
                    color: colorTotal),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _tipoOperacion == 'cambio' ? 'Registrar cambio' : 'Registrar devolución',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kBorder,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Secciones de contenido
  // ─────────────────────────────────────────────────────

  Widget _seccionClienteCambio() => _FormLabel(
    label: 'Cliente (opcional)',
    child: Column(children: [
      TextField(
        controller: _clienteCtrl,
        onChanged: _clienteSel == null ? _buscarClientes : null,
        readOnly: _clienteSel != null,
        decoration: InputDecoration(
          hintText: 'Buscar cliente por nombre o cédula...',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: _kTextMuted),
          prefixIcon: _clienteSel != null
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: _kGreen.withValues(alpha: 0.1),
                    child: Text(
                      _clienteSel!.nombre[0].toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _kGreen),
                    ),
                  ),
                )
              : const Icon(Icons.person_search_rounded, size: 18, color: _kTextMuted),
          suffixIcon: _buscandoCliente
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen)),
                )
              : _clienteSel != null
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: _kTextMuted),
                      onPressed: _limpiarCliente)
                  : _clienteCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: _kTextMuted),
                          onPressed: () {
                            _clienteCtrl.clear();
                            setState(() => _resultadosCliente = []);
                          })
                      : null,
          filled: true,
          fillColor: _clienteSel != null ? _kGreen.withValues(alpha: 0.04) : _kSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _clienteSel != null ? _kGreen : _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: _clienteSel != null ? _kGreen : _kBorder,
                  width: _clienteSel != null ? 1.5 : 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kGreen, width: 1.5)),
        ),
        style: GoogleFonts.inter(fontSize: 14),
      ),
      if (_resultadosCliente.isNotEmpty) ...[
        const SizedBox(height: 6),
        _dropdownResultados(
          itemCount: _resultadosCliente.length,
          itemBuilder: (_, i) {
            final c = _resultadosCliente[i];
            return ListTile(
              dense: true,
              onTap: () => _seleccionarCliente(c),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _kGreen.withValues(alpha: 0.1),
                child: Text(c.nombre[0].toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _kGreen)),
              ),
              title: Text(c.nombreCompleto,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                [
                  if (c.cedulaNit != null && c.cedulaNit!.isNotEmpty) c.cedulaNit!,
                  if (c.telefono.isNotEmpty) c.telefono,
                ].join('  •  '),
                style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: _kTextMuted),
            );
          },
        ),
      ],
    ]),
  );

  Widget _seccionProductosDevueltos() {
    final selCount = _items.where((i) => i.seleccionado).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            _tipoOperacion == 'cambio' ? 'Productos que trae el cliente' : 'Productos a devolver',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _kText),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$selCount/${_items.length}',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _kGreen)),
          ),
        ]),
        const SizedBox(height: 10),
        ..._items.map((item) => _ItemProductoCard(
              key: ValueKey(item.producto.productoId),
              item: item,
              onToggle: () => setState(() => item.seleccionado = !item.seleccionado),
              onChanged: () => setState(() {}),
            )),
      ],
    );
  }

  Widget _seccionProductoNuevo() {
    final fmt = NumberFormat('#,##0.##', 'es_CO');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.green.shade700),
          ),
          const SizedBox(width: 8),
          Text('Producto de reemplazo',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _kText)),
        ]),
        const SizedBox(height: 10),

        if (_productoNuevo == null) ...[
          TextField(
            controller: _busquedaCtrl,
            onChanged: _buscarProductos,
            decoration: InputDecoration(
              hintText: 'Buscar producto por nombre o código...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _kTextMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kTextMuted),
              suffixIcon: _buscandoProducto
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen)),
                    )
                  : _busquedaCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: _kTextMuted),
                          onPressed: () {
                            _busquedaCtrl.clear();
                            setState(() => _resultadosProducto = []);
                          })
                      : null,
              filled: true,
              fillColor: _kSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kGreen, width: 1.5)),
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          if (_resultadosProducto.isNotEmpty) ...[
            const SizedBox(height: 6),
            _dropdownResultados(
              itemCount: _resultadosProducto.length,
              itemBuilder: (_, i) {
                final p       = _resultadosProducto[i];
                final agotado = p.stockActual <= 0;
                return ListTile(
                  dense: true,
                  onTap: agotado ? null : () => _seleccionarProductoNuevo(p),
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: agotado ? Colors.grey.shade100 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_outlined, size: 18,
                        color: agotado ? _kTextMuted : Colors.green.shade600),
                  ),
                  title: Text(p.nombre,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                          color: agotado ? _kTextMuted : _kText)),
                  subtitle: Text('\$${fmt.format(p.precio)}  •  Stock: ${fmt.format(p.stockActual)}',
                      style: GoogleFonts.inter(fontSize: 11,
                          color: agotado ? Colors.red.shade400 : _kTextMuted)),
                  trailing: agotado
                      ? Text('Sin stock', style: GoogleFonts.inter(fontSize: 11,
                            fontWeight: FontWeight.w600, color: Colors.red.shade400))
                      : Icon(Icons.add_circle_rounded, color: _kGreen, size: 22),
                );
              },
            ),
          ],
          if (_resultadosProducto.isEmpty && _busquedaCtrl.text.isEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Text('Busca el producto que entregarás al cliente',
                  style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
                  textAlign: TextAlign.center),
            ),
          ],
        ],

        if (_productoNuevo != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.check_rounded, size: 16, color: Colors.green.shade700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_productoNuevo!.producto.nombre,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    '\$${fmt.format(_productoNuevo!.producto.precio)}  •  Subtotal: \$${fmt.format(_productoNuevo!.subtotal)}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.green.shade700),
                  ),
                ]),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _QtyBtn(icon: Icons.remove_rounded, onTap: _decrementarNuevo),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _productoNuevo!.cantidad % 1 == 0
                        ? _productoNuevo!.cantidad.toStringAsFixed(0)
                        : _productoNuevo!.cantidad.toStringAsFixed(1),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                _QtyBtn(icon: Icons.add_rounded, onTap: _incrementarNuevo),
              ]),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _productoNuevo = null;
                  _montoRecibidoCtrl.clear();
                }),
                child: const Icon(Icons.close_rounded, size: 18, color: _kTextMuted),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _resumenSaldo() {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final hayPendiente = _saldoPendiente > 0;
    final hayDevolver  = _saldoADevolver > 0;
    final color       = hayPendiente ? Colors.orange.shade700 : Colors.green.shade700;
    final bgColor     = hayPendiente ? Colors.orange.shade50  : Colors.green.shade50;
    final borderColor = hayPendiente ? Colors.orange.shade200 : Colors.green.shade200;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: [
        _SaldoRow(label: 'Valor devuelto',       valor: _totalDevuelto, fmt: fmt),
        _SaldoRow(label: 'Total producto nuevo', valor: _totalNuevo,    fmt: fmt),
        const Divider(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hayPendiente ? '⚠ Diferencia a cobrar'
                  : hayDevolver ? '↩ Devolver al cliente'
                  : '✅ Sin diferencia',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              fmt.format(hayPendiente ? _saldoPendiente : hayDevolver ? _saldoADevolver : 0),
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────

  Widget _dropdownResultados({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount.clamp(0, 5),
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: itemBuilder,
        ),
      );

  InputDecoration _inputDeco(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 13, color: _kTextMuted),
    filled: true,
    fillColor: _kSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kGreen, width: 1.5)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tipo-selector button
// ─────────────────────────────────────────────────────────────────────────────

class _TipoBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _TipoBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : _kTextMuted),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? color : _kTextMuted,
            )),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Modelos internos
// ─────────────────────────────────────────────────────────────────────────────

class _ItemCtrl {
  final ProductoDisponibleModel producto;
  final TextEditingController cantidadCtrl;
  final TextEditingController motivoCtrl;
  bool seleccionado;

  _ItemCtrl.fromProducto(this.producto)
      : cantidadCtrl = TextEditingController(
            text: producto.disponible >= 1
                ? producto.disponible.toStringAsFixed(0)
                : producto.disponible.toStringAsFixed(2)),
        motivoCtrl   = TextEditingController(),
        seleccionado = true;

  void dispose() {
    cantidadCtrl.dispose();
    motivoCtrl.dispose();
  }
}

class _ItemNuevo {
  final Producto producto;
  double cantidad;
  _ItemNuevo(this.producto) : cantidad = 1;
  double get subtotal => producto.precio * cantidad;

  Map<String, dynamic> toPayload() => {
    'producto':        producto.id,
    'cantidad':        cantidad.toString(),
    'precio_unitario': producto.precio.toString(),
    'descuento':       0,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Icon(icon, size: 16, color: Colors.green.shade700),
    ),
  );
}

class _SaldoRow extends StatelessWidget {
  final String label;
  final double valor;
  final NumberFormat fmt;
  const _SaldoRow({required this.label, required this.valor, required this.fmt});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
        Text(fmt.format(valor), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _FormLabel extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormLabel({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
          color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _ItemProductoCard extends StatelessWidget {
  final _ItemCtrl    item;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  const _ItemProductoCard({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##', 'es_CO');
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: item.seleccionado ? 1.0 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: item.seleccionado
              ? _kGreen.withValues(alpha: 0.03)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.seleccionado
                ? _kGreen.withValues(alpha: 0.3)
                : _kBorder,
          ),
        ),
        child: Column(children: [
          // Header row: checkbox + nombre + precio
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(children: [
                Transform.scale(
                  scale: 0.9,
                  child: Checkbox(
                    value: item.seleccionado,
                    onChanged: (_) => onToggle(),
                    activeColor: _kGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.producto.productoNombre,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
                    const SizedBox(height: 2),
                    Row(children: [
                      _Chip(label: '\$${fmt.format(item.producto.precioUnitario)}',
                          color: Colors.blueGrey.shade400),
                      const SizedBox(width: 5),
                      _Chip(label: 'Disponible ${fmt.format(item.producto.disponible)}',
                          color: _kGreen),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
          // Campos de cantidad y motivo
          if (item.seleccionado) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: item.cantidadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                    decoration: _deco('Cantidad',
                        helper: 'Máx: ${fmt.format(item.producto.disponible)}'),
                    style: GoogleFonts.inter(fontSize: 13),
                    validator: (_) {
                      if (!item.seleccionado) return null;
                      final v = double.tryParse(item.cantidadCtrl.text.trim()) ?? 0;
                      if (v <= 0) return 'Ingresa cantidad';
                      if (v > item.producto.disponible)
                        return 'Máx ${fmt.format(item.producto.disponible)}';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.motivoCtrl,
                    decoration: _deco('Motivo (opcional)'),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  InputDecoration _deco(String label, {String? helper}) => InputDecoration(
    labelText: label,
    helperText: helper,
    labelStyle: GoogleFonts.inter(fontSize: 11),
    helperStyle: GoogleFonts.inter(fontSize: 10),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kGreen, width: 1.5)),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Buscador de ventas (sin cambios)
// ─────────────────────────────────────────────────────────────────────────────

class _BuscadorVentasSheet extends StatefulWidget {
  final int?         tiendaId;
  final VentaService ventaService;

  const _BuscadorVentasSheet({
    required this.tiendaId,
    required this.ventaService,
  });

  static Future<VentaResumenModel?> show(
    BuildContext context, {
    required int?         tiendaId,
    required VentaService ventaService,
  }) =>
      showModalBottomSheet<VentaResumenModel>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BuscadorVentasSheet(tiendaId: tiendaId, ventaService: ventaService),
      );

  @override
  State<_BuscadorVentasSheet> createState() => _BuscadorVentasSheetState();
}

class _BuscadorVentasSheetState extends State<_BuscadorVentasSheet> {
  final _ctrl                     = TextEditingController();
  DateTime                _fechaSel  = DateTime.now();
  List<VentaResumenModel> _ventas    = [];
  List<VentaResumenModel> _filtradas = [];
  bool                    _cargando  = true;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_filtrar);
    _cargarVentas();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargarVentas() async {
    setState(() => _cargando = true);
    final fecha = DateFormat('yyyy-MM-dd').format(_fechaSel);
    final raw   = await widget.ventaService.listarVentas(
      tiendaId: widget.tiendaId, fecha: fecha,
    );
    if (!mounted) return;
    final ventas = raw
        .map((e) => VentaResumenModel.fromJson(e))
        .where((v) => v.estado != 'anulada')
        .toList();
    setState(() { _ventas = ventas; _cargando = false; });
    _filtrar();
  }

  void _filtrar() {
    final q = _ctrl.text.toLowerCase();
    setState(() {
      _filtradas = q.isEmpty
          ? _ventas
          : _ventas.where((v) =>
              v.numeroFactura.toLowerCase().contains(q) ||
              v.clienteNombre.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSel,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'CO'),
    );
    if (picked == null || !mounted) return;
    setState(() { _fechaSel = picked; _ctrl.clear(); });
    _cargarVentas();
  }

  String _labelFecha() {
    final hoy  = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    if (_fechaSel.year == hoy.year && _fechaSel.month == hoy.month &&
        _fechaSel.day == hoy.day) return 'Hoy';
    if (_fechaSel.year == ayer.year && _fechaSel.month == ayer.month &&
        _fechaSel.day == ayer.day) return 'Ayer';
    return DateFormat('dd/MM/yyyy').format(_fechaSel);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            Text('Buscar venta',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _kText)),
            const Spacer(),
            GestureDetector(
              onTap: _seleccionarFecha,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kMintLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: _kGreen),
                  const SizedBox(width: 5),
                  Text(_labelFecha(), style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _kGreen)),
                  const SizedBox(width: 3),
                  const Icon(Icons.expand_more_rounded, size: 14, color: _kGreen),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar por factura o cliente...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _kTextMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: _kTextMuted, size: 18),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: _kTextMuted),
                      onPressed: _ctrl.clear)
                  : null,
              filled: true, fillColor: _kSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kGreen, width: 1.5)),
            ),
            style: GoogleFonts.inter(fontSize: 14, color: _kText),
          ),
        ),
        const Divider(height: 1, color: _kBorder),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: _kGreen))
              : _ventas.isEmpty
                  ? _buildEmpty()
                  : _filtradas.isEmpty
                      ? Center(child: Text('Sin resultados',
                            style: GoogleFonts.inter(color: _kTextMuted)))
                      : ListView.separated(
                          itemCount: _filtradas.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: _kBorder),
                          itemBuilder: (_, i) {
                            final v = _filtradas[i];
                            return ListTile(
                              onTap: () => Navigator.pop(context, v),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 6),
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: _kMintLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long_rounded,
                                    size: 20, color: _kGreen),
                              ),
                              title: Text(v.numeroFactura,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                                      fontSize: 14, color: _kText)),
                              subtitle: Text(v.clienteNombre,
                                  style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
                              trailing: Text(fmt.format(v.total),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold,
                                      fontSize: 14, color: _kGreen)),
                            );
                          },
                        ),
        ),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.receipt_long_rounded, size: 48, color: _kBorder),
      const SizedBox(height: 12),
      Text(
        'Sin ventas ${_labelFecha().toLowerCase() == 'hoy' ? 'hoy' : 'el ${_labelFecha().toLowerCase()}'}',
        style: GoogleFonts.inter(color: _kTextMuted, fontSize: 14),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _seleccionarFecha,
        icon: const Icon(Icons.calendar_today_rounded, size: 15),
        label: Text('Cambiar fecha', style: GoogleFonts.inter(fontSize: 13)),
        style: TextButton.styleFrom(foregroundColor: _kGreen),
      ),
    ]),
  );
}
