import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/caja_provider.dart';
import '../../../models/resumen_cierre.dart';

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

  // ── Paleta ────────────────────────────────────────────────
  static const _bg        = Color(0xFF0A0E1A);
  static const _surface   = Color(0xFF111827);
  static const _card      = Color(0xFF1A2236);
  static const _border    = Color(0xFF1E2D45);
  static const _accent    = Color(0xFF3B82F6);
  static const _green     = Color(0xFF10B981);
  static const _red       = Color(0xFFEF4444);
  static const _yellow    = Color(0xFFF59E0B);
  static const _purple    = Color(0xFF8B5CF6);
  static const _sky       = Color(0xFF0EA5E9);
  static const _textPri   = Color(0xFFF1F5F9);
  static const _textSec   = Color(0xFF94A3B8);
  static const _textMuted = Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _stepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.04, 0),
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
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(56),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: _accent),
              const SizedBox(height: 20),
              Text('Cargando resumen del turno…',
                  style: GoogleFonts.dmSans(color: _textSec, fontSize: 14)),
            ]),
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth  = (screenSize.width  * 0.88).clamp(680.0, 860.0);
    final dialogHeight = (screenSize.height * 0.90).clamp(500.0, 900.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width:  dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 48,
              offset: const Offset(0, 20),
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
          _buildFooter(cont, resumen),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // HEADER — dark con stepper
  // ══════════════════════════════════════════════════
  Widget _buildHeader(ResumenCierre r) {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 20, 18),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: _accent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Corte de Caja',
                    style: GoogleFonts.dmSans(
                        color: _textPri, fontWeight: FontWeight.w700, fontSize: 17)),
                Text(r.tiendaNombre,
                    style: GoogleFonts.dmSans(color: _textMuted, fontSize: 12)),
              ]),
            ),
            // Cajero badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_accent, _purple]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      r.empleadoNombre.isNotEmpty
                          ? r.empleadoNombre[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(r.empleadoNombre,
                    style: GoogleFonts.dmSans(
                        color: _textSec, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),

        // Stepper
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: Row(children: List.generate(3, (i) {
            final idx    = i + 1;
            final activo = idx == _paso;
            final pasado = idx < _paso;
            final futuro = idx > _paso;
            return Expanded(child: Row(children: [
              Expanded(child: _StepItem(
                index: idx,
                label: _pasoLabels[i],
                activo: activo,
                pasado: pasado,
                futuro: futuro,
              )),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: pasado
                            ? [_green, _green.withOpacity(0.3)]
                            : [_border, _border],
                      ),
                    ),
                  ),
                ),
            ]));
          })),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // PASO 1 — Resumen (2 columnas)
  // ══════════════════════════════════════════════════
  Widget _buildPaso1(ResumenCierre r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        // Info del turno
        _TurnoInfoBar(r: r, formatFecha: _formatFecha),
        const SizedBox(height: 20),

        // Grid 2 columnas
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Columna izquierda
          Expanded(child: Column(children: [
            _SummaryCard(
              titulo: 'Ventas del turno',
              icono: Icons.trending_up_rounded,
              accentColor: _accent,
              child: Column(children: [
                _MetodoPago('Efectivo',      r.ventas.efectivo,      _green,  Icons.payments_rounded),
                _MetodoPago('Tarjeta',       r.ventas.tarjeta,       _accent, Icons.credit_card_rounded),
                _MetodoPago('Transferencia', r.ventas.transferencia, _purple, Icons.swap_horiz_rounded),
                if (r.ventas.mixto > 0)
                  _MetodoPago('Mixto', r.ventas.mixto, _yellow, Icons.compare_arrows_rounded),
                _SummaryDivider(),
                _TotalRow('TOTAL VENTAS', _f(r.ventas.total), _textPri),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: _Badge('${r.ventas.numTransacciones} transacciones', _accent),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            _SummaryCard(
              titulo: 'Gastos del turno',
              icono: Icons.trending_down_rounded,
              accentColor: _red,
              child: r.gastos.detalle.isEmpty
                  ? _EmptyState('Sin gastos registrados')
                  : Column(children: [
                      ...r.gastos.detalle.map((g) => _DetalleRow(
                        '${g.categoria}',
                        '${g.metodoPago}',
                        '-${_f(g.monto)}',
                        _red,
                      )),
                      _SummaryDivider(),
                      _TotalRow('TOTAL GASTOS', '-${_f(r.gastos.total)}', _red),
                    ]),
            ),

            if (r.abonos.total > 0) ...[
              const SizedBox(height: 14),
              _SummaryCard(
                titulo: 'Abonos recibidos',
                icono: Icons.bookmark_added_rounded,
                accentColor: _sky,
                child: Column(children: [
                  if (r.abonos.efectivo > 0)
                    _MetodoPago('Efectivo',      r.abonos.efectivo,      _sky, Icons.payments_rounded),
                  if (r.abonos.transferencia > 0)
                    _MetodoPago('Transferencia', r.abonos.transferencia, _sky, Icons.swap_horiz_rounded),
                  _SummaryDivider(),
                  _TotalRow('TOTAL ABONOS', _f(r.abonos.total), _sky),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _Badge(
                        '${r.abonos.cantidad} abono${r.abonos.cantidad != 1 ? "s" : ""}',
                        _sky),
                  ),
                ]),
              ),
              _InfoTip('Solo abonos en efectivo afectan el cuadre de caja.'),
            ],
          ])),

          const SizedBox(width: 14),

          // Columna derecha
          Expanded(child: Column(children: [
            // Devoluciones
            if (r.devoluciones.cantidad > 0) ...[
              _SummaryCard(
                titulo: 'Devoluciones',
                icono: Icons.assignment_return_rounded,
                accentColor: _yellow,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (r.devoluciones.cambiosProducto > 0) ...[
                    _BadgeRow(
                      icono: Icons.swap_horiz_rounded,
                      color: _purple,
                      label: 'Cambio por producto',
                      valor: '${r.devoluciones.cambiosProducto} cambio${r.devoluciones.cambiosProducto != 1 ? "s" : ""}',
                      sub: 'No sale dinero del cajón',
                    ),
                    if (r.devoluciones.efectivo > 0 ||
                        r.devoluciones.cambiosDevolver > 0 ||
                        r.devoluciones.cambiosCobrar > 0)
                      _SummaryDivider(),
                  ],
                  if (r.devoluciones.efectivo > 0)
                    _DetalleRow('Dev. efectivo', '', '-${_f(r.devoluciones.efectivo)}', _red),
                  if (r.devoluciones.cambiosDevolver > 0)
                    _DetalleRow('Dif. devuelta', '', '-${_f(r.devoluciones.cambiosDevolver)}', _red),
                  if (r.devoluciones.cambiosCobrar > 0)
                    _DetalleRow('Dif. cobrada', '', '+${_f(r.devoluciones.cambiosCobrar)}', _green),
                  if (r.devoluciones.efectivo == 0 &&
                      r.devoluciones.cambiosDevolver == 0 &&
                      r.devoluciones.cambiosCobrar == 0)
                    _EmptyState('Sin devoluciones en efectivo'),
                  _SummaryDivider(),
                  _TotalRow('NETO EFECTIVO', '-${_f(r.devoluciones.netoEfectivo.abs())}', _yellow),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _Badge(
                        '${r.devoluciones.cantidad} devolución${r.devoluciones.cantidad != 1 ? "es" : ""}',
                        _yellow),
                  ),
                ]),
              ),
              _InfoTip('Solo las devoluciones en efectivo reducen el cuadre.'),
              const SizedBox(height: 14),
            ],

            // Cálculo caja física — destacado
            _CajaEsperadaCard(r: r, f: _f),
            const SizedBox(height: 8),
            _InfoTip(
                'Tarjeta ${_f(r.ventas.tarjeta)} y transferencia '
                '${_f(r.ventas.transferencia)} van al banco.'),
          ])),
        ]),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // PASO 2 — Conteo físico
  // ══════════════════════════════════════════════════
  Widget _buildPaso2(ResumenCierre r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        // Hero del monto esperado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF065F46)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _green.withOpacity(0.3)),
            boxShadow: [BoxShadow(
              color: _green.withOpacity(0.2),
              blurRadius: 32, offset: const Offset(0, 8),
            )],
          ),
          child: Column(children: [
            Text('Esperado en caja',
                style: GoogleFonts.dmSans(
                    color: _green.withOpacity(0.75), fontSize: 13,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Text(_f(r.montoEsperadoCaja),
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 52, letterSpacing: -2)),
            const SizedBox(height: 18),
            // Chips
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12, runSpacing: 8,
              children: [
                _EsperadoChip('Inicial',      _f(r.montoInicial)),
                _EsperadoChip('Ef. ventas',   _f(r.ventas.efectivo)),
                if (r.abonos.efectivo > 0)
                  _EsperadoChip('Abonos ef.',  _f(r.abonos.efectivo)),
                if (r.gastos.efectivo > 0)
                  _EsperadoChip('- Gastos',    _f(r.gastos.efectivo),
                      isNeg: true),
                if (r.devoluciones.netoEfectivo > 0)
                  _EsperadoChip('- Devoluc.',  _f(r.devoluciones.netoEfectivo),
                      isNeg: true),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 32),

        // Entrada del monto
        Align(
          alignment: Alignment.centerLeft,
          child: Text('¿Cuánto hay físicamente en el cajón?',
              style: GoogleFonts.dmSans(
                  fontSize: 15, color: _textSec, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
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
                style: GoogleFonts.dmSans(
                    fontSize: 40, fontWeight: FontWeight.w800,
                    color: _textPri, letterSpacing: -1.5),
                decoration: InputDecoration(
                  labelText: 'Monto contado',
                  prefixText: '\$ ',
                  labelStyle: GoogleFonts.dmSans(
                      fontSize: 13, color: _textMuted),
                  prefixStyle: GoogleFonts.dmSans(
                      fontSize: 40, fontWeight: FontWeight.w800,
                      color: _textMuted),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.all(22),
              child: TextField(
                controller: _obsCtrl,
                maxLines: 3,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: _textSec),
                decoration: InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  hintText: 'Ej: billetes contados, diferencias…',
                  labelStyle: GoogleFonts.dmSans(
                      fontSize: 12, color: _textMuted),
                  hintStyle: GoogleFonts.dmSans(
                      fontSize: 12, color: _textMuted.withOpacity(0.5)),
                  filled: true,
                  fillColor: _bg.withOpacity(0.5),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accent, width: 1.5)),
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
  // PASO 3 — Resultado / Ticket
  // ══════════════════════════════════════════════════
  Widget _buildPaso3(ResumenCierre r) {
    final dif        = _diferencia;
    final esExacto   = dif.abs() < 0.01;
    final esSobrante = dif > 0;

    final color     = esExacto
        ? _green : esSobrante ? _accent : _red;
    final bgColor   = esExacto
        ? const Color(0xFF022C22)
        : esSobrante ? const Color(0xFF0E1B4E) : const Color(0xFF2D0A0A);
    final icono     = esExacto
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
      // ── Columna izquierda: resultado visual ─────────
      Expanded(
        flex: 5,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            // Hero resultado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                boxShadow: [BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 32, offset: const Offset(0, 8),
                )],
              ),
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Icon(icono, color: color, size: 32),
                ),
                const SizedBox(height: 14),
                Text(resultado,
                    style: GoogleFonts.dmSans(
                        color: color, fontWeight: FontWeight.w800,
                        fontSize: 13, letterSpacing: 1.5)),
                if (!esExacto) ...[
                  const SizedBox(height: 6),
                  Text(_f(dif.abs()),
                      style: GoogleFonts.dmSans(
                          color: Colors.white, fontWeight: FontWeight.w800,
                          fontSize: 44, letterSpacing: -2)),
                ] else ...[
                  const SizedBox(height: 6),
                  Text('¡Todo cuadra perfectamente!',
                      style: GoogleFonts.dmSans(
                          color: _green.withOpacity(0.75), fontSize: 13)),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // Tabla resumen rápido
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(children: [
                _ResultRow('Contado físico', _f(_montoIngresado), _textPri),
                _ResultRow('Esperado',       _f(r.montoEsperadoCaja), _textSec),
                const Divider(color: _border, height: 20),
                _ResultRow(
                  esSobrante ? 'Sobrante' : esExacto ? 'Diferencia' : 'Faltante',
                  '${dif >= 0 ? '+' : '-'}${_f(dif.abs())}',
                  color,
                  bold: true,
                ),
              ]),
            ),
            const SizedBox(height: 14),

            // Observaciones
            if (_obsCtrl.text.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('OBSERVACIONES',
                      style: GoogleFonts.dmSans(
                          color: _textMuted, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(_obsCtrl.text,
                      style: GoogleFonts.dmSans(
                          color: _textSec, fontSize: 13)),
                ]),
              ),
          ]),
        ),
      ),

      // Separador vertical
      Container(width: 1, color: _border),

      // ── Columna derecha: ticket ──────────────────────
      Expanded(
        flex: 4,
        child: Container(
          color: _bg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text('COMPROBANTE',
                  style: GoogleFonts.dmSans(
                      color: _textMuted, fontSize: 10,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Column(children: [
          Text('─────────────────────', style: _monoStyle(_border)),
          Text('  CORTE #${r.sesionId}  ', style: _monoStyle(_textPri, bold: true)),
          Text('  ${r.tiendaNombre}  ', style: _monoStyle(_textSec)),
          Text('  $hora  ', style: _monoStyle(_textMuted)),
          Text('─────────────────────', style: _monoStyle(_border)),
        ])),
        const SizedBox(height: 10),

        _tSeccion('RESPONSABLE'),
        _tFila('Cajero',   r.empleadoNombre),
        _tFila('Apertura', _formatFecha(r.fechaApertura)),
        _tFila('Cierre',   hora),

        const SizedBox(height: 8),
        _tSeccion('VENTAS'),
        _tFila('Efectivo',      _f(r.ventas.efectivo)),
        _tFila('Tarjeta',       _f(r.ventas.tarjeta)),
        _tFila('Transferencia', _f(r.ventas.transferencia)),
        if (r.ventas.mixto > 0)
          _tFila('Mixto', _f(r.ventas.mixto)),
        _tDivider(),
        _tFila('TOTAL', _f(r.ventas.total), bold: true),
        _tFila('Transacciones', '${r.ventas.numTransacciones}'),

        if (r.abonos.total > 0) ...[
          const SizedBox(height: 8),
          _tSeccion('ABONOS'),
          if (r.abonos.efectivo > 0)
            _tFila('Efectivo',      _f(r.abonos.efectivo)),
          if (r.abonos.transferencia > 0)
            _tFila('Transfer.',     _f(r.abonos.transferencia)),
          _tFila('TOTAL', _f(r.abonos.total), bold: true),
        ],

        const SizedBox(height: 8),
        _tSeccion('GASTOS'),
        if (r.gastos.detalle.isEmpty)
          _tFila('Sin gastos', _f(0))
        else ...[
          ...r.gastos.detalle.map((g) =>
              _tFila(g.categoria, '-${_f(g.monto)}')),
          _tDivider(),
          _tFila('TOTAL', '-${_f(r.gastos.total)}', bold: true),
        ],

        if (r.devoluciones.cantidad > 0) ...[
          const SizedBox(height: 8),
          _tSeccion('DEVOLUCIONES'),
          if (r.devoluciones.cambiosProducto > 0)
            _tFila('Cambios prod.', '${r.devoluciones.cambiosProducto}'),
          if (r.devoluciones.efectivo > 0)
            _tFila('Dev. efectivo', '-${_f(r.devoluciones.efectivo)}'),
          if (r.devoluciones.cambiosDevolver > 0)
            _tFila('Dif. devuelta', '-${_f(r.devoluciones.cambiosDevolver)}'),
          if (r.devoluciones.cambiosCobrar > 0)
            _tFila('Dif. cobrada', '+${_f(r.devoluciones.cambiosCobrar)}'),
          _tDivider(),
          _tFila('NETO EF.', '-${_f(r.devoluciones.netoEfectivo)}', bold: true),
        ],

        const SizedBox(height: 8),
        _tSeccion('RESULTADO FINAL'),
        _tFila('Contado',  _f(_montoIngresado)),
        _tFila('Esperado', _f(r.montoEsperadoCaja)),
        _tDivider(),
        _tFila(resultado, '${dif >= 0 ? '+' : ''}${_f(dif)}',
            bold: true, color: color),

        if (_obsCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _tSeccion('OBSERVACIONES'),
          Text(_obsCtrl.text, style: _monoStyle(_textMuted)),
        ],

        const SizedBox(height: 12),
        Center(child: Text('── POS Multitienda ──', style: _monoStyle(_border))),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // FOOTER — acciones
  // ══════════════════════════════════════════════════
  Widget _buildFooter(CajaProvider cont, ResumenCierre resumen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(children: [
        if (_paso > 1)
          _GhostButton(
            label: 'Atrás',
            icon: Icons.arrow_back_rounded,
            onPressed: () => _irAPaso(_paso - 1),
          ),
        const Spacer(),
        if (_paso == 1)
          _GhostButton(
            label: 'Cancelar',
            icon: Icons.close_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        const SizedBox(width: 10),
        _ActionButton(
          paso: _paso,
          procesando: cont.procesando,
          onPressed: cont.procesando ? null : () async {
            if (_paso == 1) {
              _irAPaso(2);
            } else if (_paso == 2) {
              final monto = double.tryParse(_montoCtrl.text);
              if (monto == null || monto < 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Ingresa un monto válido',
                      style: GoogleFonts.dmSans(color: Colors.white)),
                  backgroundColor: _red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
              if (ok && context.mounted) Navigator.pop(context);
            }
          },
        ),
      ]),
    );
  }

  // ── Helpers ticket ──────────────────────────────────────────
  TextStyle _monoStyle(Color c, {bool bold = false}) => TextStyle(
    fontFamily: 'monospace', fontSize: 11.5, color: c,
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
  );

  Widget _tSeccion(String t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(t,
        style: GoogleFonts.dmSans(
            fontSize: 9.5, fontWeight: FontWeight.w800,
            color: _textMuted, letterSpacing: 1.2)),
  );

  Widget _tFila(String label, String valor,
      {bool bold = false, Color? color}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _monoStyle(color ?? _textSec, bold: bold)),
          Text(valor,  style: _monoStyle(color ?? _textPri, bold: bold)),
        ],
      ),
    );

  Widget _tDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('─────────────────────', style: _monoStyle(_border)),
  );
}

