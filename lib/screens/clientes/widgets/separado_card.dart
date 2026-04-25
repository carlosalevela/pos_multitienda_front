import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/separado.dart';

class SeparadoCard extends StatelessWidget {
  final Separado      separado;
  final NumberFormat  fmt;
  final VoidCallback? onTap;
  final VoidCallback? onAbonar;
  final VoidCallback? onCancelar;
  final bool          mostrarAcciones;

  const SeparadoCard({
    super.key,
    required this.separado,
    required this.fmt,
    this.onTap,
    this.onAbonar,
    this.onCancelar,
    this.mostrarAcciones = false,
  });

  // ── Colores y label por estado ─────────────────────────
  Color _colorEstado() => switch (separado.estado) {
    'pagado'    => const Color(0xFF437A22),
    'cancelado' => const Color(0xFF7A7974),
    _           => const Color(0xFF01696F),   // activo
  };

  Color _bgEstado() => switch (separado.estado) {
    'pagado'    => const Color(0xFFD4DFCC),
    'cancelado' => const Color(0xFFF3F0EC),
    _           => const Color(0xFFCEDCD8),   // activo
  };

  String _labelEstado() => switch (separado.estado) {
    'pagado'    => 'Pagado',
    'cancelado' => 'Cancelado',
    _           => 'Activo',
  };

  IconData _iconoEstado() => switch (separado.estado) {
    'pagado'    => Icons.check_circle_rounded,
    'cancelado' => Icons.cancel_rounded,
    _           => Icons.schedule_rounded,
  };

  // ── Alerta de fecha límite ─────────────────────────────
  _AlertaFecha? _alertaFecha() {
    if (separado.fechaLimite == null || !separado.esActivo) return null;
    final limite = DateTime.tryParse(separado.fechaLimite!);
    if (limite == null) return null;
    final hoy    = DateTime.now();
    final dias   = limite.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    if (dias < 0)  return _AlertaFecha('Venció hace ${dias.abs()} día${dias.abs() != 1 ? 's' : ''}',  Colors.red.shade400);
    if (dias == 0) return _AlertaFecha('Vence hoy',                                                    Colors.orange.shade600);
    if (dias <= 3) return _AlertaFecha('Vence en $dias día${dias != 1 ? 's' : ''}',                   Colors.orange.shade400);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final alerta      = _alertaFecha();
    final cancelado   = separado.esCancelado;
    final colorEstado = _colorEstado();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cancelado ? const Color(0xFFF9F8F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: alerta != null
              ? Border.all(color: alerta.color.withOpacity(0.4), width: 1.5)
              : null,
          boxShadow: cancelado
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Fila superior: ID + estado + acciones ────
              Row(
                children: [
                  // Ícono estado
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _bgEstado(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_iconoEstado(),
                        size: 18, color: colorEstado),
                  ),
                  const SizedBox(width: 10),

                  // ID + cliente
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEP-${separado.id}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cancelado
                                ? const Color(0xFF7A7974)
                                : const Color(0xFF28251D),
                          ),
                        ),
                        Text(
                          separado.clienteNombre,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF7A7974),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chip estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _bgEstado(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _labelEstado(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorEstado,
                      ),
                    ),
                  ),

                  // Menú acciones
                  if (mostrarAcciones && separado.esActivo) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          size: 20, color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'abonar',
                          child: Row(children: [
                            const Icon(Icons.payments_outlined,
                                size: 16, color: Color(0xFF01696F)),
                            const SizedBox(width: 10),
                            Text('Registrar abono',
                                style: GoogleFonts.poppins(fontSize: 13)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'cancelar',
                          child: Row(children: [
                            Icon(Icons.cancel_outlined,
                                size: 16, color: Colors.red.shade400),
                            const SizedBox(width: 10),
                            Text('Cancelar separado',
                                style: GoogleFonts.poppins(fontSize: 13)),
                          ]),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == 'abonar')   onAbonar?.call();
                        if (v == 'cancelar') onCancelar?.call();
                      },
                    ),
                  ] else ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey.shade300, size: 20),
                  ],
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 12),

              // ── Barra de progreso ────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Abonado: ${fmt.format(separado.abonoAcumulado)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF7A7974),
                        ),
                      ),
                      Text(
                        'Total: ${fmt.format(separado.total)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF28251D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:            separado.progreso,
                      minHeight:        6,
                      backgroundColor:  const Color(0xFFF3F0EC),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        cancelado
                            ? Colors.grey.shade300
                            : colorEstado,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Fila inferior: saldo + tienda + fecha ────
              Row(
                children: [
                  // Saldo pendiente
                  if (separado.esActivo) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCEDCD8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Saldo: ${fmt.format(separado.saldoPendiente)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF01696F),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Tienda
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.store_outlined,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            separado.tiendaNombre,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF7A7974),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Fecha límite o creación
                  Row(
                    children: [
                      Icon(
                        separado.fechaLimite != null
                            ? Icons.event_outlined
                            : Icons.calendar_today_outlined,
                        size: 12,
                        color: alerta?.color ?? Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        separado.fechaLimite != null
                            ? DateFormat('dd/MM/yyyy')
                                .format(DateTime.parse(separado.fechaLimite!))
                            : DateFormat('dd/MM/yy')
                                .format(separado.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: alerta?.color ?? const Color(0xFF7A7974),
                          fontWeight: alerta != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Alerta de vencimiento ────────────────────
              if (alerta != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: alerta.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: alerta.color.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 13, color: alerta.color),
                      const SizedBox(width: 6),
                      Text(
                        alerta.mensaje,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: alerta.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

            ],
          ),
        ),
      ),
    );
  }
}

// ── Modelo interno para alertas de fecha ──────────────────────
class _AlertaFecha {
  final String mensaje;
  final Color  color;
  const _AlertaFecha(this.mensaje, this.color);
}