import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/tienda_model.dart';

class TiendaService {
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;

    if (data is Map) {
      if (data.containsKey('detail')) return data['detail'].toString();

      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');

      return msgs.isNotEmpty ? msgs : fallback;
    }

    return fallback;
  }

  Future<List<Tienda>> getTiendas({
    bool? soloActivas,
    int? empresaId,
  }) async {
    try {
      final params = <String, dynamic>{};

      if (soloActivas != null) {
        params['activo'] = soloActivas;
      }
      if (empresaId != null) {
        params['empresa'] = empresaId;
      }

      final r = await ApiClient.instance.get(
        '/tiendas/',
        queryParameters: params,
      );

      return (r.data as List).map((e) => Tienda.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('❌ getTiendas error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getTiendas error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTiendasSimple({int? empresaId}) async {
    try {
      final params = <String, dynamic>{};
      if (empresaId != null) {
        params['empresa'] = empresaId;
      }

      final r = await ApiClient.instance.get(
        '/tiendas/simple/',
        queryParameters: params,
      );

      return List<Map<String, dynamic>>.from(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getTiendasSimple error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getTiendasSimple error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> crearTienda(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);

      final r = await ApiClient.instance.post(
        '/tiendas/',
        data: payload,
      );

      return {
        'success': true,
        'data': Tienda.fromJson(r.data),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al crear tienda'),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error inesperado',
      };
    }
  }

  Future<Map<String, dynamic>> editarTienda(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('empresa');
      payload.remove('empresa_id');

      final r = await ApiClient.instance.patch('/tiendas/$id/', data: payload);

      return {
        'success': true,
        'data': Tienda.fromJson(r.data),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al editar tienda'),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error inesperado',
      };
    }
  }

  Future<Map<String, dynamic>> desactivarTienda(int id) async {
    try {
      final r = await ApiClient.instance.delete('/tiendas/$id/');
      return {
        'success': true,
        'detail': r.data['detail'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al desactivar tienda'),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error inesperado',
      };
    }
  }

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