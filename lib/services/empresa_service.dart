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
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }

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

  Future<Map<String, dynamic>> crearEmpresa(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);

      final r = await ApiClient.instance.post('/empresas/', data: payload);

      return {
        'success': true,
        'data': Empresa.fromJson(Map<String, dynamic>.from(r.data)),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al crear empresa'),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error inesperado',
      };
    }
  }

  Future<Map<String, dynamic>> editarEmpresa(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final payload = Map<String, dynamic>.from(data);

      final r = await ApiClient.instance.patch('/empresas/$id/', data: payload);

      return {
        'success': true,
        'data': Empresa.fromJson(Map<String, dynamic>.from(r.data)),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e, 'Error al actualizar empresa'),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error inesperado',
      };
    }
  }
}