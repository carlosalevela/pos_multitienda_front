import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../models/sesion_historial.dart';


class DetalleCierreSheet extends StatelessWidget {
  final SesionHistorial sesion;
  const DetalleCierreSheet({super.key, required this.sesion});

  static const _bg        = Color(0xFF0A0E1A);
  static const _surface   = Color(0xFF111827);
  static const _card      = Color(0xFF1A2236);
  static const _border    = Color(0xFF1E2D45);
  static const _accent    = Color(0xFF3B82F6);
  static const _green     = Color(0xFF10B981);
  static const _red       = Color(0xFFEF4444);
  static const _yellow    = Color(0xFFF59E0B);
  static const _purple    = Color(0xFF8B5CF6);
  static const _textPri   = Color(0xFFF1F5F9);
  static const _textSec   = Color(0xFF94A3B8);
  static const _textMuted = Color(0xFF475569);

  static final _fmt = NumberFormat('#,##0', 'en_US');

  String _f(double v) => '\$${_fmt.format(v)}';

  String _fecha(String f) {
    if (f.isEmpty) return '—';
    final c = f.replaceAll('T', ' ');
    return c.length >= 16 ? c.substring(0, 16) : c;
  }

  @override
  Widget build(BuildContext context) {
    final esPositivo = sesion.diferencia >= 0;
    final esExacto   = sesion.diferencia.abs() < 0.01;

    final difColor = esExacto
        ? _green : esPositivo ? _accent : _red;
    final difLabel = esExacto
        ? 'CUADRE EXACTO' : esPositivo ? 'SOBRANTE' : 'FALTANTE';
    final difIcon  = esExacto
        ? Icons.check_circle_rounded
        : esPositivo ? Icons.arrow_circle_up_rounded : Icons.warning_rounded;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize:     0.5,
      maxChildSize:     0.97,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          _buildHandle(),
          _buildHeader(esPositivo, esExacto, difColor, difLabel, difIcon),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [

                // ── Métricas rápidas ─────────────────────────
                _QuickMetrics(
                  sesion:     sesion,
                  f:          _f,
                  difColor:   difColor,
                  difLabel:   difLabel,
                  esPositivo: esPositivo,
                ),
                const SizedBox(height: 20),

                // ── Info general ─────────────────────────────
                _DarkCard(
                  titulo: 'Información general',
                  icono:  Icons.person_outline_rounded,
                  color:  _accent,
                  child: Column(children: [
                    _Row(
                      'Cajero', sesion.empleadoNombre,
                      leading: _Avatar(sesion.empleadoNombre),
                    ),
                    const SizedBox(height: 10),
                    _Row('Apertura', _fecha(sesion.fechaApertura),
                        icon: Icons.login_rounded,  iconColor: _green),
                    _Row('Cierre',   _fecha(sesion.fechaCierre),
                        icon: Icons.logout_rounded, iconColor: _red),
                    _Row('Saldo inicial', _f(sesion.saldoInicial),
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: _accent),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Ventas ───────────────────────────────────
                _DarkCard(
                  titulo: 'Ventas del turno',
                  icono:  Icons.trending_up_rounded,
                  color:  _green,
                  child: Column(children: [
                    _MetodoRow('Efectivo',      _f(sesion.ventasEfectivo),
                        _green,  Icons.payments_rounded),
                    _MetodoRow('Tarjeta',       _f(sesion.ventasTarjeta),
                        _accent, Icons.credit_card_rounded),
                    _MetodoRow('Transferencia', _f(sesion.ventasTransferencia),
                        _purple, Icons.swap_horiz_rounded),
                    if (sesion.ventasMixto > 0)
                      _MetodoRow('Mixto', _f(sesion.ventasMixto),
                          _yellow, Icons.compare_arrows_rounded),
                    const _CardDivider(),
                    _TotalLine('TOTAL VENTAS', _f(sesion.ventasTotal), _textPri),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _Chip(
                            '${sesion.numTransacciones} transacciones', _green),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Gastos ───────────────────────────────────
                _DarkCard(
                  titulo: 'Gastos del turno',
                  icono:  Icons.trending_down_rounded,
                  color:  _red,
                  child: _Row('Total gastos', '-${_f(sesion.gastosTotal)}',
                      valueColor: _red),
                ),
                const SizedBox(height: 12),

                // ── Devoluciones ─────────────────────────────
                if (sesion.numDevoluciones > 0) ...[
                  _DarkCard(
                    titulo: 'Devoluciones del turno',
                    icono:  Icons.assignment_return_rounded,
                    color:  _yellow,
                    child: Column(children: [
                      _Row('Devuelto en efectivo',
                          '-${_f(sesion.devolucionesEfectivo)}',
                          valueColor: _red),
                      const _CardDivider(),
                      _TotalLine(
                        '${sesion.numDevoluciones} devolución'
                        '${sesion.numDevoluciones != 1 ? "es" : ""}',
                        '', _textMuted,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  _InfoTip('Solo las devoluciones en efectivo reducen el cuadre de caja.'),
                  const SizedBox(height: 12),
                ],

                // ── Cuadre de caja ───────────────────────────
                _CuadreCard(
                  esperado:   _f(sesion.montoFinalSistema),
                  contado:    _f(sesion.montoFinalReal),
                  diferencia: sesion.diferencia,
                  esPositivo: esPositivo,
                  esExacto:   esExacto,
                  difColor:   difColor,
                  fmt:        _fmt,
                ),

                // ── Observaciones ────────────────────────────
                if (sesion.observaciones.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Icon(Icons.notes_rounded,
                            size: 14, color: _textMuted),
                        const SizedBox(width: 6),
                        Text('OBSERVACIONES',
                            style: GoogleFonts.dmSans(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: _textMuted, letterSpacing: 1.2)),
                      ]),
                      const SizedBox(height: 8),
                      Text(sesion.observaciones,
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: _textSec, height: 1.5)),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),
                _PdfButton(onPressed: () => _exportarPDF(context)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Center(
      child: Container(
        width: 38, height: 4,
        decoration: BoxDecoration(
          color: _border, borderRadius: BorderRadius.circular(2)),
      ),
    ),
  );

  Widget _buildHeader(
    bool esPositivo, bool esExacto,
    Color difColor, String difLabel, IconData difIcon,
  ) =>
    Container(
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: const Icon(Icons.receipt_long_rounded,
              color: _accent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cierre #${sesion.id}',
                style: GoogleFonts.dmSans(
                    color: _textPri, fontWeight: FontWeight.w800,
                    fontSize: 17)),
            Text(sesion.tiendaNombre,
                style: GoogleFonts.dmSans(
                    color: _textMuted, fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: difColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: difColor.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(difIcon, size: 13, color: difColor),
            const SizedBox(width: 5),
            Text(
              esExacto
                  ? difLabel
                  : '${esPositivo ? '+' : '-'}\$${_fmt.format(sesion.diferencia.abs())}',
              style: GoogleFonts.dmSans(
                  color: difColor, fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ]),
    );

  static Widget _Row(String label, String valor,
      {Color? valueColor, Widget? leading,
       IconData? icon, Color? iconColor}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        if (leading != null) ...[leading, const SizedBox(width: 10)],
        if (icon != null && leading == null) ...[
          Icon(icon, size: 14, color: iconColor ?? _textMuted),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(label,
              style: GoogleFonts.dmSans(
                  color: _textSec, fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Text(valor,
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: valueColor ?? _textPri)),
      ]),
    );

  // ── PDF ─────────────────────────────────────────────────────
  Future<void> _exportarPDF(BuildContext context) async {
    final doc        = pw.Document();
    final esPositivo = sesion.diferencia >= 0;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(22),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0A0E1A),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text(sesion.tiendaNombre,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Reporte de Cierre de Caja — #${sesion.id}',
                  style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFF94A3B8), fontSize: 12)),
            ]),
          ),
          pw.SizedBox(height: 22),

          _pdfSeccion('INFORMACIÓN GENERAL'),
          _pdfFila('Cajero',        sesion.empleadoNombre),
          _pdfFila('Apertura',      _fecha(sesion.fechaApertura)),
          _pdfFila('Cierre',        _fecha(sesion.fechaCierre)),
          _pdfFila('Saldo inicial', _f(sesion.saldoInicial)),
          pw.SizedBox(height: 16),

          _pdfSeccion('VENTAS DEL TURNO'),
          _pdfFila('Efectivo',      _f(sesion.ventasEfectivo)),
          _pdfFila('Tarjeta',       _f(sesion.ventasTarjeta)),
          _pdfFila('Transferencia', _f(sesion.ventasTransferencia)),
          if (sesion.ventasMixto > 0)
            _pdfFila('Mixto',       _f(sesion.ventasMixto)),
          pw.Divider(color: const PdfColor.fromInt(0xFF1E2D45)),
          _pdfFila('TOTAL VENTAS',  _f(sesion.ventasTotal), bold: true),
          pw.SizedBox(height: 16),

          _pdfSeccion('GASTOS DEL TURNO'),
          _pdfFila('Total gastos',  _f(sesion.gastosTotal)),
          pw.SizedBox(height: 16),

          if (sesion.numDevoluciones > 0) ...[
            _pdfSeccion('DEVOLUCIONES DEL TURNO'),
            _pdfFila('Devuelto en ef.',
                '-${_f(sesion.devolucionesEfectivo)}',
                valueColor: PdfColors.red700),
            _pdfFila('Cantidad', '${sesion.numDevoluciones}'),
            pw.SizedBox(height: 16),
          ],

          _pdfSeccion('CUADRE DE CAJA'),
          _pdfFila('Monto esperado', _f(sesion.montoFinalSistema)),
          _pdfFila('Monto contado',  _f(sesion.montoFinalReal)),
          pw.Divider(color: const PdfColor.fromInt(0xFF1E2D45)),
          _pdfFila(
            'Diferencia',
            '${esPositivo ? '+' : ''}\$${_fmt.format(sesion.diferencia)}',
            bold: true,
            valueColor: esPositivo ? PdfColors.green700 : PdfColors.red700,
          ),
          pw.SizedBox(height: 16),

          if (sesion.observaciones.isNotEmpty) ...[
            _pdfSeccion('OBSERVACIONES'),
            pw.Text(sesion.observaciones,
                style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColor.fromInt(0xFF475569))),
            pw.SizedBox(height: 16),
          ],

          pw.Spacer(),
          pw.Divider(color: const PdfColor.fromInt(0xFF1E2D45)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generado el ${DateTime.now().toString().substring(0, 16)} · POS Multitienda',
            style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xFF94A3B8))),
        ],
      ),
    ));

    await Printing.sharePdf(
      bytes:    await doc.save(),
      filename: 'cierre_caja_${sesion.id}.pdf',
    );
  }

  pw.Widget _pdfSeccion(String titulo) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(titulo,
        style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF3B82F6))),
  );

  pw.Widget _pdfFila(String label, String valor,
      {bool bold = false, PdfColor? valueColor}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromInt(0xFF64748B))),
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: bold
                      ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: valueColor ??
                      const PdfColor.fromInt(0xFF0F172A))),
        ],
      ),
    );
}


