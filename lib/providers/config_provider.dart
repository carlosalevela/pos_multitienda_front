import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/config_service.dart';
import '../services/empresa_service.dart';

class ConfigProvider extends ChangeNotifier {
  final ConfigService  _service        = ConfigService();
  final EmpresaService _empresaService = EmpresaService();

  // ── Config Tienda ─────────────────────────────────────────
  bool   _habilitaMayoreo      = false;
  double _abonoMinimoPct       = 20.0;
  int    _diasMaxLiquidar      = 30;
  int    _diasAlertaSeparados  = 3;
  String _politicaCancelacion  = 'retener';
  List<String> _metodosPago    = ['efectivo', 'tarjeta', 'transferencia', 'mixto'];
  String _monedaSimbolo        = '\$';
  String _monedaCodigo         = 'USD';
  double _ivaPct               = 0.0;

  // ── Config Empresa (mayoreo global) ──────────────────────
  bool _empresaManejaM     = false;
  int  _cantidadMayoreo    = 6;
  int? _empresaId;

  // ── Umbral por tienda ─────────────────────────────────────
  int? _umbralMayoreoTienda;

  // ── Sugerencia de cliente en ventas grandes ───────────────
  bool   _sugerirCliente       = false;
  double _umbralSugerirCliente = 150000;

  static const _kSugerirCliente       = 'pos_sugerir_cliente';
  static const _kUmbralSugerirCliente = 'pos_umbral_sugerir_cliente';

  // ── Config Impresión ──────────────────────────────────────
  String _tipoPapel            = '80mm';
  int    _copias               = 1;
  bool   _mostrarLogo          = true;
  bool   _mostrarNit           = true;
  String _mensajePie           = '';
  String _nombreDispositivo    = '';

  // ── Estado ────────────────────────────────────────────────
  bool   _cargando  = false;
  String _errorMsg  = '';
  int?   _tiendaIdCargada;

  // ── Getters config tienda ─────────────────────────────────
  bool         get habilitaMayoreo     => _habilitaMayoreo;
  double       get abonoMinimoPct      => _abonoMinimoPct;
  int          get diasMaxLiquidar     => _diasMaxLiquidar;
  int          get diasAlertaSeparados => _diasAlertaSeparados;
  String       get politicaCancelacion => _politicaCancelacion;
  List<String> get metodosPago         => List.unmodifiable(_metodosPago);
  String       get monedaSimbolo       => _monedaSimbolo;
  String       get monedaCodigo        => _monedaCodigo;
  double       get ivaPct              => _ivaPct;

  // ── Getters empresa (mayoreo global) ─────────────────────
  bool get empresaManejaM      => _empresaManejaM;
  int  get cantidadMayoreo     => _cantidadMayoreo;
  int? get empresaId           => _empresaId;
  int? get umbralMayoreoTienda => _umbralMayoreoTienda;

  // ── Getters sugerencia cliente ────────────────────────────
  bool   get sugerirCliente       => _sugerirCliente;
  double get umbralSugerirCliente => _umbralSugerirCliente;

  // ── Getters config impresión ──────────────────────────────
  String get tipoPapel         => _tipoPapel;
  int    get copias            => _copias;
  bool   get mostrarLogo       => _mostrarLogo;
  bool   get mostrarNit        => _mostrarNit;
  String get mensajePie        => _mensajePie;
  String get nombreDispositivo => _nombreDispositivo;

  // ── Estado ────────────────────────────────────────────────
  bool   get cargando  => _cargando;
  String get errorMsg  => _errorMsg;
  bool   get cargada   => _tiendaIdCargada != null;
  int?   get tiendaIdCargada => _tiendaIdCargada;

  // ── Carga ─────────────────────────────────────────────────

