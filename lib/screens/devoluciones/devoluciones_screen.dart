import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/devolucion_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/devoluciones_provider.dart';
import 'widgets/devolucion_card.dart';
import 'widgets/devolucion_detalle_sheet.dart';
import 'widgets/devolucion_form_sheet.dart';
import 'widgets/filtros_bar.dart';

class DevolucionesScreen extends StatefulWidget {
  const DevolucionesScreen({super.key});

  @override
  State<DevolucionesScreen> createState() => _DevolucionesScreenState();
}

class _DevolucionesScreenState extends State<DevolucionesScreen> {
  final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  String? _fechaActual;
  String? _fechaIniActual;
  String? _fechaFinActual;
  String? _estadoActual;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar(fecha: _strFecha(DateTime.now()));
    });
  }

  String _strFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _puedeCancel => context.read<AuthProvider>().esAdminOSupervisor;

  Future<void> _cargar({
    String? fecha,
    String? fechaIni,
    String? fechaFin,
    String? estado,
  }) async {
    setState(() {
      _fechaActual = fecha;
      _fechaIniActual = fechaIni;
      _fechaFinActual = fechaFin;
      _estadoActual = estado;
    });

    final auth = context.read<AuthProvider>();
    await context.read<DevolucionesProvider>().cargarDevoluciones(
      tiendaId: auth.tiendaId != 0 ? auth.tiendaId : null,
      fecha: fecha,
      fechaIni: fechaIni,
      fechaFin: fechaFin,
      estado: estado,
    );
  }

  Future<void> _recargar() => _cargar(
        fecha: _fechaActual,
        fechaIni: _fechaIniActual,
        fechaFin: _fechaFinActual,
        estado: _estadoActual,
      );

  void _confirmarCancelar(DevolucionModel dev) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cancelar devolución?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se revertirá el stock de ${dev.detalles.length} '
          'producto${dev.detalles.length != 1 ? 's' : ''}. '
          'Esta acción no se puede deshacer.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Volver',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final prov = context.read<DevolucionesProvider>();
              final ok = await prov.cancelarDevolucion(dev.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Devolución cancelada ✅' : prov.error ?? 'Error al cancelar',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  backgroundColor: ok ? Colors.green.shade600 : Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Cancelar devolución',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DevolucionesProvider>(
      builder: (_, prov, __) {
        final devoluciones = prov.devoluciones;
        final procesadas = devoluciones.where((d) => d.estado == 'procesada').toList();

        final totalDevuelto = procesadas.fold<double>(0.0, (sum, d) {
          if (d.tipo == 'devolucion') return sum + d.totalDevuelto;
          return sum;
        });

        final totalCobradoCambios = procesadas.fold<double>(0.0, (sum, d) {
          if (d.tipo == 'cambio' && (d.tipoDiferencia ?? '').toLowerCase() == 'cobrar') {
            return sum + (d.diferencia ?? 0.0);
          }
          return sum;
        });

        final totalDevueltoCambios = procesadas.fold<double>(0.0, (sum, d) {
          if (d.tipo == 'cambio' && (d.tipoDiferencia ?? '').toLowerCase() == 'devolver') {
            return sum + (d.diferencia ?? 0.0);
          }
          return sum;
        });

        final balanceNeto = totalCobradoCambios - totalDevuelto - totalDevueltoCambios;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                totalDevuelto: totalDevuelto,
                totalCobradoCambios: totalCobradoCambios,
                totalDevueltoCambios: totalDevueltoCambios,
                balanceNeto: balanceNeto,
                fmt: _fmt,
                cantidad: devoluciones.length,
                onNueva: () => DevolucionFormSheet.show(
                  context,
                  onCreada: _recargar,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ResumenChip(
                    label: 'Devuelto',
                    value: '- ${_fmt.format(totalDevuelto)}',
                    color: Colors.orange.shade700,
                  ),
                  _ResumenChip(
                    label: 'Cobrado cambios',
                    value: '+ ${_fmt.format(totalCobradoCambios)}',
                    color: Colors.green.shade700,
                  ),
                  _ResumenChip(
                    label: 'Devuelto cambios',
                    value: '- ${_fmt.format(totalDevueltoCambios)}',
                    color: Colors.deepOrange.shade600,
                  ),
                  _ResumenChip(
                    label: 'Balance neto',
                    value: balanceNeto > 0
                        ? '+ ${_fmt.format(balanceNeto)}'
                        : balanceNeto < 0
                            ? '- ${_fmt.format(balanceNeto.abs())}'
                            : _fmt.format(0),
                    color: balanceNeto > 0
                        ? Colors.green.shade700
                        : balanceNeto < 0
                            ? Colors.deepOrange.shade600
                            : Colors.blueGrey.shade600,
                    filled: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FiltrosBar(
                onFiltrar: ({fecha, fechaIni, fechaFin, estado}) => _cargar(
                  fecha: fecha,
                  fechaIni: fechaIni,
                  fechaFin: fechaFin,
                  estado: estado,
                ),
              ),
              const SizedBox(height: 12),
              if (prov.error != null) ...[
                _ErrorBanner(mensaje: prov.error!),
                const SizedBox(height: 12),
              ],
              if (prov.cargando)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (devoluciones.isEmpty)
                _EstadoVacio(
                  onNueva: () => DevolucionFormSheet.show(
                    context,
                    onCreada: _recargar,
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _recargar,
                    child: ListView.builder(
                      itemCount: devoluciones.length,
                      itemBuilder: (_, i) {
                        final dev = devoluciones[i];
                        return DevolucionCard(
                          dev: dev,
                          fmt: _fmt,
                          puedeCancel: _puedeCancel,
                          onTap: () => DevolucionDetalleSheet.show(
                            context,
                            dev: dev,
                            fmt: _fmt,
                          ),
                          onCancelar: () => _confirmarCancelar(dev),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final double totalDevuelto;
  final double totalCobradoCambios;
  final double totalDevueltoCambios;
  final double balanceNeto;
  final NumberFormat fmt;
  final int cantidad;
  final VoidCallback onNueva;

  const _Header({
    required this.totalDevuelto,
    required this.totalCobradoCambios,
    required this.totalDevueltoCambios,
    required this.balanceNeto,
    required this.fmt,
    required this.cantidad,
    required this.onNueva,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Devoluciones',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$cantidad registro${cantidad != 1 ? 's' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onNueva,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            'Nueva',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(Constants.primaryColor),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

class _ResumenChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool filled;

  const _ResumenChip({
    required this.label,
    required this.value,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String mensaje;

  const _ErrorBanner({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(Constants.errorColor).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(Constants.errorColor).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: const Color(Constants.errorColor),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(Constants.errorColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final VoidCallback onNueva;

  const _EstadoVacio({required this.onNueva});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_return_rounded,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin devoluciones en este período',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade400,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onNueva,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Registrar devolución',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(Constants.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}