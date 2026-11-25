// lib/screens/gastos/gastos_screen.dart
//
// "Gastos y nómina" (admin y superadmin).
// - Computador: el diseño del resto del sistema (encabezado verde oscuro,
//   tarjetas blancas con franja, tabla).
// - Celular: paleta verde claro con su propio dashboard (tarjetas que se
//   deslizan, filtros por categoría, lista por día, botón +).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cuenta_bancaria.dart';
import '../../providers/auth_provider.dart';
import '../../services/cuenta_bancaria_service.dart';
import '../../services/empleado_service.dart';
import '../../services/gastos_service.dart';
import '../inventario/widgets/inventario_movil.dart' show formatoCompacto;
import 'gastos_formularios.dart';

// ── Colores y nombres por categoría ───────────────────────────

(Color, IconData) estiloCategoria(String c) => switch (c) {
      'Nómina'        => (const Color(0xFF0369A1), Icons.badge_outlined),
      'Arriendo'      => (const Color(0xFF006C49), Icons.storefront_outlined),
      'Servicios'     => (const Color(0xFF16A34A), Icons.bolt_rounded),
      'Aseo'          => (const Color(0xFFD97706), Icons.cleaning_services_outlined),
      'Insumos'       => (const Color(0xFF0D9488), Icons.inventory_2_outlined),
      'Transporte'    => (const Color(0xFF7C3AED), Icons.local_shipping_outlined),
      'Mantenimiento' => (const Color(0xFF92400E), Icons.build_outlined),
      'Publicidad'    => (const Color(0xFFDB2777), Icons.campaign_outlined),
      'Impuestos'     => (const Color(0xFFB91C1C), Icons.account_balance_outlined),
      'Mercancía' || 'Proveedor' =>
        (const Color(0xFF4338CA), Icons.shopping_bag_outlined),
      _               => (const Color(0xFF64748B), Icons.receipt_long_outlined),
    };

/// "$3.39M", "$54K" (con el signo, como el Dashboard).
String _compacto(double v) => '\$${formatoCompacto(v)}';

/// "22 %", "<1 %".
String porcentaje(double parte, double total) {
  if (total <= 0 || parte <= 0) return '0 %';
  final p = parte / total * 100;
  return p < 1 ? '<1 %' : '${p.round()} %';
}

String _metodo(GastoItem g) => [
      metodosPagoGasto[g.metodoPago] ?? g.metodoPago,
      ?g.cuentaNombre,
    ].join(' · ');

/// "Laura Gómez · 2.ª quincena nov 2026" o el detalle del gasto.
String tituloGasto(GastoItem g) {
  if (g.esNomina) {
    final quien = g.beneficiario.isEmpty ? 'Nómina' : g.beneficiario;
    return g.periodo.isEmpty ? quien : '$quien · ${g.periodo}';
  }
  return g.descripcion.isEmpty ? g.categoria : g.descripcion;
}

/// "$800.000 + $50.000 − $100.000"
String? desgloseNomina(GastoItem g) {
  if (!g.esNomina || g.salario == null) return null;
  return [
    pesos(g.salario!),
    if ((g.extras ?? 0) > 0) '+ ${pesos(g.extras!)}',
    if ((g.descuentos ?? 0) > 0) '− ${pesos(g.descuentos!)}',
  ].join(' ');
}

// ══════════════════════════════════════════════════════════════
// PANTALLA (carga y estado)
// ══════════════════════════════════════════════════════════════

class GastosScreen extends StatefulWidget {
  /// La nómina se liquida en su propia sección; si llega, el botón de
  /// nómina lleva allá en vez de abrir el pago suelto.
  final VoidCallback? onIrANomina;
  const GastosScreen({super.key, this.onIrANomina});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final _service   = GastosService();
  final _empleados = EmpleadoService();
  final _cuentas   = CuentaBancariaService();

