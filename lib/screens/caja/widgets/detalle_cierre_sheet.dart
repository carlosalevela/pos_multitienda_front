// lib/screens/caja/widgets/detalle_cierre_sheet.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/sesion_historial.dart';
import 'pdf/cierre_pdf.dart';

// ── Palette (Enterprise POS – DESIGN.md) ─────────────────
const _cGreen     = Color(0xFF006C49);
const _cGreenCont = Color(0xFF6CF8BB);
const _cGreenText = Color(0xFF00714D);
const _cNavy      = Color(0xFF131B2E);
const _cNavyMuted = Color(0xFF7C839B);
const _cRed       = Color(0xFFBA1A1A);
const _cRedCont   = Color(0xFFFFDAD6);
const _cRedText   = Color(0xFF93000A);
const _cOnSurf    = Color(0xFF191C1E);
const _cOnVar     = Color(0xFF45464D);
const _cOutline   = Color(0xFF76777D);
const _cOutVar    = Color(0xFFC6C6CD);
const _cWhite     = Color(0xFFFFFFFF);
const _cSurface   = Color(0xFFF7F9FB);
const _cSurfLow   = Color(0xFFF2F4F6);
const _cSurfHigh  = Color(0xFFE6E8EA);

// ── Formatters ────────────────────────────────────────────
final _numFmt = NumberFormat('#,##0.00', 'en_US');
String _money(double v) => '\$${_numFmt.format(v)}';

const _meses = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

String _fecFmt(String raw) {
  if (raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw.replaceAll(' ', 'T')).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_meses[dt.month]} ${dt.year}, $h:$m';
  } catch (_) {
    return raw.length >= 16 ? raw.substring(0, 16) : raw;
  }
}

String _horaFmt(String raw) {
  if (raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw.replaceAll(' ', 'T')).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) { return '—'; }
}

// ── Synthetic movement record ─────────────────────────────
class _Mov {
  final String hora;
  final String desc;
  final String tipo; // INFO | INGRESO | EGRESO | INICIAL
  final double monto;
  const _Mov(this.hora, this.desc, this.tipo, this.monto);
}

List<_Mov> _buildMovs(SesionHistorial s) {
  final list = <_Mov>[];
  list.add(_Mov(_horaFmt(s.fechaApertura), 'Apertura de Turno', 'INICIAL', s.saldoInicial));
  if (s.ventasEfectivo > 0) {
    list.add(_Mov('—', 'Ventas Efectivo', 'INGRESO', s.ventasEfectivo));
  }
  if (s.ventasTarjeta > 0) {
    list.add(_Mov('—', 'Ventas Tarjeta', 'INGRESO', s.ventasTarjeta));
  }
  if (s.ventasTransferencia > 0) {
    list.add(_Mov('—', 'Ventas Transferencia', 'INGRESO', s.ventasTransferencia));
  }
  if (s.ventasMixto > 0) {
    list.add(_Mov('—', 'Ventas Mixto', 'INGRESO', s.ventasMixto));
  }
  if (s.abonosTotal > 0) {
    list.add(_Mov('—', 'Abonos (${s.numAbonos})', 'INGRESO', s.abonosTotal));
  }
  if (s.devolucionesEfectivo > 0) {
    list.add(_Mov('—', 'Devoluciones Efectivo', 'EGRESO', s.devolucionesEfectivo));
  }
  if (s.gastosTotal > 0) {
    list.add(_Mov('—', 'Gastos del Turno', 'EGRESO', s.gastosTotal));
  }
  list.add(_Mov(_horaFmt(s.fechaCierre), 'Cierre de Caja Final', 'INFO', s.montoFinalReal));
  return list;
}

// ═════════════════════════════════════════════════════════
// MAIN WIDGET
// ═════════════════════════════════════════════════════════

class DetalleCierreSheet extends StatelessWidget {
  final SesionHistorial sesion;
  const DetalleCierreSheet({super.key, required this.sesion});

