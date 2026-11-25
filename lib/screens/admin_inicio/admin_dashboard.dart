// lib/screens/dashboard/admin_dashboard.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
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
import '../gastos/gastos_screen.dart';
import '../nomina/nomina_screen.dart';
import '../tiendas/tiendas_screen.dart';
import '../clientes/clientes_screen.dart';
import '../compras/compras_modulo_screen.dart';
import '../empresas/empresas_screen.dart';
import '../devoluciones/devoluciones_screen.dart';
import '../caja/caja_dashboard_admin.dart';
import '../cajero_inicio/cajero_dashboard.dart';
import '../separados/separados_screen.dart';
import '../configuracion/configuracion_screen.dart';
import '../etiquetas/etiquetas_screen.dart';
import '../documentos/documentos_screen.dart';
import '../bonos/bonos_screen.dart';
import '../formatos/formatos_diarios_screen.dart';
import '../../services/update_service.dart';
import '../../core/dashboard_cache.dart';

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
  static const greenDark = Color(0xFF006C49);
  static const amber = Color(0xFFB45309);
  static const amberLight = Color(0xFFFEF3C7);
  static const rose = Color(0xFFBE123C);
  static const roseLight = Color(0xFFFFF1F2);
  static const sidebar = Color(0xFFFFFFFF);
  static const sidebarHov = Color(0xFFF3F4F6);
}

