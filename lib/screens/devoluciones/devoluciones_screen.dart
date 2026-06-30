import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/devolucion_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/devoluciones_provider.dart';
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

  String? _fechaActual;
  String? _fechaIniActual;
  String? _fechaFinActual;
  String? _estadoActual;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar(fecha: _strFecha(DateTime.now()));
    });
  }

  String _strFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _puedeCancel => context.read<AuthProvider>().esAdminOSupervisor;

  Future<void> _cargar({
    String? fecha,
    String? fechaIni,
    String? fechaFin,
    String? estado,
  }) async {
    setState(() {
      _fechaActual    = fecha;
      _fechaIniActual = fechaIni;
      _fechaFinActual = fechaFin;
      _estadoActual   = estado;
    });
    final auth = context.read<AuthProvider>();
    await context.read<DevolucionesProvider>().cargarDevoluciones(
      tiendaId: auth.tiendaId != 0 ? auth.tiendaId : null,
      fecha:    fecha,
      fechaIni: fechaIni,
      fechaFin: fechaFin,
      estado:   estado,
    );
  }

  Future<void> _recargar() => _cargar(
    fecha:    _fechaActual,
    fechaIni: _fechaIniActual,
    fechaFin: _fechaFinActual,
    estado:   _estadoActual,
  );

  void _confirmarCancelar(DevolucionModel dev) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Cancelar devolución?',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Se revertirá el stock de ${dev.detalles.length} '
          'producto${dev.detalles.length != 1 ? 's' : ''}. '
          'Esta acción no se puede deshacer.',
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  ok ? 'Devolución cancelada' : prov.error ?? 'Error al cancelar',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                backgroundColor: ok ? _kGreen : _kError,
                behavior: SnackBarBehavior.floating,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      builder: (_, prov, __) {
        final devs = prov.devoluciones;
        final proc = devs.where((d) => d.estado == 'procesada').toList();

        final devuelto  = proc.fold<double>(0, (s, d) =>
            d.tipo == 'devolucion' ? s + d.totalDevuelto : s);
        final cobrado   = proc.fold<double>(0, (s, d) =>
            (d.tipo == 'cambio' && d.tipoDiferencia?.toLowerCase() == 'cobrar')
                ? s + (d.diferencia ?? 0) : s);
        final devCambios = proc.fold<double>(0, (s, d) =>
            (d.tipo == 'cambio' && d.tipoDiferencia?.toLowerCase() == 'devolver')
                ? s + (d.diferencia ?? 0) : s);
        final balance = cobrado - devuelto - devCambios;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            _buildHeader(devs.length),

            // ── Stats ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildStats(devuelto, cobrado, balance),
            ),

            // ── Filtros ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: FiltrosBar(
                onFiltrar: ({fecha, fechaIni, fechaFin, estado}) => _cargar(
                  fecha: fecha, fechaIni: fechaIni,
                  fechaFin: fechaFin, estado: estado,
                ),
              ),
            ),

            // ── Error ────────────────────────────────────────
            if (prov.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildError(prov.error!),
              ),

            // ── Lista ────────────────────────────────────────
            const SizedBox(height: 12),
            if (prov.cargando)
              const Expanded(
                child: Center(child: CircularProgressIndicator(color: _kGreen)),
              )
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
      },
    );
  }

  // ── Header ──────────────────────────────────────────────

  Widget _buildHeader(int cantidad) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Devoluciones',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 20, color: _kText)),
              const SizedBox(height: 2),
              Row(children: [
                Text(
                  '$cantidad registro${cantidad != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(fontSize: 13, color: _kTextMuted),
                ),
                if (cantidad > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cantidad.toString(),
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Nueva',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          onPressed: () => DevolucionFormSheet.show(context, onCreada: _recargar),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }

  // ── Stats ────────────────────────────────────────────────

  Widget _buildStats(double devuelto, double cobrado, double balance) {
    return Row(children: [
      Expanded(
        child: _StatCard(
          label: 'Devuelto',
          value: _fmt.format(devuelto),
          prefix: '-',
          icon: Icons.arrow_circle_up_rounded,
          color: _kOrange,
          bg: _kOrangeBg,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          label: 'Cobrado',
          value: _fmt.format(cobrado),
          prefix: '+',
          icon: Icons.arrow_circle_down_rounded,
          color: _kGreen,
          bg: _kMintLight,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          label: 'Balance',
          value: _fmt.format(balance.abs()),
          prefix: balance > 0 ? '+' : balance < 0 ? '-' : '',
          icon: Icons.account_balance_wallet_rounded,
          color: balance >= 0 ? _kGreen : _kError,
          bg: balance >= 0 ? _kMintLight : _kErrorBg,
        ),
      ),
    ]);
  }

  // ── Error ────────────────────────────────────────────────

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
      Expanded(
        child: Text(msg, style: GoogleFonts.inter(fontSize: 12, color: _kError)),
      ),
    ]),
  );

  // ── Empty state ──────────────────────────────────────────

  Widget _buildEmpty() => Expanded(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _kSurface,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.assignment_return_rounded,
                size: 32, color: _kTextMuted),
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
            onPressed: () => DevolucionFormSheet.show(context, onCreada: _recargar),
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

// ── Stat card compacta ────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final String   prefix;
  final IconData icon;
  final Color    color;
  final Color    bg;

  const _StatCard({
    required this.label,
    required this.value,
    required this.prefix,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                    color: color)),
          ]),
          const SizedBox(height: 4),
          Text(
            '$prefix${prefix.isEmpty ? value : value}'.trim(),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
