// lib/screens/inventario/widgets/inventario_movil.dart
//
// Inventario en celular. Diseño exclusivo para pantallas angostas,
// con la misma paleta de la pantalla de Caja móvil: fondo mentolado,
// verde esmeralda, turquesa y lima (análogos), y rojo / ámbar reservados
// para alertas.
//
// Es un widget "tonto": recibe los datos ya calculados y las acciones
// como callbacks. No lee providers, así se puede renderizar en un test.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../models/producto.dart';
import '../../../utils/numero_excel.dart';

// ── Paleta (la misma de caja_dashboard_admin) ─────────────────
class _C {
  static const fondo    = Color(0xFFF0FDF4);
  static const borde    = Color(0xFFDCF0E4);
  static const tinta    = Color(0xFF0F172A);
  static const gris     = Color(0xFF6B7280);
  static const grisClaro = Color(0xFFCBD5E1);

  static const verde    = Color(0xFF059669);
  static const verdeOs  = Color(0xFF047857);
  static const verde50  = Color(0xFFECFDF5);
  static const verde100 = Color(0xFFD1FAE5);

  static const turq     = Color(0xFF0D9488);
  static const turqOs   = Color(0xFF0F766E);
  static const turq50   = Color(0xFFF0FDFA);
  static const turq100  = Color(0xFFCCFBF1);

  static const lima     = Color(0xFF65A30D);
  static const limaOs   = Color(0xFF4D7C0F);
  static const lima50   = Color(0xFFF7FEE7);
  static const lima100  = Color(0xFFECFCCB);

  static const rojo     = Color(0xFFB91C1C);
  static const rojo50   = Color(0xFFFEF2F2);
  static const rojo100  = Color(0xFFFEE2E2);

  static const ambar    = Color(0xFFD97706);
  static const ambar50  = Color(0xFFFFF7ED);
  static const ambar100 = Color(0xFFFEF3C7);
}

/// Familia de color de un elemento. Verde, turquesa y lima son la paleta
/// análoga; ámbar y rojo quedan para avisos.
enum TonoMovil { verde, turquesa, lima, ambar, rojo, gris }

extension _TonoColores on TonoMovil {
  Color get fuerte => switch (this) {
        TonoMovil.verde    => _C.verde,
        TonoMovil.turquesa => _C.turq,
        TonoMovil.lima     => _C.lima,
        TonoMovil.ambar    => _C.ambar,
        TonoMovil.rojo     => _C.rojo,
        TonoMovil.gris     => _C.gris,
      };
  Color get oscuro => switch (this) {
        TonoMovil.verde    => _C.verdeOs,
        TonoMovil.turquesa => _C.turqOs,
        TonoMovil.lima     => _C.limaOs,
        TonoMovil.ambar    => _C.ambar,
        TonoMovil.rojo     => _C.rojo,
        TonoMovil.gris     => _C.gris,
      };
  Color get suave => switch (this) {
        TonoMovil.verde    => _C.verde50,
        TonoMovil.turquesa => _C.turq50,
        TonoMovil.lima     => _C.lima50,
        TonoMovil.ambar    => _C.ambar50,
        TonoMovil.rojo     => _C.rojo50,
        TonoMovil.gris     => const Color(0xFFF1F5F9),
      };
  Color get medio => switch (this) {
        TonoMovil.verde    => _C.verde100,
        TonoMovil.turquesa => _C.turq100,
        TonoMovil.lima     => _C.lima100,
        TonoMovil.ambar    => _C.ambar100,
        TonoMovil.rojo     => _C.rojo100,
        TonoMovil.gris     => const Color(0xFFE2E8F0),
      };
}

// ── Datos que recibe la vista ─────────────────────────────────

class KpiMovil {
  final String    etiqueta;
  final String    valor;
  final String?   sufijo;
  final String    detalle;
  final IconData  icono;
  final TonoMovil tono;
  final bool      detalleDestacado;

  const KpiMovil({
    required this.etiqueta,
    required this.valor,
    required this.detalle,
    required this.icono,
    required this.tono,
    this.sufijo,
    this.detalleDestacado = false,
  });
}

class AccionMovil {
  final String       etiqueta;
  final IconData     icono;
  final TonoMovil    tono;
  final VoidCallback onTap;

  const AccionMovil({
    required this.etiqueta,
    required this.icono,
    required this.tono,
    required this.onTap,
  });
}

class TiendaMovil {
  final int?   id;
  final String nombre;
  const TiendaMovil(this.id, this.nombre);
}

// ── Formatos ──────────────────────────────────────────────────

/// $1.863.000 → "1.86M", $45.000 → "45K".
String formatoCompacto(double v) {
  final a = v.abs();
  if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
  if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(a >= 1e8 ? 0 : a >= 1e7 ? 1 : 2)}M';
  if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

String _miles(double v) => v
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

String _cant(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// ── Tipografía ────────────────────────────────────────────────

TextStyle _f({
  double size = 13,
  FontWeight w = FontWeight.w400,
  Color color = _C.tinta,
  double? ls,
  double? h,
}) {
  final fuente = InventarioMovil.fuenteDePrueba;
  if (fuente != null) {
    return TextStyle(
        fontFamily: fuente, fontSize: size, fontWeight: w,
        color: color, letterSpacing: ls, height: h);
  }
  return GoogleFonts.inter(
      fontSize: size, fontWeight: w, color: color,
      letterSpacing: ls, height: h);
}

TextStyle _seccion() =>
    _f(size: 11.5, w: FontWeight.w800, color: _C.turq, ls: 1.1);

// ── Estado del stock ──────────────────────────────────────────

enum _Estado { optimo, bajo, agotado, inactivo }

_Estado _estadoDe(Producto p) {
  if (!p.activo) return _Estado.inactivo;
  if (p.stockActual <= 0) return _Estado.agotado;
  // La misma regla del servidor (filtro "Stock bajo", Exportar, Análisis):
  // bajo si no pasa del mínimo. Sin mínimo configurado no hay alerta.
  if (p.stockMinimo > 0 && p.stockActual <= p.stockMinimo) return _Estado.bajo;
  return _Estado.optimo;
}

(String, Color, IconData) _estadoUi(_Estado e) => switch (e) {
      _Estado.optimo   => ('Óptimo',     _C.verde, Icons.trending_up_rounded),
      _Estado.bajo     => ('Stock bajo', _C.ambar, Icons.warning_amber_rounded),
      _Estado.agotado  => ('Agotado',    _C.rojo,  Icons.cancel_rounded),
      _Estado.inactivo => ('Inactivo',   _C.gris,  Icons.block_rounded),
    };

/// Cada categoría queda siempre del mismo color, alternando los tres
/// verdes análogos.
TonoMovil _tonoCategoria(String categoria) {
  var h = 0;
  for (final c in categoria.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return const [TonoMovil.verde, TonoMovil.turquesa, TonoMovil.lima][h % 3];
}

String _inicial(String s) {
  final t = s.trim();
  return t.isEmpty ? '?' : t[0].toUpperCase();
}

// ══════════════════════════════════════════════════════════════
// VISTA PRINCIPAL
// ══════════════════════════════════════════════════════════════

class InventarioMovil extends StatefulWidget {
  /// Solo para pruebas de render: ahí no hay red para descargar Inter, y
  /// con esto se usa una fuente cargada localmente. En la app queda null.
  /// También la usa producto_form_dialog en su versión móvil.
  static String? fuenteDePrueba;

  final String             subtitulo;
  final List<TiendaMovil>  tiendas;
  final int?               tiendaSeleccionada;
  final ValueChanged<int?>? onTienda;

  final List<KpiMovil>     kpis;

  final int                agotados;
  final int                bajos;
  final VoidCallback?      onAlerta;

  final TextEditingController buscar;
  final ValueChanged<String>  onBuscar;
  final int                filtrosActivos;
  final VoidCallback       onFiltros;
  /// Filtros aplicados, a la vista sobre la lista; cada uno se quita solo.
  final List<FiltroActivoMovil> filtrosAplicados;
  final VoidCallback?      onLimpiarFiltros;
  /// Cómo está ordenada la lista, si no es por nombre ("menos stock").
  final String?            ordenTexto;
  final VoidCallback       onEscanear;

  final String             estado; // 'true' | 'false' | 'all'
  final ValueChanged<String> onEstado;

  final List<Producto>     productos;
  final bool               cargando;
  final ValueChanged<Producto> onProducto;

  final VoidCallback?      onInsights;
  final IconData           iconoInsights;
  final List<AccionMovil>  accionesFab;
  final List<AccionMovil>  accionesMas;

  final Widget?            aviso;
  final Future<void> Function()? onRefrescar;

  const InventarioMovil({
    super.key,
    required this.subtitulo,
    this.tiendas = const [],
    this.tiendaSeleccionada,
    this.onTienda,
    required this.kpis,
    this.agotados = 0,
    this.bajos = 0,
    this.onAlerta,
    required this.buscar,
    required this.onBuscar,
    this.filtrosActivos = 0,
    required this.onFiltros,
    this.filtrosAplicados = const [],
    this.onLimpiarFiltros,
    this.ordenTexto,
    required this.onEscanear,
    required this.estado,
    required this.onEstado,
    required this.productos,
    this.cargando = false,
    required this.onProducto,
    this.onInsights,
    this.iconoInsights = Icons.insights_rounded,
    this.accionesFab = const [],
    this.accionesMas = const [],
    this.aviso,
    this.onRefrescar,
  });

  @override
  State<InventarioMovil> createState() => _InventarioMovilState();
}

class _InventarioMovilState extends State<InventarioMovil> {
  final _kpiCtrl = PageController(viewportFraction: 0.76);
  int  _kpiPage  = 0;
  bool _fabAbierto = false;

  @override
  void dispose() {
    _kpiCtrl.dispose();
    super.dispose();
  }

  void _cerrarFab() {
    if (_fabAbierto) setState(() => _fabAbierto = false);
  }

  @override
  Widget build(BuildContext context) {
    final lista = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _cabecera()),
        if (widget.kpis.isNotEmpty) SliverToBoxAdapter(child: _kpis()),
        if (widget.agotados + widget.bajos > 0)
          SliverToBoxAdapter(child: _alerta()),
        SliverToBoxAdapter(child: _buscador()),
        SliverToBoxAdapter(child: _estados()),
        if (widget.filtrosAplicados.isNotEmpty)
          SliverToBoxAdapter(child: _chipsFiltros()),
        if (widget.aviso != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: widget.aviso,
            ),
          ),
        SliverToBoxAdapter(child: _tituloLista()),
        _listaProductos(),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );

    return ColoredBox(
      color: _C.fondo,
      child: Stack(children: [
        widget.onRefrescar != null
            ? RefreshIndicator(
                color: _C.verde,
                onRefresh: widget.onRefrescar!,
                child: lista,
              )
            : lista,
        if (_fabAbierto)
          Positioned.fill(
            child: GestureDetector(
              onTap: _cerrarFab,
              child: const ColoredBox(color: Color(0x33000000)),
            ),
          ),
        if (widget.accionesFab.isNotEmpty)
          Positioned(right: 16, bottom: 16, child: _fab()),
      ]),
    );
  }

  // ── Cabecera: tienda ────────────────────────────────────────
  Widget _cabecera() {
    if (widget.tiendas.length > 1) {
      return SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
          itemCount: widget.tiendas.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final t   = widget.tiendas[i];
            final sel = t.id == widget.tiendaSeleccionada;
            return GestureDetector(
              onTap: sel ? null : () => widget.onTienda?.call(t.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? _C.verde : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _C.verde : _C.borde),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.id == null
                          ? Icons.all_inclusive_rounded
                          : Icons.storefront_rounded,
                      size: 15, color: sel ? Colors.white : _C.gris),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(t.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(
                            size: 12,
                            w: sel ? FontWeight.w700 : FontWeight.w600,
                            color: sel ? Colors.white : _C.gris)),
                  ),
                ]),
              ),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        const Icon(Icons.storefront_rounded, size: 16, color: _C.turq),
        const SizedBox(width: 6),
        Expanded(
          child: Text(widget.subtitulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _f(size: 12.5, w: FontWeight.w600, color: _C.gris)),
        ),
      ]),
    );
  }

  // ── KPIs en carrusel ────────────────────────────────────────
  Widget _kpis() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('MÉTRICAS CLAVE', style: _seccion()),
            const Spacer(),
            if (widget.onInsights != null)
              _botonIcono(widget.iconoInsights, TonoMovil.turquesa,
                  widget.onInsights!),
            if (widget.accionesMas.isNotEmpty) ...[
              const SizedBox(width: 8),
              _botonIcono(Icons.more_horiz_rounded, TonoMovil.gris, () {
                mostrarAccionesMovil(context,
                    titulo: 'Más opciones',
                    subtitulo: 'Inventario',
                    acciones: widget.accionesMas);
              }),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _kpiCtrl,
            padEnds: false,
            itemCount: widget.kpis.length,
            onPageChanged: (i) => setState(() => _kpiPage = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(
                  left: 16, right: i == widget.kpis.length - 1 ? 16 : 0),
              child: _kpiCard(widget.kpis[i]),
            ),
          ),
        ),
        if (widget.kpis.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.kpis.length, (i) {
              final on = i == _kpiPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: on ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: on ? _C.verde : _C.borde,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ]),
    );
  }

  Widget _kpiCard(KpiMovil k) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.borde),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D059669), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 4, color: k.tono.fuerte),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: k.tono.medio,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(k.icono, size: 19, color: k.tono.fuerte),
                ),
                const Spacer(),
                Text(k.etiqueta.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _f(
                        size: 10.5,
                        w: FontWeight.w700,
                        color: _C.gris,
                        ls: 0.4)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: k.valor,
                          style: _f(size: 25, w: FontWeight.w800, h: 1.15)),
                      if (k.sufijo != null)
                        TextSpan(
                            text: ' ${k.sufijo}',
                            style: _f(
                                size: 13, w: FontWeight.w700, color: _C.gris)),
                    ]),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(k.detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _f(
                        size: 11.5,
                        w: k.detalleDestacado
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: k.detalleDestacado ? k.tono.fuerte : _C.gris)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Banner de alertas ───────────────────────────────────────
  Widget _alerta() {
    final hayAgotados = widget.agotados > 0;
    final tono = hayAgotados ? TonoMovil.rojo : TonoMovil.ambar;
    final titulo = hayAgotados
        ? '${widget.agotados} producto${widget.agotados == 1 ? '' : 's'} agotado${widget.agotados == 1 ? '' : 's'}'
        : '${widget.bajos} con stock bajo';
    final sub = hayAgotados && widget.bajos > 0
        ? '${widget.bajos} más con stock bajo · Toca para ver'
        : 'Toca para ver';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: tono.suave,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onAlerta,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tono.medio),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: tono.medio, shape: BoxShape.circle),
                child: Icon(Icons.notifications_active_rounded,
                    size: 19, color: tono.fuerte),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(
                            size: 13,
                            w: FontWeight.w700,
                            color: tono.fuerte)),
                    const SizedBox(height: 1),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(size: 11.5, color: _C.gris)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: tono.fuerte),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Buscador + escáner + filtros ────────────────────────────
  Widget _buscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: TextField(
              controller: widget.buscar,
              onChanged: widget.onBuscar,
              textInputAction: TextInputAction.search,
              style: _f(size: 13.5),
              decoration: InputDecoration(
                hintText: 'Buscar producto o código…',
                hintStyle: _f(size: 13, color: _C.gris),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: _C.gris),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.borde)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.borde)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _C.verde, width: 1.5)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _botonCuadrado(
            Icons.qr_code_scanner_rounded, _C.turq, widget.onEscanear),
        const SizedBox(width: 8),
        Stack(clipBehavior: Clip.none, children: [
          _botonCuadrado(Icons.tune_rounded, _C.tinta, widget.onFiltros),
          if (widget.filtrosActivos > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _C.verde,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.fondo, width: 2),
                ),
                child: Text('${widget.filtrosActivos}',
                    style: _f(
                        size: 9.5,
                        w: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
        ]),
      ]),
    );
  }

  // ── Activos / Inactivos / Todos ─────────────────────────────
  Widget _estados() {
    const ops = [
      ('true',  'Activos',   Icons.check_circle_rounded),
      ('false', 'Inactivos', Icons.do_not_disturb_on_rounded),
      ('all',   'Todos',     Icons.all_inclusive_rounded),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: ops.map((o) {
          final sel = widget.estado == o.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: sel ? null : () => widget.onEstado(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _C.verde : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _C.verde : _C.borde),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(o.$3, size: 15, color: sel ? Colors.white : _C.gris),
                  const SizedBox(width: 5),
                  Text(o.$2,
                      style: _f(
                          size: 12,
                          w: sel ? FontWeight.w700 : FontWeight.w600,
                          color: sel ? Colors.white : _C.gris)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tituloLista() {
    final n = widget.productos.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(children: [
        Text('PRODUCTOS', style: _seccion()),
        const Spacer(),
        if (!widget.cargando || n > 0)
          Flexible(
            child: Text(
                [
                  '$n resultado${n == 1 ? '' : 's'}',
                  ?widget.ordenTexto,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _f(size: 11.5, color: _C.gris)),
          ),
      ]),
    );
  }

  // ── Filtros aplicados ───────────────────────────────────────
  Widget _chipsFiltros() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final f in widget.filtrosAplicados)
            Material(
              color: _C.verde50,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: f.quitar,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.verde100),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(f.etiqueta,
                        style: _f(size: 11.5, w: FontWeight.w700,
                            color: _C.verdeOs)),
                    const SizedBox(width: 3),
                    const Icon(Icons.close_rounded,
                        size: 14, color: _C.verdeOs),
                  ]),
                ),
              ),
            ),
          if (widget.onLimpiarFiltros != null &&
              widget.filtrosAplicados.length > 1)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onLimpiarFiltros,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Text('Limpiar',
                    style: _f(size: 11.5, w: FontWeight.w800,
                        color: _C.rojo)),
              ),
            ),
        ]),
      );

  // ── Lista ───────────────────────────────────────────────────
  Widget _listaProductos() {
    if (widget.cargando && widget.productos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _C.verde),
            ),
          ),
        ),
      );
    }
    if (widget.productos.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 36, 32, 0),
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  color: _C.verde100, shape: BoxShape.circle),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 26, color: _C.verde),
            ),
            const SizedBox(height: 12),
            Text('Sin productos',
                style: _f(size: 14, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                widget.filtrosActivos > 0 || widget.buscar.text.isNotEmpty
                    ? 'Prueba quitar filtros o cambiar la búsqueda'
                    : 'Agrega productos con el botón +',
                textAlign: TextAlign.center,
                style: _f(size: 12, color: _C.gris)),
          ]),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _tarjetaProducto(widget.productos[i]),
          ),
          childCount: widget.productos.length,
        ),
      ),
    );
  }

  Widget _tarjetaProducto(Producto p) {
    final tono = _tonoCategoria(p.categoria);
    final (estadoTxt, estadoColor, estadoIcono) = _estadoUi(_estadoDe(p));
    final unidad =
        p.unidadMedida == 'unidad' || p.unidadMedida.isEmpty ? 'uds' : p.unidadMedida;

    return Opacity(
      opacity: p.activo ? 1 : 0.62,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onProducto(p),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.borde),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tono.medio,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_inicial(p.nombre),
                    style: _f(
                        size: 17, w: FontWeight.w800, color: tono.oscuro)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(size: 13.5, w: FontWeight.w700, h: 1.2)),
                    if (p.referencia.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Cód. ${p.referencia}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _f(size: 10.5, color: _C.gris)),
                    ],
                    if (p.categoria.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _chip(p.categoria, tono),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${Constants.moneda}${_miles(p.precio)}',
                      style: _f(size: 14.5, w: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(estadoIcono, size: 14, color: estadoColor),
                    const SizedBox(width: 3),
                    Text('${_cant(p.stockActual)} $unidad',
                        style: _f(
                            size: 12,
                            w: FontWeight.w700,
                            color: estadoColor)),
                  ]),
                  Text(estadoTxt,
                      style: _f(
                          size: 10, w: FontWeight.w600, color: estadoColor)),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Botón flotante con menú ─────────────────────────────────
  Widget _fab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabAbierto)
          ...widget.accionesFab.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      _cerrarFab();
                      a.onTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(a.etiqueta,
                            style: _f(size: 12.5, w: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: a.tono.medio,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child:
                              Icon(a.icono, size: 17, color: a.tono.fuerte),
                        ),
                      ]),
                    ),
                  ),
                ),
              )),
        Material(
          color: _C.verde,
          elevation: 6,
          shadowColor: const Color(0x66059669),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _fabAbierto = !_fabAbierto),
            child: SizedBox(
              width: 56,
              height: 56,
              child: AnimatedRotation(
                turns: _fabAbierto ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add_rounded,
                    size: 28, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Piezas ──────────────────────────────────────────────────
  Widget _botonIcono(IconData icono, TonoMovil tono, VoidCallback onTap) {
    return Material(
      color: tono == TonoMovil.gris ? Colors.white : tono.suave,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: tono == TonoMovil.gris ? _C.borde : tono.medio),
          ),
          child: Icon(icono, size: 18, color: tono.fuerte),
        ),
      ),
    );
  }

  Widget _botonCuadrado(IconData icono, Color fondo, VoidCallback onTap) {
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icono, size: 21, color: Colors.white),
        ),
      ),
    );
  }
}

