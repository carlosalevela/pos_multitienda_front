import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/cliente.dart';
import '../../../models/separado.dart';
import '../../../providers/cliente_provider.dart';

class SeparadoForm extends StatefulWidget {
  final int?         tiendaId;
  final NumberFormat fmt;
  final VoidCallback? onCreado;

  const SeparadoForm({
    super.key,
    required this.tiendaId,
    required this.fmt,
    this.onCreado,
  });

  // ── Lanzador estático ──────────────────────────────────
  static Future<void> mostrar(
    BuildContext context, {
    required int?         tiendaId,
    required NumberFormat fmt,
    VoidCallback?         onCreado,
  }) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => SeparadoForm(
        tiendaId: tiendaId,
        fmt:      fmt,
        onCreado: onCreado,
      ),
    );
  }

  @override
  State<SeparadoForm> createState() => _SeparadoFormState();
}

// ── Modelo interno de fila de producto ────────────────────────
class _ItemProducto {
  final productoIdCtrl  = TextEditingController();
  final nombreCtrl      = TextEditingController();
  final cantidadCtrl    = TextEditingController();
  final precioCtrl      = TextEditingController();

  double get subtotal {
    final c = double.tryParse(cantidadCtrl.text) ?? 0;
    final p = double.tryParse(precioCtrl.text)   ?? 0;
    return c * p;
  }

  void dispose() {
    productoIdCtrl.dispose();
    nombreCtrl.dispose();
    cantidadCtrl.dispose();
    precioCtrl.dispose();
  }
}

class _SeparadoFormState extends State<SeparadoForm> {
  final _formKey        = GlobalKey<FormState>();
  final _fechaCtrl      = TextEditingController();
  final List<_ItemProducto> _items = [_ItemProducto()];

  Cliente? _clienteSeleccionado;
  bool     _buscandoCliente = false;

  // ── Total calculado en tiempo real ─────────────────────
  double get _total => _items.fold(0, (s, i) => s + i.subtotal);

  @override
  void dispose() {
    _fechaCtrl.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  // ── Buscar cliente con debounce ────────────────────────
  Future<void> _buscarCliente(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _buscandoCliente = true);
    await context.read<ClienteProvider>().cargarClientesSimple(q: q);
    if (mounted) setState(() => _buscandoCliente = false);
  }

