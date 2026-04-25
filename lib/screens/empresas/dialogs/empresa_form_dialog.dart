// lib/screens/empresas/dialogs/empresa_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../models/empresa_model.dart';
import '../../../providers/empresa_provider.dart';
import '../../../widgets/app/app_form_field.dart';

class EmpresaFormDialog extends StatefulWidget {
  const EmpresaFormDialog({super.key, this.empresa});

  final Empresa? empresa;

  static Future<void> show(
    BuildContext context, {
    Empresa? empresa,
  }) {
    return showDialog(
      context: context,
      builder: (_) => EmpresaFormDialog(empresa: empresa),
    );
  }

  @override
  State<EmpresaFormDialog> createState() => _EmpresaFormDialogState();
}

class _EmpresaFormDialogState extends State<EmpresaFormDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _nitCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _ciudadCtrl;

  bool get _editando => widget.empresa != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl    = TextEditingController(text: widget.empresa?.nombre    ?? '');
    _nitCtrl       = TextEditingController(text: widget.empresa?.nit       ?? '');
    _emailCtrl     = TextEditingController(text: widget.empresa?.email     ?? '');
    _telefonoCtrl  = TextEditingController(text: widget.empresa?.telefono  ?? '');
    _direccionCtrl = TextEditingController(text: widget.empresa?.direccion ?? '');
    _ciudadCtrl    = TextEditingController(text: widget.empresa?.ciudad    ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _nitCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty || _nitCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nombre y NIT son obligatorios',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    final data = {
      'nombre':    _nombreCtrl.text.trim(),
      'nit':       _nitCtrl.text.trim(),
      'email':     _emailCtrl.text.trim(),
      'telefono':  _telefonoCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
      'ciudad':    _ciudadCtrl.text.trim(),
    };

    final prov = context.read<EmpresaProvider>();
    final ok = _editando
        ? await prov.editarEmpresa(widget.empresa!.id, data)
        : await prov.crearEmpresa(data);

    if (ok && mounted) Navigator.pop(context);
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
        child: Row(children: [
          const Icon(Icons.business_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            _editando ? 'Editar Empresa' : 'Nueva Empresa',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ]),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              AppFormField(
                  label: 'Nombre de la empresa *',
                  controller: _nombreCtrl),
              AppFormField(label: 'NIT *', controller: _nitCtrl),
              AppFormField(
                  label: 'Email',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress),
              AppFormField(
                  label: 'Teléfono',
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone),
              AppFormField(label: 'Dirección', controller: _direccionCtrl),
              AppFormField(label: 'Ciudad',    controller: _ciudadCtrl),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: GoogleFonts.poppins(color: Colors.grey)),
        ),
        Consumer<EmpresaProvider>(
          builder: (_, prov, __) => ElevatedButton.icon(
            icon: prov.guardando
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              _editando ? 'Guardar cambios' : 'Crear empresa',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            onPressed: prov.guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(Constants.primaryColor),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}