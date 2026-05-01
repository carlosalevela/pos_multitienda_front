import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/cliente.dart';
import '../../../models/separado.dart';
import '../../../providers/cliente_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClienteProvider>().cargarDetalleCliente(widget.cliente.id);
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

  const _DetalleTabBar({
    required this.controller,
    required this.separadosCount,
    required this.historialCount,
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
        labelColor:           _Pal.teal,
        unselectedLabelColor: _Pal.inkLight,
        indicatorColor:       _Pal.teal,
        indicatorWeight:      2.5,
        labelStyle:           GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w600),
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