  // ── Selector de fecha límite ───────────────────────────
  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: hoy.add(const Duration(days: 7)),
      firstDate:   hoy,
      lastDate:    hoy.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   Color(0xFF01696F),
            onPrimary: Colors.white,
            surface:   Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fechaCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // ── Guardar ────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteSeleccionado == null) {
      _mostrarError('Selecciona un cliente');
      return;
    }
    if (_items.isEmpty) {
      _mostrarError('Agrega al menos un producto');
      return;
    }
    FocusScope.of(context).unfocus();

    final prov = context.read<ClienteProvider>();
    final data = {
      'tienda':      widget.tiendaId,
      'cliente':     _clienteSeleccionado!.id,
      if (_fechaCtrl.text.isNotEmpty) 'fecha_limite': _fechaCtrl.text,
      'detalles': _items.map((i) => {
        'producto':        int.parse(i.productoIdCtrl.text.trim()),
        'cantidad':        double.parse(i.cantidadCtrl.text.trim()),
        'precio_unitario': double.parse(i.precioCtrl.text.trim()),
      }).toList(),
    };

    final ok = await prov.crearSeparado(data);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      widget.onCreado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Separado creado ✅',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: const Color(0xFF437A22),
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      _mostrarError(prov.error ?? 'Error al crear separado');
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: Colors.red.shade600,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Buscador de cliente ────────────────────────────────
  Widget _buscadorCliente() {
    final clientes = context.watch<ClienteProvider>().clientesSimple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Cliente', obligatorio: true),
        const SizedBox(height: 6),

        // Cliente seleccionado
        if (_clienteSeleccionado != null)
          _clienteChip(_clienteSeleccionado!)
        else
          Autocomplete<Cliente>(
            optionsBuilder: (v) async {
              if (v.text.trim().isEmpty) return [];
              await _buscarCliente(v.text);
              return clientes;
            },
            displayStringForOption: (c) => c.nombreCompleto,
            fieldViewBuilder: (_, ctrl, focus, onSubmit) =>
                TextFormField(
                  controller:  ctrl,
                  focusNode:   focus,
                  onFieldSubmitted: (_) => onSubmit(),
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: const Color(0xFF28251D)),
                  decoration: _inputDeco(
                    hint:  'Buscar cliente...',
                    icono: Icons.person_search_outlined,
                    sufijo: _buscandoCliente
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF01696F)))
                        : null,
                  ),
                ),
            optionsViewBuilder: (_, onSelected, options) =>
                Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap:  true,
                        itemCount:   options.length,
                        itemBuilder: (_, i) {
                          final c = options.elementAt(i);
                          return ListTile(
                            leading: const Icon(
                                Icons.person_outline_rounded,
                                size: 18,
                                color: Color(0xFF01696F)),
                            title: Text(c.nombreCompleto,
                                style: GoogleFonts.poppins(fontSize: 13)),
                            subtitle: c.cedulaNit != null
                                ? Text(c.cedulaNit!,
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: const Color(0xFF7A7974)))
                                : null,
                            onTap: () {
                              onSelected(c);
                              setState(() => _clienteSeleccionado = c);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
            onSelected: (c) => setState(() => _clienteSeleccionado = c),
          ),
      ],
    );
  }

  Widget _clienteChip(Cliente c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFCEDCD8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF01696F).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_rounded,
                size: 18, color: Color(0xFF01696F)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.nombreCompleto,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF01696F))),
                  if (c.cedulaNit != null)
                    Text(c.cedulaNit!,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF01696F)
                                .withOpacity(0.7))),
                ],
              ),
            ),
            GestureDetector(
              onTap: () =>
                  setState(() => _clienteSeleccionado = null),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Color(0xFF01696F)),
            ),
          ],
        ),
      );

  // ── Fila de producto ───────────────────────────────────
  Widget _itemProducto(int idx, _ItemProducto item) {
    return StatefulBuilder(
      builder: (_, setLocal) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F8F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEAE5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header fila
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF01696F).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Producto ${idx + 1}',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF01696F))),
                ),
                const Spacer(),
                if (_items.length > 1)
                  GestureDetector(
                    onTap: () => setState(() {
                      item.dispose();
                      _items.removeAt(idx);
                    }),
                    child: Icon(Icons.close_rounded,
                        size: 17, color: Colors.red.shade400),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ID producto + Nombre (referencia)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: _miniCampo(
                    ctrl:  item.productoIdCtrl,
                    hint:  'ID',
                    tipo:  TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Req.' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniCampo(
                    ctrl: item.nombreCtrl,
                    hint: 'Nombre del producto',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Cantidad + Precio + Subtotal
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _miniCampo(
                    ctrl: item.cantidadCtrl,
                    hint: 'Cantidad',
                    tipo: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setLocal(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Req.';
                      if ((double.tryParse(v) ?? 0) <= 0) {
                        return '> 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniCampo(
                    ctrl: item.precioCtrl,
                    hint: 'Precio',
                    tipo: const TextInputType.numberWithOptions(
                        decimal: true),
                    prefijo: '\$',
                    onChanged: (_) => setLocal(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Req.';
                      if ((double.tryParse(v) ?? 0) <= 0) {
                        return '> 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Subtotal calculado
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCEDCD8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.fmt.format(item.subtotal),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF01696F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers de campos ──────────────────────────────────
  Widget _label(String texto, {bool obligatorio = false}) =>
      RichText(
        text: TextSpan(
          text: texto,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7A7974)),
          children: [
            if (obligatorio)
              const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFA12C7B))),
          ],
        ),
      );

  InputDecoration _inputDeco({
    required String hint,
    required IconData icono,
    Widget? sufijo,
  }) =>
      InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.poppins(
            fontSize: 13, color: const Color(0xFFBAB9B4)),
        prefixIcon: Icon(icono, size: 18, color: const Color(0xFF01696F)),
        suffixIcon: sufijo,
        filled:    true,
        fillColor: const Color(0xFFF9F8F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4D1CA))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4D1CA))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF01696F), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      );

  Widget _miniCampo({
    required TextEditingController ctrl,
    required String hint,
    TextInputType? tipo,
    List<TextInputFormatter>? formatters,
    String? prefijo,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) =>
      TextFormField(
        controller:      ctrl,
        keyboardType:    tipo,
        inputFormatters: formatters,
        onChanged:       onChanged,
        validator:       validator,
        style: GoogleFonts.poppins(
            fontSize: 13, color: const Color(0xFF28251D)),
        decoration: InputDecoration(
          hintText:     hint,
          prefixText:   prefijo,
          hintStyle: GoogleFonts.poppins(
              fontSize: 12, color: const Color(0xFFBAB9B4)),
          prefixStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF01696F)),
          filled:    true,
          fillColor: Colors.white,
          isDense:   true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD4D1CA))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD4D1CA))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF01696F), width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red.shade400)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 10),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Handle + título fijo ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF01696F).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(0xFF01696F), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Nuevo separado',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF28251D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 24, color: Colors.grey.shade100),

          // ── Formulario scrollable ──────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Buscador cliente ─────────────────
                    _buscadorCliente(),

                    const SizedBox(height: 20),

                    // ── Fecha límite (opcional) ──────────
                    _label('Fecha límite (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller:  _fechaCtrl,
                      readOnly:    true,
                      onTap:       _elegirFecha,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF28251D)),
                      decoration: _inputDeco(
                        hint:  'Seleccionar fecha...',
                        icono: Icons.event_outlined,
                        sufijo: _fechaCtrl.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () =>
                                    setState(() => _fechaCtrl.clear()),
                                child: const Icon(
                                    Icons.close_rounded,
                                    size: 17,
                                    color: Color(0xFF7A7974)),
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Productos ────────────────────────
                    Row(
                      children: [
                        Text('Productos',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF28251D))),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _items.add(_ItemProducto())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF01696F),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('Agregar',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Lista de productos
                    ...List.generate(
                      _items.length,
                      (i) => _itemProducto(i, _items[i]),
                    ),

                    const SizedBox(height: 8),

                    // ── Total calculado ──────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF01696F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total del separado',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white
                                      .withOpacity(0.85))),
                          Text(
                            widget.fmt.format(_total),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Botón guardar ────────────────────
                    Selector<ClienteProvider, bool>(
                      selector: (_, p) => p.guardando,
                      builder: (_, guardando, __) => SizedBox(
                        width:  double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: guardando ? null : _guardar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF01696F),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                Colors.grey.shade200,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                          ),
                          child: guardando
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5))
                              : Text('Crear separado',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}