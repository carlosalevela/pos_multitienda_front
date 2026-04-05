import 'package:flutter/material.dart';
import '../models/sesion_caja.dart';
import '../models/resumen_cierre.dart';
import '../services/caja_service.dart';

class CajaProvider extends ChangeNotifier {
  final CajaService _service = CajaService();

  SesionCaja?    _sesionActiva;
  ResumenCierre? _resumenCierre;
  bool   _cargando   = false;
  bool   _procesando = false;
  String _errorMsg   = '';
  String _successMsg = '';

  SesionCaja?    get sesionActiva   => _sesionActiva;
  ResumenCierre? get resumenCierre  => _resumenCierre;
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

  Future<void> cargarResumenCierre() async {
    if (_sesionActiva == null) return;
    _resumenCierre = null;
    notifyListeners();

    final results = await Future.wait([
      _service.getResumenCierre(_sesionActiva!.id),
      _service.getAbonosSesion(_sesionActiva!.fecha_apertura),
    ]);

    final resumen = results[0] as ResumenCierre?;
    final abonos  = results[1] as AbonosCierre;

    if (resumen == null) return;

    // ✅ Si el backend ya retorna abonos con breakdown, lo usa;
    //    si no, usa el calculado por el servicio desde la lista
    final abonosFinales = resumen.abonos.total > 0
        ? resumen.abonos   // el backend ya lo retorna completo
        : abonos;          // fallback: calculado desde /clientes/abonos/

    _resumenCierre = ResumenCierre(
      sesionId:          resumen.sesionId,
      tiendaNombre:      resumen.tiendaNombre,
      empleadoNombre:    resumen.empleadoNombre,
      fechaApertura:     resumen.fechaApertura,
      montoInicial:      resumen.montoInicial,
      montoEsperadoCaja: resumen.montoEsperadoCaja,
      ventas:            resumen.ventas,
      gastos:            resumen.gastos,
      abonos:            abonosFinales,
    );

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
    _procesando  = false;

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

    if (result['success']) {
      _sesionActiva  = null;
      _resumenCierre = null;
      _successMsg    = '✅ Caja cerrada correctamente';
    } else {
      _errorMsg = result['error'];
    }

    notifyListeners();
    return result['success'];
  }
}