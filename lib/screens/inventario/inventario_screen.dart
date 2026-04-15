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

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final _searchCtrl     = TextEditingController();
  // ✅ FIX: service como campo — no instanciar en cada llamada
  final _empleadoService = EmpleadoService();

  List<Map<String, dynamic>> _tiendas       = [];
  int?                        _tiendaFiltro;
  final Set<String>           _abiertas     = {};
  String                      _activoFiltro = 'true';

  static const _colores = [
    Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460),
    Color(0xFF1B4332), Color(0xFF533483), Color(0xFF1A535C),
    Color(0xFF2C3E50), Color(0xFF7B2D8B),
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final inv  = context.read<InventarioProvider>();

      if (auth.rol == 'admin') {
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int? get _tiendaActiva {
    final auth = context.read<AuthProvider>();
    if (auth.rol == 'admin') return _tiendaFiltro;
    return auth.tiendaId == 0 ? null : auth.tiendaId;
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
    final esAdmin  = auth.rol == 'admin';
    final grupos   = _agrupar(inv.productos);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        const Color(Constants.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: Color(Constants.primaryColor)),
            ),
            const SizedBox(width: 12),
            Text('Inventario',
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A2E))),

            if (esAdmin && _tiendas.isNotEmpty) ...[
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _tiendaFiltro,
                    icon:  const Icon(Icons.keyboard_arrow_down_rounded),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                    items: _tiendas.map((t) => DropdownMenuItem<int>(
                      value: t['id'],
                      child: Row(children: [
                        const Icon(Icons.store_rounded,
                            size: 16, color: Color(Constants.primaryColor)),
                        const SizedBox(width: 6),
                        Text(t['nombre'] ?? '',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ]),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => _tiendaFiltro = val);
                      context.read<InventarioProvider>().cargarProductos(
                          tiendaId: val, activo: _activoFiltro);
                      _searchCtrl.clear();
                    },
                  ),
                ),
              ),
            ],

            const Spacer(),

            if (!esCajero)
              ElevatedButton.icon(
                icon:  const Icon(Icons.add_rounded),
                label: Text('Nuevo Producto',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onPressed: () => _abrirFormulario(context, inv),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(Constants.primaryColor),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
          ]),
          const SizedBox(height: 16),

          // ── Filtro activo/inactivo/todos ─────────────
          if (!esCajero) ...[
            _filtroEstado(),
            const SizedBox(height: 12),
          ],

          // ── Mensajes ────────────────────────────────
          if (inv.successMsg != null)
            _banner(inv.successMsg!,
                isError: false, onClose: inv.limpiarMensajes),
          if (inv.errorMsg != null)
            _banner(inv.errorMsg!, isError: true, onClose: inv.limpiarMensajes),

          // ── Buscador ────────────────────────────────
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText:   '🔍  Buscar productos...',
              hintStyle:  GoogleFonts.poppins(color: Colors.grey.shade400),
              filled:     true,
              fillColor:  Colors.white,
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(Constants.primaryColor)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(Constants.primaryColor), width: 2)),
            ),
            onChanged: (val) => context.read<InventarioProvider>()
                .cargarProductos(
                    q: val, tiendaId: _tiendaActiva, activo: _activoFiltro),
          ),
          const SizedBox(height: 12),

          // ── Stats ────────────────────────────────────
          if (inv.productos.isNotEmpty) ...[
            _buildStats(inv.productos, grupos.length),
            const SizedBox(height: 16),
          ],

          // ── Contenido ────────────────────────────────
          Expanded(
            child: inv.cargando
                ? const Center(child: CircularProgressIndicator())
                : inv.productos.isEmpty
                    ? _emptyState(esCajero)
                    : _buildCategorias(grupos, esCajero, esAdmin, inv),
          ),
        ],
      ),
    );
  }

  // ── Filtro activo/inactivo/todos ───────────────────
  Widget _filtroEstado() {
    final opciones = [
      ('true',  'Activos',   Icons.check_circle_outline_rounded),
      ('false', 'Inactivos', Icons.block_rounded),
      ('all',   'Todos',     Icons.all_inclusive_rounded),
    ];

    return Row(
      children: opciones.map((op) {
        final (valor, label, icon) = op;
        final seleccionado = _activoFiltro == valor;
        final color = valor == 'false'
            ? Colors.red.shade600
            : valor == 'all'
                ? Colors.blueGrey.shade600
                : const Color(Constants.primaryColor);

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () {
              setState(() => _activoFiltro = valor);
              context.read<InventarioProvider>().cargarProductos(
                  tiendaId: _tiendaActiva, activo: valor);
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: seleccionado ? color.withOpacity(0.12) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: seleccionado ? color : Colors.grey.shade200,
                  width: seleccionado ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14,
                      color: seleccionado ? color : Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize:   12,
                          fontWeight: seleccionado
                              ? FontWeight.w600 : FontWeight.normal,
                          color: seleccionado
                              ? color : Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Stats Bar ──────────────────────────────────────
  Widget _buildStats(List<Producto> productos, int numCats) {
    final bajo    = productos
        .where((p) => p.stockActual > 0 && p.stockActual <= p.stockMinimo)
        .length;
    final agotado = productos.where((p) => p.stockActual <= 0).length;

    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        _chip(Icons.category_rounded,
            '$numCats categoría${numCats != 1 ? 's' : ''}',
            const Color(Constants.primaryColor)),
        _chip(Icons.inventory_2_rounded,
            '${productos.length} productos', const Color(0xFF1A1A2E)),
        if (bajo > 0)
          _chip(Icons.warning_amber_rounded,
              '$bajo stock bajo', Colors.orange.shade700),
        if (agotado > 0)
          _chip(Icons.remove_circle_outline_rounded,
              '$agotado agotado${agotado != 1 ? 's' : ''}',
              Colors.red.shade600),
        if (_activoFiltro == 'false')
          _chip(Icons.block_rounded,
              '${productos.length} inactivos', Colors.grey.shade600),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border:       Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]),
  );

  // ── Lista de categorías ────────────────────────────
  Widget _buildCategorias(Map<String, List<Producto>> grupos,
      bool esCajero, bool esAdmin, InventarioProvider inv) {
    final keys = grupos.keys.toList()..sort();
    if (keys.remove('Sin categoría')) keys.add('Sin categoría');

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final cat     = keys[i];
        final prods   = grupos[cat]!;
        final isOpen  = _abiertas.contains(cat);
        final color   = _colores[i % _colores.length];
        final icon    = _iconos[i % _iconos.length];
        final bajoCnt = prods
            .where((p) => p.stockActual > 0 && p.stockActual <= p.stockMinimo)
            .length;
        final agotCnt = prods.where((p) => p.stockActual <= 0).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: [

              // Cabecera
              InkWell(
                onTap: () => setState(() =>
                    isOpen ? _abiertas.remove(cat) : _abiertas.add(cat)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  color: _activoFiltro == 'false'
                      ? Colors.grey.shade600 : color,
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat,
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          Text(
                            '${prods.length} producto${prods.length != 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12)),
                        ],
                      ),
                    ),
                    if (_activoFiltro != 'false') ...[
                      if (agotCnt > 0) ...[
                        _alertBadge('$agotCnt agotado', Colors.red.shade400),
                        const SizedBox(width: 6),
                      ],
                      if (bajoCnt > 0) ...[
                        _alertBadge('$bajoCnt bajo', Colors.orange.shade400),
                        const SizedBox(width: 10),
                      ],
                    ],
                    AnimatedRotation(
                      turns:    isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ]),
                ),
              ),

              // Productos expandibles
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve:    Curves.easeInOut,
                child: isOpen
                    ? _buildFilasProductos(prods, esCajero, esAdmin, inv)
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _alertBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(10)),
    child: Text(text,
        style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w600)),
  );

  // ── Filas de productos ─────────────────────────────
  Widget _buildFilasProductos(List<Producto> prods, bool esCajero,
      bool esAdmin, InventarioProvider inv) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color:   Colors.grey.shade50,
        child: Row(children: [
          Expanded(flex: 3, child: _colHeader('Nombre')),
          Expanded(flex: 2, child: _colHeader('Referencia')),
          Expanded(flex: 2, child: _colHeader('Precio venta')),
          Expanded(flex: 1, child: _colHeader('Stock')),
          Expanded(flex: 2, child: _colHeader('Estado')),
          if (!esCajero) const SizedBox(width: 80),
        ]),
      ),
      const Divider(height: 1, thickness: 1),
      ...prods.asMap().entries.map((e) {
        final isLast = e.key == prods.length - 1;
        return _filaProducto(e.value, inv, esCajero, esAdmin, isLast: isLast);
      }),
    ]);
  }

  Text _colHeader(String t) => Text(t,
      style: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: Colors.grey.shade500));

  Widget _filaProducto(Producto p, InventarioProvider inv,
      bool esCajero, bool esAdmin, {required bool isLast}) {
    final esInactivo = _activoFiltro == 'false';
    final agotado    = p.stockActual <= 0;
    final bajo       = !agotado && p.stockActual <= p.stockMinimo;

    final estadoText  = esInactivo ? '🚫 Inactivo'
        : agotado     ? '❌ Agotado'
        : bajo        ? '⚠️ Stock bajo'
        : '✅ OK';
    final estadoColor = esInactivo ? Colors.grey.shade600
        : agotado     ? Colors.red.shade700
        : bajo        ? Colors.orange.shade700
        : Colors.green.shade700;
    final estadoBg    = esInactivo ? Colors.grey.shade100
        : agotado     ? Colors.red.shade50
        : bajo        ? Colors.orange.shade50
        : Colors.green.shade50;

    return Container(
      decoration: BoxDecoration(
        color: esInactivo ? Colors.grey.shade50 : Colors.white,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Text(p.nombre,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: esInactivo
                        ? Colors.grey.shade400 : Colors.black87)),
          ),
          Expanded(
            flex: 2,
            child: Text(p.referencia.isEmpty ? '—' : p.referencia,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade500)),
          ),
          Expanded(
            flex: 2,
            child: Text('\$${p.precio.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: esInactivo
                        ? Colors.grey.shade400 : Colors.black87)),
          ),
          Expanded(
            flex: 1,
            child: Text(p.stockActual.toStringAsFixed(0),
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: (agotado || bajo) && !esInactivo
                        ? FontWeight.bold : FontWeight.normal,
                    color: esInactivo   ? Colors.grey.shade400
                        : agotado ? Colors.red.shade700
                        : bajo    ? Colors.orange.shade700
                        : Colors.black87)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    color: estadoBg, borderRadius: BorderRadius.circular(20)),
                child: Text(estadoText,
                    style: GoogleFonts.poppins(
                        color: estadoColor, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          if (!esCajero)
            SizedBox(
              width: 80,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (esInactivo) ...[
                    if (esAdmin)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            size: 18, color: Colors.green),
                        tooltip:     'Reactivar',
                        padding:     EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed:   () => _confirmarReactivar(context, inv, p),
                      ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          size: 17, color: Color(Constants.primaryColor)),
                      tooltip:     'Editar',
                      padding:     EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed:   () => _abrirFormulario(context, inv, producto: p),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.block_rounded,
                          size: 17, color: Colors.redAccent),
                      tooltip:     'Desactivar',
                      padding:     EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed:   () => _confirmarEliminar(context, inv, p),
                    ),
                  ],
                ],
              ),
            ),
        ]),
      ),
    );
  }

  // ── Diálogos ───────────────────────────────────────
  void _abrirFormulario(BuildContext context, InventarioProvider inv,
      {Producto? producto}) {
    showDialog(
      context: context,
      builder: (_) => ProductoFormDialog(
        producto: producto,
        tiendaId: _tiendaActiva ?? 0,
        // ✅ FIX: eliminado guardando — ya no existe en el dialog
        onGuardar: (data) async {
          final ok = producto == null
              ? await inv.crearProducto(data)
              : await inv.editarProducto(producto.id, data);

          // ✅ FIX: lanza si falla → dialog desbloquea botón y no hace pop
          // ✅ FIX: eliminado Navigator.pop → el dialog lo hace al éxito
          if (!ok) throw Exception(inv.errorMsg ?? 'Error al guardar');
        },
      ),
    );
  }

  void _confirmarEliminar(
      BuildContext context, InventarioProvider inv, Producto p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Desactivar producto?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'Se desactivará "${p.nombre}" del inventario. '
            'Podrás reactivarlo luego desde la vista de inactivos.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            icon:  const Icon(Icons.block_rounded, size: 16),
            label: Text('Desactivar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await inv.eliminarProducto(p.id);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('❌ No se pudo desactivar "${p.nombre}"',
                      style: GoogleFonts.poppins(fontSize: 13)),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarReactivar(
      BuildContext context, InventarioProvider inv, Producto p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Reactivar producto?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            '"${p.nombre}" volverá a estar disponible en el inventario.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            icon:  const Icon(Icons.refresh_rounded, size: 16),
            label: Text('Reactivar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await inv.reactivarProducto(p.id);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('❌ No se pudo reactivar "${p.nombre}"',
                      style: GoogleFonts.poppins(fontSize: 13)),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool esCajero) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _activoFiltro == 'false'
              ? Icons.check_circle_outline_rounded
              : Icons.inventory_2_outlined,
          size: 72, color: Colors.grey.shade300,
        ),
        const SizedBox(height: 12),
        Text(
          _activoFiltro == 'false'
              ? 'No hay productos inactivos 🎉'
              : 'No hay productos en esta tienda',
          style: GoogleFonts.poppins(
              color: Colors.grey.shade400, fontSize: 16),
        ),
        if (!esCajero && _activoFiltro != 'false') ...[
          const SizedBox(height: 8),
          Text('Haz clic en "Nuevo Producto" para agregar el primero',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 13)),
        ],
      ],
    ),
  );

  Widget _banner(String msg,
      {required bool isError, required VoidCallback onClose}) =>
    Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? const Color(Constants.errorColor).withOpacity(0.1)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isError
                ? const Color(Constants.errorColor).withOpacity(0.3)
                : Colors.green.shade200),
      ),
      child: Row(children: [
        Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError
              ? const Color(Constants.errorColor) : Colors.green.shade700,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.poppins(
                  color: isError
                      ? const Color(Constants.errorColor)
                      : Colors.green.shade700,
                  fontSize: 13)),
        ),
        IconButton(
          icon:      const Icon(Icons.close_rounded, size: 16),
          onPressed: onClose,
          color:     Colors.grey,
        ),
      ]),
    );
}