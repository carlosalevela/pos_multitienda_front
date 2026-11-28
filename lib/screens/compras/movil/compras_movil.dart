// lib/screens/compras/movil/compras_movil.dart
//
// Compras en el celular: pestañas Órdenes · Proveedores · Por pagar, con la
// paleta verde claro de Clientes. Solo pinta: los datos y las acciones
// llegan desde la pantalla.

import 'package:flutter/material.dart';

import '../../clientes/widgets/cliente_contacto.dart'
    show abrirWhatsAppNumero, llamarNumero, pesosCO, telefonoBonito;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf, compactoPesos;
import 'compras_reglas.dart';

enum PestanaCompras { ordenes, proveedores, porPagar }

const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String fechaCortaCompra(DateTime? f, DateTime hoy) {
  if (f == null) return '';
  final d = DateTime(hoy.year, hoy.month, hoy.day)
      .difference(DateTime(f.year, f.month, f.day)).inDays;
  if (d == 0) return 'Hoy';
  if (d == 1) return 'Ayer';
  return '${f.day} ${_meses[f.month]}${f.year == hoy.year ? '' : ' ${f.year}'}';
}

Widget etiquetaCompra(String t, Color c, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: cf(size: 10.5, w: FontWeight.w800, color: c)),
    );

(String, Color, Color) estadoOrden(Map c) => switch (c['estado']) {
      'pendiente' => ('Por recibir', const Color(0xFF92400E), const Color(0xFFFEF3C7)),
      'recibida'  => ('Recibida', CM.verdeOs, CM.borde),
      _           => ('Cancelada', CM.gris, const Color(0xFFF1F5F9)),
    };

class DatosComprasMovil {
  final PestanaCompras pestana;
  final String? tiendaNombre;
  final bool puedeCambiarTienda;
  final List<Map<String, dynamic>> ordenes;
  final FiltroOrdenes filtro;
  final String busqueda;
  final List<Map<String, dynamic>> proveedores;
  final String filtroProveedores; // activos | deben | inactivos
  final Map<String, dynamic>? porPagar;
  final bool cargando;
  final String? error;
  final DateTime hoy;

  const DatosComprasMovil({
    required this.hoy,
    this.pestana = PestanaCompras.ordenes,
    this.tiendaNombre,
    this.puedeCambiarTienda = false,
    this.ordenes = const [],
    this.filtro = FiltroOrdenes.todas,
    this.busqueda = '',
    this.proveedores = const [],
    this.filtroProveedores = 'activos',
    this.porPagar,
    this.cargando = false,
    this.error,
  });
}

class AccionesComprasMovil {
  final ValueChanged<PestanaCompras> onPestana;
  final VoidCallback? onTienda;
  final ValueChanged<FiltroOrdenes> onFiltro;
  final ValueChanged<String> onBuscar;
  final ValueChanged<Map<String, dynamic>> onOrden;
  final VoidCallback onNuevaOrden;
  final ValueChanged<String> onFiltroProveedores;
  final ValueChanged<Map<String, dynamic>> onProveedor;
  final VoidCallback onNuevoProveedor;
  final ValueChanged<Map<String, dynamic>> onPagar;
  final Future<void> Function() onRefrescar;

  const AccionesComprasMovil({
    required this.onPestana, required this.onFiltro, required this.onBuscar,
    required this.onOrden, required this.onNuevaOrden, required this.onFiltroProveedores,
    required this.onProveedor, required this.onNuevoProveedor, required this.onPagar,
    required this.onRefrescar, this.onTienda,
  });
}

class ComprasMovil extends StatelessWidget {
  final DatosComprasMovil datos;
  final AccionesComprasMovil acciones;
  final TextEditingController buscador;

  const ComprasMovil({super.key, required this.datos, required this.acciones, required this.buscador});

