import 'package:flutter/material.dart';
import '../models/sesion_caja.dart';
import '../models/resumen_cierre.dart';
import '../models/sesion_historial.dart';        // ← NUEVO
import '../services/caja_service.dart';


class CajaProvider extends ChangeNotifier {
  final CajaService _service = CajaService();

  SesionCaja?           _sesionActiva;
  SesionCaja?           _ultimaSesionCerrada;
  ResumenCierre?        _resumenCierre;
  List<SesionHistorial> _historial = [];         // ← CAMBIAR tipo
  bool   _cargando   = false;
  bool   _procesando = false;
  String _errorMsg   = '';
  String _successMsg = '';

  // ── Gastos del turno ──────────────────────────────────
  List<Map<String, dynamic>> _gastosSesion     = [];
  double                     _gastosTotalSesion = 0;
  bool                       _cargandoGastos   = false;

  SesionCaja?           get sesionActiva          => _sesionActiva;
  SesionCaja?           get ultimaSesionCerrada   => _ultimaSesionCerrada;
  ResumenCierre?        get resumenCierre         => _resumenCierre;
  List<SesionHistorial> get historial         => _historial;  // ← CAMBIAR tipo
  bool   get cargando         => _cargando;
  bool   get procesando       => _procesando;
  String get errorMsg         => _errorMsg;
  String get successMsg       => _successMsg;
  bool   get cajaAbierta      => _sesionActiva?.abierta ?? false;
  List<Map<String, dynamic>> get gastosSesion     => _gastosSesion;
  double                     get gastosTotalSesion => _gastosTotalSesion;
  bool                       get cargandoGastos   => _cargandoGastos;


  void limpiarMensajes() {
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }

  // ── Verificar sesión activa ────────────────────────────

  Future<void> verificarSesion(int tiendaId) async {
    _cargando = true;
    notifyListeners();
    try {
      _sesionActiva = await _service.getSesionActiva(tiendaId);
    } catch (_) {
      // Error de red: conservamos el estado anterior en lugar de asumir
      // que no hay caja abierta, evitando bloquear al cajero por un corte
      // momentáneo de conexión.
    }
    _cargando = false;
    notifyListeners();
  }

  // ── Resumen pre-cierre ─────────────────────────────────

  Future<bool> cargarResumenCierre() async {
    if (_sesionActiva == null) return false;
    _resumenCierre = null;
    notifyListeners();
    try {
      _resumenCierre = await _service.getResumenCierre(_sesionActiva!.id);
    } catch (_) {
      _errorMsg = 'No se pudo cargar el resumen de cierre.';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
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
      _ultimaSesionCerrada = _sesionActiva; // guarda antes de limpiar
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

  // ── Gastos del turno activo ────────────────────────────

  Future<void> cargarGastosSesion(int sesionId) async {
    _cargandoGastos = true;
    notifyListeners();

    final result = await _service.getGastosSesion(sesionId);
    if (result['success'] == true) {
      final data = result['data'];
      _gastosSesion     = List<Map<String, dynamic>>.from(data['gastos'] ?? []);
      _gastosTotalSesion = double.tryParse(
          data['resumen']?['total']?.toString() ?? '0') ?? 0;
    } else {
      _gastosSesion     = [];
      _gastosTotalSesion = 0;
    }

    _cargandoGastos = false;
    notifyListeners();
  }

  Future<bool> registrarGasto({
    required int    sesionId,
    required int    tiendaId,
    required String categoria,
    required String descripcion,
    required double monto,
    required String metodoPago,
  }) async {
    _procesando = true;
    notifyListeners();

    final result = await _service.registrarGasto(
      sesionId:    sesionId,
      tiendaId:    tiendaId,
      categoria:   categoria,
      descripcion: descripcion,
      monto:       monto,
      metodoPago:  metodoPago,
    );

    _procesando = false;

    if (result['success'] == true) {
      _successMsg = '✅ Gasto registrado';
      await cargarGastosSesion(sesionId);
    } else {
      _errorMsg = result['error'] ?? 'Error al registrar gasto';
      notifyListeners();
    }

    return result['success'] == true;
  }
}