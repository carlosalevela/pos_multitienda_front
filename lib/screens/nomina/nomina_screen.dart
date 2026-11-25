// lib/screens/nomina/nomina_screen.dart
//
// "Nómina" (admin y superadmin): quincena por tienda (tipo, valor del día y
// días por persona), pagos en partes, planilla y desprendibles en PDF, el mes
// completo con lo que le cuesta a la empresa, y las personas con su carpeta de
// documentos y la liquidación de salida.
//
// Computador: el diseño del sistema (encabezado verde oscuro, tarjetas
// blancas). Celular: paleta verde claro, una tarjeta por persona.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cuenta_bancaria.dart';
import '../../providers/auth_provider.dart';
import '../../services/cuenta_bancaria_service.dart';
import '../../services/empleado_service.dart';
import '../../services/nomina_pdf_service.dart';
import '../../services/nomina_service.dart';
import '../gastos/gastos_formularios.dart' show TiendaOpcion, gf;
import 'nomina_formularios.dart';

// ══════════════════════════════════════════════════════════════
// UNA PERSONA EN LA QUINCENA (lo que se está escribiendo)
// ══════════════════════════════════════════════════════════════

class FilaEditable {
  final FilaQuincena base;
  final bool recibeAuxilio;
  String tipo;
  bool ganaMinimo;
  final TextEditingController valorDia, dias, danos, adelantos, fechas;

  FilaEditable(this.base, {this.recibeAuxilio = true})
      : tipo = base.tipo,
        ganaMinimo = base.ganaMinimo,
        valorDia = TextEditingController(
            text: base.valorDia > 0 && !base.ganaMinimo ? pesosNomina(base.valorDia).substring(1) : ''),
        dias = TextEditingController(text: base.guardada ? diasTexto(base.dias) : ''),
        danos = TextEditingController(text: base.calculo.danos > 0 ? pesosNomina(base.calculo.danos).substring(1) : ''),
        adelantos = TextEditingController(
            text: base.calculo.adelantos > 0 ? pesosNomina(base.calculo.adelantos).substring(1) : ''),
        fechas = TextEditingController(text: base.fechas);

  bool get esNomina => tipo == 'nomina';
  double? get diasNum => dias.text.trim().isEmpty ? 0 : leerNumero(dias.text, decimales: true);
  double? get valorNum => leerNumero(valorDia.text);
  int get danosNum => (leerNumero(danos.text) ?? 0).round();
  int get adelantosNum => (leerNumero(adelantos.text) ?? 0).round();

  CalculoFila calculo(QuincenaNomina q) => calcularFila(
        tipo: tipo, valorDia: valorNum ?? 0, dias: diasNum ?? 0,
        ganaMinimo: esNomina && ganaMinimo, recibeAuxilio: recibeAuxilio,
        salarioMinimo: q.salarioMinimo, auxilioTransporte: q.auxilioTransporte,
        danos: danosNum, adelantos: adelantosNum, redondearMil: q.redondearMil);

  String? problema(QuincenaNomina q) => problemaFila(
      nombre: base.nombres, valorDia: valorNum, dias: diasNum,
      ganaMinimo: esNomina && ganaMinimo, danos: danosNum, adelantos: adelantosNum,
      calculo: calculo(q));

  /// Lo escrito es distinto de lo guardado.
  bool get cambiada {
    final b = base;
    if (!b.guardada) return (diasNum ?? 0) > 0;
    return tipo != b.tipo || (esNomina && ganaMinimo) != b.ganaMinimo ||
        (diasNum ?? -1) != b.dias || danosNum != b.calculo.danos ||
        adelantosNum != b.calculo.adelantos || fechas.text.trim() != b.fechas ||
        (!(esNomina && ganaMinimo) && (valorNum ?? 0).round() != b.valorDia.round());
  }

  Map<String, dynamic> json() => {
        'trabajador': base.trabajador, 'tipo': tipo, 'gana_minimo': esNomina && ganaMinimo,
        'valor_dia': valorNum ?? 0, 'dias': diasNum ?? 0, 'danos': danosNum,
        'adelantos': adelantosNum, 'fechas': fechas.text.trim(),
      };

  void cambiarDias(double delta) {
    final d = ((diasNum ?? 0) + delta).clamp(0, 16).toDouble();
    dias.text = diasTexto(d);
  }

  void dispose() {
    for (final c in [valorDia, dias, danos, adelantos, fechas]) {
      c.dispose();
    }
  }
}

// ══════════════════════════════════════════════════════════════
// PANTALLA (carga y estado)
// ══════════════════════════════════════════════════════════════

class NominaScreen extends StatefulWidget {
  const NominaScreen({super.key});

  @override
  State<NominaScreen> createState() => _NominaScreenState();
}

class _NominaScreenState extends State<NominaScreen> {
  final _api = NominaService();
  final _cuentas = CuentaBancariaService();

  List<TiendaOpcion> _tiendas = const [];
  final Map<int, String> _ciudades = {};
  int? _tienda;
  late int _anio, _mes, _numero;
  String _vista = 'quincena';
  String _estadoPersonas = 'activos';

  QuincenaNomina? _q;
  List<FilaEditable> _filas = [];
  MesNomina? _mesDatos;
  List<Trabajador> _personas = const [];
  bool _cargando = true, _guardando = false;
  String? _error;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    final (a, m, n) = quincenaDeFecha(DateTime.now());
    _anio = a;
    _mes = m;
    _numero = n;
    _iniciar();
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _iniciar() async {
    final t = await EmpleadoService().getTiendas();
    if (!mounted) return;
    setState(() {
      _tiendas = [
        for (final m in t)
          if (m['id'] is int && m['activo'] != false)
            TiendaOpcion(m['id'] as int, '${m['nombre'] ?? 'Tienda'}'),
      ];
      for (final m in t) {
        if (m['id'] is int) _ciudades[m['id'] as int] = '${m['ciudad'] ?? ''}';
      }
      final propia = context.read<AuthProvider>().tiendaId;
      _tienda = _tiendas.any((x) => x.id == propia) ? propia : _tiendas.firstOrNull?.id;
    });
    await _cargar();
  }

