import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/caja_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/empresa_provider.dart';
import '../../providers/tienda_provider.dart';
import 'widgets/caja_helpers.dart';
import 'widgets/caja_cerrada_card.dart';
import 'widgets/caja_abierta_card.dart';
import 'widgets/historial_tab.dart';
import 'widgets/historial_admin_tab.dart';
import 'widgets/corte_caja_dialog.dart';


class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}


class _CajaScreenState extends State<CajaScreen>
    with TickerProviderStateMixin {
  final _saldoCtrl = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  late TabController       _tabCtrl;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 1 && !_tabCtrl.indexIsChanging) {
        final auth = context.read<AuthProvider>();
        context.read<CajaProvider>().cargarHistorial(tiendaId: auth.tiendaId);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth    = context.read<AuthProvider>();
      final rol     = auth.rol ?? '';
      final esAdmin = rol == 'admin' || rol == 'supervisor' || rol == 'superadmin';

      if (!esAdmin) {
        context.read<CajaProvider>().verificarSesion(auth.tiendaId);
      }
      // HistorialAdminTab se inicializa solo internamente
    });
  }

  @override
  void dispose() {
    _saldoCtrl.dispose();
    _fadeCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caja    = context.watch<CajaProvider>();
    final auth    = context.watch<AuthProvider>();
    final rol     = auth.rol ?? '';
    final esAdmin = rol == 'admin' || rol == 'supervisor' || rol == 'superadmin';

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: const Color(0xFFF8F9FC),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _buildHeader(caja, esAdmin),
              const SizedBox(height: 14),

              _buildTabBar(esAdmin),
              const SizedBox(height: 14),

              if (caja.successMsg.isNotEmpty)
                buildBanner(caja.successMsg,
                    isError: false, onClose: caja.limpiarMensajes),
              if (caja.errorMsg.isNotEmpty)
                buildBanner(caja.errorMsg,
                    isError: true, onClose: caja.limpiarMensajes),

              Expanded(
                child: esAdmin
                    // ── Admin/Supervisor/Superadmin: historial con selector ──
                    ? HistorialAdminTab(esSuperadmin: rol == 'superadmin')
                    // ── Cajero: tabs normales ───────────────────────────────
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          caja.cargando
                              ? buildLoadingState()
                              : caja.cajaAbierta
                                  ? CajaAbiertaCard(
                                      caja: caja,
                                      onCerrarCaja: () => _abrirCorteCaja(caja))
                                  : CajaCerradaCard(
                                      caja: caja,
                                      auth: auth,
                                      saldoCtrl: _saldoCtrl),
                          const HistorialTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(CajaProvider caja, bool esAdmin) {
    final abierta = caja.cajaAbierta && !caja.cargando && !esAdmin;
    return Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: esAdmin
                ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                : abierta
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: (esAdmin
                ? const Color(0xFF6366F1)
                : abierta
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B)).withOpacity(0.35),
            blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Icon(
          esAdmin
              ? Icons.history_rounded
              : abierta ? Icons.lock_open_rounded : Icons.point_of_sale_rounded,
          color: Colors.white, size: 26),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Caja',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A), letterSpacing: -0.5)),
        Text(
          esAdmin
              ? 'Historial de turnos'
              : abierta ? 'Sesión activa' : 'Sin sesión activa',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: esAdmin
                  ? const Color(0xFF6366F1)
                  : abierta
                      ? const Color(0xFF10B981)
                      : const Color(0xFF94A3B8)),
        ),
      ]),
    ]);
  }

  // ── TabBar ───────────────────────────────────────────────────
  Widget _buildTabBar(bool esAdmin) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFEEF2F7),
      borderRadius: BorderRadius.circular(14)),
    padding: const EdgeInsets.all(4),
    child: esAdmin
        ? Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history_rounded, size: 15,
                    color: Color(0xFF0F172A)),
                const SizedBox(width: 6),
                Text('Historial',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: const Color(0xFF0F172A))),
              ]),
            ),
          )
        : TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8, offset: const Offset(0, 2))],
            ),
            indicatorSize:        TabBarIndicatorSize.tab,
            dividerColor:         Colors.transparent,
            labelStyle:           GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500, fontSize: 13),
            labelColor:           const Color(0xFF0F172A),
            unselectedLabelColor: const Color(0xFF94A3B8),
            tabs: const [
              Tab(icon: Icon(Icons.point_of_sale_rounded, size: 15), text: 'Caja'),
              Tab(icon: Icon(Icons.history_rounded,        size: 15), text: 'Historial'),
            ],
          ),
  );

  // ── Abrir diálogo de corte ────────────────────────────────────
  Future<void> _abrirCorteCaja(CajaProvider caja) async {
    await caja.cargarResumenCierre();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CorteCajaDialog(),
    );
  }
}