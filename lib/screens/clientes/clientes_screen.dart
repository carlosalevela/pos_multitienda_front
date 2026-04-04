import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/cliente_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/cliente.dart';
import '../../models/separado.dart';
import '../../core/constants.dart';
import 'package:flutter/services.dart';
import '../../models/alerta_separado.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _busquedaCtrl = TextEditingController();

  @override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final auth = context.read<AuthProvider>();
    final prov = context.read<ClienteProvider>();
    prov.cargarClientes();
    prov.cargarAlertas(                                    // ✅ nuevo
      tiendaId: auth.rol == 'cajero' ? auth.tiendaId : null,
    );
  });
}

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(Constants.backgroundColor),
      body: Column(children: [
        // ── Header ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          color: Colors.white,
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(Constants.primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.people_alt_rounded,
                    color: Color(Constants.primaryColor), size: 26),
              ),
              const SizedBox(width: 14),
              Text('Clientes',
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A2E))),
              const Spacer(),
                ElevatedButton.icon(
                  icon:  const Icon(Icons.person_add_rounded, size: 18),
                  label: Text('Nuevo cliente',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onPressed: () => _mostrarFormCliente(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(Constants.primaryColor),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor:       const Color(Constants.primaryColor),
              unselectedLabelColor: Colors.grey,
              indicatorColor:   const Color(Constants.primaryColor),
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                tabs: [
  const Tab(icon: Icon(Icons.people_rounded), text: 'Clientes'),
  Tab(
    text: 'Separados',
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.bookmark_rounded),
        if (context.watch<ClienteProvider>().totalAlertas > 0)
          Positioned(
            top: -4, right: -8,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: Text(
                '${context.watch<ClienteProvider>().totalAlertas}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    ),
  ),
],
            ),
          ]),
        ),

        // ── Tabs ─────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TabClientes(busquedaCtrl: _busquedaCtrl),
              const _TabSeparados(),
            ],
          ),
        ),
      ]),
    );
  }

  void _mostrarFormCliente(BuildContext context, {Cliente? cliente}) {
    showDialog(
      context: context,
      builder: (_) => _DialogCliente(cliente: cliente),
    );
  }
}

// ══════════════════════════════════════════════════════
//  TAB CLIENTES
// ══════════════════════════════════════════════════════
class _TabClientes extends StatelessWidget {
  final TextEditingController busquedaCtrl;
  const _TabClientes({required this.busquedaCtrl});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ClienteProvider>();
    final auth = context.watch<AuthProvider>();

    return Column(children: [
      // Barra de búsqueda
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: busquedaCtrl,
          onChanged: (v) => prov.cargarClientes(q: v),
          decoration: InputDecoration(
            hintText:     'Buscar por nombre, cédula o teléfono...',
            hintStyle:    GoogleFonts.poppins(color: Colors.grey.shade400),
            prefixIcon:   const Icon(Icons.search_rounded),
            filled:       true,
            fillColor:    Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(Constants.primaryColor))),
          ),
        ),
      ),

      // KPIs
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _kpiCard(Icons.people_rounded,
              '${prov.clientes.length}', 'Clientes activos',
              Colors.blue.shade700, Colors.blue.shade50),
        ]),
      ),
      const SizedBox(height: 12),

      // Lista
      Expanded(child: _buildLista(context, prov, auth)),
    ]);
  }

  Widget _buildLista(BuildContext context,
      ClienteProvider prov, AuthProvider auth) {
    if (prov.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.clientes.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin clientes registrados',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Agrega el primer cliente con el botón de arriba',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade300, fontSize: 13)),
        ],
      ));
    }

    return ListView.builder(
      padding:   const EdgeInsets.symmetric(horizontal: 16),
      itemCount: prov.clientes.length,
      itemBuilder: (_, i) {
        final c = prov.clientes[i];
        return Container(
          margin:  const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            // Avatar inicial
            CircleAvatar(
              radius:          22,
              backgroundColor: const Color(Constants.primaryColor)
                  .withOpacity(0.12),
              child: Text(
                c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                    color:      const Color(Constants.primaryColor),
                    fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.nombreCompleto,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Row(children: [
                  if (c.cedulaNit != null && c.cedulaNit!.isNotEmpty) ...[
                    Icon(Icons.badge_rounded,
                        size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(c.cedulaNit!,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(width: 12),
                  ],
                  if (c.telefono.isNotEmpty) ...[
                    Icon(Icons.phone_rounded,
                        size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(c.telefono,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ]),
                if (c.email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Icon(Icons.email_rounded,
                          size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(c.email,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
              ],
            )),

            // Acciones
            if (auth.rol != 'cajero')
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      color: Colors.orange, size: 20),
                  tooltip: 'Editar',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _DialogCliente(cliente: c),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_off_rounded,
                      color: Colors.red, size: 20),
                  tooltip: 'Desactivar',
                  onPressed: () => _confirmarDesactivar(context, prov, c),
                ),
              ]),
          ]),
        );
      },
    );
  }

  void _confirmarDesactivar(BuildContext context,
      ClienteProvider prov, Cliente c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('¿Desactivar cliente?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Se desactivará a ${c.nombreCompleto}. '
          'Puedes reactivarlo desde el backend.',
          style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              await prov.desactivarCliente(c.id);
            },
            child: Text('Desactivar', style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  Widget _kpiCard(IconData icon, String valor,
      String label, Color color, Color bg) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valor, style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: GoogleFonts.poppins(
              fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ]),
    );
}

