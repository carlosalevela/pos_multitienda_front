import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../core/constants.dart';

class TabTopProductos extends StatelessWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;

  const TabTopProductos({
    super.key,
    required this.cont,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (cont.cargando && cont.topProductos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final productos = cont.topProductos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────
        Row(children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(Constants.primaryColor), size: 20),
          const SizedBox(width: 8),
          Text('Top productos', style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: const Color(0xFF1A1A2E))),
          const Spacer(),
          Text('${productos.length} productos',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 16),

        // ── Lista ────────────────────────────────────────────
        if (productos.isEmpty)
          _sinProductos()
        else
          Expanded(child: ListView.builder(
            itemCount: productos.length,
            itemBuilder: (_, i) => _productoCard(productos[i], i),
          )),
      ],
    );
  }

  // ── Sin productos ──────────────────────────────────────────
  Widget _sinProductos() {
    return Expanded(child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_rounded, size: 56,
            color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Sin ventas registradas',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Los productos aparecerán aquí\ncuando haya ventas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 12)),
      ],
    )));
  }

  // ── Card de producto ───────────────────────────────────────
  Widget _productoCard(producto, int index) {
    final maxVendido = cont.topProductos
        .map((p) => p.totalVendido)
        .reduce((a, b) => a > b ? a : b);

    final pct   = maxVendido > 0 ? producto.totalVendido / maxVendido : 0.0;
    final isPod = index < 3; // podio top 3

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPod ? _bgPodio(index) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isPod
                ? _colorPodio(index).withOpacity(0.3)
                : Colors.grey.shade100),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Posición
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isPod
                  ? _colorPodio(index)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: isPod
                ? Text(_emojPodio(index),
                    style: const TextStyle(fontSize: 16))
                : Text('${index + 1}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey.shade600))),
          ),
          const SizedBox(width: 12),

          // Nombre y categoría
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(producto.producto,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF1A1A2E))),
              if (producto.categoria.isNotEmpty &&
                  producto.categoria != 'Sin categoría')
                Text(producto.categoria,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500)),
            ],
          )),

          // Stats
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(producto.totalIngresos),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(Constants.primaryColor))),
            Text('${producto.totalVendido.toStringAsFixed(0)} uds',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ]),

        const SizedBox(height: 10),

        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(
                isPod
                    ? _colorPodio(index)
                    : const Color(Constants.primaryColor).withOpacity(0.4)),
          ),
        ),

        const SizedBox(height: 6),

        // Ticket promedio
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Ingresos totales',
              style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.grey.shade400)),
          Text(
            producto.totalVendido > 0
                ? 'Promedio: ${fmt.format(producto.totalIngresos / producto.totalVendido)}/u'
                : '',
            style: GoogleFonts.poppins(
                fontSize: 10, color: Colors.grey.shade400),
          ),
        ]),
      ]),
    );
  }

  // ── Podio helpers ──────────────────────────────────────────
  String _emojPodio(int i) {
    switch (i) {
      case 0:  return '🥇';
      case 1:  return '🥈';
      default: return '🥉';
    }
  }

  Color _colorPodio(int i) {
    switch (i) {
      case 0:  return Colors.amber.shade600;
      case 1:  return Colors.blueGrey.shade400;
      default: return Colors.brown.shade400;
    }
  }

  Color _bgPodio(int i) {
    switch (i) {
      case 0:  return Colors.amber.shade50;
      case 1:  return Colors.blueGrey.shade50;
      default: return Colors.brown.shade50;
    }
  }
}