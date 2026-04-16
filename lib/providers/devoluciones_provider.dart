
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

  // ── Cargar lista ──────────────────────────────────────

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
    }

    _cargando = false;
    notifyListeners();
  }

  // ── Crear devolución ──────────────────────────────────

  Future<Map<String, dynamic>> crearDevolucion({
    required int ventaId,
    required String metodoPago,
    required List<Map<String, dynamic>> detalles,
    String? observaciones,
  }) async {
    _error = null;

    final resp = await _devolucionService.crearDevolucion(
      ventaId: ventaId,
      metodoPago: metodoPago,
      detalles: detalles,
      observaciones: observaciones,
    );

    if (resp['success'] != true) {
      _error = resp['error']?.toString() ?? 'Error al crear devolución';
      notifyListeners();
    }

    return resp;
  }

  // ── Crear cambio con mensaje personalizado ──────────────

  Future<Map<String, dynamic>> crearCambio({
    required int ventaId,
    required String metodoPago,
    required List<Map<String, dynamic>> detalles,
    required int productoReemplazoId,
    required double cantidadReemplazo,
    String? observaciones,
  }) async {
    _error = null;

    final resp = await _devolucionService.crearCambio(
      ventaId: ventaId,
      metodoPago: metodoPago,
      detalles: detalles,
      productoReemplazoId: productoReemplazoId,
      cantidadReemplazo: cantidadReemplazo,
      observaciones: observaciones,
    );

    if (resp['success'] == true) {
      final data = resp['data'];

      // ← Generar mensaje inteligente para cambio
      resp['mensaje_ui'] = _generarMensajeCambio(data);

      // ← Refrescar lista para mostrar el cambio recién creado
      await cargarDevoluciones();
    } else {
      _error = resp['error']?.toString() ?? 'Error al procesar cambio';
      notifyListeners();
    }

    return resp;
  }

  // ← Helper para generar mensaje correcto del cambio
  String _generarMensajeCambio(Map<String, dynamic> data) {
    final diferencia = double.tryParse(data['diferencia'].toString()) ?? 0;
    final tipoDiferencia = data['tipo_diferencia']?.toString() ?? 'exacto';
    final prodNombre = data['producto_reemplazo']?['nombre']?.toString() ?? 'producto';
    final prodCantidad = data['producto_reemplazo']?['cantidad']?.toString() ?? '';

    if (tipoDiferencia == 'exacto') {
      return 'Cambio realizado ✅ $prodCantidad x $prodNombre, sin diferencia de dinero';
    } else if (tipoDiferencia == 'cobrar') {
      return 'Cambio realizado ✅ $prodCantidad x $prodNombre. Faltan ${data['diferencia']} por pagar';
    } else {
      return 'Cambio realizado ✅ $prodCantidad x $prodNombre. Devolver ${data['diferencia']} al cliente';
    }
  }

  // ── Cancelar devolución ───────────────────────────────

  Future<bool> cancelarDevolucion(int id) async {
    _error = null;

    final resp = await _devolucionService.cancelarDevolucion(id);

    if (resp['success'] == true) {
      final idx = _devoluciones.indexWhere((d) => d.id == id);
      if (idx >= 0) {
        _devoluciones[idx] = _devoluciones[idx].copyWith(estado: 'cancelada');
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