  @override
  Widget build(BuildContext context) {
    final cuerpo = switch (datos.pestana) {
      PestanaCompras.ordenes     => _ordenes(context),
      PestanaCompras.proveedores => _proveedores(context),
      PestanaCompras.porPagar    => _porPagar(context),
    };
    final fab = switch (datos.pestana) {
      PestanaCompras.ordenes     => (Icons.add_rounded, 'Nueva orden', acciones.onNuevaOrden),
      PestanaCompras.proveedores => (Icons.person_add_alt_1_rounded, 'Nuevo proveedor', acciones.onNuevoProveedor),
      PestanaCompras.porPagar    => null,
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
              SliverToBoxAdapter(child: _cabecera()),
              ...cuerpo,
            ],
          ),
        ),
        if (fab != null)
          Positioned(
            right: 16, bottom: 16,
            child: Tooltip(
              message: fab.$2,
              child: Material(
                color: CM.verde,
                elevation: 3,
                shadowColor: CM.verdeOs.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: fab.$3,
                  child: SizedBox(width: 56, height: 56,
                      child: Icon(fab.$1, color: Colors.white, size: 26, semanticLabel: fab.$2)),
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

  Widget _cabecera() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (datos.tiendaNombre != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: datos.puedeCambiarTienda ? acciones.onTienda : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: CM.borde2, width: 1.5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.storefront_outlined, size: 15, color: CM.verdeOs),
                      const SizedBox(width: 6),
                      Flexible(child: Text(datos.tiendaNombre!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: cf(size: 12.5, w: FontWeight.w700, color: CM.verdeOs))),
                      if (datos.puedeCambiarTienda)
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: CM.verdeOs),
                    ]),
                  ),
                ),
              ),
            ),
          if (datos.tiendaNombre != null) const SizedBox(height: 10),
          Row(children: [
            for (final (p, t) in [(PestanaCompras.ordenes, 'Órdenes'),
                                  (PestanaCompras.proveedores, 'Proveedores'),
                                  (PestanaCompras.porPagar, 'Por pagar')])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: datos.pestana == p ? CM.verde : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => acciones.onPestana(p),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: datos.pestana == p ? CM.verde : CM.borde, width: 1.5)),
                        child: Text(t, maxLines: 1, style: cf(size: 12.5, w: FontWeight.w800,
                            color: datos.pestana == p ? Colors.white : const Color(0xFF334155))),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          if (datos.error != null) ...[
            const SizedBox(height: 10),
            Text(datos.error!, style: cf(size: 12.5, w: FontWeight.w600, color: CM.rojo)),
          ],
        ]),
      );

  // ── Órdenes ───────────────────────────────────────────────

  List<Widget> _ordenes(BuildContext context) {
    final r = resumirOrdenes(datos.ordenes, datos.hoy);
    final lista = ordenesVisibles(datos.ordenes, datos.filtro, datos.busqueda);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 90,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _kpi('Por recibir', '${r.porRecibir}',
                    r.porRecibir == 0 ? 'nada en camino' : '${compactoPesos(r.totalPorRecibir)} en camino',
                    CM.ambar, Icons.local_shipping_outlined,
                    () => acciones.onFiltro(FiltroOrdenes.pendientes), fuerte: r.porRecibir > 0),
                _kpi('Recibidas', '${r.recibidasMes}', 'este mes · ${compactoPesos(r.totalRecibidasMes)}',
                    CM.verde, Icons.inventory_2_outlined, () => acciones.onFiltro(FiltroOrdenes.recibidas)),
                _kpi('Por pagar', compactoPesos(r.totalPorPagar), '${r.porPagar} a crédito',
                    CM.morado, Icons.handshake_outlined, () => acciones.onPestana(PestanaCompras.porPagar),
                    fuerte: r.porPagar > 0),
                _kpi('Vencidas', '${r.vencidas}', r.vencidas == 0 ? 'ninguna' : pesosCO(r.totalVencido),
                    CM.rojo, Icons.warning_amber_rounded, () => acciones.onPestana(PestanaCompras.porPagar),
                    fuerte: r.vencidas > 0),
              ]),
            ),
            const SizedBox(height: 10),
            _buscadorWidget('Buscar por número o proveedor'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final (f, t) in [(FiltroOrdenes.todas, 'Todas'), (FiltroOrdenes.pendientes, 'Por recibir'),
                                      (FiltroOrdenes.recibidas, 'Recibidas'), (FiltroOrdenes.credito, 'A crédito'),
                                      (FiltroOrdenes.canceladas, 'Canceladas')])
                  _chip(t, datos.ordenes.where((c) => cumpleFiltroOrden(c, f)).length,
                      datos.filtro == f, () => acciones.onFiltro(f)),
              ]),
            ),
          ]),
        ),
      ),
      if (lista.isEmpty)
        SliverToBoxAdapter(child: _vacio(datos.ordenes.isEmpty && !datos.cargando
            ? 'Todavía no hay órdenes de compra.' : datos.cargando ? 'Cargando…' : 'Ninguna orden coincide.'))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
          sliver: SliverList.separated(
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _tarjetaOrden(lista[i]),
          ),
        ),
    ];
  }

  Widget _tarjetaOrden(Map<String, dynamic> c) {
    final (txt, col, bg) = estadoOrden(c);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => acciones.onOrden(c),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: vencida(c, datos.hoy) ? const Color(0xFFFDA4AF) : CM.borde, width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text('${c['numero_orden'] ?? ''}', style: cf(size: 13.5, w: FontWeight.w800)),
              const SizedBox(width: 8),
              etiquetaCompra(txt, col, bg),
              if (esCredito(c) && c['estado'] != 'cancelada') ...[
                const SizedBox(width: 5),
                etiquetaCompra(c['pagado'] == true ? 'Pagada' : 'Crédito', const Color(0xFF5B21B6),
                    const Color(0xFFEDE9FE)),
              ],
              const Spacer(),
              Text(fechaCortaCompra(fechaDe(c['fecha_orden']), datos.hoy),
                  style: cf(size: 11, w: FontWeight.w600, color: CM.gris2)),
            ]),
            const SizedBox(height: 5),
            Text('${c['proveedor_nombre'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: cf(size: 13, w: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Text(textoTiendas(c), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: cf(size: 11.5, color: CM.gris))),
              Text(pesosCO(numDe(c['total'])), style: cf(size: 15, w: FontWeight.w800, color: CM.oscuro)),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Proveedores ───────────────────────────────────────────

  List<Widget> _proveedores(BuildContext context) {
    final q = datos.busqueda.trim().toLowerCase();
    final l = datos.proveedores.where((p) {
      if (datos.filtroProveedores == 'deben' && numDe(p['deuda']) <= 0) return false;
      if (q.isEmpty) return true;
      return '${p['nombre']} ${p['nit'] ?? ''} ${p['telefono'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
    final deben = datos.proveedores.where((p) => numDe(p['deuda']) > 0).length;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buscadorWidget('Buscar por nombre, NIT o teléfono'),
            const SizedBox(height: 8),
            Row(children: [
              _chip('Activos', datos.filtroProveedores == 'inactivos' ? null : datos.proveedores.length,
                  datos.filtroProveedores == 'activos', () => acciones.onFiltroProveedores('activos')),
              _chip('Les debemos', datos.filtroProveedores == 'inactivos' ? null : deben,
                  datos.filtroProveedores == 'deben', () => acciones.onFiltroProveedores('deben')),
              _chip('Inactivos', null, datos.filtroProveedores == 'inactivos',
                  () => acciones.onFiltroProveedores('inactivos')),
            ]),
          ]),
        ),
      ),
      if (l.isEmpty)
        SliverToBoxAdapter(child: _vacio(datos.cargando ? 'Cargando…' : 'No hay proveedores aquí.'))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
          sliver: SliverList.separated(
            itemCount: l.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _tarjetaProveedor(ctx, l[i]),
          ),
        ),
    ];
  }

  Widget _tarjetaProveedor(BuildContext context, Map<String, dynamic> p) {
    final nombre = '${p['nombre'] ?? ''}';
    final ini = nombre.trim().split(RegExp(r'\s+')).take(2)
        .map((x) => x.isEmpty ? '' : x[0]).join().toUpperCase();
    final deuda = numDe(p['deuda']);
    final vencido = numDe(p['deuda_vencida']) > 0;
    final tel = '${p['telefono'] ?? ''}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => acciones.onProveedor(p),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CM.borde, width: 1.5)),
          child: Row(children: [
            Container(
              width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: CM.borde, borderRadius: BorderRadius.circular(12)),
              child: Text(ini, style: cf(size: 14, w: FontWeight.w800, color: CM.verdeOs)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: cf(size: 13.5, w: FontWeight.w800)),
                Text([
                  if ('${p['nit'] ?? ''}'.isNotEmpty) 'NIT ${p['nit']}',
                  if (tel.isNotEmpty) telefonoBonito(tel),
                ].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: cf(size: 11.5, color: CM.gris)),
                Text(
                  deuda > 0
                      ? 'Le debemos ${pesosCO(deuda)}${vencido ? ' · vencido' : ''}'
                      : '${p['n_ordenes'] ?? 0} órdenes · compró ${compactoPesos(numDe(p['total_comprado']))}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: cf(size: 11.5, w: deuda > 0 ? FontWeight.w800 : FontWeight.w500,
                      color: deuda > 0 ? (vencido ? CM.rojo : CM.morado) : CM.gris2),
                ),
              ]),
            ),
            const SizedBox(width: 4),
            _icono(Icons.phone_outlined, 'Llamar a $nombre', CM.verdeOs, Colors.white,
                () => llamarNumero(context, tel, nombre)),
            const SizedBox(width: 4),
            _icono(Icons.chat_outlined, 'WhatsApp a $nombre', const Color(0xFF15803D),
                const Color(0xFFF0FDF4), () => abrirWhatsAppNumero(context, tel, nombre)),
          ]),
        ),
      ),
    );
  }

  // ── Por pagar ─────────────────────────────────────────────

  List<Widget> _porPagar(BuildContext context) {
    final d = datos.porPagar;
    if (d == null) {
      return [SliverToBoxAdapter(child: _vacio(datos.cargando ? 'Cargando…' : 'No se pudo cargar.'))];
    }
    final compras = [for (final c in (d['compras'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
    final porRecibir = [for (final c in (d['por_recibir'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
    final total = numDe(d['total_deuda']);
    final vencidas = compras.where((c) => c['vencida'] == true).toList();
    final totalVencido = vencidas.fold<double>(0, (a, c) => a + numDe(c['total']));
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Le debemos a proveedores', style: cf(size: 11.5, w: FontWeight.w600, color: const Color(0xFF5B21B6))),
              const SizedBox(height: 2),
              Text(pesosCO(total), style: cf(size: 24, w: FontWeight.w800, color: const Color(0xFF5B21B6))),
              const SizedBox(height: 2),
              Text.rich(TextSpan(style: cf(size: 12, color: CM.gris), children: [
                TextSpan(text: '${compras.length} compra${compras.length == 1 ? '' : 's'} a crédito'),
                if (vencidas.isNotEmpty)
                  TextSpan(text: ' · ${vencidas.length} vencida${vencidas.length == 1 ? '' : 's'} (${pesosCO(totalVencido)})',
                      style: cf(size: 12, w: FontWeight.w800, color: CM.rojo)),
              ])),
            ]),
          ),
        ),
      ),
      if (compras.isEmpty && porRecibir.isEmpty)
        SliverToBoxAdapter(child: _vacio('No se le debe nada a ningún proveedor.\n'
            'Las compras a crédito aparecen aquí cuando llega la mercancía.'))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
          sliver: SliverList.list(children: [
            for (final c in compras) ...[_deuda(c, pagable: true), const SizedBox(height: 8)],
            if (porRecibir.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text('A CRÉDITO, TODAVÍA POR RECIBIR',
                    style: cf(size: 10.5, w: FontWeight.w800, color: CM.verdeOs, ls: .8)),
              ),
              for (final c in porRecibir) ...[_deuda(c, pagable: false), const SizedBox(height: 8)],
            ],
          ]),
        ),
    ];
  }

  Widget _deuda(Map<String, dynamic> c, {required bool pagable}) {
    final venc = fechaDe(c['fecha_vencimiento']);
    final dias = venc == null ? null
        : DateTime(venc.year, venc.month, venc.day)
            .difference(DateTime(datos.hoy.year, datos.hoy.month, datos.hoy.day)).inDays;
    final (txt, col, bg) = !pagable
        ? ('Por recibir', const Color(0xFF92400E), const Color(0xFFFEF3C7))
        : dias == null
            ? ('Sin fecha', CM.gris, const Color(0xFFF1F5F9))
            : dias < 0
                ? (textoPago(dias), CM.rojo, const Color(0xFFFFE4E6))
                : dias <= 5
                    ? (textoPago(dias), const Color(0xFF92400E), const Color(0xFFFEF3C7))
                    : ('Al día', CM.verdeOs, CM.borde);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: col == CM.rojo ? const Color(0xFFFDA4AF) : CM.borde, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('${c['numero_orden'] ?? ''}', style: cf(size: 13, w: FontWeight.w800)),
          const SizedBox(width: 8),
          Flexible(child: etiquetaCompra(txt, col, bg)),
          const Spacer(),
          if (venc != null)
            Text('vence ${venc.day} ${_meses[venc.month]}', style: cf(size: 11, w: FontWeight.w600, color: CM.gris2)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('${c['proveedor_nombre'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: cf(size: 13, w: FontWeight.w700))),
          Text(pesosCO(numDe(c['total'])), style: cf(size: 15, w: FontWeight.w800, color: CM.oscuro)),
          if (pagable) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => acciones.onPagar(c),
              style: FilledButton.styleFrom(backgroundColor: CM.verde, minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Pagar', style: cf(size: 12.5, w: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ]),
      ]),
    );
  }

  // ── Piezas ────────────────────────────────────────────────

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

  Widget _buscadorWidget(String hint) => TextField(
        controller: buscador,
        onChanged: acciones.onBuscar,
        style: cf(size: 13.5),
        decoration: InputDecoration(
          hintText: hint,
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

  Widget _chip(String t, int? n, bool on, VoidCallback f) => Padding(
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
                if (n != null)
                  TextSpan(text: '  $n', style: cf(size: 11, w: FontWeight.w600,
                      color: on ? Colors.white.withValues(alpha: .85) : CM.gris2)),
              ])),
            ),
          ),
        ),
      );

  Widget _icono(IconData i, String tip, Color c, Color bg, VoidCallback f) => Tooltip(
        message: tip,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: f,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CM.borde, width: 1.3)),
              child: Icon(i, size: 17, color: c, semanticLabel: tip),
            ),
          ),
        ),
      );

  Widget _vacio(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
        child: Column(children: [
          const Icon(Icons.inventory_2_outlined, size: 40, color: CM.borde2),
          const SizedBox(height: 10),
          Text(t, textAlign: TextAlign.center, style: cf(size: 13.5, color: CM.gris)),
        ]),
      );
}