  Future<void> _cargar() async {
    final t = _tienda;
    if (t == null) {
      setState(() {
        _cargando = false;
        _error = 'No hay tiendas.';
      });
      return;
    }
    final id = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final personas = await _api.trabajadores(tiendaId: t, estado: 'todos');
      if (_vista == 'mes') {
        final m = await _api.mes(_anio, _mes, tiendaId: t);
        if (!mounted || id != _consulta) return;
        setState(() {
          _personas = personas;
          _mesDatos = m;
          _cargando = false;
        });
        return;
      }
      final q = await _api.quincena(t, _anio, _mes, _numero);
      if (!mounted || id != _consulta) return;
      _ponerQuincena(q, personas);
      setState(() => _cargando = false);
    } catch (e) {
      if (!mounted || id != _consulta) return;
      setState(() {
        _cargando = false;
        _error = '$e';
      });
    }
  }

  void _ponerQuincena(QuincenaNomina q, List<Trabajador> personas) {
    for (final f in _filas) {
      f.dispose();
    }
    final aux = {for (final p in personas) p.id: p.recibeAuxilio};
    setState(() {
      _q = q;
      _personas = personas;
      _filas = [
        for (final f in q.filas) FilaEditable(f, recibeAuxilio: aux[f.trabajador] ?? true),
      ];
    });
  }

  bool get _esMovil => MediaQuery.sizeOf(context).width < 600;
  Color get _acento => _esMovil ? const Color(0xFF059669) : const Color(0xFF006C49);

  void _aviso(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t),
      backgroundColor: error ? const Color(0xFFB91C1C) : const Color(0xFF006C49),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Hoja abajo en el celular, diálogo en el computador.
  Future<void> _abrir(Widget Function(VoidCallback cerrar) hijo, {double ancho = 520}) {
    if (_esMovil) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.94),
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2))),
                Flexible(child: hijo(() => Navigator.pop(ctx))),
              ]),
            ),
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho, maxHeight: MediaQuery.sizeOf(ctx).height * 0.92),
          child: Padding(padding: const EdgeInsets.only(top: 20), child: hijo(() => Navigator.pop(ctx))),
        ),
      ),
    );
  }

  Future<String?> _hacer(Future<void> Function() f, VoidCallback cerrar, String ok) async {
    try {
      await f();
    } catch (e) {
      return '$e';
    }
    cerrar();
    _aviso(ok);
    await _cargar();
    return null;
  }

  // ── Período ───────────────────────────────────────────────

  void _moverQuincena(int delta) {
    var n = _numero + delta, m = _mes, a = _anio;
    if (n == 0) {
      n = 2;
      m--;
    } else if (n == 3) {
      n = 1;
      m++;
    }
    if (m == 0) {
      m = 12;
      a--;
    } else if (m == 13) {
      m = 1;
      a++;
    }
    setState(() {
      _anio = a;
      _mes = m;
      _numero = n;
    });
    _cargar();
  }

  void _moverMes(int delta) {
    final d = DateTime(_anio, _mes + delta);
    setState(() {
      _anio = d.year;
      _mes = d.month;
    });
    _cargar();
  }

  void _verVista(String v) {
    if (v == _vista) return;
    setState(() => _vista = v);
    if (v != 'personas') _cargar();
  }

  void _verNumero(int n) {
    setState(() {
      _numero = n;
      _vista = 'quincena';
    });
    _cargar();
  }

  // ── Quincena ──────────────────────────────────────────────

  Future<void> _guardarQuincena() async {
    final q = _q;
    if (q == null) return;
    for (final f in _filas) {
      final p = f.problema(q);
      if (p != null) {
        _aviso(p, error: true);
        return;
      }
    }
    setState(() => _guardando = true);
    try {
      final r = await _api.guardarQuincena({
        'tienda_id': q.tienda, 'anio': q.anio, 'mes': q.mes, 'numero': q.numero,
        'empleador': q.empleador,
        'lineas': [for (final f in _filas) if (f.base.guardada || (f.diasNum ?? 0) > 0) f.json()],
      });
      final personas = await _api.trabajadores(tiendaId: q.tienda, estado: 'todos');
      _ponerQuincena(r, personas);
      _aviso('Quincena guardada');
    } catch (e) {
      _aviso('$e', error: true);
    }
    if (mounted) setState(() => _guardando = false);
  }

  Future<void> _empleador() async {
    final q = _q;
    if (q == null) return;
    final c = TextEditingController(text: q.empleador);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quién firma como empleador', style: gf(size: 16, w: FontWeight.w800)),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words,
            decoration: decoN('Nombre', _acento)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: _acento), child: const Text('Listo')),
        ],
      ),
    );
    c.dispose();
    if (r == null || !mounted) return;
    setState(() => _q = QuincenaNomina(
          id: q.id, tienda: q.tienda, anio: q.anio, mes: q.mes, numero: q.numero,
          salarioMinimo: q.salarioMinimo, auxilioTransporte: q.auxilioTransporte,
          tiendaNombre: q.tiendaNombre, ciudad: q.ciudad, periodo: q.periodo, empleador: r,
          redondearMil: q.redondearMil, valoresGuardados: q.valoresGuardados, filas: q.filas));
    if (q.id != null) await _guardarQuincena();
  }

  Future<List<CuentaBancaria>> _cargarCuentas(int t) => _cuentas.listar(t);

  void _pagar(FilaQuincena f) => _abrir((cerrar) => FormPagoNomina(
        persona: f.nombres,
        concepto: '${_numero == 1 ? '1.ª' : '2.ª'} quincena',
        falta: f.falta,
        tienda: _tienda!,
        acento: _acento,
        cargarCuentas: _cargarCuentas,
        onCancelar: cerrar,
        onGuardar: (d) => _hacer(() => _api.pagarLinea(f.id!, d), cerrar, 'Pago registrado'),
      ));

  Future<void> _verPagos(FilaQuincena f) => _abrir((cerrar) => _ListaPagos(
        titulo: f.nombres,
        pagos: f.pagos,
        acento: _acento,
        onCerrar: cerrar,
        onBorrar: (p) => _hacer(() => _api.borrarPago(p.id), cerrar, 'Pago borrado'),
      ));

  Future<void> _pdf(Future<Uint8List> Function() f, String nombre) async {
    try {
      await NominaPdf.abrir(await f(), nombre);
    } catch (e) {
      _aviso('No se pudo generar el PDF.', error: true);
    }
  }

  String get _sufijo => '${_numero}Q_${meses[_mes]}_$_anio';

  void _planilla() {
    final q = _q;
    if (q == null || q.guardadas.isEmpty) return _aviso('Primero guarda la quincena.', error: true);
    _pdf(() => NominaPdf.planilla(q), 'Planilla_${q.tiendaNombre}_$_sufijo.pdf');
  }

  void _desprendibles([FilaQuincena? solo]) {
    final q = _q;
    if (q == null || q.guardadas.isEmpty) return _aviso('Primero guarda la quincena.', error: true);
    final filas = solo == null ? q.guardadas : [solo];
    _pdf(() => NominaPdf.desprendibles(q, filas),
        solo == null ? 'Desprendibles_$_sufijo.pdf' : 'Desprendible_${solo.nombres}_$_sufijo.pdf');
  }

  void _planillaMes() {
    final m = _mesDatos;
    if (m == null || m.personas.isEmpty) return _aviso('No hay quincenas guardadas en este mes.', error: true);
    final tienda = _tiendas.where((t) => t.id == _tienda).firstOrNull?.nombre ?? '';
    _pdf(() => NominaPdf.planillaMes(m, tienda), 'Nomina_${tienda}_${meses[_mes]}_$_anio.pdf');
  }

  Future<void> _valores() async {
    try {
      final v = await _api.valores(_anio, tiendaId: _tienda);
      if (!mounted) return;
      await _abrir((cerrar) => FormValores(
            valores: v, acento: _acento, onCancelar: cerrar,
            onGuardar: (d) => _hacer(() => _api.guardarValores({...d, 'tienda_id': _tienda}), cerrar,
                'Valores de $_anio guardados'),
          ));
    } catch (e) {
      _aviso('$e', error: true);
    }
  }

  // ── Personas ──────────────────────────────────────────────

  void _nuevaPersona([Trabajador? p]) => _abrir((cerrar) => FormPersona(
        tiendas: _tiendas,
        tiendaInicial: _tienda,
        persona: p,
        salarioMinimo: _q?.salarioMinimo ?? _mesDatos?.valores.salarioMinimo ?? 1750905,
        acento: _acento,
        onCancelar: cerrar,
        onGuardar: (d) => _hacer(() => _api.guardarTrabajador(d, id: p?.id), cerrar,
            p == null ? 'Persona agregada' : 'Cambios guardados'),
      ), ancho: 560);

  Future<void> _verPersona(Trabajador p) => _abrir((cerrar) => PersonaDetalle(
        persona: p,
        api: _api,
        acento: _acento,
        tiendaNombre: _tiendas.where((t) => t.id == p.tienda).firstOrNull?.nombre ?? p.tiendaNombre,
        ciudad: _ciudades[p.tienda] ?? '',
        empleador: _q?.empleador ?? '',
        abrir: _abrir,
        cargarCuentas: _cargarCuentas,
        onEditar: () {
          cerrar();
          _nuevaPersona(p);
        },
        onCambio: _cargar,
        onCerrar: cerrar,
      ), ancho: 640);

  // ── Armar ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rol = context.read<AuthProvider>().rol;
    if (rol != 'admin' && rol != 'superadmin') {
      return const Center(child: Text('Solo el administrador ve esta sección.'));
    }
    final datos = DatosNomina(
      tiendas: _tiendas, tienda: _tienda, anio: _anio, mes: _mes, numero: _numero,
      vista: _vista, quincena: _q, filas: _filas, mesDatos: _mesDatos,
      personas: _personas, estadoPersonas: _estadoPersonas, cargando: _cargando,
      guardando: _guardando, error: _error,
    );
    final acciones = AccionesNomina(
      onTienda: (t) {
        setState(() => _tienda = t);
        _cargar();
      },
      onVista: _verVista,
      onNumero: _verNumero,
      onMoverQuincena: _moverQuincena,
      onMoverMes: _moverMes,
      onCambio: () => setState(() {}),
      onGuardar: _guardarQuincena,
      onEmpleador: _empleador,
      onPagar: _pagar,
      onVerPagos: _verPagos,
      onDesprendible: _desprendibles,
      onPlanilla: _planilla,
      onDesprendibles: () => _desprendibles(),
      onPlanillaMes: _planillaMes,
      onValores: _valores,
      onNuevaPersona: () => _nuevaPersona(),
      onPersona: _verPersona,
      onEstadoPersonas: (e) => setState(() => _estadoPersonas = e),
      onRefrescar: _cargar,
    );
    return _esMovil
        ? NominaMovil(datos: datos, acciones: acciones)
        : NominaEscritorio(datos: datos, acciones: acciones);
  }
}

// ── Lo que reciben las vistas (se pueden probar solas) ─────────

class DatosNomina {
  final List<TiendaOpcion> tiendas;
  final int? tienda;
  final int anio, mes, numero;
  final String vista, estadoPersonas;
  final QuincenaNomina? quincena;
  final List<FilaEditable> filas;
  final MesNomina? mesDatos;
  final List<Trabajador> personas;
  final bool cargando, guardando;
  final String? error;

  const DatosNomina({
    required this.tiendas, required this.anio, required this.mes, required this.numero,
    this.tienda, this.vista = 'quincena', this.estadoPersonas = 'activos', this.quincena,
    this.filas = const [], this.mesDatos, this.personas = const [], this.cargando = false,
    this.guardando = false, this.error,
  });

  String get nombreTienda =>
      tiendas.where((t) => t.id == tienda).firstOrNull?.nombre ?? 'Tienda';
  String get periodo => periodoQuincena(anio, mes, numero);
  String get tituloMes => '${meses[mes][0].toUpperCase()}${meses[mes].substring(1)} $anio';

  List<FilaEditable> get conDias =>
      filas.where((f) => f.base.guardada || (f.diasNum ?? 0) > 0).toList();
  bool get hayCambios => filas.any((f) => f.cambiada);
  int get totalPagar {
    final q = quincena;
    if (q == null) return 0;
    return conDias.fold(0, (s, f) => s + f.calculo(q).pagar);
  }

  int get totalPagado => quincena?.totalPagado ?? 0;
  List<Trabajador> get personasVisibles =>
      personas.where((p) => estadoPersonas == 'activos' ? p.activo : !p.activo).toList();
}

class AccionesNomina {
  final ValueChanged<int?> onTienda;
  final ValueChanged<String> onVista;
  final ValueChanged<int> onNumero;
  final ValueChanged<int> onMoverQuincena;
  final ValueChanged<int> onMoverMes;
  final VoidCallback onCambio;
  final VoidCallback onGuardar;
  final VoidCallback onEmpleador;
  final ValueChanged<FilaQuincena> onPagar;
  final ValueChanged<FilaQuincena> onVerPagos;
  final ValueChanged<FilaQuincena> onDesprendible;
  final VoidCallback onPlanilla;
  final VoidCallback onDesprendibles;
  final VoidCallback onPlanillaMes;
  final VoidCallback onValores;
  final VoidCallback onNuevaPersona;
  final ValueChanged<Trabajador> onPersona;
  final ValueChanged<String> onEstadoPersonas;
  final Future<void> Function() onRefrescar;

