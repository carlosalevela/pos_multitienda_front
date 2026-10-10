import 'package:flutter/material.dart';
import '../models/contabilidad_models.dart';
import '../services/contabilidad_service.dart';
import '../utils/file_downloader.dart';

class ContabilidadProvider extends ChangeNotifier {
  final ContabilidadService _service = ContabilidadService();

  // ── Datos existentes ──────────────────────────────────
  ResumenDiario?         resumenDiario;
  ResumenMensual?        resumenMensual;
  Map<String, dynamic>?  resumenAnual;
  Map<String, dynamic>?  gastosResumenRango;
  List<TopProducto>      topProductos  = [];
  List<Gasto>            gastos        = [];

  List<Map<String, dynamic>> abonosDia    = [];
  List<Map<String, dynamic>> separadosDia = [];
  List<TopCliente>           topClientes  = [];

  // ── Datos nuevos (P&L, Comparativo, PE, Flujo Caja) ──
  EstadoResultados?        estadoResultados;
  PuntoEquilibrio?         puntoEquilibrio;
  List<TiendaComparativo>  comparativo          = [];
  Map<String, dynamic>?    comparativoTotales;
  List<VentaEmpleado>      vendedores           = [];
  FlujoCajaResumen?        flujoCaja;

  bool   _cargando        = false;
  bool   _guardando       = false;
  bool   _cargandoPl      = false;
  bool   _cargandoFlujo   = false;
  bool   _exportando      = false;
  String _errorMsg        = '';
  String _successMsg      = '';

  bool   get cargando      => _cargando;
  bool   get guardando     => _guardando;
  bool   get cargandoPl    => _cargandoPl;
  bool   get cargandoFlujo => _cargandoFlujo;
  bool   get exportando    => _exportando;
  String get errorMsg      => _errorMsg;
  String get successMsg    => _successMsg;

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
    _errorMsg = '';
    notifyListeners();

