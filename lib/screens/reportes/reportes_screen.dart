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
import '../../services/cliente_service.dart';
import '../../services/recibo_pdf_service.dart';
import '../../models/separado.dart';
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
    final r = await _cajaService.getHistorialSesiones(
      tiendaId:    auth.tiendaId,
      fecha:       _fechaStr,
      estado:      'cerrada',
      misSesiones: true,
    );
    final lista = r['items'] as List<Map<String, dynamic>>;
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
    // Recarga separadosDia, abonosDia y topProductos para la fecha seleccionada
    context.read<ContabilidadProvider>().cargarResumenDiario(
      tiendaId: auth.tiendaId,
      fecha: _fecha,
    );
    context.read<ContabilidadProvider>().cargarTopProductos(
      tiendaId: auth.tiendaId,
      fechaIni: _fecha,
      fechaFin: _fecha,
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
          final r2 = await _cajaService.getHistorialSesiones(
            tiendaId:    auth.tiendaId,
            fecha:       _fechaStr,
            estado:      'cerrada',
            misSesiones: true,
          );
          final lista2 = r2['items'] as List<Map<String, dynamic>>;
          if (mounted && lista2.isNotEmpty) {
            setState(() => _sesionHistorial = SesionCaja.fromJson(lista2.first));
          }
        }
      } else {
        final r3 = await _cajaService.getHistorialSesiones(
          tiendaId:    auth.tiendaId,
          fecha:       _fechaStr,
          estado:      'cerrada',
          misSesiones: true,
        );
        final lista3 = r3['items'] as List<Map<String, dynamic>>;
        if (mounted) {
          setState(() {
            _sesionHistorial = lista3.isNotEmpty
                ? SesionCaja.fromJson(lista3.first)
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
        ? (_esHoy ? (caja.sesionActiva ?? _sesionHistorial) : _sesionHistorial)
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
            // Banner de error sutil cuando hay datos cargados pero el refresh falló
            if (rep.errorMsg.isNotEmpty && rep.ventas.isNotEmpty)
              Material(
                color: const Color(0xFFFFEDEA),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 15, color: _kError),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Sin conexión — mostrando datos anteriores',
                        style: GoogleFonts.inter(fontSize: 12, color: _kError))),
                    TextButton(
                      onPressed: _cargar,
                      style: TextButton.styleFrom(
                        foregroundColor: _kError,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Reintentar',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            Expanded(
              child: (rep.cargando && rep.ventas.isEmpty)
                  ? const Center(
                      child: CircularProgressIndicator(color: _kSecondary))
                  : (rep.errorMsg.isNotEmpty && rep.ventas.isEmpty)
                      ? _buildErrorState()
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
                              const SizedBox(height: 14),
                              _buildCuentasBreakdown(rep),
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

  // ── Desglose por cuenta bancaria ──────────────────────────
  //
  // "Por método de pago" junta todas las transferencias en un solo balde,
  // así que no deja ver cuánto entró específicamente a Nequi. Esto lo
  // separa cuenta por cuenta. El efectivo no tiene cuenta y no aparece.
  Widget _buildCuentasBreakdown(ReportesProvider rep) {
    final cuentas = rep.totalPorCuenta;
    if (cuentas.isEmpty) return const SizedBox.shrink();

    final total =
        cuentas.fold<double>(0, (t, c) => t + (c['total'] as double));

    Color colorTipo(String tipo) => switch (tipo) {
          'nequi' => const Color(0xFF7C3AED),
          'daviplata' => const Color(0xFFDC2626),
          'tarjeta' => const Color(0xFF0EA5E9),
          _ => _kSecondary,
        };

    IconData iconTipo(String tipo) => switch (tipo) {
          'tarjeta' => Icons.credit_card_rounded,
          'nequi' || 'daviplata' => Icons.phone_android_rounded,
          _ => Icons.account_balance_rounded,
        };

    String labelTipo(String tipo) => switch (tipo) {
          'nequi' => 'Nequi',
          'daviplata' => 'DaviPlata',
          'tarjeta' => 'Datáfono',
          'transferencia' => 'Transferencia',
          _ => 'Cuenta',
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 14, color: _kOnSurfVar),
          const SizedBox(width: 6),
          Text('Por cuenta',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kOnSurfVar)),
          const SizedBox(width: 8),
          Text('el efectivo no entra aquí',
              style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.grey.shade400)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cuentas.map((c) {
            final nombre = c['nombre'] as String;
            final tipo = c['tipo'] as String;
            final monto = c['total'] as double;
            final movs = c['movimientos'] as int;
            final pct = total == 0 ? 0.0 : monto / total * 100;
            final col = colorTipo(tipo);

            return Container(
              width: 196,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: col.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Icon(iconTipo(tipo), size: 18, color: col),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: col)),
                      Text('\$${fmtNum(monto)}',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: col)),
                      Text('${labelTipo(tipo)} · $movs mov.',
                          style: GoogleFonts.inter(
                              fontSize: 9.5,
                              color: col.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                Text('${pct.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: col.withValues(alpha: 0.6))),
              ]),
            );
          }).toList(),
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

  // ── Error state ────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDEA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kError.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 36, color: _kError),
            ),
            const SizedBox(height: 16),
            Text('Sin conexión con el servidor',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: _kPrimary)),
            const SizedBox(height: 6),
            Text('El servidor puede estar reiniciándose.\nEspera un momento e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: _kOnSurfVar, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Reintentar',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kSecondary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
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
    final metodo        = v['metodo_pago']?.toString() ?? '';
    final cuentaNombre  = v['cuenta_destino_nombre']?.toString();
    final cuentaTipo    = v['cuenta_destino_tipo']?.toString();
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
              child: _paymentChip(metodo,
                  cuentaNombre: cuentaNombre,
                  cuentaTipo: cuentaTipo),
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

  Widget _paymentChip(String metodo, {String? cuentaNombre, String? cuentaTipo}) {
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
    final chip = Container(
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

    if (cuentaNombre == null) return chip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        chip,
        const SizedBox(height: 3),
        Text(
          cuentaTipo != null ? '$cuentaNombre · $cuentaTipo' : cuentaNombre,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _kOnSurfVar),
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
                    cliente:      cliente,
                    sepId:        sepId,
                    monto:        monto,
                    metodo:       metodo,
                    empNombre:    emp,
                    createdAt:    createdAt,
                    cuentaNombre: a['cuenta_nombre']?.toString(),
                    cuentaTipo:   a['cuenta_tipo']?.toString(),
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Detalle de abono: datos + recibo ──────────────────────
  //
  // Dos columnas: a la izquierda los datos del abono y el estado del
  // separado, a la derecha una vista del recibo que se arma con los datos
  // (no depende de que exista un PDF guardado).
  Future<void> _verDetalleAbono({
    required String  cliente,
    required int?    sepId,
    required double  monto,
    required String  metodo,
    required String  empNombre,
    required String? createdAt,
    String?          cuentaNombre,
    String?          cuentaTipo,
  }) async {
    // Recibos ya guardados para este separado.
    List<File> recibos = [];
    if (sepId != null) {
      final todos = await DocumentoService.instance.listar(TipoDocumento.abono);
      recibos = todos.where((f) => f.path.contains('abono_${sepId}_')).toList();
    }

    // Estado actual del separado (para la barra de progreso).
    Separado? sep;
    if (sepId != null) {
      try {
        sep = await ClienteService().getSeparado(sepId);
      } catch (_) {}
    }

    if (!mounted) return;

    String fechaStr = '—';
    String horaStr  = '—';
    String fechaCorta = '—';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final h  = dt.hour.toString().padLeft(2, '0');
        final m  = dt.minute.toString().padLeft(2, '0');
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        const meses = ['', 'Ene','Feb','Mar','Abr','May','Jun',
                           'Jul','Ago','Sep','Oct','Nov','Dic'];
        fechaStr   = '${dt.day} ${meses[dt.month]} ${dt.year}, $h:$m';
        horaStr    = '$h:$m';
        fechaCorta = '$dd/$mm/${dt.year}';
      } catch (_) {}
    }

    final fmtR = RegExp(r'(\d)(?=(\d{3})+(?!\d))');
    String fmtM(double v) =>
        v.toStringAsFixed(0).replaceAllMapped(fmtR, (m) => '${m[1]}.');

    final metodoLabel = switch (metodo) {
      'tarjeta'       => 'Tarjeta',
      'transferencia' => 'Transferencia',
      _               => 'Efectivo',
    };

    final tipoLabel = switch (cuentaTipo) {
      'nequi'     => 'Nequi',
      'daviplata' => 'DaviPlata',
      'tarjeta'   => 'Datáfono',
      _           => 'Cuenta',
    };
    final tipoColor = switch (cuentaTipo) {
      'nequi'     => const Color(0xFF7C3AED),
      'daviplata' => const Color(0xFFDC2626),
      'tarjeta'   => const Color(0xFF0EA5E9),
      _           => _kSecondary,
    };

    final total    = sep?.total ?? 0;
    final abonado  = sep?.abonoAcumulado ?? 0;
    final saldo    = sep?.saldoPendiente ?? 0;
    final progreso = total > 0 ? (abonado / total).clamp(0.0, 1.0) : 0.0;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final ancho = MediaQuery.of(ctx).size.width;
        final compacto = ancho < 760;

        Widget fila(IconData ic, String label, Widget valor) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(ic, size: 16, color: _kOutline),
                const SizedBox(width: 9),
                SizedBox(
                  width: 68,
                  child: Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: _kOutline)),
                ),
                Expanded(child: valor),
              ]),
            );

        Widget texto(String v) => Text(v,
            style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _kOnSurface));

        // ── Columna izquierda ──────────────────────────
        final panelDatos = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _kSecondary.withValues(alpha: 0.12),
                child: Text(
                  cliente.trim().isEmpty ? '?' : cliente.trim()[0].toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kSecondary),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(cliente,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kOnSurface)),
              ),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            fila(Icons.payments_outlined, 'Método',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: texto(metodoLabel)),
                      if (cuentaTipo != null && cuentaTipo.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tipoColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: tipoColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(tipoLabel,
                              style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: tipoColor)),
                        ),
                      ],
                    ]),
                    if (cuentaNombre != null && cuentaNombre.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(cuentaNombre,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _kOutline)),
                      ),
                  ],
                )),
            fila(Icons.schedule_rounded, 'Fecha', texto(fechaStr)),
            if (empNombre.isNotEmpty)
              fila(Icons.badge_outlined, 'Atendió', texto(empNombre)),

            if (sep != null) ...[
              const SizedBox(height: 4),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(children: [
                Text('ESTADO DEL SEPARADO',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _kOutline)),
                const Spacer(),
                Text('${(progreso * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kSecondary)),
              ]),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progreso.toDouble(),
                  minHeight: 7,
                  backgroundColor: _kSurfCont,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_kSecondary),
                ),
              ),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(
                    child: _miniDato('Total', '\$${fmtM(total)}',
                        _kOnSurface, _kSurfLow, _kOutlineVar)),
                const SizedBox(width: 7),
                Expanded(
                    child: _miniDato('Abonado', '\$${fmtM(abonado)}',
                        _kSecondary, const Color(0xFFE8FFF4),
                        _kSecondary.withValues(alpha: 0.25))),
                const SizedBox(width: 7),
                Expanded(
                    child: _miniDato('Saldo', '\$${fmtM(saldo)}',
                        const Color(0xFFB45309), const Color(0xFFFFFBEB),
                        const Color(0xFFFDE68A))),
              ]),
            ],
          ],
        );

        // ── Columna derecha: el recibo ─────────────────
        TextStyle mono(double size, {bool bold = false, Color? color}) =>
            GoogleFonts.robotoMono(
                fontSize: size,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: color ?? _kOnSurface,
                height: 1.6);

        Widget lineaRecibo(String izq, String der, {bool bold = false}) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(izq, style: mono(10, bold: bold)),
                Text(der, style: mono(10, bold: bold)),
              ],
            );

        Widget sep2() => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text('--------------------------------',
                  style: mono(9.5, color: _kOutline), maxLines: 1),
            );

        final panelRecibo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text('RECIBO',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: _kOutline)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kOutlineVar),
                ),
                child: Text('80 mm',
                    style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: _kOutline)),
              ),
            ]),
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 268),
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kOutlineVar),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text('RECIBO DE ABONO',
                          style: mono(11, bold: true)),
                    ),
                    sep2(),
                    lineaRecibo('Separado:',
                        sepId != null ? 'SEP-$sepId' : '—', bold: true),
                    lineaRecibo('Fecha:', fechaCorta),
                    lineaRecibo('Hora:', horaStr),
                    lineaRecibo('Metodo:', metodoLabel),
                    if (cuentaNombre != null && cuentaNombre.isNotEmpty)
                      lineaRecibo('Cuenta:', cuentaNombre),
                    sep2(),
                    Text('CLIENTE', style: mono(10, bold: true)),
                    Text(cliente.toUpperCase(), style: mono(10)),
                    sep2(),
                    lineaRecibo('ESTE ABONO:', '\$${fmtM(monto)}',
                        bold: true),
                    if (sep != null) ...[
                      sep2(),
                      Text('Estado actual del separado',
                          style: mono(8.5, color: _kOutline)),
                      lineaRecibo('Total:', '\$${fmtM(total)}'),
                      lineaRecibo('Abonado:', '\$${fmtM(abonado)}'),
                      lineaRecibo('Saldo:', '\$${fmtM(saldo)}', bold: true),
                    ],
                    sep2(),
                    Center(
                      child: Text(
                          empNombre.isEmpty
                              ? 'Gracias por su compra'
                              : 'Atendio: $empNombre\nGracias por su compra',
                          textAlign: TextAlign.center,
                          style: mono(8.5, color: _kOutline)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Icon(recibos.isEmpty ? Icons.info_outline : Icons.cloud_done,
                  size: 15,
                  color: recibos.isEmpty ? _kOutline : _kSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  recibos.isEmpty
                      ? 'Sin PDF guardado · se puede generar ahora'
                      : 'Guardado en esta PC y en el servidor',
                  style: GoogleFonts.inter(
                      fontSize: 10.5, color: _kOutline, height: 1.3),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: sep == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _generarPdfAbono(sep!, monto, metodo);
                        },
                  icon: Icon(
                      recibos.isEmpty
                          ? Icons.picture_as_pdf_outlined
                          : Icons.open_in_new_rounded,
                      size: 16),
                  label: Text(recibos.isEmpty ? 'Generar PDF' : 'Abrir PDF',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kSecondary,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (recibos.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (recibos.length == 1) {
                      await Process.run(
                          'cmd', ['/c', 'start', '', recibos.first.path]);
                    } else {
                      await _abrirListaRecibos(recibos, sepId!);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    side: const BorderSide(color: _kOutlineVar),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('${recibos.length}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kOnSurface)),
                ),
              ],
            ]),
          ],
        );

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: compacto ? 400 : 780,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8FFF4),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kSecondary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detalle de abono',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _kSecondary)),
                          Text(
                              sepId != null
                                  ? 'SEP-$sepId'
                                  : 'Abono directo',
                              style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: _kOnSecCont.withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('ESTE ABONO',
                            style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: _kOnSecCont.withValues(alpha: 0.6))),
                        Text('\$${fmtM(monto)}',
                            style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: _kSecondary)),
                      ],
                    ),
                  ]),
                ),

                // Cuerpo
                if (compacto)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      panelDatos,
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      panelRecibo,
                    ]),
                  )
                else
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 105,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: panelDatos,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 95,
                          child: Container(
                            color: _kSurface,
                            padding: const EdgeInsets.all(20),
                            child: panelRecibo,
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cerrar',
                  style: GoogleFonts.inter(color: _kOutline)),
            ),
          ],
        );
      },
    );
  }

  Widget _miniDato(String label, String valor, Color fg, Color bg, Color bd) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: bd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: fg.withValues(alpha: 0.75))),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: fg)),
            ),
          ],
        ),
      );

  /// Genera (o regenera) el PDF del recibo y lo abre. Queda guardado en
  /// esta PC y subido al servidor, asi que un abono viejo sin respaldo
  /// deja de serlo en cuanto se consulta.
  Future<void> _generarPdfAbono(
      Separado sep, double monto, String metodo) async {
    final auth   = context.read<AuthProvider>();
    final config = context.read<ConfigProvider>();
    try {
      await ReciboPdfService.imprimirReciboAbono(
        separado: sep,
        monto: monto,
        metodoPago: metodo,
        empresaNombre: auth.empresaNombre.isNotEmpty
            ? auth.empresaNombre
            : sep.tiendaNombre,
        nit: config.nit,
        direccion: config.direccion,
        telefono: config.telefono,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo generar el PDF: $e'),
        backgroundColor: const Color(0xFFBA1A1A),
      ));
    }
  }

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
            final factura    = d['venta_numero']?.toString() ?? 'DEV-${d['id']}';
            final tipo       = d['tipo']?.toString() ?? '';
            final tipoDif    = d['tipo_diferencia']?.toString() ?? '';
            final devTotal   = double.tryParse(d['total_devuelto']?.toString() ?? '0') ?? 0;
            final diferencia = double.tryParse(d['diferencia']?.toString() ?? '0') ?? 0;
            final esDevolucion = tipo == 'devolucion';
            final label      = esDevolucion ? 'Devolución' : 'Cambio';
            final labelColor = esDevolucion ? _kError : const Color(0xFFF57C00);
            final metodo     = d['metodo_devolucion']?.toString() ?? d['metodo_pago_diferencia']?.toString() ?? '';
            final cuentaNombre = d['cuenta_destino_nombre']?.toString() ?? '';
            final mostrarCuenta = cuentaNombre.isNotEmpty &&
                (metodo == 'transferencia' || metodo == 'tarjeta');

            // Monto efectivo real del movimiento de caja
            String montoLabel;
            Color  montoColor;
            if (esDevolucion) {
              montoLabel = '-\$${fmtNum(devTotal)}';
              montoColor = _kError;
            } else if (tipoDif == 'cobrar') {
              montoLabel = '+\$${fmtNum(diferencia)}';
              montoColor = const Color(0xFF16A34A);
            } else if (tipoDif == 'devolver') {
              montoLabel = '-\$${fmtNum(diferencia)}';
              montoColor = _kError;
            } else {
              montoLabel = 'Exacto';
              montoColor = const Color(0xFF78909C);
            }

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
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(
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
                          if (mostrarCuenta) ...[
                            const SizedBox(width: 5),
                            Flexible(child: Text(
                              cuentaNombre,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: const Color(0xFF5C6BC0),
                                  fontWeight: FontWeight.w500),
                            )),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  Text(montoLabel,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: montoColor)),
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
              Text('Neto efectivo',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kOutline)),
              Text(
                rep.impactoCajaDevoluciones >= 0
                    ? '+\$${fmtNum(rep.impactoCajaDevoluciones)}'
                    : '-\$${fmtNum(rep.impactoCajaDevoluciones.abs())}',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: rep.impactoCajaDevoluciones >= 0
                        ? const Color(0xFF16A34A)
                        : _kError),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
