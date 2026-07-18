// lib/screens/dashboard/admin_dashboard.dart
// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/venta_service.dart';

import '../../providers/auth_provider.dart';
import '../pos/pos_screen.dart';
import '../inventario/inventario_screen.dart';
import '../reportes/reportes_screen.dart';
import '../caja/caja_screen.dart';
import '../empleados/empleados_screen.dart';
import '../contabilidad/contabilidad_screen.dart';
import '../tiendas/tiendas_screen.dart';
import '../clientes/clientes_screen.dart';
import '../compras/compras_modulo_screen.dart';
import '../empresas/empresas_screen.dart';
import '../devoluciones/devoluciones_screen.dart';
import '../caja/caja_dashboard_admin.dart';
import '../cajero_inicio/cajero_dashboard.dart';
import '../separados/separados_screen.dart';
import '../configuracion/configuracion_screen.dart';

class _C {
  static const bg = Color(0xFFF5F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFEEF1F4);
  static const textPrimary = Color(0xFF111827);
  static const textSecond = Color(0xFF6B7280);
  static const textFaint = Color(0xFF9CA3AF);
  static const green = Color(0xFF61DDAA);
  static const greenLight = Color(0xFFE8FFF4);
  static const greenDark = Color(0xFF0B7A53);
  static const amber = Color(0xFFB45309);
  static const amberLight = Color(0xFFFEF3C7);
  static const rose = Color(0xFFBE123C);
  static const roseLight = Color(0xFFFFF1F2);
  static const indigo = Color(0xFF3730A3);
  static const indigoLight = Color(0xFFEEF2FF);
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF5F3FF);
  static const sidebar = Color(0xFFFFFFFF);
  static const sidebarHov = Color(0xFFF3F4F6);
}

class _KPI {
  final String title, sub, value, trend;
  final bool? trendUp;
  final IconData icon;
  final Color accent, accentBg;
  final VoidCallback? onTap;
  const _KPI({required this.title, required this.sub, required this.value, required this.trend, this.trendUp, required this.icon, required this.accent, required this.accentBg, this.onTap});
}

class _Movement {
  final String id, type, description, detail, user, time;
  const _Movement({required this.id, required this.type, required this.description, required this.detail, required this.user, required this.time});
}

class _QuickAction {
  final String title, sub, screen;
  final IconData icon;
  final Color accent, bg, border;
  const _QuickAction({required this.title, required this.sub, required this.screen, required this.icon, required this.accent, required this.bg, required this.border});
}

class _NavItem {
  final String label, screen;
  final IconData icon;
  const _NavItem({required this.label, required this.screen, required this.icon});
}

final _quickActions = [
  const _QuickAction(title: 'Punto de Venta POS', sub: 'Registra ventas en terminal activa.', screen: 'pos', icon: Icons.shopping_cart_outlined, accent: _C.indigo, bg: _C.indigoLight, border: Color(0xFFD4D4F7)),
  const _QuickAction(title: 'Cortes & Arqueo', sub: 'Consulta arqueo teórico vs físico.', screen: 'cash', icon: Icons.account_balance_outlined, accent: _C.amber, bg: _C.amberLight, border: Color(0xFFFDE68A)),
  const _QuickAction(title: 'Clientes', sub: 'Consulta clientes y movimientos.', screen: 'clientes', icon: Icons.people_outline_rounded, accent: _C.purple, bg: _C.purpleLight, border: Color(0xFFDDD6FE)),
  const _QuickAction(title: 'Logística', sub: 'Recibe embarques y surte almacenes.', screen: 'compras', icon: Icons.local_shipping_outlined, accent: _C.green, bg: _C.greenLight, border: Color(0xFFBBF7D0)),
];