  const AccionesNomina({
    required this.onTienda, required this.onVista, required this.onNumero,
    required this.onMoverQuincena, required this.onMoverMes, required this.onCambio,
    required this.onGuardar, required this.onEmpleador, required this.onPagar,
    required this.onVerPagos, required this.onDesprendible, required this.onPlanilla,
    required this.onDesprendibles, required this.onPlanillaMes, required this.onValores,
    required this.onNuevaPersona, required this.onPersona, required this.onEstadoPersonas,
    required this.onRefrescar,
  });
}

/// "Pagado", "Falta $X" o "Sin pagar".
(String, Color, Color) estadoPago(FilaQuincena f) {
  if (!f.guardada) return ('Sin guardar', const Color(0xFF64748B), const Color(0xFFF1F5F9));
  if (f.falta <= 0) return ('Pagado', const Color(0xFF15803D), const Color(0xFFDCFCE7));
  if (f.pagado == 0) return ('Sin pagar', const Color(0xFFB45309), const Color(0xFFFEF3C7));
  return ('Falta ${pesosNomina(f.falta)}', const Color(0xFFB45309), const Color(0xFFFEF3C7));
}

Widget _etiqueta((String, Color, Color) e) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: e.$3, borderRadius: BorderRadius.circular(6)),
      child: Text(e.$1, style: gf(size: 10.5, w: FontWeight.w800, color: e.$2)),
    );

Widget _tipoChip(String tipo) => tipo == 'nomina'
    ? _etiqueta(('NÓMINA', const Color(0xFF15803D), const Color(0xFFDCFCE7)))
    : _etiqueta(('TEMPORAL', const Color(0xFFB45309), const Color(0xFFFEF3C7)));

TextField _campo(TextEditingController c, VoidCallback onCambio,
        {String? hint, bool decimal = false, bool enabled = true,
        Color borde = const Color(0xFFD1D5DB), TextAlign align = TextAlign.right}) =>
    TextField(
      controller: c,
      enabled: enabled,
      onChanged: (_) => onCambio(),
      textAlign: align,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: gf(size: 13, w: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: gf(size: 12, color: const Color(0xFF9CA3AF)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borde, width: 1.3)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF006C49), width: 1.6)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

// ══════════════════════════════════════════════════════════════
// COMPUTADOR
// ══════════════════════════════════════════════════════════════

class _D {
  static const bg = Color(0xFFF5F7F8);
  static const border = Color(0xFFE5E7EB);
  static const second = Color(0xFF6B7280);
  static const green = Color(0xFF61DDAA);
  static const greenDark = Color(0xFF006C49);
  static const rose = Color(0xFFBE123C);
}

class NominaEscritorio extends StatelessWidget {
  final DatosNomina datos;
  final AccionesNomina acciones;
  const NominaEscritorio({super.key, required this.datos, required this.acciones});

