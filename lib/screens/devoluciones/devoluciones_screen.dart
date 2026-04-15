// lib/screens/devoluciones/devoluciones_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pos_multitienda_app/providers/auth_provider.dart';
import 'package:pos_multitienda_app/providers/devoluciones_provider.dart';
import 'package:pos_multitienda_app/core/constants.dart';
import 'package:pos_multitienda_app/screens/devoluciones/tabs/tab_devoluciones.dart';

class DevolucionesScreen extends StatelessWidget {       // ✅ FIX #2: StatelessWidget
  const DevolucionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth     = context.read<AuthProvider>();
    // ✅ FIX #1: sin symbol — es_CO ya usa '$'
    final fmt      = NumberFormat.currency(locale: 'es_CO', symbol: r'$');
    final tiendaId = auth.tiendaId;
    final esCajero = auth.rol == 'cajero';

    return ChangeNotifierProvider(
      // ✅ FIX #2: create en lugar de .value — Provider gestiona el ciclo de vida
      create: (_) => DevolucionesProvider(),
      child: Scaffold(
        backgroundColor: const Color(Constants.backgroundColor),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'Devoluciones',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xFF1A1A2E)),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TabDevoluciones(
            fmt:      fmt,
            tiendaId: tiendaId,
            esCajero: esCajero,
            auth:     auth,
          ),
        ),
      ),
    );
  }
}