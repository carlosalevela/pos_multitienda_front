import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../models/separado.dart';
import '../models/alerta_separado.dart';
import '../services/cliente_service.dart';


class ClienteProvider extends ChangeNotifier {
  final _service = ClienteService();


  // ── Estado clientes ────────────────────────────────────────
  List<Cliente> clientes            = [];
  List<Cliente> clientesSimple      = [];
  Cliente?      clienteSeleccionado;


  // ── Estado separados (lista general) ──────────────────────
  List<Separado> separados          = [];
  Separado?      separadoSeleccionado;


  // ── Estado detalle de cliente ──────────────────────────────
  List<Separado> separadosActivos   = [];
  List<Separado> historialCliente   = [];
  bool           cargandoDetalle    = false;
  int?           _clienteDetalleId;


  // ── Estado abonos por fecha ────────────────────────────────
  List<Map<String, dynamic>> abonosPorFecha     = [];
  double                     totalAbonosPorFecha = 0.0;


  // ── Estado general ─────────────────────────────────────────
  bool    _cargando  = false;
  bool    _guardando = false;
  String? error;


  bool get cargando  => _cargando;
  bool get guardando => _guardando;


  // ── Alertas ────────────────────────────────────────────────
  List<AlertaSeparado> _vencidos     = [];
  List<AlertaSeparado> _porVencer    = [];
  int                  _totalAlertas = 0;
  int?                 _tiendaIdAlertas;


  List<AlertaSeparado> get vencidos     => _vencidos;
  List<AlertaSeparado> get porVencer    => _porVencer;
  int                  get totalAlertas => _totalAlertas;



  // ══════════════════════════════════════════════════════════
  // CLIENTES
  // ══════════════════════════════════════════════════════════


