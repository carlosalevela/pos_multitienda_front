import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/contabilidad_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../models/contabilidad_models.dart';
import '../../services/empleado_service.dart';
import '../../providers/cliente_provider.dart'; 

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

  List<Map<String, dynamic>> _tiendas     = [];
  int?                        _tiendaAdmin;

  @override
  void initState() {
    super.initState();
    final auth  = context.read<AuthProvider>();
    final esCaj = auth.rol == 'cajero';

    _tabCtrl = TabController(length: esCaj ? 3 : 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cont = context.read<ContabilidadProvider>();
      final tid  = auth.tiendaId == 0 ? null : auth.tiendaId;

      if (auth.rol == 'admin') {
        final tiendas = await EmpleadoService().getTiendas();
        if (mounted) setState(() => _tiendas = tiendas);
      }

      final tiendaEfectiva = auth.rol == 'admin' ? _tiendaAdmin : tid;

      cont.cargarResumenDiario(tiendaId: tiendaEfectiva);
      if (!esCaj) cont.cargarResumenMensual(
          tiendaId: tiendaEfectiva, anio: _anioSel, mes: _mesSel);
      cont.cargarTopProductos(tiendaId: tiendaEfectiva);
      cont.cargarGastos(tiendaId: tiendaEfectiva);
    });
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  int? get _tiendaId {
    final auth = context.read<AuthProvider>();
    if (auth.rol == 'admin') return _tiendaAdmin;
    return auth.tiendaId == 0 ? null : auth.tiendaId;
  }

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

          if (cont.successMsg.isNotEmpty)
            _banner(cont.successMsg, isError: false, onClose: cont.limpiarMensajes),
          if (cont.errorMsg.isNotEmpty)
            _banner(cont.errorMsg, isError: true, onClose: cont.limpiarMensajes),

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

