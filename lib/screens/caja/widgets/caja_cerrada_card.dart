import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/caja_provider.dart';
import '../../../providers/auth_provider.dart';
import 'caja_helpers.dart';

class CajaCerradaCard extends StatelessWidget {
  final CajaProvider          caja;
  final AuthProvider          auth;
  final TextEditingController saldoCtrl;

  const CajaCerradaCard({
    super.key,
    required this.caja,
    required this.auth,
    required this.saldoCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withOpacity(0.12),
                  const Color(0xFFFEF3C7),
                ],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.35),
                    blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    size: 36, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text('Caja cerrada',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(
                'Ingresa el saldo inicial para comenzar el turno',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8), fontSize: 13)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              buildInputField(
                controller:      saldoCtrl,
                label:           'Saldo inicial',
                prefixText:      '\$ ',
                keyboardType:    TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                accentColor:     const Color(0xFF10B981),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: buildGradientButton(
                  label: caja.procesando ? 'Abriendo...' : 'Abrir Caja',
                  icon: caja.procesando
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_open_rounded, size: 20),
                  colors:      [const Color(0xFF10B981), const Color(0xFF059669)],
                  shadowColor: const Color(0xFF10B981),
                  onPressed: caja.procesando ? null : () =>
                      caja.abrirCaja(
                        tiendaId:     auth.tiendaId,
                        saldoInicial: double.tryParse(saldoCtrl.text) ?? 0),
                ),
              ),
            ]),
          ),

        ]),
      ),
    );
  }
}