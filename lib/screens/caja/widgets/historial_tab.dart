import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/caja_provider.dart';
import '../../../providers/auth_provider.dart';
import 'caja_helpers.dart';
import 'historial_card.dart';
import 'detalle_cierre_sheet.dart';

class HistorialTab extends StatelessWidget {
  const HistorialTab({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = context.watch<CajaProvider>();

    if (caja.cargando) {
      return buildLoadingState(mensaje: 'Cargando historial…');
    }

    if (caja.historial.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.history_rounded,
                size: 36, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 16),
          Text('Sin cierres registrados',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569))),
          const SizedBox(height: 6),
          Text('Los cierres de caja aparecerán aquí',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: const Color(0xFF94A3B8))),
        ]),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6366F1),
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        await context.read<CajaProvider>()
            .cargarHistorial(tiendaId: auth.tiendaId);
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: caja.historial.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final sesion = caja.historial[i];
          return HistorialCard(
            sesion: sesion,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => DetalleCierreSheet(sesion: sesion),
            ),
          );
        },
      ),
    );
  }
}