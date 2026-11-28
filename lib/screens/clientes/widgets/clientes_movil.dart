// lib/screens/clientes/widgets/clientes_movil.dart
//
// Clientes en el celular (admin, supervisor y superadmin): la tienda en un
// chip, tarjetas resumen que filtran, aviso de separados vencidos, filtros,
// orden y una tarjeta por cliente con lo que debe, llamar y WhatsApp.
//
// Paleta verde claro, como Inventario y Gastos en el celular. Las reglas de
// filtro, orden y resumen no dependen de la pantalla y se prueban solas.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/cliente.dart';
import '../../../models/empresa_model.dart';
import '../../../models/tienda_model.dart';
import '../../inventario/widgets/inventario_movil.dart' show InventarioMovil, formatoCompacto;
import 'cliente_contacto.dart';

// ── Paleta ────────────────────────────────────────────────────

class CM {
  static const fondo   = Color(0xFFF0FDF4);
  static const borde   = Color(0xFFD1FAE5);
  static const borde2  = Color(0xFFA7F3D0);
  static const verde   = Color(0xFF059669);
  static const verdeOs = Color(0xFF047857);
  static const oscuro  = Color(0xFF064E3B);
  static const tinta   = Color(0xFF0F172A);
  static const gris    = Color(0xFF475569);
  static const gris2   = Color(0xFF64748B);
  static const rojo    = Color(0xFFBE123C);
  static const ambar   = Color(0xFFB45309);
  static const morado  = Color(0xFF6D28D9);
  static const turq    = Color(0xFF0D9488);
}

TextStyle cf({double size = 13, FontWeight w = FontWeight.w500,
    Color color = CM.tinta, double? h, double? ls}) {
  final f = InventarioMovil.fuenteDePrueba;
  if (f != null) {
    return TextStyle(fontFamily: f, fontSize: size, fontWeight: w, color: color, height: h, letterSpacing: ls);
  }
  return GoogleFonts.inter(fontSize: size, fontWeight: w, color: color, height: h, letterSpacing: ls);
}

// ── Reglas ────────────────────────────────────────────────────

enum FiltroClientes { todos, deben, vencidos, alerta, separados, credito, inactivos }

enum OrdenClientes { nombre, deuda, vence, compras, recientes }

String nombreOrden(OrdenClientes o) => switch (o) {
      OrdenClientes.nombre    => 'Nombre (A-Z)',
      OrdenClientes.deuda     => 'Más deuda primero',
      OrdenClientes.vence     => 'Separado que vence primero',
      OrdenClientes.compras   => 'Los que más compran',
      OrdenClientes.recientes => 'Agregados recientemente',
    };

String nombreOrdenCorto(OrdenClientes o) => switch (o) {
      OrdenClientes.nombre    => 'A-Z',
      OrdenClientes.deuda     => 'Más deuda',
      OrdenClientes.vence     => 'Vence primero',
      OrdenClientes.compras   => 'Más compras',
      OrdenClientes.recientes => 'Recientes',
    };

bool estaVencido(Cliente c, DateTime hoy) {
  final d = diasParaVencer(c.saldos, hoy);
  return d != null && d < 0 && (c.saldos?.separados ?? 0) > 0;
}

/// Vencido o vence en los próximos 3 días (lo mismo que las alertas).
bool enAlerta(Cliente c, DateTime hoy) {
  final d = diasParaVencer(c.saldos, hoy);
  return d != null && d <= 3 && (c.saldos?.separados ?? 0) > 0;
}

bool cumpleFiltro(Cliente c, FiltroClientes f, DateTime hoy) => switch (f) {
      FiltroClientes.todos     => c.activo,
      FiltroClientes.deben     => c.activo && c.debe > 0,
      FiltroClientes.vencidos  => estaVencido(c, hoy),
      FiltroClientes.alerta    => enAlerta(c, hoy),
      FiltroClientes.separados => (c.saldos?.separadosActivos ?? 0) > 0,
      FiltroClientes.credito   => c.activo && c.limiteCredito > 0,
      FiltroClientes.inactivos => !c.activo,
    };

