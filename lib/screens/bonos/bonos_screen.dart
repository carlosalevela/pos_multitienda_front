import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../models/bono.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caja_provider.dart';
import '../../providers/config_provider.dart';
import '../../services/bono_service.dart';
import '../../services/thermal_printer_service.dart';
import '../../services/windows_printer_service.dart';

// ── Paleta (verde institucional) ──────────────────────────
const _kGreen      = Color(0xFF006C49);
const _kGreenLight = Color(0xFFECFDF5);
const _kGreenDark  = Color(0xFF004D34);
const _kAmber      = Color(0xFFB45309);
const _kAmberLight = Color(0xFFFEF9C3);
const _kRed        = Color(0xFFBA1A1A);
const _kRedLight   = Color(0xFFFFF1F2);
const _kSurface    = Color(0xFFF7F9FB);
const _kBorder     = Color(0xFFE2E4E6);
const _kText       = Color(0xFF191C1E);
const _kMuted      = Color(0xFF76777D);
const _kCard       = Color(0xFFFFFFFF);

class BonosScreen extends StatefulWidget {
  const BonosScreen({super.key});

  @override
  State<BonosScreen> createState() => _BonosScreenState();
}

class _BonosScreenState extends State<BonosScreen>
    with SingleTickerProviderStateMixin {
  final _svc        = BonoService();
  final _codigoCtrl = TextEditingController();
  late final TabController _tabCtrl;

  List<Bono> _bonos        = [];
  bool       _cargando     = false;
  bool       _validando    = false;
  Bono?      _bonoValidado;
  String     _filtroEstado = 'activo';

  int    _totalActivos     = 0;
  double _valorCirculacion = 0;
  int    _creadosHoy       = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
      final auth   = context.read<AuthProvider>();
      final config = context.read<ConfigProvider>();
      if (config.cuentas.isEmpty) {
        config.recargarCuentas(auth.tiendaId);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final auth = context.read<AuthProvider>();
    setState(() => _cargando = true);

    final r = await _svc.listarBonos(
      empresaId: int.tryParse(auth.empresaId) ?? 0,
      tiendaId:  auth.tiendaId,
      estado:    _filtroEstado.isEmpty ? null : _filtroEstado,
    );

    final rActivos = _filtroEstado == 'activo'
        ? r
        : await _svc.listarBonos(
            empresaId: int.tryParse(auth.empresaId) ?? 0,
            tiendaId:  auth.tiendaId,
            estado:    'activo',
          );

    if (!mounted) return;

    final listaFiltrada = r['success'] == true
        ? (r['data'] as List<Bono>) : <Bono>[];
    final listaActivos  = rActivos['success'] == true
        ? (rActivos['data'] as List<Bono>) : <Bono>[];

    final hoy = DateTime.now();
    setState(() {
      _cargando         = false;
      _bonos            = listaFiltrada;
      _totalActivos     = listaActivos.length;
      _valorCirculacion = listaActivos.fold(0, (s, b) => s + b.saldo);
      _creadosHoy       = listaActivos.where((b) {
        try {
          final d = DateTime.parse(b.createdAt);
          return d.year == hoy.year &&
              d.month == hoy.month &&
              d.day == hoy.day;
        } catch (_) { return false; }
      }).length;
    });
  }

  // Abre diálogo solo en pantalla angosta; en wide cambia al tab Vender
  void _accionVender(bool isWide) {
    if (isWide) {
      _tabCtrl.animateTo(0);
    } else {
      _abrirDialogoVender();
    }
  }

  Future<void> _abrirDialogoVender() async {
    final auth = context.read<AuthProvider>();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogVender(
        svc:       _svc,
        empresaId: int.tryParse(auth.empresaId) ?? 0,
        tiendaId:  auth.tiendaId,
        onCreado:  _onBonoCreado,
      ),
    );
  }

  Future<void> _validarBono() async {
    final codigo = _codigoCtrl.text.trim().toUpperCase();
    if (codigo.isEmpty) return;
    setState(() { _validando = true; _bonoValidado = null; });
    final r = await _svc.validarBono(codigo);
    if (!mounted) return;
    setState(() {
      _validando    = false;
      _bonoValidado = r['success'] == true ? r['data'] as Bono : null;
    });
    if (r['success'] != true) {
      _snack(r['error'] ?? 'Bono no encontrado', isError: true);
    }
  }

  void _onBonoCreado(Bono bono, double vuelta, Future<void> Function(int) imprimir) {
    _cargar();
    _mostrarCodigoGenerado(bono, vuelta, imprimir);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: isError ? _kRed : _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _mostrarCodigoGenerado(Bono bono, double vuelta, Future<void> Function(int) imprimir) {
    bool printing = false;
    final venc = bono.fechaVencimiento.length >= 10
        ? bono.fechaVencimiento.substring(0, 10) : bono.fechaVencimiento;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Header ──────────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _kGreenLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(
                      Icons.card_giftcard_rounded, color: _kGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Text('¡Bono creado!',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 16,
                        color: _kText)),
              ]),
              const SizedBox(height: 20),

              // ── Código card ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  color: _kGreenLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.22)),
                ),
                child: Column(children: [
                  Text('CÓDIGO DEL BONO',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: _kGreen,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Text(bono.codigo,
                      style: GoogleFonts.inter(
                          fontSize: 24, fontWeight: FontWeight.w900,
                          color: _kGreenDark, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('\$${_fmtNum(bono.valorOriginal)}',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: _kMuted),
                    const SizedBox(width: 4),
                    Text('Vence: $venc',
                        style: GoogleFonts.inter(fontSize: 11, color: _kMuted)),
                  ]),
                ]),
              ),

              // ── Vuelta banner ────────────────────────────────────
              if (vuelta > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 9, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _kAmberLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _kAmber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payments_rounded,
                            size: 15, color: _kAmber),
                        const SizedBox(width: 8),
                        Text('Vuelta: ',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: _kAmber)),
                        Text('\$${_fmtNum(vuelta)}',
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w900,
                                color: _kAmber)),
                      ]),
                ),
              ],

              const SizedBox(height: 20),

              // ── Sección impresión ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.print_rounded, size: 13, color: _kMuted),
                    const SizedBox(width: 5),
                    Text('¿Imprimir recibo?',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kMuted,
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 10),
                  if (printing)
                    const SizedBox(
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kGreen),
                        ),
                      ),
                    )
                  else
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            setDlg(() => printing = true);
                            await imprimir(1);
                            if (ctx.mounted) setDlg(() => printing = false);
                          },
                          icon: const Icon(Icons.receipt_long_rounded, size: 14),
                          label: Text('1 copia',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kGreen,
                            side: const BorderSide(color: _kGreen),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setDlg(() => printing = true);
                            await imprimir(2);
                            if (ctx.mounted) setDlg(() => printing = false);
                          },
                          icon: const Icon(Icons.receipt_long_rounded, size: 14),
                          label: Text('2 copias',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ]),
                ]),
              ),

              const SizedBox(height: 16),

              // ── Acciones finales ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: bono.codigo));
                      _snack('Código copiado al portapapeles');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14,
                        color: _kGreen),
                    label: Text('Copiar código',
                        style: GoogleFonts.inter(
                            color: _kGreen, fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cerrar',
                        style: GoogleFonts.inter(
                            color: _kMuted, fontWeight: FontWeight.w500,
                            fontSize: 13)),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) {
            final isWide = c.maxWidth >= 700;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isWide),
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildListaColumn()),
                            _buildPanelDerecho(),
                          ],
                        )
                      : _buildNarrow(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader(bool isWide) => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
    decoration: const BoxDecoration(
      color: _kCard,
      border: Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: _kGreenLight, borderRadius: BorderRadius.circular(10)),
        child: const Icon(
            Icons.card_giftcard_rounded, size: 20, color: _kGreen),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bonos de regalo',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        Text('Gestiona, vende y consulta bonos de regalo',
            style: GoogleFonts.inter(fontSize: 11, color: _kMuted)),
      ]),
      const SizedBox(width: 16),
      _KpiPill(
        label: 'Activos',
        value: '$_totalActivos',
        color: _kGreen,
        bg: _kGreenLight,
      ),
      const SizedBox(width: 8),
      _KpiPill(
        label: 'En circulación',
        value: '\$${_fmtNum(_valorCirculacion)}',
        color: _kGreen,
        bg: _kGreenLight,
      ),
      if (_creadosHoy > 0) ...[
        const SizedBox(width: 8),
        _KpiPill(
          label: 'Hoy',
          value: '$_creadosHoy',
          color: _kAmber,
          bg: _kAmberLight,
        ),
      ],
      const Spacer(),
      IconButton(
        onPressed: _cargando ? null : _cargar,
        icon: _cargando
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kGreen))
            : const Icon(Icons.refresh_rounded, size: 20, color: _kMuted),
        tooltip: 'Actualizar',
      ),
      if (!isWide) ...[
        const SizedBox(width: 6),
        ElevatedButton.icon(
          onPressed: () => _accionVender(isWide),
          icon: const Icon(Icons.add_card_rounded, size: 16),
          label: Text('Vender bono',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ]),
  );

  // ── Panel derecho (tabs) ──────────────────────────────────

  Widget _buildPanelDerecho() {
    final auth = context.read<AuthProvider>();
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(left: BorderSide(color: _kBorder)),
      ),
      child: Column(children: [
        // Tab bar
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: _kGreen,
            unselectedLabelColor: _kMuted,
            indicatorColor: _kGreen,
            indicatorWeight: 2.5,
            labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(text: 'Vender bono'),
              Tab(text: 'Consultar'),
            ],
          ),
        ),
        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // Tab 0: Vender
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _PanelVender(
                  svc:       _svc,
                  empresaId: int.tryParse(auth.empresaId) ?? 0,
                  tiendaId:  auth.tiendaId,
                  onCreado:  _onBonoCreado,
                ),
              ),
              // Tab 1: Consultar
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _PanelValidar(
                  ctrl:         _codigoCtrl,
                  validando:    _validando,
                  bonoValidado: _bonoValidado,
                  onValidar:    _validarBono,
                  onLimpiar:    () => setState(() {
                    _bonoValidado = null;
                    _codigoCtrl.clear();
                  }),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Columna izquierda (lista) ─────────────────────────────

  Widget _buildListaColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: _buildListaHeaderRow(),
      ),
      Expanded(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: _kGreen))
            : _bonos.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _bonos.length,
                    itemBuilder: (_, i) =>
                        _FilaBono(bono: _bonos[i]),
                  ),
      ),
    ],
  );

  // ── Pantalla angosta (scroll vertical) ───────────────────

  Widget _buildNarrow() {
    final auth = context.read<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini form vender
          _PanelVender(
            svc:       _svc,
            empresaId: int.tryParse(auth.empresaId) ?? 0,
            tiendaId:  auth.tiendaId,
            onCreado:  _onBonoCreado,
          ),
          const SizedBox(height: 16),
          _PanelValidar(
            ctrl:         _codigoCtrl,
            validando:    _validando,
            bonoValidado: _bonoValidado,
            onValidar:    _validarBono,
            onLimpiar:    () => setState(() {
              _bonoValidado = null;
              _codigoCtrl.clear();
            }),
          ),
          const SizedBox(height: 20),
          _buildListaHeaderRow(),
          const SizedBox(height: 10),
          if (_cargando)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                        color: _kGreen)))
          else if (_bonos.isEmpty)
            _buildEmptyState()
          else
            ..._bonos.map((b) => _FilaBono(bono: b, onCancelado: _cargar)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildListaHeaderRow() => Row(children: [
    Text('Lista de bonos',
        style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kText)),
    const Spacer(),
    _FiltroChip(
      label: 'Activos', value: 'activo', current: _filtroEstado,
      onTap: () { setState(() => _filtroEstado = 'activo'); _cargar(); }),
    const SizedBox(width: 6),
    _FiltroChip(
      label: 'Redimidos', value: 'redimido', current: _filtroEstado,
      onTap: () { setState(() => _filtroEstado = 'redimido'); _cargar(); }),
    const SizedBox(width: 6),
    _FiltroChip(
      label: 'Todos', value: '', current: _filtroEstado,
      onTap: () { setState(() => _filtroEstado = ''); _cargar(); }),
  ]);

  Widget _buildEmptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              color: _kGreenLight, shape: BoxShape.circle),
          child: const Icon(
              Icons.card_giftcard_outlined, size: 32, color: _kGreen),
        ),
        const SizedBox(height: 14),
        Text('Sin bonos',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kText)),
        const SizedBox(height: 4),
        Text('Crea el primer bono usando el panel de la derecha.',
            style: GoogleFonts.inter(fontSize: 12, color: _kMuted)),
      ]),
    ),
  );
}

