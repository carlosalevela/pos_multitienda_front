// lib/screens/separados/movil/separado_detalle_movil.dart
//
// Detalle de un separado en el celular. Cambia según el estado:
//   activo        → lo que falta, productos (con cambiar), abonos; Abonar.
//   por entregar  → aviso y "Marcar entregado".
//   entregado     → quién y cuándo.
//   cancelado     → el bono con el saldo a favor; enviarlo o imprimirlo.

import 'package:flutter/material.dart';

import '../../../models/separado.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO, telefonoBonito;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import 'separados_movil.dart';
import 'separados_reglas.dart';

class AccionesDetalleSep {
  final VoidCallback onLlamar;
  final VoidCallback onWhatsApp;
  final VoidCallback onImprimir;
  final VoidCallback? onAbonar;
  final VoidCallback? onCancelar;
  final ValueChanged<DetalleSeparado>? onCambiar;
  final VoidCallback? onEntregar;
  final VoidCallback? onEnviarBono;
  final VoidCallback? onImprimirBono;

  const AccionesDetalleSep({
    required this.onLlamar,
    required this.onWhatsApp,
    required this.onImprimir,
    this.onAbonar,
    this.onCancelar,
    this.onCambiar,
    this.onEntregar,
    this.onEnviarBono,
    this.onImprimirBono,
  });
}

class SeparadoDetalleMovil extends StatelessWidget {
  final Separado sep;
  final AccionesDetalleSep acciones;
  final bool ocupado;
  final DateTime? hoy;

  const SeparadoDetalleMovil({super.key, required this.sep, required this.acciones, this.ocupado = false, this.hoy});

