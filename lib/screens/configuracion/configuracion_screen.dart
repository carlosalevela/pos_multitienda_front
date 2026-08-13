// lib/screens/configuracion/configuracion_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../models/tier_model.dart';
import '../../models/tienda_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/tienda_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/thermal_printer_service.dart';
import '../../services/tier_service.dart';
import '../../services/windows_printer_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;

  // ── Form controllers ──────────────────────────────────────
  final _monedaSimboloCtrl    = TextEditingController();
  final _monedaCodigoCtrl     = TextEditingController();
  final _ivaPctCtrl           = TextEditingController();
  final _abonoMinPctCtrl      = TextEditingController();
  final _diasMaxCtrl          = TextEditingController();
  final _diasAlertaCtrl       = TextEditingController();
  final _mensajePieCtrl       = TextEditingController();
  final _dispositivoCtrl      = TextEditingController();

  bool   _mayoreoHabilitado   = false;
  String _politica            = 'retener';
  String _tipoPapel           = '80mm';
  int    _copias              = 1;
  bool   _mostrarLogo         = true;
  bool   _mostrarNit          = true;
  List<String> _metodosPago   = [];

  // ── Empresa (mayoreo global) ──────────────────────────────
  final _cantidadMayoreoCtrl  = TextEditingController();
  bool _empresaManejaM        = false;
  bool _guardandoEmpresa      = false;

  // ── Umbral propio de esta tienda ──────────────────────────
  final _umbralTiendaCtrl = TextEditingController();

  bool   _guardando           = false;
  bool   _inicializado        = false;

  // Tienda activa: null mientras no se seleccione (solo superadmin)
  Tienda? _tiendaSeleccionada;

  int get _tiendaId {
    final auth = context.read<AuthProvider>();
    return _tiendaSeleccionada?.id ?? (auth.tiendaId > 0 ? auth.tiendaId : 0);
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _monedaSimboloCtrl.dispose();
    _monedaCodigoCtrl.dispose();
    _ivaPctCtrl.dispose();
    _abonoMinPctCtrl.dispose();
    _diasMaxCtrl.dispose();
    _diasAlertaCtrl.dispose();
    _mensajePieCtrl.dispose();
    _dispositivoCtrl.dispose();
    _cantidadMayoreoCtrl.dispose();
    _umbralTiendaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar({Tienda? tiendaOverride}) async {
    final auth   = context.read<AuthProvider>();
    final config = context.read<ConfigProvider>();

    if (auth.esSuperadmin) {
      // Cargar lista de tiendas para el selector
      final tiendas = context.read<TiendaProvider>();
      if (tiendas.tiendas.isEmpty) {
        await tiendas.cargarTiendas(soloActivas: true);
      }
      // Si ya hay una tienda seleccionada (o se pasó una), cargar su config
      final seleccionada = tiendaOverride ?? _tiendaSeleccionada;
      if (seleccionada != null) {
        setState(() => _tiendaSeleccionada = seleccionada);
        await config.cargar(seleccionada.id,
            empresaId: seleccionada.empresaId);
        if (!mounted) return;
        _poblarCampos(config);
      } else {
        // Sin tienda seleccionada: mostrar selector vacío
        if (!mounted) return;
        setState(() => _inicializado = true);
      }
    } else {
      final tiendaId  = auth.tiendaId;
      final empresaId = int.tryParse(auth.empresaId);
      if (tiendaId > 0) {
        await config.cargar(tiendaId, empresaId: empresaId);
      }
      if (!mounted) return;
      _poblarCampos(config);
    }
  }

  void _poblarCampos(ConfigProvider cfg) {
    _monedaSimboloCtrl.text = cfg.monedaSimbolo;
    _monedaCodigoCtrl.text  = cfg.monedaCodigo;
    _ivaPctCtrl.text        = cfg.ivaPct == 0 ? '' : cfg.ivaPct.toString();
    _abonoMinPctCtrl.text   = cfg.abonoMinimoPct.toString();
    _diasMaxCtrl.text       = cfg.diasMaxLiquidar.toString();
    _diasAlertaCtrl.text    = cfg.diasAlertaSeparados.toString();
    _mensajePieCtrl.text    = cfg.mensajePie;
    _dispositivoCtrl.text   = cfg.nombreDispositivo;
    _cantidadMayoreoCtrl.text = cfg.cantidadMayoreo.toString();
    _umbralTiendaCtrl.text    = cfg.umbralMayoreoTienda?.toString() ?? '';
    setState(() {
      _empresaManejaM     = cfg.empresaManejaM;
      _mayoreoHabilitado  = cfg.habilitaMayoreo;
      _politica           = cfg.politicaCancelacion;
      _tipoPapel          = cfg.tipoPapel;
      _copias             = cfg.copias;
      _mostrarLogo        = cfg.mostrarLogo;
      _mostrarNit         = cfg.mostrarNit;
      _metodosPago        = List<String>.from(cfg.metodosPago);
      _inicializado       = true;
    });
  }

  Future<void> _guardarGeneral() async {
    final config = context.read<ConfigProvider>();
    setState(() => _guardando = true);
    final ok = await config.guardarConfigTienda(_tiendaId, {
      'moneda_simbolo': _monedaSimboloCtrl.text.trim(),
      'moneda_codigo':  _monedaCodigoCtrl.text.trim().toUpperCase(),
      'iva_pct':        double.tryParse(_ivaPctCtrl.text) ?? 0,
      'metodos_pago':   _metodosPago,
    });
    setState(() => _guardando = false);
    _showSnack(ok ? 'Configuración guardada' : config.errorMsg, ok);
  }

  Future<void> _guardarMayoreo() async {
    final config = context.read<ConfigProvider>();
    setState(() => _guardando = true);
    final umbral = int.tryParse(_umbralTiendaCtrl.text.trim());
    final ok = await config.guardarConfigTienda(_tiendaId, {
      'habilitar_mayoreo': _mayoreoHabilitado,
      'umbral_mayoreo':    umbral,   // null = usa el global de empresa
    });
    setState(() => _guardando = false);
    _showSnack(ok ? 'Configuración tienda guardada' : config.errorMsg, ok);
  }

  Future<void> _guardarMayoreoEmpresa() async {
    final config   = context.read<ConfigProvider>();
    final cantidad = int.tryParse(_cantidadMayoreoCtrl.text) ?? 6;
    if (cantidad < 2) {
      _showSnack('El umbral mínimo es 2 unidades', false);
      return;
    }
    setState(() => _guardandoEmpresa = true);
    final ok = await config.guardarMayoreoEmpresa(
      manejaM:   _empresaManejaM,
      cantidadM: cantidad,
    );
    setState(() => _guardandoEmpresa = false);
    _showSnack(ok ? 'Configuración de empresa guardada' : config.errorMsg, ok);
  }

  Future<void> _guardarSeparados() async {
    final config = context.read<ConfigProvider>();
    setState(() => _guardando = true);
    final ok = await config.guardarConfigTienda(_tiendaId, {
      'abono_minimo_pct':      double.tryParse(_abonoMinPctCtrl.text) ?? 20,
      'dias_max_liquidar':     int.tryParse(_diasMaxCtrl.text)        ?? 30,
      'politica_cancelacion':  _politica,
      'dias_alerta_separados': int.tryParse(_diasAlertaCtrl.text)     ?? 3,
    });
    setState(() => _guardando = false);
    _showSnack(ok ? 'Configuración separados guardada' : config.errorMsg, ok);
  }

  Future<void> _guardarImpresion() async {
    final config = context.read<ConfigProvider>();
    setState(() => _guardando = true);
    final ok = await config.guardarConfigImpresion(_tiendaId, {
      'tipo_papel':          _tipoPapel,
      'copias':              _copias,
      'mostrar_logo':        _mostrarLogo,
      'mostrar_nit':         _mostrarNit,
      'mensaje_pie':         _mensajePieCtrl.text.trim(),
      'nombre_dispositivo':  _dispositivoCtrl.text.trim(),
    });
    setState(() => _guardando = false);
    _showSnack(ok ? 'Configuración impresión guardada' : config.errorMsg, ok);
  }

  void _showSnack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? const Color(0xFF0B7A53) : const Color(0xFFBE123C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final config  = context.watch<ConfigProvider>();
    final tiendas = context.watch<TiendaProvider>();

    // Flags de edición por rol:
    //  - esAdmin:            admin + superadmin
    //  - puedeEditarGeneral: moneda, IVA, métodos de pago → solo admin
    //  - puedeEditarOp:      mayoreo tienda, separados, impresión → admin + supervisor
    //  - puedeEditarEmpresa: mayoreo empresa, fidelización → solo admin
    final esAdmin           = auth.esSuperadmin || auth.rol == 'admin';
    final puedeEditarGeneral  = esAdmin;
    final puedeEditarOp       = auth.esAdminOSupervisor || auth.esSuperadmin;
    final puedeEditarEmpresa  = esAdmin;

    final nombreTienda = auth.esSuperadmin
        ? (_tiendaSeleccionada?.nombre ?? '')
        : auth.tiendaNombre;

    // Superadmin sin tienda seleccionada: solo mostrar el picker
    final sinSeleccion = auth.esSuperadmin && _tiendaSeleccionada == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: Column(
        children: [
          _Header(tienda: nombreTienda),

          // Selector de tienda para superadmin
          if (auth.esSuperadmin)
            _TiendaPicker(
              tiendas:     tiendas.tiendas,
              seleccionada: _tiendaSeleccionada,
              cargando:    tiendas.cargando,
              onSeleccionar: (t) => _cargar(tiendaOverride: t),
            ),

          if (!sinSeleccion) _TabBar(controller: _tabs),
          Expanded(
            child: sinSeleccion
                ? _EmptyPicker(cargandoTiendas: tiendas.cargando)
                : config.cargando && !_inicializado
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _TabGeneral(
                            monedaSimbolo: _monedaSimboloCtrl,
                            monedaCodigo:  _monedaCodigoCtrl,
                            ivaPct:        _ivaPctCtrl,
                            metodosPago:   _metodosPago,
                            onMetodoPago:  (m, v) => setState(() => v ? _metodosPago.add(m) : _metodosPago.remove(m)),
                            puedeEditar:   puedeEditarGeneral,   // solo admin
                            guardando:     _guardando,
                            onGuardar:     _guardarGeneral,
                          ),
                          _TabMayoreo(
                            habilitadoTienda:   _mayoreoHabilitado,
                            onChangeTienda:     (v) => setState(() => _mayoreoHabilitado = v),
                            umbralTienda:       _umbralTiendaCtrl,
                            empresaManejaM:     _empresaManejaM,
                            onChangeEmpresa:    (v) => setState(() => _empresaManejaM = v),
                            cantidadMayoreo:    _cantidadMayoreoCtrl,
                            puedeEditar:        puedeEditarOp,      // supervisor puede editar su tienda
                            puedeEditarEmpresa: puedeEditarEmpresa, // solo admin edita empresa
                            guardando:          _guardando,
                            guardandoEmpresa:   _guardandoEmpresa,
                            onGuardarTienda:    _guardarMayoreo,
                            onGuardarEmpresa:   _guardarMayoreoEmpresa,
                          ),
                          _TabSeparados(
                            abonoMinPct:  _abonoMinPctCtrl,
                            diasMax:      _diasMaxCtrl,
                            diasAlerta:   _diasAlertaCtrl,
                            politica:     _politica,
                            onPolitica:   (v) => setState(() => _politica = v!),
                            puedeEditar:  puedeEditarOp,     // supervisor puede
                            guardando:    _guardando,
                            onGuardar:    _guardarSeparados,
                          ),
                          _TabImpresion(
                            tipoPapel:     _tipoPapel,
                            copias:        _copias,
                            mostrarLogo:   _mostrarLogo,
                            mostrarNit:    _mostrarNit,
                            mensajePie:    _mensajePieCtrl,
                            dispositivo:   _dispositivoCtrl,
                            onTipoPapel:   (v) => setState(() => _tipoPapel = v!),
                            onCopias:      (v) => setState(() => _copias = v),
                            onMostrarLogo: (v) => setState(() => _mostrarLogo = v),
                            onMostrarNit:  (v) => setState(() => _mostrarNit  = v),
                            puedeEditar:   puedeEditarOp,    // supervisor puede
                            guardando:     _guardando,
                            onGuardar:     _guardarImpresion,
                          ),
                          _TabFidelizacion(puedeEditar: puedeEditarEmpresa), // solo admin
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Selector de tienda (superadmin) ───────────────────────────

class _TiendaPicker extends StatelessWidget {
  final List<Tienda> tiendas;
  final Tienda?      seleccionada;
  final bool         cargando;
  final ValueChanged<Tienda> onSeleccionar;

  const _TiendaPicker({
    required this.tiendas,
    required this.seleccionada,
    required this.cargando,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEF2FF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.store_rounded, size: 18, color: Color(0xFF3730A3)),
          const SizedBox(width: 8),
          const Text('Tienda:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3730A3))),
          const SizedBox(width: 10),
          Expanded(
            child: cargando
                ? const LinearProgressIndicator()
                : DropdownButtonHideUnderline(
                    child: DropdownButton<Tienda>(
                      value: seleccionada,
                      hint: const Text('Selecciona una tienda',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      isExpanded: true,
                      isDense: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                      items: tiendas.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.nombre),
                      )).toList(),
                      onChanged: (t) { if (t != null) onSeleccionar(t); },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío mientras no hay tienda seleccionada ──────────

class _EmptyPicker extends StatelessWidget {
  final bool cargandoTiendas;
  const _EmptyPicker({required this.cargandoTiendas});

  @override
  Widget build(BuildContext context) {
    if (cargandoTiendas) return const Center(child: CircularProgressIndicator());
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_outlined, size: 56, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('Selecciona una tienda para ver su configuración',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String tienda;
  const _Header({required this.tienda});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.settings_outlined, size: 22, color: Color(0xFF3730A3)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configuración',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              if (tienda.isNotEmpty)
                Text(tienda,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── TabBar ────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller:  controller,
        labelColor:  const Color(0xFF3730A3),
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: const Color(0xFF3730A3),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.tune_outlined,           size: 18), text: 'General'),
          Tab(icon: Icon(Icons.storefront_outlined,     size: 18), text: 'Mayoreo'),
          Tab(icon: Icon(Icons.bookmark_border_rounded, size: 18), text: 'Separados'),
          Tab(icon: Icon(Icons.print_outlined,          size: 18), text: 'Impresión'),
          Tab(icon: Icon(Icons.star_outline_rounded,    size: 18), text: 'Fidelización'),
        ],
      ),
    );
  }
}

// ── Helpers UI ────────────────────────────────────────────────

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: Color(0xFF374151), letterSpacing: 0.3)),
);

Widget _field(TextEditingController ctrl, {
  String? hint,
  TextInputType? keyboardType,
  bool enabled = true,
  int maxLines = 1,
}) => TextFormField(
  controller:   ctrl,
  enabled:      enabled,
  maxLines:     maxLines,
  keyboardType: keyboardType,
  style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
  decoration: InputDecoration(
    hintText:  hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    filled:    true,
    fillColor: enabled ? Colors.white : const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3730A3), width: 1.5)),
    disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
  ),
);

