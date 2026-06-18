import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/caja_provider.dart';
import '../../../models/resumen_cierre.dart';

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

  late AnimationController _stepCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _pasoLabels = ['Resumen', 'Conteo', 'Resultado'];

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
    if (fecha.length >= 16) return fecha.substring(0, 16).replaceAll('T', ' ');
    return fecha.replaceAll('T', ' ');
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

    if (resumen == null) {
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
          _buildHeader(resumen),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _paso == 1
                    ? _buildPaso1(resumen)
                    : _paso == 2
                        ? _buildPaso2(resumen)
                        : _buildPaso3(resumen),
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
          child: Row(children: List.generate(3, (i) {
            final idx    = i + 1;
            final activo = idx == _paso;
            final pasado = idx < _paso;
            return Expanded(child: Row(children: [
              Expanded(child: _StepDot(
                index: idx, label: _pasoLabels[i],
                activo: activo, pasado: pasado,
              )),
              if (i < 2)
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
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              const _CardDiv(),
              _TotalRow('TOTAL VENTAS', _f(r.ventas.total), _cNavy),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: _Chip('${r.ventas.numTransacciones} transacciones', _cBlue, _cBlueLt),
              ),
            ]),
          )),
          const SizedBox(width: 12),
          Expanded(child: _DataCard(
            titulo: 'Gastos del Turno',
            icono: Icons.trending_down_rounded,
            accentColor: _cRed,
            accentBg: _cRedLt,
            child: r.gastos.detalle.isEmpty
                ? const _EmptyHint('Sin gastos registrados en este turno')
                : Column(children: [
                    ...r.gastos.detalle.map(
                      (g) => _GastoRow(g.categoria, g.metodoPago, g.monto)),
                    const _CardDiv(),
                    _TotalRow('TOTAL GASTOS', '-${_f(r.gastos.total)}', _cRed),
                  ]),
          )),
        ]),
        const SizedBox(height: 12),

        // Fila 2: Abonos | Devoluciones
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _DataCard(
            titulo: 'Abonos / Separados',
            icono: Icons.bookmark_added_rounded,
            accentColor: _cSky,
            accentBg: _cSkyLt,
            child: r.abonos.total <= 0
                ? const _EmptyHint('Sin abonos recibidos en este turno')
                : Column(children: [
                    if (r.abonos.efectivo > 0)
                      _ItemRow('Efectivo',      r.abonos.efectivo,      _cGreen,  Icons.payments_rounded),
                    if (r.abonos.tarjeta > 0)
                      _ItemRow('Tarjeta',       r.abonos.tarjeta,       _cBlue,   Icons.credit_card_rounded),
                    if (r.abonos.transferencia > 0)
                      _ItemRow('Transferencia', r.abonos.transferencia, _cPurple, Icons.swap_horiz_rounded),
                    const _CardDiv(),
                    _TotalRow('TOTAL ABONOS', _f(r.abonos.total), _cSky),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _Chip(
                        '${r.abonos.cantidad} abono${r.abonos.cantidad != 1 ? "s" : ""}',
                        _cSky, _cSkyLt,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, size: 11, color: _cTextMuted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Tarjeta y transferencia no afectan el cajon fisico.',
                            style: GoogleFonts.inter(fontSize: 10, color: _cTextMuted),
                          ),
                        ),
                      ]),
                    ),
                  ]),
          )),
          const SizedBox(width: 12),
          Expanded(child: _DataCard(
            titulo: 'Devoluciones',
            icono: Icons.assignment_return_rounded,
            accentColor: _cAmber,
            accentBg: _cAmberLt,
            child: r.devoluciones.cantidad == 0
                ? const _EmptyHint('Sin devoluciones en este turno')
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (r.devoluciones.cambiosProducto > 0) ...[
                      _DevRow(
                        icono:  Icons.swap_horiz_rounded,
                        color:  _cPurple,
                        label:  'Cambio por producto',
                        valor:  '${r.devoluciones.cambiosProducto} cambio${r.devoluciones.cambiosProducto != 1 ? "s" : ""}',
                        sub:    'Sin salida de efectivo',
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
                    if (r.devoluciones.netoEfectivo > 0) ...[
                      const _CardDiv(),
                      _TotalRow('NETO EFECTIVO', '-${_f(r.devoluciones.netoEfectivo)}', _cRed),
                    ],
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _Chip(
                        '${r.devoluciones.cantidad} devolucion${r.devoluciones.cantidad != 1 ? "es" : ""}',
                        _cAmber, _cAmberLt,
                      ),
                    ),
                  ]),
          )),
        ]),
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
                _EsperadoChip('Inicial',     _f(r.montoInicial)),
                _EsperadoChip('Ventas ef.',  _f(r.ventas.efectivo)),
                if (r.abonos.efectivo > 0)
                  _EsperadoChip('Abonos ef.', _f(r.abonos.efectivo)),
                if (r.gastos.efectivo > 0)
                  _EsperadoChip('- Gastos',   _f(r.gastos.efectivo),  isNeg: true),
                if (r.devoluciones.netoEfectivo > 0)
                  _EsperadoChip('- Devoluc.', _f(r.devoluciones.netoEfectivo), isNeg: true),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(children: [
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icono, color: color, size: 28),
                ),
                const SizedBox(height: 14),
                Text(resultado,
                    style: GoogleFonts.inter(
                        color: color, fontWeight: FontWeight.w800,
                        fontSize: 12, letterSpacing: 1.5)),
                if (!esExacto) ...[
                  const SizedBox(height: 6),
                  Text(_f(dif.abs()),
                      style: GoogleFonts.inter(
                          color: color, fontWeight: FontWeight.w800,
                          fontSize: 44, letterSpacing: -2)),
                ] else ...[
                  const SizedBox(height: 6),
                  Text('Todo cuadra perfectamente',
                      style: GoogleFonts.inter(color: color, fontSize: 13)),
                ],
              ]),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cBorder),
              ),
              child: Column(children: [
                _ResRow('Contado fisico', _f(_montoIngresado), _cText),
                _ResRow('Esperado',       _f(r.montoEsperadoCaja), _cTextSec),
                const Divider(color: _cBorder, height: 20),
                _ResRow(
                  esSobrante ? 'Sobrante' : esExacto ? 'Diferencia' : 'Faltante',
                  '${dif >= 0 ? '+' : '-'}${_f(dif.abs())}',
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
        child: Container(
          color: _cBg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text('COMPROBANTE DE CIERRE',
                  style: GoogleFonts.inter(
                      color: _cTextMuted, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildTicket(r, resultado, color, hora, dif),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildTicket(ResumenCierre r, String resultado,
      Color color, String hora, double dif) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Column(children: [
          Text('─────────────────────', style: _mono(_cBorder)),
          Text('  CORTE #${r.sesionId}  ', style: _mono(_cText, bold: true)),
          Text('  ${r.tiendaNombre}  ',     style: _mono(_cTextSec)),
          Text('  $hora  ',                 style: _mono(_cTextMuted)),
          Text('─────────────────────', style: _mono(_cBorder)),
        ])),
        const SizedBox(height: 10),

        _tSec('RESPONSABLE'),
        _tFila('Cajero',   r.empleadoNombre),
        _tFila('Apertura', _formatFecha(r.fechaApertura)),
        _tFila('Cierre',   hora),

        const SizedBox(height: 2),
        _tSec('VENTAS'),
        _tFila('Efectivo',      _f(r.ventas.efectivo)),
        _tFila('Tarjeta',       _f(r.ventas.tarjeta)),
        _tFila('Transferencia', _f(r.ventas.transferencia)),
        if (r.ventas.mixto > 0) _tFila('Mixto', _f(r.ventas.mixto)),
        _tDiv(),
        _tFila('TOTAL',         _f(r.ventas.total), bold: true),
        _tFila('Transacciones', '${r.ventas.numTransacciones}'),

        if (r.abonos.total > 0) ...[
          const SizedBox(height: 2),
          _tSec('ABONOS / SEPARADOS'),
          if (r.abonos.efectivo > 0)      _tFila('Efectivo',  _f(r.abonos.efectivo)),
          if (r.abonos.tarjeta > 0)       _tFila('Tarjeta',   _f(r.abonos.tarjeta)),
          if (r.abonos.transferencia > 0) _tFila('Transfer.', _f(r.abonos.transferencia)),
          _tDiv(),
          _tFila('TOTAL',  _f(r.abonos.total),      bold: true),
          _tFila('Abonos', '${r.abonos.cantidad}'),
        ],

        const SizedBox(height: 2),
        _tSec('GASTOS'),
        if (r.gastos.detalle.isEmpty)
          _tFila('Sin gastos', '--')
        else ...[
          ...r.gastos.detalle.map((g) => _tFila(g.categoria, '-${_f(g.monto)}')),
          _tDiv(),
          _tFila('TOTAL', '-${_f(r.gastos.total)}', bold: true),
        ],

        if (r.devoluciones.cantidad > 0) ...[
          const SizedBox(height: 2),
          _tSec('DEVOLUCIONES'),
          if (r.devoluciones.cambiosProducto > 0)
            _tFila('Cambio producto', '${r.devoluciones.cambiosProducto}'),
          if (r.devoluciones.efectivo > 0)
            _tFila('Dev. efectivo',   '-${_f(r.devoluciones.efectivo)}'),
          if (r.devoluciones.cambiosDevolver > 0)
            _tFila('Dif. devuelta',   '-${_f(r.devoluciones.cambiosDevolver)}'),
          if (r.devoluciones.cambiosCobrar > 0)
            _tFila('Dif. cobrada',    '+${_f(r.devoluciones.cambiosCobrar)}'),
          _tDiv(),
          _tFila('NETO EF.', '-${_f(r.devoluciones.netoEfectivo)}', bold: true),
        ],

        const SizedBox(height: 2),
        _tSec('RESULTADO FINAL'),
        _tFila('Contado',  _f(_montoIngresado)),
        _tFila('Esperado', _f(r.montoEsperadoCaja)),
        _tDiv(),
        _tFila(resultado,  '${dif >= 0 ? '+' : ''}${_f(dif)}',
            bold: true, color: color),

        if (_obsCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 2),
          _tSec('OBSERVACIONES'),
          Text(_obsCtrl.text, style: _mono(Colors.white38)),
        ],

        const SizedBox(height: 12),
        Center(child: Text('── POS Multitienda ──', style: _mono(Colors.white12))),
      ]),
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
        if (_paso > 1)
          _GhostBtn(
            label: 'Atras',
            icon: Icons.arrow_back_rounded,
            onPressed: () => _irAPaso(_paso - 1),
          ),
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
            } else {
              final ok = await cont.cerrarCaja(
                montoFinalReal: _montoIngresado,
                observaciones:  _obsCtrl.text.trim(),
              );
              if (ok && mounted) Navigator.pop(context);
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03), blurRadius: 6,
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(7)),
            child: Icon(icono, color: accentColor, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(titulo,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 12, color: _cText)),
          ),
        ]),
        const SizedBox(height: 12),
        child,
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
  final String label;
  final double monto;
  final bool   isNeg;
  const _MontoRow(this.label, this.monto, {required this.isNeg});
  static final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  Widget build(BuildContext context) {
    final color = isNeg ? _cRed : _cGreen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: _cTextSec, fontWeight: FontWeight.w500)),
          Text('${isNeg ? '-' : '+'}\$${_fmt.format(monto)}',
              style: GoogleFonts.inter(
                  fontSize: 13, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DevRow extends StatelessWidget {
  final IconData icono;
  final Color    color;
  final String   label, valor, sub;
  const _DevRow({
    required this.icono, required this.color,
    required this.label, required this.valor, required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icono, size: 10, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(valor,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          Text(sub,
              style: GoogleFonts.inter(
                  fontSize: 10, color: _cTextMuted, fontStyle: FontStyle.italic)),
        ]),
      ]),
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

        _CalcLine('Saldo inicial',    f(r.montoInicial),          Colors.white70,  '+'),
        _CalcLine('Ventas efectivo',  f(r.ventas.efectivo),       Colors.white,    '+'),
        if (r.abonos.efectivo > 0)
          _CalcLine('Abonos efectivo', f(r.abonos.efectivo),     const Color(0xFF7DD3FC), '+'),
        _CalcLine('Gastos efectivo',  f(r.gastos.efectivo),      const Color(0xFFFFB4AB), '-'),
        if (r.devoluciones.netoEfectivo > 0)
          _CalcLine('Devoluciones ef.', f(r.devoluciones.netoEfectivo), const Color(0xFFFFB4AB), '-'),

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
                'Tarjeta ${f(r.ventas.tarjeta)} y transferencia '
                '${f(r.ventas.transferencia)} se depositan al banco.',
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
    final esFinal = paso == 3;
    final bgColor = esFinal ? _cRed : _cGreen;
    final label   = paso == 1 ? 'Continuar'
        : paso == 2 ? 'Ver resultado'
        : procesando ? 'Cerrando...' : 'Confirmar cierre';
    final icon = (procesando && esFinal)
        ? const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Icon(esFinal ? Icons.lock_rounded : Icons.arrow_forward_rounded, size: 15);

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
