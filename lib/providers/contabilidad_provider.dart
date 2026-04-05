import 'package:flutter/material.dart';
import '../models/contabilidad_models.dart';
import '../services/contabilidad_service.dart';

class ContabilidadProvider extends ChangeNotifier {
  final ContabilidadService _service = ContabilidadService();

  ResumenDiario?    resumenDiario;
  ResumenMensual?   resumenMensual;
  List<TopProducto> topProductos = [];
  List<Gasto>       gastos       = [];

  List<Map<String, dynamic>> abonosDia    = [];
  List<Map<String, dynamic>> separadosDia = [];

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

  // ✅ FIX: recibe DateTime? y convierte internamente a String
  Future<void> cargarResumenDiario({int? tiendaId, DateTime? fecha}) async {
    _cargando = true;
    notifyListeners();

    final fechaStr = fecha != null
        ? '${fecha.year}-'
          '${fecha.month.toString().padLeft(2, '0')}-'
          '${fecha.day.toString().padLeft(2, '0')}'
        : '${DateTime.now().year}-'
          '${DateTime.now().month.toString().padLeft(2, '0')}-'
          '${DateTime.now().day.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      _service.getResumenDiario(tiendaId: tiendaId, fecha: fechaStr),
      _service.getAbonosDia(fechaStr, tiendaId),    // ✅ nuevo
      _service.getSeparadosDia(fechaStr, tiendaId), // ✅ nuevo
    ]);

    resumenDiario = results[0] as ResumenDiario?;
    abonosDia     = results[1] as List<Map<String, dynamic>>;
    separadosDia  = results[2] as List<Map<String, dynamic>>;

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