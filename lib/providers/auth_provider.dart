import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool   _isLoading  = false;
  bool   _isLoggedIn = false;
  String _nombre     = '';
  String _rol        = '';
  String _errorMsg   = '';
  int    _tiendaId   = 0;        // ← nuevo
  int    _empleadoId = 0;        // ← nuevo (útil para reportes)

  bool   get isLoading   => _isLoading;
  bool   get isLoggedIn  => _isLoggedIn;
  String get nombre      => _nombre;
  String get rol         => _rol;
  String get errorMsg    => _errorMsg;
  int    get tiendaId    => _tiendaId;    // ← nuevo
  int    get empleadoId  => _empleadoId;  // ← nuevo

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMsg  = '';
    notifyListeners();

    final result = await _authService.login(email, password);

    if (result['success']) {
      final emp   = result['empleado'];
      _nombre     = '${emp['nombre']} ${emp['apellido']}';
      _rol        = emp['rol'];
      _tiendaId   = emp['tienda_id']   ?? emp['tienda']   ?? 0;  // ← nuevo
      _empleadoId = emp['id']          ?? emp['empleado_id'] ?? 0; // ← nuevo
      _isLoggedIn = true;

      // Guardar en SharedPreferences para checkSession
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('empleado_nombre', _nombre);
      await prefs.setString('empleado_rol',    _rol);
      await prefs.setInt('tienda_id',          _tiendaId);    // ← nuevo
      await prefs.setInt('empleado_id',        _empleadoId);  // ← nuevo
    } else {
      _errorMsg = result['error'];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _isLoggedIn = false;
    _nombre     = '';
    _rol        = '';
    _tiendaId   = 0;
    _empleadoId = 0;
    notifyListeners();
  }

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      _nombre     = prefs.getString('empleado_nombre') ?? '';
      _rol        = prefs.getString('empleado_rol')    ?? '';
      _tiendaId   = prefs.getInt('tienda_id')          ?? 0;   // ← nuevo
      _empleadoId = prefs.getInt('empleado_id')        ?? 0;   // ← nuevo
      _isLoggedIn = true;
      notifyListeners();
    }
  }
}