// ══════════════════════════════════════════════════════════
// COMPONENTES AUXILIARES
// ══════════════════════════════════════════════════════════

class _StepItem extends StatelessWidget {
  final int    index;
  final String label;
  final bool   activo, pasado, futuro;
  const _StepItem({
    required this.index, required this.label,
    required this.activo, required this.pasado, required this.futuro,
  });

  static const _green  = Color(0xFF10B981);
  static const _accent = Color(0xFF3B82F6);
  static const _border = Color(0xFF1E2D45);
  static const _textSec = Color(0xFF94A3B8);
  static const _textMuted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final circleColor = pasado
        ? _green : activo ? _accent : _border;
    final textColor = activo
        ? Colors.white : pasado ? _green : _textMuted;

    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: circleColor.withOpacity(activo ? 1 : pasado ? 0.2 : 0.5),
          borderRadius: BorderRadius.circular(17),
          border: activo
              ? Border.all(color: _accent.withOpacity(0.5), width: 2)
              : Border.all(color: circleColor.withOpacity(0.3)),
        ),
        child: Center(
          child: pasado
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text('$index',
                  style: GoogleFonts.dmSans(
                      color: activo ? Colors.white : textColor,
                      fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 6),
      Text(label,
          style: GoogleFonts.dmSans(
              color: activo ? Colors.white : _textSec,
              fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _TurnoInfoBar extends StatelessWidget {
  final ResumenCierre r;
  final String Function(String) formatFecha;
  const _TurnoInfoBar({required this.r, required this.formatFecha});

  static const _card   = Color(0xFF1A2236);
  static const _border = Color(0xFF1E2D45);
  static const _textPri   = Color(0xFFF1F5F9);
  static const _textSec   = Color(0xFF94A3B8);
  static const _textMuted = Color(0xFF475569);
  static const _green  = Color(0xFF10B981);
  static const _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_accent, Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              r.empleadoNombre.isNotEmpty
                  ? r.empleadoNombre[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.empleadoNombre,
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: _textPri)),
            const SizedBox(height: 2),
            Text('Apertura: ${formatFecha(r.fechaApertura)}',
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: _textMuted)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _green.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text('Turno activo',
                style: GoogleFonts.dmSans(
                    color: _green, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String   titulo;
  final IconData icono;
  final Color    accentColor;
  final Widget   child;
  const _SummaryCard({
    required this.titulo, required this.icono,
    required this.accentColor, required this.child,
  });

  static const _card   = Color(0xFF1A2236);
  static const _border = Color(0xFF1E2D45);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: accentColor, size: 15),
          ),
          const SizedBox(width: 10),
          Text(titulo,
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: accentColor)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _MetodoPago extends StatelessWidget {
  final String label;
  final double valor;
  final Color  color;
  final IconData icono;
  const _MetodoPago(this.label, this.valor, this.color, this.icono);

  static final _fmt = NumberFormat('#,##0', 'en_US');
  String _f(double v) => '\$${_fmt.format(v)}';

  static const _textMuted = Color(0xFF475569);
  static const _textSec   = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icono, size: 13, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: _textSec, fontWeight: FontWeight.w500)),
        ),
        Text(_f(valor),
            style: GoogleFonts.dmSans(
                fontSize: 13, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _DetalleRow extends StatelessWidget {
  final String label, sub, valor;
  final Color  color;
  const _DetalleRow(this.label, this.sub, this.valor, this.color);

  static const _textSec = Color(0xFF94A3B8);
  static const _textMuted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: _textSec, fontWeight: FontWeight.w500)),
          if (sub.isNotEmpty)
            Text(sub,
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: _textMuted)),
        ])),
        Text(valor,
            style: GoogleFonts.dmSans(
                fontSize: 13, color: color, fontWeight: FontWeight.w700)),
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
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: color, fontWeight: FontWeight.w800)),
          Text(valor,
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Divider(height: 1, color: Color(0xFF1E2D45)),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color  color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(text,
        style: GoogleFonts.dmSans(
            fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );
}

class _BadgeRow extends StatelessWidget {
  final IconData icono;
  final Color    color;
  final String   label, valor, sub;
  const _BadgeRow({
    required this.icono, required this.color,
    required this.label, required this.valor, required this.sub,
  });
  static const _textMuted = Color(0xFF475569);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
      const Spacer(),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(valor,
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        Text(sub,
            style: GoogleFonts.dmSans(
                fontSize: 10, color: _textMuted,
                fontStyle: FontStyle.italic)),
      ]),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState(this.msg);
  static const _textMuted = Color(0xFF475569);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(msg,
        style: GoogleFonts.dmSans(
            fontSize: 12, color: _textMuted,
            fontStyle: FontStyle.italic)),
  );
}

