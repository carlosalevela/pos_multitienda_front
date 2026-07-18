import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/devolucion_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/devoluciones_provider.dart';
import '../../services/devolucion_print_service.dart';
import '../../services/barcode_service.dart';
import 'widgets/devolucion_card.dart';
import 'widgets/devolucion_detalle_sheet.dart';
import 'widgets/devolucion_form_sheet.dart';
import 'widgets/filtros_bar.dart';

const _kGreen     = Color(0xFF006C49);
const _kMintLight = Color(0xFFE8FFF4);
const _kSurface   = Color(0xFFF7F9FB);
const _kText      = Color(0xFF191C1E);
const _kTextMuted = Color(0xFF76777D);
const _kBorder    = Color(0xFFE0E3E5);
const _kOrange    = Color(0xFFF59E0B);
const _kOrangeBg  = Color(0xFFFEF3C7);
const _kError     = Color(0xFFBA1A1A);
const _kErrorBg   = Color(0xFFFFDAD6);

class DevolucionesScreen extends StatefulWidget {
  const DevolucionesScreen({super.key});

  @override
  State<DevolucionesScreen> createState() => _DevolucionesScreenState();
}

class _DevolucionesScreenState extends State<DevolucionesScreen> {
  final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  String?          _fechaActual;
  String?          _fechaIniActual;
  String?          _fechaFinActual;
  String?          _estadoActual;
  DevolucionModel? _selectedDev;   // panel derecho (desktop)

  // Barcode scanner
  StreamSubscription<String>? _barcodeSub;
  bool   _scanActivo    = false;
  Timer? _scanPulseTimer;

  @override
  void initState() {
    super.initState();
    _barcodeSub = BarcodeService.instance.onBarcode.listen(_onBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar(fecha: _strFecha(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _scanPulseTimer?.cancel();
    super.dispose();
  }

  void _onBarcode(String codigo) {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    // Pulso visual
    setState(() => _scanActivo = true);
    _scanPulseTimer?.cancel();
    _scanPulseTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scanActivo = false);
    });
    // Abrir formulario de devolución con la venta pre-buscada
    _abrirFormularioConBarcode(codigo);
  }

