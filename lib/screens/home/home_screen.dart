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
import '../contabilidad/contabilidad_screen.dart'; // ✅ NUEVO

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<_MenuItem> _getMenuItems(String rol) {
    // Todos los roles tienen estas pantallas base
    final items = <_MenuItem>[
      _MenuItem(
          icon:    Icons.point_of_sale_rounded,
          label:   'POS / Ventas',
          roles:   ['admin', 'supervisor', 'cajero']),
      _MenuItem(
          icon:    Icons.inventory_2_rounded,
          label:   'Inventario',
          roles:   ['admin', 'supervisor', 'cajero']),
      _MenuItem(
          icon:    Icons.account_balance_wallet_rounded,
          label:   'Caja',
          roles:   ['admin', 'supervisor', 'cajero']),
      _MenuItem(
          icon:    Icons.bar_chart_rounded,
          label:   'Contabilidad',      // ✅ visible para todos
          roles:   ['admin', 'supervisor', 'cajero']),
      _MenuItem(
          icon:    Icons.assessment_rounded,
          label:   'Reportes',
          roles:   ['admin', 'supervisor']),  // cajero NO ve reportes completos
      _MenuItem(
          icon:    Icons.people_rounded,
          label:   'Empleados',
          roles:   ['admin']),                // solo admin
    ];

    return items.where((i) => i.roles.contains(rol)).toList();
  }

  List<Widget> _getScreens(String rol) {
    final all = <_Screen>[
      _Screen(widget: const PosScreen(),           roles: ['admin', 'supervisor', 'cajero']),
      _Screen(widget: const InventarioScreen(),     roles: ['admin', 'supervisor', 'cajero']),
      _Screen(widget: const CajaScreen(),           roles: ['admin', 'supervisor', 'cajero']),
      _Screen(widget: const ContabilidadScreen(),   roles: ['admin', 'supervisor', 'cajero']),
      _Screen(widget: const ReportesScreen(),       roles: ['admin', 'supervisor']),
      _Screen(widget: const EmpleadosScreen(),      roles: ['admin']),
    ];

    return all
        .where((s) => s.roles.contains(rol))
        .map((s) => s.widget)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final menuItems = _getMenuItems(auth.rol);
    final screens   = _getScreens(auth.rol);

    if (_selectedIndex >= menuItems.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(Constants.backgroundColor),
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────
          Container(
            width: 240,
            color: const Color(0xFF1A1A2E),
            child: Column(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                      colors: [
                        Color(Constants.primaryColor),
                        Color(0xFF0D47A1),
                      ],
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.store_rounded,
                        color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('POS', style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                        Text('Multitienda', style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                      ],
                    )),
                  ]),
                ),

                const SizedBox(height: 16),

                // Info empleado
                Container(
                  margin:  const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    CircleAvatar(
                      radius:          20,
                      backgroundColor: const Color(Constants.primaryColor),
                      child: Text(
                        auth.nombre.isNotEmpty
                            ? auth.nombre[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.nombre,
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                        // Badge de rol
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _rolColor(auth.rol).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            auth.rol.toUpperCase(),
                            style: GoogleFonts.poppins(
                                color: _rolColor(auth.rol),
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                        ),
                      ],
                    )),
                  ]),
                ),

                const SizedBox(height: 24),

                // Menú items
                Expanded(
                  child: ListView.builder(
                    padding:   const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item       = menuItems[index];
                      final isSelected = index == _selectedIndex;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          onTap: () =>
                              setState(() => _selectedIndex = index),
                          selected: isSelected,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          selectedTileColor: const Color(Constants.primaryColor)
                              .withOpacity(0.2),
                          leading: Icon(item.icon,
                            color: isSelected
                                ? const Color(Constants.primaryColor)
                                : Colors.white54),
                          title: Text(item.label,
                            style: GoogleFonts.poppins(
                              color: isSelected
                                  ? Colors.white : Colors.white60,
                              fontWeight: isSelected
                                  ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14)),
                        ),
                      );
                    },
                  ),
                ),

                // Cerrar sesión
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    onTap: () => context.read<AuthProvider>().logout(),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    leading: const Icon(Icons.logout_rounded,
                        color: Colors.redAccent),
                    title: Text('Cerrar sesión',
                      style: GoogleFonts.poppins(
                          color: Colors.redAccent, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),

          // ── Contenido principal ──────────────────────────
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
    );
  }

  Color _rolColor(String rol) {
    switch (rol) {
      case 'admin':      return Colors.amber;
      case 'supervisor': return Colors.lightBlue;
      default:           return Colors.green;
    }
  }
}

class _MenuItem {
  final IconData    icon;
  final String      label;
  final List<String> roles;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.roles,
  });
}

class _Screen {
  final Widget       widget;
  final List<String> roles;
  const _Screen({required this.widget, required this.roles});
}