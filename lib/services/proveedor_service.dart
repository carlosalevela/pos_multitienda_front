import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class ProveedorService {

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

  // ── Lista + búsqueda ───────────────────────────────────

  Future<List<Map<String, dynamic>>> listar({String? q}) async {
    try {
      final res = await ApiClient.instance.get(
        '/proveedores/',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
        },
      );
      final List data = res.data is List
          ? res.data
          : res.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      debugPrint('❌ listarProveedores error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ listarProveedores error: $e');
      return [];
    }
  }

  // ── Lista simple (dropdowns) ───────────────────────────

  Future<List<Map<String, dynamic>>> listarSimple() async {
    try {
      final res = await ApiClient.instance.get('/proveedores/simple/');
      return List<Map<String, dynamic>>.from(res.data);
    } on DioException catch (e) {
      debugPrint('❌ listarSimpleProveedores error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ listarSimpleProveedores error: $e');
      return [];
    }
  }

  // ── Detalle ────────────────────────────────────────────

  Future<Map<String, dynamic>?> obtener(int id) async {
    try {
      final res = await ApiClient.instance.get('/proveedores/$id/');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      debugPrint('❌ obtenerProveedor error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ obtenerProveedor error: $e');
      return null;
    }
  }

  // ── Crear ──────────────────────────────────────────────
  // ✅ empresa NO se envía — backend la inyecta desde el token

  Future<Map<String, dynamic>> crear(Map<String, dynamic> data) async {
    try {
      data.remove('empresa');   // ✅
      final res = await ApiClient.instance.post('/proveedores/', data: data);
      return {'success': true, 'data': res.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear proveedor')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Editar ─────────────────────────────────────────────

  Future<Map<String, dynamic>> editar(
      int id, Map<String, dynamic> data) async {
    try {
      data.remove('empresa');   // ✅
      final res = await ApiClient.instance.patch(
          '/proveedores/$id/', data: data);
      return {'success': true, 'data': res.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al editar proveedor')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Desactivar (soft delete) ───────────────────────────

  Future<Map<String, dynamic>> eliminar(int id) async {
    try {
      final res = await ApiClient.instance.delete('/proveedores/$id/');
      // ✅ retorna detail del backend para mostrarlo en la UI
      return {'success': true, 'detail': res.data?['detail'] ?? 'Proveedor desactivado'};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al eliminar proveedor')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }
}