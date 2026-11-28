// lib/screens/devoluciones/movil/devoluciones_movil.dart
//
// Lista de devoluciones y cambios en el celular. Solo pinta: recibe los datos
// y avisa con callbacks (la pantalla carga y navega).

import 'package:flutter/material.dart';

import '../../../models/devolucion_model.dart';
import '../../clientes/widgets/clientes_movil.dart' show CM, cf, compactoPesos;
import '../../compras/movil/compras_movil.dart' show etiquetaCompra;
import 'devoluciones_reglas.dart';

class DatosDevsMovil {
  final List<DevolucionModel> devoluciones;
  final FiltroDevs filtro;
  final RangoDevs rango;
  final String textoRango;
  final String busqueda;
  final bool cargando;
  final String? error;
  final DateTime hoy;

  const DatosDevsMovil({
    required this.devoluciones,
    this.filtro = FiltroDevs.todas,
    this.rango = RangoDevs.mes,
    this.textoRango = 'Este mes',
    this.busqueda = '',
    this.cargando = false,
    this.error,
    required this.hoy,
  });
}

class AccionesDevsMovil {
  final ValueChanged<FiltroDevs> onFiltro;
  final VoidCallback onRango;
  final ValueChanged<String> onBuscar;
  final ValueChanged<DevolucionModel> onAbrir;
  final VoidCallback onNueva;
  final Future<void> Function() onRefrescar;

  const AccionesDevsMovil({
    required this.onFiltro,
    required this.onRango,
    required this.onBuscar,
    required this.onAbrir,
    required this.onNueva,
    required this.onRefrescar,
  });
}

Widget etiquetaTipo(DevolucionModel d) {
  if (d.estado == 'cancelada') {
    return etiquetaCompra('Cancelada', const Color(0xFF475569), const Color(0xFFF1F5F9));
  }
  return d.tipo == 'cambio'
      ? etiquetaCompra('Cambio', const Color(0xFF5B21B6), const Color(0xFFEDE9FE))
      : etiquetaCompra('Devolución', const Color(0xFF075985), const Color(0xFFE0F2FE));
}

Widget etiquetaDestino(String t) => t == 'Al stock'
    ? etiquetaCompra(t, CM.verdeOs, const Color(0xFFD1FAE5))
    : etiquetaCompra(t, const Color(0xFF92400E), const Color(0xFFFEF3C7));

class DevolucionesMovil extends StatelessWidget {
  final DatosDevsMovil datos;
  final AccionesDevsMovil acciones;
  final TextEditingController buscador;

  const DevolucionesMovil({super.key, required this.datos, required this.acciones, required this.buscador});

