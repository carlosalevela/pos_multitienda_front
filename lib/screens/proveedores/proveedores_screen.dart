// lib/screens/proveedores/proveedores_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/proveedores_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});
  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  static const _dark   = Color(0xFF1A1A2E);
  static const _accent = Color(Constants.primaryColor);

  final _searchCtrl = TextEditingController();

  // ✅ FIX: eliminar _busqueda — usar _searchCtrl.text directamente
  // ✅ FIX: debounce para búsqueda
  Timer? _debounceSearch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    // ✅ FIX: cancelar timer
    _debounceSearch?.cancel();
    super.dispose();
  }

  void _cargar() =>
      context.read<ProveedoresProvider>()
          .cargarProveedores(q: _searchCtrl.text);

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProveedoresProvider>();
    context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(children: [
        _buildHeader(prov),
        Expanded(
          child: prov.cargandoProveedores
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(prov),
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────

  Widget _buildHeader(ProveedoresProvider prov) =>
    Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.local_shipping_rounded,
              color: _accent, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Proveedores',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: _dark)),
          Text('Gestión de proveedores',
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade500)),
        ]),
        const Spacer(),
        // ── Buscador ──────────────────────────────────────
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) {
              // ✅ FIX: setState para refrescar suffixIcon, debounce para la query
              setState(() {});
              _debounceSearch?.cancel();
              _debounceSearch = Timer(
                  const Duration(milliseconds: 350), () {
                context.read<ProveedoresProvider>()
                    .cargarProveedores(q: v);
              });
            },
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText:   'Buscar proveedor...',
              hintStyle:  GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: Colors.grey),
              // ✅ FIX: usa _searchCtrl.text — fuente única
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                        context.read<ProveedoresProvider>()
                            .cargarProveedores();
                      })
                  : null,
              filled:    true,
              fillColor: const Color(0xFFF4F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _abrirFormulario(context),
          icon:  const Icon(Icons.add_rounded, size: 18),
          label: Text('Nuevo proveedor',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );

  // ── Body ───────────────────────────────────────────────

  Widget _buildBody(ProveedoresProvider prov) =>
    SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpis(prov),
          const SizedBox(height: 16),
          _buildTabla(prov),
        ],
      ),
    );

  // ── KPIs ───────────────────────────────────────────────

  Widget _buildKpis(ProveedoresProvider prov) => Row(children: [
    Expanded(child: _kpiCard(
      icon:  Icons.store_rounded,
      label: 'Proveedores activos',
      valor: '${prov.totalProveedores}',
      color: const Color(0xFF1976D2),
    )),
    const SizedBox(width: 12),
    Expanded(child: _kpiCard(
      icon:  Icons.pending_actions_rounded,
      label: 'Órdenes pendientes',
      valor: '${prov.totalComprasPendientes}',
      color: const Color(0xFFE65100),
    )),
    const SizedBox(width: 12),
    Expanded(child: _kpiCard(
      icon:  Icons.check_circle_rounded,
      label: 'Total recibido',
      valor: '\$${_fmt(prov.totalComprasRecibidas)}',
      color: const Color(0xFF00897B),
    )),
  ]);

  Widget _kpiCard({
    required IconData icon,
    required String   label,
    required String   valor,
    required Color    color,
  }) =>
    Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [
              Text(valor,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18, color: _dark)),
              Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ]),
    );

  // ── Tabla ──────────────────────────────────────────────

  Widget _buildTabla(ProveedoresProvider prov) {
    if (prov.proveedores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14)),
        child: Center(child: Column(children: [
          Icon(Icons.local_shipping_outlined,
              size: 52, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text(
            // ✅ FIX: _searchCtrl.text — fuente única
            _searchCtrl.text.isNotEmpty
                ? 'Sin resultados para "${_searchCtrl.text}"'
                : 'Aún no hay proveedores registrados',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 14)),
          if (_searchCtrl.text.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _abrirFormulario(context),
              icon:  const Icon(Icons.add_rounded, size: 16),
              label: Text('Agregar primer proveedor',
                  style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ])),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              const Icon(Icons.list_alt_rounded, size: 16, color: _dark),
              const SizedBox(width: 7),
              Text('Lista de proveedores',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14, color: _dark)),
              const Spacer(),
              Text('${prov.proveedores.length} registros',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade400)),
            ]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft:  Radius.circular(14),
              bottomRight: Radius.circular(14)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor:
                    WidgetStateProperty.all(_dark),
                headingTextStyle: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 12),
                dataTextStyle:    GoogleFonts.poppins(fontSize: 12),
                columnSpacing:    24,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                dividerThickness: 0.5,
                columns: const [
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('NIT')),
                  DataColumn(label: Text('Teléfono')),
                  DataColumn(label: Text('Ciudad')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: prov.proveedores.map((p) {
                  return DataRow(
                    color: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.hovered)
                            ? const Color(0xFFF0F4FF)
                            : Colors.white),
                    cells: [
                      DataCell(Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Text(
                            (p['nombre'] as String)
                                .substring(0, 1).toUpperCase(),
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13, color: _accent),
                          )),
                        ),
                        const SizedBox(width: 10),
                        Text(p['nombre'] ?? '',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                      ])),
                      DataCell(Text(p['nit'] ?? '—')),
                      DataCell(Text(
                          p['telefono']?.isNotEmpty == true
                              ? p['telefono'] : '—')),
                      DataCell(Text(
                          p['ciudad']?.isNotEmpty == true
                              ? p['ciudad'] : '—')),
                      DataCell(Text(
                          p['email']?.isNotEmpty == true
                              ? p['email'] : '—',
                        style: GoogleFonts.poppins(
                            color: p['email']?.isNotEmpty == true
                                ? Colors.blue.shade600
                                : Colors.grey.shade400))),
                      DataCell(_estadoBadge(p['activo'] ?? true)),
                      DataCell(Row(children: [
                        _accionBtn(
                          icon:    Icons.edit_rounded,
                          color:   Colors.blue.shade600,
                          tooltip: 'Editar',
                          onTap:   () => _abrirFormulario(
                              context, proveedor: p),
                        ),
                        const SizedBox(width: 6),
                        _accionBtn(
                          icon:    Icons.delete_rounded,
                          color:   Colors.red.shade600,
                          tooltip: 'Desactivar',
                          onTap:   () => _confirmarEliminar(
                              context, p),
                        ),
                      ])),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Formulario crear / editar ──────────────────────────

  void _abrirFormulario(BuildContext context,
      {Map<String, dynamic>? proveedor}) {
    final esEdicion   = proveedor != null;
    final cNombre     = TextEditingController(
        text: proveedor?['nombre']    ?? '');
    final cNit        = TextEditingController(
        text: proveedor?['nit']       ?? '');
    final cTelefono   = TextEditingController(
        text: proveedor?['telefono']  ?? '');
    final cEmail      = TextEditingController(
        text: proveedor?['email']     ?? '');
    final cDireccion  = TextEditingController(
        text: proveedor?['direccion'] ?? '');
    final cCiudad     = TextEditingController(
        text: proveedor?['ciudad']    ?? '');
    final formKey     = GlobalKey<FormState>();

    // ✅ FIX: disponer controllers cuando el dialog se cierra
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            esEdicion
                ? Icons.edit_rounded
                : Icons.add_business_rounded,
            color: _accent, size: 22),
          const SizedBox(width: 10),
          Text(
            esEdicion ? 'Editar proveedor' : 'Nuevo proveedor',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: _campo(
                    ctrl:  cNombre,
                    label: 'Nombre *',
                    icon:  Icons.business_rounded,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Requerido' : null,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(
                    ctrl:  cNit,
                    label: 'NIT',
                    icon:  Icons.badge_rounded,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _campo(
                    ctrl:      cTelefono,
                    label:     'Teléfono',
                    icon:      Icons.phone_rounded,
                    inputType: TextInputType.phone,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(
                    ctrl:  cCiudad,
                    label: 'Ciudad',
                    icon:  Icons.location_city_rounded,
                  )),
                ]),
                const SizedBox(height: 12),
                _campo(
                  ctrl:      cEmail,
                  label:     'Email',
                  icon:      Icons.email_rounded,
                  inputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _campo(
                  ctrl:  cDireccion,
                  label: 'Dirección',
                  icon:  Icons.map_rounded,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600))),
          Consumer<ProveedoresProvider>(
            builder: (_, p, __) => ElevatedButton.icon(
              onPressed: p.guardando
                  ? null
                  : () => _guardar(
                        ctx,
                        formKey:   formKey,
                        esEdicion: esEdicion,
                        id:        proveedor?['id'],
                        nombre:    cNombre.text,
                        nit:       cNit.text,
                        telefono:  cTelefono.text,
                        email:     cEmail.text,
                        direccion: cDireccion.text,
                        ciudad:    cCiudad.text,
                      ),
              icon: p.guardando
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      esEdicion
                          ? Icons.save_rounded
                          : Icons.add_rounded,
                      size: 16),
              label: Text(
                esEdicion ? 'Guardar cambios' : 'Crear proveedor',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      // ✅ FIX: dispose de los 6 controllers al cerrar el dialog
      cNombre.dispose();
      cNit.dispose();
      cTelefono.dispose();
      cEmail.dispose();
      cDireccion.dispose();
      cCiudad.dispose();
    });
  }

  Future<void> _guardar(
    BuildContext ctx, {
    required GlobalKey<FormState> formKey,
    required bool   esEdicion,
    int?            id,
    required String nombre,
    required String nit,
    required String telefono,
    required String email,
    required String direccion,
    required String ciudad,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final data = {
      'nombre':    nombre.trim(),
      'nit':       nit.trim(),
      'telefono':  telefono.trim(),
      'email':     email.trim(),
      'direccion': direccion.trim(),
      'ciudad':    ciudad.trim(),
    };

    final prov = context.read<ProveedoresProvider>();
    final ok   = esEdicion
        ? await prov.editarProveedor(id!, data)
        : await prov.crearProveedor(data);

    if (!ctx.mounted) return;
    Navigator.pop(ctx);

    // ✅ FIX: verificar mounted del screen padre antes del SnackBar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        ok
            ? esEdicion
                ? 'Proveedor actualizado correctamente'
                : 'Proveedor creado correctamente'
            : 'Ocurrió un error, intenta de nuevo',
        style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: ok
          ? Colors.green.shade600 : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Confirmar eliminar ─────────────────────────────────

  void _confirmarEliminar(
      BuildContext context, Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_rounded,
              color: Colors.red.shade600, size: 22),
          const SizedBox(width: 10),
          Text('Desactivar proveedor',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade700),
            children: [
              const TextSpan(text: '¿Deseas desactivar el proveedor '),
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
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await context
                  .read<ProveedoresProvider>()
                  .eliminarProveedor(p['id']);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  ok ? 'Proveedor desactivado' : 'Error al desactivar',
                  style: GoogleFonts.poppins(color: Colors.white)),
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
            child: Text('Sí, desactivar',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────

  Widget _campo({
    required TextEditingController ctrl,
    required String                label,
    required IconData              icon,
    TextInputType?                 inputType,
    String? Function(String?)?     validator,
  }) =>
    TextFormField(
      controller:   ctrl,
      keyboardType: inputType,
      validator:    validator,
      style:        GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: GoogleFonts.poppins(fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled:     true,
        fillColor:  const Color(0xFFF4F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: Colors.red.shade400)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );

  Widget _estadoBadge(bool activo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: activo ? Colors.green.shade50 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: activo
              ? Colors.green.shade200
              : Colors.grey.shade300)),
    child: Text(
      activo ? 'Activo' : 'Inactivo',
      style: GoogleFonts.poppins(
        fontSize:   11,
        fontWeight: FontWeight.w600,
        color: activo
            ? Colors.green.shade700
            : Colors.grey.shade500)),
  );

  Widget _accionBtn({
    required IconData     icon,
    required Color        color,
    required String       tooltip,
    required VoidCallback onTap,
  }) =>
    Tooltip(
      message: tooltip,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
}