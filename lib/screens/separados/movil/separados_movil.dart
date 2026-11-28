// lib/screens/separados/movil/separados_movil.dart
//
// Lista de separados en el celular. Solo pinta: recibe datos y avisa con
// callbacks (la pantalla carga y navega). Aquí también las piezas que usan
// el detalle y las hojas.

import 'package:flutter/material.dart';

import '../../../models/separado.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf, compactoPesos;
import 'separados_reglas.dart';

// ── Piezas comunes ────────────────────────────────────────────

Widget etiquetaSep(EstadoSep e) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: e.fondo, borderRadius: BorderRadius.circular(6)),
      child: Text(e.texto, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: cf(size: 10.5, w: FontWeight.w800, color: e.color)),
    );

Widget cajaSep(Widget child, {Color borde = CM.borde, Color fondo = Colors.white, EdgeInsets? padding}) => Container(
      padding: padding ?? const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borde, width: 1.5)),
      child: child,
    );

Widget barraSep(double progreso, {double alto = 7}) => ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: SizedBox(
        height: alto,
        child: Stack(children: [
          Container(color: const Color(0xFFE2E8F0)),
          FractionallySizedBox(widthFactor: progreso.clamp(0.0, 1.0),
              child: Container(color: CM.verde)),
        ]),
      ),
    );

Widget tituloSep(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 7),
      child: Text(t.toUpperCase(), style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
    );

Widget kvSep(String k, String v, {Color? color, bool fuerte = false, bool raya = false}) => Container(
      margin: EdgeInsets.only(top: raya ? 4 : 0),
      padding: EdgeInsets.only(top: raya ? 7 : 3, bottom: 3),
      decoration: raya ? const BoxDecoration(border: Border(top: BorderSide(color: CM.borde))) : null,
      child: Row(children: [
        Expanded(child: Text(k, style: cf(size: 13, w: fuerte ? FontWeight.w700 : FontWeight.w500,
            color: fuerte ? CM.tinta : CM.gris))),
        const SizedBox(width: 10),
        Text(v, textAlign: TextAlign.right,
            style: cf(size: fuerte ? 15 : 13, w: FontWeight.w800, color: color ?? CM.tinta)),
      ]),
    );

String inicialesDe(String nombre) {
  final p = nombre.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
}

Widget avatarSep(String nombre, {double t = 40}) => Container(
      width: t, height: t,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(t * .3)),
      child: Text(inicialesDe(nombre), style: cf(size: t * .35, w: FontWeight.w800, color: CM.verdeOs)),
    );

Widget iconoBoton(IconData i, String tip, VoidCallback? f, {Color c = CM.verdeOs, Color borde = CM.borde,
        Color fondo = Colors.white, double t = 38}) =>
    Tooltip(
      message: tip,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: f,
          child: Container(
            width: t, height: t,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(11),
                border: Border.all(color: borde, width: 1.3)),
            child: Icon(i, size: 18, color: f == null ? CM.borde2 : c, semanticLabel: tip),
          ),
        ),
      ),
    );

ButtonStyle botonSep({Color c = CM.verde}) => FilledButton.styleFrom(
      backgroundColor: c, minimumSize: const Size(0, 48),
      disabledBackgroundColor: CM.borde,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

ButtonStyle botonContornoSep({Color c = CM.verdeOs, Color borde = CM.borde2}) => OutlinedButton.styleFrom(
      foregroundColor: c, minimumSize: const Size(0, 48),
      side: BorderSide(color: borde, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

Widget chipSep(String t, bool on, VoidCallback f, {int? n, Color? colorTexto, IconData? icono}) => Material(
      color: on ? CM.verde : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              border: Border.all(color: on ? CM.verde : CM.borde, width: 1.3)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icono != null) ...[
              Icon(icono, size: 13, color: on ? Colors.white : CM.verdeOs),
              const SizedBox(width: 5),
            ],
            Text.rich(TextSpan(children: [
              TextSpan(text: t, style: cf(size: 12, w: FontWeight.w700,
                  color: on ? Colors.white : colorTexto ?? const Color(0xFF334155))),
              if (n != null)
                TextSpan(text: '  $n', style: cf(size: 11, w: FontWeight.w600,
                    color: on ? Colors.white.withValues(alpha: .85) : CM.gris2)),
            ])),
          ]),
        ),
      ),
    );

// ── Lista ─────────────────────────────────────────────────────

class DatosSepsMovil {
  final List<Separado> separados;
  final FiltroSep filtro;
  final String busqueda;
  final bool cargando;
  final String? error;
  final String? tiendaNombre;
  final bool puedeCambiarTienda;
  final double abonosHoy;
  final int nAbonosHoy;
  final bool puedeRecordar;
  final DateTime hoy;