// ── KPI pill (header) ─────────────────────────────────────

class _KpiPill extends StatelessWidget {
  final String label, value;
  final Color  color, bg;
  const _KpiPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
      const SizedBox(width: 6),
      Text(value,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    ]),
  );
}

// ── Panel Vender (inline) ─────────────────────────────────

class _PanelVender extends StatefulWidget {
  final BonoService svc;
  final int empresaId, tiendaId;
  final void Function(Bono, double, Future<void> Function(int)) onCreado;
  const _PanelVender({
    required this.svc,
    required this.empresaId,
    required this.tiendaId,
    required this.onCreado,
  });

  @override
  State<_PanelVender> createState() => _PanelVenderState();
}

class _PanelVenderState extends State<_PanelVender> {
  final _valorCtrl    = TextEditingController();
  final _recibidoCtrl = TextEditingController();

  String  _metodo   = 'efectivo';
  int?    _cuentaId;
  bool    _creando  = false;
  String? _error;

  static const _metodos = [
    ('efectivo',      'Efectivo',        Icons.payments_rounded),
    ('tarjeta',       'Tarjeta',         Icons.credit_card_rounded),
    ('transferencia', 'Transferencia',   Icons.account_balance_rounded),
    ('nequi',         'Nequi / Daviplata', Icons.phone_android_rounded),
  ];

