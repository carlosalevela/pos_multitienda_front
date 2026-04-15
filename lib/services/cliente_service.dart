import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../models/separado.dart';
import '../core/api_client.dart';

class ClienteService {

  // ── Helper extractor de errores ────────────────────────
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

  // ── Clientes ───────────────────────────────────────────

  Future<List<Cliente>> getClientes({String? q}) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/',
        queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
      );
      // ✅ FIX: soporta respuesta paginada y lista plana
      final List data = r.data is List ? r.data : r.data['results'] ?? [];
      return data.map((e) => Cliente.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('❌ getClientes error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getClientes error: $e');
      return [];
    }
  }

  Future<List<Cliente>> getClientesSimple({String? q}) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/simple/',
        queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
      );
      // ✅ FIX: mismo patrón seguro
      final List data = r.data is List ? r.data : r.data['results'] ?? [];
      return data.map((e) => Cliente.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('❌ getClientesSimple error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getClientesSimple error: $e');
      return [];
    }
  }

  Future<Cliente?> getCliente(int id) async {
    try {
      final r = await ApiClient.instance.get('/clientes/$id/');
      return Cliente.fromJson(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getCliente error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getCliente error: $e');
      return null;
    }
  }

  // ── Crear / editar / desactivar ────────────────────────

  Future<Map<String, dynamic>> crearCliente(
      Map<String, dynamic> data) async {
    try {
      data.remove('empresa');
      final r = await ApiClient.instance.post('/clientes/', data: data);
      return {'success': true, 'data': Cliente.fromJson(r.data)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear cliente')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> editarCliente(
      int id, Map<String, dynamic> data) async {
    try {
      data.remove('empresa');
      final r = await ApiClient.instance.patch('/clientes/$id/', data: data);
      return {'success': true, 'data': Cliente.fromJson(r.data)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al editar cliente')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> desactivarCliente(int id) async {
    try {
      final r = await ApiClient.instance.delete('/clientes/$id/');
      // ✅ FIX: null-safe en detail
      return {
        'success': true,
        'detail':  r.data?['detail'] ?? 'Cliente desactivado',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al desactivar cliente')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Separados ──────────────────────────────────────────

  Future<List<Separado>> getSeparados({
    int? tiendaId, String? estado, int? clienteId,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/separados/',
        queryParameters: {
          if (tiendaId  != null) 'tienda_id':  tiendaId,
          if (estado    != null) 'estado':      estado,
          if (clienteId != null) 'cliente_id':  clienteId,
        },
      );
      // ✅ FIX: soporta paginación
      final List data = r.data is List ? r.data : r.data['results'] ?? [];
      return data.map((e) => Separado.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('❌ getSeparados error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getSeparados error: $e');
      return [];
    }
  }

  Future<Separado?> getSeparado(int id) async {
    try {
      final r = await ApiClient.instance.get('/clientes/separados/$id/');
      return Separado.fromJson(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getSeparado error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getSeparado error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> crearSeparado(
      Map<String, dynamic> data) async {
    try {
      data.remove('empresa');
      final r = await ApiClient.instance.post(
        '/clientes/separados/', data: data);
      return {'success': true, 'data': Separado.fromJson(r.data)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear separado')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> abonarSeparado(
      int id, double monto, String metodoPago) async {
    try {
      final r = await ApiClient.instance.post(
        '/clientes/separados/$id/abonar/',
        data: {'monto': monto, 'metodo_pago': metodoPago},
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al registrar abono')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> cancelarSeparado(int id) async {
    try {
      final r = await ApiClient.instance.post(
        '/clientes/separados/$id/cancelar/');
      // ✅ FIX: null-safe en detail
      return {
        'success': true,
        'detail':  r.data?['detail'] ?? 'Separado cancelado',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cancelar separado')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> getAlertasSeparados({int? tiendaId}) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/separados/alertas/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId,
        },
      );
      // ✅ FIX: cast seguro — evita CastError si data no es exactamente Map<String, dynamic>
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      debugPrint('❌ getAlertasSeparados error: ${e.response?.data}');
      return {'vencidos': [], 'por_vencer': [], 'total_alertas': 0};
    } catch (e) {
      debugPrint('❌ getAlertasSeparados error: $e');
      return {'vencidos': [], 'por_vencer': [], 'total_alertas': 0};
    }
  }
}