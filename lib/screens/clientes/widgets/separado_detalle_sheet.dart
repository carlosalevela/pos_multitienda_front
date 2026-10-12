import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/separado.dart';
import '../../../providers/auth_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/recibo_pdf_service.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../services/windows_printer_service.dart';

// ── Paleta ────────────────────────────────────────────────
const _kTeal      = Color(0xFF006C49);
const _kTealMid   = Color(0xFF01696F);
const _kTealLight = Color(0xFFE8FFF4);
const _kAmber     = Color(0xFFF59E0B);
const _kText      = Color(0xFF191C1E);
const _kMuted     = Color(0xFF76777D);
const _kBorder    = Color(0xFFE0E3E5);
const _kSurface   = Color(0xFFF7F9FB);
const _kRed       = Color(0xFFBA1A1A);

class SeparadoDetalleSheet extends StatelessWidget {
  final Separado     separado;
  final NumberFormat fmt;
  final bool         mostrarAcciones;
  final VoidCallback? onAbonar;
  final VoidCallback? onCancelar;

  const SeparadoDetalleSheet({
    super.key,
    required this.separado,
    required this.fmt,
    this.mostrarAcciones = false,
    this.onAbonar,
    this.onCancelar,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required Separado     separado,
    required NumberFormat fmt,
    bool                  mostrarAcciones = false,
    VoidCallback?         onAbonar,
    VoidCallback?         onCancelar,
  }) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => SeparadoDetalleSheet(
        separado:        separado,
        fmt:             fmt,
        mostrarAcciones: mostrarAcciones,
        onAbonar:        onAbonar,
        onCancelar:      onCancelar,
      ),
    );
  }

  // ── Estado helpers ─────────────────────────────────────
  Color _colorEstado() => switch (separado.estado) {
    'pagado'    => const Color(0xFF1D4ED8),
    'cancelado' => _kMuted,
    _           => _kTeal,
  };

  Color _bgEstado() => switch (separado.estado) {
    'pagado'    => const Color(0xFFEFF6FF),
    'cancelado' => _kSurface,
    _           => _kTealLight,
  };

  String _labelEstado() => switch (separado.estado) {
    'pagado'    => 'Pagado',
    'cancelado' => 'Cancelado',
    _           => 'Activo',
  };

  IconData _iconEstado() => switch (separado.estado) {
    'pagado'    => Icons.verified_rounded,
    'cancelado' => Icons.cancel_outlined,
    _           => Icons.bookmark_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final fmtInt = NumberFormat('#,##0', 'es_CO');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Handle ───────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // ── Contenido scrollable ──────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Tarjeta cliente (header) ──────────────
                  _clienteCard(fmtInt),

                  const SizedBox(height: 16),

                  // ── Info general ──────────────────────────
                  _infoCard(),

                  const SizedBox(height: 16),

                  // ── Productos ─────────────────────────────
                  _seccionTitle(
                    icon:  Icons.shopping_bag_outlined,
                    label: 'Productos',
                    count: separado.detalles.length,
                    color: _kTeal,
                  ),
                  const SizedBox(height: 8),
                  ...separado.detalles.map(_productoItem),

                  // ── Abonos ────────────────────────────────
                  if (separado.abonos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _seccionTitle(
                      icon:  Icons.payments_rounded,
                      label: 'Abonos',
                      count: separado.abonos.length,
                      color: _kTeal,
                    ),
                    const SizedBox(height: 8),
                    ...separado.abonos.map(_abonoItem),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Botones fijos abajo ───────────────────────────
          if (mostrarAcciones && separado.esActivo) ...[
            const Divider(height: 1, color: _kBorder),
            _bottomActions(context),
          ] else ...[
            // Solo botón imprimir
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _imprimir(context),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text('Imprimir factura',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTeal,
                    side: const BorderSide(color: _kTeal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tarjeta principal con degradado ──────────────────────
  Widget _clienteCard(NumberFormat fmtInt) {
    final progreso = separado.progreso.clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kTeal, _kTealMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _kTeal.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Nombre + SEP id + estado + imprimir
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                separado.clienteNombre.isNotEmpty
                    ? separado.clienteNombre[0].toUpperCase() : '?',
                style: GoogleFonts.inter(fontSize: 18,
                    fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(separado.clienteNombre,
                  style: GoogleFonts.inter(fontSize: 14,
                      fontWeight: FontWeight.w700, color: Colors.white)),
              Text('SEP-${separado.id}',
                  style: GoogleFonts.inter(fontSize: 12,
                      color: Colors.white70)),
            ]),
          ),
          // Chip estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_iconEstado(), size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(_labelEstado(),
                  style: GoogleFonts.inter(fontSize: 11,
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          const SizedBox(width: 8),
          // Botón imprimir
          Builder(builder: (ctx) => GestureDetector(
              onTap: () => _imprimir(ctx),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.print_rounded,
                    size: 16, color: Colors.white),
              ),
            )),
        ]),

        const SizedBox(height: 14),

        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:      progreso,
            minHeight:  6,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),

        const SizedBox(height: 12),

        // Stats
        Row(children: [
          _stat('Total',    '\$${fmtInt.format(separado.total)}',
              Colors.white70, Colors.white),
          _statDiv(),
          _stat('Abonado',  '\$${fmtInt.format(separado.abonoAcumulado)}',
              Colors.white70, const Color(0xFF86EFAC)),
          _statDiv(),
          _stat('Pendiente','\$${fmtInt.format(separado.saldoPendiente)}',
              Colors.white70, const Color(0xFFFFD580)),
        ]),
      ]),
    );
  }

  // ── Tarjeta info general ──────────────────────────────────
  Widget _infoCard() {
    final fecha = DateFormat('d MMM yyyy · HH:mm', 'es')
        .format(separado.createdAt);
    String? fechaLimiteStr;
    if (separado.fechaLimite != null) {
      try {
        final dt = DateTime.parse(separado.fechaLimite!);
        fechaLimiteStr = DateFormat('d MMM yyyy', 'es').format(dt);
        final diff = dt.difference(DateTime.now()).inDays;
        if (diff < 0) {
          fechaLimiteStr += ' · vencido';
        } else if (diff == 0) {
          fechaLimiteStr += ' · hoy';
        } else if (diff <= 3) {
          fechaLimiteStr += ' · $diff días';
        }
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        _infoRow(Icons.store_outlined,        'Tienda',    separado.tiendaNombre),
        if (separado.empleadoNombre != null)
          _infoRow(Icons.badge_outlined,      'Empleado',  separado.empleadoNombre!),
        _infoRow(Icons.calendar_today_rounded,'Fecha',     fecha),
        if (fechaLimiteStr != null)
          _infoRow(Icons.event_rounded,       'Límite',    fechaLimiteStr,
              valueColor: fechaLimiteStr.contains('vencido')
                  ? _kRed
                  : fechaLimiteStr.contains('días') || fechaLimiteStr.contains('hoy')
                      ? _kAmber
                      : null),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String valor,
      {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: _kMuted),
          const SizedBox(width: 8),
          Text('$label  ',
              style: GoogleFonts.inter(fontSize: 12, color: _kMuted)),
          Expanded(
            child: Text(valor,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? _kText)),
          ),
        ]),
      );

  // ── Título de sección ─────────────────────────────────────
  Widget _seccionTitle({
    required IconData icon,
    required String   label,
    required int      count,
    required Color    color,
  }) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(fontSize: 14,
                fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: GoogleFonts.inter(fontSize: 11,
                  fontWeight: FontWeight.w700, color: color)),
        ),
      ]);

  // ── Card producto ─────────────────────────────────────────
  Widget _productoItem(DetalleSeparado d) {
    final cant = d.cantidad % 1 == 0
        ? d.cantidad.toInt().toString()
        : d.cantidad.toStringAsFixed(2);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shopping_bag_outlined,
              size: 17, color: _kTeal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(d.productoNombre,
                style: GoogleFonts.inter(fontSize: 13,
                    fontWeight: FontWeight.w600, color: _kText)),
            Text('x$cant  ·  ${fmt.format(d.precioUnitario)} c/u',
                style: GoogleFonts.inter(fontSize: 11, color: _kMuted)),
          ]),
        ),
        Text(fmt.format(d.subtotal),
            style: GoogleFonts.inter(fontSize: 13,
                fontWeight: FontWeight.w700, color: _kTeal)),
      ]),
    );
  }

  // ── Card abono ────────────────────────────────────────────
  Widget _abonoItem(AbonoSeparado a) {
    final (metodoLabel, metodoColor, metodoIcon) = switch (a.metodoPago) {
      'transferencia' => ('Transferencia', const Color(0xFF2563EB),
          Icons.swap_horiz_rounded),
      'tarjeta'       => ('Tarjeta', const Color(0xFF7C3AED),
          Icons.credit_card_outlined),
      _               => ('Efectivo', _kTeal, Icons.payments_outlined),
    };
    final fecha = DateFormat('d MMM · HH:mm', 'es').format(a.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: metodoColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(metodoIcon, size: 17, color: metodoColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(metodoLabel,
                style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w600, color: _kText)),
            Text(
              a.empleadoNombre != null
                  ? '${a.empleadoNombre}  ·  $fecha'
                  : fecha,
              style: GoogleFonts.inter(fontSize: 11, color: _kMuted),
            ),
          ]),
        ),
        Text(fmt.format(a.monto),
            style: GoogleFonts.inter(fontSize: 14,
                fontWeight: FontWeight.w800, color: _kTeal)),
      ]),
    );
  }

  // ── Botones de acción ─────────────────────────────────────
  Widget _bottomActions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        // Cancelar separado
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onCancelar?.call();
            },
            icon: Icon(Icons.cancel_outlined, size: 16,
                color: Colors.red.shade400),
            label: Text('Cancelar',
                style: GoogleFonts.inter(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.red.shade200),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Registrar abono
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onAbonar?.call();
            },
            icon: const Icon(Icons.payments_rounded,
                size: 17, color: Colors.white),
            label: Text('Registrar abono',
                style: GoogleFonts.inter(fontSize: 14,
                    fontWeight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Stat helpers ──────────────────────────────────────────
  Widget _stat(String label, String valor,
      Color labelColor, Color valorColor) =>
      Expanded(
        child: Column(children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: labelColor)),
          const SizedBox(height: 2),
          Text(valor,
              style: GoogleFonts.inter(fontSize: 12,
                  fontWeight: FontWeight.w700, color: valorColor)),
        ]),
      );

  Widget _statDiv() => Container(
      width: 1, height: 24,
      color: Colors.white.withValues(alpha: 0.2));

  // ── Imprimir ──────────────────────────────────────────────
  Future<void> _imprimir(BuildContext context) async {
    final auth          = context.read<AuthProvider>();
    final empresaNombre = auth.empresaNombre.isNotEmpty
        ? auth.empresaNombre
        : separado.tiendaNombre;

    if (ThermalPrinterService.isWebUsbSupported) {
      try {
        final dev = await ThermalPrinterService.getAutoDevice();
        if (dev != null) {
          final bytes = await ThermalPrinterService.buildSeparadoRecibo(
              separado, empresaNombre: empresaNombre);
          await ThermalPrinterService.printBytes(dev, bytes);
          return;
        }
      } catch (_) {}
    } else if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
      try {
        final bytes = await ThermalPrinterService.buildSeparadoRecibo(
            separado, empresaNombre: empresaNombre);
        await WindowsPrinterService.printRaw(bytes);
        return;
      } catch (_) {}
    }

    if (!context.mounted) return;
    await ReciboPdfService.imprimirSeparado(
        separado: separado, empresaNombre: empresaNombre);
  }
}