Widget _guardarBtn({required VoidCallback onTap, required bool guardando}) =>
    Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: guardando ? null : onTap,
        icon: guardando
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined, size: 16),
        label: Text(guardando ? 'Guardando…' : 'Guardar cambios'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3730A3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

Widget _card({required Widget child}) => Container(
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  ),
  child: child,
);

Widget _sectionTitle(String title) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Text(title,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
        color: Color(0xFF111827))),
);

// ── Tab General ───────────────────────────────────────────────

class _TabGeneral extends StatelessWidget {
  final TextEditingController monedaSimbolo, monedaCodigo, ivaPct;
  final List<String>          metodosPago;
  final void Function(String, bool) onMetodoPago;
  final bool puedeEditar, guardando;
  final VoidCallback onGuardar;

  const _TabGeneral({
    required this.monedaSimbolo,
    required this.monedaCodigo,
    required this.ivaPct,
    required this.metodosPago,
    required this.onMetodoPago,
    required this.puedeEditar,
    required this.guardando,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Moneda'),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [_label('Símbolo'), _field(monedaSimbolo, hint: '\$', enabled: puedeEditar)])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [_label('Código ISO'), _field(monedaCodigo, hint: 'USD', enabled: puedeEditar)])),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('Impuesto (IVA)'),
            _label('Porcentaje IVA (0 = sin IVA)'),
            _field(ivaPct, hint: '0', keyboardType: TextInputType.number, enabled: puedeEditar),
          ],
        )),
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Métodos de pago habilitados'),
            ...const ['efectivo', 'tarjeta', 'transferencia', 'mixto'].map((m) =>
              CheckboxListTile(
                value:    metodosPago.contains(m),
                onChanged: puedeEditar ? (v) => onMetodoPago(m, v ?? false) : null,
                title: Text(_labelMetodo(m),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF3730A3),
              ),
            ),
          ],
        )),
        if (puedeEditar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _guardarBtn(onTap: onGuardar, guardando: guardando),
          ),
      ],
    );
  }

  static String _labelMetodo(String m) => switch (m) {
    'efectivo'     => 'Efectivo',
    'tarjeta'      => 'Tarjeta',
    'transferencia'=> 'Transferencia',
    'mixto'        => 'Pago mixto',
    _              => m,
  };
}

