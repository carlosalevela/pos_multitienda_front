// lib/screens/inventario/widgets/producto_detalle_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../models/producto.dart';

/// Bottom sheet con el detalle completo de un producto.
/// Recibe callbacks opcionales para las acciones rápidas.
class ProductoDetalleSheet extends StatelessWidget {
  const ProductoDetalleSheet({
    super.key,
    required this.producto,
    required this.esAdmin,
    this.onEditar,
    this.onKardex,
    this.onAjuste,
    this.onTransferir,
  });

  final Producto      producto;
  final bool          esAdmin;
  final VoidCallback? onEditar;
  final VoidCallback? onKardex;
  final VoidCallback? onAjuste;
  final VoidCallback? onTransferir;

  static void show(
    BuildContext context, {
    required Producto      producto,
    required bool          esAdmin,
    VoidCallback?          onEditar,
    VoidCallback?          onKardex,
    VoidCallback?          onAjuste,
    VoidCallback?          onTransferir,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductoDetalleSheet(
        producto:     producto,
        esAdmin:      esAdmin,
        onEditar:     onEditar,
        onKardex:     onKardex,
        onAjuste:     onAjuste,
        onTransferir: onTransferir,
      ),
    );
  }

  // ── Colores ──────────────────────────────────────────────
  static const _green   = Color(0xFF006C49);
  static const _danger  = Color(0xFFBE123C);
  static const _warning = Color(0xFFF59E0B);
  static const _muted   = Color(0xFF6B7280);
  static const _text    = Color(0xFF111827);
  static const _surface = Color(0xFFF9FAFB);
  static const _border  = Color(0xFFE5E7EB);

  static final _fmt = NumberFormat('#,##0', 'es_CO');