  @override
  Widget build(BuildContext context) => Container(
        color: _D.bg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _hero(),
            const SizedBox(height: 20),
            if (datos.error != null)
              avisoN(datos.error!)
            else if (datos.cargando && datos.vista != 'personas')
              const Padding(padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: _D.greenDark)))
            else
              switch (datos.vista) {
                'mes' => _VistaMes(datos: datos, acciones: acciones, movil: false),
                'personas' => _VistaPersonas(datos: datos, acciones: acciones, movil: false),
                _ => _tablaQuincena(context),
              },
          ]),
        ),
      );

  Widget _hero() {
    final q = datos.vista == 'quincena';
    final textoPeriodo = datos.vista == 'personas'
        ? 'Personas de ${datos.nombreTienda}'
        : q ? '${datos.periodo[0].toUpperCase()}${datos.periodo.substring(1)}' : datos.tituloMes;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(color: _D.greenDark, borderRadius: BorderRadius.circular(16)),
      child: Stack(children: [
        Positioned(right: -20, top: -24,
            child: Icon(Icons.badge_rounded, size: 140, color: Colors.white.withValues(alpha: .05))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _D.green, borderRadius: BorderRadius.circular(4)),
              child: Text('NÓMINA', style: gf(size: 9, w: FontWeight.w700, color: Colors.white, ls: 1.2)),
            ),
            _segmento(),
            if (datos.vista != 'personas') _flechas(),
            if (datos.tiendas.length > 1) _selectorTienda(),
          ]),
          const SizedBox(height: 12),
          Text(textoPeriodo, style: gf(size: 22, w: FontWeight.w800, color: Colors.white, h: 1.2)),
          const SizedBox(height: 6),
          Text(_resumen(), style: gf(size: 12.5, h: 1.5, color: Colors.white.withValues(alpha: .72))),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (q) ...[
              _boton(datos.guardando ? 'Guardando…' : 'Guardar quincena', Icons.save_rounded,
                  datos.guardando ? null : acciones.onGuardar, claro: true),
              _boton('Planilla PDF', Icons.table_chart_outlined, acciones.onPlanilla),
              _boton('Desprendibles PDF', Icons.picture_as_pdf_outlined, acciones.onDesprendibles),
              _boton('Empleador: ${datos.quincena?.empleador.isNotEmpty == true ? datos.quincena!.empleador : 'sin nombre'}',
                  Icons.draw_outlined, acciones.onEmpleador),
            ],
            if (datos.vista == 'mes')
              _boton('Planilla del mes PDF', Icons.picture_as_pdf_outlined, acciones.onPlanillaMes, claro: true),
            _boton('Nueva persona', Icons.person_add_alt_1_outlined, acciones.onNuevaPersona,
                claro: datos.vista == 'personas'),
            _boton('Valores del año', Icons.tune_rounded, acciones.onValores),
          ]),
        ]),
      ]),
    );
  }

  String _resumen() {
    if (datos.cargando) return 'Cargando…';
    if (datos.vista == 'personas') {
      final a = datos.personas.where((p) => p.activo).length;
      return '$a persona${a == 1 ? '' : 's'} activa${a == 1 ? '' : 's'}. Toca una para ver sus datos, '
          'documentos y liquidación de salida.';
    }
    if (datos.vista == 'mes') {
      final m = datos.mesDatos;
      if (m == null || m.personas.isEmpty) return 'Todavía no hay quincenas guardadas en este mes.';
      return 'Pagado ${pesosNomina(m.t('pagar'))} a ${m.personas.length} persona'
          '${m.personas.length == 1 ? '' : 's'}; costo total para la empresa ${pesosNomina(m.t('costo'))}.';
    }
    final q = datos.quincena;
    if (q == null) return '';
    if (!q.valoresGuardados) {
      return 'Con el mínimo de ${pesosNomina(q.salarioMinimo)} y auxilio de ${pesosNomina(q.auxilioTransporte)}: '
          'confírmalos en "Valores del año".';
    }
    final n = datos.conDias.length;
    final base = 'Por cada persona: tipo, valor del día y días. ';
    if (q.id == null) return '${base}Escribe los días y guarda la quincena.';
    return '$base$n persona${n == 1 ? '' : 's'} · a pagar ${pesosNomina(datos.totalPagar)} · '
        'pagado ${pesosNomina(datos.totalPagado)}${datos.hayCambios ? ' · hay cambios sin guardar' : ''}.';
  }

  Widget _segmento() {
    Widget s(String t, bool on, VoidCallback f) => InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8)),
            child: Text(t, style: gf(size: 12, w: FontWeight.w700,
                color: on ? _D.greenDark : Colors.white)),
          ),
        );
    final q = datos.vista == 'quincena';
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        s('1.ª quincena', q && datos.numero == 1, () => acciones.onNumero(1)),
        s('2.ª quincena', q && datos.numero == 2, () => acciones.onNumero(2)),
        s('Mes completo', datos.vista == 'mes', () => acciones.onVista('mes')),
        s('Personas', datos.vista == 'personas', () => acciones.onVista('personas')),
      ]),
    );
  }

  Widget _flechas() {
    final q = datos.vista == 'quincena';
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(visualDensity: VisualDensity.compact,
            tooltip: q ? 'Quincena anterior' : 'Mes anterior',
            onPressed: () => q ? acciones.onMoverQuincena(-1) : acciones.onMoverMes(-1),
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 18)),
        Text(q ? '${datos.numero == 1 ? '1.ª' : '2.ª'} ${meses[datos.mes].substring(0, 3)} ${datos.anio}'
               : datos.tituloMes,
            style: gf(size: 12, w: FontWeight.w700, color: Colors.white)),
        IconButton(visualDensity: VisualDensity.compact,
            tooltip: q ? 'Quincena siguiente' : 'Mes siguiente',
            onPressed: () => q ? acciones.onMoverQuincena(1) : acciones.onMoverMes(1),
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18)),
      ]),
    );
  }

  Widget _selectorTienda() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: datos.tienda,
            dropdownColor: _D.greenDark,
            iconEnabledColor: Colors.white,
            style: gf(size: 12, w: FontWeight.w700, color: Colors.white),
            items: [
              for (final t in datos.tiendas)
                DropdownMenuItem(value: t.id, child: Text(t.nombre)),
            ],
            onChanged: acciones.onTienda,
          ),
        ),
      );

  Widget _boton(String t, IconData i, VoidCallback? f, {bool claro = false}) => Material(
        color: claro ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: claro ? null : Border.all(color: Colors.white.withValues(alpha: .35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, size: 16, color: claro ? _D.greenDark : Colors.white),
              const SizedBox(width: 7),
              Text(t, style: gf(size: 12.5, w: FontWeight.w800,
                  color: claro ? _D.greenDark : Colors.white)),
            ]),
          ),
        ),
      );

  // ── Tabla de la quincena ──────────────────────────────────
  //
  // Columnas: persona, tipo, valor del día, días, sueldo, + auxilio,
  // − salud y pensión, − robos/daños, − adelantos, pagar (con el estado del
  // pago debajo) y el menú de acciones. Cabe en 1366 px con el menú lateral;
  // si sobra espacio las columnas se estiran, si falta se desliza.

  static const _base = [150.0, 100.0, 96.0, 52.0, 82.0, 76.0, 80.0, 76.0, 76.0, 116.0, 32.0];
  static const _gap = 6.0;
  static const _pad = 14.0;

  static double _fijo() => _base.length * _gap + _pad * 2;

  Widget _tablaQuincena(BuildContext context) {
    final q = datos.quincena;
    if (q == null) return const SizedBox();
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _D.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Row(children: [
            Text('Liquidación', style: gf(size: 14.5, w: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('${datos.filas.length} personas', style: gf(size: 11.5, color: _D.second)),
            const SizedBox(width: 12),
            Expanded(child: Text('El valor del día queda guardado para la próxima quincena',
                textAlign: TextAlign.right, overflow: TextOverflow.ellipsis,
                style: gf(size: 11.5, color: _D.second))),
          ]),
        ),
        if (datos.filas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(children: [
              Text('Todavía no hay personas en esta tienda.', style: gf(size: 13, color: _D.second)),
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: acciones.onNuevaPersona,
                  style: FilledButton.styleFrom(backgroundColor: _D.greenDark),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Agregar persona')),
            ]),
          )
        else
          LayoutBuilder(builder: (_, c) {
            final suma = _base.reduce((a, b) => a + b);
            final escala = ((c.maxWidth - _fijo()) / suma).clamp(1.0, 1.6);
            final w = [for (final x in _base) x * escala];
            final total = suma * escala + _fijo();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: total,
                child: Column(children: [
                  _cabecera(w),
                  for (final f in datos.filas) _filaTabla(f, q, w),
                  _totales(q, w),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  List<Widget> _sep(List<Widget> l) => [
        for (var i = 0; i < l.length; i++) ...[if (i > 0) const SizedBox(width: _gap), l[i]],
      ];

  Widget _cabecera(List<double> w) {
    Widget cab(String t, int i, {bool der = true}) => SizedBox(
        width: w[i],
        child: Text(t.toUpperCase(), textAlign: der ? TextAlign.right : TextAlign.left,
            style: gf(size: 9.5, w: FontWeight.w700, color: _D.second, ls: .5)));
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 10),
      child: Row(children: _sep([
        cab('Persona', 0, der: false), cab('Tipo', 1, der: false), cab('Valor día', 2), cab('Días', 3),
        cab('Sueldo', 4), cab('+ Auxilio', 5), cab('− Salud y pens.', 6), cab('− Robos/daños', 7),
        cab('− Adelantos', 8), cab('Pagar', 9), SizedBox(width: w[10]),
      ])),
    );
  }

  Widget _filaTabla(FilaEditable f, QuincenaNomina q, List<double> w) {
    final c = f.calculo(q);
    final b = f.base;
    final minimo = f.esNomina && f.ganaMinimo;
    String m(int v) => v == 0 ? '—' : pesosNomina(v);
    const gris = Color(0xFF9CA3AF);
    Widget num(String t, int i, {Color? color}) => SizedBox(
        width: w[i],
        child: Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Text(t, textAlign: TextAlign.right,
              style: gf(size: 12.5, color: color ?? const Color(0xFF111827))),
        ));
    final problema = f.problema(q);
    final v = f.valorNum;
    final guardadaSinCambios = b.guardada && !f.cambiada;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 8),
      decoration: BoxDecoration(
        color: f.cambiada ? const Color(0xFFFFFBEB) : null,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: _sep([
        SizedBox(width: w[0], child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.nombres, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: gf(size: 13, w: FontWeight.w800)),
          Text([if (b.cargo.isNotEmpty) b.cargo, if (b.cedula.isNotEmpty) 'C.C. ${b.cedula}'].join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: gf(size: 11, color: _D.second)),
          if (problema != null && f.cambiada)
            Text(problema.replaceFirst('${b.nombres}: ', ''),
                style: gf(size: 10.5, w: FontWeight.w700, color: _D.rose)),
        ])),
        SizedBox(width: w[1], child: _selectorTipo(f)),
        SizedBox(width: w[2], child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          minimo
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0))),
                  child: Text(pesosNomina(q.salarioMinimo / 30).substring(1), textAlign: TextAlign.right,
                      style: gf(size: 13, w: FontWeight.w700)),
                )
              : _campo(f.valorDia, acciones.onCambio, hint: '0'),
          InkWell(
            onTap: f.esNomina ? () {
              f.ganaMinimo = !f.ganaMinimo;
              acciones.onCambio();
            } : null,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                  minimo ? 'Mínimo · quitar'
                      : f.esNomina
                          ? (v != null && v > 0 ? '= ${pesosNomina(v * 30)}/mes' : 'Usar el mínimo')
                          : 'por día',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: gf(size: 10, w: FontWeight.w700,
                      color: f.esNomina ? const Color(0xFF059669) : _D.second)),
            ),
          ),
        ])),
        SizedBox(width: w[3], child: _campo(f.dias, acciones.onCambio, hint: '0', decimal: true,
            borde: _D.greenDark, align: TextAlign.center)),
        num(m(c.sueldo), 4),
        num(f.esNomina ? m(c.auxilio) : '—', 5, color: f.esNomina ? null : gris),
        num(f.esNomina ? m(c.salud + c.pension) : '—', 6, color: f.esNomina ? _D.rose : gris),
        SizedBox(width: w[7], child: _campo(f.danos, acciones.onCambio, hint: '0')),
        SizedBox(width: w[8], child: _campo(f.adelantos, acciones.onCambio, hint: '0')),
        SizedBox(width: w[9], child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(m(c.pagar), style: gf(size: 14, w: FontWeight.w800)),
            if (c.pagar != c.neto && c.neto > 0)
              Text('neto ${pesosNomina(c.neto)}', style: gf(size: 10, color: _D.second)),
            const SizedBox(height: 3),
            if (guardadaSinCambios)
              InkWell(onTap: b.pagos.isEmpty ? null : () => acciones.onVerPagos(b),
                  child: _etiqueta(estadoPago(b)))
            else if (f.cambiada)
              Text('Guarda para pagar',
                  style: gf(size: 10.5, w: FontWeight.w700, color: const Color(0xFFB45309))),
          ]),
        )),
        SizedBox(width: w[10], child: guardadaSinCambios
            ? PopupMenuButton<String>(
                tooltip: 'Acciones',
                icon: const Icon(Icons.more_vert_rounded, color: _D.second, size: 20),
                onSelected: (x) => switch (x) {
                  'pagar' => acciones.onPagar(b),
                  'pagos' => acciones.onVerPagos(b),
                  _ => acciones.onDesprendible(b),
                },
                itemBuilder: (_) => [
                  if (b.falta > 0) const PopupMenuItem(value: 'pagar', child: Text('Registrar pago')),
                  if (b.pagos.isNotEmpty) const PopupMenuItem(value: 'pagos', child: Text('Ver pagos')),
                  const PopupMenuItem(value: 'pdf', child: Text('Desprendible PDF')),
                ],
              )
            : null),
      ])),
    );
  }

  Widget _selectorTipo(FilaEditable f) {
    Widget o(String t, String k) {
      final on = f.tipo == k;
      final nom = k == 'nomina';
      return Expanded(
        child: InkWell(
          onTap: () {
            f.tipo = k;
            acciones.onCambio();
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: on ? (nom ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7)) : Colors.white,
            child: Text(t, style: gf(size: 9.5, w: FontWeight.w800,
                color: on ? (nom ? const Color(0xFF15803D) : const Color(0xFFB45309))
                    : const Color(0xFF9CA3AF))),
          ),
        ),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _D.border)),
      child: Row(children: [o('NÓMINA', 'nomina'), o('TEMP.', 'temporal')]),
    );
  }

  Widget _totales(QuincenaNomina q, List<double> w) {
    final l = datos.conDias.map((f) => f.calculo(q)).toList();
    int s(int Function(CalculoFila) g) => l.fold(0, (a, c) => a + g(c));
    Widget t(String v, int i) => SizedBox(width: w[i],
        child: Text(v, textAlign: TextAlign.right, style: gf(size: 12.5, w: FontWeight.w800)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 11),
      decoration: const BoxDecoration(color: Color(0xFFF0FDF4),
          border: Border(top: BorderSide(color: _D.greenDark, width: 2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: _sep([
        SizedBox(width: w[0], child: Text('Total quincena', style: gf(size: 12.5, w: FontWeight.w800))),
        SizedBox(width: w[1]), SizedBox(width: w[2]), SizedBox(width: w[3]),
        t(pesosNomina(s((c) => c.sueldo)), 4), t(pesosNomina(s((c) => c.auxilio)), 5),
        t(pesosNomina(s((c) => c.salud + c.pension)), 6), t(pesosNomina(s((c) => c.danos)), 7),
        t(pesosNomina(s((c) => c.adelantos)), 8),
        SizedBox(width: w[9], child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(pesosNomina(s((c) => c.pagar)), style: gf(size: 13.5, w: FontWeight.w900)),
          Text('pagado ${pesosNomina(datos.totalPagado)}', style: gf(size: 10.5, color: _D.second)),
        ])),
        SizedBox(width: w[10]),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CELULAR
// ══════════════════════════════════════════════════════════════

class _M {
  static const fondo = Color(0xFFF0FDF4);
  static const borde = Color(0xFFA7F3D0);
  static const verde = Color(0xFF059669);
  static const verdeOs = Color(0xFF047857);
  static const gris = Color(0xFF6B7280);
}

class NominaMovil extends StatelessWidget {
  final DatosNomina datos;
  final AccionesNomina acciones;
  const NominaMovil({super.key, required this.datos, required this.acciones});

  @override
  Widget build(BuildContext context) {
    final q = datos.vista == 'quincena';
    return Container(
      color: _M.fondo,
      child: Column(children: [
        Expanded(
          child: RefreshIndicator(
            color: _M.verde,
            onRefresh: acciones.onRefrescar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
              children: [
                _encabezado(),
                const SizedBox(height: 10),
                _pestanas(),
                const SizedBox(height: 10),
                if (datos.error != null)
                  avisoN(datos.error!)
                else if (datos.cargando && datos.vista != 'personas')
                  const Padding(padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: _M.verde)))
                else
                  switch (datos.vista) {
                    'mes' => _VistaMes(datos: datos, acciones: acciones, movil: true),
                    'personas' => _VistaPersonas(datos: datos, acciones: acciones, movil: true),
                    _ => _quincena(),
                  },
              ],
            ),
          ),
        ),
        if (q && !datos.cargando && datos.quincena != null && datos.filas.isNotEmpty) _pie(),
      ]),
    );
  }

  Widget _encabezado() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nómina', style: gf(size: 20, w: FontWeight.w800, color: const Color(0xFF064E3B))),
            Text(datos.vista == 'mes' ? datos.tituloMes
                : datos.vista == 'personas' ? datos.nombreTienda
                : '${datos.periodo} · ${datos.nombreTienda}',
                style: gf(size: 11.5, color: _M.gris)),
          ]),
        ),
        if (datos.vista != 'personas')
          Row(children: [
            _redondo(Icons.chevron_left_rounded, () =>
                datos.vista == 'mes' ? acciones.onMoverMes(-1) : acciones.onMoverQuincena(-1)),
            const SizedBox(width: 6),
            _redondo(Icons.chevron_right_rounded, () =>
                datos.vista == 'mes' ? acciones.onMoverMes(1) : acciones.onMoverQuincena(1)),
          ]),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          tooltip: 'Más',
          icon: const Icon(Icons.more_vert_rounded, color: _M.verdeOs),
          onSelected: (v) => switch (v) {
            'planilla' => acciones.onPlanilla(),
            'desprendibles' => acciones.onDesprendibles(),
            'mes' => acciones.onPlanillaMes(),
            'empleador' => acciones.onEmpleador(),
            'persona' => acciones.onNuevaPersona(),
            'valores' => acciones.onValores(),
            _ => null,
          },
          itemBuilder: (_) => [
            if (datos.vista == 'quincena') ...[
              const PopupMenuItem(value: 'planilla', child: Text('Planilla PDF')),
              const PopupMenuItem(value: 'desprendibles', child: Text('Desprendibles PDF')),
              const PopupMenuItem(value: 'empleador', child: Text('Quién firma como empleador')),
            ],
            if (datos.vista == 'mes')
              const PopupMenuItem(value: 'mes', child: Text('Planilla del mes PDF')),
            const PopupMenuItem(value: 'persona', child: Text('Nueva persona')),
            const PopupMenuItem(value: 'valores', child: Text('Valores del año')),
          ],
        ),
      ]);

  Widget _redondo(IconData i, VoidCallback f) => Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: _M.borde)),
        child: InkWell(customBorder: const CircleBorder(), onTap: f,
            child: Padding(padding: const EdgeInsets.all(6), child: Icon(i, size: 20, color: _M.verdeOs))),
      );

  Widget _pestanas() {
    Widget p(String t, bool on, VoidCallback f) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: on ? _M.verde : Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: f,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: on ? _M.verde : const Color(0xFFDCF0E4), width: 1.3)),
                  child: Text(t, maxLines: 1, style: gf(size: 11.5, w: FontWeight.w800,
                      color: on ? Colors.white : const Color(0xFF334155))),
                ),
              ),
            ),
          ),
        );
    final q = datos.vista == 'quincena';
    return Column(children: [
      Row(children: [
        p('1.ª quinc.', q && datos.numero == 1, () => acciones.onNumero(1)),
        p('2.ª quinc.', q && datos.numero == 2, () => acciones.onNumero(2)),
        p('Mes', datos.vista == 'mes', () => acciones.onVista('mes')),
        p('Personas', datos.vista == 'personas', () => acciones.onVista('personas')),
      ]),
      if (datos.tiendas.length > 1) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _M.borde)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: datos.tienda,
              isExpanded: true,
              style: gf(size: 13, w: FontWeight.w700),
              items: [for (final t in datos.tiendas) DropdownMenuItem(value: t.id, child: Text(t.nombre))],
              onChanged: acciones.onTienda,
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _quincena() {
    final q = datos.quincena;
    if (q == null) return const SizedBox();
    if (datos.filas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text('Todavía no hay personas en esta tienda.', textAlign: TextAlign.center,
              style: gf(size: 13, color: _M.gris)),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: acciones.onNuevaPersona,
              style: FilledButton.styleFrom(backgroundColor: _M.verde),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Agregar persona')),
        ]),
      );
    }
    return Column(children: [
      if (!q.valoresGuardados)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(onTap: acciones.onValores, child: avisoN(
              'Mínimo ${pesosNomina(q.salarioMinimo)} y auxilio ${pesosNomina(q.auxilioTransporte)}: '
              'toca para confirmarlos.', error: false)),
        ),
      for (final f in datos.filas) _tarjeta(f, q),
    ]);
  }

  Widget _tarjeta(FilaEditable f, QuincenaNomina q) {
    final c = f.calculo(q);
    final b = f.base;
    final minimo = f.esNomina && f.ganaMinimo;
    final problema = f.problema(q);
    final v = f.valorNum;
    Widget linea(String a, String bb, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: gf(size: 11.5, color: const Color(0xFF334155)))),
            Text(bb, style: gf(size: 11.5, w: FontWeight.w700, color: color ?? const Color(0xFF334155))),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: f.cambiada ? const Color(0xFFFFFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: f.cambiada ? const Color(0xFFFCD34D) : _M.borde, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(b.nombres, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: gf(size: 13.5, w: FontWeight.w800)),
        if (b.cargo.isNotEmpty)
          Text(b.cargo, maxLines: 1, overflow: TextOverflow.ellipsis, style: gf(size: 11, color: _M.gris)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Tipo', style: gf(size: 12, color: const Color(0xFF334155)))),
          chipN('Nómina', f.esNomina, _M.verde, () {
            f.tipo = 'nomina';
            acciones.onCambio();
          }),
          const SizedBox(width: 4),
          chipN('Temporal', !f.esNomina, const Color(0xFFF59E0B), () {
            f.tipo = 'temporal';
            acciones.onCambio();
          }),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('Valor del día', style: gf(size: 12, color: const Color(0xFF334155)))),
          SizedBox(
            width: 120,
            child: minimo
                ? Text(pesosNomina(q.salarioMinimo / 30), textAlign: TextAlign.right,
                    style: gf(size: 13, w: FontWeight.w800))
                : _campo(f.valorDia, acciones.onCambio, hint: '0', borde: _M.borde),
          ),
        ]),
        if (f.esNomina)
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                f.ganaMinimo = !f.ganaMinimo;
                acciones.onCambio();
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(minimo ? 'Mínimo · ${pesosNomina(q.salarioMinimo)}/mes · quitar'
                    : v != null && v > 0 ? '= ${pesosNomina(v * 30)}/mes · usar el mínimo' : 'Usar el mínimo',
                    style: gf(size: 10.5, w: FontWeight.w700, color: _M.verde)),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('Días', style: gf(size: 12, color: const Color(0xFF334155)))),
          _paso(Icons.remove_rounded, () {
            f.cambiarDias(-.5);
            acciones.onCambio();
          }),
          const SizedBox(width: 6),
          SizedBox(width: 56, child: _campo(f.dias, acciones.onCambio, hint: '0', decimal: true,
              borde: _M.borde, align: TextAlign.center)),
          const SizedBox(width: 6),
          _paso(Icons.add_rounded, () {
            f.cambiarDias(.5);
            acciones.onCambio();
          }),
        ]),
        Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            initiallyExpanded: f.danosNum > 0 || f.adelantosNum > 0,
            title: Text(f.danosNum + f.adelantosNum > 0
                ? 'Descuentos: ${pesosNomina(f.danosNum + f.adelantosNum)}'
                : 'Robos, daños o adelantos',
                style: gf(size: 11.5, w: FontWeight.w700, color: _M.verdeOs)),
            children: [
              Row(children: [
                Expanded(child: _campo(f.danos, acciones.onCambio, hint: 'Robos/daños',
                    borde: _M.borde, align: TextAlign.left)),
                const SizedBox(width: 6),
                Expanded(child: _campo(f.adelantos, acciones.onCambio, hint: 'Adelantos',
                    borde: _M.borde, align: TextAlign.left)),
              ]),
              const SizedBox(height: 4),
            ],
          ),
        ),
        if ((f.diasNum ?? 0) > 0) ...[
          linea('Sueldo', pesosNomina(c.sueldo)),
          if (f.esNomina && c.auxilio > 0) linea('+ Auxilio de transporte', pesosNomina(c.auxilio)),
          if (f.esNomina) linea('− Salud y pensión', pesosNomina(c.salud + c.pension), color: const Color(0xFFBE123C)),
          if (c.danos + c.adelantos > 0)
            linea('− Robos, daños, adelantos', pesosNomina(c.danos + c.adelantos), color: const Color(0xFFBE123C)),
        ],
        if (problema != null && f.cambiada)
          Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(problema.replaceFirst('${b.nombres}: ', ''),
                  style: gf(size: 11, w: FontWeight.w700, color: const Color(0xFFBE123C)))),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _M.borde))),
          child: Row(children: [
            Text('Pagar', style: gf(size: 13, w: FontWeight.w900, color: _M.verdeOs)),
            const SizedBox(width: 8),
            if (b.guardada && !f.cambiada) InkWell(
                onTap: b.pagos.isEmpty ? null : () => acciones.onVerPagos(b),
                child: _etiqueta(estadoPago(b))),
            const Spacer(),
            Text(pesosNomina(c.pagar), style: gf(size: 14, w: FontWeight.w900, color: _M.verdeOs)),
          ]),
        ),
        if (b.guardada && !f.cambiada)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              if (b.falta > 0) ...[
                Expanded(child: _accion('Registrar pago', Icons.payments_outlined, () => acciones.onPagar(b))),
                const SizedBox(width: 6),
              ],
              Expanded(child: _accion('Desprendible', Icons.picture_as_pdf_outlined,
                  () => acciones.onDesprendible(b))),
            ]),
          ),
      ]),
    );
  }

  Widget _paso(IconData i, VoidCallback f) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: f,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _M.borde, width: 1.3)),
            child: Icon(i, size: 18, color: _M.verdeOs),
          ),
        ),
      );

  Widget _accion(String t, IconData i, VoidCallback f) => OutlinedButton.icon(
        onPressed: f,
        icon: Icon(i, size: 16, color: _M.verdeOs),
        label: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: gf(size: 12, w: FontWeight.w800, color: _M.verdeOs)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          side: const BorderSide(color: _M.borde, width: 1.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _pie() => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: _M.borde))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: datos.guardando || !datos.hayCambios ? null : acciones.onGuardar,
              style: FilledButton.styleFrom(
                backgroundColor: _M.verde,
                disabledBackgroundColor: const Color(0xFFD1FAE5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                datos.guardando ? 'Guardando…'
                    : datos.hayCambios ? 'Guardar quincena · ${pesosNomina(datos.totalPagar)}'
                    : 'Pagado ${pesosNomina(datos.totalPagado)} de ${pesosNomina(datos.totalPagar)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: gf(size: 13.5, w: FontWeight.w800,
                    color: datos.hayCambios ? Colors.white : _M.verdeOs)),
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// MES COMPLETO (computador y celular)
// ══════════════════════════════════════════════════════════════

