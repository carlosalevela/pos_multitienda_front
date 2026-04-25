import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/caja_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/resumen_cierre.dart';
import '../../core/constants.dart';

// ══════════════════════════════════════════════════════════════
// CAJA SCREEN
// ══════════════════════════════════════════════════════════════
class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen>
    with SingleTickerProviderStateMixin {
  final _saldoCtrl = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<CajaProvider>().verificarSesion(auth.tiendaId);
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
    final caja = context.watch<CajaProvider>();
    final auth = context.watch<AuthProvider>();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: const Color(0xFFF8F9FC),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ─────────────────────────────────────
              _buildHeader(caja),
              const SizedBox(height: 20),

              // ── Mensajes ────────────────────────────────────
              if (caja.successMsg.isNotEmpty)
                _banner(caja.successMsg,
                    isError: false, onClose: caja.limpiarMensajes),
              if (caja.errorMsg.isNotEmpty)
                _banner(caja.errorMsg,
                    isError: true, onClose: caja.limpiarMensajes),

              // ── Contenido ───────────────────────────────────
              Expanded(
                child: caja.cargando
                    ? _loadingState()
                    : caja.cajaAbierta
                        ? _buildCajaAbierta(caja, auth)
                        : _buildCajaCerrada(caja, auth),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader(CajaProvider caja) {
    final abierta = caja.cajaAbierta && !caja.cargando;
    return Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: abierta
                ? [const Color(0xFF10B981), const Color(0xFF059669)]
                : [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (abierta
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B)).withOpacity(0.35),
              blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Icon(
          abierta ? Icons.lock_open_rounded : Icons.point_of_sale_rounded,
          color: Colors.white, size: 26),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Caja',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A), letterSpacing: -0.5)),
        Text(
          abierta ? 'Sesión activa' : 'Sin sesión activa',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: abierta
                  ? const Color(0xFF10B981)
                  : const Color(0xFF94A3B8)),
        ),
      ]),
    ]);
  }

  // ══════════════════════════════════════════════════════
  // CAJA CERRADA
  // ══════════════════════════════════════════════════════
  Widget _buildCajaCerrada(CajaProvider caja, AuthProvider auth) {
    return Center(
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.07),
                blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Banner superior
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFF59E0B).withOpacity(0.12),
                         const Color(0xFFFEF3C7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.35),
                      blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    size: 36, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text('Caja cerrada',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text('Ingresa el saldo inicial para comenzar el turno',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8), fontSize: 13)),
            ]),
          ),

          // Formulario
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              _inputField(
                controller: _saldoCtrl,
                label: 'Saldo inicial',
                prefixText: '\$ ',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                accentColor: const Color(0xFF10B981),
              ),
              const SizedBox(height: 20),

              // Botón
              SizedBox(
                width: double.infinity, height: 52,
                child: _gradientButton(
                  label: caja.procesando ? 'Abriendo...' : 'Abrir Caja',
                  icon: caja.procesando
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_open_rounded, size: 20),
                  colors: [const Color(0xFF10B981), const Color(0xFF059669)],
                  shadowColor: const Color(0xFF10B981),
                  onPressed: caja.procesando ? null : () =>
                      caja.abrirCaja(
                        tiendaId: auth.tiendaId,
                        saldoInicial: double.tryParse(_saldoCtrl.text) ?? 0),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CAJA ABIERTA
  // ══════════════════════════════════════════════════════
  Widget _buildCajaAbierta(CajaProvider caja, AuthProvider auth) {
    final sesion = caja.sesionActiva!;
    final fmt    = NumberFormat('#,##0', 'en_US');

    return Center(
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.07),
                blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Banner verde con info de sesión
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_open_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Caja abierta',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text('Sesión #${sesion.id} activa',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(sesion.estado.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
              ]),
              const SizedBox(height: 20),

              // Stat: saldo inicial
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Saldo inicial',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        '\$${fmt.format(sesion.saldo_inicial)}',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text('Apertura',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        sesion.fecha_apertura
                            .toLocal().toString().substring(0, 16),
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),

          // Detalles + botón
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              _infoRow('Sesión ID', '#${sesion.id}'),
              _infoRow('Estado', sesion.estado.toUpperCase()),
              _infoRow('Saldo inicial',
                  '\$${sesion.saldo_inicial.toStringAsFixed(0)}'),
              _infoRow('Apertura',
                  sesion.fecha_apertura
                      .toLocal().toString().substring(0, 16)),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 52,
                child: _gradientButton(
                  label: caja.procesando ? 'Cargando...' : 'Cerrar Caja',
                  icon: caja.procesando
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_rounded, size: 20),
                  colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                  shadowColor: const Color(0xFFEF4444),
                  onPressed: caja.procesando
                      ? null : () => _abrirCorteCaja(caja),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
  Widget _gradientButton({
    required String   label,
    required Widget   icon,
    required List<Color> colors,
    required Color    shadowColor,
    required VoidCallback? onPressed,
  }) =>
    Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.35),
            blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: ElevatedButton.icon(
        icon: icon,
        label: Text(label,
            style: GoogleFonts.plusJakartaSans(
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
    );

  Widget _inputField({
    required TextEditingController controller,
    required String               label,
    String?                       prefixText,
    TextInputType?                keyboardType,
    List<TextInputFormatter>?     inputFormatters,
    Color                         accentColor = const Color(0xFF6366F1),
  }) =>
    TextField(
      controller:       controller,
      keyboardType:     keyboardType,
      inputFormatters:  inputFormatters,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText:  label,
        prefixText: prefixText,
        labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: const Color(0xFF94A3B8)),
        prefixStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A)),
        filled:    true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 2)),
      ),
    );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8), fontSize: 13,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 13,
                color: const Color(0xFF1E293B))),
      ],
    ),
  );

  Widget _banner(String msg,
      {required bool isError, required VoidCallback onClose}) {
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Container(
      margin:  const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(
            isError ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
            color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(msg,
            style: GoogleFonts.plusJakartaSans(
                color: color.withOpacity(0.9),
                fontSize: 13, fontWeight: FontWeight.w600))),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(6),
          child: Padding(padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 16,
                  color: color.withOpacity(0.5))),
        ),
      ]),
    );
  }

  Widget _loadingState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
        ),
      ),
      const SizedBox(height: 16),
      Text('Verificando sesión de caja…',
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600, fontSize: 14)),
    ]),
  );

  Future<void> _abrirCorteCaja(CajaProvider caja) async {
    await caja.cargarResumenCierre();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CorteCajaDialog(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DIÁLOGO DE CORTE DE CAJA — 3 pasos
// ══════════════════════════════════════════════════════════════
class _CorteCajaDialog extends StatefulWidget {
  const _CorteCajaDialog();

  @override
  State<_CorteCajaDialog> createState() => _CorteCajaDialogState();
}

class _CorteCajaDialogState extends State<_CorteCajaDialog>
    with SingleTickerProviderStateMixin {
  int    _paso           = 1;
  double _montoIngresado = 0;
  final  _montoCtrl      = TextEditingController();
  final  _obsCtrl        = TextEditingController();
  final  _fmt            = NumberFormat('#,##0', 'en_US');

  late AnimationController _stepCtrl;
  late Animation<double>   _stepAnim;

  static const _pasoLabels = ['Resumen', 'Conteo', 'Resultado'];

  @override
  void initState() {
    super.initState();
    _stepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _stepAnim = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    _stepCtrl.forward();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _obsCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  String _f(double v) => '\$${_fmt.format(v)}';

  String _formatFecha(String fecha) {
    if (fecha.length >= 16) return fecha.substring(0, 16).replaceAll('T', ' ');
    return fecha.replaceAll('T', ' ');
  }

  double get _diferencia =>
      _montoIngresado -
      (context.read<CajaProvider>().resumenCierre?.montoEsperadoCaja ?? 0);

  void _irAPaso(int paso) {
    _stepCtrl.reset();
    setState(() => _paso = paso);
    _stepCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final cont    = context.watch<CajaProvider>();
    final resumen = cont.resumenCierre;

    if (resumen == null) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Padding(
          padding: EdgeInsets.all(48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: 16),
            Text('Cargando resumen del turno…'),
          ]),
        ),
      );
    }

    return Dialog(
      shape:        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 540,
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header del dialog ──────────────────────────
          _buildDialogHeader(resumen),

          // ── Contenido con animación ────────────────────
          Flexible(
            child: FadeTransition(
              opacity: _stepAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: _paso == 1
                    ? _buildPaso1(resumen)
                    : _paso == 2
                        ? _buildPaso2(resumen)
                        : _buildPaso3(resumen),
              ),
            ),
          ),

          // ── Acciones ───────────────────────────────────
          _buildAcciones(cont, resumen),
        ]),
      ),
    );
  }

  // ── Header del diálogo ──────────────────────────────────
  Widget _buildDialogHeader(ResumenCierre r) => Container(
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F1629), Color(0xFF1E2A45)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Column(children: [
      Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.receipt_long_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Corte de Caja',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 16)),
            Text(r.tiendaNombre,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ]),
        ),
      ]),
      const SizedBox(height: 18),

      // Stepper visual
      Row(children: List.generate(3, (i) {
        final idx     = i + 1;
        final activo  = idx == _paso;
        final pasado  = idx < _paso;
        return Expanded(
          child: Row(children: [
            Expanded(
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: pasado
                        ? const Color(0xFF10B981)
                        : activo
                            ? const Color(0xFF6366F1)
                            : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: activo
                        ? Border.all(color: const Color(0xFF818CF8), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: pasado
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : Text('$idx',
                            style: GoogleFonts.plusJakartaSans(
                                color: activo
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                                fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_pasoLabels[i],
                    style: GoogleFonts.plusJakartaSans(
                        color: activo
                            ? Colors.white
                            : Colors.white.withOpacity(0.35),
                        fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
              ]),
            ),
            if (i < 2)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 22),
                  color: pasado
                      ? const Color(0xFF10B981)
                      : Colors.white.withOpacity(0.12),
                ),
              ),
          ]),
        );
      })),
    ]),
  );

  // ══════════════════════════════════════════════════
  // PASO 1 — Resumen del turno
  // ══════════════════════════════════════════════════
  Widget _buildPaso1(ResumenCierre r) => Column(
    key: const ValueKey(1),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Info del cajero
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                r.empleadoNombre.isNotEmpty
                    ? r.empleadoNombre[0].toUpperCase() : '?',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.empleadoNombre,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: const Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text('Apertura: ${_formatFecha(r.fechaApertura)}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),

      // Tarjeta de ventas
      _seccionCard(
        titulo: 'Ventas del turno',
        icono:  Icons.trending_up_rounded,
        color:  const Color(0xFF6366F1),
        bgColor: const Color(0xFFF5F3FF),
        child: Column(children: [
          _filaCard('Efectivo', r.ventas.efectivo,
              const Color(0xFF10B981)),
          _filaCard('Tarjeta', r.ventas.tarjeta,
              const Color(0xFF6366F1)),
          _filaCard('Transferencia', r.ventas.transferencia,
              const Color(0xFF8B5CF6)),
          if (r.ventas.mixto > 0)
            _filaCard('Mixto', r.ventas.mixto,
                const Color(0xFFF59E0B)),
          _dividerCard(),
          _filaCard('TOTAL VENTAS', r.ventas.total,
              const Color(0xFF0F172A), bold: true),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
              child: Text('${r.ventas.numTransacciones} transacciones',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: const Color(0xFF6366F1),
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Tarjeta de gastos
      _seccionCard(
        titulo:  'Gastos del turno',
        icono:   Icons.trending_down_rounded,
        color:   const Color(0xFFEF4444),
        bgColor: const Color(0xFFFFF5F5),
        child: r.gastos.detalle.isEmpty
            ? _emptyDetalle('Sin gastos en este turno')
            : Column(children: [
                ...r.gastos.detalle.map((g) =>
                    _filaCard('${g.categoria} (${g.metodoPago})',
                        g.monto, const Color(0xFFEF4444), negativo: true)),
                _dividerCard(),
                _filaCard('TOTAL GASTOS', r.gastos.total,
                    const Color(0xFFEF4444), bold: true, negativo: true),
              ]),
      ),
      const SizedBox(height: 12),

      // Abonos
      if (r.abonos.total > 0) ...[
        _seccionCard(
          titulo:  'Abonos recibidos',
          icono:   Icons.bookmark_added_rounded,
          color:   const Color(0xFF0EA5E9),
          bgColor: const Color(0xFFF0F9FF),
          child: Column(children: [
            if (r.abonos.efectivo > 0)
              _filaCard('Efectivo', r.abonos.efectivo,
                  const Color(0xFF0EA5E9)),
            if (r.abonos.transferencia > 0)
              _filaCard('Transferencia', r.abonos.transferencia,
                  const Color(0xFF0EA5E9)),
            _dividerCard(),
            _filaCard('TOTAL ABONOS', r.abonos.total,
                const Color(0xFF0284C7), bold: true),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${r.abonos.cantidad} abono${r.abonos.cantidad != 1 ? "s" : ""}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: const Color(0xFF94A3B8))),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        _infoTip('Solo los abonos en efectivo afectan el cuadre de caja.'),
        const SizedBox(height: 12),
      ],

      // Cálculo caja física
      _seccionCard(
        titulo:  'Cálculo de caja física',
        icono:   Icons.calculate_rounded,
        color:   const Color(0xFF10B981),
        bgColor: const Color(0xFFF0FDF4),
        highlighted: true,
        child: Column(children: [
          _filaCard('Saldo inicial', r.montoInicial,
              const Color(0xFF475569)),
          _filaCard('+ Ventas efectivo', r.ventas.efectivo,
              const Color(0xFF10B981)),
          if (r.ventas.mixto > 0)
            _filaCard('+ Ventas mixto', r.ventas.mixto,
                const Color(0xFF10B981)),
          if (r.abonos.efectivo > 0)
            _filaCard('+ Abonos efectivo', r.abonos.efectivo,
                const Color(0xFF0EA5E9)),
          _filaCard('- Gastos efectivo', r.gastos.efectivo,
              const Color(0xFFEF4444), negativo: true),
          _dividerCard(),
          _filaCard('ESPERADO EN CAJA', r.montoEsperadoCaja,
              const Color(0xFF059669), bold: true),
        ]),
      ),
      const SizedBox(height: 6),
      _infoTip(
          'Tarjeta ${_f(r.ventas.tarjeta)} y transferencia '
          '${_f(r.ventas.transferencia)} van al banco.'),
    ],
  );

  // ══════════════════════════════════════════════════
  // PASO 2 — Conteo físico
  // ══════════════════════════════════════════════════
  Widget _buildPaso2(ResumenCierre r) => Column(
    key: const ValueKey(2),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Banner esperado
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(children: [
          Text('Esperado en caja',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.75), fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_f(r.montoEsperadoCaja),
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: 36, letterSpacing: -1)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16, runSpacing: 8,
            children: [
              _chipInfo('Inicial', _f(r.montoInicial)),
              _chipInfo('Ef. ventas', _f(r.ventas.efectivo)),
              if (r.abonos.efectivo > 0)
                _chipInfo('Abonos ef.', _f(r.abonos.efectivo)),
              if (r.gastos.efectivo > 0)
                _chipInfo('- Gastos', _f(r.gastos.efectivo),
                    labelColor: Colors.red.shade300,
                    valorColor: Colors.red.shade300),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 24),

      Text('¿Cuánto hay físicamente en el cajón?',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: const Color(0xFF475569),
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),

      // Input monto contado
      TextField(
        controller: _montoCtrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        ],
        onChanged: (val) {
          final parts = val.split('.');
          if (parts.length > 2) {
            _montoCtrl.text = '${parts[0]}.${parts[1]}';
            _montoCtrl.selection =
                TextSelection.collapsed(offset: _montoCtrl.text.length);
          }
        },
        style: GoogleFonts.plusJakartaSans(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText:  'Monto contado',
          prefixText: '\$ ',
          labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: const Color(0xFF94A3B8)),
          prefixStyle: GoogleFonts.plusJakartaSans(
              fontSize: 24, fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A)),
          filled:    true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFF10B981), width: 2)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 16),
        ),
      ),
      const SizedBox(height: 14),

      // Observaciones
      TextField(
        controller: _obsCtrl,
        maxLines: 3,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: const Color(0xFF475569)),
        decoration: InputDecoration(
          labelText: 'Observaciones (opcional)',
          hintText:  'Ej: billetes contados, diferencias encontradas…',
          labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: const Color(0xFF94A3B8)),
          hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: const Color(0xFFCBD5E1)),
          filled:    true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFF10B981), width: 2)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
        ),
      ),
    ],
  );

  Widget _chipInfo(String label, String valor,
      {Color labelColor = Colors.white60,
       Color valorColor = Colors.white}) =>
    Column(children: [
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              color: labelColor, fontSize: 10, fontWeight: FontWeight.w600)),
      Text(valor,
          style: GoogleFonts.plusJakartaSans(
              color: valorColor, fontSize: 13, fontWeight: FontWeight.w800)),
    ]);

  // ══════════════════════════════════════════════════
  // PASO 3 — Resultado / Ticket
  // ══════════════════════════════════════════════════
  Widget _buildPaso3(ResumenCierre r) {
    final dif        = _diferencia;
    final esExacto   = dif.abs() < 0.01;
    final esSobrante = dif > 0;

    final color     = esExacto
        ? const Color(0xFF10B981)
        : esSobrante ? const Color(0xFF6366F1) : const Color(0xFFEF4444);
    final icono     = esExacto ? Icons.check_circle_rounded
        : esSobrante ? Icons.arrow_circle_up_rounded
        : Icons.warning_rounded;
    final resultado = esExacto ? 'CUADRE EXACTO'
        : esSobrante ? 'SOBRANTE' : 'FALTANTE';

    final now  = DateTime.now();
    final hora = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return Column(
      key: const ValueKey(3),
      children: [
        // Banner de resultado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.25), width: 2),
          ),
          child: Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(resultado,
                style: GoogleFonts.plusJakartaSans(
                    color: color, fontWeight: FontWeight.w800, fontSize: 18,
                    letterSpacing: 0.3)),
            if (!esExacto) ...[
              const SizedBox(height: 4),
              Text(_f(dif.abs()),
                  style: GoogleFonts.plusJakartaSans(
                      color: color, fontWeight: FontWeight.w800,
                      fontSize: 30, letterSpacing: -1)),
            ],
          ]),
        ),
        const SizedBox(height: 18),

        // Ticket imprimible
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera ticket
              Center(child: Column(children: [
                _mono('══════════════════════════',
                    const Color(0xFFCBD5E1)),
                _mono('  CORTE DE CAJA #${r.sesionId}  ',
                    const Color(0xFF0F172A), bold: true),
                _mono('  ${r.tiendaNombre}  ',
                    const Color(0xFF475569)),
                _mono('  $hora  ',
                    const Color(0xFF94A3B8)),
                _mono('══════════════════════════',
                    const Color(0xFFCBD5E1)),
              ])),
              const SizedBox(height: 12),

              _rSeccion('RESPONSABLE'),
              _rFila('Cajero', r.empleadoNombre),
              _rFila('Apertura', _formatFecha(r.fechaApertura)),
              _rFila('Cierre', hora),

              const SizedBox(height: 8),
              _rSeccion('VENTAS DEL TURNO'),
              _rFila('Efectivo', _f(r.ventas.efectivo)),
              _rFila('Tarjeta', _f(r.ventas.tarjeta)),
              _rFila('Transferencia', _f(r.ventas.transferencia)),
              if (r.ventas.mixto > 0) _rFila('Mixto', _f(r.ventas.mixto)),
              _rDivider(),
              _rFila('TOTAL VENTAS', _f(r.ventas.total), bold: true),
              _rFila('Transacciones', '${r.ventas.numTransacciones}'),

              if (r.abonos.total > 0) ...[
                const SizedBox(height: 8),
                _rSeccion('ABONOS RECIBIDOS'),
                if (r.abonos.efectivo > 0)
                  _rFila('Efectivo', _f(r.abonos.efectivo)),
                if (r.abonos.transferencia > 0)
                  _rFila('Transferencia', _f(r.abonos.transferencia)),
                _rFila('TOTAL ABONOS', _f(r.abonos.total), bold: true),
              ],

              const SizedBox(height: 8),
              _rSeccion('GASTOS DEL TURNO'),
              if (r.gastos.detalle.isEmpty)
                _rFila('Sin gastos', _f(0))
              else ...[
                ...r.gastos.detalle.map((g) =>
                    _rFila(g.categoria, '-${_f(g.monto)}')),
                _rDivider(),
                _rFila('TOTAL GASTOS', '-${_f(r.gastos.total)}', bold: true),
              ],

              const SizedBox(height: 8),
              _rSeccion('RESULTADO FINAL'),
              _rFila('Contado', _f(_montoIngresado)),
              _rFila('Esperado', _f(r.montoEsperadoCaja)),
              _rDivider(),
              _rFila(
                resultado,
                '${dif >= 0 ? '+' : ''}${_f(dif)}',
                bold: true, color: color,
              ),

              if (_obsCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _rSeccion('OBSERVACIONES'),
                _mono(_obsCtrl.text, const Color(0xFF64748B)),
              ],

              const SizedBox(height: 12),
              Center(
                child: _mono('── POS Multitienda ──',
                    const Color(0xFFCBD5E1)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Acciones del diálogo ─────────────────────────────────
  Widget _buildAcciones(CajaProvider cont, ResumenCierre resumen) =>
    Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(children: [
        if (_paso > 1)
          TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text('Atrás',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600)),
            onPressed: () => _irAPaso(_paso - 1),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B)),
          ),
        const Spacer(),
        if (_paso == 1)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600)),
          ),
        const SizedBox(width: 10),

        // Botón principal
        _pasoButton(cont),
      ]),
    );

  Widget _pasoButton(CajaProvider cont) {
    final esFinal = _paso == 3;
    final colors = esFinal
        ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
        : [const Color(0xFF0F1629), const Color(0xFF1E2A45)];

    final label = _paso == 1
        ? 'Continuar'
        : _paso == 2
            ? 'Ver resultado'
            : cont.procesando ? 'Cerrando…' : 'Confirmar cierre';

    final icon = cont.procesando && esFinal
        ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
        : Icon(
            esFinal ? Icons.lock_rounded : Icons.arrow_forward_rounded,
            size: 16);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: ElevatedButton.icon(
        icon: icon,
        label: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: cont.procesando ? null : () async {
          if (_paso == 1) {
            _irAPaso(2);
          } else if (_paso == 2) {
            final monto = double.tryParse(_montoCtrl.text);
            if (monto == null || monto < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ingresa un monto válido',
                      style: GoogleFonts.plusJakartaSans()),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior:        SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
              return;
            }
            setState(() => _montoIngresado = monto);
            _irAPaso(3);
          } else {
            final ok = await cont.cerrarCaja(
              montoFinalReal: _montoIngresado,
              observaciones:  _obsCtrl.text.trim(),
            );
            if (ok && context.mounted) Navigator.pop(context);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor:     Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // HELPERS DE TARJETAS
  // ══════════════════════════════════════════════════
  Widget _seccionCard({
    required String  titulo,
    required IconData icono,
    required Color   color,
    required Color   bgColor,
    required Widget  child,
    bool highlighted = false,
  }) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Text(titulo,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, fontSize: 13, color: color)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );

  Widget _filaCard(String label, double valor, Color color,
      {bool bold = false, bool negativo = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: const Color(0xFF475569),
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500)),
          Text('${negativo ? '-' : ''}${_f(valor)}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: color,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );

  Widget _dividerCard() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Divider(height: 1, color: Colors.black.withOpacity(0.07)),
  );

  Widget _emptyDetalle(String msg) => Text(msg,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 13, color: const Color(0xFF94A3B8),
          fontStyle: FontStyle.italic));

  Widget _infoTip(String msg) => Row(children: [
    const Icon(Icons.info_outline_rounded,
        size: 13, color: Color(0xFFCBD5E1)),
    const SizedBox(width: 6),
    Expanded(
      child: Text(msg,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500)),
    ),
  ]);

  // ══════════════════════════════════════════════════
  // HELPERS TICKET (mono)
  // ══════════════════════════════════════════════════
  Widget _mono(String texto, Color color, {bool bold = false}) => Text(
    texto,
    style: TextStyle(
        fontFamily:  'monospace', fontSize: 12, color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal),
  );

  Widget _rSeccion(String titulo) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 3),
    child: Text(titulo.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
  );

  Widget _rFila(String label, String valor,
      {bool bold = false, Color? color}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  color: color ?? const Color(0xFF475569),
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
          Text(valor,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  color: color ?? const Color(0xFF1E293B),
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );

  Widget _rDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('──────────────────────────',
        style: TextStyle(fontFamily: 'monospace',
            fontSize: 11, color: const Color(0xFFE2E8F0))),
  );
}