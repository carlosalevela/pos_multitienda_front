// lib/screens/devoluciones/movil/devolucion_detalle_movil.dart
//
// Detalle de una devolución o cambio en el celular: qué trajo, a dónde fue
// cada producto, qué se llevó y la plata. Abajo: imprimir y cancelar.

import 'package:flutter/material.dart';

import '../../../models/devolucion_model.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import '../../compras/movil/compras_movil.dart' show etiquetaCompra;
import 'devoluciones_movil.dart' show etiquetaTipo;
import 'devoluciones_reglas.dart';

Widget tarjetaDev(Widget child, {Color borde = CM.borde, Color fondo = Colors.white, EdgeInsets? padding}) =>
    Container(
      padding: padding ?? const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borde, width: 1.5)),
      child: child,
    );

Widget filaKV(String k, String v, {Color? color, bool fuerte = false, bool raya = false}) => Container(
      margin: EdgeInsets.only(top: raya ? 4 : 0),
      padding: EdgeInsets.only(top: raya ? 7 : 3, bottom: 3),
      decoration: raya
          ? const BoxDecoration(border: Border(top: BorderSide(color: CM.borde)))
          : null,
      child: Row(children: [
        Expanded(child: Text(k, style: cf(size: 13, w: fuerte ? FontWeight.w700 : FontWeight.w500,
            color: fuerte ? CM.tinta : CM.gris))),
        const SizedBox(width: 10),
        Text(v, textAlign: TextAlign.right,
            style: cf(size: fuerte ? 15 : 13, w: FontWeight.w800, color: color ?? CM.tinta)),
      ]),
    );

Widget tituloSeccion(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 7),
      child: Text(t.toUpperCase(), style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
    );

class DevolucionDetalleMovil extends StatelessWidget {
  final DevolucionModel dev;
  final bool puedeCancelar;
  final VoidCallback onImprimir;
  final VoidCallback onCancelar;
  final DateTime? hoy;

  const DevolucionDetalleMovil({
    super.key,
    required this.dev,
    required this.puedeCancelar,
    required this.onImprimir,
    required this.onCancelar,
    this.hoy,
  });

