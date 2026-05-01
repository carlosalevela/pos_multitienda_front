import 'package:flutter/material.dart';
import '../models/sesion_caja.dart';
import '../models/resumen_cierre.dart';
import '../models/sesion_historial.dart';        // ← NUEVO
import '../services/caja_service.dart';


class CajaProvider extends ChangeNotifier {
  final CajaService _service = CajaService();

  SesionCaja?           _sesionActiva;
  ResumenCierre?        _resumenCierre;
  List<SesionHistorial> _historial = [];         // ← CAMBIAR tipo
  bool   _cargando   = false;
  bool   _procesando = false;
  String _errorMsg   = '';
  String _successMsg = '';

  SesionCaja?           get sesionActiva  => _sesionActiva;
  ResumenCierre?        get resumenCierre => _resumenCierre;
  List<SesionHistorial> get historial     => _historial;  // ← CAMBIAR tipo
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

  // ── Historial de sesiones ──────────────────────────────

  Future<void> cargarHistorial({
    int?    tiendaId,
    String? estado,
    String? fecha,
  }) async {
    _cargando = true;
    notifyListeners();

    try {
      final raw = await _service.getHistorialSesiones(
        tiendaId: tiendaId,
        estado:   estado ?? 'cerrada',
        fecha:    fecha,
      );
      // ← CAMBIAR: parsear a SesionHistorial
      _historial = (raw as List)
          .map((e) => SesionHistorial.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _historial = [];
      _errorMsg  = 'Error al cargar historial';
    }

    _cargando = false;
    notifyListeners();
  }

  // ── Limpiar historial ──────────────────────────────────

  void limpiarHistorial() {
    _historial = [];
    notifyListeners();
  }
}