  late DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  List<TiendaOpcion> _tiendas = const [];
  int?    _tienda;
  String? _categoria;
  PanelGastos      _panel  = const PanelGastos();
  List<GastoItem>  _gastos = const [];
  bool    _cargando = true;
  String? _error;
  int     _consulta = 0;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final t = await _empleados.getTiendas();
    if (!mounted) return;
    setState(() {
      _tiendas = [
        for (final m in t)
          if (m['id'] is int)
            TiendaOpcion(m['id'] as int, (m['nombre'] ?? 'Tienda').toString()),
      ];
    });
    await _cargar();
  }

  Future<void> _cargar() async {
    final id = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        _service.panel(_mes.year, _mes.month, tiendaId: _tienda),
        _service.listarMes(_mes.year, _mes.month, tiendaId: _tienda),
      ]);
      if (!mounted || id != _consulta) return;
      setState(() {
        _panel = r[0] as PanelGastos;
        _gastos = r[1] as List<GastoItem>;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || id != _consulta) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los gastos.';
      });
    }
  }

  void _cambiarMes(int delta) {
    final n = DateTime(_mes.year, _mes.month + delta);
    final hoy = DateTime.now();
    if (n.isAfter(DateTime(hoy.year, hoy.month))) return;
    setState(() => _mes = n);
    _cargar();
  }

  Future<List<EmpleadoOpcion>> _listaEmpleados() async {
    final l = await _empleados.getEmpleados();
    String rol(String r) => switch (r) {
          'cajero' => 'Cajero(a)',
          'supervisor' => 'Supervisor(a)',
          'admin' => 'Administrador(a)',
          _ => r,
        };
    return [
      for (final e in l)
        if (e['id'] is int && e['activo'] != false && e['rol'] != 'superadmin')
          EmpleadoOpcion(
            e['id'] as int,
            '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}'.trim(),
            detalle: [
              rol('${e['rol'] ?? ''}'),
              if ((e['tienda_nombre'] ?? '').toString().isNotEmpty)
                '${e['tienda_nombre']}',
            ].join(' · '),
            tiendaId: e['tienda'] is int ? e['tienda'] as int : null,
          ),
    ];
  }

  bool get _esMovil => MediaQuery.sizeOf(context).width < 600;

  Color get _acento =>
      _esMovil ? const Color(0xFF059669) : const Color(0xFF006C49);

  /// Abre un formulario: hoja abajo en el celular, diálogo en el computador.
  Future<void> _abrirFormulario(Widget Function(VoidCallback cerrar) hijo) {
    if (_esMovil) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.94),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(child: hijo(() => Navigator.pop(ctx))),
            ]),
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 520, maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: hijo(() => Navigator.pop(ctx)),
          ),
        ),
      ),
    );
  }

  Future<String?> _guardar(Map<String, dynamic> datos, VoidCallback cerrar,
      String aviso) async {
    final err = await _service.crear(datos);
    if (err != null) return err;
    cerrar();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(aviso),
        backgroundColor: const Color(0xFF006C49),
        behavior: SnackBarBehavior.floating,
      ));
    }
    _cargar();
    return null;
  }

  Future<List<CuentaBancaria>> _cargarCuentas(int t) => _cuentas.listar(t);

  void _registrarGasto() => _abrirFormulario((cerrar) => FormGasto(
        tiendas: _tiendas,
        tiendaInicial: _tienda,
        acento: _acento,
        cargarCuentas: _cargarCuentas,
        cajaAbierta: _service.cajaAbierta,
        onCancelar: cerrar,
        onGuardar: (d) => _guardar(d, cerrar, 'Gasto registrado'),
      ));

  Future<void> _registrarNomina() async {
    if (widget.onIrANomina != null) return widget.onIrANomina!();
    final empleados = await _listaEmpleados();
    if (!mounted) return;
    await _abrirFormulario((cerrar) => FormNomina(
          tiendas: _tiendas,
          empleados: empleados,
          tiendaInicial: _tienda,
          acento: _acento,
          cargarCuentas: _cargarCuentas,
          onCancelar: cerrar,
          onGuardar: (d) => _guardar(d, cerrar, 'Pago de nómina registrado'),
        ));
  }

  /// En el celular: ¿gasto o nómina?
  void _elegirRegistro() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: SafeArea(
            top: false,
            child: OpcionesRegistro(
              onGasto: () {
                Navigator.pop(ctx);
                _registrarGasto();
              },
              onNomina: () {
                Navigator.pop(ctx);
                _registrarNomina();
              },
            ),
          ),
        ),
      );

  void _verGasto(GastoItem g) => _abrirFormulario((cerrar) => DetalleGasto(
        gasto: g,
        acento: _acento,
        onCerrar: cerrar,
        onEliminar: () async {
          final err = await _service.eliminar(g.id);
          if (err != null) return err;
          cerrar();
          _cargar();
          return null;
        },
      ));

  @override
  Widget build(BuildContext context) {
    final rol = context.read<AuthProvider>().rol;
    if (rol != 'admin' && rol != 'superadmin') {
      return const Center(child: Text('Solo el administrador ve esta sección.'));
    }
    final datos = DatosGastos(
      mes: _mes,
      tiendas: _tiendas,
      tienda: _tienda,
      categoria: _categoria,
      panel: _panel,
      gastos: _gastos,
      cargando: _cargando,
      error: _error,
    );
    final acciones = AccionesGastos(
      onMes: _cambiarMes,
      onTienda: (t) {
        setState(() => _tienda = t);
        _cargar();
      },
      onCategoria: (c) => setState(() => _categoria = c),
      onRegistrarGasto: _registrarGasto,
      onRegistrarNomina: _registrarNomina,
      onRegistrar: _elegirRegistro,
      onGasto: _verGasto,
      onRefrescar: _cargar,
    );
    return _esMovil
        ? GastosMovil(datos: datos, acciones: acciones)
        : GastosEscritorio(datos: datos, acciones: acciones);
  }
}

