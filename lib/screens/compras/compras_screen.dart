import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/proveedores_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});
  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  static const _dark   = Color(0xFF1A1A2E);
  static const _accent = Color(Constants.primaryColor);

  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  void _cargar() {
    final auth = context.read<AuthProvider>();
    context.read<ProveedoresProvider>().cargarCompras(
      tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
      estado:   _filtroEstado,
    );
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProveedoresProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(children: [
        _buildHeader(prov, auth),
        Expanded(
          child: prov.cargandoCompras
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(prov, auth),
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────

  Widget _buildHeader(ProveedoresProvider prov, AuthProvider auth) =>
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shopping_cart_rounded,
              color: _accent, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Órdenes de compra',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.bold, color: _dark)),
          Text(auth.tiendaNombre,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade500)),
        ]),
        const Spacer(),
        // ── Filtro estado ─────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:        const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filtroEstado,
              hint: Text('Todos los estados',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade500)),
              style: GoogleFonts.poppins(
                  fontSize: 13, color: _dark),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18),
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
                      Icon(_iconEstado(e),
                          size: 14, color: _colorEstado(e)),
                      const SizedBox(width: 6),
                      Text(_labelEstado(e),
                          style: GoogleFonts.poppins(fontSize: 13)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _abrirFormularioCompra(context, auth),
          icon:  const Icon(Icons.add_rounded, size: 18),
          label: Text('Nueva orden',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
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

  // ── Body ───────────────────────────────────────────────

  Widget _buildBody(ProveedoresProvider prov, AuthProvider auth) =>
    SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpis(prov),
          const SizedBox(height: 16),
          _buildTabla(prov, auth),
        ],
      ),
    );

  // ── KPIs ───────────────────────────────────────────────

  Widget _buildKpis(ProveedoresProvider prov) {
    final pendientes = prov.compras
        .where((c) => c['estado'] == 'pendiente').length;
    final recibidas  = prov.compras
        .where((c) => c['estado'] == 'recibida').length;
    final canceladas = prov.compras
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
        valor: '\$${_fmt(totalInvertido)}',
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
            borderRadius: BorderRadius.circular(10),
          ),
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

  Widget _buildTabla(ProveedoresProvider prov, AuthProvider auth) {
    if (prov.compras.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Column(children: [
          Icon(Icons.shopping_cart_outlined,
              size: 52, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text(
            _filtroEstado != null
                ? 'Sin órdenes con estado "${_labelEstado(_filtroEstado!)}"'
                : 'No hay órdenes de compra registradas',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _abrirFormularioCompra(context, auth),
            icon:  const Icon(Icons.add_rounded, size: 16),
            label: Text('Crear primera orden',
                style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
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
              Text('Órdenes de compra',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14, color: _dark)),
              const Spacer(),
              Text('${prov.compras.length} registros',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade400)),
            ]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft:  Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(_dark),
                headingTextStyle: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 12),
                dataTextStyle:    GoogleFonts.poppins(fontSize: 12),
                columnSpacing:    20,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                dividerThickness: 0.5,
                columns: const [
                  DataColumn(label: Text('Orden')),
                  DataColumn(label: Text('Proveedor')),
                  DataColumn(label: Text('Empleado')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: prov.compras.map((c) {
                  final fecha = (c['fecha_orden']?.toString() ?? '')
                      .length >= 10
                      ? c['fecha_orden'].toString().substring(0, 10)
                      : '';
                  final esPendiente = c['estado'] == 'pendiente';
                  final esAdmin     = auth.rol == 'admin';

                  return DataRow(
                    color: WidgetStateProperty.resolveWith((s) {
                      if (c['estado'] == 'cancelada') {
                        return Colors.red.shade50;
                      }
                      if (c['estado'] == 'recibida') {
                        return Colors.green.shade50;
                      }
                      if (s.contains(WidgetState.hovered)) {
                        return const Color(0xFFF0F4FF);
                      }
                      return Colors.white;
                    }),
                    cells: [
                      // Número de orden
                      DataCell(Text(c['numero_orden'] ?? '',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: _accent, fontSize: 12))),
                      // Proveedor
                      DataCell(Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(child: Text(
                            ((c['proveedor_nombre'] ?? 'P') as String)
                                .substring(0, 1).toUpperCase(),
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade600),
                          )),
                        ),
                        const SizedBox(width: 8),
                        Text(c['proveedor_nombre'] ?? '',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500)),
                      ])),
                      // Empleado
                      DataCell(Text(c['empleado_nombre'] ?? '—')),
                      // Fecha
                      DataCell(Text(fecha)),
                      // Total
                      DataCell(Text(
                        '\$${_fmt(double.tryParse(c['total'].toString()) ?? 0)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600))),
                      // Estado
                      DataCell(_estadoBadge(c['estado'] ?? '')),
                      // Acciones
                      DataCell(Row(children: [
                        // Ver detalle
                        _accionBtn(
                          icon:    Icons.visibility_rounded,
                          color:   Colors.blue.shade600,
                          tooltip: 'Ver detalle',
                          onTap:   () => _verDetalle(context, c['id']),
                        ),
                        // Recibir (solo pendiente)
                        if (esPendiente) ...[
                          const SizedBox(width: 6),
                          _accionBtn(
                            icon:    Icons.move_to_inbox_rounded,
                            color:   Colors.green.shade600,
                            tooltip: 'Recibir orden',
                            onTap:   () => _confirmarRecibir(
                                context, c),
                          ),
                        ],
                        // Cancelar (solo admin y pendiente)
                        if (esPendiente && esAdmin) ...[
                          const SizedBox(width: 6),
                          _accionBtn(
                            icon:    Icons.cancel_rounded,
                            color:   Colors.red.shade600,
                            tooltip: 'Cancelar orden',
                            onTap:   () => _confirmarCancelar(
                                context, c),
                          ),
                        ],
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

  // ── Detalle compra ─────────────────────────────────────

  Future<void> _verDetalle(BuildContext context, int id) async {
    final detalle = await context
        .read<ProveedoresProvider>()
        .obtenerCompra(id);
    if (!context.mounted || detalle == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: _accent),
          const SizedBox(width: 10),
          Text(detalle['numero_orden'] ?? '',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          const Spacer(),
          _estadoBadge(detalle['estado'] ?? ''),
        ]),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detalleRow(Icons.store_rounded,    'Proveedor',
                    detalle['proveedor_nombre'] ?? ''),
                _detalleRow(Icons.business_rounded, 'Tienda',
                    detalle['tienda_nombre'] ?? ''),
                _detalleRow(Icons.badge_rounded,    'Empleado',
                    detalle['empleado_nombre'] ?? ''),
                _detalleRow(Icons.calendar_today_rounded, 'Fecha orden',
                    (detalle['fecha_orden']?.toString() ?? '')
                        .substring(0, 10)),
                if (detalle['fecha_recepcion'] != null)
                  _detalleRow(Icons.check_circle_rounded, 'Fecha recepción',
                      detalle['fecha_recepcion'].toString().substring(0, 10),
                      color: Colors.green.shade600),
                if ((detalle['observaciones'] ?? '').isNotEmpty)
                  _detalleRow(Icons.notes_rounded, 'Observaciones',
                      detalle['observaciones']),
                const Divider(height: 24),
                Text('Productos',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                ...(detalle['detalles'] as List? ?? []).map((item) =>
                  Container(
                    margin:  const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(
                        item['producto_nombre'] ?? '',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500, fontSize: 13))),
                      Text(
                        'x${double.tryParse(item['cantidad'].toString())?.toStringAsFixed(0) ?? 0}  ',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade500)),
                      Text(
                        '\$${_fmt(double.tryParse(item['precio_unitario'].toString()) ?? 0)} c/u',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(width: 12),
                      Text(
                        '\$${_fmt(double.tryParse(item['subtotal'].toString()) ?? 0)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13, color: _accent)),
                    ]),
                  ),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Total: ',
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey.shade600)),
                    Text(
                      '\$${_fmt(double.tryParse(detalle['total'].toString()) ?? 0)}',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: _accent)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  // ── Formulario nueva orden ─────────────────────────────

  void _abrirFormularioCompra(BuildContext context, AuthProvider auth) async {
  final prov = context.read<ProveedoresProvider>();

  await Future.wait([
    prov.cargarProveedoresSimple(),
    prov.cargarTiendasSimple(),
    prov.cargarCategoriasSimple(),
  ]);
  if (!context.mounted) return;

  final proveedores = prov.proveedoresSimple;
  final tiendas     = prov.tiendasSimple;

  int? proveedorId;
  int? tiendaSeleccionada = auth.rol != 'admin'
      ? (auth.tiendaId == 0 ? null : auth.tiendaId)
      : null;

  final obsCtrl  = TextEditingController();
  final detalles = <Map<String, dynamic>>[];
  final formKey  = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.shopping_cart_rounded, color: _accent),
          const SizedBox(width: 10),
          Text('Nueva orden de compra',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: SizedBox(
          width: 600,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Tienda (solo admin) ──────────────
                  if (auth.rol == 'admin') ...[
                    Text('Tienda *',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: tiendaSeleccionada,
                      validator: (v) =>
                          v == null ? 'Selecciona una tienda' : null,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: _dark),
                      decoration: _dropdownDecoration(
                          Icons.store_rounded),
                      hint: Text('Seleccionar tienda',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade400)),
                      items: tiendas.map((t) =>
                        DropdownMenuItem<int>(
                          value: t['id'] as int,
                          child: Text(t['nombre'],
                              style: GoogleFonts.poppins(
                                  fontSize: 13)),
                        ),
                      ).toList(),
                      onChanged: (v) =>
                          setStateDialog(() => tiendaSeleccionada = v),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Proveedor ────────────────────────
                  Text('Proveedor *',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: proveedorId,
                    validator: (v) =>
                        v == null ? 'Selecciona un proveedor' : null,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: _dark),
                    decoration: _dropdownDecoration(
                        Icons.local_shipping_rounded),
                    hint: Text('Seleccionar proveedor',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade400)),
                    items: proveedores.map((p) =>
                      DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text(
                          '${p['nombre']}${p['nit'] != null ? ' — ${p['nit']}' : ''}',
                          style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                    ).toList(),
                    onChanged: (v) =>
                        setStateDialog(() => proveedorId = v),
                  ),
                  const SizedBox(height: 14),

                  // ── Observaciones ────────────────────
                  Text('Observaciones',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: obsCtrl,
                    maxLines:   2,
                    style:      GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Notas adicionales (opcional)',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade400),
                      filled:    true,
                      fillColor: const Color(0xFFF4F6FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: _accent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Productos ────────────────────────
                  Row(children: [
                    Text('Productos',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14, color: _dark)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setStateDialog(() =>
                          detalles.add({
                            'producto':        null,
                            'nombre':          '',
                            'cantidad':        '',
                            'precio_unitario': '',
                            'categoria_nombre':  '', // ← nuevo
                          })),
                      icon:  const Icon(Icons.add_rounded, size: 16),
                      label: Text('Agregar producto',
                          style: GoogleFonts.poppins(fontSize: 12)),
                      style: TextButton.styleFrom(
                          foregroundColor: _accent),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  if (detalles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(child: Text(
                        'Agrega al menos un producto',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade400))),
                    )
                  else
                    ...detalles.asMap().entries.map((e) =>
                      _FilaProducto(
                        key:      ValueKey(e.key),
                        index:    e.key,
                        detalle:  e.value,
                        tiendaId: tiendaSeleccionada,
                        onRemove: () => setStateDialog(() =>
                            detalles.removeAt(e.key)),
                        onChanged: (key, val) => setStateDialog(() =>
                            detalles[e.key][key] = val),
                      ),
                    ),

                  // ── Total calculado ──────────────────
                  if (detalles.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Total estimado: ',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600)),
                        Text(
                          '\$${_fmt(_calcularTotal(detalles))}',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _accent)),
                      ],
                    ),
                  ],
                ],
              ),
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
              onPressed: p.guardando ||
                      detalles.isEmpty ||
                      tiendaSeleccionada == null
                  ? null
                  : () => _crearOrden(
                        ctx,
                        formKey:     formKey,
                        proveedorId: proveedorId,
                        tiendaId:    tiendaSeleccionada!,
                        obs:         obsCtrl.text,
                        detalles:    detalles,
                      ),
              icon: p.guardando
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text('Crear orden',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
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
    ),
  );
}

Future<void> _crearOrden(
  BuildContext ctx, {
  required GlobalKey<FormState>       formKey,
  required int?                       proveedorId,
  required int                        tiendaId,
  required String                     obs,
  required List<Map<String, dynamic>> detalles,
}) async {
  if (!formKey.currentState!.validate()) return;
  if (proveedorId == null) return;

  final data = {
    'tienda':        tiendaId,
    'proveedor':     proveedorId,
    'observaciones': obs.trim(),
    'detalles': detalles.map((d) => {
      'producto':        d['producto'],
      'nombre_libre':    d['nombre'] ?? '',    // ← nuevo
      'categoria_nombre_input': d['categoria_nombre'] ?? '',       // ← nuevo
      'cantidad':        double.tryParse(d['cantidad'].toString()) ?? 0,
      'precio_unitario': double.tryParse(
          d['precio_unitario'].toString()) ?? 0,
    }).toList(),
  };

  final ok = await context
      .read<ProveedoresProvider>()
      .crearCompra(data);

  if (!ctx.mounted) return;
  Navigator.pop(ctx);

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
      ok ? 'Orden creada correctamente' : 'Error al crear la orden',
      style: GoogleFonts.poppins(color: Colors.white)),
    backgroundColor: ok
        ? Colors.green.shade600
        : Colors.red.shade600,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(16),
  ));
}