class _VistaMes extends StatelessWidget {
  final DatosNomina datos;
  final AccionesNomina acciones;
  final bool movil;
  const _VistaMes({required this.datos, required this.acciones, required this.movil});

  @override
  Widget build(BuildContext context) {
    final m = datos.mesDatos;
    if (m == null) return const SizedBox();
    if (m.personas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Text('Todavía no hay quincenas guardadas en ${datos.tituloMes.toLowerCase()}.',
            textAlign: TextAlign.center, style: gf(size: 13, color: _M.gris)),
      );
    }
    final resumen = _resumen(m);
    if (movil) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _tarjetasMovil(m),
        const SizedBox(height: 10),
        for (final p in m.personas) _personaMovil(p),
        const SizedBox(height: 6),
        resumen,
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: acciones.onPlanillaMes,
          icon: const Icon(Icons.picture_as_pdf_outlined, color: _M.verdeOs, size: 18),
          label: Text('Planilla del mes (PDF)', style: gf(size: 13, w: FontWeight.w800, color: _M.verdeOs)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46),
              side: const BorderSide(color: _M.borde, width: 1.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _tabla(m),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (_, c) {
        final nom = m.personas.where((p) => p.tipo == 'nomina').toList();
        final costoUno = nom.isEmpty ? null : _costoPersona(nom.first, m);
        if (c.maxWidth < 900 || costoUno == null) {
          return Column(children: [?costoUno, if (costoUno != null) const SizedBox(height: 18), resumen]);
        }
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: costoUno),
            const SizedBox(width: 18),
            Expanded(child: resumen),
          ]),
        );
      }),
    ]);
  }

  Widget _tarjeta(Widget hijo) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: movil ? _M.borde : _D.border, width: movil ? 1.5 : 1)),
        child: hijo,
      );

  Widget _kv(String k, int v, {bool b = false, bool mut = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(k, style: gf(size: 12.5, color: mut ? _M.gris : const Color(0xFF111827),
              w: b ? FontWeight.w700 : FontWeight.w400))),
          Text(pesosNomina(v), style: gf(size: 12.5, w: FontWeight.w800,
              color: mut ? _M.gris : const Color(0xFF111827))),
        ]),
      );

  Widget _costo(String k, int v) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA7F3D0))),
        child: Row(children: [
          Expanded(child: Text(k, style: gf(size: 13.5, w: FontWeight.w900, color: const Color(0xFF065F46)))),
          Text(pesosNomina(v), style: gf(size: 14, w: FontWeight.w900, color: const Color(0xFF065F46))),
        ]),
      );

  Widget _resumen(MesNomina m) => _tarjeta(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Resumen del mes · lo que le cuesta a la empresa', style: gf(size: 14, w: FontWeight.w800)),
        const SizedBox(height: 6),
        _kv('Pagado a las personas (al mil)', m.t('pagar'), b: true),
        _kv('Salud y pensión retenidas (se pagan en la PILA)', m.t('salud') + m.t('pension')),
        if (m.t('danos') + m.t('adelantos') > 0)
          _kv('   · Robos, daños y adelantos descontados', m.t('danos') + m.t('adelantos'), mut: true),
        _kv('Aportes del empleador (pensión, ARL, caja)', m.t('aportes')),
        _kv('Provisión de prestaciones (prima, cesantías, intereses, vacaciones)', m.t('provisiones')),
        _costo('Costo total de nómina', m.t('costo')),
        const SizedBox(height: 8),
        Text('En Gastos queda cada pago como gasto de Nómina. Los aportes y las prestaciones se '
            'ven aquí para saber el costo real.', style: gf(size: 11, color: _M.gris, h: 1.35)),
      ]));

  Widget _costoPersona(PersonaMes p, MesNomina m) {
    final c = p.costoDetalle;
    int v(String k) => c[k] ?? 0;
    return _tarjeta(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Lo que le cuesta a la empresa · ${p.nombres}', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: gf(size: 14, w: FontWeight.w800)),
      const SizedBox(height: 6),
      _kv('Pagado (al mil)', p.pagar, b: true),
      _kv('Salud y pensión retenidas (van a la PILA)', p.salud + p.pension),
      _kv('Pensión empleador (12 %)', v('pension')),
      _kv('ARL (${'${m.valores.arlPct}'.replaceAll('.', ',')} %)', v('arl')),
      _kv('Caja de compensación (4 %)', v('caja')),
      if (m.valores.exonerado)
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
          Expanded(child: Text('Salud empleador, ICBF, SENA', style: gf(size: 12.5))),
          Text('Exonerado', style: gf(size: 12.5, w: FontWeight.w700, color: _M.gris)),
        ]))
      else ...[
        _kv('Salud empleador (8,5 %)', v('salud')),
        _kv('ICBF (3 %) y SENA (2 %)', v('icbf') + v('sena')),
      ],
      _kv('Prima (8,33 %)', v('prima')),
      _kv('Cesantías (8,33 %)', v('cesantias')),
      _kv('Intereses de cesantías (1 %)', v('intereses')),
      _kv('Vacaciones (4,17 %)', v('vacaciones')),
      _costo('Costo real del mes', p.costo),
    ]));
  }

  Widget _tabla(MesNomina m) {
    const cols = ['Persona', 'Tipo', 'Días', '1.ª quincena', '2.ª quincena', 'Devengado', 'Deducciones',
                  'Pagado', 'Costo empresa'];
    String q(int? v) => v == null ? '—' : pesosNomina(v);
    TableRow fila(List<String> c, {bool tot = false}) => TableRow(
          decoration: BoxDecoration(color: tot ? const Color(0xFFF0FDF4) : null,
              border: Border(top: BorderSide(color: tot ? _D.greenDark : const Color(0xFFF1F5F9),
                  width: tot ? 2 : 1))),
          children: [
            for (var i = 0; i < c.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(c[i], textAlign: i < 2 ? TextAlign.left : TextAlign.right,
                    style: gf(size: 12.5, w: tot || i == 0 || i == 7 ? FontWeight.w800 : FontWeight.w500,
                        color: i == 6 && !tot ? _D.rose : const Color(0xFF111827))),
              ),
          ],
        );
    return _tarjeta(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('Pagado a las personas', style: gf(size: 14.5, w: FontWeight.w800)),
        const SizedBox(width: 8),
        Text('${m.personas.length} personas · 2 quincenas', style: gf(size: 11.5, color: _D.second)),
      ]),
      const SizedBox(height: 10),
      Table(
        columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1)},
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [
              for (var i = 0; i < cols.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(cols[i].toUpperCase(), textAlign: i < 2 ? TextAlign.left : TextAlign.right,
                      style: gf(size: 9.5, w: FontWeight.w700, color: _D.second, ls: .6)),
                ),
            ],
          ),
          for (final p in m.personas)
            fila([p.nombres, p.tipo == 'nomina' ? 'Nómina' : 'Temporal', diasTexto(p.dias), q(p.q1), q(p.q2),
                  pesosNomina(p.devengado), p.deducido == 0 ? '—' : pesosNomina(p.deducido),
                  pesosNomina(p.pagar), pesosNomina(p.costo)]),
          fila(['Total', '', '', q(m.personas.fold<int>(0, (s, p) => s + (p.q1 ?? 0))),
                q(m.personas.fold<int>(0, (s, p) => s + (p.q2 ?? 0))), pesosNomina(m.t('devengado')),
                pesosNomina(m.t('salud') + m.t('pension') + m.t('danos') + m.t('adelantos')),
                pesosNomina(m.t('pagar')), pesosNomina(m.t('costo'))], tot: true),
        ],
      ),
    ]));
  }

  Widget _tarjetasMovil(MesNomina m) {
    Widget t(String titulo, String valor, String sub, IconData i) => Expanded(
          child: Container(
            height: 96,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _M.borde, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 4, decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)))),
              Expanded(child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Expanded(child: Text(titulo, style: gf(size: 10.5, w: FontWeight.w600, color: _M.verdeOs))),
                    Icon(i, size: 15, color: _M.verde),
                  ]),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                      child: Text(valor, style: gf(size: 18, w: FontWeight.w800, color: const Color(0xFF064E3B)))),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: gf(size: 10.5, color: _M.gris)),
                ]),
              )),
            ]),
          ),
        );
    return Row(children: [
      t('Pagado', pesosNomina(m.t('pagar')), '${m.personas.length} personas', Icons.payments_outlined),
      const SizedBox(width: 8),
      t('Costo empresa', pesosNomina(m.t('costo')), 'con aportes y prestaciones', Icons.business_outlined),
    ]);
  }

  Widget _personaMovil(PersonaMes p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _M.borde, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(p.nombres, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: gf(size: 13.5, w: FontWeight.w800))),
            _tipoChip(p.tipo),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text('1.ª ${p.q1 == null ? '—' : pesosNomina(p.q1!)}  ·  2.ª ${p.q2 == null ? '—' : pesosNomina(p.q2!)}',
                style: gf(size: 11.5, color: _M.gris))),
            Text(pesosNomina(p.pagar), style: gf(size: 13.5, w: FontWeight.w900, color: _M.verdeOs)),
          ]),
          if (p.tipo == 'nomina')
            Text('Le cuesta a la empresa ${pesosNomina(p.costo)}', style: gf(size: 11, color: _M.gris)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// PERSONAS
// ══════════════════════════════════════════════════════════════

class _VistaPersonas extends StatelessWidget {
  final DatosNomina datos;
  final AccionesNomina acciones;
  final bool movil;
  const _VistaPersonas({required this.datos, required this.acciones, required this.movil});

  @override
  Widget build(BuildContext context) {
    final a = movil ? _M.verde : _D.greenDark;
    final l = datos.personasVisibles;
    final retirados = datos.personas.where((p) => !p.activo).length;
    return Container(
      padding: EdgeInsets.all(movil ? 0 : 16),
      decoration: movil ? null : BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _D.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          chipN('Activas', datos.estadoPersonas == 'activos', a, () => acciones.onEstadoPersonas('activos')),
          const SizedBox(width: 6),
          chipN('Retiradas${retirados > 0 ? ' ($retirados)' : ''}', datos.estadoPersonas == 'retirados', a,
              () => acciones.onEstadoPersonas('retirados')),
          const Spacer(),
          if (movil)
            IconButton.filled(
              onPressed: acciones.onNuevaPersona,
              style: IconButton.styleFrom(backgroundColor: a),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              tooltip: 'Nueva persona',
            ),
        ]),
        const SizedBox(height: 10),
        if (l.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(datos.estadoPersonas == 'activos'
                ? 'Todavía no hay personas. Agrégalas con "Nueva persona".'
                : 'Nadie se ha retirado.', textAlign: TextAlign.center, style: gf(size: 13, color: _M.gris)),
          )
        else if (movil)
          for (final p in l) _tarjetaPersona(p, a)
        else
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final p in l) SizedBox(width: 330, child: _tarjetaPersona(p, a)),
          ]),
      ]),
    );
  }

  Widget _tarjetaPersona(Trabajador p, Color a) => Container(
        margin: EdgeInsets.only(bottom: movil ? 8 : 0),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => acciones.onPersona(p),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: movil ? _M.borde : _D.border, width: movil ? 1.5 : 1)),
              child: Row(children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: a.withValues(alpha: .12),
                  child: Text(p.nombres.isEmpty ? '?' : p.nombres[0].toUpperCase(),
                      style: gf(size: 15, w: FontWeight.w800, color: a)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.nombres, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: gf(size: 13.5, w: FontWeight.w800)),
                    Text([
                      if (p.cargo.isNotEmpty) p.cargo,
                      p.ganaMinimo ? 'Mínimo' : '${pesosNomina(p.valorDia)}/día',
                      if (!p.activo) 'Retiro ${fechaCorta(p.fechaRetiro)}'
                      else if (p.fechaIngreso != null) 'Desde ${fechaCorta(p.fechaIngreso)}',
                    ].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: gf(size: 11.5, color: _M.gris)),
                  ]),
                ),
                const SizedBox(width: 6),
                _tipoChip(p.tipo),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
              ]),
            ),
          ),
        ),
      );
}

