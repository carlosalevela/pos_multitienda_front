import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/cliente.dart';
import '../../../models/separado.dart';
import '../../../models/tier_model.dart';
import '../../../providers/cliente_provider.dart';
import '../../../services/tier_service.dart';
import '../../../services/venta_service.dart';

// ─────────────────────────────────────────────────────────────
// Paleta — misma que clientes_screen.dart
// ─────────────────────────────────────────────────────────────
class _Pal {
  static const teal        = Color(0xFF01696F);
  static const tealSurface = Color(0xFFE8F4F5);
  static const bg          = Color(0xFFF2F5F7);
  static const ink         = Color(0xFF141C22);
  static const inkMid      = Color(0xFF4A5568);
  static const inkLight    = Color(0xFF9DAAB7);
  static const success     = Color(0xFF2E9E6B);
  static const danger      = Color(0xFFE03E3E);

  static const avatarPalette = [
    [Color(0xFF01696F), Color(0xFF02A8B0)],
    [Color(0xFF5B4CF5), Color(0xFF8B7FF8)],
    [Color(0xFFD97706), Color(0xFFF59E0B)],
    [Color(0xFF059669), Color(0xFF34D399)],
    [Color(0xFFDB2777), Color(0xFFF472B6)],
    [Color(0xFF0284C7), Color(0xFF38BDF8)],
    [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    [Color(0xFFDC2626), Color(0xFFF87171)],
  ];
}

List<Color> _avatarGradient(String nombre) {
  final idx = nombre.isEmpty ? 0 : nombre.codeUnitAt(0) % _Pal.avatarPalette.length;
  return _Pal.avatarPalette[idx];
}

// ─────────────────────────────────────────────────────────────
// ENTRY POINT — llamar desde clientes_screen.dart
// ─────────────────────────────────────────────────────────────
class ClienteDetalleSheet {
  static void mostrar(
    BuildContext context, {
    required Cliente      cliente,
    required bool         esAdminOSupervisor,
    required VoidCallback onEditar,
    required VoidCallback onDesactivar,
  }) {
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder: (_) => _ClienteDetalleSheetContent(
        cliente:             cliente,
        esAdminOSupervisor:  esAdminOSupervisor,
        onEditar:            onEditar,
        onDesactivar:        onDesactivar,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CONTENIDO DEL SHEET
// ─────────────────────────────────────────────────────────────
class _ClienteDetalleSheetContent extends StatefulWidget {
  final Cliente      cliente;
  final bool         esAdminOSupervisor;
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;

  const _ClienteDetalleSheetContent({
    required this.cliente,
    required this.esAdminOSupervisor,
    required this.onEditar,
    required this.onDesactivar,
  });

  @override
  State<_ClienteDetalleSheetContent> createState() =>
      _ClienteDetalleSheetContentState();
}

class _ClienteDetalleSheetContentState
    extends State<_ClienteDetalleSheetContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<TierModel>            _tiers           = [];
  bool                       _cargandoTiers   = false;
  List<Map<String, dynamic>> _ventasCliente   = [];
  bool                       _cargandoVentas  = false;
  Map<String, dynamic>?      _creditosData;
  bool                       _cargandoCreditos = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClienteProvider>().cargarDetalleCliente(widget.cliente.id);
      _cargarTiers();
      _cargarVentasCliente();
      if (widget.cliente.limiteCredito > 0) _cargarCreditos();
    });
  }

  Future<void> _cargarTiers() async {
    setState(() => _cargandoTiers = true);
    final res = await TierService().getTiers();
    if (!mounted) return;
    setState(() {
      _cargandoTiers = false;
      if (res['success'] == true) {
        _tiers = List<TierModel>.from(res['data'] as List);
      }
    });
  }

