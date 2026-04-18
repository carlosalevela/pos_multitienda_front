import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../models/venta_model.dart';
import '../../../models/producto.dart';
import '../../../models/cliente.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/devoluciones_provider.dart';
import '../../../services/venta_service.dart';
import '../../../services/inventario_service.dart';
import '../../../services/cliente_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DevolucionFormSheet
// ─────────────────────────────────────────────────────────────────────────────

class DevolucionFormSheet extends StatefulWidget {
  final VoidCallback onCreada;
  const DevolucionFormSheet({super.key, required this.onCreada});

  static void show(BuildContext context, {required VoidCallback onCreada}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DevolucionFormSheet(onCreada: onCreada),
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

  // ── Opciones de método de pago ────────────────────────
  static const _metodos = [
    ('efectivo',      'Efectivo'),
    ('transferencia', 'Transferencia'),
    ('tarjeta',       'Tarjeta'),
    ('nota_credito',  'Nota Crédito'),
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

  // ── Producto nuevo (solo cambio — un único producto) ──
  List<Producto>  _resultadosProducto = [];
  bool            _buscandoProducto   = false;
  _ItemNuevo?     _productoNuevo;          // ← un solo objeto, no lista

  // ── Cliente (solo cambio, opcional) ──────────────────
  List<Cliente> _resultadosCliente = [];
  bool          _buscandoCliente   = false;
  Cliente?      _clienteSel;

  // ─────────────────────────────────────────────────────
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

    final raw = await _ventaService.listarVentas(
      tiendaId: tiendaId,
      fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    final ventas = raw
        .map((e) => VentaResumenModel.fromJson(e))
        .where((v) => v.estado != 'anulada')
        .toList();

    if (!mounted) return;
    final sel = await _BuscadorVentasSheet.show(context, ventas: ventas);
    if (sel == null) return;
    await _cargarDisponible(sel);
  }

  Future<void> _cargarDisponible(VentaResumenModel venta) async {
    setState(() {
      _cargandoVenta    = true;
      _ventaSel         = venta;
      _ventaDisp        = null;
      _productoNuevo    = null;
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
    final lista    = await _inventarioSvc.getProductos(q: query, tiendaId: tiendaId);
    if (!mounted) return;
    setState(() {
      _resultadosProducto = lista;
      _buscandoProducto   = false;
    });
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
      _showSnack(
        'Stock máximo: ${item.producto.stockActual.toStringAsFixed(0)}',
        error: true,
      );
      return;
    }
    setState(() => item.cantidad++);
  }

  void _decrementarNuevo() {
    final item = _productoNuevo;
    if (item == null) return;
    setState(() {
      if (item.cantidad > 1) {
        item.cantidad--;
      } else {
        _productoNuevo = null;
      }
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
    setState(() {
      _resultadosCliente = lista;
      _buscandoCliente   = false;
    });
  }

  void _seleccionarCliente(Cliente c) {
    _clienteCtrl.text = c.nombreCompleto;
    setState(() {
      _clienteSel        = c;
      _resultadosCliente = [];
    });
  }

  void _limpiarCliente() {
    _clienteCtrl.clear();
    setState(() {
      _clienteSel        = null;
      _resultadosCliente = [];
    });
  }

  // ── Totales y diferencia ──────────────────────────────

  double get _totalDevuelto => _items
      .where((i) => i.seleccionado)
      .fold(0.0, (s, i) {
        final cant = double.tryParse(i.cantidadCtrl.text.trim()) ?? 0;
        return s + i.producto.precioUnitario * cant;
      });

  double get _totalNuevo    => _productoNuevo?.subtotal ?? 0.0;
  double get _diferenciaNeta => _totalNuevo - _totalDevuelto;
  double get _saldoPendiente => _diferenciaNeta > 0 ? _diferenciaNeta : 0.0;
  double get _saldoADevolver => _diferenciaNeta < 0 ? _diferenciaNeta.abs() : 0.0;

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
        _showSnack(
          '${item.producto.productoNombre}: máximo ${item.producto.disponible}.',
          error: true,
        );
        return;
      }
    }

    if (_tipoOperacion == 'cambio' && _productoNuevo == null) {
      _showSnack('Selecciona el producto de reemplazo.', error: true);
      return;
    }

    // Validar monto recibido cuando hay diferencia por cobrar
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
        ventaId:               _ventaDisp!.ventaId,
        metodoPago:            _metodoPago,
        detalles:              detallesDevueltos,
        productoReemplazoId:   _productoNuevo!.producto.id,
        cantidadReemplazo:     _productoNuevo!.cantidad,
        observaciones:         _obsCtrl.text.trim(),
        metodoPagoDiferencia:  _saldoPendiente > 0 ? _metodoPagoDiferencia : null,
        montoRecibido:         _saldoPendiente > 0 ? montoRecibido : null,
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
      final msg = _tipoOperacion == 'cambio'
          ? (resp['mensaje_ui']?.toString() ?? 'Cambio registrado ✅')
          : (resp['data']?['detail']?.toString() ?? 'Devolución registrada ✅');
      Navigator.pop(context);
      widget.onCreada();
      _showSnack(msg);
    } else {
      _showSnack(
        resp['error']?.toString() ?? 'Error al registrar operación',
        error: true,
      );
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handle(),
              _titulo(),
              const SizedBox(height: 20),
              _selectorVenta(),
              const SizedBox(height: 14),

              if (_tipoOperacion == 'devolucion') ...[
                _dropdownMetodo(),
                const SizedBox(height: 14),
              ],

              _selectorTipo(),

              if (_ventaDisp != null) ...[
                const SizedBox(height: 20),
                _seccionProductosDevueltos(),
              ],

              if (_tipoOperacion == 'cambio') ...[
                const SizedBox(height: 20),
                _seccionClienteCambio(),
                const SizedBox(height: 20),
                _seccionProductoNuevo(),
              ],

              // Resumen saldo: solo cuando hay algo seleccionado Y hay producto nuevo
              if (_tipoOperacion == 'cambio' &&
                  _items.any((i) => i.seleccionado) &&
                  _productoNuevo != null) ...[
                const SizedBox(height: 16),
                _resumenSaldo(),
              ],

              const SizedBox(height: 14),
              _campoObservaciones(),
              const SizedBox(height: 24),
              _botonGuardar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Widgets
  // ─────────────────────────────────────────────────────

  Widget _handle() => Center(
    child: Container(
      width: 40, height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _titulo() => Row(children: [
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(Constants.primaryColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.assignment_return_rounded,
          color: const Color(Constants.primaryColor), size: 18),
    ),
    const SizedBox(width: 10),
    Text(
      _tipoOperacion == 'cambio' ? 'Nuevo cambio' : 'Nueva devolución',
      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
    ),
    const Spacer(),
    IconButton(
      icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade400),
      onPressed: () => Navigator.pop(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
  ]);

  Widget _selectorVenta() => _FormLabel(
    label: 'Venta a devolver',
    child: GestureDetector(
      onTap: _cargandoVenta ? null : _abrirBuscador,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _ventaSel != null
              ? const Color(Constants.primaryColor).withOpacity(0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _ventaSel != null
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade200,
            width: _ventaSel != null ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            _ventaSel != null ? Icons.receipt_long_rounded : Icons.search_rounded,
            size: 18,
            color: _ventaSel != null
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _cargandoVenta
                ? Row(children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(Constants.primaryColor)),
                    ),
                    const SizedBox(width: 8),
                    Text('Cargando venta...',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey.shade500)),
                  ])
                : _ventaSel == null
                    ? Text('Buscar venta del día',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey.shade400))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_ventaSel!.numeroFactura,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(Constants.primaryColor))),
                          Text(
                            '${_ventaSel!.clienteNombre}  •  '
                            '${NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(_ventaSel!.total)}',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
          ),
          if (_ventaSel != null)
            GestureDetector(
              onTap: _limpiarVenta,
              child: Icon(Icons.close_rounded,
                  size: 16, color: Colors.grey.shade400),
            )
          else
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.grey.shade400),
        ]),
      ),
    ),
  );

  Widget _dropdownMetodo() => _FormLabel(
    label: 'Método de devolución',
    child: DropdownButtonFormField<String>(
      value: _metodoPago,
      isDense: true,
      decoration: _inputDeco(null),
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A2E)),
      items: _metodos
          .map((m) => DropdownMenuItem(
                value: m.$1,
                child: Text(m.$2, style: GoogleFonts.poppins(fontSize: 14)),
              ))
          .toList(),
      onChanged: (v) => setState(() => _metodoPago = v!),
    ),
  );

  Widget _selectorTipo() => _FormLabel(
    label: 'Tipo de operación',
    child: SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'devolucion', label: Text('Devolución')),
        ButtonSegment(value: 'cambio',     label: Text('Cambio')),
      ],
      selected: {_tipoOperacion},
      onSelectionChanged: (v) => setState(() {
        _tipoOperacion  = v.first;
        if (_tipoOperacion != 'cambio') {
          _productoNuevo      = null;
          _resultadosProducto = [];
          _busquedaCtrl.clear();
          _montoRecibidoCtrl.clear();
          _limpiarCliente();
        }
      }),
    ),
  );

  // ── Cliente ───────────────────────────────────────────

  Widget _seccionClienteCambio() => _FormLabel(
    label: 'Cliente (opcional)',
    child: Column(children: [
      TextField(
        controller: _clienteCtrl,
        onChanged: _clienteSel == null ? _buscarClientes : null,
        readOnly: _clienteSel != null,
        decoration: InputDecoration(
          hintText: 'Buscar cliente por nombre o cédula...',
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: _clienteSel != null
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor:
                        const Color(Constants.primaryColor).withOpacity(0.1),
                    child: Text(
                      _clienteSel!.nombre[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(Constants.primaryColor)),
                    ),
                  ),
                )
              : Icon(Icons.person_search_rounded,
                  size: 18, color: Colors.grey.shade400),
          suffixIcon: _buscandoCliente
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(Constants.primaryColor)),
                  ),
                )
              : _clienteSel != null
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey.shade400),
                      onPressed: _limpiarCliente,
                    )
                  : _clienteCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: Colors.grey.shade400),
                          onPressed: () {
                            _clienteCtrl.clear();
                            setState(() => _resultadosCliente = []);
                          },
                        )
                      : null,
          filled: true,
          fillColor: _clienteSel != null
              ? const Color(Constants.primaryColor).withOpacity(0.04)
              : Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: _clienteSel != null
                      ? const Color(Constants.primaryColor)
                      : Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: _clienteSel != null
                      ? const Color(Constants.primaryColor)
                      : Colors.grey.shade200,
                  width: _clienteSel != null ? 1.5 : 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(Constants.primaryColor), width: 1.5)),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
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
                backgroundColor:
                    const Color(Constants.primaryColor).withOpacity(0.1),
                child: Text(c.nombre[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(Constants.primaryColor))),
              ),
              title: Text(c.nombreCompleto,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                [
                  if (c.cedulaNit != null && c.cedulaNit!.isNotEmpty) c.cedulaNit!,
                  if (c.telefono.isNotEmpty) c.telefono,
                ].join('  •  '),
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.grey.shade400),
            );
          },
        ),
      ],
    ]),
  );

  // ── Productos devueltos ───────────────────────────────

  Widget _seccionProductosDevueltos() {
    final selCount = _items.where((i) => i.seleccionado).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            _tipoOperacion == 'cambio'
                ? 'Productos que trae el cliente'
                : 'Productos a devolver',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF1A1A2E)),
          ),
          const Spacer(),
          Text('$selCount/${_items.length} seleccionados',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 8),
        ..._items.map((item) => _ItemProductoCard(
              key: ValueKey(item.producto.productoId),
              item: item,
              onToggle: () =>
                  setState(() => item.seleccionado = !item.seleccionado),
              onChanged: () => setState(() {}),
            )),
      ],
    );
  }

  // ── Producto nuevo (cambio — selección única) ─────────

  Widget _seccionProductoNuevo() {
    final fmt = NumberFormat('#,##0.##', 'es_CO');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shopping_bag_outlined,
                size: 16, color: Colors.green.shade700),
          ),
          const SizedBox(width: 8),
          Text(
            'Producto de reemplazo',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF1A1A2E)),
          ),
        ]),
        const SizedBox(height: 10),

        // Buscador — solo visible si no hay producto seleccionado
        if (_productoNuevo == null) ...[
          TextField(
            controller: _busquedaCtrl,
            onChanged: _buscarProductos,
            decoration: InputDecoration(
              hintText: 'Buscar producto por nombre o código...',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 18, color: Colors.grey.shade400),
              suffixIcon: _buscandoProducto
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(Constants.primaryColor)),
                      ),
                    )
                  : _busquedaCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: Colors.grey.shade400),
                          onPressed: () {
                            _busquedaCtrl.clear();
                            setState(() => _resultadosProducto = []);
                          },
                        )
                      : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(Constants.primaryColor), width: 1.5)),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),

          // Resultados de búsqueda
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
                      color: agotado
                          ? Colors.grey.shade100
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        size: 18,
                        color: agotado
                            ? Colors.grey.shade400
                            : Colors.green.shade600),
                  ),
                  title: Text(p.nombre,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: agotado
                              ? Colors.grey.shade400
                              : const Color(0xFF1A1A2E))),
                  subtitle: Text(
                    '\$${fmt.format(p.precio)}  •  Stock: ${fmt.format(p.stockActual)}',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: agotado
                            ? Colors.red.shade400
                            : Colors.grey.shade500),
                  ),
                  trailing: agotado
                      ? Text('Sin stock',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade400))
                      : Icon(Icons.add_circle_rounded,
                          color: const Color(Constants.primaryColor), size: 22),
                );
              },
            ),
          ],

          if (_resultadosProducto.isEmpty && _busquedaCtrl.text.isEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Busca el producto que entregarás al cliente',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],

        // Tarjeta del producto seleccionado
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
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.check_rounded,
                    size: 16, color: Colors.green.shade700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_productoNuevo!.producto.nombre,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      '\$${fmt.format(_productoNuevo!.producto.precio)}  •  '
                      'Subtotal: \$${fmt.format(_productoNuevo!.subtotal)}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
              // Controles de cantidad
              Row(mainAxisSize: MainAxisSize.min, children: [
                _QtyBtn(icon: Icons.remove_rounded, onTap: _decrementarNuevo),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _productoNuevo!.cantidad % 1 == 0
                        ? _productoNuevo!.cantidad.toStringAsFixed(0)
                        : _productoNuevo!.cantidad.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                _QtyBtn(icon: Icons.add_rounded, onTap: _incrementarNuevo),
              ]),
              // Botón eliminar selección
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _productoNuevo = null;
                  _montoRecibidoCtrl.clear();
                }),
                child: Icon(Icons.close_rounded,
                    size: 18, color: Colors.grey.shade400),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ── Resumen de saldo ──────────────────────────────────

  Widget _resumenSaldo() {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final montoRaw = double.tryParse(_montoRecibidoCtrl.text.trim()) ?? 0;

    // Determinar colores según estado
    final bool hayPendiente = _saldoPendiente > 0;
    final bool hayDevolver  = _saldoADevolver > 0;
    final color       = hayPendiente ? Colors.orange.shade700  : Colors.green.shade700;
    final bgColor     = hayPendiente ? Colors.orange.shade50   : Colors.green.shade50;
    final borderColor = hayPendiente ? Colors.orange.shade200  : Colors.green.shade200;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: [
        _SaldoRow(label: 'Valor devuelto',         valor: _totalDevuelto, fmt: fmt),
        _SaldoRow(label: 'Total producto nuevo',   valor: _totalNuevo,    fmt: fmt),
        const Divider(height: 14),

        // Caso 1: hay diferencia que el cliente debe pagar
        if (hayPendiente) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('⚠ Diferencia a cobrar',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700)),
              Text(fmt.format(_saldoPendiente),
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700)),
            ],
          ),
          const SizedBox(height: 12),
          _FormLabel(
            label: 'Método de pago de la diferencia',
            child: DropdownButtonFormField<String>(
              value: _metodoPagoDiferencia,
              isDense: true,
              decoration: _inputDeco(null),
              items: _metodos
                  .where((m) => m.$1 != 'nota_credito')
                  .map((m) => DropdownMenuItem<String>(
                        value: m.$1,
                        child: Text(m.$2, style: GoogleFonts.poppins(fontSize: 14)),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: _inputDeco('Ej: 20000'),
              style: GoogleFonts.poppins(fontSize: 14),
              validator: (_) {
                if (_tipoOperacion != 'cambio' || _saldoPendiente <= 0) return null;
                final v = double.tryParse(_montoRecibidoCtrl.text.trim());
                if (v == null || v <= 0) return 'Ingresa un monto válido';
                if (v < _saldoPendiente)  return 'Debe cubrir la diferencia';
                return null;
              },
            ),
          ),
          // Cambio devuelto al cliente (efectivo)
          if (_metodoPagoDiferencia == 'efectivo' && montoRaw >= _saldoPendiente) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cambio: ${fmt.format(montoRaw - _saldoPendiente)}',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800),
                ),
              ),
            ),
          ],
        ]

        // Caso 2: tienda debe devolver dinero al cliente
        else if (hayDevolver) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('↩ Devolver al cliente',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade700)),
              Text(fmt.format(_saldoADevolver),
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade700)),
            ],
          ),
        ]

        // Caso 3: exacto
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('✅ Valor exacto, sin diferencia',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700)),
              Text(fmt.format(0),
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700)),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _campoObservaciones() => _FormLabel(
    label: 'Observaciones (opcional)',
    child: TextFormField(
      controller: _obsCtrl,
      maxLines: 2,
      decoration: _inputDeco('Motivo general de la devolución...'),
      style: GoogleFonts.poppins(fontSize: 14),
    ),
  );

  Widget _botonGuardar() => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _guardando ? null : _guardar,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(Constants.primaryColor),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _guardando
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              _tipoOperacion == 'cambio' ? 'Registrar cambio' : 'Registrar devolución',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
            ),
    ),
  );

  // ── Helper: contenedor dropdown resultados ────────────

  Widget _dropdownResultados({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount.clamp(0, 5),
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: itemBuilder,
        ),
      );

  // ── InputDecoration compartida ────────────────────────

  InputDecoration _inputDeco(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
    filled: true,
    fillColor: Colors.grey.shade50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(Constants.primaryColor), width: 1.5)),
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
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
        Text(fmt.format(valor),
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600)),
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
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}

