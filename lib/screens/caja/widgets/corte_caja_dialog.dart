import 'dart:async' show unawaited;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caja_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../services/windows_printer_service.dart';
import '../../../models/contabilidad_models.dart';
import '../../../models/resumen_cierre.dart';
import 'registro_movimiento_diario.dart';
import '../../../models/sesion_caja.dart';
import '../../../models/sesion_historial.dart';
import '../../../services/caja_service.dart';
import '../../../services/contabilidad_service.dart';
import '../../../services/cuenta_bancaria_service.dart';
import '../../../services/documento_service.dart';
import '../../../services/formato_pdf_service.dart';
import 'pdf/cierre_pdf.dart';

// ── Enterprise palette ─────────────────────────────────────────
const _cGreen    = Color(0xFF006C49);
const _cGreenLt  = Color(0xFFD6F5E7);
const _cNavy     = Color(0xFF131B2E);
const _cRed      = Color(0xFFBA1A1A);
const _cRedLt    = Color(0xFFFFDAD6);
const _cBlue     = Color(0xFF0047AB);
const _cBlueLt   = Color(0xFFD8E4FF);
const _cAmber    = Color(0xFFB45309);
const _cAmberLt  = Color(0xFFFEF3C7);
const _cPurple   = Color(0xFF6750A4);
const _cSky      = Color(0xFF0369A1);
const _cSkyLt    = Color(0xFFDCF0FB);
const _cBg       = Color(0xFFF4F6F8);
const _cSurface  = Color(0xFFFFFFFF);
const _cBorder   = Color(0xFFE0E3E7);
const _cText     = Color(0xFF191C1E);
const _cTextSec  = Color(0xFF43474E);
const _cTextMuted = Color(0xFF73777F);

class CorteCajaDialog extends StatefulWidget {
  const CorteCajaDialog({super.key});

  @override
  State<CorteCajaDialog> createState() => _CorteCajaDialogState();
}

