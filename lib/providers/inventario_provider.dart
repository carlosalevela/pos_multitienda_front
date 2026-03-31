import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/inventario_service.dart';

class InventarioProvider extends ChangeNotifier {
  final InventarioService _service = InventarioService();

  List<Producto> _productos  = [];
  bool   _cargando   = false;
  bool   _guardando  = false;
  String _errorMsg   = '';
  String _successMsg = '';

  // ✅ Guardamos el tiendaId activo para reutilizarlo en recargas
  int? _tiendaIdActual;

  List<Producto> get productos  => _productos;
  bool   get cargando   => _cargando;
  bool   get guardando  => _guardando;
  String get errorMsg   => _errorMsg;
  String get successMsg => _successMsg;

  Future<void> cargarProductos({String? q, int? tiendaId}) async {
    // ✅ Persistimos el tiendaId para usarlo en recargas posteriores
    if (tiendaId != null) _tiendaIdActual = tiendaId;

    _cargando = true;
    notifyListeners();

    // ✅ Siempre usamos el tiendaId guardado si no se pasa uno nuevo
    _productos = await _service.getProductos(
      q:        q,
      tiendaId: tiendaId ?? _tiendaIdActual,
    );

    _cargando = false;
    notifyListeners();
  }

  // ✅ Firma compatible con onGuardar: solo recibe `data`
  // El tiendaId ya viene dentro de data['tienda_id'] (inyectado en el dialog)
  Future<bool> crearProducto(Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();

    // ✅ Extraemos tiendaId desde data para la recarga posterior
    final tiendaId = data['tienda_id'] is int
        ? data['tienda_id'] as int
        : int.tryParse('${data['tienda_id'] ?? ''}');

    final result = await _service.crearProducto(data);
    _guardando = false;

    if (result['success']) {
      _successMsg = '✅ Producto creado correctamente';
      // ✅ Recarga con tiendaId correcto → stock se muestra bien
      await cargarProductos(tiendaId: tiendaId ?? _tiendaIdActual);
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }

    notifyListeners();
    return result['success'] as bool;
  }

  Future<bool> editarProducto(int id, Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();

    final result = await _service.editarProducto(id, data);
    _guardando = false;

    if (result['success']) {
      _successMsg = '✅ Producto actualizado';
      // ✅ Usa el tiendaId guardado
      await cargarProductos(tiendaId: _tiendaIdActual);
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }

    notifyListeners();
    return result['success'] as bool;
  }

  Future<bool> eliminarProducto(int id) async {
    final ok = await _service.eliminarProducto(id);
    if (ok) {
      _productos.removeWhere((p) => p.id == id);
      _successMsg = '🗑️ Producto eliminado';
      notifyListeners();
    }
    return ok;
  }

  void limpiarMensajes() {
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }
}