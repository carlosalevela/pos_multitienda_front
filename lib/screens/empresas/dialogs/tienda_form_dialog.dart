import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../models/tienda_model.dart';
import '../../../providers/tienda_provider.dart';
import '../../../widgets/app/app_form_field.dart';

class TiendaFormDialog extends StatefulWidget {
  const TiendaFormDialog({
    super.key,
    this.tienda,
    this.empresaId,
  });

  final Tienda? tienda;
  final String? empresaId;

  static Future<void> show(
    BuildContext context, {
    Tienda? tienda,
    String? empresaId,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TiendaFormDialog(
        tienda: tienda,
        empresaId: empresaId,
      ),
    );
  }

  @override
  State<TiendaFormDialog> createState() => _TiendaFormDialogState();
}

class _TiendaFormDialogState extends State<TiendaFormDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _ciudadCtrl;
  late final TextEditingController _nitCtrl;

  bool get _editando => widget.tienda != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.tienda?.nombre ?? '');
    _direccionCtrl = TextEditingController(text: widget.tienda?.direccion ?? '');
    _telefonoCtrl = TextEditingController(text: widget.tienda?.telefono ?? '');
    _ciudadCtrl = TextEditingController(text: widget.tienda?.ciudad ?? '');
    _nitCtrl = TextEditingController(text: widget.tienda?.nit ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _ciudadCtrl.dispose();
    _nitCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El nombre de la tienda es obligatorio',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final empresaIdInt = widget.empresaId != null
        ? int.tryParse(widget.empresaId!)
        : null;

    if (!_editando && empresaIdInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se encontró la empresa seleccionada para esta sucursal',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final data = <String, dynamic>{
      'nombre': _nombreCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'ciudad': _ciudadCtrl.text.trim(),
      'nit': _nitCtrl.text.trim(),
      if (!_editando && empresaIdInt != null) 'empresa': empresaIdInt,
    };

    final prov = context.read<TiendaProvider>();

    final ok = _editando
        ? await prov.editarTienda(
            widget.tienda!.id,
            data,
            empresaId: widget.tienda?.empresaId,
          )
        : await prov.crearTienda(
            data,
            empresaId: empresaIdInt,
          );

    if (ok && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.store_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              _editando ? 'Editar Sucursal' : 'Nueva Sucursal',
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
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              AppFormField(
                label: 'Nombre de la sucursal *',
                controller: _nombreCtrl,
              ),
              AppFormField(
                label: 'Dirección',
                controller: _direccionCtrl,
              ),
              AppFormField(
                label: 'Teléfono',
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
              ),
              AppFormField(
                label: 'Ciudad',
                controller: _ciudadCtrl,
              ),
              AppFormField(
                label: 'NIT',
                controller: _nitCtrl,
              ),
            ],
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
        Consumer<TiendaProvider>(
          builder: (_, prov, __) => ElevatedButton.icon(
            icon: prov.guardando
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
              _editando ? 'Guardar cambios' : 'Crear sucursal',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: prov.guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(Constants.primaryColor),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}