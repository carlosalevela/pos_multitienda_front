import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/cliente.dart';
import '../../../providers/cliente_provider.dart';

class ClienteForm extends StatefulWidget {
  final Cliente?      cliente;
  final int?          tiendaId;
  final VoidCallback? onGuardado;

  const ClienteForm({
    super.key,
    this.cliente,
    this.tiendaId,
    this.onGuardado,
  });

  // ── Lanzador estático ──────────────────────────────────
  static Future<void> mostrar(
    BuildContext context, {
    Cliente?      cliente,
    int?          tiendaId,
    VoidCallback? onGuardado,
  }) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => ClienteForm(
        cliente:    cliente,
        tiendaId:   tiendaId,
        onGuardado: onGuardado,
      ),
    );
  }

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _formKey      = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _apellidoCtrl  = TextEditingController();
  final _cedulaCtrl    = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _direccionCtrl = TextEditingController();

  bool get _esEdicion => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final c = widget.cliente!;
      _nombreCtrl.text    = c.nombre;
      _apellidoCtrl.text  = c.apellido;
      _cedulaCtrl.text    = c.cedulaNit ?? '';
      _telefonoCtrl.text  = c.telefono;
      _emailCtrl.text     = c.email;
      _direccionCtrl.text = c.direccion;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  // ── Guardar ────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final prov = context.read<ClienteProvider>();
    final data = {
      'nombre':     _nombreCtrl.text.trim(),
      'apellido':   _apellidoCtrl.text.trim(),
      'cedula_nit': _cedulaCtrl.text.trim().isEmpty
          ? null
          : _cedulaCtrl.text.trim(),
      'telefono':   _telefonoCtrl.text.trim(),
      'email':      _emailCtrl.text.trim(),
      'direccion':  _direccionCtrl.text.trim(),
      if (widget.tiendaId != null) 'tienda': widget.tiendaId, // ✅
    };

    final ok = _esEdicion
        ? await prov.editarCliente(widget.cliente!.id, data)
        : await prov.crearCliente(data);

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      widget.onGuardado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion ? 'Cliente actualizado ✅' : 'Cliente creado ✅',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF437A22),
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prov.error ?? 'Error al guardar',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.red.shade600,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Campo de texto reutilizable ────────────────────────
  Widget _campo({
    required TextEditingController ctrl,
    required String                label,
    required IconData              icono,
    TextInputType                  tipo          = TextInputType.text,
    String? Function(String?)?     validator,
    bool                           obligatorio   = false,
    int                            maxLines      = 1,
    TextCapitalization             capitalizacion = TextCapitalization.words,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.poppins(
              fontSize:   12,
              fontWeight: FontWeight.w600,
              color:      const Color(0xFF7A7974),
            ),
            children: [
              if (obligatorio)
                const TextSpan(
                  text:  ' *',
                  style: TextStyle(color: Color(0xFFA12C7B)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:         ctrl,
          keyboardType:       tipo,
          maxLines:           maxLines,
          textCapitalization: capitalizacion,
          validator:          validator,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color:    const Color(0xFF28251D),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icono, size: 18,
                color: const Color(0xFF01696F)),
            hintText:  'Ingresa $label',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color:    const Color(0xFFBAB9B4),
            ),
            filled:    true,
            fillColor: const Color(0xFFF9F8F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: Color(0xFFD4D1CA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: Color(0xFFD4D1CA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(
                  color: Color(0xFF01696F), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide(
                  color: Colors.red.shade400, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide(
                  color: Colors.red.shade400, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize:       MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Handle ───────────────────────────────────
              Center(
                child: Container(
                  width:  40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color:        Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Título ───────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        const Color(0xFF01696F).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Color(0xFF01696F), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  _esEdicion ? 'Editar cliente' : 'Nuevo cliente',
                  style: GoogleFonts.poppins(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      const Color(0xFF28251D),
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Nombre + Apellido ────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campo(
                      ctrl:        _nombreCtrl,
                      label:       'Nombre',
                      icono:       Icons.person_outline_rounded,
                      obligatorio: true,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requerido'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo(
                      ctrl:  _apellidoCtrl,
                      label: 'Apellido',
                      icono: Icons.person_outline_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Cédula / NIT ─────────────────────────────
              _campo(
                ctrl:           _cedulaCtrl,
                label:          'Cédula / NIT',
                icono:          Icons.badge_outlined,
                tipo:           TextInputType.number,
                capitalizacion: TextCapitalization.none,
              ),

              const SizedBox(height: 16),

              // ── Teléfono + Email ─────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campo(
                      ctrl:           _telefonoCtrl,
                      label:          'Teléfono',
                      icono:          Icons.phone_outlined,
                      tipo:           TextInputType.phone,
                      capitalizacion: TextCapitalization.none,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo(
                      ctrl:           _emailCtrl,
                      label:          'Email',
                      icono:          Icons.email_outlined,
                      tipo:           TextInputType.emailAddress,
                      capitalizacion: TextCapitalization.none,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final valid = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
                        return valid.hasMatch(v.trim())
                            ? null
                            : 'Email inválido';
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Dirección ────────────────────────────────
              _campo(
                ctrl:     _direccionCtrl,
                label:    'Dirección',
                icono:    Icons.location_on_outlined,
                maxLines: 2,
              ),

              const SizedBox(height: 28),

              // ── Botón guardar ────────────────────────────
              Selector<ClienteProvider, bool>(
                selector: (_, p) => p.guardando,
                builder: (_, guardando, __) => SizedBox(
                  width:  double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:        const Color(0xFF01696F),
                      foregroundColor:        Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: guardando
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              color:       Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _esEdicion ? 'Guardar cambios' : 'Crear cliente',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize:   15,
                            ),
                          ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}