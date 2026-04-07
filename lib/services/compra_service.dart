import '../core/api_client.dart';

class CompraService {

  // ── Lista con filtros ─────────────────────────────────
  Future<List<Map<String, dynamic>>> listar({
    int?    tiendaId,
    String? estado,
  }) async {
    try {
      final res = await ApiClient.instance.get(
        '/proveedores/compras/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          if (estado   != null) 'estado':    estado,
        },
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      return [];
    }
  }

  // ── Detalle con detalles[] ────────────────────────────
  Future<Map<String, dynamic>?> obtener(int id) async {
    try {
      final res = await ApiClient.instance.get('/proveedores/compras/$id/');
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return null;
    }
  }

  // ── Crear orden de compra ─────────────────────────────
  Future<Map<String, dynamic>> crear(Map<String, dynamic> data) async {
    try {
      final res = await ApiClient.instance.post(
        '/proveedores/compras/',
        data: data,
      );
      return {'success': true, 'data': res.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al crear la orden de compra'};
    }
  }

  // ── Recibir → actualiza inventario ────────────────────
  Future<Map<String, dynamic>> recibir(int id) async {
    try {
      final res = await ApiClient.instance.post(
        '/proveedores/compras/$id/recibir/',
      );
      return {'success': true, 'data': res.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al recibir la compra'};
    }
  }

  // ── Cancelar (solo admin) ─────────────────────────────
  Future<Map<String, dynamic>> cancelar(int id) async {
    try {
      final res = await ApiClient.instance.post(
        '/proveedores/compras/$id/cancelar/',
      );
      return {'success': true, 'data': res.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al cancelar la compra'};
    }
  }
}