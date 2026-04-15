// lib/services/empleado_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class EmpleadoService {

  // ── Helper extractor de errores ────────────────────────
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('error'))  return data['error'].toString();
      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  // ── Listado ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEmpleados() async {
    try {
      final response = await ApiClient.instance.get('/auth/empleados/');
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      debugPrint('❌ getEmpleados error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getEmpleados error: $e');
      return [];
    }
  }

  // ── Crear empleado ─────────────────────────────────────
  // ✅ empresa NO se envía — el backend la inyecta desde el token

  Future<Map<String, dynamic>> crearEmpleado({
    required String nombre,
    required String apellido,
    required String cedula,
    required String email,
    required String password,
    required String rol,
    int? tiendaId,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/auth/empleados/',
        data: {
          'nombre':   nombre,
          'apellido': apellido,
          'cedula':   cedula,
          'email':    email,
          'password': password,
          'rol':      rol,
          if (tiendaId != null) 'tienda': tiendaId,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al registrar empleado')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Editar empleado ────────────────────────────────────

  Future<Map<String, dynamic>> editarEmpleado(
      int id, Map<String, dynamic> data) async {
    try {
      // ✅ FIX: copia del mapa — no mutar el objeto del caller
      final payload = Map<String, dynamic>.from(data)..remove('empresa');
      final response = await ApiClient.instance.patch(
        '/auth/empleados/$id/',
        data: payload,
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al editar empleado')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Cambiar contraseña ─────────────────────────────────

  Future<Map<String, dynamic>> cambiarPassword({
    required String passwordActual,
    required String passwordNuevo,
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/auth/cambiar-password/',
        data: {
          'password_actual': passwordActual,
          'password_nuevo':  passwordNuevo,
        },
      );
      return {
        'success': true,
        'detail':  r.data?['detail'] ?? 'Contraseña actualizada correctamente',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cambiar contraseña')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Mi perfil ──────────────────────────────────────────

  Future<Map<String, dynamic>?> getMiPerfil() async {
    try {
      final r = await ApiClient.instance.get('/auth/me/');
      return r.data;
    } on DioException catch (e) {
      debugPrint('❌ getMiPerfil error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ getMiPerfil error: $e');
      return null;
    }
  }

  // ── Listar tiendas (para selector admin) ──────────────

  Future<List<Map<String, dynamic>>> getTiendas() async {
    try {
      final r = await ApiClient.instance.get('/tiendas/');
      final data = r.data;
      if (data is List) return List<Map<String, dynamic>>.from(data);
      if (data is Map && data.containsKey('results')) {
        return List<Map<String, dynamic>>.from(data['results']);
      }
      return [];
    } on DioException catch (e) {
      debugPrint('❌ getTiendas error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ getTiendas error: $e');
      return [];
    }
  }
}