  @override
  Widget build(BuildContext context) {
    final esExacto   = sesion.diferencia.abs() < 0.01;
    final esPositivo = sesion.diferencia >= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.97,
      minChildSize:     0.5,
      maxChildSize:     1.0,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _cSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Drag handle
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 6),
            child: Center(child: SizedBox(
              width: 36, height: 4,
              child: DecoratedBox(decoration: BoxDecoration(
                color: _cOutVar,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              )),
            )),
          ),
          // Header (status + title + actions)
          _SheetHeader(sesion: sesion, esExacto: esExacto, esPositivo: esPositivo),
          // Scrollable body
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
              children: [
                _ArqueoCard(sesion: sesion, esExacto: esExacto, esPositivo: esPositivo),
                const SizedBox(height: 12),
                _MetricsGrid(sesion: sesion),
                const SizedBox(height: 16),
                _DesglosePagos(sesion: sesion),
                if (sesion.observaciones.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _NotaCierre(nota: sesion.observaciones),
                ],
                const SizedBox(height: 16),
                _MovimientosTable(sesion: sesion),
                const SizedBox(height: 24),
                _ExportButton(onTap: () => exportarCierrePDF(sesion)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// HEADER
// ═════════════════════════════════════════════════════════

class _SheetHeader extends StatelessWidget {
  final SesionHistorial sesion;
  final bool esExacto, esPositivo;
  const _SheetHeader({
    required this.sesion,
    required this.esExacto,
    required this.esPositivo,
  });

  @override
  Widget build(BuildContext context) {
    final difColor = esExacto
        ? _cGreen
        : esPositivo ? _cGreen : _cRed;
    final difLabel = esExacto ? 'CUADRE EXACTO' : esPositivo ? 'SOBRANTE' : 'FALTANTE';
    final difStr   = esExacto
        ? '\$0.00'
        : '${esPositivo ? '+' : '-'}${_money(sesion.diferencia.abs())}';
    final difIcon  = esExacto
        ? Icons.check_circle_rounded
        : esPositivo ? Icons.arrow_circle_up_rounded : Icons.warning_rounded;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 12, 14),
      decoration: const BoxDecoration(
        color: _cWhite,
        border: Border(bottom: BorderSide(color: _cOutVar)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Row 1: status badge + session id + pdf button
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _cRedCont,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: _cRed, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('CAJA CERRADA',
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _cRedText, letterSpacing: 0.8)),
            ]),
          ),
          const SizedBox(width: 10),
          Text('Sesión #${sesion.id}',
              style: GoogleFonts.inter(fontSize: 12, color: _cOutline)),
          const Spacer(),
          IconButton(
            onPressed: () => exportarCierrePDF(sesion),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            color: _cNavy,
            tooltip: 'Exportar PDF',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: _cSurfHigh,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        // Row 2: title
        Text('Resumen de Cierre',
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: _cOnSurf, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        // Row 3: fecha + diferencia chip
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 12, color: _cOutline),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Cierre: ${_fecFmt(sesion.fechaCierre)}',
              style: GoogleFonts.inter(fontSize: 12, color: _cOutline),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (esExacto || esPositivo)
                  ? _cGreenCont.withValues(alpha: 0.35)
                  : _cRedCont,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(difIcon, size: 11, color: difColor),
              const SizedBox(width: 4),
              Text('$difLabel $difStr',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: difColor)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════
// ARQUEO DE CAJA CARD
// ═════════════════════════════════════════════════════════

class _ArqueoCard extends StatelessWidget {
  final SesionHistorial sesion;
  final bool esExacto, esPositivo;
  const _ArqueoCard({
    required this.sesion,
    required this.esExacto,
    required this.esPositivo,
  });

  @override
  Widget build(BuildContext context) {
    final difColor = esExacto ? _cGreen : esPositivo ? _cGreen : _cRed;
    final difBg    = (esExacto || esPositivo)
        ? _cGreenCont.withValues(alpha: 0.3)
        : _cRedCont.withValues(alpha: 0.6);
    final difLabel = esExacto ? 'CUADRE EXACTO' : esPositivo ? 'SOBRANTE' : 'FALTANTE';
    final difStr   = esExacto
        ? '\$0.00'
        : '${esPositivo ? '+' : '-'}${_money(sesion.diferencia.abs())}';
    final difIcon  = esExacto
        ? Icons.check_circle_rounded
        : esPositivo ? Icons.arrow_circle_up_rounded : Icons.warning_rounded;
    final difValColor = (esExacto || esPositivo) ? _cGreen : _cRedText;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cOutVar),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 13, color: _cOutline),
          const SizedBox(width: 6),
          Text('ARQUEO DE CAJA',
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _cOutline, letterSpacing: 0.7)),
        ]),
        const SizedBox(height: 14),
        // Saldo real
        Text('Saldo Real Contado',
            style: GoogleFonts.inter(fontSize: 13, color: _cOnVar)),
        const SizedBox(height: 4),
        Text(_money(sesion.montoFinalReal),
            style: GoogleFonts.inter(
                fontSize: 30, fontWeight: FontWeight.w700,
                color: _cOnSurf, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _cOutVar),
        const SizedBox(height: 12),
        // Saldo esperado
        Text('Saldo Esperado en Sistema',
            style: GoogleFonts.inter(fontSize: 13, color: _cOnVar)),
        const SizedBox(height: 4),
        Text(_money(sesion.montoFinalSistema),
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w600,
                color: _cOutline)),
        const SizedBox(height: 14),
        // Difference badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: difBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: difColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(difLabel,
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: difColor, letterSpacing: 0.6)),
                const SizedBox(height: 3),
                Text(difStr,
                    style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: difValColor)),
              ]),
              Icon(difIcon, size: 30, color: difColor),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════
