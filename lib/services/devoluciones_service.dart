import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/devolucion_model.dart';

class DevolucionesService {

  // ── Helper extractor de errores ────────────────────────
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      if (data.containsKey('error'))  return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  // ── Listar devoluciones ────────────────────────────────

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
    } on DioException catch (e) {
      debugPrint('❌ getDevoluciones error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getDevoluciones error: $e');
      return [];
    }
  }

  // ── Detalle de devolución ──────────────────────────────

  Future<DevolucionModel?> getDevolucion(int id) async {
    try {
      final response = await ApiClient.instance.get('/devoluciones/$id/');
      return DevolucionModel.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('❌ getDevolucion error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getDevolucion error: $e');
      return null;
    }
  }

  // ── Crear devolución ───────────────────────────────────
  // ✅ tienda_id NO se envía — el backend la inyecta desde el token

  Future<Map<String, dynamic>> crearDevolucion({
    required int                        ventaId,
    required String                     metodoPago,
    required List<Map<String, dynamic>> detalles,
    String? observaciones,
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
          // ✅ tienda_id eliminado — backend lo toma del token
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al registrar devolución')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Cancelar devolución ────────────────────────────────

    Future<Map<String, dynamic>> cancelarDevolucion(int id) async {
    try {
      final r = await ApiClient.instance.post('/devoluciones/$id/cancelar/');
      // ✅ FIX: null-safe
      return {
        'success': true,
        'detail':  r.data?['detail'] ?? 'Devolución cancelada',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cancelar devolución')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Ventas disponibles ─────────────────────────────────
  // ✅ estos métodos usan VentaService — no duplicar aquí
  //
  //  En el provider o screen:
  //    final ventas = await VentaService().listarVentas(tiendaId: id, fecha: f);
  //    final disp   = await VentaService().ventaDisponibleDevolucion(ventaId);
}