List<Cliente> clientesVisibles(List<Cliente> todos, FiltroClientes f,
    OrdenClientes o, DateTime hoy) {
  final l = todos.where((c) => cumpleFiltro(c, f, hoy)).toList();
  int nombre(Cliente a, Cliente b) =>
      a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase());
  switch (o) {
    case OrdenClientes.nombre:
      l.sort(nombre);
    case OrdenClientes.deuda:
      l.sort((a, b) {
        final c = b.debe.compareTo(a.debe);
        return c != 0 ? c : nombre(a, b);
      });
    case OrdenClientes.vence:
      l.sort((a, b) {
        final va = a.saldos?.proximoVencimiento, vb = b.saldos?.proximoVencimiento;
        if (va == null && vb == null) return nombre(a, b);
        if (va == null) return 1;
        if (vb == null) return -1;
        return va.compareTo(vb);
      });
    case OrdenClientes.compras:
      l.sort((a, b) => b.totalAcumulado.compareTo(a.totalAcumulado));
    case OrdenClientes.recientes:
      l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return l;
}

class ResumenClientes {
  final int activos, inactivos, deben, conSeparado, separados, vencidos, porVencer, conCredito;
  final double totalDeuda, totalVencido;
  const ResumenClientes({
    this.activos = 0, this.inactivos = 0, this.deben = 0, this.conSeparado = 0,
    this.separados = 0, this.vencidos = 0, this.porVencer = 0, this.conCredito = 0,
    this.totalDeuda = 0, this.totalVencido = 0,
  });
}

ResumenClientes resumirClientes(List<Cliente> l, DateTime hoy) {
  var activos = 0, inactivos = 0, deben = 0, conSep = 0, seps = 0, venc = 0, porV = 0, cred = 0;
  var deuda = 0.0, vencido = 0.0;
  for (final c in l) {
    if (!c.activo) {
      inactivos++;
      continue;
    }
    activos++;
    if (c.debe > 0) {
      deben++;
      deuda += c.debe;
    }
    if (c.limiteCredito > 0) cred++;
    final n = c.saldos?.separadosActivos ?? 0;
    if (n > 0) {
      conSep++;
      seps += n;
    }
    if (estaVencido(c, hoy)) {
      venc++;
      vencido += c.saldos!.separados;
    } else if (enAlerta(c, hoy)) {
      porV++;
    }
  }
  return ResumenClientes(activos: activos, inactivos: inactivos, deben: deben,
      conSeparado: conSep, separados: seps, vencidos: venc, porVencer: porV,
      conCredito: cred, totalDeuda: deuda, totalVencido: vencido);
}

String iniciales(Cliente c) => [
      if (c.nombre.trim().isNotEmpty) c.nombre.trim()[0],
      if (c.apellido.trim().isNotEmpty) c.apellido.trim()[0],
    ].join().toUpperCase();

/// "$2,42M", "$104K".
String compactoPesos(double v) => '\$${formatoCompacto(v)}';

// ── Lo que recibe la vista ────────────────────────────────────

class DatosClientesMovil {
  final String? tiendaNombre;
  final bool puedeCambiarTienda;
  final List<Cliente> clientes;
  final FiltroClientes filtro;
  final OrdenClientes orden;
  final bool cargando;
  final String? error;
  final bool buscando;
  final DateTime hoy;

  const DatosClientesMovil({
    required this.clientes,
    required this.hoy,
    this.tiendaNombre,
    this.puedeCambiarTienda = true,
    this.filtro = FiltroClientes.todos,
    this.orden = OrdenClientes.nombre,
    this.cargando = false,
    this.error,
    this.buscando = false,
  });

  ResumenClientes get resumen => resumirClientes(clientes, hoy);
  List<Cliente> get visibles => clientesVisibles(clientes, filtro, orden, hoy);
}

