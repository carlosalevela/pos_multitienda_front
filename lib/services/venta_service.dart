// lib/services/venta_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class VentaService {

  // ── Helper extractor de errores ────────────────────────
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      // ✅ FIX: detail primero — estándar DRF
      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('error'))  return data['error'].toString();
      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  // ── Crear venta ────────────────────────────────────────

  Future<Map<String, dynamic>> crearVenta({
    required int    tiendaId,
    required String metodoPago,
    required double montoRecibido,
    double          descuento = 0,
    int?            clienteId,
    required List<Map<String, dynamic>> detalles,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/ventas/',
        data: {
          'tienda':          tiendaId,
          'metodo_pago':     metodoPago,
          // ✅ FIX: números directos — no strings
          'monto_recibido':  montoRecibido,
          'descuento_total': descuento,
          if (clienteId != null) 'cliente': clienteId,
          'detalles': detalles,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al registrar la venta')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Listar ventas ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> listarVentas({
    int?    tiendaId,
    String? fecha,
    int?    sesionId,
    int?    clienteId,
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/ventas/lista/',
        queryParameters: {
          if (tiendaId  != null) 'tienda_id':  tiendaId.toString(),
          if (fecha     != null && fecha.isNotEmpty) 'fecha': fecha,
          if (sesionId  != null) 'sesion_id':  sesionId.toString(),
          if (clienteId != null) 'cliente_id': clienteId.toString(),
        },
      );
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      debugPrint('❌ listarVentas error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ listarVentas error: $e');
      return [];
    }
  }

  // ── Detalle de venta ───────────────────────────────────

  Future<Map<String, dynamic>?> obtenerVenta(int id) async {
    try {
      final response = await ApiClient.instance.get('/ventas/$id/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      debugPrint('❌ obtenerVenta error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ obtenerVenta error: $e');
      return null;
    }
  }

  // ── Anular venta ───────────────────────────────────────

  Future<Map<String, dynamic>> anularVenta(int id) async {
    try {
      final r = await ApiClient.instance.post('/ventas/$id/anular/');
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al anular la venta')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Disponibilidad para devolución ─────────────────────

  Future<Map<String, dynamic>?> ventaDisponibleDevolucion(int id) async {
    try {
      final r = await ApiClient.instance.get(
          '/ventas/$id/disponible-devolucion/');
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      debugPrint('❌ ventaDisponibleDevolucion error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ ventaDisponibleDevolucion error: $e');
      return null;
    }
  }
}