  Future<void> _cargarVentasCliente() async {
    setState(() => _cargandoVentas = true);
    try {
      final list = await VentaService().listarVentas(
        clienteId: widget.cliente.id,
      );
      if (mounted) setState(() { _ventasCliente = list; _cargandoVentas = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoVentas = false);
    }
  }

  Future<void> _cargarCreditos() async {
    setState(() => _cargandoCreditos = true);
    final res = await VentaService().getCreditosCliente(widget.cliente.id);
    if (!mounted) return;
    setState(() {
      _cargandoCreditos = false;
      if (res['success'] == true) _creditosData = res['data'] as Map<String, dynamic>;
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    context.read<ClienteProvider>().limpiarDetalleCliente();
    super.dispose();
  }

  // ── Abonar ────────────────────────────────────────────────
  void _mostrarAbonar(Separado sep) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _AbonarSheet(
        separado: sep,
        onAbonar: (monto, metodo) async {
          final prov = context.read<ClienteProvider>();
          final ok   = await prov.abonarSeparado(sep.id, monto, metodo);
          if (!mounted) return;
          Navigator.pop(context);
          _showSnack(
            ok ? 'Abono registrado correctamente'
               : (prov.error ?? 'Error al registrar abono'),
            ok ? _Pal.success : _Pal.danger,
          );
        },
      ),
    );
  }

  // ── Cancelar ──────────────────────────────────────────────
  Future<void> _confirmarCancelar(Separado sep) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        titulo:  '¿Cancelar separado?',
        mensaje: 'Se revertirá el stock de ${sep.detalles.length} '
                 'producto${sep.detalles.length != 1 ? 's' : ''}. '
                 'Esta acción no se puede deshacer.',
        accion:  'Cancelar separado',
        color:   _Pal.danger,
      ),
    );
    if (ok != true || !mounted) return;
    final prov   = context.read<ClienteProvider>();
    final result = await prov.cancelarSeparado(sep.id);
    if (!mounted) return;
    _showSnack(
      result ? 'Separado cancelado'
             : (prov.error ?? 'Error al cancelar'),
      result ? _Pal.success : _Pal.danger,
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.plusJakartaSans(fontSize: 13)),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gradient  = _avatarGradient(widget.cliente.nombre);
    final iniciales = [
      widget.cliente.nombre.isNotEmpty   ? widget.cliente.nombre[0]   : '',
      widget.cliente.apellido.isNotEmpty ? widget.cliente.apellido[0] : '',
    ].join().toUpperCase();

    return Consumer<ClienteProvider>(
      builder: (_, prov, __) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Handle
          Center(
            child: Container(
              width:  36, height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color:        const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Avatar + nombre
          _AvatarHeader(
            cliente:    widget.cliente,
            gradient:   gradient,
            iniciales:  iniciales,
          ),

          // TabBar
          _DetalleTabBar(
            controller:      _tabCtrl,
            separadosCount:  prov.separadosActivos.length,
            historialCount:  prov.historialCliente.length,
            ventasCount:     _ventasCliente.length,
            tieneTier:       widget.cliente.tierInfo != null,
            tieneCredito:    widget.cliente.limiteCredito > 0,
            deudaCredito:    (_creditosData?['deuda_total'] as num?)?.toDouble() ?? 0,
          ),

          const Divider(height: 1, color: Color(0xFFEBEFF3)),

          // Contenido
          Flexible(
            child: prov.cargandoDetalle
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: _Pal.teal, strokeWidth: 2.5),
                    ),
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: [

                      // Tab 1 — Información
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(children: [
                          _InfoCard(cliente: widget.cliente),
                          if (widget.esAdminOSupervisor) ...[
                            const SizedBox(height: 16),
                            _AccionesBotones(
                              onEditar:     widget.onEditar,
                              onDesactivar: widget.onDesactivar,
                            ),
                          ],
                        ]),
                      ),

                      // Tab 2 — Separados activos
                      prov.separadosActivos.isEmpty
                          ? const _TabVacio(
                              icon:    Icons.inventory_2_outlined,
                              mensaje: 'Sin separados activos',
                              sub:     'Los separados activos de este cliente\naparecerán aquí.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: prov.separadosActivos.length,
                              itemBuilder: (_, i) => _SeparadoCard(
                                separado:   prov.separadosActivos[i],
                                esAdmin:    widget.esAdminOSupervisor,
                                onAbonar:   () => _mostrarAbonar(prov.separadosActivos[i]),
                                onCancelar: () => _confirmarCancelar(prov.separadosActivos[i]),
                              ),
                            ),

                      // Tab 3 — Historial
                      prov.historialCliente.isEmpty
                          ? const _TabVacio(
                              icon:    Icons.history_rounded,
                              mensaje: 'Sin historial',
                              sub:     'Los separados completados y cancelados\naparecerán aquí.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: prov.historialCliente.length,
                              itemBuilder: (_, i) =>
                                  _HistorialCard(separado: prov.historialCliente[i]),
                            ),

                      // Tab 4 — Fidelización
                      _TabFidelizacion(
                        cliente:        widget.cliente,
                        tiers:          _tiers,
                        cargandoTiers:  _cargandoTiers,
                      ),

                      // Tab 5 — Compras (historial de ventas)
                      _TabCompras(
                        ventas:          _ventasCliente,
                        cargando:        _cargandoVentas,
                        onRefresh:       _cargarVentasCliente,
                      ),

                      // Tab 6 — Crédito
                      _TabCredito(
                        cliente:          widget.cliente,
                        creditosData:     _creditosData,
                        cargando:         _cargandoCreditos,
                        onRefresh:        _cargarCreditos,
                        onSnack:          _showSnack,
                      ),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AVATAR HEADER
// ─────────────────────────────────────────────────────────────
class _AvatarHeader extends StatelessWidget {
  final Cliente      cliente;
  final List<Color>  gradient;
  final String       iniciales;

  const _AvatarHeader({
    required this.cliente,
    required this.gradient,
    required this.iniciales,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient[0].withOpacity(0.07),
            gradient[1].withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: Row(children: [
        Container(
          width:  56, height: 56,
          decoration: BoxDecoration(
            gradient:     LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color:      gradient[0].withOpacity(0.30),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(iniciales,
                style: GoogleFonts.plusJakartaSans(
                    color:      Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize:   19)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cliente.nombreCompleto,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize:   17,
                      fontWeight: FontWeight.w800,
                      color:      _Pal.ink)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cliente.activo
                      ? _Pal.teal.withOpacity(0.10)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cliente.activo
                        ? _Pal.teal.withOpacity(0.25)
                        : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    cliente.activo
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_rounded,
                    size:  11,
                    color: cliente.activo ? _Pal.teal : _Pal.inkLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cliente.activo ? 'Activo' : 'Inactivo',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color: cliente.activo ? _Pal.teal : _Pal.inkLight),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB BAR
// ─────────────────────────────────────────────────────────────
class _DetalleTabBar extends StatelessWidget {
  final TabController controller;
  final int           separadosCount;
  final int           historialCount;
  final int           ventasCount;
  final bool          tieneTier;
  final bool          tieneCredito;
  final double        deudaCredito;

  const _DetalleTabBar({
    required this.controller,
    required this.separadosCount,
    required this.historialCount,
    required this.ventasCount,
    required this.tieneTier,
    required this.tieneCredito,
    required this.deudaCredito,
  });

  Widget _badge(int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(10)),
    child: Text('$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller:           controller,
        isScrollable:         true,
        tabAlignment:         TabAlignment.start,
        labelColor:           _Pal.teal,
        unselectedLabelColor: _Pal.inkLight,
        indicatorColor:       _Pal.teal,
        indicatorWeight:      2.5,
        labelStyle:           GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w600),
        tabs: [
          const Tab(text: 'Información'),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Separados'),
              if (separadosCount > 0) ...[
                const SizedBox(width: 5),
                _badge(separadosCount, _Pal.teal),
              ],
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Historial'),
              if (historialCount > 0) ...[
                const SizedBox(width: 5),
                _badge(historialCount, _Pal.inkLight),
              ],
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(tieneTier ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 14),
              const SizedBox(width: 4),
              const Text('Fideliz.'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Compras'),
              if (ventasCount > 0) ...[
                const SizedBox(width: 5),
                _badge(ventasCount, _Pal.teal),
              ],
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.handshake_rounded, size: 14),
              const SizedBox(width: 4),
              const Text('Crédito'),
              if (tieneCredito && deudaCredito > 0) ...[
                const SizedBox(width: 5),
                _badge(1, const Color(0xFF7C3AED)),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INFO CARD
// ─────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Cliente cliente;
  const _InfoCard({required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFFEBEFF3)),
      ),
      child: Column(children: [
        if (cliente.cedulaNit?.isNotEmpty ?? false)
          _InfoRow(Icons.badge_outlined,       'Cédula',     cliente.cedulaNit!),
        if (cliente.telefono.isNotEmpty)
          _InfoRow(Icons.phone_rounded,        'Teléfono',   cliente.telefono),
        if (cliente.email.isNotEmpty)
          _InfoRow(Icons.email_outlined,       'Email',      cliente.email),
        if (cliente.direccion.isNotEmpty)
          _InfoRow(Icons.location_on_outlined, 'Dirección',  cliente.direccion,
              isLast: true),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     isLast;
  const _InfoRow(this.icon, this.label, this.value, {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width:  32, height: 32,
          decoration: BoxDecoration(
            color:        _Pal.teal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: _Pal.teal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: _Pal.inkLight,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: _Pal.ink,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTONES EDITAR / DESACTIVAR
// ─────────────────────────────────────────────────────────────
class _AccionesBotones extends StatelessWidget {
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;
  const _AccionesBotones({required this.onEditar, required this.onDesactivar});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onEditar,
          icon:  const Icon(Icons.edit_rounded, size: 16),
          label: Text('Editar',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _Pal.teal,
            side:    const BorderSide(color: _Pal.teal),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:   RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13)),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onDesactivar,
          icon:  const Icon(Icons.person_off_rounded, size: 16),
          label: Text('Desactivar',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _Pal.danger,
            foregroundColor: Colors.white,
            elevation:       0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13)),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// TAB VACÍO
// ─────────────────────────────────────────────────────────────
class _TabVacio extends StatelessWidget {
  final IconData icon;
  final String   mensaje;
  final String   sub;
  const _TabVacio({
    required this.icon,
    required this.mensaje,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width:  64, height: 64,
          decoration: BoxDecoration(
            color:        _Pal.teal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 30, color: _Pal.teal.withOpacity(0.5)),
        ),
        const SizedBox(height: 14),
        Text(mensaje,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w700, color: _Pal.ink)),
        const SizedBox(height: 6),
        Text(sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _Pal.inkLight)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// SEPARADO CARD
// ─────────────────────────────────────────────────────────────
class _SeparadoCard extends StatelessWidget {
  final Separado     separado;
  final bool         esAdmin;
  final VoidCallback onAbonar;
  final VoidCallback onCancelar;

  const _SeparadoCard({
    required this.separado,
    required this.esAdmin,
    required this.onAbonar,
    required this.onCancelar,
  });

  static final _fmt    = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  static final _fmtFec = DateFormat('dd MMM yyyy', 'es');

  Color get _progresoColor {
    final p = separado.progreso;
    if (p >= 1.0) return _Pal.success;
    if (p >= 0.5) return _Pal.teal;
    return const Color(0xFFD97706);
  }

  @override
  Widget build(BuildContext context) {
    final sep     = separado;
    final vencido = sep.fechaLimite != null &&
        DateTime.tryParse(sep.fechaLimite!)?.isBefore(DateTime.now()) == true;

    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(
          color: vencido
              ? _Pal.danger.withOpacity(0.35)
              : const Color(0xFFEBEFF3),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Cabecera
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color:        _Pal.teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('SEP-${sep.id}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: _Pal.teal)),
          ),
          const SizedBox(width: 8),
          if (sep.fechaLimite != null) ...[
            Icon(
              vencido ? Icons.warning_rounded : Icons.event_rounded,
              size:  13,
              color: vencido ? _Pal.danger : _Pal.inkLight,
            ),
            const SizedBox(width: 3),
            Text(
              _fmtFec.format(DateTime.parse(sep.fechaLimite!)),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: vencido ? _Pal.danger : _Pal.inkLight),
            ),
          ],
          const Spacer(),
          if (sep.empleadoNombre != null)
            Text(sep.empleadoNombre!,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: _Pal.inkLight)),
        ]),

        const SizedBox(height: 10),

        // Productos
        ...sep.detalles.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            const Icon(Icons.circle, size: 5, color: _Pal.inkLight),
            const SizedBox(width: 7),
            Expanded(
              child: Text(d.productoNombre,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: _Pal.inkMid)),
            ),
            Text(
              '×${d.cantidad % 1 == 0 ? d.cantidad.toInt() : d.cantidad}  '
              '${_fmt.format(d.subtotal)}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: _Pal.inkMid),
            ),
          ]),
        )),

        const SizedBox(height: 10),

        // Totales
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: _Pal.inkLight)),
              Text(_fmt.format(sep.total),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: _Pal.ink)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Abonado',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: _Pal.inkLight)),
            Text(_fmt.format(sep.abonoAcumulado),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _Pal.success)),
          ]),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Saldo',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: _Pal.inkLight)),
            Text(_fmt.format(sep.saldoPendiente),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _Pal.danger)),
          ]),
        ]),

        const SizedBox(height: 10),

        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           sep.progreso,
            minHeight:       6,
            backgroundColor: const Color(0xFFEBEFF3),
            valueColor:      AlwaysStoppedAnimation(_progresoColor),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(sep.progreso * 100).toStringAsFixed(0)}% pagado',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, color: _Pal.inkLight)),
        ),

        const SizedBox(height: 10),

        // Botones
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onAbonar,
              icon:  const Icon(Icons.add_rounded, size: 15),
              label: Text('Abonar',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _Pal.teal,
                foregroundColor: Colors.white,
                elevation:       0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (esAdmin) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onCancelar,
              icon:  const Icon(Icons.cancel_outlined, size: 15),
              label: Text('Cancelar',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _Pal.danger,
                side:    BorderSide(color: _Pal.danger.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape:   RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HISTORIAL CARD
// ─────────────────────────────────────────────────────────────
class _HistorialCard extends StatelessWidget {
  final Separado separado;
  const _HistorialCard({required this.separado});

  static final _fmt    = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  static final _fmtFec = DateFormat('dd MMM yyyy · HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final sep       = separado;
    final cancelado = sep.esCancelado;

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        cancelado ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFFEBEFF3)),
      ),
      child: Row(children: [
        Container(
          width:  40, height: 40,
          decoration: BoxDecoration(
            color: cancelado
                ? const Color(0xFFF0F0F0)
                : _Pal.success.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            cancelado ? Icons.cancel_rounded : Icons.check_circle_rounded,
            size:  20,
            color: cancelado ? _Pal.inkLight : _Pal.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('SEP-${sep.id}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: cancelado ? _Pal.inkLight : _Pal.ink)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cancelado
                      ? const Color(0xFFF0F0F0)
                      : _Pal.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cancelado ? 'Cancelado' : 'Pagado',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: cancelado ? _Pal.inkLight : _Pal.success),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              '${sep.detalles.length} producto${sep.detalles.length != 1 ? 's' : ''}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: _Pal.inkLight),
            ),
            const SizedBox(height: 2),
            Text(_fmtFec.format(sep.createdAt),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: _Pal.inkLight)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt.format(sep.total),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: cancelado ? _Pal.inkLight : _Pal.ink)),
          if (!cancelado)
            Text('Abonado: ${_fmt.format(sep.abonoAcumulado)}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: _Pal.success)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB COMPRAS — historial de ventas del cliente
// ─────────────────────────────────────────────────────────────
class _TabCompras extends StatelessWidget {
  final List<Map<String, dynamic>> ventas;
  final bool     cargando;
  final VoidCallback onRefresh;

  const _TabCompras({
    required this.ventas,
    required this.cargando,
    required this.onRefresh,
  });

  static final _fmt     = NumberFormat('#,##0', 'es_CO');
  static final _fmtDate = DateFormat('d MMM yyyy', 'es');
  static final _fmtHora = DateFormat('HH:mm', 'es');

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: _Pal.teal, strokeWidth: 2.5),
        ),
      );
    }

    if (ventas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 30, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text('Sin compras registradas',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _Pal.inkMid)),
            const SizedBox(height: 6),
            Text('Las ventas asociadas a este cliente\naparecerán aquí.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _Pal.inkLight)),
          ],
        ),
      );
    }

    final completadas = ventas.where((v) => v['estado'] == 'completada').length;
    final totalGastado = ventas
        .where((v) => v['estado'] == 'completada')
        .fold<double>(0, (s, v) => s + _toDouble(v['total']));

    return RefreshIndicator(
      color: _Pal.teal,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: ventas.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            // ── KPIs ──────────────────────────────────
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Expanded(child: _kpiCard(
                  '\$${_fmt.format(totalGastado)}',
                  'Total gastado',
                  _Pal.teal, _Pal.tealSurface,
                  Icons.payments_rounded,
                )),
                const SizedBox(width: 10),
                Expanded(child: _kpiCard(
                  '$completadas',
                  'Compras realizadas',
                  const Color(0xFF2E9E6B),
                  const Color(0xFFDCFCE7),
                  Icons.receipt_rounded,
                )),
              ]),
            );
          }

          // ── Tarjeta de venta ───────────────────────
          final v       = ventas[i - 1];
          final id      = v['id'] as int;
          final nroFact = v['numero_factura'] as String? ?? '#$id';
          final total   = _toDouble(v['total']);
          final metodo  = v['metodo_pago'] as String? ?? '';
          final estado  = v['estado'] as String? ?? 'completada';
          final anulada = estado == 'anulada';
          final createdAt = v['created_at'] as String?;
          DateTime? dt;
          try {
            dt = createdAt != null ? DateTime.parse(createdAt).toLocal() : null;
          } catch (_) {}

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: anulada ? const Color(0xFFFFF8F7) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: anulada
                      ? _Pal.danger.withValues(alpha: 0.2)
                      : const Color(0xFFEBEFF3),
                ),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: anulada ? const Color(0xFFFFDAD6) : _Pal.tealSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconMetodo(metodo), size: 18,
                      color: anulada ? _Pal.danger : _Pal.teal),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(nroFact,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: anulada ? _Pal.inkLight : _Pal.ink)),
                      const Spacer(),
                      Text('\$${_fmt.format(total)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: anulada ? _Pal.inkLight : _Pal.teal)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (dt != null) ...[
                        Expanded(
                          child: Text('${_fmtDate.format(dt)} · ${_fmtHora.format(dt)}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: _Pal.inkLight)),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: anulada
                              ? const Color(0xFFFFDAD6)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          anulada ? 'Anulada' : 'Completada',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: anulada ? _Pal.danger
                                  : const Color(0xFF2E9E6B)),
                        ),
                      ),
                    ]),
                  ],
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _kpiCard(String value, String label, Color color, Color bg, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEBEFF3)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: bg,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: GoogleFonts.plusJakartaSans(
                  fontSize: 9, color: _Pal.inkLight),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      );

  IconData _iconMetodo(String m) {
    return switch (m) {
      'efectivo'      => Icons.payments_outlined,
      'tarjeta'       => Icons.credit_card_outlined,
      'transferencia' => Icons.account_balance_outlined,
      'mixto'         => Icons.swap_horiz_rounded,
      _               => Icons.shopping_bag_outlined,
    };
  }
}

