import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/contabilidad_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../services/empleado_service.dart';

import 'tabs/tab_resumen_dia.dart';
import 'tabs/tab_mensual.dart';
import 'tabs/tab_top_productos.dart';
import 'tabs/tab_gastos.dart';
import 'tabs/tab_anual.dart';

class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});
  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen>
    with SingleTickerProviderStateMixin {

  TabController? _tabCtrl;
  final _fmt = NumberFormat('#,##0', 'es_CO');

  int  _anioSel   = DateTime.now().year;
  int  _mesSel    = DateTime.now().month;
  int  _anioAnual = DateTime.now().year;

  final _meses = ['Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];

  List<Map<String, dynamic>> _tiendas    = [];
  int?                        _tiendaAdmin;

  // ── LIFECYCLE ─────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final auth  = context.read<AuthProvider>();
    final esCaj = auth.rol == 'cajero';

    // cajero: 3 tabs | admin/supervisor: 5 tabs
    _tabCtrl = TabController(length: esCaj ? 3 : 5, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cont = context.read<ContabilidadProvider>();
      final tid  = auth.tiendaId == 0 ? null : auth.tiendaId;

      if (auth.rol == 'admin') {
        final tiendas = await EmpleadoService().getTiendas();
        if (mounted) setState(() => _tiendas = tiendas);
      }

      final tiendaEfectiva = auth.rol == 'admin' ? _tiendaAdmin : tid;
      _cargarTodo(cont, auth, tiendaEfectiva);
    });
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  // ── HELPERS ───────────────────────────────────────
  int? get _tiendaId {
    final auth = context.read<AuthProvider>();
    if (auth.rol == 'admin') return _tiendaAdmin;
    return auth.tiendaId == 0 ? null : auth.tiendaId;
  }

  void _cargarTodo(ContabilidadProvider cont, AuthProvider auth, int? tiendaId) {
    final esCaj = auth.rol == 'cajero';
    cont.cargarResumenDiario(tiendaId: tiendaId);
    cont.cargarTopProductos(tiendaId: tiendaId);
    cont.cargarGastos(tiendaId: tiendaId);
    if (!esCaj) {
      cont.cargarResumenMensual(tiendaId: tiendaId, anio: _anioSel, mes: _mesSel);
      cont.cargarResumenAnual(tiendaId: tiendaId, anio: _anioAnual);
    }
  }

  void _recargarTodo() {
    final cont = context.read<ContabilidadProvider>();
    final auth = context.read<AuthProvider>();
    _cargarTodo(cont, auth, _tiendaId);
  }

  // ── BUILD ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cont  = context.watch<ContabilidadProvider>();
    final auth  = context.watch<AuthProvider>();
    final esCaj = auth.rol == 'cajero';

    if (_tabCtrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _buildHeader(auth),
          const SizedBox(height: 16),

          if (cont.successMsg.isNotEmpty)
            _banner(cont.successMsg, isError: false, onClose: cont.limpiarMensajes),
          if (cont.errorMsg.isNotEmpty)
            _banner(cont.errorMsg, isError: true, onClose: cont.limpiarMensajes),

          // ── TabBar ───────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelStyle:           GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
              labelColor:           const Color(Constants.primaryColor),
              unselectedLabelColor: Colors.grey.shade500,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(Constants.primaryColor).withOpacity(0.1)),
              indicatorSize: TabBarIndicatorSize.tab,
              padding: const EdgeInsets.all(4),
              tabs: _buildTabs(esCaj),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _buildViews(esCaj, cont, auth, context),
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────
  Widget _buildHeader(AuthProvider auth) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(Constants.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.bar_chart_rounded,
            color: Color(Constants.primaryColor)),
      ),
      const SizedBox(width: 12),
      Text('Contabilidad',
        style: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.bold,
          color: const Color(0xFF1A1A2E))),
      const Spacer(),

      if (auth.rol == 'admin' && _tiendas.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.store_rounded, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _tiendaAdmin,
                isDense: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: Colors.grey.shade500),
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.public_rounded, size: 14,
                          color: Color(Constants.primaryColor)),
                      const SizedBox(width: 6),
                      Text('Todas las tiendas',
                        style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: const Color(Constants.primaryColor))),
                    ]),
                  ),
                  ..._tiendas.map((t) => DropdownMenuItem<int?>(
                    value: t['id'] as int?,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.storefront_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(t['nombre'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 13)),
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
        ),
    ]);
  }

  // ── TABS — etiquetas ──────────────────────────────
  // cajero : [0]Hoy  [1]Top  [2]Gastos
  // otros  : [0]Hoy  [1]Mensual  [2]Top  [3]Gastos  [4]Anual
  List<Tab> _buildTabs(bool esCaj) {
    final all = [
      const Tab(icon: Icon(Icons.today_rounded,          size: 18), text: 'Hoy'),
      const Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Mensual'),
      const Tab(icon: Icon(Icons.leaderboard_rounded,    size: 18), text: 'Top Productos'),
      const Tab(icon: Icon(Icons.receipt_long_rounded,   size: 18), text: 'Gastos'),
      const Tab(icon: Icon(Icons.bar_chart_rounded,      size: 18), text: 'Anual'),
      
    ];
    return esCaj ? [all[0], all[2], all[3]] : all;
  }

  // ── TABS — contenido ──────────────────────────────
  // ⚠️ El orden DEBE coincidir exactamente con _buildTabs
  List<Widget> _buildViews(
      bool esCaj, ContabilidadProvider cont,
      AuthProvider auth, BuildContext ctx) {


    final tabHoy = TabResumenDia(
      cont: cont, fmt: _fmt, tiendaId: _tiendaId,
    );
    final tabTop = TabTopProductos(
      cont: cont, fmt: _fmt,
    );
    final tabGastos = TabGastos(
      cont: cont, fmt: _fmt,
      tiendaId: _tiendaId, esCajero: esCaj,
      auth: auth, dialogContext: ctx,
    );

    if (esCaj) {
      return [tabHoy, tabTop, tabGastos];
    }

    return [
      tabHoy,
      TabMensual(
        cont: cont, fmt: _fmt, tiendaId: _tiendaId,
        anio: _anioSel, mes: _mesSel, meses: _meses,
        onCambiarMes: (a, m) {
          setState(() { _anioSel = a; _mesSel = m; });
          cont.cargarResumenMensual(tiendaId: _tiendaId, anio: a, mes: m);
        },
      ),
      tabTop,
      tabGastos,
      TabAnual(
        cont: cont, fmt: _fmt, tiendaId: _tiendaId,
        anioSel: _anioAnual,
        onCambiarAnio: (a) {
          setState(() => _anioAnual = a);
          cont.cargarResumenAnual(tiendaId: _tiendaId, anio: a);
        },
      ),
    ];
  }

  // ── BANNER éxito / error ──────────────────────────
  Widget _banner(String msg,
      {required bool isError, required VoidCallback onClose}) =>
    Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? const Color(Constants.errorColor).withOpacity(0.1)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isError
            ? const Color(Constants.errorColor).withOpacity(0.3)
            : Colors.green.shade200)),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? const Color(Constants.errorColor)
              : Colors.green.shade700, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: GoogleFonts.poppins(
          color: isError ? const Color(Constants.errorColor)
              : Colors.green.shade700, fontSize: 13))),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 16),
          onPressed: onClose, color: Colors.grey),
      ]),
    );
}