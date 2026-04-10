import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/inventario_service.dart';


class InventarioProvider extends ChangeNotifier {
  final InventarioService _service = InventarioService();

  List<Producto> _productos  = [];
  bool           _cargando   = false;
  bool           _guardando  = false;
  String?        _errorMsg;    // ✅ nullable: null = sin error
  String?        _successMsg; // ✅ nullable: null = sin mensaje

  int?   _tiendaIdActual;
  String _activoFiltro = 'true';  // ✅ nuevo: estado del filtro activo

  List<Producto> get productos    => _productos;
  bool           get cargando     => _cargando;
  bool           get guardando    => _guardando;
  String?        get errorMsg     => _errorMsg;
  String?        get successMsg   => _successMsg;
  String         get activoFiltro => _activoFiltro;

  // ── Cargar ────────────────────────────────────────────────
  Future<void> cargarProductos({
    String? q,
    int?    tiendaId,
    String  activo = 'true',   // ✅ nuevo parámetro
  }) async {
    if (tiendaId != null) _tiendaIdActual = tiendaId;
    _activoFiltro = activo;   // ✅ guardamos para recargas
    _cargando     = true;
    _errorMsg     = null;
    notifyListeners();

    try {
      _productos = await _service.getProductos(
        q:        q,
        tiendaId: tiendaId ?? _tiendaIdActual,
        activo:   activo,
      );
    } catch (e) {
      // ✅ captura el rethrow del servicio y lo muestra
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Crear ─────────────────────────────────────────────────
  Future<bool> crearProducto(Map<String, dynamic> data) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    final tiendaId = data['tienda_id'] is int
        ? data['tienda_id'] as int
        : int.tryParse('${data['tienda_id'] ?? ''}');

    try {
      final result = await _service.crearProducto(data);

      if (result['success'] == true) {
        _successMsg = 'Producto creado correctamente ✅';
        await cargarProductos(
          tiendaId: tiendaId ?? _tiendaIdActual,
          activo:   _activoFiltro,  // ✅ respeta el filtro activo
        );
        return true;
      } else {
        _errorMsg = result['error'] ?? 'Error desconocido';
        return false;
      }
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Editar ────────────────────────────────────────────────
  Future<bool> editarProducto(int id, Map<String, dynamic> data) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.editarProducto(id, data);

      if (result['success'] == true) {
        _successMsg = 'Producto actualizado ✅';
        await cargarProductos(
          tiendaId: _tiendaIdActual,
          activo:   _activoFiltro,  // ✅ respeta el filtro activo
        );
        return true;
      } else {
        _errorMsg = result['error'] ?? 'Error desconocido';
        return false;
      }
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Eliminar (soft-delete → desactiva) ────────────────────
  Future<bool> eliminarProducto(int id) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.eliminarProducto(id);

      if (result['success'] == true) {
        _successMsg = 'Producto desactivado ✅';
        // ✅ actualiza localmente sin otro request
        _productos.removeWhere((p) => p.id == id);
        return true;
      } else {
        _errorMsg = result['error'] ?? 'Error al desactivar';
        return false;
      }
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Reactivar ─────────────────────────────────────────────
  Future<bool> reactivarProducto(int id) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.reactivarProducto(id);

      if (result['success'] == true) {
        _successMsg = 'Producto reactivado ✅';
        // ✅ actualiza localmente sin otro request
        _productos.removeWhere((p) => p.id == id);
        return true;
      } else {
        _errorMsg = result['error'] ?? 'Error al reactivar';
        return false;
      }
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Utilidades ────────────────────────────────────────────
  void limpiarMensajes() {
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();
  }
}