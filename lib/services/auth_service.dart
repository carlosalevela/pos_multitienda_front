import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

class AuthService {

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiClient.instance.post(
        '/auth/login/',
        data: {'email': email, 'password': password},
        options: Options(
          sendTimeout:    const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ).timeout(const Duration(seconds: 25));

      final accessToken  = response.data['access']?.toString()  ?? '';
      final refreshToken = response.data['refresh']?.toString() ?? '';
      final empleado     = response.data['empleado'] as Map<String, dynamic>? ?? {};

      if (accessToken.isEmpty) {
        return {'success': false, 'error': 'Respuesta inválida del servidor'};
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('access_token',  accessToken);
      await prefs.setString('refresh_token', refreshToken);

      await prefs.setInt   ('empleado_id',      empleado['id']       ?? 0);
      await prefs.setString('empleado_nombre',  '${empleado['nombre'] ?? ''} ${empleado['apellido'] ?? ''}'.trim());
      await prefs.setString('empleado_rol',     empleado['rol']      ?? '');
      await prefs.setString('empleado_email',   empleado['email']    ?? '');

      await prefs.setString('tienda_id',     empleado['tienda_id']?.toString()  ?? '');
      await prefs.setString('tienda_nombre', empleado['tienda_nombre']           ?? '');

      await prefs.setString('empresa_id',     empleado['empresa_id']?.toString() ?? '');
      await prefs.setString('empresa_nombre', empleado['empresa_nombre']          ?? '');

      return {'success': true, 'empleado': empleado};

    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        return {'success': false, 'error': 'Contraseña incorrecta'};
      }
      if (status == 400) {
        // Mostrar el mensaje real del backend (ej: cédula no encontrada)
        final data = e.response?.data;
        String msg = 'Error de autenticación';
        if (data is Map) {
          if (data.containsKey('detail')) {
            msg = data['detail'].toString();
          } else {
            final first = data.values.firstOrNull;
            if (first is List && first.isNotEmpty) {
              msg = first.first.toString();
            } else if (first != null) {
              msg = first.toString();
            }
          }
        }
        return {'success': false, 'error': msg};
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return {'success': false, 'error': 'Sin conexión al servidor'};
      }
      return {'success': false, 'error': 'Error del servidor ($status)'};

    } on TimeoutException {
      return {'success': false, 'error': 'Sin respuesta del servidor (timeout)'};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado al iniciar sesión'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    final refresh = prefs.getString('refresh_token') ?? '';
    if (refresh.isNotEmpty) {
      try {
        await ApiClient.instance.post('/auth/logout/', data: {'refresh': refresh});
      } catch (_) {}
    }

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('empleado_id');
    await prefs.remove('empleado_nombre');
    await prefs.remove('empleado_rol');
    await prefs.remove('empleado_email');
    await prefs.remove('tienda_id');
    await prefs.remove('tienda_nombre');
    await prefs.remove('empresa_id');
    await prefs.remove('empresa_nombre');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }

  Future<bool> verificarTokenBackend() async {
    try {
      await ApiClient.instance.get('/auth/perfil/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id':             prefs.getInt('empleado_id'),
      'nombre':         prefs.getString('empleado_nombre'),
      'rol':            prefs.getString('empleado_rol'),
      'email':          prefs.getString('empleado_email'),
      'tienda_id':      prefs.getString('tienda_id'),
      'tienda_nombre':  prefs.getString('tienda_nombre'),
      'empresa_id':     prefs.getString('empresa_id'),
      'empresa_nombre': prefs.getString('empresa_nombre'),
    };
  }
}