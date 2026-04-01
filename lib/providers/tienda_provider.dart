import 'package:flutter/material.dart';
import '../models/tienda_model.dart';
import '../services/tienda_service.dart';

class TiendaProvider extends ChangeNotifier {
  final TiendaService _service = TiendaService();

  List<Tienda> tiendas    = [];
  bool   _cargando        = false;
  bool   _guardando       = false;
  String _errorMsg        = '';
  String _successMsg      = '';

  bool   get cargando   => _cargando;
  bool   get guardando  => _guardando;
  String get errorMsg   => _errorMsg;
  String get successMsg => _successMsg;

  int get totalActivas   => tiendas.where((t) => t.activo).length;
  int get totalInactivas => tiendas.where((t) => !t.activo).length;

  void limpiarMensajes() {
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }

  Future<void> cargarTiendas() async {
    _cargando = true;
    notifyListeners();
    tiendas = await _service.getTiendas();
    _cargando = false;
    notifyListeners();
  }

  Future<bool> crearTienda(Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();
    final result = await _service.crearTienda(data);
    _guardando = false;
    if (result['success']) {
      _successMsg = '✅ Tienda creada correctamente';
      await cargarTiendas();
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }
    notifyListeners();
    return result['success'];
  }

  Future<bool> editarTienda(int id, Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();
    final result = await _service.editarTienda(id, data);
    _guardando = false;
    if (result['success']) {
      _successMsg = '✅ Tienda actualizada correctamente';
      await cargarTiendas();
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }
    notifyListeners();
    return result['success'];
  }

  Future<void> desactivarTienda(int id) async {
    final ok = await _service.desactivarTienda(id);
    if (ok) {
      _successMsg = '🗑️ Tienda desactivada';
      await cargarTiendas();
      notifyListeners();
    }
  }
}