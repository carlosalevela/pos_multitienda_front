import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../models/separado.dart';
import '../services/cliente_service.dart';
import '../models/alerta_separado.dart';


class ClienteProvider extends ChangeNotifier {
  final _service = ClienteService();


  // ── Estado clientes ───────────────────────────────────
  List<Cliente> clientes       = [];
  List<Cliente> clientesSimple = [];
  Cliente?      clienteSeleccionado;


  // ── Estado separados ──────────────────────────────────
  List<Separado> separados            = [];
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

    clientes = await _service.getClientes(q: q);

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

    try {
      final nuevo = await _service.crearCliente(data);
      if (nuevo != null) {
        clientes = [nuevo, ...clientes];
      }
      _guardando = false;
      notifyListeners();
      return true;
    } catch (e) {
      error      = _parseError(e);
      _guardando = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarCliente(int id, Map<String, dynamic> data) async {
    _guardando = true;
    error      = null;
    notifyListeners();

    try {
      final actualizado = await _service.editarCliente(id, data);
      if (actualizado != null) {
        clientes = clientes
            .map((c) => c.id == id ? actualizado : c)
            .toList();
        if (clienteSeleccionado?.id == id) {
          clienteSeleccionado = actualizado;
        }
      }
      _guardando = false;
      notifyListeners();
      return true;
    } catch (e) {
      error      = _parseError(e);
      _guardando = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> desactivarCliente(int id) async {
    final ok = await _service.desactivarCliente(id);
    if (ok) {
      clientes = clientes.where((c) => c.id != id).toList();
      if (clienteSeleccionado?.id == id) clienteSeleccionado = null;
      notifyListeners();
    }
    return ok;
  }


  // ── Separados ─────────────────────────────────────────

  Future<void> cargarSeparados({
    int? tiendaId, String? estado, int? clienteId}) async {
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

    try {
      final nuevo = await _service.crearSeparado(data);
      if (nuevo != null) {
        separados = [nuevo, ...separados];
      }
      _guardando = false;
      notifyListeners();
      return true;
    } catch (e) {
      error      = _parseError(e);
      _guardando = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> abonarSeparado(
      int id, double monto, String metodoPago) async {
    _guardando = true;
    error      = null;
    notifyListeners();

    try {
      final respuesta = await _service.abonarSeparado(id, monto, metodoPago);

      if (respuesta != null) {
        // Actualiza lista local con respuesta del backend
        separados = separados.map((s) {
          if (s.id != id) return s;
          return Separado.fromJson({
            ...s.toJsonUpdate(),
            'abono_acumulado': respuesta['abono_acumulado'],
            'saldo_pendiente': respuesta['saldo_pendiente'],
            'estado':          respuesta['estado'],
          });
        }).toList();

        // ✅ Refresca alertas para quitar el banner si se pagó
        await cargarAlertas(tiendaId: _tiendaIdAlertas);

        // Si está abierto el detalle, lo recarga completo con abonos
        if (separadoSeleccionado?.id == id) {
          await cargarSeparado(id);
          return true;
        }
      }

      _guardando = false;
      notifyListeners();
      return true;
    } catch (e) {
      error      = _parseError(e);
      _guardando = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelarSeparado(int id) async {
    _guardando = true;
    error      = null;
    notifyListeners();

    final ok = await _service.cancelarSeparado(id);
    if (ok) {
      // Actualiza estado localmente sin recargar la lista
      separados = separados.map((s) => s.id == id
          ? Separado.fromJson({...s.toJsonUpdate(), 'estado': 'cancelado'})
          : s).toList();
      if (separadoSeleccionado?.id == id) {
        separadoSeleccionado = await _service.getSeparado(id);
      }
      // ✅ Refresca alertas para quitar el banner si se canceló
      await cargarAlertas(tiendaId: _tiendaIdAlertas);
    }

    _guardando = false;
    notifyListeners();
    return ok;
  }


  // ── Alertas de separados ──────────────────────────────

  List<AlertaSeparado> _vencidos      = [];
  List<AlertaSeparado> _porVencer     = [];
  int                  _totalAlertas  = 0;
  int?                 _tiendaIdAlertas; // ✅ guarda filtro para refrescar

  List<AlertaSeparado> get vencidos     => _vencidos;
  List<AlertaSeparado> get porVencer    => _porVencer;
  int                  get totalAlertas => _totalAlertas;

  Future<void> cargarAlertas({int? tiendaId}) async {
    _tiendaIdAlertas = tiendaId; // ✅ memoriza el filtro activo
    final data = await _service.getAlertasSeparados(tiendaId: tiendaId);
    _vencidos     = (data['vencidos']   as List)
        .map((e) => AlertaSeparado.fromJson(e)).toList();
    _porVencer    = (data['por_vencer'] as List)
        .map((e) => AlertaSeparado.fromJson(e)).toList();
    _totalAlertas = data['total_alertas'] ?? 0;
    notifyListeners();
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

  String _parseError(dynamic e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return data.values
            .map((v) => v is List ? v.join(', ') : v.toString())
            .join('\n');
      }
      return data?.toString() ?? e.toString();
    } catch (_) {
      return e.toString();
    }
  }
}