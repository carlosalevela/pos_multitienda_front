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

  /// Devuelve {'success': bool, 'data': List<Producto>, 'error': String?}
  Future<Map<String, dynamic>> getProductos({
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
      final productos = data.map((e) => Producto.fromJson(e)).toList();
      return {'success': true, 'data': productos};
    } on DioException catch (e) {
      debugPrint('❌ getProductos error: ${e.response?.data}');
      return {
        'success': false,
        'data': <Producto>[],
        'error': _extractError(e, 'Error al cargar productos'),
      };
    } catch (e) {
      debugPrint('❌ getProductos error: $e');
      return {
        'success': false,
        'data': <Producto>[],
        'error': 'Error inesperado al cargar productos',
      };
    }
  }

  Future<Map<String, dynamic>> crearProducto(
      Map<String, dynamic> data) async {
    try {
      // ✅ FIX: se eliminó ..remove('empresa') — el backend sí lo necesita
      final payload = Map<String, dynamic>.from(data);
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
      // ✅ FIX: se eliminó ..remove('empresa') — el backend sí lo necesita
      final payload = Map<String, dynamic>.from(data);
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

  /// Devuelve {'success': bool, 'data': List<Map<String,dynamic>>, 'error': String?}
  Future<Map<String, dynamic>> getInventario({
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
      return {'success': true, 'data': data.cast<Map<String, dynamic>>()};
    } on DioException catch (e) {
      debugPrint('❌ getInventario error: ${e.response?.data}');
      return {
        'success': false,
        'data': <Map<String, dynamic>>[],
        'error': _extractError(e, 'Error al cargar inventario'),
      };
    } catch (e) {
      debugPrint('❌ getInventario error: $e');
      return {
        'success': false,
        'data': <Map<String, dynamic>>[],
        'error': 'Error inesperado al cargar inventario',
      };
    }
  }

  // ── Ajustar stock ──────────────────────────────────────

  Future<Map<String, dynamic>> ajustarStock({
    required int    productoId,
    required int    tiendaId,
    required double cantidad,
    required String tipo,       // "entrada" | "salida" | "ajuste"
    String?         observacion,
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/productos/$productoId/inventario/$tiendaId/ajustar/',
        data: {
          'tipo':     tipo,
          'cantidad': cantidad,
          if (observacion != null && observacion.isNotEmpty)
            'observacion': observacion,
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

  /// Devuelve {'success': bool, 'data': List<Map<String,dynamic>>, 'error': String?}
  Future<Map<String, dynamic>> getCategorias() async {
    try {
      final r = await ApiClient.instance.get('/productos/categorias/');
      final List data = r.data is List ? r.data : r.data['results'] ?? [];
      return {'success': true, 'data': data.cast<Map<String, dynamic>>()};
    } on DioException catch (e) {
      debugPrint('❌ getCategorias error: ${e.response?.data}');
      return {
        'success': false,
        'data': <Map<String, dynamic>>[],
        'error': _extractError(e, 'Error al cargar categorías'),
      };
    } catch (e) {
      debugPrint('❌ getCategorias error: $e');
      return {
        'success': false,
        'data': <Map<String, dynamic>>[],
        'error': 'Error inesperado al cargar categorías',
      };
    }
  }

  // ── Importar productos batch (JSON) ───────────────────

  Future<Map<String, dynamic>> importarProductos({
    required List<Map<String, dynamic>> productos,
    required int  tiendaId,
    int? empresaId,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/productos/importar/',
        data: {
          'tienda_id': tiendaId,
          if (empresaId != null) 'empresa': empresaId,
          'productos': productos,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al importar productos'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Dashboard KPIs ─────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard({
    int? tiendaId,
    int? empresaId,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/productos/dashboard/',
        queryParameters: {
          if (tiendaId  != null) 'tienda_id': tiendaId.toString(),
          if (empresaId != null) 'empresa':   empresaId.toString(),
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cargar dashboard')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Top productos ──────────────────────────────────────

  Future<Map<String, dynamic>> getTopProductos({
    int? tiendaId,
    int  limite = 5,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/productos/top-productos/',
        queryParameters: {
          'limite': limite.toString(),
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
        },
      );
      final List data = r.data is List ? r.data : [];
      return {'success': true, 'data': data.cast<Map<String, dynamic>>()};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cargar top productos')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Movimientos recientes ──────────────────────────────

  Future<Map<String, dynamic>> getMovimientosRecientes({
    int? tiendaId,
    int  limite = 8,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/productos/movimientos/recientes/',
        queryParameters: {
          'limite': limite.toString(),
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
        },
      );
      final List data = r.data is List ? r.data : [];
      return {'success': true, 'data': data.cast<Map<String, dynamic>>()};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cargar movimientos')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Exportar inventario a Excel ───────────────────────

  Future<Map<String, dynamic>> exportarInventario({
    int?   tiendaId,
    String activo = 'true',
    int?   empresaId,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/productos/inventario/exportar/',
        queryParameters: {
          if (tiendaId  != null) 'tienda_id': tiendaId.toString(),
          if (empresaId != null) 'empresa':   empresaId.toString(),
          'activo': activo,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return {'success': true, 'bytes': r.data as List<int>};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al exportar inventario'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado al exportar'};
    }
  }

  // ── Importar productos desde archivo Excel ─────────────

  Future<Map<String, dynamic>> importarProductosExcel({
    required List<int> fileBytes,
    required String    fileName,
    required int       tiendaId,
    int? empresaId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'tienda_id': tiendaId.toString(),
        if (empresaId != null) 'empresa': empresaId.toString(),
        'archivo': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });
      final response = await ApiClient.instance.post(
        '/productos/importar/',
        data: formData,
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al importar Excel'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }
}