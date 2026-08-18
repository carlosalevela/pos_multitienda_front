import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/caja_provider.dart';
import '../../providers/auth_provider.dart';
import 'widgets/caja_helpers.dart';
import 'widgets/caja_cerrada_card.dart';
import 'widgets/caja_abierta_card.dart';
import 'widgets/historial_admin_tab.dart';
import 'widgets/corte_caja_dialog.dart';


class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}


class _CajaScreenState extends State<CajaScreen>
    with SingleTickerProviderStateMixin {
  final _saldoCtrl    = TextEditingController();
  bool  _cargandoCierre = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth    = context.read<AuthProvider>();
      final rol     = auth.rol;
      final esAdmin = rol == 'admin' || rol == 'supervisor' || rol == 'superadmin';

      if (!esAdmin) {
        final caja = context.read<CajaProvider>();
        await caja.verificarSesion(auth.tiendaId);
      }
    });
  }

  @override
  void dispose() {
    _saldoCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caja    = context.watch<CajaProvider>();
    final auth    = context.watch<AuthProvider>();
    final rol     = auth.rol;
    final esAdmin = rol == 'admin' || rol == 'supervisor' || rol == 'superadmin';

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: const Color(0xFFF7F9FB),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _buildHeader(caja, esAdmin),
              const SizedBox(height: 16),

              // Mensajes globales (admin y cajero cerrada)
              if (!caja.cajaAbierta) ...[
                if (caja.successMsg.isNotEmpty)
                  buildBanner(caja.successMsg,
                      isError: false, onClose: caja.limpiarMensajes),
                if (caja.errorMsg.isNotEmpty)
                  buildBanner(caja.errorMsg,
                      isError: true, onClose: caja.limpiarMensajes),
              ],

              Expanded(
                child: esAdmin
                    // ── Admin/Supervisor/Superadmin ──────────────────────
                    ? _buildAdminView(rol)
                    // ── Cajero ───────────────────────────────────────────
                    : caja.cargando
                        ? buildLoadingState()
                        : caja.cajaAbierta
                            ? CajaAbiertaCard(
                                caja: caja,
                                onCerrarCaja: () => _abrirCorteCaja(caja),
                              )
                            : Center(
                                child: CajaCerradaCard(
                                  caja: caja,
                                  auth: auth,
                                  saldoCtrl: _saldoCtrl,
                                  onCajaAbierta: () {},
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Vista admin ─────────────────────────────────────────────
  Widget _buildAdminView(String rol) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Chip de sección
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E3E5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.history_rounded, size: 15, color: Color(0xFF0F172A)),
          const SizedBox(width: 6),
          Text('Historial de turnos',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: const Color(0xFF0F172A))),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(
        child: HistorialAdminTab(esSuperadmin: rol == 'superadmin'),
      ),
    ]);
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader(CajaProvider caja, bool esAdmin) {
    final abierta = caja.cajaAbierta && !caja.cargando && !esAdmin;

    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: esAdmin
              ? const Color(0xFFECEEF0)
              : abierta
                  ? const Color(0xFF6CF8BB)
                  : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          esAdmin
              ? Icons.history_rounded
              : abierta
                  ? Icons.lock_open_rounded
                  : Icons.point_of_sale_rounded,
          color: esAdmin
              ? const Color(0xFF45464D)
              : abierta
                  ? const Color(0xFF006C49)
                  : const Color(0xFFB45309),
          size: 22,
        ),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Caja',
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: const Color(0xFF191C1E), letterSpacing: -0.3)),
        Text(
          esAdmin
              ? 'Historial de turnos'
              : abierta
                  ? 'Sesión activa'
                  : 'Sin sesión activa',
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: esAdmin
                  ? const Color(0xFF76777D)
                  : abierta
                      ? const Color(0xFF006C49)
                      : const Color(0xFF76777D)),
        ),
      ]),
    ]);
  }

  // ── Abrir diálogo de corte ───────────────────────────────────
  Future<void> _abrirCorteCaja(CajaProvider caja) async {
    if (_cargandoCierre) return;
    setState(() => _cargandoCierre = true);
    final ok = await caja.cargarResumenCierre();
    if (!mounted) { _cargandoCierre = false; return; }
    setState(() => _cargandoCierre = false);
    if (!ok) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CorteCajaDialog(),
    );
  }
}
