import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../admin_inicio/admin_dashboard.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final branch = auth.tiendaNombre.isNotEmpty
        ? auth.tiendaNombre
        : (auth.empresaNombre.isNotEmpty ? auth.empresaNombre : 'POS Multimedia');

    return AdminDashboard(
      userName: auth.nombre.isNotEmpty ? auth.nombre : 'Usuario',
      userRole: _mapRole(auth.rol),
      branch: branch,
    );
  }

  String _mapRole(String rol) {
    switch (rol) {
      case 'superadmin':
        return 'Superadministrador';
      case 'admin':
        return 'Administrativo Central';
      case 'supervisor':
        return 'Supervisor';
      case 'cajero':
        return 'Cajero';
      default:
        return rol;
    }
  }
}