class AccionesClientesMovil {
  final VoidCallback onTienda;
  final ValueChanged<FiltroClientes> onFiltro;
  final VoidCallback onOrden;
  final ValueChanged<String> onBuscar;
  final ValueChanged<Cliente> onCliente;
  final ValueChanged<Cliente> onLlamar;
  final ValueChanged<Cliente> onWhatsApp;
  final VoidCallback? onNuevo;
  final Future<void> Function() onRefrescar;

  const AccionesClientesMovil({
    required this.onTienda, required this.onFiltro, required this.onOrden,
    required this.onBuscar, required this.onCliente, required this.onLlamar,
    required this.onWhatsApp, required this.onRefrescar, this.onNuevo,
  });
}

// ── Vista ─────────────────────────────────────────────────────

class ClientesMovil extends StatelessWidget {
  final DatosClientesMovil datos;
  final AccionesClientesMovil acciones;
  final TextEditingController buscador;

  const ClientesMovil({super.key, required this.datos, required this.acciones,
      required this.buscador});

  @override
  Widget build(BuildContext context) {
    final r = datos.resumen;
    final sinTienda = datos.tiendaNombre == null;
    final lista = datos.visibles;
    return Container(
      color: CM.fondo,
      child: Stack(children: [
        RefreshIndicator(
          color: CM.verde,
          onRefresh: acciones.onRefrescar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _cabecera(r)),
              if (sinTienda)
                SliverFillRemaining(hasScrollBody: false, child: _sinTienda())
              else if (datos.error != null)
                SliverToBoxAdapter(child: _mensaje(Icons.cloud_off_rounded, datos.error!))
              else if (datos.cargando && datos.clientes.isEmpty)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: CM.verde))))
              else if (lista.isEmpty)
                SliverToBoxAdapter(child: _vacia())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
                  sliver: SliverList.separated(
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TarjetaCliente(
                      cliente: lista[i],
                      hoy: datos.hoy,
                      onTap: () => acciones.onCliente(lista[i]),
                      onLlamar: () => acciones.onLlamar(lista[i]),
                      onWhatsApp: () => acciones.onWhatsApp(lista[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (acciones.onNuevo != null && !sinTienda)
          Positioned(
            right: 16, bottom: 16,
            child: Semantics(
              button: true,
              label: 'Nuevo cliente',
              child: Material(
                color: CM.verde,
                elevation: 3,
                shadowColor: CM.verdeOs.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: acciones.onNuevo,
                  child: const SizedBox(width: 56, height: 56,
                      child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 26)),
                ),
              ),
            ),
          ),
        if (datos.cargando && datos.clientes.isNotEmpty)
          const Positioned(left: 0, right: 0, top: 0,
              child: LinearProgressIndicator(minHeight: 2.5, color: CM.verde,
                  backgroundColor: Colors.transparent)),
      ]),
    );
  }

  Widget _cabecera(ResumenClientes r) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: _chipTienda()),
            const SizedBox(width: 8),
            if (datos.tiendaNombre != null)
              Text('${r.activos} cliente${r.activos == 1 ? '' : 's'}',
                  style: cf(size: 11.5, w: FontWeight.w600, color: CM.gris2)),
          ]),
          if (datos.tiendaNombre != null) ...[
            const SizedBox(height: 10),
            _kpis(r),
            if (r.vencidos + r.porVencer > 0) ...[
              const SizedBox(height: 10),
              _alerta(r),
            ],
            const SizedBox(height: 10),
            _buscador(),
            const SizedBox(height: 8),
            _filtros(r),
            if (datos.filtro == FiltroClientes.deben && r.deben > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 2),
                child: Text.rich(TextSpan(style: cf(size: 12, color: const Color(0xFF334155)), children: [
                  TextSpan(text: '${r.deben} cliente${r.deben == 1 ? '' : 's'}', style: cf(size: 12, w: FontWeight.w800)),
                  const TextSpan(text: ' deben '),
                  TextSpan(text: pesosCO(r.totalDeuda), style: cf(size: 12, w: FontWeight.w800, color: CM.rojo)),
                  const TextSpan(text: ' entre separados y crédito'),
                ])),
              ),
          ],
          const SizedBox(height: 4),
        ]),
      );

  Widget _chipTienda() => Material(
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
              Flexible(child: Text(datos.tiendaNombre ?? 'Elegir tienda',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: cf(size: 12.5, w: FontWeight.w700, color: CM.verdeOs))),
              if (datos.puedeCambiarTienda) ...[
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: CM.verdeOs),
              ],
            ]),
          ),
        ),
      );

  Widget _kpis(ResumenClientes r) {
    Widget k(String t, String v, String s, Color col, IconData i, FiltroClientes f, {bool fuerte = false}) {
      final on = datos.filtro == f && f != FiltroClientes.todos;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => acciones.onFiltro(datos.filtro == f ? FiltroClientes.todos : f),
            child: Container(
              width: 138, height: 90,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? CM.verde : CM.borde2, width: on ? 2 : 1.5),
              ),
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(v, style: cf(size: 19, w: FontWeight.w800, color: fuerte ? col : CM.oscuro)),
                      ),
                      Text(s, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: cf(size: 10.5, color: CM.gris)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          k('Clientes', '${r.activos}', r.inactivos > 0 ? '${r.inactivos} inactivo${r.inactivos == 1 ? '' : 's'}' : 'activos',
              CM.verde, Icons.people_alt_outlined, FiltroClientes.todos),
          k('Deben', compactoPesos(r.totalDeuda), '${r.deben} cliente${r.deben == 1 ? '' : 's'}',
              CM.rojo, Icons.account_balance_wallet_outlined, FiltroClientes.deben, fuerte: r.deben > 0),
          k('Separados', '${r.separados}', '${r.conSeparado} cliente${r.conSeparado == 1 ? '' : 's'}',
              CM.turq, Icons.shopping_bag_outlined, FiltroClientes.separados),
          k('Vencidos', '${r.vencidos}', r.vencidos > 0 ? pesosCO(r.totalVencido) : 'ninguno',
              CM.ambar, Icons.warning_amber_rounded, FiltroClientes.vencidos, fuerte: r.vencidos > 0),
        ],
      ),
    );
  }

  Widget _alerta(ResumenClientes r) {
    final partes = [
      if (r.vencidos > 0) '${r.vencidos} separado${r.vencidos == 1 ? '' : 's'} vencido${r.vencidos == 1 ? '' : 's'}',
      if (r.porVencer > 0) '${r.porVencer} por vencer en 3 días',
    ];
    final on = datos.filtro == FiltroClientes.alerta;
    return Material(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => acciones.onFiltro(on ? FiltroClientes.todos : FiltroClientes.alerta),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? const Color(0xFFEA580C) : const Color(0xFFFED7AA), width: 1.5)),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFC2410C)),
            const SizedBox(width: 8),
            Expanded(child: Text(partes.join(' · '),
                style: cf(size: 12, w: FontWeight.w700, color: const Color(0xFF7C2D12)))),
            Text(on ? 'Quitar' : 'Ver', style: cf(size: 12, w: FontWeight.w800, color: const Color(0xFF9A3412))),
          ]),
        ),
      ),
    );
  }

  Widget _buscador() => TextField(
        controller: buscador,
        onChanged: acciones.onBuscar,
        textInputAction: TextInputAction.search,
        style: cf(size: 13.5),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, teléfono o cédula',
          hintStyle: cf(size: 13, color: CM.gris2),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: CM.gris2),
          suffixIcon: buscador.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.close_rounded, size: 18, color: CM.gris2),
                  onPressed: () {
                    buscador.clear();
                    acciones.onBuscar('');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CM.borde, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CM.verde, width: 1.6)),
        ),
      );

  Widget _filtros(ResumenClientes r) {
    Widget chip(String t, int n, FiltroClientes f, {bool rojo = false}) {
      final on = datos.filtro == f;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: on ? CM.verde : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => acciones.onFiltro(f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: on ? CM.verde : CM.borde, width: 1.3)),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: t, style: cf(size: 12, w: FontWeight.w700,
                    color: on ? Colors.white : rojo ? CM.rojo : const Color(0xFF334155))),
                TextSpan(text: '  $n', style: cf(size: 11, w: FontWeight.w600,
                    color: on ? Colors.white.withValues(alpha: .85) : CM.gris2)),
              ])),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('Todos', r.activos, FiltroClientes.todos),
            chip('Deben', r.deben, FiltroClientes.deben),
            chip('Vencidos', r.vencidos, FiltroClientes.vencidos, rojo: r.vencidos > 0),
            chip('Con crédito', r.conCredito, FiltroClientes.credito),
            chip('Inactivos', r.inactivos, FiltroClientes.inactivos),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      TextButton.icon(
        onPressed: acciones.onOrden,
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36), foregroundColor: CM.verdeOs),
        icon: const Icon(Icons.swap_vert_rounded, size: 17),
        label: Text(nombreOrdenCorto(datos.orden), style: cf(size: 12, w: FontWeight.w700, color: CM.verdeOs)),
      ),
    ]);
  }

  Widget _sinTienda() => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.storefront_outlined, size: 44, color: CM.borde2),
          const SizedBox(height: 12),
          Text('Elige la tienda para ver sus clientes', textAlign: TextAlign.center,
              style: cf(size: 14, w: FontWeight.w600, color: CM.gris)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: acciones.onTienda,
            style: FilledButton.styleFrom(backgroundColor: CM.verde, minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: Text('Elegir tienda', style: cf(size: 14, w: FontWeight.w800, color: Colors.white)),
          ),
        ]),
      );

  Widget _mensaje(IconData i, String t) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(children: [
          Icon(i, size: 36, color: CM.gris2),
          const SizedBox(height: 10),
          Text(t, textAlign: TextAlign.center, style: cf(size: 13, color: CM.gris)),
        ]),
      );

  Widget _vacia() {
    final texto = switch (datos.filtro) {
      _ when buscador.text.isNotEmpty => 'Nadie coincide con "${buscador.text}".',
      FiltroClientes.todos     => 'Todavía no hay clientes en esta tienda.',
      FiltroClientes.deben     => 'Nadie debe. Todo al día.',
      FiltroClientes.vencidos  => 'No hay separados vencidos.',
      FiltroClientes.alerta    => 'No hay separados vencidos ni por vencer.',
      FiltroClientes.separados => 'Nadie tiene separados activos.',
      FiltroClientes.credito   => 'Ningún cliente tiene crédito.',
      FiltroClientes.inactivos => 'No hay clientes inactivos.',
    };
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(children: [
        const Icon(Icons.people_alt_outlined, size: 40, color: CM.borde2),
        const SizedBox(height: 10),
        Text(texto, textAlign: TextAlign.center, style: cf(size: 13.5, color: CM.gris)),
        if (datos.filtro != FiltroClientes.todos) ...[
          const SizedBox(height: 6),
          TextButton(onPressed: () => acciones.onFiltro(FiltroClientes.todos),
              child: Text('Ver todos', style: cf(size: 13, w: FontWeight.w700, color: CM.verdeOs))),
        ],
      ]),
    );
  }
}

