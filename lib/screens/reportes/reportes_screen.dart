import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/reportes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contabilidad_provider.dart';
import '../../providers/caja_provider.dart';
import '../../models/sesion_caja.dart';
import '../../services/caja_service.dart';
import '../../services/venta_service.dart';
import 'widgets/reporte_detalle_dialog.dart';
import 'widgets/reporte_turno_card.dart';
import 'widgets/reporte_utils.dart';

// ── Design-system tokens (DESIGN.md) ──────────────────────
const _kPrimary     = Color(0xFF000000);
const _kSecondary   = Color(0xFF006C49);
const _kSecCont     = Color(0xFF6CF8BB);
const _kOnSecCont   = Color(0xFF00714D);
const _kSurface     = Color(0xFFF7F9FB);
const _kSurfLow     = Color(0xFFF2F4F6);
const _kSurfCont    = Color(0xFFECEEF0);
const _kSurfHigh    = Color(0xFFE6E8EA);
const _kOnSurface   = Color(0xFF191C1E);
const _kOnSurfVar   = Color(0xFF45464D);
const _kOutline     = Color(0xFF76777D);
const _kOutlineVar  = Color(0xFFC6C6CD);
const _kError       = Color(0xFFBA1A1A);

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  DateTime _fecha = DateTime.now();
  final _ventaService = VentaService();
  final _cajaService  = CajaService();
  SesionCaja? _sesionHistorial;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _cargar();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final caja = context.read<CajaProvider>();

    // Ventas y gastos contabilidad se cargan en paralelo
    context.read<ReportesProvider>().cargarVentas(
      tiendaId: auth.tiendaId,
      fecha: _fechaStr,
    );
    context.read<ContabilidadProvider>().cargarGastos(
      tiendaId: auth.tiendaId,
      fecha: _fechaStr,
    );
    // Para hoy: refresca la sesión activa y carga gastos en vivo.
    // Para fechas pasadas: carga la sesión cerrada de ese día desde historial.
    if (auth.rol == 'cajero') {
      if (_esHoy) {
        _sesionHistorial = null;
        await caja.verificarSesion(auth.tiendaId);
        if (!mounted) return;
        if (caja.sesionActiva != null) {
          caja.cargarGastosSesion(caja.sesionActiva!.id);
        }
      } else {
        final lista = await _cajaService.getHistorialSesiones(
          tiendaId:    auth.tiendaId,
          fecha:       _fechaStr,
          estado:      'cerrada',
          misSesiones: true,
        );
        if (mounted) {
          setState(() {
            _sesionHistorial = lista.isNotEmpty
                ? SesionCaja.fromJson(lista.first)
                : null;
          });
        }
      }
    }
  }

  String get _fechaStr =>
      '${_fecha.year}-'
      '${_fecha.month.toString().padLeft(2, '0')}-'
      '${_fecha.day.toString().padLeft(2, '0')}';

  bool get _esHoy {
    final n = DateTime.now();
    return _fecha.year == n.year &&
        _fecha.month == n.month &&
        _fecha.day == n.day;
  }

  Future<void> _seleccionarFecha() async {
    final nueva = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (nueva == null || !mounted) return;
    setState(() => _fecha = nueva);
    _cargar();
  }

  Future<void> _abrirDetalle(BuildContext ctx, int ventaId) async {
    try {
      final detalle = await _ventaService.obtenerVenta(ventaId);
      if (!ctx.mounted || detalle == null) return;
      showDialog(
        context: ctx,
        builder: (_) => ReporteDetalleDialog(detalle: detalle),
      );
    } catch (_) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('Error al cargar el detalle de la venta'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rep      = context.watch<ReportesProvider>();
    final auth     = context.watch<AuthProvider>();
    final caja     = context.watch<CajaProvider>();
    final contab   = context.watch<ContabilidadProvider>();
    final esCajero = auth.rol == 'cajero';
    final sesionCard = esCajero
        ? (_esHoy
            ? (caja.sesionActiva ?? caja.ultimaSesionCerrada)
            : _sesionHistorial)
        : null;

    final totalGastos =
        contab.gastos.fold(0.0, (s, g) => s + g.monto);

    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(rep, auth, contab),
            Expanded(
              child: rep.cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: _kSecondary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sesionCard != null) ...[
                            ReporteTurnoCard(
                              sesion:        sesionCard,
                              fecha:         _fechaStr,
                              tiendaNombre:  auth.tiendaNombre,
                              empresaNombre: auth.empresaNombre,
                              cajaAbierta:   _esHoy && caja.sesionActiva != null,
                            ),
                            const SizedBox(height: 24),
                          ],
                          _buildKPIRow(rep, totalGastos, caja),
                          const SizedBox(height: 10),
                          _buildStatsChips(rep),
                          const SizedBox(height: 16),
                          _buildMetodosPago(rep),
                          const SizedBox(height: 24),
                          _buildMainGrid(rep, contab),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(
    ReportesProvider rep,
    AuthProvider auth,
    ContabilidadProvider contab,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kOutlineVar)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reporte de turno',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _kPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Revisa tus ventas del día y cierra tu turno.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _kOnSurfVar),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Date toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _kOutlineVar),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _shiftBtn('Hoy', _esHoy, () {
                  setState(() => _fecha = DateTime.now());
                  _cargar();
                }),
                _shiftBtn(
                  _esHoy ? 'Otra fecha' : _fechaStr,
                  !_esHoy,
                  _seleccionarFecha,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Refresh
          Tooltip(
            message: 'Actualizar',
            child: OutlinedButton(
              onPressed: rep.cargando ? null : _cargar,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOnSurfVar,
                side: BorderSide(color: _kOutlineVar),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(42, 42),
                maximumSize: const Size(42, 42),
                padding: EdgeInsets.zero,
              ),
              child: rep.cargando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kSecondary))
                  : const Icon(Icons.refresh_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kSecondary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _kOnSurfVar,
          ),
        ),
      ),
    );
  }

  // ── KPI Row ────────────────────────────────────────────────

  Widget _buildKPIRow(
      ReportesProvider rep, double totalGastos, CajaProvider caja) {
    // Para hoy usamos datos de la sesión activa (datos frescos del turno).
    // Para fechas pasadas usamos los totales del provider (correctos para ese día).
    final sesion = _esHoy ? caja.sesionActiva : null;
    final ventas   = sesion != null ? sesion.ventasTotal      : rep.totalDia;
    final gastos   = sesion != null ? caja.gastosTotalSesion  : totalGastos;
    final esperado = sesion?.montoEsperado ?? 0.0;

    return Row(
      children: [
        _kpiCard(
          'VENTAS DEL TURNO',
          '\$${fmtNum(ventas)}',
          Icons.trending_up_rounded,
          _kSecondary,
        ),
        const SizedBox(width: 24),
        _kpiCard(
          'GASTOS DEL TURNO',
          '\$${fmtNum(gastos)}',
          Icons.payments_rounded,
          _kError,
        ),
        const SizedBox(width: 24),
        _kpiCard(
          'ABONOS HOY',
          '\$${fmtNum(rep.totalAbonos)}',
          Icons.account_balance_wallet_rounded,
          const Color(0xFF76859B),
        ),
        const SizedBox(width: 24),
        _kpiCard(
          'EFECTIVO ESPERADO',
          sesion != null ? '\$${fmtNum(esperado)}' : '—',
          Icons.check_circle_outline_rounded,
          _kSecondary,
          highlight: sesion != null,
        ),
      ],
    );
  }

  Widget _buildMetodosPago(ReportesProvider rep) {
    final metodos = rep.totalPorMetodo;
    if (metodos.isEmpty) return const SizedBox.shrink();

    final total = metodos.values.fold(0.0, (s, v) => s + v);

    return Row(
      children: metodos.entries.map((e) {
        final pct = total == 0 ? 0.0 : e.value / total * 100;

        Color bg;
        Color fg;
        switch (e.key.toLowerCase()) {
          case 'efectivo':
            bg = _kSurfHigh; fg = _kOnSurfVar;
            break;
          case 'transferencia':
            bg = const Color(0xFFD5E3FD); fg = const Color(0xFF0D1C2F);
            break;
          case 'tarjeta':
          case 'credito':
            bg = _kSecCont; fg = _kOnSecCont;
            break;
          default:
            bg = _kSurfCont; fg = _kOutline;
        }

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
                right: e.key == metodos.keys.last ? 0 : 12),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg.withValues(alpha: 0.5),
              border: Border.all(
                  color: bg.withValues(alpha: 0.8)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(iconMetodo(e.key), color: fg, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labelMetodo(e.key),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: fg)),
                      Text('\$${fmtNum(e.value)}',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: fg)),
                    ],
                  ),
                ),
                Text('${pct.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg.withValues(alpha: 0.6))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _kpiCard(
    String label, String value, IconData icon, Color iconColor, {
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        height: 128,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: highlight
              ? _kSecondary.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.85),
          border: Border.all(
              color: highlight ? _kSecondary : _kOutlineVar),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: highlight ? _kSecondary : _kOutline,
                          letterSpacing: 0.08)),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: iconColor, size: 20),
              ],
            ),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: highlight ? _kSecondary : _kOnSurface)),
          ],
        ),
      ),
    );
  }

  // ── Stats chips (ventas, ticket promedio, anuladas) ────────

  Widget _buildStatsChips(ReportesProvider rep) {
    if (rep.totalVentas == 0 && rep.totalAnuladas == 0) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (rep.totalVentas > 0)
          _statChip(
            Icons.point_of_sale_rounded,
            '${rep.totalVentas} venta${rep.totalVentas != 1 ? "s" : ""}',
            _kSecondary,
          ),
        if (rep.totalVentas > 0)
          _statChip(
            Icons.receipt_long_rounded,
            'Ticket prom: \$${fmtNum(rep.ticketPromedio)}',
            _kOnSurfVar,
          ),
        if (rep.totalAnuladas > 0)
          _statChip(
            Icons.cancel_outlined,
            '${rep.totalAnuladas} anulada${rep.totalAnuladas != 1 ? "s" : ""}',
            _kError,
          ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  // ── Main grid ──────────────────────────────────────────────

  Widget _buildMainGrid(
      ReportesProvider rep, ContabilidadProvider contab) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 8, child: _buildSalesTable(rep)),
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildExpensesSidebar(contab),
              const SizedBox(height: 24),
              _buildDepositsSidebar(rep),
              if (rep.topProductos.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildTopProductosSidebar(rep),
              ],
              if (rep.numDevoluciones > 0) ...[
                const SizedBox(height: 24),
                _buildDevolucionesSidebar(rep),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Sales table ────────────────────────────────────────────

  Widget _buildSalesTable(ReportesProvider rep) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: _kOutlineVar),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _kSurfLow,
              border: Border(bottom: BorderSide(color: _kOutlineVar)),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ventas del día',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _kPrimary)),
                Text(
                  '${rep.totalVentas} ventas',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kSecondary),
                ),
              ],
            ),
          ),
          // Column headers
          Container(
            color: _kSurfCont,
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _tableHeader('FACTURA', flex: 2),
                _tableHeader('HORA', flex: 2),
                _tableHeader('CLIENTE', flex: 3),
                _tableHeader('PAGO', flex: 2),
                _tableHeader('MONTO', flex: 2,
                    align: TextAlign.right),
              ],
            ),
          ),
          // Rows
          if (rep.ventas.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48, color: _kOutlineVar),
                  const SizedBox(height: 12),
                  Text('Sin ventas para esta fecha',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _kOutline)),
                  const SizedBox(height: 4),
                  Text('Las ventas del turno aparecerán aquí',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _kOutlineVar)),
                ],
              ),
            )
          else
            ...rep.ventas.map((v) => _saleRow(v)),
        ],
      ),
    );
  }

  Widget _tableHeader(String text,
      {int flex = 1, TextAlign align = TextAlign.left}) =>
      Expanded(
        flex: flex,
        child: Text(text,
            textAlign: align,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _kOutline,
                letterSpacing: 0.1)),
      );

  Widget _saleRow(Map<String, dynamic> v) {
    final esAnulada = v['estado'] == 'anulada';
    final created   = v['created_at']?.toString() ?? '';
    final hora      = created.length >= 19
        ? created.substring(11, 16) : '--:--';
    final metodo    = v['metodo_pago']?.toString() ?? '';
    final total     = double.tryParse(
        v['total']?.toString() ?? '0') ?? 0;
    final factura   = v['numero_factura']?.toString() ?? '#--';
    final cliente   = v['cliente_nombre']?.toString()
        ?? 'Consumidor Final';
    final id        = v['id'];

    return InkWell(
      onTap: id != null
          ? () => _abrirDetalle(context, id as int)
          : null,
      hoverColor: const Color(0xFFF7F9FB),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: esAnulada
              ? const Color(0xFFFFF5F5) : null,
          border: Border(
              bottom: BorderSide(
                  color: _kOutlineVar, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(factura,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary)),
            ),
            Expanded(
              flex: 2,
              child: Text(hora,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: _kOnSurfVar)),
            ),
            Expanded(
              flex: 3,
              child: Text(cliente,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kOnSurface)),
            ),
            Expanded(
              flex: 2,
              child: _paymentChip(metodo),
            ),
            Expanded(
              flex: 2,
              child: Text('\$${fmtNum(total)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentChip(String metodo) {
    Color bg;
    Color fg;
    switch (metodo.toLowerCase()) {
      case 'efectivo':
        bg = _kSurfHigh;
        fg = _kOnSurfVar;
        break;
      case 'transferencia':
        bg = const Color(0xFFD5E3FD);
        fg = const Color(0xFF0D1C2F);
        break;
      case 'tarjeta':
      case 'credito':
        bg = _kSecCont;
        fg = _kOnSecCont;
        break;
      default:
        bg = _kSurfCont;
        fg = _kOutline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        metodo.isEmpty ? 'N/A' : metodo.toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg),
      ),
    );
  }

  // ── Top productos sidebar ──────────────────────────────────

  Widget _buildTopProductosSidebar(ReportesProvider rep) {
    final top = rep.topProductos;
    if (top.isEmpty) return const SizedBox.shrink();
    final maxSub = (top.first['subtotal'] as double);

    return _sideCard(
      title: 'TOP PRODUCTOS',
      trailingIcon: Icons.bar_chart_rounded,
      trailingColor: _kSecondary,
      child: Column(
        children: top.asMap().entries.map((entry) {
          final i       = entry.key;
          final p       = entry.value;
          final nombre  = p['nombre']?.toString() ?? '';
          final cant    = (p['cantidad'] as double).toStringAsFixed(0);
          final sub     = p['subtotal'] as double;
          final pct     = maxSub == 0 ? 0.0 : sub / maxSub;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == 0 ? _kSecondary : _kSurfCont,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${i + 1}',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: i == 0 ? Colors.white : _kOutline)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(nombre,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _kOnSurface)),
                    ),
                    const SizedBox(width: 8),
                    Text('\$${fmtNum(sub)}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kOnSurface)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 26),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: _kSurfCont,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? _kSecondary
                                    : _kOnSurfVar.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('×$cant',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kOutline)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Expenses sidebar ───────────────────────────────────────

  Widget _buildExpensesSidebar(ContabilidadProvider contab) {
    return _sideCard(
      title: 'GASTOS DE HOY',
      trailingIcon: Icons.remove_circle_outline_rounded,
      trailingColor: _kError,
      child: contab.gastos.isEmpty
          ? _emptySideMsg('Sin gastos registrados')
          : Column(
              children: contab.gastos
                  .map((g) => _sideItem(
                        title: g.descripcion,
                        sub: g.categoria.toUpperCase(),
                        valueText: '-\$${fmtNum(g.monto)}',
                        valueColor: _kError,
                      ))
                  .toList(),
            ),
    );
  }

  // ── Deposits sidebar ───────────────────────────────────────

  Widget _buildDepositsSidebar(ReportesProvider rep) {
    return _sideCard(
      title: 'ABONOS DE HOY',
      trailingIcon: Icons.add_circle_outline_rounded,
      trailingColor: _kSecondary,
      child: rep.abonos.isEmpty
          ? _emptySideMsg('Sin depósitos hoy')
          : Column(
              children: rep.abonos.take(6).map((a) {
                final cliente = a['cliente_nombre']
                        ?.toString() ??
                    'Cliente';
                final sepId =
                    a['separado_id']?.toString() ?? '--';
                final monto = double.tryParse(
                        a['monto']?.toString() ?? '0') ??
                    0;
                return _sideItem(
                  title: cliente,
                  sub: 'REF: #SEP-$sepId',
                  valueText: '+\$${fmtNum(monto)}',
                  valueColor: _kSecondary,
                );
              }).toList(),
            ),
    );
  }

  Widget _sideCard({
    required String title,
    required IconData trailingIcon,
    required Color trailingColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: _kOutlineVar),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _kSurfLow,
              border: Border(
                  bottom: BorderSide(color: _kOutlineVar)),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kPrimary,
                        letterSpacing: 0.05)),
                Icon(trailingIcon,
                    color: trailingColor, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _sideItem({
    required String title,
    required String sub,
    required String valueText,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _kOnSurface)),
                Text(sub,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kOutline,
                        letterSpacing: 0.05)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(valueText,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
        ],
      ),
    );
  }

  Widget _emptySideMsg(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(msg,
            style: GoogleFonts.inter(
                fontSize: 13, color: _kOutline)),
      );

  // ── Devoluciones sidebar ───────────────────────────────────

  Widget _buildDevolucionesSidebar(ReportesProvider rep) {
    final total = rep.totalDevoluciones;

    return _sideCard(
      title: 'DEVOLUCIONES',
      trailingIcon: Icons.assignment_return_rounded,
      trailingColor: _kError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rep.devoluciones
              .where((d) =>
                  (d['estado']?.toString().toLowerCase() ?? '') !=
                  'cancelada')
              .take(5)
              .map((d) {
            final factura = d['venta_numero']?.toString() ??
                'DEV-${d['id']}';
            final tipo    = d['tipo']?.toString() ?? '';
            final devTotal = double.tryParse(
                    d['total_devuelto']?.toString() ?? '0') ??
                0;
            final esDevolucion = tipo == 'devolucion';
            final label = esDevolucion ? 'Devolución' : 'Cambio';
            final labelColor =
                esDevolucion ? _kError : const Color(0xFFF57C00);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(factura,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kOnSurface)),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: labelColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(label,
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: labelColor,
                                  letterSpacing: 0.05)),
                        ),
                      ],
                    ),
                  ),
                  Text('-\$${fmtNum(devTotal)}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kError)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(height: 1, color: _kOutlineVar),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total devuelto',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kOutline)),
              Text('-\$${fmtNum(total)}',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kError)),
            ],
          ),
        ],
      ),
    );
  }

}