    final fechaStr = _fechaStr(fecha);
    try {
      final results = await Future.wait([
        _service.getResumenDiario(tiendaId: tiendaId, fecha: fechaStr),
        _service.getAbonosDia(fechaStr, tiendaId),
        _service.getSeparadosDia(fechaStr, tiendaId),
        _service.getTopClientes(tiendaId: tiendaId, fecha: fechaStr),
      ]);
      resumenDiario = results[0] as ResumenDiario?;
      abonosDia     = results[1] as List<Map<String, dynamic>>;
      separadosDia  = results[2] as List<Map<String, dynamic>>;
      topClientes   = results[3] as List<TopCliente>;
    } catch (e) {
      _errorMsg = 'Error al cargar resumen del día';
      debugPrint('❌ cargarResumenDiario: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Resumen mensual ───────────────────────────────────

  Future<void> cargarResumenMensual({
    int? tiendaId, int? anio, int? mes,
  }) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();
    try {
      resumenMensual = await _service.getResumenMensual(
        tiendaId: tiendaId, anio: anio, mes: mes,
      );
    } catch (e) {
      _errorMsg = 'Error al cargar resumen mensual';
      debugPrint('❌ cargarResumenMensual: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Resumen anual ─────────────────────────────────────

  Future<void> cargarResumenAnual({
    int? tiendaId, required int anio,
  }) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();
    try {
      resumenAnual = await _service.getResumenAnual(
        tiendaId: tiendaId, anio: anio,
      );
    } catch (e) {
      _errorMsg = 'Error al cargar resumen anual';
      debugPrint('❌ cargarResumenAnual: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Top productos ─────────────────────────────────────

  Future<void> cargarTopProductos({
    int? tiendaId, DateTime? fechaIni, DateTime? fechaFin,
  }) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();
    try {
      topProductos = await _service.getTopProductos(
        tiendaId: tiendaId,
        fechaIni: fechaIni != null ? _fechaStr(fechaIni) : null,
        fechaFin: fechaFin != null ? _fechaStr(fechaFin) : null,
      );
    } catch (e) {
      _errorMsg = 'Error al cargar top productos';
      debugPrint('❌ cargarTopProductos: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
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
    _errorMsg = '';
    notifyListeners();
    try {
      gastos = await _service.getGastos(
        tiendaId:    tiendaId,
        fecha:       fecha,
        fechaIni:    fechaIni,
        fechaFin:    fechaFin,
        categoria:   categoria,
        visibilidad: visibilidad,
      );
    } catch (e) {
      _errorMsg = 'Error al cargar gastos';
      debugPrint('❌ cargarGastos: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Resumen gastos por rango ──────────────────────────

  Future<void> cargarGastosResumenRango({
    required DateTime fechaIni,
    required DateTime fechaFin,
    int?    tiendaId,
    String? categoria,
  }) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();
    try {
      gastosResumenRango = await _service.getGastosResumenRango(
        fechaIni:  _fechaStr(fechaIni),
        fechaFin:  _fechaStr(fechaFin),
        tiendaId:  tiendaId,
        categoria: categoria,
      );
    } catch (e) {
      _errorMsg = 'Error al cargar resumen de gastos';
      debugPrint('❌ cargarGastosResumenRango: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
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

  // ── P&L: Estado de Resultados + PE + Comparativo + Empleados ─

  Future<void> cargarPL({
    required String fechaIni,
    required String fechaFin,
    int? tiendaId,
  }) async {
    _cargandoPl = true;
    _errorMsg   = '';
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getEstadoResultados(fechaIni: fechaIni, fechaFin: fechaFin, tiendaId: tiendaId),
        _service.getPuntoEquilibrio(fechaIni: fechaIni, fechaFin: fechaFin, tiendaId: tiendaId),
        _service.getComparativoTiendas(fechaIni: fechaIni, fechaFin: fechaFin),
        _service.getVentasPorEmpleado(fechaIni: fechaIni, fechaFin: fechaFin, tiendaId: tiendaId),
        _service.getTopClientes(fechaIni: fechaIni, fechaFin: fechaFin, tiendaId: tiendaId),
      ]);

      estadoResultados   = results[0] as EstadoResultados?;
      puntoEquilibrio    = results[1] as PuntoEquilibrio?;

      final compData     = results[2] as Map<String, dynamic>?;
      comparativo        = compData != null
          ? (compData['tiendas'] as List<dynamic>)
              .map((e) => TiendaComparativo.fromJson(e as Map<String, dynamic>))
              .toList()
          : [];
      comparativoTotales = compData?['totales'] as Map<String, dynamic>?;

      final empData = results[3] as Map<String, dynamic>?;
      vendedores    = empData != null
          ? (empData['empleados'] as List<dynamic>)
              .map((e) => VentaEmpleado.fromJson(e as Map<String, dynamic>))
              .toList()
          : [];
      topClientes   = results[4] as List<TopCliente>;
    } catch (e) {
      _errorMsg = 'Error al cargar análisis P&L';
      debugPrint('❌ cargarPL: $e');
    } finally {
      _cargandoPl = false;
      notifyListeners();
    }
  }

  // ── Flujo de Caja ─────────────────────────────────────

  Future<void> cargarFlujoCaja({
    required String fechaIni,
    required String fechaFin,
    int? tiendaId,
  }) async {
    _cargandoFlujo = true;
    _errorMsg      = '';
    notifyListeners();
    try {
      flujoCaja = await _service.getFlujoCaja(
        fechaIni: fechaIni, fechaFin: fechaFin, tiendaId: tiendaId,
      );
    } catch (e) {
      _errorMsg = 'Error al cargar flujo de caja';
      debugPrint('❌ cargarFlujoCaja: $e');
    } finally {
      _cargandoFlujo = false;
      notifyListeners();
    }
  }

  // ── Exportar Excel ────────────────────────────────────

  Future<String?> exportarExcel({
    required String tipo,
    required String fechaIni,
    required String fechaFin,
    int? tiendaId,
  }) async {
    _exportando = true;
    _errorMsg   = '';
    notifyListeners();

    final bytes = await _service.exportarExcel(
      tipo:     tipo,
      fechaIni: fechaIni,
      fechaFin: fechaFin,
      tiendaId: tiendaId,
    );

    _exportando = false;

    if (bytes == null) {
      _errorMsg = 'No se pudo descargar el archivo';
      notifyListeners();
      return null;
    }

    try {
      final nombre = '${tipo}_${fechaIni}_$fechaFin.xlsx';
      final ruta   = await guardarArchivoExcel(bytes, nombre);
      _successMsg  = 'Archivo guardado: $ruta';
      notifyListeners();
      return ruta;
    } catch (e) {
      _errorMsg = 'Error al guardar: $e';
      notifyListeners();
      return null;
    }
  }
}