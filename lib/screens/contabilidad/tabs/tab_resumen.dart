import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/range_picker.dart';

import '../../../providers/contabilidad_provider.dart';
import 'tab_resumen_dia.dart';
import 'tab_mensual.dart';
import 'tab_anual.dart';
import 'tab_rango.dart';

enum _Vista { hoy, semana, mes, anio, rango }

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
  _Vista   _vista     = _Vista.hoy;
  int      _anioMes   = DateTime.now().year;
  int      _mesSel    = DateTime.now().month;
  int      _anioAnual = DateTime.now().year;
  DateTime _rangoIni  = _inicioSemanaActual();
  DateTime _rangoFin  = DateTime.now();

  static DateTime _inicioSemanaActual() {
    final hoy = DateTime.now();
    return hoy.subtract(Duration(days: hoy.weekday - 1));
  }

  static const _meses = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

  void _switchVista(_Vista v) async {
    if (v == _Vista.rango) {
      final range = await showDateRangePicker(
        context:          context,
        initialDateRange: DateTimeRange(start: _rangoIni, end: _rangoFin),
        firstDate:        DateTime(DateTime.now().year - 2),
        lastDate:         DateTime.now(),
        locale:           const Locale('es', 'CO'),
        builder: (ctx, child) => rangePickerDialog(ctx, child!),
      );
      if (range == null) return;
      setState(() {
        _rangoIni = range.start;
        _rangoFin = range.end;
        _vista    = _Vista.rango;
      });
      _cargarRango();
      return;
    }
    if (v == _Vista.semana) {
      setState(() {
        _rangoIni = _inicioSemanaActual();
        _rangoFin = DateTime.now();
        _vista    = _Vista.semana;
      });
      _cargarRango();
      return;
    }
    if (_vista == v) return;
    setState(() => _vista = v);
    _recargarVista(v);
  }

  void _cargarRango() {
    final ini = '${_rangoIni.year}-'
                '${_rangoIni.month.toString().padLeft(2, '0')}-'
                '${_rangoIni.day.toString().padLeft(2, '0')}';
    final fin = '${_rangoFin.year}-'
                '${_rangoFin.month.toString().padLeft(2, '0')}-'
                '${_rangoFin.day.toString().padLeft(2, '0')}';
    widget.cont.cargarResumenRango(
        fechaIni: ini, fechaFin: fin, tiendaId: widget.tiendaId);
  }

  void _recargarVista(_Vista v) {
    switch (v) {
      case _Vista.hoy:
        widget.cont.cargarResumenDiario(tiendaId: widget.tiendaId);
      case _Vista.semana:
      case _Vista.rango:
        _cargarRango();
      case _Vista.mes:
        widget.cont.cargarResumenMensual(
            tiendaId: widget.tiendaId, anio: _anioMes, mes: _mesSel);
      case _Vista.anio:
        widget.cont.cargarResumenAnual(
            tiendaId: widget.tiendaId, anio: _anioAnual);
    }
  }

  @override
  void didUpdateWidget(TabResumen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tiendaId != widget.tiendaId) {
      _recargarVista(_vista);
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
        _chip('Hoy',       Icons.today_rounded,          _Vista.hoy),
        const SizedBox(width: 8),
        _chip('Semana',    Icons.view_week_rounded,      _Vista.semana),
        const SizedBox(width: 8),
        _chip('Este mes',  Icons.calendar_month_rounded, _Vista.mes),
        const SizedBox(width: 8),
        _chip('Este año',  Icons.bar_chart_rounded,      _Vista.anio),
        const SizedBox(width: 8),
        _chip('Rango',     Icons.date_range_rounded,     _Vista.rango),
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
          color: sel ? AppColors.secondary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: sel ? Colors.white : AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.onSurfaceVariant)),
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
      case _Vista.semana:
      case _Vista.rango:
        return TabRango(
          cont:     widget.cont,
          fmt:      widget.fmt,
          tiendaId: widget.tiendaId,
          fechaIni: _rangoIni,
          fechaFin: _rangoFin,
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