// ── Detalle de una persona: datos, documentos y salida ─────────

class PersonaDetalle extends StatefulWidget {
  final Trabajador persona;
  final NominaService api;
  final Color acento;
  final String tiendaNombre, ciudad, empleador;
  final Future<void> Function(Widget Function(VoidCallback cerrar) hijo, {double ancho}) abrir;
  final Future<List<CuentaBancaria>> Function(int tienda) cargarCuentas;
  final VoidCallback onEditar;
  final Future<void> Function() onCambio;
  final VoidCallback onCerrar;

  const PersonaDetalle({super.key, required this.persona, required this.api, required this.acento,
      required this.tiendaNombre, required this.ciudad, required this.empleador, required this.abrir,
      required this.cargarCuentas, required this.onEditar, required this.onCambio, required this.onCerrar});

  @override
  State<PersonaDetalle> createState() => _PersonaDetalleState();
}

class _PersonaDetalleState extends State<PersonaDetalle> {
  late Trabajador _p = widget.persona;
  List<DocumentoTrabajador> _docs = const [];
  Liquidacion? _lq;
  bool _cargando = true;
  String? _error;

  NominaService get _api => widget.api;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await Future.wait([
        _api.documentos(_p.id),
        if (!_p.activo) _api.salida(_p.id) else Future.value(null),
      ]);
      if (!mounted) return;
      setState(() {
        _docs = r[0] as List<DocumentoTrabajador>;
        _lq = r[1] as Liquidacion?;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = '$e';
        });
      }
    }
  }

  void _msg(String t, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t), behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFB91C1C) : const Color(0xFF006C49)));

  Future<String?> _hacer(Future<void> Function() f, VoidCallback cerrar, String ok) async {
    try {
      await f();
    } catch (e) {
      return '$e';
    }
    cerrar();
    if (mounted) _msg(ok);
    await _cargar();
    await widget.onCambio();
    return null;
  }

  // Documentos
  void _subir([DocumentoTrabajador? existente]) => widget.abrir((cerrar) => FormDocumento(
        persona: _p.nombres,
        acento: widget.acento,
        existente: existente,
        onCancelar: cerrar,
        onGuardar: (d, archivos) => _hacer(
            () => existente == null
                ? _api.subirDocumento(_p.id, d, archivos)
                : _api.actualizarDocumento(existente.id, d, archivos: archivos),
            cerrar, 'Documento guardado'),
      ));

  void _memorando() => widget.abrir((cerrar) => FormMemorando(
        persona: _p.nombres,
        acento: widget.acento,
        onCancelar: cerrar,
        onGuardar: (d) async {
          try {
            final m = await _api.subirDocumento(_p.id, d, const []);
            cerrar();
            await _cargar();
            await _pdfMemorando(m);
            return null;
          } catch (e) {
            return '$e';
          }
        },
      ));

  Future<void> _pdfMemorando(DocumentoTrabajador m) async {
    try {
      final b = await NominaPdf.memorando(_p, m, tienda: widget.tiendaNombre,
          ciudad: widget.ciudad, empleador: widget.empleador);
      await NominaPdf.abrir(b, 'Memorando_${m.numero}_${_p.nombres}.pdf');
    } catch (_) {
      if (mounted) _msg('No se pudo generar el PDF.', error: true);
    }
  }

  Future<void> _verArchivo(ArchivoDoc a) async {
    try {
      final b = await _api.archivo(a.id);
      if (a.esPdf) {
        await NominaPdf.abrir(b, a.nombre);
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(children: [
            InteractiveViewer(child: Center(child: Image.memory(b))),
            Positioned(right: 4, top: 4, child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white))),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) _msg('$e', error: true);
    }
  }

  Future<void> _borrarDoc(DocumentoTrabajador d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar ${d.tipoTexto.toLowerCase()}?', style: gf(size: 16, w: FontWeight.w800)),
        content: Text('Se borra de la carpeta de ${_p.nombres} con sus archivos.', style: gf(size: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: rojoN), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.borrarDocumento(d.id);
      await _cargar();
    } catch (e) {
      if (mounted) _msg('$e', error: true);
    }
  }

  // Salida
  void _salida() => widget.abrir((cerrar) => FormSalida(
        persona: _p,
        documentos: _docs,
        acento: widget.acento,
        calcular: (d) => _api.calcularSalida(_p.id, d),
        onCancelar: cerrar,
        onGuardar: (d) async {
          try {
            final lq = await _api.guardarSalida(_p.id, d);
            cerrar();
            if (mounted) {
              setState(() {
                _lq = lq;
                _p = Trabajador.fromJson({..._json(_p), 'activo': false,
                  'fecha_retiro': lq.d['fecha_retiro']});
              });
            }
            _msg('Liquidación guardada; la persona queda como retirada.');
            await widget.onCambio();
            return null;
          } catch (e) {
            return '$e';
          }
        },
      ), ancho: 600);

  Map<String, dynamic> _json(Trabajador t) => {
        'id': t.id, 'tienda': t.tienda, 'tienda_nombre': t.tiendaNombre, 'nombres': t.nombres,
        'cedula': t.cedula, 'cargo': t.cargo, 'tipo': t.tipo, 'tipo_contrato': t.tipoContrato,
        'cuenta_pago': t.cuentaPago, 'fecha_ingreso': t.fechaIngreso?.toIso8601String(),
        'valor_dia': t.valorDia, 'gana_minimo': t.ganaMinimo, 'recibe_auxilio': t.recibeAuxilio,
        'vacaciones_tomadas': t.vacacionesTomadas,
      };

  Future<void> _pdfLiquidacion() async {
    final lq = _lq;
    if (lq == null) return;
    try {
      final anexos = <(String, Uint8List)>[];
      for (final d in lq.anexos) {
        for (final a in d.archivos) {
          anexos.add((a.nombre, await _api.archivo(a.id)));
        }
      }
      final b = await NominaPdf.liquidacion(_p, lq, widget.tiendaNombre, anexos: anexos);
      await NominaPdf.abrir(b, 'Liquidacion_${_p.nombres}.pdf');
    } catch (_) {
      if (mounted) _msg('No se pudo generar el PDF.', error: true);
    }
  }

  void _pagarSalida() {
    final lq = _lq!;
    widget.abrir((cerrar) => FormPagoNomina(
          persona: _p.nombres,
          concepto: 'Liquidación de salida',
          falta: lq.pagar - lq.pagado,
          tienda: _p.tienda,
          acento: widget.acento,
          cargarCuentas: widget.cargarCuentas,
          onCancelar: cerrar,
          onGuardar: (d) => _hacer(() => _api.pagarSalida(_p.id, d), cerrar, 'Pago registrado'),
        ));
  }

  Future<void> _anularSalida() async {
    try {
      await _api.anularSalida(_p.id);
      _msg('Liquidación anulada; la persona vuelve a estar activa.');
      widget.onCerrar();
      await widget.onCambio();
    } catch (e) {
      _msg('$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acento;
    final p = _p;
    return MarcoForm(
      titulo: p.nombres,
      subtitulo: [
        if (p.cargo.isNotEmpty) p.cargo,
        p.esNomina ? 'Nómina' : 'Temporal',
        if (p.cedula.isNotEmpty) 'C.C. ${p.cedula}',
        if (p.fechaIngreso != null) 'desde ${fechaCorta(p.fechaIngreso)}',
        if (!p.activo) 'retirada el ${fechaCorta(p.fechaRetiro)}',
      ].join(' · '),
      hijos: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (p.activo)
            OutlinedButton.icon(onPressed: widget.onEditar,
                icon: Icon(Icons.edit_outlined, size: 16, color: a),
                label: Text('Editar datos', style: gf(size: 12.5, w: FontWeight.w800, color: a))),
          if (p.activo && p.esNomina)
            OutlinedButton.icon(onPressed: _cargando ? null : _salida,
                icon: const Icon(Icons.logout_rounded, size: 16, color: rojoN),
                label: Text('Liquidar salida', style: gf(size: 12.5, w: FontWeight.w800, color: rojoN))),
        ]),
        if (_error != null) avisoN(_error!),
        if (_lq != null) ...[
          seccionN('Liquidación de salida', a),
          _liquidacion(_lq!, a),
        ],
        seccionN('Documentos', a),
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: () => _subir(),
            style: FilledButton.styleFrom(backgroundColor: a, minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text('Subir documento', style: gf(size: 12.5, w: FontWeight.w800, color: Colors.white)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: _memorando,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42),
                side: BorderSide(color: a.withValues(alpha: .5), width: 1.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: Icon(Icons.edit_note_rounded, size: 18, color: a),
            label: Text('Crear memorando', style: gf(size: 12.5, w: FontWeight.w800, color: a)),
          )),
        ]),
        const SizedBox(height: 8),
        if (_cargando)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_docs.isEmpty)
          Text('Sin documentos. Aquí van memorandos, descargos, autorizaciones de descuento, contrato, '
              'renuncia e incapacidades.', style: gf(size: 12, color: grisN, h: 1.35))
        else
          for (final d in _docs) _documento(d, a),
        const SizedBox(height: 6),
        Text('Solo el administrador ve esta carpeta.', style: gf(size: 11, color: grisN)),
      ],
      pie: SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton(onPressed: widget.onCerrar,
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text('Cerrar', style: gf(size: 14, w: FontWeight.w700, color: const Color(0xFF334155)))),
      ),
    );
  }

  Widget _liquidacion(Liquidacion lq, Color a) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECDD3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${lq.motivoTexto} · ${fechaCorta(lq.f('fecha_retiro'))}',
              style: gf(size: 13, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('A pagar ${pesosNomina(lq.pagar)} · pagado ${pesosNomina(lq.pagado)}',
              style: gf(size: 12.5, color: const Color(0xFF334155))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (lq.pagar > lq.pagado)
              FilledButton.icon(onPressed: _pagarSalida,
                  style: FilledButton.styleFrom(backgroundColor: a),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Registrar pago')),
            OutlinedButton.icon(onPressed: _pdfLiquidacion,
                icon: Icon(Icons.picture_as_pdf_outlined, size: 16, color: a),
                label: Text('PDF de liquidación', style: gf(size: 12.5, w: FontWeight.w800, color: a))),
            if (lq.pagos.isEmpty)
              TextButton(onPressed: _anularSalida,
                  child: Text('Anular', style: gf(size: 12.5, w: FontWeight.w800, color: rojoN))),
          ]),
        ]),
      );

  Widget _documento(DocumentoTrabajador d, Color a) {
    final (txt, col) = switch (d.firma) {
      'firmado' => ('✓ Firmado', const Color(0xFF15803D)),
      'negado' => ('Se negó · testigos: ${d.testigos}', ambarN),
      'pendiente' => ('Falta firmar', ambarN),
      _ => ('', grisN),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(d.tipoTexto.toUpperCase(), style: gf(size: 10, w: FontWeight.w800,
                  color: d.tipo == 'memorando' ? rojoN : a, ls: .5)),
              const SizedBox(width: 8),
              Text(fechaCorta(d.fecha), style: gf(size: 11, color: grisN)),
            ]),
            if (d.detalle.isNotEmpty)
              Text(d.detalle, style: gf(size: 12.5, w: FontWeight.w600)),
            if (txt.isNotEmpty) Text(txt, style: gf(size: 11, w: FontWeight.w700, color: col)),
            if (d.archivos.isNotEmpty || d.hechoEnSistema)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  if (d.hechoEnSistema)
                    _archivoChip('Memorando N.º ${d.numero}', Icons.picture_as_pdf_outlined,
                        () => _pdfMemorando(d)),
                  for (final ar in d.archivos)
                    _archivoChip(ar.esPdf ? 'PDF' : 'Foto', ar.esPdf ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined, () => _verArchivo(ar)),
                ]),
              ),
            if (d.firma == 'pendiente')
              TextButton.icon(
                onPressed: () => _subir(d),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                icon: Icon(Icons.photo_camera_outlined, size: 16, color: a),
                label: Text('Subir firmado', style: gf(size: 12, w: FontWeight.w800, color: a)),
              ),
          ]),
        ),
        IconButton(
          tooltip: 'Borrar',
          onPressed: () => _borrarDoc(d),
          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: grisN),
        ),
      ]),
    );
  }

  Widget _archivoChip(String t, IconData i, VoidCallback f) => InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 14, color: const Color(0xFF334155)),
            const SizedBox(width: 4),
            Text(t, style: gf(size: 11, w: FontWeight.w700, color: const Color(0xFF334155))),
          ]),
        ),
      );
}

