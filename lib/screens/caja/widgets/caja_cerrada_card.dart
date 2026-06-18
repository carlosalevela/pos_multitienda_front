import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/caja_provider.dart';
import '../../../providers/auth_provider.dart';

class CajaCerradaCard extends StatelessWidget {
  final CajaProvider          caja;
  final AuthProvider          auth;
  final TextEditingController saldoCtrl;
  final VoidCallback?         onCajaAbierta;

  const CajaCerradaCard({
    super.key,
    required this.caja,
    required this.auth,
    required this.saldoCtrl,
    this.onCajaAbierta,
  });

  static const _green          = Color(0xFF006C49);
  static const _greenContainer = Color(0xFF6CF8BB);
  static const _surface        = Color(0xFFFFFFFF);
  static const _border         = Color(0xFFC6C6CD);
  static const _surfaceLow     = Color(0xFFF2F4F6);
  static const _textPrimary    = Color(0xFF191C1E);
  static const _textSecond     = Color(0xFF45464D);
  static const _textFaint      = Color(0xFF76777D);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Cabecera
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: const BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _greenContainer,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.point_of_sale_rounded,
                  size: 32, color: _green),
            ),
            const SizedBox(height: 16),
            Text('Apertura de Caja',
                style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Ingresa el monto inicial para comenzar el turno.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: _textSecond)),
          ]),
        ),

        // Formulario
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            // Label
            Align(
              alignment: Alignment.centerLeft,
              child: Text('MONTO INICIAL / BASE',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _textFaint, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 8),
            // Input
            Container(
              decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.5),
              ),
              child: Row(children: [
                const SizedBox(width: 16),
                Text('\$',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: _textFaint)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: saldoCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 20, color: _border,
                          fontWeight: FontWeight.w700),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 16),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            // Botón Abrir
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: caja.procesando ? null : () async {
                  final ok = await caja.abrirCaja(
                    tiendaId:     auth.tiendaId,
                    saldoInicial: double.tryParse(saldoCtrl.text) ?? 0,
                  );
                  if (ok) onCajaAbierta?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _greenContainer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: caja.procesando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('ABRIR CAJA',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
