import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

class AuthService {

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiClient.instance.post(
        '/auth/login/',
        data: {'email': email, 'password': password},
      );

      final accessToken  = response.data['access'];
      final refreshToken = response.data['refresh'];
      final empleado     = response.data['empleado'];

      // Guardar tokens localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token',  accessToken);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setString('empleado_nombre', '${empleado['nombre']} ${empleado['apellido']}');
      await prefs.setString('empleado_rol',    empleado['rol']);
      await prefs.setInt('empleado_id',        empleado['id']);

      return {'success': true, 'empleado': empleado};
    } catch (e) {
      return {'success': false, 'error': 'Email o contraseña incorrectos'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('empleado_nombre');
    await prefs.remove('empleado_rol');
    await prefs.remove('empleado_id');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }
}