  double get _valor    => double.tryParse(_valorCtrl.text.trim())    ?? 0;
  double get _recibido => double.tryParse(_recibidoCtrl.text.trim()) ?? 0;
  double get _vuelta   =>
      _metodo == 'efectivo' && _recibido > _valor ? _recibido - _valor : 0;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _recibidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_valor <= 0) {
      setState(() => _error = 'Ingresa un valor mayor a 0');
      return;
    }
    if (_metodo == 'efectivo' && _recibido > 0 && _recibido < _valor) {
      setState(() => _error = 'Monto recibido menor al valor del bono');
      return;
    }
    setState(() { _creando = true; _error = null; });

    final metodoPago = _metodo == 'nequi' ? 'nequi' : _metodo;
    final sesionId   = context.read<CajaProvider>().sesionActiva?.id;

    final r = await widget.svc.venderBono(
      empresaId:     widget.empresaId,
      tiendaId:      widget.tiendaId,
      valor:         _valor,
      metodoPago:    metodoPago,
      montoRecibido: _metodo == 'efectivo' && _recibido > 0 ? _recibido : null,
      sesionCajaId:  sesionId,
    );

    if (!mounted) return;

    if (r['success'] == true) {
      final bono        = r['data'] as Bono;
      final vuelto      = (r['vuelta'] as double?) ?? 0.0;
      final numFact     = (r['numeroFactura'] as String?) ?? '';
      final metodoUsado = _metodo;
      final recibido    = _recibido;
      _valorCtrl.clear();
      _recibidoCtrl.clear();
      setState(() { _metodo = 'efectivo'; _creando = false; _error = null; });
      widget.onCreado(bono, vuelto, (int copies) async {
        for (var i = 0; i < copies; i++) {
          await _imprimir(
            bono: bono, vuelta: vuelto, numeroFactura: numFact,
            metodoPago: metodoUsado, montoRecibido: recibido,
          );
        }
      });
    } else {
      setState(() {
        _creando = false;
        _error   = r['error'] ?? 'Error al crear bono';
      });
    }
  }

  Future<void> _imprimir({
    required Bono   bono,
    required double vuelta,
    required String numeroFactura,
    required String metodoPago,
    required double montoRecibido,
  }) async {
    if (!mounted) return;
    try {
      final config    = context.read<ConfigProvider>();
      final auth      = context.read<AuthProvider>();
      final tipoPapel = config.tipoPapel;
      final paperSize = tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;

      if (tipoPapel != 'pdf' && ThermalPrinterService.isWebUsbSupported) {
        final device = await ThermalPrinterService.getOrRequestDevice();
        if (device != null) {
          final bytes = await ThermalPrinterService.buildReciboBono(
            codigo:           bono.codigo,
            valor:            bono.valorOriginal,
            metodoPago:       metodoPago,
            montoRecibido:    montoRecibido,
            vuelta:           vuelta,
            fechaVencimiento: bono.fechaVencimiento,
            tiendaNombre:     auth.tiendaNombre,
            cajeroNombre:     auth.nombre,
            numeroFactura:    numeroFactura,
            nit:              config.nit,
            direccion:        config.direccion,
            telefono:         config.telefono,
            mensajePie:       config.mensajePie,
            paperSize:        paperSize,
          );
          await ThermalPrinterService.printBytes(device, bytes);
        }
      } else if (tipoPapel != 'pdf' && !kIsWeb &&
                 await WindowsPrinterService.hasSavedPrinter()) {
        final bytes = await ThermalPrinterService.buildReciboBono(
          codigo:           bono.codigo,
          valor:            bono.valorOriginal,
          metodoPago:       metodoPago,
          montoRecibido:    montoRecibido,
          vuelta:           vuelta,
          fechaVencimiento: bono.fechaVencimiento,
          tiendaNombre:     auth.tiendaNombre,
          cajeroNombre:     auth.nombre,
          numeroFactura:    numeroFactura,
          nit:              config.nit,
          direccion:        config.direccion,
          telefono:         config.telefono,
          mensajePie:       config.mensajePie,
          paperSize:        paperSize,
        );
        await WindowsPrinterService.printRaw(bytes);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Valor del bono ───────────────────────────
        Text('Valor del bono',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kMuted,
                letterSpacing: 0.3)),
        const SizedBox(height: 6),
        TextField(
          controller: _valorCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(
              fontSize: 24, fontWeight: FontWeight.w900, color: _kText),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: GoogleFonts.inter(
                fontSize: 24, fontWeight: FontWeight.w900, color: _kMuted),
            hintText: '50 000',
            hintStyle: GoogleFonts.inter(fontSize: 24, color: _kBorder),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _kGreen.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _kGreen.withValues(alpha: 0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: _kGreen, width: 1.5)),
            filled: true,
            fillColor: _kGreenLight.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 20),

        // ── Método de pago ───────────────────────────
        Text('Método de pago',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kMuted,
                letterSpacing: 0.3)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.8,
          children: _metodos.map((m) {
            final sel = _metodo == m.$1;
            return GestureDetector(
              onTap: () =>
                  setState(() { _metodo = m.$1; _cuentaId = null; _error = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? _kGreen : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel ? _kGreen : _kBorder),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: _kGreen.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(m.$3,
                          size: 14,
                          color: sel ? Colors.white : _kMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(m.$2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : _kMuted)),
                      ),
                    ]),
              ),
            );
          }).toList(),
        ),

        // ── Cuentas destino (tarjeta / transferencia / nequi) ──
        if (_metodo != 'efectivo')
          Builder(builder: (ctx) {
            final todas = ctx.watch<ConfigProvider>().cuentas;
            final cuentas = todas.where((c) {
              if (_metodo == 'tarjeta')       return c.tipo == 'tarjeta';
              if (_metodo == 'transferencia') return c.tipo != 'tarjeta';
              return c.tipo != 'tarjeta'; // nequi y otros
            }).toList();
            if (cuentas.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Text('Cuenta destino',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kMuted,
                        letterSpacing: 0.3)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: cuentas.map((c) {
                    final sel = _cuentaId == c.id;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _cuentaId = sel ? null : c.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? _kGreen.withValues(alpha: 0.08)
                              : _kCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? _kGreen : _kBorder,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 13,
                              color: sel ? _kGreen : _kMuted),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(c.nombre,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sel ? _kGreen : _kText)),
                              Text(c.tipoDisplay,
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: sel ? _kGreen : _kMuted)),
                            ],
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }),

        // ── Monto recibido (solo efectivo) ───────────
        if (_metodo == 'efectivo') ...[
          const SizedBox(height: 20),
          Text('Monto recibido (opcional)',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kMuted,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          TextField(
            controller: _recibidoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kText),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kMuted),
              hintText: '0',
              hintStyle:
                  GoogleFonts.inter(fontSize: 18, color: _kBorder),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
              filled: true,
              fillColor: _kCard,
            ),
          ),
          if (_vuelta > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kAmberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _kAmber.withValues(alpha: 0.35)),
              ),
              child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Vuelta al cliente',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _kAmber)),
                    Text('\$${_fmtNum(_vuelta)}',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _kAmber)),
                  ]),
            ),
          ],
        ],

        // ── Error ────────────────────────────────────
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: GoogleFonts.inter(fontSize: 12, color: _kRed)),
        ],

        const SizedBox(height: 20),

        // ── Botón crear ──────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _creando ? null : _crear,
            icon: _creando
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(
                    Icons.card_giftcard_rounded, size: 17),
            label: Text(
                _creando ? 'Creando...' : 'Crear bono',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Diálogo Vender (pantalla angosta) ─────────────────────

class _DialogVender extends StatelessWidget {
  final BonoService svc;
  final int empresaId, tiendaId;
  final void Function(Bono, double, Future<void> Function(int)) onCreado;
  const _DialogVender({
    required this.svc,
    required this.empresaId,
    required this.tiendaId,
    required this.onCreado,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _kGreenLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.card_giftcard_rounded,
                      size: 20, color: _kGreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Vender bono de regalo',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kText)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: _kMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 20),
              _PanelVender(
                svc:       svc,
                empresaId: empresaId,
                tiendaId:  tiendaId,
                onCreado:  (bono, vuelta, imprimir) {
                  Navigator.pop(context);
                  onCreado(bono, vuelta, imprimir);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Panel Validar / Consultar ─────────────────────────────

class _PanelValidar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool    validando;
  final Bono?   bonoValidado;
  final VoidCallback onValidar, onLimpiar;
  const _PanelValidar({
    required this.ctrl,
    required this.validando,
    required this.bonoValidado,
    required this.onValidar,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    final bono = bonoValidado;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bono != null
            ? (bono.estaVigente ? _kGreenLight : _kRedLight)
            : _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bono != null
              ? (bono.estaVigente
                  ? _kGreen.withValues(alpha: 0.3)
                  : _kRed.withValues(alpha: 0.3))
              : _kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bono != null
                    ? (bono.estaVigente
                        ? _kGreen.withValues(alpha: 0.15)
                        : _kRed.withValues(alpha: 0.1))
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                bono != null
                    ? (bono.estaVigente
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded)
                    : Icons.search_rounded,
                size: 18,
                color: bono != null
                    ? (bono.estaVigente ? _kGreen : _kRed)
                    : _kMuted,
              ),
            ),
            const SizedBox(width: 10),
            Text('Consultar bono',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kText)),
            if (bono != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: onLimpiar,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: _kMuted),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text('Ingresa el código para ver el saldo disponible.',
              style: GoogleFonts.inter(fontSize: 11, color: _kMuted)),
          const SizedBox(height: 16),
          Text('Código del bono',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kMuted,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                    letterSpacing: 1.5),
                decoration: InputDecoration(
                  hintText: 'BON-XXXXXX',
                  hintStyle: GoogleFonts.inter(
                      color: _kBorder,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w400),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: validando ? null : onValidar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: validando
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Consultar',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
              ),
            ),
          ]),
          if (bono != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: bono.estaVigente
                      ? _kGreen.withValues(alpha: 0.2)
                      : _kRed.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(bono.codigo,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: bono.estaVigente
                                ? _kGreenDark
                                : _kRed,
                            letterSpacing: 1.5)),
                    const Spacer(),
                    _EstadoChip(
                        estado: bono.estado,
                        vigente: bono.estaVigente),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _InfoCell(
                      label: 'Saldo disponible',
                      value: '\$${_fmtNum(bono.saldo)}',
                      color: bono.estaVigente ? _kGreen : _kRed,
                    ),
                    const SizedBox(width: 24),
                    _InfoCell(
                        label: 'Valor original',
                        value: '\$${_fmtNum(bono.valorOriginal)}'),
                    const SizedBox(width: 24),
                    _InfoCell(
                        label: 'Vence',
                        value: bono.fechaVencimiento.length >= 10
                            ? bono.fechaVencimiento.substring(0, 10)
                            : bono.fechaVencimiento),
                  ]),
                  if (bono.estaVigente) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: bono.valorOriginal > 0
                            ? (bono.saldo / bono.valorOriginal)
                                .clamp(0.0, 1.0)
                            : 0,
                        minHeight: 6,
                        backgroundColor: _kBorder,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                _kGreen),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Fila de un bono ───────────────────────────────────────