Widget _chip(String texto, TonoMovil tono) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tono.medio,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _f(size: 10, w: FontWeight.w700, color: tono.oscuro)),
    );

// ══════════════════════════════════════════════════════════════
// HOJAS
// ══════════════════════════════════════════════════════════════

Future<void> _hoja(BuildContext context, Widget Function(BuildContext) cuerpo) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: _C.grisClaro,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              child: cuerpo(ctx),
            ),
          ),
        ]),
      ),
    ),
  );
}

/// Detalle de un producto con sus acciones. Solo se muestran las acciones
/// que llegan en [acciones]: el que llama decide según el rol.
Future<void> mostrarDetalleProductoMovil(
  BuildContext context, {
  required Producto producto,
  required List<AccionMovil> acciones,
}) {
  final p    = producto;
  final tono = _tonoCategoria(p.categoria);
  final (estadoTxt, estadoColor, _) = _estadoUi(_estadoDe(p));
  final margen = p.precioCompra > 0
      ? '+${((p.precio - p.precioCompra) / p.precioCompra * 100).toStringAsFixed(1)}%'
      : '—';

  return _hoja(context, (ctx) {
    Widget dato(String label, String valor, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _C.fondo,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.borde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: _f(
                        size: 9.5,
                        w: FontWeight.w700,
                        color: _C.gris,
                        ls: 0.4)),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(valor,
                      style: _f(size: 14, w: FontWeight.w800, color: color)),
                ),
              ],
            ),
          ),
        );

    Widget stock(String label, String valor, TonoMovil t) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: t.suave,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.medio),
            ),
            child: Column(children: [
              Text(valor,
                  style: _f(size: 20, w: FontWeight.w800, color: t.oscuro)),
              Text(label.toUpperCase(),
                  style: _f(
                      size: 9.5,
                      w: FontWeight.w700,
                      color: t.fuerte,
                      ls: 0.4)),
            ]),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tono.medio,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(_inicial(p.nombre),
                style: _f(size: 22, w: FontWeight.w800, color: tono.oscuro)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _f(size: 16, w: FontWeight.w800, h: 1.2)),
                if (p.referencia.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Cód. ${p.referencia}',
                      style: _f(size: 11, color: _C.gris)),
                ],
                const SizedBox(height: 5),
                Row(children: [
                  if (p.categoria.isNotEmpty) ...[
                    Flexible(child: _chip(p.categoria, tono)),
                    const SizedBox(width: 8),
                  ],
                  Text(estadoTxt,
                      style: _f(
                          size: 11, w: FontWeight.w700, color: estadoColor)),
                ]),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          dato('Costo', '${Constants.moneda}${_miles(p.precioCompra)}',
              _C.gris),
          const SizedBox(width: 8),
          dato('Precio', '${Constants.moneda}${_miles(p.precio)}', _C.tinta),
          const SizedBox(width: 8),
          dato('Margen', margen, _C.verde),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          stock('En stock', _cant(p.stockActual), TonoMovil.verde),
          const SizedBox(width: 8),
          stock('Mínimo', _cant(p.stockMinimo), TonoMovil.turquesa),
          const SizedBox(width: 8),
          stock('Máximo', p.stockMaximo > 0 ? _cant(p.stockMaximo) : '—',
              TonoMovil.lima),
        ]),
        if (acciones.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('ACCIONES', style: _seccion()),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (_, c) {
            final ancho = (c.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: acciones
                  .map((a) => SizedBox(
                        width: ancho,
                        child: _tileAccion(ctx, a),
                      ))
                  .toList(),
            );
          }),
        ],
      ],
    );
  });
}

Widget _tileAccion(BuildContext ctx, AccionMovil a) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(ctx);
          a.onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.borde),
          ),
          child: Column(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: a.tono.suave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(a.icono, size: 19, color: a.tono.fuerte),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(a.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _f(size: 11, w: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );

/// Lista de acciones en una hoja (el menú "Más").
Future<void> mostrarAccionesMovil(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  required List<AccionMovil> acciones,
}) {
  return _hoja(context, (ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: _f(size: 17, w: FontWeight.w800)),
        if (subtitulo != null)
          Text(subtitulo, style: _f(size: 12, color: _C.gris)),
        const SizedBox(height: 14),
        ...acciones.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(ctx);
                    a.onTap();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.borde),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: a.tono.suave,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(a.icono, size: 19, color: a.tono.fuerte),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(a.etiqueta,
                            style: _f(size: 13.5, w: FontWeight.w600)),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 20, color: _C.grisClaro),
                    ]),
                  ),
                ),
              ),
            )),
      ],
    );
  });
}

/// Envuelve un panel existente (insights, panel del cajero) en una hoja.
Future<void> mostrarPanelMovil(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  required Widget Function() panel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.sizeOf(ctx).height * 0.86,
      decoration: const BoxDecoration(
        color: _C.fondo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: _C.grisClaro,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: _f(size: 18, w: FontWeight.w800)),
                    if (subtitulo != null && subtitulo.isNotEmpty)
                      Text(subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _f(size: 11.5, color: _C.gris)),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: panel(),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// ANÁLISIS (alertas de stock, más vendidos, movimientos)
// ══════════════════════════════════════════════════════════════

class AlertaStockMovil {
  final String nombre;
  final String categoria;
  final double stock;
  final double minimo;
  const AlertaStockMovil({
    required this.nombre,
    required this.categoria,
    required this.stock,
    required this.minimo,
  });
}

class VendidoMovil {
  final String nombre;
  final String categoria;
  final double unidades;
  final double ingresos;
  const VendidoMovil({
    required this.nombre,
    required this.categoria,
    required this.unidades,
    required this.ingresos,
  });
}

class MovimientoMovil {
  final String    producto;
  final String    tipo; // entrada | salida | ajuste | transferencia | dano
  final double    cantidad;
  final DateTime? fecha;
  final String    empleado;
  final String    detalle;
  final VoidCallback? onTap;
  const MovimientoMovil({
    required this.producto,
    required this.tipo,
    required this.cantidad,
    this.fecha,
    this.empleado = '',
    this.detalle = '',
    this.onTap,
  });
}

class AnalisisMovil extends StatefulWidget {
  final List<AlertaStockMovil> agotados;
  final List<AlertaStockMovil> bajos;
  final List<VendidoMovil>     vendidos;
  final List<MovimientoMovil>  movimientos;
  final bool                   cargando;

  /// 'agotado' o 'bajo': filtra la lista principal con esa alerta.
  final ValueChanged<String>?  onVerAlertas;

  /// Para fijar "hoy" en las pruebas; en la app es la hora real.
  final DateTime? ahora;

  const AnalisisMovil({
    super.key,
    this.agotados = const [],
    this.bajos = const [],
    this.vendidos = const [],
    this.movimientos = const [],
    this.cargando = false,
    this.onVerAlertas,
    this.ahora,
  });

  @override
  State<AnalisisMovil> createState() => _AnalisisMovilState();
}

class _AnalisisMovilState extends State<AnalisisMovil> {
  late bool _verAgotados = widget.agotados.isNotEmpty || widget.bajos.isEmpty;

  static const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
                         'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  @override
  Widget build(BuildContext context) {
    if (widget.cargando &&
        widget.vendidos.isEmpty &&
        widget.movimientos.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _C.verde),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _tarjetaAlertas(),
        const SizedBox(height: 12),
        _tarjetaVendidos(),
        const SizedBox(height: 12),
        _tarjetaMovimientos(),
      ],
    );
  }

  // ── Estructura común de las tarjetas ────────────────────────
  Widget _tarjeta({
    required TonoMovil tono,
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required List<Widget> hijos,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 4, color: tono.fuerte),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tono.medio,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, size: 19, color: tono.fuerte),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: _f(size: 14, w: FontWeight.w700)),
                      Text(subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _f(size: 11, color: _C.gris)),
                    ],
                  ),
                ),
              ]),
              ...hijos,
            ],
          ),
        ),
      ]),
    );
  }

  // ── Alertas de stock ────────────────────────────────────────
  Widget _tarjetaAlertas() {
    final total = widget.agotados.length + widget.bajos.length;
    if (total == 0) {
      return _tarjeta(
        tono: TonoMovil.verde,
        icono: Icons.check_circle_rounded,
        titulo: 'Alertas de stock',
        subtitulo: 'Todo en orden',
        hijos: [
          const SizedBox(height: 10),
          Text('No hay productos agotados ni con stock bajo.',
              style: _f(size: 12, color: _C.gris)),
        ],
      );
    }

    final lista = _verAgotados ? widget.agotados : widget.bajos;
    final tono  = _verAgotados ? TonoMovil.rojo : TonoMovil.ambar;
    final resto = lista.length - 4;

    Widget pestana(String texto, bool activa, TonoMovil t, VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: activa ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activa ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: activa
                    ? const [
                        BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 4,
                            offset: Offset(0, 1)),
                      ]
                    : null,
              ),
              child: Text(texto,
                  style: _f(
                      size: 12,
                      w: activa ? FontWeight.w700 : FontWeight.w600,
                      color: activa ? t.fuerte : _C.gris)),
            ),
          ),
        );

    return _tarjeta(
      tono: TonoMovil.rojo,
      icono: Icons.notifications_active_rounded,
      titulo: 'Alertas de stock',
      subtitulo:
          '$total producto${total == 1 ? '' : 's'} necesita${total == 1 ? '' : 'n'} atención',
      hijos: [
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _C.fondo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.borde),
          ),
          child: Row(children: [
            pestana('Agotados · ${widget.agotados.length}', _verAgotados,
                TonoMovil.rojo, () => setState(() => _verAgotados = true)),
            const SizedBox(width: 4),
            pestana('Stock bajo · ${widget.bajos.length}', !_verAgotados,
                TonoMovil.ambar, () => setState(() => _verAgotados = false)),
          ]),
        ),
        const SizedBox(height: 4),
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
                _verAgotados
                    ? 'No hay productos agotados.'
                    : 'No hay productos con stock bajo.',
                style: _f(size: 12, color: _C.gris)),
          )
        else
          ...lista.take(4).map((a) => _filaAlerta(a, tono)),
        if (resto > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('+$resto más',
                style: _f(size: 11, color: _C.gris)),
          ),
        if (lista.isNotEmpty && widget.onVerAlertas != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onVerAlertas!(_verAgotados ? 'agotado' : 'bajo');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _C.borde),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Ver los ${lista.length} en la lista',
                    style: _f(size: 12.5, w: FontWeight.w700)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: _C.tinta),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _filaAlerta(AlertaStockMovil a, TonoMovil tono) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borde)),
      ),
      child: Row(children: [
        Container(
          width: 5,
          height: 32,
          decoration: BoxDecoration(
            color: tono.fuerte,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _f(size: 12.5, w: FontWeight.w700)),
              Text(a.categoria.isEmpty ? 'Sin categoría' : a.categoria,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _f(size: 10.5, color: _C.gris)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (tono == TonoMovil.rojo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _C.rojo50,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _C.rojo100),
            ),
            child: Text('${_cant(a.stock)} uds',
                style: _f(size: 11, w: FontWeight.w700, color: _C.rojo)),
          )
        else
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_cant(a.stock)} uds',
                style: _f(size: 12, w: FontWeight.w800, color: _C.ambar)),
            if (a.minimo > 0)
              Text('mín. ${_cant(a.minimo)}',
                  style: _f(size: 9.5, color: _C.gris)),
          ]),
      ]),
    );
  }

  // ── Más vendidos ────────────────────────────────────────────
  Widget _tarjetaVendidos() {
    final v = widget.vendidos;
    final maximo = v.fold<double>(0, (m, e) => e.ingresos > m ? e.ingresos : m);

    return _tarjeta(
      tono: TonoMovil.verde,
      icono: Icons.emoji_events_rounded,
      titulo: 'Más vendidos',
      subtitulo: 'Ordenados por plata vendida',
      hijos: [
        const SizedBox(height: 12),
        if (v.isEmpty)
          Text('Todavía no hay ventas registradas.',
              style: _f(size: 12, color: _C.gris))
        else
          ...List.generate(v.length, (i) {
            final p = v[i];
            final pct = maximo > 0 ? (p.ingresos / maximo).clamp(0.0, 1.0) : 0.0;
            final (fondo, letra, borde) = switch (i) {
              0 => (_C.verde, Colors.white, _C.verde),
              1 || 2 => (_C.verde100, _C.verdeOs, _C.verde100),
              _ => (_C.fondo, _C.gris, _C.borde),
            };
            return Padding(
              padding: EdgeInsets.only(bottom: i == v.length - 1 ? 0 : 12),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fondo,
                    shape: BoxShape.circle,
                    border: Border.all(color: borde),
                  ),
                  child: Text('${i + 1}',
                      style: _f(size: 11.5, w: FontWeight.w800, color: letra)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(p.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _f(size: 12.5, w: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Text('${Constants.moneda}${formatoCompacto(p.ingresos)}',
                            style: _f(size: 12.5, w: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          minHeight: 6,
                          backgroundColor: _C.fondo,
                          valueColor: AlwaysStoppedAnimation(
                              i == 0 ? _C.verde : _C.turq),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          [
                            '${_cant(p.unidades)} uds',
                            if (p.categoria.isNotEmpty) p.categoria,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _f(size: 10.5, color: _C.gris)),
                    ],
                  ),
                ),
              ]),
            );
          }),
      ],
    );
  }

  // ── Movimientos recientes ───────────────────────────────────
  String _dia(DateTime? f) {
    if (f == null) return 'Sin fecha';
    final hoy = widget.ahora ?? DateTime.now();
    final d0  = DateTime(hoy.year, hoy.month, hoy.day);
    final d   = DateTime(f.year, f.month, f.day);
    final dif = d0.difference(d).inDays;
    if (dif == 0) return 'Hoy';
    if (dif == 1) return 'Ayer';
    final base = '${f.day} ${_meses[f.month]}';
    return f.year == hoy.year ? base : '$base ${f.year}';
  }

  (TonoMovil, IconData, String) _tipoUi(MovimientoMovil m) =>
      switch (m.tipo) {
        'entrada'       => (TonoMovil.verde, Icons.south_west_rounded, '+'),
        'salida'        => (TonoMovil.rojo, Icons.north_east_rounded, '−'),
        'dano'          => (TonoMovil.rojo, Icons.report_rounded, '−'),
        'transferencia' => (TonoMovil.turquesa, Icons.swap_horiz_rounded, ''),
        _ => (TonoMovil.ambar, Icons.tune_rounded,
              m.cantidad < 0 ? '−' : '+'),
      };

  static String _etiquetaTipo(String t) => switch (t) {
        'entrada'       => 'Entrada',
        'salida'        => 'Salida',
        'ajuste'        => 'Ajuste',
        'transferencia' => 'Transferencia',
        'dano'          => 'Daño / pérdida',
        _               => t,
      };

  Widget _tarjetaMovimientos() {
    final hijos = <Widget>[];
    String? diaActual;
    for (final m in widget.movimientos) {
      final dia = _dia(m.fecha);
      if (dia != diaActual) {
        diaActual = dia;
        hijos.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text(dia.toUpperCase(),
              style: _f(
                  size: 10.5, w: FontWeight.w700, color: _C.gris, ls: 0.6)),
        ));
      }
      hijos.add(_filaMovimiento(m));
    }

    return _tarjeta(
      tono: TonoMovil.turquesa,
      icono: Icons.history_rounded,
      titulo: 'Movimientos recientes',
      subtitulo: 'Entradas, salidas y ajustes',
      hijos: widget.movimientos.isEmpty
          ? [
              const SizedBox(height: 10),
              Text('Sin movimientos recientes.',
                  style: _f(size: 12, color: _C.gris)),
            ]
          : hijos,
    );
  }

  Widget _filaMovimiento(MovimientoMovil m) {
    final (tono, icono, signo) = _tipoUi(m);
    final hora = m.fecha == null
        ? ''
        : '${m.fecha!.hour.toString().padLeft(2, '0')}:${m.fecha!.minute.toString().padLeft(2, '0')}';
    final linea = [
      m.detalle.isNotEmpty ? m.detalle : _etiquetaTipo(m.tipo),
      if (m.empleado.isNotEmpty) m.empleado,
      if (hora.isNotEmpty) hora,
    ].join(' · ');

    return InkWell(
      onTap: m.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _C.borde)),
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tono.suave,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icono, size: 17, color: tono.fuerte),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.producto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _f(size: 12.5, w: FontWeight.w700)),
                Text(linea,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _f(size: 10.5, color: _C.gris)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$signo${_cant(m.cantidad.abs())} uds',
              style: _f(size: 12.5, w: FontWeight.w800, color: tono.fuerte)),
          if (m.onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: _C.grisClaro),
            ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AVERÍAS (gestionar unidades dañadas)
