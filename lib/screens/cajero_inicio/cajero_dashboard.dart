// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/caja_provider.dart';
import '../../models/separado.dart';
import '../../services/cliente_service.dart';

// ── Paleta (misma que admin_dashboard) ────────────────────────────────────
class _C {
  static const bg          = Color(0xFFF5F7F8);
  static const surface     = Color(0xFFFFFFFF);
  static const border      = Color(0xFFE5E7EB);
  static const divider     = Color(0xFFEEF1F4);
  static const textPrimary = Color(0xFF111827);
  static const textSecond  = Color(0xFF6B7280);
  static const textFaint   = Color(0xFF9CA3AF);
  static const green       = Color(0xFF61DDAA);
  static const greenLight  = Color(0xFFE8FFF4);
  static const greenDark   = Color(0xFF0B7A53);
  static const amber       = Color(0xFFB45309);
  static const amberLight  = Color(0xFFFEF3C7);
  static const rose        = Color(0xFFBE123C);
  static const roseLight   = Color(0xFFFFF1F2);
  static const indigo      = Color(0xFF3730A3);
  static const indigoLight = Color(0xFFEEF2FF);
}

// ── Widget principal ───────────────────────────────────────────────────────

class CajeroDashboard extends StatefulWidget {
  final void Function(String) onNavigate;
  const CajeroDashboard({super.key, required this.onNavigate});

  @override
  State<CajeroDashboard> createState() => _CajeroDashboardState();
}

class _CajeroDashboardState extends State<CajeroDashboard> {
  final _clienteSvc = ClienteService();