class _ItemProductoCard extends StatelessWidget {
  final _ItemCtrl item;
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.seleccionado
                ? const Color(Constants.primaryColor).withOpacity(0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(item.producto.productoNombre,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: item.seleccionado,
                  onChanged: (_) => onToggle(),
                  activeColor: const Color(Constants.primaryColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ]),
            Row(children: [
              _Chip(
                  label: 'Precio \$${fmt.format(item.producto.precioUnitario)}',
                  color: Colors.blueGrey.shade400),
              const SizedBox(width: 6),
              _Chip(
                  label: 'Disponible ${fmt.format(item.producto.disponible)}',
                  color: Colors.green.shade600),
            ]),
            if (item.seleccionado) ...[
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: item.cantidadCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                    decoration: _deco(
                      'Cantidad',
                      helper: 'Máx: ${fmt.format(item.producto.disponible)}',
                    ),
                    style: GoogleFonts.poppins(fontSize: 13),
                    validator: (_) {
                      if (!item.seleccionado) return null;
                      final v = double.tryParse(
                              item.cantidadCtrl.text.trim()) ??
                          0;
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
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, {String? helper}) => InputDecoration(
    labelText: label,
    helperText: helper,
    labelStyle: GoogleFonts.poppins(fontSize: 11),
    helperStyle: GoogleFonts.poppins(fontSize: 10),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
            color: Color(Constants.primaryColor), width: 1.5)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Buscador de ventas
// ─────────────────────────────────────────────────────────────────────────────

class _BuscadorVentasSheet extends StatefulWidget {
  final List<VentaResumenModel> ventas;
  const _BuscadorVentasSheet({required this.ventas});

  static Future<VentaResumenModel?> show(
    BuildContext context, {
    required List<VentaResumenModel> ventas,
  }) =>
      showModalBottomSheet<VentaResumenModel>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BuscadorVentasSheet(ventas: ventas),
      );

  @override
  State<_BuscadorVentasSheet> createState() => _BuscadorVentasSheetState();
}

class _BuscadorVentasSheetState extends State<_BuscadorVentasSheet> {
  final _ctrl = TextEditingController();
  late List<VentaResumenModel> _filtradas;

  @override
  void initState() {
    super.initState();
    _filtradas = widget.ventas;
    _ctrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _filtrar() {
    final q = _ctrl.text.toLowerCase();
    setState(() {
      _filtradas = widget.ventas
          .where((v) =>
              v.numeroFactura.toLowerCase().contains(q) ||
              v.clienteNombre.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            Text('Ventas de hoy',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text('${widget.ventas.length} ventas',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar por factura o cliente...',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey.shade400),
                      onPressed: _ctrl.clear,
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(Constants.primaryColor), width: 1.5)),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: widget.ventas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No hay ventas hoy',
                          style: GoogleFonts.poppins(
                              color: Colors.grey.shade400, fontSize: 14)),
                    ],
                  ),
                )
              : _filtradas.isEmpty
                  ? Center(
                      child: Text('Sin resultados',
                          style: GoogleFonts.poppins(
                              color: Colors.grey.shade400)))
                  : ListView.separated(
                      itemCount: _filtradas.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (_, i) {
                        final v = _filtradas[i];
                        return ListTile(
                          onTap: () => Navigator.pop(context, v),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: const Color(Constants.primaryColor)
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded,
                                size: 20,
                                color: Color(Constants.primaryColor)),
                          ),
                          title: Text(v.numeroFactura,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(v.clienteNombre,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey.shade500)),
                          trailing: Text(fmt.format(v.total),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color(Constants.primaryColor))),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
