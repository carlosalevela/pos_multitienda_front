// lib/screens/compras/compras_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/proveedores_provider.dart';
import '../../providers/auth_provider.dart';
import 'compras_theme.dart';
import 'widgets/compras_tabla.dart';
import 'widgets/detalle_compra_dialog.dart';
import 'widgets/nueva_orden_dialog.dart';
import 'widgets/recepcion_resultado_dialog.dart';
// ✅ import del modal de precios
import 'widgets/modal_precios_recibir.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
      _cargarMayoreo(); // ✅ carga config mayoreo al iniciar
    });
  }

  void _cargar() {
    final auth = context.read<AuthProvider>();
    context.read<ProveedoresProvider>().cargarCompras(
      tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
      estado:   _filtroEstado,
    );
  }

  // ✅ Carga la configuración de mayoreo de la empresa
  Future<void> _cargarMayoreo() async {
    final auth      = context.read<AuthProvider>();
    final empresaId = int.tryParse(auth.empresaId) ?? 0;
    if (empresaId == 0) return;
    await context
        .read<ProveedoresProvider>()
        .cargarConfigMayoreo(empresaId);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProveedoresProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(children: [
        _buildHeader(auth),
        Expanded(
          child: prov.cargandoCompras
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(prov, auth),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader(AuthProvider auth) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(
        color:      Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset:     const Offset(0, 2),
      )],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:        ComprasTheme.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.shopping_cart_rounded,
            color: ComprasTheme.accent, size: 24),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Órdenes de compra',
          style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ComprasTheme.dark)),
        Text(auth.tiendaNombre,
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade500)),
      ]),
      const Spacer(),

      // Filtro estado
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:        const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _filtroEstado,
            hint: Text('Todos los estados',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade500)),
            style: GoogleFonts.poppins(
                fontSize: 13, color: ComprasTheme.dark),
            icon: const Icon(
                Icons.keyboard_arrow_down_rounded, size: 18),
            onChanged: (v) {
              setState(() => _filtroEstado = v);
              _cargar();
            },
            items: [
              DropdownMenuItem(
                value: null,
                child: Text('Todos',
                    style: GoogleFonts.poppins(fontSize: 13))),
              ...['pendiente', 'recibida', 'cancelada'].map((e) =>
                DropdownMenuItem(
                  value: e,
                  child: Row(children: [
                    Icon(ComprasTheme.iconEstado(e),
                        size: 14,
                        color: ComprasTheme.colorEstado(e)),
                    const SizedBox(width: 6),
                    Text(ComprasTheme.labelEstado(e),
                        style: GoogleFonts.poppins(fontSize: 13)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),

      // Botón nueva orden
      ElevatedButton.icon(
        onPressed: () => _abrirNuevaOrden(context),
        icon:  const Icon(Icons.add_rounded, size: 18),
        label: Text('Nueva orden',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: ComprasTheme.accent,
          foregroundColor: Colors.white,
          elevation:       0,
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );

  // ── Body ──────────────────────────────────────────────────

  Widget _buildBody(ProveedoresProvider prov, AuthProvider auth) =>
    SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpis(prov),
          const SizedBox(height: 16),
          ComprasTabla(
            prov:         prov,
            auth:         auth,
            filtroEstado: _filtroEstado,
            onNuevaOrden: () => _abrirNuevaOrden(context),
            onVerDetalle: (id) => _verDetalle(context, id),
            onRecibir:    (c)  => _confirmarRecibir(context, c),
            onCancelar:   (c)  => _confirmarCancelar(context, c),
          ),
        ],
      ),
    );

  // ── KPIs ──────────────────────────────────────────────────

  Widget _buildKpis(ProveedoresProvider prov) {
    final pendientes     = prov.compras
        .where((c) => c['estado'] == 'pendiente').length;
    final recibidas      = prov.compras
        .where((c) => c['estado'] == 'recibida').length;
    final canceladas     = prov.compras
        .where((c) => c['estado'] == 'cancelada').length;
    final totalInvertido = prov.totalComprasRecibidas;

    return Row(children: [
      Expanded(child: _kpiCard(
        icon:  Icons.receipt_long_rounded,
        label: 'Total órdenes',
        valor: '${prov.compras.length}',
        color: const Color(0xFF1976D2),
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:  Icons.pending_actions_rounded,
        label: 'Pendientes',
        valor: '$pendientes',
        color: const Color(0xFFE65100),
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:  Icons.check_circle_rounded,
        label: 'Recibidas',
        valor: '$recibidas',
        color: const Color(0xFF00897B),
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:  Icons.attach_money_rounded,
        label: 'Total invertido',
        valor: '\$${ComprasTheme.fmt(totalInvertido)}',
        color: const Color(0xFF7B1FA2),
      )),
      if (canceladas > 0) ...[
        const SizedBox(width: 12),
        Expanded(child: _kpiCard(
          icon:  Icons.cancel_rounded,
          label: 'Canceladas',
          valor: '$canceladas',
          color: Colors.red.shade700,
        )),
      ],
    ]);
  }

  Widget _kpiCard({
    required IconData icon,
    required String   label,
    required String   valor,
    required Color    color,
  }) =>
    Container(
      height: 86,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(
          color:      Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset:     const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:  MainAxisAlignment.center,
          children: [
            Text(valor,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize:   18,
                  color:      ComprasTheme.dark)),
            Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color:    Colors.grey.shade500)),
          ],
        )),
      ]),
    );

  // ── Acciones ──────────────────────────────────────────────

  void _abrirNuevaOrden(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const NuevaOrdenDialog(),
    ).then((_) => _cargar());
  }

  void _verDetalle(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => DetalleCompraDialog(id: id),
    );
  }

  // ✅ Reemplaza el dialog simple por el modal de precios
  void _confirmarRecibir(
      BuildContext context, Map<String, dynamic> c) async {
    final prov = context.read<ProveedoresProvider>();

    // Abre el modal de precios
    final result = await showModalPreciosRecibir(
      context:   context,
      compra:    c,
      manejaM:   prov.manejaM,
      cantidadM: prov.cantidadM,
    );

    // Usuario canceló el modal
    if (result == null || !mounted) return;

    // Recibir compra con los precios fijados
    final data = await prov.recibirCompra(
      c['id'],
      precios:        result.precios,
      preciosMayoreo: result.preciosMayoreo,
    );

    if (!mounted) return;

    if (data != null) {
      _cargar();
      showDialog(
        context: context,
        builder: (_) => ResultadoRecepcionDialog(data: data),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          prov.errorMsg ?? 'Error al recibir la orden',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  void _confirmarCancelar(
      BuildContext context, Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.cancel_rounded,
              color: Colors.red.shade600, size: 22),
          const SizedBox(width: 10),
          Text('Cancelar orden',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade700),
            children: [
              const TextSpan(
                  text: 'Seguro que deseas cancelar la orden '),
              TextSpan(
                text: c['numero_orden'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(
                  text: '? Esta acción no se puede deshacer.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No, mantener',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600))),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await context
                  .read<ProveedoresProvider>()
                  .cancelarCompra(c['id']);
              if (!mounted) return;
              _cargar();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  ok ? 'Orden cancelada' : 'Error al cancelar la orden',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                backgroundColor: ok
                    ? Colors.orange.shade600
                    : Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ));
            },
            icon:  const Icon(Icons.cancel_rounded, size: 16),
            label: Text('Sí, cancelar',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}