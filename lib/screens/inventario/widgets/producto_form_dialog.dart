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

  const ProductoFormDialog({
    super.key,
    this.producto,
    required this.onGuardar,
    required this.tiendaId,
    // ✅ FIX: guardando eliminado — se maneja localmente
  });

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  final _formKey          = GlobalKey<FormState>();
  final _nombreCtrl       = TextEditingController();
  final _codigoCtrl       = TextEditingController();
  final _descripcionCtrl  = TextEditingController();
  final _precioVentaCtrl  = TextEditingController();
  final _precioCompraCtrl = TextEditingController();
  final _stockCtrl        = TextEditingController();
  final _minStockCtrl     = TextEditingController();
  final _catCtrl          = TextEditingController();

  // ✅ FIX: estado local — funciona correctamente dentro de showDialog
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
      _stockCtrl.text        = p.stockActual.toStringAsFixed(0);
      _minStockCtrl.text     = p.stockMinimo.toStringAsFixed(0);
      _catCtrl.text          = p.categoria == 'Sin categoría' ? '' : p.categoria;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioVentaCtrl.dispose();
    _precioCompraCtrl.dispose();
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

                // Precio venta + Precio compra
                Row(children: [
                  Expanded(
                    child: _campo('Precio venta *', _precioVentaCtrl,
                      isNumber: true,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requerido' : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo('Precio compra', _precioCompraCtrl,
                        isNumber: true),
                  ),
                ]),

                // Stock inicial + Stock mínimo
                Row(children: [
                  Expanded(
                    child: _campo('Stock inicial', _stockCtrl, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo('Stock mínimo', _minStockCtrl, isNumber: true)),
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
          onPressed: _guardando ? null : _guardar,
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

  Widget _campo(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
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
            borderSide:   const BorderSide(
                color: Color(Constants.primaryColor), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   const BorderSide(color: Color(Constants.errorColor)),
          ),
        ),
      ),
    );
  }

  // ✅ FIX: async + try/catch + Navigator.pop al éxito
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final data = <String, dynamic>{
      'nombre':          _nombreCtrl.text.trim(),
      'codigo_barras':   _codigoCtrl.text.trim(),
      'descripcion':     _descripcionCtrl.text.trim(),
      // ✅ FIX: precios como int, no como String
      'precio_venta':    int.tryParse(_precioVentaCtrl.text) ?? 0,
      'precio_compra':   int.tryParse(_precioCompraCtrl.text) ?? 0,
      'unidad_medida':   'unidad',
      'aplica_impuesto': false,
      'tienda_id':       widget.tiendaId,
      'stock_actual':    int.tryParse(_stockCtrl.text) ?? 0,
      'stock_minimo':    int.tryParse(_minStockCtrl.text) ?? 0,
    };

    if (_catCtrl.text.isNotEmpty) {
      data['categoria_nombre'] = _catCtrl.text.trim();
    }

    try {
      await widget.onGuardar(data);
      if (mounted) Navigator.pop(context);    // ← cierra al éxito
    } catch (_) {
      if (mounted) setState(() => _guardando = false);  // ← desbloquea botón
    }
  }
}