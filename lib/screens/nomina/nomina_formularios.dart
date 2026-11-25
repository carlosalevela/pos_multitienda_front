// lib/screens/nomina/nomina_formularios.dart
//
// Formularios de Nómina: persona, pago, valores del año, liquidación de
// salida, documento y memorando. Los mismos en el computador (diálogo) y en
// el celular (hoja de abajo); cambia el color de acento.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/cuenta_bancaria.dart';
import '../../services/nomina_service.dart';
import '../gastos/gastos_formularios.dart' show TiendaOpcion, gf;

// ── Estilo y piezas comunes ───────────────────────────────────

const tintaN = Color(0xFF0F172A);
const grisN = Color(0xFF64748B);
const bordeN = Color(0xFFDCF0E4);
const rojoN = Color(0xFFB91C1C);
const ambarN = Color(0xFFB45309);

Widget seccionN(String t, Color acento) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(t.toUpperCase(),
          style: gf(size: 10.5, w: FontWeight.w800, color: acento, ls: 0.9)),
    );

Widget chipN(String texto, bool sel, Color acento, VoidCallback? onTap) => Material(
      color: sel ? acento : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? acento : bordeN, width: 1.3),
          ),
          child: Text(texto,
              style: gf(size: 12, w: FontWeight.w700,
                  color: sel ? Colors.white : const Color(0xFF334155))),
        ),
      ),
    );

InputDecoration decoN(String etiqueta, Color acento, {String? prefijo, String? ayuda}) =>
    InputDecoration(
      labelText: etiqueta,
      labelStyle: gf(size: 12, color: grisN),
      helperText: ayuda,
      helperStyle: gf(size: 11, color: grisN),
      helperMaxLines: 2,
      prefixText: prefijo,
      prefixStyle: gf(size: 13.5, w: FontWeight.w700),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: bordeN, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: acento, width: 1.6),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

Widget avisoN(String t, {bool error = true}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: error ? const Color(0xFFFEE2E2) : const Color(0xFFFDE68A)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 16, color: error ? rojoN : ambarN),
        const SizedBox(width: 7),
        Expanded(
          child: Text(t, style: gf(size: 12, w: FontWeight.w600,
              color: error ? rojoN : const Color(0xFF78350F), h: 1.35)),
        ),
      ]),
    );

Widget botonesN({
  required Color acento,
  required String texto,
  required bool guardando,
  required VoidCallback? onGuardar,
  required VoidCallback onCancelar,
  String cancelar = 'Cancelar',
}) =>
    Row(children: [
      Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: guardando ? null : onCancelar,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(cancelar, maxLines: 1,
                style: gf(size: 14, w: FontWeight.w700, color: const Color(0xFF334155))),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: guardando ? null : onGuardar,
            style: FilledButton.styleFrom(
              backgroundColor: acento,
              disabledBackgroundColor: acento.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: guardando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: gf(size: 14, w: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    ]);

/// Título del formulario y contenido con scroll; los botones quedan abajo.
class MarcoForm extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> hijos;
  final Widget pie;
  const MarcoForm({super.key, required this.titulo, this.subtitulo,
      required this.hijos, required this.pie});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: gf(size: 18, w: FontWeight.w800)),
            if (subtitulo != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitulo!, style: gf(size: 12.5, color: grisN)),
              ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), child: pie),
      ]);
}

Future<DateTime?> elegirFechaN(BuildContext context, DateTime inicial,
        {DateTime? primera, DateTime? ultima, String ayuda = 'Elige la fecha'}) =>
    showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primera ?? DateTime(2015),
      lastDate: ultima ?? DateTime(DateTime.now().year + 2, 12, 31),
      helpText: ayuda,
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );

Widget campoFecha(String etiqueta, DateTime? valor, Color acento, VoidCallback onTap,
        {VoidCallback? onBorrar}) =>
    InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: decoN(etiqueta, acento),
        child: Row(children: [
          Expanded(child: Text(valor == null ? 'Elegir' : fechaCorta(valor),
              style: gf(size: 13.5, w: FontWeight.w700,
                  color: valor == null ? grisN : tintaN))),
          if (valor != null && onBorrar != null)
            InkWell(onTap: onBorrar, child: const Icon(Icons.close_rounded, size: 16, color: grisN))
          else
            const Icon(Icons.calendar_today_rounded, size: 16, color: grisN),
        ]),
      ),
    );

Widget interruptorN(String titulo, String? sub, bool valor, Color acento,
        ValueChanged<bool> onChanged) =>
    Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bordeN, width: 1.3),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: gf(size: 13, w: FontWeight.w700)),
            if (sub != null) Text(sub, style: gf(size: 11.5, color: grisN, h: 1.3)),
          ]),
        ),
        Switch(value: valor, activeThumbColor: acento, onChanged: onChanged),
      ]),
    );