// ══════════════════════════════════════════════════════════════

class AveriaMovil {
  final String nombre;
  final String categoria;
  final double unidades;

  /// El dato original, para que quien llama sepa a qué producto se refiere.
  final Object? ref;

  const AveriaMovil({
    required this.nombre,
    required this.categoria,
    required this.unidades,
    this.ref,
  });
}

class HistorialAveriaMovil {
  final double    cantidad;
  final DateTime? fecha;
  final String    empleado;
  final String    observacion;
  const HistorialAveriaMovil({
    required this.cantidad,
    this.fecha,
    this.empleado = '',
    this.observacion = '',
  });
}

/// Pantalla de averías para celular.
///
/// [onAccion] recibe 'recuperar' o 'descartar' y la cantidad; devuelve null
/// si salió bien o el mensaje de error para mostrarlo.
class AveriasMovil extends StatefulWidget {
  final String                 tienda;
  final List<AveriaMovil>      items;
  final bool                   cargando;
  final String?                error;
  final VoidCallback?          onReintentar;
  final Future<String?> Function(AveriaMovil, String accion, double cantidad)
                               onAccion;
  final Future<List<HistorialAveriaMovil>> Function(AveriaMovil)? onHistorial;

  const AveriasMovil({
    super.key,
    required this.tienda,
    required this.items,
    required this.onAccion,
    this.cargando = false,
    this.error,
    this.onReintentar,
    this.onHistorial,
  });

  @override
  State<AveriasMovil> createState() => _AveriasMovilState();
}

class _AveriasMovilState extends State<AveriasMovil> {
  int?    _abierto;              // índice con el formulario abierto
  String  _accion = 'recuperar';
  final   _cant = TextEditingController();
  bool    _procesando = false;
  String? _errorAccion;
  String? _aviso;                // mensaje de éxito

  @override
  void dispose() {
    _cant.dispose();
    super.dispose();
  }

  void _abrir(int i, String accion) => setState(() {
        _abierto = i;
        _accion = accion;
        _cant.clear();
        _errorAccion = null;
        _aviso = null;
      });

  void _cerrar() => setState(() {
        _abierto = null;
        _errorAccion = null;
        _cant.clear();
      });

  double? get _cantidad =>
      double.tryParse(_cant.text.trim().replaceAll(',', '.'));

  void _sumar(double delta, double maximo) {
    final actual = _cantidad ?? 0;
    final nuevo = (actual + delta).clamp(0, maximo).toDouble();
    setState(() => _cant.text = nuevo == 0 ? '' : _cant2(nuevo));
  }

  static String _cant2(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _confirmar(AveriaMovil item) async {
    final c = _cantidad;
    if (c == null || c <= 0) {
      setState(() => _errorAccion = 'Escribe cuántas unidades.');
      return;
    }
    if (c > item.unidades) {
      setState(() => _errorAccion =
          'Solo hay ${_cant2(item.unidades)} en averías.');
      return;
    }
    setState(() {
      _procesando = true;
      _errorAccion = null;
    });
    final accion = _accion;
    final err = await widget.onAccion(item, accion, c);
    if (!mounted) return;
    setState(() {
      _procesando = false;
      if (err == null) {
        _abierto = null;
        _cant.clear();
        final u = '${_cant2(c)} ud${c == 1 ? '' : 's'}';
        _aviso = accion == 'recuperar'
            ? '$u de ${item.nombre} volvieron al stock'
            : '$u de ${item.nombre} dadas de baja';
      } else {
        _errorAccion = err;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalUds = widget.items.fold<double>(0, (t, e) => t + e.unidades);

    return Column(children: [
      // Encabezado
      Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 16, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.borde)),
            ),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close_rounded, color: _C.tinta),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Averías', style: _f(size: 18, w: FontWeight.w800)),
                    Text(widget.tienda,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(size: 12, color: _C.gris)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),

      Expanded(child: _cuerpo(totalUds)),
    ]);
  }

  Widget _cuerpo(double totalUds) {
    if (widget.cargando && widget.items.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _C.verde),
        ),
      );
    }
    if (widget.error != null && widget.items.isEmpty) {
      return _mensaje(
        icono: Icons.cloud_off_rounded,
        tono: TonoMovil.rojo,
        titulo: 'No se pudieron cargar las averías',
        texto: widget.error!,
        boton: widget.onReintentar == null
            ? null
            : TextButton(
                onPressed: widget.onReintentar,
                child: Text('Reintentar',
                    style: _f(size: 13, w: FontWeight.w700, color: _C.verde)),
              ),
      );
    }
    if (widget.items.isEmpty) {
      return _mensaje(
        icono: Icons.check_circle_rounded,
        tono: TonoMovil.verde,
        titulo: 'Sin averías',
        texto: 'Ningún producto tiene unidades en averías.',
        pie: true,
      );
    }

    final n = widget.items.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Resumen
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.borde),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 4, color: _C.ambar),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _C.ambar100,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      size: 21, color: _C.ambar),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${_cant2(totalUds)} unidad${totalUds == 1 ? '' : 'es'} en averías',
                          style: _f(size: 14, w: FontWeight.w800)),
                      Text('$n producto${n == 1 ? '' : 's'} afectado${n == 1 ? '' : 's'}',
                          style: _f(size: 11.5, color: _C.gris)),
                    ],
                  ),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        _pista(),
        if (_aviso != null) ...[
          const SizedBox(height: 10),
          _avisoExito(_aviso!),
        ],
        const SizedBox(height: 14),
        Text('PRODUCTOS', style: _seccion()),
        const SizedBox(height: 8),
        ...List.generate(n, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _tarjeta(i, widget.items[i]),
            )),
      ],
    );
  }

  Widget _pista() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.lightbulb_outline_rounded, size: 15, color: _C.gris),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
              'Para reportar una avería nueva, entra al producto y toca «Avería».',
              style: _f(size: 11.5, color: _C.gris, h: 1.35)),
        ),
      ]);

  Widget _avisoExito(String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _C.verde50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.verde100),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: _C.verde),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style: _f(size: 12.5, w: FontWeight.w600, color: _C.verdeOs)),
          ),
          GestureDetector(
            onTap: () => setState(() => _aviso = null),
            child: const Icon(Icons.close_rounded, size: 16, color: _C.verde),
          ),
        ]),
      );

  Widget _tarjeta(int i, AveriaMovil a) {
    final abierto = _abierto == i;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: abierto
                ? (_accion == 'recuperar' ? _C.verde100 : _C.rojo100)
                : _C.borde,
            width: abierto ? 1.5 : 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _C.ambar100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_inicial(a.nombre),
                style: _f(size: 17, w: FontWeight.w800, color: _C.ambar)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _f(size: 13.5, w: FontWeight.w700, h: 1.2)),
                const SizedBox(height: 2),
                Text(a.categoria.isEmpty ? 'Sin categoría' : a.categoria,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _f(size: 11, color: _C.gris)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_cant2(a.unidades),
                style: _f(size: 22, w: FontWeight.w800, color: _C.ambar, h: 1)),
            Text('en averías', style: _f(size: 10.5, color: _C.gris)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (widget.onHistorial != null) ...[
            Expanded(
              child: _botonAccion(Icons.history_rounded, 'Historial',
                  TonoMovil.gris, false, () => _verHistorial(a)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: _botonAccion(Icons.replay_rounded, 'Recuperar',
                TonoMovil.verde, abierto && _accion == 'recuperar',
                () => abierto && _accion == 'recuperar'
                    ? _cerrar()
                    : _abrir(i, 'recuperar')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _botonAccion(Icons.delete_outline_rounded, 'Descartar',
                TonoMovil.rojo, abierto && _accion == 'descartar',
                () => abierto && _accion == 'descartar'
                    ? _cerrar()
                    : _abrir(i, 'descartar')),
          ),
        ]),
        if (abierto) _formulario(a),
      ]),
    );
  }

  Widget _botonAccion(IconData icono, String texto, TonoMovil tono,
      bool activo, VoidCallback onTap) {
    return Material(
      color: activo ? tono.fuerte : tono.suave,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _procesando ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: activo ? tono.fuerte : tono.medio),
          ),
          child: Column(children: [
            Icon(icono, size: 18, color: activo ? Colors.white : tono.fuerte),
            const SizedBox(height: 3),
            Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _f(
                    size: 11.5,
                    w: FontWeight.w700,
                    color: activo ? Colors.white : tono.oscuro)),
          ]),
        ),
      ),
    );
  }

  Widget _formulario(AveriaMovil a) {
    final recuperar = _accion == 'recuperar';
    final tono = recuperar ? TonoMovil.verde : TonoMovil.rojo;

    Widget paso(IconData icono, VoidCallback onTap) => Material(
          color: _C.fondo,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _procesando ? null : onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.borde),
              ),
              child: Icon(icono, size: 20, color: _C.tinta),
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tono.suave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(recuperar ? 'Recuperar al stock' : 'Dar de baja',
            style: _f(size: 13, w: FontWeight.w800, color: tono.oscuro)),
        const SizedBox(height: 2),
        Text(
            recuperar
                ? 'Las unidades vuelven al stock vendible.'
                : 'Se eliminan definitivamente. No se puede deshacer.',
            style: _f(size: 11.5, color: _C.gris)),
        const SizedBox(height: 10),
        Row(children: [
          paso(Icons.remove_rounded, () => _sumar(-1, a.unidades)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _cant,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() => _errorAccion = null),
                style: _f(size: 17, w: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: _f(size: 17, w: FontWeight.w800,
                      color: _C.grisClaro),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.borde)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.borde)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tono.fuerte, width: 1.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          paso(Icons.add_rounded, () => _sumar(1, a.unidades)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('Máximo ${_cant2(a.unidades)}',
              style: _f(size: 11, color: _C.gris)),
          const Spacer(),
          GestureDetector(
            onTap: _procesando
                ? null
                : () => setState(() {
                      _cant.text = _cant2(a.unidades);
                      _errorAccion = null;
                    }),
            child: Text('Usar todas',
                style: _f(size: 11.5, w: FontWeight.w700, color: tono.fuerte)),
          ),
        ]),
        if (_errorAccion != null) ...[
          const SizedBox(height: 8),
          Text(_errorAccion!,
              style: _f(size: 11.5, w: FontWeight.w600, color: _C.rojo)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: _procesando ? null : _cerrar,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _C.borde),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancelar',
                    maxLines: 1,
                    style: _f(size: 13, w: FontWeight.w700, color: _C.gris)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: _procesando ? null : () => _confirmar(a),
                style: FilledButton.styleFrom(
                  backgroundColor: tono.fuerte,
                  disabledBackgroundColor: tono.fuerte.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _procesando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(recuperar ? 'Recuperar' : 'Dar de baja',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(
                            size: 13,
                            w: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _mensaje({
    required IconData icono,
    required TonoMovil tono,
    required String titulo,
    required String texto,
    Widget? boton,
    bool pie = false,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 24),
      children: [
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: tono.medio, shape: BoxShape.circle),
            child: Icon(icono, size: 28, color: tono.fuerte),
          ),
        ),
        const SizedBox(height: 14),
        Text(titulo,
            textAlign: TextAlign.center,
            style: _f(size: 15, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(texto,
            textAlign: TextAlign.center,
            style: _f(size: 12.5, color: _C.gris, h: 1.35)),
        if (boton != null) ...[const SizedBox(height: 8), Center(child: boton)],
        if (pie) ...[const SizedBox(height: 18), _pista()],
      ],
    );
  }

  // ── Historial ───────────────────────────────────────────────
  Future<void> _verHistorial(AveriaMovil a) async {
    final cargar = widget.onHistorial;
    if (cargar == null) return;
    final futuro = cargar(a);

    await _hoja(context, (ctx) {
      return FutureBuilder<List<HistorialAveriaMovil>>(
        future: futuro,
        builder: (_, snap) {
          final cabecera = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Historial de averías',
                  style: _f(size: 17, w: FontWeight.w800)),
              Text(a.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _f(size: 12, color: _C.gris)),
              const SizedBox(height: 12),
            ],
          );
          if (snap.connectionState != ConnectionState.done) {
            return Column(children: [
              cabecera,
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: _C.verde),
                ),
              ),
            ]);
          }
          final lista = snap.data ?? const [];
          if (snap.hasError || lista.isEmpty) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              cabecera,
              Text(
                  snap.hasError
                      ? 'No se pudo cargar el historial.'
                      : 'Sin movimientos de avería registrados.',
                  style: _f(size: 12.5, color: _C.gris)),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            cabecera,
            ...lista.map((m) {
              final f = m.fecha;
              final fecha = f == null
                  ? ''
                  : '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} · '
                      '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _C.borde)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _C.ambar50,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 17, color: _C.ambar),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            m.observacion.isEmpty
                                ? 'Sin observación'
                                : m.observacion,
                            style: _f(size: 12.5, w: FontWeight.w700)),
                        Text(
                            [
                              if (m.empleado.isNotEmpty) m.empleado,
                              if (fecha.isNotEmpty) fecha,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _f(size: 10.5, color: _C.gris)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${_cant2(m.cantidad.abs())} ud${m.cantidad.abs() == 1 ? '' : 's'}',
                      style: _f(size: 12.5, w: FontWeight.w800, color: _C.ambar)),
                ]),
              );
            }),
          ]);
        },
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
// IMPORTAR EXCEL
// ══════════════════════════════════════════════════════════════