class _FilaBono extends StatelessWidget {
  final Bono          bono;
  final VoidCallback? onCancelado;
  const _FilaBono({required this.bono, this.onCancelado});

  @override
  Widget build(BuildContext context) {
    final pct = bono.valorOriginal > 0
        ? (bono.saldo / bono.valorOriginal).clamp(0.0, 1.0)
        : 0.0;
    final barColor =
        pct > 0.5 ? _kGreen : pct > 0.2 ? _kAmber : _kRed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog(
            context: context,
            builder: (_) => _BonoDetalleDialog(
              bono: bono,
              onCancelado: onCancelado,
            ),
          ),
          child: Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bono.codigo,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _kGreenDark,
                        letterSpacing: 1)),
                if (bono.tiendaOrigenNombre != null)
                  Text(bono.tiendaOrigenNombre!,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: _kMuted)),
              ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: _kBorder,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                    '\$${_fmtNum(bono.saldo)} / \$${_fmtNum(bono.valorOriginal)}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _kMuted)),
              ]),
        ),
        const SizedBox(width: 14),
        Text(
          bono.fechaVencimiento.length >= 10
              ? bono.fechaVencimiento.substring(0, 10)
              : bono.fechaVencimiento,
          style: GoogleFonts.inter(fontSize: 10, color: _kMuted),
        ),
        const SizedBox(width: 14),
        _EstadoChip(
            estado: bono.estado, vigente: bono.estaVigente),
      ]),
          ),
        ),
      ),
    );
  }
}