// Paleta móvil — análoga a la pantalla de bienvenida/login
class _MC {
  static const bg      = Color(0xFFECFDF5);
  static const green   = Color(0xFF059669);
  static const teal    = Color(0xFF0D9488);
  static const dark    = Color(0xFF064E3B);
  static const mid     = Color(0xFF047857);
  static const light   = Color(0xFFD1FAE5);
  static const border  = Color(0xFFA7F3D0);
  static const dim     = Color(0xFF6EE7B7);
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


class _NavItem {
  final String label, screen;
  final IconData icon;
  const _NavItem({required this.label, required this.screen, required this.icon});
}


// Ítems en el orden exacto de las secciones del sidebar.
// La función _sectionFor() determina el encabezado de grupo.
const _allNavItems = <_NavItem>[
  // ── OPERACIONES ──────────────────────────────────────────
  _NavItem(label: 'Dashboard',    screen: 'dashboard',    icon: Icons.dashboard_rounded),
  _NavItem(label: 'POS / Ventas', screen: 'pos',          icon: Icons.point_of_sale_rounded),
  _NavItem(label: 'Caja',         screen: 'cash',         icon: Icons.account_balance_wallet_rounded),
  _NavItem(label: 'Inventario',   screen: 'inventory',    icon: Icons.inventory_2_rounded),
  _NavItem(label: 'Compras',      screen: 'compras',      icon: Icons.shopping_cart_rounded),
  _NavItem(label: 'Devoluciones', screen: 'devoluciones', icon: Icons.assignment_return_rounded),
  // ── CLIENTES ─────────────────────────────────────────────
  _NavItem(label: 'Clientes',     screen: 'clientes',     icon: Icons.people_alt_rounded),
  _NavItem(label: 'Separados',    screen: 'separados',    icon: Icons.bookmark_rounded),
  // ── ANÁLISIS ─────────────────────────────────────────────
  _NavItem(label: 'Contabilidad',    screen: 'contabilidad', icon: Icons.bar_chart_rounded),
  _NavItem(label: 'Gastos y nómina', screen: 'gastos',       icon: Icons.payments_rounded),
  _NavItem(label: 'Nómina',          screen: 'nomina',       icon: Icons.badge_rounded),
  _NavItem(label: 'Reportes',        screen: 'reports',      icon: Icons.assessment_rounded),
  _NavItem(label: 'Formatos Diarios',screen: 'formatos',     icon: Icons.table_chart_rounded),
  _NavItem(label: 'Bonos',           screen: 'bonos',        icon: Icons.card_giftcard_rounded),
  _NavItem(label: 'Documentos',      screen: 'documentos',   icon: Icons.folder_copy_rounded),
  // ── ADMINISTRACIÓN ───────────────────────────────────────
  _NavItem(label: 'Etiquetas',              screen: 'etiquetas',    icon: Icons.label_rounded),
  _NavItem(label: 'Empleados',              screen: 'empleados',    icon: Icons.people_rounded),
  _NavItem(label: 'Empresas & Sucursales',  screen: 'empresas',     icon: Icons.business_rounded),
  _NavItem(label: 'Configuración',          screen: 'configuracion',icon: Icons.settings_outlined),
];

// Sección del sidebar a la que pertenece cada pantalla.
String _sectionFor(String screen) {
  switch (screen) {
    case 'dashboard':
    case 'pos':
    case 'cash':
    case 'inventory':
    case 'compras':
    case 'devoluciones':
      return 'OPERACIONES';
    case 'clientes':
    case 'separados':
      return 'CLIENTES';
    case 'contabilidad':
    case 'gastos':
    case 'nomina':
    case 'reports':
    case 'formatos':
    case 'bonos':
    case 'documentos':
      return 'ANÁLISIS';
    case 'etiquetas':
    case 'empleados':
    case 'empresas':
    case 'configuracion':
      return 'ADMINISTRACIÓN';
    default:
      return '';
  }
}

List<_NavItem> _buildNavItems(String rol) {
  bool allowed(_NavItem item) {
    switch (item.screen) {
      case 'dashboard':    return true;
      case 'pos':          return rol == 'cajero';
      case 'cash':         return true;
      case 'inventory':    return true;
      case 'compras':      return ['admin', 'supervisor', 'superadmin'].contains(rol);
      case 'devoluciones': return true;
      // Cajero puede ver, crear y editar clientes de su tienda
      case 'clientes':     return true;
      case 'separados':    return true;
      case 'contabilidad': return ['admin', 'supervisor', 'superadmin'].contains(rol);
      case 'gastos':       return ['admin', 'superadmin'].contains(rol);
      case 'nomina':       return ['admin', 'superadmin'].contains(rol);
      // Reportes de turno: cajero + supervisor (supervisor revisa sus cajeros)
      case 'reports':      return ['cajero', 'supervisor'].contains(rol);
      case 'formatos':     return ['cajero', 'supervisor'].contains(rol);
      case 'bonos':        return true;
      case 'documentos':   return ['admin', 'supervisor', 'superadmin'].contains(rol);
      case 'etiquetas':    return ['admin', 'supervisor', 'superadmin'].contains(rol);
      case 'empleados':    return ['admin', 'superadmin'].contains(rol);
      case 'empresas':     return ['admin', 'superadmin'].contains(rol);
      case 'configuracion':return ['admin', 'supervisor', 'superadmin'].contains(rol);
      default: return false;
    }
  }

  return _allNavItems.where(allowed).toList();
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
  final _scaffoldKey  = GlobalKey<ScaffoldState>();
  String _activeScreen  = 'dashboard';
  bool   _navCollapsed  = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Chequear al entrar y luego cada 2 horas
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) UpdateService.chequear(context);
    });
    _updateTimer = Timer.periodic(const Duration(hours: 2), (_) {
      if (mounted) UpdateService.chequear(context);
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _navigate(String screen) {
    setState(() => _activeScreen = screen);
    _scaffoldKey.currentState?.closeDrawer();
  }

  Widget _buildScreenByKey(String screen, String rol, String userName) {
    if (!_buildNavItems(rol).any((n) => n.screen == screen)) {
      if (rol == 'cajero') return CajeroDashboard(onNavigate: _navigate);
      return _DashboardBody(userName: userName.split(' ').first, onNavigate: _navigate);
    }
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
      case 'gastos':       return GastosScreen(onIrANomina: () => _navigate('nomina'));
      case 'nomina':       return const NominaScreen();
      case 'reports': return const ReportesScreen();
      case 'formatos': return const FormatosDiariosScreen();
      case 'clientes':
        return ClientesScreen(esAdminOSupervisor: rol == 'admin' || rol == 'supervisor' || rol == 'superadmin');
      case 'separados': return const SeparadosScreen();
      case 'suppliers': return const ComprasModuloScreen();
      case 'compras': return const ComprasModuloScreen();
      case 'devoluciones': return const DevolucionesScreen();
      case 'etiquetas': return const EtiquetasScreen();
      case 'empleados': return const EmpleadosScreen();
      case 'stores': return const TiendasScreen();
      case 'empresas': return const EmpresasScreen();
      case 'configuracion': return const ConfiguracionScreen();
      case 'bonos':         return const BonosScreen();
      case 'documentos':    return const DocumentosScreen();
      default: return _PlaceholderScreen(screen: screen, onBack: () => _navigate('dashboard'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w         = MediaQuery.of(context).size.width;
    final isDesktop = w >= 1024;
    final auth      = context.watch<AuthProvider>();
    final navItems  = _buildNavItems(auth.rol);

    if (!navItems.any((n) => n.screen == _activeScreen) && navItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _activeScreen = navItems.first.screen);
      });
    }

    // ── Móvil (< 600 px) ──────────────────────────────────────
    if (w < 600) {
      return Scaffold(
        backgroundColor: _MC.bg,
        body: SafeArea(
          child: Column(children: [
            _MobileTopBar(
              title:    _mobileScreenTitle(_activeScreen),
              userName: widget.userName,
              branch:   widget.branch,
              onAvatarTap: () => _showCuentaSheet(context),
            ),
            Expanded(child: _buildScreenByKey(_activeScreen, auth.rol, widget.userName)),
          ]),
        ),
        bottomNavigationBar: _MobileBottomNav(
          activeScreen: _activeScreen,
          navItems:     navItems,
          onNavigate:   _navigate,
          onMasTap:     () => _showMasSheet(context, navItems),
        ),
      );
    }

    final sidebar = _Sidebar(
      activeScreen: _activeScreen,
      onNavigate:   _navigate,
      userName:     widget.userName,
      userRole:     widget.userRole,
      navItems:     navItems,
    );

    final onMenuTap = isDesktop
        ? () => setState(() => _navCollapsed = !_navCollapsed)
        : () => _scaffoldKey.currentState?.openDrawer();

    final mainContent = Column(children: [
      _TopBar(
        branch:         widget.branch,
        userName:       widget.userName,
        userRole:       widget.userRole,
        showMenuBtn:    true,
        navCollapsed:   _navCollapsed,
        isDesktop:      isDesktop,
        onMenuTap:      onMenuTap,
      ),
      Expanded(child: _buildScreenByKey(_activeScreen, auth.rol, widget.userName)),
    ]);

    if (isDesktop) {
      return Scaffold(
        key:             _scaffoldKey,
        backgroundColor: _C.bg,
        body: Row(children: [
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve:    Curves.easeInOut,
              width:    _navCollapsed ? 0.0 : 210.0,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth:  210,
                maxWidth:  210,
                child:     sidebar,
              ),
            ),
          ),
          Expanded(child: mainContent),
        ]),
      );
    }

    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: _C.bg,
      drawer: Drawer(
        width:           280,
        backgroundColor: _C.sidebar,
        child:           sidebar,
      ),
      body: mainContent,
    );
  }

  String _mobileScreenTitle(String screen) {
    switch (screen) {
      case 'dashboard':    return 'Resumen';
      case 'pos':          return 'POS · Ventas';
      case 'cash':         return 'Caja';
      case 'inventory':    return 'Inventario';
      case 'compras':      return 'Compras';
      case 'devoluciones': return 'Devoluciones';
      case 'clientes':     return 'Clientes';
      case 'separados':    return 'Separados';
      case 'contabilidad': return 'Contabilidad';
      case 'gastos':       return 'Gastos y nómina';
      case 'nomina':       return 'Nómina';
      case 'reports':      return 'Reportes';
      case 'formatos':     return 'Formatos Diarios';
      case 'bonos':        return 'Bonos';
      case 'documentos':   return 'Documentos';
      case 'etiquetas':    return 'Etiquetas';
      case 'empleados':    return 'Empleados';
      case 'empresas':     return 'Empresas';
      case 'configuracion':return 'Configuración';
      default:             return 'SIS POS';
    }
  }

  void _showCuentaSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _CuentaSheet(
        userName: widget.userName,
        userRole: widget.userRole,
        branch:   widget.branch,
      ),
    );
  }

  void _showMasSheet(BuildContext ctx, List<_NavItem> navItems) {
    const mainTabs = {'dashboard', 'cash', 'inventory', 'clientes'};
    final masItems = navItems.where((n) => !mainTabs.contains(n.screen)).toList();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MasSheet(
        items:        masItems,
        activeScreen: _activeScreen,
        onNavigate:   (screen) {
          Navigator.pop(ctx);
          _navigate(screen);
        },
      ),
    );
  }
}