// ══════════════════════════════════════════════════════════
// COMPONENTES INTERNOS
// ══════════════════════════════════════════════════════════

class _QuickMetrics extends StatelessWidget {
  final SesionHistorial          sesion;
  final String Function(double)  f;
  final Color   difColor;
  final String  difLabel;
  final bool    esPositivo;

  const _QuickMetrics({
    required this.sesion,   required this.f,
    required this.difColor, required this.difLabel,
    required this.esPositivo,
  });

  static const _green = Color(0xFF10B981);
  static const _red   = Color(0xFFEF4444);
  static final _fmt   = NumberFormat('#,##0', 'en_US');

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _MetricTile(
      label: 'Total ventas',
      valor: f(sesion.ventasTotal),
      color: _green,
      icon:  Icons.trending_up_rounded,
    )),
    const SizedBox(width: 10),
    Expanded(child: _MetricTile(
      label: 'Total gastos',
      valor: f(sesion.gastosTotal),
      color: _red,
      icon:  Icons.trending_down_rounded,
    )),
    const SizedBox(width: 10),
    Expanded(child: _MetricTile(
      label: difLabel,
      valor: '${esPositivo ? '+' : '-'}\$${_fmt.format(sesion.diferencia.abs())}',
      color: difColor,
      icon:  esPositivo
          ? Icons.arrow_circle_up_rounded : Icons.warning_rounded,
    )),
  ]);
}