List<_NavItem> _buildNavItems(String rol) {
  final items = <_NavItem>[
    const _NavItem(label: 'Dashboard', screen: 'dashboard', icon: Icons.dashboard_rounded),
    const _NavItem(label: 'POS / Ventas', screen: 'pos', icon: Icons.point_of_sale_rounded),
    const _NavItem(label: 'Inventario', screen: 'inventory', icon: Icons.inventory_2_rounded),
    const _NavItem(label: 'Caja', screen: 'cash', icon: Icons.account_balance_wallet_rounded),
    const _NavItem(label: 'Contabilidad', screen: 'contabilidad', icon: Icons.bar_chart_rounded),
    const _NavItem(label: 'Reportes', screen: 'reports', icon: Icons.assessment_rounded),
    const _NavItem(label: 'Clientes', screen: 'clientes', icon: Icons.people_alt_rounded),
    const _NavItem(label: 'Separados', screen: 'separados', icon: Icons.bookmark_rounded),
    const _NavItem(label: 'Compras', screen: 'compras', icon: Icons.shopping_cart_rounded),
    const _NavItem(label: 'Devoluciones', screen: 'devoluciones', icon: Icons.assignment_return_rounded),
    const _NavItem(label: 'Empleados', screen: 'empleados', icon: Icons.people_rounded),
    const _NavItem(label: 'Tiendas', screen: 'stores', icon: Icons.store_rounded),
    const _NavItem(label: 'Empresas', screen: 'empresas', icon: Icons.business_rounded),
    const _NavItem(label: 'Configuración', screen: 'configuracion', icon: Icons.settings_outlined),
  ];

  bool allowed(_NavItem item) {
    switch (item.screen) {
      case 'dashboard': return ['cajero', 'admin', 'supervisor', 'superadmin'].contains(rol);
      case 'pos': return rol == 'cajero';
      case 'inventory': return ['admin', 'supervisor', 'superadmin', 'cajero'].contains(rol);
      case 'cash': return ['cajero', 'admin', 'supervisor', 'superadmin'].contains(rol);
      case 'contabilidad': return ['admin', 'supervisor', 'superadmin'].contains(rol);
      case 'reports': return rol == 'cajero';
      case 'clientes': return ['admin', 'supervisor', 'cajero', 'superadmin'].contains(rol);
      case 'separados': return ['admin', 'supervisor', 'superadmin'].contains(rol);
      case 'suppliers': return ['admin', 'supervisor', 'superadmin'].contains(rol);
      case 'compras': return ['admin', 'supervisor', 'superadmin'].contains(rol);
      case 'devoluciones': return ['admin', 'supervisor', 'cajero', 'superadmin'].contains(rol);
      case 'empleados': return ['admin', 'superadmin'].contains(rol);
      case 'stores': return ['admin', 'superadmin'].contains(rol);
      case 'empresas': return ['admin', 'superadmin'].contains(rol);
      case 'configuracion': return ['admin', 'supervisor', 'superadmin'].contains(rol);
      default: return false;
    }
  }

  if (rol == 'superadmin') {
    return items.where((i) => [
      'dashboard',
      'inventory',
      'compras',
      'contabilidad',
      'cash',
      'clientes',
      'separados',
      'devoluciones',
      'empleados',
      'stores',
      'empresas',
      'configuracion',
    ].contains(i.screen)).toList();
  }
  return items.where(allowed).toList();
}

class AdminDashboard extends StatefulWidget {
  final String userName;
  final String userRole;
  final String branch;
  const AdminDashboard({super.key, this.userName = 'Sofía Martínez Ortega', this.userRole = 'Administrativo Central', this.branch = 'POS Multimedia Corporativo'});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _activeScreen = 'dashboard';
  bool _sidebarOpen = true;

  void _navigate(String screen) {
    setState(() => _activeScreen = screen);
    if (MediaQuery.of(context).size.width < 900) {
      setState(() => _sidebarOpen = false);
    }
  }