enum PasoImportacion { archivo, revisar, resultado }

class FilaImportMovil {
  final int     fila;
  final String  nombre;
  final String  codigo;
  final String  categoria;
  final double  precio;
  final double  stock;
  final String? error;

  /// false cuando solo se conoce fila, nombre y motivo (lo que devuelve el
  /// servidor de las filas que fallaron): así no se muestran ceros inventados.
  final bool    conDetalle;

  const FilaImportMovil({
    required this.fila,
    required this.nombre,
    this.codigo = '',
    this.categoria = '',
    this.precio = 0,
    this.stock = 0,
    this.error,
    this.conDetalle = true,
  });
}

class ResultadoImportMovil {
  final int creados;
  final int fallidos;
  final int total;
  final List<FilaImportMovil> noImportadas;
  const ResultadoImportMovil({
    required this.creados,
    required this.fallidos,
    required this.total,
    this.noImportadas = const [],
  });
}

class ImportarExcelMovil extends StatefulWidget {
  final String                 tienda;
  final PasoImportacion        paso;
  final bool                   cargando;
  final String                 mensajeCarga;
  final String                 nombreArchivo;
  final List<FilaImportMovil>  listas;
  final List<FilaImportMovil>  conError;
  final ResultadoImportMovil?  resultado;
  final String?                error;

  final VoidCallback onElegirArchivo;
  final VoidCallback onPlantilla;
  final VoidCallback onImportar;
  final VoidCallback onVolver;
  final VoidCallback onCerrar;
  final VoidCallback? onCerrarError;

  const ImportarExcelMovil({
    super.key,
    required this.tienda,
    required this.paso,
    required this.onElegirArchivo,
    required this.onPlantilla,
    required this.onImportar,
    required this.onVolver,
    required this.onCerrar,
    this.cargando = false,
    this.mensajeCarga = '',
    this.nombreArchivo = '',
    this.listas = const [],
    this.conError = const [],
    this.resultado,
    this.error,
    this.onCerrarError,
  });

  @override
  State<ImportarExcelMovil> createState() => _ImportarExcelMovilState();
}

class _ImportarExcelMovilState extends State<ImportarExcelMovil> {
  bool   _verErrores = false;
  String _buscar = '';
  final  _buscarCtrl = TextEditingController();

  @override
  void didUpdateWidget(ImportarExcelMovil old) {
    super.didUpdateWidget(old);
    if (old.paso != widget.paso) {
      _verErrores = false;
      _buscar = '';
      _buscarCtrl.clear();
    }
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  static const _titulos = ['Elegir archivo', 'Revisar productos', 'Resultado'];

  @override
  Widget build(BuildContext context) {
    final i = widget.paso.index;
    return Column(children: [
      // Encabezado + pasos
      Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.borde)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(
                  onPressed: widget.cargando ? null : widget.onCerrar,
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded, color: _C.tinta),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Importar productos',
                          style: _f(size: 18, w: FontWeight.w800)),
                      Text(widget.tienda,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _f(size: 12, color: _C.gris)),
                    ],
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 0, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: List.generate(3, (k) => Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: k < 2 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: k <= i ? _C.verde : _C.borde,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ))),
                  const SizedBox(height: 7),
                  Text('PASO ${i + 1} DE 3 · ${_titulos[i].toUpperCase()}',
                      style: _f(size: 10.5, w: FontWeight.w800,
                          color: _C.turq, ls: 0.8)),
                ]),
              ),
            ]),
          ),
        ),
      ),

      if (widget.error != null)
        Container(
          width: double.infinity,
          color: _C.rojo50,
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline_rounded, size: 18, color: _C.rojo),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.error!,
                  style: _f(size: 12.5, w: FontWeight.w600, color: _C.rojo)),
            ),
            if (widget.onCerrarError != null)
              GestureDetector(
                onTap: widget.onCerrarError,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: _C.rojo),
                ),
              ),
          ]),
        ),

      Expanded(
        child: widget.cargando
            ? _cargandoVista()
            : switch (widget.paso) {
                PasoImportacion.archivo   => _vistaArchivo(),
                PasoImportacion.revisar   => _vistaRevisar(),
                PasoImportacion.resultado => _vistaResultado(),
              },
      ),

      if (!widget.cargando) _pie(),
    ]);
  }

  // ── Paso 1: elegir archivo ──────────────────────────────────
  Widget _vistaArchivo() {
    const requeridas = ['nombre', 'precio_venta', 'stock_actual'];
    const opcionales = ['categoría', 'precio_compra', 'precio_mayoreo',
                        'stock_minimo', 'codigo_barras', 'descripcion'];

    Widget chip(String t, bool req) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: req ? _C.verde100 : _C.fondo,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: req ? _C.verde100 : _C.borde),
          ),
          child: Text(req ? '$t *' : t,
              style: _f(size: 11.5, w: req ? FontWeight.w700 : FontWeight.w500,
                  color: req ? _C.verdeOs : _C.gris)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onElegirArchivo,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.verde100, width: 1.5),
              ),
              child: Column(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _C.verde100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.upload_file_rounded,
                      size: 30, color: _C.verde),
                ),
                const SizedBox(height: 14),
                Text('Elegir archivo de Excel',
                    textAlign: TextAlign.center,
                    style: _f(size: 16, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Formatos .xlsx y .xls',
                    style: _f(size: 12.5, color: _C.gris)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onPlantilla,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.borde),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _C.turq50,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.download_rounded,
                      size: 21, color: _C.turq),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Descargar plantilla',
                          style: _f(size: 13.5, w: FontWeight.w700)),
                      Text('Un Excel listo para llenar con tus productos',
                          style: _f(size: 11.5, color: _C.gris)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: _C.grisClaro),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('COLUMNAS QUE RECONOCE', style: _seccion()),
        const SizedBox(height: 4),
        Text('Los encabezados del Excel deben llamarse así. '
            'Las marcadas con * son obligatorias.',
            style: _f(size: 11.5, color: _C.gris, h: 1.35)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in requeridas) chip(c, true),
          for (final c in opcionales) chip(c, false),
        ]),
      ],
    );
  }

  // ── Paso 2: revisar ─────────────────────────────────────────
  Widget _vistaRevisar() {
    final todos = _verErrores ? widget.conError : widget.listas;
    final q = _buscar.toLowerCase();
    final filas = q.isEmpty
        ? todos
        : todos.where((f) =>
            f.nombre.toLowerCase().contains(q) ||
            f.codigo.toLowerCase().contains(q) ||
            f.categoria.toLowerCase().contains(q)).toList();

    Widget pestana(String texto, bool activa, TonoMovil t, VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: activa ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activa ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: activa
                    ? const [BoxShadow(color: Color(0x14000000),
                          blurRadius: 4, offset: Offset(0, 1))]
                    : null,
              ),
              child: Text(texto,
                  style: _f(size: 12.5,
                      w: activa ? FontWeight.w700 : FontWeight.w600,
                      color: activa ? t.fuerte : _C.gris)),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (widget.nombreArchivo.isNotEmpty)
          Row(children: [
            const Icon(Icons.description_rounded, size: 16, color: _C.turq),
            const SizedBox(width: 6),
            Expanded(
              child: Text(widget.nombreArchivo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _f(size: 12.5, w: FontWeight.w600, color: _C.gris)),
            ),
          ]),
        if (widget.conError.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _C.ambar50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.ambar100),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 17, color: _C.ambar),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${widget.conError.length} fila${widget.conError.length == 1 ? '' : 's'} '
                    'con error no se importará${widget.conError.length == 1 ? '' : 'n'}. '
                    'Corrígela${widget.conError.length == 1 ? '' : 's'} en el Excel y vuelve a cargarlo.',
                    style: _f(size: 11.5, color: _C.ambar, h: 1.3)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.borde),
          ),
          child: Row(children: [
            pestana('Listos · ${widget.listas.length}', !_verErrores,
                TonoMovil.verde, () => setState(() => _verErrores = false)),
            const SizedBox(width: 4),
            pestana('Con error · ${widget.conError.length}', _verErrores,
                TonoMovil.rojo, () => setState(() => _verErrores = true)),
          ]),
        ),
        if (todos.length > 6) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _buscarCtrl,
              onChanged: (v) => setState(() => _buscar = v.trim()),
              style: _f(size: 13.5),
              decoration: InputDecoration(
                hintText: 'Buscar en el archivo…',
                hintStyle: _f(size: 13, color: _C.gris),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 19, color: _C.gris),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.borde)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.borde)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.verde, width: 1.5)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (filas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
                q.isNotEmpty
                    ? 'Nada coincide con «$_buscar».'
                    : _verErrores
                        ? 'Ninguna fila tiene errores.'
                        : 'No hay filas listas para importar.',
                textAlign: TextAlign.center,
                style: _f(size: 12.5, color: _C.gris)),
          )
        else
          ...filas.map(_filaTarjeta),
      ],
    );
  }

  Widget _filaTarjeta(FilaImportMovil f) {
    final conError = f.error != null;
    final linea = [
      if (f.codigo.isNotEmpty) f.codigo,
      f.categoria.isEmpty ? 'Sin categoría' : f.categoria,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: conError ? _C.rojo100 : _C.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: conError ? _C.rojo50 : _C.fondo,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Fila ${f.fila}',
                style: _f(size: 10, w: FontWeight.w700,
                    color: conError ? _C.rojo : _C.gris)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.nombre.isEmpty ? '(sin nombre)' : f.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _f(size: 13, w: FontWeight.w700, h: 1.2)),
                if (f.conDetalle) ...[
                  const SizedBox(height: 2),
                  Text(linea,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _f(size: 10.5, color: _C.gris)),
                ],
              ],
            ),
          ),
          if (f.conDetalle) ...[
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${Constants.moneda}${_miles(f.precio)}',
                  style: _f(size: 13, w: FontWeight.w800)),
              Text('${_cant(f.stock)} uds',
                  style: _f(size: 10.5, color: _C.gris)),
            ]),
          ],
        ]),
        if (conError) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline_rounded, size: 15, color: _C.rojo),
            const SizedBox(width: 5),
            Expanded(
              child: Text(f.error!,
                  style: _f(size: 11.5, w: FontWeight.w600, color: _C.rojo)),
            ),
          ]),
        ],
      ]),
    );
  }

  // ── Paso 3: resultado ───────────────────────────────────────
  Widget _vistaResultado() {
    final r = widget.resultado ??
        const ResultadoImportMovil(creados: 0, fallidos: 0, total: 0);
    final exito = r.creados > 0;
    final tono = exito ? TonoMovil.verde : TonoMovil.rojo;

    Widget dato(String label, int valor, TonoMovil t) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: t.suave,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.medio),
            ),
            child: Column(children: [
              Text('$valor',
                  style: _f(size: 22, w: FontWeight.w800, color: t.oscuro)),
              Text(label.toUpperCase(),
                  style: _f(size: 9.5, w: FontWeight.w700,
                      color: t.fuerte, ls: 0.4)),
            ]),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: tono.medio, shape: BoxShape.circle),
            child: Icon(exito ? Icons.check_rounded : Icons.close_rounded,
                size: 38, color: tono.fuerte),
          ),
        ),
        const SizedBox(height: 14),
        Text(
            exito
                ? (r.fallidos == 0
                    ? '¡Listo! Se importaron los ${r.total} productos'
                    : 'Se importaron ${r.creados} de ${r.total} productos')
                : 'No se importó ningún producto',
            textAlign: TextAlign.center,
            style: _f(size: 17, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
            exito
                ? 'Ya aparecen en el inventario de ${widget.tienda}.'
                : 'Revisa los errores de abajo y vuelve a intentarlo.',
            textAlign: TextAlign.center,
            style: _f(size: 12.5, color: _C.gris)),
        const SizedBox(height: 18),
        Row(children: [
          dato('Creados', r.creados, TonoMovil.verde),
          const SizedBox(width: 8),
          dato('Con error', r.fallidos, TonoMovil.rojo),
          const SizedBox(width: 8),
          dato('Total', r.total, TonoMovil.gris),
        ]),
        if (r.noImportadas.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('NO SE IMPORTARON', style: _seccion()),
          const SizedBox(height: 8),
          ...r.noImportadas.map(_filaTarjeta),
        ],
      ],
    );
  }

  Widget _cargandoVista() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 3, color: _C.verde),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
                widget.mensajeCarga.isEmpty ? 'Procesando…' : widget.mensajeCarga,
                textAlign: TextAlign.center,
                style: _f(size: 13.5, w: FontWeight.w600, color: _C.gris)),
          ),
        ]),
      );

  // ── Pie fijo ────────────────────────────────────────────────
  Widget _pie() {
    Widget principal(String texto, IconData icono, VoidCallback? onTap) =>
        LayoutBuilder(builder: (_, c) => SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: _C.verde,
              disabledBackgroundColor: _C.verde.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // En botones angostos el ícono se come el espacio del texto.
              if (c.maxWidth >= 200) ...[
                Icon(icono, size: 19, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _f(size: 14, w: FontWeight.w700,
                        color: Colors.white)),
              ),
            ]),
          ),
        ));

    final n = widget.listas.length;
    final contenido = switch (widget.paso) {
      PasoImportacion.archivo => principal(
          'Elegir archivo', Icons.upload_file_rounded, widget.onElegirArchivo),
      PasoImportacion.revisar => Row(children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: widget.onVolver,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _C.borde),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Volver',
                    maxLines: 1,
                    style: _f(size: 14, w: FontWeight.w700, color: _C.gris)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: principal(
                n == 0
                    ? 'Nada que importar'
                    : 'Importar $n producto${n == 1 ? '' : 's'}',
                Icons.cloud_upload_rounded,
                n == 0 ? null : widget.onImportar),
          ),
        ]),
      PasoImportacion.resultado =>
        principal('Listo', Icons.check_rounded, widget.onCerrar),
    };

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.borde)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(width: double.infinity, child: contenido),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EXPORTAR A EXCEL
// ══════════════════════════════════════════════════════════════
//
// Hoja corta: se elige qué productos van (todos, stock bajo, agotados),
// la categoría y el estado; el servidor dice cuántos entran con cada
// opción (los mismos filtros que la descarga, así el número coincide con
// el Excel). Al terminar se ofrece abrir el archivo: en el celular queda
// dentro de la app y el usuario no tiene otra forma de llegar a él.

enum PasoExportacion { elegir, generando, listo }

class CategoriaMovil {
  final int    id;
  final String nombre;
  const CategoriaMovil(this.id, this.nombre);
}

class ConteoExportMovil {
  final int    productos;
  final double valor;
  /// Productos de esta opción con averías: los que trae la hoja Averías.
  final int    averias;
  const ConteoExportMovil(this.productos, this.valor, {this.averias = 0});
}

/// Lo que responde el servidor antes de exportar: los productos de cada
/// opción ('todos', 'bajo', 'agotado') y los movimientos de las hojas de
/// historial de daños y de ajustes (no dependen de la opción).
class ConteosExportMovil {
  final Map<String, ConteoExportMovil> opciones;
  final int danos;
  final int ajustes;
  const ConteosExportMovil(this.opciones, {this.danos = 0, this.ajustes = 0});
}

/// Hojas que se pueden agregar al Excel además de Inventario.
const hojasExtraExport = ['averias', 'danos', 'ajustes'];

class FiltroExportMovil {
  final String  alerta;      // 'todos' | 'bajo' | 'agotado'
  final int?    categoriaId;
  final String? categoriaNombre;
  final String  estado;      // 'true' | 'false' | 'all'
  /// Hojas extra (de [hojasExtraExport]); Inventario va siempre.
  final Set<String> hojas;
  const FiltroExportMovil({
    required this.alerta,
    required this.estado,
    this.categoriaId,
    this.categoriaNombre,
    this.hojas = const {},
  });

  /// Lo que se va a exportar dicho en corto: "Stock bajo · Bisutería".
  String get descripcion => [
        switch (alerta) {
          'bajo'    => 'Stock bajo',
          'agotado' => 'Agotados',
          _         => 'Todos los productos',
        },
        ?categoriaNombre,
        if (estado == 'false') 'Inactivos',
        if (estado == 'all') 'Activos e inactivos',
      ].join(' · ');
}

class ArchivoExportMovil {
  final String nombre;
  final String ruta;
  final int    bytes;
  const ArchivoExportMovil({
    required this.nombre,
    required this.ruta,
    required this.bytes,
  });
}

class ExportarMovil extends StatefulWidget {
  final String               tienda;
  final List<CategoriaMovil> categorias;
  final String               estadoInicial;

  /// Hojas extra marcadas al abrir (lo último que eligió el usuario).
  final Set<String>          hojasIniciales;

  /// Avisa cuando cambian las hojas marcadas, para recordarlas.
  final ValueChanged<Set<String>>? onHojas;

  /// Conteos para la categoría y el estado dados. Si falla, lanza una
  /// excepción con el mensaje.
  final Future<ConteosExportMovil> Function(
      int? categoriaId, String estado) onContar;

