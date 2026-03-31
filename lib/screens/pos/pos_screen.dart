import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/pos_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../models/producto.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl  = TextEditingController();
  final _montoCtrl   = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _montoCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos  = context.watch<PosProvider>();
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Panel izquierdo: Buscador + Productos ─────────
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildSearchBar(pos, auth),
                const SizedBox(height: 12),
                Expanded(child: _buildProductList(pos)),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // ── Panel derecho: Carrito ────────────────────────
          SizedBox(
            width: 360,
            child: Column(
              children: [
                Expanded(child: _buildCarrito(pos, auth)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(Constants.primaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.point_of_sale_rounded,
              color: Color(Constants.primaryColor)),
        ),
        const SizedBox(width: 12),
        Text('Punto de Venta',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  // ── Buscador ─────────────────────────────────────────────
  Widget _buildSearchBar(PosProvider pos, AuthProvider auth) {
    return TextField(
      controller:  _searchCtrl,
      focusNode:   _searchFocus,
      autofocus:   true,
      decoration: InputDecoration(
        hintText: '🔍  Buscar producto por nombre o referencia...',
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
        filled:     true,
        fillColor:  Colors.white,
        prefixIcon: const Icon(Icons.search_rounded,
            color: Color(Constants.primaryColor)),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                onPressed: () {
                  _searchCtrl.clear();
                  pos.buscarProductos('', auth.tiendaId);
                  setState(() {});
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(Constants.primaryColor), width: 2),
        ),
      ),
      onChanged: (val) {
        setState(() {});
        pos.buscarProductos(val, auth.tiendaId);
      },
    );
  }

  // ── Lista de productos encontrados ───────────────────────
  Widget _buildProductList(PosProvider pos) {
    if (pos.buscando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchCtrl.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Busca un producto para agregarlo al carrito',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 14)),
          ],
        ),
      );
    }

    if (pos.resultados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No se encontraron productos',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        crossAxisSpacing: 12,
        mainAxisSpacing:  12,
        childAspectRatio: 2.2,
      ),
      itemCount: pos.resultados.length,
      itemBuilder: (context, index) =>
          _buildProductCard(pos.resultados[index], pos),
    );
  }

  Widget _buildProductCard(Producto producto, PosProvider pos) {
    final sinStock = producto.stockActual <= 0;
    return GestureDetector(
      onTap: sinStock ? null : () {
        pos.agregarAlCarrito(producto);
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color:        sinStock ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: sinStock ? [] : [
            BoxShadow(
              color:       Colors.black.withOpacity(0.04),
              blurRadius:  8,
              offset:      const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sinStock
                    ? Colors.grey.shade200
                    : const Color(Constants.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.inventory_2_rounded,
                color: sinStock
                    ? Colors.grey
                    : const Color(Constants.primaryColor),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.center,
                children: [
                  Text(producto.nombre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize:   13,
                      color: sinStock ? Colors.grey : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '\$${producto.precio.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      color:      sinStock
                          ? Colors.grey
                          : const Color(Constants.primaryColor),
                      fontWeight: FontWeight.bold,
                      fontSize:   14,
                    ),
                  ),
                  Text(
                    sinStock
                        ? 'Sin stock'
                        : 'Stock: ${producto.stockActual.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color:    sinStock ? Colors.red : Colors.grey,
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

  // ── Carrito ──────────────────────────────────────────────
  Widget _buildCarrito(PosProvider pos, AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabecera carrito
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Carrito',
                  style: GoogleFonts.poppins(
                    color:      Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize:   16,
                  ),
                ),
                const Spacer(),
                if (pos.carrito.isNotEmpty)
                  GestureDetector(
                    onTap: () => _confirmarLimpiar(pos),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                  ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:        const Color(Constants.primaryColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${pos.carrito.length}',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Items del carrito
          Expanded(
            child: pos.carrito.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('Carrito vacío',
                          style: GoogleFonts.poppins(
                              color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: pos.carrito.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.grey.shade100),
                    itemBuilder: (context, i) {
                      final item = pos.carrito[i];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.producto.nombre,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize:   13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '\$${item.subtotal.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    color:      const Color(Constants.primaryColor),
                                    fontWeight: FontWeight.bold,
                                    fontSize:   13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Controles cantidad
                          Row(
                            children: [
                              _qtyBtn(Icons.remove_rounded,
                                  () => pos.decrementar(i)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10),
                                child: Text('${item.cantidad}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize:   15,
                                  ),
                                ),
                              ),
                              _qtyBtn(Icons.add_rounded,
                                  () => pos.incrementar(i)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // ── Zona de cobro ──────────────────────────────
          if (pos.carrito.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:  Colors.grey.shade50,
                border: Border(
                    top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        '\$${pos.total.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize:   20,
                          color:      const Color(Constants.primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Método de pago
                  Row(
                    children: [
                      Expanded(
                        child: _metodoBtn('efectivo', '💵 Efectivo', pos),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metodoBtn('transferencia', '📲 Transferencia', pos),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Monto recibido (solo efectivo)
                  if (pos.metodoPago == 'efectivo') ...[
                    TextField(
                      controller: _montoCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: InputDecoration(
                        labelText:  'Monto recibido',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        prefixText: '\$ ',
                        filled:     true,
                        fillColor:  Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(Constants.primaryColor), width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        pos.setMontoRecibido(
                          double.tryParse(val) ?? 0,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Vuelto
                    if (pos.montoRecibido > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:        Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Vuelto:',
                              style: GoogleFonts.poppins(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600)),
                            Text(
                              '\$${pos.vuelto.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                color:      Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize:   16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],

                  // Mensajes error / éxito
                  if (pos.errorMsg.isNotEmpty)
                    _msgBanner(pos.errorMsg, isError: true),
                  if (pos.successMsg.isNotEmpty)
                    _msgBanner(pos.successMsg, isError: false),

                  const SizedBox(height: 8),

                  // Botón cobrar
                  SizedBox(
                    width:  double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon:  pos.procesando
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(
                        pos.procesando ? 'Procesando...' : 'COBRAR',
                        style: GoogleFonts.poppins(
                          fontSize:   16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: pos.procesando
                          ? null
                          : () {
                              _montoCtrl.clear();
                              pos.cobrar(
                                context.read<AuthProvider>().tiendaId,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color:        const Color(Constants.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 16, color: const Color(Constants.primaryColor)),
      ),
    );
  }

  Widget _metodoBtn(String value, String label, PosProvider pos) {
    final selected = pos.metodoPago == value;
    return GestureDetector(
      onTap: () {
        pos.setMetodoPago(value);
        if (value != 'efectivo') {
          _montoCtrl.clear();
          pos.setMontoRecibido(pos.total);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:        selected
              ? const Color(Constants.primaryColor)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(label,
            style: GoogleFonts.poppins(
              color:      selected ? Colors.white : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize:   12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _msgBanner(String msg, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isError
            ? const Color(Constants.errorColor).withOpacity(0.1)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? const Color(Constants.errorColor).withOpacity(0.3)
              : Colors.green.shade200,
        ),
      ),
      child: Text(msg,
        style: GoogleFonts.poppins(
          color:    isError ? const Color(Constants.errorColor) : Colors.green.shade700,
          fontSize: 12,
        ),
      ),
    );
  }

  void _confirmarLimpiar(PosProvider pos) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('¿Limpiar carrito?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Se eliminarán todos los productos del carrito.',
          style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              pos.limpiarCarrito();
              _montoCtrl.clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}