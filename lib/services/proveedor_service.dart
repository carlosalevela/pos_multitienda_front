import '../core/api_client.dart';

class ProveedorService {

  // ── Lista + búsqueda ──────────────────────────────────
  Future<List<Map<String, dynamic>>> listar({String? q}) async {
    try {
      final res = await ApiClient.instance.get(
        '/proveedores/',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      return [];
    }
  }

  // ── Lista simple (para dropdowns) ─────────────────────
  Future<List<Map<String, dynamic>>> listarSimple() async {
    try {
      final res = await ApiClient.instance.get('/proveedores/simple/');
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      return [];
    }
  }

  // ── Detalle ───────────────────────────────────────────
  Future<Map<String, dynamic>?> obtener(int id) async {
    try {
      final res = await ApiClient.instance.get('/proveedores/$id/');
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return null;
    }
  }

  // ── Crear ─────────────────────────────────────────────
  Future<Map<String, dynamic>> crear(Map<String, dynamic> data) async {
    try {
      final res = await ApiClient.instance.post('/proveedores/', data: data);
      return {'success': true, 'data': res.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al crear el proveedor'};
    }
  }

  // ── Editar ────────────────────────────────────────────
  Future<Map<String, dynamic>> editar(int id, Map<String, dynamic> data) async {
    try {
      final res = await ApiClient.instance.patch('/proveedores/$id/', data: data);
      return {'success': true, 'data': res.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al editar el proveedor'};
    }
  }

  // ── Desactivar (soft delete) ──────────────────────────
  Future<Map<String, dynamic>> eliminar(int id) async {
    try {
      await ApiClient.instance.delete('/proveedores/$id/');
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Error al eliminar el proveedor'};
    }
  }
}