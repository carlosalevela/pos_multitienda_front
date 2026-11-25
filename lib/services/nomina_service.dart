// lib/services/nomina_service.dart
//
// Nómina por quincenas (admin y superadmin): personas, quincenas, pagos,
// mes completo, liquidación de salida y documentos de cada persona.
//
// Las cuentas las hace el servidor; aquí se repiten (mismas reglas) solo
// para mostrar los totales mientras se escribe.

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api_client.dart';

// ── Reglas (sin pantalla: se prueban solas) ───────────────────

/// 929.963 → 930.000. Hacia arriba: nunca se paga de menos.
int alMil(num v) => v <= 0 ? 0 : ((v / 1000).ceil() * 1000);

/// "$1.750.905" (sin decimales, con puntos).
String pesosNomina(num v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}\$$b';
}

/// "14,5" / "15".
String diasTexto(num d) => d == d.roundToDouble()
    ? d.toInt().toString()
    : d.toStringAsFixed(1).replaceAll('.', ',');

/// Lee "58.364", "58364", "14,5" → número; null si no es número.
double? leerNumero(String t, {bool decimales = false}) {
  var s = t.trim().replaceAll(r'$', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (decimales) {
    s = s.replaceAll(',', '.');
  } else {
    s = s.replaceAll('.', '').replaceAll(',', '');
  }
  return double.tryParse(s);
}

class CalculoFila {
  final int sueldo, auxilio, salud, pension, danos, adelantos, neto, pagar;
  const CalculoFila({
    this.sueldo = 0, this.auxilio = 0, this.salud = 0, this.pension = 0,
    this.danos = 0, this.adelantos = 0, this.neto = 0, this.pagar = 0,
  });
  int get devengado => sueldo + auxilio;
  int get deducido => salud + pension + danos + adelantos;
}

/// Lo mismo que calcula el servidor para una persona en una quincena.
CalculoFila calcularFila({
  required String tipo,
  required double valorDia,
  required double dias,
  required int salarioMinimo,
  required int auxilioTransporte,
  bool ganaMinimo = false,
  bool recibeAuxilio = true,
  int danos = 0,
  int adelantos = 0,
  bool redondearMil = true,
}) {
  final nomina = tipo == 'nomina';
  final minimo = nomina && ganaMinimo;
  // Enteros para no perder pesos con los decimales (1.750.905 × 15 / 30).
  final sueldo = minimo
      ? (salarioMinimo * (dias * 2).round()) ~/ 60
      : (valorDia * dias + 1e-6).floor();
  final mensual = minimo ? salarioMinimo.toDouble() : valorDia * 30;
  final aux = nomina && recibeAuxilio && mensual <= salarioMinimo * 2
      ? (auxilioTransporte * (dias * 2).round()) ~/ 60
      : 0;
  final salud = nomina ? (sueldo * 0.04).round() : 0;
  final neto = sueldo + aux - salud * 2 - danos - adelantos;
  return CalculoFila(
    sueldo: sueldo, auxilio: aux, salud: salud, pension: salud,
    danos: danos, adelantos: adelantos, neto: neto,
    pagar: redondearMil ? alMil(neto) : (neto < 0 ? 0 : neto),
  );
}

/// Por qué no se puede guardar la fila; null si se puede.
String? problemaFila({
  required String nombre,
  required double? valorDia,
  required double? dias,
  required bool ganaMinimo,
  int danos = 0,
  int adelantos = 0,
  CalculoFila? calculo,
}) {
  if (dias == null || dias.isNaN) return '$nombre: escribe los días.';
  if (dias < 0) return '$nombre: los días no pueden ser negativos.';
  if (dias > 16) return '$nombre: una quincena tiene máximo 16 días.';
  if ((dias * 2).roundToDouble() != dias * 2) {
    return '$nombre: los días van de medio en medio (ej. 14,5).';
  }
  if (dias == 0) return null;
  if (!ganaMinimo && (valorDia == null || valorDia <= 0)) {
    return '$nombre: escribe el valor del día.';
  }
  if (danos < 0 || adelantos < 0) {
    return '$nombre: los descuentos no pueden ser negativos.';
  }
  if (calculo != null && calculo.neto < 0) {
    return '$nombre: los descuentos superan lo que ganó.';
  }
  return null;
}

const meses = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

/// "16 al 30 de noviembre de 2026".
String periodoQuincena(int anio, int mes, int numero) {
  final fin = numero == 1 ? 15 : DateTime(anio, mes + 1, 0).day;
  return '${numero == 1 ? 1 : 16} al $fin de ${meses[mes]} de $anio';
}

/// La quincena en que cae una fecha: (año, mes, 1|2).
(int, int, int) quincenaDeFecha(DateTime f) =>
    (f.year, f.month, f.day <= 15 ? 1 : 2);

String fechaCorta(DateTime? f) => f == null
    ? '—'
    : '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

String fechaIso(DateTime f) =>
    '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

DateTime? _f(Object? v) {
  if (v == null || '$v'.isEmpty) return null;
  return DateTime.tryParse('$v');
}

int _i(Object? v) => (v as num?)?.round() ?? int.tryParse('$v') ?? 0;
double _d(Object? v) => (v as num?)?.toDouble() ?? double.tryParse('$v') ?? 0;

const motivosSalida = {
  'renuncia':        'Renuncia',
  'sin_justa_causa': 'Despido sin justa causa',
  'justa_causa':     'Despido con justa causa',
  'fin_contrato':    'Fin del contrato a término fijo',
  'mutuo_acuerdo':   'Mutuo acuerdo',
  'periodo_prueba':  'Período de prueba',
};

const contratos = {
  'indefinido': 'Término indefinido',
  'fijo':       'Término fijo',
  'obra':       'Obra o labor',
  'temporal':   'Temporal por días',
};

const tiposDocumento = {
  'memorando':    'Memorando',
  'descargos':    'Descargos',
  'autorizacion': 'Autorización de descuento',
  'contrato':     'Contrato',
  'renuncia':     'Renuncia',
  'incapacidad':  'Incapacidad',
  'otro':         'Otro',
};

const firmasDocumento = {
  'firmado':   'Firmado',
  'negado':    'Se negó a firmar',
  'pendiente': 'Falta firmar',
  'no_aplica': 'No aplica',
};

const motivosMemorando = [
  'Llegadas tarde', 'Falta sin aviso', 'Incumplimiento de funciones',
  'Faltante en caja', 'Trato con clientes', 'Otro',
];

// ── Datos ─────────────────────────────────────────────────────

class ValoresAnio {
  final int anio, salarioMinimo, auxilioTransporte;
  final double arlPct;
  final bool exonerado, redondearMil, guardado;
  const ValoresAnio({
    required this.anio, required this.salarioMinimo,
    required this.auxilioTransporte, this.arlPct = 0.522,
    this.exonerado = true, this.redondearMil = true, this.guardado = false,
  });
  factory ValoresAnio.fromJson(Map j) => ValoresAnio(
        anio: _i(j['anio']), salarioMinimo: _i(j['salario_minimo']),
        auxilioTransporte: _i(j['auxilio_transporte']), arlPct: _d(j['arl_pct']),
        exonerado: j['exonerado'] != false, redondearMil: j['redondear_mil'] != false,
        guardado: j['guardado'] == true,
      );
}

class Trabajador {
  final int id, tienda;
  final String tiendaNombre, nombres, cedula, cargo, tipo, tipoContrato, cuentaPago;
  final DateTime? fechaIngreso, fechaFinContrato, primaPagadaHasta, fechaRetiro;
  final double valorDia, vacacionesTomadas;
  final bool ganaMinimo, recibeAuxilio, activo;

  const Trabajador({
    required this.id, required this.tienda, required this.nombres,
    this.tiendaNombre = '', this.cedula = '', this.cargo = '', this.tipo = 'nomina',
    this.tipoContrato = 'indefinido', this.cuentaPago = '', this.fechaIngreso,
    this.fechaFinContrato, this.primaPagadaHasta, this.fechaRetiro,
    this.valorDia = 0, this.vacacionesTomadas = 0, this.ganaMinimo = false,
    this.recibeAuxilio = true, this.activo = true,
  });

  bool get esNomina => tipo == 'nomina';

  factory Trabajador.fromJson(Map j) => Trabajador(
        id: _i(j['id']), tienda: _i(j['tienda']),
        tiendaNombre: '${j['tienda_nombre'] ?? ''}', nombres: '${j['nombres'] ?? ''}',
        cedula: '${j['cedula'] ?? ''}', cargo: '${j['cargo'] ?? ''}',
        tipo: '${j['tipo'] ?? 'nomina'}', tipoContrato: '${j['tipo_contrato'] ?? 'indefinido'}',
        cuentaPago: '${j['cuenta_pago'] ?? ''}', fechaIngreso: _f(j['fecha_ingreso']),
        fechaFinContrato: _f(j['fecha_fin_contrato']),
        primaPagadaHasta: _f(j['prima_pagada_hasta']), fechaRetiro: _f(j['fecha_retiro']),
        valorDia: _d(j['valor_dia']), vacacionesTomadas: _d(j['vacaciones_tomadas']),
        ganaMinimo: j['gana_minimo'] == true, recibeAuxilio: j['recibe_auxilio'] != false,
        activo: j['activo'] != false,
      );
}

class PagoNomina {
  final int id, valor;
  final DateTime fecha;
  final String metodoPago;
  final String? cuentaNombre;
  const PagoNomina({required this.id, required this.valor, required this.fecha,
      this.metodoPago = 'efectivo', this.cuentaNombre});
  String get medio => metodoPago == 'efectivo'
      ? 'Efectivo'
      : ['Transferencia', ?cuentaNombre].join(' · ');
  factory PagoNomina.fromJson(Map j) => PagoNomina(
        id: _i(j['id']), valor: _i(j['valor']),
        fecha: _f(j['fecha']) ?? DateTime.now(),
        metodoPago: '${j['metodo_pago'] ?? 'efectivo'}',
        cuentaNombre: j['cuenta_nombre'] as String?,
      );
}

/// Una persona en la quincena (guardada o todavía sin guardar).
class FilaQuincena {
  final int? id;
  final int trabajador;
  final String nombres, cedula, cargo, cuentaPago, tipo, fechas;
  final int? comprobante;
  final double valorDia, dias;
  final bool ganaMinimo, guardada;
  final CalculoFila calculo;
  final List<PagoNomina> pagos;

  const FilaQuincena({
    this.id, required this.trabajador, required this.nombres, this.cedula = '',
    this.cargo = '', this.cuentaPago = '', this.tipo = 'nomina', this.fechas = '',
    this.comprobante, this.valorDia = 0, this.dias = 0, this.ganaMinimo = false,
    this.guardada = false, this.calculo = const CalculoFila(), this.pagos = const [],
  });

  int get pagado => pagos.fold(0, (s, p) => s + p.valor);
  int get falta => calculo.pagar - pagado;
  bool get esNomina => tipo == 'nomina';

  factory FilaQuincena.fromJson(Map j) => FilaQuincena(
        id: j['id'] == null ? null : _i(j['id']), trabajador: _i(j['trabajador']),
        nombres: '${j['nombres'] ?? ''}', cedula: '${j['cedula'] ?? ''}',
        cargo: '${j['cargo'] ?? ''}', cuentaPago: '${j['cuenta_pago'] ?? ''}',
        tipo: '${j['tipo'] ?? 'nomina'}', fechas: '${j['fechas'] ?? ''}',
        comprobante: j['comprobante'] == null ? null : _i(j['comprobante']),
        valorDia: _d(j['valor_dia']), dias: _d(j['dias']),
        ganaMinimo: j['gana_minimo'] == true, guardada: j['guardada'] == true,
        calculo: CalculoFila(
          sueldo: _i(j['sueldo']), auxilio: _i(j['auxilio']), salud: _i(j['salud']),
          pension: _i(j['pension']), danos: _i(j['danos']), adelantos: _i(j['adelantos']),
          neto: _i(j['neto']), pagar: _i(j['pagar']),
        ),
        pagos: [for (final p in (j['pagos'] as List? ?? const [])) PagoNomina.fromJson(p as Map)],
      );
}

class QuincenaNomina {
  final int? id;
  final int tienda, anio, mes, numero, salarioMinimo, auxilioTransporte;
  final String tiendaNombre, ciudad, periodo, empleador;
  final bool redondearMil, valoresGuardados;
  final List<FilaQuincena> filas;

  const QuincenaNomina({
    this.id, required this.tienda, required this.anio, required this.mes,
    required this.numero, required this.salarioMinimo, required this.auxilioTransporte,
    this.tiendaNombre = '', this.ciudad = '', this.periodo = '', this.empleador = '',
    this.redondearMil = true, this.valoresGuardados = true, this.filas = const [],
  });

  factory QuincenaNomina.fromJson(Map j) => QuincenaNomina(
        id: j['id'] == null ? null : _i(j['id']), tienda: _i(j['tienda']),
        anio: _i(j['anio']), mes: _i(j['mes']), numero: _i(j['numero']),
        salarioMinimo: _i(j['salario_minimo']), auxilioTransporte: _i(j['auxilio_transporte']),
        tiendaNombre: '${j['tienda_nombre'] ?? ''}', ciudad: '${j['ciudad'] ?? ''}',
        periodo: '${j['periodo'] ?? ''}', empleador: '${j['empleador'] ?? ''}',
        redondearMil: j['redondear_mil'] != false,
        valoresGuardados: j['valores_guardados'] != false,
        filas: [for (final f in (j['filas'] as List? ?? const [])) FilaQuincena.fromJson(f as Map)],
      );

  List<FilaQuincena> get guardadas => filas.where((f) => f.guardada).toList();
  int get totalPagar => guardadas.fold(0, (s, f) => s + f.calculo.pagar);
  int get totalPagado => guardadas.fold(0, (s, f) => s + f.pagado);
}

class PersonaMes {
  final int trabajador;
  final String nombres, cedula, tipo, tiendaNombre;
  final int? q1, q2;
  final double dias;
  final int sueldo, auxilio, salud, pension, danos, adelantos, neto, pagar, pagado,
      costo, aportes, provisiones;
  final Map<String, int> costoDetalle;

  const PersonaMes({
    required this.trabajador, required this.nombres, this.cedula = '',
    this.tipo = 'nomina', this.tiendaNombre = '', this.q1, this.q2, this.dias = 0,
    this.sueldo = 0, this.auxilio = 0, this.salud = 0, this.pension = 0, this.danos = 0,
    this.adelantos = 0, this.neto = 0, this.pagar = 0, this.pagado = 0, this.costo = 0,
    this.aportes = 0, this.provisiones = 0, this.costoDetalle = const {},
  });

  int get devengado => sueldo + auxilio;
  int get deducido => salud + pension + danos + adelantos;

  factory PersonaMes.fromJson(Map j) {
    final c = (j['costo_detalle'] as Map?) ?? const {};
    return PersonaMes(
      trabajador: _i(j['trabajador']), nombres: '${j['nombres'] ?? ''}',
      cedula: '${j['cedula'] ?? ''}', tipo: '${j['tipo'] ?? 'nomina'}',
      tiendaNombre: '${j['tienda_nombre'] ?? ''}',
      q1: j['q1'] == null ? null : _i((j['q1'] as Map)['pagar']),
      q2: j['q2'] == null ? null : _i((j['q2'] as Map)['pagar']),
      dias: _d(j['dias']), sueldo: _i(j['sueldo']), auxilio: _i(j['auxilio']),
      salud: _i(j['salud']), pension: _i(j['pension']), danos: _i(j['danos']),
      adelantos: _i(j['adelantos']), neto: _i(j['neto']), pagar: _i(j['pagar']),
      pagado: _i(j['pagado']), costo: _i(j['costo']), aportes: _i(c['aportes']),
      provisiones: _i(c['provisiones']),
      costoDetalle: {for (final e in c.entries) '${e.key}': _i(e.value)},
    );
  }
}

class MesNomina {
  final int anio, mes;
  final ValoresAnio valores;
  final List<PersonaMes> personas;
  final Map<String, int> totales;
  const MesNomina({required this.anio, required this.mes, required this.valores,
      this.personas = const [], this.totales = const {}});
  int t(String k) => totales[k] ?? 0;
  factory MesNomina.fromJson(Map j) => MesNomina(
        anio: _i(j['anio']), mes: _i(j['mes']),
        valores: ValoresAnio.fromJson(j['valores'] as Map),
        personas: [for (final p in (j['personas'] as List? ?? const [])) PersonaMes.fromJson(p as Map)],
        totales: {for (final e in ((j['totales'] as Map?) ?? const {}).entries) '${e.key}': _i(e.value)},
      );
}

class ArchivoDoc {
  final int id, sizeKb;
  final String nombre, contentType;
  const ArchivoDoc({required this.id, required this.nombre,
      this.contentType = '', this.sizeKb = 0});
  bool get esPdf => contentType == 'application/pdf';
}

class DocumentoTrabajador {
  final int id, trabajador, numero;
  final String tipo, detalle, firma, testigos, motivo, hechos;
  final DateTime fecha;
  final List<ArchivoDoc> archivos;
  const DocumentoTrabajador({
    required this.id, required this.trabajador, required this.tipo,
    required this.fecha, this.numero = 0, this.detalle = '', this.firma = 'no_aplica',
    this.testigos = '', this.motivo = '', this.hechos = '', this.archivos = const [],
  });
  String get tipoTexto => tiposDocumento[tipo] ?? tipo;
  /// Memorando hecho en el sistema (se puede volver a sacar el PDF).
  bool get hechoEnSistema => tipo == 'memorando' && hechos.isNotEmpty;
  factory DocumentoTrabajador.fromJson(Map j) => DocumentoTrabajador(
        id: _i(j['id']), trabajador: _i(j['trabajador']), tipo: '${j['tipo']}',
        fecha: _f(j['fecha']) ?? DateTime.now(), numero: _i(j['numero']),
        detalle: '${j['detalle'] ?? ''}', firma: '${j['firma'] ?? 'no_aplica'}',
        testigos: '${j['testigos'] ?? ''}', motivo: '${j['motivo'] ?? ''}',
        hechos: '${j['hechos'] ?? ''}',
        archivos: [
          for (final a in (j['archivos'] as List? ?? const []))
            ArchivoDoc(id: _i(a['id']), nombre: '${a['nombre']}',
                contentType: '${a['content_type'] ?? ''}', sizeKb: _i(a['size_kb'])),
        ],
      );
}

/// Cálculo (o liquidación guardada) de la salida de una persona.
class Liquidacion {
  final int? id;
  final int? comprobante;
  final Map<String, dynamic> d;
  final List<PagoNomina> pagos;
  final List<DocumentoTrabajador> anexos;
  final String empleador;
  const Liquidacion({this.id, this.comprobante, required this.d,
      this.pagos = const [], this.anexos = const [], this.empleador = ''});

  int v(String k) => _i(d[k]);
  double n(String k) => _d(d[k]);
  DateTime? f(String k) => _f(d[k]);
  int get neto => v('neto');
  int get pagar => v('pagar');
  int get pagado => pagos.fold(0, (s, p) => s + p.valor);
  String get motivoTexto => '${d['motivo_texto'] ?? motivosSalida[d['motivo']] ?? ''}';

  /// Respuesta de "calcular" (el cálculo suelto).
  factory Liquidacion.calculo(Map j) =>
      Liquidacion(d: Map<String, dynamic>.from(j), empleador: '${j['empleador'] ?? ''}');

  /// Liquidación guardada.
  factory Liquidacion.fromJson(Map j) => Liquidacion(
        id: _i(j['id']), comprobante: _i(j['comprobante']),
        d: Map<String, dynamic>.from(j['detalle'] as Map? ?? const {}),
        empleador: '${j['empleador'] ?? ''}',
        pagos: [for (final p in (j['pagos'] as List? ?? const [])) PagoNomina.fromJson(p as Map)],
        anexos: [for (final a in (j['anexos'] as List? ?? const [])) DocumentoTrabajador.fromJson(a as Map)],
      );
}

// ── Servidor ──────────────────────────────────────────────────

class NominaService {
  static const _b = '/nomina';

  String error(Object e, String porDefecto) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map) {
        if (d['detail'] != null) return '${d['detail']}';
        final msgs = d.values.expand((v) => v is List ? v : [v]).join(' ');
        if (msgs.isNotEmpty) return msgs;
      }
      if (d is List && d.isNotEmpty) return d.join(' ');
    }
    return porDefecto;
  }

  Future<T> _intentar<T>(Future<T> Function() f, String porDefecto) async {
    try {
      return await f();
    } catch (e) {
      throw NominaError(error(e, porDefecto));
    }
  }

  Future<ValoresAnio> valores(int anio, {int? tiendaId}) => _intentar(() async {
        final r = await ApiClient.instance.get('$_b/valores/', queryParameters: {
          'anio': '$anio', if (tiendaId != null) 'tienda_id': '$tiendaId'});
        return ValoresAnio.fromJson(r.data as Map);
      }, 'No se pudieron cargar los valores del año.');

  Future<ValoresAnio> guardarValores(Map<String, dynamic> datos) => _intentar(() async {
        final r = await ApiClient.instance.put('$_b/valores/', data: datos);
        return ValoresAnio.fromJson(r.data as Map);
      }, 'No se pudieron guardar los valores.');

  Future<List<Trabajador>> trabajadores({int? tiendaId, String estado = 'activos'}) =>
      _intentar(() async {
        final r = await ApiClient.instance.get('$_b/trabajadores/', queryParameters: {
          'estado': estado, if (tiendaId != null) 'tienda_id': '$tiendaId'});
        return [for (final t in r.data as List) Trabajador.fromJson(t as Map)];
      }, 'No se pudieron cargar las personas.');

  Future<Trabajador> guardarTrabajador(Map<String, dynamic> datos, {int? id}) =>
      _intentar(() async {
        final r = id == null
            ? await ApiClient.instance.post('$_b/trabajadores/', data: datos)
            : await ApiClient.instance.patch('$_b/trabajadores/$id/', data: datos);
        return Trabajador.fromJson(r.data as Map);
      }, 'No se pudo guardar la persona.');

  Future<void> borrarTrabajador(int id) => _intentar(
      () => ApiClient.instance.delete('$_b/trabajadores/$id/'), 'No se pudo borrar.');

  Future<QuincenaNomina> quincena(int tiendaId, int anio, int mes, int numero) =>
      _intentar(() async {
        final r = await ApiClient.instance.get('$_b/quincena/', queryParameters: {
          'tienda_id': '$tiendaId', 'anio': '$anio', 'mes': '$mes', 'numero': '$numero'});
        return QuincenaNomina.fromJson(r.data as Map);
      }, 'No se pudo cargar la quincena.');

  Future<QuincenaNomina> guardarQuincena(Map<String, dynamic> datos) => _intentar(() async {
        final r = await ApiClient.instance.post('$_b/quincena/', data: datos);
        return QuincenaNomina.fromJson(r.data as Map);
      }, 'No se pudo guardar la quincena.');

  Future<void> pagarLinea(int lineaId, Map<String, dynamic> datos) => _intentar(
      () => ApiClient.instance.post('$_b/lineas/$lineaId/pagos/', data: datos),
      'No se pudo registrar el pago.');

  Future<void> borrarPago(int id) => _intentar(
      () => ApiClient.instance.delete('$_b/pagos/$id/'), 'No se pudo borrar el pago.');

  Future<MesNomina> mes(int anio, int mes, {int? tiendaId}) => _intentar(() async {
        final r = await ApiClient.instance.get('$_b/mes/', queryParameters: {
          'anio': '$anio', 'mes': '$mes', if (tiendaId != null) 'tienda_id': '$tiendaId'});
        return MesNomina.fromJson(r.data as Map);
      }, 'No se pudo cargar el mes.');

  Future<Liquidacion> calcularSalida(int id, Map<String, dynamic> datos) => _intentar(() async {
        final r = await ApiClient.instance.post('$_b/trabajadores/$id/salida/',
            data: {...datos, 'guardar': false});
        return Liquidacion.calculo(r.data as Map);
      }, 'No se pudo calcular la liquidación.');

  Future<Liquidacion> guardarSalida(int id, Map<String, dynamic> datos) => _intentar(() async {
        final r = await ApiClient.instance.post('$_b/trabajadores/$id/salida/',
            data: {...datos, 'guardar': true});
        return Liquidacion.fromJson(r.data as Map);
      }, 'No se pudo guardar la liquidación.');

  Future<Liquidacion?> salida(int id) async {
    try {
      final r = await ApiClient.instance.get('$_b/trabajadores/$id/salida/');
      return Liquidacion.fromJson(r.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw NominaError(error(e, 'No se pudo cargar la liquidación.'));
    }
  }

  Future<void> anularSalida(int id) => _intentar(
      () => ApiClient.instance.delete('$_b/trabajadores/$id/salida/'),
      'No se pudo anular la liquidación.');

  Future<void> pagarSalida(int id, Map<String, dynamic> datos) => _intentar(
      () => ApiClient.instance.post('$_b/trabajadores/$id/salida/pagos/', data: datos),
      'No se pudo registrar el pago.');

  Future<List<DocumentoTrabajador>> documentos(int trabajadorId) => _intentar(() async {
        final r = await ApiClient.instance.get('$_b/trabajadores/$trabajadorId/documentos/');
        return [for (final d in r.data as List) DocumentoTrabajador.fromJson(d as Map)];
      }, 'No se pudieron cargar los documentos.');

  /// [archivos]: (nombre, bytes).
  Future<DocumentoTrabajador> subirDocumento(int trabajadorId, Map<String, dynamic> datos,
          List<(String, Uint8List)> archivos) =>
      _intentar(() async {
        final form = FormData.fromMap({
          ...datos.map((k, v) => MapEntry(k, '$v')),
          'archivos': [
            for (final (nombre, bytes) in archivos)
              MultipartFile.fromBytes(bytes, filename: nombre,
                  contentType: DioMediaType.parse(tipoDeArchivo(nombre))),
          ],
        });
        final r = await ApiClient.instance.post(
            '$_b/trabajadores/$trabajadorId/documentos/', data: form);
        return DocumentoTrabajador.fromJson(r.data as Map);
      }, 'No se pudo guardar el documento.');

  Future<DocumentoTrabajador> actualizarDocumento(int id, Map<String, dynamic> datos,
          {List<(String, Uint8List)> archivos = const []}) =>
      _intentar(() async {
        final form = FormData.fromMap({
          ...datos.map((k, v) => MapEntry(k, '$v')),
          'archivos': [
            for (final (nombre, bytes) in archivos)
              MultipartFile.fromBytes(bytes, filename: nombre,
                  contentType: DioMediaType.parse(tipoDeArchivo(nombre))),
          ],
        });
        final r = await ApiClient.instance.patch('$_b/documentos/$id/', data: form);
        return DocumentoTrabajador.fromJson(r.data as Map);
      }, 'No se pudo actualizar el documento.');

  Future<void> borrarDocumento(int id) => _intentar(
      () => ApiClient.instance.delete('$_b/documentos/$id/'), 'No se pudo borrar el documento.');

  Future<Uint8List> archivo(int id) => _intentar(() async {
        final r = await ApiClient.instance.get('$_b/archivos/$id/',
            options: Options(responseType: ResponseType.bytes));
        return Uint8List.fromList(r.data as List<int>);
      }, 'No se pudo descargar el archivo.');
}

class NominaError implements Exception {
  final String mensaje;
  const NominaError(this.mensaje);
  @override
  String toString() => mensaje;
}

String tipoDeArchivo(String nombre) {
  final n = nombre.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
