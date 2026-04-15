// lib/services/inventario_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/producto.dart';

class InventarioService {

  // ── Helper extractor de errores ────────────────────────
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      // ✅ FIX: detail primero — estándar DRF, consistente con EmpleadoService
      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('error'))  return data['error'].toString();
      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  // ── Productos ──────────────────────────────────────────

  Future<List<Producto>> getProductos({
    String? q,
    int?    tiendaId,
    String  activo = 'true',
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/productos/',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          'activo': activo,
        },
      );
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return data.map((e) => Producto.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('❌ getProductos error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getProductos error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> crearProducto(
      Map<String, dynamic> data) async {
    try {
      // ✅ FIX: copia del mapa — no mutar el objeto del caller
      final payload = Map<String, dynamic>.from(data)..remove('empresa');
      final response = await ApiClient.instance.post(
          '/productos/', data: payload);
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear producto')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> editarProducto(
      int id, Map<String, dynamic> data) async {
    try {
      // ✅ FIX: copia del mapa — no mutar el objeto del caller
      final payload = Map<String, dynamic>.from(data)..remove('empresa');
      final response = await ApiClient.instance.patch(
          '/productos/$id/', data: payload);
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al editar producto')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> eliminarProducto(int id) async {
    try {
      final response = await ApiClient.instance.delete('/productos/$id/');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al desactivar producto')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> reactivarProducto(int id) async {
    try {
      final response = await ApiClient.instance.patch(
          '/productos/$id/reactivar/');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al reactivar producto')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Inventario ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInventario({
    int?    tiendaId,
    String? alerta,
    String  activo = 'true',
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/productos/inventario/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          if (alerta   != null) 'alerta':    alerta,
          'activo': activo,
        },
      );
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('❌ getInventario error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getInventario error: $e');
      return [];
    }
  }

  // ── Ajustar stock ──────────────────────────────────────

  Future<Map<String, dynamic>> ajustarStock({
    required int    productoId,
    required int    tiendaId,
    required int    cantidad,     // positivo = entrada, negativo = salida
    required String motivo,
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/productos/inventario/ajustar/',
        data: {
          'producto': productoId,
          'tienda':   tiendaId,
          'cantidad': cantidad,
          'motivo':   motivo,
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al ajustar stock')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Categorías ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategorias() async {
    try {
      final r = await ApiClient.instance.get('/productos/categorias/');
      final List data = r.data is List ? r.data : r.data['results'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('❌ getCategorias error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getCategorias error: $e');
      return [];
    }
  }
}