  /// Descarga y guarda el Excel. Si falla, lanza una excepción con el
  /// mensaje a mostrar.
  final Future<ArchivoExportMovil> Function(FiltroExportMovil) onExportar;

  /// Abre el archivo; devuelve null si abrió o el motivo si no.
  final Future<String?> Function(ArchivoExportMovil)? onAbrir;

  /// "en el celular" / "en Descargas".
  final String       lugar;
  final VoidCallback onCerrar;

  const ExportarMovil({
    super.key,
    required this.tienda,
    required this.onContar,
    required this.onExportar,
    required this.onCerrar,
    this.onAbrir,
    this.categorias = const [],
    this.estadoInicial = 'true',
    this.lugar = 'en el celular',
    this.hojasIniciales = const {},
    this.onHojas,
  });

  @override
  State<ExportarMovil> createState() => _ExportarMovilState();
}

class _ExportarMovilState extends State<ExportarMovil> {
  var     _paso      = PasoExportacion.elegir;
  String  _alerta    = 'todos';
  int?    _categoria;
  late String _estado = widget.estadoInicial;
  late final Set<String> _hojas = widget.hojasIniciales
      .where(hojasExtraExport.contains)
      .toSet();

  ConteosExportMovil? _todo;
  Map<String, ConteoExportMovil>? get _conteos => _todo?.opciones;
  bool    _contando  = false;
  int     _consulta  = 0; // descarta respuestas viejas si cambian rápido
  String? _error;

  ArchivoExportMovil? _archivo;
  int?    _exportados; // el conteo con que se exportó: coincide con el Excel
  bool    _abriendo  = false;

  @override
  void initState() {
    super.initState();
    _contar();
  }

  Future<void> _contar() async {
    final id = ++_consulta;
    setState(() {
      _contando = true;
      _error = null;
    });
    try {
      final c = await widget.onContar(_categoria, _estado);
      if (!mounted || id != _consulta) return;
      setState(() {
        _todo = c;
        _contando = false;
      });
    } catch (e) {
      if (!mounted || id != _consulta) return;
      setState(() {
        _todo = null;
        _contando = false;
        _error = _mensaje(e);
      });
    }
  }

  static String _mensaje(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  FiltroExportMovil get _filtro {
    String? nombre;
    for (final c in widget.categorias) {
      if (c.id == _categoria) nombre = c.nombre;
    }
    return FiltroExportMovil(
      alerta: _alerta,
      estado: _estado,
      categoriaId: _categoria,
      categoriaNombre: nombre,
      hojas: Set.of(_hojas),
    );
  }

  void _marcarHoja(String h, bool si) {
    setState(() => si ? _hojas.add(h) : _hojas.remove(h));
    widget.onHojas?.call(Set.of(_hojas));
  }

  /// Hojas que de verdad trae el Excel: las de movimientos solo salen si
  /// hay algo que mostrar.
  int get _hojasEnExcel {
    final t = _todo;
    var n = 1; // Inventario
    if (_hojas.contains('averias')) n++;
    if (_hojas.contains('danos') && (t?.danos ?? 0) > 0) n++;
    if (_hojas.contains('ajustes') && (t?.ajustes ?? 0) > 0) n++;
    return n;
  }

  Future<void> _exportar() async {
    final filtro = _filtro;
    setState(() {
      _exportados = _conteos?[_alerta]?.productos;
      _paso = PasoExportacion.generando;
      _error = null;
    });
    try {
      final a = await widget.onExportar(filtro);
      if (!mounted) return;
      setState(() {
        _archivo = a;
        _paso = PasoExportacion.listo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paso = PasoExportacion.elegir;
        _error = _mensaje(e);
      });
    }
  }

  Future<void> _abrir() async {
    final a = _archivo;
    if (a == null || widget.onAbrir == null) return;
    setState(() {
      _abriendo = true;
      _error = null;
    });
    final motivo = await widget.onAbrir!(a);
    if (!mounted) return;
    setState(() {
      _abriendo = false;
      _error = motivo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: switch (_paso) {
            PasoExportacion.elegir    => _vistaElegir(),
            PasoExportacion.generando => _vistaGenerando(),
            PasoExportacion.listo     => _vistaListo(),
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        child: _botones(),
      ),
    ]);
  }

  // ── Encabezado ──────────────────────────────────────────────
  Widget _encabezado() => Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _C.verde50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.download_rounded, size: 21, color: _C.verde),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Exportar a Excel', style: _f(size: 17, w: FontWeight.w800)),
            Text(widget.tienda,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _f(size: 12, color: _C.gris)),
          ]),
        ),
      ]);

  Widget _avisoError() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
        decoration: BoxDecoration(
          color: _C.rojo50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.rojo100),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 17, color: _C.rojo),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: _f(size: 12, w: FontWeight.w600, color: _C.rojo, h: 1.3)),
          ),
        ]),
      );

  // ── Paso 1: elegir ──────────────────────────────────────────
  Widget _vistaElegir() {
    Widget opcion(String clave, String texto, TonoMovil tono) {
      final sel = _alerta == clave;
      final n = _conteos?[clave]?.productos;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: sel ? _C.fondo : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _alerta = clave),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: sel ? _C.verde : _C.borde, width: sel ? 1.6 : 1.2),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: sel ? _C.verde : _C.grisClaro,
                        width: sel ? 5.5 : 2),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(texto, style: _f(size: 14, w: FontWeight.w600)),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: tono.suave,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(n == null ? '…' : '$n',
                      textAlign: TextAlign.center,
                      style: _f(size: 12, w: FontWeight.w800,
                          color: tono.oscuro)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    Widget chip(String texto, bool sel, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: sel ? _C.verde : Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: sel ? null : onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? _C.verde : _C.borde, width: 1.3),
                ),
                child: Text(texto,
                    style: _f(size: 12.5, w: FontWeight.w700,
                        color: sel ? Colors.white : const Color(0xFF334155))),
              ),
            ),
          ),
        );

    final c = _conteos?[_alerta];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _encabezado(),
      if (_error != null) _avisoError(),
      const SizedBox(height: 16),
      Text('QUÉ PRODUCTOS', style: _seccion()),
      const SizedBox(height: 8),
      opcion('todos', 'Todos', TonoMovil.verde),
      opcion('bajo', 'Stock bajo', TonoMovil.ambar),
      opcion('agotado', 'Agotados', TonoMovil.rojo),
      if (widget.categorias.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('CATEGORÍA', style: _seccion()),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('Todas', _categoria == null, () {
              setState(() => _categoria = null);
              _contar();
            }),
            for (final cat in widget.categorias)
              chip(cat.nombre, _categoria == cat.id, () {
                setState(() => _categoria = cat.id);
                _contar();
              }),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      Text('ESTADO', style: _seccion()),
      const SizedBox(height: 8),
      Wrap(runSpacing: 6, children: [
        for (final (v, t) in const [
          ('true', 'Activos'),
          ('false', 'Inactivos'),
          ('all', 'Todos'),
        ])
          chip(t, _estado == v, () {
            setState(() => _estado = v);
            _contar();
          }),
      ]),
      const SizedBox(height: 12),
      _seccionHojas(),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _C.fondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.verde100),
        ),
        child: _contando || c == null
            ? Text(_contando ? 'Contando productos…' : 'Sin datos de conteo',
                style: _f(size: 12.5, color: _C.gris))
            : Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${c.productos} '
                          'producto${c.productos == 1 ? '' : 's'}',
                      style: _f(size: 13.5, w: FontWeight.w800,
                          color: _C.verdeOs)),
                  if (c.productos > 0 && c.valor > 0)
                    TextSpan(
                        text: ' · valor a precio de venta '
                            '${Constants.moneda}${_miles(c.valor)}',
                        style: _f(size: 12.5, color: _C.verdeOs)),
                  TextSpan(
                      text: ' · Excel con $_hojasEnExcel '
                          'hoja${_hojasEnExcel == 1 ? '' : 's'}',
                      style: _f(size: 12.5, color: _C.verdeOs)),
                ]),
              ),
      ),
    ]);
  }

  /// Casillas para elegir las hojas del Excel. Inventario va siempre.
  Widget _seccionHojas() {
    final t = _todo;
    final averias = _conteos?[_alerta]?.averias;

    String movs(int? n) => n == null
        ? '…'
        : n == 0
            ? 'Sin movimientos'
            : '$n movimiento${n == 1 ? '' : 's'}';

    Widget fila(String? clave, String titulo, String detalle,
        {bool vacia = false}) {
      final fija = clave == null;
      final sel = fija || _hojas.contains(clave);
      final aviso = sel && vacia;
      return Material(
        color: Colors.white,
        child: InkWell(
          onTap: fija ? null : () => _marcarHoja(clave, !sel),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: sel
                      ? (fija ? _C.verde.withValues(alpha: 0.45) : _C.verde)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: sel ? Colors.transparent : _C.grisClaro,
                      width: 2),
                ),
                child: sel
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: _f(size: 13.5, w: FontWeight.w600)),
                      Text(aviso ? '$detalle · no saldrá en el Excel' : detalle,
                          style: _f(size: 11.5,
                              color: aviso ? _C.ambar : _C.gris)),
                    ]),
              ),
              if (fija)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.verde50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Siempre',
                      style: _f(size: 11, w: FontWeight.w700,
                          color: _C.verdeOs)),
                ),
            ]),
          ),
        ),
      );
    }

    const linea = Divider(height: 1, thickness: 1, color: _C.borde);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('QUÉ HOJAS', style: _seccion()),
      const SizedBox(height: 8),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.borde, width: 1.2),
        ),
        child: Column(children: [
          fila(null, 'Inventario', 'Los productos elegidos arriba'),
          linea,
          fila('averias', 'Averías',
              averias == null
                  ? '…'
                  : averias == 0
                      ? 'Ningún producto con averías'
                      : '$averias producto${averias == 1 ? '' : 's'} '
                          'con averías'),
          linea,
          fila('danos', 'Historial de daños', movs(t?.danos),
              vacia: t != null && t.danos == 0),
          linea,
          fila('ajustes', 'Ajustes y transferencias', movs(t?.ajustes),
              vacia: t != null && t.ajustes == 0),
        ]),
      ),
    ]);
  }

  // ── Paso 2: generando ───────────────────────────────────────
  Widget _vistaGenerando() => Column(children: [
        const SizedBox(height: 18),
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
              color: _C.verde100, shape: BoxShape.circle),
          child: const CircularProgressIndicator(
              strokeWidth: 3, color: _C.verde),
        ),
        const SizedBox(height: 14),
        Text('Generando el Excel…', style: _f(size: 16, w: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(_filtro.descripcion,
            textAlign: TextAlign.center,
            style: _f(size: 12.5, color: _C.gris)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(
            minHeight: 7,
            color: _C.verde,
            backgroundColor: _C.verde100,
          ),
        ),
        const SizedBox(height: 8),
      ]);

  // ── Paso 3: listo ───────────────────────────────────────────
  Widget _vistaListo() {
    final a = _archivo!;
    final kb = (a.bytes / 1024).ceil();
    return Column(children: [
      const SizedBox(height: 10),
      Container(
        width: 64,
        height: 64,
        decoration:
            const BoxDecoration(color: _C.verde100, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 34, color: _C.verde),
      ),
      const SizedBox(height: 10),
      Text('Excel listo', style: _f(size: 17, w: FontWeight.w800)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.borde),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF107C41),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('XLS',
                style: _f(size: 11.5, w: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.nombre,
                      style: _f(size: 13, w: FontWeight.w700, h: 1.25)),
                  const SizedBox(height: 2),
                  Text([
                    if (_exportados != null)
                      '$_exportados producto${_exportados == 1 ? '' : 's'}',
                    '$kb KB',
                  ].join(' · '),
                      style: _f(size: 11.5, color: _C.gris)),
                ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
            widget.onAbrir != null
                ? 'Guardado ${widget.lugar}. Ábrelo para verlo o '
                    'compartirlo por WhatsApp.'
                : 'Guardado ${widget.lugar}.',
            style: _f(size: 12, color: const Color(0xFF475569), h: 1.35)),
      ),
      if (_error != null) _avisoError(),
    ]);
  }

  // ── Botones ─────────────────────────────────────────────────
  Widget _botones() {
    Widget secundario(String t, VoidCallback onTap) => SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.grisClaro, width: 1.3),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(t,
                maxLines: 1,
                style: _f(size: 14, w: FontWeight.w700,
                    color: const Color(0xFF334155))),
          ),
        );

    Widget principal(String t, IconData icono, VoidCallback? onTap) =>
        LayoutBuilder(builder: (_, c) => SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: _C.verde,
                  disabledBackgroundColor: _C.verde.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (c.maxWidth >= 150) ...[
                    Icon(icono, size: 19, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(t,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(size: 14, w: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ]),
              ),
            ));

    switch (_paso) {
      case PasoExportacion.elegir:
        final n = _conteos?[_alerta]?.productos;
        final listo = !_contando && n != null && n > 0;
        return Row(children: [
          Expanded(child: secundario('Cancelar', widget.onCerrar)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: principal(
                n == 0 ? 'Nada que exportar' : 'Exportar',
                Icons.download_rounded,
                listo ? _exportar : null),
          ),
        ]);
      case PasoExportacion.generando:
        return SizedBox(
            width: double.infinity,
            child: secundario('Cancelar', widget.onCerrar));
      case PasoExportacion.listo:
        if (widget.onAbrir == null) {
          return SizedBox(
              width: double.infinity,
              child: principal('Listo', Icons.check_rounded, widget.onCerrar));
        }
        return Row(children: [
          Expanded(child: secundario('Cerrar', widget.onCerrar)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: principal(_abriendo ? 'Abriendo…' : 'Abrir Excel',
                Icons.open_in_new_rounded, _abriendo ? null : _abrir),
          ),
        ]);
    }
  }
}

/// Abre la hoja de exportar. [construir] recibe el cierre de la hoja.
Future<void> mostrarExportarMovil(
  BuildContext context,
  ExportarMovil Function(VoidCallback cerrar) construir,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: _C.grisClaro,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: construir(() => Navigator.pop(ctx))),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// KARDEX
// ══════════════════════════════════════════════════════════════
//
// Cada movimiento se cuenta en español según su tipo y de dónde vino
// (referencia). El mismo tipo no siempre significa lo mismo: un "ajuste"
// manual guarda en cuánto quedó el stock, pero las cancelaciones de
// devoluciones y cambios también se guardan como "ajuste" con las
// unidades que se movieron; y una avería por devolución no toca el
// stock, solo suma a averías. Por eso cada caso tiene su texto.

/// Un movimiento tal como llega del servidor.
class MovimientoKardexMovil {
  final String    tipo;        // entrada | salida | ajuste | transferencia | dano
  final String    referencia;  // venta, compra, manual, cambio, ...
  final double    cantidad;
  final DateTime? fecha;
  final String    empleado;
  final String    observacion;

  const MovimientoKardexMovil({
    required this.tipo,
    required this.cantidad,
    this.referencia = '',
    this.fecha,
    this.empleado = '',
    this.observacion = '',
  });

  factory MovimientoKardexMovil.fromJson(Map<String, dynamic> j) {
    double n(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    DateTime? f;
    try {
      final s = j['created_at'] as String?;
      if (s != null) f = DateTime.parse(s).toLocal();
    } catch (_) {}
    return MovimientoKardexMovil(
      tipo: (j['tipo'] ?? '').toString(),
      referencia: (j['referencia_tipo'] ?? '').toString(),
      cantidad: n(j['cantidad']),
      fecha: f,
      empleado: (j['empleado_nombre'] ?? '').toString(),
      observacion: (j['observacion'] ?? '').toString(),
    );
  }
}

/// Filtros del kardex.
enum FiltroKardex { todos, entradas, salidas, averias, ajustes }

/// Cómo se muestra un movimiento.
class LineaKardex {
  final String    titulo;
  /// "+30", "−2", "=18", "1".
  final String    cantidad;
  /// Aclaración bajo la cantidad: "quedó en", "a averías"…
  final String?   nota;
  final TonoMovil tono;
  final IconData  icono;
  /// Unidades que sumó (+) o restó (−) al stock. 0 si no lo tocó.
  final double    efectoStock;
  /// Unidades que pasaron a averías.
  final double    aAverias;
  final Set<FiltroKardex> filtros;
  /// Observación a mostrar; null si ya la dice el título.
  final String?   observacion;

