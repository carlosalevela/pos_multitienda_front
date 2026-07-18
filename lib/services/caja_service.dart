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

  /// Retorna la sesión activa, null si no hay sesión (404),
  /// o lanza [Exception] si hay error de red/servidor (para que el provider
  /// pueda conservar el estado anterior en lugar de asumir "sin caja").
  Future<SesionCaja?> getSesionActiva(int tiendaId) async {
    if (tiendaId <= 0) return null;
    try {
      final r = await ApiClient.instance.get('/caja/activa/$tiendaId/');
      return SesionCaja.fromJson(r.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      debugPrint('❌ getSesionActiva error: ${e.response?.data}');
      throw Exception('network');
    } catch (e) {
      debugPrint('❌ getSesionActiva error: $e');
      throw Exception('network');
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

  // ── Dashboard Caja Admin ───────────────────────────────

  Future<Map<String, dynamic>> getDashboardCaja({
    int?   tiendaId,
    String periodo  = 'mensual',
    int?   empresaId,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/caja/dashboard/',
        queryParameters: {
          if (tiendaId  != null) 'tienda_id': tiendaId.toString(),
          if (empresaId != null) 'empresa':   empresaId.toString(),
          'periodo': periodo,
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cargar el dashboard de caja')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Gastos de sesión ──────────────────────────────────

  Future<Map<String, dynamic>> getGastosSesion(int sesionId) async {
    try {
      final r = await ApiClient.instance.get('/caja/$sesionId/gastos/');
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      debugPrint('❌ getGastosSesion error: ${e.response?.data}');
      return {'success': false, 'error': _extractError(e, 'Error al cargar gastos')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> registrarGasto({
    required int    sesionId,
    required int    tiendaId,
    required String categoria,
    required String descripcion,
    required double monto,
    required String metodoPago,
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/contabilidad/gastos/',
        data: {
          'sesion_caja': sesionId,
          'tienda':      tiendaId,
          'categoria':   categoria,
          'descripcion': descripcion,
          'monto':       monto.toStringAsFixed(2),
          'metodo_pago': metodoPago,
          'visibilidad': 'todos',
          'tipo_gasto':  'variable',
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al registrar gasto')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Historial de sesiones ──────────────────────────────

  Future<List<Map<String, dynamic>>> getHistorialSesiones({
    int?    tiendaId,
    String? estado,
    String? fecha,
    bool    misSesiones = false,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/caja/historial/',
        queryParameters: {
          if (tiendaId    != null) 'tienda_id':    tiendaId.toString(),
          if (estado      != null) 'estado':       estado,
          if (fecha       != null) 'fecha':        fecha,
          if (misSesiones)         'mis_sesiones': 'true',
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