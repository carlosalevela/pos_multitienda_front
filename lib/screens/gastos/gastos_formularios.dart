// lib/screens/gastos/gastos_formularios.dart
//
// Formularios de "Registrar gasto" y "Pago de nómina". Los mismos en el
// computador (diálogo) y en el celular (hoja); cambia el color de acento.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../models/cuenta_bancaria.dart';
import '../../services/gastos_service.dart';
import '../inventario/widgets/inventario_movil.dart'
    show InventarioMovil, leerPrecioFiltro;

class TiendaOpcion {
  final int    id;
  final String nombre;
  const TiendaOpcion(this.id, this.nombre);
}

class EmpleadoOpcion {
  final int    id;
  final String nombre;
  final String detalle; // "Cajera · Boutique 27"
  final int?   tiendaId;
  const EmpleadoOpcion(this.id, this.nombre, {this.detalle = '', this.tiendaId});
}

// ── Estilo ────────────────────────────────────────────────────

const _tinta  = Color(0xFF0F172A);
const _gris   = Color(0xFF64748B);
const _borde  = Color(0xFFDCF0E4);
const _rojo   = Color(0xFFB91C1C);
const _rojo50 = Color(0xFFFEF2F2);

TextStyle gf({double size = 13, FontWeight w = FontWeight.w400,
    Color color = _tinta, double? h, double? ls}) {
  final f = InventarioMovil.fuenteDePrueba;
  if (f != null) {
    return TextStyle(fontFamily: f, fontSize: size, fontWeight: w,
        color: color, height: h, letterSpacing: ls);
  }
  return GoogleFonts.inter(fontSize: size, fontWeight: w, color: color,
      height: h, letterSpacing: ls);
}

String pesos(double v) {
  final s = v.round().abs().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return '${v < 0 ? '−' : ''}${Constants.moneda}$s';
}

const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago',
                'sep', 'oct', 'nov', 'dic'];

String fechaCorta(DateTime f, DateTime hoy) {
  final d = DateTime(f.year, f.month, f.day);
  final h = DateTime(hoy.year, hoy.month, hoy.day);
  final dif = h.difference(d).inDays;
  if (dif == 0) return 'Hoy';
  if (dif == 1) return 'Ayer';
  return '${f.day} ${_meses[f.month]}${f.year == hoy.year ? '' : ' ${f.year}'}';
}

// ── Piezas comunes ────────────────────────────────────────────

Widget _seccion(String t, Color acento) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(t.toUpperCase(),
          style: gf(size: 10.5, w: FontWeight.w800, color: acento, ls: 0.9)),
    );

Widget _chip(String texto, bool sel, Color acento, VoidCallback onTap) =>
    Material(
      color: sel ? acento : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? acento : _borde, width: 1.3),
          ),
          child: Text(texto,
              style: gf(size: 12, w: FontWeight.w700,
                  color: sel ? Colors.white : const Color(0xFF334155))),
        ),
      ),
    );

InputDecoration _deco(String etiqueta, Color acento,
        {String? prefijo, bool error = false}) =>
    InputDecoration(
      labelText: etiqueta,
      labelStyle: gf(size: 12, color: _gris),
      prefixText: prefijo,
      prefixStyle: gf(size: 13.5, w: FontWeight.w700),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error ? _rojo : _borde, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error ? _rojo : acento, width: 1.6),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

Widget _aviso(String t) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: _rojo50,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded, size: 16, color: _rojo),
        const SizedBox(width: 7),
        Expanded(
          child: Text(t,
              style: gf(size: 12, w: FontWeight.w600, color: _rojo, h: 1.3)),
        ),
      ]),
    );

Widget _botones({
  required Color acento,
  required String texto,
  required bool guardando,
  required VoidCallback? onGuardar,
  required VoidCallback onCancelar,
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Cancelar',
                maxLines: 1,
                style: gf(size: 14, w: FontWeight.w700,
                    color: const Color(0xFF334155))),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: guardando
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Text(texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gf(size: 14, w: FontWeight.w800,
                        color: Colors.white)),
          ),
        ),
      ),
    ]);

