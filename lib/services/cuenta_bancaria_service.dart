// lib/services/cuenta_bancaria_service.dart

import '../core/api_client.dart';
import '../models/cuenta_bancaria.dart';

class CuentaBancariaService {
  Future<List<CuentaBancaria>> listar(int tiendaId) async {
    try {
      final res = await ApiClient.instance.get('/config/cuentas/$tiendaId/');
      return (res.data as List)
          .map((j) => CuentaBancaria.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<CuentaBancaria?> crear(int tiendaId, Map<String, dynamic> data) async {
    try {
      final res = await ApiClient.instance.post('/config/cuentas/$tiendaId/', data: data);
      return CuentaBancaria.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> actualizar(int tiendaId, int cuentaId, Map<String, dynamic> data) async {
    try {
      await ApiClient.instance.patch('/config/cuentas/$tiendaId/$cuentaId/', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> eliminar(int tiendaId, int cuentaId) async {
    try {
      await ApiClient.instance.delete('/config/cuentas/$tiendaId/$cuentaId/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> resumen(int tiendaId, {int? sesionId}) async {
    try {
      final params = sesionId != null ? '?sesion_id=$sesionId' : '';
      final res = await ApiClient.instance.get('/config/cuentas/$tiendaId/resumen/$params');
      return (res.data as List)
          .map((j) => Map<String, dynamic>.from(j as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