  Future<void> cargarClientes({String? q, int? tiendaId}) async {
    _cargando = true;
    error     = null;
    notifyListeners();


    try {
      clientes = await _service.getClientes(q: q, tiendaId: tiendaId);
      debugPrint('✅ cargarClientes: ${clientes.length} clientes, tiendaId=$tiendaId');
    } catch (e) {
      error    = 'Error al cargar clientes';
      clientes = [];
      debugPrint('❌ cargarClientes: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }


  Future<void> cargarClientesSimple({String? q}) async {
    try {
      clientesSimple = await _service.getClientesSimple(q: q);
    } catch (e) {
      clientesSimple = [];
      debugPrint('❌ cargarClientesSimple: $e');
    } finally {
      notifyListeners();
    }
  }


  Future<void> cargarCliente(int id) async {
    _cargando = true;
    notifyListeners();


    try {
      clienteSeleccionado = await _service.getCliente(id);
    } catch (e) {
      debugPrint('❌ cargarCliente: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }


  Future<bool> crearCliente(Map<String, dynamic> data) async {
    _guardando = true;
    error      = null;
    notifyListeners();


    final result = await _service.crearCliente(data);
    _guardando   = false;


    if (result['success'] == true) {
      final nuevo = result['data'] as Cliente;
      clientes    = [nuevo, ...clientes];
      notifyListeners();
      return true;
    }


    error = result['error'] ?? 'No se pudo crear el cliente';
    notifyListeners();
    return false;
  }


  Future<bool> editarCliente(int id, Map<String, dynamic> data) async {
    _guardando = true;
    error      = null;
    notifyListeners();


    final result = await _service.editarCliente(id, data);
    _guardando   = false;


    if (result['success'] == true) {
      final actualizado = result['data'] as Cliente;
      clientes = clientes
          .map((c) => c.id == id ? actualizado : c)
          .toList();
      if (clienteSeleccionado?.id == id) clienteSeleccionado = actualizado;
      notifyListeners();
      return true;
    }


    error = result['error'] ?? 'No se pudo editar el cliente';
    notifyListeners();
    return false;
  }


  Future<bool> desactivarCliente(int id) async {
    final result = await _service.desactivarCliente(id);


    if (result['success'] == true) {
      clientes = clientes.where((c) => c.id != id).toList();
      if (clienteSeleccionado?.id == id) clienteSeleccionado = null;
    } else {
      error = result['error'];
    }


    notifyListeners();
    return result['success'] == true;
  }


  Future<bool> activarCliente(int id) async {
    final result = await _service.activarCliente(id);


    if (result['success'] == true) {
      final actualizado = result['data'] as Cliente;
      clientes = clientes
          .map((c) => c.id == id ? actualizado : c)
          .toList();
    } else {
      error = result['error'];
    }


    notifyListeners();
    return result['success'] == true;
  }


  void limpiarClientes() {
    clientes = [];
    notifyListeners();
  }



  // ══════════════════════════════════════════════════════════
  // DETALLE DE CLIENTE
  // ══════════════════════════════════════════════════════════


  Future<void> cargarDetalleCliente(int clienteId) async {
    if (_clienteDetalleId == clienteId) return;
    _clienteDetalleId = clienteId;
    cargandoDetalle   = true;
    error             = null;
    notifyListeners();


    try {
      final results = await Future.wait([
        _service.getSeparados(clienteId: clienteId, estado: 'activo'),
        _service.getSeparados(
            clienteId: clienteId,
            estados:   ['completado', 'cancelado']),
      ]);


      separadosActivos = results[0];
      historialCliente = results[1]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      error            = 'Error al cargar detalle del cliente';
      separadosActivos = [];
      historialCliente = [];
      debugPrint('❌ cargarDetalleCliente: $e');
    } finally {
      cargandoDetalle = false;
      notifyListeners();
    }
  }


  Future<void> _refrescarDetalleCliente() async {
    if (_clienteDetalleId == null) return;
    final id          = _clienteDetalleId!;
    _clienteDetalleId = null;
    await cargarDetalleCliente(id);
  }


  void limpiarDetalleCliente() {
    separadosActivos  = [];
    historialCliente  = [];
    cargandoDetalle   = false;
    _clienteDetalleId = null;
    notifyListeners();
  }



  // ══════════════════════════════════════════════════════════
  // SEPARADOS
  // ══════════════════════════════════════════════════════════


  Future<void> cargarSeparados({
    int? tiendaId, String? estado, int? clienteId,
  }) async {
    _cargando = true;
    error     = null;
    notifyListeners();


    try {
      separados = await _service.getSeparados(
        tiendaId:  tiendaId,
        estado:    estado,
        clienteId: clienteId,
      );
    } catch (e) {
      error     = 'Error al cargar separados';
      separados = [];
      debugPrint('❌ cargarSeparados: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }


  Future<void> cargarSeparado(int id) async {
    _cargando = true;
    notifyListeners();


    try {
      separadoSeleccionado = await _service.getSeparado(id);
    } catch (e) {
      debugPrint('❌ cargarSeparado: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }


  Future<bool> crearSeparado(Map<String, dynamic> data) async {
    _guardando = true;
    error      = null;
    notifyListeners();


    final result = await _service.crearSeparado(data);
    _guardando   = false;


    if (result['success'] == true) {
      final nuevo = result['data'] as Separado;
      separados   = [nuevo, ...separados];
      notifyListeners();
      return true;
    }


    error = result['error'] ?? 'No se pudo crear el separado';
    notifyListeners();
    return false;
  }


  Future<bool> abonarSeparado(int id, double monto, String metodoPago) async {
    _guardando = true;
    error      = null;
    notifyListeners();


    final result = await _service.abonarSeparado(id, monto, metodoPago);


    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;


      separados = separados.map((s) {
        if (s.id != id) return s;
        return s.copyWith(
          abonoAcumulado: (data['abono_acumulado'] as num).toDouble(),
          saldoPendiente: (data['saldo_pendiente'] as num).toDouble(),
          estado:          data['estado'] as String,
        );
      }).toList();


      if (separadoSeleccionado?.id == id) {
        separadoSeleccionado = separados.firstWhere((s) => s.id == id);
      }


      await Future.wait([
        _refrescarDetalleCliente(),
        cargarAlertas(tiendaId: _tiendaIdAlertas),
      ]);


      _guardando = false;
      notifyListeners();
      return true;
    }


    error      = result['error'] ?? 'Error al registrar abono';
    _guardando = false;
    notifyListeners();
    return false;
  }


  Future<bool> cancelarSeparado(int id) async {
    _guardando = true;
    error      = null;
    notifyListeners();


    final result = await _service.cancelarSeparado(id);


    if (result['success'] == true) {
      separados = separados
          .map((s) => s.id == id ? s.copyWith(estado: 'cancelado') : s)
          .toList();


      if (separadoSeleccionado?.id == id) {
        separadoSeleccionado = separados.firstWhere((s) => s.id == id);
      }


      await Future.wait([
        _refrescarDetalleCliente(),
        cargarAlertas(tiendaId: _tiendaIdAlertas),
      ]);
    } else {
      error = result['error'] ?? 'Error al cancelar separado';
    }


    _guardando = false;
    notifyListeners();
    return result['success'] == true;
  }



  // ══════════════════════════════════════════════════════════
  // ALERTAS
  // ══════════════════════════════════════════════════════════


  Future<void> cargarAlertas({int? tiendaId}) async {
    // ✅ Solo asigna si viene explícito, no reutiliza el anterior
    if (tiendaId != null) _tiendaIdAlertas = tiendaId;

    try {
      final data = await _service.getAlertasSeparados(
        tiendaId: _tiendaIdAlertas,
      );
      _vencidos = ((data['vencidos'] as List?) ?? [])
          .map((e) => AlertaSeparado.fromJson(e as Map<String, dynamic>))
          .toList();
      _porVencer = ((data['por_vencer'] as List?) ?? [])
          .map((e) => AlertaSeparado.fromJson(e as Map<String, dynamic>))
          .toList();
      _totalAlertas = (data['total_alertas'] as int?) ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ cargarAlertas: $e');
    }
  }

  // ✅ NUEVO: limpiar alertas al cambiar de tienda
  void limpiarAlertas() {
    _vencidos        = [];
    _porVencer       = [];
    _totalAlertas    = 0;
    _tiendaIdAlertas = null;
    notifyListeners();
  }



  // ══════════════════════════════════════════════════════════
  // ABONOS POR FECHA
  // ══════════════════════════════════════════════════════════


  Future<void> cargarAbonosPorFecha({
    required String fecha,
    int? tiendaId,
  }) async {
    _cargando = true;
    notifyListeners();


    try {
      final data = await _service.getAbonosPorFecha(
        fecha:    fecha,
        tiendaId: tiendaId,
      );
      abonosPorFecha = List<Map<String, dynamic>>.from(
        (data['abonos'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
      totalAbonosPorFecha = (data['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      abonosPorFecha      = [];
      totalAbonosPorFecha = 0.0;
      debugPrint('❌ cargarAbonosPorFecha: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }



  // ══════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════


  void limpiarError() {
    error = null;
    notifyListeners();
  }


  void seleccionarCliente(Cliente? c) {
    clienteSeleccionado = c;
    notifyListeners();
  }


  void seleccionarSeparado(Separado? s) {
    separadoSeleccionado = s;
    notifyListeners();
  }


  void limpiarSeparados() {
    separados            = [];
    separadoSeleccionado = null;
    notifyListeners();
  }
}