/// Tienda + fecha + forma de pago + cuenta: común a gasto y nómina.
mixin _PagoMixin<T extends StatefulWidget> on State<T> {
  late int?     tienda;
  late DateTime fecha;
  String        metodo = 'efectivo';
  int?          cuenta;
  List<CuentaBancaria> cuentas = const [];
  bool          cargandoCuentas = false;

  DateTime get hoy;
  Future<List<CuentaBancaria>> Function(int) get cargarCuentas;

  bool get necesitaCuenta => metodo != 'efectivo' && cuentas.isNotEmpty;

  Future<void> alCambiarTienda(int? t) async {
    setState(() {
      tienda = t;
      cuenta = null;
      cuentas = const [];
    });
    if (t == null) return;
    setState(() => cargandoCuentas = true);
    final l = await cargarCuentas(t);
    if (!mounted || tienda != t) return;
    setState(() {
      cuentas = l.where((c) => c.activo).toList();
      cargandoCuentas = false;
      if (cuentas.length == 1) cuenta = cuentas.first.id;
    });
  }

  Future<void> elegirFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: fecha,
      firstDate: DateTime(hoy.year - 1, hoy.month, hoy.day),
      lastDate: hoy,
      helpText: 'Fecha del gasto',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (f != null && mounted) setState(() => fecha = f);
  }

  Widget filasPago(List<TiendaOpcion> tiendas, Color acento) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: tienda,
              isExpanded: true,
              decoration: _deco('Tienda', acento),
              style: gf(size: 13.5, w: FontWeight.w700),
              items: [
                for (final t in tiendas)
                  DropdownMenuItem(
                      value: t.id,
                      child: Text(t.nombre,
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: alCambiarTienda,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: elegirFecha,
              child: InputDecorator(
                decoration: _deco('Fecha', acento),
                child: Row(children: [
                  Expanded(
                    child: Text(fechaCorta(fecha, hoy),
                        style: gf(size: 13.5, w: FontWeight.w700)),
                  ),
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: _gris),
                ]),
              ),
            ),
          ),
        ]),
        _seccion('Forma de pago', acento),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in metodosPagoGasto.entries)
            _chip(e.value, metodo == e.key, acento, () {
              setState(() => metodo = e.key);
            }),
        ]),
        if (metodo != 'efectivo') ...[
          const SizedBox(height: 10),
          if (cargandoCuentas)
            Text('Cargando cuentas…', style: gf(size: 12, color: _gris))
          else if (cuentas.isEmpty)
            Text('Esta tienda no tiene cuentas registradas.',
                style: gf(size: 12, color: _gris))
          else
            DropdownButtonFormField<int>(
              initialValue: cuenta,
              isExpanded: true,
              decoration: _deco('Cuenta', acento),
              style: gf(size: 13.5, w: FontWeight.w700),
              items: [
                for (final c in cuentas)
                  DropdownMenuItem(
                      value: c.id,
                      child: Text(
                          c.numero.isEmpty ? c.nombre : '${c.nombre} · ${c.numero}',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => cuenta = v),
            ),
        ],
      ]);

  Map<String, dynamic> datosPago() => {
        'tienda':      tienda,
        'fecha':       '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
        'metodo_pago': metodo,
        if (metodo != 'efectivo' && cuenta != null) 'cuenta_bancaria': cuenta,
      };
}

// ══════════════════════════════════════════════════════════════
// REGISTRAR GASTO
// ══════════════════════════════════════════════════════════════

class FormGasto extends StatefulWidget {
  final List<TiendaOpcion> tiendas;
  final int?   tiendaInicial;
  final Color  acento;
  final Future<List<CuentaBancaria>> Function(int tienda) cargarCuentas;
  final Future<bool> Function(int tienda) cajaAbierta;
  /// null si se guardó; si no, el mensaje a mostrar.
  final Future<String?> Function(Map<String, dynamic> datos) onGuardar;
  final VoidCallback onCancelar;
  final DateTime? hoy;

