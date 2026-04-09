import 'package:flutter/material.dart';
import '../services/proveedor_service.dart';
import '../services/compra_service.dart';
import '../services/tienda_service.dart';
import '../core/api_client.dart';

class ProveedoresProvider extends ChangeNotifier {
  final _proveedorService = ProveedorService();
  final _compraService    = CompraService();
  final _tiendaService    = TiendaService();

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
  bool guardando = false;

  // ── Tiendas y categorías ──────────────────────────────
  List<Map<String, dynamic>> tiendasSimple    = [];
  List<Map<String, dynamic>> categoriasSimple = []; // ← nuevo

  // ─────────────────────────────────────────────────────
  // PROVEEDORES
  // ─────────────────────────────────────────────────────

  Future<void> cargarProveedores({String? q}) async {
    cargandoProveedores = true;
    errorProveedores    = null;
    notifyListeners();

    proveedores = await _proveedorService.listar(q: q);

    cargandoProveedores = false;
    notifyListeners();
  }

  Future<void> cargarProveedoresSimple() async {
    proveedoresSimple = await _proveedorService.listarSimple();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> obtenerProveedor(int id) =>
      _proveedorService.obtener(id);

  Future<bool> crearProveedor(Map<String, dynamic> data) async {
    guardando = true;
    notifyListeners();

    final res = await _proveedorService.crear(data);
    guardando = false;

    if (res['success'] == true) {
      await cargarProveedores();
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<bool> editarProveedor(int id, Map<String, dynamic> data) async {
    guardando = true;
    notifyListeners();

    final res = await _proveedorService.editar(id, data);
    guardando = false;

    if (res['success'] == true) {
      await cargarProveedores();
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<bool> eliminarProveedor(int id) async {
    final res = await _proveedorService.eliminar(id);
    if (res['success'] == true) {
      proveedores.removeWhere((p) => p['id'] == id);
      notifyListeners();
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────
  // COMPRAS
  // ─────────────────────────────────────────────────────

  Future<void> cargarCompras({int? tiendaId, String? estado}) async {
    cargandoCompras = true;
    errorCompras    = null;
    notifyListeners();

    compras = await _compraService.listar(
      tiendaId: tiendaId,
      estado:   estado,
    );

    cargandoCompras = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> obtenerCompra(int id) =>
      _compraService.obtener(id);

  Future<bool> crearCompra(Map<String, dynamic> data) async {
    guardando = true;
    notifyListeners();

    final res = await _compraService.crear(data);
    guardando = false;

    if (res['success'] == true) {
      await cargarCompras();
      return true;
    }

    notifyListeners();
    return false;
  }

    Future<Map<String, dynamic>?> recibirCompra(int id) async {
      guardando = true;
      notifyListeners();

      final res = await _compraService.recibir(id);

      guardando = false;

      if (res['success'] == true) {
        // Actualiza estado local sin recargar toda la lista
        final idx = compras.indexWhere((c) => c['id'] == id);
        if (idx != -1) {
          compras[idx] = {...compras[idx], 'estado': 'recibida'};
        }
        notifyListeners();
        return res['data']; // ← devuelve JSON completo con productos y códigos
      }

      notifyListeners();
      return null; // ← error
    }

  Future<bool> cancelarCompra(int id) async {
    final res = await _compraService.cancelar(id);
    if (res['success'] == true) {
      final idx = compras.indexWhere((c) => c['id'] == id);
      if (idx != -1) {
        compras[idx] = {...compras[idx], 'estado': 'cancelada'};
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────
  // TIENDAS
  // ─────────────────────────────────────────────────────

  Future<void> cargarTiendasSimple() async {
    tiendasSimple = await _tiendaService.getTiendasSimple();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  // CATEGORÍAS ← nuevo
  // ─────────────────────────────────────────────────────

  Future<void> cargarCategoriasSimple() async {
    try {
      final res = await ApiClient.instance.get('/productos/categorias/');
      categoriasSimple = List<Map<String, dynamic>>.from(res.data);
      notifyListeners();
    } catch (e) {
      categoriasSimple = [];
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────
  // PRODUCTOS — búsqueda
  // ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> buscarProductos({
    required String q,
    int? tiendaId,
  }) async {
    try {
      final res = await ApiClient.instance.get(
        '/productos/buscar/',
        queryParameters: {
          'q': q,
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
        },
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────
  // HELPERS / GETTERS
  // ─────────────────────────────────────────────────────

  int get totalProveedores => proveedores.length;

  int get totalComprasPendientes =>
      compras.where((c) => c['estado'] == 'pendiente').length;

  double get totalComprasRecibidas => compras
      .where((c) => c['estado'] == 'recibida')
      .fold(0.0, (sum, c) =>
          sum + (double.tryParse(c['total'].toString()) ?? 0));
}