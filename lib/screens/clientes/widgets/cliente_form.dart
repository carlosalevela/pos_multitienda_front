import 'cliente_contacto.dart' show celularLocal;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../inventario/widgets/inventario_movil.dart' show InventarioMovil;
import 'package:provider/provider.dart';
import '../../../models/cliente.dart';
import '../../../providers/cliente_provider.dart';

// Computador: el verde oscuro del sistema. Celular: la paleta verde claro.
const _kGreenPc   = Color(0xFF006C49);
const _kGreenMov  = Color(0xFF059669);
const _kText      = Color(0xFF0F172A);
const _kMuted     = Color(0xFF475569);
const _kBorder    = Color(0xFFD1FAE5);
const _kDanger    = Color(0xFFB91C1C);
const _kMorado    = Color(0xFF6D28D9);

TextStyle _t({double size = 13, FontWeight w = FontWeight.w500, Color color = _kText}) {
  final f = InventarioMovil.fuenteDePrueba;
  if (f != null) return TextStyle(fontFamily: f, fontSize: size, fontWeight: w, color: color);
  return GoogleFonts.inter(fontSize: size, fontWeight: w, color: color);
}

/// "300.000" → 300000 (los puntos son de miles, no decimales).
double? leerPesos(String t) {
  final d = t.replaceAll(RegExp(r'[^\d]'), '');
  return d.isEmpty ? null : double.tryParse(d);
}

String _miles(double v) => v.round().toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

class ClienteForm extends StatefulWidget {
  final Cliente?      cliente;
  final int?          tiendaId;
  final String        tiendaNombre;
  final VoidCallback? onGuardado;

  const ClienteForm({
    super.key,
    this.cliente,
    this.tiendaId,
    this.tiendaNombre = '',
    this.onGuardado,
  });

