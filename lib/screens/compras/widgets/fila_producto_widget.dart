// lib/screens/compras/widgets/fila_producto_widget.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/proveedores_provider.dart';
import '../compras_theme.dart';

class FilaProductoWidget extends StatefulWidget {
  final int                               index;
  final Map<String, dynamic>              fila;
  final int?                              tiendaId;
  final VoidCallback                      onEliminar;
  final void Function(Map<String, dynamic>) onCambio;

  const FilaProductoWidget({
    super.key,
    required this.index,
    required this.fila,
    required this.tiendaId,
    required this.onEliminar,
    required this.onCambio,
  });

  @override
  State<FilaProductoWidget> createState() => _FilaProductoWidgetState();
}

class _FilaProductoWidgetState extends State<FilaProductoWidget> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _cantCtrl;
  late final TextEditingController _precioCtrl;

  List<Map<String, dynamic>> _sugerencias = [];
  bool _buscando  = false;
  bool _modoLibre = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
        text: widget.fila['nombre']?.toString() ?? '');
    _cantCtrl = TextEditingController(
        text: widget.fila['cantidad']?.toString() ?? '1');
    _precioCtrl = TextEditingController(
        text: widget.fila['precio_unitario']?.toString() ?? '');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    if (q.length < 2) {
      setState(() => _sugerencias = []);
      return;
    }
    setState(() => _buscando = true);
    final res = await context
        .read<ProveedoresProvider>()
        .buscarProductos(q: q, tiendaId: widget.tiendaId);
    setState(() {
      _sugerencias = res;
      _buscando    = false;
    });
  }

  void _notificar() {
    widget.onCambio({
      ...widget.fila,
      'producto':         _modoLibre ? null : widget.fila['producto'],
      'nombre':           _searchCtrl.text,
      'cantidad':         _cantCtrl.text,
      'precio_unitario':  _precioCtrl.text,
      'categoria_nombre': widget.fila['categoria_nombre'] ?? '',
    });
  }

  double get _subtotal =>
      (double.tryParse(_cantCtrl.text) ?? 0) *
      (double.tryParse(_precioCtrl.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    final cats = context
        .watch<ProveedoresProvider>()
        .categoriasSimple;

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toggle modo ─────────────────────────
          Row(children: [
            Text('Producto ${widget.index + 1}',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _modoLibre = !_modoLibre;
                _searchCtrl.clear();
                _sugerencias = [];
                widget.onCambio({
                  ...widget.fila,
                  'producto':         null,
                  'nombre':           '',
                  'categoria_nombre': '',
                });
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _modoLibre
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _modoLibre
                        ? Colors.orange.shade300
                        : Colors.blue.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _modoLibre
                          ? Icons.edit_rounded
                          : Icons.search_rounded,
                      size: 12,
                      color: _modoLibre
                          ? Colors.orange.shade700
                          : Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      _modoLibre
                          ? 'Producto nuevo'
                          : 'Buscar existente',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _modoLibre
                              ? Colors.orange.shade700
                              : Colors.blue.shade700)),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // ── Campos principales ───────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Nombre / búsqueda + categoría
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campo nombre/búsqueda
                    TextFormField(
                      controller: _searchCtrl,
                      style: GoogleFonts.poppins(fontSize: 12),
                      decoration: _inputDeco(
                        _modoLibre
                            ? 'Nombre del producto'
                            : 'Buscar producto',
                      ).copyWith(
                        prefixIcon: Icon(
                          _modoLibre
                              ? Icons.edit_rounded
                              : Icons.search_rounded,
                          size: 16,
                          color: _modoLibre
                              ? Colors.orange.shade400
                              : Colors.grey),
                        suffixIcon: _buscando
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                            : widget.fila['producto'] != null
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: Colors.green.shade500)
                                : null,
                      ),
                      onChanged: (v) {
                        widget.onCambio(
                            {...widget.fila, 'nombre': v});
                        if (!_modoLibre) _buscar(v);
                      },
                    ),

                    // Sugerencias
                    if (!_modoLibre && _sugerencias.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          children: _sugerencias.map((p) {
                            final alerta =
                                p['alerta_stock'] ?? 'ok';
                            final stock =
                                p['stock_actual'] ?? 0;
                            final alertaColor =
                                alerta == 'agotado'
                                    ? Colors.red.shade600
                                    : alerta == 'bajo'
                                        ? Colors.orange.shade600
                                        : Colors.green.shade600;
                            return InkWell(
                              onTap: () {
                                _searchCtrl.text = p['nombre'];
                                widget.onCambio({
                                  ...widget.fila,
                                  'producto': p['id'],
                                  'nombre':   p['nombre'],
                                });
                                setState(() => _sugerencias = []);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(children: [
                                  Expanded(child: Text(
                                    p['nombre'],
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w500))),
                                  if (widget.tiendaId != null)
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 8,
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color: alertaColor
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text('Stock $stock',
                                        style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: alertaColor)),
                                    ),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // Categoría (solo modo libre)
                    if (_modoLibre) ...[
                      const SizedBox(height: 6),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(
                            text: widget.fila['categoria_nombre']
                                    ?.toString() ??
                                ''),
                        optionsBuilder: (tv) {
                          final input = tv.text.toLowerCase();
                          final nombres = cats
                              .map((c) => c['nombre'] as String)
                              .toList();
                          if (input.isEmpty) return nombres;
                          return nombres.where((n) =>
                              n.toLowerCase().contains(input));
                        },
                        onSelected: (v) {
                          widget.onCambio({
                            ...widget.fila,
                            'categoria_nombre': v,
                          });
                          setState(() {});
                        },
                        fieldViewBuilder:
                            (ctx, ctrl, focusNode, onSubmit) {
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) {
                            final val = widget
                                        .fila['categoria_nombre']
                                        ?.toString() ??
                                    '';
                            if (ctrl.text != val) ctrl.text = val;
                          });
                          return TextFormField(
                            controller: ctrl,
                            focusNode:  focusNode,
                            style: GoogleFonts.poppins(
                                fontSize: 12),
                            onChanged: (v) => widget.onCambio({
                              ...widget.fila,
                              'categoria_nombre': v,
                            }),
                            decoration: _inputDeco(
                                    'Categoría (opcional)')
                                .copyWith(
                              prefixIcon: Icon(
                                Icons.category_rounded,
                                size: 16,
                                color: Colors.orange.shade400),
                              hintText: 'Escribe o selecciona...',
                              hintStyle: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade400),
                            ),
                          );
                        },
                        optionsViewBuilder:
                            (ctx, onSelected, options) => Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(10),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 180, maxWidth: 260),
                              child: ListView.builder(
                                padding:    EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount:  options.length,
                                itemBuilder: (_, i) {
                                  final opt = options.elementAt(i);
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      Icons.category_rounded,
                                      size: 14,
                                      color: Colors.orange.shade400),
                                    title: Text(opt,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12)),
                                    onTap: () => onSelected(opt),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Cantidad
              SizedBox(
                width: 72,
                child: TextFormField(
                  controller:   _cantCtrl,
                  style:        GoogleFonts.poppins(fontSize: 12),
                  keyboardType: TextInputType.number,
                  decoration:   _inputDeco('Cant.'),
                  onChanged: (_) {
                    setState(() {});
                    _notificar();
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Precio unitario
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller:   _precioCtrl,
                  style:        GoogleFonts.poppins(fontSize: 12),
                  keyboardType: const TextInputType
                      .numberWithOptions(decimal: true),
                  decoration: _inputDeco('Precio unit.'),
                  onChanged: (_) {
                    setState(() {});
                    _notificar();
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Subtotal
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Subtotal',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade400)),
                    Text('\$${ComprasTheme.fmt(_subtotal)}',
                      style: GoogleFonts.poppins(
                          fontSize:   13,
                          fontWeight: FontWeight.w700,
                          color:      ComprasTheme.dark)),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Eliminar
              IconButton(
                onPressed: widget.onEliminar,
                icon:      const Icon(
                    Icons.delete_outline_rounded),
                color:     Colors.red.shade400,
                iconSize:  20,
                tooltip:   'Eliminar fila',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helper decoration ────────────────────────────────
  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText:  label,
    labelStyle: GoogleFonts.poppins(fontSize: 11),
    isDense:    true,
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 9),
    filled:    true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:   BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:   BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:   const BorderSide(
          color: ComprasTheme.accent, width: 1.5)),
  );
} // ← cierre de _FilaProductoWidgetState