class _InfoTip extends StatelessWidget {
  final String msg;
  const _InfoTip(this.msg);
  static const _textMuted = Color(0xFF475569);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 2),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded,
          size: 12, color: _textMuted),
      const SizedBox(width: 5),
      Expanded(
        child: Text(msg,
            style: GoogleFonts.dmSans(
                fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500)),
      ),
    ]),
  );
}

class _CajaEsperadaCard extends StatelessWidget {
  final ResumenCierre r;
  final String Function(double) f;
  const _CajaEsperadaCard({required this.r, required this.f});

  static const _green  = Color(0xFF10B981);
  static const _red    = Color(0xFFEF4444);
  static const _sky    = Color(0xFF0EA5E9);
  static const _yellow = Color(0xFFF59E0B);
  static const _border = Color(0xFF1E2D45);
  static const _textSec = Color(0xFF94A3B8);
  static const _textMuted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF063A26), Color(0xFF0A4D33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(
          color: _green.withOpacity(0.12),
          blurRadius: 20, offset: const Offset(0, 6),
        )],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _green.withOpacity(0.3)),
            ),
            child: const Icon(Icons.calculate_rounded, color: _green, size: 16),
          ),
          const SizedBox(width: 10),
          Text('Cálculo de caja física',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700, fontSize: 13, color: _green)),
        ]),
        const SizedBox(height: 16),

        _LineaCalculo('Saldo inicial',       f(r.montoInicial),        _textSec,  '+'),
        _LineaCalculo('Ventas efectivo',      f(r.ventas.efectivo),     _green,    '+'),
        if (r.ventas.mixto > 0)
          _LineaCalculo('Ventas mixto',       f(r.ventas.mixto),        _green,    '+'),
        if (r.abonos.efectivo > 0)
          _LineaCalculo('Abonos efectivo',    f(r.abonos.efectivo),     _sky,      '+'),
        _LineaCalculo('Gastos efectivo',      f(r.gastos.efectivo),     _red,      '−'),
        if (r.devoluciones.netoEfectivo > 0)
          _LineaCalculo('Devoluciones ef.',   f(r.devoluciones.netoEfectivo), _yellow, '−'),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
              height: 1,
              color: _green.withOpacity(0.2)),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ESPERADO EN CAJA',
                style: GoogleFonts.dmSans(
                    color: _green, fontWeight: FontWeight.w800, fontSize: 12)),
            Text(f(r.montoEsperadoCaja),
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 22, letterSpacing: -0.5)),
          ],
        ),
      ]),
    );
  }
}