// ══════════════════════════════════════════════════════════════
// PERSONA
// ══════════════════════════════════════════════════════════════

class FormPersona extends StatefulWidget {
  final List<TiendaOpcion> tiendas;
  final int? tiendaInicial;
  final Trabajador? persona;
  final int salarioMinimo;
  final Color acento;
  final Future<String?> Function(Map<String, dynamic> datos) onGuardar;
  final VoidCallback onCancelar;

  const FormPersona({super.key, required this.tiendas, required this.salarioMinimo,
      required this.acento, required this.onGuardar, required this.onCancelar,
      this.tiendaInicial, this.persona});

  @override
  State<FormPersona> createState() => _FormPersonaState();
}

class _FormPersonaState extends State<FormPersona> {
  late final _nombres = TextEditingController(text: widget.persona?.nombres ?? '');
  late final _cedula = TextEditingController(text: widget.persona?.cedula ?? '');
  late final _cargo = TextEditingController(text: widget.persona?.cargo ?? '');
  late final _cuenta = TextEditingController(text: widget.persona?.cuentaPago ?? '');
  late final _valorDia = TextEditingController(
      text: (widget.persona?.valorDia ?? 0) > 0 ? pesosNomina(widget.persona!.valorDia).substring(1) : '');
  late final _vacaciones = TextEditingController(
      text: (widget.persona?.vacacionesTomadas ?? 0) > 0 ? diasTexto(widget.persona!.vacacionesTomadas) : '');
  late int? _tienda = widget.persona?.tienda ?? widget.tiendaInicial ??
      (widget.tiendas.length == 1 ? widget.tiendas.first.id : null);
  late String _tipo = widget.persona?.tipo ?? 'nomina';
  late String _contrato = widget.persona?.tipoContrato ?? 'indefinido';
  late bool _minimo = widget.persona?.ganaMinimo ?? false;
  late bool _auxilio = widget.persona?.recibeAuxilio ?? true;
  late DateTime? _ingreso = widget.persona?.fechaIngreso;
  late DateTime? _finContrato = widget.persona?.fechaFinContrato;
  late DateTime? _primaHasta = widget.persona?.primaPagadaHasta;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _valorDia.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_nombres, _cedula, _cargo, _cuenta, _valorDia, _vacaciones]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _problema() {
    if (_nombres.text.trim().split(RegExp(r'\s+')).length < 2) {
      return 'Escribe nombres y apellidos.';
    }
    if (_tienda == null) return 'Elige la tienda.';
    final c = _cedula.text.replaceAll('.', '').trim();
    if (c.isNotEmpty && int.tryParse(c) == null) return 'La cédula lleva solo números.';
    if (!(_tipo == 'nomina' && _minimo)) {
      final v = leerNumero(_valorDia.text);
      if (v == null || v <= 0) return 'Escribe el valor del día.';
    }
    if (_tipo == 'nomina' && _contrato == 'fijo' && _finContrato == null) {
      return 'Elige hasta cuándo va el contrato a término fijo.';
    }
    return null;
  }

  Future<void> _guardar() async {
    final p = _problema();
    if (p != null) {
      setState(() => _error = p);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final nomina = _tipo == 'nomina';
    final err = await widget.onGuardar({
      'tienda': _tienda,
      'nombres': _nombres.text.trim(),
      'cedula': _cedula.text.replaceAll('.', '').trim(),
      'cargo': _cargo.text.trim(),
      'cuenta_pago': _cuenta.text.trim(),
      'tipo': _tipo,
      'tipo_contrato': nomina ? _contrato : 'temporal',
      'gana_minimo': nomina && _minimo,
      'recibe_auxilio': _auxilio,
      'valor_dia': nomina && _minimo ? 0 : (leerNumero(_valorDia.text) ?? 0),
      'fecha_ingreso': _ingreso == null ? null : fechaIso(_ingreso!),
      'fecha_fin_contrato': nomina && _contrato == 'fijo' && _finContrato != null
          ? fechaIso(_finContrato!) : null,
      'prima_pagada_hasta': _primaHasta == null ? null : fechaIso(_primaHasta!),
      'vacaciones_tomadas': leerNumero(_vacaciones.text, decimales: true) ?? 0,
    });
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    final nomina = _tipo == 'nomina';
    final v = leerNumero(_valorDia.text);
    return MarcoForm(
      titulo: widget.persona == null ? 'Nueva persona' : 'Editar persona',
      subtitulo: 'Se escribe una sola vez; el valor del día se puede cambiar en cada quincena.',
      hijos: [
        const SizedBox(height: 6),
        TextField(controller: _nombres, textCapitalization: TextCapitalization.words,
            decoration: decoN('Nombres y apellidos', a), style: gf(size: 14, w: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _cedula, keyboardType: TextInputType.number,
              decoration: decoN('Cédula', a), style: gf(size: 14))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _cargo, textCapitalization: TextCapitalization.sentences,
              decoration: decoN('Cargo', a), style: gf(size: 14))),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _tienda,
          isExpanded: true,
          decoration: decoN('Tienda', a),
          style: gf(size: 13.5, w: FontWeight.w700),
          items: [
            for (final t in widget.tiendas)
              DropdownMenuItem(value: t.id,
                  child: Text(t.nombre, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (t) => setState(() => _tienda = t),
        ),
        seccionN('Tipo', a),
        Wrap(spacing: 6, runSpacing: 6, children: [
          chipN('Nómina', nomina, a, () => setState(() => _tipo = 'nomina')),
          chipN('Temporal', !nomina, a, () => setState(() => _tipo = 'temporal')),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(nomina
              ? 'Se le descuenta salud y pensión (4 % y 4 %) y recibe auxilio de transporte si gana hasta 2 mínimos.'
              : 'Se le paga el valor del día por los días trabajados, sin descuentos de ley.',
              style: gf(size: 11.5, color: grisN, h: 1.35)),
        ),
        if (nomina) ...[
          seccionN('Contrato', a),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in contratos.entries.where((e) => e.key != 'temporal'))
              chipN(e.value, _contrato == e.key, a, () => setState(() => _contrato = e.key)),
          ]),
        ],
        seccionN('Pago', a),
        if (nomina)
          interruptorN('Gana el mínimo', 'El sueldo sigue al mínimo del año: en enero se actualiza solo.',
              _minimo, a, (x) => setState(() => _minimo = x)),
        if (!(nomina && _minimo)) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _valorDia,
            keyboardType: TextInputType.number,
            decoration: decoN('Valor del día', a, prefijo: r'$ ',
                ayuda: v != null && v > 0 && nomina ? '= ${pesosNomina(v * 30)} al mes' : null),
            style: gf(size: 14, w: FontWeight.w700),
          ),
          if (nomina)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _minimo = true),
                child: Text('Gana el mínimo (${pesosNomina(widget.salarioMinimo / 30)} el día)',
                    style: gf(size: 12, w: FontWeight.w700, color: a)),
              ),
            ),
        ],
        if (nomina)
          interruptorN('Recibe auxilio de transporte', 'Quítalo solo si vive en la tienda o la empresa lo transporta.',
              _auxilio, a, (x) => setState(() => _auxilio = x)),
        const SizedBox(height: 10),
        TextField(controller: _cuenta, decoration: decoN('Cuenta donde se le paga (opcional)', a),
            style: gf(size: 13.5)),
        seccionN('Fechas', a),
        Row(children: [
          Expanded(child: campoFecha('Fecha de ingreso', _ingreso, a, () async {
            final f = await elegirFechaN(context, _ingreso ?? DateTime.now(), ayuda: 'Fecha de ingreso');
            if (f != null) setState(() => _ingreso = f);
          })),
          if (nomina && _contrato == 'fijo') ...[
            const SizedBox(width: 8),
            Expanded(child: campoFecha('Contrato hasta', _finContrato, a, () async {
              final f = await elegirFechaN(context, _finContrato ?? DateTime.now(), ayuda: 'Fin del contrato');
              if (f != null) setState(() => _finContrato = f);
            })),
          ],
        ]),
        if (nomina) ...[
          seccionN('Si ya trabajaba antes de usar el sistema', a),
          Row(children: [
            Expanded(child: TextField(controller: _vacaciones,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: decoN('Vacaciones ya tomadas (días)', a), style: gf(size: 13.5))),
            const SizedBox(width: 8),
            Expanded(child: campoFecha('Prima pagada hasta', _primaHasta, a, () async {
              final f = await elegirFechaN(context, _primaHasta ?? DateTime.now(), ayuda: 'Prima pagada hasta');
              if (f != null) setState(() => _primaHasta = f);
            }, onBorrar: () => setState(() => _primaHasta = null))),
          ]),
        ],
        if (_error != null) avisoN(_error!),
      ],
      pie: botonesN(acento: a, texto: 'Guardar', guardando: _guardando,
          onGuardar: _guardar, onCancelar: widget.onCancelar),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PAGO (de una quincena o de una liquidación)
