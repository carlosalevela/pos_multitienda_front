
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../models/venta_model.dart';
import '../../../models/producto.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/devoluciones_provider.dart';
import '../../../services/venta_service.dart';
import '../../../widgets/common/selector_producto_field.dart';

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
  final _ventaService = VentaService();
  final _formKey = GlobalKey<FormState>();
  final _obsCtrl = TextEditingController();
  final _cantidadReemplazoCtrl = TextEditingController();

  static const _metodos = [
    ('efectivo', 'Efectivo'),
    ('transferencia', 'Transferencia'),
    ('tarjeta', 'Tarjeta'),
    ('nota_credito', 'Nota Crédito'),
  ];

  String _metodoPago = 'efectivo';
  String _tipoOperacion = 'devolucion';
  bool _guardando = false;
  bool _cargandoVenta = false;

  VentaResumenModel? _ventaSel;
  VentaDisponibleModel? _ventaDisp;
  Producto? _productoReemplazoSel;
  final List<_ItemCtrl> _items = [];

  @override
  void dispose() {
    _obsCtrl.dispose();
    _cantidadReemplazoCtrl.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  Future<void> _abrirBuscador() async {
    final auth = context.read<AuthProvider>();
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

    final seleccionada = await _BuscadorVentasSheet.show(context, ventas: ventas);

    if (seleccionada == null) return;
    await _cargarDisponible(seleccionada);
  }

  Future<void> _cargarDisponible(VentaResumenModel venta) async {
    setState(() {
      _cargandoVenta = true;
      _ventaSel = venta;
      _ventaDisp = null;
      _productoReemplazoSel = null;
      _cantidadReemplazoCtrl.clear();
      for (final i in _items) i.dispose();
      _items.clear();
    });

    final raw = await _ventaService.ventaDisponibleDevolucion(venta.id);

    if (!mounted) return;

    if (raw == null) {
      _showSnack('Error al cargar la venta', error: true);
      setState(() {
        _cargandoVenta = false;
        _ventaSel = null;
      });
      return;
    }

    final disp = VentaDisponibleModel.fromJson(raw);

    if (disp.todosDevueltos) {
      _showSnack('Esta venta ya fue devuelta completamente', error: true);
      setState(() {
        _cargandoVenta = false;
        _ventaSel = null;
      });
      return;
    }

    setState(() {
      _cargandoVenta = false;
      _ventaDisp = disp;
      _items.addAll(disp.productos.map(_ItemCtrl.fromProducto));
    });
  }

  void _limpiarVenta() => setState(() {
        _ventaSel = null;
        _ventaDisp = null;
        _productoReemplazoSel = null;
        _cantidadReemplazoCtrl.clear();
        for (final i in _items) i.dispose();
        _items.clear();
      });

  Future<void> _guardar() async {
    if (_ventaDisp == null) {
      _showSnack('Selecciona una venta primero.', error: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final itemsSel = _items.where((i) => i.seleccionado).toList();
    if (itemsSel.isEmpty) {
      _showSnack('Selecciona al menos un producto.', error: true);
      return;
    }

    for (final item in itemsSel) {
      final cant = double.tryParse(item.cantidadCtrl.text.trim()) ?? 0;
      if (cant > item.producto.disponible) {
        _showSnack('${item.producto.productoNombre}: máximo ${item.producto.disponible}.', error: true);
        return;
      }
    }

    if (_tipoOperacion == 'cambio') {
      final cantReemplazo = double.tryParse(_cantidadReemplazoCtrl.text.trim()) ?? 0;
      if (_productoReemplazoSel == null) {
        _showSnack('Selecciona un producto de reemplazo.', error: true);
        return;
      }
      if (cantReemplazo <= 0) {
        _showSnack('Ingresa una cantidad de reemplazo válida.', error: true);
        return;
      }
    }

    setState(() => _guardando = true);

    final detalles = itemsSel.map((i) => {
      'producto': i.producto.productoId,
      'cantidad': double.parse(i.cantidadCtrl.text.trim()),
      'precio_unitario': i.producto.precioUnitario,
      if (i.motivoCtrl.text.trim().isNotEmpty) 'motivo': i.motivoCtrl.text.trim(),
    }).toList();

    Map<String, dynamic> resp;

    if (_tipoOperacion == 'cambio') {
      resp = await context.read<DevolucionesProvider>().crearCambio(
            ventaId: _ventaDisp!.ventaId,
            metodoPago: _metodoPago,
            detalles: detalles,
            productoReemplazoId: _productoReemplazoSel!.id,
            cantidadReemplazo: double.parse(_cantidadReemplazoCtrl.text.trim()),
            observaciones: _obsCtrl.text.trim(),
          );
    } else {
      resp = await context.read<DevolucionesProvider>().crearDevolucion(
            ventaId: _ventaDisp!.ventaId,
            metodoPago: _metodoPago,
            detalles: detalles,
            observaciones: _obsCtrl.text.trim(),
          );
    }

    setState(() => _guardando = false);
    if (!mounted) return;

    if (resp['success'] == true) {
      final msg = _tipoOperacion == 'cambio'
          ? (resp['mensaje_ui']?.toString() ??
              resp['data']?['detail']?.toString() ??
              'Cambio registrado ✅')
          : (resp['data']?['detail']?.toString() ?? 'Devolución registrada ✅');

      Navigator.pop(context);
      widget.onCreada();
      _showSnack(msg);
    } else {
      _showSnack(resp['error']?.toString() ?? 'Error al registrar operación', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ));
  }

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
              _dropdownMetodo(),
              const SizedBox(height: 14),
              _selectorTipo(),
              if (_tipoOperacion == 'cambio') ...[
                const SizedBox(height: 14),
                _camposCambio(),
              ],
              if (_ventaDisp != null) ...[
                const SizedBox(height: 20),
                _seccionProductos(),
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

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
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
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade400),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]);

  Widget _selectorVenta() {
    return _FormLabel(
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
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(Constants.primaryColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Cargando venta...',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
                    ])
                  : _ventaSel == null
                      ? Text('Buscar venta del día',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_ventaSel!.numeroFactura,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(Constants.primaryColor))),
                            Text(
                                '${_ventaSel!.clienteNombre}  •  ${NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(_ventaSel!.total)}',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
            ),
            if (_ventaSel != null)
              GestureDetector(
                onTap: _limpiarVenta,
                child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400),
              )
            else
              Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }

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
            ButtonSegment(value: 'cambio', label: Text('Cambio')),
          ],
          selected: {_tipoOperacion},
          onSelectionChanged: (v) {
            setState(() {
              _tipoOperacion = v.first;
              if (_tipoOperacion != 'cambio') {
                _productoReemplazoSel = null;
                _cantidadReemplazoCtrl.clear();
              }
            });
          },
        ),
      );

  Widget _camposCambio() => Column(
        children: [
          SelectorProductoField(
            productoSeleccionado: _productoReemplazoSel,
            onProductoSeleccionado: (p) {
              setState(() {
                _productoReemplazoSel = p;
              });
            },
          ),
          const SizedBox(height: 14),
          _FormLabel(
            label: 'Cantidad reemplazo',
            child: TextFormField(
              controller: _cantidadReemplazoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDeco('Cantidad a entregar'),
              validator: (v) {
                if (_tipoOperacion != 'cambio') return null;
                final n = double.tryParse((v ?? '').trim()) ?? 0;
                if (n <= 0) return 'Ingresa una cantidad válida';
                return null;
              },
            ),
          ),
        ],
      );

  Widget _seccionProductos() {
    final selCount = _items.where((i) => i.seleccionado).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Productos a devolver',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: const Color(0xFF1A1A2E))),
          const Spacer(),
          Text('$selCount/${_items.length} seleccionados',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 8),
        ..._items.map((item) => _ItemProductoCard(
              key: ValueKey(item.producto.productoId),
              item: item,
              onToggle: () => setState(() => item.seleccionado = !item.seleccionado),
              onChanged: () => setState(() {}),
            )),
      ],
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _tipoOperacion == 'cambio' ? 'Registrar cambio' : 'Registrar devolución',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                ),
        ),
      );

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

