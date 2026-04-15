// lib/screens/tiendas/tiendas_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/tienda_provider.dart';
import '../../models/tienda_model.dart';
import '../../core/constants.dart';
import '../../services/tienda_service.dart';

class TiendasScreen extends StatefulWidget {
  const TiendasScreen({super.key});
  @override
  State<TiendasScreen> createState() => _TiendasScreenState();
}

class _TiendasScreenState extends State<TiendasScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TiendaProvider>().cargarTiendas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TiendaProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(Constants.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.store_rounded,
                  color: Color(Constants.primaryColor)),
            ),
            const SizedBox(width: 12),
            Text('Tiendas',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E))),
            const Spacer(),
            ElevatedButton.icon(
              icon:  const Icon(Icons.add_rounded, size: 18),
              label: Text('Nueva tienda',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onPressed: () => _abrirFormTienda(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(Constants.primaryColor),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0),
            ),
          ]),
          const SizedBox(height: 16),

          // ── KPIs ────────────────────────────────────────
          Row(children: [
            _kpiCard('Total tiendas',  '${prov.tiendas.length}',
                Icons.store_rounded,        Colors.blue),
            const SizedBox(width: 12),
            _kpiCard('Activas',        '${prov.totalActivas}',
                Icons.check_circle_rounded, Colors.green),
            const SizedBox(width: 12),
            _kpiCard('Inactivas',      '${prov.totalInactivas}',
                Icons.cancel_rounded,       Colors.red),
          ]),
          const SizedBox(height: 16),

          // ── Lista ────────────────────────────────────────
          Expanded(
            child: prov.cargando
                ? const Center(child: CircularProgressIndicator())
                : prov.tiendas.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: prov.cargarTiendas,
                        child: ListView.builder(
                          itemCount: prov.tiendas.length,
                          itemBuilder: (_, i) => _tiendaCard(
                              context, prov, prov.tiendas[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── KPI card ──────────────────────────────────────────
  Widget _kpiCard(
      String label, String valor, IconData icon, Color color) =>
    Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade500)),
            Text(valor,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E))),
          ]),
        ]),
      ),
    );

  // ── Tienda card ───────────────────────────────────────
  Widget _tiendaCard(
      BuildContext context, TiendaProvider prov, Tienda t) =>
    Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: t.activo
                ? Colors.transparent
                : Colors.red.shade100),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.activo
                ? const Color(Constants.primaryColor).withOpacity(0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.store_rounded,
            color: t.activo
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade400,
            size: 24),
        ),
        title: Row(children: [
          Text(t.nombre,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.activo
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20)),
            child: Text(
              t.activo ? 'Activa' : 'Inactiva',
              style: GoogleFonts.poppins(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: t.activo
                    ? Colors.green.shade700
                    : Colors.red.shade700)),
          ),
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (t.ciudad.isNotEmpty)
              Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(t.ciudad,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade500)),
              ]),
            if (t.nit.isNotEmpty)
              Text('NIT: ${t.nit}',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade400)),
            Row(children: [
              Icon(Icons.people_rounded,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('${t.totalEmpleados} empleado(s)',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Ver empleados',
            icon: Icon(Icons.people_rounded,
                color: Colors.blue.shade400, size: 20),
            onPressed: () => _verEmpleados(context, t),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: Icon(Icons.edit_rounded,
                color: Colors.orange.shade400, size: 20),
            onPressed: () => _abrirFormTienda(context, tienda: t),
          ),
          if (t.activo)
            IconButton(
              tooltip: 'Desactivar',
              icon: Icon(Icons.remove_circle_outline_rounded,
                  color: Colors.red.shade300, size: 20),
              onPressed: () =>
                  _confirmarDesactivar(context, prov, t),
            ),
        ]),
      ),
    );

  // ── Empty state ───────────────────────────────────────
  Widget _emptyState() => Center(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.store_rounded, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('No hay tiendas registradas',
        style: GoogleFonts.poppins(
            fontSize: 16, color: Colors.grey.shade400)),
      const SizedBox(height: 8),
      Text('Crea la primera tienda con el botón de arriba',
        style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.grey.shade300)),
    ]),
  );

  // ── Form crear/editar tienda ──────────────────────────
  void _abrirFormTienda(BuildContext context, {Tienda? tienda}) {
    final editando      = tienda != null;
    final nombreCtrl    = TextEditingController(
        text: tienda?.nombre    ?? '');
    final direccionCtrl = TextEditingController(
        text: tienda?.direccion ?? '');
    final telefonoCtrl  = TextEditingController(
        text: tienda?.telefono  ?? '');
    final ciudadCtrl    = TextEditingController(
        text: tienda?.ciudad    ?? '');
    final nitCtrl       = TextEditingController(
        text: tienda?.nit       ?? '');

    // ✅ FIX: dispose controllers cuando el dialog se cierra
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
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(16))),
          child: Row(children: [
            const Icon(Icons.store_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              editando ? 'Editar Tienda' : 'Nueva Tienda',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          ]),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _field('Nombre de la tienda *', nombreCtrl),
                _field('Dirección',  direccionCtrl),
                _field('Teléfono',   telefonoCtrl),
                _field('Ciudad',     ciudadCtrl),
                _field('NIT',        nitCtrl),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: Colors.grey))),
          // ✅ FIX: Consumer en lugar de context.watch del screen
          Consumer<TiendaProvider>(
            builder: (_, prov, __) => ElevatedButton.icon(
              icon: prov.guardando
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                editando ? 'Guardar cambios' : 'Crear tienda',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600)),
              onPressed: prov.guardando ? null : () async {
                if (nombreCtrl.text.trim().isEmpty) return;
                final data = {
                  'nombre':    nombreCtrl.text.trim(),
                  'direccion': direccionCtrl.text.trim(),
                  'telefono':  telefonoCtrl.text.trim(),
                  'ciudad':    ciudadCtrl.text.trim(),
                  'nit':       nitCtrl.text.trim(),
                };
                final ok = editando
                    ? await prov.editarTienda(tienda!.id, data)
                    : await prov.crearTienda(data);
                if (ok && context.mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(Constants.primaryColor),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      // ✅ FIX: dispose de los 5 controllers al cerrar el dialog
      nombreCtrl.dispose();
      direccionCtrl.dispose();
      telefonoCtrl.dispose();
      ciudadCtrl.dispose();
      nitCtrl.dispose();
    });
  }

  // ── Ver empleados de la tienda ────────────────────────
  Future<void> _verEmpleados(BuildContext context, Tienda t) async {
    // ✅ FIX: eliminada variable 'service' no usada
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator()),
    );

    // ✅ FIX: try/catch — si falla la red el loading no queda infinito
    Map<String, dynamic>? data;
    try {
      data = await TiendaService().getEmpleadosPorTienda(t.id);
    } catch (_) {
      data = null;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // cierra loading

    // ✅ FIX: si hubo error, mostrar SnackBar en lugar de dialog vacío
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al cargar los empleados',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    final empleados = (data['empleados'] as List?) ?? [];

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
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(16))),
          child: Row(children: [
            const Icon(Icons.people_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Empleados — ${t.nombre}',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
                overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        content: SizedBox(
          width: 400, height: 300,
          child: empleados.isEmpty
              ? Center(child: Text('Sin empleados asignados',
                  style: GoogleFonts.poppins(
                      color: Colors.grey)))
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
                              fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                      subtitle: Text(
                        (e['rol'] ?? '').toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar',
                style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  // ── Confirmar desactivar ──────────────────────────────
  void _confirmarDesactivar(
      BuildContext context, TiendaProvider prov, Tienda t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Text('¿Desactivar tienda?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold)),
        content: Text(
          'La tienda "${t.nombre}" quedará inactiva.\n'
          '¿Deseas continuar?',
          style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await prov.desactivarTienda(t.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
            child: Text('Desactivar',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(
                  color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(
                  color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   const BorderSide(
                  color: Color(Constants.primaryColor),
                  width: 2)),
        ),
      ),
    );
}