  const DatosSepsMovil({
    required this.separados,
    this.filtro = FiltroSep.activos,
    this.busqueda = '',
    this.cargando = false,
    this.error,
    this.tiendaNombre,
    this.puedeCambiarTienda = false,
    this.abonosHoy = 0,
    this.nAbonosHoy = 0,
    this.puedeRecordar = true,
    required this.hoy,
  });
}

class AccionesSepsMovil {
  final ValueChanged<FiltroSep> onFiltro;
  final ValueChanged<String> onBuscar;
  final ValueChanged<Separado> onAbrir;
  final VoidCallback onNuevo;
  final VoidCallback onEscanear;
  final VoidCallback onRecordar;
  final VoidCallback onAbonosHoy;
  final VoidCallback? onTienda;
  final Future<void> Function() onRefrescar;

  const AccionesSepsMovil({
    required this.onFiltro,
    required this.onBuscar,
    required this.onAbrir,
    required this.onNuevo,
    required this.onEscanear,
    required this.onRecordar,
    required this.onAbonosHoy,
    this.onTienda,
    required this.onRefrescar,
  });
}

class SeparadosMovil extends StatelessWidget {
  final DatosSepsMovil datos;
  final AccionesSepsMovil acciones;
  final TextEditingController buscador;

  const SeparadosMovil({super.key, required this.datos, required this.acciones, required this.buscador});

