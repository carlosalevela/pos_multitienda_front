// lib/providers/devoluciones_provider.dart

import 'package:flutter/foundation.dart';
import '../models/devolucion_model.dart';
import '../services/devoluciones_service.dart';   // ← import del servicio

class DevolucionesProvider extends ChangeNotifier {

  // ✅ FIX: instancia declarada correctamente
  final _devolucionService = DevolucionesService();

  List<DevolucionModel> _devoluciones = [];
  bool    _cargando = false;
  String? _error;

  List<DevolucionModel> get devoluciones => _devoluciones;
  bool    get cargando => _cargando;
  String? get error    => _error;

  // ── Cargar lista ─────────────────────────────────────
  Future<void> cargarDevoluciones({
    int?    tiendaId,
    String? fecha,
    String? fechaIni,
    String? fechaFin,
    String? estado,
  }) async {
    _cargando = true;
    _error    = null;
    notifyListeners();

    try {
      _devoluciones = await _devolucionService.getDevoluciones(
        tiendaId: tiendaId,
        fecha:    fecha,
        fechaIni: fechaIni,
        fechaFin: fechaFin,
        estado:   estado,
      );
    } catch (e) {
      _error = 'Error al cargar devoluciones';
      debugPrint('❌ cargarDevoluciones: $e');
    }

    _cargando = false;
    notifyListeners();
  }

  // ── Crear devolución (efectivo / transferencia / etc.) ─
  Future<Map<String, dynamic>> crearDevolucion({
    required int    ventaId,
    required String metodoPago,
    required List<Map<String, dynamic>> detalles,
    String? observaciones,
    int?    tiendaId,
  }) async {
    _error = null;

    final resp = await _devolucionService.crearDevolucion(
      ventaId:       ventaId,
      metodoPago:    metodoPago,
      detalles:      detalles,
      observaciones: observaciones,
    );

    if (resp['success'] != true) {
      _error = resp['error']?.toString() ?? 'Error al crear devolución';
      notifyListeners();
    }

    return resp;   // ✅ siempre {'success': bool, 'error': '...' o 'data': ...}
  }

  // ── Crear devolución POR CAMBIO DE PRODUCTO ───────────
  // Recibe el Map que devuelve DevolucionProductoSheet:
  //   { 'productos': [...], 'total_nuevo': x, 'diferencia': y }
  Future<Map<String, dynamic>> crearCambioProducto(
      Map<String, dynamic> result) async {
    _error = null;

    // Convierte los productos del carrito al formato que espera el backend
    final detalles = (result['productos'] as List).map((p) => {
      'producto':       p['producto_id'],
      'cantidad':       p['cantidad'],
      'precio_unitario': p['precio'],
      // motivo opcional si lo agregas al carrito luego
    }).toList();

    final resp = await _devolucionService.crearDevolucion(
      ventaId:    0,             // ← ajusta si tienes ventaId disponible
      metodoPago: 'cambio_producto',
      detalles:   detalles,
      observaciones:
          'Cambio de producto. '
          'Diferencia: \$${result['diferencia']}',
    );

    if (resp['success'] != true) {
      _error = resp['error']?.toString() ?? 'Error al registrar cambio';
      notifyListeners();
    }

    return resp;
  }

  // ── Cancelar devolución ───────────────────────────────
  Future<bool> cancelarDevolucion(int id) async {
    _error = null;

    final resp = await _devolucionService.cancelarDevolucion(id);

    if (resp['success'] == true) {
      // remueve de la lista local o actualiza estado
      final idx = _devoluciones.indexWhere((d) => d.id == id);
      if (idx >= 0) {
        // si el modelo tiene copyWith: _devoluciones[idx] = _devoluciones[idx].copyWith(estado: 'cancelada');
        // si no, recargamos la lista directamente en la UI con aplicarFiltro()
      }
      notifyListeners();
      return true;
    } else {
      _error = resp['error']?.toString() ?? 'Error al cancelar';
      notifyListeners();
      return false;
    }
  }
}