  @override
  Widget build(BuildContext context) {
    final ahora = hoy ?? DateTime.now();
    final d = dev;
    final cambio = d.tipo == 'cambio';
    final cancelada = d.estado == 'cancelada';
    return Scaffold(
      backgroundColor: CM.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: CM.verdeOs,
        elevation: 0,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DEV-${d.id}', style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
          Text('${cuandoLargo(d.createdAt, ahora)} · ${d.empleadoNombre}', maxLines: 1,
              overflow: TextOverflow.ellipsis, style: cf(size: 11.5, color: CM.gris2)),
        ]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: CM.borde)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          tarjetaDev(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              etiquetaTipo(d),
              const SizedBox(width: 6),
              if (!cancelada) etiquetaCompra('Procesada', CM.verdeOs, const Color(0xFFD1FAE5)),
            ]),
            const SizedBox(height: 8),
            Text(d.clienteNombre, style: cf(size: 15, w: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(['Venta ${d.ventaNumero}', if (d.tiendaNombre.isNotEmpty) d.tiendaNombre].join(' · '),
                style: cf(size: 12, color: CM.gris2)),
            if (cambio && d.motivoCambioLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(d.motivoCambioLabel, style: cf(size: 12, color: CM.gris2)),
            ],
          ])),
          tituloSeccion('Lo que trajo'),
          for (final x in d.detalles) ...[
            _producto(x.productoNombre, x.cantidad, x.precioUnitario, x.motivo,
                cancelada ? null : x.aAverias),
            const SizedBox(height: 7),
          ],
          if (cambio && (d.reemplazos.isNotEmpty || d.productoReemplazoNombre != null)) ...[
            tituloSeccion('Lo que se llevó'),
            if (d.reemplazos.isNotEmpty)
              for (final r in d.reemplazos) ...[
                _producto(r.productoNombre, r.cantidad, r.precioUnitario, '', null),
                const SizedBox(height: 7),
              ]
            else
              _producto(d.productoReemplazoNombre!, d.cantidadReemplazo ?? 1, d.precioReemplazo ?? 0, '', null),
          ],
          const SizedBox(height: 7),
          tarjetaDev(Column(children: cambio ? _plataCambio(d) : _plataDevolucion(d))),
          if (d.observaciones.trim().isNotEmpty) ...[
            tituloSeccion('Observaciones'),
            tarjetaDev(Text(d.observaciones, style: cf(size: 13, color: const Color(0xFF334155)))),
          ],
          if (cancelada) ...[
            const SizedBox(height: 12),
            Text('Esta operación fue cancelada: el stock y la plata volvieron como estaban.',
                textAlign: TextAlign.center, style: cf(size: 12, color: CM.gris2)),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CM.borde))),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onImprimir,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text('Imprimir', style: cf(size: 14, w: FontWeight.w700, color: CM.verdeOs)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CM.verdeOs, minimumSize: const Size(0, 48),
                  side: const BorderSide(color: CM.borde2, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (puedeCancelar && !cancelada) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCancelar,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text('Cancelar', maxLines: 1, style: cf(size: 14, w: FontWeight.w700, color: CM.rojo)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CM.rojo, minimumSize: const Size(0, 48),
                    side: const BorderSide(color: Color(0xFFFECDD3), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _producto(String nombre, double cant, double precio, String nota, bool? aAverias) => tarjetaDev(
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: cf(size: 13, w: FontWeight.w800)),
              const SizedBox(height: 2),
              Text([
                '${cantidadTexto(cant)} × ${pesosCO(precio)}',
                if (nota.trim().isNotEmpty) '“${nota.trim()}”',
              ].join(' · '), style: cf(size: 11.5, color: CM.gris2)),
            ]),
          ),
          if (aAverias != null) ...[
            const SizedBox(width: 8),
            aAverias
                ? etiquetaCompra('A averías', const Color(0xFF92400E), const Color(0xFFFEF3C7))
                : etiquetaCompra('Volvió al stock', CM.verdeOs, const Color(0xFFD1FAE5)),
          ],
        ]),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      );

  List<Widget> _plataDevolucion(DevolucionModel d) => [
        if (d.abonadoCredito > 0) ...[
          filaKV('Devolvió', pesosCO(d.totalDevuelto)),
          filaKV('Abonó a su deuda', '− ${pesosCO(d.abonadoCredito)}', color: CM.morado),
          filaKV('Le devolviste', pesosCO(d.reembolsado), color: CM.rojo, fuerte: true, raya: true),
        ] else
          filaKV('Le devolviste', pesosCO(d.totalDevuelto), color: CM.rojo, fuerte: true),
        if (d.reembolsado > 0 || d.abonadoCredito <= 0)
          filaKV('Cómo', d.metodoDevolucion == 'efectivo'
              ? 'Efectivo · caja'
              : nombreMetodo(d.metodoDevolucion)),
      ];

  List<Widget> _plataCambio(DevolucionModel d) {
    final trae = d.totalDevuelto;
    final lleva = d.totalReemplazo ?? (trae + (d.diferencia ?? 0));
    final t = (d.tipoDiferencia ?? '').toLowerCase();
    return [
      filaKV('Trajo', pesosCO(trae)),
      filaKV('Se llevó', pesosCO(lleva)),
      if (t == 'cobrar')
        filaKV('Te pagó la diferencia', pesosCO(d.diferencia ?? 0), color: CM.verdeOs, fuerte: true, raya: true)
      else if (t == 'devolver')
        filaKV('Le devolviste', pesosCO(d.diferencia ?? 0), color: CM.rojo, fuerte: true, raya: true)
      else
        filaKV('Diferencia', 'Sin diferencia', fuerte: true, raya: true),
      if (t == 'cobrar' || t == 'devolver')
        filaKV('Cómo', nombreMetodo(d.metodoPagoDiferencia ?? '')),
      if (t == 'cobrar' && (d.montoRecibido ?? 0) > 0 && d.metodoPagoDiferencia == 'efectivo') ...[
        filaKV('Recibido', pesosCO(d.montoRecibido!)),
        filaKV('Vueltas', pesosCO(d.cambioEntregado ?? 0)),
      ],
    ];
  }
}
