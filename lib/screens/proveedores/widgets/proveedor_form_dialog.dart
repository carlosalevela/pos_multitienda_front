// lib/screens/proveedores/widgets/proveedor_form_dialog.dart
//
// Comportamiento por rol:
//   admin      → empresaIdFija y tiendaIdFijo vienen del AuthProvider.
//                NO se muestran dropdowns de empresa/tienda.
//   superadmin → esSuperadmin = true, ambos son null.
//                Se muestran dropdowns Empresa → Tienda en cascada.
//                Guardar bloqueado hasta seleccionar ambos.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../core/constants.dart';

class ProveedorFormDialog extends StatefulWidget {
  final Map<String, dynamic>?              proveedor;
  final bool                               esSuperadmin;
  final String?                            empresaIdFija;
  final int?                               tiendaIdFijo;
  final void Function(bool ok, bool esEdicion) onGuardado;

  const ProveedorFormDialog({
    super.key,
    this.proveedor,
    required this.esSuperadmin,
    this.empresaIdFija,
    this.tiendaIdFijo,
    required this.onGuardado,
  });

  @override
  State<ProveedorFormDialog> createState() => _ProveedorFormDialogState();
}

class _ProveedorFormDialogState extends State<ProveedorFormDialog> {
  static const _accent = Color(Constants.primaryColor);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _cNombre;
  late final TextEditingController _cNit;
  late final TextEditingController _cTelefono;
  late final TextEditingController _cEmail;
  late final TextEditingController _cDireccion;
  late final TextEditingController _cCiudad;

  // Solo para superadmin
  String? _empresaSelId;
  int?    _tiendaSelId;

  bool get _esEdicion => widget.proveedor != null;

