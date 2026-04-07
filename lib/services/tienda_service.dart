import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/tienda_model.dart';

class TiendaService {

  Future<List<Tienda>> getTiendas({bool? soloActivas}) async {
    try {
      final params = <String, dynamic>{};
      if (soloActivas != null) params['activo'] = soloActivas;
      final r = await ApiClient.instance.get('/tiendas/', queryParameters: params);
      return (r.data as List).map((e) => Tienda.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ getTiendas error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> crearTienda(Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.post('/tiendas/', data: data);
      return {'success': true, 'data': Tienda.fromJson(r.data)};
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['detail'] ?? 'Error al crear tienda';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> editarTienda(int id, Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.patch('/tiendas/$id/', data: data);
      return {'success': true, 'data': Tienda.fromJson(r.data)};
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['detail'] ?? 'Error al editar tienda';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<bool> desactivarTienda(int id) async {
    try {
      await ApiClient.instance.delete('/tiendas/$id/');
      return true;
    } catch (_) { return false; }
  }

  Future<Map<String, dynamic>?> getEmpleadosPorTienda(int tiendaId) async {
    try {
      final r = await ApiClient.instance.get('/tiendas/$tiendaId/empleados/');
      return r.data;
    } catch (e) {
      debugPrint('❌ getEmpleadosPorTienda error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTiendasSimple() async {
  try {
    final r = await ApiClient.instance.get('/tiendas/simple/');
    return List<Map<String, dynamic>>.from(r.data);
  } catch (e) {
    debugPrint('❌ getTiendasSimple error: $e');
    return [];
  }
}
}