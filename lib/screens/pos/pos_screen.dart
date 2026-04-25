// lib/screens/pos/pos_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/pos_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cliente_provider.dart';
import '../../models/producto.dart';
import '../../models/cliente.dart';
import '../../core/constants.dart';
import '../../providers/caja_provider.dart';

// ══════════════════════════════════════════════════════════
// COLORES DEL SISTEMA DE DISEÑO (consistente con las demás pantallas)
// ══════════════════════════════════════════════════════════
const _kPrimary   = Color(0xFF6366F1);
const _kDark      = Color(0xFF0F172A);
const _kSurface   = Color(0xFFF8F9FC);
const _kCard      = Colors.white;
const _kBorder    = Color(0xFFE2E8F0);
const _kTextSub   = Color(0xFF94A3B8);
const _kTextBody  = Color(0xFF475569);
const _kTextHead  = Color(0xFF1E293B);

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl        = TextEditingController();
  final _montoCtrl         = TextEditingController();
  final _clienteSearchCtrl = TextEditingController();
  final _descuentoCtrl     = TextEditingController();
  final _searchFocus       = FocusNode();

  Cliente?  _clienteSeleccionado;
  DateTime? _fechaLimite;
  bool      _buscandoCliente = false;
  Timer?    _debounceCliente;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _montoCtrl.dispose();
    _clienteSearchCtrl.dispose();
    _descuentoCtrl.dispose();
    _searchFocus.dispose();
    _debounceCliente?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos  = context.watch<PosProvider>();
    final auth = context.watch<AuthProvider>();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: _kSurface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Panel izquierdo: productos ──────────────
              Expanded(
                flex: 5,
                child: Column(children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildSearchBar(pos, auth),
                  const SizedBox(height: 14),
                  Expanded(child: _buildProductList(pos)),
                ]),
              ),
              const SizedBox(width: 20),
              // ── Panel derecho: carrito ──────────────────
              SizedBox(width: 390, child: _buildCarrito(pos, auth)),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════
  Widget _buildHeader() => Row(children: [
    Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: _kPrimary.withOpacity(0.35),
              blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: const Icon(Icons.point_of_sale_rounded,
          color: Colors.white, size: 26),
    ),
    const SizedBox(width: 14),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Punto de Venta',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 24, fontWeight: FontWeight.w800,
              color: _kDark, letterSpacing: -0.5)),
      Text('Selecciona productos para agregar al carrito',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: _kTextSub, fontWeight: FontWeight.w500)),
    ]),
  ]);

  // ══════════════════════════════════════════════════
  // BUSCADOR
  // ══════════════════════════════════════════════════
  Widget _buildSearchBar(PosProvider pos, AuthProvider auth) => Container(
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3)),
      ],
    ),
    child: TextField(
      controller: _searchCtrl,
      focusNode:  _searchFocus,
      autofocus:  true,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14, color: _kTextHead),
      decoration: InputDecoration(
        hintText: 'Buscar producto por nombre o referencia…',
        hintStyle: GoogleFonts.plusJakartaSans(
            color: _kTextSub, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded,
            color: _kPrimary, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: _kTextSub, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  pos.buscarProductos('', auth.tiendaId);
                  setState(() {});
                })
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 15),
      ),
      onChanged: (val) {
        setState(() {});
        pos.buscarProductos(val, auth.tiendaId);
      },
    ),
  );

  // ══════════════════════════════════════════════════
  // LISTA DE PRODUCTOS
  // ══════════════════════════════════════════════════
  Widget _buildProductList(PosProvider pos) {
    if (pos.buscando) return _loadingState();

    if (_searchCtrl.text.isEmpty) {
      return _emptyState(
        icon:  Icons.search_rounded,
        title: 'Busca un producto',
        sub:   'Escribe el nombre o referencia en el buscador',
      );
    }
    if (pos.resultados.isEmpty) {
      return _emptyState(
        icon:  Icons.inventory_2_outlined,
        title: 'Sin resultados',
        sub:   'No encontramos productos con ese nombre',
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:  2,
          crossAxisSpacing: 12,
          mainAxisSpacing:  12,
          childAspectRatio: 2.4),
      itemCount: pos.resultados.length,
      itemBuilder: (_, i) => _buildProductCard(pos.resultados[i], pos),
    );
  }

  Widget _buildProductCard(Producto p, PosProvider pos) {
    final sinStock = p.stockActual <= 0;
    return GestureDetector(
      onTap: sinStock ? null : () {
        pos.agregarAlCarrito(p);
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sinStock ? const Color(0xFFF8F9FC) : _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: sinStock ? _kBorder : _kBorder),
          boxShadow: sinStock ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          // Ícono del producto
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: sinStock
                  ? null
                  : const LinearGradient(
                      colors: [_kPrimary, Color(0xFF8B5CF6)]),
              color: sinStock ? const Color(0xFFE2E8F0) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_rounded,
                color: sinStock ? _kTextSub : Colors.white,
                size: 20),
          ),
          const SizedBox(width: 12),

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(p.nombre,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: sinStock ? _kTextSub : _kTextHead),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('\$${p.precio.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                      color: sinStock ? _kTextSub : _kPrimary,
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: sinStock
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    shape: BoxShape.circle),
                ),
                Text(
                  sinStock
                      ? 'Sin stock'
                      : 'Stock: ${p.stockActual.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: sinStock
                          ? const Color(0xFFEF4444) : _kTextSub)),
              ]),
            ],
          )),

          // Botón add
          if (!sinStock)
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded,
                  color: _kPrimary, size: 18),
            ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // CARRITO
  // ══════════════════════════════════════════════════
  Widget _buildCarrito(PosProvider pos, AuthProvider auth) {
    final esSeparado = pos.metodoPago == 'separado';

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: [

        // ── Header del carrito ──────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F1629), Color(0xFF1E2A45)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_cart_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Carrito',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const Spacer(),
            if (pos.carrito.isNotEmpty) ...[
              _iconAction(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFF87171),
                onTap: () => _confirmarLimpiar(pos),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${pos.carrito.length} items',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        // ── Items del carrito ───────────────────────────
        Expanded(
          child: pos.carrito.isEmpty
              ? _cartEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: pos.carrito.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: _kBorder, height: 1),
                  itemBuilder: (_, i) => _buildCartItem(pos, i),
                ),
        ),

        // ── Panel de cobro ──────────────────────────────
        if (pos.carrito.isNotEmpty)
          _buildPanelCobro(pos, auth, esSeparado),
      ]),
    );
  }

  Widget _buildCartItem(PosProvider pos, int i) {
    final item = pos.carrito[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        // Punto de color
        Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(right: 10),
          decoration: const BoxDecoration(
            color: _kPrimary, shape: BoxShape.circle),
        ),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.producto.nombre,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: _kTextHead),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('\$${item.subtotal.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                    color: _kPrimary, fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ],
        )),
        // Controles de cantidad
        Row(children: [
          _qtyBtn(Icons.remove_rounded, () => pos.decrementar(i)),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text('${item.cantidad}',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, fontSize: 15,
                    color: _kTextHead)),
          ),
          _qtyBtn(Icons.add_rounded, () => pos.incrementar(i)),
        ]),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // PANEL DE COBRO
  // ══════════════════════════════════════════════════
  Widget _buildPanelCobro(PosProvider pos, AuthProvider auth,
      bool esSeparado) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFF),
        border: Border(top: BorderSide(color: _kBorder)),
        borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20)),
      ),
      child: Column(children: [

        // Subtotal
        _totalRow('Subtotal', '\$${pos.total.toStringAsFixed(0)}',
            isSmall: true),
        const SizedBox(height: 10),

        // Campo descuento
        _buildDescuentoField(pos),

        // Descuento activo
        if (pos.descuento > 0) ...[
          const SizedBox(height: 8),
          _discountBadge(pos),
        ] else ...[
          const SizedBox(height: 8),
          _totalRow('TOTAL', '\$${pos.total.toStringAsFixed(0)}'),
        ],
        const SizedBox(height: 14),

        // Métodos de pago
        _buildMetodosPago(pos),
        const SizedBox(height: 12),

        // Efectivo
        if (pos.metodoPago == 'efectivo') ...[
          _buildEfectivoSection(pos),
          const SizedBox(height: 10),
        ],

        // Separado
        if (esSeparado) ...[
          _buildClienteSearch(),
          const SizedBox(height: 10),
          _buildFechaLimite(),
          const SizedBox(height: 10),
        ],

        // Mensajes
        if (pos.errorMsg.isNotEmpty)
          _msgBanner(pos.errorMsg, isError: true),
        if (pos.successMsg.isNotEmpty)
          _msgBanner(pos.successMsg, isError: false),

        // Botón principal
        SizedBox(
          width: double.infinity, height: 52,
          child: esSeparado
              ? _botonSeparado(pos, auth)
              : _botonCobrar(pos, auth),
        ),
      ]),
    );
  }

  Widget _totalRow(String label, String value,
      {bool isSmall = false}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: isSmall ? 12 : 15,
              color: isSmall ? _kTextSub : _kTextHead,
              letterSpacing: isSmall ? 0 : 0.3)),
      Text(value,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: isSmall ? 14 : 22,
              color: isSmall ? _kTextBody : _kPrimary)),
    ]);

  Widget _discountBadge(PosProvider pos) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
    ),
    child: Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.discount_rounded,
            size: 15, color: Color(0xFF10B981)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Desc. -\$${pos.descuento.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF10B981), fontSize: 12,
              fontWeight: FontWeight.w600)),
      ),
      Text('\$${pos.totalConDescuento.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF059669),
              fontWeight: FontWeight.w800, fontSize: 20)),
    ]),
  );

  // ── Campo descuento ─────────────────────────────────────
  Widget _buildDescuentoField(PosProvider pos) => Row(children: [
    Expanded(
      child: TextField(
        controller:   _descuentoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        style: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: _kTextHead, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText:  'Descuento',
          labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: _kTextSub),
          prefixText: '\$ ',
          filled: true, fillColor: _kCard,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPrimary, width: 2)),
          suffixIcon: pos.descuento > 0
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 15, color: _kTextSub),
                  onPressed: () {
                    _descuentoCtrl.clear();
                    pos.setDescuento(0);
                  })
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
  ]);

  Widget _pctBtn(PosProvider pos, int pct) => GestureDetector(
    onTap: () {
      pos.setDescuentoPorcentaje(pct);
      _descuentoCtrl.text = pos.descuento.toStringAsFixed(0);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$pct%',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _kPrimary)),
    ),
  );

  // ── Métodos de pago ─────────────────────────────────────
  Widget _buildMetodosPago(PosProvider pos) {
    final metodos = [
      ('efectivo',      '💵', 'Efectivo',    const Color(0xFF10B981)),
      ('tarjeta',       '💳', 'Tarjeta',     const Color(0xFF6366F1)),
      ('transferencia', '📲', 'Transferencia', const Color(0xFF8B5CF6)),
      ('separado',      '📦', 'Separado',    const Color(0xFFF59E0B)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 7,
      mainAxisSpacing:  7,
      childAspectRatio: 3.4,
      children: metodos.map((m) {
        final (value, emoji, label, color) = m;
        final selected = pos.metodoPago == value;
        return GestureDetector(
          onTap: () {
            pos.setMetodoPago(value);
            if (value != 'efectivo') {
              _montoCtrl.clear();
              if (value != 'separado') pos.setMontoRecibido(pos.total);
            }
            if (value != 'separado') {
              setState(() {
                _clienteSeleccionado = null;
                _fechaLimite         = null;
                _clienteSearchCtrl.clear();
              });
            }
            setState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.1) : _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? color : _kBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                          color: selected ? color : _kTextBody,
                          fontWeight: selected
                              ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Sección efectivo ────────────────────────────────────
  Widget _buildEfectivoSection(PosProvider pos) => Column(children: [
    TextField(
      controller:      _montoCtrl,
      keyboardType:    TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w700, color: _kTextHead),
      decoration: InputDecoration(
        labelText:  'Monto recibido',
        labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: _kTextSub),
        prefixText: '\$ ',
        filled: true, fillColor: _kCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF10B981), width: 2)),
      ),
      onChanged: (v) => pos.setMontoRecibido(double.tryParse(v) ?? 0),
    ),
    if (pos.montoRecibido > 0) ...[
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: pos.vuelto < 0
              ? const Color(0xFFFFF5F5)
              : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: pos.vuelto < 0
                ? const Color(0xFFEF4444).withOpacity(0.3)
                : const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Vuelto',
                style: GoogleFonts.plusJakartaSans(
                    color: pos.vuelto < 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    fontWeight: FontWeight.w700, fontSize: 13)),
            Text('\$${pos.vuelto.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                    color: pos.vuelto < 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
    ],
  ]);

  // ══════════════════════════════════════════════════
  // BÚSQUEDA DE CLIENTE (separado)
  // ══════════════════════════════════════════════════
  Widget _buildClienteSearch() {
    final clienteProv = context.watch<ClienteProvider>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.person_rounded, size: 14, color: _kTextSub),
        const SizedBox(width: 6),
        Text('Cliente *',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _kTextBody)),
      ]),
      const SizedBox(height: 8),

      if (_clienteSeleccionado != null)
        // Tarjeta de cliente seleccionado
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPrimary.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kPrimary, Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _clienteSeleccionado!.nombre[0].toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_clienteSeleccionado!.nombreCompleto,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: _kTextHead)),
                if (_clienteSeleccionado!.telefono.isNotEmpty)
                  Text(_clienteSeleccionado!.telefono,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: _kTextSub)),
              ],
            )),
            _iconAction(
              icon: Icons.close_rounded,
              color: _kTextSub,
              onTap: () => setState(() {
                _clienteSeleccionado = null;
                _clienteSearchCtrl.clear();
              }),
            ),
          ]),
        )
      else ...[
        // Input de búsqueda
        TextField(
          controller: _clienteSearchCtrl,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: _kTextHead),
          decoration: InputDecoration(
            hintText:  'Buscar por nombre o cédula…',
            hintStyle: GoogleFonts.plusJakartaSans(
                color: _kTextSub, fontSize: 12),
            prefixIcon: const Icon(Icons.person_search_rounded,
                size: 19, color: _kTextSub),
            suffixIcon: _buscandoCliente
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kPrimary)))
                : null,
            filled: true, fillColor: _kCard,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPrimary, width: 2)),
          ),
          onChanged: (v) {
            if (v.length < 2) return;
            _debounceCliente?.cancel();
            setState(() => _buscandoCliente = true);
            _debounceCliente = Timer(
                const Duration(milliseconds: 350), () async {
              await context.read<ClienteProvider>()
                  .cargarClientesSimple(q: v);
              if (mounted) setState(() => _buscandoCliente = false);
            });
          },
        ),

        // Dropdown de resultados
        if (clienteProv.clientesSimple.isNotEmpty &&
            _clienteSearchCtrl.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08),
                    blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: clienteProv.clientesSimple.length,
              itemBuilder: (_, i) {
                final c = clienteProv.clientesSimple[i];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 2),
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(c.nombre[0].toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                              color: _kPrimary, fontSize: 13,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  title: Text(c.nombreCompleto,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _kTextHead)),
                  subtitle: c.telefono.isNotEmpty
                      ? Text(c.telefono,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: _kTextSub))
                      : null,
                  onTap: () => setState(() {
                    _clienteSeleccionado = c;
                    _clienteSearchCtrl.clear();
                    context.read<ClienteProvider>()
                        .cargarClientesSimple(q: '');
                  }),
                );
              },
            ),
          ),
      ],
    ]);
  }

  // ── Selector fecha límite ───────────────────────────────
  Widget _buildFechaLimite() => GestureDetector(
    onTap: () async {
      final fecha = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 7)),
        firstDate:   DateTime.now(),
        lastDate:    DateTime.now().add(const Duration(days: 365)),
        builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _kPrimary)),
          child: child!),
      );
      if (fecha != null) setState(() => _fechaLimite = fecha);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _fechaLimite != null
            ? _kPrimary.withOpacity(0.06) : _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _fechaLimite != null
              ? _kPrimary.withOpacity(0.3) : _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: (_fechaLimite != null
                ? _kPrimary : _kTextSub).withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(Icons.calendar_today_rounded, size: 14,
              color: _fechaLimite != null ? _kPrimary : _kTextSub),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _fechaLimite != null
                ? 'Límite: ${_fechaLimite!.day}/${_fechaLimite!.month}/${_fechaLimite!.year}'
                : 'Fecha límite (opcional)',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _fechaLimite != null ? _kPrimary : _kTextSub,
                fontWeight: _fechaLimite != null
                    ? FontWeight.w600 : FontWeight.w500)),
        ),
        if (_fechaLimite != null)
          _iconAction(
            icon: Icons.close_rounded,
            color: _kTextSub,
            onTap: () => setState(() => _fechaLimite = null),
          ),
      ]),
    ),
  );

  // ── Botones de acción ───────────────────────────────────
  Widget _botonCobrar(PosProvider pos, AuthProvider auth) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35),
            blurRadius: 12, offset: const Offset(0, 5)),
      ],
    ),
    child: ElevatedButton.icon(
      icon: pos.procesando
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.check_circle_rounded, size: 20),
      label: Text(pos.procesando ? 'Procesando…' : 'COBRAR',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w800,
              letterSpacing: 0.3)),
      onPressed: pos.procesando ? null : () {
        _montoCtrl.clear();
        _descuentoCtrl.clear();
        pos.cobrar(context.read<AuthProvider>().tiendaId);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor:     Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  Widget _botonSeparado(PosProvider pos, AuthProvider auth) {
    final clienteProv = context.read<ClienteProvider>();
    final habilitado  = _clienteSeleccionado != null && !pos.procesando;

    return Container(
      decoration: BoxDecoration(
        gradient: habilitado
            ? const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)])
            : null,
        color: habilitado ? null : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
        boxShadow: habilitado ? [
          BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.35),
              blurRadius: 12, offset: const Offset(0, 5)),
        ] : [],
      ),
      child: ElevatedButton.icon(
        icon: pos.procesando
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.bookmark_add_rounded, size: 20),
        label: Text(pos.procesando ? 'Guardando…' : 'CREAR SEPARADO',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w800)),
        onPressed: habilitado
            ? () => _crearSeparado(pos, auth, clienteProv) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor:     Colors.transparent,
          disabledForegroundColor: _kTextSub,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // LÓGICA DE NEGOCIO (sin cambios)
  // ══════════════════════════════════════════════════
  Future<void> _crearSeparado(PosProvider pos, AuthProvider auth,
      ClienteProvider clienteProv) async {
    if (_clienteSeleccionado == null) return;

    final cajaAbierta = context.read<CajaProvider>().cajaAbierta;
    if (!cajaAbierta) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ Abre la caja antes de crear un separado.',
            style: GoogleFonts.plusJakartaSans()),
        backgroundColor: const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    final data = {
      'tienda':  auth.tiendaId,
      'cliente': _clienteSeleccionado!.id,
      if (pos.descuento > 0) 'descuento': pos.descuento,
      if (_fechaLimite != null)
        'fecha_limite':
            '${_fechaLimite!.year}-'
            '${_fechaLimite!.month.toString().padLeft(2, '0')}-'
            '${_fechaLimite!.day.toString().padLeft(2, '0')}',
      'detalles': pos.carrito.map((item) => {
        'producto':        item.producto.id,
        'cantidad':        item.cantidad,
        'precio_unitario': item.precioUnitario,
      }).toList(),
    };

    final ok = await clienteProv.crearSeparado(data);
    if (ok && mounted) {
      setState(() {
        _clienteSeleccionado = null;
        _fechaLimite         = null;
        _clienteSearchCtrl.clear();
        _descuentoCtrl.clear();
      });
      pos.limpiarCarrito();
      pos.setMetodoPago('efectivo');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Separado creado correctamente',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  // ══════════════════════════════════════════════════
  // HELPERS VISUALES
  // ══════════════════════════════════════════════════
  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 15, color: _kPrimary),
    ),
  );

  Widget _iconAction({
    required IconData     icon,
    required Color        color,
    required VoidCallback onTap,
  }) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );

  Widget _msgBanner(String msg, {required bool isError}) {
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(msg,
          style: GoogleFonts.plusJakartaSans(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _loadingState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_kPrimary, Color(0xFF8B5CF6)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Padding(padding: EdgeInsets.all(13),
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5)),
      ),
      const SizedBox(height: 14),
      Text('Buscando productos…',
          style: GoogleFonts.plusJakartaSans(
              color: _kTextSub, fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );

  Widget _emptyState({
    required IconData icon,
    required String   title,
    required String   sub,
  }) =>
    Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 38, color: const Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 14),
        Text(title,
            style: GoogleFonts.plusJakartaSans(
                color: _kTextBody, fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(sub,
            style: GoogleFonts.plusJakartaSans(
                color: _kTextSub, fontSize: 13)),
      ]),
    );

  Widget _cartEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.shopping_cart_outlined,
            size: 30, color: Color(0xFFCBD5E1)),
      ),
      const SizedBox(height: 10),
      Text('Carrito vacío',
          style: GoogleFonts.plusJakartaSans(
              color: _kTextSub, fontSize: 14,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Agrega productos desde el buscador',
          style: GoogleFonts.plusJakartaSans(
              color: _kTextSub, fontSize: 12)),
    ]),
  );

  void _confirmarLimpiar(PosProvider pos) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        titlePadding:   const EdgeInsets.fromLTRB(24, 24, 24, 12),
        title: Text('¿Limpiar carrito?',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 17,
                color: _kDark)),
        content: Text(
            'Se eliminarán todos los productos del carrito.',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: _kTextBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.plusJakartaSans(
                    color: _kTextSub, fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: Color(0xFFEF4444)),
              label: Text('Limpiar',
                  style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w700)),
              onPressed: () {
                pos.limpiarCarrito();
                _montoCtrl.clear();
                _descuentoCtrl.clear();
                setState(() {
                  _clienteSeleccionado = null;
                  _fechaLimite         = null;
                });
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}