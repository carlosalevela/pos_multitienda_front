import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../services/cuenta_bancaria_service.dart';

class TabCuentasBancarias extends StatefulWidget {
  final int? tiendaId;
  const TabCuentasBancarias({super.key, required this.tiendaId});

  @override
  State<TabCuentasBancarias> createState() => _TabCuentasBancariaState();
}

class _TabCuentasBancariaState extends State<TabCuentasBancarias> {
  final _fmt = NumberFormat('#,##0', 'es_CO');
  List<Map<String, dynamic>> _cuentas = [];
  bool _cargando = false;
  String _error   = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabCuentasBancarias old) {
    super.didUpdateWidget(old);
    if (old.tiendaId != widget.tiendaId) _cargar();
  }

  Future<void> _cargar() async {
    final tid = widget.tiendaId;
    if (tid == null) {
      setState(() { _cuentas = []; _error = ''; });
      return;
    }
    setState(() { _cargando = true; _error = ''; });
    try {
      final data = await CuentaBancariaService().resumen(tid);
      if (mounted) setState(() { _cuentas = data; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  String _m(double v) => '\$${_fmt.format(v.abs())}';

  IconData _icon(String tipo) {
    switch (tipo) {
      case 'tarjeta':     return Icons.credit_card_rounded;
      case 'nequi':
      case 'daviplata':   return Icons.phone_android_rounded;
      default:            return Icons.account_balance_rounded;
    }
  }

  Color _color(String tipo) {
    switch (tipo) {
      case 'tarjeta':     return const Color(0xFF0047AB);
      case 'nequi':       return const Color(0xFF6750A4);
      case 'daviplata':   return const Color(0xFFB45309);
      default:            return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tiendaId == null) {
      return _centrado(Icons.store_rounded, 'Selecciona una tienda para ver sus cuentas');
    }
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 2.5));
    }
    if (_error.isNotEmpty) {
      return _centrado(Icons.error_outline_rounded, 'Error al cargar cuentas: $_error');
    }
    if (_cuentas.isEmpty) {
      return _centrado(Icons.account_balance_wallet_outlined, 'No hay cuentas bancarias registradas con movimientos');
    }

    final totalAcum = _cuentas.fold(0.0, (s, c) => s + ((c['total_acumulado'] as num?)?.toDouble() ?? 0.0));

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Banner total acumulado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL ACUMULADO EN CUENTAS',
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(_m(totalAcum),
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 32,
                    fontWeight: FontWeight.w800, letterSpacing: -1.5)),
            const SizedBox(height: 4),
            Text('Suma de todas las cuentas de tarjeta / transferencia',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 20),

        Text('Detalle por cuenta',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
        const SizedBox(height: 12),

        ..._cuentas.map((c) {
          final nombre   = c['nombre']?.toString() ?? '—';
          final tipo     = c['tipo']?.toString() ?? '';
          final display  = c['tipo_display']?.toString() ?? tipo;
          final numero   = c['numero']?.toString() ?? '';
          final turno    = (c['sesion_total'] as num?)?.toDouble() ?? 0.0;
          final acum     = (c['total_acumulado'] as num?)?.toDouble() ?? 0.0;
          final color    = _color(tipo);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 6,
              )],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(tipo), color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                Text('$display${numero.isNotEmpty ? " · $numero" : ""}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.onSurfaceVariant)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_m(acum),
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Último turno: ${_m(turno)}',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          );
        }),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'El acumulado incluye todas las ventas completadas dirigidas a cada cuenta. '
                'No incluye abonos por tarjeta/transferencia de pedidos separados.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Botón recargar
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: Text('Actualizar', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
          ),
        ),
      ]),
    );
  }

  Widget _centrado(IconData icon, String msg) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: AppColors.outlineVariant),
      const SizedBox(height: 12),
      Text(msg,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13)),
    ]),
  );
}
