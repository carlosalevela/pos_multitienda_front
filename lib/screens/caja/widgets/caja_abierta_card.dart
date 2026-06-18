import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/sesion_caja.dart';
import '../../../models/sesion_historial.dart';
import '../../../providers/caja_provider.dart';
import 'detalle_cierre_sheet.dart';

// ── Paleta ─────────────────────────────────────────────────────
class _C {
  static const surface        = Color(0xFFFFFFFF);
  static const surfaceHigh    = Color(0xFFE6E8EA);
  static const border         = Color(0xFFC6C6CD);
  static const divider        = Color(0xFFE0E3E5);
  static const textPrimary    = Color(0xFF191C1E);
  static const textSecond     = Color(0xFF45464D);
  static const textFaint      = Color(0xFF76777D);
  static const green          = Color(0xFF006C49);
  static const greenContainer = Color(0xFF6CF8BB);
  static const greenOn        = Color(0xFF00714D);
  static const navy           = Color(0xFF131B2E);
  static const navyText       = Color(0xFFBEC6E0);
  static const error          = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
}

// ── Formatters ─────────────────────────────────────────────────
final _fmt = NumberFormat('#,##0', 'en_US');
String _cur(double v) => '\$${_fmt.format(v)}';

String _turnoNombre(DateTime ap) {
  final h = ap.toLocal().hour;
  if (h >= 6  && h < 14) return 'Turno Matutino';
  if (h >= 14 && h < 21) return 'Turno Vespertino';
  return 'Turno Nocturno';
}

String _elapsed(DateTime ap) {
  final d = DateTime.now().difference(ap.toLocal());
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return 'Hace ${h}h ${m}m';
  return 'Hace ${m}m';
}

String _turnoBadgeLabel(String fechaApertura) {
  try {
    final h = DateTime.parse(fechaApertura).toLocal().hour;
    if (h >= 6  && h < 14) return 'MAÑANA';
    if (h >= 14 && h < 21) return 'TARDE';
    return 'NOCHE';
  } catch (_) {
    return '—';
  }
}

Color _turnoBadgeBg(String badge) {
  switch (badge) {
    case 'MAÑANA': return const Color(0xFFD5E3FD);
    case 'TARDE':  return _C.greenContainer;
    default:       return _C.surfaceHigh;
  }
}

Color _turnoBadgeText(String badge) {
  switch (badge) {
    case 'MAÑANA': return const Color(0xFF0D1C2F);
    case 'TARDE':  return _C.greenOn;
    default:       return _C.textSecond;
  }
}

const _meses = [
  '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
];


// ════════════════════════════════════════════════════════════════
// Widget principal
// ════════════════════════════════════════════════════════════════

class CajaAbiertaCard extends StatelessWidget {
  final CajaProvider caja;
  final VoidCallback onCerrarCaja;

  const CajaAbiertaCard({
    super.key,
    required this.caja,
    required this.onCerrarCaja,
  });

  @override
  Widget build(BuildContext context) {
    final sesion = caja.sesionActiva!;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Sección principal: estado + KPIs + panel cierre ──
        if (isWide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 8,
              child: Column(children: [
                _EstadoCard(sesion: sesion),
                const SizedBox(height: 16),
                _KpiRow(sesion: sesion),
              ]),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 300,
              child: _CierrePanel(sesion: sesion, onCerrar: onCerrarCaja),
            ),
          ])
        else
          Column(children: [
            _EstadoCard(sesion: sesion),
            const SizedBox(height: 16),
            _KpiRow(sesion: sesion),
            const SizedBox(height: 16),
            _CierrePanel(sesion: sesion, onCerrar: onCerrarCaja),
          ]),

        const SizedBox(height: 28),

        // ── Historial de cierres ─────────────────────────────
        _HistorialSection(caja: caja),
      ]),
    );
  }
}


// ════════════════════════════════════════════════════════════════
// Estado del Turno
// ════════════════════════════════════════════════════════════════

class _EstadoCard extends StatelessWidget {
  final SesionCaja sesion;
  const _EstadoCard({required this.sesion});

  @override
  Widget build(BuildContext context) {
    final ap      = sesion.fecha_apertura.toLocal();
    final turno   = _turnoNombre(ap);
    final elapsed = _elapsed(ap);
    final hora    = '${ap.hour.toString().padLeft(2, '0')}:${ap.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ESTADO DEL TURNO',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _C.textFaint, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Row(children: [
              Text(turno,
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w600,
                      color: _C.textPrimary)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.greenContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: _C.green,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('EN CURSO',
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: _C.greenOn, letterSpacing: 0.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 14, color: _C.textFaint),
              const SizedBox(width: 4),
              Text('Iniciado hoy a las $hora  •  $elapsed',
                  style: GoogleFonts.inter(fontSize: 13, color: _C.textSecond)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Base Inicial',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _C.textFaint)),
          const SizedBox(height: 3),
          Text(_cur(sesion.saldo_inicial),
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _C.textPrimary)),
        ]),
      ]),
    );
  }
}