  static Future<void> mostrar(
    BuildContext context, {
    Cliente?      cliente,
    int?          tiendaId,
    String        tiendaNombre = '',
    VoidCallback? onGuardado,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final form = ClienteForm(cliente: cliente, tiendaId: tiendaId,
        tiendaNombre: tiendaNombre, onGuardado: onGuardado);

    if (isWide) {
      return showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: form,
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => form,
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
  bool _credito = false;

  bool get _esEdicion => widget.cliente != null;
  Color get _verde => MediaQuery.sizeOf(context).width >= 700 ? _kGreenPc : _kGreenMov;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final c = widget.cliente!;
      _nombreCtrl.text    = c.nombre;
      _apellidoCtrl.text  = c.apellido;
      _cedulaCtrl.text    = c.cedulaNit ?? '';
      _telefonoCtrl.text  = celularLocal(c.telefono);
      _emailCtrl.text     = c.email;
      _direccionCtrl.text = c.direccion;
      if (c.limiteCredito > 0) {
        _credito = true;
        _creditoCtrl.text = _miles(c.limiteCredito);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _apellidoCtrl, _cedulaCtrl, _telefonoCtrl,
                     _emailCtrl, _direccionCtrl, _creditoCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final prov = context.read<ClienteProvider>();
    final data = {
      'nombre':         _nombreCtrl.text.trim(),
      'apellido':       _apellidoCtrl.text.trim(),
      'cedula_nit':     _cedulaCtrl.text.trim().isEmpty ? null : _cedulaCtrl.text.trim(),
      'telefono':       celularLocal(_telefonoCtrl.text),
      'email':          _emailCtrl.text.trim(),
      'direccion':      _direccionCtrl.text.trim(),
      'limite_credito': _credito ? (leerPesos(_creditoCtrl.text) ?? 0) : 0,
      if (widget.tiendaId != null) 'tienda': widget.tiendaId,
    };

    final ok = _esEdicion
        ? await prov.editarCliente(widget.cliente!.id, data)
        : await prov.crearCliente(data);

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      Navigator.pop(context);
      widget.onGuardado?.call();
      messenger.showSnackBar(SnackBar(
        content:         Text(_esEdicion ? 'Cliente actualizado' : 'Cliente creado'),
        backgroundColor: _kGreenPc,
        behavior:        SnackBarBehavior.floating,
        margin:          const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
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
    final isWide = MediaQuery.of(context).size.width >= 700;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    Widget fila(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ]);

    final content = Form(
      key: _formKey,
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_esEdicion ? 'Editar cliente' : 'Nuevo cliente',
                    style: _t(size: 18, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  _esEdicion
                      ? 'Cambia lo que necesites y guarda.'
                      : 'Solo el nombre es obligatorio.'
                        '${widget.tiendaNombre.isEmpty ? '' : ' Queda en ${widget.tiendaNombre}.'}',
                  style: _t(size: 12.5, color: _kMuted),
                ),
              ]),
            ),
            if (isWide)
              IconButton(
                tooltip:   'Cerrar',
                icon:      const Icon(Icons.close_rounded, color: _kMuted),
                onPressed: () => Navigator.pop(context),
              ),
          ]),
          const SizedBox(height: 16),
          fila(
            _campo(ctrl: _nombreCtrl, label: 'Nombre', obligatorio: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null),
            _campo(ctrl: _apellidoCtrl, label: 'Apellido'),
          ),
          const SizedBox(height: 12),
          _campo(
            ctrl: _telefonoCtrl, label: 'Celular (para WhatsApp)',
            tipo: TextInputType.phone, capitalizacion: TextCapitalization.none,
            prefijo: '+57', hint: '311 737 4019',
            validator: (v) {
              final d = celularLocal(v ?? '');
              if (d.isEmpty || d.length == 10 || d.length == 7) return null;
              return 'Escribe los 10 números del celular';
            },
          ),
          const SizedBox(height: 12),
          _campo(ctrl: _cedulaCtrl, label: 'Cédula / NIT', hint: 'Opcional',
              tipo: TextInputType.number, capitalizacion: TextCapitalization.none),
          const SizedBox(height: 12),
          fila(
            _campo(
              ctrl: _emailCtrl, label: 'Email', hint: 'Opcional',
              tipo: TextInputType.emailAddress, capitalizacion: TextCapitalization.none,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v.trim()) ? null : 'Email inválido';
              },
            ),
            _campo(ctrl: _direccionCtrl, label: 'Dirección', hint: 'Opcional',
                capitalizacion: TextCapitalization.sentences),
          ),
          const SizedBox(height: 14),
          _tarjetaCredito(),
          const SizedBox(height: 18),
          Selector<ClienteProvider, bool>(
            selector: (_, p) => p.guardando,
            builder: (_, guardando, _) => Row(children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: guardando ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      side:  BorderSide(color: _verde.withValues(alpha: .35), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cancelar', maxLines: 1, softWrap: false,
                        style: _t(size: 14, w: FontWeight.w700, color: _verde)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: guardando ? null : _guardar,
                    style: FilledButton.styleFrom(
                      backgroundColor: _verde,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: guardando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(_esEdicion ? 'Guardar cambios' : 'Guardar cliente',
                            style: _t(size: 14, w: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );

    if (isWide) {
      return Container(
        padding:    const EdgeInsets.all(26),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child:      SingleChildScrollView(child: content),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .94),
      padding:     EdgeInsets.fromLTRB(18, 0, 18, 18 + bottom),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            content,
          ]),
        ),
      ),
    );
  }

  Widget _tarjetaCredito() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: _credito ? const Color(0xFFF5F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _credito ? const Color(0xFFDDD6FE) : _kBorder, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Puede comprar a crédito', style: _t(size: 13.5, w: FontWeight.w700)),
                Text(_credito ? 'Hasta el límite que pongas' : 'Si no, solo paga de contado o con separados',
                    style: _t(size: 11.5, color: _kMuted)),
              ]),
            ),
            Switch(
              value: _credito,
              activeThumbColor: Colors.white,
              activeTrackColor: _kMorado,
              onChanged: (v) => setState(() => _credito = v),
            ),
          ]),
          if (_credito) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
              child: _campo(
                ctrl: _creditoCtrl, label: 'Límite de crédito', prefijo: r'$',
                hint: '300.000', tipo: TextInputType.number,
                capitalizacion: TextCapitalization.none, color: _kMorado,
                validator: (v) {
                  if (!_credito) return null;
                  final n = leerPesos(v ?? '');
                  if (n == null || n <= 0) return 'Escribe el límite (mayor a cero)';
                  return null;
                },
              ),
            ),
          ],
        ]),
      );

  Widget _campo({
    required TextEditingController ctrl,
    required String                label,
    TextInputType                  tipo           = TextInputType.text,
    String? Function(String?)?     validator,
    bool                           obligatorio    = false,
    TextCapitalization             capitalizacion = TextCapitalization.words,
    String?                        hint,
    String?                        prefijo,
    Color?                         color,
  }) {
    final acento = color ?? _verde;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(
        text:  label,
        style: _t(size: 11.5, w: FontWeight.w700, color: const Color(0xFF334155)),
        children: [
          if (obligatorio) TextSpan(text: ' *', style: _t(size: 11.5, w: FontWeight.w700, color: _kDanger)),
        ],
      )),
      const SizedBox(height: 4),
      TextFormField(
        controller:         ctrl,
        keyboardType:       tipo,
        textCapitalization: capitalizacion,
        validator:          validator,
        style: _t(size: 13.5, w: FontWeight.w600),
        inputFormatters: tipo == TextInputType.number || tipo == TextInputType.phone
            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d. ]'))]
            : null,
        decoration: InputDecoration(
          isDense:        true,
          prefixIcon:     prefijo == null ? null : Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Text(prefijo, style: _t(size: 13.5, w: FontWeight.w800, color: acento)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          hintText:       hint,
          hintStyle:      _t(size: 13, color: const Color(0xFF94A3B8)),
          filled:         true,
          fillColor:      Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder, width: 1.5)),
          focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: acento, width: 1.6)),
          errorBorder:    OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kDanger, width: 1.3)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kDanger, width: 1.6)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]);
  }
}
