import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

class AuthService {

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiClient.instance.post(
        '/auth/login/',
        data: {'email': email, 'password': password},
      );

      // ✅ FIX: null-safe — evita CastError si el backend cambia la respuesta
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
      // ✅ FIX: distingue errores de credenciales vs errores de red/servidor
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) {
        return {'success': false, 'error': 'Email o contraseña incorrectos'};
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return {'success': false, 'error': 'Sin conexión al servidor'};
      }
      return {'success': false, 'error': 'Error del servidor ($status)'};

    } catch (e) {
      return {'success': false, 'error': 'Error inesperado al iniciar sesión'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

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