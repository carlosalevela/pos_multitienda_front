import 'package:flutter/material.dart';
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

const _teal   = Color(0xFF01696F);
const _danger = Color(0xFFE03E3E);
const _bg     = Color(0xFFF2F5F7);

enum _Fase { empresa, tienda, clientes }

// ─── SCREEN ──────────────────────────────────────────────────
class ClientesScreen extends StatefulWidget {
  final bool esAdminOSupervisor;
  const ClientesScreen({super.key, required this.esAdminOSupervisor});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  // ── Navegación ──────────────────────────────────────
  _Fase        _fase            = _Fase.empresa;
  int?         _empresaId;
  String       _empresaNombre   = '';
  int?         _tiendaId;
  String       _tiendaNombre    = '';
  List<Tienda> _tiendas         = [];
  bool         _cargandoTiendas = false;

  // ── Clientes ─────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _filtro    = 'todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.esAdminOSupervisor) {
        await context.read<EmpresaProvider>().cargarEmpresas();
      } else {
        final auth = context.read<AuthProvider>();
        setState(() {
          _tiendaId     = auth.tiendaId;
          _tiendaNombre = auth.tiendaNombre;
          _fase         = _Fase.clientes;
        });
        if (!mounted) return;
        final prov = context.read<ClienteProvider>();
        await prov.cargarClientes(tiendaId: _tiendaId);
        await prov.cargarAlertas(tiendaId: _tiendaId); // ✅ fix 1
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Seleccionar empresa ──────────────────────────────
  Future<void> _seleccionarEmpresa(Empresa e) async {
    setState(() {
      _empresaId       = e.id;
      _empresaNombre   = e.nombre;
      _fase            = _Fase.tienda;
      _tiendas         = [];
      _cargandoTiendas = true;
    });
    try {
      await context.read<TiendaProvider>().cargarTiendasPorEmpresa(e.id);
      if (mounted) {
        setState(() {
          _tiendas         = context.read<TiendaProvider>().tiendas;
          _cargandoTiendas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoTiendas = false);
    }
  }

  // ── Seleccionar tienda ───────────────────────────────
  Future<void> _seleccionarTienda(Tienda t) async {
    setState(() {
      _tiendaId     = t.id;
      _tiendaNombre = t.nombre;
      _fase         = _Fase.clientes;
      _filtro       = 'todos';
      _searchCtrl.clear();
    });
    if (!mounted) return;
    final prov = context.read<ClienteProvider>();
    await prov.cargarClientes(tiendaId: t.id);
    await prov.cargarAlertas(tiendaId: t.id); // ✅ fix 2
  }

  // ── Recargar tiendas ─────────────────────────────────
  Future<void> _recargarTiendas() async {
    if (_empresaId == null) return;
    setState(() { _tiendas = []; _cargandoTiendas = true; });
    try {
      await context.read<TiendaProvider>().cargarTiendasPorEmpresa(_empresaId!);
      if (mounted) {
        setState(() {
          _tiendas         = context.read<TiendaProvider>().tiendas;
          _cargandoTiendas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoTiendas = false);
    }
  }

  // ── Retroceder ───────────────────────────────────────
  void _retroceder() {
    if (_fase == _Fase.clientes) {
      final prov = context.read<ClienteProvider>();
      prov.limpiarClientes();
      prov.limpiarAlertas(); // ✅ fix 3
      setState(() {
        _tiendaId     = null;
        _tiendaNombre = '';
        _fase         = _Fase.tienda;
      });
    } else if (_fase == _Fase.tienda) {
      setState(() {
        _empresaId     = null;
        _empresaNombre = '';
        _tiendas       = [];
        _fase          = _Fase.empresa;
      });
    }
  }

  // ── Clientes ─────────────────────────────────────────
  List<Cliente> _filtrados(List<Cliente> lista) {
    if (_filtro == 'activos')   return lista.where((c) => c.activo).toList();
    if (_filtro == 'inactivos') return lista.where((c) => !c.activo).toList();
    return lista;
  }

  void _snack(String msg, {Color color = _teal}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _abrirFormCrear() {
    ClienteForm.mostrar(context,
        onGuardado: () => context
            .read<ClienteProvider>()
            .cargarClientes(tiendaId: _tiendaId));
  }

  void _abrirFormEditar(Cliente c) {
    ClienteForm.mostrar(context,
        cliente:    c,
        onGuardado: () => context
            .read<ClienteProvider>()
            .cargarClientes(tiendaId: _tiendaId));
  }

  void _verDetalle(Cliente c) {
    ClienteDetalleSheet.mostrar(
      context,
      cliente:            c,
      esAdminOSupervisor: widget.esAdminOSupervisor,
      onEditar:    () { Navigator.pop(context); _abrirFormEditar(c); },
      onDesactivar: () { Navigator.pop(context); _confirmarDesactivar(c); },
    );
  }

  Future<void> _confirmarDesactivar(Cliente c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('¿Desactivar cliente?'),
        content: Text('"${c.nombreCompleto}" dejará de aparecer en búsquedas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desactivar',
                  style: TextStyle(color: _danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final prov    = context.read<ClienteProvider>();
    final success = await prov.desactivarCliente(c.id);
    if (!mounted) return;
    _snack(
      success ? 'Cliente desactivado' : (prov.error ?? 'No se pudo desactivar'),
      color: success ? _teal : _danger,
    );
  }

  // ── AppBar dinámico ──────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    final (titulo, sub) = switch (_fase) {
      _Fase.empresa  => ('Clientes',     'Selecciona una empresa'),
      _Fase.tienda   => (_empresaNombre, 'Selecciona una sucursal'),
      _Fase.clientes => (_tiendaNombre,  _empresaNombre),
    };
    return AppBar(
      backgroundColor: _teal,
      foregroundColor: Colors.white,
      leading: widget.esAdminOSupervisor && _fase != _Fase.empresa
          ? IconButton(
              icon:      const Icon(Icons.arrow_back_rounded),
              onPressed: _retroceder,
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          if (sub.isNotEmpty)
            Text(sub,
                style: const TextStyle(
                    fontSize: 11, color: Colors.white70)),
        ],
      ),
      actions: [
        if (_fase == _Fase.clientes)
          Consumer<ClienteProvider>(
            builder: (_, p, __) => p.totalAlertas > 0
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Chip(
                      backgroundColor: Colors.amber,
                      label: Text('${p.totalAlertas} alertas',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar:          _buildAppBar(),
      floatingActionButton: _fase == _Fase.clientes
          ? FloatingActionButton.extended(
              onPressed:       _abrirFormCrear,
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              icon:            const Icon(Icons.person_add_rounded),
              label:           const Text('Nuevo cliente'),
            )
          : null,

      body: switch (_fase) {

        // ── FASE 1: Empresas ──────────────────────────
        _Fase.empresa => Consumer<EmpresaProvider>(
          builder: (_, prov, __) {
            if (prov.cargando) {
              return const Center(
                  child: CircularProgressIndicator(color: _teal));
            }
            if (prov.errorMsg.isNotEmpty) {
              return _ErrorVacio(
                msg:     prov.errorMsg,
                onRetry: prov.cargarEmpresas,
              );
            }
            if (prov.empresas.isEmpty) {
              return const _Vacio(
                icon:    Icons.business_outlined,
                mensaje: 'No hay empresas disponibles',
              );
            }
            return Column(children: [
              _StatsStrip(items: [
                ('Total',     '${prov.totalEmpresas}'),
                ('Activas',   '${prov.totalActivas}'),
                ('Inactivas', '${prov.totalInactivas}'),
              ]),
              Expanded(
                child: ListView.separated(
                  padding:          const EdgeInsets.all(12),
                  itemCount:        prov.empresas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = prov.empresas[i];
                    return _EmpresaTile(
                      empresa: e,
                      onTap:   () => _seleccionarEmpresa(e),
                    );
                  },
                ),
              ),
            ]);
          },
        ),

        // ── FASE 2: Tiendas ───────────────────────────
        _Fase.tienda => _cargandoTiendas
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : _tiendas.isEmpty
                ? const _Vacio(
                    icon:    Icons.store_outlined,
                    mensaje: 'Esta empresa no tiene sucursales',
                  )
                : Column(children: [
                    _StatsStrip(items: [
                      ('Sucursales', '${_tiendas.length}'),
                      ('Activas',
                          '${_tiendas.where((t) => t.activo).length}'),
                      ('Inactivas',
                          '${_tiendas.where((t) => !t.activo).length}'),
                    ]),
                    Expanded(
                      child: ListView.separated(
                        padding:          const EdgeInsets.all(12),
                        itemCount:        _tiendas.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _TiendaTile(
                          tienda: _tiendas[i],
                          onTap:  () => _seleccionarTienda(_tiendas[i]),
                        ),
                      ),
                    ),
                  ]),

        // ── FASE 3: Clientes ──────────────────────────
        _Fase.clientes => Consumer<ClienteProvider>(
          builder: (_, prov, __) {
            final lista = _filtrados(prov.clientes);
            return Column(children: [
              _StatsStrip(items: [
                ('Total',     '${prov.clientes.length}'),
                ('Activos',   '${prov.clientes.where((c) => c.activo).length}'),
                ('Inactivos', '${prov.clientes.where((c) => !c.activo).length}'),
              ]),

              // Búsqueda
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged:  (q) =>
                      prov.cargarClientes(tiendaId: _tiendaId, q: q),
                  decoration: InputDecoration(
                    hintText:   'Buscar cliente…',
                    prefixIcon: const Icon(Icons.search),
                    filled:     true,
                    fillColor:  Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide.none),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon:      const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _filtro = 'todos');
                              prov.cargarClientes(tiendaId: _tiendaId);
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Filtros
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(children: [
                  for (final (label, key) in [
                    ('Todos',    'todos'),
                    ('Activos',  'activos'),
                    ('Inactivos','inactivos'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label:         Text(label),
                        selected:      _filtro == key,
                        onSelected:    (_) => setState(() => _filtro = key),
                        selectedColor: _teal,
                        labelStyle: TextStyle(
                            color: _filtro == key ? Colors.white : null),
                      ),
                    ),
                ]),
              ),

              // Banner error
              if (prov.error != null)
                ListTile(
                  tileColor: _danger.withOpacity(0.08),
                  leading:   const Icon(Icons.error_outline, color: _danger),
                  title:     Text(prov.error!,
                      style: const TextStyle(
                          color: _danger, fontSize: 13)),
                  trailing: IconButton(
                      icon:      const Icon(Icons.close, size: 18),
                      onPressed: prov.limpiarError),
                ),

              // Lista
              Expanded(
                child: prov.cargando
                    ? const Center(
                        child: CircularProgressIndicator(color: _teal))
                    : lista.isEmpty
                        ? _Vacio(
                            icon:    Icons.people_outline,
                            mensaje: 'Sin resultados',
                            accion: TextButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _filtro = 'todos');
                                prov.cargarClientes(tiendaId: _tiendaId);
                              },
                              child: const Text('Limpiar filtros'),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await prov.cargarClientes(
                                  tiendaId: _tiendaId,
                                  q:        _searchCtrl.text);
                              await prov.cargarAlertas(tiendaId: _tiendaId); // ✅ fix 4
                            },
                            color: _teal,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 0, 12, 100),
                              itemCount:        lista.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => _ClienteTile(
                                cliente:            lista[i],
                                esAdminOSupervisor: widget.esAdminOSupervisor,
                                onTap:       () => _verDetalle(lista[i]),
                                onEditar:    () => _abrirFormEditar(lista[i]),
                                onDesactivar: () =>
                                    _confirmarDesactivar(lista[i]),
                              ),
                            ),
                          ),
              ),
            ]);
          },
        ),
      },
    );
  }
}

// ─── STATS STRIP ─────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  final List<(String, String)> items;
  const _StatsStrip({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    color:   _teal,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child:   Row(
      children: items.map((e) => _Stat(e.$1, e.$2)).toList(),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin:  const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.bold,
                fontSize:   18)),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11)),
      ]),
    ),
  );
}