// ── Helpers visuales ──────────────────────────────────────

class _EstadoChip extends StatelessWidget {
  final String estado;
  final bool   vigente;
  const _EstadoChip(
      {required this.estado, required this.vigente});

  @override
  Widget build(BuildContext context) {
    final color =
        vigente ? _kGreen : (estado == 'redimido' ? _kMuted : _kRed);
    final bg =
        vigente ? _kGreenLight : const Color(0xFFF3F4F6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        estado == 'activo'
            ? 'Activo'
            : estado == 'redimido'
                ? 'Redimido'
                : 'Vencido',
        style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _InfoCell(
      {required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9, color: _kMuted, letterSpacing: 0.3)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color ?? _kText)),
      ]);
}

class _FiltroChip extends StatelessWidget {
  final String label, value, current;
  final VoidCallback onTap;
  const _FiltroChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _kGreen : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _kGreen : _kBorder),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : _kMuted)),
      ),
    );
  }
}

String _fmtNum(double n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}k';
  return n.toStringAsFixed(0);
}

// ── Diálogo de detalle de bono ────────────────────────────

class _BonoDetalleDialog extends StatefulWidget {
  final Bono          bono;
  final VoidCallback? onCancelado;
  const _BonoDetalleDialog({required this.bono, this.onCancelado});