  @override
  Widget build(BuildContext context) {
    final ahora = hoy ?? DateTime.now();
    final s = sep;
    final e = estadoSep(s, ahora);
    return Scaffold(
      backgroundColor: CM.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: CM.verdeOs,
        elevation: 0,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SEP-${s.id}', style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
          Text([
            '${s.esCancelado ? 'Separado' : 'Separado el'} ${fechaCorta(s.createdAt, ahora)}',
            if ((s.empleadoNombre ?? '').isNotEmpty) s.empleadoNombre!,
          ].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 11.5, color: CM.gris2)),
        ]),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 14), child: Center(child: etiquetaSep(e))),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.5),
          child: ocupado
              ? const LinearProgressIndicator(minHeight: 2.5, color: CM.verde, backgroundColor: Colors.transparent)
              : const Divider(height: 1, color: CM.borde),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          _cliente(),
          const SizedBox(height: 10),
          if (s.esActivo) _saldo(ahora),
          if (s.porEntregar) _avisoEntrega(ahora),
          if (s.entregado) _avisoEntregado(ahora),
          if (s.esCancelado) ..._cancelado(ahora),
          tituloSep(s.esCancelado ? 'Lo que tenía separado' : s.esPagado ? 'Lo que se lleva' : 'Productos separados'),
          cajaSep(Column(children: [
            for (var i = 0; i < s.detalles.length; i++)
              _producto(s.detalles[i], ultimo: i == s.detalles.length - 1),
          ]), padding: const EdgeInsets.fromLTRB(12, 2, 8, 2)),
          if (s.esPagado) ...[
            const SizedBox(height: 10),
            cajaSep(Column(children: [
              kvSep('Total pagado', pesosCO(s.total), color: CM.verdeOs),
              kvSep('Abonos', '${s.abonos.length}'),
            ])),
          ],
          if (s.abonos.isNotEmpty) ...[
            tituloSep('Abonos (${s.abonos.length})'),
            cajaSep(Column(children: [
              for (var i = 0; i < s.abonos.length; i++) _abono(s.abonos[i], ahora, ultimo: i == s.abonos.length - 1),
            ]), padding: const EdgeInsets.fromLTRB(12, 0, 12, 0)),
          ],
        ],
      ),
      bottomNavigationBar: _barra(),
    );
  }

  Widget _cliente() => cajaSep(Row(children: [
        avatarSep(sep.clienteNombre),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sep.clienteNombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: cf(size: 15, w: FontWeight.w800)),
            Text([
              if ((sep.clienteTelefono ?? '').isNotEmpty) telefonoBonito(sep.clienteTelefono!),
              if ((sep.clienteCedulaNit ?? '').isNotEmpty) 'C.C. ${sep.clienteCedulaNit}',
            ].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 11.5, color: CM.gris2)),
          ]),
        ),
        const SizedBox(width: 6),
        iconoBoton(Icons.phone_outlined, 'Llamar', acciones.onLlamar),
        const SizedBox(width: 6),
        iconoBoton(Icons.chat_outlined, 'WhatsApp', acciones.onWhatsApp,
            c: const Color(0xFF15803D), borde: const Color(0xFFBBF7D0), fondo: const Color(0xFFF0FDF4)),
      ]));

  Widget _saldo(DateTime ahora) {
    final d = diasRestantes(sep, ahora);
    final l = limiteDe(sep);
    final (texto, color) = l == null
        ? ('Sin fecha límite', CM.gris)
        : d! < 0
            ? ('Venció el ${fechaCorta(l, ahora)} · hace ${plural(-d, 'día', 'días')}', CM.rojo)
            : d == 0
                ? ('Vence hoy', CM.ambar)
                : ('Vence el ${fechaCorta(l, ahora)} · en ${plural(d, 'día', 'días')}',
                    d <= diasPorVencer ? CM.ambar : CM.verdeOs);
    return cajaSep(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Le falta', style: cf(size: 11.5, w: FontWeight.w600, color: CM.gris2)),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(pesosCO(sep.saldoPendiente), style: cf(size: 26, w: FontWeight.w800, color: CM.rojo))),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Abonado', style: cf(size: 11.5, w: FontWeight.w600, color: CM.gris2)),
          Text(pesosCO(sep.abonoAcumulado), style: cf(size: 15, w: FontWeight.w800)),
          Text('de ${pesosCO(sep.total)}', style: cf(size: 11, color: CM.gris2)),
        ]),
      ]),
      const SizedBox(height: 9),
      barraSep(sep.progreso, alto: 9),
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.event_outlined, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(texto, style: cf(size: 12, w: FontWeight.w700, color: color))),
      ]),
    ]), padding: const EdgeInsets.fromLTRB(12, 10, 12, 11));
  }

  Widget _aviso(IconData i, String t, String sub, Color c, Color fondo, Color borde) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borde, width: 1.5)),
        child: Row(children: [
          Icon(i, size: 22, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: cf(size: 13.5, w: FontWeight.w800, color: c)),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sub, style: cf(size: 11.5, color: c)),
              ],
            ]),
          ),
        ]),
      );

  Widget _avisoEntrega(DateTime ahora) {
    final ultimo = sep.abonos.isEmpty ? null
        : sep.abonos.map((a) => a.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final dias = ultimo == null ? null : soloDia(ahora).difference(soloDia(ultimo)).inDays;
    return _aviso(Icons.inventory_2_outlined, 'Pagado completo · falta que lo recoja',
        ultimo == null ? '' : 'Último abono ${fechaCorta(ultimo, ahora)} ${horaCorta(ultimo)}'
            '${dias != null && dias > 0 ? ' · lleva ${plural(dias, 'día', 'días')} esperando' : ''}',
        const Color(0xFF155E75), const Color(0xFFECFEFF), const Color(0xFFA5F3FC));
  }

  Widget _avisoEntregado(DateTime ahora) => _aviso(Icons.check_circle_outline_rounded,
      'Entregado el ${fechaCorta(sep.entregadoAt!, ahora)} · ${horaCorta(sep.entregadoAt!)}',
      sep.entregadoPorNombre == null ? '' : 'Lo entregó ${sep.entregadoPorNombre}',
      CM.verdeOs, const Color(0xFFECFDF5), CM.borde2);

  List<Widget> _cancelado(DateTime ahora) {
    if (sep.bonoCodigo == null) {
      return [
        _aviso(Icons.block_rounded, 'Separado cancelado',
            sep.motivoCancelacion.isEmpty ? 'No tenía abonos: no quedó saldo a favor.'
                : 'Motivo: ${sep.motivoCancelacion}',
            CM.gris, const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)),
      ];
    }
    final vence = DateTime.tryParse(sep.bonoVence ?? '');
    final usado = sep.bonoEstado != null && sep.bonoEstado != 'activo';
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF5B21B6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.card_giftcard_rounded, size: 16, color: Color(0xFFDDD6FE)),
            const SizedBox(width: 6),
            Expanded(child: Text('Saldo a favor de ${sep.clienteNombre}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: cf(size: 12, w: FontWeight.w700, color: const Color(0xFFDDD6FE)))),
          ]),
          const SizedBox(height: 4),
          Text(pesosCO(sep.bonoSaldo ?? sep.abonoAcumulado), style: cf(size: 30, w: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Row(children: [
            SelectableText(sep.bonoCodigo!, style: cf(size: 19, w: FontWeight.w800, ls: 2, color: Colors.white)),
            const Spacer(),
            Text(usado ? (sep.bonoEstado == 'redimido' ? 'ya lo usó' : sep.bonoEstado!)
                    : vence != null ? 'vence ${fechaCorta(vence, ahora)}' : '',
                style: cf(size: 11.5, color: const Color(0xFFDDD6FE))),
          ]),
        ]),
      ),
      const SizedBox(height: 8),
      Text('En el POS: Pagar con bono y escribe el código. Si compra algo más caro, paga la diferencia; '
          'si es más barato, el resto le queda en el bono.', style: cf(size: 12, color: CM.gris)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: acciones.onEnviarBono,
            icon: const Icon(Icons.chat_outlined, size: 17),
            label: Text('Enviárselo', style: cf(size: 13.5, w: FontWeight.w700, color: const Color(0xFF15803D))),
            style: botonContornoSep(c: const Color(0xFF15803D), borde: const Color(0xFFBBF7D0)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: acciones.onImprimirBono,
            icon: const Icon(Icons.print_outlined, size: 17),
            label: Text('Imprimir bono', maxLines: 1, style: cf(size: 13.5, w: FontWeight.w700, color: CM.verdeOs)),
            style: botonContornoSep(),
          ),
        ),
      ]),
      if (sep.motivoCancelacion.isNotEmpty) ...[
        const SizedBox(height: 10),
        cajaSep(Text('Motivo: ${sep.motivoCancelacion}', style: cf(size: 12.5, color: const Color(0xFF334155)))),
      ],
      const SizedBox(height: 10),
      cajaSep(Column(children: [
        kvSep('Abonó en total', pesosCO(sep.abonoAcumulado)),
        kvSep('Se le devolvió en plata', pesosCO(0)),
      ])),
    ];
  }

  Widget _producto(DetalleSeparado d, {required bool ultimo}) {
    final cambiar = sep.esActivo && acciones.onCambiar != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: ultimo ? null
          : const BoxDecoration(border: Border(bottom: BorderSide(color: CM.borde))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.productoNombre, style: cf(size: 13, w: FontWeight.w700)),
            Text([
              '${cantidadTexto(d.cantidad)} × ${pesosCO(d.precioUnitario)}',
              if (sep.esCancelado) d.cantidad == 1 ? 'volvió al stock' : 'volvieron al stock',
            ].join(' · '), style: cf(size: 11.5, color: CM.gris2)),
          ]),
        ),
        Text(pesosCO(d.subtotal), style: cf(size: 13, w: FontWeight.w800)),
        if (cambiar) ...[
          const SizedBox(width: 8),
          iconoBoton(Icons.swap_horiz_rounded, 'Cambiar ${d.productoNombre}', () => acciones.onCambiar!(d), t: 34),
        ] else
          const SizedBox(width: 4),
      ]),
    );
  }

  Widget _abono(AbonoSeparado a, DateTime ahora, {required bool ultimo}) {
    final icono = switch (a.metodoPago) {
      'efectivo' => Icons.payments_outlined,
      'tarjeta' => Icons.credit_card_rounded,
      _ => Icons.account_balance_outlined,
    };
    final metodo = [metodoTexto(a.metodoPago), if ((a.cuentaNombre ?? '').isNotEmpty) a.cuentaNombre!].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: ultimo ? null
          : const BoxDecoration(border: Border(bottom: BorderSide(color: CM.borde))),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
          child: Icon(icono, size: 16, color: CM.verdeOs),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(metodo, maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 12.5, w: FontWeight.w700)),
            Text([
              '${fechaCorta(a.createdAt, ahora)} · ${horaCorta(a.createdAt)}',
              if ((a.empleadoNombre ?? '').isNotEmpty) nombreCorto(a.empleadoNombre!),
            ].join(' · '), style: cf(size: 11, color: CM.gris2)),
          ]),
        ),
        Text(pesosCO(a.monto), style: cf(size: 13.5, w: FontWeight.w800)),
      ]),
    );
  }

  Widget? _barra() {
    final hijos = <Widget>[];
    if (sep.esActivo) {
      hijos.addAll([
        Expanded(
          child: FilledButton.icon(
            onPressed: ocupado ? null : acciones.onAbonar,
            style: botonSep(),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: Text('Abonar', style: cf(size: 14.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 8),
        iconoBoton(Icons.print_outlined, 'Imprimir recibo', ocupado ? null : acciones.onImprimir,
            borde: CM.borde2, t: 48),
        if (acciones.onCancelar != null) ...[
          const SizedBox(width: 8),
          iconoBoton(Icons.undo_rounded, 'Cancelar separado', ocupado ? null : acciones.onCancelar,
              c: CM.rojo, borde: const Color(0xFFFECDD3), t: 48),
        ],
      ]);
    } else if (sep.porEntregar) {
      hijos.addAll([
        Expanded(
          child: FilledButton.icon(
            onPressed: ocupado ? null : acciones.onEntregar,
            style: botonSep(),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: Text('Marcar entregado', style: cf(size: 14.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 8),
        iconoBoton(Icons.print_outlined, 'Imprimir', ocupado ? null : acciones.onImprimir, borde: CM.borde2, t: 48),
      ]);
    } else {
      hijos.add(Expanded(
        child: OutlinedButton.icon(
          onPressed: ocupado ? null : acciones.onImprimir,
          icon: const Icon(Icons.print_outlined, size: 18),
          label: Text('Imprimir recibo', style: cf(size: 14, w: FontWeight.w700, color: CM.verdeOs)),
          style: botonContornoSep(),
        ),
      ));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CM.borde))),
      child: SafeArea(top: false, child: Row(children: hijos)),
    );
  }
}
