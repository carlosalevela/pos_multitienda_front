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
const _kError     = Color(0xFFBA1A1A);

class DevolucionCard extends StatelessWidget {
  final DevolucionModel  dev;
  final NumberFormat     fmt;
  final bool             puedeCancel;
  final VoidCallback     onTap;
  final VoidCallback?    onCancelar;

  const DevolucionCard({
    super.key,
    required this.dev,
    required this.fmt,
    required this.puedeCancel,
    required this.onTap,
    this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final esCambio   = dev.tipo == 'cambio';
    final cancelada  = dev.estado == 'cancelada';
    final accentColor = cancelada
        ? _kTextMuted
        : esCambio
            ? _kGreen
            : _kOrange;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: cancelada
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra izquierda de color por tipo
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft:    Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              // Contenido
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila 1: ID + factura | estado + monto
                      Row(children: [
                        Expanded(
                          child: Row(children: [
                            Text(
                              'DEV-${dev.id}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: cancelada ? _kTextMuted : _kText,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '· ${dev.ventaNumero}',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: _kTextMuted),
                            ),
                          ]),
                        ),
                        _ChipEstado(estado: dev.estado),
                        const SizedBox(width: 8),
                        _buildMonto(cancelada, esCambio),
                      ]),
                      const SizedBox(height: 8),
                      // Fila 2: tipo, método, empleado, # productos
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _Chip(
                            label: esCambio ? 'Cambio' : 'Devolución',
                            color: accentColor,
                          ),
                          _Chip(
                            label: _metodoLabel(dev.metodoDevolucion),
                            color: _kTextMuted,
                          ),
                          _Chip(
                            label: dev.empleadoNombre,
                            color: _kTextMuted,
                          ),
                          _Chip(
                            label:
                                '${dev.detalles.length} prod.',
                            color: _kTextMuted,
                          ),
                        ],
                      ),
                      // Producto de reemplazo (solo cambio)
                      if (esCambio &&
                          (dev.productoReemplazoNombre?.isNotEmpty ??
                              false)) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.swap_horiz_rounded,
                              size: 13, color: _kGreen),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${dev.productoReemplazoNombre}'
                              '${dev.cantidadReemplazo != null ? ' ×${_fmtCant(dev.cantidadReemplazo!)}' : ''}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kGreen,
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
              // Botón cancelar (solo admin/supervisor)
              if (puedeCancel && !cancelada)
                Center(
                  child: IconButton(
                    icon: Icon(
                      Icons.cancel_outlined,
                      color: _kError.withValues(alpha: 0.65),
                      size: 20,
                    ),
                    tooltip: 'Cancelar devolución',
                    onPressed: onCancelar,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonto(bool cancelada, bool esCambio) {
    if (cancelada) {
      return Text(
        fmt.format(dev.totalDevuelto),
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _kTextMuted),
      );
    }
    if (!esCambio) {
      return Text(
        '- ${fmt.format(dev.totalDevuelto)}',
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _kOrange),
      );
    }
    final tipoDif = (dev.tipoDiferencia ?? 'exacto').toLowerCase();
    final dif     = dev.diferencia ?? 0.0;
    if (tipoDif == 'cobrar') {
      return Text(
        '+ ${fmt.format(dif)}',
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w700, fontSize: 14, color: _kGreen),
      );
    }
    if (tipoDif == 'devolver') {
      return Text(
        '- ${fmt.format(dif)}',
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w700, fontSize: 14, color: _kOrange),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Text('Exacto',
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _kTextMuted)),
    );
  }

  String _metodoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transf.';
      case 'tarjeta':       return 'Tarjeta';
      case 'nota_credito':  return 'NC';
      default:              return 'Efectivo';
    }
  }

  String _fmtCant(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

// ── Chip genérico ─────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

// ── Chip estado ───────────────────────────────────────────────

class _ChipEstado extends StatelessWidget {
  final String estado;
  const _ChipEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final cancelada = estado == 'cancelada';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cancelada ? _kSurface : _kMintLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cancelada
              ? _kBorder
              : _kGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        cancelada ? 'Cancelada' : 'Procesada',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cancelada ? _kTextMuted : _kGreen,
        ),
      ),
    );
  }
}