// ── Tab Mayoreo ───────────────────────────────────────────────

class _TabMayoreo extends StatelessWidget {
  final bool   habilitadoTienda;
  final bool   empresaManejaM;
  /// Permiso para editar la sección de ESTA TIENDA (supervisor puede).
  final bool   puedeEditar;
  /// Permiso para editar la sección EMPRESA (solo admin/superadmin).
  final bool   puedeEditarEmpresa;
  final bool   guardando;
  final bool   guardandoEmpresa;
  final TextEditingController cantidadMayoreo;
  final TextEditingController umbralTienda;
  final ValueChanged<bool> onChangeTienda;
  final ValueChanged<bool> onChangeEmpresa;
  final VoidCallback onGuardarTienda;
  final VoidCallback onGuardarEmpresa;

  const _TabMayoreo({
    required this.habilitadoTienda,
    required this.empresaManejaM,
    required this.cantidadMayoreo,
    required this.umbralTienda,
    required this.onChangeTienda,
    required this.onChangeEmpresa,
    required this.puedeEditar,
    required this.puedeEditarEmpresa,
    required this.guardando,
    required this.guardandoEmpresa,
    required this.onGuardarTienda,
    required this.onGuardarEmpresa,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [

        // ── Empresa: configuración global ──────────────────
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business_rounded,
                    size: 16, color: Color(0xFF3730A3)),
              ),
              const SizedBox(width: 8),
              const Text('Configuración empresa (global)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Afecta a todas las tiendas y productos de la empresa.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),

            // Toggle empresa
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: empresaManejaM
                    ? const Color(0xFFE8FFF4)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: empresaManejaM
                      ? const Color(0xFF61DDAA)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(children: [
                Icon(
                  empresaManejaM ? Icons.storefront_rounded : Icons.storefront_outlined,
                  color: empresaManejaM
                      ? const Color(0xFF0B7A53)
                      : const Color(0xFF9CA3AF),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    empresaManejaM
                        ? 'La empresa maneja venta por mayor'
                        : 'La empresa NO maneja venta por mayor',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: empresaManejaM
                          ? const Color(0xFF0B7A53)
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
                Switch(
                  value:           empresaManejaM,
                  onChanged:       puedeEditarEmpresa ? onChangeEmpresa : null,
                  activeThumbColor: const Color(0xFF3730A3),
                  activeTrackColor: const Color(0xFFBFBFF7),
                ),
              ]),
            ),

            if (empresaManejaM) ...[
              const SizedBox(height: 16),
              _label('Umbral global: a partir de cuántas unidades aplica el precio mayoreo'),
              Row(children: [
                Expanded(
                  child: _field(
                    cantidadMayoreo,
                    hint: '6',
                    keyboardType: TextInputType.number,
                    enabled: puedeEditarEmpresa,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('unidades',
                      style: TextStyle(fontSize: 13, color: Color(0xFF3730A3),
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Los productos sin umbral propio usarán este valor. Cada producto puede tener su propio umbral desde Inventario.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],

            if (puedeEditarEmpresa) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: guardandoEmpresa ? null : onGuardarEmpresa,
                  icon: guardandoEmpresa
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 15),
                  label: Text(guardandoEmpresa
                      ? 'Guardando…'
                      : 'Guardar config empresa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3730A3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        )),

        // ── Tienda: toggle individual ──────────────────────
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.store_outlined,
                    size: 16, color: Color(0xFF0B7A53)),
              ),
              const SizedBox(width: 8),
              const Text('Configuración de esta tienda',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Solo afecta a esta tienda, sin importar la config de empresa.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: habilitadoTienda
                    ? const Color(0xFFE8FFF4)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: habilitadoTienda
                      ? const Color(0xFF61DDAA)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(children: [
                Icon(
                  habilitadoTienda
                      ? Icons.check_circle_rounded
                      : Icons.block_rounded,
                  color: habilitadoTienda
                      ? const Color(0xFF0B7A53)
                      : const Color(0xFF9CA3AF),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habilitadoTienda
                            ? 'Precio mayoreo habilitado en esta tienda'
                            : 'Precio mayoreo deshabilitado en esta tienda',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: habilitadoTienda
                              ? const Color(0xFF0B7A53)
                              : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        habilitadoTienda
                            ? 'Los productos aplicarán precio mayoreo al alcanzar el umbral.'
                            : 'Todos los productos venderán al precio normal aquí.',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value:           habilitadoTienda,
                  onChanged:       puedeEditar ? onChangeTienda : null,
                  activeThumbColor: const Color(0xFF3730A3),
                  activeTrackColor: const Color(0xFFBFBFF7),
                ),
              ]),
            ),
            if (habilitadoTienda) ...[
              const SizedBox(height: 16),
              _label('Umbral de esta tienda (vacío = usa el global de empresa)'),
              Row(children: [
                Expanded(
                  child: _field(
                    umbralTienda,
                    hint: 'Ej: 12',
                    keyboardType: TextInputType.number,
                    enabled: puedeEditar,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Text('unidades',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Si dejas vacío, se usará el umbral global de la empresa.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
            if (puedeEditar) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: guardando ? null : onGuardarTienda,
                  icon: guardando
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 15),
                  label: Text(guardando
                      ? 'Guardando…'
                      : 'Guardar config tienda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B7A53),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        )),

      ],
    );
  }
}

// ── Tab Separados ─────────────────────────────────────────────

class _TabSeparados extends StatelessWidget {
  final TextEditingController abonoMinPct, diasMax, diasAlerta;
  final String politica;
  final ValueChanged<String?> onPolitica;
  final bool puedeEditar, guardando;
  final VoidCallback onGuardar;

  const _TabSeparados({
    required this.abonoMinPct,
    required this.diasMax,
    required this.diasAlerta,
    required this.politica,
    required this.onPolitica,
    required this.puedeEditar,
    required this.guardando,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Condiciones de separado'),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Abono mínimo (%)'),
                  _field(abonoMinPct, hint: '20', keyboardType: TextInputType.number, enabled: puedeEditar),
                ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Días máx. para liquidar'),
                  _field(diasMax, hint: '30', keyboardType: TextInputType.number, enabled: puedeEditar),
                ])),
            ]),
            const SizedBox(height: 16),
            _label('Días de alerta antes de vencimiento'),
            _field(diasAlerta, hint: '3', keyboardType: TextInputType.number, enabled: puedeEditar),
          ],
        )),
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Política de cancelación'),
            _label('¿Qué pasa con el abono si se cancela un separado?'),
            const SizedBox(height: 8),
            ...{
              'retener': ('Retener abono', 'El abono queda como crédito en la cuenta del cliente.'),
              'devolver': ('Devolver abono', 'El abono se reembolsa completamente al cliente.'),
            }.entries.map((e) => RadioListTile<String>(
              value:    e.key,
              groupValue: politica,
              onChanged: puedeEditar ? onPolitica : null,
              title: Text(e.value.$1,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              subtitle: Text(e.value.$2,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF3730A3),
            )),
          ],
        )),
        if (puedeEditar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _guardarBtn(onTap: onGuardar, guardando: guardando),
          ),
      ],
    );
  }
}

