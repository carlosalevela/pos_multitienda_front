// lib/providers/tienda_provider.dart

import 'package:flutter/material.dart';
import '../models/tienda_model.dart';
import '../services/tienda_service.dart';

class TiendaProvider extends ChangeNotifier {
  final TiendaService _service = TiendaService();

  List<Tienda>          tiendas         = [];
  Map<String, dynamic>? empleadosTienda;

  bool   _cargando          = false;
  bool   _cargandoEmpleados = false; // ✅ FIX: flag separado
  bool   _guardando         = false;
  String _errorMsg          = '';
  String _successMsg        = '';

  bool   get cargando          => _cargando;
  bool   get cargandoEmpleados => _cargandoEmpleados;
  bool   get guardando         => _guardando;
  String get errorMsg          => _errorMsg;
  String get successMsg        => _successMsg;

  int get totalActivas   => tiendas.where((t) => t.activo).length;
  int get totalInactivas => tiendas.where((t) => !t.activo).length;

  void limpiarMensajes() {
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }

  // ── Cargar tiendas ────────────────────────────────────

  Future<void> cargarTiendas({bool? soloActivas}) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    // ✅ FIX: try/catch/finally — spinner nunca queda infinito
    try {
      tiendas = await _service.getTiendas(soloActivas: soloActivas);
    } catch (_) {
      _errorMsg = 'Error al cargar tiendas';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Crear ─────────────────────────────────────────────

  Future<bool> crearTienda(Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();

    try {
      final result = await _service.crearTienda(data);

      if (result['success'] == true) {
        _successMsg = '✅ Tienda creada correctamente';
        // ✅ FIX: notificar antes del reload para que el botón deje de girar
        _guardando = false;
        notifyListeners();
        await cargarTiendas();
        return true;
      }

      _errorMsg = result['error'] ?? 'Error desconocido';
      return false;
    } catch (_) {
      _errorMsg = 'Error inesperado al crear tienda';
      return false;
    } finally {
      // ✅ FIX: always reset guardando aunque haya excepción
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Editar ────────────────────────────────────────────

  Future<bool> editarTienda(int id, Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();

    try {
      final result = await _service.editarTienda(id, data);

      if (result['success'] == true) {
        _successMsg = '✅ Tienda actualizada correctamente';
        _guardando  = false;
        notifyListeners();
        await cargarTiendas();
        return true;
      }

      _errorMsg = result['error'] ?? 'Error desconocido';
      return false;
    } catch (_) {
      _errorMsg = 'Error inesperado al editar tienda';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Desactivar ────────────────────────────────────────

  Future<bool> desactivarTienda(int id) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();

    try {
      final result = await _service.desactivarTienda(id);

      if (result['success'] == true) {
        _successMsg = '🗑️ Tienda desactivada';
        _guardando  = false;
        notifyListeners();
        await cargarTiendas();
        return true;
      }

      _errorMsg = result['error'] ?? 'Error al desactivar tienda';
      return false;
    } catch (_) {
      _errorMsg = 'Error inesperado al desactivar tienda';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Empleados por tienda ──────────────────────────────

  Future<void> cargarEmpleadosTienda(int tiendaId) async {
    // ✅ FIX: flag propio — no interfiere con cargando de tiendas
    _cargandoEmpleados = true;
    empleadosTienda    = null;
    notifyListeners();

    try {
      empleadosTienda =
          await _service.getEmpleadosPorTienda(tiendaId);
    } catch (_) {
      empleadosTienda = null;
    } finally {
      _cargandoEmpleados = false;
      notifyListeners();
    }
  }
}