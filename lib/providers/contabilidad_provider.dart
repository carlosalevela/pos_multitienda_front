import 'package:flutter/material.dart';
import '../models/contabilidad_models.dart';
import '../services/contabilidad_service.dart';

class ContabilidadProvider extends ChangeNotifier {
  final ContabilidadService _service = ContabilidadService();

  ResumenDiario?   resumenDiario;
  ResumenMensual?  resumenMensual;
  List<TopProducto> topProductos = [];
  List<Gasto>       gastos       = [];

  bool   _cargando   = false;
  bool   _guardando  = false;
  String _errorMsg   = '';
  String _successMsg = '';

  bool   get cargando   => _cargando;
  bool   get guardando  => _guardando;
  String get errorMsg   => _errorMsg;
  String get successMsg => _successMsg;

  void limpiarMensajes() {
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }

  Future<void> cargarResumenDiario({int? tiendaId, String? fecha}) async {
    _cargando = true;
    notifyListeners();
    resumenDiario = await _service.getResumenDiario(
        tiendaId: tiendaId, fecha: fecha);
    _cargando = false;
    notifyListeners();
  }

  Future<void> cargarResumenMensual({int? tiendaId, int? anio, int? mes}) async {
    _cargando = true;
    notifyListeners();
    resumenMensual = await _service.getResumenMensual(
        tiendaId: tiendaId, anio: anio, mes: mes);
    _cargando = false;
    notifyListeners();
  }

  Future<void> cargarTopProductos({int? tiendaId}) async {
    _cargando = true;
    notifyListeners();
    topProductos = await _service.getTopProductos(tiendaId: tiendaId);
    _cargando = false;
    notifyListeners();
  }

  Future<void> cargarGastos({int? tiendaId, String? fecha}) async {
    _cargando = true;
    notifyListeners();
    gastos = await _service.getGastos(tiendaId: tiendaId, fecha: fecha);
    _cargando = false;
    notifyListeners();
  }

  Future<bool> crearGasto(Map<String, dynamic> data, {int? tiendaId}) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();
    final result = await _service.crearGasto(data);
    _guardando = false;
    if (result['success']) {
      _successMsg = '✅ Gasto registrado correctamente';
      await cargarGastos(tiendaId: tiendaId);
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }
    notifyListeners();
    return result['success'];
  }

  Future<void> eliminarGasto(int id, {int? tiendaId}) async {
    final ok = await _service.eliminarGasto(id);
    if (ok) {
      gastos.removeWhere((g) => g.id == id);
      _successMsg = '🗑️ Gasto eliminado';
      notifyListeners();
    }
  }
}