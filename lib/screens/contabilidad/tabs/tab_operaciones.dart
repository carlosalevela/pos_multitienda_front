import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../providers/contabilidad_provider.dart';
import '../../../providers/auth_provider.dart';
import 'tab_gastos.dart';
import 'tab_flujo_caja.dart';

enum _Vista { gastos, flujo }

class TabOperaciones extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;
  final bool                 esCajero;
  final AuthProvider         auth;

  const TabOperaciones({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.esCajero,
    required this.auth,
  });

  @override
  State<TabOperaciones> createState() => _TabOperacionesState();
}

class _TabOperacionesState extends State<TabOperaciones> {
  _Vista _vista    = _Vista.gastos;
  final Key _gastosKey = UniqueKey();

  static const _primary = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.esCajero) ...[
          _toggle(),
          const SizedBox(height: 14),
        ],
        Expanded(child: _body()),
      ],
    );
  }

  Widget _toggle() {
    return Row(children: [
      _chip('Gastos',        Icons.receipt_long_rounded,            _Vista.gastos),
      const SizedBox(width: 8),
      _chip('Flujo de Caja', Icons.account_balance_wallet_rounded,  _Vista.flujo),
    ]);
  }

  Widget _chip(String label, IconData icon, _Vista v) {
    final sel = _vista == v;
    return GestureDetector(
      onTap: () => setState(() => _vista = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: sel ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : Colors.grey.shade700)),
        ]),
      ),
    );
  }

  Widget _body() {
    switch (_vista) {
      case _Vista.gastos:
        return TabGastos(
          key:      _gastosKey,
          cont:     widget.cont,
          fmt:      widget.fmt,
          tiendaId: widget.tiendaId,
          esCajero: widget.esCajero,
          auth:     widget.auth,
        );
      case _Vista.flujo:
        return TabFlujoCaja(
          cont:     widget.cont,
          fmt:      widget.fmt,
          tiendaId: widget.tiendaId,
        );
    }
  }
}
