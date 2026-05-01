import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../models/separado.dart';
import '../core/api_client.dart';

class ClienteService {

  // ── Helper extractor de errores ────────────────────────────
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

  // ── Helper para parsear lista o paginado ───────────────────
  List _parseList(dynamic data) =>
      data is List ? data : (data['results'] as List? ?? []);


  // ══════════════════════════════════════════════════════════
  // CLIENTES
  // ══════════════════════════════════════════════════════════

  Future<List<Cliente>> getClientes({String? q, int? tiendaId}) async {
  try {
    final params = {
      if (q        != null && q.isNotEmpty) 'q':         q,
      if (tiendaId != null)                 'tienda_id': tiendaId,
    };
    debugPrint('🔍 getClientes params: $params');
    final r = await ApiClient.instance.get(
      '/clientes/',
      queryParameters: params,
    );
    debugPrint('🔍 getClientes response: ${r.data}');
    return _parseList(r.data)
        .map((e) => Cliente.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    debugPrint('❌ getClientes: ${e.response?.data}');
    rethrow;
  }
}

  Future<List<Cliente>> getClientesSimple({String? q}) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/simple/',
        queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
      );
      return _parseList(r.data)
          .map((e) => Cliente.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('❌ getClientesSimple: ${e.response?.data}');
      rethrow;
    }
  }

  Future<Cliente?> getCliente(int id) async {
    try {
      final r = await ApiClient.instance.get('/clientes/$id/');
      return Cliente.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('❌ getCliente: ${e.response?.data}');
      return null;
    }
  }

  Future<Map<String, dynamic>> crearCliente(
      Map<String, dynamic> data) async {
    try {
      data.remove('empresa');
      final r = await ApiClient.instance.post('/clientes/', data: data);
      return {
        'success': true,
        'data': Cliente.fromJson(r.data as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear cliente')};
    } catch (_) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> editarCliente(
      int id, Map<String, dynamic> data) async {
    try {
      data.remove('empresa');
      final r = await ApiClient.instance.patch('/clientes/$id/', data: data);
      return {
        'success': true,
        'data': Cliente.fromJson(r.data as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al editar cliente')};
    } catch (_) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> desactivarCliente(int id) async {
    try {
      final r = await ApiClient.instance.delete('/clientes/$id/');
      return {
        'success': true,
        'detail': r.data?['detail'] ?? 'Cliente desactivado',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al desactivar cliente')};
    } catch (_) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> activarCliente(int id) async {
    try {
      final r = await ApiClient.instance.patch(
        '/clientes/$id/',
        data: {'activo': true},
      );
      return {
        'success': true,
        'data': Cliente.fromJson(r.data as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al activar cliente')};
    } catch (_) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }


  // ══════════════════════════════════════════════════════════
  // SEPARADOS
  // ══════════════════════════════════════════════════════════

  Future<List<Separado>> getSeparados({
    int?          tiendaId,
    String?       estado,
    List<String>? estados,   // ← Opción B: múltiples estados
    int?          clienteId,
  }) async {
    // ✅ Validación: no usar ambos a la vez
    assert(
      !(estado != null && estados != null),
      'Usa "estado" o "estados", no ambos simultáneamente.',
    );
    try {
      final r = await ApiClient.instance.get(
        '/clientes/separados/',
        queryParameters: {
          if (tiendaId  != null) 'tienda_id':  tiendaId,
          if (estado    != null) 'estado':      estado,
          if (estados   != null) 'estado__in':  estados.join(','), // ← csv para Django
          if (clienteId != null) 'cliente_id':  clienteId,
        },
      );
      return _parseList(r.data)
          .map((e) => Separado.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('❌ getSeparados: ${e.response?.data}');
      rethrow;
    }
  }

  Future<Separado?> getSeparado(int id) async {
    try {
      final r = await ApiClient.instance.get('/clientes/separados/$id/');
      return Separado.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('❌ getSeparado: ${e.response?.data}');
      return null;
    }
  }

  Future<Map<String, dynamic>> crearSeparado(
      Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.post(
          '/clientes/separados/', data: data);
      return {
        'success': true,
        'data': Separado.fromJson(r.data as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear separado')};
    } catch (_) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> abonarSeparado(
      int id, double monto, String metodoPago) async {
    try {
      final r = await ApiClient.instance.post(
        '/clientes/separados/$id/abonar/',
        data: {
          'monto':       monto.toStringAsFixed(2),
          'metodo_pago': metodoPago,
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al registrar abono')};
    } catch (_) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> cancelarSeparado(int id) async {
    try {
      final r = await ApiClient.instance.post(
          '/clientes/separados/$id/cancelar/');
      return {
        'success': true,
        'detail': r.data?['detail'] ?? 'Separado cancelado',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cancelar separado')};
    } catch (_) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> getAlertasSeparados({int? tiendaId}) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/separados/alertas/',
        queryParameters: {if (tiendaId != null) 'tienda_id': tiendaId},
      );
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      debugPrint('❌ getAlertasSeparados: ${e.response?.data}');
      return {'vencidos': [], 'por_vencer': [], 'total_alertas': 0};
    } catch (_) {
      return {'vencidos': [], 'por_vencer': [], 'total_alertas': 0};
    }
  }

  Future<Map<String, dynamic>> getAbonosPorFecha({
    required String fecha,
    int? tiendaId,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/separados/abonos/',
        queryParameters: {
          'fecha': fecha,
          if (tiendaId != null) 'tienda_id': tiendaId,
        },
      );
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      debugPrint('❌ getAbonosPorFecha: ${e.response?.data}');
      return {'abonos': [], 'total': 0.0};
    } catch (_) {
      return {'abonos': [], 'total': 0.0};
    }
  }
}