  void _abrirFormularioConBarcode(String numeroOrden) {
    final isWide = MediaQuery.of(context).size.width > 700;
    if (!isWide) {
      DevolucionFormSheet.show(
        context,
        initialNumeroOrden: numeroOrden,
        onCreada: (dev) {
          _recargar();
          if (dev != null && mounted) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) { if (mounted) _mostrarDialogoImprimir(dev); });
          }
        },
      );
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 440,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(-4, 0)),
              ],
            ),
            child: DevolucionFormSheet(
              initialNumeroOrden: numeroOrden,
              onCreada: (dev) {
                _recargar();
                if (dev != null && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) { if (mounted) _mostrarDialogoImprimir(dev); });
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  String _strFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _puedeCancel => context.read<AuthProvider>().esAdminOSupervisor;

  Future<void> _cargar({
    String? fecha, String? fechaIni, String? fechaFin, String? estado,
  }) async {
    setState(() {
      _fechaActual    = fecha;
      _fechaIniActual = fechaIni;
      _fechaFinActual = fechaFin;
      _estadoActual   = estado;
      _selectedDev    = null;
    });
    final auth = context.read<AuthProvider>();
    await context.read<DevolucionesProvider>().cargarDevoluciones(
      tiendaId: auth.tiendaId != 0 ? auth.tiendaId : null,
      fecha: fecha, fechaIni: fechaIni, fechaFin: fechaFin, estado: estado,
    );
  }

  Future<void> _recargar() => _cargar(
    fecha: _fechaActual, fechaIni: _fechaIniActual,
    fechaFin: _fechaFinActual, estado: _estadoActual,
  );

  void _abrirFormulario() {
    final isWide = MediaQuery.of(context).size.width > 700;
    if (!isWide) {
      DevolucionFormSheet.show(context, onCreada: (dev) {
        _recargar();
        if (dev != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) { if (mounted) _mostrarDialogoImprimir(dev); });
        }
      });
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 440,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(-4, 0)),
              ],
            ),
            child: DevolucionFormSheet(
              onCreada: (dev) {
                // El sheet ya hizo Navigator.pop(context) y cerró el diálogo.
                // Solo refrescar y mostrar el diálogo de impresión desde el screen padre.
                _recargar();
                if (dev != null && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) { if (mounted) _mostrarDialogoImprimir(dev); });
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoImprimir(DevolucionModel dev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: _kGreen, size: 20),
          ),
          const SizedBox(width: 10),
          Text(dev.tipo == 'cambio' ? 'Cambio registrado' : 'Devolución registrada',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        content: Text('¿Deseas imprimir el comprobante DEV-${dev.id}?',
            style: GoogleFonts.inter(fontSize: 13, color: _kTextMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No, gracias',
                style: GoogleFonts.inter(color: _kTextMuted)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_rounded, size: 16),
            label: Text('Imprimir',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            onPressed: () {
              Navigator.pop(ctx);
              DevolucionPrintService.imprimir(context, dev);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarCancelar(DevolucionModel dev) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Cancelar devolución?',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Se revertirá el stock de ${dev.detalles.length} '
          'producto${dev.detalles.length != 1 ? 's' : ''}. Esta acción no se puede deshacer.',
          style: GoogleFonts.inter(fontSize: 13, color: _kTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Volver', style: GoogleFonts.inter(color: _kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final prov = context.read<DevolucionesProvider>();
              final ok   = await prov.cancelarDevolucion(dev.id);
              if (!mounted) return;
              if (ok) setState(() => _selectedDev = null);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Devolución cancelada' : prov.error ?? 'Error al cancelar',
                    style: GoogleFonts.inter(fontSize: 13)),
                backgroundColor: ok ? _kGreen : _kError,
                behavior: SnackBarBehavior.floating,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cancelar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DevolucionesProvider>(
      builder: (context, prov, _) {
        final devs = prov.devoluciones;
        final proc = devs.where((d) => d.estado == 'procesada').toList();

        final devuelto   = proc.fold<double>(0, (s, d) =>
            d.tipo == 'devolucion' ? s + d.totalDevuelto : s);
        final cobrado    = proc.fold<double>(0, (s, d) =>
            (d.tipo == 'cambio' && d.tipoDiferencia?.toLowerCase() == 'cobrar')
                ? s + (d.diferencia ?? 0) : s);
        final devCambios = proc.fold<double>(0, (s, d) =>
            (d.tipo == 'cambio' && d.tipoDiferencia?.toLowerCase() == 'devolver')
                ? s + (d.diferencia ?? 0) : s);
        final balance = cobrado - devuelto - devCambios;

        return LayoutBuilder(
          builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 700;
            return isWide
                ? _buildDesktop(prov, devs, balance, devuelto, cobrado)
                : _buildMobile(prov, devs, balance, devuelto, cobrado);
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────
  //  DESKTOP: 2 columnas
  // ─────────────────────────────────────────────────────

  Widget _buildDesktop(
    DevolucionesProvider prov,
    List<DevolucionModel> devs,
    double balance, double devuelto, double cobrado,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Columna izquierda: lista ───────────────────
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(devs.length, compact: false),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _buildStats(devuelto, cobrado, balance),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: FiltrosBar(
                  onFiltrar: ({fecha, fechaIni, fechaFin, estado}) => _cargar(
                    fecha: fecha, fechaIni: fechaIni, fechaFin: fechaFin, estado: estado,
                  ),
                ),
              ),
              if (prov.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _buildError(prov.error!),
                ),
              const SizedBox(height: 14),
              // Título historial
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(children: [
                  Text('Historial reciente',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
                  const Spacer(),
                  Text('${devs.length} registro${devs.length != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
                ]),
              ),
              if (prov.cargando)
                const Expanded(child: Center(child: CircularProgressIndicator(color: _kGreen)))
              else if (devs.isEmpty)
                _buildEmpty()
              else
                Expanded(
                  child: RefreshIndicator(
                    color: _kGreen,
                    onRefresh: _recargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: devs.length,
                      itemBuilder: (_, i) {
                        final dev    = devs[i];
                        final isSelc = _selectedDev?.id == dev.id;
                        return DevolucionCard(
                          dev:         dev,
                          fmt:         _fmt,
                          puedeCancel: _puedeCancel,
                          selected:    isSelc,
                          onTap: () => setState(() =>
                              _selectedDev = isSelc ? null : dev),
                          onCancelar: () => _confirmarCancelar(dev),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Divisor ────────────────────────────────────
        Container(width: 1, color: _kBorder),

        // ── Columna derecha: panel detalle ─────────────
        Expanded(
          flex: 4,
          child: _selectedDev == null
              ? _buildRightEmpty()
              : _DetallePanel(
                  dev:         _selectedDev!,
                  fmt:         _fmt,
                  puedeCancel: _puedeCancel,
                  onCancelar:  () => _confirmarCancelar(_selectedDev!),
                  onCerrar:    () => setState(() => _selectedDev = null),
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  //  MOBILE: columna única (igual que antes)
  // ─────────────────────────────────────────────────────

  Widget _buildMobile(
    DevolucionesProvider prov,
    List<DevolucionModel> devs,
    double balance, double devuelto, double cobrado,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(devs.length, compact: true, showButton: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildStats(devuelto, cobrado, balance),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: FiltrosBar(
            onFiltrar: ({fecha, fechaIni, fechaFin, estado}) => _cargar(
              fecha: fecha, fechaIni: fechaIni, fechaFin: fechaFin, estado: estado,
            ),
          ),
        ),
        if (prov.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildError(prov.error!),
          ),
        const SizedBox(height: 12),
        if (prov.cargando)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _kGreen)))
        else if (devs.isEmpty)
          _buildEmpty()
        else
          Expanded(
            child: RefreshIndicator(
              color: _kGreen,
              onRefresh: _recargar,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: devs.length,
                itemBuilder: (_, i) {
                  final dev = devs[i];
                  return DevolucionCard(
                    dev:         dev,
                    fmt:         _fmt,
                    puedeCancel: _puedeCancel,
                    selected:    false,
                    onTap: () => DevolucionDetalleSheet.show(
                        context, dev: dev, fmt: _fmt),
                    onCancelar: () => _confirmarCancelar(dev),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  //  Panel derecho vacío (desktop)
  // ─────────────────────────────────────────────────────

  Widget _buildRightEmpty() {
    return Container(
      color: _kSurface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // CTA principal: nueva devolución
            GestureDetector(
              onTap: _abrirFormulario,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(color: _kGreen.withValues(alpha: 0.06),
                        blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _kMintLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, size: 26, color: _kGreen),
                  ),
                  const SizedBox(height: 12),
                  Text('Nueva devolución',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                          fontSize: 14, color: _kGreen)),
                  const SizedBox(height: 4),
                  Text('Registra o procesa\nuna devolución',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted)),
                ]),
              ),
            ),
            const SizedBox(height: 28),
            // Separador con "o"
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 1, color: _kBorder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('o', style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
              ),
              Container(width: 40, height: 1, color: _kBorder),
            ]),
            const SizedBox(height: 20),
            Text('selecciona una devolución del historial',
                style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Widgets compartidos
  // ─────────────────────────────────────────────────────

  Widget _buildHeader(int cantidad, {required bool compact, bool showButton = false}) {
    final padding = compact
        ? const EdgeInsets.fromLTRB(16, 16, 16, 0)
        : const EdgeInsets.fromLTRB(20, 20, 20, 0);

    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gestión de Devoluciones',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: compact ? 18 : 22,
                      color: _kText)),
              const SizedBox(height: 2),
              Text('Valida y procesa devoluciones en todas las tiendas',
                  style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
            ],
          ),
        ),
        // Indicador escáner de barras
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color:   _scanActivo ? _kMintLight : const Color(0xFFF2F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _scanActivo ? _kGreen : const Color(0xFFE0E3E5),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.qr_code_scanner_rounded,
                size: 15,
                color: _scanActivo ? _kGreen : _kTextMuted),
            if (_scanActivo) ...[
              const SizedBox(width: 5),
              Text('OK', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen)),
            ],
          ]),
        ),

        if (showButton) ...[
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Nueva',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            onPressed: _abrirFormulario,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildStats(double devuelto, double cobrado, double balance) {
    return Row(children: [
      Expanded(child: _StatCard(label: 'Devuelto', value: _fmt.format(devuelto),
          prefix: '-', icon: Icons.arrow_circle_up_rounded, color: _kOrange, bg: _kOrangeBg)),
      const SizedBox(width: 8),
      Expanded(child: _StatCard(label: 'Cobrado', value: _fmt.format(cobrado),
          prefix: '+', icon: Icons.arrow_circle_down_rounded, color: _kGreen, bg: _kMintLight)),
      const SizedBox(width: 8),
      Expanded(child: _StatCard(label: 'Balance', value: _fmt.format(balance.abs()),
          prefix: balance > 0 ? '+' : balance < 0 ? '-' : '',
          icon: Icons.account_balance_wallet_rounded,
          color: balance >= 0 ? _kGreen : _kError,
          bg:    balance >= 0 ? _kMintLight : _kErrorBg)),
    ]);
  }

  Widget _buildError(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kErrorBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kError.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: _kError, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 12, color: _kError))),
    ]),
  );

  Widget _buildEmpty() => Expanded(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _kSurface, shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.assignment_return_rounded, size: 32, color: _kTextMuted),
          ),
          const SizedBox(height: 16),
          Text('Sin devoluciones en este período',
              style: GoogleFonts.inter(color: _kTextMuted, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Registra una devolución o cambia el filtro',
              style: GoogleFonts.inter(color: _kBorder, fontSize: 12)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Registrar devolución',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            onPressed: _abrirFormulario,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kGreen,
              side: const BorderSide(color: _kGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Panel de detalle inline (columna derecha desktop)
// ─────────────────────────────────────────────────────────────────────────────

class _DetallePanel extends StatelessWidget {
  final DevolucionModel dev;
  final NumberFormat    fmt;
  final bool            puedeCancel;
  final VoidCallback    onCancelar;
  final VoidCallback    onCerrar;

  const _DetallePanel({
    required this.dev,
    required this.fmt,
    required this.puedeCancel,
    required this.onCancelar,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final esCambio  = dev.tipo == 'cambio';
    final cancelada = dev.estado == 'cancelada';
    final accentCol = cancelada
        ? _kTextMuted
        : esCambio ? _kGreen : _kOrange;

    return Container(
      color: Colors.white,
      child: Column(children: [
        // ── Cabecera del panel ─────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: accentCol.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                esCambio ? Icons.swap_horiz_rounded : Icons.assignment_return_rounded,
                size: 20, color: accentCol,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DEV-${dev.id}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold,
                        fontSize: 16, color: _kText)),
                Text(
                  '${esCambio ? 'Cambio' : 'Devolución'} · ${dev.ventaNumero}',
                  style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
                ),
              ]),
            ),
            _ChipEstado(estado: dev.estado),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: _kTextMuted),
              onPressed: onCerrar,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),

        // ── Contenido scrollable ───────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Info general
              _InfoGrid(dev: dev, fmt: fmt),
              const SizedBox(height: 20),
              // Productos
              _PanelSeccion(
                label: esCambio ? 'Productos recibidos' : 'Productos devueltos',
                icon: Icons.assignment_return_rounded,
                color: _kOrange,
              ),
              const SizedBox(height: 10),
              ...dev.detalles.map((d) => _ProductoTile(detalle: d, fmt: fmt)),

              // Reemplazo (cambio)
              if (esCambio && dev.productoReemplazoNombre != null) ...[
                const SizedBox(height: 16),
                _PanelSeccion(
                  label: 'Producto entregado',
                  icon: Icons.shopping_bag_outlined,
                  color: _kGreen,
                ),
                const SizedBox(height: 10),
                _ReemplazoTile(dev: dev, fmt: fmt),
              ],

              // Total
              const SizedBox(height: 20),
              const Divider(color: _kBorder),
              const SizedBox(height: 12),
              _TotalRow(dev: dev, fmt: fmt, esCambio: esCambio),
            ],
          ),
        ),

        // ── Pie: imprimir + cancelar ───────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _kBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón imprimir (siempre visible)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text('Imprimir comprobante',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: () => DevolucionPrintService.imprimir(context, dev),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (puedeCancel && !cancelada) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text('Cancelar devolución',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: onCancelar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kError,
                      side: BorderSide(color: _kError.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── widgets del panel ────────────────────────────────────────────────────────

class _InfoGrid extends StatelessWidget {
  final DevolucionModel dev;
  final NumberFormat    fmt;
  const _InfoGrid({required this.dev, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy · HH:mm').format(dev.createdAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _Cell(label: 'EMPLEADO',  value: dev.empleadoNombre)),
          const SizedBox(width: 12),
          Expanded(child: _Cell(label: 'TIENDA',    value: dev.tiendaNombre)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Cell(label: 'MÉTODO',    value: _metodo(dev.metodoDevolucion))),
          const SizedBox(width: 12),
          Expanded(child: _Cell(label: 'FECHA',     value: date)),
        ]),
        if (dev.observaciones.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Cell(label: 'OBSERVACIONES', value: dev.observaciones),
        ],
      ]),
    );
  }

  String _metodo(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      case 'nota_credito':  return 'Nota Crédito';
      default:              return 'Efectivo';
    }
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  const _Cell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
          color: _kTextMuted, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
          color: _kText), overflow: TextOverflow.ellipsis),
    ],
  );
}