  const FormGasto({
    super.key,
    required this.tiendas,
    required this.cargarCuentas,
    required this.cajaAbierta,
    required this.onGuardar,
    required this.onCancelar,
    this.tiendaInicial,
    this.acento = const Color(0xFF059669),
    this.hoy,
  });

  @override
  State<FormGasto> createState() => _FormGastoState();
}

class _FormGastoState extends State<FormGasto> with _PagoMixin<FormGasto> {
  String? _categoria;
  final _detalle = TextEditingController();
  final _monto   = TextEditingController();
  bool  _deCaja  = false;
  final _cajas   = <int, bool>{};
  bool  _guardando = false;
  bool  _intento   = false;
  String? _errorServidor;

  @override
  DateTime get hoy => widget.hoy ?? DateTime.now();
  @override
  Future<List<CuentaBancaria>> Function(int) get cargarCuentas =>
      widget.cargarCuentas;

  @override
  void initState() {
    super.initState();
    fecha = DateTime(hoy.year, hoy.month, hoy.day);
    tienda = widget.tiendaInicial ??
        (widget.tiendas.length == 1 ? widget.tiendas.first.id : null);
    if (tienda != null) {
      alCambiarTienda(tienda);
      _revisarCaja(tienda!);
    }
  }

  @override
  Future<void> alCambiarTienda(int? t) async {
    _deCaja = false;
    if (t != null) _revisarCaja(t);
    return super.alCambiarTienda(t);
  }

  Future<void> _revisarCaja(int t) async {
    if (_cajas.containsKey(t)) return;
    final abierta = await widget.cajaAbierta(t);
    if (mounted) setState(() => _cajas[t] = abierta);
  }

  @override
  void dispose() {
    _detalle.dispose();
    _monto.dispose();
    super.dispose();
  }

  bool get _esHoy =>
      fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;

  /// "¿Salió del cajón?" solo tiene sentido en efectivo, hoy y con la caja
  /// de esa tienda abierta.
  bool get _puedeDeCaja =>
      metodo == 'efectivo' && _esHoy && tienda != null && _cajas[tienda] == true;

  double? get _valor => leerPrecioFiltro(_monto.text);

  String? get _problema {
    if (tienda == null) return 'Elige la tienda.';
    return problemaGasto(
      categoria: _categoria,
      monto: _valor,
      necesitaCuenta: necesitaCuenta,
      hayCuenta: cuenta != null,
    );
  }