  const LineaKardex({
    required this.titulo,
    required this.cantidad,
    required this.tono,
    required this.icono,
    required this.filtros,
    this.nota,
    this.efectoStock = 0,
    this.aAverias = 0,
    this.observacion,
  });
}

LineaKardex describirMovimiento(MovimientoKardexMovil m) {
  final n   = m.cantidad.abs();
  final txt = _cant(n);
  final obs = m.observacion.trim().isEmpty ? null : m.observacion.trim();
  const ent = {FiltroKardex.entradas};
  const sal = {FiltroKardex.salidas};

  LineaKardex entra(String t, {IconData i = Icons.add_circle_outline_rounded,
          Set<FiltroKardex> f = ent, bool ocultarObs = false}) =>
      LineaKardex(titulo: t, cantidad: '+$txt', tono: TonoMovil.verde,
          icono: i, efectoStock: n, filtros: f,
          observacion: ocultarObs ? null : obs);
  LineaKardex sale(String t, {IconData i = Icons.remove_circle_outline_rounded}) =>
      LineaKardex(titulo: t, cantidad: '−$txt', tono: TonoMovil.rojo,
          icono: i, efectoStock: -n, filtros: sal, observacion: obs);

  switch (m.tipo) {
    case 'salida':
      return switch (m.referencia) {
        'venta'           => sale('Venta', i: Icons.shopping_cart_outlined),
        'cambio' || 'cambio_pos' =>
          sale('Cambio · entregado al cliente', i: Icons.sync_alt_rounded),
        'separado'        => sale('Separado', i: Icons.bookmark_outline_rounded),
        'cambio_separado' => sale('Cambio en separado · sale',
            i: Icons.sync_alt_rounded),
        'manual'          => sale('Salida manual'),
        _                 => sale('Salida'),
      };

    case 'entrada':
      return switch (m.referencia) {
        'compra'      => entra('Compra recibida', i: Icons.inventory_2_outlined),
        'devolucion'  => entra('Devolución de cliente',
            i: Icons.assignment_return_outlined),
        'cambio'      => entra('Cambio · devuelto a inventario',
            i: Icons.sync_alt_rounded),
        'anulacion'   => entra('Venta anulada', i: Icons.undo_rounded),
        'cancelacion_separado' => entra('Separado cancelado',
            i: Icons.undo_rounded),
        'cambio_separado' => entra('Cambio en separado · vuelve',
            i: Icons.sync_alt_rounded),
        'cancelacion_cambio' => entra('Cambio cancelado · vuelve',
            i: Icons.undo_rounded),
        'recuperacion_averia' => entra('Recuperado de averías',
            i: Icons.restore_rounded,
            f: {FiltroKardex.entradas, FiltroKardex.averias},
            // "Recuperado de averías → stock normal" repite el título.
            ocultarObs: obs?.startsWith('Recuperado de averías') ?? false),
        'manual'      => entra('Entrada manual'),
        _             => entra('Entrada'),
      };

    case 'transferencia':
      // La salida guarda la cantidad en negativo; la entrada en positivo.
      final envio = m.cantidad < 0;
      String? lugar;
      String? obsLibre = obs;
      if (obs != null) {
        // "Transferencia a Unicentro" o "Transferencia a Unicentro · nota".
        final r = RegExp(envio ? r'^Transferencia a (.+?)(?: · (.+))?$'
                               : r'^Recibido desde (.+?)(?: · (.+))?$')
            .firstMatch(obs);
        if (r != null) {
          lugar = r.group(1);
          obsLibre = r.group(2); // la tienda ya va en el título
        }
      }
      final titulo = envio
          ? (lugar != null ? 'Enviado a $lugar' : 'Enviado a otra tienda')
          : (lugar != null ? 'Recibido de $lugar' : 'Recibido de otra tienda');
      return LineaKardex(
        titulo: titulo,
        cantidad: '${envio ? '−' : '+'}$txt',
        tono: TonoMovil.turquesa,
        icono: Icons.swap_horiz_rounded,
        efectoStock: envio ? -n : n,
        filtros: envio ? sal : ent,
        observacion: obsLibre,
      );

    case 'ajuste':
      switch (m.referencia) {
        case 'manual':
          return LineaKardex(
            titulo: 'Ajuste manual',
            cantidad: '=$txt',
            nota: 'quedó en',
            tono: TonoMovil.gris,
            icono: Icons.tune_rounded,
            filtros: {FiltroKardex.ajustes},
            observacion: obs,
          );
        case 'cancelacion_devolucion':
          return LineaKardex(
            titulo: 'Devolución cancelada',
            cantidad: txt,
            nota: 'sale de averías',
            tono: TonoMovil.gris,
            icono: Icons.undo_rounded,
            filtros: {FiltroKardex.ajustes, FiltroKardex.averias},
            observacion: obs,
          );
        case 'cancelacion_cambio':
          // Según el motivo del cambio, lo recibido estaba en el stock o
          // en averías: lo dice la observación.
          final deStock = obs?.contains('de inventario') ?? false;
          return LineaKardex(
            titulo: 'Cambio cancelado',
            cantidad: deStock ? '−$txt' : txt,
            nota: deStock ? null : 'sale de averías',
            tono: deStock ? TonoMovil.rojo : TonoMovil.gris,
            icono: Icons.undo_rounded,
            efectoStock: deStock ? -n : 0,
            filtros: {FiltroKardex.ajustes,
                deStock ? FiltroKardex.salidas : FiltroKardex.averias},
            observacion: obs,
          );
        default:
          return LineaKardex(
            titulo: 'Ajuste',
            cantidad: txt,
            tono: TonoMovil.gris,
            icono: Icons.tune_rounded,
            filtros: {FiltroKardex.ajustes},
            observacion: obs,
          );
      }

    case 'dano':
      const av = {FiltroKardex.averias};
      return switch (m.referencia) {
        // Reportada a mano: sale del stock y pasa a averías.
        'manual' => LineaKardex(
            titulo: 'Avería reportada',
            cantidad: '−$txt',
            nota: 'a averías',
            tono: TonoMovil.ambar,
            icono: Icons.warning_amber_rounded,
            efectoStock: -n,
            aAverias: n,
            filtros: {FiltroKardex.averias, FiltroKardex.salidas},
            observacion: obs),
        // Lo trajo el cliente dañado: va directo a averías, el stock no
        // cambia.
        'devolucion' || 'cambio' || 'cambio_pos' => LineaKardex(
            titulo: m.referencia == 'devolucion'
                ? 'Avería por devolución'
                : 'Avería por cambio',
            cantidad: txt,
            nota: 'a averías',
            tono: TonoMovil.ambar,
            icono: Icons.warning_amber_rounded,
            aAverias: n,
            filtros: av,
            observacion: obs),
        'descarte_averia' => LineaKardex(
            titulo: 'Descartado de averías',
            cantidad: txt,
            nota: 'baja definitiva',
            tono: TonoMovil.gris,
            icono: Icons.delete_outline_rounded,
            filtros: av,
            observacion: obs != null && obs.startsWith('Descartado de averías')
                ? null : obs),
        _ => LineaKardex(
            titulo: 'Avería',
            cantidad: txt,
            nota: 'a averías',
            tono: TonoMovil.ambar,
            icono: Icons.warning_amber_rounded,
            aAverias: n,
            filtros: av,
            observacion: obs),
      };

    default:
      return LineaKardex(
        titulo: m.tipo.isEmpty ? 'Movimiento' : m.tipo,
        cantidad: txt,
        tono: TonoMovil.gris,
        icono: Icons.circle_outlined,
        filtros: const {},
        observacion: obs,
      );
  }
}

const _diasCortos = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _mesesCortos = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
                      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "Hoy", "Ayer", "Lun 23 nov" o "Lun 23 nov 2025" si es de otro año.
String diaKardex(DateTime d, DateTime ahora) {
  final dia = DateTime(d.year, d.month, d.day);
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dif = hoy.difference(dia).inDays;
  if (dif == 0) return 'Hoy';
  if (dif == 1) return 'Ayer';
  final base = '${_diasCortos[d.weekday]} ${d.day} ${_mesesCortos[d.month]}';
  return d.year == ahora.year ? base : '$base ${d.year}';
}

/// "3:42 p. m."
String horaKardex(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} '
      '${d.hour < 12 ? 'a. m.' : 'p. m.'}';
}

class KardexMovil extends StatefulWidget {
  final String producto;
  final String tienda;
  final double? stockActual;
  final List<MovimientoKardexMovil> movimientos;
  final bool    cargando;
  final String? error;
  final VoidCallback? onReintentar;
  /// Para las pruebas: la fecha de "hoy".
  final DateTime? ahora;

  const KardexMovil({
    super.key,
    required this.producto,
    required this.tienda,
    required this.movimientos,
    this.stockActual,
    this.cargando = false,
    this.error,
    this.onReintentar,
    this.ahora,
  });

  @override
  State<KardexMovil> createState() => _KardexMovilState();
}

class _KardexMovilState extends State<KardexMovil> {
  var _filtro = FiltroKardex.todos;

  static const _nombres = {
    FiltroKardex.todos:    'Todos',
    FiltroKardex.entradas: 'Entradas',
    FiltroKardex.salidas:  'Salidas',
    FiltroKardex.averias:  'Averías',
    FiltroKardex.ajustes:  'Ajustes',
  };

  @override
  Widget build(BuildContext context) {
    final lineas = [
      for (final m in widget.movimientos) (m, describirMovimiento(m)),
    ];
    double entradas = 0, salidas = 0, averias = 0;
    for (final (_, l) in lineas) {
      if (l.efectoStock > 0) entradas += l.efectoStock;
      if (l.efectoStock < 0) salidas -= l.efectoStock;
      averias += l.aAverias;
    }
    int cuantos(FiltroKardex f) => f == FiltroKardex.todos
        ? lineas.length
        : lineas.where((x) => x.$2.filtros.contains(f)).length;
    final visibles = _filtro == FiltroKardex.todos
        ? lineas
        : lineas.where((x) => x.$2.filtros.contains(_filtro)).toList();

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.turq50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history_rounded,
                  size: 22, color: _C.turqOs),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.producto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(size: 16, w: FontWeight.w800)),
                    Text('Kardex · ${widget.tienda}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(size: 11.5, color: _C.gris)),
                  ]),
            ),
            if (widget.stockActual != null) ...[
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_cant(widget.stockActual!),
                    style: _f(size: 20, w: FontWeight.w800,
                        color: widget.stockActual! <= 0
                            ? _C.rojo
                            : _C.verdeOs,
                        h: 1.05)),
                Text('EN STOCK',
                    style: _f(size: 9, w: FontWeight.w800,
                        color: _C.gris, ls: 0.5)),
              ]),
            ],
          ]),
          if (!widget.cargando &&
              widget.error == null &&
              lineas.isNotEmpty) ...[
            const SizedBox(height: 11),
            Row(children: [
              _resumen('+${_cant(entradas)}', 'Entradas', TonoMovil.verde),
              const SizedBox(width: 6),
              _resumen(salidas == 0 ? '0' : '−${_cant(salidas)}', 'Salidas',
                  TonoMovil.rojo),
              const SizedBox(width: 6),
              _resumen(_cant(averias), 'Averías', TonoMovil.ambar),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in FiltroKardex.values)
                  if (f == FiltroKardex.todos || cuantos(f) > 0)
                    _chipFiltro(f, cuantos(f)),
              ]),
            ),
          ],
        ]),
      ),
      const Divider(height: 1, thickness: 1, color: _C.borde),
      Expanded(child: _cuerpo(visibles)),
    ]);
  }

  Widget _resumen(String valor, String etiqueta, TonoMovil t) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
          decoration: BoxDecoration(
            color: t.suave,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(valor,
                maxLines: 1,
                style: _f(size: 14.5, w: FontWeight.w800, color: t.oscuro)),
            Text(etiqueta.toUpperCase(),
                maxLines: 1,
                style: _f(size: 9, w: FontWeight.w800, color: t.fuerte,
                    ls: 0.3)),
          ]),
        ),
      );

  Widget _chipFiltro(FiltroKardex f, int n) {
    final sel = _filtro == f;
    final texto = sel && f != FiltroKardex.todos
        ? '${_nombres[f]} · $n'
        : _nombres[f]!;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: sel ? _C.verde : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: sel ? null : () => setState(() => _filtro = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? _C.verde : _C.borde, width: 1.3),
            ),
            child: Text(texto,
                style: _f(size: 12, w: FontWeight.w700,
                    color: sel ? Colors.white : const Color(0xFF334155))),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(List<(MovimientoKardexMovil, LineaKardex)> visibles) {
    if (widget.cargando) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3, color: _C.verde),
        ),
      );
    }
    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 32, color: _C.rojo),
            const SizedBox(height: 10),
            Text(widget.error!,
                textAlign: TextAlign.center,
                style: _f(size: 13, color: _C.gris)),
            if (widget.onReintentar != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.onReintentar,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _C.verde100),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Reintentar',
                    style: _f(size: 13, w: FontWeight.w700,
                        color: _C.verde)),
              ),
            ],
          ]),
        ),
      );
    }
    if (widget.movimientos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _C.turq50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.timeline_rounded,
                  size: 28, color: _C.turq),
            ),
            const SizedBox(height: 12),
            Text('Sin movimientos todavía',
                style: _f(size: 14, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Las ventas, compras, ajustes y averías de este\n'
                'producto en esta tienda aparecerán aquí.',
                textAlign: TextAlign.center,
                style: _f(size: 12, color: _C.gris, h: 1.35)),
          ]),
        ),
      );
    }

    final ahora = widget.ahora ?? DateTime.now();
    final items = <Widget>[];
    String? diaPrevio;
    for (final (m, l) in visibles) {
      final dia = m.fecha == null ? 'Sin fecha' : diaKardex(m.fecha!, ahora);
      if (dia != diaPrevio) {
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(2, items.isEmpty ? 4 : 10, 2, 6),
          child: Text(dia.toUpperCase(), style: _seccion()),
        ));
        diaPrevio = dia;
      }
      items.add(_fila(m, l));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: items,
    );
  }

  Widget _fila(MovimientoKardexMovil m, LineaKardex l) {
    final sub = [
      if (m.fecha != null) horaKardex(m.fecha!),
      if (m.empleado.trim().isNotEmpty) m.empleado.trim(),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 9, 11, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.borde),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: l.tono.suave,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(l.icono, size: 17, color: l.tono.fuerte),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.titulo,
                style: _f(size: 13, w: FontWeight.w700, h: 1.25)),
            if (sub.isNotEmpty)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _f(size: 11, color: _C.gris)),
            if (l.observacion != null) ...[
              const SizedBox(height: 3),
              Text(l.observacion!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _f(size: 11, color: const Color(0xFF475569), h: 1.3)
                      .copyWith(fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(l.cantidad,
              style: _f(size: 15, w: FontWeight.w800, color: l.tono.oscuro,
                  h: 1.1)),
          if (l.nota != null)
            Text(l.nota!.toUpperCase(),
                style: _f(size: 8.5, w: FontWeight.w800, color: l.tono.fuerte,
                    ls: 0.3)),
        ]),
      ]),
    );
  }
}

/// Abre el kardex en una hoja casi de pantalla completa. [cuerpo] arma el
/// contenido (normalmente un StatefulBuilder que carga los movimientos).
Future<void> mostrarKardexMovil(BuildContext context, WidgetBuilder cuerpo) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.sizeOf(ctx).height * 0.9,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: _C.fondo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: _C.grisClaro,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(child: cuerpo(ctx)),
        ]),
      ),
    ),
  );
}

