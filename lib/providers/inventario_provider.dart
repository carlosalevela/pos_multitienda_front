// lib/providers/inventario_provider.dart

import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/inventario_service.dart';

class InventarioProvider extends ChangeNotifier {
  final InventarioService _service = InventarioService();

  List<Producto>             _productos  = [];
  List<Map<String, dynamic>> _inventario = [];
  List<Map<String, dynamic>> _categorias = [];

  bool    _cargando   = false;
  bool    _guardando  = false;
  String? _errorMsg;
  String? _successMsg;

  int?   _tiendaIdActual;
  String _activoFiltro = 'true';

  List<Producto>             get productos    => _productos;
  List<Map<String, dynamic>> get inventario   => _inventario;
  List<Map<String, dynamic>> get categorias   => _categorias;
  bool                       get cargando     => _cargando;
  bool                       get guardando    => _guardando;
  String?                    get errorMsg     => _errorMsg;
  String?                    get successMsg   => _successMsg;
  String                     get activoFiltro => _activoFiltro;

  // ── Cargar productos ──────────────────────────────────

  Future<void> cargarProductos({
    String? q,
    int?    tiendaId,
    String  activo = 'true',
  }) async {
    if (tiendaId != null) _tiendaIdActual = tiendaId;
    _activoFiltro = activo;
    _cargando     = true;
    _errorMsg     = null;
    notifyListeners();

    _productos = await _service.getProductos(
      q:        q,
      tiendaId: tiendaId ?? _tiendaIdActual,
      activo:   activo,
    );

    _cargando = false;
    notifyListeners();
  }

  // ── Cargar inventario ─────────────────────────────────

  Future<void> cargarInventario({
    int?    tiendaId,
    String? alerta,
    String  activo = 'true',
  }) async {
    if (tiendaId != null) _tiendaIdActual = tiendaId;
    _cargando = true;
    _errorMsg = null;
    notifyListeners();

    _inventario = await _service.getInventario(
      tiendaId: tiendaId ?? _tiendaIdActual,
      alerta:   alerta,
      activo:   activo,
    );

    _cargando = false;
    notifyListeners();
  }

  // ── Cargar categorías ─────────────────────────────────

  Future<void> cargarCategorias() async {
    _categorias = await _service.getCategorias();
    notifyListeners();
  }

  // ── Ajustar stock ─────────────────────────────────────

  Future<bool> ajustarStock({
    required int    productoId,
    required int    tiendaId,
    required int    cantidad,
    required String motivo,
  }) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    final result = await _service.ajustarStock(
      productoId: productoId,
      tiendaId:   tiendaId,
      cantidad:   cantidad,
      motivo:     motivo,
    );

    _guardando = false;

    if (result['success'] == true) {
      _successMsg = 'Stock ajustado correctamente ✅';
      await cargarInventario(tiendaId: tiendaId);
      // ✅ cargarInventario ya notifica — no se llama de nuevo
      return true;
    }

    _errorMsg = result['error'] ?? 'Error al ajustar stock';
    notifyListeners();
    return false;
  }

  // ── Crear ─────────────────────────────────────────────

  Future<bool> crearProducto(Map<String, dynamic> data) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    // ✅ FIX: cast directo — el dialog ya envía tienda_id como int
    final tiendaId = data['tienda_id'] as int?;

    final result = await _service.crearProducto(data);

    // ✅ FIX: _guardando + notifyListeners juntos antes de los paths
    _guardando = false;

    if (result['success'] == true) {
      _successMsg = 'Producto creado correctamente ✅';
      // ✅ FIX: cargarProductos ya notifica — sin doble notifyListeners
      await cargarProductos(
        tiendaId: tiendaId ?? _tiendaIdActual,
        activo:   _activoFiltro,
      );
      return true;
    }

    _errorMsg = result['error'] ?? 'Error desconocido';
    notifyListeners();
    return false;
  }

  // ── Editar ────────────────────────────────────────────

  Future<bool> editarProducto(int id, Map<String, dynamic> data) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    final result = await _service.editarProducto(id, data);

    _guardando = false;

    if (result['success'] == true) {
      _successMsg = 'Producto actualizado ✅';
      // ✅ FIX: sin doble notifyListeners
      await cargarProductos(
        tiendaId: _tiendaIdActual,
        activo:   _activoFiltro,
      );
      return true;
    }

    _errorMsg = result['error'] ?? 'Error desconocido';
    notifyListeners();
    return false;
  }

  // ── Eliminar (soft-delete → desactiva) ────────────────

  Future<bool> eliminarProducto(int id) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    final result = await _service.eliminarProducto(id);
    _guardando   = false;

    if (result['success'] == true) {
      _successMsg = 'Producto desactivado ✅';
      _productos.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    }

    _errorMsg = result['error'] ?? 'Error al desactivar';
    notifyListeners();
    return false;
  }

  // ── Reactivar ─────────────────────────────────────────

  Future<bool> reactivarProducto(int id) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    final result = await _service.reactivarProducto(id);
    _guardando   = false;

    if (result['success'] == true) {
      _successMsg = 'Producto reactivado ✅';
      _productos.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    }

    _errorMsg = result['error'] ?? 'Error al reactivar';
    notifyListeners();
    return false;
  }

    // ── Importar productos batch desde Excel ─────────────

  Future<Map<String, dynamic>> importarProductos({
    required List<Map<String, dynamic>> productos,
    required int  tiendaId,
    int?          empresaId,
  }) async {
    _guardando  = true;
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();

    final result = await _service.importarProductos(
      productos:  productos,
      tiendaId:   tiendaId,
      empresaId:  empresaId,
    );

    _guardando = false;

    if (result['success'] == true) {
      final data    = result['data'] as Map<String, dynamic>;
      final creados = data['creados'] ?? 0;
      _successMsg   = '$creados productos importados ✅';
      await cargarProductos(
        tiendaId: tiendaId,
        activo:   _activoFiltro,
      );
      return result;   // ← retorna el resultado completo para que el widget
    }                  //   muestre el detalle de fallidos

    _errorMsg = result['error'] ?? 'Error al importar';
    notifyListeners();
    return result;
  }

  // ── Utilidades ────────────────────────────────────────

  void limpiarMensajes() {
    _errorMsg   = null;
    _successMsg = null;
    notifyListeners();
  }
}