import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/contabilidad_models.dart';
import 'package:flutter/foundation.dart'; // ← agrega esta línea

class ContabilidadService {

  Future<ResumenDiario?> getResumenDiario({int? tiendaId, String? fecha}) async {
    try {
      final params = <String, dynamic>{};
      if (tiendaId != null) params['tienda_id'] = tiendaId;
      if (fecha != null)    params['fecha']      = fecha;
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/diario/', queryParameters: params);
      return ResumenDiario.fromJson(r.data);
    } catch (_) { return null; }
  }

  Future<ResumenMensual?> getResumenMensual({
    int? tiendaId, int? anio, int? mes}) async {
    try {
      final now = DateTime.now();
      final params = <String, dynamic>{
        'anio': anio ?? now.year,
        'mes':  mes  ?? now.month,
      };
      if (tiendaId != null) params['tienda_id'] = tiendaId;
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/mensual/', queryParameters: params);
      return ResumenMensual.fromJson(r.data);
    } catch (_) { return null; }
  }

  Future<List<TopProducto>> getTopProductos({
    int? tiendaId, String? fechaIni, String? fechaFin}) async {
    try {
      final params = <String, dynamic>{};
      if (tiendaId != null) params['tienda_id']  = tiendaId;
      if (fechaIni != null) params['fecha_ini']   = fechaIni;
      if (fechaFin != null) params['fecha_fin']   = fechaFin;
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/top-productos/', queryParameters: params);
      return (r.data as List).map((e) => TopProducto.fromJson(e)).toList();
    } catch (_) { return []; }
  }

      Future<List<Gasto>> getGastos({int? tiendaId, String? fecha}) async {
        try {
          final params = <String, dynamic>{};
          if (tiendaId != null) params['tienda_id'] = tiendaId;
          if (fecha != null)    params['fecha']      = fecha;
          final r = await ApiClient.instance.get(
            '/contabilidad/gastos/', queryParameters: params);
          return (r.data as List).map((e) => Gasto.fromJson(e)).toList();
      } catch (e, stack) {
      // ✅ ahora puedes ver el error real en consola
        debugPrint('❌ getGastos error: $e');
        debugPrint('$stack');
        return [];
    }
  }

  Future<Map<String, dynamic>> crearGasto(Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.post('/contabilidad/gastos/', data: data);
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['detail'] ?? 'Error al registrar gasto';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': 'Error al registrar gasto'};
    }
  }

  Future<bool> eliminarGasto(int id) async {
    try {
      await ApiClient.instance.delete('/contabilidad/gastos/$id/');
      return true;
    } catch (_) { return false; }
  }
}