import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/inventario_service.dart';

class InventarioProvider extends ChangeNotifier {
  final InventarioService _service = InventarioService();

  List<Producto> _productos = [];
  List<Map<String, dynamic>> _inventario = [];
  List<Map<String, dynamic>> _categorias = [];

  bool _cargandoProductos = false;
  bool _cargandoInventario = false;
  bool _cargandoCategorias = false;
  bool _guardando = false;

  String? _errorMsg;
  String? _successMsg;

  int? _tiendaIdActual;
  String _activoFiltro = 'true';

  List<Producto> get productos => _productos;
  List<Map<String, dynamic>> get inventario => _inventario;
  List<Map<String, dynamic>> get categorias => _categorias;

  bool get cargando => _cargandoProductos || _cargandoInventario;
  bool get cargandoProductos => _cargandoProductos;
  bool get cargandoInventario => _cargandoInventario;
  bool get cargandoCategorias => _cargandoCategorias;

  bool get guardando => _guardando;
  String? get errorMsg => _errorMsg;
  String? get successMsg => _successMsg;
  String get activoFiltro => _activoFiltro;
  int? get tiendaIdActual => _tiendaIdActual;

  // ── Cargar productos ──────────────────────────────────
  Future<void> cargarProductos({
    String? q,
    int? tiendaId,
    String activo = 'true',
  }) async {
    _tiendaIdActual = tiendaId;
    _activoFiltro = activo;
    _cargandoProductos = true;
    _errorMsg = null;
    notifyListeners();

    try {
      final result = await _service.getProductos(
        q: q,
        tiendaId: _tiendaIdActual,
        activo: activo,
      );

      if (result['success'] == true) {
        _productos = result['data'] as List<Producto>;
      } else {
        _errorMsg = result['error'] ?? 'Error al cargar productos';
        _successMsg = null; // evita mostrar éxito y error a la vez
        _productos = [];
      }
    } catch (e) {
      _errorMsg = 'Error al cargar productos';
      _successMsg = null;
      _productos = [];
    } finally {
      _cargandoProductos = false;
      notifyListeners();
    }
  }

  // ── Cargar inventario ─────────────────────────────────
  Future<void> cargarInventario({
    int? tiendaId,
    String? alerta,
    String activo = 'true',
  }) async {
    _tiendaIdActual = tiendaId;
    _activoFiltro = activo;
    _cargandoInventario = true;
    _errorMsg = null;
    notifyListeners();

    try {
      final result = await _service.getInventario(
        tiendaId: _tiendaIdActual,
        alerta: alerta,
        activo: activo,
      );

      if (result['success'] == true) {
        _inventario = result['data'] as List<Map<String, dynamic>>;
      } else {
        _errorMsg = result['error'] ?? 'Error al cargar inventario';
        _successMsg = null; // evita mostrar éxito y error a la vez
        _inventario = [];
      }
    } catch (e) {
      _errorMsg = 'Error al cargar inventario';
      _successMsg = null;
      _inventario = [];
    } finally {
      _cargandoInventario = false;
      notifyListeners();
    }
  }

  // ── Cargar categorías ─────────────────────────────────
  Future<void> cargarCategorias() async {
    _cargandoCategorias = true;
    notifyListeners();

    try {
      final result = await _service.getCategorias();

      if (result['success'] == true) {
        _categorias = result['data'] as List<Map<String, dynamic>>;
      } else {
        _errorMsg = result['error'] ?? 'Error al cargar categorías';
        _categorias = [];
      }
    } catch (e) {
      _errorMsg = 'Error al cargar categorías';
      _categorias = [];
    } finally {
      _cargandoCategorias = false;
      notifyListeners();
    }
  }

