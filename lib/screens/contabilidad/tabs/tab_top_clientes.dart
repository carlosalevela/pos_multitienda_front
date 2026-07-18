import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../models/contabilidad_models.dart';
import '../../../services/contabilidad_service.dart';

enum _Periodo { hoy, semana, mes, custom }

class TabTopClientes extends StatefulWidget {
  final NumberFormat fmt;
  final int?         tiendaId;

  const TabTopClientes({
    super.key,
    required this.fmt,
    required this.tiendaId,
  });

  @override
  State<TabTopClientes> createState() => _TabTopClientesState();
}

class _TabTopClientesState extends State<TabTopClientes> {
  _Periodo         _periodo   = _Periodo.mes;
  DateTime         _customIni = DateTime.now().subtract(const Duration(days: 30));
  DateTime         _customFin = DateTime.now();
  List<TopCliente> _clientes  = [];
  bool             _cargando  = false;

  final _svc = ContabilidadService();

  // ── Lifecycle ──────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabTopClientes old) {
    super.didUpdateWidget(old);
    if (old.tiendaId != widget.tiendaId) _cargar();
  }

  // ── Helpers ────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  ({String? fecha, String? ini, String? fin}) _params() {
    final now = DateTime.now();
    switch (_periodo) {
      case _Periodo.hoy:
        return (fecha: _fmtDate(now), ini: null, fin: null);
      case _Periodo.semana:
        final lunes = now.subtract(Duration(days: now.weekday - 1));
        return (fecha: null, ini: _fmtDate(lunes), fin: _fmtDate(now));
      case _Periodo.mes:
        final ini = DateTime(now.year, now.month, 1);
        return (fecha: null, ini: _fmtDate(ini), fin: _fmtDate(now));
      case _Periodo.custom:
        return (fecha: null, ini: _fmtDate(_customIni), fin: _fmtDate(_customFin));
    }
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final p = _params();
    final result = await _svc.getTopClientes(
      tiendaId: widget.tiendaId,
      fecha:    p.fecha,
      fechaIni: p.ini,
      fechaFin: p.fin,
      limite:   20,
    );
    if (mounted) setState(() { _clientes = result; _cargando = false; });
  }

  Future<void> _elegirCustom() async {
    final rango = await showDateRangePicker(
      context:      context,
      firstDate:    DateTime(2020),
      lastDate:     DateTime.now(),
      initialDateRange: DateTimeRange(start: _customIni, end: _customFin),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.secondary),
        ),
        child: child!,
      ),
    );
    if (rango == null) return;
    setState(() {
      _customIni = rango.start;
      _customFin = rango.end;
      _periodo   = _Periodo.custom;
    });
    _cargar();
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 16),
        if (_cargando)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_clientes.isEmpty)
          _sinClientes()
        else
          Expanded(
            child: ListView.builder(
              itemCount: _clientes.length,
              itemBuilder: (_, i) => _clienteCard(_clientes[i], i),
            ),
          ),
      ],
    );
  }

  // ── Header con chips de período ────────────────────────

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.people_alt_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 8),
          Text('Top Clientes',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.onSurface)),
          if (_clientes.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_clientes.length}',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: const Color(0xFF7C3AED))),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('Hoy',    _Periodo.hoy),
            const SizedBox(width: 6),
            _chip('Semana', _Periodo.semana),
            const SizedBox(width: 6),
            _chip('Mes',    _Periodo.mes),
            const SizedBox(width: 6),
            _chipCustom(),
          ]),
        ),
      ],
    );
  }

  Widget _chip(String label, _Periodo p) {
    final sel = _periodo == p;
    return GestureDetector(
      onTap: () {
        if (_periodo == p) return;
        setState(() => _periodo = p);
        _cargar();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.secondary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _chipCustom() {
    final sel = _periodo == _Periodo.custom;
    final label = sel
        ? '${_customIni.day}/${_customIni.month} – ${_customFin.day}/${_customFin.month}'
        : 'Rango';
    return GestureDetector(
      onTap: _elegirCustom,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.secondary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.date_range_rounded,
              size: 12,
              color: sel ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : Colors.grey.shade600)),
        ]),
      ),
    );
  }

  // ── Card de cliente ────────────────────────────────────

  Widget _clienteCard(TopCliente c, int index) {
    final maxTotal = _clientes.first.totalPeriodo;
    final pct      = maxTotal > 0 ? c.totalPeriodo / maxTotal : 0.0;
    final isPodio  = index < 3;

    final iniciales = c.nombre.split(' ')
        .where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final avatarColor = _avatarColor(c.clienteId);

    Color? tierColor;
    if (c.tierColorHex != null) {
      try {
        tierColor = Color(int.parse(c.tierColorHex!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPodio ? _bgPodio(index) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPodio
              ? _colorPodio(index).withValues(alpha: 0.25)
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Posición
          SizedBox(
            width: 32, height: 32,
            child: isPodio
                ? Center(child: Text(_emojiPodio(index),
                    style: const TextStyle(fontSize: 18)))
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${index + 1}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500)),
                    ),
                  ),
          ),
          const SizedBox(width: 10),

          // Avatar
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(iniciales,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: avatarColor)),
            ),
          ),
          const SizedBox(width: 10),

          // Nombre + tier
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              if (tierColor != null && c.tierNombre != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.star_rounded, size: 11, color: tierColor),
                  const SizedBox(width: 3),
                  Text(c.tierNombre!,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: tierColor)),
                ]),
            ]),
          ),

          // Total período
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${widget.fmt.format(c.totalPeriodo)}',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary)),
            Text('${c.numCompras} compra${c.numCompras != 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant)),
          ]),
        ]),

        const SizedBox(height: 10),

        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(
              isPodio
                  ? _colorPodio(index)
                  : AppColors.secondary.withValues(alpha: 0.45),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Total acumulado
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total histórico',
              style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.grey.shade400)),
          Text('\$${widget.fmt.format(c.totalAcumulado)}',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }

  // ── Empty state ────────────────────────────────────────

  Widget _sinClientes() {
    return Expanded(
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_search_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin clientes en este período',
              style: GoogleFonts.inter(
                  color: Colors.grey.shade500, fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Solo aparecen ventas donde se\nseleccionó un cliente al cobrar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 15, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text('Asigna clientes en el POS al cobrar',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Helpers podio ──────────────────────────────────────

  String _emojiPodio(int i) {
    switch (i) {
      case 0:  return '🥇';
      case 1:  return '🥈';
      default: return '🥉';
    }
  }

  Color _colorPodio(int i) {
    switch (i) {
      case 0:  return Colors.amber.shade600;
      case 1:  return Colors.blueGrey.shade400;
      default: return Colors.brown.shade400;
    }
  }

  Color _bgPodio(int i) {
    switch (i) {
      case 0:  return Colors.amber.shade50;
      case 1:  return Colors.blueGrey.shade50;
      default: return Colors.brown.shade50;
    }
  }

  Color _avatarColor(int id) {
    const palette = [
      Color(0xFF006C49), Color(0xFF5B4CF5), Color(0xFFD97706),
      Color(0xFF059669), Color(0xFFDB2777), Color(0xFF0284C7),
    ];
    return palette[id % palette.length];
  }
}
