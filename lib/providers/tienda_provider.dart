import 'package:flutter/material.dart';
import '../models/tienda_model.dart';
import '../services/tienda_service.dart';

class TiendaProvider extends ChangeNotifier {
  final TiendaService _service = TiendaService();

  List<Tienda> tiendas = [];
  Map<String, dynamic>? empleadosTienda;

  bool _cargando = false;
  bool _cargandoEmpleados = false;
  bool _guardando = false;
  String _errorMsg = '';
  String _successMsg = '';

  bool get cargando => _cargando;
  bool get cargandoEmpleados => _cargandoEmpleados;
  bool get guardando => _guardando;
  String get errorMsg => _errorMsg;
  String get successMsg => _successMsg;

  int get totalActivas => tiendas.where((t) => t.activo).length;
  int get totalInactivas => tiendas.where((t) => !t.activo).length;

  void limpiarMensajes() {
    _errorMsg = '';
    _successMsg = '';
    notifyListeners();
  }

  // ── Cargar todas las tiendas ─────────────────────────
  Future<void> cargarTiendas({
    bool? soloActivas,
    int? empresaId,
  }) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    try {
      tiendas = await _service.getTiendas(
        soloActivas: soloActivas,
        empresaId: empresaId,
      );
    } catch (_) {
      _errorMsg = 'Error al cargar tiendas';
      tiendas = [];
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Tiendas por empresa ──────────────────────────────
  Future<void> cargarTiendasPorEmpresa(int empresaId) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    try {
      tiendas = await _service.getTiendas(empresaId: empresaId);
    } catch (_) {
      _errorMsg = 'Error al cargar sucursales';
      tiendas = [];
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Crear tienda ─────────────────────────────────────
  Future<bool> crearTienda(
    Map<String, dynamic> data, {
    int? empresaId,
  }) async {
    _guardando = true;
    _errorMsg = '';
    _successMsg = '';
    notifyListeners();

    try {
      final result = await _service.crearTienda(data);

      if (result['success'] == true) {
        _successMsg = '✅ Sucursal creada correctamente';

        if (empresaId != null) {
          await cargarTiendasPorEmpresa(empresaId);
        } else {
          await cargarTiendas();
        }

        return true;
      }

      _errorMsg = result['error'] ?? 'Error desconocido';
      return false;
    } catch (_) {
      _errorMsg = 'Error inesperado al crear sucursal';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Editar tienda ────────────────────────────────────
  Future<bool> editarTienda(
    int id,
    Map<String, dynamic> data, {
    int? empresaId,
  }) async {
    _guardando = true;
    _errorMsg = '';
    _successMsg = '';
    notifyListeners();

    try {
      final result = await _service.editarTienda(id, data);

      if (result['success'] == true) {
        _successMsg = '✅ Sucursal actualizada correctamente';

        final idx = tiendas.indexWhere((t) => t.id == id);
        if (idx != -1) {
          tiendas[idx] = tiendas[idx].copyWith(
            nombre: data['nombre'] ?? tiendas[idx].nombre,
            direccion: data['direccion'] ?? tiendas[idx].direccion,
            telefono: data['telefono'] ?? tiendas[idx].telefono,
            ciudad: data['ciudad'] ?? tiendas[idx].ciudad,
            nit: data['nit'] ?? tiendas[idx].nit,
          );
          notifyListeners();
        }

        if (empresaId != null) {
          await cargarTiendasPorEmpresa(empresaId);
        }

        return true;
      }

      _errorMsg = result['error'] ?? 'Error desconocido';
      return false;
    } catch (_) {
      _errorMsg = 'Error inesperado al editar sucursal';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Desactivar tienda ────────────────────────────────
  Future<bool> desactivarTienda(int id, {int? empresaId}) async {
    _guardando = true;
    _errorMsg = '';
    _successMsg = '';
    notifyListeners();

    try {
      final result = await _service.desactivarTienda(id);

      if (result['success'] == true) {
        _successMsg = '🗑️ Sucursal desactivada';

        final idx = tiendas.indexWhere((t) => t.id == id);
        if (idx != -1) {
          tiendas[idx] = tiendas[idx].copyWith(activo: false);
          notifyListeners();
        }

        if (empresaId != null) {
          await cargarTiendasPorEmpresa(empresaId);
        }

        return true;
      }

      _errorMsg = result['error'] ?? 'Error al desactivar sucursal';
      return false;
    } catch (_) {
      _errorMsg = 'Error inesperado al desactivar sucursal';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  // ── Cargar empleados de una tienda ───────────────────
  Future<void> cargarEmpleadosTienda(int tiendaId) async {
    _cargandoEmpleados = true;
    empleadosTienda = null;
    _errorMsg = '';
    notifyListeners();

    try {
      empleadosTienda = await _service.getEmpleadosPorTienda(tiendaId);
    } catch (_) {
      empleadosTienda = null;
      _errorMsg = 'Error al cargar empleados';
    } finally {
      _cargandoEmpleados = false;
      notifyListeners();
    }
  }
}