// ══════════════════════════════════════════════════════════════

class FormPagoNomina extends StatefulWidget {
  final String persona;
  final String concepto;
  final int falta;
  final int tienda;
  final Color acento;
  final Future<List<CuentaBancaria>> Function(int tienda) cargarCuentas;
  final Future<String?> Function(Map<String, dynamic> datos) onGuardar;
  final VoidCallback onCancelar;
  final DateTime? hoy;

  const FormPagoNomina({super.key, required this.persona, required this.concepto,
      required this.falta, required this.tienda, required this.acento,
      required this.cargarCuentas, required this.onGuardar, required this.onCancelar, this.hoy});

  @override
  State<FormPagoNomina> createState() => _FormPagoNominaState();
}

class _FormPagoNominaState extends State<FormPagoNomina> {
  late final _valor = TextEditingController(text: pesosNomina(widget.falta).substring(1));
  late DateTime _fecha = widget.hoy ?? DateTime.now();
  String _metodo = 'efectivo';
  int? _cuenta;
  List<CuentaBancaria> _cuentas = const [];
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.cargarCuentas(widget.tienda).then((l) {
      if (!mounted) return;
      setState(() {
        _cuentas = l.where((c) => c.activo).toList();
        if (_cuentas.length == 1) _cuenta = _cuentas.first.id;
      });
    });
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final v = leerNumero(_valor.text);
    String? p;
    if (v == null || v <= 0) {
      p = 'Escribe el valor que se pagó.';
    } else if (v > widget.falta) {
      p = 'Solo falta pagarle ${pesosNomina(widget.falta)}.';
    } else if (_metodo == 'transferencia' && _cuenta == null) {
      p = 'Elige de qué cuenta salió.';
    }
    if (p != null) {
      setState(() => _error = p);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final err = await widget.onGuardar({
      'valor': v!.round(),
      'fecha': fechaIso(_fecha),
      'metodo_pago': _metodo,
      if (_metodo == 'transferencia') 'cuenta_bancaria': _cuenta,
    });
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    return MarcoForm(
      titulo: 'Registrar pago',
      subtitulo: '${widget.persona} · ${widget.concepto} · falta ${pesosNomina(widget.falta)}',
      hijos: [
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(controller: _valor, keyboardType: TextInputType.number,
              decoration: decoN('Valor', a, prefijo: r'$ '),
              style: gf(size: 15, w: FontWeight.w800))),
          const SizedBox(width: 8),
          Expanded(child: campoFecha('Fecha', _fecha, a, () async {
            final h = widget.hoy ?? DateTime.now();
            final f = await elegirFechaN(context, _fecha,
                primera: DateTime(h.year - 1), ultima: h, ayuda: 'Fecha del pago');
            if (f != null) setState(() => _fecha = f);
          })),
        ]),
        seccionN('Cómo se pagó', a),
        Wrap(spacing: 6, runSpacing: 6, children: [
          chipN('Efectivo', _metodo == 'efectivo', a, () => setState(() => _metodo = 'efectivo')),
          chipN('Transferencia', _metodo == 'transferencia', a,
              () => setState(() => _metodo = 'transferencia')),
        ]),
        if (_metodo == 'transferencia') ...[
          const SizedBox(height: 10),
          if (_cuentas.isEmpty)
            Text('Esta tienda no tiene cuentas registradas (Configuración → Cuentas).',
                style: gf(size: 12, color: grisN))
          else
            DropdownButtonFormField<int>(
              initialValue: _cuenta,
              isExpanded: true,
              decoration: decoN('De qué cuenta salió', a),
              style: gf(size: 13.5, w: FontWeight.w700),
              items: [
                for (final c in _cuentas)
                  DropdownMenuItem(value: c.id, child: Text(
                      c.numero.isEmpty ? c.nombre : '${c.nombre} · ${c.numero}',
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _cuenta = v),
            ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('Se puede pagar en partes. Cada pago queda como gasto de Nómina.',
              style: gf(size: 11.5, color: grisN)),
        ),
        if (_error != null) avisoN(_error!),
      ],
      pie: botonesN(acento: a, texto: 'Registrar pago', guardando: _guardando,
          onGuardar: _guardar, onCancelar: widget.onCancelar),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// VALORES DEL AÑO
// ══════════════════════════════════════════════════════════════

class FormValores extends StatefulWidget {
  final ValoresAnio valores;
  final Color acento;
  final Future<String?> Function(Map<String, dynamic> datos) onGuardar;
  final VoidCallback onCancelar;
  const FormValores({super.key, required this.valores, required this.acento,
      required this.onGuardar, required this.onCancelar});

  @override
  State<FormValores> createState() => _FormValoresState();
}

class _FormValoresState extends State<FormValores> {
  late final _sm = TextEditingController(text: pesosNomina(widget.valores.salarioMinimo).substring(1));
  late final _aux = TextEditingController(text: pesosNomina(widget.valores.auxilioTransporte).substring(1));
  late final _arl = TextEditingController(text: '${widget.valores.arlPct}'.replaceAll('.', ','));
  late bool _exonerado = widget.valores.exonerado;
  late bool _redondear = widget.valores.redondearMil;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _sm.dispose();
    _aux.dispose();
    _arl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final sm = leerNumero(_sm.text), aux = leerNumero(_aux.text);
    final arl = leerNumero(_arl.text, decimales: true);
    if (sm == null || sm <= 0 || aux == null || aux < 0 || arl == null || arl < 0) {
      setState(() => _error = 'Revisa los valores: solo números.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final err = await widget.onGuardar({
      'anio': widget.valores.anio, 'salario_minimo': sm.round(),
      'auxilio_transporte': aux.round(), 'arl_pct': arl,
      'exonerado': _exonerado, 'redondear_mil': _redondear,
    });
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    return MarcoForm(
      titulo: 'Valores de ${widget.valores.anio}',
      subtitulo: 'Cambian cada enero con el decreto del Gobierno.',
      hijos: [
        if (!widget.valores.guardado)
          avisoN('Estos son los valores que trae el sistema. Revísalos y guárdalos.', error: false),
        const SizedBox(height: 10),
        TextField(controller: _sm, keyboardType: TextInputType.number,
            decoration: decoN('Salario mínimo mensual', a, prefijo: r'$ '),
            style: gf(size: 14, w: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(controller: _aux, keyboardType: TextInputType.number,
            decoration: decoN('Auxilio de transporte mensual', a, prefijo: r'$ '),
            style: gf(size: 14, w: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(controller: _arl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoN('ARL (%)', a, ayuda: 'Riesgo I (oficina y ventas): 0,522 %'),
            style: gf(size: 14, w: FontWeight.w700)),
        interruptorN('Exonerada de salud, ICBF y SENA', 'Por quien gana menos de 10 mínimos (pregúntale al contador).',
            _exonerado, a, (x) => setState(() => _exonerado = x)),
        interruptorN('Redondear el pago al mil', 'Hacia arriba: 929.963 se paga 930.000.',
            _redondear, a, (x) => setState(() => _redondear = x)),
        if (_error != null) avisoN(_error!),
      ],
      pie: botonesN(acento: a, texto: 'Guardar', guardando: _guardando,
          onGuardar: _guardar, onCancelar: widget.onCancelar),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LIQUIDACIÓN DE SALIDA
// ══════════════════════════════════════════════════════════════

class FormSalida extends StatefulWidget {
  final Trabajador persona;
  final List<DocumentoTrabajador> documentos;
  final Color acento;
  final Future<Liquidacion> Function(Map<String, dynamic> datos) calcular;
  final Future<String?> Function(Map<String, dynamic> datos) onGuardar;
  final VoidCallback onCancelar;
  final DateTime? hoy;

  const FormSalida({super.key, required this.persona, required this.documentos,
      required this.acento, required this.calcular, required this.onGuardar,
      required this.onCancelar, this.hoy});

  @override
  State<FormSalida> createState() => _FormSalidaState();
}

class _FormSalidaState extends State<FormSalida> {
  late DateTime _retiro = widget.hoy ?? DateTime.now();
  String? _motivo;
  final _pendientes = TextEditingController();
  late final _vacaciones = TextEditingController(
      text: widget.persona.vacacionesTomadas > 0 ? diasTexto(widget.persona.vacacionesTomadas) : '');
  final _otros = TextEditingController();
  final _empleador = TextEditingController();
  late final Set<int> _anexos = {
    for (final d in widget.documentos) if (d.tipo == 'renuncia') d.id,
  };
  Liquidacion? _calc;
  bool _calculando = false, _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_pendientes, _vacaciones, _otros, _empleador]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _datos() => {
        'fecha_retiro': fechaIso(_retiro),
        'motivo': _motivo,
        if (_pendientes.text.trim().isNotEmpty)
          'dias_pendientes': leerNumero(_pendientes.text, decimales: true),
        if (_vacaciones.text.trim().isNotEmpty)
          'vacaciones_tomadas': leerNumero(_vacaciones.text, decimales: true),
        'otros_descuentos': leerNumero(_otros.text) ?? 0,
        if (_empleador.text.trim().isNotEmpty) 'empleador': _empleador.text.trim(),
        'anexos': _anexos.toList(),
      };

  Future<void> _calcular() async {
    if (_motivo == null) {
      setState(() => _error = 'Elige el motivo de la salida.');
      return;
    }
    setState(() {
      _calculando = true;
      _error = null;
    });
    try {
      final r = await widget.calcular(_datos());
      if (!mounted) return;
      setState(() {
        _calc = r;
        _calculando = false;
        if (_pendientes.text.isEmpty) _pendientes.text = diasTexto(r.n('dias_pendientes'));
        if (_empleador.text.isEmpty) _empleador.text = r.empleador;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculando = false;
        _calc = null;
        _error = '$e';
      });
    }
  }

  Future<void> _guardar() async {
    if (_calc == null) return _calcular();
    setState(() {
      _guardando = true;
      _error = null;
    });
    final err = await widget.onGuardar(_datos());
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _error = err;
    });
  }

  void _cambio(VoidCallback f) => setState(() {
        f();
        _calc = null;
      });

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    final p = widget.persona;
    final c = _calc;
    Widget fila(String k, String dias, int v, {bool neg = false, bool b = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(k, style: gf(size: 12.5, w: b ? FontWeight.w800 : FontWeight.w500))),
            if (dias.isNotEmpty) Text(dias, style: gf(size: 11.5, color: grisN)),
            const SizedBox(width: 12),
            SizedBox(width: 96, child: Text('${neg ? '− ' : ''}${pesosNomina(v)}',
                textAlign: TextAlign.right,
                style: gf(size: 12.5, w: b ? FontWeight.w800 : FontWeight.w700,
                    color: neg ? rojoN : tintaN))),
          ]),
        );
    return MarcoForm(
      titulo: 'Liquidación de salida',
      subtitulo: '${p.nombres} · ${contratos[p.tipoContrato] ?? ''} · '
          'desde ${fechaCorta(p.fechaIngreso)}',
      hijos: [
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: campoFecha('Fecha de retiro', _retiro, a, () async {
            final f = await elegirFechaN(context, _retiro,
                primera: p.fechaIngreso, ayuda: 'Último día de trabajo');
            if (f != null) _cambio(() => _retiro = f);
          })),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _pendientes,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _cambio(() {}),
              decoration: decoN('Días sin pagar', a, ayuda: 'Se calcula solo'),
              style: gf(size: 13.5, w: FontWeight.w700))),
        ]),
        seccionN('Motivo', a),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in motivosSalida.entries)
            chipN(e.value, _motivo == e.key, a, () => _cambio(() => _motivo = e.key)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _vacaciones,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _cambio(() {}),
              decoration: decoN('Vacaciones ya tomadas', a, ayuda: 'Días hábiles'),
              style: gf(size: 13.5))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _otros, keyboardType: TextInputType.number,
              onChanged: (_) => _cambio(() {}),
              decoration: decoN('Otros descuentos', a, prefijo: r'$ ', ayuda: 'Con autorización escrita'),
              style: gf(size: 13.5))),
        ]),
        if (widget.documentos.isNotEmpty) ...[
          seccionN('Adjuntar al PDF (de su carpeta)', a),
          for (final d in widget.documentos)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: a,
              value: _anexos.contains(d.id),
              onChanged: (x) => setState(() => x == true ? _anexos.add(d.id) : _anexos.remove(d.id)),
              title: Text('${d.tipoTexto}${d.detalle.isEmpty ? '' : ' · ${d.detalle}'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: gf(size: 12.5, w: FontWeight.w600)),
              subtitle: Text(fechaCorta(d.fecha), style: gf(size: 11, color: grisN)),
            ),
        ],
        if (c != null) ...[
          seccionN('Cálculo', a),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(children: [
              if (c.v('sueldo') > 0) fila('Sueldo pendiente', '${diasTexto(c.n('dias_pendientes'))} d', c.v('sueldo')),
              if (c.v('auxilio') > 0) fila('Auxilio de transporte', '', c.v('auxilio')),
              fila('Cesantías', '${c.v('dias_cesantias')} d', c.v('cesantias')),
              fila('Intereses de cesantías', '', c.v('intereses')),
              fila('Prima', '${c.v('dias_prima')} d', c.v('prima')),
              fila('Vacaciones no tomadas', '${diasTexto(c.n('vacaciones_dias'))} d háb.', c.v('vacaciones')),
              if (c.v('indemnizacion') > 0)
                fila('Indemnización', '${diasTexto(c.n('indemnizacion_dias'))} d', c.v('indemnizacion')),
              fila('Salud y pensión', '', c.v('salud') + c.v('pension'), neg: true),
              if (c.v('otros_descuentos') > 0) fila('Otros descuentos', '', c.v('otros_descuentos'), neg: true),
              const Divider(height: 14),
              fila('Neto', '', c.neto, b: true),
              fila('A pagar (al mil)', '', c.pagar, b: true),
            ]),
          ),
          const SizedBox(height: 10),
          TextField(controller: _empleador, textCapitalization: TextCapitalization.words,
              decoration: decoN('Quién firma como empleador', a), style: gf(size: 13.5)),
          avisoN('Págala a más tardar el ${fechaCorta(_retiro)}: por cada día de retraso la ley '
              'obliga a pagar un día de sueldo (${pesosNomina(c.v('mora_diaria'))}). '
              'Pendientes: retiro en la PILA, examen médico de egreso y certificado laboral.',
              error: false),
        ],
        if (_error != null) avisoN(_error!),
      ],
      pie: botonesN(acento: a, texto: c == null ? 'Calcular' : 'Guardar liquidación',
          guardando: _guardando || _calculando, onGuardar: _guardar,
          onCancelar: widget.onCancelar),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DOCUMENTO (subir) Y MEMORANDO (crear)
