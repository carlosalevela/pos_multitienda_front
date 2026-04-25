// lib/providers/empresa_provider.dart

import 'package:flutter/material.dart';
import '../models/empresa_model.dart';
import '../services/empresa_service.dart';

class EmpresaProvider extends ChangeNotifier {
  final EmpresaService _service = EmpresaService();

  List<Empresa> empresas = [];
  Empresa? empresaActual;

  bool _cargando = false;
  bool _guardando = false;
  String _errorMsg = '';
  String _successMsg = '';

  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String get errorMsg => _errorMsg;
  String get successMsg => _successMsg;

  int get totalEmpresas => empresas.length;
  int get totalActivas => empresas.where((e) => e.activo).length;
  int get totalInactivas => empresas.where((e) => !e.activo).length;

  void limpiarMensajes() {
    _errorMsg = '';
    _successMsg = '';
    notifyListeners();
  }

  void limpiarEmpresaActual() {
    empresaActual = null;
    notifyListeners();
  }

  Future<void> cargarEmpresas() async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    try {
      empresas = await _service.getEmpresas();
    } catch (_) {
      _errorMsg = 'Error al cargar empresas';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cargarDetalleEmpresa(int id) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    try {
      empresaActual = await _service.getEmpresaDetalle(id);
      if (empresaActual == null) {
        _errorMsg = 'No se pudo cargar la empresa';
      }
    } catch (_) {
      _errorMsg = 'Error al cargar detalle de la empresa';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> crearEmpresa(Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg = '';
    _successMsg = '';
    notifyListeners();

    try {
      final result = await _service.crearEmpresa(data);

      if (result['success'] == true) {
        _successMsg = '✅ Empresa creada correctamente';
        await cargarEmpresas();
        return true;
      }

      _errorMsg = result['error'] ?? 'Error desconocido';
      return false;
    } catch (_) {
      _errorMsg = 'Error inesperado al crear empresa';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  Future<bool> editarEmpresa(int id, Map<String, dynamic> data) async {
    _guardando = true;
    _errorMsg = '';
    _successMsg = '';
    notifyListeners();

    try {
      final result = await _service.editarEmpresa(id, data);

      if (result['success'] == true) {
        _successMsg = '✅ Empresa actualizada correctamente';

        if (empresaActual != null && empresaActual!.id == id) {
          empresaActual = result['data'] as Empresa;
        }

        await cargarEmpresas();
        return true;
      }

      _errorMsg = result['error'] ?? 'Error desconocido';
      return false;
    } catch (_) {
      _errorMsg = 'Error inesperado al editar empresa';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }
}