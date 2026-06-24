import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/contabilidad_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/empleado_service.dart';

import 'tabs/tab_resumen.dart';
import 'tabs/tab_top_productos.dart';
import 'tabs/tab_operaciones.dart';
import 'tabs/tab_pl.dart';

class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});
  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;
  final _fmt = NumberFormat('#,##0', 'es_CO');

  List<Map<String, dynamic>> _tiendas   = [];
  int?                        _tiendaAdmin;

  // Design tokens
  static const _emerald    = Color(0xFF10B981);
  static const _emeraldBg  = Color(0xFFECFDF5);
  static const _onSurface  = Color(0xFF111827);
  static const _onSurfVar  = Color(0xFF6B7280);
  static const _border     = Color(0xFFE5E7EB);
  static const _bgContent  = Color(0xFFF3F4F6);

  // ── LIFECYCLE ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final auth  = context.read<AuthProvider>();
    final esCaj = auth.rol == 'cajero';

    _tabCtrl = TabController(length: esCaj ? 3 : 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cont = context.read<ContabilidadProvider>();
      final tid  = auth.tiendaId == 0 ? null : auth.tiendaId;

      if (auth.rol == 'admin') {
        try {
          final tiendas = await EmpleadoService().getTiendas();
          if (mounted) setState(() => _tiendas = tiendas);
        } catch (e) {
          debugPrint('❌ Error cargando tiendas: $e');
        }
      }

      final tiendaEfectiva = auth.rol == 'admin' ? _tiendaAdmin : tid;
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
    if (auth.rol == 'admin') return _tiendaAdmin;
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
                      color: _emeraldBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: _emerald, size: 20),
                  ),
                  const SizedBox(width: 12),

                  // Título + subtítulo
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Accounting Dashboard',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _onSurface)),
                      Text('Resumen financiero',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _onSurfVar)),
                    ],
                  ),
                  const Spacer(),

                  // Selector de tienda (solo admin)
                  if (auth.rol == 'admin' && _tiendas.isNotEmpty)
                    _storeSelector(),

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
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                labelColor: _emerald,
                unselectedLabelColor: _onSurfVar,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 2.5, color: _emerald),
                  insets: EdgeInsets.symmetric(horizontal: 8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: _border,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: _buildTabs(esCaj),
              ),

            ],
          ),
        ),

        // ── Área de contenido ──────────────────────────────
        Expanded(
          child: Container(
            color: _bgContent,
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

  Widget _storeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.store_rounded, size: 15, color: _onSurfVar),
        const SizedBox(width: 6),
        DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: _tiendaAdmin,
            isDense: true,
            dropdownColor: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: _onSurfVar),
            style: GoogleFonts.poppins(fontSize: 13, color: _onSurface),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.public_rounded, size: 14, color: _emerald),
                  const SizedBox(width: 6),
                  Text('Todas las tiendas',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _emerald)),
                ]),
              ),
              ..._tiendas.map((t) => DropdownMenuItem<int?>(
                    value: t['id'] as int?,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.storefront_rounded,
                          size: 14, color: _onSurfVar),
                      const SizedBox(width: 6),
                      Text(t['nombre'] ?? '',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: _onSurface)),
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
  // admin  : [0]Resumen  [1]Análisis   [2]Operaciones  [3]Productos

  List<Tab> _buildTabs(bool esCaj) {
    const resumen   = Tab(text: 'Resumen');
    const analisis  = Tab(text: 'Análisis P&L');
    const operacion = Tab(text: 'Operaciones');
    const productos = Tab(text: 'Top Productos');
    return esCaj
        ? [resumen, productos, operacion]
        : [resumen, analisis, operacion, productos];
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
    ];
  }

  // ── BANNER éxito / error ───────────────────────────

  Widget _banner(String msg,
      {required bool isError, required VoidCallback onClose}) {
    const green     = Color(0xFF10B981);
    const greenBg   = Color(0xFFECFDF5);
    const redColor  = Color(0xFFEF4444);
    const redBg     = Color(0xFFFEF2F2);
    final color     = isError ? redColor : green;
    final bg        = isError ? redBg    : greenBg;
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
              style: GoogleFonts.poppins(color: color, fontSize: 13)),
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
