// lib/screens/compras/widgets/nueva_orden_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../providers/auth_provider.dart';
import '../compras_theme.dart';
import 'fila_producto_widget.dart';

class NuevaOrdenDialog extends StatefulWidget {
  const NuevaOrdenDialog({super.key});

  @override
  State<NuevaOrdenDialog> createState() => _NuevaOrdenDialogState();
}

class _NuevaOrdenDialogState extends State<NuevaOrdenDialog> {
  final _formKey = GlobalKey<FormState>();
  final _obsCtrl = TextEditingController();

  int?                             _proveedorId;
  int?                             _tiendaId;
  final List<Map<String, dynamic>> _detalles = [];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (!ComprasTheme.esAdmin(auth.rol)) {
      _tiendaId = auth.tiendaId == 0 ? null : auth.tiendaId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDatos());
  }

  Future<void> _cargarDatos() async {
    final prov = context.read<ProveedoresProvider>();
    await Future.wait([
      prov.cargarProveedoresSimple(),
      prov.cargarTiendasSimple(),
      prov.cargarCategoriasSimple(),
    ]);
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  double get _total => _detalles.fold(0, (s, d) {
    final cant = double.tryParse(d['cantidad'].toString()) ?? 0;
    final prec = double.tryParse(d['precio_unitario'].toString()) ?? 0;
    return s + cant * prec;
  });

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<ProveedoresProvider>();
    final auth    = context.watch<AuthProvider>();
    final esAdmin = ComprasTheme.esAdmin(auth.rol);

    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(children: [
        const Icon(Icons.shopping_cart_rounded,
            color: ComprasTheme.accent),
        const SizedBox(width: 10),
        Text('Nueva orden de compra',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                // ── Tienda (solo admin/superadmin) ──────
                if (esAdmin) ...[
                  _label('Tienda *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value:      _tiendaId,
                    decoration: _dropdownDeco(Icons.store_rounded),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: ComprasTheme.dark),
                    hint: Text('Seleccionar tienda',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade400)),
                    validator: (v) =>
                        v == null ? 'Selecciona una tienda' : null,
                    items: prov.tiendasSimple.map((t) =>
                      DropdownMenuItem<int>(
                        value: t['id'] as int,
                        child: Text(t['nombre'],
                            style: GoogleFonts.poppins(
                                fontSize: 13)),
                      ),
                    ).toList(),
                    onChanged: (v) =>
                        setState(() => _tiendaId = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Proveedor ───────────────────────────
                _label('Proveedor *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value:      _proveedorId,
                  decoration: _dropdownDeco(
                      Icons.local_shipping_rounded),
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ComprasTheme.dark),
                  hint: Text('Seleccionar proveedor',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade400)),
                  validator: (v) =>
                      v == null ? 'Selecciona un proveedor' : null,
                  items: prov.proveedoresSimple.map((p) =>
                    DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Text(
                        '${p['nombre']}${p['nit'] != null ? ' — ${p['nit']}' : ''}',
                        style: GoogleFonts.poppins(
                            fontSize: 13)),
                    ),
                  ).toList(),
                  onChanged: (v) =>
                      setState(() => _proveedorId = v),
                ),
                const SizedBox(height: 14),

                // ── Observaciones ───────────────────────
                _label('Observaciones'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _obsCtrl,
                  maxLines:   2,
                  style:      GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Notas adicionales (opcional)',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade400),
                    filled:    true,
                    fillColor: const Color(0xFFF4F6FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: ComprasTheme.accent,
                            width: 1.5)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Productos ───────────────────────────
                Row(children: [
                  Text('Productos',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize:   14,
                        color:      ComprasTheme.dark)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() =>
                      _detalles.add({
                        'producto':         null,
                        'nombre':           '',
                        'cantidad':         '1',
                        'precio_unitario':  '',
                        'categoria_nombre': '',
                      }),
                    ),
                    icon:  const Icon(Icons.add_rounded, size: 16),
                    label: Text('Agregar producto',
                        style: GoogleFonts.poppins(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: ComprasTheme.accent),
                  ),
                ]),
                const SizedBox(height: 8),

                if (_detalles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.grey.shade200),
                    ),
                    child: Center(child: Text(
                      'Agrega al menos un producto',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade400))),
                  )
                else
                  ..._detalles.asMap().entries.map((e) =>
                    FilaProductoWidget(
                      key:       ValueKey(e.key),
                      index:     e.key,
                      fila:      e.value,
                      tiendaId:  _tiendaId,
                      onEliminar: () => setState(() =>
                          _detalles.removeAt(e.key)),
                      onCambio: (fila) => setState(() =>
                          _detalles[e.key] = fila),
                    ),
                  ),

                // ── Total ───────────────────────────────
                if (_detalles.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Total estimado: ',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade600)),
                      Text('\$${ComprasTheme.fmt(_total)}',
                        style: GoogleFonts.poppins(
                            fontSize:   18,
                            fontWeight: FontWeight.bold,
                            color:      ComprasTheme.accent)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade600))),
        ElevatedButton.icon(
          onPressed: prov.guardando ||
                  _detalles.isEmpty ||
                  _tiendaId == null
              ? null
              : _crear,
          icon: prov.guardando
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
              : const Icon(Icons.send_rounded, size: 16),
          label: Text('Crear orden',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ComprasTheme.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proveedorId == null) return;

    final ok = await context
        .read<ProveedoresProvider>()
        .crearCompra({
      'tienda':        _tiendaId,
      'proveedor':     _proveedorId,
      'observaciones': _obsCtrl.text.trim(),
      'detalles': _detalles.map((d) => {
        'producto':               d['producto'],
        'nombre_libre':           d['nombre'] ?? '',
        'categoria_nombre_input': d['categoria_nombre'] ?? '',
        'cantidad':        double.tryParse(
            d['cantidad'].toString()) ?? 0,
        'precio_unitario': double.tryParse(
            d['precio_unitario'].toString()) ?? 0,
      }).toList(),
    });

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        ok
            ? 'Orden creada correctamente'
            : 'Error al crear la orden',
        style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: ok
          ? Colors.green.shade600
          : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _label(String texto) => Text(texto,
    style: GoogleFonts.poppins(
        fontSize: 12, color: Colors.grey.shade600));

  InputDecoration _dropdownDeco(IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, size: 18,
        color: Colors.grey.shade400),
    filled:    true,
    fillColor: const Color(0xFFF4F6FA),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: Color(0xFFE0E0E0))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: Color(0xFFE0E0E0))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: ComprasTheme.accent, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 4, vertical: 12),
  );
}