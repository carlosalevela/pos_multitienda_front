// lib/screens/proveedores/widgets/proveedores_tabla.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../core/constants.dart';

class ProveedoresTabla extends StatelessWidget {
  final ProveedoresProvider                prov;
  final String                             searchText;
  final ValueChanged<Map<String, dynamic>> onEditar;
  final ValueChanged<Map<String, dynamic>> onEliminar;
  final VoidCallback                       onNuevo;

  const ProveedoresTabla({
    super.key,
    required this.prov,
    required this.searchText,
    required this.onEditar,
    required this.onEliminar,
    required this.onNuevo,
  });

  static const _dark   = Color(0xFF1A1A2E);
  static const _accent = Color(Constants.primaryColor);

  @override
  Widget build(BuildContext context) {
    if (prov.proveedores.isEmpty) return _emptyState();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              const Icon(Icons.list_alt_rounded, size: 16, color: _dark),
              const SizedBox(width: 7),
              Text('Lista de proveedores',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _dark)),
              const Spacer(),
              Text('${prov.proveedores.length} registros',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade400)),
            ]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft:  Radius.circular(14),
              bottomRight: Radius.circular(14)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor:    WidgetStateProperty.all(_dark),
                headingTextStyle: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
                dataTextStyle:    GoogleFonts.poppins(fontSize: 12),
                columnSpacing:    24,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                dividerThickness: 0.5,
                columns: const [
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('NIT')),
                  DataColumn(label: Text('Teléfono')),
                  DataColumn(label: Text('Ciudad')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Empresa')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: prov.proveedores.map((p) => DataRow(
                  color: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.hovered)
                          ? const Color(0xFFF0F4FF)
                          : Colors.white),
                  cells: [
                    DataCell(Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(
                          (p['nombre'] as String)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _accent),
                        )),
                      ),
                      const SizedBox(width: 10),
                      Text(p['nombre'] ?? '',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    ])),
                    DataCell(Text(p['nit'] ?? '—')),
                    DataCell(Text(
                        p['telefono']?.isNotEmpty == true
                            ? p['telefono'] : '—')),
                    DataCell(Text(
                        p['ciudad']?.isNotEmpty == true
                            ? p['ciudad'] : '—')),
                    DataCell(Text(
                        p['email']?.isNotEmpty == true
                            ? p['email'] : '—',
                      style: GoogleFonts.poppins(
                          color: p['email']?.isNotEmpty == true
                              ? Colors.blue.shade600
                              : Colors.grey.shade400))),
                    DataCell(Text(
                        p['empresa_nombre'] ?? '—',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600))),
                    DataCell(_estadoBadge(p['activo'] ?? true)),
                    DataCell(Row(children: [
                      _accionBtn(
                        icon:    Icons.edit_rounded,
                        color:   Colors.blue.shade600,
                        tooltip: 'Editar',
                        onTap:   () => onEditar(p),
                      ),
                      const SizedBox(width: 6),
                      _accionBtn(
                        icon:    Icons.delete_rounded,
                        color:   Colors.red.shade600,
                        tooltip: 'Desactivar',
                        onTap:   () => onEliminar(p),
                      ),
                    ])),
                  ],
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14)),
    child: Center(child: Column(children: [
      Icon(Icons.local_shipping_outlined,
          size: 52, color: Colors.grey.shade200),
      const SizedBox(height: 12),
      Text(
        searchText.isNotEmpty
            ? 'Sin resultados para "$searchText"'
            : 'Aún no hay proveedores registrados',
        style: GoogleFonts.poppins(
            color: Colors.grey.shade400, fontSize: 14)),
      if (searchText.isEmpty) ...[
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onNuevo,
          icon:  const Icon(Icons.add_rounded, size: 16),
          label: Text('Agregar primer proveedor',
              style: GoogleFonts.poppins()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ])),
  );

  Widget _estadoBadge(bool activo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: activo ? Colors.green.shade50 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: activo
              ? Colors.green.shade200
              : Colors.grey.shade300)),
    child: Text(
      activo ? 'Activo' : 'Inactivo',
      style: GoogleFonts.poppins(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color: activo
              ? Colors.green.shade700
              : Colors.grey.shade500)),
  );

  Widget _accionBtn({
    required IconData     icon,
    required Color        color,
    required String       tooltip,
    required VoidCallback onTap,
  }) =>
    Tooltip(
      message: tooltip,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
}