// ── Tab Impresión ─────────────────────────────────────────────

class _TabImpresion extends StatelessWidget {
  final String  tipoPapel;
  final int     copias;
  final bool    mostrarLogo, mostrarNit;
  final TextEditingController mensajePie, dispositivo;
  final ValueChanged<String?> onTipoPapel;
  final ValueChanged<int>     onCopias;
  final ValueChanged<bool>    onMostrarLogo, onMostrarNit;
  final bool puedeEditar, guardando;
  final VoidCallback onGuardar;

  const _TabImpresion({
    required this.tipoPapel,
    required this.copias,
    required this.mostrarLogo,
    required this.mostrarNit,
    required this.mensajePie,
    required this.dispositivo,
    required this.onTipoPapel,
    required this.onCopias,
    required this.onMostrarLogo,
    required this.onMostrarNit,
    required this.puedeEditar,
    required this.guardando,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Tipo de papel'),
            ...{
              '80mm': ('Térmica 80 mm', 'Impresora estándar de recibos.'),
              '58mm': ('Térmica 58 mm', 'Impresora compacta de bolsillo.'),
              'pdf':  ('PDF / A4',      'Imprimir como documento en hoja carta.'),
            }.entries.map((e) => RadioListTile<String>(
              value:      e.key,
              groupValue: tipoPapel,
              onChanged:  puedeEditar ? onTipoPapel : null,
              title: Text(e.value.$1,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              subtitle: Text(e.value.$2,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF3730A3),
            )),
          ],
        )),
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Opciones de recibo'),
            _label('Número de copias'),
            Row(
              children: [
                IconButton(
                  onPressed: puedeEditar && copias > 1 ? () => onCopias(copias - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: const Color(0xFF3730A3),
                ),
                Text('$copias', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: puedeEditar && copias < 4 ? () => onCopias(copias + 1) : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF3730A3),
                ),
              ],
            ),
            SwitchListTile(
              value:    mostrarLogo,
              onChanged: puedeEditar ? onMostrarLogo : null,
              title: const Text('Mostrar logo en recibo',
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
              activeThumbColor: const Color(0xFF3730A3),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value:    mostrarNit,
              onChanged: puedeEditar ? onMostrarNit : null,
              title: const Text('Mostrar NIT / RUT en recibo',
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
              activeThumbColor: const Color(0xFF3730A3),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            _label('Mensaje de pie de recibo'),
            _field(mensajePie,
              hint:     '¡Gracias por su compra!',
              maxLines: 2,
              enabled:  puedeEditar,
            ),
          ],
        )),
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Dispositivo de impresión'),
            _label('Nombre del dispositivo (Bluetooth / IP)'),
            _field(dispositivo,
              hint:    'Ej: POS-80C o 192.168.1.50',
              enabled: puedeEditar,
            ),
            const SizedBox(height: 6),
            const Text(
              'Nombre referencial guardado en la configuración.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        )),
        const _ConexionImpresoraCard(),
        if (puedeEditar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _guardarBtn(onTap: onGuardar, guardando: guardando),
          ),
      ],
    );
  }
}

