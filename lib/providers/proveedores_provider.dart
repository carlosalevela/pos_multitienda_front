// lib/providers/proveedores_provider.dart

import 'package:flutter/material.dart';
import '../services/proveedor_service.dart';
import '../services/compra_service.dart';
import '../services/tienda_service.dart';
import '../services/inventario_service.dart';

class ProveedoresProvider extends ChangeNotifier {
  final _proveedorService  = ProveedorService();
  final _compraService     = CompraService();
  final _tiendaService     = TiendaService();
  final _inventarioService = InventarioService();

  // ── Estado proveedores ────────────────────────────────
  List<Map<String, dynamic>> proveedores       = [];
  List<Map<String, dynamic>> proveedoresSimple = [];
  bool    cargandoProveedores = false;
  String? errorProveedores;

  // ── Estado compras ────────────────────────────────────
  List<Map<String, dynamic>> compras      = [];
  bool    cargandoCompras = false;
  String? errorCompras;

  // ── Estado formulario / operación ─────────────────────
  bool    guardando  = false;
  String? errorMsg;
  String? successMsg;

  // ── Tiendas y categorías ──────────────────────────────
  List<Map<String, dynamic>> tiendasSimple    = [];
  List<Map<String, dynamic>> categoriasSimple = [];

  void limpiarMensajes() {
    errorMsg   = null;
    successMsg = null;
    notifyListeners();
  }

  // ── Proveedores ───────────────────────────────────────

  Future<void> cargarProveedores({String? q}) async {
    cargandoProveedores = true;
    errorProveedores    = null;
    notifyListeners();

    // ✅ FIX: try/catch — evita spinner infinito si la red falla
    try {
      proveedores = await _proveedorService.listar(q: q);
    } catch (e) {
      errorProveedores = 'Error al cargar proveedores';
    } finally {
      cargandoProveedores = false;
      notifyListeners();
    }
  }

