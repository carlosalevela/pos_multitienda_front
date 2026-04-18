import 'package:flutter/foundation.dart';
import '../services/venta_service.dart';
import '../services/abono_service.dart';
import '../services/contabilidad_service.dart';

class ReportesProvider extends ChangeNotifier {
  final VentaService _service = VentaService();
  final AbonoService _abonoService = AbonoService();
  final ContabilidadService _contabilidadService = ContabilidadService();

  List<Map<String, dynamic>> _ventas = [];
  List<Map<String, dynamic>> _abonos = [];
  List<Map<String, dynamic>> _devoluciones = [];
  bool _cargando = false;
  String _errorMsg = '';

  List<Map<String, dynamic>> get ventas => _ventas;
  List<Map<String, dynamic>> get abonos => _abonos;
  List<Map<String, dynamic>> get devoluciones => _devoluciones;
  bool get cargando => _cargando;
  String get errorMsg => _errorMsg;

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  String _toStr(dynamic value) => value?.toString().toLowerCase().trim() ?? '';

  double _impactoCajaDevolucion(Map<String, dynamic> d) {
    final estado = _toStr(d['estado']);
    if (estado == 'cancelada') return 0;

    final tipo = _toStr(d['tipo']);
    final totalDevuelto = _toDouble(d['total_devuelto']);
    final diferencia = _toDouble(d['diferencia']);
    final tipoDiferencia = _toStr(d['tipo_diferencia']);

    if (tipo == 'devolucion') {
      return -totalDevuelto;
    }

    if (tipo == 'cambio') {
      if (tipoDiferencia == 'cobrar') return diferencia;
      if (tipoDiferencia == 'devolver') return -diferencia;
      return 0;
    }

    return -totalDevuelto;
  }

  double get totalDia => _ventas
      .where((v) => v['estado'] != 'anulada')
      .fold(0.0, (sum, v) => sum + _toDouble(v['total']));

  double get totalDescuentos => _ventas
      .where((v) => v['estado'] != 'anulada')
      .fold(0.0, (sum, v) => sum + _toDouble(v['descuento_total']));

  int get totalVentas => _ventas.where((v) => v['estado'] != 'anulada').length;
  int get totalAnuladas => _ventas.where((v) => v['estado'] == 'anulada').length;

  double get ticketPromedio => totalVentas == 0 ? 0 : totalDia / totalVentas;

  double get totalAbonos =>
      _abonos.fold(0.0, (sum, a) => sum + _toDouble(a['monto']));

  int get cantidadAbonos => _abonos.length;

  int get numDevoluciones =>
      _devoluciones.where((d) => _toStr(d['estado']) != 'cancelada').length;

  double get totalDevueltoProductos => _devoluciones
      .where((d) => _toStr(d['estado']) != 'cancelada')
      .fold(0.0, (sum, d) => sum + _toDouble(d['total_devuelto']));

  double get totalDevolucionesDinero => _devoluciones
      .where((d) =>
          _toStr(d['estado']) != 'cancelada' && _toStr(d['tipo']) == 'devolucion')
      .fold(0.0, (sum, d) => sum + _toDouble(d['total_devuelto']));

  double get totalCobradoCambios => _devoluciones
      .where((d) =>
          _toStr(d['estado']) != 'cancelada' &&
          _toStr(d['tipo']) == 'cambio' &&
          _toStr(d['tipo_diferencia']) == 'cobrar')
      .fold(0.0, (sum, d) => sum + _toDouble(d['diferencia']));

  double get totalDevueltoCambios => _devoluciones
      .where((d) =>
          _toStr(d['estado']) != 'cancelada' &&
          _toStr(d['tipo']) == 'cambio' &&
          _toStr(d['tipo_diferencia']) == 'devolver')
      .fold(0.0, (sum, d) => sum + _toDouble(d['diferencia']));

  int get numCambiosExactos => _devoluciones
      .where((d) =>
          _toStr(d['estado']) != 'cancelada' &&
          _toStr(d['tipo']) == 'cambio' &&
          _toStr(d['tipo_diferencia']) == 'exacto')
      .length;