// ── Tab Fidelización ──────────────────────────────────────────

class _TabFidelizacion extends StatefulWidget {
  final bool puedeEditar;
  const _TabFidelizacion({required this.puedeEditar});

  @override
  State<_TabFidelizacion> createState() => _TabFidelizacionState();
}

class _TabFidelizacionState extends State<_TabFidelizacion> {
  final _svc   = TierService();
  final _fmt   = NumberFormat('#,##0', 'es_CO');
  List<TierModel> _tiers    = [];
  bool            _cargando = false;
  String?         _error;

  // ── Sugerencia de cliente ──────────────────────────────────
  bool   _sugerirCliente    = false;
  final  _umbralSugerirCtrl = TextEditingController(text: '150000');
  bool   _guardandoSugerir  = false;

  static const _coloresPreset = [
    '#CD7F32', // Bronce
    '#A8A9AD', // Plata
    '#D4AF37', // Oro
    '#5E4DB2', // Platinum
    '#006C49', // Verde
    '#0066CC', // Azul
    '#C0392B', // Rojo
    '#76777D', // Gris
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cfg = context.read<ConfigProvider>();
      setState(() {
        _sugerirCliente        = cfg.sugerirCliente;
        _umbralSugerirCtrl.text = cfg.umbralSugerirCliente.toStringAsFixed(0);
      });
    });
  }

  Future<void> _guardarSugerir() async {
    final umbral = double.tryParse(_umbralSugerirCtrl.text.trim()) ?? 150000;
    setState(() => _guardandoSugerir = true);
    await context.read<ConfigProvider>().guardarSugerirCliente(_sugerirCliente, umbral);
    if (!mounted) return;
    setState(() => _guardandoSugerir = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Configuración guardada'),
      backgroundColor: Color(0xFF0B7A53),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    final r = await _svc.getTiers();
    if (!mounted) return;
    if (r['success'] == true) {
      setState(() { _tiers = List<TierModel>.from(r['data'] as List); _cargando = false; });
    } else {
      setState(() { _error = r['error'] as String?; _cargando = false; });
    }
  }

  Future<void> _abrirFormulario([TierModel? tier]) async {
    final resultado = await showDialog<TierModel>(
      context: context,
      builder: (_) => _TierDialog(tier: tier, colores: _coloresPreset),
    );
    if (resultado == null || !mounted) return;

    final r = tier?.id != null
        ? await _svc.actualizarTier(tier!.id!, resultado)
        : await _svc.crearTier(resultado);

    if (!mounted) return;
    if (r['success'] == true) {
      _cargar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r['error'] as String? ?? 'Error'),
        backgroundColor: const Color(0xFFBE123C),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _eliminar(TierModel tier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('¿Eliminar tier?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Se eliminará el tier "${tier.nombre}". Los clientes que estén en este tier '
          'quedarán sin tier hasta que lo reconfigures.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await _svc.eliminarTier(tier.id!);
    if (!mounted) return;
    if (r['success'] == true) {
      _cargar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r['error'] as String? ?? 'Error al eliminar'),
        backgroundColor: const Color(0xFFBE123C),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF76777D);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD4AF37)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tiers de fidelización',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  Text('Los clientes suben de tier según su total acumulado de compras.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El descuento del tier se aplica automáticamente en el POS cuando el cajero asocia un cliente a la venta.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                  ),
                ),
              ]),
            ),
          ],
        )),

        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _card(child: Text(_error!, style: const TextStyle(color: Color(0xFFBE123C))))
        else ...[
          ..._tiers.map((tier) => _card(child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _hexColor(tier.colorHex),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.star_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tier.nombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                if (!tier.activo) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Inactivo',
                        style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                'Desde \$${_fmt.format(tier.umbralMin)}'
                '${tier.umbralMax != null ? " hasta \$${_fmt.format(tier.umbralMax!)}" : " en adelante"}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 2),
              Text(
                '${tier.descuentoPct.toStringAsFixed(tier.descuentoPct % 1 == 0 ? 0 : 1)}% de descuento',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _hexColor(tier.colorHex)),
              ),
            ])),
            if (widget.puedeEditar) Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                onPressed: () => _abrirFormulario(tier),
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: const Color(0xFF3730A3),
                tooltip: 'Editar',
              ),
              IconButton(
                onPressed: () => _eliminar(tier),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: const Color(0xFFBE123C),
                tooltip: 'Eliminar',
              ),
            ]),
          ]))),

          if (_tiers.isEmpty)
            _card(child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No hay tiers configurados. ¡Agrega el primero!',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              ),
            )),
        ],

        if (widget.puedeEditar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _abrirFormulario,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar tier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3730A3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

        // ── Card sugerencia de cliente ─────────────────────────
        const SizedBox(height: 8),
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add_rounded, size: 16, color: Color(0xFF0B7A53)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sugerir registrar cliente',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  Text('Muestra un aviso en el POS cuando la venta supera el monto configurado.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _sugerirCliente
                    ? const Color(0xFFE8FFF4)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _sugerirCliente
                      ? const Color(0xFF61DDAA)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(children: [
                Icon(
                  _sugerirCliente
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: _sugerirCliente
                      ? const Color(0xFF0B7A53)
                      : const Color(0xFF9CA3AF),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sugerirCliente
                        ? 'Se mostrará sugerencia en ventas grandes'
                        : 'Sugerencia desactivada',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: _sugerirCliente
                          ? const Color(0xFF0B7A53)
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
                Switch(
                  value:    _sugerirCliente,
                  onChanged: widget.puedeEditar
                      ? (v) => setState(() => _sugerirCliente = v)
                      : null,
                  activeThumbColor: const Color(0xFF0B7A53),
                  activeTrackColor: const Color(0xFF61DDAA),
                ),
              ]),
            ),
            if (_sugerirCliente) ...[
              const SizedBox(height: 14),
              _label('Monto mínimo para mostrar el aviso (\$)'),
              _field(
                _umbralSugerirCtrl,
                hint: '150000',
                keyboardType: TextInputType.number,
                enabled: widget.puedeEditar,
              ),
              const SizedBox(height: 6),
              const Text(
                'Si el total de la venta supera este monto y no hay cliente asociado, '
                'el POS sugerirá registrarlo.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
            if (widget.puedeEditar) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _guardandoSugerir ? null : _guardarSugerir,
                  icon: _guardandoSugerir
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 15),
                  label: Text(_guardandoSugerir ? 'Guardando…' : 'Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B7A53),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        )),
      ],
    );
  }
}


// ── Dialog crear / editar tier ────────────────────────────────

class _TierDialog extends StatefulWidget {
  final TierModel?   tier;
  final List<String> colores;
  const _TierDialog({this.tier, required this.colores});

  @override
  State<_TierDialog> createState() => _TierDialogState();
}