/// Pregunta de qué tienda ver algo cuando se está en "Todas las tiendas".
/// Devuelve el id elegido o null si cierra.
Future<int?> mostrarElegirTiendaMovil(
  BuildContext context, {
  required String titulo,
  required String subtitulo,
  required List<(TiendaMovil, double?)> tiendas,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: _C.grisClaro,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              children: [
                Text(titulo, style: _f(size: 17, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style: _f(size: 12.5, color: _C.gris, h: 1.3)),
                const SizedBox(height: 12),
                for (final (t, stock) in tiendas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(ctx, t.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _C.borde, width: 1.3),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Text(t.nombre,
                                  style: _f(size: 13.5, w: FontWeight.w700)),
                            ),
                            if (stock != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stock <= 0 ? _C.rojo50 : _C.verde50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(_cant(stock),
                                    style: _f(size: 12, w: FontWeight.w800,
                                        color: stock <= 0
                                            ? _C.rojo
                                            : _C.verdeOs)),
                              ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded,
                                size: 20, color: _C.grisClaro),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// AJUSTAR STOCK
// ══════════════════════════════════════════════════════════════
//
// Entrada, salida, conteo (fija el stock; puede ser 0) y avería. Antes de
// confirmar se ve en cuánto va a quedar, y lo imposible (sacar más de lo
// que hay, un conteo igual al stock) no deja confirmar. El motivo elegido
// se guarda como observación para que el kardex diga por qué.

/// Valores que entiende el servidor: entrada | salida | ajuste | averia.
const tiposAjusteMovil = ['entrada', 'salida', 'ajuste', 'averia'];

const motivosAjusteMovil = {
  'entrada': ['Llegó mercancía', 'Estaba en bodega', 'Corrección', 'Otro'],
  'salida':  ['Uso interno', 'Obsequio', 'Corrección', 'Otro'],
  'ajuste':  ['Conteo físico', 'Error de registro', 'Pérdida', 'Otro'],
  'averia':  ['Se dañó en tienda', 'Llegó dañado', 'Defecto', 'Otro'],
};

/// Observación que se guarda: el motivo (si no es "Otro") y la nota.
String observacionAjuste(String? motivo, String nota) => [
      if (motivo != null && motivo != 'Otro') motivo,
      if (nota.trim().isNotEmpty) nota.trim(),
    ].join(' · ');

String _uds(double n) => '${_cant(n)} unidad${n == 1 ? '' : 'es'}';

/// Por qué no se puede confirmar todavía; null si se puede.
/// [soloEnteros]: el producto se maneja por unidad (no hay medio arete).
String? problemaAjuste(String tipo, double? cantidad, double stock,
    {bool soloEnteros = true}) {
  if (cantidad == null) return 'Escribe una cantidad.';
  if (cantidad < 0) return 'La cantidad no puede ser negativa.';
  if (soloEnteros && cantidad != cantidad.roundToDouble()) {
    return 'Solo unidades enteras.';
  }
  if (tipo == 'ajuste') {
    return cantidad == stock
        ? 'El stock ya está en ${_uds(stock)}.'
        : null;
  }
  if (cantidad <= 0) return 'La cantidad debe ser mayor a cero.';
  if ((tipo == 'salida' || tipo == 'averia') && cantidad > stock) {
    return stock <= 0
        ? 'No hay unidades en esta tienda.'
        : 'Solo hay ${_uds(stock)} en esta tienda.';
  }
  return null;
}

class AjusteStockMovil extends StatefulWidget {
  final String  producto;
  final String  tienda;
  final double  stock;
  /// Unidades en averías; null si no se sabe (no se muestra).
  final double? averias;
  final String  tipoInicial;
  /// true si el producto se maneja por unidad: no acepta decimales.
  final bool    soloEnteros;

  /// Envía el ajuste. Devuelve null si salió bien o el mensaje de error.
  final Future<String?> Function(String tipo, double cantidad, String obs)
      onConfirmar;
  final VoidCallback onCerrar;

  const AjusteStockMovil({
    super.key,
    required this.producto,
    required this.tienda,
    required this.stock,
    required this.onConfirmar,
    required this.onCerrar,
    this.averias,
    this.tipoInicial = 'entrada',
    this.soloEnteros = true,
  });

  @override
  State<AjusteStockMovil> createState() => _AjusteStockMovilState();
}

class _AjusteStockMovilState extends State<AjusteStockMovil> {
  late String _tipo = tiposAjusteMovil.contains(widget.tipoInicial)
      ? widget.tipoInicial
      : 'entrada';
  final _cantCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  String? _motivo;
  bool    _enviando = false;
  String? _errorServidor;

  @override
  void initState() {
    super.initState();
    _alCambiarTipo(_tipo);
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  void _alCambiarTipo(String t) {
    _tipo = t;
    _motivo = motivosAjusteMovil[t]!.first;
    _errorServidor = null;
    // El conteo arranca en el stock actual (se corrige desde ahí); los
    // demás en 1.
    _cantCtrl.text = t == 'ajuste' ? _cant(widget.stock) : '1';
  }

  double? get _cantidad {
    final s = _cantCtrl.text.trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'\d').hasMatch(s)) return null;
    return leerNumeroExcel(s);
  }

  void _sumar(double d) {
    final actual = _cantidad ?? 0;
    final nuevo = (actual + d) < 0 ? 0.0 : actual + d;
    setState(() {
      _cantCtrl.text = _cant(nuevo);
      _errorServidor = null;
    });
  }

  Future<void> _confirmar() async {
    final c = _cantidad;
    if (c == null ||
        problemaAjuste(_tipo, c, widget.stock,
                soloEnteros: widget.soloEnteros) !=
            null) {
      return;
    }
    setState(() {
      _enviando = true;
      _errorServidor = null;
    });
    final err = await widget.onConfirmar(
        _tipo, c, observacionAjuste(_motivo, _notaCtrl.text));
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _errorServidor = err;
    });
  }

  ({TonoMovil tono, IconData icono, String titulo, String ayuda,
    String etiqueta}) get _info => switch (_tipo) {
        'salida' => (
            tono: TonoMovil.rojo,
            icono: Icons.remove_circle_outline_rounded,
            titulo: 'Ajustar stock',
            ayuda: 'Saca unidades del stock (no es una venta).',
            etiqueta: 'CUÁNTAS UNIDADES'),
        'ajuste' => (
            tono: TonoMovil.gris,
            icono: Icons.fact_check_outlined,
            titulo: 'Ajustar stock',
            ayuda: 'Escribe cuántas hay en realidad. Puede ser 0.',
            etiqueta: 'CUÁNTAS CONTASTE'),
        'averia' => (
            tono: TonoMovil.ambar,
            icono: Icons.warning_amber_rounded,
            titulo: 'Reportar avería',
            ayuda: 'Pasa unidades del stock a averías.',
            etiqueta: 'UNIDADES DAÑADAS'),
        _ => (
            tono: TonoMovil.verde,
            icono: Icons.add_circle_outline_rounded,
            titulo: 'Ajustar stock',
            ayuda: 'Suma unidades al stock.',
            etiqueta: 'CUÁNTAS UNIDADES'),
      };

  String _textoBoton(double? c) {
    if (c == null) return 'Escribe una cantidad';
    final n = _cant(c);
    final pl = c == 1 ? '' : 'es';
    return switch (_tipo) {
      'salida' => 'Sacar $n unidad$pl',
      'ajuste' => c == widget.stock ? 'Sin cambios' : 'Dejar en $n unidad$pl',
      'averia' => 'Reportar $n avería${c == 1 ? '' : 's'}',
      _        => 'Sumar $n unidad$pl',
    };
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final c = _cantidad;
    final problema = problemaAjuste(_tipo, c, widget.stock,
        soloEnteros: widget.soloEnteros);
    // Los avisos que se ven: los que indican algo imposible. "Escribe una
    // cantidad" o "Sin cambios" ya los dice el botón.
    final avisoVisible = problema != null &&
        c != null &&
        !(_tipo == 'ajuste' && c == widget.stock);

    // Cursor y manija de selección en verde (no el morado por defecto).
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _C.verde,
          selectionHandleColor: _C.verde,
          selectionColor: _C.verde100,
        ),
      ),
      child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 14 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Encabezado
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: info.tono.suave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info.icono, size: 21, color: info.tono.fuerte),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info.titulo, style: _f(size: 16.5, w: FontWeight.w800)),
              Text('${widget.producto} · ${widget.tienda}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _f(size: 11.5, color: _C.gris)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),

        // Tipo
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            for (final (t, nombre, icono, tono) in const [
              ('entrada', 'Entrada', Icons.add_rounded, TonoMovil.verde),
              ('salida', 'Salida', Icons.remove_rounded, TonoMovil.rojo),
              ('ajuste', 'Conteo', Icons.fact_check_outlined, TonoMovil.gris),
              ('averia', 'Avería', Icons.warning_amber_rounded, TonoMovil.ambar),
            ])
              Expanded(
                child: GestureDetector(
                  onTap: _enviando || _tipo == t
                      ? null
                      : () => setState(() => _alCambiarTipo(t)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _tipo == t ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: _tipo == t
                          ? const [BoxShadow(color: Color(0x14000000),
                                blurRadius: 4, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: Column(children: [
                      Icon(icono, size: 18,
                          color: _tipo == t ? tono.fuerte : _C.gris),
                      const SizedBox(height: 1),
                      Text(nombre,
                          maxLines: 1,
                          style: _f(size: 11, w: FontWeight.w700,
                              color: _tipo == t ? tono.oscuro : _C.gris)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(info.ayuda, style: _f(size: 11.5, color: _C.gris)),
        const SizedBox(height: 12),

        // Cantidad
        Text(info.etiqueta, style: _seccion()),
        const SizedBox(height: 7),
        Row(children: [
          _botonPaso(Icons.remove_rounded,
              _enviando || (c ?? 0) <= 0 ? null : () => _sumar(-1)),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: _cantCtrl,
                enabled: !_enviando,
                textAlign: TextAlign.center,
                // Por unidad: teclado sin coma ni punto.
                keyboardType: TextInputType.numberWithOptions(
                    decimal: !widget.soloEnteros),
                onChanged: (_) => setState(() => _errorServidor = null),
                style: _f(size: 21, w: FontWeight.w800),
                decoration: InputDecoration(
                  suffixText: 'uds',
                  suffixStyle: _f(size: 12, w: FontWeight.w600,
                      color: _C.gris),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: avisoVisible ? _C.rojo : info.tono.fuerte,
                        width: 1.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: avisoVisible ? _C.rojo : info.tono.fuerte,
                        width: 2.2),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.borde),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _botonPaso(Icons.add_rounded, _enviando ? null : () => _sumar(1)),
        ]),
        const SizedBox(height: 10),

        if (avisoVisible)
          _aviso(problema)
        else if (c != null)
          _vistaPrevia(c),

        if (_errorServidor != null) ...[
          const SizedBox(height: 8),
          _aviso(_errorServidor!),
        ],
        const SizedBox(height: 12),

        // Motivo
        Text('MOTIVO', style: _seccion()),
        const SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in motivosAjusteMovil[_tipo]!)
            GestureDetector(
              onTap: _enviando ? null : () => setState(() => _motivo = m),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: _motivo == m ? _C.verde50 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _motivo == m ? _C.verde : _C.borde, width: 1.3),
                ),
                child: Text(m,
                    style: _f(size: 12, w: FontWeight.w700,
                        color: _motivo == m
                            ? _C.verdeOs
                            : const Color(0xFF334155))),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _notaCtrl,
          enabled: !_enviando,
          maxLines: 1,
          style: _f(size: 13),
          decoration: InputDecoration(
            hintText: _motivo == 'Otro' ? 'Escribe el motivo' : 'Nota (opcional)',
            hintStyle: _f(size: 12.5, color: const Color(0xFF94A3B8)),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.borde, width: 1.3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.verde, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.borde),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Botones
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _enviando ? null : widget.onCerrar,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _C.grisClaro, width: 1.3),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Cancelar',
                    maxLines: 1,
                    style: _f(size: 14, w: FontWeight.w700,
                        color: const Color(0xFF334155))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: problema == null && !_enviando ? _confirmar : null,
                style: FilledButton.styleFrom(
                  backgroundColor: info.tono == TonoMovil.gris
                      ? const Color(0xFF334155)
                      : info.tono.fuerte,
                  disabledBackgroundColor: (info.tono == TonoMovil.gris
                          ? const Color(0xFF334155)
                          : info.tono.fuerte)
                      .withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(_textoBoton(c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(size: 14, w: FontWeight.w800,
                            color: Colors.white)),
              ),
            ),
          ),
        ]),
      ]),
    ),
    );
  }

  Widget _botonPaso(IconData icono, VoidCallback? onTap) => SizedBox(
        width: 48,
        height: 50,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: _C.borde, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Icon(icono,
              size: 22, color: onTap == null ? _C.grisClaro : _C.verdeOs),
        ),
      );

  Widget _aviso(String texto) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
        decoration: BoxDecoration(
          color: _C.rojo50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.rojo100),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 16, color: _C.rojo),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(texto,
                style: _f(size: 12, w: FontWeight.w600, color: _C.rojo,
                    h: 1.3)),
          ),
        ]),
      );

  Widget _vistaPrevia(double c) {
    final s = widget.stock;

    Widget dato(String k, String v, Color colorK, Color colorV,
            {CrossAxisAlignment a = CrossAxisAlignment.start,
            double tam = 21}) =>
        Column(crossAxisAlignment: a, children: [
          Text(k.toUpperCase(),
              style: _f(size: 9.5, w: FontWeight.w800, color: colorK,
                  ls: 0.4)),
          Text(v, style: _f(size: tam, w: FontWeight.w800, color: colorV,
              h: 1.15)),
        ]);

    Widget caja(Color fondo, Widget hijo) => Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(14),
          ),
          child: hijo,
        );

    switch (_tipo) {
      case 'ajuste':
        final dif = c - s;
        final t = dif < 0 ? TonoMovil.rojo : TonoMovil.verde;
        return caja(t.suave, Row(children: [
          dato('Sistema', _cant(s), t.fuerte, const Color(0xFF475569)),
          Expanded(
            child: dato(dif < 0 ? 'Faltan' : 'Sobran',
                '${dif < 0 ? '−' : '+'}${_cant(dif.abs())}',
                t.fuerte, t.oscuro,
                a: CrossAxisAlignment.center, tam: 17),
          ),
          dato('Quedará en', _cant(c), t.fuerte, _C.tinta,
              a: CrossAxisAlignment.end),
        ]));
      case 'averia':
        Widget linea(String k, String v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Text(k, style: _f(size: 12.5, w: FontWeight.w700,
                    color: _C.ambar)),
                const Spacer(),
                Text(v, style: _f(size: 13.5, w: FontWeight.w800)),
              ]),
            );
        return caja(_C.ambar50, Column(children: [
          linea('Stock', '${_cant(s)} → ${_cant(s - c)}'),
          if (widget.averias != null)
            linea('Averías',
                '${_cant(widget.averias!)} → ${_cant(widget.averias! + c)}'),
        ]));
      default:
        final sale = _tipo == 'salida';
        final t = sale ? TonoMovil.rojo : TonoMovil.verde;
        return caja(t.suave, Row(children: [
          dato('Ahora', _cant(s), t.fuerte, const Color(0xFF475569)),
          Expanded(
            child: Icon(Icons.arrow_forward_rounded, size: 20,
                color: t.fuerte),
          ),
          dato('Quedará en', _cant(sale ? s - c : s + c), t.fuerte, t.oscuro,
              a: CrossAxisAlignment.end),
        ]));
    }
  }
}

/// Abre la hoja de ajustar stock. [construir] recibe el cierre de la hoja.
Future<void> mostrarAjusteStockMovil(
  BuildContext context,
  AjusteStockMovil Function(VoidCallback cerrar) construir,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.94),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
              color: _C.grisClaro,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: construir(() => Navigator.pop(ctx))),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// TRANSFERIR ENTRE TIENDAS
// ══════════════════════════════════════════════════════════════
//
// Desde (fija si se está en una tienda; a elegir en "Todas") y hacia, cada
// tienda con su stock; cantidad con − y + o "Todo"; y antes de enviar se ve
// cómo quedan las dos tiendas.

/// Por qué no se puede enviar todavía; null si se puede.
String? problemaTransferencia({
  required double? cantidad,
  required double? stockOrigen,
  required bool hayDestino,
  String origen = 'La tienda de origen',
  bool soloEnteros = true,
}) {
  if (stockOrigen == null) return 'Elige desde qué tienda.';
  if (!hayDestino) return 'Elige a qué tienda.';
  if (cantidad == null) return 'Escribe una cantidad.';
  if (cantidad < 0) return 'La cantidad no puede ser negativa.';
  if (soloEnteros && cantidad != cantidad.roundToDouble()) {
    return 'Solo unidades enteras.';
  }
  if (cantidad == 0) return 'La cantidad debe ser mayor a cero.';
  if (cantidad > stockOrigen) {
    return stockOrigen <= 0
        ? '$origen no tiene unidades.'
        : '$origen solo tiene ${_uds(stockOrigen)}.';
  }
  return null;
}

class TransferirMovil extends StatefulWidget {
  final String producto;
  /// Todas las tiendas de la empresa con el stock del producto en cada una.
  final List<(TiendaMovil, double)> tiendas;
  /// Tienda de origen ya elegida (la que se está viendo). null en "Todas":
  /// se elige en la hoja.
  final int?   origenFijo;
  final bool   soloEnteros;

  /// Envía la transferencia. null si salió bien o el mensaje de error.
  final Future<String?> Function(
      int origen, int destino, double cantidad, String nota) onConfirmar;
  final VoidCallback onCerrar;

  const TransferirMovil({
    super.key,
    required this.producto,
    required this.tiendas,
    required this.onConfirmar,
    required this.onCerrar,
    this.origenFijo,
    this.soloEnteros = true,
  });

  @override
  State<TransferirMovil> createState() => _TransferirMovilState();
}

class _TransferirMovilState extends State<TransferirMovil> {
  late int? _origen = widget.origenFijo ?? _primerOrigenConStock();
  int?    _destino;
  final   _cantCtrl = TextEditingController(text: '1');
  final   _notaCtrl = TextEditingController();
  bool    _enviando = false;
  String? _errorServidor;