List<Widget> _buildSidebarChildren(
  List<_NavItem> navItems,
  String activeScreen,
  void Function(String) onNavigate,
) {
  final widgets = <Widget>[];
  String lastSection = '';

  for (final n in navItems) {
    final section = _sectionFor(n.screen);
    if (section.isNotEmpty && section != lastSection) {
      if (lastSection.isNotEmpty) widgets.add(const SizedBox(height: 4));
      widgets.add(_SidebarSection(label: section));
      lastSection = section;
    }
    widgets.add(_NavTile(
      item:   n,
      active: activeScreen == n.screen,
      onTap:  () => onNavigate(n.screen),
    ));
  }
  return widgets;
}

class _Sidebar extends StatelessWidget {
  final String activeScreen, userName, userRole;
  final List<_NavItem> navItems;
  final void Function(String) onNavigate;
  const _Sidebar({required this.activeScreen, required this.onNavigate, required this.userName, required this.userRole, required this.navItems});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _C.sidebar,
      child: Column(children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.point_of_sale_rounded, size: 16, color: Colors.white)),
            const SizedBox(width: 10),
            Text('SIS POS', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            children: _buildSidebarChildren(navItems, activeScreen, onNavigate),
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
  final bool showMenuBtn, navCollapsed, isDesktop;
  final VoidCallback onMenuTap;
  const _TopBar({required this.branch, required this.userName, required this.userRole, required this.showMenuBtn, required this.onMenuTap, this.navCollapsed = false, this.isDesktop = false});
  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isNarrow = w < 700;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _C.surface, border: Border(bottom: BorderSide(color: _C.border))),
      child: Row(children: [

        // ── Hamburguesa ──────────────────────────────
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              isDesktop && !navCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
              key: ValueKey('$isDesktop-$navCollapsed'),
              size: 20,
            ),
          ),
          onPressed: onMenuTap,
          color: _C.textSecond,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),

        // Logo inline cuando nav está cerrado en desktop
        if (isDesktop && navCollapsed) ...[
          const SizedBox(width: 6),
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.point_of_sale_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text('SIS POS', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ],

        const Spacer(),

        // ── Sucursal ──────────────────────────────────
        if (!isNarrow)
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.store_rounded, size: 13, color: _C.textFaint),
              const SizedBox(width: 6),
              Flexible(child: Text(branch,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: _C.textSecond, fontSize: 12, fontWeight: FontWeight.w500))),
            ]),
          ),

        const SizedBox(width: 12),

        // ── Usuario ───────────────────────────────────
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _C.greenLight, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(userName[0],
                style: GoogleFonts.inter(color: _C.greenDark, fontWeight: FontWeight.w800, fontSize: 13))),
          ),
          if (!isNarrow) ...[
            const SizedBox(width: 9),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(userName.split(' ').first,
                  style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(userRole,
                  style: GoogleFonts.inter(color: _C.greenDark, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ],
        ]),

        const SizedBox(width: 8),

        // ── Botón de actualización ────────────────────
        ValueListenableBuilder<String?>(
          valueListenable: UpdateService.updateError,
          builder: (ctx, error, _) {
            return ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: UpdateService.updateDisponible,
              builder: (ctx2, info, _) {
                final hayError  = error != null;
                final hayUpdate = info != null && !hayError;

                final IconData icono = hayError
                    ? Icons.warning_amber_rounded
                    : hayUpdate
                        ? Icons.system_update_rounded
                        : Icons.download_done_rounded;
                final Color color = hayError
                    ? const Color(0xFFB45309)
                    : hayUpdate
                        ? _C.greenDark
                        : _C.textFaint;
                final String tooltip = hayError
                    ? 'Error al verificar: $error'
                    : hayUpdate
                        ? 'Nueva versión ${info!['version']} disponible'
                        : 'v$currentVersion — al día';

                return Tooltip(
                  message: tooltip,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(icono, size: 20, color: color),
                        onPressed: () {
                          if (hayError) {
                            showDialog(
                              context: ctx2,
                              builder: (_) => AlertDialog(
                                title: const Text('Error al verificar versión'),
                                content: SingleChildScrollView(
                                  child: Text(error!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace')),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx2);
                                      UpdateService.chequear(ctx2);
                                    },
                                    child: const Text('Reintentar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx2),
                                    child: const Text('Cerrar'),
                                  ),
                                ],
                              ),
                            );
                          } else if (hayUpdate) {
                            UpdateService.mostrarDialogo(ctx2);
                          } else {
                            ScaffoldMessenger.of(ctx2).showSnackBar(
                              SnackBar(
                                content: Text('v$currentVersion — estás al día'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
                      if (hayUpdate || hayError)
                        Positioned(
                          top: 4, right: 4,
                          child: Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(
                              color: hayError
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                hayError ? '!' : '1',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(width: 4),
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
  Timer? _refreshTimer;

  // Alias al caché compartido (se limpia en logout desde auth_provider)
  static Map<String, Map<String, dynamic>> get _responseCache => dashboardAdminCache;

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
  List<Map<String, dynamic>> _metodosPago     = [];

  @override
  void initState() {
    super.initState();
    _cargar();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted && !_loading) _cargar();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final key    = _periodo;
    final cached = _responseCache[key];

    if (cached != null) {
      // Mostrar datos guardados al instante (sin spinner)
      _applyData(cached);
      // Refrescar silenciosamente en background
      _refreshBackground(key);
      return;
    }

    // Primera carga: spinner normal
    setState(() { _loading = true; _error = null; });
    await _fetchAndStore(key);
  }

  // ignore: unawaited_futures
  void _refreshBackground(String key) => _fetchAndStore(key);

  Future<void> _fetchAndStore(String key) async {
    final res = await _svc.getDashboardAdmin(periodo: _periodo);
    if (!mounted) return;
    if (res['success'] != true) {
      if (_responseCache[key] == null) {
        setState(() { _loading = false; _error = res['error']?.toString() ?? 'Error al cargar'; });
      }
      return;
    }
    final d = res['data'] as Map<String, dynamic>;
    _responseCache[key] = d;
    _applyData(d);
  }

  void _applyData(Map<String, dynamic> d) {
    final kpis = d['kpis'] as Map<String, dynamic>;
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
      _metodosPago       = List<Map<String, dynamic>>.from(d['metodos_pago']            ?? []);
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
        accent: _C.greenDark, accentBg: _C.greenLight,
      ),
      _KPI(
        title: 'Alerta Existencias', sub: '$_alertasCriticas críticos',
        value: '$totalBajo',
        trend: totalBajo > 4 ? 'Revisar urgente' : 'Bajo control',
        trendUp: totalBajo <= 4,
        icon: Icons.inventory_2_outlined,
        accent: _C.greenDark, accentBg: _C.greenLight,
        onTap: () => widget.onNavigate('inventory'),
      ),
      _KPI(
        title: 'Compras Pendientes', sub: 'Por recibir',
        value: '$_comprasPendientes',
        trend: _comprasPendientes > 0 ? 'Atención requerida' : 'Al día',
        trendUp: _comprasPendientes == 0,
        icon: Icons.shopping_cart_outlined,
        accent: _C.greenDark, accentBg: _C.greenLight,
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

    final w        = MediaQuery.of(context).size.width;
    final isWide   = w >= 1100;
    final isNarrow = w < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isNarrow ? 16 : 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Banner + KPIs — versión según ancho
        if (w < 600) ...[
          // Hero móvil — fondo claro análogo al login
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD1FAE5), Color(0xFFCCFBF1), Color(0xFFECFDF5)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6EE7B7), width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PERSPECTIVA GENERAL', style: GoogleFonts.inter(color: _MC.green, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
              const SizedBox(height: 4),
              Text('¡Buenos días, ${widget.userName}!', style: GoogleFonts.inter(color: _MC.dark, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 6),
              Text(
                totalBajo > 0
                    ? 'Hay $totalBajo SKUs con stock bajo ($_alertasCriticas críticos) y $_comprasPendientes compras pendientes.'
                    : 'Inventario en buen estado. $_comprasPendientes compras pendientes de recibir.',
                style: GoogleFonts.inter(color: _MC.mid, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 10),
              _MobilePeriodRow(value: _periodo, onChange: (p) { setState(() => _periodo = p); _cargar(); }),
            ]),
          ),
          const SizedBox(height: 14),
          // KPIs móvil — 2×2 con gradientes por categoría
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.08,
            children: [
              _MobileKPICard(kpi: kpis[0], stripe: const [Color(0xFF059669), Color(0xFF10B981)], iconBg: const Color(0xFFD1FAE5), iconColor: Color(0xFF059669)),
              _MobileKPICard(kpi: kpis[1], stripe: const [Color(0xFF0D9488), Color(0xFF14B8A6)], iconBg: const Color(0xFFCCFBF1), iconColor: Color(0xFF0D9488)),
              _MobileKPICard(kpi: kpis[2], stripe: const [Color(0xFFF59E0B), Color(0xFFF97316)], iconBg: const Color(0xFFFEF3C7), iconColor: Color(0xFFF59E0B)),
              _MobileKPICard(kpi: kpis[3], stripe: const [Color(0xFF059669), Color(0xFF10B981)], iconBg: const Color(0xFFD1FAE5), iconColor: Color(0xFF059669)),
            ],
          ),
          const SizedBox(height: 14),
        ] else ...[
          // Banner desktop — fondo oscuro
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: _C.greenDark, borderRadius: BorderRadius.circular(16)),
            child: Stack(children: [
              Positioned(right: -20, top: -20, child: Icon(Icons.point_of_sale_rounded, size: 140, color: Colors.white.withOpacity(0.04))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(4)), child: Text('PERSPECTIVA GENERAL DEL NEGOCIO', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
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
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 560 ? 2 : 1;
            return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: c.maxWidth >= 1000 ? 1.7 : 2.1, children: kpis.map((k) => _KPICard(kpi: k)).toList());
          }),
          const SizedBox(height: 24),
        ],

        // Panel de alertas consolidado
        _AlertasPanel(
          inventarioBajo: _inventarioBajo,
          alertasCriticas: _alertasCriticas,
          comprasPendientes: _comprasPendientes,
          onNavigate: widget.onNavigate,
        ),

        if (w < 600) ...[
          // ── Layout móvil: orden del mockup ──
          const SizedBox(height: 14),

          // Tiendas compactas
          if (_ventasPorTienda.isNotEmpty || _desempeno.isNotEmpty) ...[
            _MobileSectionLabel('Ventas por tienda'),
            const SizedBox(height: 8),
            _MobileStoresList(ventas: _ventasPorTienda, desempeno: _desempeno),
            const SizedBox(height: 14),
          ],

          // Métodos de pago — chips horizontales scrollables
          if (_metodosPago.isNotEmpty) ...[
            _MobileSectionLabel('Métodos de pago'),
            const SizedBox(height: 8),
            _MobileMetodosChips(metodos: _metodosPago),
            const SizedBox(height: 14),
          ],

          // Bitácora — solo 3 entradas
          _MobileSectionLabel('Bitácora reciente'),
          const SizedBox(height: 8),
          _MobileBitacora(movements: movements),
          const SizedBox(height: 8),

        ] else ...[
          // ── Layout desktop ──
          const SizedBox(height: 24),

          // Bitácora + métodos de pago
          isWide
              ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 6, child: _MovementsCard(movements: movements)),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: _MetodosPagoCard(metodos: _metodosPago, periodo: _periodo)),
                ]))
              : Column(children: [
                  _MovementsCard(movements: movements),
                  const SizedBox(height: 20),
                  _MetodosPagoCard(metodos: _metodosPago, periodo: _periodo),
                ]),

          // Ventas por tienda + Estado de sucursales
          if (_ventasPorTienda.isNotEmpty || _desempeno.isNotEmpty) ...[
            const SizedBox(height: 24),
            if (isWide)
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_ventasPorTienda.isNotEmpty)
                  Expanded(child: _VentasPorTiendaCard(ventas: _ventasPorTienda, periodo: _periodo)),
                if (_ventasPorTienda.isNotEmpty && _desempeno.isNotEmpty)
                  const SizedBox(width: 20),
                if (_desempeno.isNotEmpty)
                  Expanded(child: _SucursalesCard(desempeno: _desempeno)),
              ]))
            else
              Column(children: [
                if (_ventasPorTienda.isNotEmpty)
                  _VentasPorTiendaCard(ventas: _ventasPorTienda, periodo: _periodo),
                if (_ventasPorTienda.isNotEmpty && _desempeno.isNotEmpty)
                  const SizedBox(height: 20),
                if (_desempeno.isNotEmpty)
                  _SucursalesCard(desempeno: _desempeno),
              ]),
          ],

          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

