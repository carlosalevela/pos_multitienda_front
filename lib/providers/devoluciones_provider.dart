import 'package:flutter/foundation.dart';
import '../models/devolucion_model.dart';
import '../services/devoluciones_service.dart';

class DevolucionesProvider extends ChangeNotifier {
  final _devolucionService = DevolucionesService();

  List<DevolucionModel> _devoluciones = [];
  bool _cargando = false;
  String? _error;

  List<DevolucionModel> get devoluciones => _devoluciones;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarDevoluciones({
    int? tiendaId,
    String? fecha,
    String? fechaIni,
    String? fechaFin,
    String? estado,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _devoluciones = await _devolucionService.getDevoluciones(
        tiendaId: tiendaId,
        fecha: fecha,
        fechaIni: fechaIni,
        fechaFin: fechaFin,
        estado: estado,
      );
    } catch (e) {
      _error = 'Error al cargar devoluciones';
      debugPrint('❌ cargarDevoluciones: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> crearDevolucion({
    required int ventaId,
    required String metodoPago,
    required List<Map<String, dynamic>> detalles,
    String? observaciones,
    int?    cuentaDestinoId,
  }) async {
    _error = null;
    try {
      final resp = await _devolucionService.crearDevolucion(
        ventaId: ventaId,
        metodoPago: metodoPago,
        detalles: detalles,
        observaciones: observaciones,
        cuentaDestinoId: cuentaDestinoId,
      );

      if (resp['success'] != true) {
        _error = resp['error']?.toString() ?? 'Error al crear devolución';
        notifyListeners();
      }

      return resp;
    } catch (e) {
      _error = 'Error al crear devolución';
      debugPrint('❌ crearDevolucion: $e');
      notifyListeners();
      return {'success': false, 'error': _error};
    }
  }

  Future<Map<String, dynamic>> crearCambio({
    required int ventaId,
    required String metodoPago,
    required List<Map<String, dynamic>> detalles,
    required int productoReemplazoId,
    required double cantidadReemplazo,
    String? observaciones,
    String? metodoPagoDiferencia,
    double? montoRecibido,
    int?    cuentaDestinoId,
  }) async {
    _error = null;
    try {
      final resp = await _devolucionService.crearCambio(
        ventaId: ventaId,
        metodoPago: metodoPago,
        detalles: detalles,
        productoReemplazoId: productoReemplazoId,
        cantidadReemplazo: cantidadReemplazo,
        observaciones: observaciones,
        metodoPagoDiferencia: metodoPagoDiferencia,
        montoRecibido: montoRecibido,
        cuentaDestinoId: cuentaDestinoId,
      );

      if (resp['success'] == true) {
        final rawData = resp['data'];
        final data = rawData is Map<String, dynamic>
            ? rawData
            : Map<String, dynamic>.from(rawData as Map);

        resp['mensaje_ui'] = _generarMensajeCambio(data);

        await cargarDevoluciones();
      } else {
        _error = resp['error']?.toString() ?? 'Error al procesar cambio';
        notifyListeners();
      }

      return resp;
    } catch (e) {
      _error = 'Error al procesar cambio';
      debugPrint('❌ crearCambio: $e');
      notifyListeners();
      return {'success': false, 'error': _error};
    }
  }

  String _generarMensajeCambio(Map<String, dynamic> data) {
    final diferencia = double.tryParse(data['diferencia']?.toString() ?? '') ?? 0;
    final tipoDiferencia = data['tipo_diferencia']?.toString() ?? 'exacto';

    final productoRaw = data['producto_reemplazo'];
    final producto = productoRaw is Map<String, dynamic>
        ? productoRaw
        : (productoRaw is Map ? Map<String, dynamic>.from(productoRaw) : null);

    final prodNombre = producto?['nombre']?.toString() ?? 'producto';
    final prodCantidad = producto?['cantidad']?.toString() ?? '';

    if (tipoDiferencia == 'exacto') {
      return 'Cambio realizado ✅ $prodCantidad x $prodNombre, sin diferencia de dinero';
    } else if (tipoDiferencia == 'cobrar') {
      return 'Cambio realizado ✅ $prodCantidad x $prodNombre. Faltan $diferencia por pagar';
    } else {
      return 'Cambio realizado ✅ $prodCantidad x $prodNombre. Devolver $diferencia al cliente';
    }
  }

  Future<bool> cancelarDevolucion(int id) async {
    _error = null;
    try {
      final resp = await _devolucionService.cancelarDevolucion(id);

      if (resp['success'] == true) {
        final idx = _devoluciones.indexWhere((d) => d.id == id);
        if (idx >= 0) {
          _devoluciones[idx] = _devoluciones[idx].copyWith(estado: 'cancelada');
        }
        notifyListeners();
        return true;
      }

      _error = resp['error']?.toString() ?? 'Error al cancelar';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error al cancelar devolución';
      debugPrint('❌ cancelarDevolucion: $e');
      notifyListeners();
      return false;
    }
  }
}