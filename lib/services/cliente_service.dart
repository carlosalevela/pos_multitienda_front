import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../models/separado.dart';
import '../core/api_client.dart';

class ClienteService {

  // ── Clientes ──────────────────────────────────────────

  Future<List<Cliente>> getClientes({String? q}) async {
    try {
      final params = <String, dynamic>{};
      if (q != null && q.isNotEmpty) params['q'] = q;

      final r = await ApiClient.instance.get(
        '/clientes/', queryParameters: params);
      return (r.data as List).map((e) => Cliente.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ getClientes error: $e');
      return [];
    }
  }

  Future<List<Cliente>> getClientesSimple({String? q}) async {
    try {
      final params = <String, dynamic>{};
      if (q != null && q.isNotEmpty) params['q'] = q;

      final r = await ApiClient.instance.get(
        '/clientes/simple/', queryParameters: params);
      return (r.data as List).map((e) => Cliente.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ getClientesSimple error: $e');
      return [];
    }
  }

  Future<Cliente?> getCliente(int id) async {
    try {
      final r = await ApiClient.instance.get('/clientes/$id/');
      return Cliente.fromJson(r.data);
    } catch (e) {
      debugPrint('❌ getCliente error: $e');
      return null;
    }
  }

  Future<Cliente?> crearCliente(Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.post('/clientes/', data: data);
      return Cliente.fromJson(r.data);
    } catch (e) {
      debugPrint('❌ crearCliente error: $e');
      rethrow;   // ✅ rethrow para mostrar errores de validación en UI
    }
  }

  Future<Cliente?> editarCliente(int id, Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.patch('/clientes/$id/', data: data);
      return Cliente.fromJson(r.data);
    } catch (e) {
      debugPrint('❌ editarCliente error: $e');
      rethrow;
    }
  }

  Future<bool> desactivarCliente(int id) async {
    try {
      await ApiClient.instance.delete('/clientes/$id/');
      return true;
    } catch (e) {
      debugPrint('❌ desactivarCliente error: $e');
      return false;
    }
  }

  // ── Separados ─────────────────────────────────────────

  Future<List<Separado>> getSeparados({
    int? tiendaId, String? estado, int? clienteId}) async {
    try {
      final params = <String, dynamic>{};
      if (tiendaId  != null) params['tienda_id']  = tiendaId;
      if (estado    != null) params['estado']      = estado;
      if (clienteId != null) params['cliente_id']  = clienteId;

      final r = await ApiClient.instance.get(
        '/clientes/separados/', queryParameters: params);
      return (r.data as List).map((e) => Separado.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ getSeparados error: $e');
      return [];
    }
  }

  Future<Separado?> getSeparado(int id) async {
    try {
      final r = await ApiClient.instance.get('/clientes/separados/$id/');
      return Separado.fromJson(r.data);
    } catch (e) {
      debugPrint('❌ getSeparado error: $e');
      return null;
    }
  }

  Future<Separado?> crearSeparado(Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.post(
        '/clientes/separados/', data: data);
      return Separado.fromJson(r.data);
    } catch (e) {
      debugPrint('❌ crearSeparado error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> abonarSeparado(
      int id, double monto, String metodoPago) async {
    try {
      final r = await ApiClient.instance.post(
        '/clientes/separados/$id/abonar/',
        data: {'monto': monto, 'metodo_pago': metodoPago},
      );
      return r.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ abonarSeparado error: $e');
      rethrow;
    }
  }

  Future<bool> cancelarSeparado(int id) async {
    try {
      await ApiClient.instance.post('/clientes/separados/$id/cancelar/');
      return true;
    } catch (e) {
      debugPrint('❌ cancelarSeparado error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getAlertasSeparados({int? tiendaId}) async {
  try {
    final params = <String, dynamic>{};
    if (tiendaId != null) params['tienda_id'] = tiendaId;

    final r = await ApiClient.instance.get(
      '/clientes/separados/alertas/',
      queryParameters: params,
    );
    return r.data as Map<String, dynamic>;
  } catch (e) {
    debugPrint('❌ getAlertasSeparados: $e');
    return {'vencidos': [], 'por_vencer': [], 'total_alertas': 0};
  }
}
}