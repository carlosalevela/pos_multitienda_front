// lib/screens/proveedores/proveedores_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/proveedores_provider.dart';
import '../../providers/auth_provider.dart';
import 'widgets/proveedores_header.dart';
import 'widgets/proveedores_kpis.dart';
import 'widgets/proveedores_tabla.dart';
import 'widgets/proveedor_form_dialog.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});
  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _cargar() =>
      context.read<ProveedoresProvider>().cargarProveedores(q: _searchCtrl.text);

  void _onSearch(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => context.read<ProveedoresProvider>().cargarProveedores(q: v),
    );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {});
    context.read<ProveedoresProvider>().cargarProveedores();
  }

  void _abrirFormulario({Map<String, dynamic>? proveedor}) {
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProveedorFormDialog(
        proveedor:     proveedor,
        esSuperadmin:  auth.esSuperadmin,
        empresaIdFija: auth.esSuperadmin ? null : auth.empresaId,
        tiendaIdFijo:  auth.esSuperadmin ? null : auth.tiendaId,
        onGuardado: (ok, esEdicion) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok
                ? esEdicion
                    ? 'Proveedor actualizado correctamente'
                    : 'Proveedor creado correctamente'
                : 'Ocurrió un error, intenta de nuevo'),
            backgroundColor:
                ok ? Colors.green.shade600 : Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ));
        },
      ),
    );
  }

  void _confirmarEliminar(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_rounded,
              color: Colors.red.shade600, size: 22),
          const SizedBox(width: 10),
          const Text('Desactivar proveedor'),
        ]),
        content: RichText(
          text: TextSpan(
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade700),
            children: [
              const TextSpan(text: '¿Deseas desactivar a '),
              TextSpan(
                text: p['nombre'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(
                  text: '? No se eliminará permanentemente.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await context
                  .read<ProveedoresProvider>()
                  .eliminarProveedor(p['id']);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Proveedor desactivado'
                    : 'Error al desactivar'),
                backgroundColor: ok
                    ? Colors.orange.shade600
                    : Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sí, desactivar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProveedoresProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(children: [
        ProveedoresHeader(
          searchCtrl: _searchCtrl,
          onSearch:   _onSearch,
          onClear:    _clearSearch,
          onNuevo:    () => _abrirFormulario(),
        ),
        Expanded(
          child: prov.cargandoProveedores
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProveedoresKpis(prov: prov),
                      const SizedBox(height: 16),
                      ProveedoresTabla(
                        prov:       prov,
                        searchText: _searchCtrl.text,
                        onEditar:   (p) => _abrirFormulario(proveedor: p),
                        onEliminar: _confirmarEliminar,
                        onNuevo:    () => _abrirFormulario(),
                      ),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }
}