// ══════════════════════════════════════════════════════════════

/// Fotos o PDF elegidos: (nombre, bytes).
typedef Archivos = List<(String, Uint8List)>;

Future<Archivos> elegirArchivos() async {
  final r = await FilePicker.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    withData: true,
  );
  if (r == null) return [];
  return [
    for (final f in r.files)
      if (f.bytes != null) (f.name, f.bytes!),
  ];
}

Future<Archivos> tomarFoto() async {
  final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70,
      maxWidth: 2000);
  if (x == null) return [];
  return [(x.name.isEmpty ? 'foto.jpg' : x.name, await x.readAsBytes())];
}

bool get hayCamara =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class FormDocumento extends StatefulWidget {
  final String persona;
  final Color acento;
  /// Para subir la foto firmada de un documento que ya existe (memorando).
  final DocumentoTrabajador? existente;
  final Future<String?> Function(Map<String, dynamic> datos, Archivos archivos) onGuardar;
  final VoidCallback onCancelar;
  final Future<Archivos> Function() elegir;
  final Future<Archivos> Function() foto;

  const FormDocumento({super.key, required this.persona, required this.acento,
      required this.onGuardar, required this.onCancelar, this.existente,
      this.elegir = elegirArchivos, this.foto = tomarFoto});

  @override
  State<FormDocumento> createState() => _FormDocumentoState();
}