  bool   _loading = true;
  List<Separado>           _separados = [];
  Map<String, dynamic>     _alertas   = {'vencidos': [], 'por_vencer': [], 'total_alertas': 0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final caja = context.read<CajaProvider>();

    // Verificar sesión de caja si no está cargada
    if (caja.sesionActiva == null && auth.tiendaId > 0) {
      await caja.verificarSesion(auth.tiendaId);
    }

    // Cargar separados y alertas en paralelo (cajero tiene acceso)
    if (auth.tiendaId > 0) {
      try {
        final results = await Future.wait([
          _clienteSvc.getSeparados(tiendaId: auth.tiendaId, estado: 'activo'),
          _clienteSvc.getAlertasSeparados(tiendaId: auth.tiendaId),
        ]);
        if (!mounted) return;
        setState(() {
          _separados = results[0] as List<Separado>;
          _alertas   = results[1] as Map<String, dynamic>;
        });
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);
  }

  String _fmt(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth         = context.watch<AuthProvider>();
    final caja         = context.watch<CajaProvider>();
    final sesion       = caja.sesionActiva;
    final cajaAbierta  = sesion?.abierta ?? false;
    final nombre       = auth.nombre.split(' ').first;

    final separadosListos   = _separados.where((s) => s.saldoPendiente <= 0).toList();
    final alertasTotal      = (_alertas['total_alertas'] as int?) ?? 0;
    final vencidos          = (_alertas['vencidos']   as List?) ?? [];
    final porVencer         = (_alertas['por_vencer'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Banner bienvenida ──────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(color: _C.greenDark, borderRadius: BorderRadius.circular(14)),
          child: Stack(children: [
            Positioned(right: -10, top: -10,
              child: Icon(Icons.point_of_sale_rounded, size: 110, color: Colors.white.withOpacity(0.05))),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hola, $nombre 👋',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  cajaAbierta
                    ? 'Tu turno está activo · Caja abierta'
                    : 'No tienes una caja abierta aún',
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.70), fontSize: 12.5)),
              ])),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigate('pos'),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('Nueva Venta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── KPI Cards ──────────────────────────────────────────
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth >= 700 ? 3 : 1;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: c.maxWidth >= 700 ? 2.1 : 3.2,
            children: [
              _KpiCard(
                title: 'Estado de Caja',
                value: cajaAbierta ? _fmt(sesion!.saldo_inicial) : '—',
                sub: cajaAbierta ? 'ABIERTA' : 'CERRADA',
                subColor: cajaAbierta ? _C.greenDark : _C.rose,
                subBg:    cajaAbierta ? _C.greenLight : _C.roseLight,
                icon: Icons.account_balance_wallet_outlined,
                accent: cajaAbierta ? _C.green : _C.rose,
                accentBg: cajaAbierta ? _C.greenLight : _C.roseLight,
                onTap: () => widget.onNavigate('cash'),
              ),
              _KpiCard(
                title: 'Ventas del Turno',
                value: cajaAbierta ? _fmt(sesion!.ventasTotal) : '—',
                sub: cajaAbierta
                  ? '${sesion!.numTransacciones} transacciones'
                  : 'Sin caja activa',
                icon: Icons.trending_up_rounded,
                accent: _C.indigo,
                accentBg: _C.indigoLight,
              ),
              _KpiCard(
                title: 'Separados Listos',
                value: _loading ? '…' : '${separadosListos.length}',
                sub: separadosListos.isNotEmpty ? 'listos para entregar' : 'sin pendientes hoy',
                icon: Icons.inventory_2_outlined,
                accent: separadosListos.isNotEmpty ? _C.amber : _C.green,
                accentBg: separadosListos.isNotEmpty ? _C.amberLight : _C.greenLight,
                badge: separadosListos.isNotEmpty,
                onTap: () => widget.onNavigate('clientes'),
              ),
            ],
          );
        }),
        const SizedBox(height: 20),

        // ── Fila inferior ──────────────────────────────────────
        LayoutBuilder(builder: (_, c) {
          final wide = c.maxWidth >= 800;

          final separadosCard = _SeparadosCard(
            separados: _separados.take(4).toList(),
            loading: _loading,
            onTap: () => widget.onNavigate('clientes'),
          );
          final alertasCard = _AlertasCard(
            vencidos: vencidos,
            porVencer: porVencer,
            total: alertasTotal,
            onTap: () => widget.onNavigate('clientes'),
          );
          final accionesCard = _AccionesCard(onNavigate: widget.onNavigate);

          return wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: separadosCard),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: alertasCard),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: accionesCard),
              ])
            : Column(children: [
                separadosCard,
                const SizedBox(height: 16),
                alertasCard,
                const SizedBox(height: 16),
                accionesCard,
              ]);
        }),

        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── KPI Card ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String title, value, sub;
  final Color  accent, accentBg;
  final Color  subColor, subBg;
  final IconData icon;
  final bool badge;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title, required this.value, required this.sub,
    required this.icon,  required this.accent, required this.accentBg,
    this.subColor = _C.textFaint,
    this.subBg    = Colors.transparent,
    this.badge    = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(title,
                style: GoogleFonts.inter(color: _C.textSecond, fontSize: 11.5, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              Stack(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 16, color: accent)),
                if (badge)
                  Positioned(top: 0, right: 0,
                    child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: _C.rose, shape: BoxShape.circle))),
              ]),
            ]),
            Text(value,
              style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            subBg != Colors.transparent
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: subBg, borderRadius: BorderRadius.circular(4)),
                  child: Text(sub,
                    style: GoogleFonts.inter(color: subColor, fontSize: 10, fontWeight: FontWeight.w700)))
              : Text(sub, style: GoogleFonts.inter(color: _C.textFaint, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Separados Card ─────────────────────────────────────────────────────────

class _SeparadosCard extends StatelessWidget {
  final List<Separado> separados;
  final bool loading;
  final VoidCallback onTap;
  const _SeparadosCard({required this.separados, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 15, color: _C.textFaint),
            const SizedBox(width: 8),
            Text('Apartados Pendientes',
              style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text('Ver todos',
              style: GoogleFonts.inter(color: _C.greenDark, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
        Divider(color: _C.divider),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
        else if (separados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Sin apartados activos',
              style: GoogleFonts.inter(color: _C.textFaint, fontSize: 12)))
        else
          ...separados.map((s) => _SeparadoRow(s: s)),
      ]),
    );
  }
}

class _SeparadoRow extends StatelessWidget {
  final Separado s;
  const _SeparadoRow({required this.s});

  @override
  Widget build(BuildContext context) {
    final ini      = s.clienteNombre.isNotEmpty ? s.clienteNombre[0].toUpperCase() : '?';
    final pendiente = s.saldoPendiente > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.bg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border.withOpacity(0.5))),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: _C.greenLight, borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(ini,
            style: GoogleFonts.inter(color: _C.greenDark, fontWeight: FontWeight.w700, fontSize: 13)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.clienteNombre,
            style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
          Text(s.detalles.isNotEmpty ? s.detalles.first.productoNombre : 'Sin productos',
            style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10), overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${s.saldoPendiente.toStringAsFixed(2)}',
            style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: pendiente ? _C.amberLight : _C.greenLight,
              borderRadius: BorderRadius.circular(4)),
            child: Text(pendiente ? 'Pendiente' : 'Listo',
              style: GoogleFonts.inter(
                color: pendiente ? _C.amber : _C.greenDark,
                fontSize: 9, fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }
}

// ── Alertas Card ───────────────────────────────────────────────────────────

class _AlertasCard extends StatelessWidget {
  final List  vencidos, porVencer;
  final int   total;
  final VoidCallback onTap;
  const _AlertasCard({required this.vencidos, required this.porVencer, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_rounded, size: 15, color: _C.rose),
          const SizedBox(width: 8),
          Text('Alertas de Separados',
            style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _C.roseLight, borderRadius: BorderRadius.circular(20)),
              child: Text('$total', style: GoogleFonts.inter(color: _C.rose, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        Divider(color: _C.divider),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, size: 16, color: _C.green),
              const SizedBox(width: 6),
              Text('Sin alertas activas', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 12)),
            ]))
        else ...[
          ...vencidos.take(2).map((a) => _AlertaItem(
            label: 'VENCIDO',
            nombre: (a['cliente'] ?? '') as String,
            saldo: double.tryParse(a['saldo_pendiente']?.toString() ?? '0') ?? 0,
            dias: (a['dias_restantes'] as int?) ?? -1,
            esVencido: true)),
          ...porVencer.take(2).map((a) => _AlertaItem(
            label: 'POR VENCER',
            nombre: (a['cliente'] ?? '') as String,
            saldo: double.tryParse(a['saldo_pendiente']?.toString() ?? '0') ?? 0,
            dias: (a['dias_restantes'] as int?) ?? 0,
            esVencido: false)),
          if (total > 4)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('Ver todas (+${total - 4})',
                style: GoogleFonts.inter(color: _C.greenDark, fontSize: 11, fontWeight: FontWeight.w600))),
        ],
      ]),
    );
  }
}