// ══════════════════════════════════════════════════════
//  TAB SEPARADOS (placeholder — lo desarrollamos después)
// ══════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════
//  TAB SEPARADOS
// ══════════════════════════════════════════════════════
class _TabSeparados extends StatefulWidget {
  const _TabSeparados();

  @override
  State<_TabSeparados> createState() => _TabSeparadosState();
}

class _TabSeparadosState extends State<_TabSeparados> {
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClienteProvider>().cargarSeparados();
    });
  }

  Widget _buildBannerAlertas(BuildContext context) {
  final prov      = context.watch<ClienteProvider>();
  final vencidos  = prov.vencidos;
  final porVencer = prov.porVencer;

  if (vencidos.isEmpty && porVencer.isEmpty) return const SizedBox.shrink();

  return Column(children: [
    // ── Vencidos ──────────────────────────────────
    if (vencidos.isNotEmpty)
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.warning_rounded,
                  color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Text('${vencidos.length} separado(s) vencido(s)',
                style: GoogleFonts.poppins(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ...vencidos.map((s) => _filaSeparadoAlerta(s)),
          ],
        ),
      ),

    // ── Por vencer ────────────────────────────────
    if (porVencer.isNotEmpty)
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.schedule_rounded,
                  color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Text('${porVencer.length} separado(s) por vencer',
                style: GoogleFonts.poppins(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ...porVencer.map((s) => _filaSeparadoAlerta(s)),
          ],
        ),
      ),
  ]);
}

Widget _filaSeparadoAlerta(AlertaSeparado s) {
  final esVencido = s.esVencido;
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.cliente,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
            Text(s.etiquetaDias,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: esVencido
                      ? Colors.red.shade600
                      : Colors.orange.shade600)),
          ],
        ),
      ),
      Text('\$${s.saldoPendiente.toStringAsFixed(0)}',
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.bold,
            color: esVencido
                ? Colors.red.shade700
                : Colors.orange.shade700)),
    ]),
  );
}

  @override