class _MetricTile extends StatelessWidget {
  final String   label, valor;
  final Color    color;
  final IconData icon;
  const _MetricTile({
    required this.label, required this.valor,
    required this.color, required this.icon,
  });

  static const _card    = Color(0xFF1A2236);
  static const _border  = Color(0xFF1E2D45);
  static const _textSec = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(height: 10),
      Text(valor,
          style: GoogleFonts.dmSans(
              fontSize: 16, fontWeight: FontWeight.w800, color: color),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label,
          style: GoogleFonts.dmSans(
              fontSize: 10, color: _textSec, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}


class _DarkCard extends StatelessWidget {
  final String   titulo;
  final IconData icono;
  final Color    color;
  final Widget   child;
  const _DarkCard({
    required this.titulo, required this.icono,
    required this.color,  required this.child,
  });

  static const _card   = Color(0xFF1A2236);
  static const _border = Color(0xFF1E2D45);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Text(titulo,
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}


class _MetodoRow extends StatelessWidget {
  final String   label, valor;
  final Color    color;
  final IconData icon;
  const _MetodoRow(this.label, this.valor, this.color, this.icon);

  static const _textSec = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 13, color: _textSec,
                fontWeight: FontWeight.w500)),
      ),
      Text(valor,
          style: GoogleFonts.dmSans(
              fontSize: 13, color: color, fontWeight: FontWeight.w700)),
    ]),
  );
}


