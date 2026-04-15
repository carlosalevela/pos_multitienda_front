// lib/providers/reportes_provider.dart

import 'package:flutter/foundation.dart';
import '../services/venta_service.dart';
import '../services/abono_service.dart';
import '../services/contabilidad_service.dart'; // ✅ NUEVO


class ReportesProvider extends ChangeNotifier {
  final VentaService         _service             = VentaService();
  final AbonoService         _abonoService        = AbonoService();
  final ContabilidadService  _contabilidadService = ContabilidadService(); // ✅

  List<Map<String, dynamic>> _ventas       = [];
  List<Map<String, dynamic>> _abonos       = [];
  List<Map<String, dynamic>> _devoluciones = []; // ✅ NUEVO
  bool   _cargando = false;
  String _errorMsg = '';

  List<Map<String, dynamic>> get ventas       => _ventas;
  List<Map<String, dynamic>> get abonos       => _abonos;
  List<Map<String, dynamic>> get devoluciones => _devoluciones; // ✅
  bool   get cargando => _cargando;
  String get errorMsg => _errorMsg;


  // ── KPIs ventas ───────────────────────────────────────

  double get totalDia => _ventas
      .where((v) => v['estado'] != 'anulada')
      .fold(0, (sum, v) => sum + (double.tryParse(v['total'].toString()) ?? 0));

  double get totalDescuentos => _ventas
      .where((v) => v['estado'] != 'anulada')
      .fold(0, (sum, v) =>
          sum + (double.tryParse(v['descuento_total'].toString()) ?? 0));

  int get totalVentas   => _ventas.where((v) => v['estado'] != 'anulada').length;
  int get totalAnuladas => _ventas.where((v) => v['estado'] == 'anulada').length;

  double get ticketPromedio =>
      totalVentas == 0 ? 0 : totalDia / totalVentas;

  double get totalAbonos => _abonos
      .fold(0, (sum, a) => sum + (double.tryParse(a['monto'].toString()) ?? 0));

  int get cantidadAbonos => _abonos.length;


  // ── KPIs devoluciones ✅ NUEVO ─────────────────────────

  /// Suma de total_devuelto de todas las devoluciones procesadas del día.
  double get totalDevoluciones => _devoluciones
      .fold(0, (sum, d) =>
          sum + (double.tryParse(d['total_devuelto']?.toString() ?? '0') ?? 0));

  int get numDevoluciones => _devoluciones.length;

  /// Ventas reales del día descontando devoluciones.
  double get totalNeto => totalDia - totalDevoluciones;

  /// Productos distintos devueltos en el día.
  List<Map<String, dynamic>> get productosDevueltos {
    final Map<String, Map<String, dynamic>> acum = {};
    for (final dev in _devoluciones) {
      final detalles = dev['productos_devueltos'] is List
          ? dev['productos_devueltos'] as List
          : [];
      for (final d in detalles) {
        if (d is! Map) continue;
        final nombre   = d['producto']?.toString() ?? '';
        final cantidad = double.tryParse(d['cantidad']?.toString() ?? '0') ?? 0;
        final subtotal = double.tryParse(d['subtotal']?.toString() ?? '0') ?? 0;
        if (acum.containsKey(nombre)) {
          acum[nombre]!['cantidad'] =
              (acum[nombre]!['cantidad'] as double) + cantidad;
          acum[nombre]!['subtotal'] =
              (acum[nombre]!['subtotal'] as double) + subtotal;
        } else {
          acum[nombre] = {
            'nombre':   nombre,
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


  // ── Ventas por método de pago ─────────────────────────

  Map<String, double> get totalPorMetodo {
    final Map<String, double> result = {};
    for (final v in _ventas.where((v) => v['estado'] != 'anulada')) {
      final metodo = v['metodo_pago']?.toString() ?? 'otro';
      final total  = double.tryParse(v['total'].toString()) ?? 0;
      result[metodo] = (result[metodo] ?? 0) + total;
    }
    return result;
  }


  // ── Ventas por tienda ─────────────────────────────────

  Map<String, double> get totalPorTienda {
    final Map<String, double> result = {};
    for (final v in _ventas.where((v) => v['estado'] != 'anulada')) {
      final tienda = v['tienda_nombre']?.toString() ?? 'Sin tienda';
      final total  = double.tryParse(v['total'].toString()) ?? 0;
      result[tienda] = (result[tienda] ?? 0) + total;
    }
    return result;
  }


  // ── Top productos ─────────────────────────────────────

  List<Map<String, dynamic>> get topProductos {
    final Map<String, Map<String, dynamic>> acum = {};
    for (final v in _ventas.where((v) => v['estado'] != 'anulada')) {
      final detalles = v['detalles'] is List ? v['detalles'] as List : [];
      for (final d in detalles) {
        if (d is! Map) continue;
        final nombre   = d['producto_nombre']?.toString() ?? '';
        final cantidad = double.tryParse(d['cantidad']?.toString()  ?? '0') ?? 0;
        final subtotal = double.tryParse(d['subtotal']?.toString()  ?? '0') ?? 0;
        if (acum.containsKey(nombre)) {
          acum[nombre]!['cantidad'] =
              (acum[nombre]!['cantidad'] as double) + cantidad;
          acum[nombre]!['subtotal'] =
              (acum[nombre]!['subtotal'] as double) + subtotal;
        } else {
          acum[nombre] = {
            'nombre':   nombre,
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


  // ── Carga ─────────────────────────────────────────────

  Future<void> cargarVentas({int? tiendaId, String? fecha}) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    try {
      // ✅ las 3 cargas en paralelo — devoluciones se suma sin romper las demás
      final resultados = await Future.wait([
        _service.listarVentas(tiendaId: tiendaId, fecha: fecha),
        _abonoService.listarAbonos(tiendaId: tiendaId, fecha: fecha),
        _contabilidadService.getDevolucionesDia(  // ✅ NUEVO
          fecha ?? _fechaHoy(),
          tiendaId,
        ),
      ]);

      _ventas       = resultados[0];
      _abonos       = resultados[1];
      _devoluciones = resultados[2]; // ✅
    } catch (e) {
      _errorMsg = 'Error al cargar reportes';
      debugPrint('❌ cargarVentas error: $e');
    }

    _cargando = false;
    notifyListeners();
  }

  // ── Helpers privados ──────────────────────────────────

  String _fechaHoy() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}'
           '-${now.day.toString().padLeft(2, '0')}';
  }
}