// 4-METRIC GRID
// ═════════════════════════════════════════════════════════

class _MetricsGrid extends StatelessWidget {
  final SesionHistorial sesion;
  const _MetricsGrid({required this.sesion});

  @override
  Widget build(BuildContext context) {
    final ingresoTotal = sesion.ventasTotal + sesion.abonosTotal;
    return Column(children: [
      Row(children: [
        Expanded(child: _MetricCard(
          icon: Icons.start_rounded,
          iconBg: _cSurfHigh,
          iconColor: _cOnVar,
          label: 'Monto Inicial',
          value: _money(sesion.saldoInicial),
        )),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
          icon: Icons.add_circle_outline_rounded,
          iconBg: _cGreenCont.withValues(alpha: 0.4),
          iconColor: _cGreen,
          label: 'Ingresos Totales',
          value: _money(ingresoTotal),
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
          icon: Icons.remove_circle_outline_rounded,
          iconBg: _cRedCont,
          iconColor: _cRed,
          label: 'Egresos / Gastos',
          value: _money(sesion.gastosTotal),
        )),
        const SizedBox(width: 10),
        Expanded(child: _MetricCardDark(
          icon: Icons.receipt_long_rounded,
          label: 'Ventas Realizadas',
          count: sesion.numTransacciones,
        )),
      ]),
    ]);
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color    iconBg, iconColor;
  final String   label, value;
  const _MetricCard({
    required this.icon,     required this.iconBg,
    required this.iconColor, required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _cWhite,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _cOutVar),
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 8, offset: const Offset(0, 2),
      )],
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: _cOutline),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: _cOnSurf),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      )),
    ]),
  );
}

class _MetricCardDark extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      count;
  const _MetricCardDark({
    required this.icon, required this.label, required this.count,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _cNavy,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: Colors.white70),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: _cNavyMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(
            '$count Transacciones',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ],
      )),
    ]),
  );
}

// ═════════════════════════════════════════════════════════
// DESGLOSE DE PAGOS
// ═════════════════════════════════════════════════════════

class _DesglosePagos extends StatelessWidget {
  final SesionHistorial sesion;
  const _DesglosePagos({required this.sesion});

