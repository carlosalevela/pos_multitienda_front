// lib/screens/inventario/widgets/producto_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../models/producto.dart';

class ProductoFormDialog extends StatefulWidget {
  final Producto?                                    producto;
  final Future<void> Function(Map<String, dynamic>) onGuardar;
  final int                                          tiendaId;
  final int?                                         empresaId;

  const ProductoFormDialog({
    super.key,
    this.producto,
    required this.onGuardar,
    required this.tiendaId,
    this.empresaId,
  });

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  final _formKey           = GlobalKey<FormState>();
  final _nombreCtrl        = TextEditingController();
  final _codigoCtrl        = TextEditingController();
  final _descripcionCtrl   = TextEditingController();
  final _precioVentaCtrl   = TextEditingController();
  final _precioCompraCtrl  = TextEditingController();
  final _precioMayoreoCtrl    = TextEditingController();
  final _stockCtrl            = TextEditingController();
  final _minStockCtrl      = TextEditingController();
  final _maxStockCtrl      = TextEditingController();
  final _catCtrl           = TextEditingController();

  bool _guardando = false;

  // ── Design tokens ──────────────────────────────────────
  static const _text    = Color(0xFF191C1E);
  static const _muted   = Color(0xFF45464D);
  static const _muted2  = Color(0xFF76777D);
  static const _border  = Color(0xFFD4D6DD);
  static const _surfLow = Color(0xFFF7F9FB);
  static const _green   = Color(0xFF006C49);
  static const _danger  = Color(0xFFBA1A1A);
  static const _warning = Color(0xFFF59E0B);

