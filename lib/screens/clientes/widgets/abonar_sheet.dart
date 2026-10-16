import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/cuenta_bancaria.dart';
import '../../../models/separado.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cliente_provider.dart';
import '../../../providers/config_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/recibo_pdf_service.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../services/windows_printer_service.dart';

// ── Paleta ────────────────────────────────────────────────
const _kTeal      = Color(0xFF006C49);
const _kTealLight = Color(0xFFE8FFF4);
const _kTealMid   = Color(0xFF01696F);
const _kAmber     = Color(0xFFF59E0B);
const _kText      = Color(0xFF191C1E);
const _kMuted     = Color(0xFF76777D);
const _kBorder    = Color(0xFFE0E3E5);
const _kSurface   = Color(0xFFF7F9FB);

class AbonarSheet extends StatefulWidget {
  final Separado     separado;
  final NumberFormat fmt;
  final VoidCallback? onAbonado;

  const AbonarSheet({
    super.key,
    required this.separado,
    required this.fmt,
    this.onAbonado,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required Separado     separado,
    required NumberFormat fmt,
    VoidCallback?         onAbonado,
  }) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => AbonarSheet(separado: separado, fmt: fmt, onAbonado: onAbonado),
    );
  }

  @override
  State<AbonarSheet> createState() => _AbonarSheetState();
}

