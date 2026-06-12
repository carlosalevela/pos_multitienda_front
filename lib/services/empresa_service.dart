// lib/services/empresa_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/empresa_model.dart';

class EmpresaService {

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      if (data.containsKey('detail')) return data['detail'].toString();
      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  Future<List<Empresa>> getEmpresas() async {
    try {
      final r = await ApiClient.instance.get('/empresas/');
      return (r.data as List)
          .map((e) => Empresa.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      debugPrint('❌ getEmpresas error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getEmpresas error: $e');
      return [];
    }
  }

  Future<Empresa?> getEmpresaDetalle(int id) async {
    try {
      final r = await ApiClient.instance.get('/empresas/$id/');
      return Empresa.fromJson(Map<String, dynamic>.from(r.data));
    } on DioException catch (e) {
      debugPrint('❌ getEmpresaDetalle error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getEmpresaDetalle error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> crearEmpresa(
      Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.post(
          '/empresas/', data: Map<String, dynamic>.from(data));
      return {
        'success': true,
        'data': Empresa.fromJson(Map<String, dynamic>.from(r.data)),
      };
    } on DioException catch (e) {
      return {'success': false,
              'error': _extractError(e, 'Error al crear empresa')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<Map<String, dynamic>> editarEmpresa(
      int id, Map<String, dynamic> data) async {
    try {
      final r = await ApiClient.instance.patch(
          '/empresas/$id/', data: Map<String, dynamic>.from(data));
      return {
        'success': true,
        'data': Empresa.fromJson(Map<String, dynamic>.from(r.data)),
      };
    } on DioException catch (e) {
      return {'success': false,
              'error': _extractError(e, 'Error al actualizar empresa')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  Future<List<Map<String, dynamic>>> listarSimple() async {
    try {
      final empresas = await getEmpresas();
      return empresas
          .where((e) => e.activo)
          .map((e) => {'id': e.id, 'nombre': e.nombre})
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Configuración mayoreo ─────────────────────────────

  /// GET /empresas/<id>/mayoreo/
  /// Retorna: {id, maneja_mayoreo, cantidad_mayoreo}
  Future<Map<String, dynamic>?> getConfigMayoreo(int empresaId) async {
    try {
      final r = await ApiClient.instance.get(
          '/empresas/$empresaId/mayoreo/');
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      debugPrint('❌ getConfigMayoreo error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getConfigMayoreo error: $e');
      return null;
    }
  }

  /// PATCH /empresas/<id>/mayoreo/
  /// Actualiza maneja_mayoreo y cantidad_mayoreo
  Future<Map<String, dynamic>> updateConfigMayoreo(
    int  empresaId, {
    required bool manejaM,
    required int  cantidadM,
  }) async {
    try {
      final r = await ApiClient.instance.patch(
        '/empresas/$empresaId/mayoreo/',
        data: {
          'maneja_mayoreo':   manejaM,
          'cantidad_mayoreo': cantidadM,
        },
      );
      return {'success': true, 'data': Map<String, dynamic>.from(r.data)};
    } on DioException catch (e) {
      return {'success': false,
              'error': _extractError(e, 'Error al guardar configuración')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }
}