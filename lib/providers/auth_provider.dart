// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool   _isLoading     = false;
  bool   _isLoggedIn    = false;
  String _nombre        = '';
  String _rol           = '';
  String _errorMsg      = '';
  int    _empleadoId    = 0;
  int    _tiendaId      = 0;
  String _tiendaNombre  = '';
  String _empresaId     = '';
  String _empresaNombre = '';

  bool   get isLoading     => _isLoading;
  bool   get isLoggedIn    => _isLoggedIn;
  String get nombre        => _nombre;
  String get rol           => _rol;
  String get errorMsg      => _errorMsg;
  int    get empleadoId    => _empleadoId;
  int    get tiendaId      => _tiendaId;
  String get tiendaNombre  => _tiendaNombre;
  String get empresaId     => _empresaId;
  String get empresaNombre => _empresaNombre;

  // ── Helpers de rol ─────────────────────────────────────

  bool get esAdmin            => _rol == 'admin';
  bool get esSupervisor       => _rol == 'supervisor';
  bool get esCajero           => _rol == 'cajero';
  bool get esAdminOSupervisor => esAdmin || esSupervisor;

  // ── Login ──────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMsg  = '';
    notifyListeners();

    final result = await _authService.login(email, password);

    if (result['success'] == true) {
      final emp = result['empleado'] as Map<String, dynamic>? ?? {};

      final nombre   = emp['nombre']?.toString()  ?? '';
      final apellido = emp['apellido']?.toString() ?? '';
      _nombre        = '$nombre $apellido'.trim();

      _rol           = emp['rol']?.toString()            ?? '';
      _empleadoId    = emp['id']                         ?? 0;
      // ✅ FIX: parsing seguro — backend puede retornar int o string
      _tiendaId      = int.tryParse(emp['tienda_id']?.toString() ?? '') ?? 0;
      _tiendaNombre  = emp['tienda_nombre']?.toString()  ?? '';
      _empresaId     = emp['empresa_id']?.toString()     ?? '';
      _empresaNombre = emp['empresa_nombre']?.toString() ?? '';
      _isLoggedIn    = true;
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Logout ─────────────────────────────────────────────

  Future<void> logout() async {
    await _authService.logout();
    _isLoading     = false;
    _isLoggedIn    = false;
    _nombre        = '';
    _rol           = '';
    _errorMsg      = '';
    _empleadoId    = 0;
    _tiendaId      = 0;
    _tiendaNombre  = '';
    _empresaId     = '';
    _empresaNombre = '';
    notifyListeners();
  }

  // ── Restaurar sesión al abrir el app ───────────────────

  Future<void> checkSession() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) return;

    final data = await _authService.getUsuarioLocal();

    // ✅ FIX: AuthService ya guarda nombre+apellido combinado en 'nombre'
    //        no hay campo 'apellido' separado en SharedPreferences
    _nombre        = data['nombre']?.toString()         ?? '';
    _rol           = data['rol']?.toString()            ?? '';
    _empleadoId    = data['id']                         ?? 0;
    // ✅ FIX: parsing consistente con login()
    _tiendaId      = int.tryParse(data['tienda_id']?.toString()  ?? '') ?? 0;
    _tiendaNombre  = data['tienda_nombre']?.toString()  ?? '';
    _empresaId     = data['empresa_id']?.toString()     ?? '';
    _empresaNombre = data['empresa_nombre']?.toString() ?? '';
    _isLoggedIn    = true;
    notifyListeners();
  }

  // ── Utilidades ─────────────────────────────────────────

  // ✅ FIX: requerido por LoginScreen para limpiar error antes de reintentar
  void clearError() {
    _errorMsg = '';
    notifyListeners();
  }
}