class _FormDocumentoState extends State<FormDocumento> {
  late String? _tipo = widget.existente?.tipo;
  late DateTime _fecha = widget.existente?.fecha ?? DateTime.now();
  late final _detalle = TextEditingController(text: widget.existente?.detalle ?? '');
  late String _firma = widget.existente == null ? 'firmado' : 'firmado';
  late final _testigo1 = TextEditingController();
  late final _testigo2 = TextEditingController();
  final Archivos _archivos = [];
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_detalle, _testigo1, _testigo2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _agregar(Future<Archivos> Function() f) async {
    try {
      final l = await f();
      if (!mounted || l.isEmpty) return;
      final grandes = l.where((x) => x.$2.length > 8 * 1024 * 1024).map((x) => x.$1).toList();
      setState(() {
        _archivos.addAll(l.where((x) => x.$2.length <= 8 * 1024 * 1024));
        _error = grandes.isEmpty ? null : '${grandes.join(', ')} pesa más de 8 MB.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo abrir el archivo o la cámara.');
    }
  }

  Future<void> _guardar() async {
    String? p;
    if (_tipo == null) {
      p = 'Elige el tipo de documento.';
    } else if (_archivos.isEmpty) {
      p = 'Sube la foto o el PDF del documento.';
    } else if (_firma == 'negado' &&
        (_testigo1.text.trim().isEmpty || _testigo2.text.trim().isEmpty)) {
      p = 'Si se negó a firmar, escribe los nombres de los dos testigos.';
    }
    if (p != null) {
      setState(() => _error = p);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final err = await widget.onGuardar({
      if (widget.existente == null) ...{
        'tipo': _tipo,
        'fecha': fechaIso(_fecha),
        'detalle': _detalle.text.trim(),
      },
      'firma': _firma,
      if (_firma == 'negado') 'testigos': '${_testigo1.text.trim()}, ${_testigo2.text.trim()}',
    }, List.of(_archivos));
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    final ex = widget.existente;
    return MarcoForm(
      titulo: ex == null ? 'Subir documento' : 'Subir ${ex.tipoTexto.toLowerCase()} firmado',
      subtitulo: widget.persona,
      hijos: [
        if (ex == null) ...[
          seccionN('Tipo', a),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in tiposDocumento.entries)
              chipN(e.value, _tipo == e.key, a, () => setState(() => _tipo = e.key)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: campoFecha('Fecha del documento', _fecha, a, () async {
              final f = await elegirFechaN(context, _fecha, ultima: DateTime.now(), ayuda: 'Fecha del documento');
              if (f != null) setState(() => _fecha = f);
            })),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _detalle, textCapitalization: TextCapitalization.sentences,
              decoration: decoN('Detalle (ej. Falta sin aviso el 4 de noviembre)', a),
              style: gf(size: 13.5)),
        ],
        seccionN('Firma', a),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in firmasDocumento.entries.where((e) => e.key != 'pendiente'))
            chipN(e.value, _firma == e.key, a, () => setState(() => _firma = e.key)),
        ]),
        if (_firma == 'negado') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _testigo1, textCapitalization: TextCapitalization.words,
                decoration: decoN('Testigo 1', a), style: gf(size: 13.5))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _testigo2, textCapitalization: TextCapitalization.words,
                decoration: decoN('Testigo 2', a), style: gf(size: 13.5))),
          ]),
        ],
        seccionN('Archivo', a),
        Row(children: [
          if (hayCamara) ...[
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _agregar(widget.foto),
              icon: Icon(Icons.photo_camera_outlined, color: a, size: 18),
              label: Text('Tomar foto', style: gf(size: 13, w: FontWeight.w800, color: a)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46),
                  side: BorderSide(color: a.withValues(alpha: .5), width: 1.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(width: 8),
          ],
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _agregar(widget.elegir),
            icon: Icon(Icons.attach_file_rounded, color: a, size: 18),
            label: Text('Elegir archivo', style: gf(size: 13, w: FontWeight.w800, color: a)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46),
                side: BorderSide(color: a.withValues(alpha: .5), width: 1.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ]),
        const SizedBox(height: 6),
        if (_archivos.isEmpty)
          Text('Foto (JPG o PNG) o PDF, hasta 8 MB. Si tiene varias hojas, sube una foto por hoja.',
              style: gf(size: 11.5, color: grisN))
        else
          for (final (i, f) in _archivos.indexed)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(children: [
                Icon(f.$1.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined, size: 18, color: grisN),
                const SizedBox(width: 8),
                Expanded(child: Text(f.$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: gf(size: 12.5, w: FontWeight.w600))),
                Text('${(f.$2.length / 1024).ceil()} KB', style: gf(size: 11, color: grisN)),
                IconButton(
                  tooltip: 'Quitar',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _archivos.removeAt(i)),
                  icon: const Icon(Icons.close_rounded, size: 18, color: grisN),
                ),
              ]),
            ),
        if (_error != null) avisoN(_error!),
      ],
      pie: botonesN(acento: a, texto: 'Guardar en su carpeta', guardando: _guardando,
          onGuardar: _guardar, onCancelar: widget.onCancelar),
    );
  }
}

