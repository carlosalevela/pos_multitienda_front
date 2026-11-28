// lib/screens/clientes/widgets/cliente_detalle_movil.dart
//
// Las 4 pestañas del detalle del cliente en el celular, con el diseño del
// ejemplo aprobado: Separados (con el historial plegado), Crédito, Compras y
// Datos. Solo pintan: los datos y las acciones llegan desde el detalle.

import 'package:flutter/material.dart';

import '../../../models/cliente.dart';
import '../../../models/separado.dart';
import '../../../models/tier_model.dart';
import 'cliente_contacto.dart';
import 'clientes_movil.dart' show CM, cf, compactoPesos;

const _mesesCortos = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago',
                      'sep', 'oct', 'nov', 'dic'];

String _fechaCorta(DateTime f) => '${f.day} ${_mesesCortos[f.month]}';
String _fechaAnio(DateTime f) => '${f.day} ${_mesesCortos[f.month]} ${f.year}';

/// Estado de un separado activo: (texto, color, fondo).
(String, Color, Color) estadoSeparado(Separado s, DateTime hoy) {
  final lim = s.fechaLimite == null ? null : DateTime.tryParse(s.fechaLimite!);
  if (lim == null) return ('Sin fecha límite', CM.gris, const Color(0xFFF1F5F9));
  final dias = DateTime(lim.year, lim.month, lim.day)
      .difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  if (dias < 0) return (textoVencimiento(dias), CM.rojo, const Color(0xFFFFE4E6));
  if (dias <= 3) return (textoVencimiento(dias), CM.ambar, const Color(0xFFFEF3C7));
  return ('Al día', CM.verdeOs, CM.borde);
}

String productosDe(Separado s) => s.detalles.map((d) {
      final n = d.cantidad == d.cantidad.roundToDouble() ? d.cantidad.toInt() : d.cantidad;
      return n == 1 ? d.productoNombre : '${d.productoNombre} x$n';
    }).join(', ');

Widget _tarjeta({required Widget child, Color borde = CM.borde, Color fondo = Colors.white,
        EdgeInsets padding = const EdgeInsets.fromLTRB(12, 11, 12, 12)}) =>
    Container(
      padding: padding,
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borde, width: 1.5)),
      child: child,
    );

Widget _etiqueta(String t, Color c, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: cf(size: 10.5, w: FontWeight.w800, color: c)),
    );

Widget _vacio(IconData i, String t, String? sub) => Padding(
      padding: const EdgeInsets.fromLTRB(30, 50, 30, 30),
      child: Column(children: [
        Icon(i, size: 40, color: CM.borde2),
        const SizedBox(height: 10),
        Text(t, textAlign: TextAlign.center, style: cf(size: 14, w: FontWeight.w700, color: CM.gris)),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: cf(size: 12, color: CM.gris2)),
        ],
      ]),
    );

