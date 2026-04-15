import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class CompraService {

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

  // ── Lista con filtros ──────────────────────────────────

  Future<List<Map<String, dynamic>>> listar({
    int?    tiendaId,
    String? estado,
    String? fechaIni,   // ✅ filtros de rango útiles para reportes
    String? fechaFin,
  }) async {
    try {
      final res = await ApiClient.instance.get(
        '/proveedores/compras/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          if (estado   != null) 'estado':    estado,
          if (fechaIni != null) 'fecha_ini': fechaIni,
          if (fechaFin != null) 'fecha_fin': fechaFin,
        },
      );
      // ✅ maneja lista directa o paginada
      final List data = res.data is List
          ? res.data
          : res.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      debugPrint('❌ listarCompras error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ listarCompras error: $e');
      return [];
    }
  }

  // ── Detalle ────────────────────────────────────────────

  Future<Map<String, dynamic>?> obtener(int id) async {
    try {
      final res = await ApiClient.instance.get(
          '/proveedores/compras/$id/');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      debugPrint('❌ obtenerCompra error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ obtenerCompra error: $e');
      return null;
    }
  }

  // ── Crear orden de compra ──────────────────────────────
  // ✅ empresa NO se envía — backend la inyecta desde el token

  Future<Map<String, dynamic>> crear(Map<String, dynamic> data) async {
    try {
      data.remove('empresa');   // ✅
      final res = await ApiClient.instance.post(
        '/proveedores/compras/', data: data);
      return {'success': true, 'data': res.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear la orden de compra')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Recibir → actualiza inventario ────────────────────

  Future<Map<String, dynamic>> recibir(int id) async {
    try {
      final res = await ApiClient.instance.post(
          '/proveedores/compras/$id/recibir/');
      return {'success': true, 'data': res.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al recibir la compra')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Cancelar (solo admin) ──────────────────────────────

  Future<Map<String, dynamic>> cancelar(int id) async {
    try {
      final res = await ApiClient.instance.post(
          '/proveedores/compras/$id/cancelar/');
      return {'success': true, 'data': res.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cancelar la compra')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }
}