  TextStyle _t({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize:      size,
        fontWeight:    weight,
        color:         color ?? _text,
        letterSpacing: letterSpacing,
      );

  // ══════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    if (widget.producto != null) {
      final p = widget.producto!;
      _nombreCtrl.text        = p.nombre;
      _codigoCtrl.text        = p.referencia;
      _descripcionCtrl.text   = p.descripcion;
      _precioVentaCtrl.text   = p.precio.toStringAsFixed(0);
      _precioCompraCtrl.text  = p.precioCompra.toStringAsFixed(0);
      _precioMayoreoCtrl.text = p.precioMayoreo != null && p.precioMayoreo! > 0
          ? p.precioMayoreo!.toStringAsFixed(0)
          : '';
      _stockCtrl.text    = p.stockActual.toStringAsFixed(0);
      _minStockCtrl.text = p.stockMinimo.toStringAsFixed(0);
      _maxStockCtrl.text = p.stockMaximo > 0
          ? p.stockMaximo.toStringAsFixed(0)
          : '';
      _catCtrl.text = p.categoria == 'Sin categoría' ? '' : p.categoria;
    }
    _precioVentaCtrl.addListener(_recalcular);
    _precioCompraCtrl.addListener(_recalcular);
  }

  void _recalcular() => setState(() {});

  double get _costo => double.tryParse(_precioCompraCtrl.text) ?? 0;
  double get _venta => double.tryParse(_precioVentaCtrl.text)  ?? 0;

  double get _margen {
    if (_costo <= 0 || _venta <= 0) return 0;
    return ((_venta - _costo) / _costo) * 100;
  }

  Color get _margenColor {
    if (_costo <= 0)   return _muted2;
    if (_margen < 0)   return _danger;
    if (_margen < 10)  return _warning;
    return _green;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioVentaCtrl.dispose();
    _precioCompraCtrl.dispose();
    _precioMayoreoCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _maxStockCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.producto != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(esEdicion),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildLeftColumn()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildRightColumn()),
                    ],
                  ),
                ),
              ),
              _buildFooter(esEdicion),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════
  Widget _buildHeader(bool esEdicion) => Container(
    padding: const EdgeInsets.fromLTRB(28, 22, 20, 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          esEdicion ? Icons.edit_rounded : Icons.add_rounded,
          color: Colors.white, size: 18,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            esEdicion ? 'Editar Producto' : 'Nuevo Producto',
            style: _t(size: 18, weight: FontWeight.w700),
          ),
          Text(
            esEdicion
                ? 'Modifica los datos del producto'
                : 'Completa la información del nuevo producto',
            style: _t(size: 12, color: _muted),
          ),
        ]),
      ),
      InkWell(
        onTap: _guardando ? null : () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close_rounded, size: 18, color: _muted),
        ),
      ),
    ]),
  );

  // ══════════════════════════════════════════════════════
  // LEFT COLUMN — Info del producto
  // ══════════════════════════════════════════════════════
  Widget _buildLeftColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _campo(
        label:     'NOMBRE DEL PRODUCTO',
        ctrl:      _nombreCtrl,
        hint:      'Ej. Zenith Wireless Headset',
        validator: (v) => v == null || v.trim().isEmpty ? 'Campo requerido' : null,
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: _campo(
            label: 'SKU / BARCODE',
            ctrl:  _codigoCtrl,
            hint:  'ZWH-99201',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _campo(
            label: 'CATEGORÍA',
            ctrl:  _catCtrl,
            hint:  'Ej. Electrónica',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _campo(
        label:    'DESCRIPCIÓN',
        ctrl:     _descripcionCtrl,
        hint:     'Detalles del producto…',
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      _imagenPlaceholder(),
      const SizedBox(height: 24),
    ],
  );

  Widget _imagenPlaceholder() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('IMAGEN DEL PRODUCTO',
          style: _t(size: 11, weight: FontWeight.w600,
              color: _muted, letterSpacing: 0.6)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: _surfLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _border, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.cloud_upload_outlined,
                  size: 20, color: _muted2),
            ),
            const SizedBox(height: 8),
            Text('Click para subir o arrastra una imagen',
                style: _t(size: 12, color: _muted)),
          ],
        ),
      ),
    ],
  );

  // ══════════════════════════════════════════════════════
  // RIGHT COLUMN — Precios + Inventario
  // ══════════════════════════════════════════════════════
  Widget _buildRightColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _seccionLabel('PRECIOS'),
      const SizedBox(height: 12),
      _campo(
        label:      'Precio de Costo',
        ctrl:       _precioCompraCtrl,
        hint:       '0',
        prefixText: '${Constants.moneda} ',
        isNumber:   true,
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: _campo(
            label:      'Precio de Venta',
            ctrl:       _precioVentaCtrl,
            hint:       '0',
            prefixText: '${Constants.moneda} ',
            isNumber:   true,
            validator:  (v) =>
                v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _campo(
            label:      'Precio Mayorista',
            ctrl:       _precioMayoreoCtrl,
            hint:       '0',
            prefixText: '${Constants.moneda} ',
            isNumber:   true,
          ),
        ),
      ]),

      // Indicador de margen en tiempo real
      if (_costo > 0 && _venta > 0) ...[
        const SizedBox(height: 4),
        _margenBadge(),
        const SizedBox(height: 12),
      ] else
        const SizedBox(height: 16),

      _seccionLabel('INVENTARIO'),
      const SizedBox(height: 12),
      _campo(
        label:   'Stock Inicial',
        ctrl:    _stockCtrl,
        hint:    '0',
        isNumber: true,
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: _campo(
            label:    'Stock Mínimo',
            ctrl:     _minStockCtrl,
            hint:     '0',
            isNumber: true,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _campo(
            label:    'Stock Máximo',
            ctrl:     _maxStockCtrl,
            hint:     '0',
            isNumber: true,
          ),
        ),
      ]),
      const SizedBox(height: 24),
    ],
  );

  Widget _margenBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _margenColor.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _margenColor.withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Icon(
        _margen >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        size: 14, color: _margenColor,
      ),
      const SizedBox(width: 8),
      Text(
        'Margen: ${_margen.toStringAsFixed(1)}%',
        style: _t(size: 12, weight: FontWeight.w600, color: _margenColor),
      ),
      if (_margen < 0) ...[
        const SizedBox(width: 8),
        Text('· Precio bajo el costo',
            style: _t(size: 11, color: _danger)),
      ] else if (_margen < 10) ...[
        const SizedBox(width: 8),
        Text('· Margen muy bajo',
            style: _t(size: 11, color: _warning)),
      ],
    ]),
  );

  // ══════════════════════════════════════════════════════
  // FOOTER
  // ══════════════════════════════════════════════════════
  Widget _buildFooter(bool esEdicion) => Container(
    padding: const EdgeInsets.fromLTRB(28, 16, 28, 22),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE8EAED))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: _muted,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Cancelar',
              style: _t(size: 13, weight: FontWeight.w600, color: _muted)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _guardando ? null : _validarYGuardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _guardando
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.save_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    esEdicion ? 'Actualizar Producto' : 'Guardar Producto',
                    style: _t(size: 13, weight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ]),
        ),
      ],
    ),
  );

  // ══════════════════════════════════════════════════════
  // WIDGETS REUTILIZABLES
  // ══════════════════════════════════════════════════════
  Widget _seccionLabel(String texto) => Row(children: [
    Text(texto,
        style: _t(size: 11, weight: FontWeight.w700,
            color: _green, letterSpacing: 0.6)),
    const SizedBox(width: 10),
    Expanded(child: Divider(color: _green.withValues(alpha: 0.15), thickness: 1)),
  ]);

  Widget _campo({
    required String                  label,
    required TextEditingController   ctrl,
    String?                          hint,
    String?                          prefixText,
    bool                             isNumber  = false,
    int                              maxLines  = 1,
    String? Function(String?)?       validator,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: _t(size: 11, weight: FontWeight.w600,
                  color: _muted, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextFormField(
            controller:      ctrl,
            keyboardType:    isNumber
                ? TextInputType.number
                : TextInputType.text,
            inputFormatters: isNumber
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            maxLines:        maxLines,
            validator:       validator,
            style:           _t(size: 14),
            decoration: InputDecoration(
              hintText:    hint,
              hintStyle:   _t(size: 14, color: const Color(0xFFAAAAAA)),
              prefixText:  prefixText,
              prefixStyle: _t(size: 14, color: _muted),
              filled:      true,
              fillColor:   _surfLow,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF131B2E), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: _danger, width: 1.5),
              ),
              errorStyle: _t(size: 11, color: _danger),
            ),
          ),
        ],
      );

  // ══════════════════════════════════════════════════════
  // LÓGICA
  // ══════════════════════════════════════════════════════
  Future<void> _validarYGuardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_costo > 0 && _venta > 0 && _venta < _costo) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade600, size: 22),
            const SizedBox(width: 10),
            Text('Precio bajo el costo',
                style: _t(size: 15, weight: FontWeight.w700)),
          ]),
          content: Text(
            'El precio de venta (\$${_venta.toStringAsFixed(0)}) es menor '
            'al costo (\$${_costo.toStringAsFixed(0)}). '
            '¿Deseas guardar de todas formas?',
            style: _t(size: 13, color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Revisar',
                  style: _t(size: 13, color: _muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                elevation:       0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Guardar igual',
                  style: _t(size: 13, weight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ],
        ),
      );
      if (continuar != true) return;
    }

    await _guardar();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);

    final mayoreoVal   = double.tryParse(_precioMayoreoCtrl.text);
    final categoria    = _catCtrl.text.trim();

    final data = <String, dynamic>{
      'nombre':          _nombreCtrl.text.trim(),
      'codigo_barras':   _codigoCtrl.text.trim(),
      'descripcion':     _descripcionCtrl.text.trim(),
      'precio_venta':    double.tryParse(_precioVentaCtrl.text)  ?? 0,
      'precio_compra':   double.tryParse(_precioCompraCtrl.text) ?? 0,
      if (mayoreoVal != null && mayoreoVal > 0) 'precio_mayoreo': mayoreoVal,
      if (categoria.isNotEmpty) 'categoria_nombre': categoria,
      'unidad_medida':   'unidad',
      'aplica_impuesto': false,
      'tienda_id':       widget.tiendaId,
      if (widget.empresaId != null) 'empresa': widget.empresaId!,
      'stock_actual':    int.tryParse(_stockCtrl.text)    ?? 0,
      'stock_minimo':    int.tryParse(_minStockCtrl.text) ?? 0,
      'stock_maximo':    int.tryParse(_maxStockCtrl.text) ?? 0,
    };

    try {
      await widget.onGuardar(data);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