class _ItemCtrl {
  final ProductoDisponibleModel producto;
  final cantidadCtrl = TextEditingController();
  final motivoCtrl = TextEditingController();
  bool seleccionado = true;

  _ItemCtrl.fromProducto(this.producto) {
    cantidadCtrl.text = producto.disponible % 1 == 0
        ? producto.disponible.toStringAsFixed(0)
        : producto.disponible.toStringAsFixed(2);
  }

  void dispose() {
    cantidadCtrl.dispose();
    motivoCtrl.dispose();
  }
}

class _BuscadorVentasSheet extends StatefulWidget {
  final List<VentaResumenModel> ventas;

  const _BuscadorVentasSheet({required this.ventas});

  static Future<VentaResumenModel?> show(BuildContext context, {required List<VentaResumenModel> ventas}) {
    return showModalBottomSheet<VentaResumenModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuscadorVentasSheet(ventas: ventas),
    );
  }

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
          .where((v) => v.numeroFactura.toLowerCase().contains(q) || v.clienteNombre.toLowerCase().contains(q))
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
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            Text('Ventas de hoy', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text('${widget.ventas.length} ventas', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar por factura o cliente...',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
                      onPressed: () {
                        _ctrl.clear();
                        _filtrar();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(Constants.primaryColor), width: 1.5)),
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
                      Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No hay ventas hoy', style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14)),
                    ],
                  ),
                )
              : _filtradas.isEmpty
                  ? Center(child: Text('Sin resultados', style: GoogleFonts.poppins(color: Colors.grey.shade400)))
                  : ListView.separated(
                      itemCount: _filtradas.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (_, i) {
                        final v = _filtradas[i];
                        return ListTile(
                          onTap: () => Navigator.pop(context, v),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(Constants.primaryColor).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(Constants.primaryColor)),
                          ),
                          title: Text(v.numeroFactura, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(v.clienteNombre, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                          trailing: Text(
                            fmt.format(v.total),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(Constants.primaryColor)),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormLabel({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
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
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: item.seleccionado,
                  onChanged: (_) => onToggle(),
                  activeColor: const Color(Constants.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ]),
            Row(children: [
              _Chip(
                label: 'Precio: \$${fmt.format(item.producto.precioUnitario)}',
                color: Colors.blueGrey.shade400,
              ),
              const SizedBox(width: 6),
              _Chip(
                label: 'Disponible: ${fmt.format(item.producto.disponible)}',
                color: Colors.green.shade600,
              ),
            ]),
            if (item.seleccionado) ...[
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: item.cantidadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                    decoration: _deco(
                      'Cantidad',
                      helper: 'Máx: ${fmt.format(item.producto.disponible)}',
                    ),
                    style: GoogleFonts.poppins(fontSize: 13),
                    validator: (_) {
                      if (!item.seleccionado) return null;
                      final v = double.tryParse(item.cantidadCtrl.text.trim()) ?? 0;
                      if (v <= 0) return 'Ingresa cantidad';
                      if (v > item.producto.disponible) return 'Máx ${fmt.format(item.producto.disponible)}';
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(Constants.primaryColor), width: 1.5)),
      );
}