void _mostrarResultadoRecepcion(BuildContext context, Map<String, dynamic> data) {
  final productos = (data['productos'] as List?) ?? [];

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            data['detail'] ?? 'Orden recibida',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ]),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tienda
              Row(children: [
                Icon(Icons.store_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  data['tienda'] ?? '',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                'Productos actualizados:',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),

              // Lista de productos
              ...productos.map((p) {
                final esNuevo = p['es_nuevo'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: esNuevo ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: esNuevo ? Colors.orange.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Row(children: [
                    // Ícono nuevo / existente
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: esNuevo ? Colors.orange.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        esNuevo ? Icons.add_box_rounded : Icons.inventory_2_rounded,
                        size: 16,
                        color: esNuevo ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre + badge NUEVO
                          Row(children: [
                            Expanded(
                              child: Text(
                                p['producto'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                            if (esNuevo)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'NUEVO',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9, fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 4),

                          // Código de barras + categoría
                          Row(children: [
                            Icon(Icons.qr_code_rounded, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              p['codigo_barras'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 11, fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700),
                            ),
                            if (p['categoria'] != null) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.category_rounded, size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                p['categoria'],
                                style: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 3),

                          // Cantidad + stock
                          Text(
                            '+${(p['cantidad_recibida'] as num?)?.toStringAsFixed(0) ?? '0'} uds  →  Stock: ${(p['stock_actual'] as num?)?.toStringAsFixed(0) ?? '0'}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: esNuevo
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('Entendido', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
// ── Confirmar recibir ──────────────────────────────────

void _confirmarRecibir(
    BuildContext context, Map<String, dynamic> c) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(Icons.move_to_inbox_rounded,
            color: Colors.green.shade600, size: 22),
        const SizedBox(width: 10),
        Text('Recibir orden',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      content: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
              fontSize: 13, color: Colors.grey.shade700),
          children: [
            const TextSpan(
                text: '¿Confirmas la recepción de la orden '),
            TextSpan(
              text: c['numero_orden'],
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(
                text: '? Esto actualizará el inventario automáticamente.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade600))),
        ElevatedButton.icon(
            onPressed: () async {
                Navigator.pop(context);
                final data = await context
                    .read<ProveedoresProvider>()
                    .recibirCompra(c['id']);

                if (!mounted) return;

                if (data != null) {
                  _mostrarResultadoRecepcion(context, data);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error al recibir la orden',
                        style: GoogleFonts.poppins(color: Colors.white)),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(16),
                  ));
                }
              },
          icon:  const Icon(Icons.check_rounded, size: 16),
          label: Text('Sí, recibir',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
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

// ── Confirmar cancelar ─────────────────────────────────

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
                text: '¿Seguro que deseas cancelar la orden '),
            TextSpan(
              text: c['numero_orden'],
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: '? Esta acción no se puede deshacer.'),
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                ok
                    ? 'Orden cancelada'
                    : 'Error al cancelar la orden',
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

// ── Helpers ────────────────────────────────────────────

double _calcularTotal(List<Map<String, dynamic>> detalles) =>
    detalles.fold(0.0, (sum, d) =>
        sum +
        (double.tryParse(d['cantidad']?.toString() ?? '0') ?? 0) *
        (double.tryParse(
            d['precio_unitario']?.toString() ?? '0') ?? 0));

String _fmt(double v) => v.toStringAsFixed(0)
    .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

Color _colorEstado(String e) {
  switch (e) {
    case 'pendiente': return Colors.orange.shade600;
    case 'recibida':  return Colors.green.shade600;
    case 'cancelada': return Colors.red.shade600;
    default:          return Colors.grey.shade600;
  }
}

IconData _iconEstado(String e) {
  switch (e) {
    case 'pendiente': return Icons.pending_actions_rounded;
    case 'recibida':  return Icons.check_circle_rounded;
    case 'cancelada': return Icons.cancel_rounded;
    default:          return Icons.help_rounded;
  }
}

String _labelEstado(String e) {
  switch (e) {
    case 'pendiente': return 'Pendiente';
    case 'recibida':  return 'Recibida';
    case 'cancelada': return 'Cancelada';
    default:          return e;
  }
}

Widget _estadoBadge(String estado) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: _colorEstado(estado).withOpacity(0.1),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
        color: _colorEstado(estado).withOpacity(0.3)),
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(_iconEstado(estado),
        size: 11, color: _colorEstado(estado)),
    const SizedBox(width: 4),
    Text(_labelEstado(estado),
      style: GoogleFonts.poppins(
        fontSize:   11,
        fontWeight: FontWeight.w600,
        color:      _colorEstado(estado))),
  ]),
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
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    ),
  );

Widget _detalleRow(IconData icon, String label, String valor,
    {Color? color}) =>
  Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 15, color: Colors.grey.shade400),
      const SizedBox(width: 8),
      Text('$label: ',
        style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.grey.shade600)),
      Expanded(child: Text(valor,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: color ?? _dark))),
    ]),
  );

InputDecoration _dropdownDecoration(IconData icon) => InputDecoration(
  prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
  filled:     true,
  fillColor:  const Color(0xFFF4F6FA),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide:   const BorderSide(color: _accent, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(
      horizontal: 4, vertical: 12),
);

InputDecoration _miniInputDecoration(String label) => InputDecoration(
  labelText:  label,
  labelStyle: GoogleFonts.poppins(fontSize: 11),
  filled:     true,
  fillColor:  Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide:   const BorderSide(color: _accent, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(
      horizontal: 10, vertical: 10),
  isDense: true,
);

// ── Widget separado para cada fila de producto ────────
}

// ═══════════════════════════════════════════════════════
// _FilaProducto — CON CATEGORÍA INTEGRADA
// ═══════════════════════════════════════════════════════
class _FilaProducto extends StatefulWidget {
  final int                            index;
  final Map<String, dynamic>           detalle;
  final int?                           tiendaId;
  final VoidCallback                   onRemove;
  final void Function(String, dynamic) onChanged;

  const _FilaProducto({
    super.key,
    required this.index,
    required this.detalle,
    required this.tiendaId,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_FilaProducto> createState() => _FilaProductoState();
}

class _FilaProductoState extends State<_FilaProducto> {
  static const _dark   = Color(0xFF1A1A2E);
  static const _accent = Color(Constants.primaryColor);

  late final TextEditingController _searchCtrl;
  late final TextEditingController _cantCtrl;
  late final TextEditingController _precioCtrl;

  List<Map<String, dynamic>> _sugerencias = [];
  bool _buscando  = false;
  bool _modoLibre = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
        text: widget.detalle['nombre']?.toString() ?? '');
    _cantCtrl   = TextEditingController(
        text: widget.detalle['cantidad']?.toString() ?? '');
    _precioCtrl = TextEditingController(
        text: widget.detalle['precio_unitario']?.toString() ?? '');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    if (q.length < 2) {
      setState(() => _sugerencias = []);
      return;
    }
    setState(() => _buscando = true);
    final res = await context
        .read<ProveedoresProvider>()
        .buscarProductos(q: q, tiendaId: widget.tiendaId);
    setState(() {
      _sugerencias = res;
      _buscando    = false;
    });
  }

  double get _subtotal =>
      (double.tryParse(_cantCtrl.text)   ?? 0) *
      (double.tryParse(_precioCtrl.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Toggle modo ──────────────────────────────
          Row(children: [
            Text('Producto ${widget.index + 1}',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _modoLibre = !_modoLibre;
                _searchCtrl.clear();
                widget.onChanged('producto',         null);
                widget.onChanged('nombre',           '');
                widget.onChanged('categoria_nombre', '');
                _sugerencias = [];
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _modoLibre
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _modoLibre
                        ? Colors.orange.shade300
                        : Colors.blue.shade300,
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _modoLibre
                        ? Icons.edit_rounded
                        : Icons.search_rounded,
                    size: 12,
                    color: _modoLibre
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _modoLibre ? 'Producto nuevo' : 'Buscar existente',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _modoLibre
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.swap_horiz_rounded,
                      size: 12,
                      color: _modoLibre
                          ? Colors.orange.shade400
                          : Colors.blue.shade400),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // ── Fila principal de campos ──────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Campo nombre / búsqueda + categoría
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre o búsqueda
                  TextFormField(
                    controller: _searchCtrl,
                    style: GoogleFonts.poppins(fontSize: 12),
                    validator: (v) {
                      if (_modoLibre) {
                        return (v == null || v.isEmpty)
                            ? 'Escribe el nombre' : null;
                      }
                      return widget.detalle['producto'] == null
                          ? 'Selecciona un producto' : null;
                    },
                    onChanged: (v) {
                      widget.onChanged('nombre', v);
                      if (!_modoLibre) {
                        widget.onChanged('producto', null);
                        _buscar(v);
                      }
                    },
                    decoration: _modoLibre
                        ? _miniInputDecoration('Nombre del producto *').copyWith(
                            prefixIcon: Icon(Icons.edit_rounded,
                                size: 16, color: Colors.orange.shade400))
                        : _miniInputDecoration('Buscar producto *').copyWith(
                            prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: Colors.grey),
                            suffixIcon: _buscando
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)))
                                : widget.detalle['producto'] != null
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: Colors.green.shade500)
                                    : null),
                  ),

                  // Sugerencias (solo modo búsqueda)
                  if (!_modoLibre && _sugerencias.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: _sugerencias.map((p) {
                          final alerta = p['alerta_stock'] ?? 'ok';
                          final stock  = p['stock_actual']  ?? 0;
                          final alertaColor = alerta == 'agotado'
                              ? Colors.red.shade600
                              : alerta == 'bajo'
                                  ? Colors.orange.shade600
                                  : Colors.green.shade600;
                          return InkWell(
                            onTap: () {
                              _searchCtrl.text = p['nombre'];
                              widget.onChanged('producto', p['id']);
                              widget.onChanged('nombre',   p['nombre']);
                              setState(() => _sugerencias = []);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(children: [
                                Expanded(
                                  child: Text(p['nombre'],
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                ),
                                if (widget.tiendaId != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: alertaColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Stock: $stock',
                                      style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: alertaColor)),
                                  ),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // ── Categoría (solo modo libre) ───────  ← FIX: _modoLibre
                  if (_modoLibre) ...[
                    const SizedBox(height: 6),
                    Consumer<ProveedoresProvider>(
                      builder: (_, prov, __) {
                        final cats = prov.categoriasSimple;
                        return Autocomplete<String>(
                          initialValue: TextEditingValue(
                            text: widget.detalle['categoria_nombre'] ?? '',
                          ),
                          optionsBuilder: (textEditingValue) {
                            final input = textEditingValue.text.toLowerCase();
                            final nombres =
                                cats.map((c) => c['nombre'] as String);
                            if (input.isEmpty) return nombres;
                            return nombres.where(
                                (n) => n.toLowerCase().contains(input));
                          },
                          onSelected: (value) {
                            widget.onChanged('categoria_nombre', value);
                            setState(() {});
                          },
                          fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              final val =
                                  widget.detalle['categoria_nombre'] ?? '';
                              if (ctrl.text != val) ctrl.text = val;
                            });
                            return TextFormField(
                              controller: ctrl,
                              focusNode:  focusNode,
                              style: GoogleFonts.poppins(fontSize: 12),
                              onChanged: (v) =>
                                  widget.onChanged('categoria_nombre', v),
                              // ← FIX: _miniInputDecoration con guión bajo
                              decoration: _miniInputDecoration(
                                      'Categoría (opcional)')
                                  .copyWith(
                                prefixIcon: Icon(Icons.category_rounded,
                                    size: 16,
                                    color: Colors.orange.shade400),
                                hintText: 'Escribe o selecciona...',
                                hintStyle: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade400),
                              ),
                            );
                          },
                          optionsViewBuilder: (ctx, onSelected, options) =>
                              Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(10),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                    maxHeight: 180, maxWidth: 260),
                                child: ListView.builder(
                                  padding:    EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount:  options.length,
                                  itemBuilder: (_, i) {
                                    final opt = options.elementAt(i);
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                          Icons.category_rounded,
                                          size: 14,
                                          color: Colors.orange.shade400),
                                      title: Text(opt,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12)),
                                      onTap: () => onSelected(opt),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Cantidad
            Expanded(
              child: TextFormField(
                controller:   _cantCtrl,
                style:        GoogleFonts.poppins(fontSize: 12),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v) == null) return 'Inválido';
                  return null;
                },
                onChanged: (v) {
                  widget.onChanged('cantidad', v);
                  setState(() {});
                },
                decoration: _miniInputDecoration('Cantidad *'),
              ),
            ),
            const SizedBox(width: 8),

            // Precio unitario
            Expanded(
              child: TextFormField(
                controller:   _precioCtrl,
                style:        GoogleFonts.poppins(fontSize: 12),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v) == null) return 'Inválido';
                  return null;
                },
                onChanged: (v) {
                  widget.onChanged('precio_unitario', v);
                  setState(() {});
                },
                decoration: _miniInputDecoration('Precio unit. *'),
              ),
            ),
            const SizedBox(width: 8),

            // Subtotal
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Subtotal',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.grey.shade500)),
                  Text('\$${_fmt(_subtotal)}',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _accent)),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Eliminar
            InkWell(
              onTap:        widget.onRemove,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:        Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.red.shade400),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  InputDecoration _miniInputDecoration(String label) =>
      InputDecoration(
        labelText:  label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 11, color: Colors.grey.shade500),
        filled:    true,
        fillColor: Colors.white,
        isDense:   true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
      );

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.');
}