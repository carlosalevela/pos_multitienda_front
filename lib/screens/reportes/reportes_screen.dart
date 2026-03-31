import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/reportes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../services/venta_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  DateTime _fecha = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final rep  = context.read<ReportesProvider>();
      rep.cargarVentas(
        tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
        fecha: _fecha.toIso8601String().substring(0, 10),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final rep  = context.watch<ReportesProvider>();
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(Constants.primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    color: Color(Constants.primaryColor)),
              ),
              const SizedBox(width: 12),
              Text('Reportes de ventas',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _seleccionarFecha,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(
                  '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Resumen del día
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total vendido',
                      style: GoogleFonts.poppins(
                          color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('\$${rep.totalDia.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(Constants.primaryColor),
                      )),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Número de ventas',
                      style: GoogleFonts.poppins(
                          color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${rep.ventas.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabla / lista
          Expanded(
            child: rep.cargando
                ? const Center(child: CircularProgressIndicator())
                : rep.ventas.isEmpty
                    ? Center(
                        child: Text('Sin ventas para esta fecha',
                          style: GoogleFonts.poppins(color: Colors.grey)),
                      )
                    : _buildTabla(rep),
          ),
        ],
      ),
    );
  }

  Widget _buildTabla(ReportesProvider rep) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(const Color(0xFF1A1A2E)),
            headingTextStyle: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            dataTextStyle: GoogleFonts.poppins(fontSize: 13),
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Factura')),
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('Cliente')),
              DataColumn(label: Text('Método')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Estado')),
            ],
            rows: rep.ventas.map((v) {
              final created = v['created_at']?.toString() ?? '';
              final fecha = created.length >= 10 ? created.substring(0, 10) : created;
              return DataRow(
                    onSelectChanged: (selected) {
                      if (selected == true && v['id'] != null) {
                      _abrirDetalleVenta(context, v['id']);
                    }
                  },
                cells: [
                DataCell(Text(v['numero_factura'] ?? '')),
                DataCell(Text(fecha)),
                DataCell(Text(v['cliente_nombre'] ?? '')),
                DataCell(Text(v['metodo_pago'] ?? '')),
                DataCell(Text(
                  '\$${(v['total'] ?? 0).toString()}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                )),
                DataCell(Text(
                  v['estado'] ?? '',
                  style: GoogleFonts.poppins(
                    color: (v['estado'] == 'anulada')
                        ? Colors.red
                        : Colors.green,
                  ),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final nueva = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (nueva == null) return;
    setState(() => _fecha = nueva);

    final auth = context.read<AuthProvider>();
    await context.read<ReportesProvider>().cargarVentas(
      tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
      fecha: _fecha.toIso8601String().substring(0, 10),
    );
  }

    Future<void> _abrirDetalleVenta(BuildContext context, int ventaId) async {
    final ventaService = VentaService();
    final detalle = await ventaService.obtenerVenta(ventaId);

    if (!context.mounted || detalle == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Detalle ${detalle['numero_factura'] ?? ''}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cliente: ${detalle['cliente_nombre'] ?? 'Consumidor Final'}'),
                Text('Empleado: ${detalle['empleado_nombre'] ?? ''}'),
                Text('Método: ${detalle['metodo_pago'] ?? ''}'),
                Text('Total: \$${detalle['total'] ?? 0}'),
                Text('Estado: ${detalle['estado'] ?? ''}'),
                const SizedBox(height: 16),
                Text('Productos:',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...(detalle['detalles'] as List? ?? []).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item['producto_nombre'] ?? '')),
                        Text('x${item['cantidad']}'),
                        Text('\$${item['subtotal'] ?? 0}'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}