  Widget _buildScreenByKey(String screen, String rol, String userName) {
    switch (screen) {
      case 'dashboard':
        if (rol == 'cajero') return CajeroDashboard(onNavigate: _navigate);
        return _DashboardBody(userName: userName.split(' ').first, onNavigate: _navigate);
      case 'pos': return PosScreen(onNavigate: _navigate);
      case 'inventory': return const InventarioScreen();
      case 'cash':
        if (rol == 'admin' || rol == 'superadmin') return const CajaDashboardAdmin();
        return const CajaScreen();
      case 'contabilidad': return const ContabilidadScreen();
      case 'reports': return const ReportesScreen();
      case 'clientes':
        if (rol == 'cajero') return const SeparadosScreen();
        return ClientesScreen(esAdminOSupervisor: rol == 'admin' || rol == 'supervisor' || rol == 'superadmin');
      case 'separados': return const SeparadosScreen();
      case 'suppliers': return const ComprasModuloScreen();
      case 'compras': return const ComprasModuloScreen();
      case 'devoluciones': return const DevolucionesScreen();
      case 'empleados': return const EmpleadosScreen();
      case 'stores': return const TiendasScreen();
      case 'empresas': return const EmpresasScreen();
      case 'configuracion': return const ConfiguracionScreen();
      default: return _PlaceholderScreen(screen: screen, onBack: () => _navigate('dashboard'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 1024;
    final isTablet = w >= 768 && w < 1024;
    final auth = context.watch<AuthProvider>();
    final navItems = _buildNavItems(auth.rol);

    if (!navItems.any((n) => n.screen == _activeScreen) && navItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _activeScreen = navItems.first.screen);
      });
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(children: [
        if (isDesktop || (isTablet && _sidebarOpen))
          _Sidebar(activeScreen: _activeScreen, onNavigate: _navigate, userName: widget.userName, userRole: widget.userRole, navItems: navItems),
        Expanded(
          child: Column(children: [
            _TopBar(branch: widget.branch, userName: widget.userName, userRole: widget.userRole, showMenuBtn: !isDesktop, onMenuTap: () => setState(() => _sidebarOpen = !_sidebarOpen)),
            Expanded(child: _buildScreenByKey(_activeScreen, auth.rol, widget.userName)),
          ]),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String activeScreen, userName, userRole;
  final List<_NavItem> navItems;
  final void Function(String) onNavigate;
  const _Sidebar({required this.activeScreen, required this.onNavigate, required this.userName, required this.userRole, required this.navItems});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: _C.sidebar,
      child: Column(children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.point_of_sale_rounded, size: 16, color: Colors.white)),
            const SizedBox(width: 10),
            Text('SIS POS', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          ]),
        ),
        Container(height: 1, color: _C.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            children: [
              _SidebarSection(label: 'MÓDULOS'),
              ...navItems.map((n) => _NavTile(item: n, active: activeScreen == n.screen, onTap: () => onNavigate(n.screen))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.border))),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: _C.greenLight, borderRadius: BorderRadius.circular(17)), child: Center(child: Text(userName[0], style: GoogleFonts.inter(color: _C.greenDark, fontWeight: FontWeight.w700, fontSize: 14)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(userName.split(' ').first, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text(userRole, style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10), overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(onTap: () => context.read<AuthProvider>().logout(), child: Icon(Icons.logout_rounded, size: 16, color: _C.textSecond)),
          ]),
        ),
      ]),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final String label;
  const _SidebarSection({required this.label});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(10, 10, 0, 4), child: Text(label, style: GoogleFonts.inter(color: _C.textFaint, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)));
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      hoverColor: _C.sidebarHov,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active ? const Color(0xFFCFF7E4) : Colors.transparent,
          border: active ? Border.all(color: const Color(0xFFA7EBCF)) : null,
        ),
        child: Row(children: [
          Icon(item.icon, size: 18, color: active ? const Color(0xFF0F172A) : _C.textSecond),
          const SizedBox(width: 10),
          Expanded(child: Text(item.label, style: GoogleFonts.inter(color: active ? const Color(0xFF0F172A) : _C.textSecond, fontSize: 12.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500))),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String branch, userName, userRole;
  final bool showMenuBtn;
  final VoidCallback onMenuTap;
  const _TopBar({required this.branch, required this.userName, required this.userRole, required this.showMenuBtn, required this.onMenuTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: _C.surface, border: Border(bottom: BorderSide(color: _C.border))),
      child: Row(children: [
        if (showMenuBtn) ...[IconButton(icon: const Icon(Icons.menu_rounded), onPressed: onMenuTap, color: _C.textSecond, padding: EdgeInsets.zero), const SizedBox(width: 8)],
        Text('Consola Central', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('•', style: TextStyle(color: _C.border, fontSize: 14))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)), child: Text(branch, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 11, fontWeight: FontWeight.w600))),
        const Spacer(),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(userName, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(userRole, style: GoogleFonts.inter(color: _C.greenDark, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(width: 10),
        Container(width: 36, height: 36, decoration: BoxDecoration(color: _C.greenLight, borderRadius: BorderRadius.circular(18)), child: Center(child: Text(userName[0], style: GoogleFonts.inter(color: _C.greenDark, fontWeight: FontWeight.w800, fontSize: 14)))),
      ]),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  final String userName;
  final void Function(String) onNavigate;
  const _DashboardBody({required this.userName, required this.onNavigate});
  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final _svc = VentaService();

  bool    _loading = true;
  String? _error;
  String  _periodo = 'mensual';

  double _ventasHoy         = 0;
  double _variacionPct      = 0;
  int    _inventarioBajo    = 0;
  int    _alertasCriticas   = 0;
  double _balanceMensual    = 0;
  int    _comprasPendientes = 0;

  List<Map<String, dynamic>> _ventasPorTienda = [];
  List<Map<String, dynamic>> _transacciones   = [];
  List<Map<String, dynamic>> _desempeno       = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    final res = await _svc.getDashboardAdmin(periodo: _periodo);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() { _loading = false; _error = res['error']?.toString() ?? 'Error al cargar'; });
      return;
    }
    final d    = res['data'] as Map<String, dynamic>;
    final kpis = d['kpis']  as Map<String, dynamic>;
    setState(() {
      _loading           = false;
      _ventasHoy         = (kpis['ventas_hoy']               as num).toDouble();
      _variacionPct      = (kpis['ventas_hoy_variacion_pct']  as num).toDouble();
      _inventarioBajo    = (kpis['inventario_bajo_sku']        as num).toInt();
      _alertasCriticas   = (kpis['alertas_criticas']           as num).toInt();
      _balanceMensual    = (kpis['balance_mensual']            as num).toDouble();
      _comprasPendientes = (kpis['compras_pendientes']         as num).toInt();
      _ventasPorTienda   = List<Map<String, dynamic>>.from(d['ventas_por_tienda']       ?? []);
      _transacciones     = List<Map<String, dynamic>>.from(d['transacciones_recientes'] ?? []);
      _desempeno         = List<Map<String, dynamic>>.from(d['desempeno_tiendas']       ?? []);
    });
  }

  String _fmt(double v) {
    final abs    = v.abs();
    final prefix = v < 0 ? '-' : '';
    if (abs >= 1000000) return '$prefix\$${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000)    return '$prefix\$${(abs / 1000).toStringAsFixed(0)}K';
    return '$prefix\$${abs.toStringAsFixed(0)}';
  }

  String _relTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1)  return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_rounded, size: 48, color: _C.textFaint),
        const SizedBox(height: 16),
        Text(_error!, style: GoogleFonts.inter(color: _C.textSecond, fontSize: 13)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(backgroundColor: _C.green, foregroundColor: Colors.white, elevation: 0),
        ),
      ]));
    }

    final totalBajo = _inventarioBajo + _alertasCriticas;

    final kpis = [
      _KPI(
        title: 'Ventas Hoy', sub: 'vs ayer',
        value: _fmt(_ventasHoy),
        trend: '${_variacionPct >= 0 ? '+' : ''}${_variacionPct.toStringAsFixed(1)}%',
        trendUp: _variacionPct >= 0,
        icon: Icons.attach_money_rounded, accent: _C.green, accentBg: _C.greenLight,
      ),
      _KPI(
        title: 'Balance Mensual', sub: 'Ventas − Gastos',
        value: _fmt(_balanceMensual),
        trend: _balanceMensual >= 0 ? 'Positivo' : 'Negativo',
        trendUp: _balanceMensual >= 0,
        icon: Icons.account_balance_outlined,
        accent: _balanceMensual >= 0 ? _C.indigo : _C.rose,
        accentBg: _balanceMensual >= 0 ? _C.indigoLight : _C.roseLight,
      ),
      _KPI(
        title: 'Alerta Existencias', sub: '$_alertasCriticas críticos',
        value: '$totalBajo',
        trend: totalBajo > 4 ? 'Revisar urgente' : 'Bajo control',
        trendUp: totalBajo <= 4,
        icon: Icons.inventory_2_outlined,
        accent: totalBajo > 4 ? _C.rose : _C.amber,
        accentBg: totalBajo > 4 ? _C.roseLight : _C.amberLight,
        onTap: () => widget.onNavigate('inventory'),
      ),
      _KPI(
        title: 'Compras Pendientes', sub: 'Por recibir',
        value: '$_comprasPendientes',
        trend: _comprasPendientes > 0 ? 'Atención requerida' : 'Al día',
        trendUp: _comprasPendientes == 0,
        icon: Icons.shopping_cart_outlined,
        accent: _comprasPendientes > 0 ? _C.amber : _C.indigo,
        accentBg: _comprasPendientes > 0 ? _C.amberLight : _C.indigoLight,
        onTap: () => widget.onNavigate('compras'),
      ),
    ];

    final movements = _transacciones.map((t) {
      final esVenta = (t['tipo'] as String) == 'venta';
      final monto   = (t['monto'] as num).toDouble();
      return _Movement(
        id:          t['numero']   as String,
        type:        esVenta ? 'out' : 'in',
        description: esVenta ? 'Venta Registrada' : 'Devolución Procesada',
        detail:      '\$${monto.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
        user:        t['tienda']   as String,
        time:        _relTime(t['created_at'] as String),
      );
    }).toList();

    final w      = MediaQuery.of(context).size.width;
    final isWide = w >= 1100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: _C.greenDark, borderRadius: BorderRadius.circular(16)),
          child: Stack(children: [
            Positioned(right: -20, top: -20, child: Icon(Icons.point_of_sale_rounded, size: 140, color: Colors.white.withOpacity(0.04))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(4)), child: Text('PERSPECTIVA GENERAL DEL NEGOCIO', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
                const Spacer(),
                _PeriodToggle(value: _periodo, onChange: (p) { setState(() => _periodo = p); _cargar(); }),
              ]),
              const SizedBox(height: 12),
              Text('¡Bienvenido, ${widget.userName}!', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 8),
              Text(
                totalBajo > 0
                    ? 'Hay $totalBajo SKUs con stock bajo ($_alertasCriticas críticos) y $_comprasPendientes compras pendientes.'
                    : 'Inventario en buen estado. $_comprasPendientes compras pendientes de recibir.',
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.65), fontSize: 12.5, height: 1.6),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 24),

        // KPIs
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth >= 900 ? 4 : c.maxWidth >= 600 ? 2 : 1;
          return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: c.maxWidth >= 900 ? 1.9 : 2.2, children: kpis.map((k) => _KPICard(kpi: k)).toList());
        }),
        const SizedBox(height: 24),

        // Transacciones + acciones rápidas
        isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: _MovementsCard(movements: movements)),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: _QuickActionsCard(onNavigate: widget.onNavigate)),
              ])
            : Column(children: [
                _MovementsCard(movements: movements),
                const SizedBox(height: 20),
                _QuickActionsCard(onNavigate: widget.onNavigate),
              ]),

        // Ventas por tienda
        if (_ventasPorTienda.isNotEmpty) ...[
          const SizedBox(height: 24),
          _VentasPorTiendaCard(ventas: _ventasPorTienda, periodo: _periodo),
        ],

        // Desempeño por tienda
        if (_desempeno.isNotEmpty) ...[
          const SizedBox(height: 24),
          _DesempenoCard(desempeno: _desempeno),
        ],

        const SizedBox(height: 8),
      ]),
    );
  }
}

