// lib/screens/inventario/widgets/averias_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/inventario_service.dart';

class AveriasDialog extends StatefulWidget {
  final int?   tiendaId;
  final String nombreTienda;

  const AveriasDialog({
    super.key,
    required this.tiendaId,
    required this.nombreTienda,
  });

  @override
  State<AveriasDialog> createState() => _AveriasDialogState();
}

class _AveriasDialogState extends State<AveriasDialog> {
  final _service = InventarioService();

  bool                       _cargando = true;
  String?                    _error;
  List<Map<String, dynamic>> _items    = [];

  // id del producto que tiene el formulario de acción abierto
  int?    _expandedId;
  String  _accionSeleccionada = 'recuperar';
  final   _cantCtrl = TextEditingController();
  bool    _procesando = false;
  String? _errAccion;

  // ── Colores ────────────────────────────────────────────
  static const _surface  = Colors.white;
  static const _bg       = Color(0xFFF7F9FB);
  static const _border   = Color(0xFFE5E7EB);
  static const _text     = Color(0xFF111827);
  static const _muted    = Color(0xFF6B7280);
  static const _green    = Color(0xFF006C49);
  static const _greenBg  = Color(0xFFE8FFF4);
  static const _danger   = Color(0xFFBE123C);
  static const _dangerBg = Color(0xFFFFF1F2);
  static const _amber    = Color(0xFFB45309);
  static const _amberBg  = Color(0xFFFEF3C7);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    final r = await _service.getAverias(tiendaId: widget.tiendaId);
    if (!mounted) return;
    if (r['success'] == true) {
      setState(() {
        _items    = List<Map<String, dynamic>>.from(r['data'] as List);
        _cargando = false;
      });
    } else {
      setState(() { _error = r['error'] as String?; _cargando = false; });
    }
  }

  void _abrirAccion(int productoId, String accion) {
    setState(() {
      _expandedId         = productoId;
      _accionSeleccionada = accion;
      _cantCtrl.clear();
      _errAccion = null;
      _procesando = false;
    });
  }

  void _cerrarAccion() => setState(() {
    _expandedId = null;
    _errAccion  = null;
    _cantCtrl.clear();
  });

  Future<void> _confirmar(Map<String, dynamic> item) async {
    final cantRaw = double.tryParse(_cantCtrl.text.trim().replaceAll(',', '.'));
    if (cantRaw == null || cantRaw <= 0) {
      setState(() => _errAccion = 'Ingresa una cantidad válida.');
      return;
    }
    final stockAverias = _toDouble(item['stock_averias']);
    if (cantRaw > stockAverias) {
      setState(() => _errAccion = 'No hay suficiente stock en averías ($stockAverias).');
      return;
    }

    setState(() { _procesando = true; _errAccion = null; });

    final r = await _service.recuperarAveria(
      productoId: item['producto'] as int,
      tiendaId:   item['tienda']   as int,
      accion:     _accionSeleccionada,
      cantidad:   cantRaw,
    );

    if (!mounted) return;

    if (r['success'] == true) {
      _cerrarAccion();
      _mostrarSnack(
        _accionSeleccionada == 'recuperar'
            ? '✓ Unidades recuperadas al stock normal'
            : '✓ Unidades dadas de baja definitivamente',
        isError: false,
      );
      await _cargar();
    } else {
      setState(() {
        _errAccion  = r['error'] as String? ?? 'Error al procesar';
        _procesando = false;
      });
    }
  }

  void _mostrarSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: isError ? _danger : _green,
      duration:        const Duration(seconds: 3),
    ));
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: _border),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: _amberBg, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.warning_amber_rounded, color: _amber, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Gestión de Averías',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
        Text('${widget.nombreTienda} · productos con stock dañado',
          style: GoogleFonts.inter(fontSize: 12, color: _muted)),
      ])),
      IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
        splashRadius: 18,
      ),
    ]),
  );

  Widget _buildBody() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 36),
          const SizedBox(height: 12),
          Text(_error!, style: GoogleFonts.inter(color: _danger, fontSize: 13),
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ]),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_outline_rounded,
            color: _green, size: 40),
          const SizedBox(height: 12),
          Text('Sin averías registradas',
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
          const SizedBox(height: 4),
          Text('Todos los productos tienen stock de averías en cero.',
            style: GoogleFonts.inter(fontSize: 12, color: _muted),
            textAlign: TextAlign.center),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      itemCount: _items.length,
      separatorBuilder: (_, idx) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildItem(_items[i]),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final productoId    = item['producto'] as int;
    final nombre        = (item['producto_nombre'] ?? '') as String;
    final categoria     = (item['categoria_nombre'] ?? 'Sin categoría') as String;
    final stockAverias  = _toDouble(item['stock_averias']);
    final isExpanded    = _expandedId == productoId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:        isExpanded ? _bg : _surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: isExpanded ? _amber : _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Fila principal ──────────────────────────
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        _amberBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    color: _amber, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre,
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _text),
                overflow: TextOverflow.ellipsis),
              Text(categoria,
                style: GoogleFonts.inter(fontSize: 11, color: _muted)),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(stockAverias.toStringAsFixed(
                  stockAverias == stockAverias.roundToDouble() ? 0 : 2),
                style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _amber)),
              Text('en averías',
                style: GoogleFonts.inter(fontSize: 10, color: _muted)),
            ]),
            if (!isExpanded) ...[
              const SizedBox(width: 12),
              _btnAccion(
                label: 'Recuperar',
                icon:  Icons.refresh_rounded,
                color: _green, bg: _greenBg,
                onTap: () => _abrirAccion(productoId, 'recuperar'),
              ),
              const SizedBox(width: 6),
              _btnAccion(
                label: 'Descartar',
                icon:  Icons.delete_outline_rounded,
                color: _danger, bg: _dangerBg,
                onTap: () => _abrirAccion(productoId, 'descartar'),
              ),
            ] else ...[
              const SizedBox(width: 12),
              IconButton(
                onPressed: _procesando ? null : _cerrarAccion,
                icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
                splashRadius: 16,
              ),
            ],
          ]),

          // ── Formulario de acción ────────────────────
          if (isExpanded) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        _surface,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: _border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Selector recuperar / descartar
                Row(children: [
                  _chipAccion(
                    label:    'Recuperar al stock',
                    icon:     Icons.refresh_rounded,
                    accion:   'recuperar',
                    color:    _green,
                    bg:       _greenBg,
                  ),
                  const SizedBox(width: 8),
                  _chipAccion(
                    label:    'Descartar',
                    icon:     Icons.delete_outline_rounded,
                    accion:   'descartar',
                    color:    _danger,
                    bg:       _dangerBg,
                  ),
                ]),
                const SizedBox(height: 12),

                // Campo cantidad
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextField(
                      controller: _cantCtrl,
                      enabled:    !_procesando,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: GoogleFonts.inter(fontSize: 14, color: _text),
                      decoration: InputDecoration(
                        labelText:    'Cantidad (máx. $stockAverias)',
                        labelStyle:   GoogleFonts.inter(fontSize: 12, color: _muted),
                        errorText:    _errAccion,
                        errorStyle:   GoogleFonts.inter(fontSize: 11, color: _danger),
                        isDense:      true,
                        filled:       true,
                        fillColor:    _bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF006C49), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _procesando ? null : () => _confirmar(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accionSeleccionada == 'recuperar'
                            ? _green : _danger,
                        foregroundColor: Colors.white,
                        elevation:       0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _procesando
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                          : Text('Confirmar',
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _btnAccion({
    required String    label,
    required IconData  icon,
    required Color     color,
    required Color     bg,
    required VoidCallback onTap,
  }) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );

  Widget _chipAccion({
    required String   label,
    required IconData icon,
    required String   accion,
    required Color    color,
    required Color    bg,
  }) {
    final sel = _accionSeleccionada == accion;
    return GestureDetector(
      onTap: () => setState(() => _accionSeleccionada = accion),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        sel ? bg : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? color : _muted),
          const SizedBox(width: 5),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: sel ? color : _muted)),
        ]),
      ),
    );
  }
}
