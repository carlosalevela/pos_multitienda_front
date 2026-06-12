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
  final _formKey            = GlobalKey<FormState>();
  final _nombreCtrl         = TextEditingController();
  final _codigoCtrl         = TextEditingController();
  final _descripcionCtrl    = TextEditingController();
  final _precioVentaCtrl    = TextEditingController();
  final _precioCompraCtrl   = TextEditingController();
  final _precioMayoreoCtrl  = TextEditingController();
  final _stockCtrl          = TextEditingController();
  final _minStockCtrl       = TextEditingController();
  final _catCtrl            = TextEditingController();

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.producto != null) {
      final p = widget.producto!;
      _nombreCtrl.text       = p.nombre;
      _codigoCtrl.text       = p.referencia;
      _descripcionCtrl.text  = p.descripcion;
      _precioVentaCtrl.text  = p.precio.toStringAsFixed(0);
      _precioCompraCtrl.text = p.precioCompra.toStringAsFixed(0);
      _precioMayoreoCtrl.text =
          p.precioMayoreo != null && p.precioMayoreo! > 0
              ? p.precioMayoreo!.toStringAsFixed(0)
              : '';
      _stockCtrl.text    = p.stockActual.toStringAsFixed(0);
      _minStockCtrl.text = p.stockMinimo.toStringAsFixed(0);
      _catCtrl.text      = p.categoria == 'Sin categoría' ? '' : p.categoria;
    }

    // Recalcular margen cuando cambian los precios
    _precioVentaCtrl.addListener(_recalcular);
    _precioCompraCtrl.addListener(_recalcular);
  }

  void _recalcular() => setState(() {});

  double get _costo => double.tryParse(_precioCompraCtrl.text) ?? 0;
  double get _venta => double.tryParse(_precioVentaCtrl.text) ?? 0;

  double get _margen {
    if (_costo <= 0 || _venta <= 0) return 0;
    return ((_venta - _costo) / _costo) * 100;
  }

  Color get _margenColor {
    if (_costo <= 0) return const Color(0xFF94A3B8);
    if (_margen < 0)  return const Color(0xFFEF4444);
    if (_margen < 10) return const Color(0xFFF59E0B);
    if (_margen < 20) return const Color(0xFFF97316);
    return const Color(0xFF10B981);
  }

  IconData get _margenIcon =>
      _margen >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded;

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
    _catCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.producto != null;

    return AlertDialog(
      shape:        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color:        Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(children: [
          Icon(esEdicion ? Icons.edit_rounded : Icons.add_rounded,
              color: Colors.white),
          const SizedBox(width: 10),
          Text(
            esEdicion ? 'Editar Producto' : 'Nuevo Producto',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ]),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Nombre
                _campo('Nombre del producto *', _nombreCtrl,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo requerido' : null),

                // Descripción
                _campo('Descripción', _descripcionCtrl),

                // Código de barras + Categoría
                Row(children: [
                  Expanded(child: _campo('Código de barras', _codigoCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _campo('Categoría', _catCtrl)),
                ]),

                // ── Sección Precios ──────────────────────────
                _seccionLabel('Precios', Icons.sell_rounded),
                const SizedBox(height: 10),

                // Precio compra + Precio venta
                Row(children: [
                  Expanded(
                    child: _campo('Precio costo', _precioCompraCtrl,
                        isNumber: true,
                        prefixText: '\$ '),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo('Precio venta *', _precioVentaCtrl,
                        isNumber: true,
                        prefixText: '\$ ',
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null),
                  ),
                ]),

                // Indicador de margen en tiempo real
                if (_costo > 0 && _venta > 0) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _margenColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _margenColor.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      Icon(_margenIcon, size: 15, color: _margenColor),
                      const SizedBox(width: 8),
                      Text(
                        'Margen: ${_margen.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _margenColor),
                      ),
                      if (_margen < 0) ...[
                        const SizedBox(width: 8),
                        Text('⚠️ Precio bajo el costo',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFFEF4444))),
                      ] else if (_margen < 10) ...[
                        const SizedBox(width: 8),
                        Text('Margen muy bajo',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFFF59E0B))),
                      ],
                    ]),
                  ),
                ],

                // Precio mayoreo (opcional)
                _campo(
                  'Precio mayoreo (opcional)',
                  _precioMayoreoCtrl,
                  isNumber: true,
                  prefixText: '\$ ',
                  helperText: 'Dejar vacío si no aplica mayoreo',
                ),

                // ── Sección Stock ────────────────────────────
                _seccionLabel('Stock', Icons.inventory_2_rounded),
                const SizedBox(height: 10),

                // Stock inicial + Stock mínimo
                Row(children: [
                  Expanded(
                    child: _campo('Stock inicial', _stockCtrl,
                        isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo('Stock mínimo', _minStockCtrl,
                        isNumber: true)),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: Text('Cancelar',
              style: GoogleFonts.poppins(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          icon: _guardando
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(
            esEdicion ? 'Actualizar' : 'Guardar',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          onPressed: _guardando ? null : _validarYGuardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(Constants.primaryColor),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // ── Etiqueta de sección ───────────────────────────
  Widget _seccionLabel(String texto, IconData icono) {
    return Row(children: [
      Icon(icono, size: 14, color: const Color(0xFF6366F1)),
      const SizedBox(width: 6),
      Text(texto,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6366F1),
              letterSpacing: 0.3)),
      const SizedBox(width: 8),
      Expanded(
        child: Divider(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
    ]);
  }

  // ── Campo reutilizable ────────────────────────────
  Widget _campo(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
    String? prefixText,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller:      ctrl,
        keyboardType:    isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: validator,
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          prefixText: prefixText,
          prefixStyle: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFF64748B)),
          helperText:  helperText,
          helperStyle: GoogleFonts.poppins(
              fontSize: 10.5, color: const Color(0xFF94A3B8)),
          filled:     true,
          fillColor:  Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(Constants.primaryColor), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(Constants.errorColor)),
          ),
        ),
      ),
    );
  }

  // ── Validar → advertir si precio < costo → guardar ──
  Future<void> _validarYGuardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Advertencia precio bajo costo
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
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          content: Text(
            'El precio de venta (\$${_venta.toStringAsFixed(0)}) es menor '
            'al costo (\$${_costo.toStringAsFixed(0)}). '
            '¿Deseas guardar de todas formas?',
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Revisar',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Guardar igual',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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

    final mayoreoVal = int.tryParse(_precioMayoreoCtrl.text);

    final data = <String, dynamic>{
      'nombre':          _nombreCtrl.text.trim(),
      'codigo_barras':   _codigoCtrl.text.trim(),
      'descripcion':     _descripcionCtrl.text.trim(),
      'precio_venta':    int.tryParse(_precioVentaCtrl.text) ?? 0,
      'precio_compra':   int.tryParse(_precioCompraCtrl.text) ?? 0,
      // solo envía precio_mayoreo si el usuario escribió algo
      if (mayoreoVal != null && mayoreoVal > 0)
        'precio_mayoreo': mayoreoVal,
      'unidad_medida':   'unidad',
      'aplica_impuesto': false,
      'tienda_id':       widget.tiendaId,
      if (widget.empresaId != null) 'empresa': widget.empresaId!,
      'stock_actual':    int.tryParse(_stockCtrl.text) ?? 0,
      'stock_minimo':    int.tryParse(_minStockCtrl.text) ?? 0,
    };

    if (_catCtrl.text.isNotEmpty) {
      data['categoria_nombre'] = _catCtrl.text.trim();
    }

    debugPrint('📦 empresaId del widget: ${widget.empresaId}');
    debugPrint('📦 data completo: $data');

    try {
      await widget.onGuardar(data);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
