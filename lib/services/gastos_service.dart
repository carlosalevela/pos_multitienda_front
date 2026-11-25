// lib/services/gastos_service.dart
//
// Sección "Gastos y nómina" (admin y superadmin): lista del mes, resumen,
// registrar gastos y pagos de nómina.

import 'package:dio/dio.dart';

import '../core/api_client.dart';

// ── Datos ─────────────────────────────────────────────────────

class GastoItem {
  final int       id;
  final int       tiendaId;
  final String    tiendaNombre;
  final String    categoria;
  final String    descripcion;
  final double    monto;
  final String    metodoPago;
  final String?   cuentaNombre;
  final DateTime  fecha;
  final bool      deCaja;
  final String    registradoPor;
  final String    beneficiario;
  final String    periodo;
  final double?   salario;
  final double?   extras;
  final double?   descuentos;

  const GastoItem({
    required this.id,
    required this.tiendaId,
    required this.tiendaNombre,
    required this.categoria,
    required this.monto,
    required this.fecha,
    this.descripcion = '',
    this.metodoPago = 'efectivo',
    this.cuentaNombre,
    this.deCaja = false,
    this.registradoPor = '',
    this.beneficiario = '',
    this.periodo = '',
    this.salario,
    this.extras,
    this.descuentos,
  });

  bool get esNomina => categoria == 'Nómina';

  factory GastoItem.fromJson(Map<String, dynamic> j) {
    double? n(Object? v) => v == null ? null : double.tryParse('$v');
    DateTime fecha;
    try {
      fecha = DateTime.parse('${j['fecha'] ?? j['created_at']}');
    } catch (_) {
      fecha = DateTime.now();
    }
    return GastoItem(
      id:            (j['id'] as num).toInt(),
      tiendaId:      (j['tienda'] as num?)?.toInt() ?? 0,
      tiendaNombre:  '${j['tienda_nombre'] ?? ''}',
      categoria:     '${j['categoria'] ?? ''}'.isEmpty ? 'Otros' : '${j['categoria']}',
      descripcion:   '${j['descripcion'] ?? ''}',
      monto:         n(j['monto']) ?? 0,
      metodoPago:    '${j['metodo_pago'] ?? 'efectivo'}',
      cuentaNombre:  j['cuenta_nombre'] as String?,
      fecha:         DateTime(fecha.year, fecha.month, fecha.day),
      deCaja:        j['de_caja'] == true,
      registradoPor: '${j['empleado_nombre'] ?? ''}',
      beneficiario:  '${j['beneficiario_nombre'] ?? ''}',
      periodo:       '${j['periodo'] ?? ''}',
      salario:       n(j['salario']),
      extras:        n(j['extras']),
      descuentos:    n(j['descuentos']),
    );
  }
}

class PanelGastos {
  final double  total;
  final int     cantidad;
  final double  totalMesAnterior;
  final double? variacionPct;
  final double  nominaTotal;
  final int     nominaPagos;
  final int     nominaPersonas;
  final double  arriendoServicios;
  final double  deCaja;
  final List<(String, double, int)> porCategoria;

  const PanelGastos({
    this.total = 0,
    this.cantidad = 0,
    this.totalMesAnterior = 0,
    this.variacionPct,
    this.nominaTotal = 0,
    this.nominaPagos = 0,
    this.nominaPersonas = 0,
    this.arriendoServicios = 0,
    this.deCaja = 0,
    this.porCategoria = const [],
  });

  factory PanelGastos.fromJson(Map<String, dynamic> j) {
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    final nom = (j['nomina'] as Map?) ?? const {};
    return PanelGastos(
      total:             n(j['total']),
      cantidad:          (j['cantidad'] as num?)?.toInt() ?? 0,
      totalMesAnterior:  n(j['total_mes_anterior']),
      variacionPct:      (j['variacion_pct'] as num?)?.toDouble(),
      nominaTotal:       n(nom['total']),
      nominaPagos:       (nom['pagos'] as num?)?.toInt() ?? 0,
      nominaPersonas:    (nom['personas'] as num?)?.toInt() ?? 0,
      arriendoServicios: n(j['arriendo_servicios']),
      deCaja:            n(j['de_caja']),
      porCategoria: [
        for (final c in (j['por_categoria'] as List? ?? const []))
          if (c is Map)
            ('${c['categoria']}', n(c['total']),
             (c['cantidad'] as num?)?.toInt() ?? 0),
      ],
    );
  }
}

/// Categorías que se eligen al registrar un gasto (la nómina tiene su
/// propio formulario; "Proveedor" lo crea el sistema al pagar compras).
const categoriasGasto = [
  'Arriendo', 'Servicios', 'Aseo', 'Insumos', 'Transporte',
  'Mantenimiento', 'Publicidad', 'Impuestos', 'Mercancía', 'Otros',
];

/// Lo que se ve en los filtros de la lista.
const categoriasFiltro = [
  'Nómina', 'Arriendo', 'Servicios', 'Aseo', 'Insumos', 'Transporte',
  'Mantenimiento', 'Publicidad', 'Impuestos', 'Mercancía', 'Proveedor', 'Otros',
];