  Future<void> cargarProveedoresSimple() async {
    try {
      proveedoresSimple = await _proveedorService.listarSimple();
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> obtenerProveedor(int id) =>
      _proveedorService.obtener(id);

  Future<bool> crearProveedor(Map<String, dynamic> data) async {
    guardando = true;
    errorMsg  = null;
    notifyListeners();

    try {
      final res = await _proveedorService.crear(data);

      if (res['success'] == true) {
        successMsg = '✅ Proveedor creado correctamente';
        // ✅ FIX: notificar antes del reload para que el botón deje de girar
        guardando = false;
        notifyListeners();
        await cargarProveedores();
        return true;
      }

      errorMsg = res['error'] ?? 'Error al crear proveedor';
      return false;
    } catch (e) {
      errorMsg = 'Error inesperado al crear proveedor';
      return false;
    } finally {
      // ✅ FIX: always reset guardando aunque haya excepción
      guardando = false;
      notifyListeners();
    }
  }

  Future<bool> editarProveedor(int id, Map<String, dynamic> data) async {
    guardando = true;
    errorMsg  = null;
    notifyListeners();

    try {
      final res = await _proveedorService.editar(id, data);

      if (res['success'] == true) {
        successMsg = '✅ Proveedor actualizado';
        guardando  = false;
        notifyListeners();
        await cargarProveedores();
        return true;
      }

      errorMsg = res['error'] ?? 'Error al editar proveedor';
      return false;
    } catch (e) {
      errorMsg = 'Error inesperado al editar proveedor';
      return false;
    } finally {
      guardando = false;
      notifyListeners();
    }
  }

  Future<bool> eliminarProveedor(int id) async {
    try {
      final res = await _proveedorService.eliminar(id);

      if (res['success'] == true) {
        proveedores.removeWhere((p) => p['id'] == id);
        successMsg = '🗑️ Proveedor desactivado';
        notifyListeners();
        return true;
      }

      errorMsg = res['error'] ?? 'Error al eliminar proveedor';
      notifyListeners();
      return false;
    } catch (e) {
      errorMsg = 'Error inesperado al desactivar proveedor';
      notifyListeners();
      return false;
    }
  }

  // ── Compras ───────────────────────────────────────────

  Future<void> cargarCompras({int? tiendaId, String? estado}) async {
    cargandoCompras = true;
    errorCompras    = null;
    notifyListeners();

    // ✅ FIX: try/catch — evita spinner infinito
    try {
      compras = await _compraService.listar(
        tiendaId: tiendaId,
        estado:   estado,
      );
    } catch (e) {
      errorCompras = 'Error al cargar compras';
    } finally {
      cargandoCompras = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> obtenerCompra(int id) =>
      _compraService.obtener(id);

  Future<bool> crearCompra(Map<String, dynamic> data) async {
    guardando = true;
    errorMsg  = null;
    notifyListeners();

    try {
      final res = await _compraService.crear(data);

      if (res['success'] == true) {
        successMsg = '✅ Compra registrada correctamente';
        guardando  = false;
        notifyListeners();
        await cargarCompras();
        return true;
      }

      errorMsg = res['error'] ?? 'Error al crear compra';
      return false;
    } catch (e) {
      errorMsg = 'Error inesperado al registrar compra';
      return false;
    } finally {
      guardando = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> recibirCompra(int id) async {
    guardando = true;
    errorMsg  = null;
    notifyListeners();

    try {
      final res = await _compraService.recibir(id);

      if (res['success'] == true) {
        final idx = compras.indexWhere((c) => c['id'] == id);
        if (idx != -1) {
          compras[idx] = {...compras[idx], 'estado': 'recibida'};
        }
        successMsg = '✅ Compra recibida correctamente';
        notifyListeners();
        return res['data'];
      }

      errorMsg = res['error'] ?? 'Error al recibir compra';
      notifyListeners();
      return null;
    } catch (e) {
      errorMsg = 'Error inesperado al recibir compra';
      notifyListeners();
      return null;
    } finally {
      guardando = false;
      notifyListeners();
    }
  }

  Future<bool> cancelarCompra(int id) async {
    try {
      final res = await _compraService.cancelar(id);

      if (res['success'] == true) {
        final idx = compras.indexWhere((c) => c['id'] == id);
        if (idx != -1) {
          compras[idx] = {...compras[idx], 'estado': 'cancelada'};
        }
        successMsg = '✅ Compra cancelada';
        notifyListeners();
        return true;
      }

      errorMsg = res['error'] ?? 'Error al cancelar compra';
      notifyListeners();
      return false;
    } catch (e) {
      errorMsg = 'Error inesperado al cancelar compra';
      notifyListeners();
      return false;
    }
  }

  // ── Tiendas ───────────────────────────────────────────

  Future<void> cargarTiendasSimple() async {
    try {
      tiendasSimple = await _tiendaService.getTiendasSimple();
      notifyListeners();
    } catch (_) {}
  }

  // ── Categorías ────────────────────────────────────────

  Future<void> cargarCategoriasSimple() async {
    try {
      categoriasSimple = await _inventarioService.getCategorias();
      notifyListeners();
    } catch (_) {}
  }

  // ── Productos — búsqueda ──────────────────────────────

  Future<List<Map<String, dynamic>>> buscarProductos({
    required String q,
    int? tiendaId,
  }) async {
    try {
      final productos = await _inventarioService.getProductos(
        q:        q,
        tiendaId: tiendaId,
      );
      return productos.map((p) => p.toJson()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Getters ───────────────────────────────────────────

  // ✅ FIX: solo cuenta proveedores activos
  int get totalProveedores =>
      proveedores.where((p) => p['activo'] == true).length;

  int get totalComprasPendientes =>
      compras.where((c) => c['estado'] == 'pendiente').length;

  double get totalComprasRecibidas => compras
      .where((c) => c['estado'] == 'recibida')
      .fold(0.0, (sum, c) =>
          sum + (double.tryParse(c['total'].toString()) ?? 0));
}