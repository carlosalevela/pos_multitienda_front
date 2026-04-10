// lib/services/devoluciones_service.dart

import '../core/api_client.dart';
import '../models/devolucion_model.dart';

class DevolucionesService {

  // ── GET /api/devoluciones/lista/ ──────────────────
  Future<List<DevolucionModel>> getDevoluciones({
    int?    tiendaId,
    String? fecha,
    String? fechaIni,
    String? fechaFin,
    String? estado,
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/devoluciones/lista/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          if (fecha    != null) 'fecha':     fecha,
          if (fechaIni != null) 'fecha_ini': fechaIni,
          if (fechaFin != null) 'fecha_fin': fechaFin,
          if (estado   != null) 'estado':    estado,
        },
      );
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return data.map((e) => DevolucionModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // ── POST /api/devoluciones/ ───────────────────────
  Future<Map<String, dynamic>?> crearDevolucion({  // ✅ era Future<DevolucionModel?>
    required int                        ventaId,
    required String                     metodoPago,
    required List<Map<String, dynamic>> detalles,
    String? observaciones,
    int?    tiendaId,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/devoluciones/',
        data: {
          'venta':             ventaId,
          'metodo_devolucion': metodoPago,
          'detalles':          detalles,
          if (observaciones != null && observaciones.isNotEmpty)
            'observaciones': observaciones,
          if (tiendaId != null) 'tienda_id': tiendaId,
        },
      );
      return response.data as Map<String, dynamic>;  // ✅ era DevolucionModel.fromJson(...)
    } catch (e) {
      rethrow;
    }
  }

  // ── GET /api/devoluciones/<id>/ ───────────────────
  Future<DevolucionModel> getDevolucion(int id) async {
    try {
      final response =
          await ApiClient.instance.get('/devoluciones/$id/');
      return DevolucionModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  // ── POST /api/devoluciones/<id>/cancelar/ ─────────
  Future<bool> cancelarDevolucion({required int id}) async {
    try {
      await ApiClient.instance.post('/devoluciones/$id/cancelar/');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── GET /api/ventas/lista/ ────────────────────────
  Future<List<dynamic>> listarVentasPorFecha({
    String? fecha,
    int?    tiendaId,
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/ventas/lista/',
        queryParameters: {
          if (fecha    != null) 'fecha':     fecha,
          if (tiendaId != null && tiendaId != 0)
            'tienda_id': tiendaId.toString(),
        },
      );
      final data = response.data;
      return data is List ? data : (data['results'] ?? []);
    } catch (e) {
      rethrow;
    }
  }

  // ── GET /api/ventas/<id>/disponible-devolucion/ ───
  Future<Map<String, dynamic>> ventaDisponible(int ventaId) async {
    try {
      final response = await ApiClient.instance.get(
        '/ventas/$ventaId/disponible-devolucion/',
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}