// ── Panel de alertas consolidado ───────────────────────────────────────────

class _AlertasPanel extends StatelessWidget {
  final int inventarioBajo;
  final int alertasCriticas;
  final int comprasPendientes;
  final void Function(String) onNavigate;
  const _AlertasPanel({required this.inventarioBajo, required this.alertasCriticas, required this.comprasPendientes, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final hayAlertas = alertasCriticas > 0 || inventarioBajo > 0 || comprasPendientes > 0;
    final borderCol = alertasCriticas > 0 ? _C.rose.withOpacity(0.35) : inventarioBajo > 0 ? _C.amber.withOpacity(0.35) : _C.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: hayAlertas ? _C.surface : _C.greenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hayAlertas ? borderCol : _C.green.withOpacity(0.25)),
      ),
      child: hayAlertas
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.notifications_active_rounded, size: 14, color: alertasCriticas > 0 ? _C.rose : _C.amber),
                const SizedBox(width: 8),
                Text('Requiere atención', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (alertasCriticas > 0)
                  _alertaChip(icon: Icons.block_rounded, color: _C.rose, bg: _C.roseLight, label: '$alertasCriticas sin stock', onTap: () => onNavigate('inventory')),
                if (inventarioBajo > 0)
                  _alertaChip(icon: Icons.inventory_2_outlined, color: _C.amber, bg: _C.amberLight, label: '$inventarioBajo stock bajo', onTap: () => onNavigate('inventory')),
                if (comprasPendientes > 0)
                  _alertaChip(icon: Icons.local_shipping_outlined, color: _C.greenDark, bg: _C.greenLight, label: '$comprasPendientes por recibir', onTap: () => onNavigate('compras')),
              ]),
            ])
          : Row(children: [
              Container(width: 24, height: 24, decoration: BoxDecoration(color: _C.green.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 14, color: _C.greenDark)),
              const SizedBox(width: 10),
              Text('Sin alertas — Inventario y logística en orden', style: GoogleFonts.inter(color: _C.greenDark, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
    );
  }

  Widget _alertaChip({required IconData icon, required Color color, required Color bg, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, size: 10, color: color.withOpacity(0.7)),
        ]),
      ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 3, color: kpi.accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(kpi.title, style: GoogleFonts.inter(color: _C.textSecond, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: kpi.accentBg, borderRadius: BorderRadius.circular(8)), child: Icon(kpi.icon, size: 16, color: kpi.accent)),
                ]),
                const SizedBox(height: 10),
                Text(kpi.value, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: trendColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(trendIcon, size: 10, color: trendColor),
                      const SizedBox(width: 3),
                      Text(kpi.trend, style: GoogleFonts.inter(color: trendColor, fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(kpi.sub, style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10), overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MobileKPICard extends StatelessWidget {
  final _KPI kpi;
  final List<Color> stripe;
  final Color iconBg;
  final Color iconColor;
  const _MobileKPICard({required this.kpi, required this.stripe, required this.iconBg, required this.iconColor});
  @override
  Widget build(BuildContext context) {
    final trendColor = kpi.trendUp == null ? _MC.mid : kpi.trendUp! ? _MC.green : const Color(0xFFF97316);
    final trendIcon  = kpi.trendUp == null ? Icons.remove_rounded : kpi.trendUp! ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    return GestureDetector(
      onTap: kpi.onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MC.border, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Stripe de gradiente en la parte superior
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: stripe),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(kpi.title, style: GoogleFonts.inter(color: _MC.mid, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(7)), child: Icon(kpi.icon, size: 14, color: iconColor)),
                ]),
                const SizedBox(height: 4),
                Text(kpi.value, style: GoogleFonts.inter(color: _MC.dark, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: trendColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(trendIcon, size: 9, color: trendColor),
                      const SizedBox(width: 2),
                      Text(kpi.trend, style: GoogleFonts.inter(color: trendColor, fontSize: 9, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ]),
            ),
          ),
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.history_rounded, size: 15, color: _C.greenDark), const SizedBox(width: 8), Text('Auditoría: Bitácora del Día', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))]), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)), child: Text('Últimas ${movements.length} acciones', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10)))]),
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

