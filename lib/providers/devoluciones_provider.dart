// lib/providers/devoluciones_provider.dart

import 'package:flutter/material.dart';
import 'package:pos_multitienda_app/models/devolucion_model.dart';
import 'package:pos_multitienda_app/services/devoluciones_service.dart';

class DevolucionesProvider extends ChangeNotifier {
  final DevolucionesService _service = DevolucionesService();

  List<DevolucionModel> _devoluciones = [];
  DevolucionModel?      _detalle;
  bool                  _cargando  = false;
  bool                  _guardando = false;
  String?               _error;

  List<DevolucionModel> get devoluciones => _devoluciones;
  DevolucionModel?      get detalle      => _detalle;
  bool                  get cargando     => _cargando;
  bool                  get guardando    => _guardando;
  String?               get error        => _error;

  // ── Listar ─────────────────────────────────────────
  Future<void> cargarDevoluciones({
    String? token,   // ✅ opcional e ignorado — ApiClient lo maneja
    int?    tiendaId,
    String? estado,
    String? fecha,
    String? fechaIni,
    String? fechaFin,
  }) async {
    _cargando = true;
    _error    = null;
    notifyListeners();

    try {
      // ✅ FIX: listar() → getDevoluciones()
      _devoluciones = await _service.getDevoluciones(
        tiendaId: tiendaId,
        estado:   estado,
        fecha:    fecha,
        fechaIni: fechaIni,
        fechaFin: fechaFin,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Detalle ────────────────────────────────────────
  Future<void> cargarDetalle(int id) async {
    _cargando = true;
    _detalle  = null;
    _error    = null;
    notifyListeners();

    try {
      // ✅ FIX: detalle() → getDevolucion()
      _detalle = await _service.getDevolucion(id);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Crear ──────────────────────────────────────────
  Future<Map<String, dynamic>?> crearDevolucion({
    String?                             token,      // ✅ opcional e ignorado
    required int                        ventaId,
    required String                     metodoPago,
    required List<Map<String, dynamic>> detalles,
    String?                             observaciones,
    int?                                tiendaId,
  }) async {
    _guardando = true;
    _error     = null;
    notifyListeners();

    try {
      // ✅ FIX: crear() → crearDevolucion() con firma correcta
      final dev = await _service.crearDevolucion(
        ventaId:       ventaId,
        metodoPago:    metodoPago,
        detalles:      detalles,
        observaciones: observaciones,
        tiendaId:      tiendaId,
      );
      return dev;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Cancelar ───────────────────────────────────────
  Future<bool> cancelarDevolucion({
  String? token,
  required int id,
}) async {
  _guardando = true;
  _error     = null;
  notifyListeners();

  try {
    // ✅ FIX: usar el bool que devuelve el servicio
    final ok = await _service.cancelarDevolucion(id: id);

    if (!ok) {
      _error = 'No se pudo cancelar la devolución';
      return false;
    }

    _devoluciones = _devoluciones.map((d) =>
        d.id == id ? _copiarCancelada(d) : d).toList();

    if (_detalle?.id == id) {
      _detalle = _copiarCancelada(_detalle!);
    }

    return true;
  } catch (e) {
    _error = e.toString().replaceFirst('Exception: ', '');
    return false;
  } finally {
    _guardando = false;
    notifyListeners();
  }
}

  // ── Helpers ────────────────────────────────────────
  DevolucionModel _copiarCancelada(DevolucionModel d) => DevolucionModel(
    id:               d.id,
    ventaId:          d.ventaId,
    ventaNumero:      d.ventaNumero,
    tiendaId:         d.tiendaId,
    tiendaNombre:     d.tiendaNombre,
    empleadoId:       d.empleadoId,
    empleadoNombre:   d.empleadoNombre,
    totalDevuelto:    d.totalDevuelto,
    metodoDevolucion: d.metodoDevolucion,
    estado:           'cancelada',
    observaciones:    d.observaciones,
    createdAt:        d.createdAt,
    detalles:         d.detalles,
  );

  void limpiar() {
    _devoluciones = [];
    _detalle      = null;
    _cargando     = false;
    _guardando    = false;
    _error        = null;
    notifyListeners();
  }
}