  int? _primerOrigenConStock() {
    for (final (t, s) in widget.tiendas) {
      if (s > 0) return t.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _destino = _unicoDestino();
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  /// Con dos tiendas el destino es la otra: ya viene elegido.
  int? _unicoDestino() {
    final otros = _destinos;
    return otros.length == 1 ? otros.first.$1.id : null;
  }

  List<(TiendaMovil, double)> get _destinos =>
      widget.tiendas.where((x) => x.$1.id != _origen).toList();

  (TiendaMovil, double)? _tienda(int? id) {
    for (final x in widget.tiendas) {
      if (x.$1.id == id) return x;
    }
    return null;
  }

  double? get _cantidad {
    final s = _cantCtrl.text.trim();
    if (s.isEmpty || !RegExp(r'\d').hasMatch(s)) return null;
    return leerNumeroExcel(s);
  }

  void _poner(double v) => setState(() {
        _cantCtrl.text = _cant(v < 0 ? 0 : v);
        _errorServidor = null;
      });

  void _elegirOrigen(int id) => setState(() {
        _origen = id;
        if (_destino == id) _destino = null;
        _destino ??= _unicoDestino();
        _errorServidor = null;
      });

  String _nombre(int? id) => _tienda(id)?.$1.nombre ?? '';

  String? get _problema => problemaTransferencia(
        cantidad: _cantidad,
        stockOrigen: _tienda(_origen)?.$2,
        hayDestino: _destino != null,
        origen: _nombre(_origen),
        soloEnteros: widget.soloEnteros,
      );

  Future<void> _enviar() async {
    final c = _cantidad;
    if (_problema != null || c == null) return;
    setState(() {
      _enviando = true;
      _errorServidor = null;
    });
    final err = await widget.onConfirmar(
        _origen!, _destino!, c, _notaCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _errorServidor = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _cantidad;
    final problema = _problema;
    final origen = _tienda(_origen);
    final destino = _tienda(_destino);
    // Se muestran solo los avisos de algo imposible; "elige a qué tienda"
    // o "escribe una cantidad" ya los dice el botón.
    final avisoCantidad = problema != null &&
        c != null &&
        origen != null &&
        destino != null;

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _C.turq,
          selectionHandleColor: _C.turq,
          selectionColor: _C.turq100,
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 14 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.turq50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  size: 22, color: _C.turq),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transferir', style: _f(size: 16.5, w: FontWeight.w800)),
                    Text(widget.producto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _f(size: 11.5, color: _C.gris)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),

          // Desde
          Text('DESDE', style: _seccion()),
          const SizedBox(height: 7),
          if (widget.origenFijo != null && origen != null)
            _filaTienda(origen.$1, origen.$2, fija: true)
          else
            for (final (t, s) in widget.tiendas)
              _filaTienda(t, s,
                  sel: _origen == t.id,
                  deshabilitada: s <= 0,
                  onTap: () => _elegirOrigen(t.id!)),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Center(
              child: Icon(Icons.south_rounded, size: 20, color: _C.turq),
            ),
          ),

          // Hacia
          Text('HACIA', style: _seccion()),
          const SizedBox(height: 7),
          for (final (t, s) in _destinos)
            _filaTienda(t, s,
                sel: _destino == t.id,
                onTap: () => setState(() {
                      _destino = t.id;
                      _errorServidor = null;
                    })),
          const SizedBox(height: 10),

          // Cantidad
          Text('CUÁNTAS UNIDADES', style: _seccion()),
          const SizedBox(height: 7),
          Row(children: [
            _paso(Icons.remove_rounded,
                _enviando || (c ?? 0) <= 0 ? null : () => _poner((c ?? 0) - 1)),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _cantCtrl,
                  enabled: !_enviando,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(
                      decimal: !widget.soloEnteros),
                  onChanged: (_) => setState(() => _errorServidor = null),
                  style: _f(size: 20, w: FontWeight.w800),
                  decoration: InputDecoration(
                    suffixText: 'uds',
                    suffixStyle:
                        _f(size: 12, w: FontWeight.w600, color: _C.gris),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: avisoCantidad ? _C.rojo : _C.turq,
                          width: 1.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: avisoCantidad ? _C.rojo : _C.turq,
                          width: 2.2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _C.borde),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _paso(Icons.add_rounded,
                _enviando ? null : () => _poner((c ?? 0) + 1)),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _enviando || origen == null || origen.$2 <= 0
                    ? null
                    : () => _poner(origen.$2.floorToDouble()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: _C.turq50,
                  side: const BorderSide(color: _C.turq100, width: 1.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Todo',
                    style: _f(size: 12.5, w: FontWeight.w800,
                        color: _C.turqOs)),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          if (avisoCantidad)
            _avisoRojo(problema)
          else if (c != null && origen != null && destino != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
              decoration: BoxDecoration(
                color: _C.turq50,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(children: [
                _lineaPrevia(origen.$1.nombre,
                    '${_cant(origen.$2)} → ${_cant(origen.$2 - c)}'),
                const SizedBox(height: 3),
                _lineaPrevia(destino.$1.nombre,
                    '${_cant(destino.$2)} → ${_cant(destino.$2 + c)}'),
              ]),
            ),
          if (_errorServidor != null) ...[
            const SizedBox(height: 8),
            _avisoRojo(_errorServidor!),
          ],
          const SizedBox(height: 10),

          TextField(
            controller: _notaCtrl,
            enabled: !_enviando,
            style: _f(size: 13),
            decoration: InputDecoration(
              hintText: 'Nota (opcional)',
              hintStyle: _f(size: 12.5, color: const Color(0xFF94A3B8)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.borde, width: 1.3),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.turq, width: 1.5),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.borde),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _enviando ? null : widget.onCerrar,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.grisClaro, width: 1.3),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Cancelar',
                      maxLines: 1,
                      style: _f(size: 14, w: FontWeight.w700,
                          color: const Color(0xFF334155))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: problema == null && !_enviando ? _enviar : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _C.turq,
                    disabledBackgroundColor: _C.turq.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          origen == null
                              ? 'Elige desde qué tienda'
                              : destino == null
                                  ? 'Elige a qué tienda'
                                  : c == null
                                      ? 'Escribe una cantidad'
                                      // El destino ya se ve marcado y en la
                                      // vista previa; con nombres largos no
                                      // cabría en el botón.
                                      : 'Enviar ${_cant(c)} unidad${c == 1 ? '' : 'es'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _f(size: 13.5, w: FontWeight.w800,
                              color: Colors.white)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _filaTienda(TiendaMovil t, double stock,
      {bool sel = false,
      bool fija = false,
      bool deshabilitada = false,
      VoidCallback? onTap}) {
    final activa = !fija && !deshabilitada && !_enviando;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: deshabilitada ? 0.45 : 1,
        child: Material(
          color: fija
              ? const Color(0xFFF8FAFC)
              : sel
                  ? _C.turq50
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: activa && !sel ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: fija
                        ? const Color(0xFFE2E8F0)
                        : sel
                            ? _C.turq
                            : _C.borde,
                    width: sel ? 1.6 : 1.3),
              ),
              child: Row(children: [
                if (fija)
                  const Icon(Icons.storefront_outlined,
                      size: 18, color: _C.gris)
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: sel ? _C.turq : _C.grisClaro,
                          width: sel ? 5.5 : 2),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _f(size: 13, w: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: stock > 0 ? _C.verde50 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      deshabilitada ? 'sin stock' : _cant(stock),
                      style: _f(size: 11.5, w: FontWeight.w800,
                          color: stock > 0
                              ? _C.verdeOs
                              : const Color(0xFF94A3B8))),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paso(IconData icono, VoidCallback? onTap) => SizedBox(
        width: 44,
        height: 48,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: _C.borde, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Icon(icono,
              size: 21, color: onTap == null ? _C.grisClaro : _C.turqOs),
        ),
      );

  Widget _lineaPrevia(String tienda, String cambio) => Row(children: [
        Expanded(
          child: Text(tienda,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _f(size: 12.5, w: FontWeight.w700, color: _C.turqOs)),
        ),
        const SizedBox(width: 8),
        Text(cambio, style: _f(size: 13.5, w: FontWeight.w800)),
      ]);

  Widget _avisoRojo(String texto) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
        decoration: BoxDecoration(
          color: _C.rojo50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.rojo100),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 16, color: _C.rojo),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(texto,
                style: _f(size: 12, w: FontWeight.w600, color: _C.rojo,
                    h: 1.3)),
          ),
        ]),
      );
}

/// Abre la hoja de transferir. [construir] recibe el cierre de la hoja.
Future<void> mostrarTransferirMovil(
  BuildContext context,
  TransferirMovil Function(VoidCallback cerrar) construir,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.94),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
              color: _C.grisClaro,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: construir(() => Navigator.pop(ctx))),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// FILTROS
// ══════════════════════════════════════════════════════════════
//
// Estado de stock, categoría, precio (con rangos de un toque) y orden.
// Al aplicar, los filtros quedan como chips sobre la lista (ver
// InventarioMovil.filtrosAplicados).

/// Un filtro activo que se muestra sobre la lista y se quita con su ✕.
class FiltroActivoMovil {
  final String       etiqueta;
  final VoidCallback quitar;
  const FiltroActivoMovil(this.etiqueta, this.quitar);
}

const ordenesInventario = {
  'nombre':      'Nombre A–Z',
  'stock':       'Menos stock',
  'precio_desc': 'Mayor precio',
  'precio_asc':  'Menor precio',
};

const alertasInventario = {
  'bajo':        'Stock bajo',
  'agotado':     'Agotados',
  'con_averias': 'Con averías',
};

/// Ordena en el celular (la lista ya está completa): sin volver a pedir.
List<Producto> ordenarProductos(List<Producto> ps, String orden) {
  int nombre(Producto a, Producto b) =>
      a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
  final l = List<Producto>.of(ps);
  switch (orden) {
    case 'stock':
      l.sort((a, b) {
        final c = a.stockActual.compareTo(b.stockActual);
        return c != 0 ? c : nombre(a, b);
      });
    case 'precio_desc':
      l.sort((a, b) {
        final c = b.precio.compareTo(a.precio);
        return c != 0 ? c : nombre(a, b);
      });
    case 'precio_asc':
      l.sort((a, b) {
        final c = a.precio.compareTo(b.precio);
        return c != 0 ? c : nombre(a, b);
      });
    default:
      l.sort(nombre);
  }
  return l;
}

/// "$20.000 – $50.000", "Hasta $20.000", "Desde $50.000".
String etiquetaPrecio(double? min, double? max) {
  String m(double v) => '${Constants.moneda}${_miles(v)}';
  if (min != null && max != null) return '${m(min)} – ${m(max)}';
  if (max != null) return 'Hasta ${m(max)}';
  if (min != null) return 'Desde ${m(min)}';
  return '';
}

/// Lee un precio escrito: "20.000", "$ 20.000", "20000". null si está
/// vacío; NaN si tiene texto que no es número.
double? leerPrecioFiltro(String t) {
  final s = t.trim();
  if (s.isEmpty) return null;
  if (!RegExp(r'\d').hasMatch(s)) return double.nan;
  return leerNumeroExcel(s);
}

/// Por qué no se puede aplicar el rango; null si está bien.
String? problemaPrecio(double? min, double? max) {
  if ((min?.isNaN ?? false) || (max?.isNaN ?? false)) {
    return 'Escribe el precio solo con números.';
  }
  if ((min ?? 0) < 0 || (max ?? 0) < 0) {
    return 'El precio no puede ser negativo.';
  }
  if (min != null && max != null && min > max) {
    return '“Desde” es mayor que “Hasta”.';
  }
  return null;
}

class FiltrosInventarioMovil {
  final String? alerta;
  final int?    categoriaId;
  final String? categoriaNombre;
  final double? precioMin;
  final double? precioMax;
  final String  orden;

  const FiltrosInventarioMovil({
    this.alerta,
    this.categoriaId,
    this.categoriaNombre,
    this.precioMin,
    this.precioMax,
    this.orden = 'nombre',
  });
}

class FiltrosMovil extends StatefulWidget {
  final FiltrosInventarioMovil inicial;
  final List<CategoriaMovil>   categorias;
  final ValueChanged<FiltrosInventarioMovil> onAplicar;
  final VoidCallback onCerrar;

  const FiltrosMovil({
    super.key,
    required this.inicial,
    required this.onAplicar,
    required this.onCerrar,
    this.categorias = const [],
  });

  @override
  State<FiltrosMovil> createState() => _FiltrosMovilState();
}

class _FiltrosMovilState extends State<FiltrosMovil> {
  late String? _alerta = widget.inicial.alerta;
  late int?    _categoria = widget.inicial.categoriaId;
  late String  _orden = widget.inicial.orden;
  late final _minCtrl = TextEditingController(
      text: widget.inicial.precioMin == null
          ? '' : _miles(widget.inicial.precioMin!));
  late final _maxCtrl = TextEditingController(
      text: widget.inicial.precioMax == null
          ? '' : _miles(widget.inicial.precioMax!));

  static const _rangos = <(double?, double?)>[
    (null, 20000),
    (20000, 50000),
    (50000, null),
  ];

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  double? get _min => leerPrecioFiltro(_minCtrl.text);
  double? get _max => leerPrecioFiltro(_maxCtrl.text);

  void _limpiar() => setState(() {
        _alerta = null;
        _categoria = null;
        _orden = 'nombre';
        _minCtrl.clear();
        _maxCtrl.clear();
      });

  void _aplicar() {
    String? nombre;
    for (final c in widget.categorias) {
      if (c.id == _categoria) nombre = c.nombre;
    }
    widget.onAplicar(FiltrosInventarioMovil(
      alerta: _alerta,
      categoriaId: _categoria,
      categoriaNombre: nombre,
      precioMin: _min,
      precioMax: _max,
      orden: _orden,
    ));
  }

  Widget _chip(String texto, bool sel, VoidCallback onTap) => Material(
        color: sel ? _C.verde : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: sel ? _C.verde : _C.borde, width: 1.3),
            ),
            child: Text(texto,
                style: _f(size: 12, w: FontWeight.w700,
                    color: sel ? Colors.white : const Color(0xFF334155))),
          ),
        ),
      );

  Widget _cuadro(String? valor, String texto, IconData icono, TonoMovil t) {
    final sel = _alerta == valor;
    return Expanded(
      child: Material(
        color: sel ? _C.verde50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _alerta = valor),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? _C.verde : _C.borde, width: sel ? 1.6 : 1.3),
            ),
            child: Row(children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: t.suave,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, size: 15, color: t.fuerte),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _f(size: 12.5, w: FontWeight.w700,
                        color: sel ? _C.verdeOs : _C.tinta)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _campoPrecio(String etiqueta, TextEditingController c, bool error) =>
      Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: _f(size: 14, w: FontWeight.w700),
          decoration: InputDecoration(
            labelText: etiqueta,
            labelStyle: _f(size: 12, color: _C.gris),
            prefixText: '${Constants.moneda} ',
            prefixStyle: _f(size: 14, w: FontWeight.w700),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error ? _C.rojo : _C.borde, width: 1.3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: error ? _C.rojo : _C.verde, width: 1.6),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final min = _min, max = _max;
    final problema = problemaPrecio(min, max);

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _C.verde,
          selectionHandleColor: _C.verde,
          selectionColor: _C.verde100,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 8 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Filtros', style: _f(size: 17, w: FontWeight.w800)),
                    const Spacer(),
                    TextButton(
                      onPressed: _limpiar,
                      child: Text('Limpiar todo',
                          style: _f(size: 12.5, w: FontWeight.w800,
                              color: _C.rojo)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('ESTADO DE STOCK', style: _seccion()),
                  const SizedBox(height: 8),
                  Row(children: [
                    _cuadro(null, 'Todos', Icons.inventory_2_outlined,
                        TonoMovil.gris),
                    const SizedBox(width: 6),
                    _cuadro('bajo', 'Stock bajo', Icons.trending_down_rounded,
                        TonoMovil.ambar),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    _cuadro('agotado', 'Agotados', Icons.cancel_outlined,
                        TonoMovil.rojo),
                    const SizedBox(width: 6),
                    _cuadro('con_averias', 'Con averías',
                        Icons.warning_amber_rounded, TonoMovil.ambar),
                  ]),
                  if (widget.categorias.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('CATEGORÍA', style: _seccion()),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _chip('Todas', _categoria == null,
                          () => setState(() => _categoria = null)),
                      for (final c in widget.categorias)
                        _chip(c.nombre, _categoria == c.id,
                            () => setState(() => _categoria = c.id)),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  Text('PRECIO DE VENTA', style: _seccion()),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (a, b) in _rangos)
                      _chip(etiquetaPrecio(a, b), min == a && max == b, () {
                        setState(() {
                          if (min == a && max == b) {
                            _minCtrl.clear();
                            _maxCtrl.clear();
                          } else {
                            _minCtrl.text = a == null ? '' : _miles(a);
                            _maxCtrl.text = b == null ? '' : _miles(b);
                          }
                        });
                      }),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _campoPrecio('Desde', _minCtrl, problema != null),
                    const SizedBox(width: 8),
                    _campoPrecio('Hasta', _maxCtrl, problema != null),
                  ]),
                  if (problema != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                      decoration: BoxDecoration(
                        color: _C.rojo50,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: _C.rojo100),
                      ),
                      child: Text(problema,
                          style: _f(size: 12, w: FontWeight.w600,
                              color: _C.rojo)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text('ORDENAR POR', style: _seccion()),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final e in ordenesInventario.entries)
                      _chip(e.value, _orden == e.key,
                          () => setState(() => _orden = e.key)),
                  ]),
                ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: widget.onCerrar,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.grisClaro, width: 1.3),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Cancelar',
                      maxLines: 1,
                      style: _f(size: 14, w: FontWeight.w700,
                          color: const Color(0xFF334155))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: problema == null ? _aplicar : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _C.verde,
                    disabledBackgroundColor: _C.verde.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Ver resultados',
                      maxLines: 1,
                      style: _f(size: 14, w: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Abre la hoja de filtros. [construir] recibe el cierre de la hoja.
Future<void> mostrarFiltrosMovil(
  BuildContext context,
  FiltrosMovil Function(VoidCallback cerrar) construir,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: _C.grisClaro,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: construir(() => Navigator.pop(ctx))),
        ]),
      ),
    ),
  );
}
