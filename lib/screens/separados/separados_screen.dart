// lib/screens/separados/separados_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/alerta_separado.dart';
import '../../models/cliente.dart';
import '../../models/separado.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cliente_provider.dart';
import '../clientes/widgets/abonar_sheet.dart';
import '../clientes/widgets/separado_detalle_sheet.dart';
import '../clientes/widgets/separado_form.dart';

// ── Paleta (verde+blanco como los dashboards) ─────────────────
const _kGreen      = Color(0xFF61DDAA);   // mint — igual que dashboard
const _kGreenDark  = Color(0xFF0B7A53);   // verde oscuro para texto/iconos
const _kGreenLight = Color(0xFFE8FFF4);
const _kSurface    = Color(0xFFF7F9FB);
const _kCard       = Colors.white;
const _kBorder     = Color(0xFFE2E8F0);
const _kText       = Color(0xFF191C1E);
const _kTextSub    = Color(0xFF45464D);
const _kTextMuted  = Color(0xFF76777D);
const _kRed        = Color(0xFFBA1A1A);
const _kRedLight   = Color(0xFFFFDAD6);
const _kAmber      = Color(0xFFF59E0B);
const _kAmberLight = Color(0xFFFEF3C7);

final _fmt = NumberFormat.currency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 0);

enum _SepTab { activos, historial, abonos, vencimientos }

class SeparadosScreen extends StatefulWidget {
  const SeparadosScreen({super.key});

  @override
  State<SeparadosScreen> createState() => _SeparadosScreenState();
}