  @override
  void initState() {
    super.initState();
    final p     = widget.proveedor;
    _cNombre    = TextEditingController(text: p?['nombre']    ?? '');
    _cNit       = TextEditingController(text: p?['nit']       ?? '');
    _cTelefono  = TextEditingController(text: p?['telefono']  ?? '');
    _cEmail     = TextEditingController(text: p?['email']     ?? '');
    _cDireccion = TextEditingController(text: p?['direccion'] ?? '');
    _cCiudad    = TextEditingController(text: p?['ciudad']    ?? '');

    if (widget.esSuperadmin) {
      // En edición pre-poblar empresa/tienda existentes
      if (_esEdicion) {
        _empresaSelId = p?['empresa_id']?.toString();
        _tiendaSelId  = p?['tienda_id'] != null
            ? int.tryParse(p!['tienda_id'].toString())
            : null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final prov = context.read<ProveedoresProvider>();
        await prov.cargarEmpresasSimple();
        // Si hay empresa pre-seleccionada (edición), cargar sus tiendas
        if (_empresaSelId != null) {
          await prov.cargarTiendasSimple(
              empresaId: int.tryParse(_empresaSelId!));
        }
      });
    }
  }

  @override
  void dispose() {
    _cNombre.dispose();
    _cNit.dispose();
    _cTelefono.dispose();
    _cEmail.dispose();
    _cDireccion.dispose();
    _cCiudad.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.esSuperadmin) {
      if (_empresaSelId == null) {
        _snackError('Debes seleccionar una empresa');
        return;
      }
      if (_tiendaSelId == null) {
        _snackError('Debes seleccionar una tienda');
        return;
      }
    }

    final data = <String, dynamic>{
      'nombre':     _cNombre.text.trim(),
      'nit':        _cNit.text.trim(),
      'telefono':   _cTelefono.text.trim(),
      'email':      _cEmail.text.trim(),
      'direccion':  _cDireccion.text.trim(),
      'ciudad':     _cCiudad.text.trim(),
      'empresa_id': widget.esSuperadmin
          ? _empresaSelId
          : widget.empresaIdFija,
      'tienda_id':  widget.esSuperadmin
          ? _tiendaSelId
          : widget.tiendaIdFijo,
    };

    debugPrint('📦 payload proveedor: $data');

    final prov = context.read<ProveedoresProvider>();
    final ok   = _esEdicion
        ? await prov.editarProveedor(widget.proveedor!['id'], data)
        : await prov.crearProveedor(data);

    if (!mounted) return;
    Navigator.pop(context);
    widget.onGuardado(ok, _esEdicion);
  }

  void _snackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.orange.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(
          _esEdicion ? Icons.edit_rounded : Icons.add_business_rounded,
          color: _accent, size: 22),
        const SizedBox(width: 10),
        Text(
          _esEdicion ? 'Editar proveedor' : 'Nuevo proveedor',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── Selector empresa/tienda (solo superadmin) ──
                if (widget.esSuperadmin) ...[
                  _EmpresaTiendaSelector(
                    empresaSelId: _empresaSelId,
                    tiendaSelId:  _tiendaSelId,
                    onEmpresaChanged: (id) {
                      setState(() {
                        _empresaSelId = id;
                        _tiendaSelId  = null;
                      });
                      context.read<ProveedoresProvider>()
                          .cargarTiendasSimple(
                              empresaId: int.tryParse(id ?? ''));
                    },
                    onTiendaChanged: (id) =>
                        setState(() => _tiendaSelId = id),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                ],

                // ── Campos del proveedor ───────────────────────
                Row(children: [
                  Expanded(child: _campo(
                    ctrl:  _cNombre,
                    label: 'Nombre *',
                    icon:  Icons.business_rounded,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requerido' : null,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(
                    ctrl:  _cNit,
                    label: 'NIT',
                    icon:  Icons.badge_rounded,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _campo(
                    ctrl:      _cTelefono,
                    label:     'Teléfono',
                    icon:      Icons.phone_rounded,
                    inputType: TextInputType.phone,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(
                    ctrl:  _cCiudad,
                    label: 'Ciudad',
                    icon:  Icons.location_city_rounded,
                  )),
                ]),
                const SizedBox(height: 12),
                _campo(
                  ctrl:      _cEmail,
                  label:     'Email',
                  icon:      Icons.email_rounded,
                  inputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _campo(
                  ctrl:  _cDireccion,
                  label: 'Dirección',
                  icon:  Icons.map_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: GoogleFonts.poppins(color: Colors.grey.shade600))),
        Consumer<ProveedoresProvider>(
          builder: (_, p, __) => ElevatedButton.icon(
            onPressed: p.guardando ? null : _guardar,
            icon: p.guardando
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(
                    _esEdicion ? Icons.save_rounded : Icons.add_rounded,
                    size: 16),
            label: Text(
              _esEdicion ? 'Guardar cambios' : 'Crear proveedor',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campo({
    required TextEditingController ctrl,
    required String                label,
    required IconData              icon,
    TextInputType?                 inputType,
    String? Function(String?)?     validator,
  }) =>
    TextFormField(
      controller:   ctrl,
      keyboardType: inputType,
      validator:    validator,
      style:        GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: GoogleFonts.poppins(fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled:     true,
        fillColor:  const Color(0xFFF4F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
}

// ── Selector Empresa → Tienda ─────────────────────────────────────────────

class _EmpresaTiendaSelector extends StatelessWidget {
  final String?               empresaSelId;
  final int?                  tiendaSelId;
  final ValueChanged<String?> onEmpresaChanged;
  final ValueChanged<int?>    onTiendaChanged;

  const _EmpresaTiendaSelector({
    required this.empresaSelId,
    required this.tiendaSelId,
    required this.onEmpresaChanged,
    required this.onTiendaChanged,
  });

  static const _accent = Color(Constants.primaryColor);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProveedoresProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.business_center_rounded,
              size: 15, color: _accent),
          const SizedBox(width: 6),
          Text('Asignación',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          // Dropdown empresa
          Expanded(child: _dropdown<String>(
            label:     'Empresa *',
            icon:      Icons.domain_rounded,
            value:     empresaSelId,
            loading:   prov.cargandoEmpresas,
            items:     prov.empresasSimple,
            toValue:   (e) => e['id'].toString(),
            toLabel:   (e) => e['nombre']?.toString() ?? '',
            onChanged: onEmpresaChanged,
            hint:      'Seleccionar empresa',
          )),
          const SizedBox(width: 12),
          // Dropdown tienda — se habilita al elegir empresa
          Expanded(child: _dropdown<int>(
            label:     'Tienda *',
            icon:      Icons.store_rounded,
            value:     tiendaSelId,
            loading:   prov.cargandoTiendas,
            items:     prov.tiendasSimple,
            toValue:   (e) => int.tryParse(e['id'].toString()) ?? 0,
            toLabel:   (e) => e['nombre']?.toString() ?? '',
            onChanged: empresaSelId != null ? onTiendaChanged : null,
            hint:      empresaSelId == null
                ? 'Primero elige empresa'
                : prov.tiendasSimple.isEmpty && !prov.cargandoTiendas
                    ? 'Sin tiendas disponibles'
                    : 'Seleccionar tienda',
            disabled:  empresaSelId == null,
          )),
        ]),
      ],
    );
  }

  Widget _dropdown<T>({
    required String                     label,
    required IconData                   icon,
    required T?                         value,
    required bool                       loading,
    required List<Map<String, dynamic>> items,
    required T Function(Map<String, dynamic>)      toValue,
    required String Function(Map<String, dynamic>) toLabel,
    required ValueChanged<T?>?          onChanged,
    required String                     hint,
    bool                                disabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: disabled
                ? const Color(0xFFF0F0F0)
                : const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: loading
              ? const Center(child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)))
              : DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value:      value,
                    isExpanded: true,
                    hint: Row(children: [
                      Icon(icon, size: 16,
                          color: disabled
                              ? Colors.grey.shade300
                              : Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Flexible(child: Text(hint,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: disabled
                                ? Colors.grey.shade400
                                : Colors.grey.shade500))),
                    ]),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF1A1A2E)),
                    onChanged: disabled ? null : onChanged,
                    items: items.map((e) => DropdownMenuItem<T>(
                      value: toValue(e),
                      child: Text(toLabel(e),
                          style: GoogleFonts.poppins(fontSize: 13)),
                    )).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}