// ─────────────────────────────────────────────────────────────
// TAB FIDELIZACIÓN
// ─────────────────────────────────────────────────────────────
class _TabFidelizacion extends StatelessWidget {
  final Cliente        cliente;
  final List<TierModel> tiers;
  final bool           cargandoTiers;

  const _TabFidelizacion({
    required this.cliente,
    required this.tiers,
    required this.cargandoTiers,
  });

  static final _fmtCop = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  Color _tierColor(String hex) =>
      Color(int.parse(hex.replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    if (cargandoTiers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: _Pal.teal, strokeWidth: 2.5),
        ),
      );
    }

    final tierActual = cliente.tierInfo;
    final acumulado  = cliente.totalAcumulado;

    // Encuentra el modelo completo del tier actual y el siguiente
    TierModel? modelActual;
    TierModel? modelSiguiente;
    if (tierActual != null && tiers.isNotEmpty) {
      final sorted = [...tiers]..sort((a, b) =>
          a.umbralMin.compareTo(b.umbralMin));
      try {
        modelActual = sorted.firstWhere((t) => t.id == tierActual.id);
      } catch (_) {}
      if (modelActual != null) {
        final idx = sorted.indexOf(modelActual);
        if (idx + 1 < sorted.length) modelSiguiente = sorted[idx + 1];
      }
    }

    // Barra de progreso
    double progreso = 0;
    double falta    = 0;
    if (modelActual != null) {
      final min = modelActual.umbralMin;
      final max = modelSiguiente?.umbralMin ?? modelActual.umbralMax;
      if (max != null && max > min) {
        progreso = ((acumulado - min) / (max - min)).clamp(0.0, 1.0);
        falta    = (max - acumulado).clamp(0, double.infinity);
      } else {
        progreso = 1.0; // nivel máximo
      }
    } else if (tiers.isNotEmpty) {
      // Aún sin tier — buscar el primer umbral
      final sorted = [...tiers]..sort((a, b) =>
          a.umbralMin.compareTo(b.umbralMin));
      final primero = sorted.first;
      if (primero.umbralMin > 0) {
        progreso = (acumulado / primero.umbralMin).clamp(0.0, 1.0);
        falta    = (primero.umbralMin - acumulado).clamp(0, double.infinity);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Banner tier actual ──────────────────────────
        if (tierActual != null) ...[
          _TierBanner(
            tier:      tierActual,
            tierColor: _tierColor(tierActual.colorHex),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: const Color(0xFFEBEFF3)),
            ),
            child: Row(children: [
              Container(
                width:  44, height: 44,
                decoration: BoxDecoration(
                  color:        _Pal.inkLight.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star_outline_rounded,
                    size: 22, color: _Pal.inkLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sin tier asignado',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: _Pal.inkMid)),
                  const SizedBox(height: 2),
                  Text('Acumula compras para alcanzar el primer nivel',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: _Pal.inkLight)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── Total acumulado ─────────────────────────────
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        _Pal.teal.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: _Pal.teal.withOpacity(0.15)),
          ),
          child: Row(children: [
            Container(
              width:  38, height: 38,
              decoration: BoxDecoration(
                color:        _Pal.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: _Pal.teal),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total acumulado',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _Pal.teal,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_fmtCop.format(acumulado),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: _Pal.teal)),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Progreso al siguiente tier ──────────────────
        if (modelSiguiente != null || (tierActual == null && tiers.isNotEmpty)) ...[
          Text(
            modelSiguiente != null
                ? 'Progreso hacia "${modelSiguiente.nombre}"'
                : 'Progreso hacia "${([...tiers]..sort((a, b) => a.umbralMin.compareTo(b.umbralMin))).first.nombre}"',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _Pal.inkMid),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value:           progreso,
              minHeight:       10,
              backgroundColor: const Color(0xFFEBEFF3),
              valueColor:      const AlwaysStoppedAnimation(_Pal.teal),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${(progreso * 100).toStringAsFixed(0)}% completado',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: _Pal.inkLight)),
            if (falta > 0)
              Text('Faltan ${_fmtCop.format(falta)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _Pal.inkMid)),
          ]),
          const SizedBox(height: 16),
        ] else if (tierActual != null && modelSiguiente == null) ...[
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(children: [
              const Icon(Icons.emoji_events_rounded,
                  size: 18, color: Color(0xFFD4AF37)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('¡Nivel máximo alcanzado!',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: const Color(0xFF8B6F1E))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── Lista de todos los tiers ────────────────────
        if (tiers.isNotEmpty) ...[
          Text('Niveles de fidelización',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: _Pal.inkMid)),
          const SizedBox(height: 8),
          ...([...tiers]..sort((a, b) => a.umbralMin.compareTo(b.umbralMin)))
              .map((t) {
            final esCurrent = t.id == tierActual?.id;
            final tColor    = _tierColor(t.colorHex);
            return Container(
              margin:  const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:        esCurrent ? tColor.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(
                  color: esCurrent ? tColor.withOpacity(0.40) : const Color(0xFFEBEFF3),
                  width: esCurrent ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  width:  32, height: 32,
                  decoration: BoxDecoration(
                    color:        tColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.star_rounded, size: 16, color: tColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(t.nombre,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: esCurrent ? tColor : _Pal.ink)),
                      if (esCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:        tColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Actual',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ]),
                    Text(
                      t.umbralMax != null
                          ? 'Desde ${_fmtCop.format(t.umbralMin)} hasta ${_fmtCop.format(t.umbralMax!)}'
                          : 'Desde ${_fmtCop.format(t.umbralMin)}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, color: _Pal.inkLight),
                    ),
                  ]),
                ),
                Text('${t.descuentoPct.toStringAsFixed(0)}% desc.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: esCurrent ? tColor : _Pal.inkMid)),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

class _TierBanner extends StatelessWidget {
  final TierInfo tierInfo;
  final Color    tierColor;

  const _TierBanner({
    required TierInfo tier,
    required this.tierColor,
  }) : tierInfo = tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor, tierColor.withOpacity(0.75)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width:  52, height: 52,
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.star_rounded, size: 28, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nivel actual',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: Colors.white.withOpacity(0.80),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(tierInfo.nombre,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text('${tierInfo.descuentoPct.toStringAsFixed(0)}%',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text('descuento',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 9, color: Colors.white.withOpacity(0.80),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ABONAR SHEET
// ─────────────────────────────────────────────────────────────
class _AbonarSheet extends StatefulWidget {
  final Separado                      separado;
  final void Function(double, String) onAbonar;
  const _AbonarSheet({required this.separado, required this.onAbonar});

  @override
  State<_AbonarSheet> createState() => _AbonarSheetState();
}

class _AbonarSheetState extends State<_AbonarSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  String _metodo   = 'efectivo';
  bool   _enviando = false;

  static const _metodos = [
    ('efectivo',      'Efectivo',      Icons.payments_rounded),
    ('transferencia', 'Transferencia', Icons.swap_horiz_rounded),
    ('tarjeta',       'Tarjeta',       Icons.credit_card_rounded),
  ];

  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void dispose() { _montoCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sep    = widget.separado;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          Center(
            child: Container(
              width:  36, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color:        const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título
          Row(children: [
            Container(
              width:  40, height: 40,
              decoration: BoxDecoration(
                color:        _Pal.teal.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded, color: _Pal.teal, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Registrar abono',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: _Pal.ink)),
                Text('SEP-${sep.id} · Saldo: ${_fmt.format(sep.saldoPendiente)}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: _Pal.inkLight)),
              ]),
            ),
          ]),

          const SizedBox(height: 20),

          // Campo monto
          TextFormField(
            controller:   _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _Pal.ink),
            decoration: _inputDeco('Monto del abono', Icons.attach_money_rounded),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa el monto';
              final monto = double.tryParse(v);
              if (monto == null || monto <= 0) return 'Monto inválido';
              if (monto > sep.saldoPendiente) {
                return 'No puede superar el saldo (${_fmt.format(sep.saldoPendiente)})';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Método de pago
          Row(children: _metodos.map((m) {
            final activo = _metodo == m.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _metodo = m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin:  const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color:        activo ? _Pal.teal : const Color(0xFFF2F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: activo ? _Pal.teal : const Color(0xFFE4EAF0)),
                  ),
                  child: Column(children: [
                    Icon(m.$3, size: 18,
                        color: activo ? Colors.white : _Pal.inkLight),
                    const SizedBox(height: 4),
                    Text(m.$2,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: activo ? Colors.white : _Pal.inkMid)),
                  ]),
                ),
              ),
            );
          }).toList()),

          const SizedBox(height: 20),

          // Botón
          SizedBox(
            width:  double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _enviando
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _enviando = true);
                      widget.onAbonar(double.parse(_montoCtrl.text), _metodo);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:         _Pal.teal,
                foregroundColor:         Colors.white,
                disabledBackgroundColor: _Pal.teal.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text('Confirmar abono',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText:  hint,
    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: _Pal.inkLight),
    prefixIcon:    Icon(icon, size: 20, color: _Pal.teal),
    filled:        true,
    fillColor:     const Color(0xFFF8FAFB),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Color(0xFFE4EAF0))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Color(0xFFE4EAF0))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: _Pal.teal, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: _Pal.danger)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

// ─────────────────────────────────────────────────────────────
// CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String accion;
  final Color  color;

  const _ConfirmDialog({
    required this.titulo,
    required this.mensaje,
    required this.accion,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(titulo,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, fontSize: 16)),
      content: Text(mensaje,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: _Pal.inkMid)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Volver',
              style: GoogleFonts.plusJakartaSans(color: _Pal.inkLight)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(accion,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB CRÉDITO
// ─────────────────────────────────────────────────────────────
class _TabCredito extends StatelessWidget {
  final Cliente              cliente;
  final Map<String, dynamic>? creditosData;
  final bool                 cargando;
  final VoidCallback         onRefresh;
  final void Function(String, Color) onSnack;

  const _TabCredito({
    required this.cliente,
    required this.creditosData,
    required this.cargando,
    required this.onRefresh,
    required this.onSnack,
  });

  static final _fmt = NumberFormat('#,##0', 'es_CO');

  @override
  Widget build(BuildContext context) {
    if (cliente.limiteCredito <= 0) {
      return const _TabVacio(
        icon:    Icons.handshake_outlined,
        mensaje: 'Sin crédito habilitado',
        sub:     'Edita el cliente y asigna un\nlímite de crédito para habilitar el fiado.',
      );
    }

    if (cargando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFF7C3AED), strokeWidth: 2.5),
        ),
      );
    }

    final data    = creditosData;
    final ventas  = data == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(data['ventas'] as List);
    final limite  = (data?['limite_credito'] as num?)?.toDouble() ?? cliente.limiteCredito;
    final deuda   = (data?['deuda_total']    as num?)?.toDouble() ?? 0;
    final disponible = limite - deuda;
    final pct     = limite > 0 ? (deuda / limite).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF7C3AED),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Resumen
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.handshake_rounded, size: 16, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Text('Crédito', style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFF5B21B6))),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: const Color(0xFFEDE9FE),
                  valueColor: AlwaysStoppedAnimation(
                    pct > 0.85 ? const Color(0xFFDC2626) : const Color(0xFF7C3AED)),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _statChip('Deuda', '\$${_fmt.format(deuda)}',
                    deuda > 0 ? const Color(0xFFDC2626) : const Color(0xFF7C3AED)),
                _statChip('Disponible', '\$${_fmt.format(disponible)}',
                    const Color(0xFF059669)),
                _statChip('Límite', '\$${_fmt.format(limite)}',
                    const Color(0xFF5B21B6)),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          if (ventas.isEmpty)
            const _TabVacio(
              icon:    Icons.receipt_long_outlined,
              mensaje: 'Sin ventas a crédito',
              sub:     'Las ventas al fiado aparecerán aquí.',
            )
          else
            ...ventas.map((v) => _CreditoCard(
              venta:    v,
              onAbonar: () => _mostrarAbonar(context, v),
            )),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 10, color: _Pal.inkLight)),
      Text(value, style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ],
  );

  void _mostrarAbonar(BuildContext context, Map<String, dynamic> venta) {
    final saldo = (venta['saldo_pendiente'] as num).toDouble();
    if (saldo <= 0) return;
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _AbonarCreditoSheet(
        ventaId:        venta['id'] as int,
        numeroFactura:  venta['numero_factura'] as String,
        saldoPendiente: saldo,
        onAbonar: (monto, metodo) async {
          final res = await VentaService().abonarCredito(
              ventaId: venta['id'] as int, monto: monto, metodo: metodo);
          if (!context.mounted) return;
          Navigator.pop(context);
          onSnack(
            res['success'] == true
                ? 'Abono registrado correctamente'
                : (res['error'] ?? 'Error al registrar abono'),
            res['success'] == true ? _Pal.success : _Pal.danger,
          );
          if (res['success'] == true) onRefresh();
        },
      ),
    );
  }
}

// ─── Tarjeta de venta a crédito ──────────────────────────────
class _CreditoCard extends StatelessWidget {
  final Map<String, dynamic> venta;
  final VoidCallback         onAbonar;

  const _CreditoCard({required this.venta, required this.onAbonar});

  static final _fmt     = NumberFormat('#,##0', 'es_CO');
  static final _fmtDate = DateFormat('dd/MM/yyyy', 'es');

  @override
  Widget build(BuildContext context) {
    final saldo    = (venta['saldo_pendiente'] as num).toDouble();
    final total    = (venta['total']           as num).toDouble();
    final pagado   = (venta['total_pagado']    as num).toDouble();
    final fecha    = DateTime.tryParse(venta['fecha'] as String? ?? '');
    final estadoOk = saldo <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: estadoOk
              ? const Color(0xFF059669).withOpacity(0.3)
              : const Color(0xFF7C3AED).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color:  Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(venta['numero_factura'] as String,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _Pal.ink)),
            if (fecha != null) ...[
              const SizedBox(height: 2),
              Text(_fmtDate.format(fecha),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _Pal.inkLight)),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Text('Total: \$${_fmt.format(total)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _Pal.inkMid)),
              const SizedBox(width: 10),
              if (pagado > 0)
                Text('Pagado: \$${_fmt.format(pagado)}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: const Color(0xFF059669))),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: estadoOk
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              estadoOk ? 'Pagado' : '\$${_fmt.format(saldo)}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: estadoOk
                      ? const Color(0xFF059669)
                      : const Color(0xFF7C3AED)),
            ),
          ),
          if (!estadoOk) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onAbonar,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Abonar',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ─── Sheet de abono a crédito ─────────────────────────────────
class _AbonarCreditoSheet extends StatefulWidget {
  final int    ventaId;
  final String numeroFactura;
  final double saldoPendiente;
  final Future<void> Function(double monto, String metodo) onAbonar;

  const _AbonarCreditoSheet({
    required this.ventaId,
    required this.numeroFactura,
    required this.saldoPendiente,
    required this.onAbonar,
  });

  @override
  State<_AbonarCreditoSheet> createState() => _AbonarCreditoSheetState();
}

class _AbonarCreditoSheetState extends State<_AbonarCreditoSheet> {
  final _montoCtrl = TextEditingController();
  String _metodo   = 'efectivo';
  bool   _loading  = false;

  static final _fmt = NumberFormat('#,##0', 'es_CO');

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final monto = double.tryParse(_montoCtrl.text.trim());
    if (monto == null || monto <= 0) return;
    if (monto > widget.saldoPendiente) return;
    setState(() => _loading = true);
    await widget.onAbonar(monto, _metodo);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    const purple = Color(0xFF7C3AED);
    const purpleDark = Color(0xFF5B21B6);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(children: [
          const Icon(Icons.handshake_rounded, color: purple, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Abonar crédito',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 17, fontWeight: FontWeight.w800, color: purpleDark)),
            Text(widget.numeroFactura,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _Pal.inkLight)),
          ]),
        ]),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Saldo pendiente',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _Pal.inkMid)),
              Text('\$${_fmt.format(widget.saldoPendiente)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: purple)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Monto
        TextField(
          controller:  _montoCtrl,
          keyboardType: TextInputType.number,
          autofocus:   true,
          style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _Pal.ink),
          decoration: InputDecoration(
            labelText:  'Monto a abonar',
            prefixText: '\$ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: purple, width: 1.5)),
          ),
          onSubmitted: (_) => _confirmar(),
        ),
        const SizedBox(height: 12),
        // Método
        Row(children: [
          for (final (val, label, icon) in [
            ('efectivo',      'Efectivo',   Icons.payments_rounded),
            ('tarjeta',       'Tarjeta',    Icons.credit_card_rounded),
            ('transferencia', 'Transfer.',  Icons.account_balance_rounded),
          ]) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _metodo = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _metodo == val
                        ? purple.withOpacity(0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _metodo == val ? purple : const Color(0xFFE2E8F0),
                      width: _metodo == val ? 1.5 : 1),
                  ),
                  child: Column(children: [
                    Icon(icon, size: 16,
                        color: _metodo == val ? purpleDark : _Pal.inkLight),
                    const SizedBox(height: 2),
                    Text(label, style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: _metodo == val ? purpleDark : _Pal.inkLight)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text('Registrar abono',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}