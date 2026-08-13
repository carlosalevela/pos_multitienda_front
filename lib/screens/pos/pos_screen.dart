// lib/screens/pos/pos_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/pos_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cliente_provider.dart';
import '../../models/producto.dart';
import '../../models/item_carrito.dart';
import '../../models/cliente.dart';
import '../../services/inventario_service.dart';
import '../../services/cliente_service.dart';
import '../clientes/widgets/separado_form.dart';
import '../../providers/notificaciones_provider.dart';
import '../../services/recibo_pdf_service.dart';
import '../../services/cotizacion_pdf_service.dart';
import '../../services/thermal_printer_service.dart';
import '../../services/windows_printer_service.dart';
import '../../providers/config_provider.dart';
import '../../services/barcode_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../devoluciones/widgets/devolucion_form_sheet.dart';

// ── Design system (Material You / Enterprise POS) ─────────
const _kGreen          = Color(0xFF61DDAA);   // mint — igual que dashboard _C.green
const _kGreenDark      = Color(0xFF0B7A53);   // verde oscuro — igual que _C.greenDark
const _kGreenLight     = Color(0xFFE8FFF4);   // fondo verde suave
const _kSurface        = Color(0xFFF7F9FB);
const _kCard           = Colors.white;
const _kSurfaceLow     = Color(0xFFF2F4F6);
const _kSurfaceMid     = Color(0xFFECEEF0);
const _kSurfaceHigh    = Color(0xFFE6E8EA);
const _kBorder         = Color(0xFFC6C6CD);
const _kText           = Color(0xFF191C1E);
const _kTextSub        = Color(0xFF45464D);
const _kTextMuted      = Color(0xFF76777D);
const _kError          = Color(0xFFBA1A1A);
const _kErrorBg        = Color(0xFFFFDAD6);
const _kAmber          = Color(0xFFF59E0B);

enum _ViewMode { gridLarge, gridMedium, gridSmall, list }

class PosScreen extends StatefulWidget {
  final void Function(String screen)? onNavigate;
  const PosScreen({super.key, this.onNavigate});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl        = TextEditingController();
  final _montoCtrl         = TextEditingController();
  final _descuentoCtrl     = TextEditingController();

  // Categories
  List<Map<String, dynamic>> _categorias   = [];
  int?                       _catId;
  bool                       _cargandoCats = false;

  // Client
  Cliente?  _clienteSeleccionado;
  int       _separadosCliente  = 0;
  DateTime? _fechaLimite;

  // Alerts
  int _countStockBajo = 0;
  NotificacionesProvider? _notifProv;

  // View mode
  _ViewMode _viewMode = _ViewMode.gridMedium;

  // Notification dropdown
  final _notifLink = LayerLink();
  OverlayEntry? _notifOverlay;

  Timer? _debounceSearch;
  StreamSubscription<String>? _barcodeSub;

  // Barcode scanner pulse indicator
  bool   _scanActivo      = false;
  Timer? _scanPulseTimer;