// ── Lo que reciben las vistas (se pueden probar solas) ─────────

class DatosGastos {
  final DateTime mes;
  final List<TiendaOpcion> tiendas;
  final int?    tienda;
  final String? categoria;
  final PanelGastos panel;
  final List<GastoItem> gastos;
  final bool    cargando;
  final String? error;
  final DateTime? hoy;

  const DatosGastos({
    required this.mes,
    required this.panel,
    required this.gastos,
    this.tiendas = const [],
    this.tienda,
    this.categoria,
    this.cargando = false,
    this.error,
    this.hoy,
  });

  List<GastoItem> get visibles => categoria == null
      ? gastos
      : gastos.where((g) => g.categoria == categoria).toList();

  /// Categorías que hay en el mes, en el orden del filtro.
  List<String> get categoriasDelMes {
    final hay = gastos.map((g) => g.categoria).toSet();
    return [
      for (final c in categoriasFiltro) if (hay.contains(c)) c,
      for (final c in hay) if (!categoriasFiltro.contains(c)) c,
    ];
  }

  String get tituloMes => '${mesesLargos[mes.month]} ${mes.year}';

  bool get esMesActual {
    final h = hoy ?? DateTime.now();
    return mes.year == h.year && mes.month == h.month;
  }

  String get nombreTienda => tienda == null
      ? 'Todas las tiendas'
      : tiendas.where((t) => t.id == tienda).firstOrNull?.nombre ?? 'Tienda';
}

class AccionesGastos {
  final ValueChanged<int>      onMes;
  final ValueChanged<int?>     onTienda;
  final ValueChanged<String?>  onCategoria;
  final VoidCallback           onRegistrarGasto;
  final VoidCallback           onRegistrarNomina;
  final VoidCallback           onRegistrar;
  final ValueChanged<GastoItem> onGasto;
  final Future<void> Function() onRefrescar;

  const AccionesGastos({
    required this.onMes,
    required this.onTienda,
    required this.onCategoria,
    required this.onRegistrarGasto,
    required this.onRegistrarNomina,
    required this.onRegistrar,
    required this.onGasto,
    required this.onRefrescar,
  });
}

/// Resumen de una línea para el encabezado.
String resumenMes(PanelGastos p) {
  if (p.cantidad == 0) return 'Todavía no hay gastos registrados en este mes.';
  final partes = <String>[];
  if (p.total > 0 && p.nominaTotal > 0) {
    partes.add('${(p.nominaTotal / p.total * 100).round()} % nómina');
  }
  if (p.total > 0 && p.arriendoServicios > 0) {
    partes.add('${(p.arriendoServicios / p.total * 100).round()} % arriendo y servicios');
  }
  return 'Van ${pesos(p.total)} en ${p.cantidad} '
      'gasto${p.cantidad == 1 ? '' : 's'}'
      '${partes.isEmpty ? '' : ': ${partes.join(', ')}'}.';
}

// ══════════════════════════════════════════════════════════════
// COMPUTADOR — mismo diseño del sistema
// ══════════════════════════════════════════════════════════════

class _D {
  static const bg         = Color(0xFFF5F7F8);
  static const surface    = Colors.white;
  static const border     = Color(0xFFE5E7EB);
  static const divider    = Color(0xFFEEF1F4);
  static const second     = Color(0xFF6B7280);
  static const faint      = Color(0xFF9CA3AF);
  static const green      = Color(0xFF61DDAA);
  static const greenLight = Color(0xFFE8FFF4);
  static const greenDark  = Color(0xFF006C49);
  static const rose       = Color(0xFFBE123C);
}

class GastosEscritorio extends StatelessWidget {
  final DatosGastos    datos;
  final AccionesGastos acciones;
  const GastosEscritorio({super.key, required this.datos, required this.acciones});

