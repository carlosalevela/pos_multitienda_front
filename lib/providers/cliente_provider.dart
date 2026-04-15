import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../models/separado.dart';
import '../models/alerta_separado.dart';
import '../services/cliente_service.dart';

class ClienteProvider extends ChangeNotifier {
  final _service = ClienteService();

  // ── Estado clientes ───────────────────────────────────
  List<Cliente> clientes            = [];
  List<Cliente> clientesSimple      = [];
  Cliente?      clienteSeleccionado;

  // ── Estado separados ──────────────────────────────────
  List<Separado> separados             = [];
  Separado?      separadoSeleccionado;

  // ── Estado general ────────────────────────────────────
  bool    _cargando  = false;
  bool    _guardando = false;
  String? error;

  bool get cargando  => _cargando;
  bool get guardando => _guardando;

  // ── Clientes ──────────────────────────────────────────

  Future<void> cargarClientes({String? q}) async {
    _cargando = true;
    error     = null;
    notifyListeners();

    clientes  = await _service.getClientes(q: q);

    _cargando = false;
    notifyListeners();
  }

  Future<void> cargarClientesSimple({String? q}) async {
    clientesSimple = await _service.getClientesSimple(q: q);
    notifyListeners();
  }

  Future<void> cargarCliente(int id) async {
    _cargando = true;
    notifyListeners();

    clienteSeleccionado = await _service.getCliente(id);

    _cargando = false;
    notifyListeners();
  }

  Future<bool> crearCliente(Map<String, dynamic> data) async {
    _guardando = true;
    error      = null;
    notifyListeners();

    // ✅ Service retorna Map — no lanzará DioException
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

    final result    = await _service.editarCliente(id, data);
    _guardando      = false;

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
    // ✅ Service retorna Map — extraer 'success'
    final result = await _service.desactivarCliente(id);
    if (result['success'] == true) {
      clientes = clientes.where((c) => c.id != id).toList();
      if (clienteSeleccionado?.id == id) clienteSeleccionado = null;
      notifyListeners();
    } else {
      error = result['error'];
      notifyListeners();
    }
    return result['success'] == true;
  }

  // ── Separados ─────────────────────────────────────────

  Future<void> cargarSeparados({
    int? tiendaId, String? estado, int? clienteId,
  }) async {
    _cargando = true;
    error     = null;
    notifyListeners();

    separados = await _service.getSeparados(
      tiendaId:  tiendaId,
      estado:    estado,
      clienteId: clienteId,
    );

    _cargando = false;
    notifyListeners();
  }

  Future<void> cargarSeparado(int id) async {
    _cargando = true;
    notifyListeners();

    separadoSeleccionado = await _service.getSeparado(id);

    _cargando = false;
    notifyListeners();
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

  Future<bool> abonarSeparado(
      int id, double monto, String metodoPago) async {
    _guardando = true;
    error      = null;
    notifyListeners();

    final result = await _service.abonarSeparado(id, monto, metodoPago);

    if (result['success'] == true) {
      // ✅ los campos reales vienen en result['data']
      final data = result['data'] as Map<String, dynamic>;

      separados = separados.map((s) {
        if (s.id != id) return s;
        return Separado.fromJson({
          ...s.toJsonUpdate(),
          'abono_acumulado': data['abono_acumulado'],
          'saldo_pendiente': data['saldo_pendiente'],
          'estado':          data['estado'],
        });
      }).toList();

      await cargarAlertas(tiendaId: _tiendaIdAlertas);

      if (separadoSeleccionado?.id == id) {
        await cargarSeparado(id);
      }

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

    // ✅ Service retorna Map — extraer 'success'
    final result = await _service.cancelarSeparado(id);

    if (result['success'] == true) {
      separados = separados.map((s) => s.id == id
          ? Separado.fromJson({...s.toJsonUpdate(), 'estado': 'cancelado'})
          : s).toList();
      if (separadoSeleccionado?.id == id) {
        separadoSeleccionado = await _service.getSeparado(id);
      }
      await cargarAlertas(tiendaId: _tiendaIdAlertas);
    } else {
      error = result['error'] ?? 'Error al cancelar separado';
    }

    _guardando = false;
    notifyListeners();
    return result['success'] == true;
  }

  // ── Alertas de separados ──────────────────────────────

  List<AlertaSeparado> _vencidos      = [];
  List<AlertaSeparado> _porVencer     = [];
  int                  _totalAlertas  = 0;
  int?                 _tiendaIdAlertas;

  List<AlertaSeparado> get vencidos     => _vencidos;
  List<AlertaSeparado> get porVencer    => _porVencer;
  int                  get totalAlertas => _totalAlertas;

  Future<void> cargarAlertas({int? tiendaId}) async {
    _tiendaIdAlertas = tiendaId;
    try {
      final data    = await _service.getAlertasSeparados(tiendaId: tiendaId);
      _vencidos     = ((data['vencidos']   as List?) ?? [])
          .map((e) => AlertaSeparado.fromJson(e)).toList();
      _porVencer    = ((data['por_vencer'] as List?) ?? [])
          .map((e) => AlertaSeparado.fromJson(e)).toList();
      _totalAlertas = data['total_alertas'] ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ cargarAlertas error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────

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
}