ButtonStyle _botonLleno(Color c) => FilledButton.styleFrom(
      backgroundColor: c,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

ButtonStyle _botonBorde() => OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      side: const BorderSide(color: CM.borde2, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

// ══════════════════════════════════════════════════════════════
// SEPARADOS
// ══════════════════════════════════════════════════════════════

class SeparadosMovil extends StatelessWidget {
  final List<Separado> activos;
  final List<Separado> historial;
  final DateTime hoy;
  final bool esAdmin;
  final ValueChanged<Separado> onAbonar;
  final ValueChanged<Separado> onRecibos;
  final ValueChanged<Separado> onDetalle;
  final ValueChanged<Separado> onCancelar;

  const SeparadosMovil({super.key, required this.activos, required this.historial,
      required this.hoy, required this.esAdmin, required this.onAbonar,
      required this.onRecibos, required this.onDetalle, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    if (activos.isEmpty && historial.isEmpty) {
      return ListView(children: [
        _vacio(Icons.shopping_bag_outlined, 'No tiene separados',
            'Los separados se hacen desde el POS.'),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        if (activos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('No tiene separados activos.', style: cf(size: 13, color: CM.gris)),
          ),
        for (final s in activos) ...[
          _separado(context, s),
          const SizedBox(height: 10),
        ],
        if (historial.isNotEmpty) _historial(),
      ],
    );
  }

  Widget _separado(BuildContext context, Separado s) {
    final (txt, col, bg) = estadoSeparado(s, hoy);
    final vencido = col == CM.rojo;
    final pct = s.total <= 0 ? 0.0 : (s.abonoAcumulado / s.total).clamp(0.0, 1.0);
    final lim = s.fechaLimite == null ? null : DateTime.tryParse(s.fechaLimite!);
    return _tarjeta(
      borde: vencido ? const Color(0xFFFDA4AF) : CM.borde,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('SEP-${s.id}', style: cf(size: 13.5, w: FontWeight.w800)),
          const SizedBox(width: 8),
          Flexible(child: _etiqueta(txt, col, bg)),
          const Spacer(),
          if (lim != null && !vencido)
            Text('vence ${_fechaCorta(lim)}', style: cf(size: 11, w: FontWeight.w600, color: CM.gris2)),
        ]),
        const SizedBox(height: 6),
        Text(productosDe(s), maxLines: 2, overflow: TextOverflow.ellipsis,
            style: cf(size: 12.5, color: const Color(0xFF334155))),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 7,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation(CM.verde),
          ),
        ),
        const SizedBox(height: 7),
        Row(children: [
          Text.rich(TextSpan(style: cf(size: 12, color: CM.gris), children: [
            const TextSpan(text: 'Abonado '),
            TextSpan(text: pesosCO(s.abonoAcumulado), style: cf(size: 12, w: FontWeight.w800)),
            TextSpan(text: ' de ${pesosCO(s.total)}'),
          ])),
          const Spacer(),
          Text.rich(TextSpan(style: cf(size: 12, color: CM.gris), children: [
            const TextSpan(text: 'Saldo '),
            TextSpan(text: pesosCO(s.saldoPendiente),
                style: cf(size: 12.5, w: FontWeight.w800, color: vencido ? CM.rojo : CM.tinta)),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () => onAbonar(s),
              style: _botonLleno(CM.verde),
              child: Text('Abonar', style: cf(size: 13, w: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => onRecibos(s),
            style: _botonBorde(),
            icon: const Icon(Icons.receipt_long_outlined, size: 16, color: CM.verdeOs),
            label: Text('Recibos', style: cf(size: 12.5, w: FontWeight.w700, color: CM.verdeOs)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 42, height: 40,
            child: PopupMenuButton<String>(
              tooltip: 'Más opciones',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_horiz_rounded, color: CM.verdeOs),
              style: IconButton.styleFrom(
                side: const BorderSide(color: CM.borde2, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSelected: (v) => v == 'cancelar' ? onCancelar(s) : onDetalle(s),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'detalle', child: Text('Ver detalle y abonos')),
                if (esAdmin) const PopupMenuItem(value: 'cambiar', child: Text('Cambiar producto')),
                if (esAdmin)
                  const PopupMenuItem(value: 'cancelar',
                      child: Text('Cancelar separado', style: TextStyle(color: CM.rojo))),
              ],
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _historial() {
    final pagados = historial.where((s) => s.estado == 'pagado').length;
    final cancelados = historial.length - pagados;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.history_rounded, color: CM.gris, size: 20),
          title: Text('Historial · $pagados pagado${pagados == 1 ? '' : 's'}'
              '${cancelados > 0 ? ', $cancelados cancelado${cancelados == 1 ? '' : 's'}' : ''}',
              style: cf(size: 13, w: FontWeight.w600)),
          iconColor: CM.gris,
          collapsedIconColor: CM.gris,
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          children: [
            for (final s in historial)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SEP-${s.id} · ${_fechaAnio(s.createdAt)}',
                          style: cf(size: 12.5, w: FontWeight.w700)),
                      Text(productosDe(s), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: cf(size: 11.5, color: CM.gris2)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(pesosCO(s.total), style: cf(size: 12.5, w: FontWeight.w700)),
                    s.estado == 'pagado'
                        ? _etiqueta('Pagado', CM.verdeOs, CM.borde)
                        : _etiqueta('Cancelado', CM.gris, const Color(0xFFF1F5F9)),
                  ]),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CRÉDITO
// ══════════════════════════════════════════════════════════════

class CreditoMovil extends StatelessWidget {
  final Cliente cliente;
  final Map<String, dynamic>? datos;
  final bool cargando;
  final ValueChanged<Map<String, dynamic>> onAbonar;
  final Future<void> Function() onRefrescar;

  const CreditoMovil({super.key, required this.cliente, required this.datos,
      required this.cargando, required this.onAbonar, required this.onRefrescar});

  @override
  Widget build(BuildContext context) {
    if (cliente.limiteCredito <= 0) {
      return ListView(children: [
        _vacio(Icons.handshake_outlined, 'No tiene crédito',
            'Para venderle a crédito, ponle un límite en Editar.'),
      ]);
    }
    if (cargando && datos == null) {
      return const Center(child: CircularProgressIndicator(color: CM.verde));
    }
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    final limite = n(datos?['limite_credito'] ?? cliente.limiteCredito);
    final deuda = n(datos?['deuda_total']);
    final disponible = (limite - deuda).clamp(0, double.infinity).toDouble();
    final ventas = [
      for (final v in (datos?['ventas'] as List? ?? const []))
        if (v is Map) Map<String, dynamic>.from(v),
    ];
    final pct = limite <= 0 ? 0.0 : (deuda / limite).clamp(0.0, 1.0);
    return RefreshIndicator(
      color: CM.verde,
      onRefresh: onRefrescar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          _tarjeta(
            borde: const Color(0xFFDDD6FE),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text.rich(TextSpan(style: cf(size: 12, color: CM.gris), children: [
                  const TextSpan(text: 'Usado '),
                  TextSpan(text: pesosCO(deuda), style: cf(size: 12.5, w: FontWeight.w800, color: CM.morado)),
                ])),
                const Spacer(),
                Text.rich(TextSpan(style: cf(size: 12, color: CM.gris), children: [
                  const TextSpan(text: 'Límite '),
                  TextSpan(text: pesosCO(limite), style: cf(size: 12.5, w: FontWeight.w800)),
                ])),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 8,
                  backgroundColor: const Color(0xFFEDE9FE),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(TextSpan(style: cf(size: 12.5, color: const Color(0xFF334155)), children: [
                const TextSpan(text: 'Le quedan '),
                TextSpan(text: pesosCO(disponible), style: cf(size: 12.5, w: FontWeight.w800)),
                const TextSpan(text: ' para comprar a crédito.'),
              ])),
            ]),
          ),
          const SizedBox(height: 14),
          Text('VENTAS A CRÉDITO', style: cf(size: 10.5, w: FontWeight.w800, color: CM.verdeOs, ls: .8)),
          const SizedBox(height: 8),
          if (ventas.isEmpty)
            Text('Todavía no le ha comprado a crédito.', style: cf(size: 13, color: CM.gris))
          else
            for (final v in ventas) ...[
              _venta(v),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _venta(Map<String, dynamic> v) {
    double n(Object? x) => (x as num?)?.toDouble() ?? 0;
    final saldo = n(v['saldo_pendiente']);
    final pagada = saldo <= 0;
    final fecha = DateTime.tryParse('${v['fecha'] ?? ''}')?.toLocal();
    final abonado = n(v['total_pagado']);
    return _tarjeta(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${v['numero_factura'] ?? 'Venta ${v['id']}'}',
                  style: cf(size: 13, w: FontWeight.w800)),
              if (fecha != null)
                TextSpan(text: ' · ${_fechaCorta(fecha)}', style: cf(size: 11.5, color: CM.gris2)),
            ])),
            const SizedBox(height: 2),
            Text('Total ${pesosCO(n(v['total']))} · ${pagada ? 'pagada' : 'abonó ${pesosCO(abonado)}'}',
                style: cf(size: 11.5, color: CM.gris)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(pagada ? 'Pagado' : 'Saldo', style: cf(size: 10.5, w: FontWeight.w600, color: CM.gris2)),
          pagada
              ? const Icon(Icons.check_circle_rounded, size: 18, color: CM.verde)
              : Text(pesosCO(saldo), style: cf(size: 13.5, w: FontWeight.w800, color: CM.morado)),
        ]),
        if (!pagada) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => onAbonar(v),
            style: _botonBorde().copyWith(
                side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFDDD6FE), width: 1.5))),
            child: Text('Abonar', style: cf(size: 12.5, w: FontWeight.w800, color: CM.morado)),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// COMPRAS
// ══════════════════════════════════════════════════════════════

class ComprasMovil extends StatelessWidget {
  final List<Map<String, dynamic>> ventas;
  final bool cargando;
  final Future<void> Function() onRefrescar;

  const ComprasMovil({super.key, required this.ventas, required this.cargando,
      required this.onRefrescar});

  @override
  Widget build(BuildContext context) {
    if (cargando && ventas.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: CM.verde));
    }
    if (ventas.isEmpty) {
      return ListView(children: [
        _vacio(Icons.shopping_cart_outlined, 'Sin compras registradas', null),
      ]);
    }
    double n(Object? x) => double.tryParse('${x ?? 0}') ?? 0;
    final validas = ventas.where((v) => v['estado'] != 'anulada').toList();
    final total = validas.fold<double>(0, (a, v) => a + n(v['total']));
    return RefreshIndicator(
      color: CM.verde,
      onRefresh: onRefrescar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          Row(children: [
            Expanded(child: _resumen('Total comprado', compactoPesos(total))),
            const SizedBox(width: 8),
            Expanded(child: _resumen('Compras', '${validas.length}')),
            const SizedBox(width: 8),
            Expanded(child: _resumen('Promedio',
                validas.isEmpty ? '—' : compactoPesos(total / validas.length))),
          ]),
          const SizedBox(height: 12),
          for (final v in ventas) ...[
            _fila(v, n),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _resumen(String t, String v) => _tarjeta(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: cf(size: 10.5, w: FontWeight.w600, color: CM.gris2)),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(v, style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro))),
        ]),
      );

  Widget _fila(Map<String, dynamic> v, double Function(Object?) n) {
    final anulada = v['estado'] == 'anulada';
    final fecha = DateTime.tryParse('${v['created_at'] ?? ''}')?.toLocal();
    final metodo = '${v['metodo_pago'] ?? ''}';
    return _tarjeta(
      child: Row(children: [
        Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: anulada ? const Color(0xFFF1F5F9) : CM.borde,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.receipt_long_outlined, size: 18, color: anulada ? CM.gris2 : CM.verdeOs),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${v['numero_factura'] ?? 'Venta ${v['id']}'}', style: cf(size: 13, w: FontWeight.w700)),
            Text([
              if (fecha != null) _fechaAnio(fecha),
              if (metodo.isNotEmpty) metodo[0].toUpperCase() + metodo.substring(1),
            ].join(' · '), style: cf(size: 11.5, color: CM.gris2)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(pesosCO(n(v['total'])), style: cf(size: 13.5, w: FontWeight.w800,
              color: anulada ? CM.gris2 : CM.tinta)),
          if (anulada) _etiqueta('Anulada', CM.rojo, const Color(0xFFFFE4E6)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DATOS
// ══════════════════════════════════════════════════════════════

class DatosMovil extends StatelessWidget {
  final Cliente cliente;
  final List<TierModel> tiers;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;
  final VoidCallback? onReactivar;

  const DatosMovil({super.key, required this.cliente, required this.tiers,
      required this.puedeEditar, required this.onEditar, required this.onDesactivar,
      this.onReactivar});

  @override
  Widget build(BuildContext context) {
    final c = cliente;
    Widget dato(IconData i, String t, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 18, color: CM.verdeOs),
            const SizedBox(width: 10),
            SizedBox(width: 82, child: Text(t, style: cf(size: 12, color: CM.gris2))),
            Expanded(child: Text(v.isEmpty ? '—' : v, style: cf(size: 13, w: FontWeight.w600,
                color: v.isEmpty ? CM.gris2 : CM.tinta))),
          ]),
        );
    final activos = tiers.where((t) => t.activo).toList()
      ..sort((a, b) => a.umbralMin.compareTo(b.umbralMin));
    TierModel? siguiente;
    for (final t in activos) {
      if (t.umbralMin > c.totalAcumulado) {
        siguiente = t;
        break;
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _tarjeta(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(children: [
            dato(Icons.phone_outlined, 'Celular', telefonoBonito(c.telefono)),
            dato(Icons.badge_outlined, 'Cédula/NIT', c.cedulaNit ?? ''),
            dato(Icons.mail_outline_rounded, 'Email', c.email),
            dato(Icons.location_on_outlined, 'Dirección', c.direccion),
            dato(Icons.event_outlined, 'Cliente desde', _fechaAnio(c.createdAt)),
          ]),
        ),
        const SizedBox(height: 12),
        _tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.star_outline_rounded, size: 18, color: CM.verdeOs),
              const SizedBox(width: 8),
              Text('Nivel', style: cf(size: 13, w: FontWeight.w700)),
              const Spacer(),
              Text(c.tierInfo?.nombre ?? 'Sin nivel', style: cf(size: 13, w: FontWeight.w800, color: CM.oscuro)),
            ]),
            const SizedBox(height: 6),
            Text(
              siguiente == null
                  ? 'Ha comprado ${pesosCO(c.totalAcumulado)}.'
                  : 'Ha comprado ${pesosCO(c.totalAcumulado)}. Le faltan '
                    '${pesosCO(siguiente.umbralMin - c.totalAcumulado)} para ${siguiente.nombre}.',
              style: cf(size: 12, color: CM.gris),
            ),
            if ((c.tierInfo?.descuentoPct ?? 0) > 0) ...[
              const SizedBox(height: 4),
              Text('Tiene ${c.tierInfo!.descuentoPct.toStringAsFixed(0)} % de descuento por su nivel.',
                  style: cf(size: 12, w: FontWeight.w600, color: CM.verdeOs)),
            ],
          ]),
        ),
        if (puedeEditar) ...[
          const SizedBox(height: 16),
          if (c.activo)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditar,
                  style: _botonBorde().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 46))),
                  icon: const Icon(Icons.edit_outlined, size: 17, color: CM.verdeOs),
                  label: Text('Editar datos', style: cf(size: 13, w: FontWeight.w800, color: CM.verdeOs)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDesactivar,
                  style: _botonBorde().copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
                      side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFFECDD3), width: 1.5))),
                  icon: const Icon(Icons.person_off_outlined, size: 17, color: CM.rojo),
                  label: Text('Desactivar', style: cf(size: 13, w: FontWeight.w800, color: CM.rojo)),
                ),
              ),
            ])
          else if (onReactivar != null)
            FilledButton.icon(
              onPressed: onReactivar,
              style: _botonLleno(CM.verde).copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 48))),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text('Reactivar cliente', style: cf(size: 14, w: FontWeight.w800, color: Colors.white)),
            ),
        ],
      ],
    );
  }
}
