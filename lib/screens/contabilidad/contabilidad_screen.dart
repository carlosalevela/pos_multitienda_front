import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/contabilidad_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../models/contabilidad_models.dart';
import '../../services/empleado_service.dart'; // ✅ para getTiendas()

class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});
  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen>
    with SingleTickerProviderStateMixin {

  TabController? _tabCtrl;
  final _fmt = NumberFormat('#,##0', 'es_CO');

  int _anioSel = DateTime.now().year;
  int _mesSel  = DateTime.now().month;
  final _meses = ['Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];

  // ✅ NUEVO — para el selector de tienda del admin
  List<Map<String, dynamic>> _tiendas     = [];
  int?                        _tiendaAdmin; // null = todas las tiendas

  @override
  void initState() {
    super.initState();
    final auth  = context.read<AuthProvider>();
    final esCaj = auth.rol == 'cajero';

    _tabCtrl = TabController(length: esCaj ? 3 : 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cont = context.read<ContabilidadProvider>();
      final tid  = auth.tiendaId == 0 ? null : auth.tiendaId;

      // ✅ Admin carga lista de tiendas
      if (auth.rol == 'admin') {
        final tiendas = await EmpleadoService().getTiendas();
        if (mounted) {
          setState(() => _tiendas = tiendas);
        }
      }

      // Tienda efectiva: admin usa su selector, otros usan la suya
      final tiendaEfectiva = auth.rol == 'admin' ? _tiendaAdmin : tid;

      cont.cargarResumenDiario(tiendaId: tiendaEfectiva);
      if (!esCaj) cont.cargarResumenMensual(
          tiendaId: tiendaEfectiva, anio: _anioSel, mes: _mesSel);
      cont.cargarTopProductos(tiendaId: tiendaEfectiva);
      cont.cargarGastos(tiendaId: tiendaEfectiva); // ✅ sin filtro fecha
    });
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  // ✅ tiendaId respeta el selector admin
  int? get _tiendaId {
    final auth = context.read<AuthProvider>();
    if (auth.rol == 'admin') return _tiendaAdmin; // null = todas
    return auth.tiendaId == 0 ? null : auth.tiendaId;
  }

  // ✅ Recarga todo al cambiar de tienda
  void _recargarTodo() {
    final cont  = context.read<ContabilidadProvider>();
    final auth  = context.read<AuthProvider>();
    final esCaj = auth.rol == 'cajero';
    cont.cargarResumenDiario(tiendaId: _tiendaId);
    if (!esCaj) cont.cargarResumenMensual(
        tiendaId: _tiendaId, anio: _anioSel, mes: _mesSel);
    cont.cargarTopProductos(tiendaId: _tiendaId);
    cont.cargarGastos(tiendaId: _tiendaId);
  }

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

          // ── Header ────────────────────────────────
          Row(children: [
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

            // ✅ Selector de tienda — solo admin
            if (auth.rol == 'admin' && _tiendas.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6, offset: const Offset(0, 2))]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.store_rounded, size: 15,
                      color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _tiendaAdmin,
                      isDense: true,
                      icon: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: Colors.grey.shade500),
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.black87),
                      items: [
                        // Opción "Todas las tiendas"
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Row(mainAxisSize: MainAxisSize.min,
                            children: [
                            const Icon(Icons.public_rounded, size: 14,
                                color: Color(Constants.primaryColor)),
                            const SizedBox(width: 6),
                            Text('Todas las tiendas',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(Constants.primaryColor))),
                          ]),
                        ),
                        // Tiendas individuales
                        ..._tiendas.map((t) => DropdownMenuItem<int?>(
                          value: t['id'] as int?,
                          child: Row(mainAxisSize: MainAxisSize.min,
                            children: [
                            const Icon(Icons.storefront_rounded,
                                size: 14, color: Colors.grey),
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
          ]),
          const SizedBox(height: 16),

          // ── Mensajes ──────────────────────────────
          if (cont.successMsg.isNotEmpty)
            _banner(cont.successMsg,
                isError: false, onClose: cont.limpiarMensajes),
          if (cont.errorMsg.isNotEmpty)
            _banner(cont.errorMsg,
                isError: true, onClose: cont.limpiarMensajes),

          // ── TabBar ────────────────────────────────
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
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13),
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

  List<Tab> _buildTabs(bool esCaj) {
    final all = [
      const Tab(icon: Icon(Icons.today_rounded, size: 18), text: 'Hoy'),
      const Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Mensual'),
      const Tab(icon: Icon(Icons.leaderboard_rounded, size: 18), text: 'Top Productos'),
      const Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Gastos'),
    ];
    return esCaj ? [all[0], all[2], all[3]] : all;
  }

  List<Widget> _buildViews(
      bool esCaj, ContabilidadProvider cont,
      AuthProvider auth, BuildContext ctx) {
    return [
      _TabResumenDia(cont: cont, fmt: _fmt, tiendaId: _tiendaId),
      if (!esCaj) _TabMensual(
        cont: cont, fmt: _fmt, tiendaId: _tiendaId,
        anio: _anioSel, mes: _mesSel, meses: _meses,
        onCambiarMes: (a, m) {
          setState(() { _anioSel = a; _mesSel = m; });
          cont.cargarResumenMensual(tiendaId: _tiendaId, anio: a, mes: m);
        },
      ),
      _TabTopProductos(cont: cont, fmt: _fmt),
      _TabGastos(
        cont: cont, fmt: _fmt,
        tiendaId: _tiendaId, esCajero: esCaj,
        auth: auth, dialogContext: ctx,
      ),
    ];
  }

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
        IconButton(icon: const Icon(Icons.close_rounded, size: 16),
          onPressed: onClose, color: Colors.grey),
      ]),
    );
}