class _KPICard extends StatelessWidget {
  final _KPI kpi;
  const _KPICard({required this.kpi});
  @override
  Widget build(BuildContext context) {
    final trendColor = kpi.trendUp == null ? _C.textFaint : kpi.trendUp! ? _C.green : _C.rose;
    final trendIcon = kpi.trendUp == null ? Icons.remove_rounded : kpi.trendUp! ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    return GestureDetector(
      onTap: kpi.onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(kpi.title, style: GoogleFonts.inter(color: _C.textSecond, fontSize: 11.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)), Container(width: 34, height: 34, decoration: BoxDecoration(color: kpi.accentBg, borderRadius: BorderRadius.circular(8)), child: Icon(kpi.icon, size: 17, color: kpi.accent))]),
          Text(kpi.value, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
          Row(children: [Icon(trendIcon, size: 13, color: trendColor), const SizedBox(width: 4), Text(kpi.trend, style: GoogleFonts.inter(color: trendColor, fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(width: 6), Text(kpi.sub, style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10), overflow: TextOverflow.ellipsis)]),
        ]),
      ),
    );
  }
}

class _MovementsCard extends StatelessWidget {
  final List<_Movement> movements;
  const _MovementsCard({required this.movements});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.history_rounded, size: 15, color: _C.indigo), const SizedBox(width: 8), Text('Auditoría: Bitácora del Día', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))]), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)), child: Text('Últimas ${movements.length} acciones', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10)))]),
        const SizedBox(height: 4),
        Divider(color: _C.divider),
        const SizedBox(height: 8),
        ...movements.map((m) => _MovementRow(m: m)),
      ]),
    );
  }
}

