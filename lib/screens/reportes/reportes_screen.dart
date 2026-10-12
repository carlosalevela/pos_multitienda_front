import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/reportes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/contabilidad_provider.dart';
import '../../providers/caja_provider.dart';
import '../../models/sesion_caja.dart';
import '../../services/caja_service.dart';
import '../../services/documento_service.dart';
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
  CajaProvider? _cajaEscuchado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
      // Escuchar cuando la caja se cierra para cargar la sesión automáticamente
      _cajaEscuchado = context.read<CajaProvider>()
        ..addListener(_onCajaCerrada);
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !context.read<ReportesProvider>().cargando) _cargar();
    });
  }

  @override
  void dispose() {
    _cajaEscuchado?.removeListener(_onCajaCerrada);
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Se dispara cada vez que CajaProvider notifica. Si la caja acaba de
  // cerrarse y estamos viendo hoy sin sesión cargada, la cargamos del API.
  void _onCajaCerrada() {
    if (!mounted) return;
    final caja = _cajaEscuchado!;
    if (_esHoy && !caja.cajaAbierta && !caja.cargando && _sesionHistorial == null) {
      _cargarSesionCerradaHoy();
    }
  }

  Future<void> _cargarSesionCerradaHoy() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.rol != 'cajero') return;
    final lista = await _cajaService.getHistorialSesiones(
      tiendaId:    auth.tiendaId,
      fecha:       _fechaStr,
      estado:      'cerrada',
      misSesiones: true,
    );
    if (mounted && lista.isNotEmpty) {
      setState(() => _sesionHistorial = SesionCaja.fromJson(lista.first));
    }
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
        } else {
          // Caja cerrada hoy: cargar la sesión del día para mostrar el resumen
          final lista = await _cajaService.getHistorialSesiones(
            tiendaId:    auth.tiendaId,
            fecha:       _fechaStr,
            estado:      'cerrada',
            misSesiones: true,
          );
          if (mounted && lista.isNotEmpty) {
            setState(() => _sesionHistorial = SesionCaja.fromJson(lista.first));
          }
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
    setState(() {
      _fecha = nueva;
      _sesionHistorial = null;
    });
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
        ? (caja.sesionActiva ?? _sesionHistorial)
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
                  : LayoutBuilder(
                      builder: (_, lbc) {
                        final contentW = lbc.maxWidth - 48;
                        return SingleChildScrollView(
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
                              _buildKPIRow(rep, totalGastos, caja, sesionCard, contentW),
                              const SizedBox(height: 16),
                              _buildMetaVenta(rep),
                              const SizedBox(height: 10),
                              _buildStatsChips(rep),
                              const SizedBox(height: 16),
                              _buildMetodosPago(rep),
                              const SizedBox(height: 24),
                              _buildMainGrid(rep, contab, contentW),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
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
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      // Date toggle
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kOutlineVar),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _shiftBtn('Hoy', _esHoy, () {
            setState(() => _fecha = DateTime.now());
            _cargar();
          }),
          _shiftBtn(
            _esHoy ? 'Otra fecha' : _fechaStr,
            !_esHoy,
            _seleccionarFecha,
          ),
        ]),
      ),
      const SizedBox(width: 8),
      // Refresh
      Tooltip(
        message: 'Actualizar',
        child: OutlinedButton(
          onPressed: rep.cargando ? null : _cargar,
          style: OutlinedButton.styleFrom(
            foregroundColor: _kOnSurfVar,
            side: BorderSide(color: _kOutlineVar),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(42, 42),
            maximumSize: const Size(42, 42),
            padding: EdgeInsets.zero,
          ),
          child: rep.cargando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kSecondary))
              : const Icon(Icons.refresh_rounded, size: 18),
        ),
      ),
    ]);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kOutlineVar)),
      ),
      child: LayoutBuilder(builder: (_, c) {
        final isNarrow = c.maxWidth < 560;
        if (isNarrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reporte de turno',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600, color: _kPrimary)),
            const SizedBox(height: 10),
            actions,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reporte de turno',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w600, color: _kPrimary)),
              const SizedBox(height: 2),
              Text('Revisa tus ventas del día y cierra tu turno.',
                  style: GoogleFonts.inter(fontSize: 13, color: _kOnSurfVar)),
            ]),
          ),
          const SizedBox(width: 16),
          actions,
        ]);
      }),
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
      ReportesProvider rep, double totalGastos, CajaProvider caja,
      SesionCaja? sesionCard, double availableWidth) {
    final sesion   = sesionCard;
    final ventas   = sesion?.ventasTotal ?? rep.totalDia;
    final gastos   = (_esHoy && caja.sesionActiva != null)
        ? caja.gastosTotalSesion
        : totalGastos;
    final esperado = sesion?.montoEsperado ?? 0.0;

    final cards = [
      _kpiCard('VENTAS DEL TURNO', '\$${fmtNum(ventas)}',
          Icons.trending_up_rounded, _kSecondary),
      _kpiCard('GASTOS DEL TURNO', '\$${fmtNum(gastos)}',
          Icons.payments_rounded, _kError),
      _kpiCard('ABONOS HOY', '\$${fmtNum(rep.totalAbonos)}',
          Icons.account_balance_wallet_rounded, const Color(0xFF76859B)),
      _kpiCard(
        'EFECTIVO ESPERADO',
        sesion != null ? '\$${fmtNum(esperado)}' : '—',
        Icons.check_circle_outline_rounded,
        _kSecondary,
        highlight: sesion != null,
      ),
    ];

    if (availableWidth < 700) {
      final cardW = (availableWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
      );
    }
    return Row(children: [
      Expanded(child: cards[0]),
      const SizedBox(width: 24),
      Expanded(child: cards[1]),
      const SizedBox(width: 24),
      Expanded(child: cards[2]),
      const SizedBox(width: 24),
      Expanded(child: cards[3]),
    ]);
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
    return Container(
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
    );
  }

  // ── Meta de ventas diaria ──────────────────────────────────

  Widget _buildMetaVenta(ReportesProvider rep) {
    final cfg  = context.watch<ConfigProvider>();
    final meta = cfg.metaVentaDiaria;

    // Si no hay meta configurada, mostrar solo el botón de configurar
    if (meta <= 0) {
      return GestureDetector(
        onTap: () => _editarMeta(cfg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            border: Border.all(color: _kOutlineVar, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: _kOnSurfVar),
              const SizedBox(width: 8),
              Text('Configurar meta de ventas del día',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _kOnSurfVar,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.add_rounded, size: 16, color: _kSecondary),
            ],
          ),
        ),
      );
    }

    final vendido  = rep.totalDia;
    final pct      = (vendido / meta).clamp(0.0, 1.0);
    final superada = vendido >= meta;
    final pctTexto = '${(pct * 100).toStringAsFixed(0)}%';

    final Color barColor;
    final Color bgColor;
    if (superada) {
      barColor = _kSecondary;
      bgColor  = _kSecondary.withValues(alpha: 0.06);
    } else if (pct >= 0.8) {
      barColor = const Color(0xFF0891B2);   // cyan
      bgColor  = const Color(0xFFE0F2FE);
    } else if (pct >= 0.5) {
      barColor = const Color(0xFFF59E0B);   // amber
      bgColor  = const Color(0xFFFEF3C7);
    } else {
      barColor = const Color(0xFFEF4444);   // red
      bgColor  = const Color(0xFFFEE2E2);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: barColor.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                superada ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 15,
                color: barColor,
              ),
              const SizedBox(width: 6),
              Text(
                superada ? '¡Meta alcanzada! 🎉' : 'Meta de ventas del día',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: barColor),
              ),
              const Spacer(),
              Text(pctTexto,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: barColor)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _editarMeta(cfg),
                child: Icon(Icons.edit_outlined, size: 15, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: barColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Vendido: \$${fmtNum(vendido)}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: barColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('Meta: \$${fmtNum(meta)}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: barColor.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editarMeta(ConfigProvider cfg) async {
    final ctrl = TextEditingController(
      text: cfg.metaVentaDiaria > 0
          ? cfg.metaVentaDiaria.toStringAsFixed(0)
          : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.flag_rounded, color: Color(0xFF006C49)),
          SizedBox(width: 8),
          Text('Meta de ventas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Cuánto quieres vender hoy?',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          if (cfg.metaVentaDiaria > 0)
            TextButton(
              onPressed: () => Navigator.pop(dCtx, 0.0),
              child: const Text('Quitar meta', style: TextStyle(color: Color(0xFFEF4444))),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v != null && v >= 0) Navigator.pop(dCtx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006C49),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await cfg.guardarMetaVentaDiaria(result);
    }
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
      ReportesProvider rep, ContabilidadProvider contab, double availableWidth) {
    final sidebar = Column(
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
    );

    if (availableWidth < 700) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSalesTable(rep),
          const SizedBox(height: 24),
          sidebar,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 8, child: _buildSalesTable(rep)),
        const SizedBox(width: 24),
        Expanded(flex: 4, child: sidebar),
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
    final created = v['created_at']?.toString() ?? '';
    String hora;
    if (created.isNotEmpty) {
      try {
        final dt = DateTime.parse(created).toLocal();
        hora = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        hora = created.length >= 19 ? created.substring(11, 16) : '--:--';
      }
    } else {
      hora = '--:--';
    }
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
                final cliente  = a['cliente_nombre']?.toString() ?? 'Cliente';
                final sepIdRaw = a['separado_id'];
                final sepId    = sepIdRaw is int
                    ? sepIdRaw
                    : int.tryParse(sepIdRaw?.toString() ?? '');
                final sepRef   = sepId != null
                    ? 'SEP-$sepId'
                    : 'Abono directo';
                final monto    = double.tryParse(
                        a['monto']?.toString() ?? '0') ?? 0;
                final metodo   = a['metodo_pago']?.toString() ?? 'efectivo';
                final emp      = a['empleado_nombre']?.toString() ?? '';
                final createdAt = a['created_at']?.toString();

                return _sideItem(
                  title:      cliente,
                  sub:        sepRef,
                  valueText:  '+\$${fmtNum(monto)}',
                  valueColor: _kSecondary,
                  onTap: () => _verDetalleAbono(
                    cliente:   cliente,
                    sepId:     sepId,
                    monto:     monto,
                    metodo:    metodo,
                    empNombre: emp,
                    createdAt: createdAt,
                  ),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _verDetalleAbono({
    required String  cliente,
    required int?    sepId,
    required double  monto,
    required String  metodo,
    required String  empNombre,
    required String? createdAt,
  }) async {
    List<File> recibos = [];
    if (sepId != null) {
      final todos = await DocumentoService.instance.listar(TipoDocumento.abono);
      recibos = todos.where((f) => f.path.contains('abono_${sepId}_')).toList();
    }

    if (!mounted) return;

    final metodoLabel = switch (metodo) {
      'tarjeta'       => 'Tarjeta',
      'transferencia' => 'Transferencia',
      _               => 'Efectivo',
    };

    String fechaStr = '—';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final h  = dt.hour.toString().padLeft(2, '0');
        final m  = dt.minute.toString().padLeft(2, '0');
        final meses = ['', 'Ene','Feb','Mar','Abr','May','Jun',
                            'Jul','Ago','Sep','Oct','Nov','Dic'];
        fechaStr = '${dt.day} ${meses[dt.month]} ${dt.year}, $h:$m';
      } catch (_) {}
    }

    final fmt = RegExp(r'(\d)(?=(\d{3})+(?!\d))');
    String fmtM(double v) =>
        v.toStringAsFixed(0).replaceAllMapped(fmt, (m) => '${m[1]},');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: EdgeInsets.zero,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFE8FFF4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _kSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detalle de abono',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: _kSecondary)),
                  if (sepId != null)
                    Text('SEP-$sepId',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: _kSecondary)),
                ],
              )),
              Text('\$${fmtM(monto)}',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: _kSecondary)),
            ]),
          ),
          // Cuerpo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(children: [
              _detalleAbonoRow(Icons.person_outline_rounded,  'Cliente',  cliente),
              _detalleAbonoRow(Icons.credit_card_outlined,   'Método',   metodoLabel),
              _detalleAbonoRow(Icons.schedule_rounded,       'Fecha',    fechaStr),
              if (empNombre.isNotEmpty)
                _detalleAbonoRow(Icons.badge_outlined,       'Empleado', empNombre),
            ]),
          ),
          // Botón PDF
          if (recibos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity, height: 44,
                child: ElevatedButton.icon(
                  icon:  const Icon(Icons.picture_as_pdf_rounded, size: 17),
                  label: Text(
                    recibos.length == 1
                        ? 'Ver recibo PDF'
                        : 'Ver ${recibos.length} recibos PDF',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (recibos.length == 1) {
                      await Process.run('cmd', ['/c', 'start', '', recibos.first.path]);
                    } else {
                      await _abrirListaRecibos(recibos, sepId!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kSecondary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('Sin recibo PDF guardado',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: _kOutline,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
            ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cerrar',
                style: GoogleFonts.inter(color: _kOutline)),
          ),
        ],
      ),
    );
  }

  Widget _detalleAbonoRow(IconData icon, String label, String valor) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 15, color: _kOutline),
          const SizedBox(width: 8),
          Text('$label:',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _kOutline,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(valor,
                style: GoogleFonts.inter(
                    fontSize: 12, color: _kOnSurface,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  Future<void> _abrirListaRecibos(List<File> recibos, int sepId) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Recibos SEP-$sepId',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 320,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount:  recibos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final f   = recibos[i];
              final mod = f.lastModifiedSync().toLocal();
              final h   = mod.hour.toString().padLeft(2, '0');
              final m   = mod.minute.toString().padLeft(2, '0');
              final ts  = '${mod.day}/${mod.month}/${mod.year} $h:$m';
              return ListTile(
                dense: true,
                leading: const Icon(Icons.picture_as_pdf_rounded,
                    color: Color(0xFF006C49), size: 20),
                title: Text('Abono ${i + 1}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(ts,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _kOutline)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Process.run('cmd', ['/c', 'start', '', f.path]);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cerrar',
                style: GoogleFonts.inter(color: _kOutline)),
          ),
        ],
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
    required String   title,
    required String   sub,
    required String   valueText,
    required Color    valueColor,
    VoidCallback?     onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 14,
                color: Color(0xFFC6C6CD)),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
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
