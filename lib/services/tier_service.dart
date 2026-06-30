// lib/services/tier_service.dart

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/tier_model.dart';

class TierService {
  static const _base = '/clientes/tiers/';

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      if (data.containsKey('error'))  return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
      final msgs = data.values.expand((v) => v is List ? v : [v]).join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  Future<Map<String, dynamic>> getTiers() async {
    try {
      final r = await ApiClient.instance.get(_base);
      final list = r.data is List ? r.data as List : (r.data['results'] as List? ?? []);
      return {
        'success': true,
        'data': list.map((e) => TierModel.fromJson(e as Map<String, dynamic>)).toList(),
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cargar tiers')};
    }
  }

  Future<Map<String, dynamic>> crearTier(TierModel tier) async {
    try {
      final r = await ApiClient.instance.post(_base, data: tier.toJson());
      return {'success': true, 'data': TierModel.fromJson(r.data as Map<String, dynamic>)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear tier')};
    }
  }

  Future<Map<String, dynamic>> actualizarTier(int id, TierModel tier) async {
    try {
      final r = await ApiClient.instance.patch('$_base$id/', data: tier.toJson());
      return {'success': true, 'data': TierModel.fromJson(r.data as Map<String, dynamic>)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al actualizar tier')};
    }
  }

  Future<Map<String, dynamic>> eliminarTier(int id) async {
    try {
      await ApiClient.instance.delete('$_base$id/');
      return {'success': true};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al eliminar tier')};
    }
  }
}