class _MovementRow extends StatelessWidget {
  final _Movement m;
  const _MovementRow({required this.m});
  @override
  Widget build(BuildContext context) {
    final colors = {'in': (bg: const Color(0xFFECFDF5), fg: const Color(0xFF065F46), label: 'INGRESO'), 'out': (bg: const Color(0xFFFFF1F2), fg: const Color(0xFF9F1239), label: 'EGRESO'), 'transfer': (bg: const Color(0xFFEFF6FF), fg: const Color(0xFF1E40AF), label: 'TRASPASO')};
    final c = colors[m.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border.withOpacity(0.6))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(3), border: Border.all(color: c.fg.withOpacity(0.2))), child: Text(c.label, style: GoogleFonts.inter(color: c.fg, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5))), const SizedBox(width: 8), Flexible(child: Text('${m.time} · ${m.user}', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10), overflow: TextOverflow.ellipsis))]), const SizedBox(height: 5), Text(m.description, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(m.detail, style: GoogleFonts.inter(color: _C.textSecond, fontSize: 11), overflow: TextOverflow.ellipsis)])), const SizedBox(width: 8), Text(m.id, style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10))]),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final void Function(String) onNavigate;
  const _QuickActionsCard({required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.bolt_rounded, size: 15, color: _C.indigo), const SizedBox(width: 8), Text('Accesos y Operaciones Rápidas', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 4),
        Divider(color: _C.divider),
        const SizedBox(height: 10),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55, children: _quickActions.map((a) => _QuickActionTile(action: a, onTap: () => onNavigate(a.screen))).toList()),
      ]),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback onTap;
  const _QuickActionTile({required this.action, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: action.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: action.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(action.icon, size: 20, color: action.accent),
          const SizedBox(height: 8),
          Text(action.title, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(action.sub, style: GoogleFonts.inter(color: _C.textSecond, fontSize: 10, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Toggle semanal / mensual ───────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChange;
  const _PeriodToggle({required this.value, required this.onChange});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _PeriodBtn(label: 'Semanal', active: value == 'semanal', onTap: () => onChange('semanal')),
        _PeriodBtn(label: 'Mensual', active: value == 'mensual', onTap: () => onChange('mensual')),
      ]),
    );
  }
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PeriodBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: active ? Colors.white.withOpacity(0.25) : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

// ── Ventas por tienda (barras horizontales) ────────────────────────────────

class _VentasPorTiendaCard extends StatelessWidget {
  final List<Map<String, dynamic>> ventas;
  final String periodo;
  const _VentasPorTiendaCard({required this.ventas, required this.periodo});
  @override
  Widget build(BuildContext context) {
    final maxVal = ventas.map((v) => (v['total'] as num).toDouble()).reduce(max);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 15, color: _C.green),
          const SizedBox(width: 8),
          Text('Ventas por Tienda', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)), child: Text(periodo == 'semanal' ? 'Esta semana' : 'Este mes', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10))),
        ]),
        const SizedBox(height: 4),
        Divider(color: _C.divider),
        const SizedBox(height: 12),
        ...ventas.map((v) {
          final total = (v['total'] as num).toDouble();
          final pct   = maxVal > 0 ? (total / maxVal).clamp(0.0, 1.0) : 0.0;
          final label = '\$${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(v['nombre'] as String, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                Text(label, style: GoogleFonts.inter(color: _C.textSecond, fontSize: 11)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct, backgroundColor: _C.bg, color: _C.green, minHeight: 8),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Desempeño por tienda ───────────────────────────────────────────────────

class _DesempenoCard extends StatelessWidget {
  final List<Map<String, dynamic>> desempeno;
  const _DesempenoCard({required this.desempeno});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.store_outlined, size: 15, color: _C.indigo), const SizedBox(width: 8), Text('Desempeño por Tienda', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 4),
        Divider(color: _C.divider),
        const SizedBox(height: 8),
        ...desempeno.map((t) => _DesempenoRow(t: t)),
      ]),
    );
  }
}

