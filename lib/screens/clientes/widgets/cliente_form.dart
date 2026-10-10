import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/cliente.dart';
import '../../../providers/cliente_provider.dart';

const _kGreen     = Color(0xFF006C49);
const _kGreenBg   = Color(0xFFE8FFF4);
const _kText      = Color(0xFF191C1E);
const _kMuted     = Color(0xFF76777D);
const _kBorder    = Color(0xFFE0E3E5);
const _kSurface   = Color(0xFFF7F9FB);
const _kDanger    = Color(0xFFBA1A1A);

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

  static Future<void> mostrar(
    BuildContext context, {
    Cliente?      cliente,
    int?          tiendaId,
    VoidCallback? onGuardado,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    if (isWide) {
      return showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ClienteForm(cliente: cliente, tiendaId: tiendaId, onGuardado: onGuardado),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => ClienteForm(cliente: cliente, tiendaId: tiendaId, onGuardado: onGuardado),
    );
  }

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _formKey       = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _apellidoCtrl  = TextEditingController();
  final _cedulaCtrl    = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _creditoCtrl   = TextEditingController();

  bool get _esEdicion => widget.cliente != null;

  String get _iniciales {
    final n = _nombreCtrl.text.trim();
    final a = _apellidoCtrl.text.trim();
    return [
      if (n.isNotEmpty) n[0],
      if (a.isNotEmpty) a[0],
    ].join().toUpperCase();
  }

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
      if (c.limiteCredito > 0) _creditoCtrl.text = c.limiteCredito.toStringAsFixed(0);
    }
    _nombreCtrl.addListener(() => setState(() {}));
    _apellidoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _creditoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final prov = context.read<ClienteProvider>();
    final creditoStr = _creditoCtrl.text.trim();
    final data = {
      'nombre':         _nombreCtrl.text.trim(),
      'apellido':       _apellidoCtrl.text.trim(),
      'cedula_nit':     _cedulaCtrl.text.trim().isEmpty ? null : _cedulaCtrl.text.trim(),
      'telefono':       _telefonoCtrl.text.trim(),
      'email':          _emailCtrl.text.trim(),
      'direccion':      _direccionCtrl.text.trim(),
      'limite_credito': creditoStr.isEmpty ? 0 : double.tryParse(creditoStr) ?? 0,
      if (widget.tiendaId != null) 'tienda': widget.tiendaId,
    };

    final ok = _esEdicion
        ? await prov.editarCliente(widget.cliente!.id, data)
        : await prov.crearCliente(data);

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      widget.onGuardado?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(_esEdicion ? 'Cliente actualizado' : 'Cliente creado'),
        backgroundColor: _kGreen,
        behavior:        SnackBarBehavior.floating,
        margin:          const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(prov.error ?? 'Error al guardar'),
        backgroundColor: _kDanger,
        behavior:        SnackBarBehavior.floating,
        margin:          const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide  = MediaQuery.of(context).size.width >= 700;
    final bottom  = MediaQuery.of(context).viewInsets.bottom;
    final iniciales = _iniciales;

    final content = Form(
      key: _formKey,
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          _buildHeader(iniciales, isWide),
          const SizedBox(height: 20),

          // ── Campos en dos columnas ───────────────────────
          _seccion('Información personal', [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _campo(ctrl: _nombreCtrl, label: 'Nombre', icono: Icons.person_outline_rounded, obligatorio: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null)),
              const SizedBox(width: 12),
              Expanded(child: _campo(ctrl: _apellidoCtrl, label: 'Apellido', icono: Icons.person_outline_rounded)),
            ]),
            const SizedBox(height: 12),
            _campo(ctrl: _cedulaCtrl, label: 'Cédula / NIT', icono: Icons.badge_outlined,
                tipo: TextInputType.number, capitalizacion: TextCapitalization.none),
          ]),

          const SizedBox(height: 16),
          _seccion('Contacto', [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _campo(ctrl: _telefonoCtrl, label: 'Teléfono', icono: Icons.phone_outlined,
                  tipo: TextInputType.phone, capitalizacion: TextCapitalization.none)),
              const SizedBox(width: 12),
              Expanded(child: _campo(
                ctrl:           _emailCtrl,
                label:          'Email',
                icono:          Icons.email_outlined,
                tipo:           TextInputType.emailAddress,
                capitalizacion: TextCapitalization.none,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v.trim()) ? null : 'Email inválido';
                },
              )),
            ]),
            const SizedBox(height: 12),
            _campo(ctrl: _direccionCtrl, label: 'Dirección', icono: Icons.location_on_outlined, maxLines: 2),
          ]),

          const SizedBox(height: 16),
          _seccion('Crédito', [
            _campo(
              ctrl:           _creditoCtrl,
              label:          'Límite de crédito',
              icono:          Icons.handshake_rounded,
              tipo:           TextInputType.number,
              capitalizacion: TextCapitalization.none,
              hint:           '0 = sin límite',
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (double.tryParse(v.trim()) == null) return 'Número inválido';
                return null;
              },
            ),
          ]),

          const SizedBox(height: 24),

          // ── Botones ──────────────────────────────────────
          Selector<ClienteProvider, bool>(
            selector: (_, p) => p.guardando,
            builder: (_, guardando, child) => Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: guardando ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side:    const BorderSide(color: _kBorder),
                    shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Cancelar', style: GoogleFonts.inter(color: _kMuted, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:        _kGreen,
                    foregroundColor:        Colors.white,
                    disabledBackgroundColor: _kBorder,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: guardando
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _esEdicion ? 'Guardar cambios' : 'Crear cliente',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );

    // ── Contenedor ──────────────────────────────────────────
    if (isWide) {
      return Container(
        padding:    const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child:      SingleChildScrollView(child: content),
      );
    }

    return Container(
      padding:    EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          content,
        ]),
      ),
    );
  }

  Widget _buildHeader(String iniciales, bool isWide) {
    return Row(children: [
      // Avatar con iniciales en tiempo real
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color:        iniciales.isNotEmpty ? _kGreenBg : _kSurface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: iniciales.isNotEmpty ? _kGreen.withValues(alpha: 0.3) : _kBorder),
        ),
        child: Center(
          child: iniciales.isNotEmpty
              ? Text(iniciales, style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w800, fontSize: 18))
              : const Icon(Icons.person_outline_rounded, color: _kMuted, size: 22),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _esEdicion ? 'Editar cliente' : 'Nuevo cliente',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: _kText),
        ),
        Text(
          _esEdicion
              ? 'Modifica los datos del cliente'
              : 'Completa los datos para registrar',
          style: GoogleFonts.inter(fontSize: 12, color: _kMuted),
        ),
      ])),
      if (isWide)
        IconButton(
          icon:       const Icon(Icons.close_rounded, color: _kMuted),
          onPressed:  () => Navigator.pop(context),
          padding:    EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
    ]);
  }

  Widget _seccion(String titulo, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 3, height: 13, decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(titulo, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.5)),
        ]),
      ),
      ...children,
    ]);
  }

  Widget _campo({
    required TextEditingController ctrl,
    required String                label,
    required IconData              icono,
    TextInputType                  tipo           = TextInputType.text,
    String? Function(String?)?     validator,
    bool                           obligatorio    = false,
    int                            maxLines       = 1,
    TextCapitalization             capitalizacion = TextCapitalization.words,
    String?                        hint,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(
        text: TextSpan(
          text:  label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted, letterSpacing: 0.3),
          children: [
            if (obligatorio)
              const TextSpan(text: ' *', style: TextStyle(color: _kDanger)),
          ],
        ),
      ),
      const SizedBox(height: 5),
      TextFormField(
        controller:         ctrl,
        keyboardType:       tipo,
        maxLines:           maxLines,
        textCapitalization: capitalizacion,
        validator:          validator,
        style: GoogleFonts.inter(fontSize: 13, color: _kText, fontWeight: FontWeight.w500),
        inputFormatters: tipo == TextInputType.number ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null,
        decoration: InputDecoration(
          prefixIcon:     Icon(icono, size: 17, color: _kGreen),
          hintText:       hint ?? 'Ingresa $label',
          hintStyle:      GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB0B7BF)),
          filled:         true,
          fillColor:      _kSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border:         _border12,
          enabledBorder:  _border12,
          focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGreen, width: 1.5)),
          errorBorder:    OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kDanger)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kDanger, width: 1.5)),
        ),
      ),
    ]);
  }

  static final _border12 = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide:   const BorderSide(color: _kBorder),
  );
}