  @override
  Widget build(BuildContext context) {
    final r = resumirDevs(datos.devoluciones, datos.hoy);
    final lista = devsVisibles(datos.devoluciones, datos.filtro, datos.busqueda);
    final periodo = switch (datos.rango) {
      RangoDevs.hoy => 'hoy',
      RangoDevs.semana => 'esta semana',
      RangoDevs.mes => 'este mes',
      RangoDevs.elegido => 'en esas fechas',
    };
    return Container(
      color: CM.fondo,
      child: Stack(children: [
        RefreshIndicator(
          color: CM.verde,
          onRefresh: acciones.onRefrescar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text('Devoluciones', style: cf(size: 20, w: FontWeight.w800, color: CM.oscuro))),
                      _chipRango(),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView(scrollDirection: Axis.horizontal, children: [
                        _kpi('Hoy', '${r.hoy}', textoHoy(r), CM.verde, Icons.undo_rounded,
                            () => acciones.onFiltro(FiltroDevs.todas)),
                        _kpi('Devuelto', compactoPesos(r.devuelto), 'salió de la tienda', CM.rojo,
                            Icons.payments_outlined, () => acciones.onFiltro(FiltroDevs.devoluciones),
                            fuerte: r.devuelto > 0),
                        _kpi('Cobrado', compactoPesos(r.cobrado), 'diferencias de cambios', CM.verdeOs,
                            Icons.swap_horiz_rounded, () => acciones.onFiltro(FiltroDevs.cambios),
                            fuerte: r.cobrado > 0),
                        _kpi('A averías', '${cantidadTexto(r.unidadesAverias)} u.', 'dañados $periodo', CM.ambar,
                            Icons.broken_image_outlined, () => acciones.onFiltro(FiltroDevs.devoluciones),
                            fuerte: r.unidadesAverias > 0),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    _buscador(),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final (f, t) in [(FiltroDevs.todas, 'Todas'), (FiltroDevs.devoluciones, 'Devoluciones'),
                                              (FiltroDevs.cambios, 'Cambios'), (FiltroDevs.canceladas, 'Canceladas')])
                          _chip(t, datos.devoluciones.where((d) => cumpleFiltroDev(d, f)).length,
                              datos.filtro == f, () => acciones.onFiltro(f)),
                      ]),
                    ),
                    if (datos.error != null) ...[
                      const SizedBox(height: 8),
                      Text(datos.error!, style: cf(size: 12.5, w: FontWeight.w600, color: CM.rojo)),
                    ],
                  ]),
                ),
              ),
              if (lista.isEmpty)
                SliverToBoxAdapter(child: _vacio(datos.cargando
                    ? 'Cargando…'
                    : datos.devoluciones.isEmpty
                        ? 'No hay devoluciones ni cambios $periodo.'
                        : 'Ninguna coincide.'))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
                  sliver: SliverList.separated(
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _tarjeta(lista[i]),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16, bottom: 16,
          child: Tooltip(
            message: 'Nueva devolución o cambio',
            child: Material(
              color: CM.verde,
              elevation: 3,
              shadowColor: CM.verdeOs.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: acciones.onNueva,
                child: const SizedBox(width: 56, height: 56,
                    child: Icon(Icons.add_rounded, color: Colors.white, size: 26,
                        semanticLabel: 'Nueva devolución o cambio')),
              ),
            ),
          ),
        ),
        if (datos.cargando)
          const Positioned(left: 0, right: 0, top: 0,
              child: LinearProgressIndicator(minHeight: 2.5, color: CM.verde,
                  backgroundColor: Colors.transparent)),
      ]),
    );
  }

  Widget _chipRango() => Material(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: acciones.onRango,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CM.borde2, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: CM.verdeOs),
              const SizedBox(width: 6),
              Text(datos.textoRango, style: cf(size: 12.5, w: FontWeight.w700, color: CM.verdeOs)),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: CM.verdeOs),
            ]),
          ),
        ),
      );

  Widget _tarjeta(DevolucionModel d) {
    final m = montoDev(d);
    final destino = d.tipo == 'cambio' ? null : destinoDev(d);
    final cancelada = d.estado == 'cancelada';
    return Opacity(
      opacity: cancelada ? .7 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => acciones.onAbrir(d),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CM.borde, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text('DEV-${d.id}', style: cf(size: 13.5, w: FontWeight.w800)),
                const SizedBox(width: 8),
                etiquetaTipo(d),
                if (destino != null) ...[const SizedBox(width: 5), Flexible(child: etiquetaDestino(destino))],
                const Spacer(),
                Text(cuandoDev(d.createdAt, datos.hoy), style: cf(size: 11, w: FontWeight.w600, color: CM.gris2)),
              ]),
              const SizedBox(height: 5),
              Text('${d.ventaNumero} · ${d.clienteNombre}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: cf(size: 12.5, color: const Color(0xFF334155))),
              const SizedBox(height: 3),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Text(productosDev(d), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: cf(size: 11.5, color: CM.gris))),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(m.texto, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: cf(size: 14.5, w: FontWeight.w800, color: m.color)),
                    Text(m.detalle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: cf(size: 11, color: CM.gris2)),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _kpi(String t, String v, String s, Color col, IconData i, VoidCallback f, {bool fuerte = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: f,
            child: Container(
              width: 138, height: 90,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CM.borde2, width: 1.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 4, color: col),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        Expanded(child: Text(t, style: cf(size: 10.5, w: FontWeight.w600, color: CM.verdeOs))),
                        Icon(i, size: 15, color: col),
                      ]),
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                          child: Text(v, style: cf(size: 19, w: FontWeight.w800, color: fuerte ? col : CM.oscuro))),
                      Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 10.5, color: CM.gris)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _buscador() => TextField(
        controller: buscador,
        onChanged: acciones.onBuscar,
        style: cf(size: 13.5),
        decoration: InputDecoration(
          hintText: 'Buscar por DEV, factura, cliente o producto',
          hintStyle: cf(size: 13, color: CM.gris2),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: CM.gris2),
          suffixIcon: buscador.text.isEmpty ? null : IconButton(
            tooltip: 'Borrar búsqueda',
            icon: const Icon(Icons.close_rounded, size: 18, color: CM.gris2),
            onPressed: () {
              buscador.clear();
              acciones.onBuscar('');
            },
          ),
          filled: true, fillColor: Colors.white, isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CM.borde, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CM.verde, width: 1.6)),
        ),
      );

  Widget _chip(String t, int n, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: on ? CM.verde : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: f,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: on ? CM.verde : CM.borde, width: 1.3)),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: t, style: cf(size: 12, w: FontWeight.w700,
                    color: on ? Colors.white : const Color(0xFF334155))),
                TextSpan(text: '  $n', style: cf(size: 11, w: FontWeight.w600,
                    color: on ? Colors.white.withValues(alpha: .85) : CM.gris2)),
              ])),
            ),
          ),
        ),
      );

  Widget _vacio(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
        child: Column(children: [
          const Icon(Icons.assignment_return_outlined, size: 40, color: CM.borde2),
          const SizedBox(height: 10),
          Text(t, textAlign: TextAlign.center, style: cf(size: 13.5, color: CM.gris)),
        ]),
      );
}
