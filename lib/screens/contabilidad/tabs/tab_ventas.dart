// lib/screens/contabilidad/tabs/tab_ventas.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../services/venta_service.dart';
import '../../../providers/auth_provider.dart';

class TabVentas extends StatefulWidget {
  final int?         tiendaId;
  final AuthProvider auth;

  const TabVentas({
    super.key,
    required this.tiendaId,
    required this.auth,
  });

  @override
  State<TabVentas> createState() => _TabVentasState();
}

class _TabVentasState extends State<TabVentas> {
  final _service = VentaService();
  final _fmt     = NumberFormat('#,##0', 'es_CO');
  final _fmtDate = DateFormat('d MMM yyyy', 'es');
  final _fmtHora = DateFormat('HH:mm', 'es');

  List<Map<String, dynamic>> _ventas    = [];
  bool   _cargando  = false;
  String _error     = '';
  String _fecha     = DateFormat('yyyy-MM-dd').format(DateTime.now());
  int?   _anulando;

  // ── Design tokens (matching inventario_screen) ──────
  static const _surface  = Colors.white;
  static const _border   = Color(0xFFE2E8F0);
  static const _text     = Color(0xFF1E293B);
  static const _muted    = Color(0xFF64748B);
  static const _muted2   = Color(0xFF94A3B8);
  static const _danger   = Color(0xFFBA1A1A);
  static const _dangerBg = Color(0xFFFFDAD6);
  static const _warning  = Color(0xFFF59E0B);
  static const _green    = Color(0xFF006C49);
  static const _greenBg  = Color(0xFFDCFCE7);
  static const _surfLow  = Color(0xFFF8FAFC);