// ──────────────────────────────────────────────────────
// TAB 1 — RESUMEN DEL DÍA
// ──────────────────────────────────────────────────────
// ════════════════════════════════════════════════════
// TAB RESUMEN DÍA — con selector de fecha y recarga
// ════════════════════════════════════════════════════
class _TabResumenDia extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat fmt;
  final int? tiendaId;

  const _TabResumenDia({
    required this.cont,
    required this.fmt,
    required this.tiendaId,
  });

  @override
  State<_TabResumenDia> createState() => _TabResumenDiaState();
}

class _TabResumenDiaState extends State<_TabResumenDia> {
  DateTime _fechaSeleccionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Carga automática al abrir el tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
    });
  }

  void _cargar() {
    widget.cont.cargarResumenDiario(
      tiendaId: widget.tiendaId,
      fecha: _fechaSeleccionada,
    );
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(hoy.year - 1),   // hasta 1 año atrás
      lastDate: hoy,                        // no puede ser futuro
      locale: const Locale('es', 'CO'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color(Constants.primaryColor),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && picked != _fechaSeleccionada) {
      setState(() => _fechaSeleccionada = picked);
      _cargar();
    }
  }

  bool get _esHoy {
    final hoy = DateTime.now();
    return _fechaSeleccionada.year  == hoy.year &&
           _fechaSeleccionada.month == hoy.month &&
           _fechaSeleccionada.day   == hoy.day;
  }

  String get _labelFecha {
    if (_esHoy) return 'Hoy';
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    if (_fechaSeleccionada.year  == ayer.year &&
        _fechaSeleccionada.month == ayer.month &&
        _fechaSeleccionada.day   == ayer.day) return 'Ayer';
    return '${_fechaSeleccionada.day.toString().padLeft(2,'0')}/'
           '${_fechaSeleccionada.month.toString().padLeft(2,'0')}/'
           '${_fechaSeleccionada.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cont = widget.cont;
    final fmt  = widget.fmt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header: selector de fecha + botón recargar ──
        Row(children: [
          // Selector de fecha
          Expanded(
            child: InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(Constants.primaryColor).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(Constants.primaryColor).withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                    size: 16, color: const Color(Constants.primaryColor)),
                  const SizedBox(width: 8),
                  Text(_labelFecha,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14,
                      color: const Color(Constants.primaryColor))),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down_rounded,
                    color: const Color(Constants.primaryColor)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Botón recargar
          Tooltip(
            message: 'Recargar datos',
            child: InkWell(
              onTap: cont.cargando ? null : _cargar,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300)),
                child: cont.cargando
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(Constants.primaryColor)))
                    : const Icon(Icons.refresh_rounded,
                        size: 20, color: Colors.grey),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Contenido ──────────────────────────────────
        Expanded(
          child: _buildContenido(cont, fmt),
        ),
      ],
    );
  }

  Widget _buildContenido(ContabilidadProvider cont, NumberFormat fmt) {
    // Cargando por primera vez
    if (cont.cargando && cont.resumenDiario == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final r = cont.resumenDiario;

    // Sin datos
    if (r == null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.today_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin datos para $_labelFecha',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade400, fontSize: 16)),
          const SizedBox(height: 6),
          Text('No hay ventas registradas este día',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade300, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Recargar', style: GoogleFonts.poppins()),
            onPressed: _cargar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(Constants.primaryColor),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ));
    }

    final utilColor = r.utilidadBruta >= 0
        ? Colors.green.shade700 : Colors.red.shade700;
    final utilBg    = r.utilidadBruta >= 0
        ? Colors.green.shade50  : Colors.red.shade50;

    return RefreshIndicator(
      onRefresh: () async => _cargar(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Indicador de fecha cargada
          Row(children: [
            Text('Resumen del ${r.fecha}',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600, fontSize: 13)),
            if (!_esHoy) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200)),
                child: Text('Histórico',
                  style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
          const SizedBox(height: 16),

          // KPIs
          Row(children: [
            Expanded(child: _kpiCard(
              Icons.trending_up_rounded, 'Ventas totales',
              '\$${fmt.format(r.totalVentas)}',
              '${r.numVentas} transacciones',
              Colors.blue.shade700, Colors.blue.shade50)),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard(
              Icons.money_off_rounded, 'Total gastos',
              '\$${fmt.format(r.totalGastos)}', '',
              Colors.orange.shade700, Colors.orange.shade50)),
          ]),
          const SizedBox(height: 12),

          // Utilidad
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: utilBg, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: utilColor.withOpacity(0.2))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Utilidad bruta',
                    style: GoogleFonts.poppins(color: utilColor, fontSize: 14)),
                  Text('\$${fmt.format(r.utilidadBruta)}',
                    style: GoogleFonts.poppins(
                      color: utilColor, fontSize: 26,
                      fontWeight: FontWeight.bold)),
                ]),
                Icon(r.utilidadBruta >= 0
                    ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: utilColor, size: 40),
              ]),
          ),
          const SizedBox(height: 20),

          // Ventas por método
          if (r.ventasPorMetodo.isNotEmpty) ...[
            Text('Ventas por método de pago',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...r.ventasPorMetodo.map((m) {
              final pct = r.totalVentas > 0
                  ? (m['total'] as num) / r.totalVentas : 0.0;
              return _metodoPago(m['metodo'] ?? '', m['cantidad'] ?? 0,
                  (m['total'] as num).toDouble(), pct, fmt);
            }),
          ],
        ]),
      ),
    );
  }

  // ── Helpers (igual que antes) ────────────────────────
  Widget _kpiCard(IconData icon, String label, String valor,
      String sub, Color color, Color bg) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.poppins(
            color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(valor, style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        if (sub.isNotEmpty)
          Text(sub, style: GoogleFonts.poppins(
              color: Colors.grey.shade500, fontSize: 11)),
      ]),
    );

  Widget _metodoPago(String metodo, int cantidad, double total,
      double pct, NumberFormat fmt) =>
    Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_labelMetodo(metodo),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('\$${fmt.format(total)}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(Constants.primaryColor))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0), minHeight: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation(
                  Color(Constants.primaryColor)),
            ),
          )),
          const SizedBox(width: 8),
          Text('${(pct * 100).toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.grey.shade500)),
        ]),
        Text('$cantidad venta${cantidad != 1 ? "s" : ""}',
          style: GoogleFonts.poppins(
              fontSize: 11, color: Colors.grey.shade500)),
      ]),
    );

  String _labelMetodo(String m) => const {
    'efectivo':      '💵 Efectivo',
    'tarjeta':       '💳 Tarjeta',
    'transferencia': '🏦 Transferencia',
    'mixto':         '🔀 Mixto',
  }[m] ?? m;
}
// ──────────────────────────────────────────────────────
// TAB 2 — RESUMEN MENSUAL
// ──────────────────────────────────────────────────────
class _TabMensual extends StatelessWidget {
  final ContabilidadProvider cont;
  final NumberFormat fmt;
  final int? tiendaId;
  final int anio, mes;
  final List<String> meses;
  final void Function(int, int) onCambiarMes;

