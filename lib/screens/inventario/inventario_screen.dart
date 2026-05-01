// lib/screens/inventario/inventario_screen.dart

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
  final _searchCtrl      = TextEditingController();
  final _empleadoService = EmpleadoService();

  List<Map<String, dynamic>> _tiendas       = [];
  int?                        _tiendaFiltro;
  final Set<String>           _abiertas     = {};
  String                      _activoFiltro = 'true';

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  static const _gradientes = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
    [Color(0xFFF97316), Color(0xFFEF4444)],
  ];

  static const _iconos = [
    Icons.category_rounded,    Icons.shopping_bag_rounded,
    Icons.inventory_2_rounded, Icons.local_offer_rounded,
    Icons.storefront_rounded,  Icons.label_rounded,
    Icons.star_rounded,        Icons.folder_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
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
    });
  }

  void _abrirImportarExcel(InventarioProvider inv) async {
    final importo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportarExcelDialog(
        tiendaId:     _tiendaActiva ?? 0,
        empresaId:    _empresaActiva,
        nombreTienda: _nombreTiendaActual(),
      ),
    );
    if (importo == true && mounted) {
      inv.cargarProductos(
        tiendaId: _tiendaActiva,
        activo:   _activoFiltro,
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
    if (raw is int)    return raw;
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
    final inv      = context.watch<InventarioProvider>();
    final auth     = context.watch<AuthProvider>();
    final esCajero = auth.rol == 'cajero';
    final esAdmin  = auth.rol == 'admin' || auth.rol == 'superadmin';
    final grupos   = _agrupar(inv.productos);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: const Color(0xFFF8F9FC),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(esCajero, esAdmin, inv),
              const SizedBox(height: 20),

              if (esAdmin && _tiendas.isNotEmpty) ...[
                _selectorTienda(),
                const SizedBox(height: 16),
              ],

              if (inv.productos.isNotEmpty) ...[
                _buildStatsRow(inv.productos, grupos.length),
                const SizedBox(height: 20),
              ],

              _buildToolbar(esCajero, inv),
              const SizedBox(height: 16),

              if (inv.successMsg != null)
                _banner(inv.successMsg!, isError: false,
                    onClose: inv.limpiarMensajes),
              if (inv.errorMsg != null)
                _banner(inv.errorMsg!, isError: true,
                    onClose: inv.limpiarMensajes),

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

  // ══════════════════════════════════════════════════
  // HEADER — ✅ FIX: botón Importar Excel con colores visibles
  // ══════════════════════════════════════════════════
  Widget _buildHeader(bool esCajero, bool esAdmin, InventarioProvider inv) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.35),
                blurRadius: 12, offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.inventory_2_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventario',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5)),
              if (esAdmin)
                Text(
                  _tiendas.isEmpty ? 'Cargando tiendas…' : _nombreTiendaActual(),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF6366F1),
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),

        // ✅ FIX: colores visibles sobre fondo claro #F8F9FC
        if (!esCajero) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.table_chart_rounded, size: 16),
            label: Text('Importar Excel',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () => _abrirImportarExcel(inv),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),          // ← indigo visible
              side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 10),
        ],

        if (!esCajero)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.35),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Nuevo Producto',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              onPressed: () => _abrirFormulario(context, inv),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════
  // STATS ROW
  // ══════════════════════════════════════════════════
  Widget _buildStatsRow(List<Producto> productos, int numCats) {
    final bajo    = productos
        .where((p) => p.stockActual > 0 && p.stockActual <= p.stockMinimo)
        .length;
    final agotado = productos.where((p) => p.stockActual <= 0).length;

    final stats = [
      _StatData(
        icon:   Icons.category_rounded,
        label:  'Categorías',
        value:  '$numCats',
        colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      ),
      _StatData(
        icon:   Icons.inventory_2_rounded,
        label:  'Productos',
        value:  '${productos.length}',
        colors: [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
      ),
      if (bajo > 0)
        _StatData(
          icon:   Icons.warning_amber_rounded,
          label:  'Stock bajo',
          value:  '$bajo',
          colors: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
        ),
      if (agotado > 0)
        _StatData(
          icon:   Icons.remove_circle_outline_rounded,
          label:  'Agotados',
          value:  '$agotado',
          colors: [const Color(0xFFEF4444), const Color(0xFFEC4899)],
        ),
    ];

    return SizedBox(
      height: 88,
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
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: s.colors),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(s.icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.value,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A), height: 1)),
            Text(s.label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // TOOLBAR
  // ══════════════════════════════════════════════════
  Widget _buildToolbar(bool esCajero, InventarioProvider inv) {
    return Row(children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Buscar productos…',
              hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFCBD5E1), fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF6366F1), size: 20),
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            onChanged: (val) => context.read<InventarioProvider>()
                .cargarProductos(
                    q: val, tiendaId: _tiendaActiva, activo: _activoFiltro),
          ),
        ),
      ),
      if (!esCajero) ...[
        const SizedBox(width: 12),
        _filtroEstado(),
      ],
    ]);
  }

  // ══════════════════════════════════════════════════
  // SELECTOR DE TIENDA
  // ══════════════════════════════════════════════════
  Widget _selectorTienda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text('Tienda',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B), letterSpacing: 0.5)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipTienda({
    required int?     id,
    required String   nombre,
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
            tiendaId: id, activo: _activoFiltro);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: sel
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
              : null,
          color: sel ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (sel)
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 10, offset: const Offset(0, 4))
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6, offset: const Offset(0, 2)),
          ],
          border: sel ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono,
              size: 15,
              color: sel ? Colors.white : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text(nombre,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : const Color(0xFF475569))),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // FILTRO ESTADO
  // ══════════════════════════════════════════════════
  Widget _filtroEstado() {
    final opciones = [
      ('true',  'Activos',   Icons.check_circle_outline_rounded,
          const Color(0xFF10B981)),
      ('false', 'Inactivos', Icons.block_rounded,
          const Color(0xFFEF4444)),
      ('all',   'Todos',     Icons.all_inclusive_rounded,
          const Color(0xFF6366F1)),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
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
                  tiendaId: _tiendaActiva, activo: valor);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? color.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14,
                    color: sel ? color : const Color(0xFFCBD5E1)),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? color : const Color(0xFF94A3B8))),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // LISTA DE CATEGORÍAS
  // ══════════════════════════════════════════════════
  Widget _buildCategorias(Map<String, List<Producto>> grupos,
      bool esCajero, bool esAdmin, InventarioProvider inv) {
    final keys = grupos.keys.toList()..sort();
    if (keys.remove('Sin categoría')) keys.add('Sin categoría');

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final cat   = keys[i];
        final prods = grupos[cat]!;
        final isOpen  = _abiertas.contains(cat);
        final g1 = _gradientes[i % _gradientes.length][0];
        final g2 = _gradientes[i % _gradientes.length][1];
        final icon   = _iconos[i % _iconos.length];
        final bajoCnt = prods
            .where((p) => p.stockActual > 0 && p.stockActual <= p.stockMinimo)
            .length;
        final agotCnt = prods.where((p) => p.stockActual <= 0).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.06),
                blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(children: [
              InkWell(
                onTap: () => setState(() =>
                    isOpen ? _abiertas.remove(cat) : _abiertas.add(cat)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: _activoFiltro == 'false'
                        ? LinearGradient(colors: [
                            Colors.grey.shade500, Colors.grey.shade600])
                        : LinearGradient(
                            colors: [g1, g2],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat,
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15, letterSpacing: -0.2)),
                          Text(
                            '${prods.length} producto${prods.length != 1 ? 's' : ''}',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (_activoFiltro != 'false') ...[
                      if (agotCnt > 0) ...[
                        _alertBadge('$agotCnt agotado', Colors.red.shade300),
                        const SizedBox(width: 6),
                      ],
                      if (bajoCnt > 0) ...[
                        _alertBadge('$bajoCnt bajo', Colors.orange.shade300),
                        const SizedBox(width: 10),
                      ],
                    ],
                    AnimatedRotation(
                      turns:    isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: isOpen
                    ? _buildFilasProductos(prods, esCajero, esAdmin, inv, g1)
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _alertBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5))),
    child: Text(text,
        style: GoogleFonts.plusJakartaSans(
            color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w700)),
  );

  // ══════════════════════════════════════════════════
  // FILAS DE PRODUCTOS
  // ══════════════════════════════════════════════════
  Widget _buildFilasProductos(List<Producto> prods, bool esCajero,
      bool esAdmin, InventarioProvider inv, Color accentColor) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.04),
          border: Border(
            bottom: BorderSide(color: accentColor.withOpacity(0.1)),
          ),
        ),
        child: Row(children: [
          Expanded(flex: 3, child: _colHeader('Nombre')),
          Expanded(flex: 2, child: _colHeader('Referencia')),
          Expanded(flex: 2, child: _colHeader('Precio')),
          Expanded(flex: 1, child: _colHeader('Stock')),
          Expanded(flex: 2, child: _colHeader('Estado')),
          if (!esCajero) const SizedBox(width: 76),
        ]),
      ),
      ...prods.asMap().entries.map((e) {
        final isLast = e.key == prods.length - 1;
        return _filaProducto(e.value, inv, esCajero, esAdmin,
            accentColor: accentColor, isLast: isLast);
      }),
    ]);
  }

  Widget _colHeader(String t) => Text(t,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8), letterSpacing: 0.4));

  Widget _filaProducto(Producto p, InventarioProvider inv,
      bool esCajero, bool esAdmin,
      {required Color accentColor, required bool isLast}) {
    final esInactivo = _activoFiltro == 'false';
    final agotado    = p.stockActual <= 0;
    final bajo       = !agotado && p.stockActual <= p.stockMinimo;

    final (estadoText, estadoColor, estadoBg) = esInactivo
        ? ('Inactivo', const Color(0xFF94A3B8), const Color(0xFFF1F5F9))
        : agotado
            ? ('Agotado', const Color(0xFFEF4444), const Color(0xFFFEF2F2))
            : bajo
                ? ('Stock bajo', const Color(0xFFF59E0B), const Color(0xFFFFFBEB))
                : ('Disponible', const Color(0xFF10B981), const Color(0xFFF0FDF4));

    final estadoIcon = esInactivo
        ? Icons.block_rounded
        : agotado ? Icons.remove_circle_outline_rounded
        : bajo ? Icons.warning_amber_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      decoration: BoxDecoration(
        color: esInactivo ? const Color(0xFFFAFAFA) : Colors.white,
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: InkWell(
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Row(children: [
                if (!esInactivo)
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: agotado
                          ? const Color(0xFFEF4444)
                          : bajo
                              ? const Color(0xFFF59E0B)
                              : accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(p.nombre,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: esInactivo
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF1E293B))),
                ),
              ]),
            ),
            Expanded(
              flex: 2,
              child: Text(p.referencia.isEmpty ? '—' : p.referencia,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: const Color(0xFF94A3B8))),
            ),
            Expanded(
              flex: 2,
              child: Text('\$${p.precio.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: esInactivo
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF1E293B))),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: esInactivo
                      ? const Color(0xFFF1F5F9)
                      : (agotado || bajo)
                          ? estadoBg
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.stockActual.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: (agotado || bajo) && !esInactivo
                          ? FontWeight.w800 : FontWeight.w600,
                      color: esInactivo
                          ? const Color(0xFFCBD5E1)
                          : agotado ? const Color(0xFFEF4444)
                          : bajo ? const Color(0xFFF59E0B)
                          : const Color(0xFF64748B))),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: estadoBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: estadoColor.withOpacity(0.2))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estadoIcon, size: 11, color: estadoColor),
                      const SizedBox(width: 5),
                      Text(estadoText,
                          style: GoogleFonts.plusJakartaSans(
                              color: estadoColor, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            if (!esCajero)
              SizedBox(
                width: 76,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (esInactivo) ...[
                      if (esAdmin)
                        _actionBtn(
                          icon: Icons.refresh_rounded,
                          color: const Color(0xFF10B981),
                          tooltip: 'Reactivar',
                          onTap: () => _confirmarReactivar(context, inv, p),
                        ),
                    ] else ...[
                      _actionBtn(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF6366F1),
                        tooltip: 'Editar',
                        onTap: () => _abrirFormulario(context, inv, producto: p),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        icon: Icons.block_rounded,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Desactivar',
                        onTap: () => _confirmarEliminar(context, inv, p),
                      ),
                    ],
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color    color,
    required String   tooltip,
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
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );

  // ══════════════════════════════════════════════════
  // LOADING STATE
  // ══════════════════════════════════════════════════
  Widget _loadingState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
          ),
        ),
        const SizedBox(height: 16),
        Text('Cargando inventario…',
            style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    ),
  );

  // ══════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════
  Widget _emptyState(bool esCajero) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            _activoFiltro == 'false'
                ? Icons.check_circle_outline_rounded
                : Icons.inventory_2_outlined,
            size: 44, color: const Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _activoFiltro == 'false'
              ? '¡Sin productos inactivos!'
              : 'No hay productos aquí',
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF475569),
              fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _activoFiltro == 'false'
              ? 'Todo tu inventario está activo 🎉'
              : 'Agrega el primero con "Nuevo Producto"',
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8), fontSize: 13),
        ),
      ],
    ),
  );

  // ══════════════════════════════════════════════════
  // BANNER DE MENSAJES
  // ══════════════════════════════════════════════════
  Widget _banner(String msg,
      {required bool isError, required VoidCallback onClose}) {
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Container(
      margin:  const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isError ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
            color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.plusJakartaSans(
                  color: color.withOpacity(0.85),
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 16,
                color: color.withOpacity(0.5)),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // DIÁLOGOS
  // ══════════════════════════════════════════════════
  void _abrirFormulario(BuildContext context, InventarioProvider inv,
      {Producto? producto}) {
    showDialog(
      context: context,
      builder: (_) => ProductoFormDialog(
        producto:  producto,
        tiendaId:  _tiendaActiva ?? 0,
        empresaId: _empresaActiva,
        onGuardar: (data) async {
          if (_empresaActiva != null) {
            data.putIfAbsent('empresa', () => _empresaActiva!);
          }
          final ok = producto == null
              ? await inv.crearProducto(data)
              : await inv.editarProducto(producto.id, data);
          if (!ok) throw Exception(inv.errorMsg ?? 'Error al guardar');
        },
      ),
    );
  }

  void _confirmarEliminar(
      BuildContext context, InventarioProvider inv, Producto p) {
    showDialog(
      context: context,
      builder: (_) => _dialogConfirmacion(
        titulo:   '¿Desactivar producto?',
        mensaje:  '"${p.nombre}" quedará inactivo. Podrás reactivarlo luego.',
        labelOk:  'Desactivar',
        colorOk:  const Color(0xFFEF4444),
        iconOk:   Icons.block_rounded,
        onOk: () async {
          Navigator.pop(context);
          final ok = await inv.eliminarProducto(p.id);
          if (!context.mounted || ok) return;
          _showSnack(context,
              '❌ No se pudo desactivar "${p.nombre}"', isError: true);
        },
      ),
    );
  }

  void _confirmarReactivar(
      BuildContext context, InventarioProvider inv, Producto p) {
    showDialog(
      context: context,
      builder: (_) => _dialogConfirmacion(
        titulo:  '¿Reactivar producto?',
        mensaje: '"${p.nombre}" volverá a estar disponible.',
        labelOk: 'Reactivar',
        colorOk: const Color(0xFF10B981),
        iconOk:  Icons.refresh_rounded,
        onOk: () async {
          Navigator.pop(context);
          final ok = await inv.reactivarProducto(p.id);
          if (!context.mounted || ok) return;
          _showSnack(context,
              '❌ No se pudo reactivar "${p.nombre}"', isError: true);
        },
      ),
    );
  }

  Widget _dialogConfirmacion({
    required String       titulo,
    required String       mensaje,
    required String       labelOk,
    required Color        colorOk,
    required IconData     iconOk,
    required VoidCallback onOk,
  }) =>
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      titlePadding:   const EdgeInsets.fromLTRB(24, 24, 24, 12),
      title: Text(titulo,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, fontSize: 17,
              color: const Color(0xFF0F172A))),
      content: Text(mensaje,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: const Color(0xFF64748B))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600)),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorOk.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
          child: TextButton.icon(
            icon:  Icon(iconOk, size: 16, color: colorOk),
            label: Text(labelOk,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: colorOk)),
            onPressed: onOk,
          ),
        ),
      ],
    );

  void _showSnack(BuildContext ctx, String msg, {required bool isError}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.plusJakartaSans(fontSize: 13)),
      backgroundColor: isError
          ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ── Modelo de dato para stats ──────────────────────
class _StatData {
  final IconData    icon;
  final String      label;
  final String      value;
  final List<Color> colors;
  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });
}
