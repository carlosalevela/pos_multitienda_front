// lib/features/caja/widgets/historial_admin_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caja_provider.dart';
import '../../../providers/empresa_provider.dart';
import '../../../providers/tienda_provider.dart';
import '../../../models/sesion_historial.dart';
import 'detalle_cierre_sheet.dart';                // ← NUEVO


class HistorialAdminTab extends StatefulWidget {
  final bool esSuperadmin;
  const HistorialAdminTab({super.key, required this.esSuperadmin});

  @override
  State<HistorialAdminTab> createState() => _HistorialAdminTabState();
}


class _HistorialAdminTabState extends State<HistorialAdminTab> {
  int?   _empresaSeleccionada;
  int?   _tiendaSeleccionada;
  String _nombreEmpresa = '';
  String _nombreTienda  = '';
  final  _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializar());
  }

  void _inicializar() {
    final auth = context.read<AuthProvider>();

    if (widget.esSuperadmin) {
      context.read<EmpresaProvider>().cargarEmpresas();
    } else {
      final empId = int.tryParse(auth.empresaId) ?? 0;
      if (empId > 0) {
        _empresaSeleccionada = empId;
        _nombreEmpresa       = auth.empresaNombre;
        context.read<TiendaProvider>().cargarTiendasPorEmpresa(empId);
      }
    }
  }

  void _seleccionarEmpresa(int id, String nombre) {
    setState(() {
      _empresaSeleccionada = id;
      _nombreEmpresa       = nombre;
      _tiendaSeleccionada  = null;
      _nombreTienda        = '';
    });
    context.read<TiendaProvider>().cargarTiendasPorEmpresa(id);
    context.read<CajaProvider>().limpiarHistorial();
  }

  void _seleccionarTienda(int id, String nombre) {
    setState(() {
      _tiendaSeleccionada = id;
      _nombreTienda       = nombre;
    });
    context.read<CajaProvider>().cargarHistorial(tiendaId: id);
  }

  String _f(double v) => '\$${_fmt.format(v)}';

  @override
  Widget build(BuildContext context) {
    final empresaProv = context.watch<EmpresaProvider>();
    final tiendaProv  = context.watch<TiendaProvider>();
    final cajaProv    = context.watch<CajaProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Selectores ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Selector empresa (solo superadmin)
              if (widget.esSuperadmin) ...[
                Text('Empresa',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B))),
                const SizedBox(height: 8),
                empresaProv.cargando
                    ? _loadingChip()
                    : Wrap(
                        spacing: 8, runSpacing: 8,
                        children: empresaProv.empresas.map((e) {
                          final sel = _empresaSeleccionada == e.id;
                          return _selectorChip(
                            label:    e.nombre,
                            selected: sel,
                            onTap:    () => _seleccionarEmpresa(e.id, e.nombre),
                            color:    const Color(0xFF6366F1),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 14),
              ],

              // Selector tienda
              Text('Sucursal',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B))),
              const SizedBox(height: 8),
              _empresaSeleccionada == null
                  ? Text('Selecciona una empresa primero',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: const Color(0xFFCBD5E1),
                          fontStyle: FontStyle.italic))
                  : tiendaProv.cargando
                      ? _loadingChip()
                      : tiendaProv.tiendas.isEmpty
                          ? Text('Sin sucursales disponibles',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: const Color(0xFFCBD5E1),
                                  fontStyle: FontStyle.italic))
                          : Wrap(
                              spacing: 8, runSpacing: 8,
                              children: tiendaProv.tiendas.map((t) {
                                final sel = _tiendaSeleccionada == t.id;
                                return _selectorChip(
                                  label:    t.nombre,
                                  selected: sel,
                                  onTap:    () => _seleccionarTienda(t.id, t.nombre),
                                  color:    const Color(0xFF10B981),
                                );
                              }).toList(),
                            ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Breadcrumb ────────────────────────────────────────
        if (_tiendaSeleccionada != null) ...[
          Row(children: [
            const Icon(Icons.store_rounded, size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            if (widget.esSuperadmin) ...[
              Text(_nombreEmpresa,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right_rounded,
                    size: 14, color: Color(0xFFCBD5E1)),
              ),
            ],
            Text(_nombreTienda,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${cajaProv.historial.length} sesiones',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: const Color(0xFF94A3B8))),
          ]),
          const SizedBox(height: 12),
        ],

        // ── Lista historial ───────────────────────────────────
        Expanded(
          child: _tiendaSeleccionada == null
              ? _estadoVacio(
                  icon:    Icons.store_rounded,
                  mensaje: widget.esSuperadmin
                      ? 'Selecciona una empresa y sucursal'
                      : 'Selecciona una sucursal',
                )
              : cajaProv.cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6366F1)))
                  : cajaProv.historial.isEmpty
                      ? _estadoVacio(
                          icon:    Icons.history_rounded,
                          mensaje: 'Sin sesiones registradas en esta sucursal',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount:        cajaProv.historial.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder:      (_, i)  => _sesionCard(cajaProv.historial[i]),
                        ),
        ),
      ],
    );
  }

  // ── Tarjeta de sesión ─────────────────────────────────────
  Widget _sesionCard(SesionHistorial s) {
    final esExacto   = s.diferencia.abs() < 0.01;
    final esSobrante = s.diferencia > 0;
    final statusColor = esExacto
        ? const Color(0xFF10B981)
        : esSobrante ? const Color(0xFF6366F1) : const Color(0xFFEF4444);
    final statusLabel = esExacto ? 'Exacto'
        : esSobrante ? 'Sobrante' : 'Faltante';

    return Material(                                         // ← NUEVO
      color: Colors.transparent,
      child: InkWell(                                        // ← NUEVO
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(                   // ← NUEVO
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DetalleCierreSheet(sesion: s),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(children: [

            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Text(
                    s.empleadoNombre.isNotEmpty
                        ? s.empleadoNombre[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w800,
                        fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(s.empleadoNombre,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B))),
                  Text(_formatFecha(s.fechaApertura),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: const Color(0xFF94A3B8))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.25)),
                ),
                child: Text(statusLabel,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,        // ← NUEVO
                  size: 16, color: Color(0xFFCBD5E1)),
            ]),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.black.withOpacity(0.05)),
            const SizedBox(height: 12),

            Row(children: [
              _statCol('Ventas',     _f(s.ventasTotal),       const Color(0xFF10B981)),
              _statCol('Gastos',     _f(s.gastosTotal),       const Color(0xFFEF4444)),
              _statCol('Esperado',   _f(s.montoFinalSistema), const Color(0xFF6366F1)),
              _statCol('Diferencia',
                  '${s.diferencia >= 0 ? '+' : ''}\$${_fmt.format(s.diferencia.abs())}',
                  statusColor),
            ]),

            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.receipt_rounded, size: 12, color: Color(0xFFCBD5E1)),
              const SizedBox(width: 4),
              Text('${s.numTransacciones} ventas',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: const Color(0xFF94A3B8))),
              const SizedBox(width: 12),
              const Icon(Icons.account_balance_wallet_rounded,
                  size: 12, color: Color(0xFFCBD5E1)),
              const SizedBox(width: 4),
              Text('Inicial: ${_f(s.saldoInicial)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: const Color(0xFF94A3B8))),
              if (s.numDevoluciones > 0) ...[
                const SizedBox(width: 12),
                const Icon(Icons.assignment_return_rounded,
                    size: 12, color: Color(0xFFCBD5E1)),
                const SizedBox(width: 4),
                Text('${s.numDevoluciones} devoluciones',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  Widget _statCol(String label, String valor, Color color) => Expanded(
    child: Column(children: [
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 10, color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(valor,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: color, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _selectorChip({
    required String       label,
    required bool         selected,
    required VoidCallback onTap,
    required Color        color,
  }) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        selected ? color.withOpacity(0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color.withOpacity(0.4) : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : const Color(0xFF64748B))),
      ),
    );

  Widget _loadingChip() => Container(
    width: 80, height: 32,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10)),
    child: const Center(
      child: SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF94A3B8)))),
  );

  Widget _estadoVacio({required IconData icon, required String mensaje}) =>
    Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(18)),
          child: Icon(icon, size: 30, color: const Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 14),
        Text(mensaje,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500)),
      ]),
    );

  String _formatFecha(String fecha) {
    if (fecha.length >= 16) return fecha.substring(0, 16).replaceAll('T', ' ');
    return fecha.replaceAll('T', ' ');
  }
}