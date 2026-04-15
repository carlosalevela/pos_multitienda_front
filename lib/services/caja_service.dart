import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/sesion_caja.dart';
import '../models/resumen_cierre.dart';

class CajaService {

  // ── Helper extractor de errores ────────────────────────
  // ✅ FIX: maneja listas de validación {'monto_inicial': ['...']}
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

  // ── Sesión activa ──────────────────────────────────────

  Future<SesionCaja?> getSesionActiva(int tiendaId) async {
    if (tiendaId <= 0) return null;
    try {
      final r = await ApiClient.instance.get('/caja/activa/$tiendaId/');
      return SesionCaja.fromJson(r.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      debugPrint('❌ getSesionActiva error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getSesionActiva error: $e');
      return null;
    }
  }

  // ── Resumen pre-cierre ─────────────────────────────────

  Future<ResumenCierre?> getResumenCierre(int sesionId) async {
    try {
      final r = await ApiClient.instance.get('/caja/$sesionId/resumen-cierre/');
      return ResumenCierre.fromJson(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getResumenCierre error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getResumenCierre error: $e');
      return null;
    }
  }

  // ── Abrir caja ─────────────────────────────────────────

  Future<Map<String, dynamic>> abrirCaja({
    required double saldoInicial,
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/caja/abrir/',
        data: {'monto_inicial': saldoInicial},
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        // ✅ FIX: cast seguro — evita CastError si data es String o List
        final raw  = e.response?.data;
        final data = raw is Map ? Map<String, dynamic>.from(raw) : null;

        final sesionId = data?['sesion_id'];
        if (sesionId != null) {
          return {
            'success':    false,
            'ya_abierta': true,
            'sesion_id':  sesionId,
            'error':      data?['error'] ?? 'La caja ya está abierta',
          };
        }
        return {
          'success': false,
          'error':   data?['error'] ?? 'Error al abrir la caja',
        };
      }
      return {'success': false, 'error': _extractError(e, 'Error de conexión')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Cerrar caja ────────────────────────────────────────

  Future<Map<String, dynamic>> cerrarCaja(
    int sesionId, {
    required double montoFinalReal,
    String observaciones = '',
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/caja/$sesionId/cerrar/',
        data: {
          'monto_final_real': montoFinalReal.toString(),
          'observaciones':    observaciones,
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cerrar la caja')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Historial de sesiones ──────────────────────────────

  Future<List<Map<String, dynamic>>> getHistorialSesiones({
    int?    tiendaId,
    String? estado,
    String? fecha,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/caja/sesiones/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          if (estado   != null) 'estado':    estado,
          if (fecha    != null) 'fecha':     fecha,
        },
      );
      final List data = r.data is List ? r.data : r.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      debugPrint('❌ getHistorialSesiones error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getHistorialSesiones error: $e');
      return [];
    }
  }
}