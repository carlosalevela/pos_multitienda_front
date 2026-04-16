import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';

enum RangoFecha { hoy, semana, mes, custom }

class FiltrosBar extends StatefulWidget {
  final void Function({
    String? fecha,
    String? fechaIni,
    String? fechaFin,
    String? estado,
  }) onFiltrar;

  const FiltrosBar({super.key, required this.onFiltrar});

  @override
  State<FiltrosBar> createState() => _FiltrosBarState();
}

class _FiltrosBarState extends State<FiltrosBar> {
  RangoFecha _rango     = RangoFecha.hoy;
  String?    _estado;             // null = todos
  DateTime   _customIni = DateTime.now();
  DateTime   _customFin = DateTime.now();

  // ── Aplicar filtro ────────────────────────────────────

  void _aplicar() {
    final now = DateTime.now();
    switch (_rango) {
      case RangoFecha.hoy:
        widget.onFiltrar(fecha: _strFecha(now), estado: _estado);
      case RangoFecha.semana:
        final ini = now.subtract(Duration(days: now.weekday - 1));
        widget.onFiltrar(
            fechaIni: _strFecha(ini),
            fechaFin: _strFecha(now),
            estado:   _estado);
      case RangoFecha.mes:
        final ini = DateTime(now.year, now.month, 1);
        widget.onFiltrar(
            fechaIni: _strFecha(ini),
            fechaFin: _strFecha(now),
            estado:   _estado);
      case RangoFecha.custom:
        widget.onFiltrar(
            fechaIni: _strFecha(_customIni),
            fechaFin: _strFecha(_customFin),
            estado:   _estado);
    }
  }

  String _strFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  // ── Rango custom ──────────────────────────────────────

  Future<void> _elegirRangoCustom() async {
    DateTime inicioTemp = _customIni;
    DateTime finTemp    = _customFin;
    bool seleccionandoInicio = true;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 32, vertical: 40),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Título
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(Constants.primaryColor)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.date_range_rounded,
                        color: Color(Constants.primaryColor), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Rango personalizado',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: Colors.grey.shade400),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
                const SizedBox(height: 14),

