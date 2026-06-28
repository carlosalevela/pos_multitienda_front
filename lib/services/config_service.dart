import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class ConfigService {

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

  // ── ConfigTienda ──────────────────────────────────────────

  Future<Map<String, dynamic>> getConfigTienda(int tiendaId) async {
    try {
      final r = await ApiClient.instance.get('/config/tienda/$tiendaId/');
      return {'success': true, 'data': Map<String, dynamic>.from(r.data as Map)};
    } on DioException catch (e) {
      debugPrint('❌ getConfigTienda error: ${e.response?.data}');
      return {'success': false, 'error': _extractError(e, 'Error al cargar configuración')};
    } catch (e) {
      debugPrint('❌ getConfigTienda error: $e');
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> patchConfigTienda(
    int tiendaId,
    Map<String, dynamic> datos,
  ) async {
    try {
      final r = await ApiClient.instance.patch(
        '/config/tienda/$tiendaId/',
        data: datos,
      );
      return {'success': true, 'data': Map<String, dynamic>.from(r.data as Map)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al guardar configuración')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── ConfigImpresión ───────────────────────────────────────

  Future<Map<String, dynamic>> getConfigImpresion(int tiendaId) async {
    try {
      final r = await ApiClient.instance.get('/config/impresion/$tiendaId/');
      return {'success': true, 'data': Map<String, dynamic>.from(r.data as Map)};
    } on DioException catch (e) {
      debugPrint('❌ getConfigImpresion error: ${e.response?.data}');
      return {'success': false, 'error': _extractError(e, 'Error al cargar config impresión')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> patchConfigImpresion(
    int tiendaId,
    Map<String, dynamic> datos,
  ) async {
    try {
      final r = await ApiClient.instance.patch(
        '/config/impresion/$tiendaId/',
        data: datos,
      );
      return {'success': true, 'data': Map<String, dynamic>.from(r.data as Map)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al guardar config impresión')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Defaults ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getDefaults() async {
    try {
      final r = await ApiClient.instance.get('/config/defaults/');
      return {'success': true, 'data': Map<String, dynamic>.from(r.data as Map)};
    } on DioException catch (e) {
      debugPrint('❌ getDefaults error: ${e.response?.data}');
      return {'success': false, 'error': _extractError(e, 'Error al cargar defaults')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Verificar caja antes de reportar ─────────────────────

  Future<Map<String, dynamic>> verificarReporte({int? tiendaId}) async {
    try {
      final r = await ApiClient.instance.get(
        '/caja/verificar-reporte/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
        },
      );
      return {
        'success':        true,
        'puede_reportar': r.data['puede_reportar'] as bool? ?? true,
        'cajas_abiertas': r.data['cajas_abiertas'] ?? [],
      };
    } on DioException catch (e) {
      debugPrint('❌ verificarReporte error: ${e.response?.data}');
      return {'success': false, 'error': _extractError(e, 'Error al verificar caja')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }
}
