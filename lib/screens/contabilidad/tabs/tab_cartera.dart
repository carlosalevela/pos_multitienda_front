// lib/screens/contabilidad/tabs/tab_cartera.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/venta_service.dart';
import '../../../theme/app_colors.dart';

class TabCartera extends StatefulWidget {
  final int? tiendaId;

  const TabCartera({super.key, this.tiendaId});

  @override
  State<TabCartera> createState() => _TabCarteraState();
}

class _TabCarteraState extends State<TabCartera>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = VentaService();

  Map<String, dynamic>? _data;
  bool _cargando = false;
  String? _error;

  // Expandido: cliente_id → bool
  final Set<int> _expandidos = {};

  // Abonar
  bool _procesandoAbono = false;

  static final _fmtCop = NumberFormat('#,##0', 'es_CO');
  static final _fmtFecha = DateFormat('dd MMM yy', 'es');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabCartera old) {
    super.didUpdateWidget(old);
    if (old.tiendaId != widget.tiendaId) _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = null; });
    final res = await _svc.getCartera(tiendaId: widget.tiendaId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _data = res['data'] as Map<String, dynamic>; _cargando = false; });
    } else {
      setState(() { _error = res['error']?.toString(); _cargando = false; });
    }
  }

  Future<void> _abonar(int ventaId, double saldoMax, String numero) async {
    final ctrl = TextEditingController();
    String metodo = 'efectivo';

    final monto = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Abonar a $numero',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldo pendiente: \$${_fmtCop.format(saldoMax)}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Monto a abonar',
                  prefixText: '\$ ',
                  hintText: _fmtCop.format(saldoMax),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Método de pago',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              const SizedBox(height: 6),
              Row(children: [
                for (final (val, icon, lbl) in [
                  ('efectivo',      Icons.payments_rounded,       'Efectivo'),
                  ('tarjeta',       Icons.credit_card_rounded,    'Tarjeta'),
                  ('transferencia', Icons.account_balance_rounded, 'Transf.'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setS(() => metodo = val),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: metodo == val
                                ? AppColors.mintLight
                                : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: metodo == val
                                  ? AppColors.secondary
                                  : AppColors.outlineVariant,
                            ),
                          ),
                          child: Column(children: [
                            Icon(icon, size: 16,
                                color: metodo == val
                                    ? AppColors.secondary
                                    : AppColors.onSurfaceVariant),
                            const SizedBox(height: 3),
                            Text(lbl,
                                style: GoogleFonts.inter(
                                    fontSize: 9, fontWeight: FontWeight.w600,
                                    color: metodo == val
                                        ? AppColors.secondary
                                        : AppColors.onSurfaceVariant)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
                if (v == null || v <= 0) return;
                if (v > saldoMax) return;
                Navigator.pop(ctx, v);
              },
              child: Text('Confirmar abono',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (monto == null || !mounted) return;

    setState(() => _procesandoAbono = true);
    final res = await _svc.abonarCredito(ventaId: ventaId, monto: monto, metodo: metodo);
    if (!mounted) return;
    setState(() => _procesandoAbono = false);

    if (res['success'] == true) {
      _mostrarSnack('Abono registrado correctamente', esError: false);
      await _cargar();
    } else {
      _mostrarSnack(res['error']?.toString() ?? 'Error al registrar abono', esError: true);
    }
  }

  void _mostrarSnack(String msg, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: esError ? AppColors.error : AppColors.secondary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 36, color: AppColors.error),
        const SizedBox(height: 10),
        Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text('Reintentar', style: GoogleFonts.inter()),
          style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
        ),
      ]));
    }

    final total       = (_data?['total_cartera'] as num?)?.toDouble() ?? 0;
    final numClientes = (_data?['num_clientes']  as num?)?.toInt()    ?? 0;
    final cartera     = (_data?['cartera']        as List?) ?? [];

    if (cartera.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.mintLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.handshake_rounded, size: 30, color: AppColors.secondary),
        ),
        const SizedBox(height: 14),
        Text('Sin créditos pendientes',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('Todos los créditos han sido cobrados',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline)),
      ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // KPIs
      Row(children: [
        _kpi(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Cartera total',
          value: '\$${_fmtCop.format(total)}',
          color: AppColors.error,
          bg:    AppColors.errorContainer,
        ),
        const SizedBox(width: 12),
        _kpi(
          icon: Icons.people_alt_rounded,
          label: 'Clientes con deuda',
          value: '$numClientes',
          color: AppColors.warning,
          bg:    AppColors.warningContainer,
        ),
        const SizedBox(width: 12),
        _kpi(
          icon: Icons.receipt_long_rounded,
          label: 'Facturas pendientes',
          value: '${cartera.fold<int>(0, (s, c) => s + ((c['num_facturas'] as num?)?.toInt() ?? 0))}',
          color: AppColors.secondary,
          bg:    AppColors.mintLight,
        ),
      ]),

      const SizedBox(height: 16),

      // Encabezado lista
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Clientes con créditos pendientes',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.secondary),
          tooltip: 'Actualizar',
          onPressed: _cargando ? null : _cargar,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),

      const SizedBox(height: 8),

      // Lista
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ListView.separated(
              itemCount: cartera.length,
              separatorBuilder: (ctx, idx) =>
                  const Divider(height: 1, color: AppColors.surfaceContainerLow),
              itemBuilder: (_, i) {
                final c          = cartera[i] as Map<String, dynamic>;
                final clienteId  = (c['cliente_id'] as num).toInt();
                final nombre     = c['cliente_nombre'] as String;
                final deuda      = (c['deuda_total']  as num).toDouble();
                final limite     = (c['limite_credito'] as num).toDouble();
                final numFact    = (c['num_facturas'] as num).toInt();
                final ventas     = (c['ventas'] as List?) ?? [];
                final expandido  = _expandidos.contains(clienteId);
                final utilizado  = limite > 0 ? (deuda / limite).clamp(0.0, 1.0) : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila cliente
                    InkWell(
                      onTap: () => setState(() {
                        if (expandido) { _expandidos.remove(clienteId); }
                        else           { _expandidos.add(clienteId); }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                        child: Row(children: [
                          // Avatar
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                                style: GoogleFonts.inter(
                                    fontSize: 15, fontWeight: FontWeight.w700,
                                    color: AppColors.error),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Info
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(nombre,
                                      style: GoogleFonts.inter(
                                          fontSize: 13, fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                Text('\$${_fmtCop.format(deuda)}',
                                    style: GoogleFonts.inter(
                                        fontSize: 14, fontWeight: FontWeight.w800,
                                        color: AppColors.error)),
                              ]),
                              const SizedBox(height: 4),
                              if (limite > 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('$numFact factura${numFact != 1 ? 's' : ''}',
                                        style: GoogleFonts.inter(
                                            fontSize: 11, color: AppColors.outline)),
                                    Text(
                                      'Límite: \$${_fmtCop.format(limite)}',
                                      style: GoogleFonts.inter(
                                          fontSize: 11, color: AppColors.outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value:           utilizado,
                                    minHeight:       4,
                                    backgroundColor: AppColors.surfaceContainerLow,
                                    valueColor: AlwaysStoppedAnimation(
                                      utilizado > 0.9
                                          ? AppColors.error
                                          : utilizado > 0.6
                                              ? AppColors.warning
                                              : AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ] else
                                Text('$numFact factura${numFact != 1 ? 's' : ''}',
                                    style: GoogleFonts.inter(
                                        fontSize: 11, color: AppColors.outline)),
                            ],
                          )),

                          const SizedBox(width: 8),
                          Icon(
                            expandido
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ]),
                      ),
                    ),

                    // Facturas expandidas
                    if (expandido)
                      Container(
                        color: AppColors.surfaceContainerLow,
                        child: Column(
                          children: ventas.map<Widget>((v) {
                            final vMap    = v as Map<String, dynamic>;
                            final vId     = (vMap['id'] as num).toInt();
                            final numero  = vMap['numero_factura'] as String;
                            final saldo   = (vMap['saldo_pendiente'] as num).toDouble();
                            final total   = (vMap['total'] as num).toDouble();
                            final fecha   = DateTime.tryParse(
                                vMap['fecha'] as String? ?? '') ?? DateTime.now();
                            final tienda  = vMap['tienda'] as String? ?? '';
                            final pagado  = total - saldo;
                            final pct     = total > 0 ? (pagado / total).clamp(0.0, 1.0) : 0.0;

                            return Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: AppColors.outlineVariant),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
                                child: Row(children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.outlineVariant),
                                    ),
                                    child: const Icon(Icons.receipt_rounded,
                                        size: 15, color: AppColors.onSurfaceVariant),
                                  ),
                                  const SizedBox(width: 10),

                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                        Text(numero,
                                            style: GoogleFonts.inter(
                                                fontSize: 12, fontWeight: FontWeight.w600,
                                                color: AppColors.onSurface)),
                                        Text('\$${_fmtCop.format(saldo)} pendiente',
                                            style: GoogleFonts.inter(
                                                fontSize: 12, fontWeight: FontWeight.w700,
                                                color: AppColors.error)),
                                      ]),
                                      const SizedBox(height: 3),
                                      Row(children: [
                                        Text(_fmtFecha.format(fecha.toLocal()),
                                            style: GoogleFonts.inter(
                                                fontSize: 10, color: AppColors.outline)),
                                        if (tienda.isNotEmpty) ...[
                                          const Text(' · ',
                                              style: TextStyle(color: AppColors.outline)),
                                          Text(tienda,
                                              style: GoogleFonts.inter(
                                                  fontSize: 10, color: AppColors.outline)),
                                        ],
                                        const Spacer(),
                                        Text('Pagado: \$${_fmtCop.format(pagado)} / '
                                            '\$${_fmtCop.format(total)}',
                                            style: GoogleFonts.inter(
                                                fontSize: 10, color: AppColors.onSurfaceVariant)),
                                      ]),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          minHeight: 3,
                                          backgroundColor: AppColors.surfaceContainerLow,
                                          valueColor: const AlwaysStoppedAnimation(
                                              AppColors.secondary),
                                        ),
                                      ),
                                    ],
                                  )),

                                  const SizedBox(width: 10),

                                  // Botón abonar
                                  _procesandoAbono
                                      ? const SizedBox(
                                          width: 24, height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.secondary),
                                        )
                                      : GestureDetector(
                                          onTap: () => _abonar(vId, saldo, numero),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.mintLight,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: AppColors.secondary
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              const Icon(Icons.payments_rounded,
                                                  size: 13, color: AppColors.secondary),
                                              const SizedBox(width: 4),
                                              Text('Abonar',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.secondary)),
                                            ]),
                                          ),
                                        ),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _kpi({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    color,
    required Color    bg,
  }) =>
    Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.onSurface)),
          ]),
        ]),
      ),
    );
}
