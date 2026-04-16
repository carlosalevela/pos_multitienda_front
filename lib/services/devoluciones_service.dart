import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/devolucion_model.dart';

class DevolucionesService {
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;

    if (data is Map) {
      if (data.containsKey('error')) return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();

      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');

      return msgs.isNotEmpty ? msgs : fallback;
    }

    return fallback;
  }

  Future<List<DevolucionModel>> getDevoluciones({
    int? tiendaId,
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
          if (fecha != null) 'fecha': fecha,
          if (fechaIni != null) 'fechaIni': fechaIni,
          if (fechaFin != null) 'fechaFin': fechaFin,
          if (estado != null) 'estado': estado,
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

  Future<Map<String, dynamic>> crearDevolucion({
    required int ventaId,
    required String metodoPago,
    required List<Map<String, dynamic>> detalles,
    String? observaciones,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/devoluciones/',
        data: {
          'venta': ventaId,
          'metodo_devolucion': metodoPago,
          'detalles': detalles,
          if (observaciones != null && observaciones.isNotEmpty)
            'observaciones': observaciones,
        },
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al registrar devolución'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> crearCambio({
    required int ventaId,
    required String metodoPago,
    required List<Map<String, dynamic>> detalles,
    required int productoReemplazoId,
    required double cantidadReemplazo,
    String? observaciones,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/devoluciones/cambio/',
        data: {
          'venta': ventaId,
          'metodo_devolucion': metodoPago,
          'detalles': detalles,
          'producto_reemplazo': productoReemplazoId,
          'cantidad_reemplazo': cantidadReemplazo,
          if (observaciones != null && observaciones.isNotEmpty)
            'observaciones': observaciones,
        },
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al procesar cambio'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> cancelarDevolucion(int id) async {
    try {
      final r = await ApiClient.instance.post('/devoluciones/$id/cancelar/');
      return {
        'success': true,
        'detail': r.data?['detail'] ?? 'Devolución cancelada',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al cancelar devolución'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }
}