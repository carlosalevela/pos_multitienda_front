import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../providers/contabilidad_provider.dart';
import 'tab_resumen_dia.dart';
import 'tab_mensual.dart';
import 'tab_anual.dart';

enum _Vista { hoy, mes, anio }

class TabResumen extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;
  final bool                 esCajero;

  const TabResumen({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.esCajero,
  });

  @override
  State<TabResumen> createState() => _TabResumenState();
}

class _TabResumenState extends State<TabResumen> {
  _Vista _vista    = _Vista.hoy;
  int    _anioMes  = DateTime.now().year;
  int    _mesSel   = DateTime.now().month;
  int    _anioAnual = DateTime.now().year;

  static const _primary = Color(0xFF10B981);
  static const _meses   = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

  void _switchVista(_Vista v) {
    if (_vista == v) return;
    setState(() => _vista = v);
    switch (v) {
      case _Vista.mes:
        widget.cont.cargarResumenMensual(
            tiendaId: widget.tiendaId, anio: _anioMes, mes: _mesSel);
      case _Vista.anio:
        widget.cont.cargarResumenAnual(
            tiendaId: widget.tiendaId, anio: _anioAnual);
      case _Vista.hoy:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.esCajero) ...[
          _selector(),
          const SizedBox(height: 14),
        ],
        Expanded(child: _body()),
      ],
    );
  }

  Widget _selector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('Hoy',      Icons.today_rounded,          _Vista.hoy),
        const SizedBox(width: 8),
        _chip('Este mes', Icons.calendar_month_rounded, _Vista.mes),
        const SizedBox(width: 8),
        _chip('Este año', Icons.bar_chart_rounded,      _Vista.anio),
      ]),
    );
  }

  Widget _chip(String label, IconData icon, _Vista v) {
    final sel = _vista == v;
    return GestureDetector(
      onTap: () => _switchVista(v),
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
      case _Vista.hoy:
        return TabResumenDia(
          cont:     widget.cont,
          fmt:      widget.fmt,
          tiendaId: widget.tiendaId,
        );
      case _Vista.mes:
        return TabMensual(
          cont:         widget.cont,
          fmt:          widget.fmt,
          tiendaId:     widget.tiendaId,
          anio:         _anioMes,
          mes:          _mesSel,
          meses:        _meses,
          onCambiarMes: (a, m) {
            setState(() { _anioMes = a; _mesSel = m; });
            widget.cont.cargarResumenMensual(
                tiendaId: widget.tiendaId, anio: a, mes: m);
          },
        );
      case _Vista.anio:
        return TabAnual(
          cont:          widget.cont,
          fmt:           widget.fmt,
          tiendaId:      widget.tiendaId,
          anioSel:       _anioAnual,
          onCambiarAnio: (a) {
            setState(() => _anioAnual = a);
            widget.cont.cargarResumenAnual(
                tiendaId: widget.tiendaId, anio: a);
          },
        );
    }
  }
}