class _TarjetaCliente extends StatelessWidget {
  final Cliente cliente;
  final DateTime hoy;
  final VoidCallback onTap, onLlamar, onWhatsApp;
  const _TarjetaCliente({required this.cliente, required this.hoy, required this.onTap,
      required this.onLlamar, required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    final c = cliente;
    final tier = c.tierInfo;
    Color? tierCol;
    if (tier != null) {
      try {
        tierCol = Color(int.parse(tier.colorHex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    final inactivo = !c.activo;
    return LayoutBuilder(builder: (_, caja) {
    final angosta = caja.maxWidth < 360;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CM.borde, width: 1.5)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: inactivo ? const Color(0xFFF1F5F9) : CM.borde,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(iniciales(c), style: cf(size: 14, w: FontWeight.w800,
                  color: inactivo ? CM.gris2 : CM.verdeOs)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.nombreCompleto, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: cf(size: 13.5, w: FontWeight.w800, color: inactivo ? CM.gris2 : CM.tinta)),
                const SizedBox(height: 2),
                if (angosta && _tieneMonto)
                  Padding(padding: const EdgeInsets.only(top: 1), child: _derecha(enLinea: true)),
                Row(children: [
                  Flexible(child: Text(c.telefono.isEmpty ? 'Sin teléfono' : telefonoBonito(c.telefono),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 11.5, color: CM.gris))),
                  if (inactivo) ...[
                    const SizedBox(width: 6),
                    _etiqueta('INACTIVO', CM.gris2, const Color(0xFFF1F5F9)),
                  ] else if (tier != null) ...[
                    const SizedBox(width: 6),
                    _etiqueta(tier.nombre.toUpperCase(), tierCol ?? CM.gris,
                        (tierCol ?? CM.gris).withValues(alpha: .12)),
                  ],
                ]),
              ]),
            ),
            if (!angosta) ...[
              const SizedBox(width: 6),
              _derecha(),
            ],
            const SizedBox(width: 4),
            _boton(Icons.phone_outlined, 'Llamar a ${c.nombre}', CM.verdeOs, Colors.white, onLlamar),
            const SizedBox(width: 4),
            _boton(Icons.chat_outlined, 'WhatsApp a ${c.nombre}', const Color(0xFF15803D),
                const Color(0xFFF0FDF4), onWhatsApp),
          ]),
        ),
      ),
    );
    });
  }

  bool get _tieneMonto => cliente.debe > 0 || cliente.totalAcumulado > 0;

  Widget _derecha({bool enLinea = false}) {
    final c = cliente;
    final s = c.saldos;
    if (c.debe > 0) {
      final dias = diasParaVencer(s, hoy);
      final vencido = estaVencido(c, hoy);
      final col = vencido ? CM.rojo : CM.ambar;
      final sub = (s?.separados ?? 0) > 0 && dias != null
          ? textoVencimiento(dias)
          : (s?.credito ?? 0) > 0 && (s?.separados ?? 0) == 0
              ? 'Crédito'
              : (s?.separadosActivos ?? 0) > 1
                  ? '${s!.separadosActivos} separados'
                  : 'Separado';
      if (enLinea) {
        return Text.rich(TextSpan(children: [
          TextSpan(text: 'Debe ${pesosCO(c.debe)}', style: cf(size: 12, w: FontWeight.w800, color: col)),
          TextSpan(text: '  ·  $sub', style: cf(size: 10.5, w: FontWeight.w600, color: CM.gris2)),
        ]), maxLines: 1, overflow: TextOverflow.ellipsis);
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 104),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          FittedBox(fit: BoxFit.scaleDown,
              child: Text('Debe ${pesosCO(c.debe)}', style: cf(size: 12.5, w: FontWeight.w800, color: col))),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: cf(size: 10, w: FontWeight.w600, color: CM.gris2)),
        ]),
      );
    }
    if (c.totalAcumulado > 0) {
      if (enLinea) {
        return Text('Compró ${compactoPesos(c.totalAcumulado)}',
            style: cf(size: 11.5, w: FontWeight.w700, color: CM.gris));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Compró', style: cf(size: 10, w: FontWeight.w600, color: CM.gris2)),
        Text(compactoPesos(c.totalAcumulado), style: cf(size: 12, w: FontWeight.w700, color: CM.gris)),
      ]);
    }
    return const SizedBox();
  }

  Widget _etiqueta(String t, Color c, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Text(t, style: cf(size: 9, w: FontWeight.w800, color: c, ls: .3)),
      );

  Widget _boton(IconData i, String tip, Color c, Color bg, VoidCallback f) => Tooltip(
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
}

