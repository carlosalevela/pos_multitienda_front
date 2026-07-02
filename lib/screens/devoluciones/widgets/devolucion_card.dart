import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/devolucion_model.dart';

const _kGreen     = Color(0xFF006C49);
const _kMintLight = Color(0xFFE8FFF4);
const _kSurface   = Color(0xFFF7F9FB);
const _kText      = Color(0xFF191C1E);
const _kTextMuted = Color(0xFF76777D);
const _kBorder    = Color(0xFFE0E3E5);
const _kOrange    = Color(0xFFF59E0B);

class DevolucionCard extends StatelessWidget {
  final DevolucionModel  dev;
  final NumberFormat     fmt;
  final bool             puedeCancel;
  final bool             selected;
  final VoidCallback     onTap;
  final VoidCallback?    onCancelar;

  const DevolucionCard({
    super.key,
    required this.dev,
    required this.fmt,
    required this.puedeCancel,
    required this.onTap,
    this.selected    = false,
    this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final esCambio  = dev.tipo == 'cambio';
    final cancelada = dev.estado == 'cancelada';

    final iconColor = cancelada
        ? _kTextMuted
        : esCambio ? _kGreen : _kOrange;
    final iconBg = cancelada
        ? _kSurface
        : esCambio
            ? _kGreen.withValues(alpha: 0.1)
            : _kOrange.withValues(alpha: 0.1);
    final iconData = cancelada
        ? Icons.cancel_outlined
        : esCambio
            ? Icons.swap_horiz_rounded
            : Icons.assignment_return_rounded;

    final date = DateFormat('dd/MM/yyyy · HH:mm').format(dev.createdAt);
    final monto = _buildMonto(esCambio, cancelada);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        decoration: BoxDecoration(
          color: selected ? _kGreen.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kGreen.withValues(alpha: 0.5) : _kBorder,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: cancelada ? null : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          // ── Ícono izquierdo ───────────────────────────
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),

          // ── Contenido central ─────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Línea 1: ID + factura
                Row(children: [
                  Text(
                    'DEV-${dev.id}',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: cancelada ? _kTextMuted : _kText),
                  ),
                  const SizedBox(width: 6),
                  Text('· ${dev.ventaNumero}',
                      style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
                ]),
                const SizedBox(height: 3),
                // Línea 2: empleado · fecha
                Text(
                  '${dev.empleadoNombre}  ·  $date',
                  style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                // Línea 3: producto de reemplazo si es cambio
                if (esCambio && (dev.productoReemplazoNombre?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.swap_horiz_rounded, size: 12, color: _kGreen),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${dev.productoReemplazoNombre}'
                        '${dev.cantidadReemplazo != null ? ' ×${_fmtCant(dev.cantidadReemplazo!)}' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600, color: _kGreen),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Columna derecha: estado + monto + chevron ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ChipEstado(estado: dev.estado, tipo: dev.tipo),
              const SizedBox(height: 6),
              monto,
            ],
          ),
          const SizedBox(width: 4),
          // Botón cancelar (admin/supervisor)
          if (puedeCancel && !cancelada)
            GestureDetector(
              onTap: onCancelar,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.more_vert_rounded, size: 18, color: _kTextMuted),
              ),
            )
          else
            const Icon(Icons.chevron_right_rounded, size: 18, color: _kTextMuted),
        ]),
      ),
    );
  }

  Widget _buildMonto(bool esCambio, bool cancelada) {
    if (cancelada) {
      return Text(
        fmt.format(dev.totalDevuelto),
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextMuted),
      );
    }
    if (!esCambio) {
      return Text(
        '- ${fmt.format(dev.totalDevuelto)}',
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kOrange),
      );
    }
    final tipoDif = (dev.tipoDiferencia ?? 'exacto').toLowerCase();
    final dif     = dev.diferencia ?? 0.0;
    if (tipoDif == 'cobrar') {
      return Text(
        '+ ${fmt.format(dif)}',
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kGreen),
      );
    }
    if (tipoDif == 'devolver') {
      return Text(
        '- ${fmt.format(dif)}',
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kOrange),
      );
    }
    return Text(
      'Exacto',
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: _kTextMuted),
    );
  }

  String _fmtCant(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

// ── Chip de estado ────────────────────────────────────────────

class _ChipEstado extends StatelessWidget {
  final String estado;
  final String tipo;
  const _ChipEstado({required this.estado, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final cancelada = estado == 'cancelada';
    final esCambio  = tipo == 'cambio';

    final Color bg;
    final Color border;
    final Color text;
    final String label;

    if (cancelada) {
      bg     = _kSurface;
      border = _kBorder;
      text   = _kTextMuted;
      label  = 'Cancelada';
    } else if (esCambio) {
      bg     = _kGreen.withValues(alpha: 0.08);
      border = _kGreen.withValues(alpha: 0.25);
      text   = _kGreen;
      label  = 'Cambio';
    } else {
      bg     = _kMintLight;
      border = _kGreen.withValues(alpha: 0.25);
      text   = _kGreen;
      label  = 'Procesada';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
    );
  }
}