class _AbonarSheetState extends State<AbonarSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  String _metodoPago        = 'efectivo';
  int?   _cuentaSeleccionadaId;

  static const _metodos = [
    ('efectivo',      'Efectivo',      Icons.payments_outlined),
    ('transferencia', 'Transferencia', Icons.swap_horiz_rounded),
    ('tarjeta',       'Tarjeta',       Icons.credit_card_outlined),
  ];

  double get _saldo => widget.separado.saldoPendiente;

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  void _pagarTodo() {
    _montoCtrl.text = _saldo.toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _abonar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ingresado = double.tryParse(_montoCtrl.text.trim()) ?? 0;
    // Si el cliente paga de más, registramos solo el saldo pendiente
    final monto = ingresado > _saldo ? _saldo : ingresado;
    final cambio = ingresado > _saldo ? ingresado - _saldo : 0.0;
    final prov  = context.read<ClienteProvider>();

    final ok = await prov.abonarSeparado(widget.separado.id, monto, _metodoPago,
        cuentaDestinoId: _cuentaSeleccionadaId);
    if (!mounted) return;

    if (ok) {
      if (_metodoPago == 'efectivo') unawaited(_kickCajon());
      final imprimir = await showDialog<bool>(
        context:            context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header verde
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: const BoxDecoration(
                  color: _kTeal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text('¡Abono registrado!',
                      style: GoogleFonts.inter(fontSize: 18,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(widget.separado.clienteNombre,
                      style: GoogleFonts.inter(fontSize: 13,
                          color: Colors.white70)),
                ]),
              ),
              // Cuerpo
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(children: [
                  _dialogRow('Abono registrado',
                      widget.fmt.format(monto), _kTeal),
                  if (cambio > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.currency_exchange,
                            size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Text('Cambio al cliente',
                            style: GoogleFonts.inter(fontSize: 13,
                                color: const Color(0xFFD97706))),
                        const Spacer(),
                        Text(widget.fmt.format(cambio),
                            style: GoogleFonts.inter(fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD97706))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('¿Imprimir recibo de abono?',
                      style: GoogleFonts.inter(fontSize: 13, color: _kMuted)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kMuted,
                          side: const BorderSide(color: _kBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('No gracias',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: Text('Imprimir',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ]),
              ),
            ]),
          ),
        ),
      );

      if (!mounted) return;
      if (imprimir == true) {
        await _imprimirReciboAbono(monto, _metodoPago);
        if (!mounted) return;
      }

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onAbonado?.call();
      messenger.showSnackBar(SnackBar(
        content: Text('Abono de ${widget.fmt.format(monto)} registrado ✅',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: _kTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(prov.error ?? 'Error al registrar abono',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _kickCajon() async {
    try {
      if (ThermalPrinterService.isWebUsbSupported) {
        if (!await ThermalPrinterService.hasCashDrawer()) return;
        final dev = await ThermalPrinterService.getAutoDevice();
        if (dev != null) await ThermalPrinterService.kickDrawer(dev);
      } else if (!kIsWeb && await ThermalPrinterService.hasCashDrawer()) {
        final bytes = await ThermalPrinterService.buildDrawerBytes();
        await WindowsPrinterService.printRaw(bytes);
      }
    } catch (_) {}
  }

  Future<void> _imprimirReciboAbono(double monto, String metodo) async {
    final auth          = context.read<AuthProvider>();
    final empresaNombre = auth.empresaNombre.isNotEmpty
        ? auth.empresaNombre
        : widget.separado.tiendaNombre;

    if (ThermalPrinterService.isWebUsbSupported) {
      try {
        final dev = await ThermalPrinterService.getAutoDevice();
        if (dev != null) {
          final bytes = await ThermalPrinterService.buildReciboAbono(
            separado: widget.separado, monto: monto,
            metodoPago: metodo, empresaNombre: empresaNombre,
          );
          await ThermalPrinterService.printBytes(dev, bytes);
          return;
        }
      } catch (_) {}
    } else if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
      try {
        final bytes = await ThermalPrinterService.buildReciboAbono(
          separado: widget.separado, monto: monto,
          metodoPago: metodo, empresaNombre: empresaNombre,
        );
        await WindowsPrinterService.printRaw(bytes);
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    await ReciboPdfService.imprimirReciboAbono(
      separado: widget.separado, monto: monto,
      metodoPago: metodo, empresaNombre: empresaNombre,
    );
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom    = MediaQuery.of(context).viewInsets.bottom;
    final sep       = widget.separado;
    final ingresado = double.tryParse(_montoCtrl.text.trim()) ?? 0;
    final nuevoSaldo = (_saldo - ingresado).clamp(0.0, double.infinity);
    final saldado    = ingresado > 0 && nuevoSaldo == 0;
    final excede     = ingresado > _saldo;
    final fmtInt     = NumberFormat('#,##0', 'es_CO');

    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Handle ─────────────────────────────────────
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // ── Tarjeta cliente + progreso ──────────────────
              _clienteCard(sep, fmtInt),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Sección pago ──────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kBorder),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header sección
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _kTeal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.payments_outlined,
                                  size: 16, color: _kTeal),
                            ),
                            const SizedBox(width: 10),
                            Text('Registrar pago',
                                style: GoogleFonts.inter(fontSize: 14,
                                    fontWeight: FontWeight.w700, color: _kText)),
                          ]),

                          const SizedBox(height: 16),

                          // Método de pago — chips
                          Text('Método de pago',
                              style: GoogleFonts.inter(fontSize: 11,
                                  fontWeight: FontWeight.w600, color: _kMuted)),
                          const SizedBox(height: 8),
                          Row(
                            children: _metodos.map((m) {
                              final sel = _metodoPago == m.$1;
                              final isLast = m.$1 == _metodos.last.$1;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: isLast ? 0 : 8),
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _metodoPago = m.$1;
                                      _cuentaSeleccionadaId = null;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 130),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: sel ? _kTeal : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: sel ? _kTeal : _kBorder),
                                        boxShadow: sel ? [
                                          BoxShadow(
                                              color: _kTeal.withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3)),
                                        ] : null,
                                      ),
                                      child: Column(children: [
                                        Icon(m.$3, size: 18,
                                            color: sel ? Colors.white : _kMuted),
                                        const SizedBox(height: 4),
                                        Text(m.$2,
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: sel ? Colors.white : _kMuted),
                                            textAlign: TextAlign.center),
                                      ]),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          // Selector de cuentas bancarias
                          Builder(builder: (ctx) {
                            if (_metodoPago == 'efectivo') {
                              return const SizedBox.shrink();
                            }
                            final cuentas = ctx.watch<ConfigProvider>().cuentas
                                .where((c) => _metodoPago == 'tarjeta'
                                    ? c.tipo == 'tarjeta'
                                    : c.tipo != 'tarjeta')
                                .toList();
                            if (cuentas.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text('Cuenta destino',
                                    style: GoogleFonts.inter(fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _kMuted)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: cuentas.map((c) {
                                    final sel = _cuentaSeleccionadaId == c.id;
                                    return GestureDetector(
                                      onTap: () => setState(() =>
                                          _cuentaSeleccionadaId = sel ? null : c.id),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 120),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: sel
                                              ? _kTeal.withValues(alpha: 0.1)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: sel ? _kTeal : _kBorder,
                                            width: sel ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(mainAxisSize: MainAxisSize.min,
                                            children: [
                                          Icon(Icons.account_balance_wallet_outlined,
                                              size: 13,
                                              color: sel ? _kTeal : _kMuted),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(c.nombre,
                                                  style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: sel ? _kTeal : _kText)),
                                              Text(c.tipoDisplay,
                                                  style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: sel ? _kTeal : _kMuted)),
                                            ],
                                          ),
                                          if (sel) ...[
                                            const SizedBox(width: 6),
                                            Icon(Icons.check_circle,
                                                size: 13, color: _kTeal),
                                          ],
                                        ]),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          }),

                          const SizedBox(height: 16),
                          const Divider(height: 1, color: _kBorder),
                          const SizedBox(height: 16),

                          // Monto a abonar
                          Row(children: [
                            Text('Monto a abonar',
                                style: GoogleFonts.inter(fontSize: 11,
                                    fontWeight: FontWeight.w600, color: _kMuted)),
                            const Spacer(),
                            GestureDetector(
                              onTap: _pagarTodo,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kTeal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _kTeal.withValues(alpha: 0.3)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min,
                                    children: [
                                  const Icon(Icons.done_all_rounded,
                                      size: 12, color: _kTeal),
                                  const SizedBox(width: 4),
                                  Text('Pagar todo',
                                      style: GoogleFonts.inter(fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _kTeal)),
                                ]),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),

                          // Input monto grande
                          TextFormField(
                            controller:   _montoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.inter(fontSize: 28,
                                fontWeight: FontWeight.w800, color: _kText),
                            decoration: InputDecoration(
                              prefixText: '\$ ',
                              prefixStyle: GoogleFonts.inter(fontSize: 28,
                                  fontWeight: FontWeight.w800, color: _kTeal),
                              hintText:  fmtInt.format(_saldo),
                              hintStyle: GoogleFonts.inter(fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade200),
                              filled:    true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: _kBorder)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: _kBorder)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: _kTeal, width: 1.5)),
                              errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.red.shade400, width: 1.5)),
                              focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.red.shade400, width: 1.5)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa un monto';
                              }
                              final m = double.tryParse(v.trim());
                              if (m == null || m <= 0) {
                                return 'El monto debe ser mayor a 0';
                              }
                              return null;
                            },
                          ),

                          // Feedback en tiempo real
                          if (ingresado > 0) ...[
                            const SizedBox(height: 10),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: excede
                                    ? const Color(0xFFFFFBEB)
                                    : saldado
                                        ? const Color(0xFFDCFCE7)
                                        : _kTealLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: excede
                                      ? const Color(0xFFFDE68A)
                                      : saldado
                                          ? const Color(0xFF86EFAC)
                                          : _kTeal.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(children: [
                                Icon(
                                  excede
                                      ? Icons.currency_exchange
                                      : saldado
                                          ? Icons.check_circle_rounded
                                          : Icons.info_outline_rounded,
                                  size: 16,
                                  color: excede
                                      ? const Color(0xFFD97706)
                                      : saldado
                                          ? const Color(0xFF16A34A)
                                          : _kTeal,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    excede
                                        ? 'Cambio al cliente'
                                        : saldado
                                            ? '¡Separado completamente saldado!'
                                            : 'Nuevo saldo: \$${fmtInt.format(nuevoSaldo)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: excede
                                          ? const Color(0xFFD97706)
                                          : saldado
                                              ? const Color(0xFF16A34A)
                                              : _kTeal,
                                    ),
                                  ),
                                ),
                                if (excede)
                                  Text(
                                    '\$${fmtInt.format(ingresado - _saldo)}',
                                    style: GoogleFonts.inter(
                                        fontSize: 15, fontWeight: FontWeight.w800,
                                        color: const Color(0xFFD97706)),
                                  )
                                else if (saldado)
                                  const Text('🎉', style: TextStyle(fontSize: 14)),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Botón registrar ───────────────────────
                    Selector<ClienteProvider, bool>(
                      selector: (_, p) => p.guardando,
                      builder: (_, guardando, __) {
                        final montoDisplay = ingresado > 0
                            ? widget.fmt.format(ingresado)
                            : null;
                        return SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: guardando ? null : _abonar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kTeal,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade200,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: guardando
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.payments_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        montoDisplay != null
                                            ? 'Registrar $montoDisplay'
                                            : 'Registrar abono',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tarjeta de cliente con progreso ───────────────────────
  Widget _clienteCard(Separado sep, NumberFormat fmtInt) {
    final progreso = sep.progreso.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kTeal, _kTealMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _kTeal.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Nombre + badge
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                sep.clienteNombre.isNotEmpty
                    ? sep.clienteNombre[0].toUpperCase() : '?',
                style: GoogleFonts.inter(fontSize: 17,
                    fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(sep.clienteNombre,
                  style: GoogleFonts.inter(fontSize: 14,
                      fontWeight: FontWeight.w700, color: Colors.white)),
              Text('SEP-${sep.id}  ·  ${sep.tiendaNombre}',
                  style: GoogleFonts.inter(fontSize: 11,
                      color: Colors.white70)),
            ]),
          ),
          // Saldo pendiente destacado
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Pendiente',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white60)),
            Text('\$${fmtInt.format(sep.saldoPendiente)}',
                style: GoogleFonts.inter(fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFD580))),
          ]),
        ]),

        const SizedBox(height: 14),

        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           progreso,
            minHeight:       6,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),

        const SizedBox(height: 12),

        // Stats: total / abonado / pendiente
        Row(children: [
          _stat('Total',     '\$${fmtInt.format(sep.total)}',
              Colors.white70, Colors.white),
          _statDiv(),
          _stat('Abonado',   '\$${fmtInt.format(sep.abonoAcumulado)}',
              Colors.white70, const Color(0xFF86EFAC)),
          _statDiv(),
          _stat('Pendiente', '\$${fmtInt.format(sep.saldoPendiente)}',
              Colors.white70, const Color(0xFFFFD580)),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String valor, Color labelColor, Color valorColor) =>
      Expanded(
        child: Column(children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: labelColor)),
          const SizedBox(height: 2),
          Text(valor,
              style: GoogleFonts.inter(fontSize: 12,
                  fontWeight: FontWeight.w700, color: valorColor)),
        ]),
      );

  Widget _statDiv() => Container(
      width: 1, height: 24,
      color: Colors.white.withValues(alpha: 0.2));

  Widget _dialogRow(String label, String valor, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 13, color: _kMuted)),
      Text(valor,  style: GoogleFonts.inter(fontSize: 15,
          fontWeight: FontWeight.w700, color: color)),
    ],
  );
}