// ── Pagos de una persona (para borrar uno) ─────────────────────

class _ListaPagos extends StatefulWidget {
  final String titulo;
  final List<PagoNomina> pagos;
  final Color acento;
  final VoidCallback onCerrar;
  final Future<String?> Function(PagoNomina p) onBorrar;
  const _ListaPagos({required this.titulo, required this.pagos, required this.acento,
      required this.onCerrar, required this.onBorrar});

  @override
  State<_ListaPagos> createState() => _ListaPagosState();
}

class _ListaPagosState extends State<_ListaPagos> {
  int? _confirmar;
  String? _error;
  bool _borrando = false;

  @override
  Widget build(BuildContext context) => MarcoForm(
        titulo: 'Pagos',
        subtitulo: widget.titulo,
        hijos: [
          for (final p in widget.pagos)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pesosNomina(p.valor), style: gf(size: 14, w: FontWeight.w800)),
                  Text('${fechaCorta(p.fecha)} · ${p.medio}', style: gf(size: 11.5, color: grisN)),
                ])),
                if (_confirmar == p.id)
                  TextButton(
                    onPressed: _borrando ? null : () async {
                      setState(() => _borrando = true);
                      final e = await widget.onBorrar(p);
                      if (mounted) {
                        setState(() {
                          _borrando = false;
                          _error = e;
                        });
                      }
                    },
                    child: Text('Sí, borrar', style: gf(size: 12.5, w: FontWeight.w800, color: rojoN)),
                  )
                else
                  IconButton(onPressed: () => setState(() => _confirmar = p.id),
                      tooltip: 'Borrar pago',
                      icon: const Icon(Icons.delete_outline_rounded, color: grisN, size: 18)),
              ]),
            ),
          const SizedBox(height: 8),
          Text('Al borrar un pago también se borra su gasto de Nómina.',
              style: gf(size: 11.5, color: grisN)),
          if (_error != null) avisoN(_error!),
        ],
        pie: SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(onPressed: widget.onCerrar,
              child: Text('Cerrar', style: gf(size: 14, w: FontWeight.w700, color: const Color(0xFF334155)))),
        ),
      );
}
