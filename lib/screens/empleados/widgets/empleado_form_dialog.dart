// lib/screens/empleados/tabs/empleado_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../services/empleado_service.dart';

class EmpleadoFormDialog extends StatefulWidget {
  final Map<String, dynamic>?                        empleado;
  final Future<void> Function(Map<String, dynamic>)  onGuardar;

  const EmpleadoFormDialog({
    super.key,
    this.empleado,
    required this.onGuardar,
  });

  @override
  State<EmpleadoFormDialog> createState() => _EmpleadoFormDialogState();
}

class _EmpleadoFormDialogState extends State<EmpleadoFormDialog> {
  final _formKey      = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _cedulaCtrl   = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();

  // ✅ Service como campo — no instanciar en cada llamada
  final _empleadoService = EmpleadoService();

  bool   _obscurePass = true;
  bool   _guardando   = false;
  String _rolSelected = 'cajero';
  int?   _tiendaSelected;
  List<Map<String, dynamic>> _tiendas = [];

  @override
  void initState() {
    super.initState();
    _cargarTiendas();
    if (widget.empleado != null) {
      final e = widget.empleado!;
      _nombreCtrl.text   = e['nombre']   ?? '';
      _apellidoCtrl.text = e['apellido'] ?? '';
      _cedulaCtrl.text   = e['cedula']   ?? '';
      _emailCtrl.text    = e['email']    ?? '';
      _rolSelected = (e['rol'] == 'admin') ? 'supervisor' : (e['rol'] ?? 'cajero');
      // ✅ FIX: cast seguro — backend puede retornar objeto o int
      _tiendaSelected = e['tienda'] is int
          ? e['tienda'] as int
          : (e['tienda_id'] as int?);
    }
  }

  Future<void> _cargarTiendas() async {
    final tiendas = await _empleadoService.getTiendas();
    // ✅ FIX: mounted guard — el dialog pudo cerrarse antes de la respuesta
    if (mounted) setState(() => _tiendas = tiendas);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _cedulaCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.empleado != null;

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
          Icon(esEdicion ? Icons.edit_rounded : Icons.person_add_rounded,
              color: Colors.white),
          const SizedBox(width: 10),
          Text(
            esEdicion ? 'Editar Empleado' : 'Nuevo Empleado',
            style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ]),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 8),

              // Nombre + Apellido
              Row(children: [
                Expanded(child: _campo('Nombre *', _nombreCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _campo('Apellido *', _apellidoCtrl)),
              ]),

              // Cédula
              _campo('Cédula *', _cedulaCtrl,
                keyboardType: TextInputType.number),

              // Email
              _campo('Email *', _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Email inválido';
                  return null;
                },
              ),

              // Contraseña (solo en creación)
              if (!esEdicion)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller:  _passCtrl,
                    obscureText: _obscurePass,
                    decoration: InputDecoration(
                      labelText:  'Contraseña *',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      filled:     true,
                      fillColor:  Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(Constants.primaryColor), width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                ),

              // Rol
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  value: _rolSelected,
                  decoration: InputDecoration(
                    labelText:  'Rol *',
                    labelStyle: GoogleFonts.poppins(fontSize: 13),
                    filled:     true,
                    fillColor:  Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cajero',     child: Text('Cajero')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                  ],
                  onChanged: (v) => setState(() => _rolSelected = v!),
                ),
              ),

              // Tienda
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<int>(
                  value: _tiendaSelected,
                  hint: Text('Sin tienda asignada',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
                  decoration: InputDecoration(
                    labelText:  'Tienda',
                    labelStyle: GoogleFonts.poppins(fontSize: 13),
                    filled:     true,
                    fillColor:  Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  items: _tiendas.map((t) => DropdownMenuItem<int>(
                    value: t['id'],
                    child: Text(t['nombre'] ?? '',
                        style: GoogleFonts.poppins(fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setState(() => _tiendaSelected = v),
                ),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _campo(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller:   ctrl,
        keyboardType: keyboardType,
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
            borderSide: const BorderSide(
                color: Color(Constants.primaryColor), width: 2),
          ),
        ),
        validator: validator ??
            (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final data = {
      'nombre':   _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'cedula':   _cedulaCtrl.text.trim(),
      'email':    _emailCtrl.text.trim(),
      'rol':      _rolSelected,
      if (_tiendaSelected != null) 'tienda': _tiendaSelected,
      if (_passCtrl.text.isNotEmpty) 'password': _passCtrl.text.trim(),
    };

    try {
      await widget.onGuardar(data);
      // ✅ FIX: cierra el dialog al guardar exitosamente
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // ✅ FIX: desbloquea el botón si onGuardar lanza
      if (mounted) setState(() => _guardando = false);
    }
  }
}