class _MetodosPagoCard extends StatelessWidget {
  final List<Map<String, dynamic>> metodos;
  final String periodo;
  const _MetodosPagoCard({required this.metodos, required this.periodo});

  static const _info = {
    'efectivo':      (label: 'Efectivo',      icon: Icons.payments_rounded,        color: Color(0xFF0B7A53)),
    'tarjeta':       (label: 'Tarjeta',        icon: Icons.credit_card_rounded,      color: Color(0xFF3730A3)),
    'transferencia': (label: 'Transferencia',  icon: Icons.account_balance_rounded,  color: Color(0xFFB45309)),
    'mixto':         (label: 'Mixto',          icon: Icons.swap_horiz_rounded,       color: Color(0xFF0E7490)),
    'credito':       (label: 'Fiado',          icon: Icons.handshake_rounded,        color: Color(0xFF7C3AED)),
  };

  String _fmt(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final total = metodos.fold(0.0, (s, m) => s + (m['total'] as num).toDouble());

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.donut_small_rounded, size: 15, color: _C.greenDark),
          const SizedBox(width: 8),
          Text('Métodos de Pago',
              style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)),
            child: Text(periodo == 'semanal' ? 'Esta semana' : 'Este mes',
                style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10)),
          ),
        ]),
        const SizedBox(height: 4),
        Divider(color: _C.divider),
        const SizedBox(height: 12),

        if (metodos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Sin ventas en el período',
                style: GoogleFonts.inter(color: _C.textFaint, fontSize: 12))),
          )
        else ...[
          // Barra apilada total
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: metodos.map((m) {
                  final pct = (m['total'] as num).toDouble() / total;
                  final info = _info[m['metodo']] ?? (label: m['metodo'] as String, icon: Icons.circle, color: _C.textFaint);
                  return Expanded(
                    flex: (pct * 1000).round(),
                    child: Container(height: 10, color: info.color),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Filas por método
          ...metodos.map((m) {
            final monto = (m['total'] as num).toDouble();
            final count = (m['count'] as num).toInt();
            final pct   = total > 0 ? monto / total : 0.0;
            final info  = _info[m['metodo']] ?? (label: m['metodo'] as String, icon: Icons.circle, color: _C.textFaint);
            final bg    = info.color.withValues(alpha: 0.08);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border.withValues(alpha: 0.6)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
                    child: Icon(info.icon, size: 14, color: info.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(info.label,
                      style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                  Text(_fmt(monto),
                      style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 4,
                      backgroundColor: _C.border,
                      valueColor: AlwaysStoppedAnimation<Color>(info.color),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Text('${(pct * 100).toStringAsFixed(0)}%  ·  $count vtas',
                      style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ]),
            );
          }),
        ],
      ]),
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

// ── Estado de sucursales en tiempo real ───────────────────────────────────

class _SucursalesCard extends StatelessWidget {
  final List<Map<String, dynamic>> desempeno;
  const _SucursalesCard({required this.desempeno});

  @override
  Widget build(BuildContext context) {
    final activas = desempeno.where((t) => (t['cajas_activas'] as num).toInt() > 0).length;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.store_rounded, size: 15, color: _C.greenDark),
          const SizedBox(width: 8),
          Text('Estado de Sucursales', style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: activas > 0 ? _C.greenLight : _C.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activas > 0 ? _C.green.withOpacity(0.3) : _C.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: activas > 0 ? const Color(0xFF22C55E) : _C.textFaint, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('$activas/${desempeno.length} activas', style: GoogleFonts.inter(color: activas > 0 ? _C.greenDark : _C.textFaint, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Divider(color: _C.divider),
        const SizedBox(height: 8),
        ...desempeno.map((t) => _SucursalRow(t: t)),
      ]),
    );
  }
}

class _SucursalRow extends StatelessWidget {
  final Map<String, dynamic> t;
  const _SucursalRow({required this.t});

  Color  _estadoBg(String e)  => e == 'optimo' ? _C.greenLight  : e == 'estable' ? _C.divider : _C.amberLight;
  Color  _estadoFg(String e)  => e == 'optimo' ? _C.greenDark   : e == 'estable' ? _C.textSecond : _C.amber;
  String _estadoLbl(String e) => e == 'optimo' ? 'ÓPTIMO'       : e == 'estable' ? 'ESTABLE'      : 'MODERADO';

  @override
  Widget build(BuildContext context) {
    final estado       = t['estado'] as String;
    final cajasActivas = (t['cajas_activas'] as num).toInt();
    final eficiencia   = t['eficiencia_pct'] as int;
    final ventasHoy    = (t['ventas_hoy'] as num).toDouble();
    final isLive       = cajasActivas > 0;
    final label = '\$${ventasHoy.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isLive ? _C.border.withOpacity(0.7) : _C.border.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: isLive ? const Color(0xFF22C55E) : _C.textFaint, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(t['nombre'] as String, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          Text(label, style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const SizedBox(width: 16),
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: _estadoBg(estado), borderRadius: BorderRadius.circular(3)), child: Text(_estadoLbl(estado), style: GoogleFonts.inter(color: _estadoFg(estado), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
          const SizedBox(width: 6),
          Flexible(child: Text('${t['encargado']}${isLive ? ' · $cajasActivas caja${cajasActivas > 1 ? 's' : ''}' : ' · cerrada'}', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 10), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 16),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: eficiencia / 100.0, backgroundColor: _C.border, color: isLive ? _C.green : _C.textFaint, minHeight: 4))),
          const SizedBox(width: 8),
          Text('$eficiencia%', style: GoogleFonts.inter(color: _C.textSecond, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// ── Mobile nav ─────────────────────────────────────────────────────────────

const _kMainTabs = <_NavItem>[
  _NavItem(label: 'Inicio',     screen: 'dashboard', icon: Icons.home_rounded),
  _NavItem(label: 'Caja',       screen: 'cash',      icon: Icons.account_balance_wallet_rounded),
  _NavItem(label: 'Inventario', screen: 'inventory', icon: Icons.inventory_2_rounded),
  _NavItem(label: 'Clientes',   screen: 'clientes',  icon: Icons.people_alt_rounded),
];

class _MobileTopBar extends StatelessWidget {
  final String title, userName, branch;
  final VoidCallback? onAvatarTap;
  const _MobileTopBar({required this.title, required this.userName, required this.branch, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _MC.border)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _MC.dark)),
            if (branch.isNotEmpty)
              Text(branch, style: GoogleFonts.inter(fontSize: 11, color: _MC.mid, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ]),
        ),
        ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: UpdateService.updateDisponible,
          builder: (ctx, info, _) {
            if (info == null) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.system_update_rounded, size: 20, color: _MC.green),
              onPressed: () => UpdateService.mostrarDialogo(ctx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            );
          },
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_MC.green, _MC.teal]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            )),
          ),
        ),
      ]),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final String activeScreen;
  final List<_NavItem> navItems;
  final void Function(String) onNavigate;
  final VoidCallback onMasTap;
  const _MobileBottomNav({required this.activeScreen, required this.navItems, required this.onNavigate, required this.onMasTap});

  @override
  Widget build(BuildContext context) {
    const mainSet = {'dashboard', 'cash', 'inventory', 'clientes'};
    final hasMas  = navItems.any((n) => !mainSet.contains(n.screen));
    final tabs    = _kMainTabs.where((t) => navItems.any((n) => n.screen == t.screen)).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _MC.border)),
        boxShadow: [BoxShadow(color: Color(0x14059669), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(children: [
            ...tabs.map((t) => _tab(t.screen, t.label, t.icon, activeScreen == t.screen, () => onNavigate(t.screen))),
            if (hasMas)
              _tab('mas', 'Más', Icons.apps_rounded, false, onMasTap),
          ]),
        ),
      ),
    );
  }

  Widget _tab(String screen, String label, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44, height: 32,
            decoration: BoxDecoration(
              color: active ? _MC.light : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: active ? _MC.green : _MC.dim),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _MC.green : _MC.dim,
          )),
        ]),
      ),
    );
  }
}

