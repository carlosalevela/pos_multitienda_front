// lib/screens/compras/widgets/fila_producto_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../compras_theme.dart'; // solo fmt() y calcularTotal()

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
        color:        AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
        border:       Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toggle modo ─────────────────────────
          Row(children: [
            Text('Producto ${widget.index + 1}',
                style: AppTextStyles.labelMd),
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
                      ? AppColors.warningContainer
                      : AppColors.surfaceContainer,
                  borderRadius: AppRadius.full,
                  border: Border.all(
                    color: _modoLibre
                        ? AppColors.warning.withOpacity(0.45)
                        : AppColors.outlineVariant),
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
                          ? AppColors.warning
                          : AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _modoLibre
                          ? 'Producto nuevo'
                          : 'Buscar existente',
                      style: AppTextStyles.labelSm.copyWith(
                          color: _modoLibre
                              ? AppColors.warning
                              : AppColors.onSurfaceVariant)),
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
                    TextFormField(
                      controller: _searchCtrl,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.onSurface),
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
                              ? AppColors.warning
                              : AppColors.outline),
                        suffixIcon: _buscando
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.secondary)))
                            : widget.fila['producto'] != null
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppColors.secondary)
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
                          color:        AppColors.surfaceContainerLowest,
                          borderRadius: AppRadius.lg,
                          border: Border.all(color: AppColors.outlineVariant),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          children: _sugerencias.map((p) {
                            final alerta = p['alerta_stock'] ?? 'ok';
                            final stock  = p['stock_actual'] ?? 0;
                            final alertaColor = alerta == 'agotado'
                                ? AppColors.error
                                : alerta == 'bajo'
                                    ? AppColors.warning
                                    : AppColors.secondary;
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
                                    style: AppTextStyles.bodyMd.copyWith(
                                        fontWeight: FontWeight.w500))),
                                  if (widget.tiendaId != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: alertaColor.withOpacity(0.1),
                                        borderRadius: AppRadius.lg,
                                      ),
                                      child: Text('Stock $stock',
                                        style: AppTextStyles.labelSm.copyWith(
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
                                    ?.toString() ?? ''),
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
                            final val = widget.fila['categoria_nombre']
                                        ?.toString() ?? '';
                            if (ctrl.text != val) ctrl.text = val;
                          });
                          return TextFormField(
                            controller: ctrl,
                            focusNode:  focusNode,
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.onSurface),
                            onChanged: (v) => widget.onCambio({
                              ...widget.fila,
                              'categoria_nombre': v,
                            }),
                            decoration: _inputDeco('Categoría (opcional)')
                                .copyWith(
                              prefixIcon: Icon(
                                Icons.category_rounded,
                                size: 16,
                                color: AppColors.warning),
                              hintText: 'Escribe o selecciona...',
                              hintStyle: AppTextStyles.bodySm
                                  .copyWith(color: AppColors.outline),
                            ),
                          );
                        },
                        optionsViewBuilder:
                            (ctx, onSelected, options) => Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(10)),
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
                                      color: AppColors.warning),
                                    title: Text(opt,
                                        style: AppTextStyles.bodySm
                                            .copyWith(
                                                color: AppColors.onSurface)),
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
                  style:        AppTextStyles.bodySm
                      .copyWith(color: AppColors.onSurface),
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
                  style:        AppTextStyles.bodySm
                      .copyWith(color: AppColors.onSurface),
                  keyboardType: const TextInputType
                      .numberWithOptions(decimal: true),
                  decoration:   _inputDeco('Precio unit.'),
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
                    Text('Subtotal', style: AppTextStyles.labelSm),
                    Text('\$${ComprasTheme.fmt(_subtotal)}',
                      style: AppTextStyles.bodyMd.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Eliminar
              IconButton(
                onPressed: widget.onEliminar,
                icon:      const Icon(Icons.delete_outline_rounded),
                color:     AppColors.error,
                iconSize:  20,
                tooltip:   'Eliminar fila',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.errorContainer,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.lg),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText:  label,
    labelStyle: AppTextStyles.labelSm,
    isDense:    true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    filled:    true,
    fillColor: AppColors.surfaceContainerLowest,
    border: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      borderSide:   const BorderSide(color: AppColors.outlineVariant)),
    enabledBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      borderSide:   const BorderSide(color: AppColors.outlineVariant)),
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      borderSide:   const BorderSide(color: AppColors.secondary, width: 1.5)),
  );
}