  @override
  Widget build(BuildContext context) {
    final r = resumirSeps(datos.separados, datos.hoy);
    final lista = sepsVisibles(datos.separados, datos.filtro, datos.busqueda, datos.hoy);
    final alerta = textoAlerta(r);
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
                      Expanded(child: Text('Separados', style: cf(size: 20, w: FontWeight.w800, color: CM.oscuro))),
                      if (datos.tiendaNombre != null) Flexible(child: _chipTienda()),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView(scrollDirection: Axis.horizontal, children: [
                        _kpi('Activos', '${r.activos}', '${compactoPesos(r.porCobrar)} por cobrar', CM.verde,
                            Icons.shopping_bag_outlined, () => acciones.onFiltro(FiltroSep.activos)),
                        _kpi('Vencidos', '${r.vencidos}', r.vencidos == 0 ? 'ninguno' : '${pesosCO(r.saldoVencido)} sin pagar',
                            CM.rojo, Icons.warning_amber_rounded, () => acciones.onFiltro(FiltroSep.vencidos),
                            fuerte: r.vencidos > 0),
                        _kpi('Por entregar', '${r.porEntregar}', 'pagados, sin recoger', CM.turq,
                            Icons.inventory_2_outlined, () => acciones.onFiltro(FiltroSep.porEntregar),
                            fuerte: r.porEntregar > 0),
                        _kpi('Abonos hoy', compactoPesos(datos.abonosHoy), plural(datos.nAbonosHoy, 'abono', 'abonos'),
                            CM.verdeOs, Icons.payments_outlined, acciones.onAbonosHoy),
                      ]),
                    ),
                    if (alerta != null && datos.puedeRecordar) ...[
                      const SizedBox(height: 10),
                      _alerta(alerta),
                    ],
                    const SizedBox(height: 10),
                    _buscador(),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final f in FiltroSep.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: chipSep(nombreFiltro(f), datos.filtro == f, () => acciones.onFiltro(f),
                                n: datos.separados.where((s) => cumpleFiltroSep(s, f, datos.hoy)).length,
                                colorTexto: f == FiltroSep.vencidos ? CM.rojo : null),
                          ),
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
                    : datos.busqueda.trim().isNotEmpty
                        ? 'Ningún separado coincide.'
                        : switch (datos.filtro) {
                            FiltroSep.activos => 'No hay separados activos.',
                            FiltroSep.porVencer => 'Ninguno vence en los próximos $diasPorVencer días.',
                            FiltroSep.vencidos => 'No hay separados vencidos.',
                            FiltroSep.porEntregar => 'No hay separados pagados esperando que los recojan.',
                            FiltroSep.pagados => 'Todavía no hay separados entregados.',
                            FiltroSep.cancelados => 'No hay separados cancelados.',
                          }))
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
            message: 'Nuevo separado',
            child: Material(
              color: CM.verde,
              elevation: 3,
              shadowColor: CM.verdeOs.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: acciones.onNuevo,
                child: const SizedBox(width: 56, height: 56,
                    child: Icon(Icons.add_rounded, color: Colors.white, size: 26, semanticLabel: 'Nuevo separado')),
              ),
            ),
          ),
        ),
        if (datos.cargando)
          const Positioned(left: 0, right: 0, top: 0,
              child: LinearProgressIndicator(minHeight: 2.5, color: CM.verde, backgroundColor: Colors.transparent)),
      ]),
    );
  }

  Widget _chipTienda() => Material(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: datos.puedeCambiarTienda ? acciones.onTienda : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CM.borde2, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.storefront_outlined, size: 14, color: CM.verdeOs),
              const SizedBox(width: 5),
              Flexible(child: Text(datos.tiendaNombre!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: cf(size: 12, w: FontWeight.w700, color: CM.verdeOs))),
              if (datos.puedeCambiarTienda)
                const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: CM.verdeOs),
            ]),
          ),
        ),
      );

  Widget _alerta(String t) => Material(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: acciones.onRecordar,
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA), width: 1.5)),
            child: Row(children: [
              const Icon(Icons.chat_outlined, size: 18, color: Color(0xFF9A3412)),
              const SizedBox(width: 9),
              Expanded(child: Text.rich(TextSpan(children: [
                TextSpan(text: '$t ', style: cf(size: 12, w: FontWeight.w800, color: const Color(0xFF9A3412))),
                TextSpan(text: 'Mándales un recordatorio por WhatsApp.',
                    style: cf(size: 12, color: const Color(0xFF7C2D12))),
              ]))),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF9A3412)),
            ]),
          ),
        ),
      );

  Widget _tarjeta(Separado s) {
    final e = estadoSep(s, datos.hoy);
    final venc = vencido(s, datos.hoy);
    final apagada = s.esCancelado || s.entregado;
    return Opacity(
      opacity: apagada ? .75 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => acciones.onAbrir(s),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: venc ? const Color(0xFFFDA4AF) : CM.borde, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text('SEP-${s.id}', style: cf(size: 13.5, w: FontWeight.w800)),
                const SizedBox(width: 8),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: etiquetaSep(e))),
                const SizedBox(width: 8),
                Text(cuandoSep(s, datos.hoy), style: cf(size: 11, w: FontWeight.w600, color: CM.gris2)),
              ]),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.clienteNombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: cf(size: 13, w: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text(productosSep(s), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: cf(size: 11.5, color: CM.gris)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (s.esActivo) ...[
                    Text(pesosCO(s.saldoPendiente), style: cf(size: 14.5, w: FontWeight.w800, color: CM.rojo)),
                    Text('por pagar', style: cf(size: 10.5, color: CM.gris2)),
                  ] else if (s.esCancelado && s.bonoCodigo != null) ...[
                    Text(pesosCO(s.bonoSaldo ?? s.abonoAcumulado),
                        style: cf(size: 14.5, w: FontWeight.w800, color: CM.morado)),
                    Text('a favor', style: cf(size: 10.5, color: CM.gris2)),
                  ] else ...[
                    Text(pesosCO(s.total), style: cf(size: 14.5, w: FontWeight.w800,
                        color: s.esCancelado ? CM.gris : CM.verdeOs)),
                    Text(s.esCancelado ? 'cancelado' : 'pagado', style: cf(size: 10.5, color: CM.gris2)),
                  ],
                ]),
              ]),
              if (s.esActivo) ...[
                const SizedBox(height: 8),
                barraSep(s.progreso),
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'Abonado ', style: cf(size: 11, color: CM.gris)),
                    TextSpan(text: pesosCO(s.abonoAcumulado), style: cf(size: 11, w: FontWeight.w800)),
                    TextSpan(text: ' de ${pesosCO(s.total)}', style: cf(size: 11, color: CM.gris)),
                  ]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${(s.progreso * 100).round()}%', style: cf(size: 11, w: FontWeight.w700, color: CM.gris)),
                ]),
              ],
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
          hintText: 'Cliente, cédula o SEP-…',
          hintStyle: cf(size: 13, color: CM.gris2),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: CM.gris2),
          suffixIcon: buscador.text.isEmpty
              ? IconButton(
                  tooltip: 'Escanear el recibo',
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: CM.verdeOs),
                  onPressed: acciones.onEscanear,
                )
              : IconButton(
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

  Widget _vacio(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
        child: Column(children: [
          const Icon(Icons.shopping_bag_outlined, size: 40, color: CM.borde2),
          const SizedBox(height: 10),
          Text(t, textAlign: TextAlign.center, style: cf(size: 13.5, color: CM.gris)),
        ]),
      );
}