  @override
  void initState() {
    super.initState();
    _barcodeSub = BarcodeService.instance.onBarcode.listen(_onBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifProv = context.read<NotificacionesProvider>()..iniciarPolling();
      _cargarAlertas();
      _cargarCategorias();
      _cargarTodos();
      context.read<PosProvider>().cargarTicketsGuardados();
    });
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _scanPulseTimer?.cancel();
    _notifProv?.detenerPolling();
    _searchCtrl.dispose();
    _montoCtrl.dispose();
    _descuentoCtrl.dispose();
    _debounceSearch?.cancel();
    _notifOverlay?.remove();
    super.dispose();
  }

  // ── Carga inicial ────────────────────────────────────────

  Future<void> _cargarAlertas() async {
    final tid = context.read<AuthProvider>().tiendaId;
    final tidOpt = tid > 0 ? tid : null;
    try {
      final r = await InventarioService().getInventario(tiendaId: tidOpt, alerta: 'bajo');
      if (mounted && r['success'] == true) {
        setState(() => _countStockBajo = (r['data'] as List).length);
      }
    } catch (_) {}
  }

  Future<void> _cargarCategorias() async {
    setState(() => _cargandoCats = true);
    final tid = context.read<AuthProvider>().tiendaId;
    // Carga todos los productos de la tienda para extraer categorías reales
    final r = await InventarioService().getProductos(
      tiendaId: tid > 0 ? tid : null,
    );
    if (mounted) {
      setState(() {
        _cargandoCats = false;
        if (r['success'] == true) {
          final productos = r['data'] as List<Producto>;
          final seen = <int?>{};
          final cats = <Map<String, dynamic>>[];
          for (final p in productos) {
            if (p.categoriaId != null && !seen.contains(p.categoriaId)) {
              seen.add(p.categoriaId);
              cats.add({'id': p.categoriaId, 'nombre': p.categoria});
            }
          }
          cats.sort((a, b) =>
              (a['nombre'] as String).compareTo(b['nombre'] as String));
          _categorias = cats;
        }
      });
    }
  }

  Future<void> _cargarTodos() async {
    final tid = context.read<AuthProvider>().tiendaId;
    context.read<PosProvider>().cargarProductos(
      tiendaId:    tid > 0 ? tid : null,
      categoriaId: _catId,
    );
  }

  Future<void> _seleccionarCategoria(int? catId) async {
    setState(() => _catId = catId);
    _searchCtrl.clear();
    final tid = context.read<AuthProvider>().tiendaId;
    context.read<PosProvider>().cargarProductos(
      tiendaId:    tid > 0 ? tid : null,
      categoriaId: catId,
    );
  }

  Future<void> _cargarClienteResumen(int clienteId) async {
    final resumen = await ClienteService().getClienteResumen(clienteId);
    if (!mounted) return;
    setState(() => _separadosCliente = (resumen['separados_activos'] as int?) ?? 0);

    // Aplicar descuento del tier si el cliente lo tiene y el carrito ya tiene items
    final pct = _clienteSeleccionado?.tierInfo?.descuentoPct ?? 0;
    if (pct > 0) {
      final pos = context.read<PosProvider>();
      if (pos.total > 0) {
        pos.setDescuentoPorcentaje(pct.round());
        _descuentoCtrl.text = pos.descuento.toStringAsFixed(0);
      }
      // Si el carrito está vacío, el descuento se aplicará en _aplicarDescuentoTierSiNecesario
      // cuando se agregue el primer producto.
    }
  }

  // Aplica el descuento del tier del cliente seleccionado al agregar un producto,
  // sólo si aún no hay descuento manual activo.
  void _aplicarDescuentoTierSiNecesario() {
    final pct = _clienteSeleccionado?.tierInfo?.descuentoPct ?? 0;
    if (pct <= 0) return;
    final pos = context.read<PosProvider>();
    if (pos.descuento == 0 && pos.total > 0) {
      pos.setDescuentoPorcentaje(pct.round());
      _descuentoCtrl.text = pos.descuento.toStringAsFixed(0);
    }
  }

  // ── Lector de código de barras ───────────────────────────

  void _pulsarEscaner() {
    setState(() => _scanActivo = true);
    _scanPulseTimer?.cancel();
    _scanPulseTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scanActivo = false);
    });
  }

  Future<void> _onBarcode(String codigo) async {
    if (!mounted) return;
    // Ignorar si hay un modal/diálogo encima (ej: buscador, separado form)
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _pulsarEscaner();

    final auth    = context.read<AuthProvider>();
    final tiendaId = auth.tiendaId > 0 ? auth.tiendaId : null;

    final result   = await InventarioService().buscarProductoPos(
      q: codigo, tiendaId: tiendaId,
    );
    if (!mounted) return;

    final productos = result['data'] as List<Producto>;

    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Código no encontrado: $codigo'),
        backgroundColor: _kError,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    if (productos.length == 1) {
      final p = productos.first;
      if (p.stockActual <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${p.nombre}: sin stock disponible'),
          backgroundColor: _kAmber,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
        return;
      }
      context.read<PosProvider>().agregarAlCarrito(p);
      _aplicarDescuentoTierSiNecesario();
      HapticFeedback.lightImpact();
      return;
    }

    // Múltiples resultados → mostrar en el catálogo via búsqueda
    _searchCtrl.text = codigo;
    context.read<PosProvider>().buscarProductos(codigo, tiendaId ?? 0);
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final pos   = context.watch<PosProvider>();
    final auth  = context.watch<AuthProvider>();
    final notif = context.watch<NotificacionesProvider>();

    return Container(
      color: _kSurface,
      child: Column(children: [

        // Contenido principal
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Panel izquierdo: catálogo ──────────────────
            Expanded(
              child: Column(children: [
                _buildSearchBar(pos, auth, notif),
                _buildCategoryTabs(),
                Expanded(child: _buildProductGrid(pos, auth)),
              ]),
            ),

            // ── Panel derecho: ticket ──────────────────────
            SizedBox(
              width: min(420, MediaQuery.of(context).size.width * 0.34),
              child: _buildTicketPanel(pos, auth),
            ),
          ]),
        ),
      ]),
    );
  }

  void _toggleNotifMenu(BuildContext context) {
    if (_notifOverlay != null) {
      _closeNotifMenu();
      return;
    }
    final overlay = Overlay.of(context);
    _notifOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Tap fuera para cerrar
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeNotifMenu,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.shrink(),
            ),
          ),
          CompositedTransformFollower(
            link: _notifLink,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 6),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black26,
              child: _notifDropdown(),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_notifOverlay!);
    setState(() {});
  }

  void _closeNotifMenu() {
    _notifOverlay?.remove();
    _notifOverlay = null;
    setState(() {});
  }

  Widget _notifDropdown() {
    final vencidos  = _notifProv?.vencidos  ?? [];
    final porVencer = _notifProv?.porVencer ?? [];
    final totalSep  = _notifProv?.totalAlertas ?? 0;
    final total     = _countStockBajo + totalSep;
    final hayAlertas = total > 0;

    return Container(
      width: 310,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded, size: 15, color: _kGreenDark),
                  const SizedBox(width: 6),
                  const Text('Notificaciones',
                      style: TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (hayAlertas)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: _kErrorBg, borderRadius: BorderRadius.circular(20)),
                      child: Text('$total',
                          style: const TextStyle(
                              color: _kError, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),

            if (!hayAlertas)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 16, color: _kGreenDark),
                    SizedBox(width: 6),
                    Text('Sin alertas pendientes',
                        style: TextStyle(color: _kTextMuted, fontSize: 12)),
                  ],
                ),
              ),

            // Stock bajo
            if (_countStockBajo > 0)
              _notifRow(
                icon: Icons.inventory_2_outlined,
                color: _kError,
                title: 'Stock bajo',
                subtitle: '$_countStockBajo producto${_countStockBajo > 1 ? 's' : ''} requieren reposición',
                onTap: () { _closeNotifMenu(); widget.onNavigate?.call('inventario'); },
              ),

            // Separados vencidos
            if (vencidos.isNotEmpty) ...[
              if (_countStockBajo > 0) const Divider(height: 1, color: _kBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                child: Text('VENCIDOS',
                    style: const TextStyle(
                        color: _kError, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
              ...vencidos.take(3).map((v) => _notifRow(
                icon: Icons.bookmark_outlined,
                color: _kError,
                title: v['cliente']?.toString() ?? '—',
                subtitle: 'Hace ${(v['dias_restantes'] as num).abs().toInt()} día(s) · \$${v['saldo_pendiente']}',
                onTap: () { _closeNotifMenu(); widget.onNavigate?.call('clientes'); },
              )),
            ],

            // Por vencer
            if (porVencer.isNotEmpty) ...[
              if (vencidos.isNotEmpty || _countStockBajo > 0)
                const Divider(height: 1, color: _kBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                child: Text('POR VENCER',
                    style: const TextStyle(
                        color: _kAmber, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
              ...porVencer.take(3).map((v) => _notifRow(
                icon: Icons.bookmark_add_outlined,
                color: _kAmber,
                title: v['cliente']?.toString() ?? '—',
                subtitle: 'En ${(v['dias_restantes'] as num).toInt()} día(s) · \$${v['saldo_pendiente']}',
                onTap: () { _closeNotifMenu(); widget.onNavigate?.call('clientes'); },
              )),
            ],

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _notifRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) =>
    InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _kText, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: _kTextMuted, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: _kTextMuted),
        ]),
      ),
    );

  // ══════════════════════════════════════════════════════════
  // BARRA DE BÚSQUEDA
  // ══════════════════════════════════════════════════════════

  Widget _buildSearchBar(PosProvider pos, AuthProvider auth, NotificacionesProvider notif) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
    color: _kCard,
    child: Row(children: [
      // Search field
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: _kSurfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 14, color: _kText),
            decoration: InputDecoration(
              hintText: 'Buscar productos por nombre o código de barras…',
              hintStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _kGreenDark, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 17, color: _kTextMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                        _cargarTodos();
                      })
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) {
              setState(() {});
              _debounceSearch?.cancel();
              _debounceSearch = Timer(const Duration(milliseconds: 300), () {
                final tid = auth.tiendaId;
                if (v.isEmpty) {
                  _cargarTodos();
                } else {
                  pos.cargarProductos(q: v, tiendaId: tid > 0 ? tid : null);
                }
              });
            },
          ),
        ),
      ),

      const SizedBox(width: 10),

      // Nuevo ticket
      _headerBtn(
        icon: Icons.add_rounded,
        label: 'Nuevo ticket',
        color: _kGreenDark,
        onTap: () {
          final ok = pos.parquearTicket();
          if (!ok) _showSnack('El carrito está vacío', _kAmber);
        },
      ),

      const SizedBox(width: 8),

      // Indicador lector de código de barras
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color:        _scanActivo ? _kGreenLight : _kSurfaceLow,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
            color: _scanActivo ? _kGreen : _kBorder,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 16,
            color: _scanActivo ? _kGreenDark : _kTextMuted,
          ),
          if (_scanActivo) ...[
            const SizedBox(width: 5),
            Text('OK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kGreenDark,
                )),
          ],
        ]),
      ),

      const SizedBox(width: 8),

      // Campana de notificaciones
      CompositedTransformTarget(
        link: _notifLink,
        child: GestureDetector(
          onTap: () => _toggleNotifMenu(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _notifOverlay != null ? _kGreenLight : _kSurfaceLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _notifOverlay != null ? _kGreen : _kBorder,
                  ),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 18,
                  color: _notifOverlay != null ? _kGreenDark : _kTextMuted,
                ),
              ),
              if (_countStockBajo + notif.totalAlertas > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: _kError,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (_countStockBajo + notif.totalAlertas) > 9
                            ? '9+'
                            : '${_countStockBajo + notif.totalAlertas}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ]),
  );

  Widget _headerBtn({
    required IconData     icon,
    required String       label,
    required Color        color,
    required VoidCallback onTap,
    int badge = 0,
  }) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          if (badge > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Text('$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      ),
    );

  // ══════════════════════════════════════════════════════════
  // FILTROS DE CATEGORÍA
  // ══════════════════════════════════════════════════════════

  Widget _buildCategoryTabs() => Container(
    color: _kCard,
    height: 42,
    child: Row(children: [
      // Chips de categoría (scrollable)
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          child: Row(children: [
            _catChip(null, 'Todo'),
            if (_cargandoCats)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen)),
              )
            else
              ..._categorias.map((c) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _catChip(c['id'] as int, c['nombre'] as String),
              )),
          ]),
        ),
      ),
      // Toggle de vista
      Container(
        margin: const EdgeInsets.only(right: 12, bottom: 6),
        decoration: BoxDecoration(
          color: _kSurfaceLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _viewBtn(_ViewMode.gridLarge,  Icons.grid_view_rounded,       'Grande'),
          _viewBtn(_ViewMode.gridMedium, Icons.apps_rounded,            'Mediano'),
          _viewBtn(_ViewMode.gridSmall,  Icons.grid_on_rounded,         'Pequeño'),
          _viewBtn(_ViewMode.list,       Icons.view_list_rounded,       'Lista'),
        ]),
      ),
    ]),
  );

  Widget _viewBtn(_ViewMode mode, IconData icon, String tooltip) {
    final active = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? _kGreenDark : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15,
              color: active ? Colors.white : _kTextMuted),
        ),
      ),
    );
  }

  Widget _catChip(int? id, String label) {
    final selected = _catId == id;
    return GestureDetector(
      onTap: () => _seleccionarCategoria(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _kGreen : _kSurfaceLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kGreen : _kBorder),
        ),
        child: Text(label, style: GoogleFonts.inter(
          color: selected ? _kGreenDark : _kTextSub,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0.2,
        )),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // GRID DE PRODUCTOS
  // ══════════════════════════════════════════════════════════

  Widget _buildProductGrid(PosProvider pos, AuthProvider auth) {
    if (pos.buscando) {
      return const Center(child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2.5));
    }
    if (pos.resultados.isEmpty) {
      return _emptyState(
        icon: _searchCtrl.text.isNotEmpty ? Icons.search_off_rounded : Icons.inventory_2_outlined,
        title: _searchCtrl.text.isNotEmpty ? 'Sin resultados' : 'Sin productos',
        sub: _searchCtrl.text.isNotEmpty
            ? 'No encontramos "${_searchCtrl.text}"'
            : 'No hay productos disponibles en esta categoría',
      );
    }
    if (_viewMode == _ViewMode.list) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        itemCount: pos.resultados.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildProductCardList(pos.resultados[i], pos),
      );
    }

    final (cols, ratio) = switch (_viewMode) {
      _ViewMode.gridLarge  => (2, 0.72),
      _ViewMode.gridMedium => (3, 0.82),
      _ViewMode.gridSmall  => (5, 0.88),
      _ViewMode.list       => (3, 0.82),
    };

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   cols,
        crossAxisSpacing: 10,
        mainAxisSpacing:  10,
        childAspectRatio: ratio,
      ),
      itemCount: pos.resultados.length,
      itemBuilder: (_, i) => _buildProductCard(pos.resultados[i], pos),
    );
  }

  Widget _buildProductCard(Producto p, PosProvider pos) {
    final sinStock = p.stockActual <= 0;
    final stockBajo = !sinStock && p.stockActual <= p.stockMinimo && p.stockMinimo > 0;

    return GestureDetector(
      onTap: sinStock ? null : () {
        pos.agregarAlCarrito(p);
        _aplicarDescuentoTierSiNecesario();
        HapticFeedback.lightImpact();
      },
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Imagen ────────────────────────────────────
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              // Fondo / imagen
              Container(
                color: sinStock ? _kSurfaceHigh : _kSurfaceLow,
                child: p.imagen != null && p.imagen!.isNotEmpty
                    ? Image.network(
                        p.imagen!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, err, st) => _iconProducto(sinStock, p.categoria),
                      )
                    : _iconProducto(sinStock, p.categoria),
              ),

              // Overlay sin stock
              if (sinStock)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _kError, borderRadius: BorderRadius.circular(6)),
                    child: const Text('AGOTADO',
                        style: TextStyle(color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ),

              // Badge stock bajo
              if (stockBajo)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: _kAmber, borderRadius: BorderRadius.circular(5)),
                    child: Text('${p.stockActual.toInt()}',
                        style: const TextStyle(color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),

          // ── Info ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.categoria.toUpperCase(),
                  style: GoogleFonts.inter(
                      color: _kTextMuted, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(p.nombre,
                  style: GoogleFonts.inter(
                      color: sinStock ? _kTextMuted : _kText,
                      fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Text('\$${p.precio.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      color: sinStock ? _kTextMuted : _kText,
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _iconProducto(bool sinStock, String categoria) {
    final icon = _iconPorCategoria(categoria);
    return Container(
      color: sinStock ? _kSurfaceHigh : _kGreenLight,
      child: Center(
        child: Icon(icon, size: 36,
            color: sinStock ? _kBorder : _kGreenDark.withValues(alpha: 0.55)),
      ),
    );
  }

  IconData _iconPorCategoria(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('bisut') || c.contains('joya') || c.contains('joyería') || c.contains('diam')) return Icons.diamond_outlined;
    if (c.contains('prenda') || c.contains('ropa') || c.contains('camisa') || c.contains('blusa') || c.contains('vestido')) return Icons.checkroom_outlined;
    if (c.contains('zapato') || c.contains('calzado') || c.contains('bota') || c.contains('sandal')) return Icons.hiking_outlined;
    if (c.contains('bolso') || c.contains('cartera') || c.contains('mochila') || c.contains('bolsa')) return Icons.shopping_bag_outlined;
    if (c.contains('cosmét') || c.contains('maquillaje') || c.contains('belleza') || c.contains('beauty')) return Icons.face_retouching_natural;
    if (c.contains('perfum') || c.contains('fragancia') || c.contains('aroma')) return Icons.spa_outlined;
    if (c.contains('electr') || c.contains('tecno') || c.contains('celular') || c.contains('comput')) return Icons.devices_outlined;
    if (c.contains('hogar') || c.contains('deco') || c.contains('mueble') || c.contains('cocina')) return Icons.chair_outlined;
    if (c.contains('deport') || c.contains('sport') || c.contains('gym') || c.contains('fitness')) return Icons.sports_outlined;
    if (c.contains('aliment') || c.contains('comida') || c.contains('snack') || c.contains('dulce')) return Icons.restaurant_outlined;
    if (c.contains('bebida') || c.contains('licor') || c.contains('agua') || c.contains('jugo')) return Icons.local_drink_outlined;
    if (c.contains('juguete') || c.contains('toy') || c.contains('niño')) return Icons.toys_outlined;
    if (c.contains('libro') || c.contains('papeler') || c.contains('útil')) return Icons.menu_book_outlined;
    if (c.contains('mascota') || c.contains('pet')) return Icons.pets_outlined;
    return Icons.inventory_2_outlined;
  }

  Widget _buildProductCardList(Producto p, PosProvider pos) {
    final sinStock  = p.stockActual <= 0;
    final stockBajo = !sinStock && p.stockActual <= p.stockMinimo && p.stockMinimo > 0;

    return GestureDetector(
      onTap: sinStock ? null : () {
        pos.agregarAlCarrito(p);
        _aplicarDescuentoTierSiNecesario();
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          // Miniatura
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56, height: 56,
              child: p.imagen != null && p.imagen!.isNotEmpty
                  ? Image.network(p.imagen!, fit: BoxFit.cover,
                      errorBuilder: (_, err, st) => _iconProducto(sinStock, p.categoria))
                  : _iconProducto(sinStock, p.categoria),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.categoria.toUpperCase(),
                  style: GoogleFonts.inter(
                      color: _kTextMuted, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 0.7),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(p.nombre,
                  style: GoogleFonts.inter(
                      color: sinStock ? _kTextMuted : _kText,
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (stockBajo)
                Text('Stock bajo: ${p.stockActual.toInt()} uds',
                    style: GoogleFonts.inter(
                        color: _kAmber, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 12),
          // Precio + estado
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${p.precio.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    color: sinStock ? _kTextMuted : _kText,
                    fontSize: 15, fontWeight: FontWeight.w800)),
            if (sinStock)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: _kError, borderRadius: BorderRadius.circular(5)),
                child: const Text('AGOTADO',
                    style: TextStyle(color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 0.4)),
              ),
          ]),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // PANEL DERECHO — TICKET
  // ══════════════════════════════════════════════════════════

  Widget _buildTicketPanel(PosProvider pos, AuthProvider auth) => Container(
    decoration: const BoxDecoration(
      color: _kCard,
      border: Border(left: BorderSide(color: _kBorder)),
    ),
    child: Column(children: [

      // Header
      _buildPanelHeader(pos),

      // Cliente asociado
      _buildClienteCard(),

      // Badge separados
      if (_separadosCliente > 0) _buildSeparadosBadge(),

      // Divisor
      const Divider(height: 1, color: _kBorder),

      // Items del carrito
      Expanded(child: _buildCartItems(pos)),

      // Zona 4 — Resumen financiero
      if (pos.carrito.isNotEmpty)
        _buildZonaResumen(pos),

      // Zona 5 — Configuración de pago
      if (pos.carrito.isNotEmpty)
        _buildZonaPago(pos),

      // Zona 6 — Acciones
      if (pos.carrito.isNotEmpty)
        _buildZonaAcciones(pos, auth),
    ]),
  );

  // ── Header del panel ─────────────────────────────────────

  Widget _buildPanelHeader(PosProvider pos) {
    final totalItems = pos.carrito.fold(0, (s, i) => s + i.cantidad);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Título + contador
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ticket Actual',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
              if (totalItems > 0)
                Text('$totalItems artículo${totalItems != 1 ? "s" : ""}',
                    style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted)),
            ]),
          ),
          // Asociar cliente — link de texto
          GestureDetector(
            onTap: _mostrarAsociarCliente,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_add_rounded, size: 15, color: _kGreenDark),
              const SizedBox(width: 4),
              Text('Asociar Cliente',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _kGreenDark)),
            ]),
          ),
        ]),

        // Tabs de tickets parkados
        if (pos.hayTicketsParkados) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _ticketTab(
                label: pos.numeroActual != null ? '#${pos.numeroActual}' : 'Nuevo',
                total: pos.total,
                items: pos.carrito.fold(0, (s, i) => s + i.cantidad),
                isActive: true,
              ),
              ...pos.ticketsParkados.asMap().entries.map((e) =>
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _ticketTab(
                    label: '#${e.value.numero}',
                    total: e.value.total,
                    items: e.value.items,
                    isActive: false,
                    onTap: () => pos.restaurarTicket(e.key),
                    onClose: () => _confirmarDescartarTicket(pos, e.key),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _ticketTab({
    required String label,
    required double total,
    required int    items,
    required bool   isActive,
    VoidCallback?   onTap,
    VoidCallback?   onClose,
  }) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? _kGreen.withValues(alpha: 0.08) : _kSurfaceLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? _kGreen : _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(
                color: isActive ? _kGreenDark : _kTextSub,
                fontSize: 11, fontWeight: FontWeight.w700)),
            Text('\$${total.toStringAsFixed(0)} · $items item${items != 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                    color: isActive ? _kText : _kTextMuted, fontSize: 9)),
          ]),
          if (onClose != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close_rounded, size: 12, color: _kTextMuted),
            ),
          ],
        ]),
      ),
    );

  // ── Sección cliente ──────────────────────────────────────

  Widget _buildClienteCard() {
    if (_clienteSeleccionado == null) return const SizedBox.shrink();

    final tier      = _clienteSeleccionado!.tierInfo;
    final tierColor = tier != null ? _hexFromString(tier.colorHex) : _kGreenDark;
    final inicial   = _clienteSeleccionado!.nombre.isNotEmpty
        ? _clienteSeleccionado!.nombre[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _kGreenLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreenDark.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        // Avatar con inicial
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(inicial,
                style: GoogleFonts.inter(
                    color: tierColor, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        // Nombre + tier
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_clienteSeleccionado!.nombreCompleto,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kText),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (tier != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 10, color: tierColor),
                const SizedBox(width: 3),
                Text(tier.nombre,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: tierColor, fontWeight: FontWeight.w600)),
                if (tier.descuentoPct > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· ${tier.descuentoPct.toStringAsFixed(tier.descuentoPct % 1 == 0 ? 0 : 1)}% desc.',
                    style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted),
                  ),
                ],
              ])
            else if (_clienteSeleccionado!.cedulaNit != null &&
                     _clienteSeleccionado!.cedulaNit!.isNotEmpty)
              Text(_clienteSeleccionado!.cedulaNit!,
                  style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted)),
          ],
        )),
        // Quitar cliente
        GestureDetector(
          onTap: () {
            setState(() {
              _clienteSeleccionado = null;
              _separadosCliente    = 0;
            });
            context.read<PosProvider>().setDescuento(0);
            _descuentoCtrl.clear();
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 15, color: _kTextMuted),
          ),
        ),
      ]),
    );
  }

  // Convierte un hex string a Color
  Color _hexFromString(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return _kGreen;
    }
  }

  Widget _buildSeparadosBadge() => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    color: const Color(0xFFD5E3FD),
    child: Row(children: [
      const Icon(Icons.bookmark_rounded, size: 14, color: Color(0xFF3A485C)),
      const SizedBox(width: 8),
      Text(
        'Este cliente tiene $_separadosCliente '
        'apartado${_separadosCliente > 1 ? 's' : ''} pendiente${_separadosCliente > 1 ? 's' : ''}',
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: const Color(0xFF3A485C)),
      ),
    ]),
  );

  // ── Items del carrito ────────────────────────────────────

  Widget _buildCartItems(PosProvider pos) {
    if (pos.carrito.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 68, height: 68,
          decoration: const BoxDecoration(color: _kSurfaceLow, shape: BoxShape.circle),
          child: const Icon(Icons.shopping_cart_outlined, size: 30, color: _kBorder),
        ),
        const SizedBox(height: 12),
        Text('Carrito vacío',
            style: GoogleFonts.inter(color: _kTextSub, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Toca un producto para agregarlo',
            style: GoogleFonts.inter(color: _kTextMuted, fontSize: 12)),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: pos.carrito.length,
      separatorBuilder: (_, sep) => const Divider(height: 1, color: _kBorder),
      itemBuilder: (_, i) => _buildCartItem(pos, i),
    );
  }

  Widget _buildCartItem(PosProvider pos, int i) {
    final item = pos.carrito[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 56, height: 68,
            child: item.producto.imagen != null && item.producto.imagen!.isNotEmpty
                ? Image.network(item.producto.imagen!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconProducto(false, item.producto.categoria))
                : _iconProducto(false, item.producto.categoria),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(item.producto.nombre,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700, color: _kText),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: () => pos.eliminarItem(i),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.delete_outline_rounded, size: 16, color: _kBorder),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Flexible(
                child: Text(
                  item.producto.referencia.isNotEmpty
                      ? item.producto.referencia : 'Sin ref.',
                  style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.aplicaMayoreo) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kGreenDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_offer_rounded, size: 8, color: Colors.white),
                    const SizedBox(width: 2),
                    Text('Mayoreo',
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // Stepper
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _qtyBtn(Icons.remove_rounded, () => pos.decrementar(i)),
                  SizedBox(
                    width: 28,
                    child: Text('${item.cantidad}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                  ),
                  _qtyBtn(Icons.add_rounded, () => pos.incrementar(i)),
                ]),
              ),
              // Precio
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$${item.subtotal.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: item.aplicaMayoreo ? _kGreenDark : _kText)),
                if (item.cantidad > 1)
                  Text('\$${item.precioUnitario.toStringAsFixed(0)} c/u',
                      style: GoogleFonts.inter(fontSize: 9, color: _kTextMuted)),
              ]),
            ]),
          ],
        )),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ZONA 4 — RESUMEN FINANCIERO (solo lectura, sin inputs)
  // ══════════════════════════════════════════════════════════

  Widget _buildZonaResumen(PosProvider pos) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(
      color: _kCard,
      border: Border(top: BorderSide(color: _kBorder)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (pos.descuento > 0) ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Subtotal',
              style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
          Text('\$${pos.total.toStringAsFixed(0)}',
              style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
        ]),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Descuento',
              style: GoogleFonts.inter(fontSize: 12, color: _kGreenDark)),
          Text('−\$${pos.descuento.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _kGreenDark)),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1, color: _kBorder),
        const SizedBox(height: 8),
      ],
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('Total',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSub)),
          Text('\$${pos.totalConDescuento.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  fontSize: 26, fontWeight: FontWeight.w800, color: _kText)),
        ],
      ),
    ]),
  );

  // ══════════════════════════════════════════════════════════
  // ZONA 5 — CONFIGURACIÓN DE PAGO (inputs, método, efectivo)
  // ══════════════════════════════════════════════════════════

  Widget _buildZonaPago(PosProvider pos) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(
      color: _kSurfaceLow,
      border: Border.symmetric(horizontal: BorderSide(color: _kBorder)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _buildDescuentoField(pos),
      const SizedBox(height: 10),
      _buildMetodosPago(pos),
      if (pos.metodoPago == 'efectivo') ...[
        const SizedBox(height: 10),
        _buildEfectivoSection(pos),
      ],
      if (pos.metodoPago == 'credito') ...[
        const SizedBox(height: 10),
        _buildCreditoInfo(),
      ],
    ]),
  );

  // ══════════════════════════════════════════════════════════
  // ZONA 6 — ACCIONES (cobrar, imprimir, separar)
  // ══════════════════════════════════════════════════════════

  Widget _buildZonaAcciones(PosProvider pos, AuthProvider auth) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    color: _kCard,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (pos.errorMsg.isNotEmpty) ...[
        _msgBanner(pos.errorMsg, isError: true),
        const SizedBox(height: 8),
      ],
      if (pos.successMsg.isNotEmpty) ...[
        _msgBanner(pos.successMsg, isError: false),
        const SizedBox(height: 8),
      ],

      // Banner sugerencia cliente
      Builder(builder: (_) {
        final config = context.read<ConfigProvider>();
        final mostrar = config.sugerirCliente
            && _clienteSeleccionado == null
            && pos.totalConDescuento >= config.umbralSugerirCliente;
        if (!mostrar) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kGreenDark.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.person_add_rounded, size: 16, color: _kGreenDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¿Registrar cliente para acumular puntos?',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _kGreenDark),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _mostrarAsociarCliente,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kGreenDark,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text('Asociar',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ),
        );
      }),

      // Separar | Cobrar — 2 columnas iguales
      Row(children: [
        // Separar
        Expanded(
          child: GestureDetector(
            onTap: pos.carrito.isEmpty ? null : () => _abrirSeparado(pos, auth),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _kSurfaceLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bookmark_add_rounded, size: 20, color: _kTextSub),
                const SizedBox(height: 4),
                Text('Separar Pedido',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _kTextSub)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Cobrar
        Expanded(
          child: GestureDetector(
            onTap: pos.procesando ? null : () async {
              final clienteAntes     = _clienteSeleccionado;
              final tierNombreAntes  = clienteAntes?.tierInfo?.nombre;
              _montoCtrl.clear();
              _descuentoCtrl.clear();
              final ok = await pos.cobrar(auth.tiendaId, clienteId: clienteAntes?.id);
              if (!mounted) return;
              setState(() => _clienteSeleccionado = null);
              if (ok && clienteAntes != null) {
                final feedback = pos.ultimaVenta?['tier_feedback'] as Map<String, dynamic>?;
                if (feedback != null) {
                  final tierData    = feedback['tier_actual']    as Map<String, dynamic>?;
                  final siguienteT  = feedback['siguiente_tier'] as Map<String, dynamic>?;
                  if (tierData != null || siguienteT != null) {
                    _mostrarTierFeedback(clienteAntes, feedback, tierNombreAntes);
                  }
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _kGreenDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                pos.procesando
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.shopping_cart_checkout_rounded,
                        size: 20, color: Colors.white),
                const SizedBox(height: 4),
                Text(pos.procesando ? 'Procesando…' : 'Completar Venta',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
        ),
      ]),

      const SizedBox(height: 6),

      // Cotización
      if (pos.carrito.isNotEmpty)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _generarCotizacion(pos, auth),
            icon: const Icon(Icons.request_quote_rounded, size: 15),
            label: Text('Cotización PDF',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kGreenDark,
              side: const BorderSide(color: _kGreenDark),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),

      const SizedBox(height: 6),

      // Quick actions — 4 íconos
      Row(children: [
        _quickIcon(Icons.percent_rounded,
            onTap: () => _mostrarDialogPorcentaje(pos)),
        const SizedBox(width: 6),
        _quickIcon(Icons.print_rounded,
            onTap: () => _cobrarEImprimir(pos, auth)),
        const SizedBox(width: 6),
        _quickIcon(Icons.replay_rounded,
            onTap: () => DevolucionFormSheet.show(context, onCreada: (_) {})),
        const SizedBox(width: 6),
        _quickIcon(Icons.delete_sweep_rounded,
            color: _kError, bg: _kErrorBg,
            onTap: () => _confirmarLimpiar(pos)),
      ]),
    ]),
  );

  Widget _quickIcon(IconData icon,
      {required VoidCallback onTap,
      Color color = _kTextSub,
      Color bg = _kSurfaceLow}) =>
    Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );

  Widget _totalRow(String label, String value,
      {bool small = false, Color? color}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.inter(
          fontSize: small ? 12 : 14, color: _kTextSub, fontWeight: FontWeight.w500)),
      Text(value, style: GoogleFonts.inter(
          fontSize: small ? 13 : 16, fontWeight: FontWeight.w700,
          color: color ?? _kText)),
    ]);

  // ── Campo descuento ──────────────────────────────────────

  Widget _buildDescuentoField(PosProvider pos) {
    final tier = _clienteSeleccionado?.tierInfo;
    final hasTier = tier != null && tier.descuentoPct > 0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (hasTier) ...[
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _hexFromString(tier.colorHex).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _hexFromString(tier.colorHex).withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.workspace_premium_rounded, size: 12,
                  color: _hexFromString(tier.colorHex)),
              const SizedBox(width: 5),
              Text(
                'Tier ${tier.nombre} · ${tier.descuentoPct.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}% aplicado',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _hexFromString(tier.colorHex)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
      ],
      Row(children: [
      Expanded(
        child: TextField(
        controller: _descuentoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        style: GoogleFonts.inter(fontSize: 13, color: _kText, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Descuento',
          labelStyle: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
          prefixText: '\$ ',
          filled: true, fillColor: _kSurfaceLow,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kGreen, width: 2)),
          suffixIcon: pos.descuento > 0
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  if (pos.total > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kGreenLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kGreenDark.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        '${(pos.descuento / pos.total * 100).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}%',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: _kGreenDark),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14, color: _kTextMuted),
                    onPressed: () {
                      _descuentoCtrl.clear();
                      pos.setDescuento(0);
                    }),
                ])
              : null,
        ),
        onChanged: (v) => pos.setDescuento(double.tryParse(v) ?? 0),
      ),
    ),
    const SizedBox(width: 6),
    _pctBtn(pos, 5),
    const SizedBox(width: 4),
    _pctBtn(pos, 10),
    const SizedBox(width: 4),
    _pctBtn(pos, 15),
      ]),
    ]);
  }

  Widget _pctBtn(PosProvider pos, int pct) => GestureDetector(
    onTap: () {
      pos.setDescuentoPorcentaje(pct);
      _descuentoCtrl.text = pos.descuento.toStringAsFixed(0);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: _kSurfaceMid,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$pct%', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700, color: _kTextSub)),
    ),
  );

  // ── Métodos de pago ──────────────────────────────────────

  Widget _buildMetodosPago(PosProvider pos) {
    const metodos = [
      ('efectivo',      Icons.payments_rounded,       'Efectivo'),
      ('tarjeta',       Icons.credit_card_rounded,     'Tarjeta'),
      ('transferencia', Icons.account_balance_rounded, 'Transf.'),
      ('credito',       Icons.handshake_rounded,       'Fiado'),
    ];
    final tieneCredito = (_clienteSeleccionado?.limiteCredito ?? 0) > 0;

    return Row(children: metodos.indexed.map((e) {
      final (idx, (value, icon, label)) = e;
      final esFiado    = value == 'credito';
      final disabled   = esFiado && !tieneCredito;
      final selected   = pos.metodoPago == value && !disabled;
      final activeClr  = esFiado ? const Color(0xFF7C3AED) : _kGreen;
      final activeDark = esFiado ? const Color(0xFF5B21B6) : _kGreenDark;
      final iconColor  = disabled
          ? _kTextMuted.withValues(alpha: 0.4)
          : selected ? activeDark : _kTextMuted;
      final textColor  = disabled
          ? _kTextMuted.withValues(alpha: 0.4)
          : selected ? activeDark : _kTextMuted;

      Widget chip = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? activeClr.withValues(alpha: 0.08)
              : disabled ? _kSurfaceLow.withValues(alpha: 0.5) : _kSurfaceLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? activeClr : _kBorder.withValues(alpha: disabled ? 0.5 : 1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: textColor)),
        ]),
      );

      if (disabled) {
        chip = Tooltip(
          message: 'Selecciona un cliente\ncon crédito habilitado',
          preferBelow: false,
          child: chip,
        );
      }

      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: idx < metodos.length - 1 ? 6 : 0),
          child: GestureDetector(
            onTap: disabled ? null : () {
              pos.setMetodoPago(value);
              if (value != 'efectivo') {
                _montoCtrl.clear();
                pos.setMontoRecibido(pos.total);
              }
              setState(() {});
            },
            child: chip,
          ),
        ),
      );
    }).toList());
  }

  // ── Info crédito ──────────────────────────────────────────

  Widget _buildCreditoInfo() {
    final cliente = _clienteSeleccionado;
    if (cliente == null) return const SizedBox.shrink();
    final fmt = (double v) => '\$${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.handshake_rounded, size: 16, color: Color(0xFF5B21B6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${cliente.nombre} · Límite ${fmt(cliente.limiteCredito)}',
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: const Color(0xFF5B21B6)),
          ),
        ),
      ]),
    );
  }

  // ── Sección efectivo ─────────────────────────────────────

  Widget _buildEfectivoSection(PosProvider pos) => Column(children: [
    TextField(
      controller: _montoCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _kText),
      decoration: InputDecoration(
        labelText: 'Monto recibido',
        labelStyle: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
        prefixText: '\$ ',
        filled: true, fillColor: _kSurfaceLow,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGreen, width: 2)),
      ),
      onChanged: (v) => pos.setMontoRecibido(double.tryParse(v) ?? 0),
    ),
    if (pos.montoRecibido > 0) ...[
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: pos.vuelto >= 0 ? _kGreenLight : _kErrorBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: pos.vuelto >= 0
                ? _kGreenDark.withValues(alpha: 0.3)
                : _kError.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Cambio',
              style: GoogleFonts.inter(
                  color: pos.vuelto >= 0 ? _kGreenDark : _kError,
                  fontWeight: FontWeight.w700, fontSize: 13)),
          Text('\$${pos.vuelto.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  color: pos.vuelto >= 0 ? _kGreenDark : _kError,
                  fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
      ),
    ],
  ]);

  // ══════════════════════════════════════════════════════════
  // ACCIONES
  // ══════════════════════════════════════════════════════════

  void _abrirSeparado(PosProvider pos, AuthProvider auth) {
    if (_clienteSeleccionado == null) {
      _showSnack('Primero asocia un cliente para crear un separado', _kAmber);
      return;
    }
    SeparadoForm.mostrar(
      context,
      tiendaId:       auth.tiendaId,
      fmt:            NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0),
      clienteInicial: _clienteSeleccionado,
      fechaInicial:   _fechaLimite,
      itemsInciales:  pos.carrito,
      onCreado: () {
        pos.limpiarCarrito();
        setState(() {
          _clienteSeleccionado = null;
          _separadosCliente    = 0;
          _fechaLimite         = null;
          _descuentoCtrl.clear();
        });
      },
    );
  }

  void _mostrarAsociarCliente() {
    final clienteProv = context.read<ClienteProvider>();
    clienteProv.cargarClientesSimple(q: '');

    showDialog(
      context: context,
      builder: (ctx) {
        final buscarCtrl   = TextEditingController();
        final nombreCtrl   = TextEditingController();
        final apellidoCtrl = TextEditingController();
        final telefonoCtrl = TextEditingController();
        final cedulaCtrl   = TextEditingController();
        bool buscando  = false;
        bool creando   = false;
        bool guardando = false;
        String? errorCrear;

        return StatefulBuilder(builder: (ctx, setS) {

          // ── Modo búsqueda ─────────────────────────────────
          if (!creando) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                const Icon(Icons.person_search_rounded, color: _kGreenDark, size: 20),
                const SizedBox(width: 8),
                Text('Asociar Cliente',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
              ]),
              content: SizedBox(
                width: 380, height: 320,
                child: Column(children: [
                  TextField(
                    controller: buscarCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o cédula…',
                      hintStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kGreenDark),
                      suffixIcon: buscando
                          ? const Padding(padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _kGreenDark)))
                          : null,
                      filled: true, fillColor: _kSurfaceLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kGreen, width: 2)),
                    ),
                    onChanged: (v) async {
                      if (v.length < 2) return;
                      setS(() => buscando = true);
                      await clienteProv.cargarClientesSimple(q: v);
                      if (ctx.mounted) setS(() => buscando = false);
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Consumer<ClienteProvider>(
                      builder: (_, cp, __) => cp.clientesSimple.isEmpty
                          ? Center(
                              child: Text('Escribe al menos 2 caracteres para buscar',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: _kTextMuted, fontSize: 13)))
                          : ListView.builder(
                              itemCount: cp.clientesSimple.length,
                              itemBuilder: (_, i) {
                                final c      = cp.clientesSimple[i];
                                final tierC  = c.tierInfo;
                                final tColor = tierC != null ? _hexFromString(tierC.colorHex) : _kGreen;
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  leading: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: tColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(child: Text(
                                      c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                                      style: GoogleFonts.inter(
                                          color: tColor, fontSize: 14, fontWeight: FontWeight.w800),
                                    )),
                                  ),
                                  title: Row(children: [
                                    Expanded(
                                      child: Text(c.nombreCompleto,
                                          style: GoogleFonts.inter(
                                              fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    if (tierC != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.star_rounded, size: 9, color: tColor),
                                          const SizedBox(width: 2),
                                          Text(tierC.nombre,
                                              style: GoogleFonts.inter(
                                                  fontSize: 10, fontWeight: FontWeight.w700,
                                                  color: tColor)),
                                        ]),
                                      ),
                                    ],
                                  ]),
                                  subtitle: (c.cedulaNit != null && c.cedulaNit!.isNotEmpty)
                                      ? Text(c.cedulaNit!,
                                          style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted))
                                      : null,
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    setState(() => _clienteSeleccionado = c);
                                    await _cargarClienteResumen(c.id);
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: GoogleFonts.inter(color: _kTextMuted)),
                ),
                TextButton.icon(
                  onPressed: () => setS(() => creando = true),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: _kGreenDark),
                  label: Text('Nuevo cliente',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _kGreenDark)),
                ),
              ],
            );
          }

          // ── Modo creación rápida ──────────────────────────
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              GestureDetector(
                onTap: guardando ? null : () => setS(() { creando = false; errorCrear = null; }),
                child: const Icon(Icons.arrow_back_rounded, size: 20, color: _kTextSub),
              ),
              const SizedBox(width: 10),
              Text('Nuevo Cliente',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
            ]),
            content: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (errorCrear != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kErrorBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kError.withValues(alpha: 0.3)),
                    ),
                    child: Text(errorCrear!,
                        style: GoogleFonts.inter(fontSize: 12, color: _kError)),
                  ),
                ],
                Row(children: [
                  Expanded(child: _inputCrear(nombreCtrl,   'Nombre *',  Icons.person_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _inputCrear(apellidoCtrl, 'Apellido',  null)),
                ]),
                const SizedBox(height: 10),
                _inputCrear(telefonoCtrl, 'Teléfono *', Icons.phone_rounded,
                    tipo: TextInputType.phone),
                const SizedBox(height: 10),
                _inputCrear(cedulaCtrl, 'Cédula / NIT (opcional)', Icons.badge_rounded,
                    tipo: TextInputType.number),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('* Campos requeridos',
                      style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted)),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => setS(() { creando = false; errorCrear = null; }),
                child: Text('Volver', style: GoogleFonts.inter(color: _kTextMuted)),
              ),
              ElevatedButton(
                onPressed: guardando ? null : () async {
                  final nombre = nombreCtrl.text.trim();
                  final tel    = telefonoCtrl.text.trim();
                  if (nombre.isEmpty || tel.isEmpty) {
                    setS(() => errorCrear = 'Nombre y teléfono son requeridos');
                    return;
                  }
                  setS(() { guardando = true; errorCrear = null; });
                  final res = await ClienteService().crearCliente({
                    'nombre':    nombre,
                    'apellido':  apellidoCtrl.text.trim(),
                    'telefono':  tel,
                    if (cedulaCtrl.text.trim().isNotEmpty)
                      'cedula_nit': cedulaCtrl.text.trim(),
                    'email':     '',
                    'direccion': '',
                    'activo':    true,
                  });
                  if (!ctx.mounted) return;
                  if (res['success'] == true) {
                    final nuevo = res['data'] as Cliente;
                    Navigator.pop(ctx);
                    setState(() => _clienteSeleccionado = nuevo);
                    await _cargarClienteResumen(nuevo.id);
                  } else {
                    setS(() {
                      guardando  = false;
                      errorCrear = res['error']?.toString() ?? 'Error al crear cliente';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreenDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: guardando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Crear y asociar',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _inputCrear(
    TextEditingController ctrl,
    String hint,
    IconData? icon, {
    TextInputType tipo = TextInputType.text,
  }) =>
    TextField(
      controller: ctrl,
      keyboardType: tipo,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 17, color: _kTextSub) : null,
        filled: true,
        fillColor: _kSurfaceLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGreen, width: 2)),
      ),
    );

  void _confirmarDescartarTicket(PosProvider pos, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Descartar ticket?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _kText)),
        content: Text('Se eliminarán los productos de este ticket.',
            style: GoogleFonts.inter(fontSize: 13, color: _kTextSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter(color: _kTextMuted))),
          TextButton(
            onPressed: () { pos.descartarTicketParkado(index); Navigator.pop(context); },
            child: Text('Descartar',
                style: GoogleFonts.inter(color: _kError, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _generarCotizacion(PosProvider pos, AuthProvider auth) async {
    if (pos.carrito.isEmpty) return;
    try {
      await CotizacionPdfService.generarCotizacion(
        items:          List.from(pos.carrito),
        descuento:      pos.descuento,
        total:          pos.totalConDescuento,
        empresaNombre:  auth.empresaNombre.isNotEmpty ? auth.empresaNombre : 'Empresa',
        tiendaNombre:   auth.tiendaNombre.isNotEmpty  ? auth.tiendaNombre  : 'Tienda',
        cajeroNombre:   auth.nombre,
        clienteNombre:  _clienteSeleccionado?.nombreCompleto,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar cotización: $e'),
          backgroundColor: _kError,
        ),
      );
    }
  }

  Future<void> _cobrarEImprimir(PosProvider pos, AuthProvider auth) async {
    // Snapshot antes de cobrar — pos limpia el carrito en caso de éxito
    final items         = List<ItemCarrito>.from(pos.carrito);
    final descuento     = pos.descuento;
    final total         = pos.totalConDescuento;
    final montoRecibido = pos.montoRecibido;
    final vuelto        = pos.vuelto;
    final metodoPago    = pos.metodoPago;
    final clienteAntes       = _clienteSeleccionado;
    final clienteNombre      = clienteAntes?.nombre ?? '';
    final clienteId          = clienteAntes?.id;
    final tierAnteriorNombre = clienteAntes?.tierInfo?.nombre;

    _montoCtrl.clear();
    _descuentoCtrl.clear();

    final ok = await pos.cobrar(auth.tiendaId, clienteId: clienteId);
    if (mounted) setState(() => _clienteSeleccionado = null);
    if (!ok || !mounted) return;

    // Feedback de fidelización (no bloqueante — no afecta el flujo de impresión)
    if (clienteAntes != null) {
      final feedback = pos.ultimaVenta?['tier_feedback'] as Map<String, dynamic>?;
      if (feedback != null) {
        final tierData   = feedback['tier_actual']    as Map<String, dynamic>?;
        final siguienteT = feedback['siguiente_tier'] as Map<String, dynamic>?;
        if (tierData != null || siguienteT != null) {
          _mostrarTierFeedback(clienteAntes, feedback, tierAnteriorNombre);
        }
      }
    }

    final factura    = pos.ultimaVenta?['numero_factura']?.toString() ?? '-';
    final config     = context.read<ConfigProvider>();
    final tipoPapel  = config.tipoPapel;
    final esCash     = metodoPago == 'efectivo' || metodoPago == 'mixto';

    try {
      final paperSize = tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;

      if (tipoPapel != 'pdf' && ThermalPrinterService.isWebUsbSupported) {
        // Web: WebUSB ESC/POS
        final device = await ThermalPrinterService.getOrRequestDevice();
        if (device != null) {
          final bytes = await ThermalPrinterService.buildRecibo(
            items: items, numeroFactura: factura,
            tiendaNombre: auth.tiendaNombre, empresaNombre: auth.empresaNombre,
            cajeroNombre: auth.nombre, metodoPago: metodoPago,
            descuento: descuento, total: total,
            montoRecibido: montoRecibido, vuelto: vuelto, paperSize: paperSize,
            clienteNombre: clienteNombre,
          );
          await ThermalPrinterService.printBytes(device, bytes);
          if (esCash && await ThermalPrinterService.hasCashDrawer()) {
            await ThermalPrinterService.kickDrawer(device);
          }
          unawaited(ReciboPdfService.imprimirRecibo(
            items: items, numeroFactura: factura,
            tiendaNombre: auth.tiendaNombre, empresaNombre: auth.empresaNombre,
            cajeroNombre: auth.nombre, metodoPago: metodoPago,
            descuento: descuento, total: total,
            montoRecibido: montoRecibido, vuelto: vuelto,
            clienteNombre: clienteNombre, soloGuardar: true,
          ));
          return;
        }
      } else if (tipoPapel != 'pdf' && !kIsWeb &&
                 await WindowsPrinterService.hasSavedPrinter()) {
        // Exe: ESC/POS RAW via WritePrinter (COM, USB, red — cualquier puerto)
        final bytes = await ThermalPrinterService.buildRecibo(
          items: items, numeroFactura: factura,
          tiendaNombre: auth.tiendaNombre, empresaNombre: auth.empresaNombre,
          cajeroNombre: auth.nombre, metodoPago: metodoPago,
          descuento: descuento, total: total,
          montoRecibido: montoRecibido, vuelto: vuelto, paperSize: paperSize,
          clienteNombre: clienteNombre,
        );
        await WindowsPrinterService.printRaw(bytes);
        unawaited(ReciboPdfService.imprimirRecibo(
          items: items, numeroFactura: factura,
          tiendaNombre: auth.tiendaNombre, empresaNombre: auth.empresaNombre,
          cajeroNombre: auth.nombre, metodoPago: metodoPago,
          descuento: descuento, total: total,
          montoRecibido: montoRecibido, vuelto: vuelto,
          clienteNombre: clienteNombre, soloGuardar: true,
        ));
        return;
      }
      // Fallback: PDF (abre en Edge o visor del sistema)
      await ReciboPdfService.imprimirRecibo(
        items:          items,
        numeroFactura:  factura,
        tiendaNombre:   auth.tiendaNombre,
        empresaNombre:  auth.empresaNombre,
        cajeroNombre:   auth.nombre,
        metodoPago:     metodoPago,
        descuento:      descuento,
        total:          total,
        montoRecibido:  montoRecibido,
        vuelto:         vuelto,
        clienteNombre:  clienteNombre,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al imprimir: $e'),
        backgroundColor: const Color(0xFFBE123C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  void _mostrarDialogPorcentaje(PosProvider pos) {
    final ctrl = TextEditingController();
    const presets = [5, 10, 15, 20, 25, 30];
    int? selPreset;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          title: Row(children: [
            const Icon(Icons.percent_rounded, size: 20, color: _kGreenDark),
            const SizedBox(width: 8),
            Text('Descuento rápido',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                    fontSize: 16, color: _kText)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // Chips de preset
            Wrap(spacing: 6, runSpacing: 6, children: presets.map((p) {
              final sel = selPreset == p;
              return GestureDetector(
                onTap: () => setS(() {
                  selPreset = p;
                  ctrl.text = '$p';
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color:   sel ? _kGreenDark : _kSurfaceLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? _kGreenDark : _kBorder),
                  ),
                  child: Text('$p%',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : _kTextSub)),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            // Campo personalizado
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
              ],
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600,
                  color: _kText),
              decoration: InputDecoration(
                hintText: 'Porcentaje personalizado',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: _kTextMuted),
                suffixText: '%',
                suffixStyle: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kGreenDark),
                filled: true, fillColor: _kSurfaceLow,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kGreenDark, width: 2)),
              ),
              onChanged: (_) => setS(() => selPreset = null),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: GoogleFonts.inter(color: _kTextMuted, fontSize: 13)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreenDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final pct = double.tryParse(ctrl.text) ?? 0;
                if (pct > 0) {
                  pos.setDescuentoPorcentaje(pct.round());
                  _descuentoCtrl.text = pos.descuento.toStringAsFixed(0);
                }
                Navigator.pop(ctx);
              },
              child: Text('Aplicar',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarLimpiar(PosProvider pos) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Vaciar carrito?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _kText)),
        content: Text('Se eliminarán todos los productos del carrito.',
            style: GoogleFonts.inter(fontSize: 13, color: _kTextSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter(color: _kTextMuted))),
          TextButton(
            onPressed: () {
              pos.limpiarCarrito();
              _descuentoCtrl.clear();
              Navigator.pop(context);
            },
            child: Text('Vaciar',
                style: GoogleFonts.inter(color: _kError, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: SizedBox(width: 26, height: 26,
        child: Icon(icon, size: 14, color: _kTextSub)),
  );

  Widget _msgBanner(String msg, {required bool isError}) {
    final bgColor   = isError ? _kError   : _kGreen;
    final textColor = isError ? _kError   : _kGreenDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bgColor.withValues(alpha: 0.3)),
      ),
      child: Text(msg,
          style: GoogleFonts.inter(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState({required IconData icon, required String title, required String sub}) =>
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: _kSurfaceLow, borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, size: 36, color: _kBorder),
      ),
      const SizedBox(height: 14),
      Text(title, style: GoogleFonts.inter(color: _kTextSub, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(sub, style: GoogleFonts.inter(color: _kTextMuted, fontSize: 12), textAlign: TextAlign.center),
    ]));

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _mostrarTierFeedback(
    Cliente cliente,
    Map<String, dynamic> feedback,
    String? tierNombreAntes,
  ) {
    final tierData        = feedback['tier_actual']    as Map<String, dynamic>?;
    final siguienteTier   = feedback['siguiente_tier'] as Map<String, dynamic>?;
    final tierNombreAhora = tierData?['nombre'] as String?;
    final subioTier = tierNombreAntes != tierNombreAhora && tierNombreAhora != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TierFeedbackSheet(
        clienteNombre:  cliente.nombreCompleto,
        totalAcumulado: (feedback['total_acumulado'] as num?)?.toDouble() ?? 0,
        tierActual:     tierData,
        siguienteTier:  siguienteTier,
        subioTier:      subioTier,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TIER FEEDBACK BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _TierFeedbackSheet extends StatelessWidget {
  final String                  clienteNombre;
  final double                  totalAcumulado;
  final Map<String, dynamic>?   tierActual;
  final Map<String, dynamic>?   siguienteTier;
  final bool                    subioTier;

  const _TierFeedbackSheet({
    required this.clienteNombre,
    required this.totalAcumulado,
    required this.subioTier,
    this.tierActual,
    this.siguienteTier,
  });

  Color _color(String? hex, Color fallback) {
    if (hex == null) return fallback;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return fallback; }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _color(
      tierActual?['color_hex'] as String?,
      siguienteTier != null ? _kGreenDark : _kGreenDark,
    );

    final fmt = NumberFormat('#,##0', 'es');

    // Progreso hacia siguiente tier (0.0 – 1.0)
    double progress = 0;
    double faltante = 0;
    if (siguienteTier != null) {
      final umbral = (siguienteTier!['umbral_min'] as num?)?.toDouble() ?? 0;
      if (umbral > 0) {
        progress = (totalAcumulado / umbral).clamp(0.0, 1.0);
        faltante = (umbral - totalAcumulado).clamp(0.0, double.infinity);
      }
    }

    final esMaxTier = tierActual != null && siguienteTier == null;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  // Header
                  if (subioTier) ...[
                    Icon(Icons.workspace_premium_rounded, size: 52, color: tierColor),
                    const SizedBox(height: 8),
                    Text('¡Subiste de nivel!',
                        style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w800, color: tierColor)),
                    Text(clienteNombre,
                        style: GoogleFonts.inter(fontSize: 13, color: _kTextMuted)),
                  ] else ...[
                    Row(children: [
                      Icon(Icons.star_rounded, size: 16, color: _kAmber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Puntos de $clienteNombre',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 14),

                  // Total acumulado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _kGreenLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kGreenDark.withValues(alpha: 0.2)),
                    ),
                    child: Column(children: [
                      Text('Total acumulado',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _kTextMuted,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('\$${fmt.format(totalAcumulado)}',
                          style: GoogleFonts.inter(
                              fontSize: 28, fontWeight: FontWeight.w800,
                              color: _kGreenDark)),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // Badge tier actual
                  if (tierActual != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.workspace_premium_rounded, size: 14, color: tierColor),
                        const SizedBox(width: 6),
                        Text(
                          subioTier
                              ? '¡Ahora eres ${tierActual!['nombre']}!'
                              : 'Nivel ${tierActual!['nombre']}',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: tierColor),
                        ),
                      ]),
                    ),

                  // Progreso hacia siguiente tier
                  if (siguienteTier != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Próximo: ${siguienteTier!['nombre']}',
                            style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted)),
                        Text('Faltan \$${fmt.format(faltante)}',
                            style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: _kText)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: _kSurfaceMid,
                        valueColor: AlwaysStoppedAnimation(tierColor),
                        minHeight: 8,
                      ),
                    ),
                  ] else if (esMaxTier) ...[
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.emoji_events_rounded, size: 14, color: _kAmber),
                      const SizedBox(width: 5),
                      Text('¡Estás en el nivel más alto!',
                          style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
                    ]),
                  ],

                  const SizedBox(height: 20),

                  // Botón cerrar
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGreenDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Continuar',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