  Future<void> _guardar() async {
    setState(() => _intento = true);
    if (_problema != null) return;
    setState(() {
      _guardando = true;
      _errorServidor = null;
    });
    final err = await widget.onGuardar({
      ...datosPago(),
      'categoria':   _categoria,
      'descripcion': _detalle.text.trim(),
      'monto':       _valor!.toStringAsFixed(2),
      'tipo_gasto':  const {'Arriendo', 'Servicios'}.contains(_categoria)
          ? 'fijo' : 'variable',
      if (_puedeDeCaja && _deCaja) 'de_caja': true,
    });
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _errorServidor = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    final problema = _problema;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              18, 0, 18, 8 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Registrar gasto', style: gf(size: 17, w: FontWeight.w800)),
            _seccion('Categoría', a),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in categoriasGasto)
                _chip(c, _categoria == c, a,
                    () => setState(() => _categoria = c)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _detalle,
              style: gf(size: 13.5),
              decoration: _deco('Detalle (ej: recibo de luz octubre)', a),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _monto,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              style: gf(size: 15, w: FontWeight.w800),
              decoration: _deco('Monto', a,
                  prefijo: '${Constants.moneda} ',
                  error: _intento && (_valor == null || _valor!.isNaN || _valor! <= 0)),
            ),
            const SizedBox(height: 10),
            filasPago(widget.tiendas, a),
            if (_puedeDeCaja) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(children: [
                  Switch(
                    value: _deCaja,
                    activeThumbColor: Colors.white,
                    activeTrackColor: a,
                    onChanged: (v) => setState(() => _deCaja = v),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Salió del cajón de la caja de hoy. ',
                          style: gf(size: 12, w: FontWeight.w800,
                              color: const Color(0xFF9A3412))),
                      TextSpan(text: 'Se descuenta del efectivo del cierre.',
                          style: gf(size: 12,
                              color: const Color(0xFF9A3412))),
                    ])),
                  ),
                ]),
              ),
            ],
            if (_intento && problema != null) _aviso(problema),
            if (_errorServidor != null) _aviso(_errorServidor!),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: _botones(
          acento: a,
          texto: 'Guardar gasto',
          guardando: _guardando,
          onGuardar: _guardar,
          onCancelar: widget.onCancelar,
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// PAGO DE NÓMINA
// ══════════════════════════════════════════════════════════════

class FormNomina extends StatefulWidget {
  final List<TiendaOpcion>   tiendas;
  final List<EmpleadoOpcion> empleados;
  final int?   tiendaInicial;
  final Color  acento;
  final Future<List<CuentaBancaria>> Function(int tienda) cargarCuentas;
  final Future<String?> Function(Map<String, dynamic> datos) onGuardar;
  final VoidCallback onCancelar;
  final DateTime? hoy;

  const FormNomina({
    super.key,
    required this.tiendas,
    required this.empleados,
    required this.cargarCuentas,
    required this.onGuardar,
    required this.onCancelar,
    this.tiendaInicial,
    this.acento = const Color(0xFF059669),
    this.hoy,
  });

  @override
  State<FormNomina> createState() => _FormNominaState();
}

class _FormNominaState extends State<FormNomina> with _PagoMixin<FormNomina> {
  /// id del empleado, o -1 para "otra persona".
  int?   _empleado;
  final _otraPersona = TextEditingController();
  late String _periodo;
  final _periodoOtro = TextEditingController();
  final _salario     = TextEditingController();
  final _extras      = TextEditingController();
  final _descuentos  = TextEditingController();
  bool  _guardando   = false;
  bool  _intento     = false;
  String? _errorServidor;

  @override
  DateTime get hoy => widget.hoy ?? DateTime.now();
  @override
  Future<List<CuentaBancaria>> Function(int) get cargarCuentas =>
      widget.cargarCuentas;

  @override
  void initState() {
    super.initState();
    fecha = DateTime(hoy.year, hoy.month, hoy.day);
    _periodo = quincenaDe(fecha);
    metodo = 'transferencia';
    tienda = widget.tiendaInicial ??
        (widget.tiendas.length == 1 ? widget.tiendas.first.id : null);
    if (tienda != null) alCambiarTienda(tienda);
  }

  @override
  void dispose() {
    for (final c in [_otraPersona, _periodoOtro, _salario, _extras, _descuentos]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => leerPrecioFiltro(c.text);

  void _elegirEmpleado(int? id) {
    setState(() => _empleado = id);
    // La tienda del empleado, si se sabe.
    final e = widget.empleados.where((x) => x.id == id).firstOrNull;
    if (e?.tiendaId != null &&
        e!.tiendaId != tienda &&
        widget.tiendas.any((t) => t.id == e.tiendaId)) {
      alCambiarTienda(e.tiendaId);
    }
  }

  bool get _hayBeneficiario =>
      (_empleado != null && _empleado != -1) ||
      (_empleado == -1 && _otraPersona.text.trim().isNotEmpty);

  String? get _problema {
    if (tienda == null) return 'Elige la tienda.';
    final p = problemaNomina(
      hayBeneficiario: _hayBeneficiario,
      salario: _num(_salario),
      extras: _num(_extras),
      descuentos: _num(_descuentos),
    );
    if (p != null) return p;
    if (_periodo == 'otro' && _periodoOtro.text.trim().isEmpty) {
      return 'Escribe el periodo.';
    }
    if (necesitaCuenta && cuenta == null) return 'Elige la cuenta.';
    return null;
  }

  Future<void> _guardar() async {
    setState(() => _intento = true);
    if (_problema != null) return;
    setState(() {
      _guardando = true;
      _errorServidor = null;
    });
    final periodo = periodoNomina(_periodo, fecha, otro: _periodoOtro.text);
    final err = await widget.onGuardar({
      ...datosPago(),
      'categoria':   'Nómina',
      'tipo_gasto':  'fijo',
      if (_empleado != null && _empleado != -1) 'beneficiario': _empleado,
      if (_empleado == -1) 'beneficiario_nombre': _otraPersona.text.trim(),
      'periodo':     periodo,
      'descripcion': periodo,
      'salario':     _num(_salario)!.toStringAsFixed(2),
      'extras':      (_num(_extras) ?? 0).toStringAsFixed(2),
      'descuentos':  (_num(_descuentos) ?? 0).toStringAsFixed(2),
    });
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _errorServidor = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    final salario = _num(_salario), extras = _num(_extras),
        descuentos = _num(_descuentos);
    final validos = [salario, extras, descuentos]
        .every((v) => v == null || !v.isNaN);
    final total = validos ? totalNomina(salario, extras, descuentos) : 0.0;
    final problema = _problema;

    Widget campo(String t, TextEditingController c) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: gf(size: 14, w: FontWeight.w700),
            decoration: _deco(t, a, prefijo: '${Constants.moneda} '),
          ),
        );

    Widget linea(String t, String v, {bool fuerte = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(children: [
            Text(t, style: gf(size: fuerte ? 13.5 : 12.5,
                w: fuerte ? FontWeight.w800 : FontWeight.w500,
                color: fuerte ? const Color(0xFF0F766E) : _tinta)),
            const Spacer(),
            Text(v, style: gf(size: fuerte ? 14.5 : 12.5,
                w: FontWeight.w800,
                color: fuerte ? const Color(0xFF0F766E) : _tinta)),
          ]),
        );

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              18, 0, 18, 8 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pago de nómina', style: gf(size: 17, w: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _empleado,
              isExpanded: true,
              decoration: _deco('Empleado', a,
                  error: _intento && !_hayBeneficiario),
              style: gf(size: 13.5, w: FontWeight.w700),
              items: [
                for (final e in widget.empleados)
                  DropdownMenuItem(
                    value: e.id,
                    child: Text(
                        e.detalle.isEmpty ? e.nombre : '${e.nombre} · ${e.detalle}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                const DropdownMenuItem(value: -1, child: Text('Otra persona')),
              ],
              onChanged: _elegirEmpleado,
            ),
            if (_empleado == -1) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _otraPersona,
                onChanged: (_) => setState(() {}),
                style: gf(size: 13.5),
                decoration: _deco('Nombre de la persona', a),
              ),
            ],
            _seccion('Periodo', a),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (k, t) in const [
                ('q1', '1.ª quincena'),
                ('q2', '2.ª quincena'),
                ('mes', 'Mes completo'),
                ('otro', 'Otro'),
              ])
                _chip(t, _periodo == k, a, () => setState(() => _periodo = k)),
            ]),
            if (_periodo == 'otro') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _periodoOtro,
                onChanged: (_) => setState(() {}),
                style: gf(size: 13.5),
                decoration: _deco('Periodo (ej: prima de junio)', a),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              campo('Salario', _salario),
              const SizedBox(width: 8),
              campo('Extras / bonos', _extras),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              campo('Descuentos / adelantos', _descuentos),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                linea('Salario', pesos(salario != null && !salario.isNaN ? salario : 0)),
                linea('+ Extras', pesos(extras != null && !extras.isNaN ? extras : 0)),
                linea('− Descuentos', pesos(descuentos != null && !descuentos.isNaN ? descuentos : 0)),
                const Divider(height: 10, color: Color(0xFF99F6E4)),
                linea('Total a pagar', pesos(total), fuerte: true),
              ]),
            ),
            const SizedBox(height: 10),
            filasPago(widget.tiendas, a),
            if (_intento && problema != null) _aviso(problema),
            if (_errorServidor != null) _aviso(_errorServidor!),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: _botones(
          acento: a,
          texto: 'Registrar pago',
          guardando: _guardando,
          onGuardar: _guardar,
          onCancelar: widget.onCancelar,
        ),
      ),
    ]);
  }
}
