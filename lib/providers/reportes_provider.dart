import 'package:flutter/foundation.dart';
import '../services/venta_service.dart';
import '../services/abono_service.dart';

class ReportesProvider extends ChangeNotifier {
  final VentaService _service = VentaService();
  final AbonoService _abonoService = AbonoService(); 

  List<Map<String, dynamic>> _ventas = [];
  List<Map<String, dynamic>> _abonos = [];
  bool   _cargando = false;
  String _errorMsg = '';

  List<Map<String, dynamic>> get ventas   => _ventas;
   List<Map<String, dynamic>> get abonos  => _abonos;
  bool   get cargando => _cargando;
  String get errorMsg => _errorMsg;

  // ── KPIs principales ─────────────────────────────────

  double get totalDia => _ventas
      .where((v) => v['estado'] != 'anulada')
      .fold(0, (sum, v) => sum + (double.tryParse(v['total'].toString()) ?? 0));

  double get totalDescuentos => _ventas
      .where((v) => v['estado'] != 'anulada')
      .fold(0, (sum, v) =>
          sum + (double.tryParse(v['descuento_total'].toString()) ?? 0));

  int get totalVentas =>
      _ventas.where((v) => v['estado'] != 'anulada').length;

  int get totalAnuladas =>
      _ventas.where((v) => v['estado'] == 'anulada').length;

  double get ticketPromedio =>
      totalVentas == 0 ? 0 : totalDia / totalVentas;
  
   double get totalAbonos => _abonos
      .fold(0, (sum, a) => sum + (double.tryParse(a['monto'].toString()) ?? 0));

  int get cantidadAbonos => _abonos.length;

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

  // ── Ventas por tienda (para admin) ────────────────────

  Map<String, double> get totalPorTienda {
    final Map<String, double> result = {};
    for (final v in _ventas.where((v) => v['estado'] != 'anulada')) {
      final tienda = v['tienda_nombre']?.toString() ?? 'Sin tienda';
      final total  = double.tryParse(v['total'].toString()) ?? 0;
      result[tienda] = (result[tienda] ?? 0) + total;
    }
    return result;
  }

  // ── Top productos del día ─────────────────────────────

  List<Map<String, dynamic>> get topProductos {
    final Map<String, Map<String, dynamic>> acum = {};
    for (final v in _ventas.where((v) => v['estado'] != 'anulada')) {
      final detalles = v['detalles'] as List? ?? [];
      for (final d in detalles) {
        final nombre   = d['producto_nombre']?.toString() ?? '';
        final cantidad = double.tryParse(d['cantidad'].toString()) ?? 0;
        final subtotal = double.tryParse(d['subtotal'].toString()) ?? 0;
        if (acum.containsKey(nombre)) {
          acum[nombre]!['cantidad'] += cantidad;
          acum[nombre]!['subtotal'] += subtotal;
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
      ..sort((a, b) => (b['subtotal'] as double)
          .compareTo(a['subtotal'] as double));
    return lista.take(5).toList(); // top 5
  }

  // ── Carga ─────────────────────────────────────────────

  Future<void> cargarVentas({int? tiendaId, String? fecha}) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    final resultados = await Future.wait([
    _service.listarVentas(tiendaId: tiendaId, fecha: fecha),
    _abonoService.listarAbonos(tiendaId: tiendaId, fecha: fecha),
    ]);

    _ventas = resultados[0] as List<Map<String, dynamic>>;  // ✅
    _abonos = resultados[1] as List<Map<String, dynamic>>;  // ✅

    _cargando = false;
    notifyListeners();
  }
}