  double get impactoCajaDevoluciones => _devoluciones.fold(
      0.0, (sum, d) => sum + _impactoCajaDevolucion(d));

  double get totalDevoluciones => impactoCajaDevoluciones.abs();

  double get totalNeto => totalDia + impactoCajaDevoluciones;

  List<Map<String, dynamic>> get productosDevueltos {
    final Map<String, Map<String, dynamic>> acum = {};
    for (final dev in _devoluciones.where((d) => _toStr(d['estado']) != 'cancelada')) {
      final detalles = dev['productos_devueltos'] is List
          ? dev['productos_devueltos'] as List
          : [];
      for (final d in detalles) {
        if (d is! Map) continue;
        final nombre = d['producto']?.toString() ?? '';
        final cantidad = _toDouble(d['cantidad']);
        final subtotal = _toDouble(d['subtotal']);
        if (acum.containsKey(nombre)) {
          acum[nombre]!['cantidad'] =
              (acum[nombre]!['cantidad'] as double) + cantidad;
          acum[nombre]!['subtotal'] =
              (acum[nombre]!['subtotal'] as double) + subtotal;
        } else {
          acum[nombre] = {
            'nombre': nombre,
            'cantidad': cantidad,
            'subtotal': subtotal,
          };
        }
      }
    }
    return acum.values.toList()
      ..sort((a, b) =>
          (b['cantidad'] as double).compareTo(a['cantidad'] as double));
  }

  Map<String, double> get totalPorMetodo {
    final Map<String, double> result = {};
    for (final v in _ventas.where((v) => v['estado'] != 'anulada')) {
      final metodo = v['metodo_pago']?.toString() ?? 'otro';
      final total = _toDouble(v['total']);
      result[metodo] = (result[metodo] ?? 0) + total;
    }
    return result;
  }

  Map<String, double> get totalPorTienda {
    final Map<String, double> result = {};
    for (final v in _ventas.where((v) => v['estado'] != 'anulada')) {
      final tienda = v['tienda_nombre']?.toString() ?? 'Sin tienda';
      final total = _toDouble(v['total']);
      result[tienda] = (result[tienda] ?? 0) + total;
    }
    return result;
  }

  List<Map<String, dynamic>> get topProductos {
    final Map<String, Map<String, dynamic>> acum = {};
    for (final v in _ventas.where((v) => v['estado'] != 'anulada')) {
      final detalles = v['detalles'] is List ? v['detalles'] as List : [];
      for (final d in detalles) {
        if (d is! Map) continue;
        final nombre = d['producto_nombre']?.toString() ?? '';
        final cantidad = _toDouble(d['cantidad']);
        final subtotal = _toDouble(d['subtotal']);
        if (acum.containsKey(nombre)) {
          acum[nombre]!['cantidad'] =
              (acum[nombre]!['cantidad'] as double) + cantidad;
          acum[nombre]!['subtotal'] =
              (acum[nombre]!['subtotal'] as double) + subtotal;
        } else {
          acum[nombre] = {
            'nombre': nombre,
            'cantidad': cantidad,
            'subtotal': subtotal,
          };
        }
      }
    }
    final lista = acum.values.toList()
      ..sort((a, b) =>
          (b['subtotal'] as double).compareTo(a['subtotal'] as double));
    return lista.take(5).toList();
  }

  Future<void> cargarVentas({int? tiendaId, String? fecha}) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    try {
      final resultados = await Future.wait([
        _service.listarVentas(tiendaId: tiendaId, fecha: fecha),
        _abonoService.listarAbonos(tiendaId: tiendaId, fecha: fecha),
        _contabilidadService.getDevolucionesDia(
          fecha ?? _fechaHoy(),
          tiendaId,
        ),
      ]);

      _ventas = resultados[0];
      _abonos = resultados[1];
      _devoluciones = resultados[2];
    } catch (e) {
      _errorMsg = 'Error al cargar reportes';
      debugPrint('❌ cargarVentas error: $e');
    }

    _cargando = false;
    notifyListeners();
  }

  String _fechaHoy() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}