Widget build(BuildContext context) {
  final prov = context.watch<ClienteProvider>();
  final auth = context.watch<AuthProvider>();

  final lista = _filtroEstado == 'todos'
      ? prov.separados
      : prov.separados.where((s) => s.estado == _filtroEstado).toList();

  return Column(children: [
    // ── Banners de alertas ────────────────────── ✅ AGREGA ESTO
    _buildBannerAlertas(context),

    // ── Filtros de estado ─────────────────────────────
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        _filtroChip('todos',     'Todos',      Icons.list_rounded),
        const SizedBox(width: 8),
        _filtroChip('activo',    'Activos',    Icons.pending_rounded),
        const SizedBox(width: 8),
        _filtroChip('pagado',    'Pagados',    Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _filtroChip('cancelado', 'Cancelados', Icons.cancel_rounded),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            Icon(Icons.bookmark_rounded,
                size: 14, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text(
              '${prov.separados.where((s) => s.esActivo).length} activos',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700),
            ),
          ]),
        ),
      ]),
    ),
    const SizedBox(height: 12),

    // ── Lista ─────────────────────────────────────────
    Expanded(child: _buildLista(context, lista, prov, auth)),
  ]);
}

  Widget _buildLista(BuildContext context, List<Separado> lista,
      ClienteProvider prov, AuthProvider auth) {
    if (prov.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lista.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_outline_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No hay separados',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Los separados se crean desde el POS al momento de cobrar',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade300, fontSize: 13)),
        ],
      ));
    }

    return ListView.builder(
      padding:   const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: lista.length,
      itemBuilder: (_, i) => _SeparadoCard(
        separado: lista[i],
        auth:     auth,
        prov:     prov,
      ),
    );
  }

  Widget _filtroChip(String value, String label, IconData icon) {
    final selected = _filtroEstado == value;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(Constants.primaryColor)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              size: 14,
              color: selected ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label,
            style: GoogleFonts.poppins(
              fontSize:   12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey.shade600,
            )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  CARD DE SEPARADO
// ══════════════════════════════════════════════════════
class _SeparadoCard extends StatelessWidget {
  final Separado       separado;
  final AuthProvider   auth;
  final ClienteProvider prov;

  const _SeparadoCard({
    required this.separado,
    required this.auth,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final colorEstado = _colorEstado(separado.estado);

    return GestureDetector(
      onTap: () => _abrirDetalle(context),
      child: Container(
        margin:  const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Fila principal
          Row(children: [
            // Avatar cliente
            CircleAvatar(
              radius:          22,
              backgroundColor: colorEstado.withOpacity(0.12),
              child: Text(
                separado.clienteNombre.isNotEmpty
                    ? separado.clienteNombre[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                    color: colorEstado,
                    fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(separado.clienteNombre,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 8),
                  _badgeEstado(separado.estado),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.store_rounded,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(separado.tiendaNombre,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500)),
                  if (separado.fechaLimite != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('Límite: ${_formatFecha(separado.fechaLimite!)}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ]),
              ],
            )),
            // Total
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${separado.total.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16,
                    color: const Color(0xFF1A1A2E))),
              Text('Saldo: \$${separado.saldoPendiente.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: separado.esPagado
                        ? Colors.green : Colors.orange.shade700)),
            ]),
          ]),

          // Barra de progreso
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:            separado.progreso,
                backgroundColor:  Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(colorEstado),
                minHeight: 6,
              ),
            )),
            const SizedBox(width: 10),
            Text('${(separado.progreso * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: colorEstado)),
          ]),

          // Botones de acción
          const SizedBox(height: 12),
          Row(children: [
            // Abonar — solo cajero y separado activo
            if (auth.rol == 'cajero' && separado.esActivo)
              Expanded(child: _actionBtn(
                '💵 Abonar', Colors.green,
                () => _mostrarAbonar(context))),
            if (auth.rol == 'cajero' && separado.esActivo)
              const SizedBox(width: 8),

            // Cancelar — admin/supervisor y separado activo
            if (['admin', 'supervisor'].contains(auth.rol) && separado.esActivo)
              Expanded(child: _actionBtn(
                'Cancelar', Colors.red,
                () => _confirmarCancelar(context))),
            if (['admin', 'supervisor'].contains(auth.rol) && separado.esActivo)
              const SizedBox(width: 8),

            // Ver detalle — siempre
            Expanded(child: _actionBtn(
              '📋 Ver detalle', const Color(Constants.primaryColor),
              () => _abrirDetalle(context))),
          ]),
        ]),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: color))),
      ),
    );

  Widget _badgeEstado(String estado) {
    final color = _colorEstado(estado);
    final label = estado[0].toUpperCase() + estado.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pagado':    return Colors.green.shade600;
      case 'cancelado': return Colors.red.shade400;
      default:          return Colors.orange.shade600; // activo
    }
  }

  String _formatFecha(String fecha) {
    try {
      final d = DateTime.parse(fecha);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return fecha; }
  }

  // ── Abonar dialog ────────────────────────────────────
  void _mostrarAbonar(BuildContext context) {
    final montoCtrl = TextEditingController();
    String metodoPago = 'efectivo';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.payments_rounded,
                color: Color(Constants.primaryColor)),
            const SizedBox(width: 8),
            Text('Registrar abono',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          content: SizedBox(width: 380, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info separado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saldo pendiente',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.orange.shade700)),
                        Text('\$${separado.saldoPendiente.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 18,
                              color: Colors.orange.shade700)),
                      ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Abonado',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.green.shade700)),
                        Text('\$${separado.abonoAcumulado.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 18,
                              color: Colors.green.shade700)),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Monto
              Text('Monto a abonar',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller:   montoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  hintText:   'Ej: 50000',
                  filled:     true,
                  fillColor:  Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(Constants.primaryColor))),
                ),
              ),
              const SizedBox(height: 14),

              // Método de pago
              Text('Método de pago',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                _metodoPagoChip('efectivo', '💵 Efectivo',
                    metodoPago, (v) => setStateDialog(() => metodoPago = v)),
                const SizedBox(width: 8),
                _metodoPagoChip('transferencia', '📲 Transferencia',
                    metodoPago, (v) => setStateDialog(() => metodoPago = v)),
              ]),
            ],
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.poppins())),
            ElevatedButton.icon(
              icon:  const Icon(Icons.check_rounded, size: 18),
              label: Text('Confirmar abono',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text) ?? 0;
                if (monto <= 0) return;
                if (monto > separado.saldoPendiente) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('El monto no puede superar el saldo pendiente',
                        style: GoogleFonts.poppins()),
                    backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx);
                final ok = await prov.abonarSeparado(
                    separado.id, monto, metodoPago);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('✅ Abono registrado correctamente',
                        style: GoogleFonts.poppins()),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metodoPagoChip(String value, String label,
      String current, Function(String) onSelect) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        sel ? const Color(Constants.primaryColor) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade300),
        ),
        child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  // ── Cancelar dialog ──────────────────────────────────
  void _confirmarCancelar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('¿Cancelar separado?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 48),
          const SizedBox(height: 12),
          Text(
            'Se cancelará el separado de ${separado.clienteNombre}.\n'
            'El stock de los productos será restaurado automáticamente.',
            style: GoogleFonts.poppins(fontSize: 13),
            textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No cancelar', style: GoogleFonts.poppins())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await prov.cancelarSeparado(separado.id);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ Separado cancelado. Stock restaurado.',
                      style: GoogleFonts.poppins()),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating));
              }
            },
            child: Text('Cancelar separado', style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  // ── Detalle dialog ───────────────────────────────────
  void _abrirDetalle(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DialogDetalleSeparado(separado: separado),
    );
  }
}