  @override
  Widget build(BuildContext context) {
    final p = datos.panel;
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      color: _D.bg,
      child: RefreshIndicator(
        onRefresh: acciones.onRefrescar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _hero(),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (_, c) {
              final cols = c.maxWidth >= 1000 ? 4 : 2;
              final kpis = [
                _kpi('Gastos del mes', _compacto(p.total),
                    p.variacionPct == null
                        ? null
                        : '${p.variacionPct! > 0 ? '+' : ''}${p.variacionPct!.toStringAsFixed(1)} %',
                    p.variacionPct == null ? null : p.variacionPct! <= 0,
                    p.variacionPct == null ? '${p.cantidad} registros' : 'vs mes anterior',
                    Icons.payments_outlined, primera: true),
                _kpi('Nómina', _compacto(p.nominaTotal),
                    '${p.nominaPagos} pago${p.nominaPagos == 1 ? '' : 's'}', null,
                    '${p.nominaPersonas} persona${p.nominaPersonas == 1 ? '' : 's'}',
                    Icons.badge_outlined),
                _kpi('Arriendo y servicios', _compacto(p.arriendoServicios),
                    null, null, 'Arriendo, luz, agua, internet',
                    Icons.storefront_outlined),
                _kpi('Salió de la caja', _compacto(p.deCaja),
                    'En los cierres', true, 'ya descontado',
                    Icons.point_of_sale_outlined),
              ];
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: c.maxWidth >= 1000 ? 1.7 : 2.3,
                children: kpis,
              );
            }),
            const SizedBox(height: 24),
            if (w >= 1100)
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 13, child: _tabla()),
                  const SizedBox(width: 20),
                  Expanded(flex: 7, child: _porCategoria()),
                ]),
              )
            else ...[
              _tabla(),
              const SizedBox(height: 20),
              _porCategoria(),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _hero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: _D.greenDark, borderRadius: BorderRadius.circular(16)),
        child: Stack(children: [
          Positioned(
            right: -20, top: -24,
            child: Icon(Icons.payments_rounded, size: 140,
                color: Colors.white.withValues(alpha: 0.05)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 10, runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _D.green, borderRadius: BorderRadius.circular(4)),
                child: Text('GASTOS Y NÓMINA',
                    style: gf(size: 9, w: FontWeight.w700,
                        color: Colors.white, ls: 1.2)),
              ),
              _selectorMesHero(),
              if (datos.tiendas.length > 1) _selectorTiendaHero(),
            ]),
            const SizedBox(height: 12),
            Text(datos.tituloMes,
                style: gf(size: 22, w: FontWeight.w800, color: Colors.white,
                    h: 1.2)),
            const SizedBox(height: 8),
            Text(datos.cargando ? 'Cargando…' : resumenMes(datos.panel),
                style: gf(size: 12.5, h: 1.6,
                    color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _botonHero('Registrar gasto', Icons.add_rounded,
                  acciones.onRegistrarGasto, claro: true),
              _botonHero('Liquidar nómina', Icons.badge_outlined,
                  acciones.onRegistrarNomina),
            ]),
          ]),
        ]),
      );

  Widget _selectorMesHero() => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Mes anterior',
            onPressed: () => acciones.onMes(-1),
            icon: const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 18),
          ),
          Text(datos.tituloMes,
              style: gf(size: 12, w: FontWeight.w700, color: Colors.white)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Mes siguiente',
            onPressed: datos.esMesActual ? null : () => acciones.onMes(1),
            icon: Icon(Icons.chevron_right_rounded, size: 18,
                color: datos.esMesActual
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white),
          ),
        ]),
      );

  Widget _selectorTiendaHero() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: datos.tienda,
            dropdownColor: _D.greenDark,
            iconEnabledColor: Colors.white,
            style: gf(size: 12, w: FontWeight.w700, color: Colors.white),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Todas las tiendas')),
              for (final t in datos.tiendas)
                DropdownMenuItem<int?>(value: t.id, child: Text(t.nombre)),
            ],
            onChanged: acciones.onTienda,
          ),
        ),
      );

  Widget _botonHero(String t, IconData i, VoidCallback onTap,
          {bool claro = false}) =>
      Material(
        color: claro ? Colors.white : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: claro
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, size: 16, color: claro ? _D.greenDark : Colors.white),
              const SizedBox(width: 6),
              Text(t, style: gf(size: 12.5, w: FontWeight.w800,
                  color: claro ? _D.greenDark : Colors.white)),
            ]),
          ),
        ),
      );

  Widget _kpi(String titulo, String valor, String? tendencia, bool? bien,
      String sub, IconData icono, {bool primera = false}) {
    final color = bien == null ? _D.second : bien ? _D.greenDark : _D.rose;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: _D.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _D.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 3, color: primera ? _D.green : _D.greenDark),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: gf(size: 11, w: FontWeight.w600,
                                color: _D.second)),
                      ),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _D.greenLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icono, size: 16, color: _D.greenDark),
                      ),
                    ]),
                    Text(datos.cargando ? '—' : valor,
                        style: gf(size: 26, w: FontWeight.w800)),
                    Row(children: [
                      if (tendencia != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(tendencia,
                              style: gf(size: 10, w: FontWeight.w700,
                                  color: color)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: gf(size: 10, color: _D.faint)),
                      ),
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tarjeta({required Widget titulo, required Widget hijo}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _D.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _D.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          titulo,
          const SizedBox(height: 12),
          const Divider(height: 1, color: _D.divider),
          const SizedBox(height: 12),
          hijo,
        ]),
      );

  Widget _titulo(IconData i, String t, String etiqueta) => Row(children: [
        Icon(i, size: 18, color: _D.greenDark),
        const SizedBox(width: 8),
        Flexible(child: Text(t, style: gf(size: 14.5, w: FontWeight.w800))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _D.border),
          ),
          child: Text(etiqueta, style: gf(size: 10.5, color: _D.second)),
        ),
      ]);

  Widget _tabla() {
    final filas = datos.visibles;
    final cats = datos.categoriasDelMes;
    Widget filtro(String t, bool sel, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: Material(
            color: sel ? _D.greenDark : Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? _D.greenDark : _D.border),
                ),
                child: Text(t, style: gf(size: 11.5, w: FontWeight.w700,
                    color: sel ? Colors.white : const Color(0xFF3D4A42))),
              ),
            ),
          ),
        );

    Widget cab(String t, {bool der = false, int flex = 1}) => Expanded(
          flex: flex,
          child: Text(t.toUpperCase(),
              textAlign: der ? TextAlign.right : TextAlign.left,
              style: gf(size: 10, w: FontWeight.w700, color: _D.second,
                  ls: 0.6)),
        );

    return _tarjeta(
      titulo: _titulo(Icons.receipt_long_outlined, 'Movimientos del mes',
          '${datos.gastos.length} registro${datos.gastos.length == 1 ? '' : 's'}'),
      hijo: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (cats.isNotEmpty)
          Wrap(children: [
            filtro('Todos', datos.categoria == null,
                () => acciones.onCategoria(null)),
            for (final c in cats)
              filtro(c, datos.categoria == c, () => acciones.onCategoria(c)),
          ]),
        const SizedBox(height: 6),
        if (datos.error != null)
          _vacio(datos.error!, Icons.error_outline_rounded)
        else if (datos.cargando && datos.gastos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator(
                strokeWidth: 2.5, color: _D.greenDark)),
          )
        else if (filas.isEmpty)
          _vacio('Sin gastos en este mes. Registra el primero con '
              '“Registrar gasto”.', Icons.receipt_long_outlined)
        else ...[
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              cab('Fecha'),
              cab('Categoría', flex: 2),
              cab('Detalle', flex: 4),
              cab('Tienda', flex: 2),
              cab('Pago', flex: 2),
              cab('Monto', der: true, flex: 2),
            ]),
          ),
          for (final g in filas) _filaTabla(g),
        ],
      ]),
    );
  }

  Widget _filaTabla(GastoItem g) {
    final (color, _) = estiloCategoria(g.categoria);
    final hoy = datos.hoy ?? DateTime.now();
    final desglose = desgloseNomina(g);
    return InkWell(
      onTap: () => acciones.onGasto(g),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(fechaCorta(g.fecha, hoy),
              style: gf(size: 12.5))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(g.categoria.toUpperCase(),
                    style: gf(size: 10, w: FontWeight.w800, color: color,
                        ls: 0.3)),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tituloGasto(g),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: gf(size: 12.5, w: FontWeight.w700)),
              if (desglose != null)
                Text(desglose, style: gf(size: 11, color: _D.second)),
              if (!g.esNomina && g.registradoPor.isNotEmpty)
                Text('Registró: ${g.registradoPor}',
                    style: gf(size: 11, color: _D.faint)),
            ]),
          ),
          Expanded(flex: 2, child: Text(g.tiendaNombre,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: gf(size: 12.5))),
          Expanded(
            flex: 2,
            child: Wrap(spacing: 4, runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(_metodo(g), style: gf(size: 12)),
              if (g.deCaja)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('CAJA', style: gf(size: 9.5, w: FontWeight.w800,
                      color: const Color(0xFFC2410C))),
                ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(pesos(g.monto),
                textAlign: TextAlign.right,
                style: gf(size: 13, w: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }

  Widget _porCategoria() {
    final cats = datos.panel.porCategoria;
    final total = datos.panel.total;
    return _tarjeta(
      titulo: _titulo(Icons.donut_large_rounded, 'Por categoría',
          datos.tituloMes),
      hijo: cats.isEmpty
          ? _vacio('Sin datos', Icons.donut_large_rounded)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 12,
                  child: Row(children: [
                    for (final (c, t, _) in cats)
                      if (t > 0)
                        Expanded(
                          flex: (t / total * 1000).round().clamp(1, 1000),
                          child: Container(color: estiloCategoria(c).$1),
                        ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              for (final (c, t, n) in cats)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _D.border),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Icon(estiloCategoria(c).$2, size: 16,
                          color: estiloCategoria(c).$1),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c,
                          style: gf(size: 13, w: FontWeight.w700))),
                      Text(pesos(t), style: gf(size: 13, w: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: total > 0 ? t / total : 0,
                        minHeight: 5,
                        color: estiloCategoria(c).$1,
                        backgroundColor: const Color(0xFFF1F5F9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                          '${porcentaje(t, total)} · '
                          '$n registro${n == 1 ? '' : 's'}',
                          style: gf(size: 10.5, color: _D.second)),
                    ),
                  ]),
                ),
            ]),
    );
  }

  Widget _vacio(String t, IconData i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(children: [
            Icon(i, size: 30, color: _D.faint),
            const SizedBox(height: 8),
            Text(t, textAlign: TextAlign.center,
                style: gf(size: 12.5, color: _D.second)),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// CELULAR — paleta verde claro
// ══════════════════════════════════════════════════════════════

class _M {
  static const fondo   = Color(0xFFF0FDF4);
  static const borde   = Color(0xFFDCF0E4);
  static const verde   = Color(0xFF059669);
  static const verdeOs = Color(0xFF047857);
  static const verde50 = Color(0xFFECFDF5);
  static const turq    = Color(0xFF0D9488);
  static const gris    = Color(0xFF6B7280);
}

class GastosMovil extends StatelessWidget {
  final DatosGastos    datos;
  final AccionesGastos acciones;
  const GastosMovil({super.key, required this.datos, required this.acciones});

  @override
  Widget build(BuildContext context) {
    final hoy = datos.hoy ?? DateTime.now();
    final filas = datos.visibles;
    final items = <Widget>[];
    String? dia;
    for (final g in filas) {
      final d = fechaCorta(g.fecha, hoy);
      if (d != dia) {
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(4, items.isEmpty ? 4 : 12, 4, 6),
          child: Text(d.toUpperCase(),
              style: gf(size: 10.5, w: FontWeight.w800, color: _M.turq,
                  ls: 0.9)),
        ));
        dia = d;
      }
      items.add(_fila(g));
    }

    return Stack(children: [
      Container(
        color: _M.fondo,
        child: RefreshIndicator(
          color: _M.verde,
          onRefresh: acciones.onRefrescar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 100),
            children: [
              _cabecera(),
              const SizedBox(height: 12),
              _tarjetas(),
              if (datos.categoriasDelMes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _filtros(),
              ],
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: datos.error != null
                    ? _vacio(datos.error!, Icons.error_outline_rounded)
                    : datos.cargando && datos.gastos.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: _M.verde)))
                        : filas.isEmpty
                            ? _vacio('Sin gastos en este mes.\nToca + para '
                                'registrar el primero.',
                                Icons.receipt_long_outlined)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: items),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: SafeArea(
          child: FloatingActionButton(
            onPressed: acciones.onRegistrar,
            backgroundColor: _M.verde,
            foregroundColor: Colors.white,
            tooltip: 'Registrar',
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ),
    ]);
  }

  Widget _cabecera() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Gastos y nómina',
                  style: gf(size: 19, w: FontWeight.w800)),
            ),
            if (datos.tiendas.length > 1)
              PopupMenuButton<int?>(
                tooltip: 'Tienda',
                onSelected: acciones.onTienda,
                itemBuilder: (_) => [
                  const PopupMenuItem<int?>(
                      value: null, child: Text('Todas las tiendas')),
                  for (final t in datos.tiendas)
                    PopupMenuItem<int?>(value: t.id, child: Text(t.nombre)),
                ],
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _M.verde50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.storefront_outlined, size: 14,
                        color: _M.verdeOs),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                          datos.tienda == null ? 'Todas' : datos.nombreTienda,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: gf(size: 11, w: FontWeight.w700,
                              color: _M.verdeOs)),
                    ),
                    const Icon(Icons.expand_more_rounded, size: 16,
                        color: _M.verdeOs),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _flecha(Icons.chevron_left_rounded, () => acciones.onMes(-1)),
            Expanded(
              child: Text(datos.tituloMes,
                  textAlign: TextAlign.center,
                  style: gf(size: 14, w: FontWeight.w800, color: _M.verdeOs)),
            ),
            _flecha(Icons.chevron_right_rounded,
                datos.esMesActual ? null : () => acciones.onMes(1)),
          ]),
        ]),
      );

  Widget _flecha(IconData i, VoidCallback? onTap) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 36, height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _M.borde),
            ),
            child: Icon(i, size: 20,
                color: onTap == null ? const Color(0xFFCBD5E1) : _M.verdeOs),
          ),
        ),
      );

  /// Mismo estilo de las tarjetas del inicio en el celular: blancas, borde
  /// verde menta, franja de color arriba e ícono en su cuadrito.
  Widget _tarjetas() {
    final p = datos.panel;
    Widget t(String titulo, String valor, String sub, IconData icono,
            List<Color> franja, Color iconoFondo, Color iconoColor) =>
        Container(
          width: 200,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: franja),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13), topRight: Radius.circular(13)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: gf(size: 10.5, w: FontWeight.w600,
                                  color: _M.verdeOs, ls: 0.2)),
                        ),
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: iconoFondo,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(icono, size: 15, color: iconoColor),
                        ),
                      ]),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(datos.cargando ? '—' : valor,
                            style: gf(size: 20, w: FontWeight.w800,
                                color: const Color(0xFF064E3B), h: 1.1)),
                      ),
                      Text(sub,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: gf(size: 10.5, color: _M.gris)),
                    ]),
              ),
            ),
          ]),
        );
    final variacion = p.variacionPct == null
        ? '${p.cantidad} registros'
        : '${p.variacionPct! > 0 ? '+' : ''}'
            '${p.variacionPct!.toStringAsFixed(0)} % vs mes anterior';
    const verde = [Color(0xFF059669), Color(0xFF10B981)];
    const turquesa = [Color(0xFF0D9488), Color(0xFF14B8A6)];
    const ambar = [Color(0xFFF59E0B), Color(0xFFF97316)];
    return SizedBox(
      height: 116,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          t('Gastos del mes', pesos(p.total), variacion,
              Icons.payments_outlined, verde,
              const Color(0xFFD1FAE5), const Color(0xFF059669)),
          t('Nómina', pesos(p.nominaTotal),
              '${p.nominaPagos} pago${p.nominaPagos == 1 ? '' : 's'} · '
              '${p.nominaPersonas} persona${p.nominaPersonas == 1 ? '' : 's'}',
              Icons.badge_outlined, turquesa,
              const Color(0xFFCCFBF1), const Color(0xFF0D9488)),
          t('Arriendo y servicios', pesos(p.arriendoServicios),
              'Arriendo, luz, agua, internet',
              Icons.storefront_outlined, verde,
              const Color(0xFFD1FAE5), const Color(0xFF059669)),
          t('Salió de la caja', pesos(p.deCaja), 'Ya descontado en los cierres',
              Icons.point_of_sale_outlined, ambar,
              const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _filtros() {
    Widget chip(String t, bool sel, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: sel ? _M.verde : Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _M.verde : _M.borde, width: 1.3),
                ),
                child: Text(t, style: gf(size: 12, w: FontWeight.w700,
                    color: sel ? Colors.white : const Color(0xFF334155))),
              ),
            ),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        chip('Todos', datos.categoria == null, () => acciones.onCategoria(null)),
        for (final c in datos.categoriasDelMes)
          chip(c, datos.categoria == c, () => acciones.onCategoria(c)),
      ]),
    );
  }

  Widget _fila(GastoItem g) {
    final (color, icono) = estiloCategoria(g.categoria);
    final sub = [
      g.esNomina ? 'Nómina' : g.categoria,
      if (datos.tienda == null) g.tiendaNombre,
      _metodo(g),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => acciones.onGasto(g),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _M.borde),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tituloGasto(g),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: gf(size: 13, w: FontWeight.w700, h: 1.25)),
                  Text(sub,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: gf(size: 11, color: _M.gris)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(pesos(g.monto), style: gf(size: 13.5, w: FontWeight.w800)),
                if (g.deCaja)
                  Text('DE LA CAJA', style: gf(size: 8.5, w: FontWeight.w800,
                      color: const Color(0xFFC2410C), ls: 0.3)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _vacio(String t, IconData i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5), shape: BoxShape.circle),
            child: Icon(i, size: 26, color: _M.verde),
          ),
          const SizedBox(height: 10),
          Text(t, textAlign: TextAlign.center,
              style: gf(size: 12.5, color: _M.gris, h: 1.4)),
        ]),
      );
}

