// lib/screens/inventario/inventario_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/file_downloader.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/inventario_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../models/producto.dart';
import '../../models/separado.dart';
import '../../services/empleado_service.dart';
import '../../services/inventario_service.dart';
import '../../services/barcode_service.dart';
import '../../core/api_client.dart';
import '../../services/cliente_service.dart';
import 'widgets/producto_form_dialog.dart';
import 'widgets/importar_excel_dialog.dart';
import 'widgets/averias_dialog.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen>
    with TickerProviderStateMixin {
  final _searchCtrl      = TextEditingController();
  final _empleadoService = EmpleadoService();
  final _service         = InventarioService();

  List<Map<String, dynamic>> _tiendas     = [];
  int?                       _tiendaFiltro;
  String                     _activoFiltro = 'true';
  int?                       _hoveredRow;
  bool                       _exportando = false;

  // Insights panel data
  Map<String, dynamic>?      _dashboard;
  List<Map<String, dynamic>> _topProductos     = [];
  List<Map<String, dynamic>> _movimientos      = [];
  List<Map<String, dynamic>> _alertasAgotado   = [];
  List<Map<String, dynamic>> _alertasBajo      = [];
  bool                       _cargandoInsights = false;

  // Cajero panel data
  List<Separado> _separadosActivos   = [];
  bool           _cargandoCajeroPanel = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // Barcode scanner
  StreamSubscription<String>? _barcodeSub;
  bool   _scanActivo    = false;
  Timer? _scanPulseTimer;

  // ── Design tokens ──────────────────────────────────────
  static const _bg       = Color(0xFFF7F9FB);
  static const _surface  = Colors.white;
  static const _border   = Color(0xFFC6C6CD);
  static const _text     = Color(0xFF191C1E);
  static const _muted    = Color(0xFF45464D);
  static const _muted2   = Color(0xFF76777D);
  static const _green    = Color(0xFF006C49);
  static const _greenBg  = Color(0xFF6CF8BB);
  static const _danger   = Color(0xFFBA1A1A);
  static const _dangerBg = Color(0xFFFFDAD6);
  static const _warning  = Color(0xFFF59E0B);
  static const _surfLow  = Color(0xFFF2F4F6);
  static const _surfHigh = Color(0xFFE6E8EA);

  TextStyle _t({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize:      size,
        fontWeight:    weight,
        color:         color ?? _text,
        letterSpacing: letterSpacing,
        height:        height,
      );

  // ══════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _barcodeSub = BarcodeService.instance.onBarcode.listen(_onBarcode);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final inv  = context.read<InventarioProvider>();

      if (auth.rol == 'admin' || auth.rol == 'superadmin') {
        final tiendas = await _empleadoService.getTiendas();
        if (!mounted) return;
        setState(() {
          _tiendas      = tiendas;
          _tiendaFiltro = tiendas.isNotEmpty ? tiendas.first['id'] : null;
        });
        inv.cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro);
      } else {
        inv.cargarProductos(
          tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
          activo:   _activoFiltro,
        );
      }
      _cargarInsights();
      if (auth.rol == 'cajero') _cargarPanelCajero();
    });
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _scanPulseTimer?.cancel();
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onBarcode(String codigo) {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _searchCtrl.text = codigo;
    context.read<InventarioProvider>().cargarProductos(
      q: codigo, tiendaId: _tiendaActiva, activo: _activoFiltro,
    );
    setState(() => _scanActivo = true);
    _scanPulseTimer?.cancel();
    _scanPulseTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scanActivo = false);
    });
  }

  // ══════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int)    return v;
    if (v is num)    return v.toInt();
    if (v is String) return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? 0);
    return 0;
  }

  int? get _tiendaActiva {
    final auth = context.read<AuthProvider>();
    if (auth.rol == 'admin' || auth.rol == 'superadmin') return _tiendaFiltro;
    return auth.tiendaId == 0 ? null : auth.tiendaId;
  }

  int? get _empresaActiva {
    if (_tiendaFiltro == null) return null;
    final t   = _tiendas.where((t) => t['id'] == _tiendaFiltro).firstOrNull;
    final raw = t?['empresa'];
    if (raw is int)    return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String _nombreTiendaActual() {
    if (_tiendaFiltro == null) return 'Todas las tiendas';
    final t = _tiendas.where((t) => t['id'] == _tiendaFiltro).firstOrNull;
    return t?['nombre'] ?? 'Tienda';
  }

  Future<void> _cargarInsights() async {
    setState(() => _cargandoInsights = true);
    try {
      final results = await Future.wait([
        _service.getDashboard(tiendaId: _tiendaActiva, empresaId: _empresaActiva),
        _service.getTopProductos(tiendaId: _tiendaActiva, limite: 5),
        _service.getMovimientosRecientes(tiendaId: _tiendaActiva, limite: 8),
        _service.getInventario(tiendaId: _tiendaActiva, alerta: 'agotado'),
        _service.getInventario(tiendaId: _tiendaActiva, alerta: 'bajo'),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard      = results[0]['data'] as Map<String, dynamic>?;
        _topProductos   = (results[1]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _movimientos    = (results[2]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _alertasAgotado = (results[3]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _alertasBajo    = (results[4]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _cargandoInsights = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoInsights = false);
    }
  }

  Future<void> _cargarPanelCajero() async {
    if (!mounted) return;
    setState(() => _cargandoCajeroPanel = true);
    final tid = context.read<AuthProvider>().tiendaId;
    try {
      final seps = await ClienteService().getSeparados(
        tiendaId: tid > 0 ? tid : null,
        estado: 'activo',
      );
      if (mounted) setState(() => _separadosActivos = seps);
    } catch (_) {}
    if (mounted) setState(() => _cargandoCajeroPanel = false);
  }

  Color _avatarColor(String nombre) {
    const cols = [
      Color(0xFF6366F1), Color(0xFF0891B2), Color(0xFF059669),
      Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF7C3AED),
      Color(0xFF0284C7), Color(0xFF16A34A),
    ];
    if (nombre.isEmpty) return cols[0];
    return cols[nombre.codeUnitAt(0) % cols.length];
  }

  String _formatNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  String _tiempoRelativo(String? iso) {
    if (iso == null) return '';
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60)  return 'hace ${diff.inMinutes}m';
      if (diff.inHours   < 24)  return 'hace ${diff.inHours}h';
      if (diff.inDays    < 7)   return 'hace ${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  // ══════════════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════════════
  void _abrirImportarExcel(InventarioProvider inv) {
    showDialog<bool>(
      context:          context,
      barrierDismissible: false,
      builder: (_) => ImportarExcelDialog(
        tiendaId:     _tiendaActiva ?? 0,
        empresaId:    _empresaActiva,
        nombreTienda: _nombreTiendaActual(),
      ),
    );
  }

  Future<void> _abrirAverias() async {
    await showDialog(
      context: context,
      builder: (_) => AveriasDialog(
        tiendaId:     _tiendaActiva,
        nombreTienda: _nombreTiendaActual(),
      ),
    );
    if (!mounted) return;
    context.read<InventarioProvider>().cargarProductos(
      tiendaId: _tiendaActiva,
      activo:   _activoFiltro,
    );
    _cargarInsights();
  }

  Future<void> _exportarExcel() async {
    setState(() => _exportando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _service.exportarInventario(
        tiendaId:  _tiendaActiva,
        empresaId: _empresaActiva,
        activo:    _activoFiltro,
      );

      if (result['success'] != true) {
        messenger.showSnackBar(SnackBar(
          content: Text(result['error'] ?? 'Error al exportar'),
          backgroundColor: _danger,
        ));
        return;
      }

      final bytes    = result['bytes'] as List<int>;
      final now      = DateTime.now();
      final stamp    = '${now.year}${now.month.toString().padLeft(2, '0')}'
                       '${now.day.toString().padLeft(2, '0')}';
      final fileName = 'inventario_$stamp.xlsx';

      final saved = await guardarArchivoExcel(bytes, fileName);

      messenger.showSnackBar(SnackBar(
        content: Text('Guardado: $saved'),
        backgroundColor: _green,
        duration: const Duration(seconds: 4),
      ));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _abrirFormulario(BuildContext ctx, InventarioProvider inv,
      {Producto? producto}) {
    showDialog(
      context: ctx,
      builder: (_) => ProductoFormDialog(
        producto:  producto,
        tiendaId:  _tiendaActiva ?? 0,
        empresaId: _empresaActiva,
        onGuardar: (data) async {
          producto == null
              ? await inv.crearProducto(data)
              : await inv.editarProducto(producto.id, data);
        },
      ),
    );
  }

  void _confirmarEliminar(
      BuildContext ctx, InventarioProvider inv, Producto p) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   Text('Desactivar producto',
            style: _t(size: 16, weight: FontWeight.w700)),
        content: Text(
          '¿Desactivar "${p.nombre}"? No aparecerá en ventas ni búsquedas.',
          style: _t(size: 13, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: _t(size: 13, color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await inv.eliminarProducto(p.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Desactivar',
                style: _t(size: 13, weight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarReactivar(
      BuildContext ctx, InventarioProvider inv, Producto p) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   Text('Reactivar producto',
            style: _t(size: 16, weight: FontWeight.w700)),
        content: Text('¿Reactivar "${p.nombre}"?',
            style: _t(size: 13, color: _muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: _t(size: 13, color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await inv.reactivarProducto(p.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reactivar',
                style: _t(size: 13, weight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final inv      = context.watch<InventarioProvider>();
    final auth     = context.watch<AuthProvider>();
    final esCajero    = auth.rol == 'cajero';
    final esAdmin     = auth.rol == 'admin' || auth.rol == 'superadmin';
    final esSupervisor = auth.rol == 'supervisor';
    final puedeGestionar = esAdmin || esSupervisor;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: _bg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(esCajero, esAdmin, inv),
              const SizedBox(height: 14),
              if (esAdmin && _tiendas.isNotEmpty) ...[
                _selectorTienda(),
                const SizedBox(height: 12),
              ],
              _buildKPIGrid(inv.productos, esCajero: esCajero),
              const SizedBox(height: 14),
              _buildToolbar(esCajero, inv),
              const SizedBox(height: 12),
              if (inv.successMsg != null)
                _banner(inv.successMsg!,
                    isError: false, onClose: inv.limpiarMensajes),
              if (inv.errorMsg != null)
                _banner(inv.errorMsg!,
                    isError: true, onClose: inv.limpiarMensajes),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Tabla principal ──────────────────
                    Expanded(
                      flex: 3,
                      child: inv.cargando
                          ? _loadingState()
                          : inv.productos.isEmpty
                              ? _emptyState(esCajero)
                              : _buildTabla(
                                  inv.productos, esCajero, esAdmin, inv),
                    ),
                    // ── Panel insights (admin/supervisor) ─
                    if (puedeGestionar) ...[
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 280,
                        child: _buildInsightsPanel(),
                      ),
                    ],
                    // ── Panel turno (cajero) ──────────────
                    if (esCajero) ...[
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 280,
                        child: _buildCajeroPanel(inv.productos),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════
  Widget _buildHeader(
      bool esCajero, bool esAdmin, InventarioProvider inv) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.inventory_2_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Control de Inventario',
                  style: _t(size: 20, weight: FontWeight.w700,
                      letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(
                esAdmin
                    ? 'Vista general · ${_tiendas.isEmpty ? 'Cargando…' : _nombreTiendaActual()}'
                    : 'Supervisa existencias, precios y disponibilidad',
                style: _t(size: 13, color: _muted),
              ),
            ],
          ),
        ),
        if (!esCajero) ...[
          _btnSecundario(
            icon:  Icons.download_rounded,
            label: _exportando ? 'Exportando…' : 'Exportar Excel',
            onTap: _exportando ? null : _exportarExcel,
          ),
          const SizedBox(width: 10),
          _btnSecundario(
            icon:  Icons.table_chart_rounded,
            label: 'Importar Excel',
            // Importar sin tienda crearía productos sin inventario (stock 0)
            onTap: _tiendaActiva != null ? () => _abrirImportarExcel(inv) : null,
          ),
          const SizedBox(width: 10),
          _btnSecundario(
            icon:  Icons.warning_amber_rounded,
            label: 'Averías',
            onTap: () => _abrirAverias(),
          ),
          const SizedBox(width: 10),
          _btnPrimario(
            icon:  Icons.add_rounded,
            label: 'Nuevo producto',
            onTap: () => _abrirFormulario(context, inv),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // SELECTOR TIENDA
  // ══════════════════════════════════════════════════════
  Widget _selectorTienda() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chipTienda(id: null, nombre: 'Todas',
            icono: Icons.store_mall_directory_rounded),
        const SizedBox(width: 8),
        ..._tiendas.asMap().entries.map((e) {
          final t = e.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _chipTienda(
              id:     t['id'] as int,
              nombre: t['nombre'] as String? ?? 'Tienda',
              icono:  Icons.store_rounded,
            ),
          );
        }),
      ]),
    ),
  );

  Widget _chipTienda({
    required int?    id,
    required String  nombre,
    required IconData icono,
  }) {
    final sel = _tiendaFiltro == id;
    return GestureDetector(
      onTap: () {
        if (_tiendaFiltro == id) return;
        setState(() { _tiendaFiltro = id; _searchCtrl.clear(); });
        context.read<InventarioProvider>().cargarProductos(
          tiendaId: id, activo: _activoFiltro);
        _cargarInsights();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:  sel ? _greenBg  : _surfLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? _green : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14, color: sel ? _green : _muted2),
          const SizedBox(width: 7),
          Text(nombre, style: _t(size: 12, weight: FontWeight.w600,
              color: sel ? _green : _muted)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // KPI GRID
  // ══════════════════════════════════════════════════════
  Widget _buildKPIGrid(List<Producto> productos, {bool esCajero = false}) {
    final d          = _dashboard;
    final valorTotal = d != null
        ? _toDouble(d['total_valor_inventario'])
        : productos.fold<double>(0, (s, p) => s + p.precio * p.stockActual);
    final alertasBajo = d != null
        ? _toInt(d['alertas_stock_bajo'])
        : productos.where((p) =>
            p.stockActual > 0 &&
            (p.stockMinimo > 0
                ? p.stockActual <= p.stockMinimo
                : p.stockActual <= 10)).length;
    final alertasCrit = d != null
        ? _toInt(d['alertas_criticas'])
        : productos.where((p) => p.stockActual <= 0).length;
    final ingresosMes = d != null
        ? _toDouble(d['ingresos_mes_unidades'])
        : 0.0;
    final perdidasMes = d != null
        ? _toDouble(d['perdidas_mes_valor'])
        : 0.0;

    return Row(children: [
      if (!esCajero) ...[
        Expanded(child: _kpiCard(
          icon:      Icons.payments_rounded,
          iconBg:    const Color(0xFFDAE2FD),
          iconColor: const Color(0xFF3F465C),
          label:     'VALOR DE INVENTARIO',
          value:     '${Constants.moneda}${_formatNum(valorTotal)}',
          sub:       '${productos.length} productos en stock',
          accent:    _green,
          barValue:  null,
        )),
        const SizedBox(width: 12),
      ],
      Expanded(child: _kpiCard(
        icon:        Icons.warning_rounded,
        iconBg:      _dangerBg,
        iconColor:   _danger,
        label:       'ALERTAS STOCK BAJO',
        value:       '${alertasBajo + alertasCrit}',
        valueSuffix: ' Items',
        sub:         '$alertasCrit críticos (agotados)',
        accent:      _danger,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:      Icons.input_rounded,
        iconBg:    _greenBg,
        iconColor: _green,
        label:     'INGRESOS DEL MES',
        value:     _formatNum(ingresosMes),
        sub:       'Unidades recibidas este mes',
        accent:    _green,
        barValue:  null,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:      Icons.inventory_2_rounded,
        iconBg:    _surfHigh,
        iconColor: _muted2,
        label:     'DAÑOS / PÉRDIDAS',
        value:     '${Constants.moneda}${_formatNum(perdidasMes)}',
        sub:       'Reportados este mes',
        accent:    _muted2,
      )),
    ]);
  }

  Widget _kpiCard({
    required IconData  icon,
    required Color     iconBg,
    required Color     iconColor,
    required String    label,
    required String    value,
    String?            valueSuffix,
    required String    sub,
    required Color     accent,
    double?            barValue,
  }) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:         iconBg,
                    borderRadius:  BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(label,
                style: _t(size: 11, weight: FontWeight.w600,
                    color: _muted, letterSpacing: 0.05)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(value,
                      style: _t(size: 26, weight: FontWeight.w700,
                          letterSpacing: -0.5, height: 1.1)),
                ),
                if (valueSuffix != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Text(valueSuffix,
                        style: _t(size: 15, weight: FontWeight.w600,
                            color: _muted)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (barValue != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value:           barValue.clamp(0.0, 1.0),
                  minHeight:       4,
                  backgroundColor: _surfHigh,
                  valueColor:      AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(sub, style: _t(size: 11, color: _muted)),
          ],
        ),
      );

  // ══════════════════════════════════════════════════════
  // TOOLBAR
  // ══════════════════════════════════════════════════════
  Widget _buildToolbar(bool esCajero, InventarioProvider inv) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(children: [
      Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: _surfLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: _t(size: 14),
            decoration: InputDecoration(
              hintText:  'Buscar inventarios, SKUs...',
              hintStyle: _t(size: 14, color: _muted2),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF76777D), size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
            ),
            onChanged: (val) =>
                context.read<InventarioProvider>().cargarProductos(
                  q: val, tiendaId: _tiendaActiva, activo: _activoFiltro),
          ),
        ),
      ),
      const SizedBox(width: 10),
      // Indicador escáner
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color:        _scanActivo ? const Color(0xFFE8FFF4) : _surfLow,
          borderRadius: BorderRadius.circular(999),
          border:       Border.all(
            color: _scanActivo ? _green : _border,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.qr_code_scanner_rounded,
              size: 16,
              color: _scanActivo ? _green : _muted2),
          if (_scanActivo) ...[
            const SizedBox(width: 5),
            Text('OK', style: _t(size: 11, weight: FontWeight.w700, color: _green)),
          ],
        ]),
      ),
      if (!esCajero) ...[
        const SizedBox(width: 10),
        _filtroEstado(),
      ],
    ]),
  );

  Widget _filtroEstado() {
    final ops = [
      ('true',  'Activos',   Icons.check_circle_outline_rounded, _green),
      ('false', 'Inactivos', Icons.block_rounded,                _danger),
      ('all',   'Todos',     Icons.all_inclusive_rounded,        _muted),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _surfLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ops.map((op) {
          final (valor, label, icon, color) = op;
          final sel = _activoFiltro == valor;
          return GestureDetector(
            onTap: () {
              setState(() => _activoFiltro = valor);
              context.read<InventarioProvider>().cargarProductos(
                  tiendaId: _tiendaActiva, activo: valor);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: sel
                    ? [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 13,
                    color: sel ? color : _muted2),
                const SizedBox(width: 5),
                Text(label,
                    style: _t(size: 12,
                        weight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? color : _muted)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TABLA PLANA
  // ══════════════════════════════════════════════════════
  void _abrirTransferencia(Producto p) {
    final tiendaId = _tiendaActiva;
    if (tiendaId == null || _tiendas.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            _tiendas.length < 2
                ? 'Se necesitan al menos 2 tiendas para transferir.'
                : 'Selecciona una tienda específica de origen.',
            style: _t(size: 13, color: Colors.white)),
        backgroundColor: _warning,
      ));
      return;
    }
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _TransferenciaSheet(
        producto:         p,
        tiendaOrigenId:   tiendaId,
        tiendas:          _tiendas,
        onTransferida: () => context.read<InventarioProvider>()
            .cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro),
      ),
    );
  }

  void _abrirAjuste(Producto p) {
    final tiendaId = _tiendaActiva;
    if (tiendaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecciona una tienda específica para ajustar stock.',
            style: _t(size: 13, color: Colors.white)),
        backgroundColor: _danger,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AjusteStockSheet(
        producto:  p,
        tiendaId:  tiendaId,
        onAjustado: () => context
            .read<InventarioProvider>()
            .cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro),
      ),
    );
  }

  void _abrirKardex(Producto p) {
    final tiendaId = _tiendaActiva;
    if (tiendaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecciona una tienda específica para ver el kardex.',
            style: _t(size: 13, color: Colors.white)),
        backgroundColor: _warning,
      ));
      return;
    }
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _KardexSheet(
        producto:  p,
        tiendaId:  tiendaId,
        service:   _service,
      ),
    );
  }

  Widget _buildTabla(List<Producto> productos, bool esCajero,
      bool esAdmin, InventarioProvider inv) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          _tablaHeader(esAdmin, esCajero),
          const Divider(height: 1, color: Color(0xFFC6C6CD)),
          Expanded(
            child: ListView.builder(
              padding:     EdgeInsets.zero,
              itemCount:   productos.length,
              itemBuilder: (_, i) =>
                  _tablaFila(productos[i], i, esCajero, esAdmin, inv),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tablaHeader(bool esAdmin, bool esCajero) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
    color: _surfLow,
    child: Row(children: [
      Expanded(flex: 3, child: _th('Producto & SKU')),
      Expanded(flex: 2, child: _th('Categoría')),
      if (esAdmin) ...[
        Expanded(flex: 2, child: _th('Costo', right: true)),
        Expanded(flex: 2, child: _th('Precio venta', right: true)),
        Expanded(flex: 2, child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _th('Margen'),
        )),
      ] else
        Expanded(flex: 2, child: _th('Precio', right: true)),
      Expanded(flex: 1, child: _th('Stock', right: true)),
      Expanded(flex: 2, child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _th('Estado'),
      )),
      if (!esCajero) const SizedBox(width: 44),
    ]),
  );

  Widget _th(String t, {bool right = false}) => Text(
    t,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: _t(size: 11, weight: FontWeight.w600,
        color: _muted2, letterSpacing: 0.04),
  );

  Widget _tablaFila(Producto p, int idx, bool esCajero,
      bool esAdmin, InventarioProvider inv) {
    final esInactivo = _activoFiltro == 'false';
    final agotado    = p.stockActual <= 0;
    final bajo       = !agotado && (p.stockMinimo > 0
        ? p.stockActual <= p.stockMinimo
        : p.stockActual <= 10);
    final isHovered  = _hoveredRow == idx;

    final (estadoText, estadoColor) = esInactivo
        ? ('Inactivo', _muted2)
        : agotado
            ? ('Agotado', _muted2)
            : bajo
                ? ('Stock bajo', _warning)
                : ('Óptimo', _green);

    final costo  = p.precioCompra;
    final venta  = p.precio;
    final margen = costo > 0 ? (venta - costo) / costo * 100 : 0.0;
    final mColor = margen < 0 ? _danger : margen < 10 ? _warning : _green;

    final avatarColor = _avatarColor(p.nombre);
    final inicial     = p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRow = idx),
      onExit:  (_) => setState(() => _hoveredRow = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: isHovered
            ? const Color(0xFFECEEF0)
            : idx.isEven ? _surface : _surfLow.withValues(alpha: 0.35),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(children: [
              // ── Producto & SKU ────────────────────────
              Expanded(
                flex: 3,
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color:         avatarColor.withValues(alpha: 0.12),
                      borderRadius:  BorderRadius.circular(9),
                    ),
                    child: Center(child: Text(inicial,
                        style: _t(size: 14, weight: FontWeight.w700,
                            color: avatarColor))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 13, weight: FontWeight.w600,
                              color: esInactivo ? _muted2 : _text)),
                      if (p.referencia.isNotEmpty)
                        Text('SKU: ${p.referencia}',
                            style: _t(size: 11, color: _muted2)),
                    ],
                  )),
                ]),
              ),
              // ── Categoría ────────────────────────────
              Expanded(
                flex: 2,
                child: p.categoria.isNotEmpty &&
                        p.categoria != 'Sin categoría'
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _surfHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(p.categoria,
                            overflow: TextOverflow.ellipsis,
                            style: _t(size: 11, weight: FontWeight.w600,
                                color: _muted)))
                    : Text('—',
                        style: _t(size: 12, color: _muted2)),
              ),
              // ── Precios ──────────────────────────────
              if (esAdmin) ...[
                Expanded(flex: 2, child: Text(
                    '${Constants.moneda}${costo.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: _t(size: 13, weight: FontWeight.w600,
                        color: _muted))),
                Expanded(flex: 2, child: Text(
                    '${Constants.moneda}${venta.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: _t(size: 13, weight: FontWeight.w700,
                        color: esInactivo ? _muted2 : _text))),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: esInactivo
                      ? Text('—',
                          style: _t(size: 12, color: _muted2))
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: mColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              Icon(
                                margen >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                size: 11, color: mColor),
                              const SizedBox(width: 3),
                              Text('${margen.toStringAsFixed(1)}%',
                                  style: _t(size: 11, weight: FontWeight.w700,
                                      color: mColor)),
                            ]),
                          ),
                        ),
                  ),
                ),
              ] else
                Expanded(flex: 2, child: Text(
                    '${Constants.moneda}${venta.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: _t(size: 13, weight: FontWeight.w700,
                        color: esInactivo ? _muted2 : _text))),
              // ── Stock ────────────────────────────────
              Expanded(flex: 1, child: Text(
                  p.stockActual.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: _t(size: 14, weight: FontWeight.w700,
                      color: esInactivo
                          ? _muted2
                          : agotado
                              ? _danger
                              : bajo ? _warning : _text))),
              // ── Estado ───────────────────────────────
              Expanded(
                flex: 2,
                child: Row(children: [
                  const SizedBox(width: 12),
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: estadoColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(estadoText,
                        overflow: TextOverflow.ellipsis,
                        style: _t(size: 12, weight: FontWeight.w600,
                            color: estadoColor)),
                  ),
                ]),
              ),
              // ── Acciones ─────────────────────────────
              if (!esCajero)
                SizedBox(
                  width: 44,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 130),
                    opacity:  isHovered ? 1.0 : 0.0,
                    child: esInactivo
                        ? (esAdmin
                            ? _actionBtn(
                                icon:    Icons.refresh_rounded,
                                color:   _green,
                                tooltip: 'Reactivar',
                                onTap:   () =>
                                    _confirmarReactivar(context, inv, p))
                            : const SizedBox())
                        : PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                size: 18, color: _muted),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (v) {
                              if (v == 'edit') {
                                _abrirFormulario(context, inv, producto: p);
                              }
                              if (v == 'kardex') {
                                _abrirKardex(p);
                              }
                              if (v == 'transfer') {
                                _abrirTransferencia(p);
                              }
                              if (v == 'adjust') {
                                _abrirAjuste(p);
                              }
                              if (v == 'del') {
                                _confirmarEliminar(context, inv, p);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit_rounded,
                                      size: 16, color: _muted),
                                  const SizedBox(width: 10),
                                  Text('Editar', style: _t(size: 13)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'kardex',
                                child: Row(children: [
                                  Icon(Icons.timeline_rounded,
                                      size: 16, color: _muted),
                                  const SizedBox(width: 10),
                                  Text('Kardex', style: _t(size: 13)),
                                ]),
                              ),
                              if (_tiendas.length >= 2)
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(children: [
                                    Icon(Icons.swap_horiz_rounded,
                                        size: 16, color: _muted),
                                    const SizedBox(width: 10),
                                    Text('Transferir', style: _t(size: 13)),
                                  ]),
                                ),
                              if (!esCajero)
                                PopupMenuItem(
                                  value: 'adjust',
                                  child: Row(children: [
                                    Icon(Icons.tune_rounded,
                                        size: 16, color: _muted),
                                    const SizedBox(width: 10),
                                    Text('Ajustar stock', style: _t(size: 13)),
                                  ]),
                                ),
                              PopupMenuItem(
                                value: 'del',
                                child: Row(children: [
                                  const Icon(Icons.block_rounded,
                                      size: 16, color: _danger),
                                  const SizedBox(width: 10),
                                  Text('Desactivar',
                                      style: _t(size: 13, color: _danger)),
                                ]),
                              ),
                            ],
                          ),
                  ),
                ),
            ]),
          ),
          if (!isHovered)
            const Divider(height: 1, color: Color(0xFFF0F0F2)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // PANEL INSIGHTS (Top Sellers + Movimientos)
  // ══════════════════════════════════════════════════════
  Widget _buildInsightsPanel() {
    final hayAlertas = _alertasAgotado.isNotEmpty || _alertasBajo.isNotEmpty;
    return SingleChildScrollView(
      child: Column(children: [
        if (hayAlertas || _cargandoInsights) ...[
          _alertasStockCard(),
          const SizedBox(height: 14),
        ],
        _topSellersCard(),
        const SizedBox(height: 14),
        _movimientosCard(),
      ]),
    );
  }

  Widget _alertasStockCard() {
    final total = _alertasAgotado.length + _alertasBajo.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _alertasAgotado.isNotEmpty
            ? _dangerBg.withValues(alpha: 0.5)
            : const Color(0xFFFEF9EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _alertasAgotado.isNotEmpty
              ? _danger.withValues(alpha: 0.25)
              : _warning.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _alertasAgotado.isNotEmpty ? _dangerBg : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              size: 16,
              color: _alertasAgotado.isNotEmpty ? _danger : _warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alertas de stock',
                  style: _t(size: 13, weight: FontWeight.w700)),
              Text(
                '$total producto${total != 1 ? 's' : ''} requiere${total == 1 ? '' : 'n'} atención',
                style: _t(size: 10, color: _muted2),
              ),
            ],
          )),
          if (_cargandoInsights)
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: Color(0xFF006C49))),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF0F0F2)),
        const SizedBox(height: 12),
        if (_alertasAgotado.isNotEmpty) ...[
          _seccionLabel('AGOTADOS', _danger),
          ..._alertasAgotado.take(4).map((item) {
            final nombre = item['producto_nombre'] as String? ?? '—';
            final cat    = item['categoria_nombre'] as String? ?? '';
            return _stockRow(nombre, cat, 'Agotado', _danger, _dangerBg);
          }),
          if (_alertasAgotado.length > 4)
            _verMasTxt('+${_alertasAgotado.length - 4} más agotados', _danger),
          if (_alertasBajo.isNotEmpty) const SizedBox(height: 8),
        ],
        if (_alertasBajo.isNotEmpty) ...[
          _seccionLabel('STOCK BAJO', _warning),
          ..._alertasBajo.take(5).map((item) {
            final nombre  = item['producto_nombre'] as String? ?? '—';
            final cat     = item['categoria_nombre'] as String? ?? '';
            final actual  = _toInt(item['stock_actual']);
            final minimo  = _toInt(item['stock_minimo']);
            final label   = minimo > 0 ? '$actual / $minimo uds' : '$actual uds';
            return _stockRow(nombre, cat, label, _warning,
                const Color(0xFFFEF3C7));
          }),
          if (_alertasBajo.length > 5)
            _verMasTxt('+${_alertasBajo.length - 5} más con stock bajo', _warning),
        ],
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // PANEL TURNO CAJERO
  // ══════════════════════════════════════════════════
  Widget _buildCajeroPanel(List<Producto> productos) {
    final agotados = productos.where((p) => p.stockActual <= 0).toList();
    // Si stockMinimo está configurado úsalo; si no, considera crítico ≤ 10 uds
    final criticos = productos.where((p) =>
        p.stockActual > 0 &&
        (p.stockMinimo > 0
            ? p.stockActual <= p.stockMinimo
            : p.stockActual <= 10)).toList();
    final fmtMoney  = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final fmtDate   = DateFormat('d MMM', 'es');

    return SingleChildScrollView(
      child: Column(children: [

        // ── Encabezado ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informe de turno',
                    style: _t(size: 13, weight: FontWeight.w700,
                        color: Colors.white)),
                Text(DateFormat('EEEE d MMM · HH:mm', 'es')
                        .format(DateTime.now()),
                    style: _t(size: 10, color: Colors.white60)),
              ],
            )),
            GestureDetector(
              onTap: () {
                _cargarPanelCajero();
                _cargarInsights();
              },
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white54, size: 16),
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // ── 1. Stock crítico ────────────────────────
        _cajeroCard(
          icon: Icons.warning_rounded,
          iconColor: agotados.isNotEmpty ? _danger : _warning,
          iconBg: agotados.isNotEmpty ? _dangerBg : const Color(0xFFFEF3C7),
          title: 'Stock crítico',
          subtitle: '${agotados.length} agotados · ${criticos.length} bajos',
          loading: false,
          empty: agotados.isEmpty && criticos.isEmpty,
          emptyMsg: 'Todo el stock está bien',
          emptyIcon: Icons.check_circle_outline_rounded,
          child: Column(children: [
            if (agotados.isNotEmpty) ...[
              _seccionLabel('AGOTADOS', _danger),
              ...agotados.take(5).map((p) => _stockRow(
                p.nombre, p.categoria,
                '0 uds', _danger, _dangerBg,
              )),
              if (agotados.length > 5)
                _verMasTxt('${agotados.length - 5} más agotados', _danger),
            ],
            if (criticos.isNotEmpty) ...[
              if (agotados.isNotEmpty) const SizedBox(height: 8),
              _seccionLabel('STOCK BAJO', _warning),
              ...criticos.take(4).map((p) => _stockRow(
                p.nombre, p.categoria,
                '${p.stockActual.toInt()} uds', _warning,
                const Color(0xFFFEF3C7),
              )),
              if (criticos.length > 4)
                _verMasTxt('${criticos.length - 4} más con stock bajo',
                    _warning),
            ],
          ]),
        ),

        const SizedBox(height: 12),

        // ── 2. Separados activos ────────────────────
        _cajeroCard(
          icon: Icons.bookmark_rounded,
          iconColor: _green,
          iconBg: _greenBg,
          title: 'Separados activos',
          subtitle: '${_separadosActivos.length} pedido${_separadosActivos.length != 1 ? 's' : ''} reservado${_separadosActivos.length != 1 ? 's' : ''}',
          loading: _cargandoCajeroPanel,
          empty: _separadosActivos.isEmpty,
          emptyMsg: 'Sin separados activos',
          emptyIcon: Icons.bookmark_border_rounded,
          child: Column(
            children: _separadosActivos.take(5).map((s) {
              final vencido = s.fechaLimite != null &&
                  DateTime.tryParse(s.fechaLimite!)
                          ?.isBefore(DateTime.now()) ==
                      true;
              final porVencer = !vencido && s.fechaLimite != null &&
                  DateTime.tryParse(s.fechaLimite!)
                          ?.isBefore(DateTime.now().add(
                              const Duration(days: 3))) ==
                      true;
              final alertColor = vencido
                  ? _danger
                  : porVencer
                      ? _warning
                      : _green;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        s.clienteNombre.isNotEmpty
                            ? s.clienteNombre[0].toUpperCase() : '?',
                        style: _t(size: 13, weight: FontWeight.w800,
                            color: alertColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.clienteNombre,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 12, weight: FontWeight.w600)),
                      if (s.fechaLimite != null)
                        Text(
                          vencido ? 'Vencido' :
                          'Límite: ${fmtDate.format(DateTime.parse(s.fechaLimite!))}',
                          style: _t(size: 10, color: alertColor,
                              weight: FontWeight.w600),
                        ),
                    ],
                  )),
                  Text(fmtMoney.format(s.saldoPendiente),
                      style: _t(size: 12, weight: FontWeight.w700,
                          color: alertColor)),
                ]),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // ── 3. Movimientos recientes ────────────────
        _cajeroCard(
          icon: Icons.swap_horiz_rounded,
          iconColor: const Color(0xFF3F465C),
          iconBg: const Color(0xFFDAE2FD),
          title: 'Movimientos hoy',
          subtitle: '${_movimientos.length} registrado${_movimientos.length != 1 ? 's' : ''}',
          loading: _cargandoInsights,
          empty: _movimientos.isEmpty,
          emptyMsg: 'Sin movimientos hoy',
          emptyIcon: Icons.swap_horiz_rounded,
          child: Column(
            children: _movimientos.take(6).map((m) {
              final tipo     = m['tipo'] as String? ?? '';
              final nombre   = m['producto_nombre'] as String? ?? '—';
              final cantidad = m['cantidad'];
              final hora     = m['created_at'] != null
                  ? DateFormat('HH:mm').format(
                      DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now())
                  : '';
              final (color, icon, prefix) = switch (tipo) {
                'entrada'  => (_green,   Icons.arrow_downward_rounded, '+'),
                'salida'   => (_danger,  Icons.arrow_upward_rounded,   '-'),
                'averia'   => (_warning, Icons.report_rounded,         ''),
                _          => (_muted2,  Icons.swap_horiz_rounded,     ''),
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(nombre,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 12, weight: FontWeight.w600))),
                  const SizedBox(width: 4),
                  Text('$prefix$cantidad',
                      style: _t(size: 12, weight: FontWeight.w700,
                          color: color)),
                  if (hora.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(hora, style: _t(size: 10, color: _muted2)),
                  ],
                ]),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _cajeroCard({
    required IconData icon,
    required Color    iconColor,
    required Color    iconBg,
    required String   title,
    required String   subtitle,
    required bool     loading,
    required bool     empty,
    required String   emptyMsg,
    required IconData emptyIcon,
    required Widget   child,
  }) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _t(size: 13, weight: FontWeight.w700)),
              Text(subtitle, style: _t(size: 10, color: _muted2)),
            ],
          )),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF0F0F2)),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: Color(0xFF006C49))))
        else if (empty)
          Row(children: [
            Icon(emptyIcon, size: 15, color: _muted2),
            const SizedBox(width: 6),
            Text(emptyMsg, style: _t(size: 12, color: _muted2)),
          ])
        else
          child,
      ]),
    );

  Widget _seccionLabel(String label, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label,
        style: _t(size: 9, weight: FontWeight.w800,
            color: color, letterSpacing: 0.8)),
  );

  Widget _stockRow(String nombre, String cat, String stock,
      Color color, Color bg) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(7)),
          child: Icon(Icons.inventory_2_outlined, size: 13, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre, overflow: TextOverflow.ellipsis,
                style: _t(size: 12, weight: FontWeight.w600)),
            Text(cat.toUpperCase(),
                style: _t(size: 9, color: _muted2, letterSpacing: 0.5)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Text(stock,
              style: _t(size: 10, weight: FontWeight.w700, color: color)),
        ),
      ]),
    );

  Widget _verMasTxt(String label, Color color) => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 4),
    child: Text(label,
        style: _t(size: 10, weight: FontWeight.w600, color: color)),
  );

  Widget _topSellersCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Top Sellers',
            style: _t(size: 15, weight: FontWeight.w700))),
        Text('Ver reporte',
            style: _t(size: 12, weight: FontWeight.w600, color: _green)),
      ]),
      const SizedBox(height: 16),
      if (_cargandoInsights)
        const Center(child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2,
              color: Color(0xFF006C49)),
        ))
      else if (_topProductos.isEmpty)
        Text('Sin datos de ventas',
            style: _t(size: 13, color: _muted2))
      else
        ...List.generate(_topProductos.length, (i) {
          final item    = _topProductos[i];
          final nombre  = item['producto_nombre'] as String? ?? '—';
          final vendido = _toDouble(item['total_vendido']);
          final maxVend = _toDouble(_topProductos.first['total_vendido']);
          final pct     = maxVend > 0 ? vendido / maxVend : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: i == 0
                      ? const Color(0xFF131B2E)
                      : _surfHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(child: Text('${i + 1}',
                    style: _t(size: 11, weight: FontWeight.w700,
                        color: i == 0 ? Colors.white : _muted))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 13, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value:           pct.clamp(0.0, 1.0),
                          minHeight:       6,
                          backgroundColor: _surfHigh,
                          valueColor:      const AlwaysStoppedAnimation(
                              Color(0xFF006C49)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatNum(vendido),
                        style: _t(size: 11, weight: FontWeight.w700,
                            color: _muted)),
                  ]),
                ],
              )),
            ]),
          );
        }),
    ]),
  );

  Widget _movimientosCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Movimientos Recientes',
            style: _t(size: 15, weight: FontWeight.w700))),
        Icon(Icons.history_rounded, color: _muted2, size: 18),
      ]),
      const SizedBox(height: 16),
      if (_cargandoInsights)
        const Center(child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2,
              color: Color(0xFF006C49)),
        ))
      else if (_movimientos.isEmpty)
        Text('Sin movimientos recientes',
            style: _t(size: 13, color: _muted2))
      else
        ...List.generate(_movimientos.length, (i) {
          final mov      = _movimientos[i];
          final tipo     = mov['tipo'] as String? ?? '';
          final producto = mov['producto_nombre'] as String? ?? '—';
          final empleado = mov['empleado_nombre'] as String? ?? 'Sistema';
          final cantidad = _toDouble(mov['cantidad']);
          final fecha    = _tiempoRelativo(mov['created_at'] as String?);

          final (dotColor, dotBg, signo) = switch (tipo) {
            'entrada'       => (_green, _greenBg, '+'),
            'salida'        => (_danger, _dangerBg, '-'),
            'dano'          => (_danger, _dangerBg, '-'),
            'transferencia' => (const Color(0xFF3F465C),
                const Color(0xFFDAE2FD), '↔'),
            _               => (_muted, _surfHigh, '~'),
          };

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: dotBg, shape: BoxShape.circle),
                child: Center(child: Text(signo,
                    style: _t(size: 14, weight: FontWeight.w700,
                        color: dotColor))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 13, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${_tipoLabel(tipo)} · ${cantidad.toStringAsFixed(0)} uds',
                      style: _t(size: 11, color: _muted)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.person_outline_rounded,
                        size: 11, color: _muted2),
                    const SizedBox(width: 4),
                    Text(empleado,
                        style: _t(size: 11, color: _muted2)),
                    const SizedBox(width: 6),
                    Text(fecha,
                        style: _t(size: 11, color: _muted2)),
                  ]),
                ],
              )),
            ]),
          );
        }),
    ]),
  );

  String _tipoLabel(String tipo) => switch (tipo) {
    'entrada'       => 'Entrada',
    'salida'        => 'Salida',
    'ajuste'        => 'Ajuste',
    'transferencia' => 'Transferencia',
    'dano'          => 'Daño/Pérdida',
    _               => tipo,
  };

  // ══════════════════════════════════════════════════════
  // STATES
  // ══════════════════════════════════════════════════════
  Widget _loadingState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(
                color: Color(0xFF006C49), strokeWidth: 2.5),
          ),
        ),
        const SizedBox(height: 14),
        Text('Cargando inventario…',
            style: _t(size: 13, weight: FontWeight.w600, color: _muted)),
      ],
    ),
  );

  Widget _emptyState(bool esCajero) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _surfHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 34, color: _muted2),
          ),
          const SizedBox(height: 16),
          Text(
            _activoFiltro == 'false'
                ? 'No hay productos inactivos'
                : 'No hay productos registrados',
            style: _t(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _activoFiltro == 'false'
                ? 'Todo tu inventario está activo.'
                : 'Agrega el primero con "Nuevo producto".',
            textAlign: TextAlign.center,
            style: _t(size: 13, color: _muted),
          ),
        ],
      ),
    ),
  );

  Widget _banner(String msg,
      {required bool isError, required VoidCallback onClose}) {
    final color = isError ? _danger : _green;
    final bg    = isError ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: color, size: 17),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: _t(size: 13, weight: FontWeight.w600, color: color))),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close_rounded,
                size: 14, color: color.withValues(alpha: 0.7)),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUTTONS
  // ══════════════════════════════════════════════════════
  Widget _btnPrimario({
    required IconData     icon,
    required String       label,
    required VoidCallback onTap,
  }) =>
      ElevatedButton.icon(
        onPressed: onTap,
        icon:  Icon(icon, size: 17),
        label: Text(label,
            style: _t(size: 13, weight: FontWeight.w700, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          elevation:       0,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _btnSecundario({
    required IconData      icon,
    required String        label,
    required VoidCallback? onTap,
  }) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon:  Icon(icon, size: 17),
        label: Text(label,
            style: _t(size: 13, weight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          elevation:       0,
          foregroundColor: _text,
          backgroundColor: _surface,
          side: const BorderSide(color: Color(0xFFC6C6CD)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _actionBtn({
    required IconData     icon,
    required Color        color,
    required String       tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color:         color.withValues(alpha: 0.08),
              borderRadius:  BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
// KARDEX SHEET
// ═══════════════════════════════════════════════════════════════
class _KardexSheet extends StatefulWidget {
  final Producto          producto;
  final int               tiendaId;
  final InventarioService service;

  const _KardexSheet({
    required this.producto,
    required this.tiendaId,
    required this.service,
  });

  @override
  State<_KardexSheet> createState() => _KardexSheetState();
}

class _KardexSheetState extends State<_KardexSheet> {
  List<Map<String, dynamic>> _movimientos = [];
  bool   _cargando = true;
  String _error    = '';

  static const _bg      = Color(0xFFF7F9FB);
  static const _surface = Colors.white;
  static const _border  = Color(0xFFE2E8F0);
  static const _text    = Color(0xFF1E293B);
  static const _muted   = Color(0xFF64748B);
  static const _muted2  = Color(0xFF94A3B8);
  static const _green   = Color(0xFF006C49);
  static const _greenBg = Color(0xFFDCFCE7);
  static const _danger  = Color(0xFFBA1A1A);
  static const _amber   = Color(0xFFF59E0B);
  static const _blue    = Color(0xFF0284C7);
  static const _blueBg  = Color(0xFFE0F2FE);

  static final _fmt     = NumberFormat('#,##0.##', 'es_CO');
  static final _fmtDate = DateFormat('d MMM yyyy · HH:mm', 'es');

  TextStyle _t({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight,
          color: color ?? _text);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = ''; });
    final res = await widget.service.getMovimientosProducto(
      productoId: widget.producto.id,
      tiendaId:   widget.tiendaId,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _movimientos = (res['data'] as List).cast<Map<String, dynamic>>();
        _cargando    = false;
      });
    } else {
      setState(() {
        _error    = res['error'] ?? 'Error al cargar movimientos';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.80;

    return Container(
      height:      h,
      decoration:  const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.timeline_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kardex',
                    style: _t(size: 16, weight: FontWeight.w700)),
                Text(widget.producto.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: _t(size: 12, color: _muted)),
              ],
            )),
            GestureDetector(
              onTap: _cargar,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 16, color: _muted),
              ),
            ),
          ]),
        ),

        const Divider(height: 1, color: Color(0xFFEBEFF3)),

        // Contenido
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(
          color: Color(0xFF006C49), strokeWidth: 2));
    }
    if (_error.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _danger, size: 32),
          const SizedBox(height: 12),
          Text(_error, style: _t(size: 13, color: _muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: _cargar,
              child: Text('Reintentar', style: _t(size: 13, color: _green))),
        ]),
      ));
    }
    if (_movimientos.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.timeline_rounded,
                size: 28, color: _muted2),
          ),
          const SizedBox(height: 16),
          Text('Sin movimientos registrados',
              style: _t(size: 14, weight: FontWeight.w600, color: _muted)),
          const SizedBox(height: 6),
          Text('Los movimientos de este producto\naparecerán aquí.',
              textAlign: TextAlign.center,
              style: _t(size: 12, color: _muted2)),
        ],
      ));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount:      _movimientos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder:   (_, i) => _movCard(_movimientos[i]),
    );
  }

  Widget _movCard(Map<String, dynamic> m) {
    final tipo       = m['tipo'] as String? ?? '';
    final cantidad   = _toDouble(m['cantidad']);
    final empleado   = m['empleado_nombre'] as String?;
    final refTipo    = m['referencia_tipo'] as String?;
    final obs        = m['observacion'] as String?;
    final createdAt  = m['created_at'] as String?;
    DateTime? dt;
    try { dt = createdAt != null ? DateTime.parse(createdAt).toLocal() : null; } catch (_) {}

    final (icon, color, bg, label, signo) = _tipoConfig(tipo);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: bg,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label,
                    style: _t(size: 9, weight: FontWeight.w800,
                        color: color)),
              ),
              const Spacer(),
              Text('$signo${_fmt.format(cantidad)} uds',
                  style: _t(size: 14, weight: FontWeight.w800, color: color)),
            ]),
            if (dt != null) ...[
              const SizedBox(height: 4),
              Text(_fmtDate.format(dt),
                  style: _t(size: 11, color: _muted2)),
            ],
            if (empleado != null || refTipo != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                if (empleado != null) ...[
                  const Icon(Icons.person_outline_rounded,
                      size: 11, color: _muted2),
                  const SizedBox(width: 4),
                  Flexible(child: Text(empleado,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 11, color: _muted))),
                ],
                if (refTipo != null) ...[
                  if (empleado != null) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_labelRef(refTipo),
                        style: _t(size: 9, color: _muted2,
                            weight: FontWeight.w600)),
                  ),
                ],
              ]),
            ],
            if (obs != null && obs.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(obs,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: _t(size: 11, color: _muted2,
                      weight: FontWeight.w400)),
            ],
          ],
        )),
      ]),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  (IconData, Color, Color, String, String) _tipoConfig(String tipo) {
    return switch (tipo) {
      'entrada'       => (Icons.add_circle_rounded,     _green,  _greenBg,
                          'ENTRADA',     '+'),
      'salida'        => (Icons.remove_circle_rounded,  _danger,
                          const Color(0xFFFFDAD6),      'SALIDA',      '-'),
      'ajuste'        => (Icons.tune_rounded,           _amber,
                          const Color(0xFFFEF3C7),      'AJUSTE',      ''),
      'transferencia' => (Icons.swap_horiz_rounded,     _blue,   _blueBg,
                          'TRANSFERENCIA', ''),
      'daño'          => (Icons.broken_image_rounded,   _danger,
                          const Color(0xFFFFDAD6),      'DAÑO',        '-'),
      _               => (Icons.circle_outlined,        _muted,
                          const Color(0xFFF1F5F9),      tipo.toUpperCase(), ''),
    };
  }

  String _labelRef(String ref) {
    return switch (ref) {
      'venta'           => 'Venta',
      'compra'          => 'Compra',
      'devolucion'      => 'Devolución',
      'ajuste_manual'   => 'Ajuste',
      'transferencia'   => 'Transferencia',
      'separado'        => 'Separado',
      _                 => ref,
    };
  }
}