/// "Mi cuenta": se abre desde el avatar del encabezado móvil.
/// El menú "Más" queda solo para navegar entre secciones.
class _CuentaSheet extends StatelessWidget {
  final String userName, userRole, branch;
  const _CuentaSheet({required this.userName, required this.userRole, required this.branch});

  /// En el celular no había forma de cerrar sesión: el botón vivía solo en
  /// la barra lateral de escritorio. Se pide confirmación para que un toque
  /// sin querer a mitad de turno no saque al cajero.
  Future<void> _cerrarSesion(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('¿Cerrar sesión?', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: _MC.dark)),
        content: Text('Tendrás que volver a ingresar con tu usuario y contraseña.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('Cancelar', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            child: Text('Cerrar sesión', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.pop(context); // cierra el menú
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    Widget dato(IconData icono, String label, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Icon(icono, size: 18, color: _MC.mid),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            const Spacer(),
            Flexible(
              child: Text(valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _MC.dark)),
            ),
          ]),
        );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _MC.border, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: _MC.border, borderRadius: BorderRadius.circular(2))),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_MC.green, _MC.teal]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
              )),
            ),
            const SizedBox(height: 10),
            Text(userName.isEmpty ? 'Usuario' : userName,
                textAlign: TextAlign.center,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: _MC.dark)),
            if (userRole.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: _MC.light, borderRadius: BorderRadius.circular(20)),
                child: Text(userRole, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _MC.mid)),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _MC.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _MC.border),
              ),
              child: Column(children: [
                dato(Icons.storefront_rounded, 'Tienda', branch.isEmpty ? '—' : branch),
                const Divider(height: 1, color: _MC.border),
                dato(Icons.info_outline_rounded, 'Versión de la app', currentVersion),
              ]),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _cerrarSesion(context),
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: Text('Cerrar sesión', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  foregroundColor: const Color(0xFFB91C1C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFFEE2E2)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MasSheet extends StatelessWidget {
  final List<_NavItem> items;
  final String activeScreen;
  final void Function(String) onNavigate;
  const _MasSheet({required this.items, required this.activeScreen, required this.onNavigate});


  static const _colors = <String, Color>{
    'pos':          Color(0xFFD1FAE5),
    'compras':      Color(0xFFD1FAE5),
    'devoluciones': Color(0xFFFEE2E2),
    'contabilidad': Color(0xFFFEF3C7),
    'gastos':       Color(0xFFE0F2FE),
    'nomina':       Color(0xFFD1FAE5),
    'reports':      Color(0xFFFEF3C7),
    'formatos':     Color(0xFFFEF3C7),
    'bonos':        Color(0xFFEDE9FE),
    'documentos':   Color(0xFFCCFBF1),
    'etiquetas':    Color(0xFFFCE7F3),
    'empleados':    Color(0xFFDBEAFE),
    'separados':    Color(0xFFD1FAE5),
    'empresas':     Color(0xFFFEF9C3),
    'configuracion':Color(0xFFF3F4F6),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _MC.border, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: _MC.border, borderRadius: BorderRadius.circular(2))),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Todas las secciones', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .07, color: _MC.green)),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 10, childAspectRatio: 0.88,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item     = items[i];
            final isActive = item.screen == activeScreen;
            final bg       = _colors[item.screen] ?? const Color(0xFFF3F4F6);
            return GestureDetector(
              onTap: () => onNavigate(item.screen),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(16),
                    border: isActive
                        ? Border.all(color: _MC.green, width: 2)
                        : Border.all(color: Colors.black.withOpacity(.06)),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
                  ),
                  child: Icon(item.icon, size: 24, color: isActive ? _MC.green : _MC.dark),
                ),
                const SizedBox(height: 6),
                Text(item.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _MC.dark), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