  @override
  State<_BonoDetalleDialog> createState() => _BonoDetalleDialogState();
}

class _BonoDetalleDialogState extends State<_BonoDetalleDialog> {
  bool _cancelando = false;

  Future<void> _confirmarCancelar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancelar bono',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          '¿Seguro que deseas cancelar el bono ${widget.bono.codigo}?\n\n'
          'Esta acción pondrá el saldo a \$0 y no podrá usarse más.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.inter(color: _kMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sí, cancelar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancelando = true);
    final r = await BonoService().cancelarBono(widget.bono.codigo);
    if (!mounted) return;
    setState(() => _cancelando = false);

    if (r['success'] == true) {
      Navigator.pop(context);
      widget.onCancelado?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bono ${widget.bono.codigo} cancelado',
            style: GoogleFonts.inter()),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r['error'] ?? 'Error al cancelar',
            style: GoogleFonts.inter()),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bono = widget.bono;
    final fmt  = NumberFormat('#,##0', 'es_CO');
    final auth = context.read<AuthProvider>();
    final puedeCancel = (auth.esAdmin || auth.esSuperadmin) &&
        bono.estado != 'cancelado' && bono.estado != 'redimido';

    String creadoStr = '';
    if (bono.createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(bono.createdAt).toLocal();
        creadoStr =
            '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'
            '  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) {}
    }

    String venceStr = bono.fechaVencimiento;
    if (bono.fechaVencimiento.isNotEmpty) {
      try {
        final dt = DateTime.parse(bono.fechaVencimiento);
        venceStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
      } catch (_) {}
    }

    final pct      = bono.valorOriginal > 0
        ? (bono.saldo / bono.valorOriginal).clamp(0.0, 1.0)
        : 0.0;
    final barColor = pct > 0.5 ? _kGreen : pct > 0.2 ? _kAmber : _kRed;
    final usado    = bono.valorOriginal - bono.saldo;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FBF9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: _kGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bono.codigo,
                      style: GoogleFonts.inter(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: _kGreenDark, letterSpacing: 1.5)),
                  if (creadoStr.isNotEmpty)
                    Text(creadoStr,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kMuted)),
                ],
              )),
              const SizedBox(width: 10),
              _EstadoChip(estado: bono.estado, vigente: bono.estaVigente),
            ]),
          ),

          // ── Cuerpo ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Info (tienda / cliente)
                if (bono.tiendaOrigenNombre != null ||
                    bono.clienteNombre != null) ...[
                  _label('Información'),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(children: [
                      if (bono.tiendaOrigenNombre != null)
                        _fila(Icons.store_rounded, 'Tienda',
                            bono.tiendaOrigenNombre!),
                      if (bono.tiendaOrigenNombre != null &&
                          bono.clienteNombre != null)
                        const Divider(
                            height: 1, indent: 38,
                            color: Color(0xFFEEF0F2)),
                      if (bono.clienteNombre != null)
                        _fila(Icons.person_rounded, 'Cliente',
                            bono.clienteNombre!),
                    ]),
                  ),
                  const SizedBox(height: 18),
                ],

                // Valor del bono
                _label('Valor del bono'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(children: [
                    // Valor original — banda destacada
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: .06),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                      ),
                      child: Row(children: [
                        Expanded(child: Text('VALOR ORIGINAL',
                            style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: _kGreen, letterSpacing: .6))),
                        Text('\$${fmt.format(bono.valorOriginal)}',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: _kGreen)),
                      ]),
                    ),
                    const Divider(height: 1, color: _kBorder),
                    // Barra + stats
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: _kBorder,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _stat(
                              'Saldo disponible',
                              '\$${fmt.format(bono.saldo)}',
                              barColor)),
                          Expanded(child: _stat(
                              'Usado',
                              '\$${fmt.format(usado)}',
                              _kMuted)),
                          Expanded(child: _stat(
                              'Vence',
                              venceStr,
                              _kMuted)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),

          // ── Acciones ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (puedeCancel) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelando ? null : _confirmarCancelar,
                    icon: _cancelando
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kRed))
                        : const Icon(Icons.cancel_outlined, size: 15),
                    label: Text(_cancelando ? 'Cancelando…' : 'Cancelar bono',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: const BorderSide(color: _kRed),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: bono.codigo));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Código copiado'),
                      backgroundColor: _kGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: Text('Copiar código',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGreen,
                    side: const BorderSide(color: _kGreen),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Cerrar',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  static Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t.toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: _kMuted, letterSpacing: .9)),
  );

  static Widget _fila(IconData icon, String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: const Color(0xFFADB5BD)),
      const SizedBox(width: 10),
      Expanded(flex: 4,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: _kMuted))),
      Expanded(flex: 6,
          child: Text(valor,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _kText))),
    ]),
  );

  static Widget _stat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(value,
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 10, color: _kMuted)),
    ],
  );
}