                // Selectores desde / hasta
                Row(children: [
                  Expanded(child: _FechaBox(
                    label:  'Desde',
                    valor:  DateFormat('dd/MM/yyyy').format(inicioTemp),
                    activo: seleccionandoInicio,
                    onTap:  () => setLocal(() => seleccionandoInicio = true),
                  )),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Colors.grey.shade400),
                  ),
                  Expanded(child: _FechaBox(
                    label:  'Hasta',
                    valor:  DateFormat('dd/MM/yyyy').format(finTemp),
                    activo: !seleccionandoInicio,
                    onTap:  () => setLocal(() => seleccionandoInicio = false),
                  )),
                ]),
                const SizedBox(height: 4),
                Text(
                  seleccionandoInicio
                      ? '👆 Toca la fecha de inicio'
                      : '👆 Toca la fecha de fin',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(Constants.primaryColor)),
                ),
                const SizedBox(height: 8),

                // Calendario
                SizedBox(
                  height: 270,
                  child: CalendarDatePicker(
                    initialDate: seleccionandoInicio
                        ? inicioTemp
                        : finTemp,
                    firstDate: DateTime(2024),
                    lastDate:  DateTime.now(),
                    onDateChanged: (date) => setLocal(() {
                      if (seleccionandoInicio) {
                        inicioTemp = date;
                        if (finTemp.isBefore(date)) finTemp = date;
                        seleccionandoInicio = false;
                      } else {
                        if (date.isBefore(inicioTemp)) {
                          inicioTemp = date;
                          finTemp    = date;
                        } else {
                          finTemp = date;
                        }
                      }
                    }),
                  ),
                ),
                const Divider(height: 20),

                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancelar',
                          style: GoogleFonts.poppins(
                              color: Colors.grey.shade600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _customIni = inicioTemp;
                          _customFin = finTemp;
                          _rango     = RangoFecha.custom;
                        });
                        Navigator.pop(ctx);
                        _aplicar();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(Constants.primaryColor),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Aplicar',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipsRango(),
        const SizedBox(height: 10),
        _dropdownEstado(),
      ],
    );
  }

  // ── Chips de rango ────────────────────────────────────

  Widget _chipsRango() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _ChipRango(
          label: 'Hoy',
          seleccionado: _rango == RangoFecha.hoy,
          onTap: () {
            setState(() => _rango = RangoFecha.hoy);
            _aplicar();
          },
        ),
        const SizedBox(width: 8),
        _ChipRango(
          label: 'Semana',
          seleccionado: _rango == RangoFecha.semana,
          onTap: () {
            setState(() => _rango = RangoFecha.semana);
            _aplicar();
          },
        ),
        const SizedBox(width: 8),
        _ChipRango(
          label: 'Mes',
          seleccionado: _rango == RangoFecha.mes,
          onTap: () {
            setState(() => _rango = RangoFecha.mes);
            _aplicar();
          },
        ),
        const SizedBox(width: 8),
        _ChipRango(
          label: 'Personalizado',
          seleccionado: _rango == RangoFecha.custom,
          icono: Icons.date_range_rounded,
          onTap: _elegirRangoCustom,
        ),
      ]),
    );
  }

  // ── Dropdown estado ───────────────────────────────────

  Widget _dropdownEstado() {
    return SizedBox(
      height: 38,
      child: DropdownButtonFormField<String?>(
        value: _estado,
        isDense: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          filled:    true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
        hint: Text('Todos los estados',
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade500)),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('Todos los estados',
                style: GoogleFonts.poppins(fontSize: 12)),
          ),
          DropdownMenuItem<String?>(
            value: 'procesada',
            child: Text('Procesadas',
                style: GoogleFonts.poppins(fontSize: 12)),
          ),
          DropdownMenuItem<String?>(
            value: 'cancelada',
            child: Text('Canceladas',
                style: GoogleFonts.poppins(fontSize: 12)),
          ),
        ],
        onChanged: (v) {
          setState(() => _estado = v);
          _aplicar();
        },
      ),
    );
  }

  // ── Título del rango (para usar en la screen) ─────────

  static String tituloRango(
    RangoFecha rango,
    DateTime customIni,
    DateTime customFin,
  ) {
    switch (rango) {
      case RangoFecha.hoy:    return 'Devoluciones de hoy';
      case RangoFecha.semana: return 'Devoluciones de esta semana';
      case RangoFecha.mes:    return 'Devoluciones de este mes';
      case RangoFecha.custom:
        return 'Del ${DateFormat('dd/MM').format(customIni)} '
               'al ${DateFormat('dd/MM').format(customFin)}';
    }
  }
}


// ── Subwidgets privados ───────────────────────────────────────

class _ChipRango extends StatelessWidget {
  final String     label;
  final bool       seleccionado;
  final IconData?  icono;
  final VoidCallback onTap;

  const _ChipRango({
    required this.label,
    required this.seleccionado,
    required this.onTap,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: seleccionado
              ? const Color(Constants.primaryColor)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icono != null) ...[
            Icon(icono,
                size: 14,
                color: seleccionado
                    ? Colors.white
                    : Colors.grey.shade600),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: seleccionado
                      ? Colors.white
                      : Colors.grey.shade700)),
        ]),
      ),
    );
  }
}


class _FechaBox extends StatelessWidget {
  final String       label;
  final String       valor;
  final bool         activo;
  final VoidCallback onTap;

  const _FechaBox({
    required this.label,
    required this.valor,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo
              ? const Color(Constants.primaryColor).withOpacity(0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade200,
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: activo
                        ? const Color(Constants.primaryColor)
                        : Colors.grey.shade500)),
            Text(valor,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: activo
                        ? const Color(Constants.primaryColor)
                        : const Color(0xFF1A1A2E))),
          ],
        ),
      ),
    );
  }
}