import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/cliente_provider.dart';
import '../../providers/empresa_provider.dart';
import '../../providers/tienda_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/cliente.dart';
import '../../models/empresa_model.dart';
import '../../models/tienda_model.dart';
import 'widgets/cliente_form.dart';
import 'widgets/cliente_detalle_sheet.dart';
import 'widgets/alertas_badge.dart';

const _teal   = Color(0xFF01696F);
const _tealBg = Color(0xFFE6F4F4);
const _danger = Color(0xFFE03E3E);
const _bg     = Color(0xFFF2F5F7);
const _surface = Colors.white;
const _border = Color(0xFFE4E8EB);
const _textPrimary = Color(0xFF141C22);
const _textMuted   = Color(0xFF8C9BAB);

class ClientesScreen extends StatefulWidget {
  final bool esAdminOSupervisor;
  const ClientesScreen({super.key, required this.esAdminOSupervisor});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  // ── Selección ──────────────────────────────────────────
  Empresa?     _empresa;
  Tienda?      _tienda;
  List<Tienda> _tiendas = [];
  bool         _cargandoTiendas = false;

  // ── Lista ──────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _filtro    = 'todos';

  // ── Detail panel ───────────────────────────────────────
  Cliente? _selectedCliente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    if (!widget.esAdminOSupervisor) {
      // Cajero: tienda fija
      await _cargarClientes(auth.tiendaId);
    } else if (auth.esSuperadmin) {
      // Superadmin: necesita elegir empresa
      await context.read<EmpresaProvider>().cargarEmpresas();
    } else {
      // Admin/supervisor: empresa fija — cargar sus tiendas directamente
      final empresaId = int.tryParse(auth.empresaId) ?? 0;
      if (empresaId > 0) {
        setState(() => _cargandoTiendas = true);
        try {
          await context.read<TiendaProvider>().cargarTiendasPorEmpresa(empresaId);
          if (!mounted) return;
          final t = context.read<TiendaProvider>().tiendas;
          setState(() { _tiendas = t; _cargandoTiendas = false; });
          if (t.length == 1) await _onTiendaChanged(t.first);
        } catch (_) {
          if (mounted) setState(() => _cargandoTiendas = false);
        }
      }
    }
  }

  Future<void> _onEmpresaChanged(Empresa e) async {
    setState(() {
      _empresa         = e;
      _tienda          = null;
      _tiendas         = [];
      _cargandoTiendas = true;
      _selectedCliente = null;
    });
    context.read<ClienteProvider>().limpiarClientes();
    try {
      await context.read<TiendaProvider>().cargarTiendasPorEmpresa(e.id);
      if (!mounted) return;
      final t = context.read<TiendaProvider>().tiendas;
      setState(() { _tiendas = t; _cargandoTiendas = false; });
      if (t.length == 1) await _onTiendaChanged(t.first);
    } catch (_) {
      if (mounted) setState(() => _cargandoTiendas = false);
    }
  }

  Future<void> _onTiendaChanged(Tienda t) async {
    setState(() { _tienda = t; _selectedCliente = null; _filtro = 'todos'; });
    _searchCtrl.clear();
    await _cargarClientes(t.id);
  }

  Future<void> _cargarClientes(int? tiendaId) async {
    if (tiendaId == null || !mounted) return;
    final prov = context.read<ClienteProvider>();
    await prov.cargarClientes(tiendaId: tiendaId);
    await prov.cargarAlertas(tiendaId: tiendaId);
  }

  int? get _tiendaActual {
    if (!widget.esAdminOSupervisor) return context.read<AuthProvider>().tiendaId;
    return _tienda?.id;
  }

  List<Cliente> _filtrados(List<Cliente> lista) {
    var result = lista;
    if (_filtro == 'activos')   result = result.where((c) => c.activo).toList();
    if (_filtro == 'inactivos') result = result.where((c) => !c.activo).toList();
    return result;
  }

  // ── Acciones ───────────────────────────────────────────

  void _abrirFormCrear() => ClienteForm.mostrar(
    context,
    tiendaId:   _tiendaActual,
    onGuardado: () => context.read<ClienteProvider>().cargarClientes(tiendaId: _tiendaActual),
  );

  void _abrirFormEditar(Cliente c) => ClienteForm.mostrar(
    context,
    cliente:    c,
    tiendaId:   _tiendaActual,
    onGuardado: () => context.read<ClienteProvider>().cargarClientes(tiendaId: _tiendaActual),
  );

  void _verDetalle(Cliente c) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    if (isWide) {
      setState(() => _selectedCliente = c);
    } else {
      ClienteDetalleSheet.mostrar(
        context,
        cliente:            c,
        esAdminOSupervisor: widget.esAdminOSupervisor,
        onEditar:     () { Navigator.pop(context); _abrirFormEditar(c); },
        onDesactivar: () { Navigator.pop(context); _confirmarDesactivar(c); },
      );
    }
  }

  Future<void> _confirmarDesactivar(Cliente c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('¿Desactivar cliente?'),
        content: Text('"${c.nombreCompleto}" dejará de aparecer en búsquedas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Desactivar', style: TextStyle(color: _danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final prov    = context.read<ClienteProvider>();
    final success = await prov.desactivarCliente(c.id);
    if (!mounted) return;
    if (success && _selectedCliente?.id == c.id) setState(() => _selectedCliente = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(success ? 'Cliente desactivado' : (prov.error ?? 'No se pudo desactivar')),
      backgroundColor: success ? _teal : _danger,
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide   = MediaQuery.of(context).size.width >= 900;
    final auth     = context.watch<AuthProvider>();
    final prov     = context.watch<ClienteProvider>();
    final lista    = _filtrados(prov.clientes);
    final content = Column(children: [
      _buildHeader(prov, auth.esSuperadmin),
      if (prov.error != null)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFEDED), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.error_outline, color: _danger, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(prov.error!, style: const TextStyle(color: _danger, fontSize: 13))),
            IconButton(icon: const Icon(Icons.close, size: 16), onPressed: prov.limpiarError, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
      Expanded(child: _buildLista(lista, prov, isWide)),
    ]);

    if (!isWide || _selectedCliente == null) {
      return Scaffold(
        backgroundColor: _bg,
        floatingActionButton: _tiendaActual != null
            ? FloatingActionButton.extended(
                onPressed: _abrirFormCrear,
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                icon:  const Icon(Icons.person_add_rounded),
                label: const Text('Nuevo cliente'),
              )
            : null,
        body: content,
      );
    }

    // Desktop: split view
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _tiendaActual != null
          ? FloatingActionButton.extended(
              onPressed: _abrirFormCrear,
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              icon:  const Icon(Icons.person_add_rounded),
              label: const Text('Nuevo cliente'),
            )
          : null,
      body: Row(children: [
        SizedBox(width: 380, child: content),
        const VerticalDivider(width: 1, color: _border),
        Expanded(
          child: _buildDetailPanel(_selectedCliente!),
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────

  Widget _buildHeader(ClienteProvider prov, bool isSuperadmin) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Título + alertas
        Row(children: [
          Text('Clientes', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: _textPrimary)),
          const Spacer(),
          Consumer<ClienteProvider>(
            builder: (_, p, child) => p.totalAlertas > 0
                ? AlertasBadge(total: p.totalAlertas, vencidos: p.vencidos, porVencer: p.porVencer)
                : const SizedBox.shrink(),
          ),
        ]),
        const SizedBox(height: 14),

        // Dropdowns empresa + tienda (solo admin)
        if (widget.esAdminOSupervisor) ...[
          Row(children: [
            if (isSuperadmin) ...[
              Expanded(child: _buildEmpresaDropdown()),
              const SizedBox(width: 10),
            ],
            Expanded(child: _buildTiendaDropdown()),
          ]),
          const SizedBox(height: 12),
        ],

        // Búsqueda
        TextField(
          controller: _searchCtrl,
          onChanged: (q) => context.read<ClienteProvider>().cargarClientes(tiendaId: _tiendaActual, q: q),
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText:       'Buscar cliente por nombre, teléfono…',
            hintStyle:      GoogleFonts.inter(color: _textMuted, fontSize: 13),
            prefixIcon:     const Icon(Icons.search_rounded, size: 18, color: _textMuted),
            filled:         true,
            fillColor:      _bg,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border:         OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon:      const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _filtro = 'todos');
                      context.read<ClienteProvider>().cargarClientes(tiendaId: _tiendaActual);
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),

        // Chips + stats
        Row(children: [
          for (final (lbl, key) in [('Todos', 'todos'), ('Activos', 'activos'), ('Inactivos', 'inactivos')])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _filtro = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:        _filtro == key ? _teal : _bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(lbl, style: GoogleFonts.inter(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      _filtro == key ? Colors.white : _textMuted,
                  )),
                ),
              ),
            ),
          const Spacer(),
          if (prov.clientes.isNotEmpty)
            Text(
              '${prov.clientes.length} cliente${prov.clientes.length != 1 ? 's' : ''}',
              style: GoogleFonts.inter(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500),
            ),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _border),
      ]),
    );
  }

  Widget _buildEmpresaDropdown() {
    final empresas = context.watch<EmpresaProvider>().empresas;
    return _Dropdown<Empresa>(
      hint:     'Empresa',
      icon:     Icons.business_rounded,
      value:    _empresa,
      items:    empresas,
      label:    (e) => e.nombre,
      onChanged: (e) { if (e != null) _onEmpresaChanged(e); },
    );
  }

  Widget _buildTiendaDropdown() {
    if (_cargandoTiendas) {
      return Container(
        height: 42,
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
        child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _teal))),
      );
    }
    return _Dropdown<Tienda>(
      hint:      _empresa == null ? 'Selecciona empresa primero' : 'Sucursal',
      icon:      Icons.store_rounded,
      value:     _tienda,
      items:     _tiendas,
      label:     (t) => t.nombre,
      enabled:   _tiendas.isNotEmpty,
      onChanged: (t) { if (t != null) _onTiendaChanged(t); },
    );
  }

  // ── Lista ──────────────────────────────────────────────

  Widget _buildLista(List<Cliente> lista, ClienteProvider prov, bool isWide) {
    if (_tiendaActual == null && widget.esAdminOSupervisor) {
      return const _Empty(icon: Icons.store_outlined, msg: 'Selecciona una sucursal para ver sus clientes');
    }
    if (prov.cargando) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }
    if (lista.isEmpty) {
      return _Empty(
        icon: Icons.people_outline,
        msg:  prov.clientes.isEmpty ? 'Sin clientes registrados' : 'Sin resultados para este filtro',
        accion: prov.clientes.isNotEmpty
            ? TextButton(
                onPressed: () { _searchCtrl.clear(); setState(() => _filtro = 'todos'); prov.cargarClientes(tiendaId: _tiendaActual); },
                child: const Text('Limpiar filtros'),
              )
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await prov.cargarClientes(tiendaId: _tiendaActual, q: _searchCtrl.text);
        await prov.cargarAlertas(tiendaId: _tiendaActual);
      },
      color: _teal,
      child: ListView.separated(
        padding:          const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount:        lista.length,
        separatorBuilder: (_, index) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ClienteTile(
          cliente:            lista[i],
          esAdminOSupervisor: widget.esAdminOSupervisor,
          selected:           isWide && _selectedCliente?.id == lista[i].id,
          onTap:              () => _verDetalle(lista[i]),
          onEditar:           () => _abrirFormEditar(lista[i]),
          onDesactivar:       () => _confirmarDesactivar(lista[i]),
        ),
      ),
    );
  }

  // ── Detail panel (desktop) ─────────────────────────────

  Widget _buildDetailPanel(Cliente c) {
    final tier   = c.tierInfo;
    final accent = tier != null ? _accentFromTier(tier.colorHex) : _teal;
    final iniciales = [
      c.nombre.isNotEmpty   ? c.nombre[0]   : '',
      c.apellido.isNotEmpty ? c.apellido[0] : '',
    ].join().toUpperCase();

    return Container(
      color: _surface,
      child: Column(children: [
        // Header del panel
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
          child: Row(children: [
            Text('Detalle', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => _selectedCliente = null),
              color: _textMuted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar + nombre
              Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                  child: Center(child: Text(iniciales, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 20))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.nombreCompleto, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.activo ? _tealBg : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(c.activo ? 'Activo' : 'Inactivo',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.activo ? _teal : Colors.grey)),
                  ),
                ])),
              ]),
              const SizedBox(height: 20),
              const Divider(color: _border),
              const SizedBox(height: 16),

              // Info
              if (c.telefono.isNotEmpty)  _infoRow(Icons.phone_rounded,    'Teléfono',     c.telefono),
              if (c.email.isNotEmpty)     _infoRow(Icons.email_rounded,    'Email',         c.email),
              if (c.cedulaNit?.isNotEmpty ?? false) _infoRow(Icons.badge_rounded, 'Cédula / NIT', c.cedulaNit!),
              if (c.direccion.isNotEmpty) _infoRow(Icons.location_on_rounded, 'Dirección',  c.direccion),

              if (tier != null) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.star_rounded, 'Tier', tier.nombre, color: accent),
              ],
              if (c.totalAcumulado > 0) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.shopping_bag_rounded, 'Total acumulado',
                    '\$${NumberFormat.compact(locale: 'es_CO').format(c.totalAcumulado)}'),
              ],
              if (c.limiteCredito > 0) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.handshake_rounded, 'Límite crédito',
                    '\$${NumberFormat.compact(locale: 'es_CO').format(c.limiteCredito)}',
                    color: const Color(0xFF7C3AED)),
              ],

              const SizedBox(height: 24),
              if (widget.esAdminOSupervisor) ...[
                const Divider(color: _border),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { setState(() => _selectedCliente = null); _abrirFormEditar(c); },
                      icon:  const Icon(Icons.edit_rounded, size: 16, color: _teal),
                      label: Text('Editar', style: GoogleFonts.inter(color: _teal, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _teal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { setState(() => _selectedCliente = null); _confirmarDesactivar(c); },
                      icon:  const Icon(Icons.person_off_rounded, size: 16, color: _danger),
                      label: Text('Desactivar', style: GoogleFonts.inter(color: _danger, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _danger),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    final c = color ?? _teal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: c),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _textPrimary)),
        ])),
      ]),
    );
  }

  static Color _accentFromTier(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return _teal; }
  }
}

