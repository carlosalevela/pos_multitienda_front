import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/cliente_provider.dart';
import '../../models/cliente.dart';
import 'widgets/cliente_card.dart';
import 'widgets/cliente_form.dart';
import 'widgets/cliente_search_bar.dart';
import 'widgets/alertas_badge.dart';

class ClientesScreen extends StatefulWidget {
  final bool esAdminOSupervisor;

  const ClientesScreen({
    super.key,
    required this.esAdminOSupervisor,
  });

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<ClienteProvider>();
      await prov.cargarClientes();
      await prov.cargarAlertas();
    });
  }

  void _mostrarFormCrear() {
    ClienteForm.mostrar(
      context,
      onGuardado: () async {
        await context.read<ClienteProvider>().cargarClientes();
      },
    );
  }

  void _mostrarFormEditar(Cliente cliente) {
    ClienteForm.mostrar(
      context,
      cliente: cliente,
      onGuardado: () async {
        await context.read<ClienteProvider>().cargarClientes();
      },
    );
  }

  Future<void> _confirmarDesactivar(Cliente cliente) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          '¿Desactivar cliente?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          'El cliente "${cliente.nombreCompleto}" dejará de aparecer en las búsquedas activas.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Desactivar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final prov = context.read<ClienteProvider>();
    final success = await prov.desactivarCliente(cliente.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Cliente desactivado correctamente'
              : (prov.error ?? 'No se pudo desactivar el cliente'),
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        backgroundColor:
            success ? const Color(0xFF437A22) : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _verDetalleCliente(Cliente cliente) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ClienteDetalleSheet(
        cliente: cliente,
        esAdminOSupervisor: widget.esAdminOSupervisor,
        onEditar: () {
          Navigator.pop(context);
          _mostrarFormEditar(cliente);
        },
        onDesactivar: () {
          Navigator.pop(context);
          _confirmarDesactivar(cliente);
        },
      ),
    );
  }

  Future<void> _recargar() async {
    final prov = context.read<ClienteProvider>();
    await prov.cargarClientes();
    await prov.cargarAlertas();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClienteProvider>(
      builder: (_, prov, __) {
        final clientes = prov.clientes;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clientes',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF28251D),
                        ),
                      ),
                      Text(
                        '${clientes.length} registrados',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF7A7974),
                        ),
                      ),
                    ],
                  ),
                ),
                AlertasBadge(
                  total: prov.totalAlertas,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          prov.totalAlertas > 0
                              ? 'Tienes ${prov.totalAlertas} alertas de separados'
                              : 'No hay alertas activas',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Search bar ─────────────────────────────────
            ClienteSearchBar(
              onSearch: (q) => prov.cargarClientes(q: q),
              onAgregar:
                  widget.esAdminOSupervisor ? _mostrarFormCrear : null,
            ),

            const SizedBox(height: 14),

            // ── Estado error ───────────────────────────────
            if (prov.error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prov.error!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: prov.limpiarError,
                      child: Icon(Icons.close_rounded,
                          size: 18, color: Colors.red.shade300),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Lista ──────────────────────────────────────
            Expanded(
              child: prov.cargando
                  ? const Center(child: CircularProgressIndicator())
                  : clientes.isEmpty
                      ? _EstadoVacio(
                          esAdminOSupervisor: widget.esAdminOSupervisor,
                          onCrear: _mostrarFormCrear,
                          onRecargar: _recargar,
                        )
                      : RefreshIndicator(
                          onRefresh: _recargar,
                          color: const Color(0xFF01696F),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: clientes.length,
                            itemBuilder: (_, i) {
                              final cliente = clientes[i];
                              return ClienteCard(
                                cliente: cliente,
                                mostrarAcciones: widget.esAdminOSupervisor,
                                onTap: () => _verDetalleCliente(cliente),
                                onEditar: () => _mostrarFormEditar(cliente),
                                onDesactivar: () =>
                                    _confirmarDesactivar(cliente),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════

class _EstadoVacio extends StatelessWidget {
  final bool esAdminOSupervisor;
  final VoidCallback onCrear;
  final Future<void> Function() onRecargar;

  const _EstadoVacio({
    required this.esAdminOSupervisor,
    required this.onCrear,
    required this.onRecargar,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF01696F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              size: 32,
              color: Color(0xFF01696F),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'No hay clientes aún',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF28251D),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              esAdminOSupervisor
                  ? 'Crea tu primer cliente para empezar a registrar ventas y separados.'
                  : 'Todavía no hay clientes disponibles para mostrar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF7A7974),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (esAdminOSupervisor)
              ElevatedButton.icon(
                onPressed: onCrear,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(
                  'Nuevo cliente',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF01696F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            if (esAdminOSupervisor) const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onRecargar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Recargar',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF01696F),
                side: const BorderSide(color: Color(0xFF01696F)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════

class _ClienteDetalleSheet extends StatelessWidget {
  final Cliente cliente;
  final bool esAdminOSupervisor;
  final VoidCallback? onEditar;
  final VoidCallback? onDesactivar;

  const _ClienteDetalleSheet({
    required this.cliente,
    required this.esAdminOSupervisor,
    this.onEditar,
    this.onDesactivar,
  });

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFFBAB9B4)),
          const SizedBox(width: 10),
          Text(
            '$label  ',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF7A7974),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF28251D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iniciales = [
      cliente.nombre.isNotEmpty ? cliente.nombre[0] : '',
      cliente.apellido.isNotEmpty ? cliente.apellido[0] : '',
    ].join().toUpperCase();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF01696F).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      iniciales,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF01696F),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  cliente.nombreCompleto,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF28251D),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cliente.activo
                        ? const Color(0xFFD4DFCC)
                        : const Color(0xFFF3F0EC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cliente.activo ? 'Activo' : 'Inactivo',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cliente.activo
                          ? const Color(0xFF437A22)
                          : const Color(0xFF7A7974),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F8F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEDEAE5)),
                  ),
                  child: Column(
                    children: [
                      _infoTile(Icons.badge_outlined, 'Cédula/NIT',
                          cliente.cedulaNit ?? '—'),
                      _infoTile(
                          Icons.phone_outlined, 'Teléfono', cliente.telefono),
                      _infoTile(Icons.email_outlined, 'Email', cliente.email),
                      _infoTile(Icons.location_on_outlined, 'Dirección',
                          cliente.direccion),
                    ],
                  ),
                ),
                if (esAdminOSupervisor) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEditar,
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: Text(
                            'Editar',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF01696F),
                            side: const BorderSide(
                              color: Color(0xFF01696F),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onDesactivar,
                          icon: const Icon(Icons.person_off_outlined, size: 17),
                          label: Text(
                            'Desactivar',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade500,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}