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
      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('error'))  return data['error'].toString();
      // Maneja errores anidados de DRF (ej: {"pagos": "Saldo insuficiente..."})
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
      final r = await ApiClient.instance.get('/ventas/$id/disponible-devolucion/');
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      debugPrint('❌ ventaDisponibleDevolucion error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ ventaDisponibleDevolucion error: $e');
      return null;
    }
  }


  // ── Cambio POS ─────────────────────────────────────────

  /// Procesa un cambio POS completo.
  ///
  /// [sesionCajaId]       → ID de la sesión de caja abierta
  /// [clienteId]          → ID del cliente (opcional)
  /// [detallesDevueltos]  → productos que el cliente trae de vuelta
  ///                        [ { "producto": 5, "cantidad": 1.0 }, ... ]
  /// [productosNuevos]    → carrito de reemplazo
  ///                        [ { "producto": 8, "cantidad": 1.0,
  ///                            "precio_unitario": 50000.0, "descuento": 0.0 }, ... ]
  /// [pagos]              → pagos adicionales en caja (puede ser lista vacía
  ///                        si el valor devuelto cubre el total nuevo)
  ///                        [ { "metodo": "efectivo", "monto": 10000.0 }, ... ]
  /// [observaciones]      → texto libre (opcional)

  Future<Map<String, dynamic>> procesarCambioPOS({
    required int sesionCajaId,
    int?         clienteId,
    required List<Map<String, dynamic>> detallesDevueltos,
    required List<Map<String, dynamic>> productosNuevos,
    List<Map<String, dynamic>>          pagos         = const [],
    String                              observaciones = '',
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/ventas/cambio-pos/',
        data: {
          'sesion_caja':         sesionCajaId,
          if (clienteId != null) 'cliente': clienteId,
          'detalles_devueltos':  detallesDevueltos,
          'productos_nuevos':    productosNuevos,
          'pagos':               pagos,
          'observaciones':       observaciones,
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      debugPrint('❌ procesarCambioPOS error: ${e.response?.data}');
      return {
        'success': false,
        'error': _extractError(e, 'Error al procesar el cambio POS'),
      };
    } catch (e) {
      debugPrint('❌ procesarCambioPOS error: $e');
      return {'success': false, 'error': 'Error inesperado'};
    }
  }
}
