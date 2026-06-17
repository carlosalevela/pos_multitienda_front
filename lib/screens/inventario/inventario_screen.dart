// lib/screens/inventario/inventario_screen.dart

import 'package:flutter/material.dart';
import '../../utils/file_downloader.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/inventario_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../models/producto.dart';
import '../../services/empleado_service.dart';
import '../../services/inventario_service.dart';
import 'widgets/producto_form_dialog.dart';
import 'widgets/importar_excel_dialog.dart';

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
  List<Map<String, dynamic>> _topProductos = [];
  List<Map<String, dynamic>> _movimientos  = [];
  bool                       _cargandoInsights = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

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
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
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
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard    = results[0]['data'] as Map<String, dynamic>?;
        _topProductos = (results[1]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _movimientos  = (results[2]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _cargandoInsights = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoInsights = false);
    }
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
    final esCajero = auth.rol == 'cajero';
    final esAdmin  = auth.rol == 'admin' || auth.rol == 'superadmin';

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
              _buildKPIGrid(inv.productos),
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
                    // ── Panel insights ───────────────────
                    if (esAdmin) ...[
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 280,
                        child: _buildInsightsPanel(),
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
            onTap: () => _abrirImportarExcel(inv),
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
  Widget _buildKPIGrid(List<Producto> productos) {
    final d          = _dashboard;
    final valorTotal = d != null
        ? _toDouble(d['total_valor_inventario'])
        : productos.fold<double>(0, (s, p) => s + p.precio * p.stockActual);
    final alertasBajo = d != null
        ? _toInt(d['alertas_stock_bajo'])
        : productos.where((p) => p.stockActual > 0 && p.stockActual <= p.stockMinimo).length;
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
      Expanded(flex: 2, child: _th('Estado')),
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
    final bajo       = !agotado && p.stockActual <= p.stockMinimo;
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
                      : Container(
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
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 12),
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: estadoColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(estadoText,
                      style: _t(size: 12, weight: FontWeight.w600,
                          color: estadoColor)),
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
    return SingleChildScrollView(
      child: Column(children: [
        _topSellersCard(),
        const SizedBox(height: 14),
        _movimientosCard(),
      ]),
    );
  }

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
          final nombre  = item['producto'] as String? ?? '—';
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
