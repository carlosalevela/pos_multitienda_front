import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/tienda_model.dart';

class TiendaService {

  // ── Helper extractor de errores ────────────────────────
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      // ✅ captura tanto {'detail': '...'} como {'nombre': ['...']}
      if (data.containsKey('detail')) return data['detail'].toString();
      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  // ── Listado completo (admin) ───────────────────────────

  Future<List<Tienda>> getTiendas({bool? soloActivas}) async {
    try {
      final params = <String, dynamic>{};
      if (soloActivas != null) params['activo'] = soloActivas;
      final r = await ApiClient.instance.get(
        '/tiendas/', queryParameters: params);
      return (r.data as List).map((e) => Tienda.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('❌ getTiendas error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getTiendas error: $e');
      return [];
    }
  }

  // ── Dropdown liviano (todos los roles) ────────────────

  Future<List<Map<String, dynamic>>> getTiendasSimple() async {
    try {
      final r = await ApiClient.instance.get('/tiendas/simple/');
      return List<Map<String, dynamic>>.from(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getTiendasSimple error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getTiendasSimple error: $e');
      return [];
    }
  }

  // ── Crear tienda ───────────────────────────────────────
  // ✅ NO enviar empresa en data — el backend la inyecta desde el token

  Future<Map<String, dynamic>> crearTienda(Map<String, dynamic> data) async {
    try {
      // ✅ asegura que empresa no venga del formulario
      data.remove('empresa');
      final r = await ApiClient.instance.post('/tiendas/', data: data);
      return {'success': true, 'data': Tienda.fromJson(r.data)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear tienda')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Editar tienda ──────────────────────────────────────

  Future<Map<String, dynamic>> editarTienda(
      int id, Map<String, dynamic> data) async {
    try {
      data.remove('empresa');   // ✅ read_only en backend
      final r = await ApiClient.instance.patch('/tiendas/$id/', data: data);
      return {'success': true, 'data': Tienda.fromJson(r.data)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al editar tienda')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Desactivar tienda ──────────────────────────────────

  Future<Map<String, dynamic>> desactivarTienda(int id) async {
    try {
      final r = await ApiClient.instance.delete('/tiendas/$id/');
      return {'success': true, 'detail': r.data['detail']};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al desactivar tienda')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Empleados por tienda ───────────────────────────────

  Future<Map<String, dynamic>?> getEmpleadosPorTienda(int tiendaId) async {
    try {
      final r = await ApiClient.instance.get('/tiendas/$tiendaId/empleados/');
      return r.data;
    } on DioException catch (e) {
      debugPrint('❌ getEmpleadosPorTienda error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getEmpleadosPorTienda error: $e');
      return null;
    }
  }
}