// ── Hoja: ordenar ─────────────────────────────────────────────

Future<OrdenClientes?> elegirOrden(BuildContext context, OrdenClientes actual) =>
    showModalBottomSheet<OrdenClientes>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            Text('Ordenar por', style: cf(size: 17, w: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final o in OrdenClientes.values)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Opcion(texto: nombreOrden(o), on: o == actual, onTap: () => Navigator.pop(ctx, o)),
              ),
          ]),
        ),
      ),
    );

class _Opcion extends StatelessWidget {
  final String texto;
  final String? detalle;
  final bool on;
  final VoidCallback onTap;
  const _Opcion({required this.texto, required this.on, required this.onTap, this.detalle});

  @override
  Widget build(BuildContext context) => Material(
        color: on ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? CM.verde : const Color(0xFFE2E8F0), width: 1.5)),
            child: Row(children: [
              Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 20, color: on ? CM.verde : const Color(0xFFCBD5E1)),
              const SizedBox(width: 10),
              Expanded(child: Text(texto, style: cf(size: 13.5, w: FontWeight.w600))),
              if (detalle != null) Text(detalle!, style: cf(size: 11.5, color: CM.gris2)),
            ]),
          ),
        ),
      );
}

// ── Hoja: elegir empresa y tienda ─────────────────────────────

