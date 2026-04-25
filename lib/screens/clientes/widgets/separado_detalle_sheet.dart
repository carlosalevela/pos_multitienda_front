import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/separado.dart';
import 'abonar_sheet.dart';

class SeparadoDetalleSheet extends StatelessWidget {
  final Separado     separado;
  final NumberFormat fmt;
  final bool         mostrarAcciones;
  final VoidCallback? onAbonar;
  final VoidCallback? onCancelar;

  const SeparadoDetalleSheet({
    super.key,
    required this.separado,
    required this.fmt,
    this.mostrarAcciones = false,
    this.onAbonar,
    this.onCancelar,
  });

  // ── Lanzador estático ──────────────────────────────────
  static Future<void> mostrar(
    BuildContext context, {
    required Separado     separado,
    required NumberFormat fmt,
    bool                  mostrarAcciones = false,
    VoidCallback?         onAbonar,
    VoidCallback?         onCancelar,
  }) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => SeparadoDetalleSheet(
        separado:        separado,
        fmt:             fmt,
        mostrarAcciones: mostrarAcciones,
        onAbonar:        onAbonar,
        onCancelar:      onCancelar,
      ),
    );
  }

  // ── Colores por estado ─────────────────────────────────
  Color _colorEstado() => switch (separado.estado) {
    'pagado'    => const Color(0xFF437A22),
    'cancelado' => const Color(0xFF7A7974),
    _           => const Color(0xFF01696F),
  };

  Color _bgEstado() => switch (separado.estado) {
    'pagado'    => const Color(0xFFD4DFCC),
    'cancelado' => const Color(0xFFF3F0EC),
    _           => const Color(0xFFCEDCD8),
  };

  String _labelEstado() => switch (separado.estado) {
    'pagado'    => 'Pagado',
    'cancelado' => 'Cancelado',
    _           => 'Activo',
  };

  // ── Fila de info ───────────────────────────────────────
  Widget _infoRow(IconData icono, String label, String valor) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icono, size: 15, color: const Color(0xFFBAB9B4)),
            const SizedBox(width: 10),
            Text(
              '$label  ',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF7A7974),
              ),
            ),
            Expanded(
              child: Text(
                valor,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF28251D),
                ),
              ),
            ),
          ],
        ),
      );

  // ── Card de producto ───────────────────────────────────
  Widget _productoItem(DetalleSeparado d) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F8F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEDEAE5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF01696F).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 17, color: Color(0xFF01696F)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.productoNombre,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF28251D),
                    ),
                  ),
                  Text(
                    'x${d.cantidad % 1 == 0 ? d.cantidad.toInt() : d.cantidad}  •  '
                    '${fmt.format(d.precioUnitario)} c/u',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF7A7974),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              fmt.format(d.subtotal),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF28251D),
              ),
            ),
          ],
        ),
      );

  // ── Card de abono ──────────────────────────────────────
  Widget _abonoItem(AbonoSeparado a) {
    final metodoColor = switch (a.metodoPago) {
      'transferencia' => Colors.blue.shade600,
      'tarjeta'       => const Color(0xFF7A39BB),
      _               => const Color(0xFF437A22),
    };
    final metodoLabel = switch (a.metodoPago) {
      'transferencia' => 'Transferencia',
      'tarjeta'       => 'Tarjeta',
      _               => 'Efectivo',
    };
    final metodoIcono = switch (a.metodoPago) {
      'transferencia' => Icons.swap_horiz_rounded,
      'tarjeta'       => Icons.credit_card_outlined,
      _               => Icons.payments_outlined,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEAE5)),
      ),
      child: Row(
        children: [
          // Ícono método
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: metodoColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(metodoIcono, size: 16, color: metodoColor),
          ),
          const SizedBox(width: 10),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metodoLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF28251D),
                  ),
                ),
                if (a.empleadoNombre != null)
                  Text(
                    a.empleadoNombre!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF7A7974),
                    ),
                  ),
              ],
            ),
          ),

          // Monto + fecha
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt.format(a.monto),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF437A22),
                ),
              ),
              Text(
                DateFormat('dd/MM/yy HH:mm').format(a.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFFBAB9B4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sección con título ─────────────────────────────────
  Widget _seccion(String titulo, {required Widget child}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF28251D),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      );

  @override
  Widget build(BuildContext context) {
    final colorEstado = _colorEstado();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Handle ─────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header fijo ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                // ID + estado
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEP-${separado.id}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF28251D),
                      ),
                    ),
                    Text(
                      separado.clienteNombre,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF7A7974),
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Chip estado
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _bgEstado(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _labelEstado(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorEstado,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // ── Contenido scrollable ───────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Barra de progreso ───────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F8F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4D1CA)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _montoLabel('Total',
                                fmt.format(separado.total),
                                const Color(0xFF28251D)),
                            _montoLabel('Abonado',
                                fmt.format(separado.abonoAcumulado),
                                const Color(0xFF437A22)),
                            _montoLabel('Pendiente',
                                fmt.format(separado.saldoPendiente),
                                const Color(0xFFA12C7B)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:           separado.progreso,
                            minHeight:       8,
                            backgroundColor: const Color(0xFFDCD9D5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              separado.esCancelado
                                  ? Colors.grey.shade300
                                  : colorEstado,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Info general ────────────────────────
                  _seccion(
                    'Información general',
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F8F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEDEAE5)),
                      ),
                      child: Column(
                        children: [
                          _infoRow(Icons.store_outlined,
                              'Tienda', separado.tiendaNombre),
                          if (separado.empleadoNombre != null)
                            _infoRow(Icons.badge_outlined,
                                'Empleado', separado.empleadoNombre!),
                          _infoRow(Icons.calendar_today_outlined,
                              'Fecha',
                              DateFormat('dd/MM/yyyy HH:mm')
                                  .format(separado.createdAt)),
                          if (separado.fechaLimite != null)
                            _infoRow(Icons.event_outlined,
                                'Límite', separado.fechaLimite!),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Productos ───────────────────────────
                  _seccion(
                    'Productos (${separado.detalles.length})',
                    child: Column(
                      children: separado.detalles
                          .map(_productoItem)
                          .toList(),
                    ),
                  ),

                  // ── Abonos ──────────────────────────────
                  if (separado.abonos.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _seccion(
                      'Abonos (${separado.abonos.length})',
                      child: Column(
                        children: separado.abonos
                            .map(_abonoItem)
                            .toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Botones de acción fijos abajo ──────────────
          if (mostrarAcciones && separado.esActivo) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20,
                  14 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  // Cancelar separado
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onCancelar?.call();
                      },
                      icon: Icon(Icons.cancel_outlined,
                          size: 17, color: Colors.red.shade400),
                      label: Text(
                        'Cancelar',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade400,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Abonar
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onAbonar?.call();
                      },
                      icon: const Icon(Icons.payments_rounded,
                          size: 17, color: Colors.white),
                      label: Text(
                        'Registrar abono',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01696F),
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],

        ],
      ),
    );
  }

  // ── Helper monto con label ─────────────────────────────
  Widget _montoLabel(String label, String valor, Color color) =>
      Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: const Color(0xFF7A7974),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
}