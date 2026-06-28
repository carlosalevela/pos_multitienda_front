import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../providers/contabilidad_provider.dart';
import 'export_guard.dart';

enum _PeriodoFlujo { semana, mes, custom }

class TabFlujoCaja extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;

  const TabFlujoCaja({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
  });

  @override
  State<TabFlujoCaja> createState() => _TabFlujoCajaState();
}

class _TabFlujoCajaState extends State<TabFlujoCaja> {
  _PeriodoFlujo _periodo   = _PeriodoFlujo.mes;
  DateTime      _customIni = DateTime.now().subtract(const Duration(days: 30));
  DateTime      _customFin = DateTime.now();

  static const _primary = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  (String, String) _rango() {
    final now = DateTime.now();
    switch (_periodo) {
      case _PeriodoFlujo.semana:
        final ini = now.subtract(Duration(days: now.weekday - 1));
        return (_s(ini), _s(now));
      case _PeriodoFlujo.mes:
        return (_s(DateTime(now.year, now.month, 1)), _s(now));
      case _PeriodoFlujo.custom:
        return (_s(_customIni), _s(_customFin));
    }
  }

  String _s(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _cargar() {
    final (ini, fin) = _rango();
    widget.cont.cargarFlujoCaja(
      fechaIni: ini,
      fechaFin: fin,
      tiendaId: widget.tiendaId,
    );
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cont  = widget.cont;
    final flujo = cont.flujoCaja;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filtros(),
        const SizedBox(height: 12),

        if (cont.cargandoFlujo)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (flujo == null)
          _vacio()
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _resumenKpis(),
                  const SizedBox(height: 16),
                  _sesionesCard(),
                  const SizedBox(height: 16),
                  _exportRow(cont),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Filtros ──────────────────────────────────────────

  Widget _filtros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('Esta semana', _PeriodoFlujo.semana),
        const SizedBox(width: 8),
        _chip('Este mes',    _PeriodoFlujo.mes),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _elegirCustom,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _periodo == _PeriodoFlujo.custom
                  ? _primary
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.date_range_rounded,
                  size: 14,
                  color: _periodo == _PeriodoFlujo.custom
                      ? Colors.white
                      : Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                _periodo == _PeriodoFlujo.custom
                    ? '${DateFormat('dd/MM/yy').format(_customIni)} – '
                      '${DateFormat('dd/MM/yy').format(_customFin)}'
                    : 'Personalizado',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _periodo == _PeriodoFlujo.custom
                        ? Colors.white
                        : Colors.grey.shade700),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, _PeriodoFlujo p) {
    final sel = _periodo == p;
    return GestureDetector(
      onTap: () {
        setState(() => _periodo = p);
        _cargar();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }

  // ── KPI resumen ──────────────────────────────────────

  Widget _resumenKpis() {
    final r = widget.cont.flujoCaja!;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpi('Total entradas',    r.totalEntradas,    Colors.green.shade600,
            Icons.arrow_downward_rounded),
        _kpi('Total salidas',     r.totalSalidas,     Colors.red.shade600,
            Icons.arrow_upward_rounded),
        _kpi('Flujo neto',        r.flujoNeto,
            r.flujoNeto >= 0 ? const Color(0xFF10B981) : Colors.red.shade600,
            Icons.account_balance_rounded),
        _kpi('Diferencia cierre', r.totalDiferencias,
            r.totalDiferencias < 0 ? Colors.red.shade600 : Colors.green.shade600,
            Icons.compare_arrows_rounded,
            sesiones: r.numSesiones),
      ],
    );
  }

