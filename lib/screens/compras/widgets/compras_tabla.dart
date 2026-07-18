// lib/screens/compras/widgets/compras_tabla.dart

import 'package:flutter/material.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../compras_theme.dart';

class ComprasTabla extends StatelessWidget {
  final List<Map<String, dynamic>>          compras;
  final AuthProvider                        auth;
  final bool                                hayFiltro;
  final VoidCallback                        onNuevaOrden;
  final void Function(int id)               onVerDetalle;
  final void Function(Map<String, dynamic>) onRecibir;
  final void Function(Map<String, dynamic>) onCancelar;

  const ComprasTabla({
    super.key,
    required this.compras,
    required this.auth,
    required this.hayFiltro,
    required this.onNuevaOrden,
    required this.onVerDetalle,
    required this.onRecibir,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    if (compras.isEmpty) {
      return _EmptyState(
        hayFiltro:   hayFiltro,
        onNuevaOrden: onNuevaOrden,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lg,
        boxShadow: [BoxShadow(
          color:      Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset:     const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              const Icon(Icons.list_alt_rounded,
                  size: 16, color: AppColors.onSurface),
              const SizedBox(width: 7),
              Text('Órdenes de compra',
                  style: AppTextStyles.bodyMd
                      .copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${compras.length} registro(s)',
                  style: AppTextStyles.bodySm),
            ]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft:  Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                    AppColors.primaryContainer),
                headingTextStyle: AppTextStyles.labelMd
                    .copyWith(color: AppColors.onSecondary,
                        letterSpacing: 0.4),
                dataTextStyle: AppTextStyles.bodyMd
                    .copyWith(fontSize: 13),
                columnSpacing:    20,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                dividerThickness: 0.5,
                columns: const [
                  DataColumn(label: Text('Orden')),
                  DataColumn(label: Text('Proveedor')),
                  DataColumn(label: Text('Empleado')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: compras.map(_buildRow).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> c) {
    final fecha = (c['fecha_orden']?.toString() ?? '').length >= 10
        ? c['fecha_orden'].toString().substring(0, 10)
        : '';
    final esPendiente = c['estado'] == 'pendiente';
    final puedeAdmin  = ComprasTheme.esAdmin(auth.rol);

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (c['estado'] == 'cancelada') return AppColors.errorContainer;
        if (c['estado'] == 'recibida')  return AppColors.mintLight;
        if (states.contains(WidgetState.hovered)) {
          return AppColors.surfaceContainerLow;
        }
        return AppColors.surfaceContainerLowest;
      }),
      cells: [
        // Número de orden
        DataCell(Text(c['numero_orden'] ?? '',
            style: AppTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
                color:      AppColors.secondary,
                fontSize:   13))),

        // Proveedor con avatar
        DataCell(Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:        AppColors.secondaryContainer,
              borderRadius: AppRadius.md,
            ),
            child: Center(
              child: Text(
                ((c['proveedor_nombre'] ?? 'P') as String)
                    .substring(0, 1).toUpperCase(),
                style: AppTextStyles.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSecondaryContainer),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(c['proveedor_nombre'] ?? '',
              style: AppTextStyles.bodyMd.copyWith(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ])),

        DataCell(Text(c['empleado_nombre'] ?? '—',
            style: AppTextStyles.bodyMd.copyWith(fontSize: 13))),
        DataCell(Text(fecha,
            style: AppTextStyles.bodyMd.copyWith(fontSize: 13))),

        // Total
        DataCell(Text(
          '\$${ComprasTheme.fmt(double.tryParse(c['total'].toString()) ?? 0)}',
          style: AppTextStyles.bodyMd.copyWith(
              fontSize: 13, fontWeight: FontWeight.w600))),

        DataCell(EstadoBadge(estado: c['estado'] ?? '')),

        // Acciones
        DataCell(Row(children: [
          _AccionBtn(
            icon:    Icons.visibility_rounded,
            color:   AppColors.secondary,
            tooltip: 'Ver detalle',
            onTap:   () => onVerDetalle(c['id']),
          ),
          if (esPendiente) ...[
            const SizedBox(width: 6),
            _AccionBtn(
              icon:    Icons.move_to_inbox_rounded,
              color:   AppColors.mintDark,
              tooltip: 'Recibir orden',
              onTap:   () => onRecibir(c),
            ),
          ],
          if (esPendiente && puedeAdmin) ...[
            const SizedBox(width: 6),
            _AccionBtn(
              icon:    Icons.cancel_rounded,
              color:   AppColors.error,
              tooltip: 'Cancelar orden',
              onTap:   () => onCancelar(c),
            ),
          ],
        ])),
      ],
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool         hayFiltro;
  final VoidCallback onNuevaOrden;

  const _EmptyState({
    required this.hayFiltro,
    required this.onNuevaOrden,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        color:        AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lg,
      ),
      child: Center(
        child: Column(children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 52, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          Text(
            hayFiltro
                ? 'No hay órdenes que coincidan con el filtro'
                : 'No hay órdenes de compra registradas',
            style: AppTextStyles.bodySm,
          ),
          const SizedBox(height: 16),
          if (!hayFiltro)
            ElevatedButton.icon(
              onPressed: onNuevaOrden,
              icon:  const Icon(Icons.add_rounded, size: 16),
              label: Text('Crear primera orden',
                  style: AppTextStyles.bodyMd
                      .copyWith(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.xl),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Badge de estado (público, reutilizable) ───────────────────

class EstadoBadge extends StatelessWidget {
  final String estado;
  const EstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = ComprasTheme.colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ComprasTheme.iconEstado(estado), size: 11, color: color),
        const SizedBox(width: 4),
        Text(ComprasTheme.labelEstado(estado),
            style: AppTextStyles.labelSm.copyWith(
                fontSize:   11,
                fontWeight: FontWeight.w700,
                color:      color,
                letterSpacing: 0)),
      ]),
    );
  }
}

// ── Botón de acción ───────────────────────────────────────────

class _AccionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;

  const _AccionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap:        onTap,
        borderRadius: AppRadius.md,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.10),
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
