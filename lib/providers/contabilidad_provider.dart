import 'package:flutter/material.dart';
import '../models/contabilidad_models.dart';
import '../services/contabilidad_service.dart';

class ContabilidadProvider extends ChangeNotifier {
  final ContabilidadService _service = ContabilidadService();

  ResumenDiario?         resumenDiario;
  ResumenMensual?        resumenMensual;
  Map<String, dynamic>?  resumenAnual;
  Map<String, dynamic>?  gastosResumenRango;
  List<TopProducto>      topProductos  = [];
  List<Gasto>            gastos        = [];

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

  // ── Helper ────────────────────────────────────────────

  String _fechaStr(DateTime? fecha) {
    final d = fecha ?? DateTime.now();
    return '${d.year}-'
           '${d.month.toString().padLeft(2, '0')}-'
           '${d.day.toString().padLeft(2, '0')}';
  }

  // ── Resumen diario ────────────────────────────────────
  // ✅ FIX: Future.wait con tipos explícitos para evitar casts inseguros

  Future<void> cargarResumenDiario({int? tiendaId, DateTime? fecha}) async {
    _cargando = true;
    notifyListeners();

    final fechaStr = _fechaStr(fecha);

    // ✅ Llamadas independientes tipadas — más seguro que Future.wait + cast
    final results = await Future.wait([
      _service.getResumenDiario(tiendaId: tiendaId, fecha: fechaStr),
      _service.getAbonosDia(fechaStr, tiendaId),
      _service.getSeparadosDia(fechaStr, tiendaId),
    ]);

    resumenDiario = results[0] as ResumenDiario?;
    abonosDia     = results[1] as List<Map<String, dynamic>>;
    separadosDia  = results[2] as List<Map<String, dynamic>>;

    _cargando = false;
    notifyListeners();
  }

  // ── Resumen mensual ───────────────────────────────────

  Future<void> cargarResumenMensual({
    int? tiendaId, int? anio, int? mes,
  }) async {
    _cargando = true;
    notifyListeners();
    resumenMensual = await _service.getResumenMensual(
      tiendaId: tiendaId, anio: anio, mes: mes,
    );
    _cargando = false;
    notifyListeners();
  }

  // ── Resumen anual ─────────────────────────────────────

  Future<void> cargarResumenAnual({
    int? tiendaId, required int anio,
  }) async {
    _cargando = true;
    notifyListeners();
    resumenAnual = await _service.getResumenAnual(
      tiendaId: tiendaId, anio: anio,
    );
    _cargando = false;
    notifyListeners();
  }

  // ── Top productos ─────────────────────────────────────

  Future<void> cargarTopProductos({
    int? tiendaId, DateTime? fechaIni, DateTime? fechaFin,
  }) async {
    _cargando = true;
    notifyListeners();
    topProductos = await _service.getTopProductos(
      tiendaId: tiendaId,
      fechaIni: fechaIni != null ? _fechaStr(fechaIni) : null,
      fechaFin: fechaFin != null ? _fechaStr(fechaFin) : null,
    );
    _cargando = false;
    notifyListeners();
  }

  // ── Gastos ────────────────────────────────────────────

  Future<void> cargarGastos({
    int?    tiendaId,
    String? fecha,
    String? fechaIni,
    String? fechaFin,
    String? categoria,
    String? visibilidad,
  }) async {
    _cargando = true;
    notifyListeners();
    gastos = await _service.getGastos(
      tiendaId:    tiendaId,
      fecha:       fecha,
      fechaIni:    fechaIni,
      fechaFin:    fechaFin,
      categoria:   categoria,
      visibilidad: visibilidad,
    );
    _cargando = false;
    notifyListeners();
  }

  // ── Resumen gastos por rango ──────────────────────────

  Future<void> cargarGastosResumenRango({
    required DateTime fechaIni,
    required DateTime fechaFin,
    int?    tiendaId,
    String? categoria,
  }) async {
    _cargando = true;
    notifyListeners();
    gastosResumenRango = await _service.getGastosResumenRango(
      fechaIni:  _fechaStr(fechaIni),
      fechaFin:  _fechaStr(fechaFin),
      tiendaId:  tiendaId,
      categoria: categoria,
    );
    _cargando = false;
    notifyListeners();
  }

  // ── Crear gasto ───────────────────────────────────────

  Future<bool> crearGasto(Map<String, dynamic> data, {
    int?    tiendaId,
    String? fecha,
  }) async {
    _guardando = true;
    _errorMsg  = '';
    notifyListeners();

    final result   = await _service.crearGasto(data);
    _guardando     = false;

    // ✅ FIX: comparación explícita == true (null-safe)
    if (result['success'] == true) {
      _successMsg = '✅ Gasto registrado correctamente';
      await cargarGastos(tiendaId: tiendaId, fecha: fecha);
    } else {
      _errorMsg = result['error'] ?? 'Error desconocido';
    }

    notifyListeners();
    return result['success'] == true;
  }

  // ── Eliminar gasto ────────────────────────────────────

  Future<bool> eliminarGasto(int id, {int? tiendaId}) async {
    // ✅ FIX: service retorna Map — leer ['success'], no tratar como bool
    final result = await _service.eliminarGasto(id);

    if (result['success'] == true) {
      gastos.removeWhere((g) => g.id == id);
      _successMsg = '🗑️ Gasto eliminado';
      notifyListeners();
      return true;
    }

    _errorMsg = result['error'] ?? 'No se pudo eliminar el gasto';
    notifyListeners();
    return false;
  }
}