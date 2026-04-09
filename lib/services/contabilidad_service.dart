import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/contabilidad_models.dart';
import 'package:flutter/foundation.dart';

class ContabilidadService {

  Future<ResumenDiario?> getResumenDiario({int? tiendaId, String? fecha}) async {
    try {
      final params = <String, dynamic>{};
      if (tiendaId != null) params['tienda_id'] = tiendaId;
      if (fecha != null)    params['fecha']      = fecha;
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/diario/',   // ✅ FIX: URL correcta
        queryParameters: params,
      );
      return ResumenDiario.fromJson(r.data);
    } catch (e) {
      debugPrint('❌ getResumenDiario error: $e');
      return null;
    }
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
      debugPrint('📊 MENSUAL RESPONSE: ${r.data}');
      return ResumenMensual.fromJson(r.data);
    } catch (e) {
      debugPrint('❌ getResumenMensual error: $e');
      return null;
    }
  }

    Future<Map<String, dynamic>?> getResumenAnual({
    int? tiendaId, required int anio}) async {
    try {
      final params = <String, dynamic>{'anio': anio};
      if (tiendaId != null) params['tienda_id'] = tiendaId;
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/anual/',
        queryParameters: params,
      );
      debugPrint('📊 ANUAL RESPONSE: ${r.data}'); // ← agrega esto
      return Map<String, dynamic>.from(r.data);
    } catch (e) {
      debugPrint('❌ getResumenAnual error: $e');
      return null;
    }
  }
  Future<List<TopProducto>> getTopProductos({
    int? tiendaId, String? fechaIni, String? fechaFin}) async {
  try {
    final params = <String, dynamic>{};
    if (tiendaId != null) params['tienda_id'] = tiendaId;
    if (fechaIni != null) params['fecha_ini']  = fechaIni;
    if (fechaFin != null) params['fecha_fin']  = fechaFin;

    final r = await ApiClient.instance.get(
      '/productos/top-productos/',   // ✅ ruta actualizada
      queryParameters: params,
    );
    return (r.data as List).map((e) => TopProducto.fromJson(e)).toList();
  } catch (e) {
    debugPrint('❌ getTopProductos error: $e');
    return [];
  }
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

  Future<List<Map<String, dynamic>>> getAbonosDia(
      String fecha, int? tiendaId) async {
    try {
      final params = <String, dynamic>{'fecha': fecha};
      if (tiendaId != null) params['tienda_id'] = tiendaId.toString();
      final r = await ApiClient.instance.get(
          '/clientes/abonos/', queryParameters: params);
      return List<Map<String, dynamic>>.from(r.data['abonos'] ?? []);
    } catch (e) {
      debugPrint('❌ getAbonosDia error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSeparadosDia(
      String fecha, int? tiendaId) async {
    try {
      final params = <String, dynamic>{'fecha_creacion': fecha};
      if (tiendaId != null) params['tienda_id'] = tiendaId.toString();
      final r = await ApiClient.instance.get(
          '/clientes/separados/', queryParameters: params);
      final data  = r.data;
      final lista = data is List ? data : (data['results'] ?? data);
      return List<Map<String, dynamic>>.from(lista);
    } catch (e) {
      debugPrint('❌ getSeparadosDia error: $e');
      return [];
    }
  }
}