class _PanelSeccion extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  const _PanelSeccion({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 13, color: color),
    ),
    const SizedBox(width: 8),
    Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700,
        fontSize: 13, color: _kText)),
  ]);
}

class _ProductoTile extends StatelessWidget {
  final DetalleDevolucionModel detalle;
  final NumberFormat fmt;
  const _ProductoTile({required this.detalle, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cantStr = detalle.cantidad % 1 == 0
        ? detalle.cantidad.toStringAsFixed(0)
        : detalle.cantidad.toStringAsFixed(2);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_outlined, size: 16, color: _kOrange),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(detalle.productoNombre,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
            if (detalle.motivo.isNotEmpty)
              Text(detalle.motivo,
                  style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('×$cantStr', style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted)),
          Text(fmt.format(detalle.subtotal),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _kOrange)),
        ]),
      ]),
    );
  }
}

class _ReemplazoTile extends StatelessWidget {
  final DevolucionModel dev;
  final NumberFormat    fmt;
  const _ReemplazoTile({required this.dev, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cant = dev.cantidadReemplazo ?? 0;
    final cantStr = cant % 1 == 0 ? cant.toStringAsFixed(0) : cant.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check_circle_rounded, size: 18, color: _kGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dev.productoReemplazoNombre ?? '',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
            Text('Cantidad: $cantStr',
                style: GoogleFonts.inter(fontSize: 11, color: _kGreen)),
          ]),
        ),
        if (dev.subtotalReemplazo != null)
          Text(fmt.format(dev.subtotalReemplazo!),
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _kGreen)),
      ]),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final DevolucionModel dev;
  final NumberFormat    fmt;
  final bool            esCambio;
  const _TotalRow({required this.dev, required this.fmt, required this.esCambio});

  @override
  Widget build(BuildContext context) {
    final tipoDif = (dev.tipoDiferencia ?? 'exacto').toLowerCase();
    final dif     = dev.diferencia ?? 0.0;

    return Column(children: [
      // Diferencia en cambios
      if (esCambio && tipoDif != 'exacto' && dif > 0) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: tipoDif == 'cobrar'
                ? _kOrange.withValues(alpha: 0.08)
                : Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tipoDif == 'cobrar'
                  ? _kOrange.withValues(alpha: 0.3)
                  : Colors.blueGrey.shade200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tipoDif == 'cobrar' ? '⬆ Cobrado al cliente' : '⬇ Devuelto al cliente',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                    color: tipoDif == 'cobrar' ? _kOrange : Colors.blueGrey.shade700),
              ),
              Text(fmt.format(dif),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
                      color: tipoDif == 'cobrar' ? _kOrange : Colors.blueGrey.shade700)),
            ],
          ),
        ),
      ],
      // Total principal
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: esCambio ? _kMintLight : _kOrangeBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: esCambio
                ? _kGreen.withValues(alpha: 0.2)
                : _kOrange.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              esCambio ? 'Valor reconocido' : 'Total devuelto',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                  color: esCambio ? _kGreen : _kOrange),
            ),
            Text(
              fmt.format(dev.totalDevuelto),
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold,
                  color: esCambio ? _kGreen : _kOrange),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _ChipEstado extends StatelessWidget {
  final String estado;
  const _ChipEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final cancelada = estado == 'cancelada';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cancelada ? _kSurface : _kMintLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cancelada ? _kBorder : _kGreen.withValues(alpha: 0.3)),
      ),
      child: Text(
        cancelada ? 'Cancelada' : 'Procesada',
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
            color: cancelada ? _kTextMuted : _kGreen),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value, prefix;
  final IconData icon;
  final Color color, bg;
  const _StatCard({
    required this.label, required this.value, required this.prefix,
    required this.icon, required this.color, required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ]),
      const SizedBox(height: 4),
      Text('$prefix${prefix.isEmpty ? value : value}'.trim(),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          overflow: TextOverflow.ellipsis),
    ]),
  );
}