  const _TabMensual({
    required this.cont, required this.fmt, required this.tiendaId,
    required this.anio, required this.mes, required this.meses,
    required this.onCambiarMes,
  });

  @override
  Widget build(BuildContext context) {
    if (cont.cargando && cont.resumenMensual == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final r = cont.resumenMensual;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            final nm = mes - 1 <= 0 ? 12 : mes - 1;
            final na = mes - 1 <= 0 ? anio - 1 : anio;
            onCambiarMes(na, nm);
          },
        ),
        Expanded(child: Center(
          child: Text('${meses[mes - 1]} $anio',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16)),
        )),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            final nm = mes + 1 > 12 ? 1 : mes + 1;
            final na = mes + 1 > 12 ? anio + 1 : anio;
            onCambiarMes(na, nm);
          },
        ),
      ]),
      const SizedBox(height: 8),
      if (r == null)
        Expanded(child: Center(child: Text('Sin datos para este mes',
          style: GoogleFonts.poppins(color: Colors.grey.shade400))))
      else
        Expanded(child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _kpiMes('Total ventas',
                  '\$${fmt.format(r.totalVentas)}',
                  Colors.blue.shade700, Colors.blue.shade50)),
              const SizedBox(width: 12),
              Expanded(child: _kpiMes('Total gastos',
                  '\$${fmt.format(r.totalGastos)}',
                  Colors.orange.shade700, Colors.orange.shade50)),
            ]),
            const SizedBox(height: 12),
            _kpiMes('Utilidad bruta',
              '\$${fmt.format(r.utilidadBruta)}',
              r.utilidadBruta >= 0
                  ? Colors.green.shade700 : Colors.red.shade700,
              r.utilidadBruta >= 0
                  ? Colors.green.shade50 : Colors.red.shade50,
              fullWidth: true),
            const SizedBox(height: 20),
            if (r.ventasPorDia.isNotEmpty) ...[
              Text('Ventas por día',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              _buildBarChart(r.ventasPorDia),
            ],
          ],
        ))),
    ]);
  }

  Widget _kpiMes(String label, String valor, Color color, Color bg,
      {bool fullWidth = false}) =>
    Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(
            color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(valor, style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, fontSize: 20, color: color)),
      ]),
    );

  Widget _buildBarChart(List<Map<String, dynamic>> dias) {
    final maxVal = dias
        .map((d) => (d['total'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: SizedBox(
        height: 180,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: dias.map((d) {
            final val = (d['total'] as num).toDouble();
            final dia = (d['dia']?.toString().length ?? 0) >= 10
                ? d['dia'].toString().substring(8, 10) : '?';
            final pct = maxVal > 0 ? val / maxVal : 0.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 140 * pct.clamp(0.02, 1.0),
                      decoration: BoxDecoration(
                        color: const Color(Constants.primaryColor)
                            .withOpacity(0.7 + 0.3 * pct),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3))),
                    ),
                    const SizedBox(height: 4),
                    Text(dia, style: GoogleFonts.poppins(
                        fontSize: 8, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// TAB 3 — TOP PRODUCTOS
// ──────────────────────────────────────────────────────
class _TabTopProductos extends StatelessWidget {
  final ContabilidadProvider cont;
  final NumberFormat fmt;
  const _TabTopProductos({required this.cont, required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (cont.cargando && cont.topProductos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cont.topProductos.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin datos de productos', style: GoogleFonts.poppins(
              color: Colors.grey.shade400, fontSize: 16)),
        ],
      ));
    }

    final maxVendido = cont.topProductos
        .map((p) => p.totalVendido)
        .fold(0.0, (a, b) => a > b ? a : b);
    final colores = [
      Colors.amber, Colors.grey.shade400, Colors.brown.shade300];

    return ListView.builder(
      itemCount: cont.topProductos.length,
      itemBuilder: (_, i) {
        final p   = cont.topProductos[i];
        final pct = maxVendido > 0 ? p.totalVendido / maxVendido : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: i < 3
                    ? colores[i].withOpacity(0.15) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${i + 1}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14,
                  color: i < 3 ? colores[i] : Colors.grey.shade500))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.producto,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0), minHeight: 5,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation(
                        i < 3 ? colores[i]
                            : const Color(Constants.primaryColor)),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${p.totalVendido.toStringAsFixed(0)} unidades',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade500)),
              ],
            )),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${fmt.format(p.totalIngresos)}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color(Constants.primaryColor), fontSize: 13)),
              Text('ingresos', style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ]),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────
