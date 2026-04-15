// lib/screens/devoluciones/widgets/devolucion_producto_sheet.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pos_multitienda_app/providers/auth_provider.dart';
import 'package:pos_multitienda_app/services/inventario_service.dart';

// ── Modelo interno ────────────────────────────────────
class _ItemCarrito {
  final int    id;
  final String nombre;
  final double precio;
  int          cantidad;

  _ItemCarrito({
    required this.id,
    required this.nombre,
    required this.precio,
    this.cantidad = 1,
  });

  double get subtotal => precio * cantidad;
}

// ── Widget principal ──────────────────────────────────
class DevolucionProductoSheet extends StatefulWidget {
  final double       totalDevuelto;
  final AuthProvider auth;           // ✅ solo auth, sin callback ni tiendaId suelto

  const DevolucionProductoSheet({
    super.key,
    required this.totalDevuelto,
    required this.auth,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required double       totalDevuelto,
    required AuthProvider auth,
  }) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context:             context,
      isScrollControlled:  true,
      backgroundColor:     Colors.transparent,
      builder: (_) => DevolucionProductoSheet(
        totalDevuelto: totalDevuelto,
        auth:          auth,
      ),
    );

  @override
  State<DevolucionProductoSheet> createState() =>
      _DevolucionProductoSheetState();
}

class _DevolucionProductoSheetState
    extends State<DevolucionProductoSheet> {

  final _inventarioService = InventarioService();
  final _searchCtrl        = TextEditingController();

  List<Map<String, dynamic>> _productos     = [];
  List<Map<String, dynamic>> _productosFilt = [];
  final List<_ItemCarrito>   _carrito       = [];
  bool   _cargando = true;
  String? _errorMsg;

  static const _azul    = Color(0xFF1565C0);
  static const _verde   = Color(0xFF2E7D32);
  static const _naranja = Color(0xFFE65100);
  static const _dark    = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ✅ usa auth.tiendaId internamente — sin callback ni parámetro suelto
  Future<void> _cargarProductos() async {
    setState(() { _cargando = true; _errorMsg = null; });
    try {
      final lista = await _inventarioService.getProductos(
        tiendaId: widget.auth.tiendaId,
        activo:   'true',
      );
      if (!mounted) return;
      setState(() {
        _productos = lista.map((p) => {
          'id':     p.id,
          'nombre': p.nombre,
          'precio': p.precio,
          'stock':  p.stockActual,
        }).toList();
        _productosFilt = _productos;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _productosFilt = q.isEmpty
          ? _productos
          : _productos.where((p) =>
              (p['nombre'] as String)
                  .toLowerCase()
                  .contains(q)).toList();
    });
  }

  // ── carrito ───────────────────────────────────────────
  void _agregar(Map<String, dynamic> p) {
    setState(() {
      final idx = _carrito.indexWhere(
          (c) => c.id == p['id'] as int);
      if (idx >= 0) {
        _carrito[idx].cantidad++;
      } else {
        _carrito.add(_ItemCarrito(
          id:     p['id'] as int,
          nombre: p['nombre'] as String,
          precio: double.tryParse(p['precio'].toString()) ?? 0,
        ));
      }
    });
  }

  void _quitar(int id) {
    setState(() {
      final idx = _carrito.indexWhere((c) => c.id == id);
      if (idx < 0) return;
      if (_carrito[idx].cantidad > 1) {
        _carrito[idx].cantidad--;
      } else {
        _carrito.removeAt(idx);
      }
    });
  }

  // ── totales ───────────────────────────────────────────
  double get _totalNuevo =>
      _carrito.fold(0, (s, c) => s + c.subtotal);

  double get _diferencia => _totalNuevo - widget.totalDevuelto;

  // ── confirmar ─────────────────────────────────────────
  void _confirmar() {
    if (_carrito.isEmpty) return;
    Navigator.pop(context, {
      'productos': _carrito.map((c) => {
        'producto_id': c.id,
        'nombre':      c.nombre,
        'cantidad':    c.cantidad,
        'precio':      c.precio,
        'subtotal':    c.subtotal,
      }).toList(),
      'total_nuevo': _totalNuevo,
      'diferencia':  _diferencia,
    });
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [

        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
          ),
        ),

        _buildHeader(),
        _buildBuscador(),

        // ── error de carga ──────────────────────────────
        if (_errorMsg != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded,
                  size: 16, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Expanded(child: Text(_errorMsg!,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.red.shade600))),
              GestureDetector(
                onTap: _cargarProductos,
                child: Text('Reintentar',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade600)),
              ),
            ]),
          ),

        Expanded(
          child: Row(children: [
            Expanded(
              flex: 3,
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _buildInventario(),
            ),
            SizedBox(width: 280, child: _buildCarrito()),
          ]),
        ),

      ]),
    );
  }

  // ── Header ────────────────────────────────────────────
  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _azul.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.swap_horiz_rounded,
            color: _azul, size: 22),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cambio de producto',
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: _dark)),
        Text('Crédito disponible: \$${_fmt(widget.totalDevuelto)}',
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade500)),
      ]),
      const Spacer(),
      IconButton(
        icon: const Icon(Icons.close_rounded),
        color: Colors.grey.shade500,
        onPressed: () => Navigator.pop(context),
      ),
    ]),
  );

  // ── Buscador ──────────────────────────────────────────
  Widget _buildBuscador() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar producto por nombre...',
        hintStyle: GoogleFonts.poppins(
            fontSize: 13, color: Colors.grey.shade400),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 18, color: Colors.grey),
        filled:    true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _azul, width: 1.5)),
      ),
    ),
  );

  // ── Inventario ────────────────────────────────────────
  Widget _buildInventario() {
    if (_productosFilt.isEmpty) {
      return Center(child: Text('Sin resultados',
        style: GoogleFonts.poppins(color: Colors.grey.shade400)));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio:   0.78,
        crossAxisSpacing:   10,
        mainAxisSpacing:    10,
      ),
      itemCount: _productosFilt.length,
      itemBuilder: (_, i) => _ProductoCard(
        producto:  _productosFilt[i],
        enCarrito: _carrito.firstWhere(
          (c) => c.id == _productosFilt[i]['id'],
          orElse: () => _ItemCarrito(id: -1, nombre: '', precio: 0),
        ).cantidad,
        onAdd: () => _agregar(_productosFilt[i]),
      ),
    );
  }

  // ── Carrito ───────────────────────────────────────────
  Widget _buildCarrito() => Container(
    margin: const EdgeInsets.fromLTRB(0, 4, 12, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(children: [

      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Row(children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 16, color: _dark),
          const SizedBox(width: 8),
          Text('Productos nuevos',
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _dark)),
        ]),
      ),
      const Divider(height: 1),

      Expanded(
        child: _carrito.isEmpty
            ? Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_shopping_cart_rounded,
                      size: 36, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Text('Añade productos\ndel inventario',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade400)),
                ]))
            : ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: _carrito.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _CarritoItem(
                  item:     _carrito[i],
                  onAdd:    () => _agregar({
                    'id':     _carrito[i].id,
                    'nombre': _carrito[i].nombre,
                    'precio': _carrito[i].precio,
                  }),
                  onQuitar: () => _quitar(_carrito[i].id),
                ),
              ),
      ),

      _buildResumen(),

    ]),
  );

  // ── Resumen financiero ────────────────────────────────
  Widget _buildResumen() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F6FA),
      borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16)),
      border: Border(top: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Column(children: [

      _resumenLinea('Crédito por devolución',
          '\$${_fmt(widget.totalDevuelto)}', Colors.grey.shade600),
      const SizedBox(height: 4),
      _resumenLinea('Productos elegidos',
          '\$${_fmt(_totalNuevo)}', Colors.grey.shade600),
      const Divider(height: 16),

      if (_diferencia > 0) ...[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _naranja.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _naranja.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.payments_outlined,
                size: 16, color: _naranja),
            const SizedBox(width: 8),
            Expanded(child: Text('Cliente paga diferencia',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: _naranja))),
            Text('+\$${_fmt(_diferencia)}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13, color: _naranja)),
          ]),
        ),
      ] else if (_diferencia < 0) ...[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _verde.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _verde.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.price_check_rounded,
                size: 16, color: _verde),
            const SizedBox(width: 8),
            Expanded(child: Text('Vuelto al cliente',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: _verde))),
            Text('\$${_fmt(-_diferencia)}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13, color: _verde)),
          ]),
        ),
      ] else if (_carrito.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _azul.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 16, color: _azul),
            const SizedBox(width: 8),
            Text('¡Cambio exacto!',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _azul)),
          ]),
        ),
      ],

      const SizedBox(height: 12),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _carrito.isEmpty ? null : _confirmar,
          icon:  const Icon(Icons.check_rounded, size: 18),
          label: Text('Confirmar cambio',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor:         _azul,
            foregroundColor:         Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    ]),
  );

  Widget _resumenLinea(String label, String valor, Color color) =>
    Row(children: [
      Text(label,
        style: GoogleFonts.poppins(fontSize: 11, color: color)),
      const Spacer(),
      Text(valor,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]);

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
}

