// lib/screens/devoluciones/devoluciones_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pos_multitienda_app/providers/auth_provider.dart';
import 'package:pos_multitienda_app/providers/devoluciones_provider.dart';
import 'package:pos_multitienda_app/core/constants.dart';
import 'package:pos_multitienda_app/screens/devoluciones/tabs/tab_devoluciones.dart';


class DevolucionesScreen extends StatefulWidget {
  const DevolucionesScreen({super.key});

  @override
  State<DevolucionesScreen> createState() => _DevolucionesScreenState();
}

class _DevolucionesScreenState extends State<DevolucionesScreen> {
  // ✅ El provider se crea UNA sola vez y vive con el State
  late final DevolucionesProvider _devolucionesProvider;
  late final AuthProvider         _auth;
  late final NumberFormat         _fmt;
  late final int?                 _tiendaId;
  late final bool                 _esCajero;

  @override
  void initState() {
    super.initState();
    _devolucionesProvider = DevolucionesProvider();
    _auth     = context.read<AuthProvider>();
    _fmt      = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    _tiendaId = _auth.tiendaId;
    _esCajero = _auth.rol == 'cajero';
  }

  @override
  void dispose() {
    _devolucionesProvider.dispose(); // ✅ limpia al salir de la pantalla
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      // ✅ .value porque ya existe la instancia, no la crea de nuevo
      value: _devolucionesProvider,
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
            fmt:      _fmt,
            tiendaId: _tiendaId,
            esCajero: _esCajero,
            auth:     _auth,
          ),
        ),
      ),
    );
  }
}