  Widget _kpi(String label, double valor, Color color, IconData icon,
      {int? sesiones}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 10),
        Text(
          '${valor < 0 ? '-' : ''}\$${widget.fmt.format(valor.abs())}',
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color),
        ),
        const SizedBox(height: 2),
        Text(
          sesiones != null ? '$label  •  $sesiones sesiones' : label,
          style: GoogleFonts.poppins(
              fontSize: 11, color: Colors.grey.shade500),
        ),
      ]),
    );
  }

  // ── Tabla de sesiones ────────────────────────────────

  Widget _sesionesCard() {
    final sesiones = widget.cont.flujoCaja!.sesiones;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                size: 16, color: _primary),
          ),
          const SizedBox(width: 10),
          Text('Sesiones de Caja',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: const Color(0xFF1A1A2E))),
          const Spacer(),
          Text('${sesiones.length} registros',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 14),

        if (sesiones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Sin sesiones en el período',
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade400)),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 48,
              columnSpacing: 20,
              headingTextStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600),
              dataTextStyle: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF1A1A2E)),
              columns: const [
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Tienda')),
                DataColumn(label: Text('Cajero')),
                DataColumn(label: Text('Entradas'),   numeric: true),
                DataColumn(label: Text('Salidas'),    numeric: true),
                DataColumn(label: Text('Flujo'),      numeric: true),
                DataColumn(label: Text('Diferencia'), numeric: true),
                DataColumn(label: Text('Estado')),
              ],
              rows: sesiones.map((s) {
                final entradas   = (s['entradas']  as Map)['total'] as num? ?? 0;
                final salidas    = (s['salidas']   as Map)['total'] as num? ?? 0;
                final flujo      = (s['flujo_sesion']  as num?) ?? 0;
                final diferencia = s['diferencia'] as num?;
                final estado     = s['estado']?.toString() ?? '';

                return DataRow(cells: [
                  DataCell(Text(s['fecha']?.toString() ?? '')),
                  DataCell(Text(s['tienda_nombre']?.toString() ?? '',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600))),
                  DataCell(Text(s['empleado']?.toString() ?? '–')),
                  DataCell(Text('\$${widget.fmt.format(entradas)}',
                      style: GoogleFonts.poppins(
                          color: Colors.green.shade700))),
                  DataCell(Text('\$${widget.fmt.format(salidas)}',
                      style: GoogleFonts.poppins(
                          color: Colors.red.shade600))),
                  DataCell(Text(
                    '${flujo < 0 ? '-' : ''}\$${widget.fmt.format(flujo.abs())}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: flujo >= 0
                            ? const Color(0xFF10B981)
                            : Colors.red.shade600),
                  )),
                  DataCell(
                    diferencia == null
                        ? Text('–',
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade400))
                        : Text(
                            '${diferencia < 0 ? '-' : '+'}\$${widget.fmt.format(diferencia.abs())}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: diferencia < 0
                                    ? Colors.red.shade600
                                    : Colors.green.shade700),
                          ),
                  ),
                  DataCell(_estadoChip(estado)),
                ]);
              }).toList(),
            ),
          ),
      ]),
    );
  }

  Widget _estadoChip(String estado) {
    final cerrada = estado == 'cerrada';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (cerrada ? Colors.grey : Colors.green)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (cerrada ? Colors.grey : Colors.green)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        cerrada ? 'Cerrada' : 'Abierta',
        style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cerrada
                ? Colors.grey.shade600
                : Colors.green.shade700),
      ),
    );
  }

  // ── Exportar ─────────────────────────────────────────

  Widget _exportRow(ContabilidadProvider cont) {
    final (ini, fin) = _rango();
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      ElevatedButton.icon(
        onPressed: cont.exportando
            ? null
            : () async {
                final ok = await verificarReporteAntesDe(
                  context, tiendaId: widget.tiendaId);
                if (!ok || !mounted) return;
                await cont.exportarExcel(
                  tipo:     'flujo-caja',
                  fechaIni: ini,
                  fechaFin: fin,
                  tiendaId: widget.tiendaId,
                );
              },
        icon: cont.exportando
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.download_rounded, size: 18),
        label: Text('Exportar Flujo',
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    ]);
  }

  // ── Vacío ─────────────────────────────────────────────

  Widget _vacio() => Expanded(
    child: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_balance_wallet_rounded,
            size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Sin sesiones en el período',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 15)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _cargar,
          child: Text('Reintentar',
              style: GoogleFonts.poppins(
                  color: _primary, fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );

  // ── Selector de rango custom ──────────────────────────

  Future<void> _elegirCustom() async {
    DateTime? ini = _customIni;
    DateTime? fin = _customFin;
    bool selIni   = true;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: StatefulBuilder(
          builder: (ctx, setL) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.date_range_rounded,
                      color: _primary, size: 18),
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
              Row(children: [
                Expanded(child: _fechaBox(
                  label:  'Desde',
                  valor:  ini != null
                      ? DateFormat('dd/MM/yyyy').format(ini!)
                      : 'Selecciona',
                  activo: selIni,
                  onTap:  () => setL(() => selIni = true),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.grey.shade400),
                ),
                Expanded(child: _fechaBox(
                  label:  'Hasta',
                  valor:  fin != null
                      ? DateFormat('dd/MM/yyyy').format(fin!)
                      : 'Selecciona',
                  activo: !selIni,
                  onTap:  () => setL(() => selIni = false),
                )),
              ]),
              const SizedBox(height: 8),
              Text(
                selIni ? '👆 Selecciona inicio' : '👆 Selecciona fin',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: _primary),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 270,
                child: CalendarDatePicker(
                  initialDate: selIni
                      ? (ini ?? DateTime.now())
                      : (fin ?? ini ?? DateTime.now()),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  onDateChanged: (d) {
                    setL(() {
                      if (selIni) {
                        ini = d;
                        if (fin != null && fin!.isBefore(d)) fin = null;
                        selIni = false;
                      } else {
                        if (ini != null && d.isBefore(ini!)) {
                          ini = d; fin = null;
                        } else {
                          fin = d;
                        }
                      }
                    });
                  },
                ),
              ),
              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar',
                      style: GoogleFonts.poppins(
                          color: Colors.grey.shade600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: ini != null && fin != null
                      ? () {
                          setState(() {
                            _customIni = ini!;
                            _customFin = fin!;
                            _periodo   = _PeriodoFlujo.custom;
                          });
                          Navigator.pop(ctx);
                          _cargar();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Aplicar',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _fechaBox({
    required String label,
    required String valor,
    required bool activo,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: activo
                ? _primary.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo ? _primary : Colors.grey.shade200,
              width: activo ? 1.5 : 1,
            ),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: activo ? _primary : Colors.grey.shade500)),
                Text(valor,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: activo ? _primary : const Color(0xFF1A1A2E))),
              ]),
        ),
      );
}