// ─── DROPDOWN GENÉRICO ────────────────────────────────────────

class _Dropdown<T> extends StatelessWidget {
  final String        hint;
  final IconData      icon;
  final T?            value;
  final List<T>       items;
  final String Function(T) label;
  final void Function(T?) onChanged;
  final bool          enabled;

  const _Dropdown({
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:     42,
      padding:    const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:        enabled ? _bg : const Color(0xFFF0F2F4),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:       value,
          isExpanded:  true,
          icon:        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _textMuted),
          style:       GoogleFonts.inter(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
          hint: Row(children: [
            Icon(icon, size: 14, color: _textMuted),
            const SizedBox(width: 6),
            Text(hint, style: GoogleFonts.inter(fontSize: 13, color: _textMuted)),
          ]),
          onChanged:   enabled ? onChanged : null,
          items: items.map((e) => DropdownMenuItem<T>(
            value: e,
            child: Text(label(e), overflow: TextOverflow.ellipsis),
          )).toList(),
        ),
      ),
    );
  }
}

// ─── CLIENTE TILE ─────────────────────────────────────────────

class _ClienteTile extends StatelessWidget {
  final Cliente      cliente;
  final bool         esAdminOSupervisor;
  final bool         selected;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;

  const _ClienteTile({
    required this.cliente,
    required this.esAdminOSupervisor,
    required this.selected,
    required this.onTap,
    required this.onEditar,
    required this.onDesactivar,
  });