class _TierDialogState extends State<_TierDialog> {
  final _formKey       = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _umbralMinCtrl = TextEditingController();
  final _umbralMaxCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();
  final _ordenCtrl     = TextEditingController();

  String _colorHex = '#D4AF37';
  bool   _activo   = true;

  @override
  void initState() {
    super.initState();
    final t = widget.tier;
    if (t != null) {
      _nombreCtrl.text    = t.nombre;
      _umbralMinCtrl.text = t.umbralMin.toStringAsFixed(0);
      _umbralMaxCtrl.text = t.umbralMax?.toStringAsFixed(0) ?? '';
      _descuentoCtrl.text = t.descuentoPct.toStringAsFixed(
          t.descuentoPct % 1 == 0 ? 0 : 2);
      _ordenCtrl.text     = t.orden.toString();
      _colorHex           = t.colorHex;
      _activo             = t.activo;
    } else {
      _ordenCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _umbralMinCtrl.dispose();
    _umbralMaxCtrl.dispose();
    _descuentoCtrl.dispose();
    _ordenCtrl.dispose();
    super.dispose();
  }

  Color _hexColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return const Color(0xFF76777D); }
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, TierModel(
      id:           widget.tier?.id,
      nombre:       _nombreCtrl.text.trim(),
      umbralMin:    double.parse(_umbralMinCtrl.text),
      umbralMax:    _umbralMaxCtrl.text.trim().isEmpty
                      ? null
                      : double.parse(_umbralMaxCtrl.text),
      descuentoPct: double.parse(_descuentoCtrl.text),
      colorHex:     _colorHex,
      activo:       _activo,
      orden:        int.tryParse(_ordenCtrl.text) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.tier == null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(esNuevo ? 'Nuevo tier' : 'Editar tier',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Nombre del tier'),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: _inputDeco('Ej: Oro, Platino, VIP…'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Desde (\$)'),
                    TextFormField(
                      controller: _umbralMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('0'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (double.tryParse(v) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Hasta (\$) — vacío = ∞'),
                    TextFormField(
                      controller: _umbralMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('Sin límite'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (double.tryParse(v) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ])),
                ]),
                const SizedBox(height: 14),

                _label('Descuento (%)'),
                TextFormField(
                  controller: _descuentoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Ej: 5'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final d = double.tryParse(v);
                    if (d == null || d < 0 || d > 100) return '0–100';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('Color del badge'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ...widget.colores.map((c) => GestureDetector(
                    onTap: () => setState(() => _colorHex = c),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _hexColor(c),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _colorHex == c
                              ? const Color(0xFF111827)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  )),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _hexColor(_colorHex),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(
                    initialValue: _colorHex,
                    decoration: _inputDeco('#D4AF37'),
                    onChanged: (v) {
                      if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v)) {
                        setState(() => _colorHex = v.toUpperCase());
                      }
                    },
                    validator: (v) => (v == null ||
                            !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v))
                        ? 'Formato: #RRGGBB'
                        : null,
                  )),
                ]),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Orden'),
                    TextFormField(
                      controller: _ordenCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('0'),
                    ),
                  ])),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Estado'),
                    Row(children: [
                      Switch(
                        value: _activo,
                        onChanged: (v) => setState(() => _activo = v),
                        activeThumbColor: const Color(0xFF3730A3),
                        activeTrackColor: const Color(0xFFBFBFF7),
                      ),
                      Text(_activo ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _activo
                                ? const Color(0xFF3730A3)
                                : const Color(0xFF9CA3AF),
                          )),
                    ]),
                  ])),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: Color(0xFF6B7280))),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3730A3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(esNuevo ? 'Crear tier' : 'Guardar cambios'),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3730A3), width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFBE123C))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tarjeta de hardware: impresora térmica + caja de dinero
// ─────────────────────────────────────────────────────────────────────────────

class _ConexionImpresoraCard extends StatefulWidget {
  const _ConexionImpresoraCard();

  @override
  State<_ConexionImpresoraCard> createState() => _ConexionImpresoraCardState();
}

class _ConexionImpresoraCardState extends State<_ConexionImpresoraCard> {
  // WebUSB (Chrome/Edge web)
  ThermalDevice? _device;
  bool           _cargando   = false;
  // Windows exe
  List<Printer>  _winPrinters   = [];
  Printer?       _winPrinter;
  bool           _cargandoWin   = false;
  // Compartido
  bool           _trabajando = false;
  bool           _tieneCaja  = false;
  String?        _error;

  static const _indigo = Color(0xFF3730A3);
  static const _green  = Color(0xFF0B7A53);
  static const _red    = Color(0xFFBE123C);
  static const _grey   = Color(0xFF6B7280);

  static const _kHasCaja = 'thermal_has_drawer';

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCaja = prefs.getBool(_kHasCaja) ?? false;
    if (!mounted) return;
    setState(() => _tieneCaja = hasCaja);

