import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/sesion_caja.dart';
import '../../../providers/caja_provider.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../providers/reportes_provider.dart';
import '../../../services/cierre_turno_print_service.dart';
import 'reporte_utils.dart';

// ── Paleta verde (caja cerrada / lista para imprimir) ─────────
const _kGreen    = Color(0xFF0B7A53);
const _kGreenMid = Color(0xFF0D9E6A);

// ── Paleta ámbar (caja abierta / turno en curso) ──────────────
const _kAmber    = Color(0xFFB45309);
const _kAmberMid = Color(0xFFD97706);

class ReporteTurnoCard extends StatelessWidget {
  final SesionCaja sesion;
  final String     fecha;
  final String     tiendaNombre;
  final String     empresaNombre;
  final bool       cajaAbierta;

  const ReporteTurnoCard({
    super.key,
    required this.sesion,
    required this.fecha,
    required this.tiendaNombre,
    required this.empresaNombre,
    this.cajaAbierta = false,
  });

  @override
  Widget build(BuildContext context) {
    final caja   = context.watch<CajaProvider>();
    final rep    = context.watch<ReportesProvider>();
    final contab = context.watch<ContabilidadProvider>();
    final accent = cajaAbierta ? _kAmber : _kGreen;
    final gradStart = cajaAbierta ? _kAmber    : _kGreen;
    final gradEnd   = cajaAbierta ? _kAmberMid : _kGreenMid;

    final horaApertura =
        '${sesion.fecha_apertura.hour.toString().padLeft(2, '0')}:'
        '${sesion.fecha_apertura.minute.toString().padLeft(2, '0')}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradStart, gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono izquierdo
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  cajaAbierta
                      ? Icons.schedule_rounded
                      : Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),

              // Título y subtítulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cajaAbierta ? 'Turno en curso' : 'Resumen de turno',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      '${sesion.empleadoNombre}  •  Apertura: $horaApertura',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Derecha: candado (abierta) o botón imprimir (cerrada)
              if (cajaAbierta)
                Tooltip(
                  message: 'Cierra tu caja para habilitar el reporte',
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => CierreTurnoPrintService.imprimir(
                    context:       context,
                    sesion:        sesion,
                    fecha:         fecha,
                    tiendaNombre:  tiendaNombre,
                    empresaNombre: empresaNombre,
                    metodosPago:   rep.totalPorMetodo,
                    // Para sesiones históricas usa los gastos del día ya cargados
                    // en ContabilidadProvider; para la sesión activa usa la lista viva.
                    gastosSesion: cajaAbierta
                        ? caja.gastosSesion
                        : contab.gastos.map((g) => {
                            'monto':       g.monto,
                            'descripcion': g.descripcion,
                            'categoria':   g.categoria,
                            'metodo_pago': g.metodoPago,
                          }).toList(),
                    totalGastos: cajaAbierta
                        ? caja.gastosTotalSesion
                        : sesion.gastosTotal,
                  ),
                  icon: const Icon(Icons.print_rounded, size: 15),
                  label: Text(
                    'Imprimir cierre',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _kGreen,
                    disabledBackgroundColor: Colors.white54,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 14),

          // ── Balance de caja ──────────────────────────────────
          Row(
            children: [
              _BalanceCell(
                label: 'Saldo apertura',
                value: '\$${fmtNum(sesion.saldo_inicial)}',
                icon: Icons.account_balance_wallet_outlined,
                accent: accent,
              ),
              const _Arrow(),
              _BalanceCell(
                label: 'Ventas del turno',
                value: '+\$${fmtNum(sesion.ventasTotal)}',
                icon: Icons.trending_up_rounded,
                accent: accent,
              ),
              const _Arrow(),
              _BalanceCell(
                label: 'Gastos del turno',
                value: '-\$${fmtNum(cajaAbierta ? caja.gastosTotalSesion : sesion.gastosTotal)}',
                icon: Icons.remove_circle_outline_rounded,
                accent: accent,
              ),
              const _Arrow(),
              _BalanceCell(
                label: 'Efectivo esperado',
                value: '\$${fmtNum(sesion.montoEsperado)}',
                icon: cajaAbierta
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_outline_rounded,
                accent: accent,
                highlight: true,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Chips de métodos + nº transacciones ──────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                '${sesion.numTransacciones} '
                'venta${sesion.numTransacciones != 1 ? "s" : ""}',
                Icons.point_of_sale_rounded,
              ),
              ...rep.totalPorMetodo.entries.map((e) => _MetaChip(
                    '${labelMetodo(e.key)}: \$${fmtNum(e.value)}',
                    iconMetodo(e.key),
                  )),
            ],
          ),

          // ── Aviso cuando la caja está abierta ────────────────
          if (cajaAbierta) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.white70, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    'Cierra tu caja desde la sección Caja para imprimir el reporte',
                    style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// ── Celda del balance ──────────────────────────────────────────

class _BalanceCell extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    accent;
  final bool     highlight;

  const _BalanceCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.white
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: highlight ? null : Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 14,
                color: highlight ? accent : Colors.white70),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: highlight ? accent : Colors.white)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: highlight
                        ? accent.withValues(alpha: 0.65)
                        : Colors.white60)),
          ],
        ),
      ),
    );
  }
}


// ── Flecha entre celdas ────────────────────────────────────────

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Icon(Icons.arrow_forward_rounded,
            size: 14, color: Colors.white38),
      );
}


// ── Chip de metadato (método de pago / nº ventas) ──────────────

class _MetaChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _MetaChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ]),
      );
}
