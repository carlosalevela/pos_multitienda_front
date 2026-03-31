import '../core/api_client.dart';

class EmpleadoService {

  Future<List<Map<String, dynamic>>> getEmpleados() async {
    try {
      final response = await ApiClient.instance.get('/auth/empleados/');
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

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
    } catch (e) {
      return {'success': false, 'error': 'Error al registrar empleado'};
    }
  }

  Future<Map<String, dynamic>> editarEmpleado(
      int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.instance.patch(
        '/auth/empleados/$id/',
        data: data,
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al editar empleado'};
    }
  }

  Future<List<Map<String, dynamic>>> getTiendas() async {
    try {
      final response = await ApiClient.instance.get('/tiendas/');
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }
}