  @override
  Widget build(BuildContext context) {
    final total = sesion.ventasTotal > 0 ? sesion.ventasTotal : 1.0;
    final items = <_PagoItem>[
      if (sesion.ventasEfectivo > 0)
        _PagoItem('Efectivo', sesion.ventasEfectivo, _cGreen,
            sesion.ventasEfectivo / total),
      if (sesion.ventasTarjeta > 0)
        _PagoItem('Tarjeta (Débito/Crédito)', sesion.ventasTarjeta,
            const Color(0xFF3F465C), sesion.ventasTarjeta / total),
      if (sesion.ventasTransferencia > 0)
        _PagoItem('Transferencias / Otros', sesion.ventasTransferencia,
            const Color(0xFF3A485C), sesion.ventasTransferencia / total),
      if (sesion.ventasMixto > 0)
        _PagoItem('Pago Mixto', sesion.ventasMixto,
            const Color(0xFF005236), sesion.ventasMixto / total),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cOutVar),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Desglose de Pagos',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: _cOnSurf)),
          const Icon(Icons.donut_large_rounded, size: 18, color: _cOutline),
        ]),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Text('Sin ventas en este turno',
              style: GoogleFonts.inter(fontSize: 13, color: _cOutline))
        else
          for (final item in items) _PagoRow(item: item),
        // Abonos
        if (sesion.abonosTotal > 0) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, color: _cOutVar),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF0EA5E9), shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('Abonos recibidos (${sesion.numAbonos})',
                  style: GoogleFonts.inter(fontSize: 13, color: _cOnVar)),
            ]),
            Text(_money(sesion.abonosTotal),
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _cOnSurf)),
          ]),
        ],
        // Cajero info
        const SizedBox(height: 14),
        const Divider(height: 1, color: _cOutVar),
        const SizedBox(height: 12),
        _InfoRow(Icons.person_outline_rounded, 'Cajero',
            sesion.empleadoNombre.isNotEmpty ? sesion.empleadoNombre : '—'),
        const SizedBox(height: 6),
        _InfoRow(Icons.store_outlined, 'Tienda',
            sesion.tiendaNombre.isNotEmpty ? sesion.tiendaNombre : '—'),
        const SizedBox(height: 6),
        _InfoRow(Icons.login_rounded, 'Apertura', _fecFmt(sesion.fechaApertura)),
        if (sesion.numDevoluciones > 0) ...[
          const SizedBox(height: 6),
          _InfoRow(Icons.assignment_return_rounded, 'Devoluciones',
              '${sesion.numDevoluciones} • ${_money(sesion.devolucionesEfectivo)} efectivo'),
        ],
      ]),
    );
  }
}

class _PagoItem {
  final String label;
  final double monto, pct;
  final Color  color;
  const _PagoItem(this.label, this.monto, this.color, this.pct);
}

class _PagoRow extends StatelessWidget {
  final _PagoItem item;
  const _PagoRow({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: item.color, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(item.label,
              style: GoogleFonts.inter(fontSize: 13, color: _cOnVar)),
        ]),
        Text(_money(item.monto),
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: _cOnSurf)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: item.pct.clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: _cSurfHigh,
          valueColor: AlwaysStoppedAnimation<Color>(item.color),
        ),
      ),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: _cOutline),
    const SizedBox(width: 7),
    Text('$label: ',
        style: GoogleFonts.inter(
            fontSize: 12, color: _cOutline, fontWeight: FontWeight.w600)),
    Expanded(
      child: Text(value,
          style: GoogleFonts.inter(fontSize: 12, color: _cOnVar),
          overflow: TextOverflow.ellipsis),
    ),
  ]);
}

// ═════════════════════════════════════════════════════════
// NOTA DE CIERRE
// ═════════════════════════════════════════════════════════

class _NotaCierre extends StatelessWidget {
  final String nota;
  const _NotaCierre({required this.nota});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _cWhite,
      borderRadius: BorderRadius.circular(12),
      border: Border(
        top:    BorderSide(color: _cOutVar),
        right:  BorderSide(color: _cOutVar),
        bottom: BorderSide(color: _cOutVar),
        left:   BorderSide(color: _cGreen, width: 4),
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('NOTA DE CIERRE',
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _cGreen, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      Text('"$nota"',
          style: GoogleFonts.inter(
              fontSize: 13, color: _cOnVar,
              fontStyle: FontStyle.italic, height: 1.5)),
    ]),
  );
}

