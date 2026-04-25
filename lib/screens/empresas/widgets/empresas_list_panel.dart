// lib/screens/empresas/widgets/empresas_list_panel.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../models/empresa_model.dart';
import '../../../widgets/app/empty_state_card.dart';
import 'empresa_card.dart';

class EmpresasListPanel extends StatefulWidget {
  const EmpresasListPanel({
    super.key,
    required this.empresas,
    required this.cargando,
    required this.empresaSeleccionada,
    required this.onSeleccionar,
    required this.onEditar,
    required this.onRefresh,
  });

  final List<Empresa> empresas;
  final bool cargando;
  final Empresa? empresaSeleccionada;
  final void Function(Empresa) onSeleccionar;
  final void Function(Empresa) onEditar;
  final Future<void> Function() onRefresh;

  @override
  State<EmpresasListPanel> createState() => _EmpresasListPanelState();
}

class _EmpresasListPanelState extends State<EmpresasListPanel> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Empresa> get _filtradas {
    if (_query.isEmpty) return widget.empresas;
    final q = _query.toLowerCase();
    return widget.empresas.where((e) {
      return e.nombre.toLowerCase().contains(q) ||
          e.nit.toLowerCase().contains(q) ||
          e.ciudad.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado panel ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Empresas',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E),
              ),
            ),
          ),

          // ── Buscador ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar empresa...',
                hintStyle:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: Colors.grey.shade400),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 16, color: Colors.grey.shade400),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(Constants.primaryColor), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Lista ─────────────────────────────────────
          Expanded(
            child: widget.cargando
                ? const Center(child: CircularProgressIndicator())
                : _filtradas.isEmpty
                    ? EmptyStateCard(
                        icon: Icons.business_rounded,
                        title: _query.isNotEmpty
                            ? 'Sin resultados'
                            : 'No hay empresas',
                        subtitle: _query.isNotEmpty
                            ? 'Intenta con otro nombre o NIT'
                            : 'Crea la primera empresa',
                      )
                    : RefreshIndicator(
                        onRefresh: widget.onRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _filtradas.length,
                          itemBuilder: (_, i) {
                            final e = _filtradas[i];
                            return EmpresaCard(
                              empresa: e,
                              seleccionada:
                                  widget.empresaSeleccionada?.id == e.id,
                              onTap: () => widget.onSeleccionar(e),
                              onEdit: () => widget.onEditar(e),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}