// ── Modal de Transferencia ─────────────────────────────────────
class _TransferenciaSheet extends StatefulWidget {
  final Producto               producto;
  final int                    tiendaOrigenId;
  final List<Map<String, dynamic>> tiendas;
  final VoidCallback           onTransferida;

  const _TransferenciaSheet({
    required this.producto,
    required this.tiendaOrigenId,
    required this.tiendas,
    required this.onTransferida,
  });

  @override
  State<_TransferenciaSheet> createState() => _TransferenciaSheetState();
}

class _TransferenciaSheetState extends State<_TransferenciaSheet> {
  final _cantCtrl = TextEditingController();
  final _obsCtrl  = TextEditingController();
  int?   _tiendaDestinoId;
  bool   _enviando = false;
  String _error    = '';

  static const _green    = Color(0xFF16A34A);
  static const _greenDk  = Color(0xFF15803D);
  static const _surface  = Color(0xFFF8FAFC);
  static const _border   = Color(0xFFE2E8F0);
  static const _text     = Color(0xFF1E293B);
  static const _muted    = Color(0xFF64748B);
  static const _red      = Color(0xFFDC2626);

  @override
  void dispose() {
    _cantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _tiendasDestino =>
      widget.tiendas.where((t) => t['id'] != widget.tiendaOrigenId).toList();

  String _nombreTienda(int id) =>
      widget.tiendas.firstWhere(
          (t) => t['id'] == id,
          orElse: () => {'nombre': 'Tienda $id'})['nombre'] as String;

  Future<void> _enviar() async {
    final cant = double.tryParse(_cantCtrl.text) ?? 0;
    if (cant <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor a cero.');
      return;
    }
    if (_tiendaDestinoId == null) {
      setState(() => _error = 'Selecciona la tienda de destino.');
      return;
    }
    setState(() { _enviando = true; _error = ''; });
    try {
      await ApiClient.instance.post('/productos/transferencias/', data: {
        'producto_id':       widget.producto.id,
        'tienda_origen_id':  widget.tiendaOrigenId,
        'tienda_destino_id': _tiendaDestinoId,
        'cantidad':          cant,
        'observacion':       _obsCtrl.text.trim(),
      });
      widget.onTransferida();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${cant.toStringAsFixed(cant % 1 == 0 ? 0 : 1)} u. de "${widget.producto.nombre}" '
            'transferidas a ${_nombreTienda(_tiendaDestinoId!)}.',
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      final msg = (e is Exception) ? e.toString() : 'Error al transferir.';
      setState(() {
        _error    = msg.replaceAll('Exception: ', '');
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinos = _tiendasDestino;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: _border, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // Título
        Row(children: [
          const Icon(Icons.swap_horiz_rounded, color: _green, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Transferir ${widget.producto.nombre}',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: _text),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
        const SizedBox(height: 4),
        Text(
          'Origen: ${_nombreTienda(widget.tiendaOrigenId)}',
          style: GoogleFonts.inter(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 16),

        // Tienda destino
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
            color: _surface,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _tiendaDestinoId,
              isExpanded: true,
              hint: Text('Tienda de destino',
                  style: GoogleFonts.inter(fontSize: 13, color: _muted)),
              items: destinos.map((t) => DropdownMenuItem<int>(
                value: t['id'] as int,
                child: Text(t['nombre'] as String,
                    style: GoogleFonts.inter(fontSize: 13, color: _text)),
              )).toList(),
              onChanged: (v) => setState(() => _tiendaDestinoId = v),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Cantidad
        TextField(
          controller: _cantCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(fontSize: 14, color: _text),
          decoration: InputDecoration(
            labelText: 'Cantidad a transferir',
            labelStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
            filled: true, fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 2)),
          ),
        ),
        const SizedBox(height: 12),

        // Observación
        TextField(
          controller: _obsCtrl,
          style: GoogleFonts.inter(fontSize: 13, color: _text),
          decoration: InputDecoration(
            labelText: 'Observación (opcional)',
            labelStyle: GoogleFonts.inter(fontSize: 12, color: _muted),
            filled: true, fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 2)),
          ),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withAlpha(80)),
            ),
            child: Text(_error,
                style: GoogleFonts.inter(fontSize: 12, color: _red)),
          ),
        ],
        const SizedBox(height: 16),

        // Botones
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: _enviando ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text('Cancelar',
                style: GoogleFonts.inter(fontSize: 13, color: _muted)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _enviando ? null : _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _greenDk,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _enviando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Transferir',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: Colors.white)),
          )),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AJUSTE DE STOCK SHEET
// ═══════════════════════════════════════════════════════════════

class _AjusteStockSheet extends StatefulWidget {
  final Producto     producto;
  final int          tiendaId;
  final VoidCallback onAjustado;

  const _AjusteStockSheet({
    required this.producto,
    required this.tiendaId,
    required this.onAjustado,
  });

  @override
  State<_AjusteStockSheet> createState() => _AjusteStockSheetState();
}

class _AjusteStockSheetState extends State<_AjusteStockSheet> {
  final _cantCtrl = TextEditingController();
  final _obsCtrl  = TextEditingController();
  final _service  = InventarioService();

  String _tipo     = 'entrada'; // 'entrada' | 'salida' | 'ajuste'
  bool   _enviando = false;
  String _error    = '';

  static const _greenDk = Color(0xFF15803D);
  static const _surface = Color(0xFFF8FAFC);
  static const _border  = Color(0xFFE2E8F0);
  static const _text    = Color(0xFF1E293B);
  static const _muted   = Color(0xFF64748B);
  static const _red     = Color(0xFFDC2626);
  static const _indigo  = Color(0xFF3730A3);

  @override
  void dispose() {
    _cantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  // Accent color según el tipo de ajuste
  Color get _accentColor => switch (_tipo) {
    'entrada' => _greenDk,
    'salida'  => _red,
    'ajuste'  => _indigo,
    _         => _greenDk,
  };

  Future<void> _enviar() async {
    final cant = double.tryParse(_cantCtrl.text.trim()) ?? 0;
    if (cant <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor a cero.');
      return;
    }
    setState(() { _enviando = true; _error = ''; });
    try {
      final result = await _service.ajustarStock(
        productoId:  widget.producto.id,
        tiendaId:    widget.tiendaId,
        cantidad:    cant,
        tipo:        _tipo,
        observacion: _obsCtrl.text.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final nuevoStock = result['data']?['stock_actual'] ?? '—';
        widget.onAjustado();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Stock ajustado · ${widget.producto.nombre} → $nuevoStock u.',
          ),
          backgroundColor: _greenDk,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      } else {
        setState(() {
          _error   = result['error'] ?? 'Error al ajustar stock.';
          _enviando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error    = e.toString().replaceAll('Exception: ', '');
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final stockActual = widget.producto.stockActual;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: _border, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // Título + stock actual
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.tune_rounded, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ajustar stock',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
            Text(widget.producto.nombre,
              style: GoogleFonts.inter(fontSize: 12, color: _muted),
              overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Stock actual',
                style: GoogleFonts.inter(fontSize: 9, color: _muted,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              Text('${stockActual.toStringAsFixed(stockActual % 1 == 0 ? 0 : 1)} u.',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800,
                    color: stockActual <= 0 ? _red : _text)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        // Selector de tipo
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            _tipoBtn('entrada', 'Entrada',  Icons.add_circle_outline_rounded,  _greenDk),
            _tipoBtn('salida',  'Salida',   Icons.remove_circle_outline_rounded, _red),
            _tipoBtn('ajuste',  'Ajuste',   Icons.swap_vert_rounded,             _indigo),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          switch (_tipo) {
            'entrada' => 'Suma unidades al stock actual',
            'salida'  => 'Resta unidades del stock actual',
            'ajuste'  => 'Reemplaza el stock con el valor exacto',
            _         => '',
          },
          style: GoogleFonts.inter(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 16),

        // Campo cantidad
        TextField(
          controller: _cantCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _tipo == 'ajuste' ? 'Nuevo stock total' : 'Cantidad',
            labelStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
            prefixIcon: Icon(
              _tipo == 'entrada'
                ? Icons.add_rounded
                : _tipo == 'salida' ? Icons.remove_rounded : Icons.sync_rounded,
              size: 18, color: accent),
            suffixText: 'u.',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.5)),
          ),
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          autofocus: true,
        ),
        const SizedBox(height: 10),

        // Campo observación
        TextField(
          controller: _obsCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Motivo / observación (opcional)',
            labelStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
            prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.5)),
          ),
          style: GoogleFonts.inter(fontSize: 13),
        ),
        const SizedBox(height: 10),

        // Error
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDAD6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 15, color: _red),
              const SizedBox(width: 8),
              Expanded(child: Text(_error,
                  style: GoogleFonts.inter(fontSize: 12, color: _red))),
            ]),
          ),

        // Botones
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cancelar',
                style: GoogleFonts.inter(fontSize: 13, color: _muted)),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: _enviando ? null : _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _enviando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('Confirmar ajuste',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700)),
          )),
        ]),
      ]),
    );
  }

  Widget _tipoBtn(String value, String label, IconData icon, Color color) {
    final active = _tipo == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _tipo = value; _error = ''; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: active ? Border.all(color: color.withValues(alpha: 0.4)) : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: active ? color : _muted),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: active ? color : _muted)),
          ]),
        ),
      ),
    );
  }
}
