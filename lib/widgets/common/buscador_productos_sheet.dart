import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/producto.dart';
import '../../services/inventario_service.dart';

class BuscadorProductosSheet extends StatefulWidget {
  final int? tiendaId;

  const BuscadorProductosSheet({super.key, this.tiendaId});

  static Future<Producto?> show(BuildContext context, {int? tiendaId}) {
    return showModalBottomSheet<Producto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BuscadorProductosSheet(tiendaId: tiendaId),
    );
  }

  @override
  State<BuscadorProductosSheet> createState() => _BuscadorProductosSheetState();
}

class _BuscadorProductosSheetState extends State<BuscadorProductosSheet> {
  final _ctrl = TextEditingController();
  final _service = InventarioService();
  List<Producto> _productos = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_buscar);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    if (_ctrl.text.length < 2) {
      if (mounted) setState(() => _productos.clear());
      return;
    }

    setState(() => _cargando = true);

    try {
      _productos = await _service.getProductos(
        q: _ctrl.text,
        tiendaId: widget.tiendaId,
      );
    } catch (e) {
      debugPrint('❌ Error buscando productos: $e');
      _productos.clear();
    }

    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            Text('Buscar producto',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text('${_productos.length} encontrados',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'ID, código de barras, nombre...',
              hintStyle:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey.shade400),
                      onPressed: () {
                        _ctrl.clear();
                        _buscar();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF01696F), width: 1.5)),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        const Divider(height: 1),
        // ← Loading indicator
        if (_cargando) ...[
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ] else if (_productos.isEmpty)
          // Results
          _emptyState(_ctrl.text.isEmpty)
        else
          Expanded(
            child: ListView.separated(
              itemCount: _productos.length,
              separatorBuilder: (_, __) => Divider(
                  height: 1, color: Colors.grey.shade100),
              itemBuilder: (_, i) {
                final p = _productos[i];
                return ListTile(
                  onTap: () => Navigator.pop(context, p),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF01696F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.inventory_2_rounded,
                        size: 20, color: const Color(0xFF01696F)),
                  ),
                  title: Text(p.nombre,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.referencia.isNotEmpty ? p.referencia : 'Sin código',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey.shade500)),
                      Text('Stock: ${fmt.format(p.stockActual)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.green.shade600)),
                    ],
                  ),
                  trailing: Text(
                    '\$${fmt.format(p.precio)}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF01696F)),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _emptyState(bool sinBusqueda) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_rounded,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(sinBusqueda
              ? 'Escribe para buscar productos'
              : 'No se encontraron productos',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }
}