const metodosPagoGasto = {
  'efectivo':      'Efectivo',
  'transferencia': 'Transferencia',
  'tarjeta':       'Tarjeta',
};

// ── Reglas (sin pantalla: se prueban solas) ───────────────────

/// Salario + extras − descuentos.
double totalNomina(double? salario, double? extras, double? descuentos) =>
    (salario ?? 0) + (extras ?? 0) - (descuentos ?? 0);

/// Por qué no se puede registrar la nómina todavía; null si se puede.
String? problemaNomina({
  required bool    hayBeneficiario,
  required double? salario,
  double? extras,
  double? descuentos,
}) {
  if (!hayBeneficiario) return 'Elige a quién se le paga.';
  if (salario == null) return 'Escribe el salario.';
  if ([salario, extras ?? 0, descuentos ?? 0].any((v) => v.isNaN)) {
    return 'Escribe los valores solo con números.';
  }
  if (salario < 0 || (extras ?? 0) < 0 || (descuentos ?? 0) < 0) {
    return 'Los valores no pueden ser negativos.';
  }
  if (totalNomina(salario, extras, descuentos) <= 0) {
    return 'Los descuentos no pueden ser iguales o mayores que el salario '
        'más los extras.';
  }
  return null;
}

/// Por qué no se puede guardar el gasto todavía; null si se puede.
String? problemaGasto({
  required String? categoria,
  required double? monto,
  required bool    necesitaCuenta,
  required bool    hayCuenta,
}) {
  if (categoria == null) return 'Elige la categoría.';
  if (monto == null) return 'Escribe el monto.';
  if (monto.isNaN) return 'Escribe el monto solo con números.';
  if (monto <= 0) return 'El monto debe ser mayor a cero.';
  if (necesitaCuenta && !hayCuenta) return 'Elige la cuenta.';
  return null;
}

const _mesesCortos = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
                      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const mesesLargos = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo',
  'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre',
  'Diciembre'];

/// "2.ª quincena nov 2026", "Mes completo nov 2026" u otro texto libre.
String periodoNomina(String opcion, DateTime fecha, {String otro = ''}) {
  final mes = '${_mesesCortos[fecha.month]} ${fecha.year}';
  return switch (opcion) {
    'q1'  => '1.ª quincena $mes',
    'q2'  => '2.ª quincena $mes',
    'mes' => 'Mes completo $mes',
    _     => otro.trim(),
  };
}

/// La quincena que corresponde a una fecha.
String quincenaDe(DateTime f) => f.day <= 15 ? 'q1' : 'q2';

// ── Servidor ──────────────────────────────────────────────────

class GastosService {
  String _error(DioException e, String porDefecto) {
    final d = e.response?.data;
    if (d is Map) {
      if (d['detail'] != null) return '${d['detail']}';
      if (d['error'] != null) return '${d['error']}';
      final msgs = d.values.expand((v) => v is List ? v : [v]).join(' ');
      if (msgs.isNotEmpty) return msgs;
    }
    return porDefecto;
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<GastoItem>> listarMes(int anio, int mes, {int? tiendaId}) async {
    final ini = DateTime(anio, mes, 1);
    final fin = DateTime(anio, mes + 1, 0);
    final r = await ApiClient.instance.get('/contabilidad/gastos/', queryParameters: {
      'fecha_ini': _iso(ini),
      'fecha_fin': _iso(fin),
      if (tiendaId != null) 'tienda_id': '$tiendaId',
    });
    final data = r.data is List ? r.data as List : (r.data['results'] as List? ?? const []);
    return data.whereType<Map<String, dynamic>>().map(GastoItem.fromJson).toList();
  }

  Future<PanelGastos> panel(int anio, int mes, {int? tiendaId}) async {
    final r = await ApiClient.instance.get('/contabilidad/gastos/panel/', queryParameters: {
      'anio': '$anio',
      'mes':  '$mes',
      if (tiendaId != null) 'tienda_id': '$tiendaId',
    });
    return PanelGastos.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// null si se guardó; si no, el mensaje del servidor.
  Future<String?> crear(Map<String, dynamic> data) async {
    try {
      await ApiClient.instance.post('/contabilidad/gastos/', data: data);
      return null;
    } on DioException catch (e) {
      return _error(e, 'No se pudo guardar el gasto.');
    } catch (_) {
      return 'No se pudo guardar el gasto.';
    }
  }

  Future<String?> eliminar(int id) async {
    try {
      await ApiClient.instance.delete('/contabilidad/gastos/$id/');
      return null;
    } on DioException catch (e) {
      return _error(e, 'No se pudo eliminar el gasto.');
    } catch (_) {
      return 'No se pudo eliminar el gasto.';
    }
  }

  Future<bool> cajaAbierta(int tiendaId) async {
    try {
      await ApiClient.instance.get('/caja/activa/$tiendaId/');
      return true;
    } catch (_) {
      return false;
    }
  }

  String fechaIso(DateTime d) => _iso(d);
}
