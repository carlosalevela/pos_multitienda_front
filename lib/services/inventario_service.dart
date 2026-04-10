import '../core/api_client.dart';
import '../models/producto.dart';

class InventarioService {

  // ── Productos ─────────────────────────────────────────────

  Future<List<Producto>> getProductos({
    String? q,
    int?    tiendaId,
    String  activo = 'true',  // 'true' | 'false' | 'all'
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/productos/',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          'activo': activo,
        },
      );
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return data.map((e) => Producto.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearProducto(
      Map<String, dynamic> data) async {
    try {
      final response =
          await ApiClient.instance.post('/productos/', data: data);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al crear producto'),
      };
    }
  }

  Future<Map<String, dynamic>> editarProducto(
      int id, Map<String, dynamic> data) async {
    try {
      final response =
          await ApiClient.instance.patch('/productos/$id/', data: data);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al editar producto'),
      };
    }
  }

  // Soft-delete → pone activo=false en el backend
  Future<Map<String, dynamic>> eliminarProducto(int id) async {
    try {
      final response =
          await ApiClient.instance.delete('/productos/$id/');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al desactivar producto'),
      };
    }
  }

  // ✅ Reactivar producto (solo admin)
  Future<Map<String, dynamic>> reactivarProducto(int id) async {
    try {
      final response =
          await ApiClient.instance.patch('/productos/$id/reactivar/');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al reactivar producto'),
      };
    }
  }

  // ── Inventario ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInventario({
    int?    tiendaId,
    String? alerta,
    String  activo = 'true',  // 'true' | 'false' | 'all'
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/productos/inventario/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          if (alerta   != null) 'alerta':    alerta,
          'activo': activo,
        },
      );
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }

  // ── Helper ────────────────────────────────────────────────

  String _extractError(Object e, String fallback) {
    try {
      final dynamic err = (e as dynamic).response?.data;
      if (err is Map) {
        return err['error'] ?? err['detail'] ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }
}