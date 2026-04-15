import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class AbonoService {

  // ── Helper extractor de errores ────────────────────────
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      if (data.containsKey('error'))  return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return fallback;
  }

  // ── Listar abonos ──────────────────────────────────────
  // ✅ usa ApiClient — hereda JWT refresh automático

  Future<List<Map<String, dynamic>>> listarAbonos({
    int?    tiendaId,
    String? fecha,
    int?    separadoId,   // ✅ filtro útil para detalle de separado
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/abonos/',
        queryParameters: {
          if (fecha      != null) 'fecha':       fecha,
          if (tiendaId   != null) 'tienda_id':   tiendaId.toString(),
          if (separadoId != null) 'separado_id': separadoId.toString(),
        },
      );
      // ✅ acepta {'abonos': [...]} o lista directa
      final raw = r.data;
      if (raw is Map && raw.containsKey('abonos')) {
        return List<Map<String, dynamic>>.from(raw['abonos']);
      }
      if (raw is List) return List<Map<String, dynamic>>.from(raw);
      return [];
    } on DioException catch (e) {
      debugPrint('❌ listarAbonos error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ listarAbonos error: $e');
      return [];
    }
  }

  // ── Crear abono manual ✅ NUEVO ────────────────────────

  Future<Map<String, dynamic>> crearAbono({
    required int    separadoId,
    required double monto,
    required String metodoPago,
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/clientes/separados/$separadoId/abonar/',
        data: {
          'monto':      monto,
          'metodo_pago': metodoPago,
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al registrar abono')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }
}