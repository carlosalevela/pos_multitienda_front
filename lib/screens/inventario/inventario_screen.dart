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
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _tiendas      = [];
  int?                        _tiendaFiltro;
  final Set<String>           _abiertas    = {}; // categorías expandidas

  // Paleta de colores para las tarjetas de categoría
  static const _colores = [
    Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460),
    Color(0xFF1B4332), Color(0xFF533483), Color(0xFF1A535C),
    Color(0xFF2C3E50), Color(0xFF7B2D8B),
  ];

  static const _iconos = [
    Icons.category_rounded,       Icons.shopping_bag_rounded,
    Icons.inventory_2_rounded,    Icons.local_offer_rounded,
    Icons.storefront_rounded,     Icons.label_rounded,
    Icons.star_rounded,           Icons.folder_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final inv  = context.read<InventarioProvider>();

      if (auth.rol == 'admin') {
        final tiendas = await EmpleadoService().getTiendas();
        setState(() {
          _tiendas      = tiendas;
          _tiendaFiltro = tiendas.isNotEmpty ? tiendas.first['id'] : null;
        });
        inv.cargarProductos(tiendaId: _tiendaFiltro);
      } else {
        inv.cargarProductos(
            tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId);
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
      final cat = (p.categoria.isEmpty || p.categoria == 'null' ||
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
                color: const Color(Constants.primaryColor).withOpacity(0.1),
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
                  color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _tiendaFiltro,
                    icon:  const Icon(Icons.keyboard_arrow_down_rounded),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                    items: _tiendas.map((t) => DropdownMenuItem<int>(
                      value: t['id'],
                      child: Row(children: [
                        const Icon(Icons.store_rounded, size: 16,
                            color: Color(Constants.primaryColor)),
                        const SizedBox(width: 6),
                        Text(t['nombre'] ?? '',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ]),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => _tiendaFiltro = val);
                      inv.cargarProductos(tiendaId: val);
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0),
              ),
          ]),
          const SizedBox(height: 20),

          // ── Mensajes ────────────────────────────────
          if (inv.successMsg.isNotEmpty)
            _banner(inv.successMsg,
                isError: false, onClose: inv.limpiarMensajes),
          if (inv.errorMsg.isNotEmpty)
            _banner(inv.errorMsg,
                isError: true, onClose: inv.limpiarMensajes),

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
            onChanged: (val) =>
                inv.cargarProductos(q: val, tiendaId: _tiendaActiva),
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
                    : _buildCategorias(grupos, esCajero, inv),
          ),
        ],
      ),
    );
  }

  // ── Stats Bar ──────────────────────────────────────
  Widget _buildStats(List<Producto> productos, int numCats) {
    final bajo    = productos.where((p) =>
        p.stockActual > 0 && p.stockActual <= p.stockMinimo).length;
    final agotado = productos.where((p) => p.stockActual <= 0).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(Icons.category_rounded,
            '$numCats categoría${numCats != 1 ? 's' : ''}',
            const Color(Constants.primaryColor)),
        _chip(Icons.inventory_2_rounded,
            '${productos.length} productos',
            const Color(0xFF1A1A2E)),
        if (bajo > 0)
          _chip(Icons.warning_amber_rounded,
              '$bajo stock bajo', Colors.orange.shade700),
        if (agotado > 0)
          _chip(Icons.remove_circle_outline_rounded,
              '$agotado agotado${agotado != 1 ? 's' : ''}',
              Colors.red.shade600),
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
  Widget _buildCategorias(
    Map<String, List<Producto>> grupos, bool esCajero,
    InventarioProvider inv) {

    final keys = grupos.keys.toList()..sort();
    if (keys.remove('Sin categoría')) keys.add('Sin categoría');

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final cat      = keys[i];
        final prods    = grupos[cat]!;
        final isOpen   = _abiertas.contains(cat);
        final color    = _colores[i % _colores.length];
        final icon     = _iconos[i % _iconos.length];
        final bajoCnt  = prods.where(
            (p) => p.stockActual > 0 && p.stockActual <= p.stockMinimo).length;
        final agotCnt  = prods.where((p) => p.stockActual <= 0).length;

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

              // ── Cabecera de categoría ──────────────
              InkWell(
                onTap: () => setState(() =>
                    isOpen ? _abiertas.remove(cat) : _abiertas.add(cat)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  color: color,
                  child: Row(children: [

                    // Icono
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),

                    // Nombre + conteo
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

                    // Badges de alerta
                    if (agotCnt > 0) ...[
                      _alertBadge('$agotCnt agotado', Colors.red.shade400),
                      const SizedBox(width: 6),
                    ],
                    if (bajoCnt > 0) ...[
                      _alertBadge('$bajoCnt bajo', Colors.orange.shade400),
                      const SizedBox(width: 10),
                    ],

                    // Flecha animada
                    AnimatedRotation(
                      turns:    isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 22),
                    ),
                  ]),
                ),
              ),

              // ── Productos (expandible) ─────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve:    Curves.easeInOut,
                child: isOpen
                    ? _buildFilasProductos(prods, esCajero, inv)
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
      color:        color,
      borderRadius: BorderRadius.circular(10)),
    child: Text(text,
      style: GoogleFonts.poppins(
        color: Colors.white, fontSize: 11,
        fontWeight: FontWeight.w600)),
  );

  // ── Filas de productos dentro de la categoría ──────
  Widget _buildFilasProductos(
    List<Producto> prods, bool esCajero, InventarioProvider inv) {

    return Column(children: [
      // Encabezado de columnas
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: Colors.grey.shade50,
        child: Row(children: [
          Expanded(flex: 3,
              child: _colHeader('Nombre')),
          Expanded(flex: 2,
              child: _colHeader('Referencia')),
          Expanded(flex: 2,
              child: _colHeader('Precio venta')),
          Expanded(flex: 1,
              child: _colHeader('Stock')),
          Expanded(flex: 2,
              child: _colHeader('Estado')),
          if (!esCajero)
            const SizedBox(width: 72),
        ]),
      ),
      const Divider(height: 1, thickness: 1),

      // Filas
      ...prods.asMap().entries.map((e) {
        final isLast = e.key == prods.length - 1;
        return _filaProducto(e.value, inv, esCajero, isLast: isLast);
      }),
    ]);
  }

  Text _colHeader(String t) => Text(t,
    style: GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: Colors.grey.shade500));

  Widget _filaProducto(
    Producto p, InventarioProvider inv, bool esCajero,
    {required bool isLast}) {

    final agotado = p.stockActual <= 0;
    final bajo    = !agotado && p.stockActual <= p.stockMinimo;

    final estadoText  = agotado ? '❌ Agotado'
        : bajo ? '⚠️ Stock bajo' : '✅ OK';
    final estadoColor = agotado ? Colors.red.shade700
        : bajo ? Colors.orange.shade700 : Colors.green.shade700;
    final estadoBg    = agotado ? Colors.red.shade50
        : bajo ? Colors.orange.shade50 : Colors.green.shade50;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast ? null : Border(
            bottom: BorderSide(color: Colors.grey.shade100))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(children: [
          // Nombre
          Expanded(flex: 3, child: Text(p.nombre,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 13))),

          // Referencia
          Expanded(flex: 2, child: Text(
            p.referencia.isEmpty ? '—' : p.referencia,
            style: GoogleFonts.poppins(
              fontSize: 13, color: Colors.grey.shade500))),

          // Precio
          Expanded(flex: 2, child: Text(
            '\$${p.precio.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600))),

          // Stock
          Expanded(flex: 1, child: Text(
            p.stockActual.toStringAsFixed(0),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: (agotado || bajo)
                  ? FontWeight.bold : FontWeight.normal,
              color: agotado ? Colors.red.shade700
                  : bajo ? Colors.orange.shade700 : Colors.black87))),

          // Estado badge
          Expanded(flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color:        estadoBg,
                  borderRadius: BorderRadius.circular(20)),
                child: Text(estadoText,
                  style: GoogleFonts.poppins(
                    color: estadoColor, fontSize: 11,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          // Acciones
          if (!esCajero)
            SizedBox(
              width: 72,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 17,
                        color: Color(Constants.primaryColor)),
                    tooltip:    'Editar',
                    padding:    EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        _abrirFormulario(context, inv, producto: p),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 17, color: Colors.redAccent),
                    tooltip:    'Eliminar',
                    padding:    EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        _confirmarEliminar(context, inv, p),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────
  void _abrirFormulario(BuildContext context, InventarioProvider inv,
      {Producto? producto}) {
    showDialog(
      context: context,
      builder: (_) => ProductoFormDialog(
        producto:  producto,
        tiendaId:  _tiendaActiva ?? 0,
        onGuardar: (data) async {
          final ok = producto == null
              ? await inv.crearProducto(data)
              : await inv.editarProducto(producto.id, data);
          if (ok && context.mounted) Navigator.pop(context);
        },
        guardando: inv.guardando,
      ),
    );
  }

  void _confirmarEliminar(
    BuildContext context, InventarioProvider inv, Producto p) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Text('¿Eliminar producto?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Text('Se desactivará "${p.nombre}" del inventario.',
          style: GoogleFonts.poppins(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);

            // ✅ Ahora sí espera la respuesta real del backend
            final ok = await inv.eliminarProducto(p.id);

            if (!context.mounted) return;

            if (ok) {
              // ✅ Solo recarga si el backend confirmó el delete
              inv.cargarProductos(tiendaId: _tiendaActiva);
            } else {
              // ✅ Avisa al usuario si falló
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '❌ No se pudo eliminar "${p.nombre}"',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8))),
          child: const Text('Eliminar')),
      ],
    ),
  );
}

  Widget _emptyState(bool esCajero) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined,
            size: 72, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No hay productos en esta tienda',
          style: GoogleFonts.poppins(
              color: Colors.grey.shade400, fontSize: 16)),
        if (!esCajero) ...[
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
              : Colors.green.shade200)),
      child: Row(children: [
        Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError
              ? const Color(Constants.errorColor)
              : Colors.green.shade700,
          size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
            style: GoogleFonts.poppins(
              color: isError
                  ? const Color(Constants.errorColor)
                  : Colors.green.shade700,
              fontSize: 13))),
        IconButton(
          icon:      const Icon(Icons.close_rounded, size: 16),
          onPressed: onClose,
          color:     Colors.grey),
      ]),
    );
}