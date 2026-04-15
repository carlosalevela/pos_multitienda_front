// lib/screens/devoluciones/widgets/venta_selector_sheet.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:pos_multitienda_app/core/constants.dart';
import 'package:pos_multitienda_app/services/venta_service.dart';

class VentaSelectorSheet extends StatefulWidget {
  final int? tiendaId;

  const VentaSelectorSheet({
    super.key,
    required this.tiendaId,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required int? tiendaId,
  }) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => VentaSelectorSheet(tiendaId: tiendaId),
    );

  @override
  State<VentaSelectorSheet> createState() => _VentaSelectorSheetState();
}

class _VentaSelectorSheetState extends State<VentaSelectorSheet> {

  final _ventaService = VentaService();
  final _searchCtrl   = TextEditingController();

  List<Map<String, dynamic>> _ventas     = [];
  List<Map<String, dynamic>> _ventasFilt = [];
  bool    _cargando = true;
  String? _errorMsg;

  static const _primary = Color(Constants.primaryColor);
  static const _dark    = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _cargarVentas();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarVentas() async {
    setState(() { _cargando = true; _errorMsg = null; });
    try {
      // ✅ FIX 1: nombre correcto del método
      final lista = await _ventaService.listarVentas(
        tiendaId: widget.tiendaId,
      );

      if (!mounted) return;

      // ✅ FIX 2: filtro local — últimos 30 días + solo 'completada'
      final limite = DateTime.now().subtract(const Duration(days: 30));
      final filtradas = lista.where((v) {
        // filtro por estado
        final estadoOk =
            (v['estado']?.toString() ?? '') == 'completada';

        // filtro por fecha
        final fechaRaw = v['created_at']?.toString();
        if (fechaRaw == null) return estadoOk;
        try {
          final fecha = DateTime.parse(fechaRaw);
          return estadoOk && fecha.isAfter(limite);
        } catch (_) {
          return estadoOk;
        }
      }).toList();

      setState(() {
        _ventas     = filtradas;
        _ventasFilt = filtradas;
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
      _ventasFilt = q.isEmpty
          ? _ventas
          : _ventas.where((v) {
              final numero  = (v['numero_factura'] ?? '').toString().toLowerCase();
              final cliente = (v['cliente_nombre'] ?? '').toString().toLowerCase();
              return numero.contains(q) || cliente.contains(q);
            }).toList();
    });
  }

  // ✅ FIX 3: ya no se usa _strFecha (no se pasan parámetros de fecha al servicio)
  // Se elimina el método _strFecha

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.85,
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
        if (_errorMsg != null) _buildError(),
        Expanded(child: _buildLista()),

      ]),
    );
  }

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
          color: _primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.receipt_long_rounded,
            color: _primary, size: 22),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Seleccionar venta',
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: _dark)),
        Text('Últimos 30 días • solo completadas',
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

  Widget _buildBuscador() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar por # factura o cliente...',
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
          borderSide: const BorderSide(color: _primary, width: 1.5)),
      ),
    ),
  );

  Widget _buildError() => Container(
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
        onTap: _cargarVentas,
        child: Text('Reintentar',
          style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600)),
      ),
    ]),
  );

  Widget _buildLista() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ventasFilt.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_rounded,
              size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text(
            _searchCtrl.text.isNotEmpty
                ? 'Sin resultados para "${_searchCtrl.text}"'
                : 'Sin ventas en los últimos 30 días',
            style: GoogleFonts.poppins(
                fontSize: 14, color: Colors.grey.shade400)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _ventasFilt.length,
      itemBuilder: (_, i) => _VentaCard(
        venta: _ventasFilt[i],
        onTap: () => Navigator.pop(context, _ventasFilt[i]),
      ),
    );
  }
}


// ── Tarjeta de venta ──────────────────────────────────
class _VentaCard extends StatelessWidget {
  final Map<String, dynamic> venta;
  final VoidCallback          onTap;

  const _VentaCard({required this.venta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final numero   = venta['numero_factura']?.toString() ?? 'S/N';
    final cliente  = venta['cliente_nombre']?.toString() ?? 'Consumidor Final';
    final empleado = venta['empleado_nombre']?.toString() ?? '';
    final total    = double.tryParse(venta['total'].toString()) ?? 0;
    final metodo   = venta['metodo_pago']?.toString() ?? 'efectivo';
    final fecha    = _parseFecha(venta['created_at']?.toString());
    final nItems   = (venta['detalles'] as List?)?.length
                     ?? int.tryParse(venta['num_items']?.toString() ?? '0')
                     ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [

          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(Constants.primaryColor)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_rounded,
                color: Color(Constants.primaryColor), size: 22),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(numero,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF1A1A2E))),
                  const Spacer(),
                  Text('\$${_fmtNum(total)}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(Constants.primaryColor))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.person_outline_rounded,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(cliente,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade600)),
                  ),
                  if (fecha != null)
                    Text(
                      DateFormat('dd/MM/yy HH:mm').format(fecha),
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade400),
                    ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _chip(_labelMetodo(metodo), _colorMetodo(metodo)),
                  const SizedBox(width: 6),
                  if (empleado.isNotEmpty) ...[
                    _chip(empleado, Colors.blueGrey.shade400),
                    const SizedBox(width: 6),
                  ],
                  if (nItems > 0)
                    _chip('$nItems ítem${nItems != 1 ? 's' : ''}',
                        Colors.grey.shade500),
                ]),
              ],
            ),
          ),

          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.grey.shade300),

        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
      style: GoogleFonts.poppins(
          fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  DateTime? _parseFecha(String? raw) {
    if (raw == null) return null;
    try { return DateTime.parse(raw); } catch (_) { return null; }
  }

  String _fmtNum(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  String _labelMetodo(String m) {
    switch (m.toLowerCase()) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      default:              return 'Efectivo';
    }
  }

  Color _colorMetodo(String m) {
    switch (m.toLowerCase()) {
      case 'transferencia': return Colors.blue.shade600;
      case 'tarjeta':       return Colors.purple.shade600;
      default:              return Colors.green.shade600;
    }
  }
}