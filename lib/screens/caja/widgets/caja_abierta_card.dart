import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/caja_provider.dart';
import 'caja_helpers.dart';

class CajaAbiertaCard extends StatelessWidget {
  final CajaProvider caja;
  final VoidCallback onCerrarCaja;

  const CajaAbiertaCard({
    super.key,
    required this.caja,
    required this.onCerrarCaja,
  });

  @override
  Widget build(BuildContext context) {
    final sesion = caja.sesionActiva!;
    final fmt    = NumberFormat('#,##0', 'en_US');

    return Center(
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Banner verde
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.lock_open_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Caja abierta',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text('Sesión #${sesion.id} activa',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(sesion.estado.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ]),
              const SizedBox(height: 20),

              // Stat saldo inicial
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Saldo inicial',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('\$${fmt.format(sesion.saldo_inicial)}',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Apertura',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        sesion.fecha_apertura
                            .toLocal().toString().substring(0, 16),
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),

          // Info + botón cerrar
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              buildInfoRow('Sesión ID',     '#${sesion.id}'),
              buildInfoRow('Estado',        sesion.estado.toUpperCase()),
              buildInfoRow('Saldo inicial',
                  '\$${sesion.saldo_inicial.toStringAsFixed(0)}'),
              buildInfoRow('Apertura',
                  sesion.fecha_apertura.toLocal().toString().substring(0, 16)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: buildGradientButton(
                  label: caja.procesando ? 'Cargando...' : 'Cerrar Caja',
                  icon: caja.procesando
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_rounded, size: 20),
                  colors:      [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                  shadowColor: const Color(0xFFEF4444),
                  onPressed: caja.procesando ? null : onCerrarCaja,
                ),
              ),
            ]),
          ),

        ]),
      ),
    );
  }
}