// lib/screens/empresas/empresas_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/empresa_model.dart';
import '../../models/tienda_model.dart';
import '../../providers/empresa_provider.dart';
import '../../providers/tienda_provider.dart';
import '../../services/tienda_service.dart';
import '../../widgets/app/section_header.dart';
import '../../widgets/app/stat_card.dart';
import 'dialogs/confirmar_desactivar_tienda_dialog.dart';
import 'dialogs/empresa_form_dialog.dart';
import 'dialogs/tienda_form_dialog.dart';
import 'widgets/empresa_detail_panel.dart';
import 'widgets/empresas_list_panel.dart';

class EmpresasScreen extends StatefulWidget {
  const EmpresasScreen({super.key});

  @override
  State<EmpresasScreen> createState() => _EmpresasScreenState();
}

class _EmpresasScreenState extends State<EmpresasScreen> {
  Empresa? _empresaSeleccionada;
  List<Tienda> _tiendas = [];
  bool _cargandoTiendas = false;

  // ── Lifecycle ────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmpresaProvider>().cargarEmpresas();
    });
  }

  // ── Seleccionar empresa y cargar sus tiendas ─────────
  Future<void> _seleccionarEmpresa(Empresa empresa) async {
    setState(() {
      _empresaSeleccionada = empresa;
      _tiendas = [];
      _cargandoTiendas = true;
    });

    try {
      await context
          .read<TiendaProvider>()
          .cargarTiendasPorEmpresa(empresa.id);
      if (mounted) {
        setState(() {
          _tiendas = context.read<TiendaProvider>().tiendas;
          _cargandoTiendas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoTiendas = false);
    }
  }

  // ── Recargar tiendas de la empresa activa ────────────
  Future<void> _recargarTiendas() async {
    if (_empresaSeleccionada == null) return;
    await _seleccionarEmpresa(_empresaSeleccionada!);
  }

  // ── Snackbars ────────────────────────────────────────
  void _mostrarMensajes(EmpresaProvider prov) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (prov.errorMsg.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(prov.errorMsg,
                style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        prov.limpiarMensajes();
      } else if (prov.successMsg.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(prov.successMsg,
                style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        prov.limpiarMensajes();
      }
    });
  }

  // ── Ver empleados de una tienda ──────────────────────
  Future<void> _verEmpleados(Tienda t) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic>? data;
    try {
      data = await TiendaService().getEmpleadosPorTienda(t.id);
    } catch (_) {
      data = null;
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al cargar los empleados',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    final empleados = (data['empleados'] as List?) ?? [];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.people_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Empleados — ${t.nombre}',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: empleados.isEmpty
              ? Center(
                  child: Text('Sin empleados asignados',
                      style:
                          GoogleFonts.poppins(color: Colors.grey)))
              : ListView.builder(
                  itemCount: empleados.length,
                  itemBuilder: (_, i) {
                    final e = empleados[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(Constants.primaryColor)
                                .withOpacity(0.15),
                        child: Text(
                          (e['nombre'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                              color: Color(Constants.primaryColor),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        (e['rol'] ?? '').toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<EmpresaProvider>();
    _mostrarMensajes(prov);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header global ────────────────────────────
          SectionHeader(
            icon: Icons.business_rounded,
            title: 'Empresas y sucursales',
            subtitle: 'Selecciona una empresa para ver sus sucursales',
            actionLabel: 'Nueva empresa',
            onActionPressed: () => EmpresaFormDialog.show(context).then(
              (_) => context.read<EmpresaProvider>().cargarEmpresas(),
            ),
          ),
          const SizedBox(height: 16),

          // ── KPIs globales ────────────────────────────
          Row(
            children: [
              StatCard(
                label: 'Total empresas',
                value: '${prov.totalEmpresas}',
                icon: Icons.business_rounded,
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              StatCard(
                label: 'Activas',
                value: '${prov.totalActivas}',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              StatCard(
                label: 'Inactivas',
                value: '${prov.totalInactivas}',
                icon: Icons.cancel_rounded,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Layout maestro-detalle ───────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panel izquierdo — lista de empresas
                SizedBox(
                  width: 320,
                  child: EmpresasListPanel(
                    empresas: prov.empresas,
                    cargando: prov.cargando,
                    empresaSeleccionada: _empresaSeleccionada,
                    onSeleccionar: _seleccionarEmpresa,
                    onEditar: (e) => EmpresaFormDialog.show(
                      context,
                      empresa: e,
                    ).then((_) async {
                      await context
                          .read<EmpresaProvider>()
                          .cargarEmpresas();
                      // Si editamos la empresa activa, refrescar detalle
                      if (_empresaSeleccionada?.id == e.id) {
                        final actualizada = context
                            .read<EmpresaProvider>()
                            .empresas
                            .firstWhere((em) => em.id == e.id,
                                orElse: () => e);
                        setState(
                            () => _empresaSeleccionada = actualizada);
                      }
                    }),
                    onRefresh: prov.cargarEmpresas,
                  ),
                ),
                const SizedBox(width: 16),

                // Panel derecho — detalle de empresa
                Expanded(
                  child: EmpresaDetailPanel(
                    empresaSeleccionada: _empresaSeleccionada,
                    tiendas: _tiendas,
                    cargandoTiendas: _cargandoTiendas,
                    onEditarEmpresa: () => _empresaSeleccionada == null
                        ? null
                        : EmpresaFormDialog.show(
                            context,
                            empresa: _empresaSeleccionada,
                          ).then((_) async {
                            await context
                                .read<EmpresaProvider>()
                                .cargarEmpresas();
                            final actualizada = context
                                .read<EmpresaProvider>()
                                .empresas
                                .firstWhere(
                                    (e) =>
                                        e.id == _empresaSeleccionada!.id,
                                    orElse: () => _empresaSeleccionada!);
                            setState(
                                () => _empresaSeleccionada = actualizada);
                          }),
                    onNuevaTienda: () => TiendaFormDialog.show(
                      context,
                      empresaId: _empresaSeleccionada?.id.toString(),
                    ).then((_) => _recargarTiendas()),
                    onEditarTienda: (t) => TiendaFormDialog.show(
                      context,
                      tienda: t,
                    ).then((_) => _recargarTiendas()),
                    onVerEmpleados: _verEmpleados,
                    onDesactivarTienda: (t) =>
                        ConfirmarDesactivarTiendaDialog.show(
                      context,
                      tienda: t,
                    ).then((_) => _recargarTiendas()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}