// ── Tarjeta de producto en inventario ─────────────────
class _ProductoCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final int          enCarrito;
  final VoidCallback onAdd;

  const _ProductoCard({
    required this.producto,
    required this.enCarrito,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final precio   = double.tryParse(producto['precio'].toString()) ?? 0;
    final stock    = (producto['stock'] as num?)?.toInt() ?? 0;
    final sinStock = stock <= 0;

    return GestureDetector(
      onTap: sinStock ? null : onAdd,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enCarrito > 0
                ? const Color(0xFF1565C0).withValues(alpha: 0.4)
                : Colors.grey.shade200,
            width: enCarrito > 0 ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (enCarrito > 0)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('x$enCarrito',
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                ),
              )
            else
              const SizedBox(height: 14),

            Expanded(
              child: Text(producto['nombre'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: sinStock
                        ? Colors.grey.shade400
                        : const Color(0xFF1A1A2E))),
            ),
            const SizedBox(height: 6),

            Text('\$${_fmt(precio)}',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: sinStock
                      ? Colors.grey.shade400
                      : const Color(0xFF1565C0))),
            const SizedBox(height: 4),

            Row(children: [
              Text(
                sinStock ? 'Sin stock' : 'Stock: $stock',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: sinStock
                        ? Colors.red.shade400
                        : Colors.grey.shade500),
              ),
              const Spacer(),
              if (!sinStock)
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded,
                      size: 16, color: Color(0xFF1565C0)),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
}

// ── Fila de item en el carrito ─────────────────────────
class _CarritoItem extends StatelessWidget {
  final _ItemCarrito item;
  final VoidCallback onAdd;
  final VoidCallback onQuitar;

  const _CarritoItem({
    required this.item,
    required this.onAdd,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w500)),
            Text('\$${_fmt(item.subtotal)}',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF1565C0),
                  fontWeight: FontWeight.w600)),
          ],
        )),
        Row(children: [
          _btn(Icons.remove_rounded, onQuitar),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('${item.cantidad}',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          _btn(Icons.add_rounded, onAdd),
        ]),
      ]),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300)),
        child: Icon(icon, size: 12, color: Colors.grey.shade600),
      ),
    );

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
}