// ════════════════════════════════════════════════════════════════
// Fila de 3 KPIs
// ════════════════════════════════════════════════════════════════

class _KpiRow extends StatelessWidget {
  final SesionCaja sesion;
  const _KpiRow({required this.sesion});

  @override
  Widget build(BuildContext context) {
    final hayGastos = sesion.gastosTotal > 0;

    return Row(children: [
      // Ventas del Turno
      Expanded(child: _KpiCard(
        icon: Icons.payments_rounded,
        iconBg: _C.greenContainer,
        iconColor: _C.green,
        topRight: '${sesion.numTransacciones} transacciones',
        topRightBg: _C.greenContainer.withValues(alpha: 0.5),
        topRightColor: _C.greenOn,
        label: 'Ventas del Turno',
        value: _cur(sesion.ventasTotal),
        valueColor: _C.textPrimary,
        cardBg: _C.surface,
        leftBorder: _C.green,
      )),
      const SizedBox(width: 12),
      // Gastos / Egresos
      Expanded(child: _KpiCard(
        icon: Icons.swap_horiz_rounded,
        iconBg: _C.surfaceHigh,
        iconColor: _C.textSecond,
        topRight: 'Egresos del turno',
        topRightBg: _C.surfaceHigh,
        topRightColor: _C.textFaint,
        label: 'Gastos / Egresos',
        value: hayGastos ? '-${_cur(sesion.gastosTotal)}' : _cur(0),
        valueColor: hayGastos ? _C.error : _C.textPrimary,
        cardBg: _C.surface,
        leftBorder: _C.textFaint,
      )),
      const SizedBox(width: 12),
      // Efectivo Esperado (dark card)
      Expanded(child: _KpiCard(
        icon: Icons.account_balance_wallet_rounded,
        iconBg: Colors.white.withValues(alpha: 0.12),
        iconColor: _C.navyText,
        topRight: 'Incluye base inicial',
        topRightBg: Colors.white.withValues(alpha: 0.1),
        topRightColor: _C.navyText,
        label: 'Efectivo Esperado',
        value: _cur(sesion.montoEsperado),
        valueColor: Colors.white,
        labelColor: _C.navyText,
        cardBg: _C.navy,
        leftBorder: _C.navy,
      )),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color    iconBg, iconColor;
  final String   topRight;
  final Color    topRightBg, topRightColor;
  final String   label, value;
  final Color    valueColor, cardBg, leftBorder;
  final Color?   labelColor;

  const _KpiCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.topRight,
    required this.topRightBg,
    required this.topRightColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.cardBg,
    required this.leftBorder,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final lColor = labelColor ?? _C.textSecond;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: leftBorder, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: topRightBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(topRight,
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: topRightColor)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500, color: lColor)),
        const SizedBox(height: 3),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 26, fontWeight: FontWeight.w700, color: valueColor)),
      ]),
    );
  }
}


// ════════════════════════════════════════════════════════════════
// Panel Cierre de Caja
// ════════════════════════════════════════════════════════════════

class _CierrePanel extends StatelessWidget {
  final SesionCaja sesion;
  final VoidCallback onCerrar;
  const _CierrePanel({required this.sesion, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _C.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Cierre de Caja',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _C.textPrimary)),
        ]),
        const SizedBox(height: 14),
        Text(
          'Finaliza tu jornada laboral. Asegúrate de contar el efectivo físico antes de proceder con el cierre.',
          style: GoogleFonts.inter(fontSize: 13, color: _C.textSecond, height: 1.5),
        ),
        const SizedBox(height: 20),
        _CierreRow('Ventas Totales',   _cur(sesion.ventasTotal)),
        _CierreRow('Efectivo Sistema', _cur(sesion.montoEsperado)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.point_of_sale_rounded, size: 18),
            label: Text('CERRAR CAJA AHORA',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
            onPressed: onCerrar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.green,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: _C.green.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CierreRow extends StatelessWidget {
  final String label, value;
  const _CierreRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text(label,
          style: GoogleFonts.inter(fontSize: 14, color: _C.textSecond)),
      const Spacer(),
      Text(value,
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPrimary)),
    ]),
  );
}


// ════════════════════════════════════════════════════════════════
// Historial de Cierres (tabla)
// ════════════════════════════════════════════════════════════════

