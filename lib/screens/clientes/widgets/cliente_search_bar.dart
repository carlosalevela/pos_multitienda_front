import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClienteSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;   // se llama con debounce
  final VoidCallback?        onAgregar;  // null = botón oculto
  final String               hint;

  const ClienteSearchBar({
    super.key,
    required this.onSearch,
    this.onAgregar,
    this.hint = 'Buscar por nombre, cédula o teléfono...',
  });

  @override
  State<ClienteSearchBar> createState() => _ClienteSearchBarState();
}

class _ClienteSearchBarState extends State<ClienteSearchBar> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool  _tieneTexto = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final tiene = _ctrl.text.isNotEmpty;
      if (tiene != _tieneTexto) setState(() => _tieneTexto = tiene);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.onSearch(value.trim());
    });
  }

  void _limpiar() {
    _ctrl.clear();
    widget.onSearch('');
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        // ── Barra de búsqueda ──────────────────────────────
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF9F8F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focus.hasFocus
                    ? const Color(0xFF01696F)
                    : const Color(0xFFD4D1CA),
                width: _focus.hasFocus ? 1.5 : 1,
              ),
            ),
            child: Focus(
              focusNode: _focus,
              onFocusChange: (_) => setState(() {}),
              child: TextField(
                controller:  _ctrl,
                onChanged:   _onChanged,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF28251D),
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFFBAB9B4),
                  ),
                  prefixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _focus.hasFocus
                          ? Icons.search_rounded
                          : Icons.search_outlined,
                      key: ValueKey(_focus.hasFocus),
                      size: 20,
                      color: _focus.hasFocus
                          ? const Color(0xFF01696F)
                          : const Color(0xFFBAB9B4),
                    ),
                  ),
                  // ── Botón limpiar ────────────────────────
                  suffixIcon: _tieneTexto
                      ? GestureDetector(
                          onTap: _limpiar,
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF7A7974),
                          ),
                        )
                      : null,
                  border:         InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
        ),

        // ── Botón agregar ──────────────────────────────────
        if (widget.onAgregar != null) ...[
          const SizedBox(width: 10),
          _BotonAgregar(onTap: widget.onAgregar!),
        ],

      ],
    );
  }
}


// ── Botón agregar separado del widget ─────────────────────────
class _BotonAgregar extends StatelessWidget {
  final VoidCallback onTap;
  const _BotonAgregar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF01696F),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF01696F).withOpacity(0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.person_add_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}