// ── ¿Gasto o nómina? ──────────────────────────────────────────

class OpcionesRegistro extends StatelessWidget {
  final VoidCallback onGasto;
  final VoidCallback onNomina;
  const OpcionesRegistro({super.key, required this.onGasto, required this.onNomina});

  @override
  Widget build(BuildContext context) {
    Widget op(IconData i, Color c, String t, String s, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _M.borde, width: 1.3),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(i, size: 21, color: c),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t, style: gf(size: 14, w: FontWeight.w800)),
                      Text(s, style: gf(size: 11.5, color: _M.gris)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFCBD5E1)),
                ]),
              ),
            ),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      Text('¿Qué vas a registrar?', style: gf(size: 17, w: FontWeight.w800)),
      const SizedBox(height: 12),
      op(Icons.receipt_long_outlined, _M.verde, 'Gasto',
          'Arriendo, servicios, aseo, insumos…', onGasto),
      op(Icons.badge_outlined, const Color(0xFF0369A1), 'Nómina',
          'Quincenas, pagos y desprendibles', onNomina),
    ]);
  }
}

// ── Detalle de un gasto (con eliminar) ────────────────────────

class DetalleGasto extends StatefulWidget {
  final GastoItem gasto;
  final Color     acento;
  final VoidCallback onCerrar;
  final Future<String?> Function() onEliminar;
  final DateTime? hoy;
  const DetalleGasto({
    super.key,
    required this.gasto,
    required this.onCerrar,
    required this.onEliminar,
    this.acento = const Color(0xFF059669),
    this.hoy,
  });