// ─── EMPRESA TILE ─────────────────────────────────────────────
class _EmpresaTile extends StatelessWidget {
  final Empresa      empresa;
  final VoidCallback onTap;
  const _EmpresaTile({required this.empresa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final activa = empresa.activo;
    final subtitulo = [
      if (empresa.nit.isNotEmpty)    'NIT: ${empresa.nit}',
      if (empresa.ciudad.isNotEmpty)  empresa.ciudad,
    ].join(' · ');

    return ListTile(
      onTap:     activa ? onTap : null,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width:  42, height: 42,
        decoration: BoxDecoration(
          color:        _teal.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.business_rounded,
            color: _teal, size: 22),
      ),
      title: Text(empresa.nombre,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: activa ? null : Colors.grey)),
      subtitle: subtitulo.isNotEmpty
          ? Text(subtitulo, style: const TextStyle(fontSize: 12))
          : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _Badge(activo: activa, labelOn: 'Activa', labelOff: 'Inactiva'),
        if (activa) ...[
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ]),
    );
  }
}

// ─── TIENDA TILE ──────────────────────────────────────────────
class _TiendaTile extends StatelessWidget {
  final Tienda       tienda;
  final VoidCallback onTap;
  const _TiendaTile({required this.tienda, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final activa = tienda.activo;
    final subtitulo = [
      if (tienda.ciudad.isNotEmpty)    tienda.ciudad,
      if (tienda.direccion.isNotEmpty) tienda.direccion,
      if (tienda.telefono.isNotEmpty)  'Tel: ${tienda.telefono}',
    ].join(' · ');

    return ListTile(
      onTap:     activa ? onTap : null,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width:  42, height: 42,
        decoration: BoxDecoration(
          color:        _teal.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.store_rounded, color: _teal, size: 22),
      ),
      title: Text(tienda.nombre,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: activa ? null : Colors.grey)),
      subtitle: subtitulo.isNotEmpty
          ? Text(subtitulo, style: const TextStyle(fontSize: 12))
          : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _Badge(activo: activa, labelOn: 'Activa', labelOff: 'Inactiva'),
        if (activa) ...[
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ]),
    );
  }
}

