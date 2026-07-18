// lib/screens/compras/widgets/pdf_preview_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../compras_theme.dart'; // fmt()

class PdfPreviewDialog extends StatefulWidget {
  final List<Map<String, dynamic>> productos;

  const PdfPreviewDialog({super.key, required this.productos});

  static Future<List<Map<String, dynamic>>?> mostrar(
    BuildContext context,
    List<Map<String, dynamic>> productos,
  ) =>
      showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PdfPreviewDialog(productos: productos),
      );

  @override
  State<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<PdfPreviewDialog> {
  late final List<_FilaEditable> _filas;

  @override
  void initState() {
    super.initState();
    _filas = widget.productos.map((p) => _FilaEditable(p)).toList();
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  double get _total => _filas.fold(0, (s, f) => s + f.subtotal);

  void _refrescarTotal() => setState(() {});

  void _eliminarFila(int idx) => setState(() => _filas.removeAt(idx));

  void _confirmar() {
    final result = _filas.map((f) {
      final pv = double.tryParse(f.ventaCtrl.text) ?? 0;
      return {
        'producto':            null,
        'nombre':              f.nombreCtrl.text.trim(),
        'codigo_barras_input': f.codigoCtrl.text.trim(),
        'cantidad':            f.cantCtrl.text,
        'precio_unitario':     f.costoCtrl.text,
        'precio_venta':        pv > 0 ? f.ventaCtrl.text : null,
        'categoria_nombre':    f.categoriaCtrl.text.trim(),
      };
    }).toList();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
      titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(children: [
        const Icon(Icons.picture_as_pdf_rounded,
            color: AppColors.secondary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Revisar productos del PDF',
                  style: AppTextStyles.headlineSm),
              Text(
                'Edita nombre, código, costo y precio de venta antes de importar',
                style: AppTextStyles.bodySm,
              ),
            ],
          ),
        ),
      ]),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),

            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.58,
              ),
              child: _filas.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No quedan productos')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filas.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _FilaCard(
                        key: ValueKey(i),
                        fila: _filas[i],
                        numero: i + 1,
                        onEliminar: () => _eliminarFila(i),
                        onTotalChanged: _refrescarTotal,
                      ),
                    ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.outlineVariant),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_filas.length} producto(s)',
                    style: AppTextStyles.bodySm),
                Row(children: [
                  Text('Total estimado: ',
                      style: AppTextStyles.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                  Text('\$${ComprasTheme.fmt(_total)}',
                      style: AppTextStyles.numericData
                          .copyWith(color: AppColors.secondary)),
                ]),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Cancelar',
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ),
        ElevatedButton.icon(
          onPressed: _filas.isEmpty ? null : _confirmar,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: Text('Importar ${_filas.length} producto(s)',
              style: AppTextStyles.bodyMd
                  .copyWith(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.onSecondary,
            elevation: 0,
            shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.xl),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ── Datos editables ───────────────────────────────────────────

class _FilaEditable {
  final TextEditingController nombreCtrl;
  final TextEditingController codigoCtrl;
  final TextEditingController categoriaCtrl;
  final TextEditingController cantCtrl;
  final TextEditingController costoCtrl;
  final TextEditingController ventaCtrl;

  _FilaEditable(Map<String, dynamic> p)
      : nombreCtrl    = TextEditingController(
            text: _limpiarNombre(p['nombre']?.toString() ?? '')),
        codigoCtrl    = TextEditingController(
            text: _extraerCodigo(p['nombre']?.toString() ?? '')),
        categoriaCtrl = TextEditingController(),
        cantCtrl      = TextEditingController(
            text: _fmtNum(p['cantidad'] ?? 1)),
        costoCtrl     = TextEditingController(
            text: _fmtNum(p['precio_unitario'] ?? 0)),
        ventaCtrl     = TextEditingController();

  double get subtotal =>
      (double.tryParse(cantCtrl.text) ?? 0) *
      (double.tryParse(costoCtrl.text) ?? 0);

  void dispose() {
    nombreCtrl.dispose();
    codigoCtrl.dispose();
    categoriaCtrl.dispose();
    cantCtrl.dispose();
    costoCtrl.dispose();
    ventaCtrl.dispose();
  }

  static String _extraerCodigo(String nombre) {
    final tok = nombre.split(' ');
    if (tok.isEmpty) return '';
    final p = tok.first;
    if (RegExp(r'^[A-Z]{1,8}[-_./]', caseSensitive: false).hasMatch(p) ||
        RegExp(r'^[A-Z]{2,}\d{3,}$', caseSensitive: false).hasMatch(p)) {
      return p;
    }
    return '';
  }

  static String _limpiarNombre(String nombre) {
    final c = _extraerCodigo(nombre);
    if (c.isEmpty) return nombre;
    final s = nombre.substring(c.length).trim();
    return s.isEmpty ? nombre : s;
  }

  static String _fmtNum(dynamic v) {
    final d = double.tryParse(v.toString()) ?? 0;
    return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
  }
}

// ── Card por producto ─────────────────────────────────────────

class _FilaCard extends StatefulWidget {
  final _FilaEditable fila;
  final int           numero;
  final VoidCallback  onEliminar;
  final VoidCallback  onTotalChanged;

  const _FilaCard({
    super.key,
    required this.fila,
    required this.numero,
    required this.onEliminar,
    required this.onTotalChanged,
  });

  @override
  State<_FilaCard> createState() => _FilaCardState();
}

class _FilaCardState extends State<_FilaCard> {
  double _subtotal = 0;

  @override
  void initState() {
    super.initState();
    _subtotal = widget.fila.subtotal;
  }

  void _actualizarSubtotal() {
    final nuevo = widget.fila.subtotal;
    if (nuevo != _subtotal) {
      setState(() => _subtotal = nuevo);
      widget.onTotalChanged();
    }
  }

  void _actualizarVenta() => setState(() {});

  double? get _margen {
    final c = double.tryParse(widget.fila.costoCtrl.text) ?? 0;
    final v = double.tryParse(widget.fila.ventaCtrl.text) ?? 0;
    if (c <= 0 || v <= 0) return null;
    return ((v - c) / c) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final m = _margen;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fila 1: Nº + Nombre + Código + Categoría + Eliminar ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Número de ítem
              Container(
                width: 22, height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.outlineVariant,
                  shape: BoxShape.circle,
                ),
                child: Text('${widget.numero}',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.onSurface)),
              ),
              const SizedBox(width: 8),

              // Nombre
              Expanded(
                flex: 3,
                child: _CampoTexto(
                  ctrl:  widget.fila.nombreCtrl,
                  hint:  'Nombre del producto',
                  icon:  Icons.edit_rounded,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(width: 8),

              // Código / Barras
              SizedBox(
                width: 130,
                child: _CampoTexto(
                  ctrl:  widget.fila.codigoCtrl,
                  hint:  'Código / Barras',
                  icon:  Icons.qr_code_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),

              // Categoría (autocomplete)
              Expanded(
                flex: 2,
                child: _CategoriaField(
                  ctrl: widget.fila.categoriaCtrl,
                ),
              ),
              const SizedBox(width: 6),

              // Eliminar
              IconButton(
                onPressed: widget.onEliminar,
                icon: const Icon(Icons.close_rounded),
                iconSize:  16,
                color:     AppColors.onSurfaceVariant,
                tooltip:   'Quitar',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Fila 2: 4 columnas numéricas simétricas ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cantidad
              Expanded(
                child: _NumCol(
                  label:  'Cantidad',
                  ctrl:   widget.fila.cantCtrl,
                  onDone: _actualizarSubtotal,
                ),
              ),
              const SizedBox(width: 10),

              // P. Costo
              Expanded(
                child: _NumCol(
                  label:  'P. Costo',
                  ctrl:   widget.fila.costoCtrl,
                  onDone: _actualizarSubtotal,
                ),
              ),
              const SizedBox(width: 10),

              // P. Venta
              Expanded(
                child: _NumCol(
                  label:       'P. Venta',
                  ctrl:        widget.fila.ventaCtrl,
                  accent:      true,
                  showEmpty:   true,
                  onDone:      _actualizarVenta,
                  bottomWidget: _MargenChip(margen: m),
                ),
              ),
              const SizedBox(width: 10),

              // Subtotal
              Expanded(
                child: _SubtotalCol(subtotal: _subtotal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Columna numérica con label ────────────────────────────────
// Estructura uniforme: label / campo / bottomWidget (16px fijo)
// Esto garantiza que todas las columnas tienen la misma altura.

class _NumCol extends StatelessWidget {
  final String               label;
  final TextEditingController ctrl;
  final bool                  accent;
  final bool                  showEmpty;
  final VoidCallback          onDone;
  final Widget?               bottomWidget;

  const _NumCol({
    required this.label,
    required this.ctrl,
    this.accent      = false,
    this.showEmpty   = false,
    required this.onDone,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        _CampoNum(
          ctrl:      ctrl,
          accent:    accent,
          showEmpty: showEmpty,
          onDone:    onDone,
        ),
        const SizedBox(height: 4),
        // Espacio inferior fijo (16px) — compartido entre margen y vacío
        SizedBox(
          height: 16,
          child: bottomWidget ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Columna Subtotal (solo lectura) ───────────────────────────

class _SubtotalCol extends StatelessWidget {
  final double subtotal;
  const _SubtotalCol({required this.subtotal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Subtotal',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:        AppColors.surfaceContainerLowest,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            border:       Border.all(color: AppColors.outlineVariant),
          ),
          child: Text(
            '\$${ComprasTheme.fmt(subtotal)}',
            style: AppTextStyles.bodyMd.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface),
          ),
        ),
        const SizedBox(height: 4),
        const SizedBox(height: 16), // simetría con _NumCol
      ],
    );
  }
}

// ── Chip de margen ────────────────────────────────────────────

class _MargenChip extends StatelessWidget {
  final double? margen;
  const _MargenChip({required this.margen});

  Color _color(double m) {
    if (m < 0)  return AppColors.error;
    if (m < 10) return AppColors.error;
    if (m < 20) return AppColors.warning;
    return AppColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    if (margen == null) {
      return Center(
        child: Text('— %',
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.outlineVariant)),
      );
    }
    final m     = margen!;
    final color = _color(m);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          m >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          size: 11, color: color),
        const SizedBox(width: 2),
        Text(
          '${m >= 0 ? '+' : ''}${m.toStringAsFixed(1)}%',
          style: AppTextStyles.labelSm.copyWith(
              color: color, fontWeight: FontWeight.w700)),
        if (m < 0) ...[
          const SizedBox(width: 3),
          Text('bajo costo',
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.error)),
        ],
      ],
    );
  }
}

// ── Campo de texto libre ──────────────────────────────────────

class _CampoTexto extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final Color color;

  const _CampoTexto({
    required this.ctrl,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: AppTextStyles.bodyMd
          .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySm
            .copyWith(color: AppColors.outlineVariant),
        prefixIcon: Icon(icon, size: 13, color: color),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        filled:    true,
        fillColor: AppColors.surfaceContainerLowest,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide:
              BorderSide(color: AppColors.secondary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Campo categoría con autocomplete ─────────────────────────

class _CategoriaField extends StatefulWidget {
  final TextEditingController ctrl;
  const _CategoriaField({required this.ctrl});

  @override
  State<_CategoriaField> createState() => _CategoriaFieldState();
}

class _CategoriaFieldState extends State<_CategoriaField> {
  @override
  Widget build(BuildContext context) {
    final cats = context
        .read<ProveedoresProvider>()
        .categoriasSimple
        .map((c) => c['nombre'] as String)
        .toList();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.ctrl.text),
      optionsBuilder: (value) {
        if (value.text.isEmpty) return const [];
        final q = value.text.toLowerCase();
        return cats.where((c) => c.toLowerCase().contains(q));
      },
      onSelected: (v) => widget.ctrl.text = v,
      fieldViewBuilder: (ctx, fieldCtrl, focus, onSub) => TextField(
        controller: fieldCtrl,
        focusNode:  focus,
        onEditingComplete: onSub,
        onChanged: (v) => widget.ctrl.text = v,
        style: AppTextStyles.bodyMd
            .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Categoría',
          hintStyle: AppTextStyles.bodySm
              .copyWith(color: AppColors.outlineVariant),
          prefixIcon: const Icon(Icons.label_outline_rounded,
              size: 13, color: AppColors.outline),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          filled: true,
          fillColor: AppColors.surfaceContainerLowest,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: AppColors.outlineVariant),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: AppColors.outlineVariant),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: AppColors.secondary, width: 1.5),
          ),
        ),
      ),
      optionsViewBuilder: (ctx, onSel, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: opts.length,
              itemBuilder: (_, i) {
                final opt = opts.elementAt(i);
                return InkWell(
                  onTap: () => onSel(opt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Text(opt,
                        style: AppTextStyles.bodyMd.copyWith(fontSize: 12)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Campo numérico (FocusNode propio para no perder foco) ─────

class _CampoNum extends StatefulWidget {
  final TextEditingController ctrl;
  final bool accent;
  final bool showEmpty;
  final VoidCallback onDone;

  const _CampoNum({
    required this.ctrl,
    this.accent    = false,
    this.showEmpty = false,
    required this.onDone,
  });

  @override
  State<_CampoNum> createState() => _CampoNumState();
}

class _CampoNumState extends State<_CampoNum> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) widget.onDone();
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esVacio = widget.showEmpty &&
        (double.tryParse(widget.ctrl.text) ?? 0) == 0;

    final borderColor = esVacio
        ? AppColors.warning
        : widget.accent
            ? AppColors.secondary.withValues(alpha: 0.4)
            : AppColors.outlineVariant;

    return SizedBox(
      height: 36,
      child: TextField(
        controller: widget.ctrl,
        focusNode:  _focus,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMd.copyWith(
          fontSize: 13,
          color: widget.accent
              ? AppColors.secondary
              : AppColors.onSurface,
          fontWeight: FontWeight.w600,
        ),
        onSubmitted: (_) => widget.onDone(),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          filled: true,
          fillColor: esVacio
              ? AppColors.warningContainer
              : widget.accent
                  ? AppColors.mintLight
                  : AppColors.surfaceContainerLowest,
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide:
                BorderSide(color: AppColors.secondary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