  @override
  State<DetalleGasto> createState() => _DetalleGastoState();
}

class _DetalleGastoState extends State<DetalleGasto> {
  bool    _confirmar = false;
  bool    _borrando  = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final g = widget.gasto;
    final (color, icono) = estiloCategoria(g.categoria);
    final hoy = widget.hoy ?? DateTime.now();
    Widget dato(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110,
                child: Text(k, style: gf(size: 12.5, color: _M.gris))),
            Expanded(child: Text(v, style: gf(size: 13, w: FontWeight.w700))),
          ]),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tituloGasto(g), style: gf(size: 15.5, w: FontWeight.w800)),
              Text(g.categoria, style: gf(size: 12, color: _M.gris)),
            ]),
          ),
          Text(pesos(g.monto), style: gf(size: 17, w: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 6),
        if (g.esNomina && g.salario != null) ...[
          dato('Salario', pesos(g.salario!)),
          if ((g.extras ?? 0) > 0) dato('Extras', pesos(g.extras!)),
          if ((g.descuentos ?? 0) > 0) dato('Descuentos', pesos(g.descuentos!)),
        ],
        if (!g.esNomina && g.descripcion.isNotEmpty) dato('Detalle', g.descripcion),
        dato('Fecha', fechaCorta(g.fecha, hoy)),
        dato('Tienda', g.tiendaNombre),
        dato('Pago', _metodo(g)),
        dato('De la caja', g.deCaja ? 'Sí, se descontó del cierre' : 'No'),
        if (g.registradoPor.isNotEmpty) dato('Registró', g.registradoPor),
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!, style: gf(size: 12, w: FontWeight.w600,
                color: const Color(0xFFB91C1C))),
          ),
        const SizedBox(height: 14),
        if (_confirmar)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¿Eliminar este gasto? No se puede deshacer.',
                  style: gf(size: 12.5, w: FontWeight.w700,
                      color: const Color(0xFFB91C1C))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _borrando
                        ? null
                        : () => setState(() => _confirmar = false),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C)),
                    onPressed: _borrando
                        ? null
                        : () async {
                            setState(() {
                              _borrando = true;
                              _error = null;
                            });
                            final e = await widget.onEliminar();
                            if (!mounted) return;
                            setState(() {
                              _borrando = false;
                              _error = e;
                              if (e != null) _confirmar = false;
                            });
                          },
                    child: Text(_borrando ? 'Eliminando…' : 'Sí, eliminar'),
                  ),
                ),
              ]),
            ]),
          )
        else
          Row(children: [
            TextButton.icon(
              onPressed: () => setState(() => _confirmar = true),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFB91C1C), size: 18),
              label: Text('Eliminar', style: gf(size: 13, w: FontWeight.w700,
                  color: const Color(0xFFB91C1C))),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.acento),
              onPressed: widget.onCerrar,
              child: const Text('Cerrar'),
            ),
          ]),
      ]),
    );
  }
}
