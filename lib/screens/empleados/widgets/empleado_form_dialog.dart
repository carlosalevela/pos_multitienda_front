import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../models/empresa_model.dart';
import '../../../services/empleado_service.dart';
import '../../../services/empresa_service.dart';

class EmpleadoFormDialog extends StatefulWidget {
  final Map<String, dynamic>? empleado;
  final Future<void> Function(Map<String, dynamic>) onGuardar;

  const EmpleadoFormDialog({
    super.key,
    this.empleado,
    required this.onGuardar,
  });

  @override
  State<EmpleadoFormDialog> createState() => _EmpleadoFormDialogState();
}

class _EmpleadoFormDialogState extends State<EmpleadoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _empleadoService = EmpleadoService();
  final _empresaService = EmpresaService();

  bool _obscurePass = true;
  bool _guardando = false;
  String _rolSelected = 'cajero';

  int? _empresaSelected;
  int? _tiendaSelected;

  List<Empresa> _empresas = [];
  List<Map<String, dynamic>> _tiendas = [];

  bool get _esEdicion => widget.empleado != null;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _cargarEmpresas();

    if (widget.empleado != null) {
      final e = widget.empleado!;

      _nombreCtrl.text = e['nombre'] ?? '';
      _apellidoCtrl.text = e['apellido'] ?? '';
      _cedulaCtrl.text = e['cedula'] ?? '';
      _emailCtrl.text = e['email'] ?? '';
      _rolSelected = (e['rol'] == 'admin') ? 'supervisor' : (e['rol'] ?? 'cajero');

      final empresa = e['empresa'];
      if (empresa is int) {
        _empresaSelected = empresa;
      } else if (e['empresa_id'] is int) {
        _empresaSelected = e['empresa_id'] as int;
      }

      final tienda = e['tienda'];
      if (tienda is int) {
        _tiendaSelected = tienda;
      } else if (e['tienda_id'] is int) {
        _tiendaSelected = e['tienda_id'] as int;
      }

      if (_empresaSelected != null) {
        await _cargarTiendasPorEmpresa(_empresaSelected!, preservarSeleccion: true);
      }
    }
  }

  Future<void> _cargarEmpresas() async {
    final empresas = await _empresaService.getEmpresas();
    if (!mounted) return;
    setState(() => _empresas = empresas);
  }

  Future<void> _cargarTiendasPorEmpresa(
    int empresaId, {
    bool preservarSeleccion = false,
  }) async {
    final tiendas = await _empleadoService.getTiendas(empresaId: empresaId);
    if (!mounted) return;

    setState(() {
      _tiendas = tiendas;
      if (!preservarSeleccion) {
        _tiendaSelected = null;
      }
    });
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(
              _esEdicion ? Icons.edit_rounded : Icons.person_add_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              _esEdicion ? 'Editar Empleado' : 'Nuevo Empleado',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(child: _campo('Nombre *', _nombreCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _campo('Apellido *', _apellidoCtrl)),
                  ],
                ),

                _campo(
                  'Cédula *',
                  _cedulaCtrl,
                  keyboardType: TextInputType.number,
                ),

                _campo(
                  'Email *',
                  _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),

                if (!_esEdicion)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Contraseña *',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        filled: true,
                        fillColor: Colors.grey.shade50,
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
                            color: Color(Constants.primaryColor),
                            width: 2,
                          ),
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

                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    value: _rolSelected,
                    decoration: InputDecoration(
                      labelText: 'Rol *',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade50,
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
                      DropdownMenuItem(value: 'cajero', child: Text('Cajero')),
                      DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                    ],
                    onChanged: (v) => setState(() => _rolSelected = v!),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<int>(
                    value: _empresaSelected,
                    decoration: InputDecoration(
                      labelText: 'Empresa *',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    hint: Text(
                      'Seleccione una empresa',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                    ),
                    items: _empresas.map((empresa) {
                      return DropdownMenuItem<int>(
                        value: empresa.id,
                        child: Text(
                          empresa.nombre,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) async {
                      setState(() {
                        _empresaSelected = v;
                        _tiendaSelected = null;
                        _tiendas = [];
                      });

                      if (v != null) {
                        await _cargarTiendasPorEmpresa(v);
                      }
                    },
                    validator: (v) {
                      if (v == null) return 'Seleccione una empresa';
                      return null;
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<int>(
                    value: _tiendaSelected,
                    decoration: InputDecoration(
                      labelText: 'Tienda',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    hint: Text(
                      _empresaSelected == null
                          ? 'Primero seleccione una empresa'
                          : 'Sin tienda asignada',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                    ),
                    items: _tiendas.map((t) {
                      return DropdownMenuItem<int>(
                        value: t['id'] as int,
                        child: Text(
                          (t['nombre'] ?? '').toString(),
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: _empresaSelected == null
                        ? null
                        : (v) => setState(() => _tiendaSelected = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ),
        ElevatedButton.icon(
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(
            _esEdicion ? 'Actualizar' : 'Guardar',
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
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          filled: true,
          fillColor: Colors.grey.shade50,
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
              color: Color(Constants.primaryColor),
              width: 2,
            ),
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
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'cedula': _cedulaCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'rol': _rolSelected,
      if (_tiendaSelected != null) 'tienda': _tiendaSelected,
      if (_passCtrl.text.isNotEmpty) 'password': _passCtrl.text.trim(),
      if (_empresaSelected != null) 'empresa': _empresaSelected,
    };

    try {
      await widget.onGuardar(data);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}