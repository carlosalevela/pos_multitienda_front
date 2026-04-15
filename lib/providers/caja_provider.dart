import 'package:flutter/material.dart';
import '../models/sesion_caja.dart';
import '../models/resumen_cierre.dart';
import '../services/caja_service.dart';

class CajaProvider extends ChangeNotifier {
  final CajaService _service = CajaService();

  SesionCaja?                    _sesionActiva;
  ResumenCierre?                 _resumenCierre;
  List<Map<String, dynamic>>     _historial = [];
  bool   _cargando   = false;
  bool   _procesando = false;
  String _errorMsg   = '';
  String _successMsg = '';

  SesionCaja?                get sesionActiva  => _sesionActiva;
  ResumenCierre?             get resumenCierre => _resumenCierre;
  List<Map<String, dynamic>> get historial     => _historial;
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

  // ── Verificar sesión activa ────────────────────────────

  Future<void> verificarSesion(int tiendaId) async {
    _cargando = true;
    notifyListeners();
    _sesionActiva = await _service.getSesionActiva(tiendaId);
    _cargando = false;
    notifyListeners();
  }

  // ── Resumen pre-cierre ─────────────────────────────────
  // ✅ usa solo getResumenCierre — ya incluye abonos completos

  Future<void> cargarResumenCierre() async {
    if (_sesionActiva == null) return;
    _resumenCierre = null;
    notifyListeners();

    _resumenCierre = await _service.getResumenCierre(_sesionActiva!.id);
    notifyListeners();
  }

  // ── Abrir caja ─────────────────────────────────────────

    Future<bool> abrirCaja({
  required int    tiendaId,
  required double saldoInicial,
}) async {
  _procesando = true;
  _errorMsg   = '';
  notifyListeners();

  final result = await _service.abrirCaja(saldoInicial: saldoInicial);
  _procesando  = false;

  if (result['success'] == true) {
    // ✅ FIX: null-safe — evita crash si data viene null
    final data = result['data'];
    if (data != null) {
      _sesionActiva = SesionCaja.fromJson(data);
      _successMsg   = '✅ Caja abierta correctamente';
    } else {
      await verificarSesion(tiendaId);
    }
  } else if (result['ya_abierta'] == true) {
    await verificarSesion(tiendaId);
    if (_sesionActiva != null) _successMsg = 'ℹ️ Caja ya estaba abierta';
  } else {
    _errorMsg = result['error'] ?? 'Error desconocido';
  }

  notifyListeners();
  return _sesionActiva != null;
}

  // ── Cerrar caja ────────────────────────────────────────

  Future<bool> cerrarCaja({
    required double montoFinalReal,
    String observaciones = '',
  }) async {
    if (_sesionActiva == null) return false;

    _procesando = true;
    _errorMsg   = '';
    notifyListeners();

    final result = await _service.cerrarCaja(
      _sesionActiva!.id,
      montoFinalReal: montoFinalReal,
      observaciones:  observaciones,
    );

    _procesando = false;

    if (result['success'] == true) {
      _sesionActiva  = null;
      _resumenCierre = null;
      _successMsg    = '✅ Caja cerrada correctamente';
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }

    notifyListeners();
    return result['success'] == true;
  }

  // ── Historial de sesiones ✅ NUEVO ─────────────────────

    Future<void> cargarHistorial({
      int?    tiendaId,
      String? estado,
      String? fecha,
    }) async {
      _cargando = true;
      notifyListeners();

      try {
        // ✅ FIX: try-catch garantiza que _cargando = false siempre
        _historial = await _service.getHistorialSesiones(
          tiendaId: tiendaId,
          estado:   estado,
          fecha:    fecha,
        );
      } catch (e) {
        _historial = [];
        _errorMsg  = 'Error al cargar historial';
      }

      _cargando = false;
      notifyListeners();
    }
}