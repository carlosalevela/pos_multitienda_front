import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/inventario_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../models/producto.dart';
import '../../services/empleado_service.dart';
import 'widgets/producto_form_dialog.dart';
import 'widgets/importar_excel_dialog.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _empleadoService = EmpleadoService();

  List<Map<String, dynamic>> _tiendas = [];
  int? _tiendaFiltro;
  final Set<String> _abiertas = {};
  String _activoFiltro = 'true';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _bg = Color(0xFFF4F6F8);
  static const _card = Colors.white;
  static const _border = Color(0xFFE5E7EB);
  static const _text = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _muted2 = Color(0xFF9CA3AF);
  static const _accent = Color(0xFF22C55E);
  static const _accentDark = Color(0xFF15803D);
  static const _danger = Color(0xFFEF4444);
  static const _warning = Color(0xFFF59E0B);
  static const _chipBg = Color(0xFFF8FAFC);

  static const _iconos = [
    Icons.category_rounded,
    Icons.shopping_bag_rounded,
    Icons.inventory_2_rounded,
    Icons.local_offer_rounded,
    Icons.storefront_rounded,
    Icons.label_rounded,
    Icons.star_rounded,
    Icons.folder_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final inv = context.read<InventarioProvider>();

      if (auth.rol == 'admin' || auth.rol == 'superadmin') {
        final tiendas = await _empleadoService.getTiendas();
        if (!mounted) return;
        setState(() {
          _tiendas = tiendas;
          _tiendaFiltro = tiendas.isNotEmpty ? tiendas.first['id'] : null;
        });
        inv.cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro);
      } else {
        inv.cargarProductos(
          tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
          activo: _activoFiltro,
        );
      }
    });
  }

  void _abrirImportarExcel(InventarioProvider inv) async {
    final importo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportarExcelDialog(
        tiendaId: _tiendaActiva ?? 0,
        empresaId: _empresaActiva,
        nombreTienda: _nombreTiendaActual(),
      ),
    );
    if (importo == true && mounted) {
      inv.cargarProductos(
        tiendaId: _tiendaActiva,
        activo: _activoFiltro,
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  int? get _tiendaActiva {
    final auth = context.read<AuthProvider>();
    if (auth.rol == 'admin' || auth.rol == 'superadmin') return _tiendaFiltro;
    return auth.tiendaId == 0 ? null : auth.tiendaId;
  }

  int? get _empresaActiva {
    if (_tiendaFiltro == null) return null;
    final t = _tiendas.where((t) => t['id'] == _tiendaFiltro).firstOrNull;
    final raw = t?['empresa'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String _nombreTiendaActual() {
    if (_tiendaFiltro == null) return 'Todas las tiendas';
    final t = _tiendas.where((t) => t['id'] == _tiendaFiltro).firstOrNull;
    return t?['nombre'] ?? 'Tienda';
  }

  Map<String, List<Producto>> _agrupar(List<Producto> lista) {
    final map = <String, List<Producto>>{};
    for (final p in lista) {
      final cat = (p.categoria.isEmpty ||
              p.categoria == 'null' ||
              p.categoria == 'Sin categoría')
          ? 'Sin categoría'
          : p.categoria;
      map.putIfAbsent(cat, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventarioProvider>();
    final auth = context.watch<AuthProvider>();
    final esCajero = auth.rol == 'cajero';
    final esAdmin = auth.rol == 'admin' || auth.rol == 'superadmin';
    final grupos = _agrupar(inv.productos);

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
              const SizedBox(height: 18),
              if (esAdmin && _tiendas.isNotEmpty) ...[
                _selectorTienda(),
                const SizedBox(height: 14),
              ],
              if (inv.productos.isNotEmpty) ...[
                _buildStatsRow(inv.productos, grupos.length),
                const SizedBox(height: 18),
              ],
              _buildToolbar(esCajero, inv),
              const SizedBox(height: 14),
              if (inv.successMsg != null)
                _banner(inv.successMsg!, isError: false, onClose: inv.limpiarMensajes),
              if (inv.errorMsg != null)
                _banner(inv.errorMsg!, isError: true, onClose: inv.limpiarMensajes),
              Expanded(
                child: inv.cargando
                    ? _loadingState()
                    : inv.productos.isEmpty
                        ? _emptyState(esCajero)
                        : _buildCategorias(grupos, esCajero, esAdmin, inv),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool esCajero, bool esAdmin, InventarioProvider inv) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F9EF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCDEFD8)),
          ),
          child: const Icon(Icons.inventory_2_rounded, color: _accentDark, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Control de inventario',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                esAdmin
                    ? 'Vista general · ${_tiendas.isEmpty ? 'Cargando tiendas…' : _nombreTiendaActual()}'
                    : 'Supervisa existencias, precios y disponibilidad de productos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!esCajero) ...[
          _secondaryButton(
            icon: Icons.table_chart_rounded,
            label: 'Importar Excel',
            onTap: () => _abrirImportarExcel(inv),
          ),
          const SizedBox(width: 10),
          _primaryButton(
            icon: Icons.add_rounded,
            label: 'Nuevo producto',
            onTap: () => _abrirFormulario(context, inv),
          ),
        ],
      ],
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: _accentDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        elevation: 0,
        foregroundColor: _text,
        backgroundColor: _card,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildStatsRow(List<Producto> productos, int numCats) {
    final bajo = productos.where((p) => p.stockActual > 0 && p.stockActual <= p.stockMinimo).length;
    final agotado = productos.where((p) => p.stockActual <= 0).length;
    final activos = productos.where((p) => p.stockActual > p.stockMinimo).length;

    final stats = [
      _StatData(
        icon: Icons.grid_view_rounded,
        label: 'Categorías',
        value: '$numCats',
        tone: const Color(0xFFEEF2FF),
        iconColor: const Color(0xFF4F46E5),
      ),
      _StatData(
        icon: Icons.inventory_2_rounded,
        label: 'Productos',
        value: '${productos.length}',
        tone: const Color(0xFFEFFBF3),
        iconColor: _accentDark,
      ),
      _StatData(
        icon: Icons.check_circle_outline_rounded,
        label: 'Disponibles',
        value: '$activos',
        tone: const Color(0xFFEAFBF0),
        iconColor: _accent,
      ),
      _StatData(
        icon: Icons.warning_amber_rounded,
        label: 'Stock bajo',
        value: '$bajo',
        tone: const Color(0xFFFFF7E8),
        iconColor: _warning,
      ),
      _StatData(
        icon: Icons.remove_circle_outline_rounded,
        label: 'Agotados',
        value: '$agotado',
        tone: const Color(0xFFFFEFEF),
        iconColor: _danger,
      ),
    ];

    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _statCard(stats[i]),
      ),
    );
  }

  Widget _statCard(_StatData s) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: s.tone,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, color: s.iconColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _text,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool esCajero, InventarioProvider inv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _text),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o referencia...',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: _muted2),
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                onChanged: (val) => context.read<InventarioProvider>().cargarProductos(
                      q: val,
                      tiendaId: _tiendaActiva,
                      activo: _activoFiltro,
                    ),
              ),
            ),
          ),
          if (!esCajero) ...[
            const SizedBox(width: 12),
            _filtroEstado(),
          ],
        ],
      ),
    );
  }

  Widget _selectorTienda() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tiendas',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipTienda(
                  id: null,
                  nombre: 'Todas',
                  icono: Icons.store_mall_directory_rounded,
                ),
                const SizedBox(width: 8),
                ..._tiendas.asMap().entries.map((e) {
                  final t = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _chipTienda(
                      id: t['id'] as int,
                      nombre: t['nombre'] as String? ?? 'Tienda',
                      icono: Icons.store_rounded,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipTienda({
    required int? id,
    required String nombre,
    required IconData icono,
  }) {
    final sel = _tiendaFiltro == id;
    return GestureDetector(
      onTap: () {
        if (_tiendaFiltro == id) return;
        setState(() {
          _tiendaFiltro = id;
          _abiertas.clear();
          _searchCtrl.clear();
        });
        context.read<InventarioProvider>().cargarProductos(
              tiendaId: id,
              activo: _activoFiltro,
            );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFEAFBF0) : _chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? const Color(0xFFB9E8C8) : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: sel ? _accentDark : _muted),
            const SizedBox(width: 8),
            Text(
              nombre,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: sel ? _accentDark : _text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtroEstado() {
    final opciones = [
      ('true', 'Activos', Icons.check_circle_outline_rounded, _accentDark),
      ('false', 'Inactivos', Icons.block_rounded, _danger),
      ('all', 'Todos', Icons.all_inclusive_rounded, const Color(0xFF475569)),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: opciones.map((op) {
          final (valor, label, icon, color) = op;
          final sel = _activoFiltro == valor;
          return GestureDetector(
            onTap: () {
              setState(() => _activoFiltro = valor);
              context.read<InventarioProvider>().cargarProductos(
                    tiendaId: _tiendaActiva,
                    activo: valor,
                  );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: sel ? color : _muted2),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                      color: sel ? color : _muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategorias(
    Map<String, List<Producto>> grupos,
    bool esCajero,
    bool esAdmin,
    InventarioProvider inv,
  ) {
    final keys = grupos.keys.toList()..sort();
    if (keys.remove('Sin categoría')) keys.add('Sin categoría');

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final cat = keys[i];
        final prods = grupos[cat]!;
        final isOpen = _abiertas.contains(cat);
        final icon = _iconos[i % _iconos.length];
        final bajoCnt = prods.where((p) => p.stockActual > 0 && p.stockActual <= p.stockMinimo).length;
        final agotCnt = prods.where((p) => p.stockActual <= 0).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    isOpen ? _abiertas.remove(cat) : _abiertas.add(cat);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    color: const Color(0xFFFCFCFD),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD7F3DF)),
                          ),
                          child: Icon(icon, color: _accentDark, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat,
                                style: GoogleFonts.plusJakartaSans(
                                  color: _text,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${prods.length} producto${prods.length != 1 ? 's' : ''}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: _muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_activoFiltro != 'false') ...[
                          if (agotCnt > 0) ...[
                            _alertBadge('$agotCnt agotado', const Color(0xFFFFEFEF), _danger),
                            const SizedBox(width: 6),
                          ],
                          if (bajoCnt > 0) ...[
                            _alertBadge('$bajoCnt bajo', const Color(0xFFFFF7E8), _warning),
                            const SizedBox(width: 8),
                          ],
                        ],
                        AnimatedRotation(
                          turns: isOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _chipBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _border),
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _muted,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  child: isOpen
                      ? _buildFilasProductos(prods, esCajero, esAdmin, inv)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _alertBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFilasProductos(
    List<Producto> prods,
    bool esCajero,
    bool esAdmin,
    InventarioProvider inv,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _colHeader('Nombre')),
              Expanded(flex: 2, child: _colHeader('Referencia')),
              if (esAdmin) ...[
                Expanded(flex: 2, child: _colHeader('Costo')),
                Expanded(flex: 2, child: _colHeader('Venta')),
                Expanded(flex: 2, child: _colHeader('Mayoreo')),
                Expanded(flex: 2, child: _colHeader('Margen')),
              ] else
                Expanded(flex: 2, child: _colHeader('Precio')),
              Expanded(flex: 1, child: _colHeader('Stock')),
              Expanded(flex: 2, child: _colHeader('Estado')),
              if (!esCajero) const SizedBox(width: 84),
            ],
          ),
        ),
        ...prods.asMap().entries.map((e) {
          final isLast = e.key == prods.length - 1;
          return _filaProducto(
            e.value,
            inv,
            esCajero,
            esAdmin,
            isLast: isLast,
          );
        }),
      ],
    );
  }

  Widget _colHeader(String t) {
    return Text(
      t,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _muted2,
        letterSpacing: 0.3,
      ),
    );
  }

  String _margenTexto(double costo, double venta) {
    if (costo <= 0) return '—';
    final m = ((venta - costo) / costo) * 100;
    return '${m.toStringAsFixed(1)}%';
  }

  Color _margenColor(double costo, double venta) {
    if (costo <= 0) return _muted2;
    final m = ((venta - costo) / costo) * 100;
    if (m < 0) return _danger;
    if (m < 10) return _warning;
    if (m < 20) return const Color(0xFF2563EB);
    return _accentDark;
  }

  Widget _filaProducto(
    Producto p,
    InventarioProvider inv,
    bool esCajero,
    bool esAdmin, {
    required bool isLast,
  }) {
    final esInactivo = _activoFiltro == 'false';
    final agotado = p.stockActual <= 0;
    final bajo = !agotado && p.stockActual <= p.stockMinimo;

    final (estadoText, estadoColor, estadoBg) = esInactivo
        ? ('Inactivo', _muted, const Color(0xFFF3F4F6))
        : agotado
            ? ('Agotado', _danger, const Color(0xFFFFF1F2))
            : bajo
                ? ('Stock bajo', _warning, const Color(0xFFFFF7ED))
                : ('Disponible', _accentDark, const Color(0xFFF0FDF4));

    final estadoIcon = esInactivo
        ? Icons.block_rounded
        : agotado
            ? Icons.remove_circle_outline_rounded
            : bajo
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded;

    final costo = p.precioCompra;
    final venta = p.precio;
    final mayoreo = p.precioMayoreo;

    return Container(
      decoration: BoxDecoration(
        color: esInactivo ? const Color(0xFFFCFCFC) : Colors.white,
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  if (!esInactivo)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: agotado ? _danger : bajo ? _warning : _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: esInactivo ? _muted2 : _text,
                          ),
                        ),
                        if (p.categoria.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              p.categoria,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: _muted2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                p.referencia.isEmpty ? '—' : p.referencia,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted),
              ),
            ),
            if (esAdmin) ...[
              Expanded(
                flex: 2,
                child: Text(
                  '${Constants.moneda}${costo.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: esInactivo ? _muted2 : _muted,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${Constants.moneda}${venta.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: esInactivo ? _muted2 : _text,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: mayoreo != null && mayoreo > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${Constants.moneda}${mayoreo.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: esInactivo ? _muted2 : _text,
                          ),
                        ),
                      )
                    : Text(
                        '—',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted2),
                      ),
              ),
              Expanded(
                flex: 2,
                child: esInactivo
                    ? Text(
                        '—',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted2),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _margenColor(costo, venta).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              venta >= costo ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: 12,
                              color: _margenColor(costo, venta),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _margenTexto(costo, venta),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _margenColor(costo, venta),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ] else
              Expanded(
                flex: 2,
                child: Text(
                  '${Constants.moneda}${venta.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: esInactivo ? _muted2 : _text,
                  ),
                ),
              ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: esInactivo
                      ? const Color(0xFFF3F4F6)
                      : (agotado || bajo)
                          ? estadoBg
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.stockActual.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: (agotado || bajo) && !esInactivo ? FontWeight.w800 : FontWeight.w700,
                    color: esInactivo
                        ? _muted2
                        : agotado
                            ? _danger
                            : bajo
                                ? _warning
                                : _text,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: estadoBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: estadoColor.withOpacity(0.16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estadoIcon, size: 12, color: estadoColor),
                      const SizedBox(width: 5),
                      Text(
                        estadoText,
                        style: GoogleFonts.plusJakartaSans(
                          color: estadoColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!esCajero)
              SizedBox(
                width: 84,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (esInactivo) ...[
                      if (esAdmin)
                        _actionBtn(
                          icon: Icons.refresh_rounded,
                          color: _accentDark,
                          tooltip: 'Reactivar',
                          onTap: () => _confirmarReactivar(context, inv, p),
                        ),
                    ] else ...[
                      _actionBtn(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF334155),
                        tooltip: 'Editar',
                        onTap: () => _abrirFormulario(context, inv, producto: p),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        icon: Icons.block_rounded,
                        color: _danger,
                        tooltip: 'Desactivar',
                        onTap: () => _confirmarEliminar(context, inv, p),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.10)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _loadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: _accentDark,
                strokeWidth: 2.7,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando inventario…',
            style: GoogleFonts.plusJakartaSans(
              color: _muted,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool esCajero) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _activoFiltro == 'false'
                    ? Icons.check_circle_outline_rounded
                    : Icons.inventory_2_outlined,
                size: 42,
                color: _accentDark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _activoFiltro == 'false' ? 'No hay productos inactivos' : 'No hay productos registrados',
              style: GoogleFonts.plusJakartaSans(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _activoFiltro == 'false'
                  ? 'Todo tu inventario está activo en este momento.'
                  : 'Agrega el primero con el botón de nuevo producto.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: _muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(String msg, {required bool isError, required VoidCallback onClose}) {
    final color = isError ? _danger : _accentDark;
    final bg = isError ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 16, color: color.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFormulario(BuildContext context, InventarioProvider inv, {Producto? producto}) {
    showDialog(
      context: context,
      builder: (_) => ProductoFormDialog(
        producto: producto,
        tiendaId: _tiendaActiva ?? 0,
        empresaId: _empresaActiva,
        onGuardar: (data) async {
          if (_empresaActiva != null) {
            data.putIfAbsent('empresa', () => _empresaActiva!);
          }
          final ok = producto == null
              ? await inv.crearProducto(data)
              : await inv.editarProducto(producto.id, data);
          if (ok && mounted) {
            inv.cargarProductos(tiendaId: _tiendaActiva, activo: _activoFiltro);
          }
        },
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, InventarioProvider inv, Producto p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Desactivar producto',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _text),
        ),
        content: Text(
          '¿Desactivar "${p.nombre}"? No aparecerá en ventas ni búsquedas.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.plusJakartaSans(color: _muted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await inv.eliminarProducto(p.id);
              if (ok && mounted) {
                inv.cargarProductos(tiendaId: _tiendaActiva, activo: _activoFiltro);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Desactivar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarReactivar(BuildContext context, InventarioProvider inv, Producto p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Reactivar producto',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _text),
        ),
        content: Text(
          '¿Reactivar "${p.nombre}"?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.plusJakartaSans(color: _muted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await inv.reactivarProducto(p.id);
              if (ok && mounted) {
                inv.cargarProductos(tiendaId: _tiendaActiva, activo: _activoFiltro);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Reactivar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final Color iconColor;

  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.iconColor,
  });
}
