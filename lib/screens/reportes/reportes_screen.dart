import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reportes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contabilidad_provider.dart';          // ✅ NUEVO
import '../../services/venta_service.dart';
import 'widgets/reporte_header.dart';
import 'widgets/reporte_kpis.dart';
import 'widgets/reporte_metodos_pago.dart';
import 'widgets/reporte_devoluciones_card.dart';
import 'widgets/reporte_top_productos.dart';
import 'widgets/reporte_tabla.dart';
import 'widgets/reporte_detalle_dialog.dart';
import 'widgets/reporte_gastos_card.dart';                    // ✅ NUEVO


class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}


class _ReportesScreenState extends State<ReportesScreen> {
  DateTime _fecha = DateTime.now();
  final _ventaService = VentaService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  void _cargar() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    // ✅ Ambas cargas en paralelo
    context.read<ReportesProvider>().cargarVentas(
      tiendaId: auth.tiendaId,
      fecha: _fechaStr,
    );
    context.read<ContabilidadProvider>().cargarGastos(
      tiendaId: auth.tiendaId,
      fecha: _fechaStr,
    );
  }

  String get _fechaStr =>
      '${_fecha.year}-'
      '${_fecha.month.toString().padLeft(2, '0')}-'
      '${_fecha.day.toString().padLeft(2, '0')}';

  Future<void> _seleccionarFecha() async {
    final nueva = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (nueva == null || !mounted) return;
    setState(() => _fecha = nueva);
    _cargar();
  }

  Future<void> _abrirDetalle(BuildContext ctx, int ventaId) async {
    try {
      final detalle = await _ventaService.obtenerVenta(ventaId);
      if (!ctx.mounted || detalle == null) return;
      showDialog(
        context: ctx,
        builder: (_) => ReporteDetalleDialog(detalle: detalle),
      );
    } catch (_) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('Error al cargar el detalle de la venta'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rep  = context.watch<ReportesProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            ReporteHeader(
              rep: rep,
              auth: auth,
              fechaStr: _fechaStr,
              cargando: rep.cargando,
              onFecha: _seleccionarFecha,
              onRecargar: _cargar,
            ),
            Expanded(
              child: rep.cargando
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide   = constraints.maxWidth >= 1100;
                        final isMedium = constraints.maxWidth >= 760;

                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 20 : 14,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ReporteKpis(rep: rep),
                              const SizedBox(height: 16),

                              // ── Layout WIDE ≥1100px ──────────────────
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 320,
                                      child: Column(
                                        children: [
                                          ReporteMetodosPago(rep: rep),
                                          if (rep.numDevoluciones > 0) ...[
                                            const SizedBox(height: 12),
                                            ReporteDevolucionesCard(rep: rep),
                                          ],
                                          const SizedBox(height: 12),
                                          const ReporteGastosCard(), // ✅
                                          const SizedBox(height: 12),
                                          ReporteTopProductos(rep: rep),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ReporteTabla(
                                        rep: rep,
                                        onTapVenta: (id) =>
                                            _abrirDetalle(context, id),
                                      ),
                                    ),
                                  ],
                                )

                              // ── Layout MEDIUM ≥760px y MOBILE ────────
                              else ...[
                                if (isMedium)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            ReporteMetodosPago(rep: rep),
                                            if (rep.numDevoluciones > 0) ...[
                                              const SizedBox(height: 12),
                                              ReporteDevolucionesCard(rep: rep),
                                            ],
                                            const SizedBox(height: 12),
                                            const ReporteGastosCard(), // ✅
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ReporteTopProductos(rep: rep),
                                      ),
                                    ],
                                  )
                                else ...[
                                  ReporteMetodosPago(rep: rep),
                                  if (rep.numDevoluciones > 0) ...[
                                    const SizedBox(height: 12),
                                    ReporteDevolucionesCard(rep: rep),
                                  ],
                                  const SizedBox(height: 12),
                                  const ReporteGastosCard(),           // ✅
                                  const SizedBox(height: 12),
                                  ReporteTopProductos(rep: rep),
                                ],
                                const SizedBox(height: 16),
                                ReporteTabla(
                                  rep: rep,
                                  onTapVenta: (id) =>
                                      _abrirDetalle(context, id),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}