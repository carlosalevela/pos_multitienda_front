import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

import '../../providers/contabilidad_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/empleado_service.dart';

import 'tabs/tab_resumen.dart';
import 'tabs/tab_top_productos.dart';
import 'tabs/tab_operaciones.dart';
import 'tabs/tab_pl.dart';
import 'tabs/tab_top_clientes.dart';
import 'tabs/tab_comparativo.dart';
import 'tabs/tab_ventas.dart';
import 'tabs/tab_vendedores.dart';
import 'tabs/tab_rentabilidad.dart';
import 'tabs/tab_cartera.dart';

class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});
  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;
  final _fmt = NumberFormat('#,##0', 'es_CO');

  List<Map<String, dynamic>> _tiendas        = [];
  int?                        _tiendaAdmin;
  bool                        _cargandoTiendas = false;


  // ── LIFECYCLE ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final auth  = context.read<AuthProvider>();
    final esCaj = auth.rol == 'cajero';

    _tabCtrl = TabController(length: esCaj ? 3 : 10, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cont = context.read<ContabilidadProvider>();
      final tid  = auth.tiendaId == 0 ? null : auth.tiendaId;

      if (auth.esSuperadmin || auth.esAdmin || auth.esSupervisor) {
        setState(() => _cargandoTiendas = true);
        try {
          final tiendas = await EmpleadoService().getTiendas();
          if (mounted) setState(() { _tiendas = tiendas; _cargandoTiendas = false; });
        } catch (e) {
          debugPrint('❌ Error cargando tiendas: $e');
          if (mounted) setState(() => _cargandoTiendas = false);
        }
      }

      final tiendaEfectiva = (auth.esSuperadmin || auth.esAdmin || auth.esSupervisor) ? _tiendaAdmin : tid;
      _cargarTodo(cont, auth, tiendaEfectiva);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── HELPERS ────────────────────────────────────────

  int? get _tiendaId {
    final auth = context.read<AuthProvider>();
    if (auth.esSuperadmin || auth.esAdmin || auth.esSupervisor) return _tiendaAdmin;
    return auth.tiendaId == 0 ? null : auth.tiendaId;
  }

  void _cargarTodo(
      ContabilidadProvider cont, AuthProvider auth, int? tiendaId) {
    cont.cargarResumenDiario(tiendaId: tiendaId);
    cont.cargarTopProductos(tiendaId: tiendaId);
  }

  void _recargarTodo() {
    final cont = context.read<ContabilidadProvider>();
    final auth = context.read<AuthProvider>();
    _cargarTodo(cont, auth, _tiendaId);
  }

  String _labelTienda(AuthProvider auth) {
    if (auth.esSuperadmin || auth.esAdmin || auth.esSupervisor) {
      if (_tiendaAdmin == null) return 'Todas las tiendas';
      final t = _tiendas.firstWhere(
        (t) => t['id'] == _tiendaAdmin,
        orElse: () => <String, dynamic>{},
      );
      return t['nombre']?.toString() ?? 'Tienda';
    }
    return auth.tiendaNombre.isNotEmpty ? auth.tiendaNombre : 'Mi tienda';
  }

  // ── BUILD ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cont  = context.watch<ContabilidadProvider>();
    final auth  = context.watch<AuthProvider>();
    final esCaj = auth.rol == 'cajero';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header + Tabs integrados (fondo blanco) ─────────
        Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Fila del título
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(children: [

                  // Ícono
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.mintLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: AppColors.secondary, size: 20),
                  ),
                  const SizedBox(width: 12),

                  // Título + tienda activa
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contabilidad',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface)),
                        Row(children: [
                          const Icon(Icons.store_rounded,
                              size: 11, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            _labelTienda(auth),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  // Selector de tienda (superadmin / admin / supervisor)
                  if (auth.esSuperadmin || auth.esAdmin || auth.esSupervisor)
                    _cargandoTiendas
                        ? _storeSelectorSkeleton()
                        : _tiendas.isNotEmpty
                            ? _storeSelector()
                            : const SizedBox.shrink(),

                ]),
              ),

              // Banners (success/error)
              if (cont.successMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _banner(cont.successMsg,
                      isError: false, onClose: cont.limpiarMensajes),
                ),
              if (cont.errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _banner(cont.errorMsg,
                      isError: true, onClose: cont.limpiarMensajes),
                ),

              // ── TabBar estilo underline ─────────────────
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                labelColor: AppColors.secondary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 2.5, color: AppColors.secondary),
                  insets: EdgeInsets.symmetric(horizontal: 8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: AppColors.outlineVariant,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: _buildTabs(esCaj),
              ),

            ],
          ),
        ),

        // ── Área de contenido ──────────────────────────────
        Expanded(
          child: Container(
            color: AppColors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TabBarView(
                controller: _tabCtrl,
                children: _buildViews(esCaj, cont, auth),
              ),
            ),
          ),
        ),

      ],
    );
  }

  // ── STORE SELECTOR ─────────────────────────────────

  Widget _storeSelectorSkeleton() {
    return Container(
      width: 160,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Text('Cargando tiendas…',
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _storeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.store_rounded, size: 15, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 6),
        DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: _tiendaAdmin,
            isDense: true,
            dropdownColor: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.onSurfaceVariant),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.public_rounded, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text('Todas las tiendas',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary)),
                ]),
              ),
              ..._tiendas.map((t) => DropdownMenuItem<int?>(
                    value: t['id'] as int?,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.storefront_rounded,
                          size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(t['nombre'] ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.onSurface)),
                    ]),
                  )),
            ],
            onChanged: (val) {
              setState(() => _tiendaAdmin = val);
              _recargarTodo();
            },
          ),
        ),
      ]),
    );
  }

  // ── TABS — etiquetas ───────────────────────────────
  // cajero : [0]Resumen  [1]Productos  [2]Operaciones
  // admin  : [0]Resumen  [1]Análisis   [2]Operaciones  [3]Productos  [4]Clientes  [5]Tiendas

  List<Tab> _buildTabs(bool esCaj) {
    const resumen     = Tab(text: 'Resumen');
    const analisis    = Tab(text: 'Análisis P&L');
    const operacion   = Tab(text: 'Operaciones');
    const productos   = Tab(text: 'Top Productos');
    const clientes    = Tab(text: 'Clientes');
    const comparativo   = Tab(text: 'Tiendas');
    const ventas        = Tab(text: 'Ventas');
    const vendedores    = Tab(text: 'Vendedores');
    const rentabilidad  = Tab(text: 'Rentabilidad');
    const cartera = Tab(text: 'Cartera');
    return esCaj
        ? [resumen, productos, operacion]
        : [resumen, analisis, operacion, productos, clientes, comparativo,
           ventas, vendedores, rentabilidad, cartera];
  }

  // ── TABS — contenido ───────────────────────────────

  List<Widget> _buildViews(
      bool esCaj, ContabilidadProvider cont, AuthProvider auth) {

    final tabResumen = TabResumen(
      cont: cont, fmt: _fmt, tiendaId: _tiendaId, esCajero: esCaj,
    );
    final tabProductos = TabTopProductos(cont: cont, fmt: _fmt);
    final tabOperaciones = TabOperaciones(
      cont:     cont,
      fmt:      _fmt,
      tiendaId: _tiendaId,
      esCajero: esCaj,
      auth:     auth,
    );

    if (esCaj) return [tabResumen, tabProductos, tabOperaciones];

    return [
      tabResumen,
      TabPL(cont: cont, fmt: _fmt, tiendaId: _tiendaId),
      tabOperaciones,
      tabProductos,
      TabTopClientes(fmt: _fmt, tiendaId: _tiendaId),
      TabComparativo(fmt: _fmt),
      TabVentas(tiendaId: _tiendaId, auth: auth),
      TabVendedores(tiendaId: _tiendaId),
      TabRentabilidad(tiendaId: _tiendaId),
      TabCartera(tiendaId: _tiendaId),
    ];
  }

  // ── BANNER éxito / error ───────────────────────────

  Widget _banner(String msg,
      {required bool isError, required VoidCallback onClose}) {
    final color = isError ? AppColors.error : AppColors.secondary;
    final bg    = isError ? AppColors.errorContainer : AppColors.mintLight;
    final icon      = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.inter(color: color, fontSize: 13)),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded,
              size: 16, color: color.withValues(alpha: 0.7)),
          onPressed: onClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}