    if (ThermalPrinterService.isWebUsbSupported) {
      // Chrome/Edge web — WebUSB
      setState(() { _cargando = true; _error = null; });
      try {
        final dev = await ThermalPrinterService.getAutoDevice();
        if (!mounted) return;
        setState(() { _device = dev; _cargando = false; });
      } catch (e) {
        if (!mounted) return;
        setState(() { _error = e.toString(); _cargando = false; });
      }
    } else if (!kIsWeb) {
      // Exe nativo — impresoras del sistema
      await _cargarWinPrinters();
    }
  }

  Future<void> _cargarWinPrinters() async {
    setState(() => _cargandoWin = true);
    try {
      final printers  = await WindowsPrinterService.listPrinters();
      final savedName = await WindowsPrinterService.getSavedName();
      Printer? saved;
      if (savedName != null) {
        try { saved = printers.firstWhere((p) => p.name == savedName); }
        catch (_) {} // impresora desconectada
      }
      if (!mounted) return;
      setState(() {
        _winPrinters  = printers;
        _winPrinter   = saved;
        _cargandoWin  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoWin = false);
    }
  }

  Future<void> _seleccionarWinPrinter(Printer p) async {
    await WindowsPrinterService.savePrinter(p);
    if (!mounted) return;
    setState(() => _winPrinter = p);
  }

  Future<void> _desvincularWin() async {
    await WindowsPrinterService.clearSaved();
    if (!mounted) return;
    setState(() => _winPrinter = null);
  }

  Future<void> _imprimirPruebaWin() async {
    if (_winPrinter == null) return;
    setState(() => _trabajando = true);
    try {
      bool ok;
      if (await WindowsPrinterService.hasSavedPrinter()) {
        // ESC/POS RAW via WritePrinter (COM, USB, red — cualquier puerto)
        final bytes = await ThermalPrinterService.buildTestPage();
        ok = await WindowsPrinterService.printRaw(bytes);
      } else {
        // Impresora Windows normal → PDF
        final bytes = await _buildPdfTestPage();
        ok = await Printing.directPrintPdf(
          printer: _winPrinter!,
          onLayout: (_) async => bytes,
          name: 'Prueba_Impresora.pdf',
        );
      }
      if (!mounted) return;
      _snack(ok ? 'Página de prueba enviada a ${_winPrinter!.name}' : 'No se pudo imprimir', ok);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', false);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _seleccionar() async {
    setState(() { _cargando = true; _error = null; });
    final dev = await ThermalPrinterService.requestDevice();
    if (!mounted) return;
    setState(() { _device = dev; _cargando = false; });
  }

  Future<void> _desvincular() async {
    await ThermalPrinterService.clearSaved();
    if (!mounted) return;
    setState(() => _device = null);
  }

  Future<void> _toggleCaja(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasCaja, value);
    if (!mounted) return;
    setState(() => _tieneCaja = value);
  }

  Future<void> _imprimirPrueba() async {
    if (ThermalPrinterService.isWebUsbSupported) {
      if (_device == null) return;
      setState(() => _trabajando = true);
      try {
        final bytes = await ThermalPrinterService.buildTestPage();
        await ThermalPrinterService.printBytes(_device!, bytes);
        if (!mounted) return;
        _snack('Página de prueba impresa', true);
      } catch (e) {
        if (!mounted) return;
        _snack('Error: $e', false);
      } finally {
        if (mounted) setState(() => _trabajando = false);
      }
    } else {
      setState(() => _trabajando = true);
      try {
        await Printing.layoutPdf(
          onLayout: (_) => _buildPdfTestPage(),
          name: 'Prueba_Impresora.pdf',
        );
      } finally {
        if (mounted) setState(() => _trabajando = false);
      }
    }
  }

  Future<void> _abrirCaja() async {
    if (_device == null) return;
    setState(() => _trabajando = true);
    try {
      await ThermalPrinterService.kickDrawer(_device!);
      if (!mounted) return;
      // El comando llegó a la impresora. Si la caja no abrió es un problema físico.
      _snack('Señal enviada. Si no abrió, verifica el cable RJ-11.', true);
    } catch (e) {
      if (!mounted) return;
      _snack('Error al enviar señal: $e', false);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: ok ? _green : _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // Página de prueba PDF (fallback Firefox/Safari)
  Future<Uint8List> _buildPdfTestPage() async {
    final fontReg  = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMono = await PdfGoogleFonts.sourceCodeProRegular();
    final now      = DateFormat('dd/MM/yyyy  HH:mm:ss').format(DateTime.now());

    const pdfGreen   = PdfColor.fromInt(0xFF006C49);
    const pdfGreenBg = PdfColor.fromInt(0xFFE8FFF4);

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat(
        80 * PdfPageFormat.mm, 1500 * PdfPageFormat.mm,
        marginLeft: 4 * PdfPageFormat.mm, marginRight: 4 * PdfPageFormat.mm,
        marginTop:  5 * PdfPageFormat.mm, marginBottom: 8 * PdfPageFormat.mm,
      ),
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: const pw.BoxDecoration(color: pdfGreen),
          child: pw.Text('PÁGINA DE PRUEBA',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: fontBold, fontSize: 13,
                color: PdfColors.white, letterSpacing: 1.5)),
        ),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text('POS MULTITIENDA',
            style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700))),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Fecha / Hora:',
              style: pw.TextStyle(font: fontReg, fontSize: 8, color: PdfColors.grey500)),
          pw.Text(now,
              style: pw.TextStyle(font: fontMono, fontSize: 8, color: PdfColors.grey700)),
        ]),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: pdfGreenBg,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Text('Impresora funcionando correctamente',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: pdfGreen)),
            pw.SizedBox(height: 4),
            pw.Text('La conexión es correcta.',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontReg, fontSize: 8, color: PdfColors.grey500)),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Texto normal — 9pt',
            style: pw.TextStyle(font: fontReg, fontSize: 9, color: PdfColors.grey700)),
        pw.Text('TEXTO EN NEGRITA — 9pt',
            style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
        pw.SizedBox(height: 6),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ),
        pw.Center(child: pw.BarcodeWidget(
          barcode:  pw.Barcode.code128(),
          data:     'PRUEBA-POS-80MM',
          width:    58 * PdfPageFormat.mm,
          height:   22,
          drawText: false,
          color:    PdfColors.black,
        )),
        pw.SizedBox(height: 3),
        pw.Center(child: pw.Text('PRUEBA-POS-80MM',
            style: pw.TextStyle(font: fontMono, fontSize: 7, color: PdfColors.grey700))),
        pw.SizedBox(height: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ),
        pw.Center(child: pw.Text('— Fin de página de prueba —',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontReg, fontSize: 8, color: PdfColors.grey500))),
        pw.SizedBox(height: 6),
      ],
    ));
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final webUsb    = ThermalPrinterService.isWebUsbSupported;
    final nativeExe = !kIsWeb;
    final conectada = webUsb ? _device != null
                             : nativeExe && _winPrinter != null;
    final deviceLabel = webUsb ? (_device?.displayName ?? '')
                                : (_winPrinter?.name ?? '');

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ══════════════════════════════════════════════════
          // SECCIÓN 1 — Impresora térmica
          // ══════════════════════════════════════════════════
          _DeviceRow(
            icon: conectada ? Icons.print_rounded : Icons.print_outlined,
            iconColor: conectada ? _green : _grey,
            iconBg: conectada ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
            loading: _cargando || _cargandoWin,
            title: 'Impresora térmica',
            subtitle: (_cargando || _cargandoWin) ? 'Buscando…'
                    : conectada                    ? deviceLabel
                    : kIsWeb && !webUsb            ? 'Requiere Chrome o Edge'
                                                   : 'Sin impresora configurada',
            subtitleColor: conectada ? _green : _grey,
          ),

          if (webUsb) ...[
            const SizedBox(height: 10),
            if (conectada) ...[
              // ── Impresora conectada ──────────────────────
              _StatusChip(
                label: _device!.displayName,
                sub: _device!.manufacturer.isNotEmpty ? _device!.manufacturer : null,
                color: _green,
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFF6EE7B7),
                icon: Icons.check_circle_rounded,
                trailing: TextButton(
                  onPressed: _desvincular,
                  child: const Text('Desvincular',
                      style: TextStyle(fontSize: 11, color: _red)),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Prueba de impresión',
                    icon: Icons.print_rounded,
                    color: _indigo,
                    loading: _trabajando,
                    onTap: _imprimirPrueba,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _trabajando ? null : _seleccionar,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                  label: const Text('Cambiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _indigo,
                    side: const BorderSide(color: Color(0xFFBFBFF7)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ] else ...[
              // ── Sin impresora: botón configurar ──────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cargando ? null : _seleccionar,
                  icon: const Icon(Icons.usb_rounded, size: 16),
                  label: const Text('Conectar impresora USB'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _InfoBanner(
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF0284C7),
                bg: const Color(0xFFF0F9FF),
                border: const Color(0xFFBAE6FD),
                text: 'Chrome mostrará el picker USB. '
                    'El permiso queda guardado — la próxima vez '
                    'la impresora se conecta automáticamente.',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              _InfoBanner(
                icon: Icons.error_outline_rounded,
                color: _red,
                bg: const Color(0xFFFFF1F2),
                border: const Color(0xFFFECACA),
                text: _error!,
              ),
            ],
          ] else if (nativeExe) ...[
            // ── Exe nativo: selector de impresoras del sistema ──
            const SizedBox(height: 10),
            if (_cargandoWin)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_winPrinter != null) ...[
              // Impresora seleccionada
              _StatusChip(
                label: _winPrinter!.name,
                sub: _winPrinter!.isDefault ? 'Impresora predeterminada' : null,
                color: _green,
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFF6EE7B7),
                icon: Icons.check_circle_rounded,
                trailing: TextButton(
                  onPressed: _desvincularWin,
                  child: const Text('Cambiar', style: TextStyle(fontSize: 11, color: _indigo)),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Prueba de impresión',
                    icon: Icons.print_rounded,
                    color: _indigo,
                    loading: _trabajando,
                    onTap: _imprimirPruebaWin,
                  ),
                ),
              ]),
            ] else ...[
              // Sin impresora seleccionada
              if (_winPrinters.isEmpty)
                _InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFD97706),
                  bg: const Color(0xFFFFF7ED),
                  border: const Color(0xFFFED7AA),
                  text: 'No se encontraron impresoras instaladas. '
                      'Instala el driver de tu impresora y recarga.',
                )
              else ...[
                _InfoBanner(
                  icon: Icons.info_outline_rounded,
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFF0F9FF),
                  border: const Color(0xFFBAE6FD),
                  text: 'Selecciona la impresora térmica instalada en Windows. '
                      'Queda guardada y los recibos se imprimen automáticamente.',
                ),
                const SizedBox(height: 10),
                // Dropdown de impresoras disponibles
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _winPrinters.map((p) {
                      final isLast = p == _winPrinters.last;
                      return InkWell(
                        onTap: () => _seleccionarWinPrinter(p),
                        borderRadius: BorderRadius.vertical(
                          top: _winPrinters.first == p
                              ? const Radius.circular(8) : Radius.zero,
                          bottom: isLast ? const Radius.circular(8) : Radius.zero,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: isLast ? null
                                : const Border(bottom: BorderSide(
                                    color: Color(0xFFE5E7EB))),
                          ),
                          child: Row(children: [
                            Icon(
                              p.isDefault
                                  ? Icons.print_rounded
                                  : Icons.print_outlined,
                              size: 18,
                              color: p.isDefault ? _indigo : _grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  if (p.isDefault)
                                    const Text('Predeterminada',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                size: 16, color: Color(0xFF9CA3AF)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _cargarWinPrinters,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Actualizar lista',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: _grey,
                      padding: EdgeInsets.zero),
                ),
              ],
            ],
          ] else ...[
            // ── Fallback Firefox/Safari ────────────────────
            const SizedBox(height: 10),
            _InfoBanner(
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFD97706),
              bg: const Color(0xFFFFF7ED),
              border: const Color(0xFFFED7AA),
              text: 'La conexión directa requiere Chrome o Edge (WebUSB).',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _ActionBtn(
                label: 'Imprimir prueba (diálogo)',
                icon: Icons.print_rounded,
                color: _grey,
                loading: _trabajando,
                onTap: _imprimirPrueba,
              ),
            ),
          ],

          // ══════════════════════════════════════════════════
          // SECCIÓN 2 — Caja de dinero
          // ══════════════════════════════════════════════════
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),

          _DeviceRow(
            icon: _tieneCaja
                ? Icons.point_of_sale_rounded
                : Icons.point_of_sale_outlined,
            iconColor: _tieneCaja ? const Color(0xFF92400E) : _grey,
            iconBg: _tieneCaja
                ? const Color(0xFFFEF9C3)
                : const Color(0xFFF3F4F6),
            loading: false,
            title: 'Caja de dinero',
            subtitle: _tieneCaja
                ? 'Configurada (puerto RJ-11 de la impresora)'
                : 'Sin caja de dinero configurada',
            subtitleColor: _tieneCaja ? const Color(0xFF92400E) : _grey,
            trailing: Switch(
              value: _tieneCaja,
              onChanged: _toggleCaja,
              activeThumbColor: const Color(0xFF92400E),
              activeTrackColor: const Color(0xFFFDE68A),
            ),
          ),

          if (_tieneCaja) ...[
            const SizedBox(height: 10),
            if (conectada) ...[
              _StatusChip(
                label: 'Conectada vía ${_device!.displayName}',
                sub: 'El cable RJ-11 debe estar enchufado a la impresora',
                color: const Color(0xFF92400E),
                bgColor: const Color(0xFFFEF9C3),
                borderColor: const Color(0xFFFDE68A),
                icon: Icons.cable_rounded,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _ActionBtn(
                  label: 'Probar apertura de caja',
                  icon: Icons.lock_open_rounded,
                  color: const Color(0xFF92400E),
                  loading: _trabajando,
                  onTap: _abrirCaja,
                ),
              ),
            ] else ...[
              _InfoBanner(
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFD97706),
                bg: const Color(0xFFFFF7ED),
                border: const Color(0xFFFED7AA),
                text: 'Conecta la impresora primero para poder '
                    'operar la caja de dinero.',
              ),
            ],
          ] else ...[
            const SizedBox(height: 6),
            _InfoBanner(
              icon: Icons.info_outline_rounded,
              color: _grey,
              bg: const Color(0xFFF9FAFB),
              border: const Color(0xFFE5E7EB),
              text: 'Activa este toggle si tienes una caja de dinero '
                  'conectada al puerto RJ-11 de la impresora.',
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares de la tarjeta de hardware ─────────────────────────────

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final bool     loading;
  final String   title;
  final String   subtitle;
  final Color    subtitleColor;
  final Widget?  trailing;

  const _DeviceRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.loading,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: loading ? const Color(0xFFF3F4F6) : iconBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF3730A3)))
            : Icon(icon, size: 18, color: iconColor),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: subtitleColor)),
        ]),
      ),
      if (trailing case final t?) t, // ignore: use_null_aware_elements
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final String  label;
  final String? sub;
  final Color   color;
  final Color   bgColor;
  final Color   borderColor;
  final IconData icon;
  final Widget? trailing;

  const _StatusChip({
    required this.label,
    this.sub,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: color)),
            if (sub != null)
              Text(sub!,
                  style: TextStyle(fontSize: 11,
                      color: color.withValues(alpha: 0.75))),
          ]),
        ),
        if (trailing case final t?) t, // ignore: use_null_aware_elements
      ]),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final Color    bg;
  final Color    border;
  final String   text;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 7),
        Expanded(child: Text(text,
            style: TextStyle(fontSize: 11, color: color))),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final bool     loading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: Colors.white))
          : Icon(icon, size: 15),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