  @override
  Widget build(BuildContext context) {
    final p          = producto;
    final agotado    = p.stockActual <= 0;
    final bajo       = !agotado && (p.stockMinimo > 0
        ? p.stockActual <= p.stockMinimo
        : p.stockActual <= 10);
    final margen     = p.precioCompra > 0
        ? (p.precio - p.precioCompra) / p.precioCompra * 100
        : 0.0;
    final margenColor = margen < 0 ? _danger : margen < 10 ? _warning : _green;

    final (estadoLabel, estadoColor) = !p.activo
        ? ('Inactivo', _muted)
        : agotado
            ? ('Agotado', _danger)
            : bajo
                ? ('Stock bajo', _warning)
                : ('Óptimo', _green);

    // Avatar color basado en nombre
    final hue = p.nombre.codeUnits.fold(0, (a, b) => a + b) % 360;
    final avatarColor = HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.45).toColor();
    final inicial = p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // ── Handle ───────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 38, height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Contenido scrolleable ─────────────────────────
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                // ── Header: avatar + nombre + estado ─────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Avatar
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(inicial,
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700,
                          color: avatarColor)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nombre,
                          style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: _text)),
                        const SizedBox(height: 4),
                        if (p.categoria.isNotEmpty)
                          Text(p.categoria,
                            style: const TextStyle(
                              fontSize: 13, color: _muted)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: estadoColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(estadoLabel,
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: estadoColor)),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Código de barras ──────────────────────────
                if (p.referencia.isNotEmpty) ...[
                  _seccion('Identificación'),
                  _fila('Código / SKU', p.referencia,
                      icon: Icons.qr_code_rounded),
                  const SizedBox(height: 16),
                ],

                // ── Descripción ───────────────────────────────
                if (p.descripcion.isNotEmpty) ...[
                  _seccion('Descripción'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Text(p.descripcion,
                      style: const TextStyle(
                        fontSize: 13, color: _text, height: 1.5)),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Precios ───────────────────────────────────
                _seccion('Precios'),
                _tarjetaPrecios(p, margen, margenColor, esAdmin),
                const SizedBox(height: 16),

                // ── Stock ─────────────────────────────────────
                _seccion('Stock'),
                _tarjetaStock(p, agotado, bajo),
                const SizedBox(height: 16),

                // ── Info adicional ────────────────────────────
                _seccion('Información'),
                _fila('Unidad de medida', p.unidadMedida,
                    icon: Icons.straighten_rounded),
                _fila('ID del producto', '#${p.id}',
                    icon: Icons.tag_rounded),
                const SizedBox(height: 24),

                // ── Acciones rápidas ──────────────────────────
                if (esAdmin) ...[
                  _seccion('Acciones'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    if (onEditar != null)
                      _accionBtn(
                        icon:  Icons.edit_rounded,
                        label: 'Editar',
                        color: _green,
                        onTap: () {
                          Navigator.pop(context);
                          onEditar!();
                        },
                      ),
                    if (onKardex != null)
                      _accionBtn(
                        icon:  Icons.timeline_rounded,
                        label: 'Kardex',
                        color: const Color(0xFF0369A1),
                        onTap: () {
                          Navigator.pop(context);
                          onKardex!();
                        },
                      ),
                    if (onAjuste != null)
                      _accionBtn(
                        icon:  Icons.tune_rounded,
                        label: 'Ajuste stock',
                        color: const Color(0xFF7C3AED),
                        onTap: () {
                          Navigator.pop(context);
                          onAjuste!();
                        },
                      ),
                    if (onTransferir != null)
                      _accionBtn(
                        icon:  Icons.swap_horiz_rounded,
                        label: 'Transferir',
                        color: const Color(0xFFD97706),
                        onTap: () {
                          Navigator.pop(context);
                          onTransferir!();
                        },
                      ),
                  ]),
                ] else ...[
                  // Cajero: solo kardex
                  if (onKardex != null)
                    _accionBtn(
                      icon:  Icons.timeline_rounded,
                      label: 'Ver movimientos',
                      color: const Color(0xFF0369A1),
                      onTap: () {
                        Navigator.pop(context);
                        onKardex!();
                      },
                    ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(titulo.toUpperCase(),
      style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: _muted, letterSpacing: 1.1)),
  );

  Widget _fila(String label, String valor, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 15, color: _muted),
        const SizedBox(width: 8),
      ],
      Text(label,
        style: const TextStyle(fontSize: 13, color: _muted)),
      const Spacer(),
      Text(valor,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
    ]),
  );

  Widget _tarjetaPrecios(Producto p, double margen, Color margenColor, bool esAdmin) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _precioTile(
            'Precio venta', '${Constants.moneda}${_fmt.format(p.precio)}',
            color: _text, grande: true)),
          if (esAdmin && p.precioCompra > 0) ...[
            const SizedBox(width: 12),
            Expanded(child: _precioTile(
              'Precio compra', '${Constants.moneda}${_fmt.format(p.precioCompra)}',
              color: _muted)),
          ],
        ]),
        if (esAdmin && p.precioCompra > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: margenColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Margen de ganancia',
                  style: TextStyle(fontSize: 12, color: margenColor)),
                Text('${margen.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: margenColor)),
              ],
            ),
          ),
        ],
        if (p.precioMayoreo != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF006C49).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Precio mayoreo',
                  style: TextStyle(fontSize: 12, color: _green)),
                Text('${Constants.moneda}${_fmt.format(p.precioMayoreo!)}',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _green)),
              ],
            ),
          ),
          if (p.umbralMayoreo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Aplica desde ${p.umbralMayoreo} unidades',
                style: const TextStyle(fontSize: 11, color: _muted)),
            ),
        ],
      ]),
    );

  Widget _precioTile(String label, String valor,
      {required Color color, bool grande = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: const TextStyle(fontSize: 11, color: _muted)),
      const SizedBox(height: 2),
      Text(valor,
        style: TextStyle(
          fontSize: grande ? 18 : 14,
          fontWeight: FontWeight.w700,
          color: color)),
    ]);

  Widget _tarjetaStock(Producto p, bool agotado, bool bajo) {
    final stockColor = agotado ? _danger : bajo ? _warning : _green;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stockColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stockColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stockTile('Actual', p.stockActual, stockColor, grande: true),
          _dividerV(),
          _stockTile('Mínimo', p.stockMinimo, _muted),
          _dividerV(),
          _stockTile('Máximo', p.stockMaximo, _muted),
        ],
      ),
    );
  }

  Widget _stockTile(String label, double valor, Color color,
      {bool grande = false}) =>
    Column(children: [
      Text(
        valor % 1 == 0 ? valor.toStringAsFixed(0) : valor.toStringAsFixed(1),
        style: TextStyle(
          fontSize: grande ? 22 : 16,
          fontWeight: FontWeight.w700,
          color: color)),
      const SizedBox(height: 2),
      Text(label,
        style: const TextStyle(fontSize: 11, color: _muted)),
    ]);

  Widget _dividerV() => Container(
    height: 36, width: 1,
    color: _border,
  );

  Widget _accionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
}
