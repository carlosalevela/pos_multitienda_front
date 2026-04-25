import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/contabilidad_models.dart';

class ContabilidadService {
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      if (data.containsKey('error')) return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
      final msgs = data.values.expand((v) => v is List ? v : [v]).join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  Future<ResumenDiario?> getResumenDiario({
    int? tiendaId,
    String? fecha,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/diario/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId,
          if (fecha != null) 'fecha': fecha,
        },
      );
      return ResumenDiario.fromJson(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getResumenDiario error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getResumenDiario error: $e');
      return null;
    }
  }

  Future<ResumenMensual?> getResumenMensual({
    int? tiendaId,
    int? anio,
    int? mes,
  }) async {
    try {
      final now = DateTime.now();
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/mensual/',
        queryParameters: {
          'anio': anio ?? now.year,
          'mes': mes ?? now.month,
          if (tiendaId != null) 'tienda_id': tiendaId,
        },
      );
      return ResumenMensual.fromJson(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getResumenMensual error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getResumenMensual error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getResumenAnual({
    int? tiendaId,
    required int anio,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/anual/',
        queryParameters: {
          'anio': anio,
          if (tiendaId != null) 'tienda_id': tiendaId,
        },
      );
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getResumenAnual error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getResumenAnual error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getDevolucionesDia(
    String fecha,
    int? tiendaId,
  ) async {
    try {
      final r = await ApiClient.instance.get(
        '/devoluciones/lista/',
        queryParameters: {
          'fecha': fecha,
          'estado': 'procesada',
          if (tiendaId != null) 'tienda_id': tiendaId,
        },
      );
      final data = r.data;
      final lista = data is List ? data : (data['results'] ?? data);
      return List<Map<String, dynamic>>.from(lista);
    } on DioException catch (e) {
      debugPrint('❌ getDevolucionesDia error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getDevolucionesDia error: $e');
      return [];
    }
  }

  Future<List<TopProducto>> getTopProductos({
    int? tiendaId,
    String? fechaIni,
    String? fechaFin,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/productos/top-productos/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId,
          if (fechaIni != null) 'fecha_ini': fechaIni,
          if (fechaFin != null) 'fecha_fin': fechaFin,
        },
      );
      return (r.data as List).map((e) => TopProducto.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('❌ getTopProductos error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getTopProductos error: $e');
      return [];
    }
  }

  Future<List<Gasto>> getGastos({
    int? tiendaId,
    String? fecha,
    String? fechaIni,
    String? fechaFin,
    String? categoria,
    String? visibilidad,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/contabilidad/gastos/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId,
          if (fecha != null) 'fecha': fecha,
          if (fechaIni != null) 'fecha_ini': fechaIni,
          if (fechaFin != null) 'fecha_fin': fechaFin,
          if (categoria != null) 'categoria': categoria,
          if (visibilidad != null) 'visibilidad': visibilidad,
        },
      );
      return (r.data as List).map((e) => Gasto.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('❌ getGastos error: ${e.response?.data}');
      return [];
    } catch (e, stack) {
      debugPrint('❌ getGastos error: $e\n$stack');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getGastosResumenRango({
    required String fechaIni,
    required String fechaFin,
    int? tiendaId,
    String? categoria,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/contabilidad/gastos/resumen-rango/',
        queryParameters: {
          'fecha_ini': fechaIni,
          'fecha_fin': fechaFin,
          if (tiendaId != null) 'tienda_id': tiendaId,
          if (categoria != null) 'categoria': categoria,
        },
      );
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getGastosResumenRango error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getGastosResumenRango error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> crearGasto(Map<String, dynamic> data) async {
    try {
      data.remove('empresa');
      final r = await ApiClient.instance.post(
        '/contabilidad/gastos/',
        data: data,
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al registrar gasto'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> eliminarGasto(int id) async {
    try {
      final r = await ApiClient.instance.delete('/contabilidad/gastos/$id/');
      return {
        'success': true,
        'detail': r.data?['detail'] ?? 'Gasto eliminado',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al eliminar gasto'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<List<Map<String, dynamic>>> getAbonosDia(
    String fecha,
    int? tiendaId,
  ) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/separados/abonos/',
        queryParameters: {
          'fecha': fecha,
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
        },
      );
      final raw = r.data;
      if (raw is Map && raw.containsKey('abonos')) {
        return List<Map<String, dynamic>>.from(raw['abonos']);
      }
      if (raw is List) {
        return List<Map<String, dynamic>>.from(raw);
      }
      return [];
    } on DioException catch (e) {
      debugPrint('❌ getAbonosDia error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getAbonosDia error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSeparadosDia(
    String fecha,
    int? tiendaId,
  ) async {
    try {
      final r = await ApiClient.instance.get(
        '/clientes/separados/',
        queryParameters: {
          'fecha_creacion': fecha,
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
        },
      );
      final data = r.data;
      final lista = data is List ? data : (data['results'] ?? data);
      return List<Map<String, dynamic>>.from(lista);
    } on DioException catch (e) {
      debugPrint('❌ getSeparadosDia error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getSeparadosDia error: $e');
      return [];
    }
  }
}