class _LineaCalculo extends StatelessWidget {
  final String label, valor, signo;
  final Color  color;
  const _LineaCalculo(this.label, this.valor, this.color, this.signo);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(children: [
        Text(signo,
            style: TextStyle(color: color.withOpacity(0.6),
                fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: color.withOpacity(0.75))),
        ),
        Text(valor,
            style: GoogleFonts.dmSans(
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                color: isNeg ? Colors.red.shade300 : Colors.white60,
                fontSize: 10, fontWeight: FontWeight.w600)),
        Text(valor,
            style: TextStyle(
                color: isNeg ? Colors.red.shade300 : Colors.white,
                fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label, valor;
  final Color  color;
  final bool   bold;
  const _ResultRow(this.label, this.valor, this.color, {this.bold = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: color.withOpacity(bold ? 1 : 0.8),
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(valor,
              style: GoogleFonts.dmSans(
                  color: color, fontSize: bold ? 18 : 13,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String   label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _GhostButton({required this.label, required this.icon, this.onPressed});
  static const _textMuted = Color(0xFF475569);
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: Icon(icon, size: 15),
    label: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: _textMuted,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final int  paso;
  final bool procesando;
  final VoidCallback? onPressed;
  const _ActionButton({
    required this.paso, required this.procesando, this.onPressed,
  });

  static const _accent = Color(0xFF3B82F6);
  static const _red    = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final esFinal   = paso == 3;
    final startColor = esFinal ? _red : _accent;
    final endColor   = esFinal
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB);
    final label = paso == 1
        ? 'Continuar'
        : paso == 2 ? 'Ver resultado'
        : procesando ? 'Cerrando…' : 'Confirmar cierre';
    final icon = procesando && esFinal
        ? const SizedBox(
            width: 15, height: 15,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Icon(
            esFinal ? Icons.lock_rounded : Icons.arrow_forward_rounded,
            size: 16);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: startColor.withOpacity(0.35),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: ElevatedButton.icon(
        icon: icon,
        label: Text(label,
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor:     Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}