// ── Period row móvil — pills con borde verde y texto oscuro ───────────────

class _MobilePeriodRow extends StatelessWidget {
  final String value;
  final void Function(String) onChange;
  const _MobilePeriodRow({required this.value, required this.onChange});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _MPBtn(label: 'Hoy',  val: 'hoy',      current: value, onChange: onChange),
      const SizedBox(width: 6),
      _MPBtn(label: 'Sem',  val: 'semanal',   current: value, onChange: onChange),
      const SizedBox(width: 6),
      _MPBtn(label: 'Mes',  val: 'mensual',   current: value, onChange: onChange),
    ]);
  }
}

class _MPBtn extends StatelessWidget {
  final String label, val, current;
  final void Function(String) onChange;
  const _MPBtn({required this.label, required this.val, required this.current, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final active = current == val;
    return GestureDetector(
      onTap: () => onChange(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF0D9488)]) : null,
          color:    active ? null : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFF059669) : const Color(0xFF6EE7B7), width: 1.5),
        ),
        child: Text(label, style: GoogleFonts.inter(color: active ? Colors.white : const Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Etiqueta de sección móvil ─────────────────────────────────────────────

class _MobileSectionLabel extends StatelessWidget {
  final String text;
  const _MobileSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.inter(color: _MC.green, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.7),
  );
}

// ── Chips horizontales de métodos de pago ────────────────────────────────

class _MobileMetodosChips extends StatelessWidget {
  final List<Map<String, dynamic>> metodos;
  const _MobileMetodosChips({required this.metodos});

  static const _info = <String, ({Color bg, Color fg, IconData icon, String label})>{
    'efectivo':      (bg: Color(0xFFD1FAE5), fg: Color(0xFF059669), icon: Icons.payments_rounded,       label: 'Efectivo'),
    'tarjeta':       (bg: Color(0xFFEDE9FE), fg: Color(0xFF3730A3), icon: Icons.credit_card_rounded,     label: 'Tarjeta'),
    'transferencia': (bg: Color(0xFFFEF3C7), fg: Color(0xFFB45309), icon: Icons.account_balance_rounded, label: 'Transferencia'),
    'mixto':         (bg: Color(0xFFCCFBF1), fg: Color(0xFF0E7490), icon: Icons.swap_horiz_rounded,      label: 'Mixto'),
    'credito':       (bg: Color(0xFFEDE9FE), fg: Color(0xFF7C3AED), icon: Icons.handshake_rounded,       label: 'Fiado'),
    'bono':          (bg: Color(0xFFCCFBF1), fg: Color(0xFF059669), icon: Icons.card_giftcard_rounded,   label: 'Bono'),
    'bono_efectivo': (bg: Color(0xFFD1FAE5), fg: Color(0xFF047857), icon: Icons.card_giftcard_rounded,   label: 'Bono Ef.'),
  };

  String _fmt(double v) {
    if (v >= 1000000) return '\$${(v/1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '\$${(v/1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final total = metodos.fold(0.0, (s, m) => s + (m['total'] as num).toDouble());
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: metodos.map((m) {
        final monto = (m['total'] as num).toDouble();
        final count = (m['count'] as num).toInt();
        final pct   = total > 0 ? (monto / total * 100).round() : 0;
        final key   = (m['metodo'] as String).toLowerCase();
        final info  = _info[key] ?? (bg: const Color(0xFFD1FAE5), fg: _MC.green, icon: Icons.circle, label: m['metodo'] as String);
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MC.border, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: info.bg, borderRadius: BorderRadius.circular(8)), child: Icon(info.icon, size: 16, color: info.fg)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info.label, style: GoogleFonts.inter(color: _MC.mid, fontSize: 11, fontWeight: FontWeight.w500)),
              Text(_fmt(monto), style: GoogleFonts.inter(color: _MC.dark, fontSize: 14, fontWeight: FontWeight.w800)),
              Text('$pct% · $count vtas', style: GoogleFonts.inter(color: _MC.green, fontSize: 10)),
            ]),
          ]),
        );
      }).toList()),
    );
  }
}