// ══════════════════════════════════════════════════════
//  DIALOG DETALLE SEPARADO
// ══════════════════════════════════════════════════════
class _DialogDetalleSeparado extends StatelessWidget {
  final Separado separado;
  const _DialogDetalleSeparado({required this.separado});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              const Icon(Icons.bookmark_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Separado — ${separado.clienteNombre}',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(separado.tiendaNombre,
                    style: GoogleFonts.poppins(
                        color: Colors.white60, fontSize: 12)),
                ],
              )),
              _badgeEstado(separado.estado),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            ]),
          ),

          // Cuerpo scrollable
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen financiero
                  Row(children: [
                    _infoBox('Total', '\$${separado.total.toStringAsFixed(0)}',
                        const Color(0xFF1A1A2E), Icons.attach_money_rounded),
                    const SizedBox(width: 10),
                    _infoBox('Abonado',
                        '\$${separado.abonoAcumulado.toStringAsFixed(0)}',
                        Colors.green.shade600, Icons.check_circle_rounded),
                    const SizedBox(width: 10),
                    _infoBox('Pendiente',
                        '\$${separado.saldoPendiente.toStringAsFixed(0)}',
                        Colors.orange.shade600, Icons.pending_rounded),
                  ]),
                  const SizedBox(height: 8),
                  // Barra progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: separado.progreso,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          separado.esPagado
                              ? Colors.green.shade600
                              : Colors.orange.shade600),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Productos
                  Text('Productos separados',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...separado.detalles.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200)),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_rounded,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d.productoNombre,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w500))),
                      Text('x${d.cantidad.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Text('\$${d.subtotal.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: const Color(Constants.primaryColor))),
                    ]),
                  )),

                  // Historial de abonos
                  if (separado.abonos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Historial de abonos',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...separado.abonos.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200)),
                      child: Row(children: [
                        const Icon(Icons.payments_rounded,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('\$${a.monto.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green.shade700)),
                            Text(
                              '${a.metodoPago} • ${a.empleadoNombre ?? 'Cajero'} • ${_formatFecha(a.createdAt)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey)),
                          ],
                        )),
                      ]),
                    )),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoBox(String label, String valor, Color color, IconData icon) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(valor, style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label, style: GoogleFonts.poppins(
            fontSize: 10, color: Colors.grey.shade500)),
      ]),
    ));

  Widget _badgeEstado(String estado) {
    final color = estado == 'pagado'
        ? Colors.green : estado == 'cancelado'
        ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20)),
      child: Text(estado[0].toUpperCase() + estado.substring(1),
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _formatFecha(String fecha) {
    try {
      final d = DateTime.parse(fecha);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return fecha; }
  }
}