class _AlertaItem extends StatelessWidget {
  final String label, nombre;
  final double saldo;
  final int    dias;
  final bool   esVencido;
  const _AlertaItem({
    required this.label, required this.nombre,
    required this.saldo, required this.dias, required this.esVencido,
  });

  String _fmtSaldo(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  String get _diasLabel {
    if (dias < 0) return 'Venció hace ${dias.abs()} día(s)';
    if (dias == 0) return 'Vence hoy';
    return 'Vence en $dias día(s)';
  }

  @override
  Widget build(BuildContext context) {
    final color = esVencido ? _C.rose : _C.amber;
    final bg    = esVencido ? _C.roseLight : _C.amberLight.withOpacity(0.5);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6), bottomRight: Radius.circular(6))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(nombre.isNotEmpty ? nombre : '—',
            style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
          Text(_diasLabel,
            style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10)),
        ])),
        if (saldo > 0)
          Text(_fmtSaldo(saldo),
            style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Acciones Rápidas ───────────────────────────────────────────────────────

class _AccionesCard extends StatelessWidget {
  final void Function(String) onNavigate;
  const _AccionesCard({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bolt_rounded, size: 15, color: _C.textFaint),
          const SizedBox(width: 8),
          Text('Acciones Rápidas',
            style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        Divider(color: _C.divider),
        _AccionTile(icon: Icons.add_shopping_cart_rounded, label: 'Nueva Venta',
          color: _C.greenDark, bg: _C.greenLight, onTap: () => onNavigate('pos')),
        _AccionTile(icon: Icons.assignment_return_rounded, label: 'Devolución',
          color: _C.textSecond, bg: _C.bg, onTap: () => onNavigate('devoluciones')),
        _AccionTile(icon: Icons.account_balance_wallet_outlined, label: 'Ir a Caja',
          color: _C.indigo, bg: _C.indigoLight, onTap: () => onNavigate('cash')),
        _AccionTile(icon: Icons.people_alt_outlined, label: 'Clientes',
          color: _C.amber, bg: _C.amberLight, onTap: () => onNavigate('clientes')),
      ]),
    );
  }
}

class _AccionTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color, bg;
  final VoidCallback onTap;
  const _AccionTile({required this.icon, required this.label, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.border.withOpacity(0.5))),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, size: 16, color: _C.textFaint),
        ]),
      ),
    );
  }
}