class _DesempenoRow extends StatelessWidget {
  final Map<String, dynamic> t;
  const _DesempenoRow({required this.t});

  Color  _bg(String e)  => e == 'optimo' ? _C.greenLight  : e == 'estable' ? _C.indigoLight : _C.amberLight;
  Color  _fg(String e)  => e == 'optimo' ? _C.greenDark   : e == 'estable' ? _C.indigo      : _C.amber;
  String _lbl(String e) => e == 'optimo' ? 'ÓPTIMO'       : e == 'estable' ? 'ESTABLE'      : 'MODERADO';

  @override
  Widget build(BuildContext context) {
    final estado      = t['estado'] as String;
    final ventasHoy   = (t['ventas_hoy'] as num).toDouble();
    final eficiencia  = t['eficiencia_pct'] as int;
    final label = '\$${ventasHoy.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border.withOpacity(0.6))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _bg(estado), borderRadius: BorderRadius.circular(3), border: Border.all(color: _fg(estado).withOpacity(0.2))), child: Text(_lbl(estado), style: GoogleFonts.inter(color: _fg(estado), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
            const SizedBox(width: 8),
            Flexible(child: Text(t['encargado'] as String, style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 5),
          Text(t['nombre'] as String, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${t['cajas_activas']} caja(s) activa(s) · Eficiencia: $eficiencia%', style: GoogleFonts.inter(color: _C.textSecond, fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Placeholder ────────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String screen;
  final VoidCallback onBack;
  const _PlaceholderScreen({required this.screen, required this.onBack});
  @override
  Widget build(BuildContext context) {
    final labels = {'pos': 'Punto de Venta POS', 'inventory': 'Gestión de Inventario', 'cash': 'Cortes & Arqueo de Caja', 'layaway': 'Apartados de Clientes', 'suppliers': 'Proveedores & Órdenes', 'stores': 'Rendimiento de Sucursales', 'reports': 'Reportes Financieros'};
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: _C.greenLight, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.construction_rounded, size: 30, color: _C.green)), const SizedBox(height: 20), Text(labels[screen] ?? screen, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text('Este módulo se implementará en la siguiente iteración.', style: GoogleFonts.inter(color: _C.textSecond, fontSize: 13)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, size: 16), label: const Text('Volver al Dashboard'), style: ElevatedButton.styleFrom(backgroundColor: _C.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12))), ]));
  }
}
