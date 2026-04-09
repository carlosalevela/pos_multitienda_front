// lib/screens/contabilidad/tabs/tab_resumen_dia.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../core/constants.dart';

class TabResumenDia extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;

  const TabResumenDia({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
  });

  @override
  State<TabResumenDia> createState() => _TabResumenDiaState();
}

class _TabResumenDiaState extends State<TabResumenDia> {

  DateTime _fecha = DateTime.now();

  // ── Helpers de fecha ────────────────────────────────
  bool get _esHoy {
    final h = DateTime.now();
    return _fecha.year == h.year &&
           _fecha.month == h.month &&
           _fecha.day   == h.day;
  }

  String get _labelFecha {
    if (_esHoy) return 'Hoy';
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    if (_fecha.year  == ayer.year &&
        _fecha.month == ayer.month &&
        _fecha.day   == ayer.day) return 'Ayer';
    return '${_fecha.day.toString().padLeft(2,'0')}/'
           '${_fecha.month.toString().padLeft(2,'0')}/'
           '${_fecha.year}';
  }

  double _d(Map m, String key) =>
      double.tryParse(m[key]?.toString() ?? '0') ?? 0.0;

  // ── Lifecycle ────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  void _cargar() {
    widget.cont.cargarResumenDiario(
      tiendaId: widget.tiendaId,
      fecha: _fecha,
    );
  }

  Future<void> _seleccionarFecha() async {
    final hoy    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _fecha,
      firstDate:   DateTime(hoy.year - 2),
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
    if (picked != null && picked != _fecha) {
      setState(() => _fecha = picked);
      _cargar();
    }
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cont = widget.cont;
    final fmt  = widget.fmt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Selector de fecha + botón recargar ───────────
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
                  // Badge "Histórico" si no es hoy
                  if (!_esHoy)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade200)),
                      child: Text('Histórico',
                        style: GoogleFonts.poppins(
                            fontSize: 9, fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700)),
                    ),
                  const SizedBox(width: 4),
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

        // ── Contenido scrollable ─────────────────────────
        Expanded(
          child: cont.cargando && cont.resumenDiario == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => _cargar(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        if (cont.resumenDiario != null) ...[
                          _kpis(cont.resumenDiario!, fmt),
                          const SizedBox(height: 16),

                          if (cont.resumenDiario!.ventasPorMetodo.isNotEmpty) ...[
                            _tituloSeccion(Icons.payment_rounded,
                                'Ventas por método de pago'),
                            const SizedBox(height: 10),
                            _metodosGrid(cont.resumenDiario!.ventasPorMetodo, fmt),
                            const SizedBox(height: 20),
                          ],
                        ] else
                          _sinDatos(),

                        // Abonos
                        _tituloSeccion(Icons.savings_rounded,
                            'Abonos recibidos ${_esHoy ? "hoy" : _labelFecha}',
                            badge: cont.abonosDia.length),
                        const SizedBox(height: 10),
                        if (cont.abonosDia.isEmpty)
                          _vacios('Sin abonos este día', Icons.savings_outlined)
                        else
                          ...cont.abonosDia.map((a) => _abonoCard(a, fmt)),
                        const SizedBox(height: 20),

                        // Separados
                        _tituloSeccion(Icons.inventory_2_rounded,
                            'Separados creados ${_esHoy ? "hoy" : _labelFecha}',
                            badge: cont.separadosDia.length),
                        const SizedBox(height: 10),
                        if (cont.separadosDia.isEmpty)
                          _vacios('Sin separados este día',
                              Icons.inventory_2_outlined)
                        else
                          ...cont.separadosDia.map((s) => _separadoCard(s, fmt)),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Sin datos ──────────────────────────────────────────
  Widget _sinDatos() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16)),
    child: Center(child: Column(children: [
      Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 8),
      Text('Sin datos para $_labelFecha',
          style: GoogleFonts.poppins(
              color: Colors.grey.shade400, fontSize: 13)),
      const SizedBox(height: 16),
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
    ])),
  );

  // ── KPIs ───────────────────────────────────────────────
  Widget _kpis(dynamic r, NumberFormat fmt) {
    final utilidad = r.utilidadBruta as double;
    return Column(children: [
      Row(children: [
        Expanded(child: _kpi(
          Icons.trending_up_rounded, 'Ventas',
          fmt.format(r.totalVentas),
          '${r.numVentas} transacciones',
          Colors.blue.shade700, Colors.blue.shade50,
        )),
        const SizedBox(width: 10),
        Expanded(child: _kpi(
          Icons.trending_down_rounded, 'Gastos',
          fmt.format(r.totalGastos),
          'Del día',
          Colors.orange.shade700, Colors.orange.shade50,
        )),
      ]),
      const SizedBox(height: 10),
      _kpiBig(
        utilidad >= 0
            ? Icons.account_balance_wallet_rounded
            : Icons.warning_rounded,
        'Utilidad bruta del día',
        fmt.format(utilidad),
        utilidad >= 0 ? Colors.green.shade700 : Colors.red.shade700,
        utilidad >= 0 ? Colors.green.shade50  : Colors.red.shade50,
      ),
    ]);
  }

  Widget _kpi(IconData icon, String label, String valor,
      String sub, Color color, Color bg) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.poppins(
            color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 2),
        Text(valor,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(sub, style: GoogleFonts.poppins(
            fontSize: 10, color: Colors.grey.shade400)),
      ]),
    );

  Widget _kpiBig(IconData icon, String label, String valor,
      Color color, Color bg) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(
              color: Colors.grey.shade600, fontSize: 11)),
          Text(valor, style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 22, color: color)),
        ]),
      ]),
    );

  // ── Métodos de pago ─────────────────────────────────────
  Widget _metodosGrid(List<Map<String, dynamic>> metodos, NumberFormat fmt) =>
    GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 2.4,
        crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: metodos.length,
      itemBuilder: (_, i) {
        final m      = metodos[i];
        final metodo = m['metodo']?.toString() ?? '';
        final total  = _d(m, 'total');
        final cant   = m['cantidad'] ?? 0;
        final color  = _metodoPagoColor(metodo);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [
              Row(children: [
                Icon(_metodoPagoIcon(metodo), color: color, size: 14),
                const SizedBox(width: 4),
                Text(_metodoPagoLabel(metodo),
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ]),
              const SizedBox(height: 4),
              Text(fmt.format(total),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13,
                      color: const Color(0xFF1A1A2E))),
              Text('$cant transacciones',
                  style: GoogleFonts.poppins(
                      fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
        );
      },
    );

  // ── Título sección ──────────────────────────────────────
  Widget _tituloSeccion(IconData icon, String titulo,
      {Color? color, int? badge}) =>
    Row(children: [
      Icon(icon, size: 18, color: color ?? const Color(Constants.primaryColor)),
      const SizedBox(width: 8),
      Expanded(child: Text(titulo, style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold, fontSize: 15,
          color: const Color(0xFF1A1A2E)))),
      if (badge != null && badge > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: const Color(Constants.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$badge', style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: const Color(Constants.primaryColor))),
        ),
    ]);

  Widget _vacios(String msg, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(children: [
      Icon(icon, size: 36, color: Colors.grey.shade300),
      const SizedBox(height: 6),
      Text(msg, style: GoogleFonts.poppins(
          color: Colors.grey.shade400, fontSize: 12)),
    ]),
  );

  // ── Card abono ──────────────────────────────────────────
  Widget _abonoCard(Map<String, dynamic> a, NumberFormat fmt) {
    final monto       = _d(a, 'monto');
    final clienteNom  = a['cliente_nombre']?.toString()  ?? '—';
    final empleadoNom = a['empleado_nombre']?.toString() ?? '—';
    final metodo      = a['metodo_pago']?.toString()     ?? 'efectivo';
    final hora        = _hora(a['created_at']?.toString() ?? '');
    final color       = _metodoPagoColor(metodo);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.savings_rounded,
              color: Colors.green.shade600, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clienteNom,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: const Color(0xFF1A1A2E))),
            Row(children: [
              Text('Por: $empleadoNom',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey.shade500)),
              const SizedBox(width: 6),
              _chip(_metodoPagoLabel(metodo), color),
            ]),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(monto), style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 14,
              color: Colors.green.shade600)),
          Text(hora, style: GoogleFonts.poppins(
              fontSize: 10, color: Colors.grey.shade400)),
        ]),
      ]),
    );
  }

  // ── Card separado ───────────────────────────────────────
  Widget _separadoCard(Map<String, dynamic> s, NumberFormat fmt) {
    final clienteNom  = s['cliente_nombre']?.toString()  ?? '—';
    final empleadoNom = s['empleado_nombre']?.toString() ?? '—';
    final total       = _d(s, 'total');
    final abonado     = _d(s, 'abono_acumulado');
    final saldo       = _d(s, 'saldo_pendiente');
    final estado      = s['estado']?.toString() ?? 'pendiente';
    final fechaLim    = s['fecha_limite']?.toString() ?? '';
    final detalles    = List<Map<String, dynamic>>.from(s['detalles'] ?? []);
    final pct         = total > 0 ? abonado / total : 0.0;
    final colorE      = _colorEstado(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: colorE.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.inventory_2_rounded, color: colorE, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(clienteNom,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13,
                      color: const Color(0xFF1A1A2E))),
              Text('Vendedor: $empleadoNom',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey.shade500)),
            ],
          )),
          _chip(_estadoLabel(estado), colorE),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Abonado: ${fmt.format(abonado)}',
              style: GoogleFonts.poppins(fontSize: 11,
                  fontWeight: FontWeight.w600, color: Colors.green.shade600)),
          Text('Saldo: ${fmt.format(saldo)}',
              style: GoogleFonts.poppins(fontSize: 11,
                  fontWeight: FontWeight.w600, color: Colors.red.shade400)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0), minHeight: 6,
            backgroundColor: Colors.red.shade50,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade500),
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total: ${fmt.format(total)}',
              style: GoogleFonts.poppins(fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(Constants.primaryColor))),
          if (fechaLim.isNotEmpty)
            Text('Límite: $fechaLim',
                style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.grey.shade400)),
        ]),
        if (detalles.isNotEmpty) ...[
          const Divider(height: 16),
          ...detalles.take(3).map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              const Icon(Icons.circle, size: 5, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(child: Text(d['producto_nombre']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade600))),
              Text('x${d['cantidad']}  ${fmt.format(_d(d, 'subtotal'))}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade500)),
            ]),
          )),
          if (detalles.length > 3)
            Text('+ ${detalles.length - 3} productos más',
                style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.grey.shade400)),
        ],
      ]),
    );
  }

  // ── Micro helpers ───────────────────────────────────────
  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: GoogleFonts.poppins(
        fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  String _hora(String s) {
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:'
             '${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  String _metodoPagoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      default:              return 'Efectivo';
    }
  }

  Color _metodoPagoColor(String m) {
    switch (m) {
      case 'transferencia': return Colors.blue.shade600;
      case 'tarjeta':       return Colors.purple.shade600;
      default:              return Colors.green.shade600;
    }
  }

  IconData _metodoPagoIcon(String m) {
    switch (m) {
      case 'transferencia': return Icons.account_balance_rounded;
      case 'tarjeta':       return Icons.credit_card_rounded;
      default:              return Icons.payments_rounded;
    }
  }

  String _estadoLabel(String e) {
    switch (e) {
      case 'completado': return 'Completado';
      case 'cancelado':  return 'Cancelado';
      default:           return 'Pendiente';
    }
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'completado': return Colors.green.shade600;
      case 'cancelado':  return Colors.red.shade600;
      default:           return Colors.orange.shade600;
    }
  }
}