// ── Bitácora móvil — 3 entradas + ver más ────────────────────────────────

class _MobileBitacora extends StatelessWidget {
  final List<_Movement> movements;
  const _MobileBitacora({required this.movements});

  @override
  Widget build(BuildContext context) {
    final shown = movements.take(3).toList();
    final extra = movements.length - shown.length;
    return Column(children: [
      ...shown.map((m) {
        const colors = {
          'in':       (bg: Color(0xFFECFDF5), fg: Color(0xFF065F46), label: 'INGRESO'),
          'out':      (bg: Color(0xFFFFF1F2), fg: Color(0xFF9F1239), label: 'EGRESO'),
          'transfer': (bg: Color(0xFFEFF6FF), fg: Color(0xFF1E40AF), label: 'TRASPASO'),
        };
        final c = colors[m.type] ?? (bg: Color(0xFFECFDF5), fg: Color(0xFF065F46), label: m.type.toUpperCase());
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _MC.border, width: 1.5)),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: c.fg.withOpacity(0.2))), child: Text(c.label, style: GoogleFonts.inter(color: c.fg, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.description, style: GoogleFonts.inter(color: _MC.dark, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${m.time} · ${m.user} · ${m.detail}', style: GoogleFonts.inter(color: _MC.mid, fontSize: 10), overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            Text(m.id, style: GoogleFonts.inter(color: _MC.dark, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        );
      }),
      if (extra > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(child: Text('Ver $extra más →', style: GoogleFonts.inter(color: _MC.green, fontSize: 12, fontWeight: FontWeight.w600))),
        ),
    ]);
  }
}

// ── Lista compacta de tiendas para móvil ──────────────────────────────────

class _MobileStoresList extends StatelessWidget {
  final List<Map<String, dynamic>> ventas;
  final List<Map<String, dynamic>> desempeno;
  const _MobileStoresList({required this.ventas, required this.desempeno});
  @override
  Widget build(BuildContext context) {
    if (ventas.isEmpty) return const SizedBox.shrink();
    final maxVal = ventas.map((v) => (v['total'] as num).toDouble()).reduce(max);
    return Column(children: ventas.map((v) {
      final total = (v['total'] as num).toDouble();
      final pct   = maxVal > 0 ? (total / maxVal).clamp(0.0, 1.0) : 0.0;
      final nombre = v['nombre'] as String;
      final info   = desempeno.firstWhere((d) => d['nombre'] == nombre, orElse: () => {'cajas_activas': 0});
      final cajas  = (info['cajas_activas'] as num).toInt();
      final dotColor = cajas > 0 ? _MC.green : _MC.dim;
      final barColor = cajas > 0 ? _MC.green : _MC.dim;
      // Formato compacto del monto
      final abs = total.abs();
      final label = abs >= 1000000
          ? '\$${(abs/1000000).toStringAsFixed(1)}M'
          : abs >= 1000
              ? '\$${(abs/1000).toStringAsFixed(0)}K'
              : '\$${abs.toStringAsFixed(0)}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MC.border, width: 1.5)),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: GoogleFonts.inter(color: _MC.dark, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$label · ${cajas > 0 ? "$cajas caja activa" : "cerrada"}', style: GoogleFonts.inter(color: _MC.mid, fontSize: 11)),
            ])),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: _MC.light, valueColor: AlwaysStoppedAnimation<Color>(barColor)),
            )),
            const SizedBox(width: 8),
            Text('${(pct * 100).toStringAsFixed(0)}%', style: GoogleFonts.inter(color: _MC.dark, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }).toList());
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