// ─── CLIENTE TILE ─────────────────────────────────────────────
class _ClienteTile extends StatelessWidget {
  final Cliente      cliente;
  final bool         esAdminOSupervisor;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;

  const _ClienteTile({
    required this.cliente,
    required this.esAdminOSupervisor,
    required this.onTap,
    required this.onEditar,
    required this.onDesactivar,
  });

  @override
  Widget build(BuildContext context) {
    final c = cliente;
    final iniciales = [
      c.nombre.isNotEmpty   ? c.nombre[0]   : '',
      c.apellido.isNotEmpty ? c.apellido[0] : '',
    ].join().toUpperCase();

    return ListTile(
      onTap:     onTap,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      leading: CircleAvatar(
        backgroundColor: c.activo ? _teal : Colors.grey,
        child: Text(iniciales,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      title: Text(c.nombreCompleto,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: c.activo ? null : Colors.grey)),
      subtitle: c.telefono.isNotEmpty ? Text(c.telefono) : null,
      trailing: esAdminOSupervisor
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded,
                    size: 18, color: _teal),
                onPressed: onEditar,
              ),
              IconButton(
                icon: const Icon(Icons.person_off_rounded,
                    size: 18, color: _danger),
                onPressed: onDesactivar,
              ),
            ])
          : _Badge(
              activo:   c.activo,
              labelOn:  'Activo',
              labelOff: 'Inactivo',
            ),
    );
  }
}

// ─── BADGE ────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final bool   activo;
  final String labelOn, labelOff;
  const _Badge({
    required this.activo,
    required this.labelOn,
    required this.labelOff,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: activo
          ? _teal.withOpacity(0.10)
          : Colors.grey.withOpacity(0.10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      activo ? labelOn : labelOff,
      style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.bold,
          color: activo ? _teal : Colors.grey),
    ),
  );
}

// ─── ESTADO VACÍO ─────────────────────────────────────────────
class _Vacio extends StatelessWidget {
  final IconData icon;
  final String   mensaje;
  final Widget?  accion;
  const _Vacio({
    required this.icon,
    required this.mensaje,
    this.accion,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 48, color: Colors.grey),
      const SizedBox(height: 12),
      Text(mensaje, style: const TextStyle(color: Colors.grey)),
      if (accion != null) accion!,
    ]),
  );
}

// ─── ERROR + RETRY ────────────────────────────────────────────
class _ErrorVacio extends StatelessWidget {
  final String       msg;
  final VoidCallback onRetry;
  const _ErrorVacio({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: _danger),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: _danger)),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: onRetry,
        icon:  const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    ]),
  );
}