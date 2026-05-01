import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../pos/pos_screen.dart';
import '../inventario/inventario_screen.dart';
import '../reportes/reportes_screen.dart';
import '../caja/caja_screen.dart';
import '../empleados/empleados_screen.dart';
import '../contabilidad/contabilidad_screen.dart';
import '../tiendas/tiendas_screen.dart';
import '../clientes/clientes_screen.dart';
import '../proveedores/proveedores_screen.dart';
import '../compras/compras_screen.dart';
import '../empresas/empresas_screen.dart';
import '../devoluciones/devoluciones_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  late AnimationController _sidebarCtrl;
  late Animation<double>   _sidebarAnim;

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _sidebarAnim = CurvedAnimation(
        parent: _sidebarCtrl, curve: Curves.easeOutCubic);
    _sidebarCtrl.forward();
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    super.dispose();
  }

  List<_MenuItem> _getMenuItems(String rol) {
    final items = <_MenuItem>[
      _MenuItem(
        icon:  Icons.point_of_sale_rounded,
        label: 'POS / Ventas',
        roles: ['cajero'],
        group: 'Operaciones',
      ),
      _MenuItem(
        icon:  Icons.inventory_2_rounded,
        label: 'Inventario',
        roles: ['admin', 'supervisor', 'cajero'],
        group: 'Operaciones',
      ),
      _MenuItem(
        icon:  Icons.account_balance_wallet_rounded,
        label: 'Caja',
        roles: ['cajero', 'admin', 'supervisor', 'superadmin'],
        group: 'Operaciones',
      ),
      _MenuItem(
        icon:  Icons.bar_chart_rounded,
        label: 'Contabilidad',
        roles: ['admin', 'supervisor', 'cajero'],
        group: 'Finanzas',
      ),
      // ✅ Reportes: solo cajero
      _MenuItem(
        icon:  Icons.assessment_rounded,
        label: 'Reportes',
        roles: ['cajero'],
        group: 'Finanzas',
      ),
      _MenuItem(
        icon:  Icons.people_alt_rounded,
        label: 'Clientes',
        roles: ['admin', 'supervisor', 'cajero'],
        group: 'Gestión',
      ),
      _MenuItem(
        icon:  Icons.local_shipping_rounded,
        label: 'Proveedores',
        roles: ['admin', 'supervisor'],
        group: 'Gestión',
      ),
      _MenuItem(
        icon:  Icons.shopping_cart_rounded,
        label: 'Compras',
        roles: ['admin', 'supervisor'],
        group: 'Gestión',
      ),
      _MenuItem(
        icon:  Icons.assignment_return_rounded,
        label: 'Devoluciones',
        roles: ['admin', 'supervisor', 'cajero'],
        group: 'Gestión',
      ),
      _MenuItem(
        icon:  Icons.people_rounded,
        label: 'Empleados',
        roles: ['admin'],
        group: 'Administración',
      ),
      _MenuItem(
        icon:  Icons.store_rounded,
        label: 'Tiendas',
        roles: ['admin'],
        group: 'Administración',
      ),
      _MenuItem(
        icon:  Icons.business_rounded,
        label: 'Empresas',
        roles: ['superadmin'],
        group: 'Administración',
      ),
    ];

    if (rol == 'superadmin') {
      return items.where((i) =>
          i.roles.contains('admin') || i.roles.contains('superadmin'))
          .toList();
    }
    return items.where((i) => i.roles.contains(rol)).toList();
  }

  List<Widget> _getScreens(String rol) {
    final all = <_Screen>[
      _Screen(widget: const PosScreen(),          roles: ['cajero']),
      _Screen(widget: const InventarioScreen(),   roles: ['admin', 'supervisor', 'cajero']),
      _Screen(widget: const CajaScreen(),         roles: ['cajero','admin', 'supervisor', 'superadmin']),
      _Screen(widget: const ContabilidadScreen(), roles: ['admin', 'supervisor', 'cajero']),
      // ✅ Reportes: solo cajero
      _Screen(widget: const ReportesScreen(),     roles: ['cajero']),
      _Screen(
        widget: ClientesScreen(
          esAdminOSupervisor:
              rol == 'admin' || rol == 'supervisor' || rol == 'superadmin'),
        roles: ['admin', 'supervisor', 'cajero'],
      ),
      _Screen(widget: const ProveedoresScreen(),  roles: ['admin', 'supervisor']),
      _Screen(widget: const ComprasScreen(),      roles: ['admin', 'supervisor']),
      _Screen(widget: const DevolucionesScreen(), roles: ['admin', 'supervisor', 'cajero']),
      _Screen(widget: const EmpleadosScreen(),    roles: ['admin']),
      _Screen(widget: const TiendasScreen(),      roles: ['admin']),
      _Screen(widget: const EmpresasScreen(),     roles: ['superadmin']),
    ];

    if (rol == 'superadmin') {
      return all
          .where((s) => s.roles.contains('admin') || s.roles.contains('superadmin'))
          .map((s) => s.widget)
          .toList();
    }
    return all.where((s) => s.roles.contains(rol)).map((s) => s.widget).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final menuItems = _getMenuItems(auth.rol);
    final screens   = _getScreens(auth.rol);

    if (_selectedIndex >= menuItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = 0);
      });
    }

    final activeItem = menuItems.isNotEmpty ? menuItems[_selectedIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F9),
      body: Row(children: [

        // ── SIDEBAR ──────────────────────────────────────────────
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(_sidebarAnim),
          child: _Sidebar(
            menuItems:     menuItems,
            selectedIndex: _selectedIndex,
            auth:          auth,
            onSelect:      (i) => setState(() => _selectedIndex = i),
            onLogout:      () => context.read<AuthProvider>().logout(),
          ),
        ),

        // ── CONTENIDO PRINCIPAL ───────────────────────────────────
        Expanded(
          child: Column(
            children: [
              // Header superior
              if (activeItem != null)
                _ContentHeader(item: activeItem),

              // Pantalla activa
              Expanded(
                child: screens.isEmpty
                    ? _noModules()
                    : IndexedStack(
                        index: _selectedIndex,
                        children: screens,
                      ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _noModules() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.lock_outline_rounded,
              size: 38, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 16),
        Text('Sin módulos disponibles',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: const Color(0xFF475569))),
        const SizedBox(height: 6),
        Text('Tu rol no tiene acceso a ningún módulo',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: const Color(0xFF94A3B8))),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// HEADER DEL CONTENIDO PRINCIPAL
// ══════════════════════════════════════════════════════════════
class _ContentHeader extends StatelessWidget {
  final _MenuItem item;
  const _ContentHeader({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8ECF2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícono del módulo
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon,
                size: 18, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),

          // Breadcrumb
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.group.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                item.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Separador + fecha/hora opcional
          Text(
            _formattedDate(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFFB0BBCC),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${now.day} ${months[now.month - 1]}. ${now.year}';
  }
}

// ══════════════════════════════════════════════════════════════
// SIDEBAR
// ══════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  final List<_MenuItem>    menuItems;
  final int                selectedIndex;
  final AuthProvider       auth;
  final void Function(int) onSelect;
  final VoidCallback       onLogout;

  const _Sidebar({
    required this.menuItems,
    required this.selectedIndex,
    required this.auth,
    required this.onSelect,
    required this.onLogout,
  });

  List<_MenuGroup> _buildGroups() {
    final map = <String, List<_MenuItem>>{};
    for (final item in menuItems) {
      map.putIfAbsent(item.group, () => []).add(item);
    }
    const order = ['Operaciones', 'Finanzas', 'Gestión', 'Administración'];
    final result = <_MenuGroup>[];
    for (final g in order) {
      if (map.containsKey(g)) result.add(_MenuGroup(g, map[g]!));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();

    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1526),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 32,
            offset: Offset(6, 0),
          ),
        ],
      ),
      child: Column(children: [

        // ── Logo / Marca ─────────────────────────────
        _buildBrand(),

        // ── Línea divisora decorativa ─────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Color(0xFF1E3050),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Perfil de usuario ────────────────────────
        _buildUserCard(),

        const SizedBox(height: 8),

        // ── Navegación con grupos ────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: groups.expand((g) => [
              _groupLabel(g.title),
              ...g.items.map((item) {
                final idx = menuItems.indexOf(item);
                return _navItem(item, idx, idx == selectedIndex);
              }),
              const SizedBox(height: 4),
            ]).toList(),
          ),
        ),

        // ── Versión ──────────────────────────────────
        _buildVersion(),

        // ── Cerrar sesión ────────────────────────────
        _buildLogout(context),
      ]),
    );
  }

  // ── Brand header ──────────────────────────────────
  Widget _buildBrand() => Container(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.45),
              blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.store_rounded,
            color: Colors.white, size: 20),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POS',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20, letterSpacing: -0.5)),
          Text('Multitienda',
              style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF3D5270),
                  fontSize: 11, fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ],
      ),

      const Spacer(),

      // Punto verde de "en línea"
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withOpacity(0.5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    ]),
  );

  // ── Tarjeta de usuario ─────────────────────────────
  Widget _buildUserCard() => Container(
    margin:  const EdgeInsets.symmetric(horizontal: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF131F35),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF1E3050)),
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_rolGradient(auth.rol)[0], _rolGradient(auth.rol)[1]],
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(
          child: Text(
            auth.nombre.isNotEmpty ? auth.nombre[0].toUpperCase() : 'U',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(auth.nombre,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFE2E8F0), fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _rolColor(auth.rol).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _rolColor(auth.rol).withOpacity(0.25)),
              ),
              child: Text(
                auth.rol.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                    color: _rolColor(auth.rol),
                    fontSize: 9, fontWeight: FontWeight.w800,
                    letterSpacing: 0.6),
              ),
            ),
          ],
        ),
      ),
    ]),
  );

  // ── Etiqueta de grupo ──────────────────────────────
  Widget _groupLabel(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 18, 10, 5),
    child: Row(children: [
      Container(
        width: 16, height: 1,
        color: const Color(0xFF1E3050),
      ),
      const SizedBox(width: 8),
      Text(title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF2E4268),
              fontSize: 9, fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
      const SizedBox(width: 8),
      Expanded(
        child: Container(height: 1, color: const Color(0xFF1E3050)),
      ),
    ]),
  );

  // ── Ítem de navegación ─────────────────────────────
  Widget _navItem(_MenuItem item, int index, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap:        () => onSelect(index),
          borderRadius: BorderRadius.circular(10),
          hoverColor:   const Color(0xFF131F35),
          splashColor:  const Color(0xFF6366F1).withOpacity(0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve:    Curves.easeOut,
            padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF6366F1).withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.25))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(children: [
              // Indicador lateral izquierdo
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3, height: 22,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF818CF8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Ícono
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6366F1).withOpacity(0.18)
                      : const Color(0xFF131F35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 16,
                  color: selected
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF3D5270),
                ),
              ),
              const SizedBox(width: 11),

              // Label
              Expanded(
                child: Text(item.label,
                    style: GoogleFonts.plusJakartaSans(
                        color: selected
                            ? const Color(0xFFCDD5FF)
                            : const Color(0xFF4E6285),
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700 : FontWeight.w500)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Versión de la app ──────────────────────────────
  Widget _buildVersion() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Row(children: [
      const Icon(Icons.circle, size: 6, color: Color(0xFF1E3050)),
      const SizedBox(width: 8),
      Text('v1.0.0',
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF1E3050),
              fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );

  // ── Cerrar sesión ──────────────────────────────────
  Widget _buildLogout(BuildContext context) => Container(
    margin:  const EdgeInsets.fromLTRB(12, 0, 12, 16),
    decoration: BoxDecoration(
      color:        const Color(0xFF130A0A),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: const Color(0xFF2A1010)),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap:        onLogout,
        borderRadius: BorderRadius.circular(12),
        hoverColor:   const Color(0xFFEF4444).withOpacity(0.07),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout_rounded,
                  size: 16, color: Color(0xFFF87171)),
            ),
            const SizedBox(width: 12),
            Text('Cerrar sesión',
                style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF87171),
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 10, color: Color(0xFF7B2020)),
          ]),
        ),
      ),
    ),
  );

  // ── Helpers de color por rol ───────────────────────
  Color _rolColor(String rol) {
    switch (rol) {
      case 'superadmin': return const Color(0xFFA78BFA);
      case 'admin':      return const Color(0xFFFBBF24);
      case 'supervisor': return const Color(0xFF38BDF8);
      default:           return const Color(0xFF34D399);
    }
  }

  List<Color> _rolGradient(String rol) {
    switch (rol) {
      case 'superadmin': return [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];
      case 'admin':      return [const Color(0xFFD97706), const Color(0xFFFBBF24)];
      case 'supervisor': return [const Color(0xFF0284C7), const Color(0xFF38BDF8)];
      default:           return [const Color(0xFF059669), const Color(0xFF34D399)];
    }
  }
}

// ══════════════════════════════════════════════════════
// MODELOS INTERNOS
// ══════════════════════════════════════════════════════
class _MenuItem {
  final IconData     icon;
  final String       label;
  final List<String> roles;
  final String       group;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.roles,
    required this.group,
  });
}

class _MenuGroup {
  final String          title;
  final List<_MenuItem> items;
  const _MenuGroup(this.title, this.items);
}

class _Screen {
  final Widget         widget;
  final List<String>   roles;
  const _Screen({required this.widget, required this.roles});
}