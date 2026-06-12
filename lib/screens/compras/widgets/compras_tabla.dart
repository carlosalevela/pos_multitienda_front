// lib/screens/compras/widgets/compras_tabla.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../providers/auth_provider.dart';
import '../compras_theme.dart';

class ComprasTabla extends StatelessWidget {
  final ProveedoresProvider                 prov;
  final AuthProvider                        auth;
  final String?                             filtroEstado;
  final VoidCallback                        onNuevaOrden;
  final void Function(int id)               onVerDetalle;
  final void Function(Map<String, dynamic>) onRecibir;
  final void Function(Map<String, dynamic>) onCancelar;

  const ComprasTabla({
    super.key,
    required this.prov,
    required this.auth,
    required this.filtroEstado,
    required this.onNuevaOrden,
    required this.onVerDetalle,
    required this.onRecibir,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    if (prov.compras.isEmpty) {
      return _EmptyState(
        filtroEstado: filtroEstado,
        onNuevaOrden: onNuevaOrden,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              const Icon(Icons.list_alt_rounded,
                  size: 16, color: ComprasTheme.dark),
              const SizedBox(width: 7),
              Text('Órdenes de compra',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize:   14,
                    color:      ComprasTheme.dark)),
              const Spacer(),
              Text('${prov.compras.length} registros',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade400)),
            ]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft:  Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(ComprasTheme.dark),
                headingTextStyle: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize:   12),
                dataTextStyle:    GoogleFonts.poppins(fontSize: 12),
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
                rows: prov.compras.map(_buildRow).toList(),
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
        if (c['estado'] == 'cancelada') return Colors.red.shade50;
        if (c['estado'] == 'recibida')  return Colors.green.shade50;
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFF0F4FF);
        }
        return Colors.white;
      }),
      cells: [
        DataCell(Text(c['numero_orden'] ?? '',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color:      ComprasTheme.accent,
              fontSize:   12))),
        DataCell(Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:        Colors.purple.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(child: Text(
              ((c['proveedor_nombre'] ?? 'P') as String)
                  .substring(0, 1).toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize:   11,
                  fontWeight: FontWeight.bold,
                  color:      Colors.purple.shade600),
            )),
          ),
          const SizedBox(width: 8),
          Text(c['proveedor_nombre'] ?? '',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        ])),
        DataCell(Text(c['empleado_nombre'] ?? '—')),
        DataCell(Text(fecha)),
        DataCell(Text(
          '\$${ComprasTheme.fmt(double.tryParse(c['total'].toString()) ?? 0)}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
        DataCell(EstadoBadge(estado: c['estado'] ?? '')),
        DataCell(Row(children: [
          _AccionBtn(
            icon:    Icons.visibility_rounded,
            color:   Colors.blue.shade600,
            tooltip: 'Ver detalle',
            onTap:   () => onVerDetalle(c['id']),
          ),
          if (esPendiente) ...[
            const SizedBox(width: 6),
            _AccionBtn(
              icon:    Icons.move_to_inbox_rounded,
              color:   Colors.green.shade600,
              tooltip: 'Recibir orden',
              onTap:   () => onRecibir(c),
            ),
          ],
          if (esPendiente && puedeAdmin) ...[
            const SizedBox(width: 6),
            _AccionBtn(
              icon:    Icons.cancel_rounded,
              color:   Colors.red.shade600,
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
  final String?      filtroEstado;
  final VoidCallback onNuevaOrden;

  const _EmptyState({
    required this.filtroEstado,
    required this.onNuevaOrden,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Column(children: [
          Icon(Icons.shopping_cart_outlined,
              size: 52, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text(
            filtroEstado != null
                ? 'Sin órdenes con estado "${ComprasTheme.labelEstado(filtroEstado!)}"'
                : 'No hay órdenes de compra registradas',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onNuevaOrden,
            icon:  const Icon(Icons.add_rounded, size: 16),
            label: Text('Crear primera orden',
                style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComprasTheme.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ComprasTheme.iconEstado(estado), size: 11, color: color),
        const SizedBox(width: 4),
        Text(ComprasTheme.labelEstado(estado),
          style: GoogleFonts.poppins(
              fontSize:   11,
              fontWeight: FontWeight.w600,
              color:      color)),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}