class _HistorialSection extends StatelessWidget {
  final CajaProvider caja;
  const _HistorialSection({required this.caja});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Historial de Cierres',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w600, color: _C.textPrimary)),
          Text('Tus últimos turnos registrados',
              style: GoogleFonts.inter(fontSize: 13, color: _C.textFaint)),
        ]),
        const Spacer(),
      ]),
      const SizedBox(height: 12),
      const Divider(color: _C.divider),
      const SizedBox(height: 4),

      if (caja.cargando)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(
              color: _C.green, strokeWidth: 2),
          ),
        )
      else if (caja.historial.isEmpty)
        Container(
          padding: const EdgeInsets.all(40),
          alignment: Alignment.center,
          child: Column(children: [
            const Icon(Icons.history_rounded, size: 40, color: _C.border),
            const SizedBox(height: 12),
            Text('Sin cierres registrados aún',
                style: GoogleFonts.inter(fontSize: 14, color: _C.textFaint)),
          ]),
        )
      else
        _HistorialTable(items: caja.historial, context: context),
    ]);
  }
}

class _HistorialTable extends StatelessWidget {
  final List<SesionHistorial> items;
  final BuildContext context;
  const _HistorialTable({required this.items, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Column(children: [
      // Encabezados
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Expanded(flex: 3, child: _th('FECHA Y HORA')),
          Expanded(flex: 2, child: _th('TURNO', center: true)),
          Expanded(flex: 2, child: _th('MONTO INICIAL')),
          Expanded(flex: 2, child: _th('VENTAS TOTALES', right: true)),
          Expanded(flex: 2, child: _th('DIFERENCIA', center: true)),
          const SizedBox(width: 48),
        ]),
      ),
      // Filas
      ...items.take(8).map((s) => _HistorialRow(sesion: s)),
    ]);
  }

  Widget _th(String t, {bool right = false, bool center = false}) => Text(t,
      textAlign: center
          ? TextAlign.center
          : right
              ? TextAlign.right
              : TextAlign.left,
      style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: _C.textFaint, letterSpacing: 0.5));
}

class _HistorialRow extends StatelessWidget {
  final SesionHistorial sesion;
  const _HistorialRow({required this.sesion});

  @override
  Widget build(BuildContext context) {
    final esPos      = sesion.diferencia >= 0;
    final difColor   = esPos ? _C.green : _C.error;
    final difBg      = esPos ? _C.greenContainer : _C.errorContainer;
    final badge      = _turnoBadgeLabel(sesion.fechaApertura);
    final badgeBg    = _turnoBadgeBg(badge);
    final badgeColor = _turnoBadgeText(badge);

    String fechaStr = '', horaStr = '';
    try {
      final ap = DateTime.parse(sesion.fechaApertura).toLocal();
      final cl = sesion.fechaCierre.isNotEmpty
          ? DateTime.parse(sesion.fechaCierre).toLocal()
          : null;
      fechaStr = '${ap.day} ${_meses[ap.month]}, ${ap.year}';
      final from = '${ap.hour.toString().padLeft(2,'0')}:${ap.minute.toString().padLeft(2,'0')}';
      final to   = cl != null
          ? '${cl.hour.toString().padLeft(2,'0')}:${cl.minute.toString().padLeft(2,'0')}'
          : '—';
      horaStr = '$from - $to';
    } catch (_) {}

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DetalleCierreSheet(sesion: sesion),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.divider),
        ),
        child: Row(children: [
          // Fecha y Hora
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fechaStr,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: _C.textPrimary)),
              Text(horaStr,
                  style: GoogleFonts.inter(fontSize: 11, color: _C.textFaint)),
            ],
          )),
          // Turno badge
          Expanded(flex: 2, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(badge,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: badgeColor, letterSpacing: 0.5)),
          ))),
          // Monto Inicial
          Expanded(flex: 2, child: Text(
            _cur(sesion.saldoInicial),
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: _C.textPrimary),
          )),
          // Ventas Totales
          Expanded(flex: 2, child: Text(
            _cur(sesion.ventasTotal),
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: _C.textPrimary),
          )),
          // Diferencia
          Expanded(flex: 2, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: difBg, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                esPos ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 14, color: difColor),
              const SizedBox(width: 4),
              Text(
                '${esPos ? '' : '-'}\$${_fmt.format(sesion.diferencia.abs())}',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: difColor)),
            ]),
          ))),
          // Acción
          SizedBox(width: 48, child: Center(child: IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 16, color: _C.green),
            tooltip: 'Ver detalle',
            style: IconButton.styleFrom(
              backgroundColor: _C.greenContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(34, 34),
            ),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => DetalleCierreSheet(sesion: sesion),
            ),
          ))),
        ]),
      ),
    );
  }
}