// ═════════════════════════════════════════════════════════
// MOVIMIENTOS TABLE
// ═════════════════════════════════════════════════════════

class _MovimientosTable extends StatelessWidget {
  final SesionHistorial sesion;
  const _MovimientosTable({required this.sesion});

  @override
  Widget build(BuildContext context) {
    final movs = _buildMovs(sesion);
    return Container(
      decoration: BoxDecoration(
        color: _cWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cOutVar),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(children: [
        // Table header bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Movimientos de la Sesión',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _cOnSurf)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _cSurfHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${movs.length} registros',
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _cOutline)),
              ),
            ],
          ),
        ),
        // Column headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _cSurfLow,
          child: Row(children: [
            SizedBox(width: 40,
              child: Text('HORA',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: _cOutline, letterSpacing: 0.5))),
            const SizedBox(width: 8),
            Expanded(
              child: Text('DESCRIPCIÓN',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: _cOutline, letterSpacing: 0.5))),
            SizedBox(width: 56,
              child: Text('TIPO',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: _cOutline, letterSpacing: 0.5))),
            SizedBox(width: 78,
              child: Text('MONTO',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: _cOutline, letterSpacing: 0.5))),
          ]),
        ),
        // Rows
        for (int i = 0; i < movs.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, color: _cOutVar, indent: 16, endIndent: 16),
          _MovRow(mov: movs[i]),
        ],
        // Footer link-style
        const Divider(height: 1, color: _cOutVar),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'Resumen sintético — ver PDF para detalle completo',
              style: GoogleFonts.inter(
                  fontSize: 11, color: _cOutline,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MovRow extends StatelessWidget {
  final _Mov mov;
  const _MovRow({required this.mov});

  Color get _tipoBg {
    switch (mov.tipo) {
      case 'INGRESO': return _cGreenCont.withValues(alpha: 0.45);
      case 'EGRESO':  return _cRedCont;
      case 'INICIAL': return _cGreenCont.withValues(alpha: 0.45);
      default:        return _cSurfHigh;
    }
  }

  Color get _tipoText {
    switch (mov.tipo) {
      case 'INGRESO': return _cGreenText;
      case 'EGRESO':  return _cRedText;
      case 'INICIAL': return _cGreenText;
      default:        return _cOutline;
    }
  }

  Color get _montoColor {
    switch (mov.tipo) {
      case 'INGRESO': return _cGreen;
      case 'EGRESO':  return _cRed;
      case 'INICIAL': return _cGreen;
      default:        return _cOnSurf;
    }
  }

  String get _prefix {
    switch (mov.tipo) {
      case 'INGRESO': return '+';
      case 'EGRESO':  return '-';
      default:        return '';
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      SizedBox(width: 40,
        child: Text(mov.hora,
            style: GoogleFonts.inter(fontSize: 11, color: _cOnVar))),
      const SizedBox(width: 8),
      Expanded(
        child: Text(mov.desc,
            style: GoogleFonts.inter(fontSize: 13, color: _cOnSurf),
            overflow: TextOverflow.ellipsis),
      ),
      SizedBox(width: 56,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: _tipoBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(mov.tipo,
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _tipoText, letterSpacing: 0.3),
              overflow: TextOverflow.ellipsis),
        ),
      ),
      SizedBox(width: 78,
        child: Text(
          '$_prefix${_money(mov.monto)}',
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _montoColor),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]),
  );
}

// ═════════════════════════════════════════════════════════
// EXPORT BUTTON
// ═════════════════════════════════════════════════════════

class _ExportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExportButton({required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton.icon(
      icon:  const Icon(Icons.picture_as_pdf_rounded, size: 18),
      label: Text('Guardar / Compartir PDF',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _cNavy,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
