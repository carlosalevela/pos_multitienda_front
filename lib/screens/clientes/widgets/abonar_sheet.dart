import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/separado.dart';
import '../../../providers/cliente_provider.dart';

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

  // ── Lanzador estático ──────────────────────────────────
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
      builder: (_) => AbonarSheet(
        separado:  separado,
        fmt:       fmt,
        onAbonado: onAbonado,
      ),
    );
  }

  @override
  State<AbonarSheet> createState() => _AbonarSheetState();
}

class _AbonarSheetState extends State<AbonarSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();

  String _metodoPago = 'efectivo';

  static const _metodos = [
    ('efectivo',      'Efectivo',     Icons.payments_outlined),
    ('transferencia', 'Transferencia',Icons.swap_horiz_rounded),
    ('tarjeta',       'Tarjeta',      Icons.credit_card_outlined),
  ];

  double get _saldo => widget.separado.saldoPendiente;

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  // ── Pagar todo de una vez ──────────────────────────────
  void _pagarTodo() {
    _montoCtrl.text = _saldo.toStringAsFixed(0);
    setState(() {});
  }

  // ── Registrar abono ────────────────────────────────────
  Future<void> _abonar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0;
    final prov  = context.read<ClienteProvider>();

    final ok = await prov.abonarSeparado(
      widget.separado.id,
      monto,
      _metodoPago,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      widget.onAbonado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Abono de ${widget.fmt.format(monto)} registrado ✅',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF437A22),
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prov.error ?? 'Error al registrar abono',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.red.shade600,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Resumen de deuda ───────────────────────────────────
  Widget _resumenDeuda() {
    final sep = widget.separado;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4D1CA)),
      ),
      child: Column(
        children: [
          // Nombre cliente
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 16, color: Color(0xFF7A7974)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sep.clienteNombre,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF28251D),
                  ),
                ),
              ),
              // Badge SEP-id
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFCEDCD8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'SEP-${sep.id}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF01696F),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           sep.progreso,
              minHeight:       8,
              backgroundColor: const Color(0xFFDCD9D5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF01696F)),
            ),
          ),

          const SizedBox(height: 10),

          // Total / abonado / saldo
          Row(
            children: [
              _statItem('Total',    widget.fmt.format(sep.total),
                  const Color(0xFF28251D)),
              _divider(),
              _statItem('Abonado',  widget.fmt.format(sep.abonoAcumulado),
                  const Color(0xFF437A22)),
              _divider(),
              _statItem('Pendiente', widget.fmt.format(sep.saldoPendiente),
                  const Color(0xFFA12C7B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String valor, Color color) =>
      Expanded(
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: const Color(0xFF7A7974))),
            const SizedBox(height: 2),
            Text(valor,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1, height: 28,
        color: const Color(0xFFD4D1CA),
      );

  // ── Selector método de pago ────────────────────────────
  Widget _selectorMetodo() {
    return Row(
      children: _metodos.map((m) {
        final (value, label, icono) = m;
        final sel = _metodoPago == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _metodoPago = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(
                  right: value != 'tarjeta' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel
                    ? const Color(0xFF01696F)
                    : const Color(0xFFF9F8F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel
                      ? const Color(0xFF01696F)
                      : const Color(0xFFD4D1CA),
                ),
              ),
              child: Column(
                children: [
                  Icon(icono,
                      size: 18,
                      color: sel ? Colors.white : const Color(0xFF7A7974)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : const Color(0xFF7A7974),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
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

              // ── Handle ───────────────────────────────────
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Título ───────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01696F).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_rounded,
                        color: Color(0xFF01696F), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Registrar abono',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF28251D),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Resumen deuda ────────────────────────────
              _resumenDeuda(),

              const SizedBox(height: 20),

              // ── Método de pago ───────────────────────────
              Text(
                'Método de pago',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7A7974),
                ),
              ),
              const SizedBox(height: 8),
              _selectorMetodo(),

              const SizedBox(height: 20),

              // ── Monto ────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Monto a abonar',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7A7974),
                    ),
                  ),
                  const Spacer(),
                  // Botón pagar todo
                  GestureDetector(
                    onTap: _pagarTodo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCEDCD8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Pagar todo',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF01696F),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller:   _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF28251D),
                ),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF01696F),
                  ),
                  hintText:  '0',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFBAB9B4),
                  ),
                  filled:    true,
                  fillColor: const Color(0xFFF9F8F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFD4D1CA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFD4D1CA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFF01696F), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.red.shade400, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa un monto';
                  }
                  final monto = double.tryParse(v.trim());
                  if (monto == null || monto <= 0) {
                    return 'El monto debe ser mayor a 0';
                  }
                  if (monto > _saldo) {
                    return 'Excede el saldo pendiente '
                        '(${widget.fmt.format(_saldo)})';
                  }
                  return null;
                },
              ),

              // ── Vista previa nuevo saldo ─────────────────
              if (_montoCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                _vistaPreviaSaldo(),
              ],

              const SizedBox(height: 24),

              // ── Botón registrar ──────────────────────────
              Selector<ClienteProvider, bool>(
                selector: (_, p) => p.guardando,
                builder: (_, guardando, __) => SizedBox(
                  width:  double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: guardando ? null : _abonar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF01696F),
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
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'Registrar abono',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  // ── Vista previa del nuevo saldo ───────────────────────
  Widget _vistaPreviaSaldo() {
    final ingresado = double.tryParse(_montoCtrl.text.trim()) ?? 0;
    final nuevoSaldo = (_saldo - ingresado).clamp(0.0, double.infinity);
    final saldado    = nuevoSaldo == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: saldado
            ? const Color(0xFFD4DFCC)
            : const Color(0xFFF9F8F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: saldado
              ? const Color(0xFF437A22).withOpacity(0.3)
              : const Color(0xFFD4D1CA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            saldado
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: saldado
                ? const Color(0xFF437A22)
                : const Color(0xFF7A7974),
          ),
          const SizedBox(width: 8),
          Text(
            saldado
                ? '¡Separado completamente pagado! 🎉'
                : 'Nuevo saldo: ${widget.fmt.format(nuevoSaldo)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: saldado
                  ? const Color(0xFF437A22)
                  : const Color(0xFF7A7974),
            ),
          ),
        ],
      ),
    );
  }
}