class HojaTienda extends StatefulWidget {
  /// Solo el superadmin elige empresa; vacío = no se muestra.
  final List<Empresa> empresas;
  final Empresa? empresa;
  final List<Tienda> tiendas;
  final Tienda? tienda;
  final Future<List<Tienda>> Function(Empresa e) cargarTiendas;
  final void Function(Empresa? e, Tienda t) onElegir;

  const HojaTienda({super.key, required this.empresas, required this.tiendas,
      required this.cargarTiendas, required this.onElegir, this.empresa, this.tienda});

  @override
  State<HojaTienda> createState() => _HojaTiendaState();
}

class _HojaTiendaState extends State<HojaTienda> {
  late Empresa? _empresa = widget.empresa;
  late List<Tienda> _tiendas = widget.tiendas;
  late Tienda? _tienda = widget.tienda;
  bool _cargando = false;

  Future<void> _cambiarEmpresa(Empresa e) async {
    setState(() {
      _empresa = e;
      _tienda = null;
      _tiendas = const [];
      _cargando = true;
    });
    final t = await widget.cargarTiendas(e);
    if (!mounted || _empresa?.id != e.id) return;
    setState(() {
      _tiendas = t;
      _cargando = false;
      if (t.length == 1) _tienda = t.first;
    });
  }

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            Text('¿De qué tienda?', style: cf(size: 17, w: FontWeight.w800)),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (widget.empresas.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('EMPRESA', style: cf(size: 10.5, w: FontWeight.w800, color: CM.verdeOs, ls: .8)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final e in widget.empresas)
                        ChoiceChip(
                          label: Text(e.nombre),
                          selected: _empresa?.id == e.id,
                          showCheckmark: false,
                          selectedColor: CM.verde,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: _empresa?.id == e.id ? CM.verde : CM.borde),
                          labelStyle: cf(size: 12, w: FontWeight.w700,
                              color: _empresa?.id == e.id ? Colors.white : const Color(0xFF334155)),
                          onSelected: (_) => _cambiarEmpresa(e),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Text('TIENDA', style: cf(size: 10.5, w: FontWeight.w800, color: CM.verdeOs, ls: .8)),
                  if (_cargando)
                    const Padding(padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator(color: CM.verde)))
                  else if (_tiendas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(widget.empresas.isNotEmpty && _empresa == null
                          ? 'Primero elige la empresa.' : 'Esta empresa no tiene tiendas.',
                          style: cf(size: 13, color: CM.gris)),
                    )
                  else
                    for (final t in _tiendas)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _Opcion(texto: t.nombre, detalle: t.ciudad.isEmpty ? null : t.ciudad,
                            on: _tienda?.id == t.id, onTap: () => setState(() => _tienda = t)),
                      ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _tienda == null ? null : () {
                  Navigator.pop(context);
                  widget.onElegir(_empresa, _tienda!);
                },
                style: FilledButton.styleFrom(backgroundColor: CM.verde,
                    disabledBackgroundColor: CM.borde,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text('Ver clientes', style: cf(size: 14, w: FontWeight.w800,
                    color: _tienda == null ? CM.verdeOs : Colors.white)),
              ),
            ),
          ]),
        ),
      );
}