class _SeparadosScreenState extends State<SeparadosScreen> {
  _SepTab _tab         = _SepTab.activos;
  String  _busqueda    = '';
  String  _filtroEstado = 'todos';

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTodo());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final prov = context.read<ClienteProvider>();
    final tid  = auth.tiendaId > 0 ? auth.tiendaId : null;
    await Future.wait([
      prov.cargarSeparados(tiendaId: tid),
      prov.cargarAlertas(tiendaId: tid),
      prov.cargarAbonosPorFecha(
          fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          tiendaId: tid),
    ]);
  }

  Future<void> _cargarTab() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final prov = context.read<ClienteProvider>();
    final tid  = auth.tiendaId > 0 ? auth.tiendaId : null;
    switch (_tab) {
      case _SepTab.activos:
        await prov.cargarSeparados(tiendaId: tid, estado: 'activo');
      case _SepTab.historial:
        await prov.cargarSeparados(
            tiendaId: tid,
            estado: _filtroEstado == 'todos' ? null : _filtroEstado);
      case _SepTab.abonos:
        await prov.cargarAbonosPorFecha(
            fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            tiendaId: tid);
      case _SepTab.vencimientos:
        await prov.cargarAlertas(tiendaId: tid);
    }
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final prov = context.watch<ClienteProvider>();

    return Container(
      color: _kSurface,
      child: Column(children: [
        _buildHeader(auth, prov),
        _buildTabBar(prov),
        Expanded(child: _buildContent()),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════════
  Widget _buildHeader(AuthProvider auth, ClienteProvider prov) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bookmark_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Separados',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: _kText)),
          Text(auth.tiendaNombre.isNotEmpty
                  ? auth.tiendaNombre : 'Mi Tienda',
              style: GoogleFonts.inter(
                  fontSize: 11, color: _kTextMuted)),
        ]),
        const Spacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.bookmark_add_rounded, size: 15),
          label: Text('Nuevo',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          onPressed: _abrirNuevoSeparado,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreenDark,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label: Text('Actualizar',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          onPressed: _cargarTodo,
          style: TextButton.styleFrom(
            foregroundColor: _kGreenDark,
            backgroundColor: _kGreenLight,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TAB BAR HORIZONTAL
  // ════════════════════════════════════════════════════════════
  Widget _buildTabBar(ClienteProvider prov) {
    return Container(
      color: _kCard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            _tabItem(_SepTab.activos,      Icons.bookmark_added_rounded, 'Activos',
                badge: _activosCount(prov)),
            _tabItem(_SepTab.historial,    Icons.history_rounded,        'Historial'),
            _tabItem(_SepTab.abonos,       Icons.payments_rounded,       'Abonos',
                badge: _abonosHoy(prov)),
            _tabItem(_SepTab.vencimientos, Icons.event_busy_rounded,     'Vencimientos',
                badge: prov.totalAlertas, badgeError: true),
          ]),
          const Divider(height: 1, color: _kBorder),
        ],
      ),
    );
  }

  Widget _tabItem(_SepTab tab, IconData icon, String label,
      {int badge = 0, bool badgeError = false}) {
    final active = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tab = tab;
            _busqueda = '';
            _searchCtrl.clear();
          });
          _cargarTab();
        },
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15,
                    color: active ? _kGreenDark : _kTextMuted),
                const SizedBox(width: 5),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? _kGreenDark : _kTextMuted)),
                if (badge > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: badgeError ? _kRed : _kGreenDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$badge',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              // Indicador activo
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: active ? 32 : 0,
                decoration: BoxDecoration(
                  color: _kGreenDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // CONTENIDO POR SECCIÓN
  // ════════════════════════════════════════════════════════════
  Widget _buildContent() {
    return switch (_tab) {
      _SepTab.activos      => _buildActivos(),
      _SepTab.historial    => _buildHistorial(),
      _SepTab.abonos       => _buildAbonos(),
      _SepTab.vencimientos => _buildVencimientos(),
    };
  }

  // ── 1. ACTIVOS ──────────────────────────────────────────────
  Widget _buildActivos() {
    final prov = context.watch<ClienteProvider>();
    final lista = prov.separados
        .where((s) => s.esActivo)
        .where((s) => _busqueda.isEmpty ||
            s.clienteNombre.toLowerCase().contains(_busqueda.toLowerCase()))
        .toList();

    return Column(children: [
      _pageHeader(
        icon:    Icons.bookmark_added_rounded,
        title:   'Separados activos',
        subtitle: '${lista.length} pendiente${lista.length != 1 ? 's' : ''}',
        actions: [
          _searchField(),
        ],
      ),
      Expanded(
        child: prov.cargando
            ? _loading()
            : lista.isEmpty
                ? _empty(
                    icon:  Icons.bookmark_border_rounded,
                    title: _busqueda.isEmpty
                        ? 'Sin separados activos'
                        : 'Sin resultados',
                    sub: _busqueda.isEmpty
                        ? 'Los separados creados en el POS aparecerán aquí'
                        : 'Intenta con otro nombre')
                : RefreshIndicator(
                    color: _kGreen,
                    onRefresh: _cargarTab,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount:    lista.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _separadoCard(lista[i], mostrarEstado: false),
                    ),
                  ),
      ),
    ]);
  }

  // ── 2. HISTORIAL ───────────────────────────────────────────
  Widget _buildHistorial() {
    final prov  = context.watch<ClienteProvider>();
    final lista = prov.separados
        .where((s) =>
            (_filtroEstado == 'todos' || s.estado == _filtroEstado) &&
            (_busqueda.isEmpty ||
                s.clienteNombre
                    .toLowerCase()
                    .contains(_busqueda.toLowerCase())))
        .toList();

    return Column(children: [
      _pageHeader(
        icon:    Icons.history_rounded,
        title:   'Historial',
        subtitle: '${lista.length} resultado${lista.length != 1 ? 's' : ''}',
        actions: [_searchField()],
      ),

      // Chips de estado
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(children: [
          for (final e in [
            ('todos',     'Todos',     Colors.transparent),
            ('activo',    'Activos',   _kGreenDark),
            ('pagado',    'Pagados',   const Color(0xFF1D4ED8)),
            ('cancelado', 'Cancelados', _kRed),
          ])
            _estadoChip(e.$1, e.$2, e.$3),
        ]),
      ),

      Expanded(
        child: prov.cargando
            ? _loading()
            : lista.isEmpty
                ? _empty(
                    icon:  Icons.history_rounded,
                    title: 'Sin resultados',
                    sub:   'Cambia los filtros o busca otro cliente')
                : RefreshIndicator(
                    color: _kGreen,
                    onRefresh: _cargarTab,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: lista.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _separadoCard(lista[i], mostrarEstado: true),
                    ),
                  ),
      ),
    ]);
  }

  Widget _estadoChip(String valor, String label, Color color) {
    final active = _filtroEstado == valor;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroEstado = valor);
        _cargarTab();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? (valor == 'todos' ? _kGreenDark : color)
              : _kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? (valor == 'todos' ? _kGreenDark : color)
                : _kBorder),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kTextSub)),
      ),
    );
  }

  // ── 3. ABONOS ───────────────────────────────────────────────
  Widget _buildAbonos() {
    final prov  = context.watch<ClienteProvider>();
    final lista = prov.abonosPorFecha;

    final totalHoy = lista.fold<double>(
        0, (s, a) => s + ((a['monto'] as num?)?.toDouble() ?? 0));

    return Column(children: [
      _pageHeader(
        icon:    Icons.payments_rounded,
        title:   'Abonos',
        subtitle: 'Recibidos hoy · ${DateFormat('d MMM yyyy', 'es').format(DateTime.now())}',
      ),

      // KPI total
      if (lista.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.attach_money_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total recibido hoy',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white70)),
              Text(_fmt.format(totalHoy),
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ]),
            const Spacer(),
            Text('${lista.length} abono${lista.length != 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white70)),
          ]),
        ),

      Expanded(
        child: prov.cargando
            ? _loading()
            : lista.isEmpty
                ? _empty(
                    icon:  Icons.payments_outlined,
                    title: 'Sin abonos hoy',
                    sub:   'Los abonos registrados hoy aparecerán aquí')
                : RefreshIndicator(
                    color: _kGreen,
                    onRefresh: _cargarTab,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: lista.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _abonoCard(lista[i]),
                    ),
                  ),
      ),
    ]);
  }

  Widget _abonoCard(Map<String, dynamic> a) {
    final monto    = (a['monto'] as num?)?.toDouble() ?? 0;
    final cliente  = a['cliente_nombre'] as String? ?? '—';
    final metodo   = a['metodo_pago']    as String? ?? 'efectivo';
    final hora     = a['created_at']  != null
        ? DateFormat('HH:mm').format(DateTime.parse(a['created_at'] as String))
        : '';
    final sepId    = a['separado'] as int?;

    final metodoIcon = switch (metodo) {
      'tarjeta'       => Icons.credit_card_rounded,
      'transferencia' => Icons.swap_horiz_rounded,
      _               => Icons.payments_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _kGreenLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(metodoIcon, size: 18, color: _kGreenDark),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cliente,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _kText)),
            Text('Separado #$sepId${hora.isNotEmpty ? '  ·  $hora' : ''}',
                style: GoogleFonts.inter(
                    fontSize: 11, color: _kTextMuted)),
          ],
        )),
        Text(_fmt.format(monto),
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: _kGreenDark)),
      ]),
    );
  }

  // ── 4. VENCIMIENTOS ────────────────────────────────────────
  Widget _buildVencimientos() {
    final prov     = context.watch<ClienteProvider>();
    final vencidos  = prov.vencidos;
    final porVencer = prov.porVencer;

    return Column(children: [
      _pageHeader(
        icon:    Icons.event_busy_rounded,
        title:   'Vencimientos',
        subtitle: '${vencidos.length + porVencer.length} alerta${(vencidos.length + porVencer.length) != 1 ? 's' : ''}',
      ),
      Expanded(
        child: prov.cargando
            ? _loading()
            : (vencidos.isEmpty && porVencer.isEmpty)
                ? _empty(
                    icon:  Icons.check_circle_rounded,
                    title: 'Sin vencimientos',
                    sub:   'No hay separados vencidos ni próximos a vencer',
                    color: _kGreenDark)
                : RefreshIndicator(
                    color: _kGreen,
                    onRefresh: _cargarTab,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        if (vencidos.isNotEmpty) ...[
                          _alertaSeccion('VENCIDOS', vencidos.length,
                              _kRed, _kRedLight),
                          const SizedBox(height: 8),
                          ...vencidos.map((a) =>
                              _alertaCard(a, isVencido: true)),
                          const SizedBox(height: 20),
                        ],
                        if (porVencer.isNotEmpty) ...[
                          _alertaSeccion('POR VENCER', porVencer.length,
                              _kAmber, _kAmberLight),
                          const SizedBox(height: 8),
                          ...porVencer.map((a) =>
                              _alertaCard(a, isVencido: false)),
                        ],
                      ],
                    ),
                  ),
      ),
    ]);
  }

  Widget _alertaSeccion(String label, int count, Color color, Color bg) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(
          label.startsWith('V') ? Icons.warning_rounded : Icons.schedule_rounded,
          size: 15, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: color, letterSpacing: 0.5)),
        const Spacer(),
        Text('$count',
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );

  Widget _alertaCard(AlertaSeparado a, {required bool isVencido}) {
    final color = isVencido ? _kRed : _kAmber;
    final bg    = isVencido ? _kRedLight : _kAmberLight;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(11)),
          child: Center(
            child: Text(a.cliente.isNotEmpty
                    ? a.cliente[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                    color: color, fontWeight: FontWeight.w800,
                    fontSize: 17)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.cliente,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _kText)),
            Text(a.etiquetaDias,
                style: GoogleFonts.inter(
                    fontSize: 11, color: color,
                    fontWeight: FontWeight.w600)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt.format(a.saldoPendiente),
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: color)),
          Text('saldo',
              style: GoogleFonts.inter(
                  fontSize: 10, color: _kTextMuted)),
        ]),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _abrirAbonoDeAlerta(a),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _kGreenDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Abonar',
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),

      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TARJETA DE SEPARADO (shared)
  // ════════════════════════════════════════════════════════════
  Widget _separadoCard(Separado s, {required bool mostrarEstado}) {
    final estadoColor = switch (s.estado) {
      'pagado'    => const Color(0xFF1D4ED8),
      'cancelado' => _kTextMuted,
      _           => _kGreenDark,
    };
    final estadoBg = switch (s.estado) {
      'pagado'    => const Color(0xFFEFF6FF),
      'cancelado' => _kSurface,
      _           => _kGreenLight,
    };

    return GestureDetector(
      onTap: () => _verDetalle(s),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // Encabezado
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: estadoBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(s.clienteNombre.isNotEmpty
                        ? s.clienteNombre[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                        color: estadoColor, fontWeight: FontWeight.w800,
                        fontSize: 17)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.clienteNombre,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _kText)),
                Text('Separado #${s.id}  ·  ${_fechaCorta(s.createdAt)}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _kTextMuted)),
              ],
            )),
            if (mostrarEstado)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: estadoColor.withValues(alpha: 0.25)),
                ),
                child: Text(s.estado.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: estadoColor, letterSpacing: 0.4)),
              )
            else if (s.esActivo)
              GestureDetector(
                onTap: () => _abrirAbono(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _kGreenDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Abonar',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ]),

          const SizedBox(height: 12),

          // Barra de progreso
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Abonado ${_fmt.format(s.abonoAcumulado)}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _kTextMuted)),
                Text('Total ${_fmt.format(s.total)}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _kTextMuted)),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:           s.progreso,
                minHeight:       6,
                backgroundColor: _kBorder,
                color:           estadoColor,
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // Saldo + fecha límite
          Row(children: [
            if (s.saldoPendiente > 0) ...[
              const Icon(Icons.pending_rounded, size: 13, color: _kAmber),
              const SizedBox(width: 5),
              Text('Saldo: ${_fmt.format(s.saldoPendiente)}',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: _kAmber)),
            ] else ...[
              const Icon(Icons.check_circle_rounded,
                  size: 13, color: _kGreenDark),
              const SizedBox(width: 5),
              Text('Saldado',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: _kGreenDark)),
            ],
            const Spacer(),
            if (s.fechaLimite != null) ...[
              const Icon(Icons.event_rounded, size: 12, color: _kTextMuted),
              const SizedBox(width: 4),
              Text('Límite: ${_fechaLimiteLabel(s.fechaLimite!)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: _kTextMuted)),
            ],
          ]),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGETS REUTILIZABLES
  // ════════════════════════════════════════════════════════════
  Widget _pageHeader({
    required IconData icon,
    required String   title,
    required String   subtitle,
    List<Widget>      actions = const [],
  }) =>
    Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      color: _kCard,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kGreenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _kGreenDark),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: _kText)),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _kTextMuted)),
            ],
          )),
          ...actions,
        ]),
        const SizedBox(height: 12),
        const Divider(color: _kBorder, height: 1),
      ]),
    );

  Widget _searchField() => SizedBox(
    width: 220,
    child: TextField(
      controller: _searchCtrl,
      style: GoogleFonts.inter(fontSize: 13, color: _kText),
      decoration: InputDecoration(
        hintText:   'Buscar cliente…',
        hintStyle:  GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 17, color: _kTextMuted),
        suffixIcon: _busqueda.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 14, color: _kTextMuted),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _busqueda = '');
                })
            : null,
        filled:     true, fillColor: _kSurface,
        isDense:    true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
      ),
      onChanged: (v) => setState(() => _busqueda = v),
    ),
  );

  Widget _loading() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(
        width: 36, height: 36,
        child: CircularProgressIndicator(
            color: _kGreen, strokeWidth: 2.5)),
      const SizedBox(height: 12),
      Text('Cargando…',
          style: GoogleFonts.inter(
              color: _kTextMuted, fontSize: 13)),
    ]),
  );

  Widget _empty({
    required IconData icon,
    required String   title,
    required String   sub,
    Color             color = _kTextMuted,
  }) =>
    Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 36, color: color),
        ),
        const SizedBox(height: 14),
        Text(title,
            style: GoogleFonts.inter(
                color: _kTextSub, fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(sub,
            style: GoogleFonts.inter(
                color: _kTextMuted, fontSize: 13)),
      ]),
    );

  // ════════════════════════════════════════════════════════════
  // ACCIONES
  // ════════════════════════════════════════════════════════════

  void _abrirNuevoSeparado() {
    final auth        = context.read<AuthProvider>();
    final clienteProv = context.read<ClienteProvider>();
    clienteProv.cargarClientesSimple(q: '');

    showDialog(
      context: context,
      builder: (ctx) {
        final localCtrl = TextEditingController();
        bool buscando   = false;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.person_search_rounded,
                  color: _kGreenDark, size: 20),
              const SizedBox(width: 8),
              Text('Seleccionar cliente',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: _kText)),
            ]),
            content: SizedBox(
              width: 380, height: 320,
              child: Column(children: [
                TextField(
                  controller: localCtrl,
                  autofocus:  true,
                  decoration: InputDecoration(
                    hintText:  'Buscar por nombre o cédula…',
                    hintStyle: GoogleFonts.inter(
                        color: _kTextMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: _kGreenDark),
                    suffixIcon: buscando
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kGreenDark),
                            ))
                        : null,
                    filled: true, fillColor: _kSurface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _kGreen, width: 2)),
                  ),
                  onChanged: (v) async {
                    if (v.length < 2) return;
                    setS(() => buscando = true);
                    await clienteProv.cargarClientesSimple(q: v);
                    if (ctx.mounted) setS(() => buscando = false);
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Consumer<ClienteProvider>(
                    builder: (_, cp, _) => cp.clientesSimple.isEmpty
                        ? Center(
                            child: Text(
                              'Escribe al menos 2 caracteres para buscar',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: _kTextMuted, fontSize: 13),
                            ))
                        : ListView.builder(
                            itemCount: cp.clientesSimple.length,
                            itemBuilder: (_, i) {
                              final Cliente c = cp.clientesSimple[i];
                              return ListTile(
                                dense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 2),
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: _kGreen.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      c.nombre.isNotEmpty
                                          ? c.nombre[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.inter(
                                          color: _kGreenDark,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                                title: Text(c.nombreCompleto,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _kText)),
                                subtitle: (c.cedulaNit != null &&
                                        c.cedulaNit!.isNotEmpty)
                                    ? Text(c.cedulaNit!,
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _kTextMuted))
                                    : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  SeparadoForm.mostrar(
                                    context,
                                    tiendaId: auth.tiendaId > 0
                                        ? auth.tiendaId
                                        : null,
                                    fmt:            _fmt,
                                    clienteInicial: c,
                                    itemsInciales:  const [],
                                    onCreado: () {
                                      _cargarTodo();
                                      setState(() => _tab = _SepTab.activos);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar',
                    style: GoogleFonts.inter(color: _kTextMuted)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _verDetalle(Separado s) {
    SeparadoDetalleSheet.mostrar(context, separado: s, fmt: _fmt);
  }

  void _abrirAbono(Separado s) {
    AbonarSheet.mostrar(context,
        separado:  s,
        fmt:       _fmt,
        onAbonado: () {
          _cargarTab();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Abono registrado correctamente',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: _kGreenDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        });
  }

  void _abrirAbonoDeAlerta(AlertaSeparado a) {
    final prov = context.read<ClienteProvider>();
    final sep = prov.separados.firstWhere(
      (s) => s.id == a.id,
      orElse: () => Separado(
        id:             a.id,
        tienda:         0,
        tiendaNombre:   a.tienda,
        cliente:        0,
        clienteNombre:  a.cliente,
        total:          a.saldoPendiente,
        abonoAcumulado: 0,
        saldoPendiente: a.saldoPendiente,
        estado:         'activo',
        createdAt:      DateTime.now(),
        detalles:       [],
        abonos:         [],
      ),
    );
    _abrirAbono(sep);
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════
  int _activosCount(ClienteProvider p) =>
      p.separados.where((s) => s.esActivo).length;

  int _abonosHoy(ClienteProvider p) => p.abonosPorFecha.length;

  String _fechaCorta(DateTime d) =>
      DateFormat('d MMM yyyy', 'es').format(d);

  String _fechaLimiteLabel(String fechaStr) {
    try {
      final d = DateTime.parse(fechaStr);
      return DateFormat('d MMM', 'es').format(d);
    } catch (_) {
      return fechaStr;
    }
  }
}