  Future<void> cargar(int tiendaId, {int? empresaId}) async {
    if (_cargando) return;
    _cargando = true;
    _errorMsg = '';
    if (empresaId != null) _empresaId = empresaId;
    notifyListeners();

    final futures = [
      _service.getConfigTienda(tiendaId),
      _service.getConfigImpresion(tiendaId),
      if (_empresaId != null)
        _empresaService.getConfigMayoreo(_empresaId!).then(
          (d) => d != null ? {'success': true, 'data': d} : {'success': false},
        ),
    ];

    final results = await Future.wait(futures);

    final resT = results[0];
    final resI = results[1];

    if (resT['success'] == true) {
      final d = resT['data'] as Map<String, dynamic>;
      _habilitaMayoreo      = d['habilitar_mayoreo']     as bool?   ?? false;
      _umbralMayoreoTienda  = d['umbral_mayoreo']        as int?;
      _abonoMinimoPct       = double.tryParse(d['abono_minimo_pct']?.toString() ?? '') ?? 20.0;
      _diasMaxLiquidar     = d['dias_max_liquidar']      as int?    ?? 30;
      _diasAlertaSeparados = d['dias_alerta_separados']  as int?    ?? 3;
      _politicaCancelacion = d['politica_cancelacion']   as String? ?? 'retener';
      _metodosPago         = List<String>.from(d['metodos_pago'] ?? ['efectivo']);
      _monedaSimbolo       = d['moneda_simbolo']         as String? ?? '\$';
      _monedaCodigo        = d['moneda_codigo']          as String? ?? 'USD';
      _ivaPct              = double.tryParse(d['iva_pct']?.toString() ?? '') ?? 0.0;
    } else {
      _errorMsg = resT['error'] ?? 'Error al cargar configuración';
    }

    if (resI['success'] == true) {
      final d = resI['data'] as Map<String, dynamic>;
      _tipoPapel         = d['tipo_papel']         as String? ?? '80mm';
      _copias            = d['copias']             as int?    ?? 1;
      _mostrarLogo       = d['mostrar_logo']       as bool?   ?? true;
      _mostrarNit        = d['mostrar_nit']        as bool?   ?? true;
      _mensajePie        = d['mensaje_pie']        as String? ?? '';
      _nombreDispositivo = d['nombre_dispositivo'] as String? ?? '';
    }

    if (results.length > 2 && results[2]['success'] == true) {
      final d = results[2]['data'] as Map<String, dynamic>;
      _empresaManejaM  = d['maneja_mayoreo']  as bool? ?? false;
      _cantidadMayoreo = d['cantidad_mayoreo'] as int? ?? 6;
    }

    final prefs = await SharedPreferences.getInstance();
    _sugerirCliente       = prefs.getBool(_kSugerirCliente)         ?? false;
    _umbralSugerirCliente = prefs.getDouble(_kUmbralSugerirCliente) ?? 150000;

    _tiendaIdCargada = tiendaId;
    _cargando = false;
    notifyListeners();
  }

  // ── Guardar sugerencia de cliente ─────────────────────────

  Future<void> guardarSugerirCliente(bool enabled, double umbral) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSugerirCliente, enabled);
    await prefs.setDouble(_kUmbralSugerirCliente, umbral);
    _sugerirCliente       = enabled;
    _umbralSugerirCliente = umbral;
    notifyListeners();
  }

  // ── Guardar config tienda ─────────────────────────────────

  Future<bool> guardarConfigTienda(
    int tiendaId,
    Map<String, dynamic> datos,
  ) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    final res = await _service.patchConfigTienda(tiendaId, datos);
    _cargando = false;

    if (res['success'] == true) {
      await cargar(tiendaId);
      return true;
    }
    _errorMsg = res['error'] ?? 'Error al guardar';
    notifyListeners();
    return false;
  }

  // ── Guardar config impresión ──────────────────────────────

  Future<bool> guardarConfigImpresion(
    int tiendaId,
    Map<String, dynamic> datos,
  ) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    final res = await _service.patchConfigImpresion(tiendaId, datos);
    _cargando = false;

    if (res['success'] == true) {
      await cargar(tiendaId);
      return true;
    }
    _errorMsg = res['error'] ?? 'Error al guardar';
    notifyListeners();
    return false;
  }

  // ── Guardar config mayoreo empresa ───────────────────────

  Future<bool> guardarMayoreoEmpresa({
    required bool manejaM,
    required int  cantidadM,
  }) async {
    if (_empresaId == null) {
      _errorMsg = 'No se identificó la empresa.';
      notifyListeners();
      return false;
    }
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    final res = await _empresaService.updateConfigMayoreo(
      _empresaId!,
      manejaM:    manejaM,
      cantidadM:  cantidadM,
    );
    _cargando = false;

    if (res['success'] == true) {
      _empresaManejaM  = manejaM;
      _cantidadMayoreo = cantidadM;
      notifyListeners();
      return true;
    }
    _errorMsg = res['error'] ?? 'Error al guardar';
    notifyListeners();
    return false;
  }

  void limpiar() {
    _tiendaIdCargada = null;
    _errorMsg        = '';
    notifyListeners();
  }
}