class _TotalLine extends StatelessWidget {
  final String label, valor;
  final Color  color;
  const _TotalLine(this.label, this.valor, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: GoogleFonts.dmSans(
              fontSize: 13, color: color, fontWeight: FontWeight.w800)),
      if (valor.isNotEmpty)
        Text(valor,
            style: GoogleFonts.dmSans(
                fontSize: 14, color: color, fontWeight: FontWeight.w800)),
    ],
  );
}


class _CardDivider extends StatelessWidget {
  const _CardDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Divider(height: 1, color: Color(0xFF1E2D45)),
  );
}


class _Chip extends StatelessWidget {
  final String text;
  final Color  color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(text,
        style: GoogleFonts.dmSans(
            fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );
}


class _Avatar extends StatelessWidget {
  final String nombre;
  const _Avatar(this.nombre);

  static const _accent = Color(0xFF3B82F6);
  static const _purple = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_accent, _purple]),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
      ),
    ),
  );
}


class _InfoTip extends StatelessWidget {
  final String msg;
  const _InfoTip(this.msg);
  static const _textMuted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, top: 4),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, size: 12, color: _textMuted),
      const SizedBox(width: 5),
      Expanded(
        child: Text(msg,
            style: GoogleFonts.dmSans(
                fontSize: 11, color: _textMuted,
                fontWeight: FontWeight.w500)),
      ),
    ]),
  );
}


class _CuadreCard extends StatelessWidget {
  final String esperado, contado;
  final double diferencia;
  final bool   esPositivo, esExacto;
  final Color  difColor;
  final NumberFormat fmt;
  const _CuadreCard({
    required this.esperado,   required this.contado,
    required this.diferencia, required this.esPositivo,
    required this.esExacto,   required this.difColor,
    required this.fmt,
  });

  static const _green   = Color(0xFF10B981);
  static const _textSec = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final difLabel = esExacto
        ? 'CUADRE EXACTO' : esPositivo ? 'SOBRANTE' : 'FALTANTE';
    final difStr   = esExacto
        ? '\$0'
        : '${esPositivo ? '+' : '-'}\$${fmt.format(diferencia.abs())}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF063A26), Color(0xFF0A4D33)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(
          color: _green.withOpacity(0.12),
          blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _green.withOpacity(0.3)),
            ),
            child: const Icon(Icons.calculate_rounded,
                color: _green, size: 15),
          ),
          const SizedBox(width: 10),
          Text('Cuadre de caja',
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: _green)),
        ]),
        const SizedBox(height: 16),
        _CuadreLine('Monto esperado', esperado, _textSec),
        _CuadreLine('Monto contado',  contado,  _textSec),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(height: 1, color: _green.withOpacity(0.2)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(difLabel,
                style: GoogleFonts.dmSans(
                    color: difColor, fontWeight: FontWeight.w800,
                    fontSize: 12)),
            Text(difStr,
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 22, letterSpacing: -0.5)),
          ],
        ),
      ]),
    );
  }
}


class _CuadreLine extends StatelessWidget {
  final String label, valor;
  final Color  color;
  const _CuadreLine(this.label, this.valor, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 13, color: color.withOpacity(0.75))),
        Text(valor,
            style: GoogleFonts.dmSans(
                fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}


class _PdfButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _PdfButton({required this.onPressed});

  static const _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accent, Color(0xFF2563EB)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: _accent.withOpacity(0.35),
          blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: ElevatedButton.icon(
        icon:  const Icon(Icons.picture_as_pdf_rounded, size: 19),
        label: Text('Guardar / Compartir PDF',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700, fontSize: 15)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
  );
}