// TAB 4 — GASTOS
// ──────────────────────────────────────────────────────
// ──────────────────────────────────────────────────────
// TAB 4 — GASTOS  ✅ StatefulWidget para carga automática
// ──────────────────────────────────────────────────────
// ──────────────────────────────────────────────────────
// TAB 4 — GASTOS
// ──────────────────────────────────────────────────────
class _TabGastos extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat fmt;
  final int? tiendaId;
  final bool esCajero;
  final AuthProvider auth;
  final BuildContext dialogContext;

  const _TabGastos({
    required this.cont, required this.fmt, required this.tiendaId,
    required this.esCajero, required this.auth,
    required this.dialogContext,
  });

  @override
  State<_TabGastos> createState() => _TabGastosState();
}

class _TabGastosState extends State<_TabGastos> {
  DateTime _fechaSeleccionada = DateTime.now(); // ← nuevo

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar(); // ← usa _cargar() en vez de cargarGastos directo
    });
  }

  // ── Helpers de fecha ────────────────────────────────
  void _cargar() {
    final fechaStr =
        '${_fechaSeleccionada.year}-'
        '${_fechaSeleccionada.month.toString().padLeft(2, '0')}-'
        '${_fechaSeleccionada.day.toString().padLeft(2, '0')}';
    widget.cont.cargarGastos(tiendaId: widget.tiendaId, fecha: fechaStr);
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.orange.shade600,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _fechaSeleccionada) {
      setState(() => _fechaSeleccionada = picked);
      _cargar();
    }
  }

  bool get _esHoy {
    final hoy = DateTime.now();
    return _fechaSeleccionada.year  == hoy.year &&
           _fechaSeleccionada.month == hoy.month &&
           _fechaSeleccionada.day   == hoy.day;
  }

  String get _labelFecha {
    if (_esHoy) return 'Hoy';
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    if (_fechaSeleccionada.year  == ayer.year &&
        _fechaSeleccionada.month == ayer.month &&
        _fechaSeleccionada.day   == ayer.day) return 'Ayer';
    return '${_fechaSeleccionada.day.toString().padLeft(2,'0')}/'
           '${_fechaSeleccionada.month.toString().padLeft(2,'0')}/'
           '${_fechaSeleccionada.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cont = context.watch<ContabilidadProvider>();

    return Column(children: [

      // ── Fila 1: título + botón registrar ────────────
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gastos',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 15)),
          Text(
            widget.esCajero ? 'Tus gastos registrados' : 'Todos los gastos',
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.grey.shade500)),
        ]),
        ElevatedButton.icon(
          icon:  const Icon(Icons.add_rounded, size: 18),
          label: Text('Registrar gasto',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          onPressed: () => _abrirFormGasto(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0),
        ),
      ]),
      const SizedBox(height: 10),

      // ── Fila 2: selector de fecha + recargar ────────
      Row(children: [
        Expanded(
          child: InkWell(
            onTap: _seleccionarFecha,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200)),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    size: 16, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text(_labelFecha,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14,
                    color: Colors.orange.shade700)),
                const Spacer(),
                // Badge "Histórico" si no es hoy
                if (!_esHoy)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20)),
                    child: Text('Histórico',
                      style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600)),
                  ),
                Icon(Icons.arrow_drop_down_rounded,
                    color: Colors.orange.shade600),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Botón recargar
        Tooltip(
          message: 'Recargar gastos',
          child: InkWell(
            onTap: cont.cargando ? null : _cargar,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300)),
              child: cont.cargando
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange.shade600))
                  : const Icon(Icons.refresh_rounded,
                      size: 20, color: Colors.grey),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),

      // ── Lista de gastos ──────────────────────────────
      Expanded(
        child: cont.cargando && cont.gastos.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : cont.gastos.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 64,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Sin gastos para $_labelFecha',
                        style: GoogleFonts.poppins(
                            color: Colors.grey.shade400, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('No hay gastos registrados este día',
                        style: GoogleFonts.poppins(
                            color: Colors.grey.shade300, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text('Recargar', style: GoogleFonts.poppins()),
                        onPressed: _cargar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      ),
                    ],
                  ))
                : RefreshIndicator(
                    onRefresh: () async => _cargar(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: cont.gastos.length,
                      itemBuilder: (_, i) => _gastoItem(cont, cont.gastos[i]),
                    ),
                  ),
      ),
    ]);
  }

  Widget _gastoItem(ContabilidadProvider cont, Gasto g) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 6, offset: const Offset(0, 2))]),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.receipt_long_rounded,
            color: Colors.orange.shade600, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(g.categoria.isNotEmpty ? g.categoria : 'Sin categoría',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13)),
          if (g.descripcion.isNotEmpty)
            Text(g.descripcion, style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis),
          Row(children: [
            Text(g.empleadoNombre, style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.grey.shade400)),
            if (g.tiendaNombre.isNotEmpty) ...[
              Text(' · ', style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade300)),
              Text(g.tiendaNombre, style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade400)),
            ],
          ]),
        ],
      )),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('\$${widget.fmt.format(g.monto)}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.red.shade600, fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8)),
          child: Text(g.metodoPago, style: GoogleFonts.poppins(
              fontSize: 10, color: Colors.grey.shade600)),
        ),
      ]),
      if (!widget.esCajero) ...[
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              color: Colors.red.shade300, size: 18),
          onPressed: () =>
              cont.eliminarGasto(g.id, tiendaId: widget.tiendaId),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ]),
  );

  void _abrirFormGasto(BuildContext ctx) {
    final catCtrl   = TextEditingController();
    final descCtrl  = TextEditingController();
    final montoCtrl = TextEditingController();
    String metodoPago = 'efectivo';

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) {
          final cont = context.watch<ContabilidadProvider>();
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text('Registrar Gasto',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 16)),
              ]),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  _inputField('Categoría (arriendo, nómina...)', catCtrl),
                  _inputField('Descripción', descCtrl),
                  _inputField('Monto *', montoCtrl, isNumber: true),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: metodoPago,
                    decoration: InputDecoration(
                      labelText: 'Método de pago',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      filled: true, fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'efectivo',      child: Text('Efectivo')),
                      DropdownMenuItem(value: 'tarjeta',       child: Text('Tarjeta')),
                      DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                    ],
                    onChanged: (v) => setS(() => metodoPago = v ?? 'efectivo'),
                  ),
                ],
              )),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: Text('Cancelar',
                    style: GoogleFonts.poppins(color: Colors.grey))),
              ElevatedButton.icon(
                icon: cont.guardando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text('Guardar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onPressed: cont.guardando ? null : () async {
                  final monto = double.tryParse(montoCtrl.text);
                  if (monto == null || monto <= 0) return;
                  final ok = await cont.crearGasto({
                    'tienda':      widget.tiendaId ?? widget.auth.tiendaId,
                    'categoria':   catCtrl.text.trim(),
                    'descripcion': descCtrl.text.trim(),
                    'monto':       monto,
                    'metodo_pago': metodoPago,
                  }, tiendaId: widget.tiendaId);
                  // ✅ recarga con la fecha seleccionada tras crear
                  if (ok && ctx2.mounted) {
                    Navigator.pop(ctx2);
                    _cargar();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {bool isNumber = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: Colors.orange.shade600, width: 2)),
        ),
      ),
    );
}