  // ── Ajustar stock ─────────────────────────────────────
  Future<bool> ajustarStock({
    required int    productoId,
    required int    tiendaId,
    required double cantidad,
    required String tipo,        // "entrada" | "salida" | "ajuste"
    String?         observacion,
  }) async {
    _guardando = true;
    _errorMsg = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.ajustarStock(
        productoId:  productoId,
        tiendaId:    tiendaId,
        cantidad:    cantidad,
        tipo:        tipo,
        observacion: observacion,
      );

      if (result['success'] == true) {
        _tiendaIdActual = tiendaId;
        _successMsg = 'Stock ajustado correctamente ✅';
        await cargarInventario(
          tiendaId: _tiendaIdActual,
          activo: _activoFiltro,
        );
        return true;
      }

      _errorMsg = result['error'] ?? 'Error al ajustar stock';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMsg = 'Error al ajustar stock';
      notifyListeners();
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Crear ─────────────────────────────────────────────
  Future<bool> crearProducto(Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg = null;
    _successMsg = null;
    notifyListeners();

    try {
      final tiendaId = data['tienda_id'] as int?;
      final result = await _service.crearProducto(data);

      if (result['success'] == true) {
        _tiendaIdActual = tiendaId ?? _tiendaIdActual;
        _successMsg = 'Producto creado correctamente ✅';
        await cargarProductos(
          tiendaId: _tiendaIdActual,
          activo: _activoFiltro,
        );
        return true;
      }

      _errorMsg = result['error'] ?? 'Error desconocido';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMsg = 'Error al crear producto';
      notifyListeners();
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Editar ────────────────────────────────────────────
  Future<bool> editarProducto(int id, Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.editarProducto(id, data);

      if (result['success'] == true) {
        _successMsg = 'Producto actualizado ✅';
        await cargarProductos(
          tiendaId: _tiendaIdActual,
          activo: _activoFiltro,
        );
        return true;
      }

      _errorMsg = result['error'] ?? 'Error desconocido';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMsg = 'Error al actualizar producto';
      notifyListeners();
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Eliminar (soft-delete → desactiva) ────────────────
  Future<bool> eliminarProducto(int id) async {
    _guardando = true;
    _errorMsg = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.eliminarProducto(id);

      if (result['success'] == true) {
        _successMsg = 'Producto desactivado ✅';
        await cargarProductos(
          tiendaId: _tiendaIdActual,
          activo: _activoFiltro,
        );
        return true;
      }

      _errorMsg = result['error'] ?? 'Error al desactivar';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMsg = 'Error al desactivar producto';
      notifyListeners();
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Reactivar ─────────────────────────────────────────
  Future<bool> reactivarProducto(int id) async {
    _guardando = true;
    _errorMsg = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.reactivarProducto(id);

      if (result['success'] == true) {
        _successMsg = 'Producto reactivado ✅';
        await cargarProductos(
          tiendaId: _tiendaIdActual,
          activo: _activoFiltro,
        );
        return true;
      }

      _errorMsg = result['error'] ?? 'Error al reactivar';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMsg = 'Error al reactivar producto';
      notifyListeners();
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Importar productos batch desde Excel ─────────────
  Future<Map<String, dynamic>> importarProductos({
    required List<Map<String, dynamic>> productos,
    required int tiendaId,
    int? empresaId,
  }) async {
    _guardando = true;
    _errorMsg = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.importarProductos(
        productos: productos,
        tiendaId: tiendaId,
        empresaId: empresaId,
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final creados = data['creados'] ?? 0;

        _tiendaIdActual = tiendaId;
        _successMsg = '$creados productos importados ✅';

        await cargarProductos(
          tiendaId: _tiendaIdActual,
          activo: _activoFiltro,
        );

        return result;
      }

      _errorMsg = result['error'] ?? 'Error al importar';
      notifyListeners();
      return result;
    } catch (e) {
      _errorMsg = 'Error al importar productos';
      notifyListeners();
      return {
        'success': false,
        'error': 'Error al importar productos',
      };
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Importar desde archivo Excel (raw) ───────────────
  Future<Map<String, dynamic>> importarProductosExcel({
    required List<int> fileBytes,
    required String    fileName,
    required int       tiendaId,
    int? empresaId,
  }) async {
    _guardando = true;
    _errorMsg  = null;
    _successMsg = null;
    notifyListeners();

    try {
      final result = await _service.importarProductosExcel(
        fileBytes:  fileBytes,
        fileName:   fileName,
        tiendaId:   tiendaId,
        empresaId:  empresaId,
      );

      if (result['success'] == true) {
        final data    = result['data'] as Map<String, dynamic>;
        final creados = data['creados'] ?? 0;
        _tiendaIdActual = tiendaId;
        _successMsg = '$creados productos importados ✅';
        await cargarProductos(tiendaId: _tiendaIdActual, activo: _activoFiltro);
        return result;
      }

      _errorMsg = result['error'] ?? 'Error al importar';
      notifyListeners();
      return result;
    } catch (e) {
      _errorMsg = 'Error al importar archivo';
      notifyListeners();
      return {'success': false, 'error': 'Error al importar archivo'};
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Utilidades ────────────────────────────────────────
  void limpiarMensajes() {
    _errorMsg = null;
    _successMsg = null;
    notifyListeners();
  }
}