class _CorteCajaDialogState extends State<CorteCajaDialog>
    with SingleTickerProviderStateMixin {
  int    _paso           = 1;
  double _montoIngresado = 0;
  final  _montoCtrl      = TextEditingController();
  final  _obsCtrl        = TextEditingController();
  final  _fmt            = NumberFormat('#,##0', 'en_US');
  List<Map<String, dynamic>> _resumenCuentas = [];

  late AnimationController _stepCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _pasoLabels = ['Resumen', 'Conteo', 'Resultado', 'Registro'];

  // ── Paso 4: datos del cierre ya completado (guardados al cerrar caja) ──
  int?    _p4SesionId;
  double? _p4MontoFinal;
  String  _p4Obs      = '';
  dynamic _p4TipoPapel;
  ResumenCierre? _p4Resumen;
  String _p4Nit = '', _p4Dir = '', _p4Tel = '';
  int    _p4TiendaId  = 0;
  ScaffoldMessengerState? _p4Msgr;


  @override
  void initState() {
    super.initState();
    _stepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _fadeAnim  = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.03, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut));
    _stepCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarResumenCuentas());
  }

  Future<void> _cargarResumenCuentas() async {
    final resumen  = context.read<CajaProvider>().resumenCierre;
    final tiendaId = context.read<AuthProvider>().tiendaId;
    if (resumen == null || tiendaId <= 0) return;
    final data = await CuentaBancariaService()
        .resumen(tiendaId, sesionId: resumen.sesionId);
    if (mounted) setState(() => _resumenCuentas = data);
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _obsCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  String _f(double v) => '\$${_fmt.format(v)}';

  String _formatFecha(String fecha) {
    try {
      final dt = DateTime.parse(fecha.replaceAll(' ', 'T')).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} '
             '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      if (fecha.length >= 16) return fecha.substring(0, 16).replaceAll('T', ' ');
      return fecha.replaceAll('T', ' ');
    }
  }

  double get _diferencia =>
      _montoIngresado -
      (context.read<CajaProvider>().resumenCierre?.montoEsperadoCaja ?? 0);

  void _irAPaso(int paso) {
    _stepCtrl.reset();
    setState(() => _paso = paso);
    _stepCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final cont    = context.watch<CajaProvider>();
    final resumen = cont.resumenCierre;

    // En paso 4 el resumen del provider puede ser null (caja ya cerrada), usar el guardado
    if (resumen == null && _paso != 4) {
      return Dialog(
        backgroundColor: _cSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const SizedBox(
          width: 360,
          child: Padding(
            padding: EdgeInsets.all(56),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: _cGreen, strokeWidth: 2.5),
              SizedBox(height: 20),
              Text('Cargando resumen del turno…',
                  style: TextStyle(color: _cTextMuted, fontSize: 13)),
            ]),
          ),
        ),
      );
    }
    // Para paso 4 usamos el resumen guardado antes del cierre
    final effectiveResumen = resumen ?? _p4Resumen!;

    final screenSize   = MediaQuery.of(context).size;
    final dialogWidth  = (screenSize.width  * 0.88).clamp(700.0, 880.0);
    final dialogHeight = (screenSize.height * 0.92).clamp(520.0, 920.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width:  dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: _cBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          _buildHeader(effectiveResumen),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _paso == 1
                    ? _buildPaso1(effectiveResumen)
                    : _paso == 2
                        ? _buildPaso2(effectiveResumen)
                        : _paso == 3
                            ? _buildPaso3(effectiveResumen)
                            : _buildPaso4(_p4Resumen ?? effectiveResumen),
              ),
            ),
          ),
          _buildFooter(cont),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // HEADER — verde institucional con stepper
  // ══════════════════════════════════════════════════
  Widget _buildHeader(ResumenCierre r) {
    return Container(
      color: _cGreen,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 20, 14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _cGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Corte de Caja',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text(r.tiendaNombre,
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(11)),
                  child: Center(
                    child: Text(
                      r.empleadoNombre.isNotEmpty
                          ? r.empleadoNombre[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(r.empleadoNombre,
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),

        // Stepper
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          child: Row(children: List.generate(4, (i) {
            final idx    = i + 1;
            final activo = idx == _paso;
            final pasado = idx < _paso;
            return Expanded(child: Row(children: [
              Expanded(child: _StepDot(
                index: idx, label: _pasoLabels[i],
                activo: activo, pasado: pasado,
              )),
              if (i < 3)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 22),
                    color: pasado
                        ? _cGreen
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
            ]));
          })),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // PASO 1 — Resumen completo en 4 cards
  // ══════════════════════════════════════════════════
  Widget _buildPaso1(ResumenCierre r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(children: [

        // Barra de info del turno
        _TurnoBar(r: r, formatFecha: _formatFecha),
        const SizedBox(height: 16),

        // Fila 1: Ventas | Gastos
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _DataCard(
            titulo: 'Ventas del Turno',
            icono: Icons.trending_up_rounded,
            accentColor: _cGreen,
            accentBg: _cGreenLt,
            child: Column(children: [
              _ItemRow('Efectivo',      r.ventas.efectivo,      _cGreen,  Icons.payments_rounded),
              _ItemRow('Tarjeta',       r.ventas.tarjeta,       _cBlue,   Icons.credit_card_rounded),
              _ItemRow('Transferencia', r.ventas.transferencia, _cPurple, Icons.swap_horiz_rounded),
              if (r.ventas.mixto > 0)
                _ItemRow('Mixto',       r.ventas.mixto,         _cAmber,  Icons.compare_arrows_rounded),
              if (r.ventas.bono > 0)
                _ItemRow('Bono (100%)',    r.ventas.bono,              _cAmber, Icons.card_giftcard_rounded),
              if (r.ventas.bonoEfectivo > 0)
                _ItemRow('Bono+Ef. (ef.)', r.ventas.bonoEfectivo,     _cGreen, Icons.card_giftcard_rounded),
              if (r.ventas.bonoTarjeta > 0)
                _ItemRow('Bono+Tar.',      r.ventas.bonoTarjeta,      _cBlue,  Icons.card_giftcard_rounded),
              if (r.ventas.bonoTransferencia > 0)
                _ItemRow('Bono+Tra.',      r.ventas.bonoTransferencia, _cPurple, Icons.card_giftcard_rounded),
              const _CardDiv(),
              _TotalRow('TOTAL VENTAS', _f(r.ventas.total), _cNavy),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _Chip('${r.ventas.numTransacciones} transacciones', _cBlue, _cBlueLt),
              ]),
            ]),
          )),
          const SizedBox(width: 12),
          Expanded(child: _DataCard(
            titulo: 'Gastos del Turno',
            icono: Icons.trending_down_rounded,
            accentColor: _cRed,
            accentBg: _cRedLt,
            child: r.gastos.detalle.isEmpty
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _EmptyHint('Sin gastos registrados en este turno'),
                  ])
                : Column(children: [
                    ...r.gastos.detalle.map(
                      (g) => _GastoRow(g.categoria, g.metodoPago, g.monto)),
                    const _CardDiv(),
                    _TotalRow('TOTAL GASTOS', '-${_f(r.gastos.total)}', _cRed),
                  ]),
          )),
        ])),
        const SizedBox(height: 12),

        // Fila 2: Abonos | Devoluciones
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _DataCard(
            titulo: 'Abonos / Separados',
            icono: Icons.bookmark_added_rounded,
            accentColor: _cSky,
            accentBg: _cSkyLt,
            child: r.abonos.total <= 0
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _EmptyHint('Sin abonos recibidos en este turno'),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Detalle individual con cuenta (si viene del backend)
                    if (r.abonos.detalle.isNotEmpty) ...[
                      ...r.abonos.detalle.map((a) {
                        final monto  = (a['monto'] as num?)?.toDouble() ?? 0.0;
                        final metodo = a['metodo_pago']?.toString() ?? '';
                        final cuenta = a['cuenta_nombre']?.toString() ?? '';
                        final hora   = a['hora']?.toString() ?? '';
                        final label  = cuenta.isNotEmpty ? cuenta
                            : metodo == 'efectivo'      ? 'Efectivo'
                            : metodo == 'tarjeta'       ? 'Datáfono'
                            : 'Transferencia';
                        final icon   = metodo == 'efectivo'      ? Icons.payments_rounded
                            : metodo == 'tarjeta'       ? Icons.credit_card_rounded
                            : Icons.swap_horiz_rounded;
                        final color  = metodo == 'efectivo' ? _cGreen
                            : metodo == 'tarjeta'       ? _cBlue
                            : _cPurple;
                        return _ItemRow(
                          hora.isNotEmpty ? '$label  $hora' : label,
                          monto, color, icon,
                        );
                      }),
                    ] else ...[
                      if (r.abonos.efectivo > 0)
                        _ItemRow('Efectivo',      r.abonos.efectivo,      _cGreen,  Icons.payments_rounded),
                      if (r.abonos.tarjeta > 0)
                        _ItemRow('Tarjeta',       r.abonos.tarjeta,       _cBlue,   Icons.credit_card_rounded),
                      if (r.abonos.transferencia > 0)
                        _ItemRow('Transferencia', r.abonos.transferencia, _cPurple, Icons.swap_horiz_rounded),
                    ],
                    const _CardDiv(),
                    _TotalRow('TOTAL ABONOS', _f(r.abonos.total), _cSky),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        const Icon(Icons.info_outline_rounded, size: 10, color: _cTextMuted),
                        const SizedBox(width: 4),
                        Text('Solo efectivo en caja',
                            style: GoogleFonts.inter(fontSize: 9, color: _cTextMuted)),
                      ]),
                      _Chip(
                        '${r.abonos.cantidad} abono${r.abonos.cantidad != 1 ? "s" : ""}',
                        _cSky, _cSkyLt,
                      ),
                    ]),
                  ]),
          )),
          const SizedBox(width: 12),
          Expanded(child: _DataCard(
            titulo: 'Devoluciones',
            icono: Icons.assignment_return_rounded,
            accentColor: _cAmber,
            accentBg: _cAmberLt,
            child: r.devoluciones.cantidad == 0
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _EmptyHint('Sin devoluciones en este turno'),
                  ])
                : Column(children: [
                    if (r.devoluciones.cambiosProducto > 0) ...[
                      _MontoRow(
                        'Cambios de producto',
                        r.devoluciones.cambiosProducto.toDouble(),
                        isNeg: false,
                        isCount: true,
                        countLabel: '${r.devoluciones.cambiosProducto} cambio${r.devoluciones.cambiosProducto != 1 ? "s" : ""}',
                        subLabel: 'Sin salida de efectivo',
                      ),
                      if (r.devoluciones.efectivo > 0 ||
                          r.devoluciones.cambiosDevolver > 0 ||
                          r.devoluciones.cambiosCobrar > 0)
                        const _CardDiv(),
                    ],
                    if (r.devoluciones.efectivo > 0)
                      _MontoRow('Dev. efectivo',  r.devoluciones.efectivo,        isNeg: true),
                    if (r.devoluciones.cambiosDevolver > 0)
                      _MontoRow('Dif. devuelta',  r.devoluciones.cambiosDevolver, isNeg: true),
                    if (r.devoluciones.cambiosCobrar > 0)
                      _MontoRow('Dif. cobrada',   r.devoluciones.cambiosCobrar,   isNeg: false),
                    if (r.devoluciones.netoEfectivo != 0) ...[
                      const _CardDiv(),
                      _TotalRow(
                        'NETO EFECTIVO',
                        r.devoluciones.netoEfectivo > 0
                            ? '-${_f(r.devoluciones.netoEfectivo)}'
                            : '+${_f(-r.devoluciones.netoEfectivo)}',
                        r.devoluciones.netoEfectivo > 0 ? _cRed : _cGreen,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      _Chip(
                        '${r.devoluciones.cantidad} devolucion${r.devoluciones.cantidad != 1 ? "es" : ""}',
                        _cAmber, _cAmberLt,
                      ),
                    ]),
                  ]),
          )),
        ])),
        const SizedBox(height: 12),

        // Card anulaciones — solo si hubo anulaciones en el turno
        if (r.anulaciones.cantidad > 0)
          _DataCard(
            titulo: 'Anulaciones del Turno',
            icono: Icons.block_rounded,
            accentColor: _cRed,
            accentBg: _cRedLt,
            child: Column(children: [
              ...r.anulaciones.detalle.map((a) {
                final numero  = a['numero_factura']?.toString() ?? '—';
                final hora    = a['hora']?.toString()           ?? '—';
                final total   = double.tryParse(a['total']?.toString() ?? '0') ?? 0.0;
                final metodo  = a['metodo_pago']?.toString()    ?? '';
                final emp     = a['empleado']?.toString()       ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    const Icon(Icons.cancel_outlined, size: 14, color: _cRed),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, children: [
                      Text(numero,
                          style: GoogleFonts.inter(fontSize: 12,
                              fontWeight: FontWeight.w600, color: _cText)),
                      Text('$hora · $metodo${emp.isNotEmpty ? " · $emp" : ""}',
                          style: GoogleFonts.inter(fontSize: 10, color: _cTextMuted)),
                    ])),
                    Text('-${_f(total)}',
                        style: GoogleFonts.inter(fontSize: 13,
                            fontWeight: FontWeight.w700, color: _cRed)),
                  ]),
                );
              }),
              const _CardDiv(),
              _TotalRow('TOTAL ANULADO', '-${_f(r.anulaciones.totalAnulado)}', _cRed),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _Chip(
                  '${r.anulaciones.cantidad} anulacion${r.anulaciones.cantidad != 1 ? "es" : ""}',
                  _cRed, _cRedLt,
                ),
              ]),
            ]),
          ),
        if (r.anulaciones.cantidad > 0) const SizedBox(height: 12),

        // Card ingresos por cuenta — ancho completo
        if (_resumenCuentas.isNotEmpty)
          _DataCard(
            titulo: 'Ingresos por Cuenta',
            icono: Icons.account_balance_wallet_rounded,
            accentColor: _cPurple,
            accentBg: const Color(0xFFEDE7F6),
            child: Column(children: [
              ..._resumenCuentas.map((c) {
                final nombre   = c['nombre']?.toString()       ?? '—';
                final tipo     = c['tipo_display']?.toString() ?? '';
                final turno    = double.tryParse(c['sesion_total']?.toString()    ?? '0') ?? 0;
                final acum     = double.tryParse(c['total_acumulado']?.toString() ?? '0') ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 14, color: _cPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, children: [
                        Text(nombre,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: _cText)),
                        Text(tipo,
                            style: GoogleFonts.inter(
                                fontSize: 10, color: _cTextMuted)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min, children: [
                      Text(_f(turno),
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _cPurple)),
                      Text('acum. ${_f(acum)}',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _cTextMuted)),
                    ]),
                  ]),
                );
              }),
            ]),
          ),
        const SizedBox(height: 12),

        // Card calculo caja fisica — ancho completo
        _CajaEsperadaCard(r: r, f: _f),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // PASO 2 — Conteo físico
  // ══════════════════════════════════════════════════
  Widget _buildPaso2(ResumenCierre r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        // Hero monto esperado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _cGreen,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(children: [
            Text('Esperado en caja',
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Text(_f(r.montoEsperadoCaja),
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 48, letterSpacing: -2)),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10, runSpacing: 6,
              children: [
                _EsperadoChip('Inicial',       _f(r.montoInicial)),
                _EsperadoChip('Ventas ef.',    _f(r.ventas.efectivo)),
                if (r.ventas.mixtoEfectivo > 0)
                  _EsperadoChip('Mixto ef.',   _f(r.ventas.mixtoEfectivo)),
                if (r.ventas.bonoEfectivo > 0)
                  _EsperadoChip('Bono ef.',    _f(r.ventas.bonoEfectivo)),
                if (r.abonos.efectivo + r.abonos.ingresosSepEfectivo > 0)
                  _EsperadoChip('Abonos sep.', _f(r.abonos.efectivo + r.abonos.ingresosSepEfectivo)),
                if (r.abonos.creditoEfectivo > 0)
                  _EsperadoChip('Cartera ef.', _f(r.abonos.creditoEfectivo)),
                if (r.gastos.efectivo > 0)
                  _EsperadoChip('- Gastos',    _f(r.gastos.efectivo),  isNeg: true),
                if (r.devoluciones.netoEfectivo != 0)
                  _EsperadoChip(
                    r.devoluciones.netoEfectivo > 0 ? '- Devoluc.' : '+ Devoluc.',
                    _f(r.devoluciones.netoEfectivo.abs()),
                    isNeg: r.devoluciones.netoEfectivo > 0,
                  ),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 26),

        Align(
          alignment: Alignment.centerLeft,
          child: Text('Cuenta el efectivo fisico en el cajon',
              style: GoogleFonts.inter(
                  fontSize: 14, color: _cText, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: _cSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cBorder),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 8,
            )],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: TextField(
                controller: _montoCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                onChanged: (val) {
                  final parts = val.split('.');
                  if (parts.length > 2) {
                    _montoCtrl.text = '${parts[0]}.${parts[1]}';
                    _montoCtrl.selection = TextSelection.collapsed(
                        offset: _montoCtrl.text.length);
                  }
                },
                style: GoogleFonts.inter(
                    fontSize: 38, fontWeight: FontWeight.w800,
                    color: _cText, letterSpacing: -1.5),
                decoration: InputDecoration(
                  labelText: 'Monto contado',
                  prefixText: '\$ ',
                  labelStyle: GoogleFonts.inter(fontSize: 13, color: _cTextMuted),
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 38, fontWeight: FontWeight.w800, color: _cTextMuted),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const Divider(height: 1, color: _cBorder),
            Padding(
              padding: const EdgeInsets.all(22),
              child: TextField(
                controller: _obsCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13, color: _cTextSec),
                decoration: InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  hintText: 'Ej: billetes contados, diferencias encontradas…',
                  labelStyle: GoogleFonts.inter(fontSize: 12, color: _cTextMuted),
                  hintStyle: GoogleFonts.inter(
                      fontSize: 12,
                      color: _cTextMuted.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: _cBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _cBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _cBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _cGreen, width: 1.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // PASO 3 — Resultado
  // ══════════════════════════════════════════════════
  Widget _buildPaso3(ResumenCierre r) {
    final dif        = _diferencia;
    final esExacto   = dif.abs() < 0.01;
    final esSobrante = dif > 0;

    final color   = esExacto ? _cGreen : esSobrante ? _cBlue : _cRed;
    final bgColor = esExacto ? _cGreenLt : esSobrante ? _cBlueLt : _cRedLt;
    final icono   = esExacto
        ? Icons.check_circle_rounded
        : esSobrante ? Icons.arrow_circle_up_rounded : Icons.warning_rounded;
    final resultado = esExacto ? 'CUADRE EXACTO'
        : esSobrante ? 'SOBRANTE' : 'FALTANTE';

    final now = DateTime.now();
    final hora =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return Row(children: [
      // Columna izquierda: resultado visual
      Expanded(
        flex: 5,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            // Hero resultado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Icon(icono, color: color, size: 30),
                ),
                const SizedBox(height: 16),
                Text(resultado,
                    style: GoogleFonts.inter(
                        color: color, fontWeight: FontWeight.w800,
                        fontSize: 11, letterSpacing: 2.0)),
                const SizedBox(height: 8),
                if (!esExacto)
                  Text(_f(dif.abs()),
                      style: GoogleFonts.inter(
                          color: color, fontWeight: FontWeight.w800,
                          fontSize: 48, letterSpacing: -2.5))
                else
                  Text('Todo cuadra perfectamente',
                      style: GoogleFonts.inter(
                          color: color, fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 12),

            // Desglose contado vs esperado
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cBorder),
              ),
              child: Column(children: [
                _ResRow('Contado fisico', _f(_montoIngresado), _cText),
                const SizedBox(height: 4),
                _ResRow('Esperado',       _f(r.montoEsperadoCaja), _cTextSec),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: _cBorder, height: 1),
                ),
                _ResRow(
                  esSobrante ? 'Sobrante' : esExacto ? 'Diferencia' : 'Faltante',
                  '${dif >= 0 ? '+' : ''}${_f(dif)}',
                  color,
                  bold: true,
                ),
              ]),
            ),

            if (_obsCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('OBSERVACIONES',
                      style: GoogleFonts.inter(
                          color: _cTextMuted, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(_obsCtrl.text,
                      style: GoogleFonts.inter(color: _cTextSec, fontSize: 13)),
                ]),
              ),
            ],
          ]),
        ),
      ),

      Container(width: 1, color: _cBorder),

      // Columna derecha: comprobante
      Expanded(
        flex: 4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: const BoxDecoration(
              color: _cNavy,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(0),
              ),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white54, size: 14),
              const SizedBox(width: 8),
              Text('COMPROBANTE DE CIERRE',
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ]),
          ),
          Expanded(
            child: Container(
              color: _cBg,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildTicket(r, resultado, color, hora, dif),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildTicket(ResumenCierre r, String resultado,
      Color color, String hora, double dif) {

    // ── Colores papel térmico ──────────────────────────────────
    const kPaper   = Color(0xFFFEFDF8);
    const kInk     = Color(0xFF1A1A1A);
    const kInkMid  = Color(0xFF555555);
    const kInkDim  = Color(0xFF999999);

    // ── Helpers internos ──────────────────────────────────────
    TextStyle ts({bool bold = false, Color? c, double sz = 11}) => TextStyle(
        fontFamily: 'monospace', fontSize: sz, color: c ?? kInk,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal, height: 1.35);

    String ml(String m) => switch (m) {
      'tarjeta'            => 'Tarjeta',
      'transferencia'      => 'Transf.',
      'mixto'              => 'Mixto',
      'credito'            => 'Credito',
      'bono'               => 'Bono',
      'bono_efectivo'      => 'Bono+Ef.',
      'bono_tarjeta'       => 'Bono+Tar.',
      'bono_transferencia' => 'Bono+Tra.',
      _                    => 'Efectivo',
    };

    Widget rdiv() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('─' * 32, style: ts(c: kInkDim)),
    );

    Widget rsec(String t) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Text('─── $t ───',
          style: ts(bold: true), textAlign: TextAlign.center),
    );

    Widget rrow(String label, String val, {bool bold = false, Color? valC}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(children: [
          Expanded(child: Text(label, style: ts(bold: bold, c: bold ? kInk : kInkMid))),
          Text(val, style: ts(bold: bold, c: valC ?? kInk)),
        ]),
      );

    return Center(
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: kPaper,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 24, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Encabezado ──────────────────────────────────────
          Text(r.tiendaNombre.toUpperCase(),
              textAlign: TextAlign.center, style: ts(bold: true, sz: 13)),
          const SizedBox(height: 2),
          Text('CIERRE DE TURNO',
              textAlign: TextAlign.center, style: ts(bold: true)),
          rdiv(),
          rrow('Turno #:', '#${r.sesionId}'),
          rrow('Cajero:', r.empleadoNombre),
          rrow('Apertura:', _formatFecha(r.fechaApertura)),
          rrow('Cierre:', hora),
          rdiv(),

          // ── Detalle FAC ──────────────────────────────────────
          if (r.ventasDetalle.isNotEmpty) ...[
            Text('[ FACTURAS ]',
                textAlign: TextAlign.center, style: ts(bold: true)),
            ...r.ventasDetalle.map((v) {
              final total = double.tryParse(v['total']?.toString()       ?? '0') ?? 0;
              final metodo = ml(v['metodo_pago']?.toString()             ?? '');
              final fac   = v['numero_factura']?.toString()
                         ?? '#${v['id']}';
              final prods = (v['productos'] as List? ?? []).cast<Map>();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(child: Text('$fac  $metodo', style: ts(bold: true))),
                  Text(_f(total), style: ts(bold: true)),
                ]),
                ...prods.map((p) {
                  final nombre  = p['producto']?.toString()     ?? '';
                  final cant    = double.tryParse(
                      p['cantidad']?.toString()  ?? '1') ?? 1;
                  final sub     = double.tryParse(
                      p['subtotal']?.toString()  ?? '0') ?? 0;
                  final cantStr = cant == cant.roundToDouble()
                      ? cant.toInt().toString()
                      : cant.toStringAsFixed(1);
                  final corto   = nombre.length > 16
                      ? '${nombre.substring(0, 15)}.' : nombre;
                  return Row(children: [
                    Expanded(child: Text(
                        '  $cantStr x $corto', style: ts(c: kInkMid))),
                    Text(_f(sub), style: ts(c: kInkMid)),
                  ]);
                }),
              ]);
            }),
            rdiv(),
            rrow('TOTAL FAC:', _f(r.ventas.total), bold: true),
            rdiv(),
          ],

          // ── Detalle Abonos / Separados ───────────────────────
          if (r.abonos.detalle.isNotEmpty) ...[
            Text('[ ABONOS SEP ]',
                textAlign: TextAlign.center, style: ts(bold: true)),
            ...r.abonos.detalle.map((a) {
              final mon  = double.tryParse(a['monto']?.toString()       ?? '0') ?? 0;
              final met  = ml(a['metodo_pago']?.toString()              ?? '');
              final desc = a['descripcion']?.toString()                 ?? '';
              final h    = a['hora']?.toString()                        ?? '';
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text('$h  $met', style: ts(bold: true))),
                  Text(_f(mon), style: ts(bold: true)),
                ]),
                if (desc.isNotEmpty)
                  Text('  $desc', style: ts(c: kInkMid)),
              ]);
            }),
            rdiv(),
          ],

          // ── Resumen ventas ───────────────────────────────────
          rsec('VENTAS'),
          rrow('Efectivo',         _f(r.ventas.efectivo)),
          if (r.ventas.tarjeta > 0)
            rrow('Tarjeta',        _f(r.ventas.tarjeta)),
          if (r.ventas.transferencia > 0)
            rrow('Transferencia',  _f(r.ventas.transferencia)),
          if (r.ventas.mixto > 0) ...[
            rrow('Mixto',          _f(r.ventas.mixto)),
            if (r.ventas.mixtoEfectivo > 0)
              rrow('  Mixto ef.',  _f(r.ventas.mixtoEfectivo)),
          ],
          if (r.ventas.bono > 0)
            rrow('Bonos redimidos', _f(r.ventas.bono)),
          if (r.ventas.bonoDifBonoParte > 0 ||
              r.ventas.bonoEfectivo > 0 ||
              r.ventas.bonoTarjeta > 0 ||
              r.ventas.bonoTransferencia > 0) ...[
            rrow('Bonos+dif.', _f(r.ventas.bonoDifBonoParte +
                r.ventas.bonoEfectivo +
                r.ventas.bonoTarjeta +
                r.ventas.bonoTransferencia)),
            if (r.ventas.bonoEfectivo > 0)
              rrow('  ef.',    _f(r.ventas.bonoEfectivo),      valC: kInkMid),
            if (r.ventas.bonoTarjeta > 0)
              rrow('  tar.',   _f(r.ventas.bonoTarjeta),       valC: kInkMid),
            if (r.ventas.bonoTransferencia > 0)
              rrow('  tra.',   _f(r.ventas.bonoTransferencia), valC: kInkMid),
            if (r.ventas.bonoDifBonoParte > 0)
              rrow('  bono',   _f(r.ventas.bonoDifBonoParte),  valC: kInkMid),
          ],
          rdiv(),
          rrow('TOTAL',          _f(r.ventas.total), bold: true),
          rrow('Transacciones',  '${r.ventas.numTransacciones}'),

          // ── Compra de bonos ──────────────────────────────────
          if (r.compraBonos.total > 0) ...[
            rsec('COMPRA DE BONOS'),
            if (r.compraBonos.efectivo > 0)
              rrow('Efectivo',      _f(r.compraBonos.efectivo)),
            if (r.compraBonos.tarjeta > 0)
              rrow('Tarjeta',       _f(r.compraBonos.tarjeta)),
            if (r.compraBonos.transferencia > 0)
              rrow('Transferencia', _f(r.compraBonos.transferencia)),
            rdiv(),
            rrow('TOTAL',    _f(r.compraBonos.total), bold: true),
            rrow('Cantidad', '${r.compraBonos.cantidad}'),
          ],

          // ── Abonos totales ───────────────────────────────────
          if (r.abonos.total > 0 || r.abonos.ingresosSepEfectivo > 0) ...[
            rsec('ABONOS / SEPARADOS'),
            if (r.abonos.ingresosSepEfectivo > 0)
              rrow('Sep. ini. ef.',  _f(r.abonos.ingresosSepEfectivo)),
            if (r.abonos.ingresosSepTarjeta > 0)
              rrow('Sep. ini. tar.', _f(r.abonos.ingresosSepTarjeta)),
            if (r.abonos.ingresosSepTransferencia > 0)
              rrow('Sep. ini. tra.', _f(r.abonos.ingresosSepTransferencia)),
            if (r.abonos.efectivo > 0)
              rrow('Abonos ef.',     _f(r.abonos.efectivo)),
            if (r.abonos.tarjeta > 0)
              rrow('Tarjeta',        _f(r.abonos.tarjeta)),
            if (r.abonos.transferencia > 0)
              rrow('Transfer.',      _f(r.abonos.transferencia)),
            rdiv(),
            rrow('TOTAL',  _f(r.abonos.total +
                r.abonos.ingresosSepEfectivo +
                r.abonos.ingresosSepTarjeta +
                r.abonos.ingresosSepTransferencia), bold: true),
            rrow('Abonos', '${r.abonos.cantidad}'),
          ],

          if (r.abonos.creditoEfectivo > 0) ...[
            rsec('ABONOS CARTERA'),
            rrow('Efectivo', _f(r.abonos.creditoEfectivo)),
          ],

          // ── Gastos ───────────────────────────────────────────
          rsec('GASTOS'),
          if (r.gastos.detalle.isEmpty)
            rrow('Sin gastos', '--')
          else ...[
            ...r.gastos.detalle.map((g) => rrow(g.categoria, '-${_f(g.monto)}')),
            rdiv(),
            rrow('TOTAL', '-${_f(r.gastos.total)}', bold: true),
          ],

          // ── Devoluciones ─────────────────────────────────────
          if (r.devoluciones.cantidad > 0) ...[
            rsec('DEVOLUCIONES'),
            if (r.devoluciones.cambiosProducto > 0)
              rrow('Cambio producto', '${r.devoluciones.cambiosProducto}'),
            if (r.devoluciones.efectivo > 0)
              rrow('Dev. efectivo',   '-${_f(r.devoluciones.efectivo)}'),
            if (r.devoluciones.cambiosDevolver > 0)
              rrow('Dif. devuelta',   '-${_f(r.devoluciones.cambiosDevolver)}'),
            if (r.devoluciones.cambiosCobrar > 0)
              rrow('Dif. cobrada',    '+${_f(r.devoluciones.cambiosCobrar)}'),
            rdiv(),
            rrow('NETO EF.',
                r.devoluciones.netoEfectivo >= 0
                    ? '-${_f(r.devoluciones.netoEfectivo)}'
                    : '+${_f(-r.devoluciones.netoEfectivo)}',
                bold: true),
          ],

          // ── Resultado ────────────────────────────────────────
          rsec('RESULTADO'),
          rrow('Contado',  _f(_montoIngresado)),
          rrow('Esperado', _f(r.montoEsperadoCaja)),
          rdiv(),
          rrow(resultado,
              '${dif >= 0 ? '+' : '-'}${_f(dif.abs())}',
              bold: true, valC: color),

          if (_obsCtrl.text.isNotEmpty) ...[
            rsec('OBSERVACIONES'),
            Text(_obsCtrl.text, style: ts(c: kInkMid)),
          ],

          const SizedBox(height: 12),
          Text('── POS Multitienda ──',
              textAlign: TextAlign.center, style: ts(c: kInkDim)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // PASO 4 — Registro de Movimiento Diario (preview)
  // ══════════════════════════════════════════════════
  Widget _buildPaso4(ResumenCierre r) {
    DateTime fecha;
    try { fecha = DateTime.parse(r.fechaApertura).toLocal(); }
    catch (_) { fecha = DateTime.now(); }

    final diferencia = (_p4MontoFinal ?? 0) - r.montoEsperadoCaja;
    final sobrante   = diferencia > 0 ? diferencia : 0.0;
    final faltante   = diferencia < 0 ? diferencia.abs() : 0.0;

    final cb        = r.compraBonos;
    final efVentas  = r.ventas.efectivo + r.ventas.mixtoEfectivo - cb.efectivo;
    final devEfNeto = r.devoluciones.cambiosCobrar - r.devoluciones.cambiosDevolver - r.devoluciones.efectivo;

    final dtTotal   = r.ventas.tarjeta  + r.abonos.tarjeta + r.abonos.ingresosSepTarjeta - cb.tarjeta;
    final trTotal   = r.ventas.transferencia + r.abonos.transferencia + r.abonos.ingresosSepTransferencia - cb.transferencia;
    final nVentas   = r.ventas.numTransacciones - cb.cantidad;

    final dtCount   = r.ventasDetalle.where((v) => v['metodo_pago'] == 'tarjeta').length - (cb.tarjeta > 0 ? 1 : 0);
    final trCount   = r.ventasDetalle.where((v) => v['metodo_pago'] == 'transferencia').length - (cb.transferencia > 0 ? 1 : 0);
    final bonoCount = r.ventasDetalle.where((v) =>
        (v['metodo_pago'] as String? ?? '').contains('bono')).length;

    final data = RegistroMovimientoData(
      almacen:      r.tiendaNombre.toUpperCase(),
      fecha:        fecha,
      encargado:    r.empleadoNombre.toUpperCase(),
      numeroVentas: r.ventas.numTransacciones,
      totalVentas:  r.ventas.total,
      realizo:      r.empleadoNombre,
      observaciones: _p4Obs,
      filas: [
        FilaRegistro(signo: '+', concepto: 'VENTAS EN CAJA',
            cantidad: nVentas,
            montos: efVentas > 0 ? {MedioPago.efectivo: efVentas} : {}),
        FilaRegistro(signo: '+', concepto: 'INGRESOS SEPARADOS',
            cantidad: r.abonos.numIngresosSep,
            montos: {
              if (r.abonos.ingresosSepEfectivo > 0)      MedioPago.efectivo:    r.abonos.ingresosSepEfectivo,
              if (r.abonos.ingresosSepTarjeta > 0)       MedioPago.datafono:    r.abonos.ingresosSepTarjeta,
              if (r.abonos.ingresosSepTransferencia > 0) MedioPago.bancolombia: r.abonos.ingresosSepTransferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'ABONOS PAGOS CLIENTES',
            cantidad: r.abonos.cantidad,
            montos: {
              if ((r.abonos.efectivo + r.abonos.creditoEfectivo) > 0) MedioPago.efectivo: r.abonos.efectivo + r.abonos.creditoEfectivo,
              if (r.abonos.tarjeta > 0)       MedioPago.datafono:    r.abonos.tarjeta,
              if (r.abonos.transferencia > 0) MedioPago.bancolombia: r.abonos.transferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'DEVOLUCIONES',
            cantidad: r.devoluciones.cantidad,
            montos: {
              if (devEfNeto != 0)                                MedioPago.efectivo:    devEfNeto,
              if (r.devoluciones.netoCambiosTarjeta != 0)        MedioPago.datafono:    r.devoluciones.netoCambiosTarjeta,
              if (r.devoluciones.netoCambiosTransferencia != 0)  MedioPago.bancolombia: r.devoluciones.netoCambiosTransferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'COMPRA DE BONOS',
            cantidad: r.compraBonos.cantidad,
            montos: {
              if (r.compraBonos.efectivo > 0)      MedioPago.efectivo:    r.compraBonos.efectivo,
              if (r.compraBonos.tarjeta > 0)        MedioPago.datafono:    r.compraBonos.tarjeta,
              if (r.compraBonos.transferencia > 0)  MedioPago.bancolombia: r.compraBonos.transferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'DATÁFONO',
            cantidad: dtCount,
            montos: dtTotal > 0 ? {MedioPago.datafono: dtTotal} : {}),
        FilaRegistro(signo: '+', concepto: 'TRANSFERENCIAS',
            cantidad: trCount,
            montos: trTotal > 0 ? {MedioPago.bancolombia: trTotal} : {}),
        FilaRegistro(signo: '+', concepto: 'BONOS REDIMIDOS',
            cantidad: r.ventas.bonoNum,
            montos: r.ventas.bono > 0
                ? {MedioPago.bono: r.ventas.bono} : {}),
        FilaRegistro(signo: '+', concepto: 'BONOS + DIFERENCIA',
            cantidad: r.ventas.bonoDifNum,
            montos: {
              if (r.ventas.bonoEfectivo > 0)        MedioPago.efectivo:    r.ventas.bonoEfectivo,
              if (r.ventas.bonoTarjeta > 0)          MedioPago.datafono:    r.ventas.bonoTarjeta,
              if (r.ventas.bonoTransferencia > 0)    MedioPago.bancolombia: r.ventas.bonoTransferencia,
              if (r.ventas.bonoDifBonoParte > 0)     MedioPago.bono:        r.ventas.bonoDifBonoParte,
            }),
        FilaRegistro(signo: '+', concepto: 'TOTAL EFECTIVO',
            cantidad: r.ventas.numTransacciones,
            montos: {MedioPago.efectivo: r.montoEsperadoCaja + r.gastos.efectivo - r.montoInicial}),
        FilaRegistro(signo: '−', concepto: 'GASTOS',
            cantidad: r.gastos.cantidad,
            montos: r.gastos.efectivo > 0 ? {MedioPago.efectivo: r.gastos.efectivo} : {}),
        FilaRegistro(signo: '+', concepto: 'SOBRANTES',
            cantidad: sobrante > 0 ? 1 : 0,
            montos: sobrante > 0 ? {MedioPago.efectivo: sobrante} : {}),
        FilaRegistro(signo: '−', concepto: 'FALTANTE',
            cantidad: faltante > 0 ? 1 : 0,
            montos: faltante > 0 ? {MedioPago.efectivo: faltante} : {}),
      ],
      totalEntregado: FilaRegistro(
        signo: '+',
        concepto: 'TOTAL EFECTIVO ENTREGADO',
        cantidad: r.ventas.numTransacciones,
        montos: {MedioPago.efectivo: (_p4MontoFinal ?? 0) - r.montoInicial},
      ),
    );

    return Container(
      color: const Color(0xFFE9ECEF),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Material(
            elevation: 6,
            child: RegistroMovimientoDiario(data: data),
          ),
          const SizedBox(height: 12),
          Text(
            'Una vez copiado al formato físico, presiona "Listo, ya copié".',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF555555),
                fontStyle: FontStyle.italic),
          ),
        ]),
      ),
    );
  }


  // ══════════════════════════════════════════════════
  // FOOTER
  // ══════════════════════════════════════════════════
  Widget _buildFooter(CajaProvider cont) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      decoration: BoxDecoration(
        color: _cSurface,
        border: const Border(top: BorderSide(color: _cBorder)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, -2),
        )],
      ),
      child: Row(children: [
        // No hay botón "Atrás" en paso 4 porque el cierre ya fue confirmado
        if (_paso > 1 && _paso < 4)
          _GhostBtn(
            label: 'Atras',
            icon: Icons.arrow_back_rounded,
            onPressed: () => _irAPaso(_paso - 1),
          ),
        if (_paso == 4)
          Text('Cierre #${_p4SesionId ?? '—'} completado',
              style: GoogleFonts.inter(
                  fontSize: 11, color: _cTextMuted, fontStyle: FontStyle.italic)),
        const Spacer(),
        if (_paso == 1)
          _GhostBtn(
            label: 'Cancelar',
            icon: Icons.close_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        const SizedBox(width: 10),
        _ActionBtn(
          paso: _paso,
          procesando: cont.procesando,
          onPressed: cont.procesando ? null : () async {
            if (_paso == 1) {
              _irAPaso(2);
            } else if (_paso == 2) {
              final monto = double.tryParse(_montoCtrl.text);
              if (monto == null || monto < 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Ingresa un monto valido',
                      style: GoogleFonts.inter(color: Colors.white)),
                  backgroundColor: _cRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                ));
                return;
              }
              setState(() => _montoIngresado = monto);
              _irAPaso(3);
            } else if (_paso == 3) {
              // Capturar datos de respaldo ANTES de cerrar
              final r          = cont.resumenCierre;
              final sesionId   = r?.sesionId;
              final obs        = _obsCtrl.text.trim();
              final montoFinal = _montoIngresado;
              final cfg        = context.read<ConfigProvider>();
              final tipoPapel  = cfg.tipoPapel;
              final nit        = cfg.nit;
              final dir        = cfg.direccion;
              final tel        = cfg.telefono;
              final tiendaId   = context.read<AuthProvider>().tiendaId;
              final messenger  = ScaffoldMessenger.of(context);

              final ok = await cont.cerrarCaja(
                montoFinalReal: montoFinal,
                observaciones:  obs,
              );
              if (ok && mounted) {
                unawaited(_kickCajonCierre());
                // Guardar params para usarlos al confirmar el registro
                setState(() {
                  _p4SesionId   = sesionId;
                  _p4MontoFinal = montoFinal;
                  _p4Obs        = obs;
                  _p4TipoPapel  = tipoPapel;
                  _p4Resumen    = r;
                  _p4Nit        = nit;
                  _p4Dir        = dir;
                  _p4Tel        = tel;
                  _p4TiendaId   = tiendaId;
                  _p4Msgr       = messenger;
                });
                _irAPaso(4);
              }
            } else {
              // Paso 4: registro completado → cerrar y enviar PDF/WhatsApp
              // Capturamos el resumen antes de cerrar el widget
              final resumenParaFormato = _p4Resumen;
              final montoParaFormato   = _p4MontoFinal ?? 0;
              final sesionParaFormato  = _p4SesionId;
              Navigator.pop(context);
              if (sesionParaFormato != null) {
                unawaited(_imprimirCierreFinalizado(
                  sesionId:   sesionParaFormato,
                  montoFinal: montoParaFormato,
                  obs:        _p4Obs,
                  tipoPapel:  _p4TipoPapel,
                  fallback:   _p4Resumen,
                  nit:        _p4Nit,
                  dir:        _p4Dir,
                  tel:        _p4Tel,
                  tiendaId:   _p4TiendaId,
                  messenger:  _p4Msgr,
                ));
              }
              // Auto-guardar PDF del formato diario en la carpeta local
              if (resumenParaFormato != null) {
                unawaited(_guardarFormatoPdf(
                    resumenParaFormato, montoParaFormato, sesionParaFormato));
              }
            }
          },
        ),
      ]),
    );
  }

  // ── Ticket helpers ──────────────────────────────────────────
  TextStyle _mono(Color c, {bool bold = false}) => TextStyle(
    fontFamily: 'monospace', fontSize: 11, color: c,
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
  );

  Widget _tSec(String t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 3),
    child: Text(t,
        style: GoogleFonts.inter(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: _cGreen, letterSpacing: 1.2)),
  );

  Widget _tFila(String label, String valor,
      {bool bold = false, Color? color}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _mono(color ?? _cTextSec,  bold: bold)),
          Text(valor,  style: _mono(color ?? _cText,     bold: bold)),
        ],
      ),
    );

  Widget _tDiv() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('─────────────────────', style: _mono(_cBorder)),
  );

  // Obtiene los datos finalizados del servidor (post-cierre) antes de imprimir.
  // Si falla la red, construye el historial desde el resumen pre-cierre capturado.
  // Imprime el ticket completo con buildCierreTurno (igual que la reimpresión manual).
  Future<void> _imprimirCierreFinalizado({
    required int                    sesionId,
    required double                 montoFinal,
    required String                 obs,
    required dynamic                tipoPapel,
    required ResumenCierre?         fallback,
    String                          nit       = '',
    String                          dir       = '',
    String                          tel       = '',
    int                             tiendaId  = 0,
    ScaffoldMessengerState?         messenger,
  }) async {
    SesionHistorial? sesion;

    // Intento 1: datos post-cierre del servidor
    try {
      final detalle = await CajaService().getDetalleSesion(sesionId);
      if (detalle['success'] == true && detalle['data'] != null) {
        sesion = SesionHistorial.fromJson(
          detalle['data'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[Cierre] Error obteniendo detalle post-cierre: $e');
    }

    // Intento 2: fallback con datos pre-cierre
    if (sesion == null && fallback != null) {
      final r = fallback;
      sesion = SesionHistorial(
        id:                   r.sesionId,
        empleadoNombre:       r.empleadoNombre,
        tiendaNombre:         r.tiendaNombre,
        fechaApertura:        r.fechaApertura,
        fechaCierre:          DateTime.now().toIso8601String(),
        estado:               'cerrada',
        observaciones:        obs,
        saldoInicial:         r.montoInicial,
        ventasEfectivo:       r.ventas.efectivo,
        ventasTarjeta:        r.ventas.tarjeta,
        ventasTransferencia:  r.ventas.transferencia,
        ventasMixto:          r.ventas.mixto,
        ventasMixtoEfectivo:  r.ventas.mixtoEfectivo,
        ventasTotal:          r.ventas.total,
        gastosTotal:          r.gastos.total,
        gastosDetalle:        r.gastos.detalle
            .map((g) => {'categoria': g.categoria, 'descripcion': '', 'monto': g.monto, 'metodo_pago': g.metodoPago})
            .toList(),
        abonosEfectivo:       r.abonos.efectivo,
        abonosTarjeta:        r.abonos.tarjeta,
        abonosTransferencia:  r.abonos.transferencia,
        abonosTotal:          r.abonos.total,
        abonosCreditoEfectivo: r.abonos.creditoEfectivo,
        cancelacionesEfectivo: r.abonos.cancelacionesEfectivo,
        ingresosManual:        r.abonos.ingresosManual,
        numAbonos:             r.abonos.cantidad,
        abonosDetalle:         r.abonos.detalle,
        devolucionesEfectivo:  r.devoluciones.netoEfectivo,
        devolucionesDirectasEf: r.devoluciones.efectivo,
        cambiosCobrarEf:       r.devoluciones.cambiosCobrar,
        cambiosDevEf:          r.devoluciones.cambiosDevolver,
        cambiosCobrarTar:      r.devoluciones.cambiosCobrarTar,
        cambiosDevTar:         r.devoluciones.cambiosDevTar,
        cambiosCobrarTra:      r.devoluciones.cambiosCobrarTra,
        cambiosDevTra:         r.devoluciones.cambiosDevTra,
        numDevoluciones:       r.devoluciones.cantidad,
        numCambiosProducto:    r.devoluciones.cambiosProducto,
        devolucionesDetalle:   r.devoluciones.detalle,
        ventasDetalle:         r.ventasDetalle,
        cuentasResumen:        _resumenCuentas,
        montoFinalSistema:     r.montoEsperadoCaja,
        montoFinalReal:        montoFinal,
        diferencia:            montoFinal - r.montoEsperadoCaja,
        numTransacciones:      r.ventas.numTransacciones,
      );
    }

    if (sesion == null) return;

    // PDF + WhatsApp + DocumentoService (sin imprimir térmica aquí)
    try {
      await exportarCierrePDF(sesion,
          tipoPapel: tipoPapel, nit: nit, dir: dir, tel: tel,
          messenger: messenger, skipThermal: true);
    } catch (e) {
      debugPrint('[Cierre] Error en PDF/WhatsApp: $e');
      messenger?.showSnackBar(SnackBar(
        content: Text('Error al generar cierre: $e'),
        backgroundColor: const Color(0xFFBE123C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }

    // Impresión térmica: usa buildCierreTurno = mismo ticket que la reimpresión manual
    if (tipoPapel != 'pdf') {
      try {
        final ps = tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;
        if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
          final ventasNorm = _normalizarVentas(sesion.ventasDetalle);

          // Separados del turno (misma fecha de apertura)
          final fechaSep = sesion.fechaApertura.length >= 10
              ? sesion.fechaApertura.substring(0, 10)
              : DateTime.now().toString().substring(0, 10);
          List<Map<String, dynamic>> separadosDia = [];
          if (tiendaId > 0) {
            try {
              separadosDia = await ContabilidadService()
                  .getSeparadosDia(fechaSep, tiendaId);
            } catch (_) {}
          }

          final bytes = await ThermalPrinterService.buildCierreTurno(
            sesion:         _toSesionCaja(sesion),
            empresaNombre:  sesion.tiendaNombre,
            metodosPago:    _metodosPagoDesdeHistorial(sesion),
            totalGastos:    sesion.gastosTotal,
            nit: nit, direccion: dir, telefono: tel,
            paperSize:      ps,
            resumenCuentas: _resumenCuentas,
            gastosSesion:   sesion.gastosDetalle,
            ventasDia:      ventasNorm,
            abonosDia:      sesion.abonosDetalle,
            devolucionesDia: sesion.devolucionesDetalle,
            separadosDia:   separadosDia,
            topProductos:   _calcTopProductos(ventasNorm),
          );
          await WindowsPrinterService.printRaw(bytes);
        }
      } catch (e) {
        debugPrint('[Cierre] Error en impresión térmica: $e');
      }
    }
  }

  // Construye un SesionCaja provisional a partir de SesionHistorial para buildCierreTurno.
  static SesionCaja _toSesionCaja(SesionHistorial h) {
    DateTime apertura;
    DateTime? cierre;
    try { apertura = DateTime.parse(h.fechaApertura).toLocal(); } catch (_) { apertura = DateTime.now(); }
    try { cierre = h.fechaCierre.isNotEmpty ? DateTime.parse(h.fechaCierre).toLocal() : null; } catch (_) {}
    return SesionCaja(
      id:                  h.id,
      estado:              h.estado,
      saldo_inicial:       h.saldoInicial,
      saldo_final:         h.montoFinalReal,
      fecha_apertura:      apertura,
      fecha_cierre:        cierre,
      ventasTotal:         h.ventasTotal,
      ventasEfectivo:      h.ventasEfectivo,
      ventasTarjeta:       h.ventasTarjeta,
      ventasTransferencia: h.ventasTransferencia,
      ventasMixtoEfectivo: h.ventasMixtoEfectivo,
      ventasBono:          h.ventasBono,
      numTransacciones:    h.numTransacciones,
      gastosTotal:         h.gastosTotal,
      montoEsperado:       h.montoFinalSistema,
      tiendaNombre:        h.tiendaNombre,
      empleadoNombre:      h.empleadoNombre,
      abonosTotal:         h.abonosTotal,
      abonosEfectivo:      h.abonosEfectivo,
      abonosTarjeta:       h.abonosTarjeta,
      abonosTransferencia: h.abonosTransferencia,
      numAbonos:           h.numAbonos,
      cambiosCobrarEf:     h.cambiosCobrarEf,
      cambiosCobrarTar:    h.cambiosCobrarTar,
      cambiosDevTar:       h.cambiosDevTar,
      cambiosCobrarTra:    h.cambiosCobrarTra,
      cambiosDevTra:       h.cambiosDevTra,
      observaciones:       h.observaciones,
    );
  }

  // Construye el mapa de métodos de pago para buildCierreTurno.
  static Map<String, double> _metodosPagoDesdeHistorial(SesionHistorial h) {
    final m = <String, double>{};
    if (h.ventasEfectivo      > 0) m['efectivo']      = h.ventasEfectivo;
    if (h.ventasTarjeta       > 0) m['tarjeta']       = h.ventasTarjeta;
    if (h.ventasTransferencia > 0) m['transferencia'] = h.ventasTransferencia;
    if (h.ventasMixto         > 0) m['mixto']         = h.ventasMixto;
    if (h.ventasBono          > 0) m['bono']          = h.ventasBono;
    return m;
  }

  // Calcula top 5 productos desde la lista de ventas normalizadas.
  static List<TopProducto> _calcTopProductos(
      List<Map<String, dynamic>> ventas) {
    final acum = <String, Map<String, dynamic>>{};
    for (final v in ventas) {
      if ((v['estado']?.toString() ?? '') == 'anulada') continue;
      for (final d in (v['detalles'] as List? ?? [])) {
        if (d is! Map) continue;
        final nombre   = d['producto_nombre']?.toString() ?? '';
        final cantidad = (d['cantidad'] as num?)?.toDouble() ?? 0.0;
        final subtotal = (d['subtotal']  as num?)?.toDouble() ?? 0.0;
        if (nombre.isEmpty) continue;
        acum.update(nombre, (e) => {
          'nombre':   nombre,
          'cantidad': (e['cantidad'] as double) + cantidad,
          'subtotal': (e['subtotal'] as double) + subtotal,
        }, ifAbsent: () => {'nombre': nombre, 'cantidad': cantidad, 'subtotal': subtotal});
      }
    }
    final lista = acum.values.toList()
      ..sort((a, b) =>
          (b['subtotal'] as double).compareTo(a['subtotal'] as double));
    return lista.take(5).map((e) => TopProducto(
      producto:      e['nombre'] as String,
      categoria:     '',
      totalVendido:  e['cantidad'] as double,
      totalIngresos: e['subtotal'] as double,
    )).toList();
  }

  // Normaliza ventas_detalle del historial al formato esperado por buildCierreTurno.
  // El SesionCajaSerializer usa 'productos'/'producto' mientras buildCierreTurno
  // espera 'detalles'/'producto_nombre' (igual que VentaSerializer).
  static List<Map<String, dynamic>> _normalizarVentas(
      List<Map<String, dynamic>> raw) {
    return raw.map((v) {
      final prods = (v['productos'] as List?) ??
          (v['detalles'] as List?) ?? [];
      final detalles = prods.map((p) => <String, dynamic>{
        'producto_nombre': p['producto_nombre'] ?? p['producto'] ?? '',
        'cantidad':        p['cantidad'],
        'subtotal':        p['subtotal'],
      }).toList();
      return <String, dynamic>{
        ...v,
        'estado':   v['estado']  ?? 'completada',
        'detalles': detalles,
      };
    }).toList();
  }

  Future<void> _guardarFormatoPdf(
      ResumenCierre r, double montoFinalReal, int? sesionId) async {
    try {
      final fecha      = DateTime.now();
      final diferencia = montoFinalReal - r.montoEsperadoCaja;
      final sobrante   = diferencia > 0 ? diferencia : 0.0;
      final faltante   = diferencia < 0 ? -diferencia : 0.0;

      final pdfCb       = r.compraBonos;
      final efVentas  = r.ventas.efectivo + r.ventas.mixtoEfectivo - pdfCb.efectivo;
      final devEfNeto = r.devoluciones.cambiosCobrar - r.devoluciones.cambiosDevolver - r.devoluciones.efectivo;
      final pdfDtTotal  = r.ventas.tarjeta  + r.abonos.tarjeta + r.abonos.ingresosSepTarjeta - pdfCb.tarjeta;
      final pdfTrTotal  = r.ventas.transferencia + r.abonos.transferencia + r.abonos.ingresosSepTransferencia - pdfCb.transferencia;
      final pdfNVentas  = r.ventas.numTransacciones - pdfCb.cantidad;
      final pdfDtCount  = r.ventasDetalle.where((v) => v['metodo_pago'] == 'tarjeta').length - (pdfCb.tarjeta > 0 ? 1 : 0);
      final pdfTrCount  = r.ventasDetalle.where((v) => v['metodo_pago'] == 'transferencia').length - (pdfCb.transferencia > 0 ? 1 : 0);
      final pdfBonoCount = r.ventasDetalle.where((v) =>
          (v['metodo_pago'] as String? ?? '').contains('bono')).length;

      final data = RegistroMovimientoData(
        almacen:      r.tiendaNombre.toUpperCase(),
        fecha:        fecha,
        encargado:    r.empleadoNombre.toUpperCase(),
        numeroVentas: r.ventas.numTransacciones,
        totalVentas:  r.ventas.total,
        realizo:      r.empleadoNombre,
        observaciones: _p4Obs,
        filas: [
          FilaRegistro(signo: '+', concepto: 'VENTAS EN CAJA',
              cantidad: pdfNVentas,
              montos: efVentas > 0 ? {MedioPago.efectivo: efVentas} : {}),
          FilaRegistro(signo: '+', concepto: 'INGRESOS SEPARADOS',
              cantidad: r.abonos.numIngresosSep,
              montos: {
                if (r.abonos.ingresosSepEfectivo > 0)      MedioPago.efectivo:    r.abonos.ingresosSepEfectivo,
                if (r.abonos.ingresosSepTarjeta > 0)       MedioPago.datafono:    r.abonos.ingresosSepTarjeta,
                if (r.abonos.ingresosSepTransferencia > 0) MedioPago.bancolombia: r.abonos.ingresosSepTransferencia,
              }),
          FilaRegistro(signo: '+', concepto: 'ABONOS PAGOS CLIENTES',
              cantidad: r.abonos.cantidad,
              montos: {
                if ((r.abonos.efectivo + r.abonos.creditoEfectivo) > 0) MedioPago.efectivo: r.abonos.efectivo + r.abonos.creditoEfectivo,
                if (r.abonos.tarjeta > 0)       MedioPago.datafono:    r.abonos.tarjeta,
                if (r.abonos.transferencia > 0) MedioPago.bancolombia: r.abonos.transferencia,
              }),
          FilaRegistro(signo: '+', concepto: 'DEVOLUCIONES',
              cantidad: r.devoluciones.cantidad,
              montos: {
                if (devEfNeto != 0)                                MedioPago.efectivo:    devEfNeto,
                if (r.devoluciones.netoCambiosTarjeta != 0)        MedioPago.datafono:    r.devoluciones.netoCambiosTarjeta,
                if (r.devoluciones.netoCambiosTransferencia != 0)  MedioPago.bancolombia: r.devoluciones.netoCambiosTransferencia,
              }),
          FilaRegistro(signo: '+', concepto: 'COMPRA DE BONOS',
              cantidad: pdfCb.cantidad,
              montos: {
                if (pdfCb.efectivo > 0)      MedioPago.efectivo:    pdfCb.efectivo,
                if (pdfCb.tarjeta > 0)       MedioPago.datafono:    pdfCb.tarjeta,
                if (pdfCb.transferencia > 0) MedioPago.bancolombia: pdfCb.transferencia,
              }),
          FilaRegistro(signo: '+', concepto: 'DATÁFONO',
              cantidad: pdfDtCount,
              montos: pdfDtTotal > 0 ? {MedioPago.datafono: pdfDtTotal} : {}),
          FilaRegistro(signo: '+', concepto: 'TRANSFERENCIAS',
              cantidad: pdfTrCount,
              montos: pdfTrTotal > 0 ? {MedioPago.bancolombia: pdfTrTotal} : {}),
          FilaRegistro(signo: '+', concepto: 'BONOS REDIMIDOS',
              cantidad: r.ventas.bonoNum,
              montos: r.ventas.bono > 0 ? {MedioPago.bono: r.ventas.bono} : {}),
          FilaRegistro(signo: '+', concepto: 'BONOS + DIFERENCIA',
              cantidad: r.ventas.bonoDifNum,
              montos: {
                if (r.ventas.bonoEfectivo > 0)        MedioPago.efectivo:    r.ventas.bonoEfectivo,
                if (r.ventas.bonoTarjeta > 0)          MedioPago.datafono:    r.ventas.bonoTarjeta,
                if (r.ventas.bonoTransferencia > 0)    MedioPago.bancolombia: r.ventas.bonoTransferencia,
                if (r.ventas.bonoDifBonoParte > 0)     MedioPago.bono:        r.ventas.bonoDifBonoParte,
              }),
          FilaRegistro(signo: '+', concepto: 'TOTAL EFECTIVO',
              cantidad: r.ventas.numTransacciones,
              montos: {MedioPago.efectivo: r.montoEsperadoCaja + r.gastos.efectivo - r.montoInicial}),
          FilaRegistro(signo: '−', concepto: 'GASTOS',
              cantidad: r.gastos.cantidad,
              montos: r.gastos.efectivo > 0
                  ? {MedioPago.efectivo: r.gastos.efectivo} : {}),
          if (sobrante > 0)
            FilaRegistro(signo: '+', concepto: 'SOBRANTES',
                cantidad: 1,
                montos: {MedioPago.efectivo: sobrante}),
          if (faltante > 0)
            FilaRegistro(signo: '−', concepto: 'FALTANTE',
                cantidad: 1,
                montos: {MedioPago.efectivo: faltante}),
        ],
        totalEntregado: FilaRegistro(
          signo: '+',
          concepto: 'TOTAL EFECTIVO ENTREGADO',
          cantidad: r.ventas.numTransacciones,
          montos: {MedioPago.efectivo: montoFinalReal - r.montoInicial},
        ),
      );

      final bytes = await generarFormatoDiarioPdf(data);
      final d  = fecha;
      final ts = '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
      final ref = sesionId != null ? '${sesionId}_$ts' : ts;
      await DocumentoService.instance.guardarFormato(
          bytes: bytes, referencia: ref);
    } catch (e) {
      debugPrint('FormatoPdf: error al guardar: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPONENTES
// ═══════════════════════════════════════════════════════════════

class _StepDot extends StatelessWidget {
  final int    index;
  final String label;
  final bool   activo, pasado;
  const _StepDot({
    required this.index, required this.label,
    required this.activo, required this.pasado,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: (pasado || activo)
              ? _cGreen
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: activo
              ? Border.all(color: _cGreen, width: 2)
              : Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: pasado
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text('$index',
                  style: GoogleFonts.inter(
                      color: activo ? Colors.white : Colors.white38,
                      fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 5),
      Text(label,
          style: GoogleFonts.inter(
              color: activo ? Colors.white : Colors.white54,
              fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _TurnoBar extends StatelessWidget {
  final ResumenCierre r;
  final String Function(String) formatFecha;
  const _TurnoBar({required this.r, required this.formatFecha});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _cSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cBorder),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: _cGreen, borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text(
              r.empleadoNombre.isNotEmpty ? r.empleadoNombre[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.empleadoNombre,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 13, color: _cText)),
            Text('Apertura: ${formatFecha(r.fechaApertura)}',
                style: GoogleFonts.inter(fontSize: 11, color: _cTextMuted)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _cGreenLt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cGreen.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: _cGreen, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text('Turno activo',
                style: GoogleFonts.inter(
                    color: _cGreen, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 12),
        Text('#${r.sesionId}',
            style: GoogleFonts.inter(
                color: _cTextMuted, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _DataCard extends StatelessWidget {
  final String   titulo;
  final IconData icono;
  final Color    accentColor, accentBg;
  final Widget   child;
  const _DataCard({
    required this.titulo,      required this.icono,
    required this.accentColor, required this.accentBg,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03), blurRadius: 6,
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: accentBg.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.12))),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icono, color: accentColor, size: 14),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(titulo,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 12, color: _cText)),
            ),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String   label;
  final double   valor;
  final Color    color;
  final IconData icono;
  const _ItemRow(this.label, this.valor, this.color, this.icono);
  static final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icono, size: 11, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: _cTextSec, fontWeight: FontWeight.w500)),
        ),
        Text('\$${_fmt.format(valor)}',
            style: GoogleFonts.inter(
                fontSize: 13, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _GastoRow extends StatelessWidget {
  final String categoria, metodoPago;
  final double monto;
  const _GastoRow(this.categoria, this.metodoPago, this.monto);
  static final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(categoria,
              style: GoogleFonts.inter(
                  fontSize: 12, color: _cTextSec, fontWeight: FontWeight.w500)),
          if (metodoPago.isNotEmpty)
            Text(metodoPago,
                style: GoogleFonts.inter(fontSize: 10, color: _cTextMuted)),
        ])),
        Text('-\$${_fmt.format(monto)}',
            style: GoogleFonts.inter(
                fontSize: 13, color: _cRed, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _MontoRow extends StatelessWidget {
  final String  label;
  final double  monto;
  final bool    isNeg;
  final bool    isCount;
  final String? countLabel;
  final String? subLabel;
  const _MontoRow(this.label, this.monto, {
    required this.isNeg,
    this.isCount = false,
    this.countLabel,
    this.subLabel,
  });
  static final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  Widget build(BuildContext context) {
    final color = isCount ? _cPurple : (isNeg ? _cRed : _cGreen);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _cTextSec, fontWeight: FontWeight.w500)),
              if (subLabel != null)
                Text(subLabel!,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _cTextMuted, fontStyle: FontStyle.italic)),
            ],
          )),
          const SizedBox(width: 8),
          isCount
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _cPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(countLabel ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _cPurple, fontWeight: FontWeight.w700)),
                )
              : Text('${isNeg ? '-' : '+'}\$${_fmt.format(monto)}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label, valor;
  final Color  color;
  const _TotalRow(this.label, this.valor, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: color, fontWeight: FontWeight.w800)),
          Text(valor,
              style: GoogleFonts.inter(
                  fontSize: 14, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CardDiv extends StatelessWidget {
  const _CardDiv();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Divider(height: 1, color: _cBorder),
  );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color  color, bg;
  const _Chip(this.text, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(text,
        style: GoogleFonts.inter(
            fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );
}

class _EmptyHint extends StatelessWidget {
  final String msg;
  const _EmptyHint(this.msg);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, size: 12, color: _cTextMuted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(msg,
            style: GoogleFonts.inter(
                fontSize: 11, color: _cTextMuted, fontStyle: FontStyle.italic)),
      ),
    ]),
  );
}

class _CajaEsperadaCard extends StatelessWidget {
  final ResumenCierre r;
  final String Function(double) f;
  const _CajaEsperadaCard({required this.r, required this.f});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Text('Calculo de Caja Fisica',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
          const Spacer(),
          Text('Solo efectivo',
              style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.white54, fontStyle: FontStyle.italic)),
        ]),
        const SizedBox(height: 14),

        _CalcLine('Saldo inicial',      f(r.montoInicial),                Colors.white70,          '+'),
        _CalcLine('Ventas efectivo',    f(r.ventas.efectivo),             Colors.white,            '+'),
        if (r.ventas.mixtoEfectivo > 0)
          _CalcLine('Ventas mixto (ef.)', f(r.ventas.mixtoEfectivo),     Colors.white,            '+'),
        if (r.ventas.bonoEfectivo > 0)
          _CalcLine('Ventas bono (ef.)',  f(r.ventas.bonoEfectivo),      Colors.white,            '+'),
        if (r.abonos.efectivo + r.abonos.ingresosSepEfectivo > 0)
          _CalcLine('Abonos separados',   f(r.abonos.efectivo + r.abonos.ingresosSepEfectivo), const Color(0xFF7DD3FC), '+'),
        if (r.abonos.creditoEfectivo > 0)
          _CalcLine('Abonos cartera',     f(r.abonos.creditoEfectivo),   const Color(0xFF7DD3FC), '+'),
        _CalcLine('Gastos efectivo',    f(r.gastos.efectivo),             const Color(0xFFFFB4AB), '-'),
        if (r.devoluciones.netoEfectivo != 0)
          _CalcLine(
            'Devoluciones ef.',
            f(r.devoluciones.netoEfectivo.abs()),
            r.devoluciones.netoEfectivo > 0
                ? const Color(0xFFFFB4AB)
                : const Color(0xFF86EFAC),
            r.devoluciones.netoEfectivo > 0 ? '-' : '+',
          ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ESPERADO EN CAJA',
                style: GoogleFonts.inter(
                    color: Colors.white70, fontWeight: FontWeight.w800,
                    fontSize: 11, letterSpacing: 0.5)),
            Text(f(r.montoEsperadoCaja),
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 24, letterSpacing: -0.5)),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 11, color: Colors.white54),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tarjeta, transferencia'
                '${r.ventas.mixto > 0 ? " y parte no-efectivo de mixto" : ""}'
                ' se depositan al banco.',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white60),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CalcLine extends StatelessWidget {
  final String label, valor, signo;
  final Color  color;
  const _CalcLine(this.label, this.valor, this.color, this.signo);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(signo,
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
        ),
        Text(valor,
            style: GoogleFonts.inter(
                fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _EsperadoChip extends StatelessWidget {
  final String label, valor;
  final bool   isNeg;
  const _EsperadoChip(this.label, this.valor, {this.isNeg = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                color: isNeg ? Colors.red.shade300 : Colors.white54,
                fontSize: 9, fontWeight: FontWeight.w600)),
        Text(valor,
            style: TextStyle(
                color: isNeg ? Colors.red.shade300 : Colors.white,
                fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ResRow extends StatelessWidget {
  final String label, valor;
  final Color  color;
  final bool   bold;
  const _ResRow(this.label, this.valor, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: color.withValues(alpha: bold ? 1.0 : 0.8),
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(valor,
              style: GoogleFonts.inter(
                  color: color,
                  fontSize: bold ? 18 : 13,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _GhostBtn({required this.label, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: Icon(icon, size: 14),
    label: Text(label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: _cTextMuted,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final int  paso;
  final bool procesando;
  final VoidCallback? onPressed;
  const _ActionBtn({
    required this.paso, required this.procesando, this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final esFinal   = paso == 3;
    final esRegistro = paso == 4;
    final bgColor = esFinal ? _cRed : esRegistro ? _cGreen : _cGreen;
    final label   = paso == 1 ? 'Continuar'
        : paso == 2 ? 'Ver resultado'
        : paso == 4 ? 'Listo, ya copié'
        : procesando ? 'Cerrando...' : 'Confirmar cierre';
    final icon = (procesando && esFinal)
        ? const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Icon(esRegistro
            ? Icons.check_circle_rounded
            : esFinal ? Icons.lock_rounded : Icons.arrow_forward_rounded,
            size: 15);

    return ElevatedButton.icon(
      icon: icon,
      label: Text(label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

}

Future<void> _kickCajonCierre() async {
  try {
    if (ThermalPrinterService.isWebUsbSupported) {
      if (!await ThermalPrinterService.hasCashDrawer()) return;
      final dev = await ThermalPrinterService.getOrRequestDevice();
      if (dev != null) await ThermalPrinterService.kickDrawer(dev);
    } else if (!kIsWeb && await ThermalPrinterService.hasCashDrawer()) {
      final bytes = await ThermalPrinterService.buildDrawerBytes();
      await WindowsPrinterService.printRaw(bytes);
    }
  } catch (_) {}
}
