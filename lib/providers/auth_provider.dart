import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool   _isLoading    = false;
  bool   _isLoggedIn   = false;
  String _nombre       = '';
  String _rol          = '';
  String _errorMsg     = '';
  int    _tiendaId     = 0;
  int    _empleadoId   = 0;
  String _tiendaNombre = '';
  String _token        = '';   // ✅ NUEVO

  bool   get isLoading    => _isLoading;
  bool   get isLoggedIn   => _isLoggedIn;
  String get nombre       => _nombre;
  String get rol          => _rol;
  String get errorMsg     => _errorMsg;
  int    get tiendaId     => _tiendaId;
  int    get empleadoId   => _empleadoId;
  String get tiendaNombre => _tiendaNombre;
  String get token        => _token;   // ✅ NUEVO

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMsg  = '';
    notifyListeners();

    final result = await _authService.login(email, password);

    if (result['success']) {
      final emp     = result['empleado'];
      _nombre       = '${emp['nombre']} ${emp['apellido']}';
      _rol          = emp['rol'];
      _tiendaId     = emp['tienda_id']     ?? emp['tienda']      ?? 0;
      _empleadoId   = emp['id']            ?? emp['empleado_id'] ?? 0;
      _tiendaNombre = emp['tienda_nombre'] ?? '';
      _token        = result['token'] ?? result['access_token'] ?? '';  // ✅

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('empleado_nombre', _nombre);
      await prefs.setString('empleado_rol',    _rol);
      await prefs.setInt('tienda_id',          _tiendaId);
      await prefs.setInt('empleado_id',        _empleadoId);
      await prefs.setString('tienda_nombre',   _tiendaNombre);

      _isLoggedIn = true;
    } else {
      _errorMsg = result['error'];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _isLoading    = false;
    _isLoggedIn   = false;
    _nombre       = '';
    _rol          = '';
    _errorMsg     = '';
    _tiendaId     = 0;
    _empleadoId   = 0;
    _tiendaNombre = '';
    _token        = '';   // ✅
    notifyListeners();
  }

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      _token        = token;   // ✅
      _nombre       = prefs.getString('empleado_nombre') ?? '';
      _rol          = prefs.getString('empleado_rol')    ?? '';
      _tiendaId     = prefs.getInt('tienda_id')          ?? 0;
      _empleadoId   = prefs.getInt('empleado_id')        ?? 0;
      _tiendaNombre = prefs.getString('tienda_nombre')   ?? '';
      _isLoggedIn   = true;
      notifyListeners();
    }
  }
}