  TextStyle _t({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize:      size,
        fontWeight:    weight,
        color:         color ?? _text,
        letterSpacing: letterSpacing,
      );

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabVentas old) {
    super.didUpdateWidget(old);
    if (old.tiendaId != widget.tiendaId) _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = ''; });
    try {
      final list = await _service.listarVentas(
        tiendaId: widget.tiendaId,
        fecha:    _fecha,
      );
      if (mounted) setState(() { _ventas = list; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error al cargar ventas'; _cargando = false; });
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context:      context,
      initialDate:  DateTime.tryParse(_fecha) ?? DateTime.now(),
      firstDate:    DateTime(2020),
      lastDate:     DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   AppColors.secondary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _fecha = DateFormat('yyyy-MM-dd').format(picked));
    _cargar();
  }

  Future<void> _anular(Map<String, dynamic> venta) async {
    final id       = venta['id'] as int;
    final nroFact  = venta['numero_factura'] ?? '#$id';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: _danger, size: 22),
          const SizedBox(width: 8),
          Text('Anular venta', style: _t(size: 16, weight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Anular la venta $nroFact?',
                style: _t(size: 14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'El stock de todos los productos será restaurado. '
              'Esta acción no se puede deshacer.',
              style: _t(size: 13, color: _muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: _t(size: 13, color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sí, anular',
                style: _t(size: 13, weight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _anulando = id);
    final result = await _service.anularVenta(id);
    if (!mounted) return;
    setState(() => _anulando = null);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Venta $nroFact anulada. Stock restaurado.',
            style: _t(size: 13, color: Colors.white)),
        backgroundColor: _green,
        duration: const Duration(seconds: 3),
      ));
      _cargar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['error'] ?? 'Error al anular',
            style: _t(size: 13, color: Colors.white)),
        backgroundColor: _danger,
      ));
    }
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final esAdmin = widget.auth.esAdmin || widget.auth.esSuperadmin
        || widget.auth.esSupervisor;

    final completadas = _ventas.where((v) => v['estado'] == 'completada').length;
    final anuladas    = _ventas.where((v) => v['estado'] == 'anulada').length;
    final totalDia    = _ventas
        .where((v) => v['estado'] == 'completada')
        .fold<double>(0, (s, v) => s + _toDouble(v['total']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Toolbar ─────────────────────────────────────
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _seleccionarFecha,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 15, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    _fecha == DateFormat('yyyy-MM-dd').format(DateTime.now())
                        ? 'Hoy, ${_fmtDate.format(DateTime.now())}'
                        : _fmtDate.format(DateTime.tryParse(_fecha) ?? DateTime.now()),
                    style: _t(size: 13, weight: FontWeight.w600,
                        color: AppColors.secondary),
                  ),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppColors.onSurfaceVariant),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _cargando ? null : _cargar,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: _cargando
                  ? const Center(child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: AppColors.secondary)))
                  : const Icon(Icons.refresh_rounded, size: 18,
                      color: AppColors.onSurfaceVariant),
            ),
          ),
        ]),

        const SizedBox(height: 14),

        // ── KPIs ────────────────────────────────────────
        if (!_cargando && _ventas.isNotEmpty) ...[
          Row(children: [
            Expanded(child: _kpi('\$${_fmt.format(totalDia)}',
                'Ingresos del día', AppColors.secondary,
                AppColors.mintLight, Icons.payments_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _kpi('$completadas',
                'Ventas completadas', _green, _greenBg,
                Icons.check_circle_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _kpi('$anuladas',
                'Ventas anuladas',
                anuladas > 0 ? _danger : _muted2,
                anuladas > 0 ? _dangerBg : const Color(0xFFF1F5F9),
                Icons.cancel_rounded)),
          ]),
          const SizedBox(height: 14),
        ],

        // ── Error ────────────────────────────────────────
        if (_error.isNotEmpty)
          _banner(_error, isError: true),

        // ── Lista ────────────────────────────────────────
        Expanded(child: _body(esAdmin)),
      ],
    );
  }

  Widget _body(bool esAdmin) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(
          color: AppColors.secondary, strokeWidth: 2));
    }
    if (_ventas.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _surfLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 30, color: _muted2),
          ),
          const SizedBox(height: 16),
          Text('Sin ventas en esta fecha',
              style: _t(size: 15, weight: FontWeight.w600, color: _muted)),
          const SizedBox(height: 6),
          Text('Selecciona otra fecha o verifica los filtros',
              style: _t(size: 13, color: _muted2)),
        ],
      ));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _ventas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _ventaCard(_ventas[i], esAdmin),
    );
  }

  Widget _ventaCard(Map<String, dynamic> v, bool esAdmin) {
    final id        = v['id'] as int;
    final nroFact   = v['numero_factura'] as String? ?? '#$id';
    final cliente   = v['cliente_nombre'] as String? ?? 'Consumidor Final';
    final cajero    = v['empleado_nombre'] as String? ?? '—';
    final total     = _toDouble(v['total']);
    final metodo    = _labelMetodo(v['metodo_pago'] as String? ?? '');
    final estado    = v['estado'] as String? ?? 'completada';
    final createdAt = v['created_at'] as String?;
    final hora      = createdAt != null
        ? _fmtHora.format(DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now())
        : '';
    final anulada    = estado == 'anulada';
    final esAnulando = _anulando == id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: anulada ? const Color(0xFFFFF8F7) : _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: anulada ? _danger.withValues(alpha: 0.2) : _border,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Badge estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: anulada ? _dangerBg : _greenBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                anulada ? 'ANULADA' : 'COMPLETADA',
                style: _t(size: 9, weight: FontWeight.w800,
                    color: anulada ? _danger : _green, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(nroFact,
                style: _t(size: 13, weight: FontWeight.w700)),
            const Spacer(),
            Text(hora, style: _t(size: 12, color: _muted2)),
          ]),

          const SizedBox(height: 10),

          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person_outline_rounded, cliente),
                const SizedBox(height: 4),
                _infoRow(Icons.badge_outlined, cajero),
                const SizedBox(height: 4),
                _infoRow(_iconMetodo(v['metodo_pago'] as String? ?? ''), metodo),
              ],
            )),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${_fmt.format(total)}',
                  style: _t(size: 17, weight: FontWeight.w800,
                      color: anulada ? _muted2 : _text)),
              if (anulada)
                Text('Anulada', style: _t(size: 10, color: _danger,
                    weight: FontWeight.w600)),
            ]),
          ]),

          // Botón anular (solo admin + completada)
          if (esAdmin && !anulada) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: esAnulando
                  ? const Center(child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: _danger)))
                  : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _danger,
                        side: const BorderSide(color: _danger, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: () => _anular(v),
                      icon: const Icon(Icons.block_rounded, size: 15),
                      label: Text('Anular venta',
                          style: _t(size: 12, weight: FontWeight.w600,
                              color: _danger)),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label) => Row(children: [
    Icon(icon, size: 13, color: _muted2),
    const SizedBox(width: 5),
    Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
        style: _t(size: 12, color: _muted))),
  ]);

  Widget _kpi(String value, String label, Color color, Color bg, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: bg,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: _t(size: 15, weight: FontWeight.w800, color: color)),
              Text(label, style: _t(size: 9, color: _muted2), maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      );

  Widget _banner(String msg, {required bool isError}) {
    final color = isError ? _danger : _green;
    final bg    = isError ? _dangerBg : _greenBg;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: _t(size: 12, color: color))),
      ]),
    );
  }

  // ── Helpers ─────────────────────────────────────────────
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _labelMetodo(String m) {
    return switch (m) {
      'efectivo'     => 'Efectivo',
      'tarjeta'      => 'Tarjeta',
      'transferencia'=> 'Transferencia',
      'mixto'        => 'Pago mixto',
      _              => m.isNotEmpty ? m[0].toUpperCase() + m.substring(1) : '—',
    };
  }

  IconData _iconMetodo(String m) {
    return switch (m) {
      'efectivo'      => Icons.payments_outlined,
      'tarjeta'       => Icons.credit_card_outlined,
      'transferencia' => Icons.account_balance_outlined,
      'mixto'         => Icons.swap_horiz_rounded,
      _               => Icons.attach_money_rounded,
    };
  }
}
