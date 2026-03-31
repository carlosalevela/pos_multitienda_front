import 'package:flutter/material.dart';
import '../models/sesion_caja.dart';
import '../models/resumen_cierre.dart';
import '../services/caja_service.dart';

class CajaProvider extends ChangeNotifier {
  final CajaService _service = CajaService();

  SesionCaja?   _sesionActiva;
  ResumenCierre? _resumenCierre;    // ← nuevo
  bool   _cargando   = false;
  bool   _procesando = false;
  String _errorMsg   = '';
  String _successMsg = '';

  SesionCaja?   get sesionActiva  => _sesionActiva;
  ResumenCierre? get resumenCierre => _resumenCierre; // ← nuevo
  bool   get cargando    => _cargando;
  bool   get procesando  => _procesando;
  String get errorMsg    => _errorMsg;
  String get successMsg  => _successMsg;
  bool   get cajaAbierta => _sesionActiva?.abierta ?? false;

  void limpiarMensajes() {
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }

  Future<void> verificarSesion(int tiendaId) async {
    _cargando = true;
    notifyListeners();
    _sesionActiva = await _service.getSesionActiva(tiendaId);
    _cargando = false;
    notifyListeners();
  }

  // ← nuevo: carga el resumen pre-cierre
  Future<void> cargarResumenCierre() async {
    if (_sesionActiva == null) return;
    _resumenCierre = null;
    notifyListeners();
    _resumenCierre = await _service.getResumenCierre(_sesionActiva!.id);
    notifyListeners();
  }

  Future<bool> abrirCaja({
    required int    tiendaId,
    required double saldoInicial,
  }) async {
    _procesando = true;
    _errorMsg   = '';
    notifyListeners();

    final result = await _service.abrirCaja(saldoInicial: saldoInicial);
    _procesando = false;

    if (result['success'] == true) {
      _sesionActiva = SesionCaja.fromJson(result['data']);
      _successMsg   = '✅ Caja abierta correctamente';
    } else if (result['ya_abierta'] == true) {
      await verificarSesion(tiendaId);
      if (_sesionActiva != null) _successMsg = 'ℹ️ Caja ya estaba abierta';
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }

    notifyListeners();
    return _sesionActiva != null;
  }

  Future<bool> cerrarCaja({
    required double montoFinalReal,
    String observaciones = '',               // ← nuevo
  }) async {
    if (_sesionActiva == null) return false;

    _procesando = true;
    _errorMsg   = '';
    notifyListeners();

    final result = await _service.cerrarCaja(
      _sesionActiva!.id,
      montoFinalReal: montoFinalReal,
      observaciones:  observaciones,         // ← nuevo
    );

    _procesando = false;

    if (result['success']) {
      _sesionActiva  = null;
      _resumenCierre = null;                 // ← limpiar
      _successMsg    = '✅ Caja cerrada correctamente';
    } else {
      _errorMsg = result['error'];
    }

    notifyListeners();
    return result['success'];
  }
}