  static final _fmtAcum = NumberFormat.compact(locale: 'es_CO');

  static Color _accentFromTier(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return _teal; }
  }

  @override
  Widget build(BuildContext context) {
    final c      = cliente;
    final tier   = c.tierInfo;
    final accent = tier != null ? _accentFromTier(tier.colorHex) : _teal;
    final iniciales = [
      c.nombre.isNotEmpty   ? c.nombre[0]   : '',
      c.apellido.isNotEmpty ? c.apellido[0] : '',
    ].join().toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color:        selected ? _tealBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: selected ? _teal.withValues(alpha: 0.4) : _border),
        ),
        child: Stack(children: [
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: c.activo ? accent : Colors.grey.shade300,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(children: [
              // Avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c.activo ? accent.withValues(alpha: 0.10) : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(iniciales, style: TextStyle(color: c.activo ? accent : Colors.grey, fontWeight: FontWeight.w800, fontSize: 14))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.nombreCompleto, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: c.activo ? _textPrimary : Colors.grey)),
                if (c.telefono.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(c.telefono, style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
                ],
                if (tier != null || c.limiteCredito > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    if (tier != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(5)),
                        child: Text(tier.nombre, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: accent)),
                      ),
                    if (tier != null && c.limiteCredito > 0) const SizedBox(width: 4),
                    if (c.limiteCredito > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(5)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.handshake_rounded, size: 9, color: Color(0xFF7C3AED)),
                          SizedBox(width: 3),
                          Text('Crédito', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                        ]),
                      ),
                  ]),
                ],
              ])),
              // Acumulado
              if (c.totalAcumulado > 0) ...[
                const SizedBox(width: 8),
                Text('\$${_fmtAcum.format(c.totalAcumulado)}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _textMuted)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── EMPTY STATE ─────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final IconData icon;
  final String   msg;
  final Widget?  accion;
  const _Empty({required this.icon, required this.msg, this.accion});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
        child: Icon(icon, size: 30, color: _textMuted),
      ),
      const SizedBox(height: 14),
      Text(msg, style: GoogleFonts.inter(color: _textMuted, fontSize: 13), textAlign: TextAlign.center),
      if (accion != null) ...[const SizedBox(height: 8), accion!],
    ]),
  );
}
