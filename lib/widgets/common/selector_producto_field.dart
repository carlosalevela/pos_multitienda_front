import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/producto.dart';
import 'buscador_productos_sheet.dart';

class SelectorProductoField extends StatefulWidget {
  final Producto? productoSeleccionado;
  final ValueChanged<Producto?> onProductoSeleccionado;
  final String? hintText;

  const SelectorProductoField({
    super.key,
    this.productoSeleccionado,
    required this.onProductoSeleccionado,
    this.hintText,
  });

  @override
  State<SelectorProductoField> createState() => _SelectorProductoFieldState();
}

class _SelectorProductoFieldState extends State<SelectorProductoField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.productoSeleccionado?.id.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant SelectorProductoField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevoTexto = widget.productoSeleccionado?.id.toString() ?? '';
    if (_ctrl.text != nuevoTexto) {
      _ctrl.text = nuevoTexto;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _abrirBuscador() async {
    final producto = await BuscadorProductosSheet.show(context);
    if (producto != null && mounted) {
      widget.onProductoSeleccionado(producto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seleccionado = widget.productoSeleccionado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Producto reemplazo',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _ctrl,
          readOnly: true,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Buscar producto de reemplazo',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                Icons.search_rounded,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onPressed: _abrirBuscador,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide:
                  const BorderSide(color: Color(0xFF01696F), width: 1.5),
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 14),
          onTap: _abrirBuscador,
        ),
        if (seleccionado != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seleccionado.nombre,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\$${seleccionado.precio.toStringAsFixed(0)} · ${seleccionado.stockActual.toStringAsFixed(0)} disponibles',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.red.shade400,
                  ),
                  onPressed: () {
                    widget.onProductoSeleccionado(null);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