// ══════════════════════════════════════════════════════
//  DIALOG CREAR / EDITAR CLIENTE
// ══════════════════════════════════════════════════════
class _DialogCliente extends StatefulWidget {
  final Cliente? cliente;
  const _DialogCliente({this.cliente});

  @override
  State<_DialogCliente> createState() => _DialogClienteState();
}

class _DialogClienteState extends State<_DialogCliente> {
  final _formKey   = GlobalKey<FormState>();
  final _nombre    = TextEditingController();
  final _apellido  = TextEditingController();
  final _cedula    = TextEditingController();
  final _telefono  = TextEditingController();
  final _email     = TextEditingController();
  final _direccion = TextEditingController();

  bool get _esEdicion => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final c = widget.cliente!;
      _nombre.text    = c.nombre;
      _apellido.text  = c.apellido;
      _cedula.text    = c.cedulaNit ?? '';
      _telefono.text  = c.telefono;
      _email.text     = c.email;
      _direccion.text = c.direccion;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();    _apellido.dispose();
    _cedula.dispose();    _telefono.dispose();
    _email.dispose();     _direccion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ClienteProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Row(children: [
                  Icon(
                    _esEdicion
                        ? Icons.edit_rounded
                        : Icons.person_add_rounded,
                    color: const Color(Constants.primaryColor)),
                  const SizedBox(width: 10),
                  Text(
                    _esEdicion ? 'Editar cliente' : 'Nuevo cliente',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context)),
                ]),
                const Divider(height: 24),

                // Error si existe
                if (prov.error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200)),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(prov.error!,
                        style: GoogleFonts.poppins(
                            color: Colors.red, fontSize: 12))),
                    ]),
                  ),

                // Campos
                Row(children: [
                  Expanded(child: _campo(_nombre,    'Nombre *',   required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(_apellido,  'Apellido')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _campo(_cedula,    'Cédula / NIT')),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(_telefono,  'Teléfono')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _campo(_email,     'Email',
                      keyboardType: TextInputType.emailAddress)),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(_direccion, 'Dirección')),
                ]),

                const SizedBox(height: 20),

                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        prov.limpiarError();
                        Navigator.pop(context);
                      },
                      child: Text('Cancelar',
                          style: GoogleFonts.poppins())),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: prov.guardando
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Icon(_esEdicion
                              ? Icons.save_rounded
                              : Icons.person_add_rounded, size: 18),
                      label: Text(
                        _esEdicion ? 'Guardar cambios' : 'Crear cliente',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                      onPressed: prov.guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(Constants.primaryColor),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) =>
    TextFormField(
      controller:   ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 12),
        filled:    true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(Constants.primaryColor))),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
              ? 'Campo requerido' : null
          : null,
    );

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final prov = context.read<ClienteProvider>();
    prov.limpiarError();

    final data = <String, dynamic>{
      'nombre':    _nombre.text.trim(),
      'apellido':  _apellido.text.trim(),
      'telefono':  _telefono.text.trim(),
      'email':     _email.text.trim(),
      'direccion': _direccion.text.trim(),
      if (_cedula.text.trim().isNotEmpty)
        'cedula_nit': _cedula.text.trim(),
    };

    bool ok;
    if (_esEdicion) {
      ok = await prov.editarCliente(widget.cliente!.id, data);
    } else {
      ok = await prov.crearCliente(data);
    }

    if (ok && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _esEdicion
              ? '✅ Cliente actualizado correctamente'
              : '✅ Cliente creado correctamente',
          style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
        behavior:        SnackBarBehavior.floating,
      ));
    }
  }
}