// ════════════════════════════════════════════════════
// TAB RESUMEN DÍA
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  void _cargar() {
    widget.cont.cargarResumenDiario(
      tiendaId: widget.tiendaId,
      fecha: _fechaSeleccionada,
    );
  }

  Future<void> _seleccionarFecha() async {
    final hoy    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _fechaSeleccionada,
      firstDate:   DateTime(hoy.year - 1),
      lastDate:    hoy,
      locale:      const Locale('es', 'CO'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary:   const Color(Constants.primaryColor),
            onPrimary: Colors.white,
            surface:   Colors.white,
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
    return '${_fechaSeleccionada.day.toString().padLeft(2, '0')}/'
           '${_fechaSeleccionada.month.toString().padLeft(2, '0')}/'
           '${_fechaSeleccionada.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cont = widget.cont;
    final fmt  = widget.fmt;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Selector de fecha + recargar ─────────────────
      Row(children: [
        Expanded(
          child: InkWell(
            onTap:        _seleccionarFecha,
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
        Tooltip(
          message: 'Recargar datos',
          child: InkWell(
            onTap:        cont.cargando ? null : _cargar,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: Colors.grey.shade300)),
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

      Expanded(child: _buildContenido(cont, fmt)),
    ]);
  }

  Widget _buildContenido(ContabilidadProvider cont, NumberFormat fmt) {
    if (cont.cargando && cont.resumenDiario == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final r = cont.resumenDiario;

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
            icon:      const Icon(Icons.refresh_rounded),
            label:     Text('Recargar', style: GoogleFonts.poppins()),
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

    // ── Cálculos derivados ──────────────────────────────
    final ticketPromedio = r.numVentas > 0
        ? r.totalVentas / r.numVentas : 0.0;
    final margenPct = r.totalVentas > 0
        ? (r.utilidadBruta / r.totalVentas) * 100 : 0.0;
    final gastosPct = r.totalVentas > 0
        ? (r.totalGastos / r.totalVentas).clamp(0.0, 1.0) : 0.0;

    final separados  = cont.separadosDia;
    final abonosList = cont.abonosDia;

    // ✅ FIX 1 — monto puede llegar como String del backend
    final totalAbonos = abonosList.fold<double>(
        0, (sum, a) => sum + (double.tryParse(a['monto'].toString()) ?? 0.0));

    return RefreshIndicator(
      onRefresh: () async => _cargar(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Indicador fecha + badge histórico ─────────
          Row(children: [
            Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Text('Resumen del ${r.fecha}',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade500, fontSize: 12)),
            if (!_esHoy) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200)),
                child: Text('Histórico',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
          const SizedBox(height: 14),

          // ── 3 KPIs en fila ─────────────────────────
          Row(children: [
            Expanded(child: _kpiCard(
              icon:  Icons.trending_up_rounded,
              label: 'Ventas totales',
              valor: '\$${fmt.format(r.totalVentas)}',
              sub:   '${r.numVentas} transacción${r.numVentas != 1 ? "es" : ""}',
              color: Colors.blue.shade700,
              bg:    Colors.blue.shade50,
            )),
            const SizedBox(width: 10),
            Expanded(child: _kpiCard(
              icon:  Icons.receipt_long_rounded,
              label: 'Total gastos',
              valor: '\$${fmt.format(r.totalGastos)}',
              sub:   r.totalVentas > 0
                  ? '${(gastosPct * 100).toStringAsFixed(1)}% de ventas' : '',
              color: Colors.orange.shade700,
              bg:    Colors.orange.shade50,
            )),
            const SizedBox(width: 10),
            Expanded(child: _kpiCard(
              icon:  Icons.confirmation_number_rounded,
              label: 'Ticket promedio',
              valor: '\$${fmt.format(ticketPromedio)}',
              sub:   r.numVentas > 0 ? 'por venta' : 'sin ventas',
              color: Colors.purple.shade700,
              bg:    Colors.purple.shade50,
            )),
          ]),
          const SizedBox(height: 12),

          // ── Utilidad bruta ──────────────────────────
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: r.utilidadBruta >= 0
                    ? [Colors.green.shade700, Colors.green.shade500]
                    : [Colors.red.shade700,   Colors.red.shade500],
                begin: Alignment.centerLeft,
                end:   Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  r.utilidadBruta >= 0
                      ? Icons.account_balance_wallet_rounded
                      : Icons.warning_rounded,
                  color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Utilidad bruta del día',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                Text('\$${fmt.format(r.utilidadBruta)}',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 24)),
              ]),
              const Spacer(),
              if (r.totalVentas > 0)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Gastos / Ventas',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 110,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value:      gastosPct,
                        minHeight:  10,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          gastosPct > 0.8
                              ? Colors.redAccent.shade100 : Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Margen: ${margenPct.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
                ]),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Métodos de pago ─────────────────────────
          if (r.ventasPorMetodo.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.payments_rounded,
                  size: 18, color: Color(Constants.primaryColor)),
              const SizedBox(width: 8),
              Text('Ventas por método de pago',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: const Color(0xFF1A1A2E))),
              const Spacer(),
              Text('${r.ventasPorMetodo.length} método${r.ventasPorMetodo.length != 1 ? "s" : ""}',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade400)),
            ]),
            const SizedBox(height: 12),

            // ✅ FIX 2 — total de ventasPorMetodo como String
            ...r.ventasPorMetodo.map((m) {
              final totalMet = double.tryParse(m['total'].toString()) ?? 0.0;
              final pct = r.totalVentas > 0 ? totalMet / r.totalVentas : 0.0;
              return _metodoPago(
                m['metodo']   ?? '',
                m['cantidad'] ?? 0,
                totalMet,
                pct, fmt,
              );
            }),
            const SizedBox(height: 20),
          ],

          // ── Separados nuevos del día ──────────────
          if (separados.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.inventory_2_rounded,
                  size: 18, color: Color(Constants.primaryColor)),
              const SizedBox(width: 8),
              Text('Separados nuevos',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: const Color(0xFF1A1A2E))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20)),
                child: Text('${separados.length}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700)),
              ),
            ]),
            const SizedBox(height: 10),
            ...separados.map((s) => _separadoCard(s, fmt)),
            const SizedBox(height: 20),
          ],

          // ── Abonos a separados del día ────────────
          if (abonosList.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.bookmark_added_rounded,
                  size: 18, color: Colors.teal),
              const SizedBox(width: 8),
              Text('Abonos a separados',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: const Color(0xFF1A1A2E))),
              const Spacer(),
              Text('\$${fmt.format(totalAbonos)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: Colors.teal.shade700)),
            ]),
            const SizedBox(height: 10),
            ...abonosList.map((a) => _abonoCard(a, fmt)),
            const SizedBox(height: 20),
          ],

          // ── Detalle del día ─────────────────────────
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: Color(Constants.primaryColor)),
            const SizedBox(width: 8),
            Text('Detalle del día',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 15,
                  color: const Color(0xFF1A1A2E))),
          ]),
          const SizedBox(height: 12),
          _buildDetalleDia(r, ticketPromedio, margenPct, fmt),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildDetalleDia(dynamic r, double ticketProm,
      double margenPct, NumberFormat fmt) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: [
        _detalleRow(Icons.shopping_cart_rounded, Colors.blue,
            'Total transacciones',
            '${r.numVentas} venta${r.numVentas != 1 ? "s" : ""}'),
        _divider(),
        _detalleRow(Icons.confirmation_number_rounded, Colors.purple,
            'Ticket promedio',
            r.numVentas > 0 ? '\$${fmt.format(ticketProm)}' : '-'),
        _divider(),
        _detalleRow(Icons.pie_chart_rounded, Colors.teal,
            'Margen de utilidad',
            r.totalVentas > 0 ? '${margenPct.toStringAsFixed(1)}%' : '-'),
        _divider(),
        _detalleRow(Icons.payments_outlined, Colors.orange,
            'Métodos usados',
            '${r.ventasPorMetodo.length} método${r.ventasPorMetodo.length != 1 ? "s" : ""}'),
        _divider(),
        _detalleRow(
          r.utilidadBruta >= 0
              ? Icons.sentiment_satisfied_alt_rounded
              : Icons.sentiment_dissatisfied_rounded,
          r.utilidadBruta >= 0 ? Colors.green : Colors.red,
          'Estado del día',
          r.utilidadBruta >= 0 ? '✅ Rentable' : '⚠️ Con pérdidas'),
      ]),
    );

  Widget _detalleRow(IconData icon, Color color, String label, String valor) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        Text(valor, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E))),
      ]),
    );

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade100);

  Widget _kpiCard({
    required IconData icon, required String label,
    required String valor, required String sub,
    required Color color, required Color bg,
  }) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.poppins(
            color: Colors.grey.shade600, fontSize: 11),
          overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(valor, style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        if (sub.isNotEmpty)
          Text(sub, style: GoogleFonts.poppins(
              color: Colors.grey.shade500, fontSize: 10)),
      ]),
    );

  Widget _metodoPago(String metodo, int cantidad, double total,
      double pct, NumberFormat fmt) {
    final info = _infoMetodo(metodo);
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        info['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(info['icon'], color: info['color'], size: 16)),
            const SizedBox(width: 10),
            Text(info['label'], style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          Text('\$${fmt.format(total)}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(Constants.primaryColor),
                fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           pct.clamp(0.0, 1.0),
              minHeight:       6,
              backgroundColor: Colors.grey.shade100,
              valueColor:      AlwaysStoppedAnimation(info['color']),
            ),
          )),
          const SizedBox(width: 8),
          Text('${(pct * 100).toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 4),
        Text('$cantidad venta${cantidad != 1 ? "s" : ""}',
          style: GoogleFonts.poppins(
              fontSize: 11, color: Colors.grey.shade500)),
      ]),
    );
  }

  // ✅ FIX 3 — total y saldo pueden llegar como String
  Widget _separadoCard(Map<String, dynamic> s, NumberFormat fmt) {
    final cliente = s['cliente_nombre'] ?? '—';
    final total   = double.tryParse(s['total'].toString())           ?? 0.0;
    final saldo   = double.tryParse(s['saldo_pendiente'].toString()) ?? 0.0;
    final estado  = s['estado'] ?? '';
    final color   = estado == 'pagado'
        ? Colors.green.shade600
        : estado == 'cancelado'
            ? Colors.red.shade600
            : Colors.orange.shade700;

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.inventory_2_outlined,
              color: Colors.indigo.shade600, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cliente, style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13)),
            Text('Saldo pendiente: \$${fmt.format(saldo)}',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade500)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${fmt.format(total)}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 13,
                color: Colors.indigo.shade700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Text(estado.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          ),
        ]),
      ]),
    );
  }

  // ✅ FIX 4 — monto puede llegar como String
  Widget _abonoCard(Map<String, dynamic> a, NumberFormat fmt) {
    final cliente = a['cliente_nombre'] ?? '—';
    final monto   = double.tryParse(a['monto'].toString()) ?? 0.0;
    final metodo  = a['metodo_pago'] ?? 'efectivo';
    final hora    = (a['created_at'] ?? '').toString().length >= 16
        ? a['created_at'].toString().substring(11, 16) : '';

    final infoMet = <String, Map<String, dynamic>>{
      'efectivo':      {'icon': Icons.payments_rounded,        'color': Colors.green},
      'tarjeta':       {'icon': Icons.credit_card_rounded,     'color': Colors.blue},
      'transferencia': {'icon': Icons.account_balance_rounded, 'color': Colors.indigo},
    }[metodo] ?? {'icon': Icons.attach_money_rounded, 'color': Colors.grey};

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        (infoMet['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(infoMet['icon'] as IconData,
              color: infoMet['color'] as Color, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cliente, style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13)),
            if (hora.isNotEmpty)
              Text(hora, style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade400)),
          ],
        )),
        Text('\$${fmt.format(monto)}',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 13,
              color: Colors.teal.shade700)),
      ]),
    );
  }

  Map<String, dynamic> _infoMetodo(String m) => const {
    'efectivo':      {'label': 'Efectivo',      'icon': Icons.payments_rounded,       'color': Colors.green},
    'tarjeta':       {'label': 'Tarjeta',        'icon': Icons.credit_card_rounded,    'color': Colors.blue},
    'transferencia': {'label': 'Transferencia',  'icon': Icons.account_balance_rounded,'color': Colors.indigo},
    'mixto':         {'label': 'Mixto',          'icon': Icons.shuffle_rounded,        'color': Colors.purple},
  }[m] ?? {'label': m, 'icon': Icons.attach_money_rounded, 'color': Colors.grey};
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

      // ── Navegador de mes ────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              final nm = mes - 1 <= 0 ? 12 : mes - 1;
              final na = mes - 1 <= 0 ? anio - 1 : anio;
              onCambiarMes(na, nm);
            },
          ),
          Expanded(child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: Color(Constants.primaryColor)),
              const SizedBox(width: 8),
              Text('${meses[mes - 1]} $anio',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16,
                    color: const Color(0xFF1A1A2E))),
            ]),
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
      ),

      const SizedBox(height: 16),

      if (r == null)
        Expanded(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Sin datos para este mes',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 15)),
          ],
        )))
      else
        Expanded(child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Fila KPIs principales ──────────────────
              Row(children: [
                Expanded(child: _kpiCard(
                  label:  'Total ventas',
                  valor:  '\$${fmt.format(r.totalVentas)}',
                  icon:   Icons.trending_up_rounded,
                  color:  Colors.blue.shade700,
                  bg:     Colors.blue.shade50,
                )),
                const SizedBox(width: 12),
                Expanded(child: _kpiCard(
                  label:  'Total gastos',
                  valor:  '\$${fmt.format(r.totalGastos)}',
                  icon:   Icons.trending_down_rounded,
                  color:  Colors.orange.shade700,
                  bg:     Colors.orange.shade50,
                )),
                const SizedBox(width: 12),
                Expanded(child: _kpiCard(
                  label: 'Margen utilidad',
                  valor: r.totalVentas > 0
                      ? '${((r.utilidadBruta / r.totalVentas) * 100).toStringAsFixed(1)}%'
                      : '0%',
                  icon:  Icons.pie_chart_rounded,
                  color: r.utilidadBruta >= 0
                      ? Colors.teal.shade700 : Colors.red.shade700,
                  bg:    r.utilidadBruta >= 0
                      ? Colors.teal.shade50 : Colors.red.shade50,
                )),
              ]),

              const SizedBox(height: 12),

              // ── Utilidad bruta (full width) ────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: r.utilidadBruta >= 0
                        ? [Colors.green.shade700, Colors.green.shade500]
                        : [Colors.red.shade700, Colors.red.shade500],
                    begin: Alignment.centerLeft,
                    end:   Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(
                      r.utilidadBruta >= 0
                          ? Icons.account_balance_wallet_rounded
                          : Icons.warning_rounded,
                      color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Utilidad bruta del mes',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                    Text('\$${fmt.format(r.utilidadBruta)}',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24)),
                  ]),
                  const Spacer(),
                  // Proporción ventas vs gastos
                  if (r.totalVentas > 0)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Gastos / Ventas',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (r.totalGastos / r.totalVentas).clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              (r.totalGastos / r.totalVentas) > 0.8
                                  ? Colors.redAccent.shade100
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${((r.totalGastos / r.totalVentas) * 100).toStringAsFixed(1)}% de las ventas',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 10)),
                    ]),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Gráfico barras ─────────────────────────
              if (r.ventasPorDia.isNotEmpty) ...[
                Row(children: [
                  const Icon(Icons.bar_chart_rounded,
                      size: 18, color: Color(Constants.primaryColor)),
                  const SizedBox(width: 8),
                  Text('Ventas por día',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 15,
                        color: const Color(0xFF1A1A2E))),
                  const Spacer(),
                  Text('${r.ventasPorDia.length} días con ventas',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade400)),
                ]),
                const SizedBox(height: 12),
                _buildBarChart(r.ventasPorDia),
              ],

              const SizedBox(height: 20),

              // ── Resumen rápido ─────────────────────────
              Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: Color(Constants.primaryColor)),
                const SizedBox(width: 8),
                Text('Resumen del mes',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: const Color(0xFF1A1A2E))),
              ]),
              const SizedBox(height: 12),
              _buildResumenRapido(r),
              const SizedBox(height: 12),
            ],
          ),
        )),
    ]);
  }

  // ── KPI card con ícono ────────────────────────────────
  Widget _kpiCard({
    required String label,
    required String valor,
    required IconData icon,
    required Color color,
    required Color bg,
  }) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, style: GoogleFonts.poppins(
                color: Colors.grey.shade600, fontSize: 11),
              overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 8),
        Text(valor, style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ]),
    );

  // ── Gráfico de barras mejorado ────────────────────────
  Widget _buildBarChart(List<Map<String, dynamic>> dias) {
    final maxVal = dias
        .map((d) => (d['total'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: SizedBox(
        height: 200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: dias.map((d) {
            final val = (d['total'] as num).toDouble();
            final dia = (d['dia']?.toString().length ?? 0) >= 10
                ? d['dia'].toString().substring(8, 10) : '?';
            final pct = maxVal > 0 ? val / maxVal : 0.0;
            final esMax = val == maxVal;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Valor encima de la barra máxima
                    if (esMax)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '\$${fmt.format(val)}',
                          style: GoogleFonts.poppins(
                              fontSize: 8, fontWeight: FontWeight.bold,
                              color: const Color(Constants.primaryColor)),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                    // Barra
                    Container(
                      height: 150 * pct.clamp(0.02, 1.0),
                      decoration: BoxDecoration(
                        color: esMax
                            ? const Color(Constants.primaryColor)
                            : const Color(Constants.primaryColor).withOpacity(0.45),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4))),
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

  // ── Resumen rápido al fondo ───────────────────────────
  Widget _buildResumenRapido(dynamic r) {
    final diasConVentas = r.ventasPorDia.length;
    final promedioVentaDia = diasConVentas > 0
        ? r.totalVentas / diasConVentas : 0.0;
    final promedioGastoDia = diasConVentas > 0
        ? r.totalGastos / diasConVentas : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: [
        _resumenFila(
          Icons.calendar_today_rounded, Colors.blue,
          'Días con ventas', '$diasConVentas días'),
        _divider(),
        _resumenFila(
          Icons.show_chart_rounded, Colors.indigo,
          'Promedio venta/día', '\$${fmt.format(promedioVentaDia)}'),
        _divider(),
        _resumenFila(
          Icons.receipt_long_rounded, Colors.orange,
          'Promedio gasto/día', '\$${fmt.format(promedioGastoDia)}'),
        _divider(),
        _resumenFila(
          r.utilidadBruta >= 0
              ? Icons.sentiment_satisfied_rounded
              : Icons.sentiment_dissatisfied_rounded,
          r.utilidadBruta >= 0 ? Colors.green : Colors.red,
          'Estado del mes',
          r.utilidadBruta >= 0 ? '✅ Rentable' : '⚠️ Con pérdidas'),
      ]),
    );
  }

  Widget _resumenFila(IconData icon, Color color, String label, String valor) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        Text(valor, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E))),
      ]),
    );

  Widget _divider() =>
    Divider(height: 1, color: Colors.grey.shade100);
}
// ──────────────────────────────────────────────────────
// TAB 3 — TOP PRODUCTOS
// ──────────────────────────────────────────────────────
class _TabTopProductos extends StatelessWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;

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
          Icon(Icons.leaderboard_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sin datos de productos',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 16)),
        ],
      ));
    }

    // ── Agrupar por categoría ─────────────────────────
    final Map<String, List<TopProducto>> porCategoria = {};
    for (final p in cont.topProductos) {
      porCategoria.putIfAbsent(p.categoria, () => []).add(p);
    }

    final totalIngresos = cont.topProductos
        .fold(0.0, (s, p) => s + p.totalIngresos);
    final totalUnidades = cont.topProductos
        .fold(0.0, (s, p) => s + p.totalVendido);
    final maxIngresos   = cont.topProductos
        .map((p) => p.totalIngresos)
        .fold(0.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 3 KPIs globales ─────────────────────────
        Row(children: [
          Expanded(child: _kpiGlobal(
            Icons.emoji_events_rounded,
            '${cont.topProductos.length} productos',
            'en ranking',
            Colors.amber.shade700, Colors.amber.shade50,
          )),
          const SizedBox(width: 10),
          Expanded(child: _kpiGlobal(
            Icons.inventory_2_rounded,
            '${totalUnidades.toStringAsFixed(0)} uds',
            'total vendidas',
            Colors.blue.shade700, Colors.blue.shade50,
          )),
          const SizedBox(width: 10),
          Expanded(child: _kpiGlobal(
            Icons.attach_money_rounded,
            '\$${fmt.format(totalIngresos)}',
            'ingresos totales',
            Colors.green.shade700, Colors.green.shade50,
          )),
        ]),
        const SizedBox(height: 20),

        // ── Podium top 3 ────────────────────────────
        if (cont.topProductos.length >= 3) ...[
          Row(children: [
            const Icon(Icons.workspace_premium_rounded,
                size: 18, color: Color(Constants.primaryColor)),
            const SizedBox(width: 8),
            Text('Top 3 productos',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 15,
                  color: const Color(0xFF1A1A2E))),
          ]),
          const SizedBox(height: 12),
          _buildPodium(cont.topProductos.take(3).toList(), maxIngresos),
          const SizedBox(height: 20),
        ],

        // ── Secciones por categoría ──────────────────
        ...porCategoria.entries.map((entry) {
          final categoria   = entry.key;
          final productos   = entry.value;
          final ingresosCat = productos
              .fold(0.0, (s, p) => s + p.totalIngresos);
          final pctCat = totalIngresos > 0
              ? ingresosCat / totalIngresos : 0.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header categoría
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _colorCategoria(categoria).withOpacity(0.12),
                      _colorCategoria(categoria).withOpacity(0.04),
                    ],
                    begin: Alignment.centerLeft,
                    end:   Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _colorCategoria(categoria).withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(_iconoCategoria(categoria),
                      size: 18, color: _colorCategoria(categoria)),
                  const SizedBox(width: 8),
                  Text(categoria,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13,
                        color: _colorCategoria(categoria))),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${fmt.format(ingresosCat)}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: _colorCategoria(categoria))),
                      Text('${(pctCat * 100).toStringAsFixed(1)}% del total',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: Colors.grey.shade500)),
                    ]),
                ]),
              ),
              const SizedBox(height: 8),

              // Productos de la categoría
              ...productos.map((p) {
                final idx      = cont.topProductos.indexOf(p);
                final pct      = maxIngresos > 0
                    ? p.totalIngresos / maxIngresos : 0.0;
                final pctEnCat = ingresosCat > 0
                    ? p.totalIngresos / ingresosCat : 0.0;
                return _productoCard(p, idx, pct, pctEnCat);
              }),
              const SizedBox(height: 16),
            ],
          );
        }),
      ]),
    );
  }

  // ── Podium ────────────────────────────────────────────
  Widget _buildPodium(List<TopProducto> top3, double maxIng) {
    final medallas  = ['🥇', '🥈', '🥉'];
    final colores   = [Colors.amber.shade600, Colors.grey.shade500, Colors.brown.shade400];
    final bgColores = [Colors.amber.shade50,  Colors.grey.shade50,  Colors.brown.shade50];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(top3.length, (i) {
        final p   = top3[i];
        final pct = maxIng > 0 ? p.totalIngresos / maxIng : 0.0;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left:  i == 0 ? 0 : 5,
              right: i == 2 ? 0 : 5,
              top:   i == 0 ? 0 : i == 1 ? 12 : 24,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        bgColores[i],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colores[i].withOpacity(0.3)),
              boxShadow: [BoxShadow(
                  color: colores[i].withOpacity(0.1),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(children: [
              Text(medallas[i], style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(p.producto,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 11,
                    color: const Color(0xFF1A1A2E)),
                textAlign: TextAlign.center,
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(p.categoria,
                style: GoogleFonts.poppins(
                    fontSize: 9, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           pct.clamp(0.0, 1.0),
                  minHeight:       4,
                  backgroundColor: Colors.white,
                  valueColor:      AlwaysStoppedAnimation(colores[i]),
                ),
              ),
              const SizedBox(height: 6),
              Text('\$${NumberFormat('#,###').format(p.totalIngresos)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12, color: colores[i])),
              Text('${p.totalVendido.toStringAsFixed(0)} uds',
                style: GoogleFonts.poppins(
                    fontSize: 9, color: Colors.grey.shade400)),
            ]),
          ),
        );
      }),
    );
  }

  // ── Producto card ─────────────────────────────────────
  Widget _productoCard(TopProducto p, int idx,
      double pct, double pctEnCat) =>
    Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // Número ranking global
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: idx < 3
                ? [Colors.amber.shade50,
                   Colors.grey.shade100,
                   Colors.brown.shade50][idx]
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('${idx + 1}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 12,
              color: idx < 3
                  ? [Colors.amber.shade700,
                     Colors.grey.shade600,
                     Colors.brown.shade500][idx]
                  : Colors.grey.shade400))),
        ),
        const SizedBox(width: 12),

        // Info producto
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
                value:           pct.clamp(0.0, 1.0),
                minHeight:       6,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation(
                    Color(Constants.primaryColor)),
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Text('${p.totalVendido.toStringAsFixed(0)} uds',
                style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.grey.shade500)),
              const SizedBox(width: 8),
              // Badge % dentro de su categoría
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _colorCategoria(p.categoria).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${(pctEnCat * 100).toStringAsFixed(0)}% en cat.',
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: _colorCategoria(p.categoria),
                      fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        )),
        const SizedBox(width: 12),

        // Ingresos
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${fmt.format(p.totalIngresos)}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(Constants.primaryColor),
                fontSize: 13)),
          Text('ingresos',
            style: GoogleFonts.poppins(
                fontSize: 10, color: Colors.grey.shade400)),
          const SizedBox(height: 2),
          Text('${(pct * 100).toStringAsFixed(1)}% del top',
            style: GoogleFonts.poppins(
                fontSize: 9, color: Colors.grey.shade400)),
        ]),
      ]),
    );

  // ── KPI global ────────────────────────────────────────
  Widget _kpiGlobal(IconData icon, String valor,
      String sub, Color color, Color bg) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(valor, style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, fontSize: 15, color: color),
          overflow: TextOverflow.ellipsis),
        Text(sub, style: GoogleFonts.poppins(
            fontSize: 10, color: Colors.grey.shade500)),
      ]),
    );

  // ── Helpers categoría ─────────────────────────────────
  Color _colorCategoria(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('ropa') || c.contains('moda'))       return Colors.pink.shade600;
    if (c.contains('electro'))                          return Colors.blue.shade700;
    if (c.contains('alimento') || c.contains('comida')) return Colors.green.shade700;
    if (c.contains('hogar') || c.contains('casa'))      return Colors.orange.shade700;
    if (c.contains('joya') || c.contains('accesorio'))  return Colors.purple.shade700;
    if (c.contains('calzado') || c.contains('zapato'))  return Colors.brown.shade600;
    if (c.contains('belleza') || c.contains('cosmet'))  return Colors.deepPurple.shade500;
    return Colors.teal.shade600;
  }

  IconData _iconoCategoria(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('ropa') || c.contains('moda'))       return Icons.checkroom_rounded;
    if (c.contains('electro'))                          return Icons.devices_rounded;
    if (c.contains('alimento') || c.contains('comida')) return Icons.fastfood_rounded;
    if (c.contains('hogar') || c.contains('casa'))      return Icons.home_rounded;
    if (c.contains('joya') || c.contains('accesorio'))  return Icons.diamond_rounded;
    if (c.contains('calzado') || c.contains('zapato'))  return Icons.run_circle_rounded;
    if (c.contains('belleza') || c.contains('cosmet'))  return Icons.face_retouching_natural_rounded;
    return Icons.category_rounded;
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
    final auth = context.read<AuthProvider>();
    context.read<ClienteProvider>().cargarSeparados(
      // ✅ cajero filtra por su tienda, admin/supervisor ve todo
      tiendaId: auth.rol == 'cajero' ? auth.tiendaId : null,
    );
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