class FormMemorando extends StatefulWidget {
  final String persona;
  final Color acento;
  final Future<String?> Function(Map<String, dynamic> datos) onGuardar;
  final VoidCallback onCancelar;
  const FormMemorando({super.key, required this.persona, required this.acento,
      required this.onGuardar, required this.onCancelar});

  @override
  State<FormMemorando> createState() => _FormMemorandoState();
}

class _FormMemorandoState extends State<FormMemorando> {
  DateTime _fecha = DateTime.now();
  String? _motivo;
  final _otro = TextEditingController();
  final _hechos = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _otro.dispose();
    _hechos.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final motivo = _motivo == 'Otro' ? _otro.text.trim() : _motivo;
    String? p;
    if (motivo == null || motivo.isEmpty) {
      p = 'Elige o escribe el motivo.';
    } else if (_hechos.text.trim().length < 10) {
      p = 'Cuenta qué pasó: fechas, horas y lo que hizo.';
    }
    if (p != null) {
      setState(() => _error = p);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final err = await widget.onGuardar({
      'tipo': 'memorando',
      'fecha': fechaIso(_fecha),
      'motivo': motivo,
      'detalle': motivo,
      'hechos': _hechos.text.trim(),
      'firma': 'pendiente',
    });
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    return MarcoForm(
      titulo: 'Nuevo memorando',
      subtitulo: '${widget.persona} · sale el PDF para imprimir y firmar',
      hijos: [
        const SizedBox(height: 6),
        campoFecha('Fecha', _fecha, a, () async {
          final f = await elegirFechaN(context, _fecha, ultima: DateTime.now(), ayuda: 'Fecha del memorando');
          if (f != null) setState(() => _fecha = f);
        }),
        seccionN('Motivo', a),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in motivosMemorando)
            chipN(m, _motivo == m, a, () => setState(() => _motivo = m)),
        ]),
        if (_motivo == 'Otro') ...[
          const SizedBox(height: 10),
          TextField(controller: _otro, textCapitalization: TextCapitalization.sentences,
              decoration: decoN('¿Cuál?', a), style: gf(size: 13.5)),
        ],
        seccionN('Qué pasó', a),
        TextField(
          controller: _hechos,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: decoN('Ej. Los días 7, 9 y 10 de octubre llegó a las 9:25, 9:40 y 9:20; la entrada es a las 9:00 a. m.', a),
          style: gf(size: 13.5, h: 1.4),
        ),
        avisoN('Después de imprimirlo y firmarlo, súbele la foto desde su carpeta. Si se niega a firmar, '
            'firman dos testigos.', error: false),
        if (_error != null) avisoN(_error!),
      ],
      pie: botonesN(acento: a, texto: 'Crear y sacar PDF', guardando: _guardando,
          onGuardar: _guardar, onCancelar: widget.onCancelar),
    );
  }
}
