// lib/screens/compras/movil/nueva_orden_movil.dart
//
// Nueva orden de compra en el celular, por pasos:
//   ① proveedor y tiendas  ② productos (buscar, escanear, factura PDF o
//   crear nuevo, con su reparto por tienda)  ③ resumen, contado o crédito.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import 'compras_reglas.dart';
import 'orden_movil.dart' show botonVerde;

String _miles(num v) => v.round().toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
double? _leer(String t) {
  final d = t.replaceAll(RegExp(r'[^\d]'), '');
  return d.isEmpty ? null : double.tryParse(d);
}

const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Un producto de la orden mientras se arma.
class FilaOrden {
  final int? producto;
  String nombre;
  String codigo;
  String categoria;
  double costo;
  double? precioVenta;
  /// tiendaId → cantidad.
  final Map<int, double> reparto;

  FilaOrden({this.producto, required this.nombre, this.codigo = '', this.categoria = '',
      this.costo = 0, this.precioVenta, Map<int, double>? reparto})
      : reparto = reparto ?? {};

  bool get nueva => producto == null;
  double get cantidad => reparto.values.fold(0, (a, b) => a + b);
  double get subtotal => cantidad * costo;
}

/// Por qué no se puede seguir en cada paso; null si se puede.
String? problemaPaso(int paso, {int? proveedor, required Set<int> tiendas,
    required List<FilaOrden> filas, bool credito = false, DateTime? vence}) {
  if (paso == 1) {
    if (proveedor == null) return 'Elige el proveedor.';
    if (tiendas.isEmpty) return 'Elige al menos una tienda.';
    return null;
  }
  if (paso == 2) {
    if (filas.isEmpty) return 'Agrega al menos un producto.';
    for (final f in filas) {
      if (f.nombre.trim().isEmpty) return 'Escribe el nombre del producto nuevo.';
      if (f.cantidad <= 0) return '${f.nombre}: escribe la cantidad.';
      if (f.costo <= 0) return '${f.nombre}: escribe el costo.';
    }
    return null;
  }
  if (credito && vence == null) return 'Elige la fecha para pagarle.';
  return null;
}

/// Lo que se manda al servidor para crear la orden.
Map<String, dynamic> cuerpoOrden({required int proveedor, required Set<int> tiendas,
    required List<FilaOrden> filas, required bool credito, DateTime? vence, String obs = ''}) {
  final una = tiendas.length == 1;
  return {
    if (una) 'tienda': tiendas.first,
    'proveedor': proveedor,
    'observaciones': obs.trim(),
    'a_credito': credito,
    if (credito && vence != null)
      'fecha_vencimiento': '${vence.year}-${vence.month.toString().padLeft(2, '0')}-${vence.day.toString().padLeft(2, '0')}',
    'detalles': [
      for (final f in filas)
        {
          'producto': f.producto,
          'nombre_libre': f.nueva ? f.nombre.trim() : '',
          'codigo_barras_input': f.codigo.trim(),
          'categoria_nombre_input': f.nueva ? f.categoria.trim() : '',
          'cantidad': f.cantidad,
          'precio_unitario': f.costo,
          if ((f.precioVenta ?? 0) > 0) 'precio_venta': f.precioVenta,
          if (!una)
            'distribuciones': [
              for (final e in f.reparto.entries)
                if (e.value > 0 && tiendas.contains(e.key)) {'tienda': e.key, 'cantidad': e.value},
            ],
        },
    ],
  };
}

class NuevaOrdenMovil extends StatefulWidget {
  final List<Map<String, dynamic>> proveedores; // id, nombre, nit
  final List<Map<String, dynamic>> tiendas;     // id, nombre
  final List<String> categorias;
  /// Si el usuario no elige tienda (supervisor), la suya.
  final int? tiendaFija;
  final Future<List<Map<String, dynamic>>> Function(String q) buscar;
  final Future<String?> Function()? escanear;
  /// Lee la factura PDF; devuelve filas con producto, nombre, cantidad,
  /// precio_unitario, precio_venta, categoria_nombre, codigo_barras_input.
  final Future<List<Map<String, dynamic>>?> Function()? factura;
  final Future<String?> Function(Map<String, dynamic> cuerpo) onCrear;
  final DateTime hoy;

  const NuevaOrdenMovil({super.key, required this.proveedores, required this.tiendas,
      required this.buscar, required this.onCrear, required this.hoy, this.categorias = const [],
      this.tiendaFija, this.escanear, this.factura});

  @override
  State<NuevaOrdenMovil> createState() => _NuevaOrdenMovilState();
}

class _NuevaOrdenMovilState extends State<NuevaOrdenMovil> {
  int _paso = 1;
  int? _proveedor;
  late final Set<int> _tiendas = {
    if (widget.tiendaFija != null) widget.tiendaFija!
    else if (widget.tiendas.length == 1) widget.tiendas.first['id'] as int,
  };
  final List<FilaOrden> _filas = [];
  bool _credito = false;
  int? _plazo;
  DateTime? _vence;
  final _obs = TextEditingController();
  bool _guardando = false, _trabajando = false;
  String? _error;

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  String get _nombreProveedor =>
      '${widget.proveedores.where((p) => p['id'] == _proveedor).firstOrNull?['nombre'] ?? ''}';
  String _nombreTienda(int id) =>
      '${widget.tiendas.where((t) => t['id'] == id).firstOrNull?['nombre'] ?? 'Tienda'}';
  List<int> get _tiendasOrden => [for (final t in widget.tiendas) if (_tiendas.contains(t['id'])) t['id'] as int];
  double get _total => _filas.fold(0, (a, f) => a + f.subtotal);

  void _siguiente() {
    final p = problemaPaso(_paso, proveedor: _proveedor, tiendas: _tiendas, filas: _filas,
        credito: _credito, vence: _vence);
    if (p != null) return setState(() => _error = p);
    if (_paso < 3) {
      setState(() {
        _paso++;
        _error = null;
      });
      return;
    }
    _crear();
  }

  Future<void> _crear() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final e = await widget.onCrear(cuerpoOrden(proveedor: _proveedor!, tiendas: _tiendas, filas: _filas,
        credito: _credito, vence: _vence, obs: _obs.text));
    if (mounted) {
      setState(() {
        _guardando = false;
        _error = e;
      });
    }
  }

  void _agregar(FilaOrden f) {
    final existe = f.producto == null ? null : _filas.where((x) => x.producto == f.producto).firstOrNull;
    setState(() {
      if (existe != null) {
        final t = _tiendasOrden.first;
        existe.reparto[t] = (existe.reparto[t] ?? 0) + 1;
      } else {
        // El producto nuevo llega con la cantidad sin tienda (-1): va a la primera.
        final sinTienda = f.reparto.remove(-1);
        if (sinTienda != null) f.reparto[_tiendasOrden.first] = sinTienda;
        if (f.reparto.isEmpty) f.reparto[_tiendasOrden.first] = 1;
        _filas.add(f);
      }
      _error = null;
    });
  }

  FilaOrden _deProducto(Map<String, dynamic> p) => FilaOrden(
        producto: p['id'] as int?,
        nombre: '${p['nombre'] ?? ''}',
        codigo: '${p['codigo_barras'] ?? ''}',
        costo: numDe(p['precio_compra']),
      );

  // ── Agregar productos ─────────────────────────────────────

  Future<void> _buscarProducto() async {
    final p = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaBuscar(buscar: widget.buscar),
    );
    if (p != null) _agregar(_deProducto(p));
  }

  Future<void> _escanear() async {
    final codigo = await widget.escanear?.call();
    if (codigo == null || codigo.isEmpty || !mounted) return;
    setState(() => _trabajando = true);
    final r = await widget.buscar(codigo);
    if (!mounted) return;
    setState(() => _trabajando = false);
    final exacto = r.where((p) => '${p['codigo_barras']}' == codigo).firstOrNull ?? r.firstOrNull;
    if (exacto != null) {
      _agregar(_deProducto(exacto));
    } else {
      await _crearProducto(codigo: codigo, aviso: 'No existe un producto con el código $codigo. Créalo:');
    }
  }

  Future<void> _factura() async {
    setState(() => _trabajando = true);
    final filas = await widget.factura?.call();
    if (!mounted) return;
    setState(() => _trabajando = false);
    if (filas == null || filas.isEmpty) return;
    for (final d in filas) {
      _agregar(FilaOrden(
        producto: d['producto'] as int?,
        nombre: '${d['nombre'] ?? ''}',
        codigo: '${d['codigo_barras_input'] ?? ''}',
        categoria: '${d['categoria_nombre'] ?? ''}',
        costo: numDe(d['precio_unitario']),
        precioVenta: numDe(d['precio_venta']) > 0 ? numDe(d['precio_venta']) : null,
        reparto: {_tiendasOrden.first: numDe(d['cantidad']) > 0 ? numDe(d['cantidad']) : 1},
      ));
    }
  }

  Future<void> _crearProducto({String codigo = '', String? aviso}) async {
    final f = await showModalBottomSheet<FilaOrden>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _HojaProductoNuevo(codigo: codigo, aviso: aviso, categorias: widget.categorias),
      ),
    );
    if (f != null) _agregar(f);
  }

  // ── Armar ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final titulos = ['Proveedor', 'Productos', 'Resumen'];
    return PopScope(
      canPop: _paso == 1,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) setState(() => _paso--);
      },
      child: Scaffold(
        backgroundColor: CM.fondo,
        appBar: AppBar(
          backgroundColor: Colors.white, surfaceTintColor: Colors.white, foregroundColor: CM.verdeOs,
          leading: IconButton(
            tooltip: _paso == 1 ? 'Cerrar' : 'Atrás',
            icon: Icon(_paso == 1 ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: () => _paso == 1 ? Navigator.maybePop(context) : setState(() => _paso--),
          ),
          titleSpacing: 0,
          title: Text('Nueva orden', style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
          actions: [
            if (_proveedor != null && _paso > 1)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(_nombreProveedor, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: cf(size: 12, color: CM.gris2)),
                )),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                for (var i = 1; i <= 3; i++) ...[
                  _paso_(i, titulos[i - 1]),
                  if (i < 3) Expanded(child: Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: CM.borde)),
                ],
              ]),
            ),
          ),
        ),
        body: switch (_paso) {
          1 => _paso1(),
          2 => _paso2(),
          _ => _paso3(),
        },
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CM.borde))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null)
                Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: cf(size: 12.5, w: FontWeight.w700, color: CM.rojo))),
              if (_paso >= 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(child: Text('${_filas.length} producto${_filas.length == 1 ? '' : 's'} · '
                        '${_miles(_filas.fold<double>(0, (a, f) => a + f.cantidad))} unidades',
                        style: cf(size: 12.5, color: CM.gris))),
                    Text(pesosCO(_total), style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
                  ]),
                ),
              FilledButton(
                onPressed: _guardando ? null : _siguiente,
                style: botonVerde(),
                child: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(switch (_paso) { 1 => 'Siguiente: productos', 2 => 'Siguiente: resumen', _ => 'Crear orden y sacar PDF' },
                        style: cf(size: 14, w: FontWeight.w800, color: Colors.white)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ignore: non_constant_identifier_names
  Widget _paso_(int i, String t) {
    final on = i == _paso, ok = i < _paso;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 22, height: 22, alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? CM.verde : ok ? CM.borde : Colors.white,
          border: Border.all(color: on ? CM.verde : ok ? CM.borde2 : const Color(0xFFCBD5E1), width: 1.5),
        ),
        child: ok ? const Icon(Icons.check_rounded, size: 14, color: CM.verdeOs)
            : Text('$i', style: cf(size: 11, w: FontWeight.w800, color: on ? Colors.white : CM.gris2)),
      ),
      const SizedBox(width: 5),
      Text(t, style: cf(size: 11.5, w: FontWeight.w700, color: on || ok ? CM.verdeOs : CM.gris2)),
    ]);
  }

  Widget _seccion(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(t.toUpperCase(), style: cf(size: 10.5, w: FontWeight.w800, color: CM.verdeOs, ls: .8)),
      );

  Widget _opcion(String t, String? sub, bool on, VoidCallback f, {bool radio = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: on ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: f,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? CM.verde : const Color(0xFFE2E8F0), width: 1.5)),
              child: Row(children: [
                Icon(radio
                        ? (on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded)
                        : (on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
                    size: 20, color: on ? CM.verde : const Color(0xFFCBD5E1)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: cf(size: 13.5, w: FontWeight.w700)),
                  if (sub != null && sub.isNotEmpty) Text(sub, style: cf(size: 11.5, color: CM.gris2)),
                ])),
              ]),
            ),
          ),
        ),
      );

  // ① Proveedor y tiendas
  Widget _paso1() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          _seccion('Proveedor'),
          if (widget.proveedores.isEmpty)
            Text('No hay proveedores. Créalo primero en la pestaña Proveedores.',
                style: cf(size: 13, color: CM.gris))
          else
            for (final p in widget.proveedores)
              _opcion('${p['nombre']}', '${p['nit'] ?? ''}'.isEmpty ? null : 'NIT ${p['nit']}',
                  _proveedor == p['id'], () => setState(() {
                    _proveedor = p['id'] as int;
                    _error = null;
                  })),
          if (widget.tiendaFija == null && widget.tiendas.length > 1) ...[
            const SizedBox(height: 8),
            _seccion('¿A qué tiendas llega?'),
            for (final t in widget.tiendas)
              _opcion('${t['nombre']}', null, _tiendas.contains(t['id']), () => setState(() {
                final id = t['id'] as int;
                _tiendas.contains(id) ? _tiendas.remove(id) : _tiendas.add(id);
                _error = null;
              }), radio: false),
            Text('Si eliges varias, en cada producto dices cuánto va a cada tienda.',
                style: cf(size: 11.5, color: CM.gris2)),
          ],
        ],
      );

  // ② Productos
  Widget _paso2() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          Row(children: [
            _agregarBtn(Icons.search_rounded, 'Buscar', _buscarProducto),
            if (widget.escanear != null) ...[const SizedBox(width: 6), _agregarBtn(Icons.qr_code_scanner_rounded, 'Escanear', _escanear)],
            if (widget.factura != null) ...[const SizedBox(width: 6), _agregarBtn(Icons.picture_as_pdf_outlined, 'Factura PDF', _factura)],
          ]),
          if (_trabajando)
            const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(color: CM.verde)),
          const SizedBox(height: 10),
          for (final (i, f) in _filas.indexed) ...[_tarjetaFila(i, f), const SizedBox(height: 8)],
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _crearProducto(),
              child: Container(
                height: 46,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CM.borde2, width: 1.5)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_rounded, color: CM.verdeOs, size: 19),
                  const SizedBox(width: 6),
                  Text('Crear producto nuevo', style: cf(size: 13, w: FontWeight.w800, color: CM.verdeOs)),
                ]),
              ),
            ),
          ),
        ],
      );

  Widget _agregarBtn(IconData i, String t, VoidCallback f) => Expanded(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _trabajando ? null : f,
            child: Container(
              height: 58,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CM.borde2, width: 1.5)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, size: 20, color: CM.verdeOs),
                const SizedBox(height: 2),
                Text(t, style: cf(size: 11.5, w: FontWeight.w800, color: CM.verdeOs)),
              ]),
            ),
          ),
        ),
      );

  Widget _tarjetaFila(int i, FilaOrden f) {
    final tiendas = _tiendasOrden;
    Widget numero(String etiqueta, double valor, ValueChanged<double> cambio, {bool pesos = false}) =>
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: cf(size: 10.5, w: FontWeight.w600, color: CM.gris2)),
            const SizedBox(height: 3),
            TextFormField(
              key: ValueKey('$i-$etiqueta-${f.nombre}'),
              initialValue: valor > 0 ? _miles(valor) : '',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (t) => setState(() => cambio(_leer(t) ?? 0)),
              style: cf(size: 13.5, w: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true, hintText: '0',
                prefixText: pesos ? r'$ ' : null,
                prefixStyle: cf(size: 12.5, w: FontWeight.w700, color: CM.gris2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: CM.borde, width: 1.4)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: CM.verde, width: 1.6)),
              ),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CM.borde, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: f.nombre, style: cf(size: 13, w: FontWeight.w800)),
                if (f.nueva) TextSpan(text: '  nuevo', style: cf(size: 11, w: FontWeight.w800, color: CM.ambar)),
              ])),
              if (f.codigo.isNotEmpty || f.categoria.isNotEmpty)
                Text([if (f.codigo.isNotEmpty) f.codigo, if (f.categoria.isNotEmpty) f.categoria].join(' · '),
                    style: cf(size: 11, color: CM.gris2)),
            ]),
          ),
          IconButton(
            tooltip: 'Quitar ${f.nombre}',
            onPressed: () => setState(() => _filas.removeAt(i)),
            icon: const Icon(Icons.close_rounded, size: 19, color: CM.gris2),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (tiendas.length == 1)
              numero('Cantidad', f.reparto[tiendas.first] ?? 0, (v) => f.reparto[tiendas.first] = v)
            else
              for (final (j, t) in tiendas.indexed) ...[
                if (j > 0) const SizedBox(width: 6),
                numero(_nombreTienda(t), f.reparto[t] ?? 0, (v) => f.reparto[t] = v),
              ],
            const SizedBox(width: 6),
            numero('Costo c/u', f.costo, (v) => f.costo = v, pesos: true),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(children: [
            if (tiendas.length > 1)
              Text('Total ${_miles(f.cantidad)} u.', style: cf(size: 11.5, w: FontWeight.w700, color: CM.gris)),
            const Spacer(),
            Text('Subtotal ', style: cf(size: 11.5, color: CM.gris2)),
            Text(pesosCO(f.subtotal), style: cf(size: 13, w: FontWeight.w800, color: CM.oscuro)),
          ]),
        ),
      ]),
    );
  }

  // ③ Resumen
  Widget _paso3() {
    Widget fila(String k, String v, {bool b = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: cf(size: 13, color: CM.gris)),
            const SizedBox(width: 12),
            Expanded(child: Text(v, textAlign: TextAlign.right,
                style: cf(size: b ? 15 : 13, w: FontWeight.w800, color: b ? CM.oscuro : CM.tinta))),
          ]),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CM.borde, width: 1.5)),
          child: Column(children: [
            fila('Proveedor', _nombreProveedor),
            fila('Llega a', _tiendasOrden.map(_nombreTienda).join(' · ')),
            fila('Productos', '${_filas.length} (${_miles(_filas.fold<double>(0, (a, f) => a + f.cantidad))} unidades)'),
            const Divider(color: CM.borde),
            fila('Total', pesosCO(_total), b: true),
          ]),
        ),
        const SizedBox(height: 6),
        _seccion('¿Cómo se le paga?'),
        Row(children: [
          Expanded(child: _opcion('De contado', 'Se paga al recibir', !_credito,
              () => setState(() => _credito = false))),
          const SizedBox(width: 8),
          Expanded(child: _opcion('A crédito', 'Se paga después', _credito, () => setState(() {
            _credito = true;
            _plazo ??= 30;
            _vence ??= widget.hoy.add(const Duration(days: 30));
          }))),
        ]),
        if (_credito) ...[
          const SizedBox(height: 4),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final f = await showDatePicker(
                  context: context, initialDate: _vence ?? widget.hoy.add(const Duration(days: 30)),
                  firstDate: widget.hoy, lastDate: widget.hoy.add(const Duration(days: 365)),
                  helpText: 'Fecha para pagarle', cancelText: 'Cancelar', confirmText: 'Listo',
                );
                if (f != null) setState(() {
                  _vence = f;
                  _plazo = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CM.borde2, width: 1.5)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: CM.verdeOs),
                  const SizedBox(width: 8),
                  Text('Pagarle el ', style: cf(size: 13, color: CM.gris)),
                  Text(_vence == null ? 'elegir fecha' : '${_vence!.day} ${_meses[_vence!.month]} ${_vence!.year}',
                      style: cf(size: 13, w: FontWeight.w800)),
                  const Spacer(),
                  if (_vence != null)
                    Text('a ${_vence!.difference(DateTime(widget.hoy.year, widget.hoy.month, widget.hoy.day)).inDays} días',
                        style: cf(size: 11.5, color: CM.gris2)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final d in [15, 30, 45, 60])
              ChoiceChip(
                label: Text('$d días'),
                selected: _plazo == d,
                showCheckmark: false,
                selectedColor: CM.verde,
                backgroundColor: Colors.white,
                side: BorderSide(color: _plazo == d ? CM.verde : CM.borde),
                labelStyle: cf(size: 12, w: FontWeight.w700, color: _plazo == d ? Colors.white : const Color(0xFF334155)),
                onSelected: (_) => setState(() {
                  _plazo = d;
                  _vence = DateTime(widget.hoy.year, widget.hoy.month, widget.hoy.day).add(Duration(days: d));
                }),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _obs,
          minLines: 1, maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: cf(size: 13.5),
          decoration: InputDecoration(
            labelText: 'Observaciones (opcional)', isDense: true,
            labelStyle: cf(size: 12, color: CM.gris),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CM.borde, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CM.verde, width: 1.6)),
          ),
        ),
        const SizedBox(height: 10),
        Text(_credito
            ? 'Queda en Por pagar; el gasto se registra cuando se le pague.'
            : 'Al recibirla se registra el pago (efectivo o cuenta) como gasto.',
            style: cf(size: 12, color: CM.gris)),
      ],
    );
  }
}

// ── Hoja: buscar producto ─────────────────────────────────────

class _HojaBuscar extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(String q) buscar;
  const _HojaBuscar({required this.buscar});

  @override
  State<_HojaBuscar> createState() => _HojaBuscarState();
}

class _HojaBuscarState extends State<_HojaBuscar> {
  final _ctrl = TextEditingController();
  Timer? _espera;
  List<Map<String, dynamic>> _r = const [];
  bool _buscando = false;
  int _n = 0;

  @override
  void dispose() {
    _espera?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _cambio(String q) {
    _espera?.cancel();
    if (q.trim().length < 2) return setState(() => _r = const []);
    _espera = Timer(const Duration(milliseconds: 350), () async {
      final id = ++_n;
      setState(() => _buscando = true);
      final r = await widget.buscar(q.trim());
      if (!mounted || id != _n) return;
      setState(() {
        _r = r;
        _buscando = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _cambio,
              style: cf(size: 14),
              decoration: InputDecoration(
                hintText: 'Nombre o código del producto',
                hintStyle: cf(size: 13, color: CM.gris2),
                prefixIcon: const Icon(Icons.search_rounded, color: CM.gris2),
                isDense: true,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CM.borde, width: 1.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CM.verde, width: 1.6)),
              ),
            ),
            if (_buscando) const LinearProgressIndicator(minHeight: 2, color: CM.verde),
            Flexible(
              child: _r.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(_ctrl.text.trim().length < 2 ? 'Escribe al menos 2 letras.'
                          : _buscando ? 'Buscando…' : 'No se encontró. Créalo como producto nuevo.',
                          textAlign: TextAlign.center, style: cf(size: 13, color: CM.gris)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: _r.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: CM.borde),
                      itemBuilder: (_, i) {
                        final p = _r[i];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          title: Text('${p['nombre'] ?? ''}', style: cf(size: 13.5, w: FontWeight.w700)),
                          subtitle: Text([
                            if ('${p['codigo_barras'] ?? ''}'.isNotEmpty) '${p['codigo_barras']}',
                            if (numDe(p['precio_compra']) > 0) 'costo ${pesosCO(numDe(p['precio_compra']))}',
                          ].join(' · '), style: cf(size: 11.5, color: CM.gris2)),
                          trailing: const Icon(Icons.add_circle_outline_rounded, color: CM.verde),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ]),
        ),
      );
}

// ── Hoja: producto nuevo ──────────────────────────────────────

class _HojaProductoNuevo extends StatefulWidget {
  final String codigo;
  final String? aviso;
  final List<String> categorias;
  const _HojaProductoNuevo({this.codigo = '', this.aviso, this.categorias = const []});

  @override
  State<_HojaProductoNuevo> createState() => _HojaProductoNuevoState();
}

class _HojaProductoNuevoState extends State<_HojaProductoNuevo> {
  final _nombre = TextEditingController();
  late final _codigo = TextEditingController(text: widget.codigo);
  final _categoria = TextEditingController();
  final _costo = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _codigo, _categoria, _costo, _cantidad]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _deco(String t, {String? prefijo}) => InputDecoration(
        labelText: t, isDense: true, prefixText: prefijo,
        labelStyle: cf(size: 12, color: CM.gris),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: CM.borde, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: CM.verde, width: 1.6)),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
              Text('Producto nuevo', style: cf(size: 17, w: FontWeight.w800)),
              Text(widget.aviso ?? 'Se crea en el inventario cuando llegue la mercancía.',
                  style: cf(size: 12, color: CM.gris)),
              const SizedBox(height: 12),
              TextField(controller: _nombre, autofocus: true, textCapitalization: TextCapitalization.sentences,
                  style: cf(size: 14, w: FontWeight.w700), decoration: _deco('Nombre *')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _codigo, style: cf(size: 13.5),
                    decoration: _deco('Código de barras'))),
                const SizedBox(width: 8),
                Expanded(child: Autocomplete<String>(
                  optionsBuilder: (v) => widget.categorias
                      .where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
                  onSelected: (v) => _categoria.text = v,
                  fieldViewBuilder: (ctx, ctrl, foco, _) => TextField(
                    controller: ctrl, focusNode: foco, style: cf(size: 13.5),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (v) => _categoria.text = v,
                    decoration: _deco('Categoría'),
                  ),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _cantidad, keyboardType: TextInputType.number,
                    style: cf(size: 13.5, w: FontWeight.w700), decoration: _deco('Cantidad'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _costo, keyboardType: TextInputType.number,
                    style: cf(size: 13.5, w: FontWeight.w700), decoration: _deco('Costo c/u', prefijo: r'$ '))),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: cf(size: 12.5, w: FontWeight.w700, color: CM.rojo)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final costo = _leer(_costo.text) ?? 0;
                  final cant = _leer(_cantidad.text) ?? 0;
                  if (_nombre.text.trim().isEmpty) return setState(() => _error = 'Escribe el nombre.');
                  if (cant <= 0) return setState(() => _error = 'Escribe la cantidad.');
                  if (costo <= 0) return setState(() => _error = 'Escribe el costo.');
                  Navigator.pop(context, FilaOrden(
                    nombre: _nombre.text.trim(), codigo: _codigo.text.trim(),
                    categoria: _categoria.text.trim(), costo: costo,
                    reparto: {-1: cant},
                  ));
                },
                style: botonVerde(),
                child: Text('Agregar a la orden', style: cf(size: 14, w: FontWeight.w800, color: Colors.white)),
              ),
            ]),
          ),
        ),
      );
}

// ── Escáner con la cámara ─────────────────────────────────────

/// Abre la cámara y devuelve el primer código que lee.
Future<String?> escanearConCamara(BuildContext context) => Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _Escaner()),
    );

class _Escaner extends StatefulWidget {
  const _Escaner();

  @override
  State<_Escaner> createState() => _EscanerState();
}

class _EscanerState extends State<_Escaner> {
  bool _listo = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black, foregroundColor: Colors.white,
          title: Text('Escanear código', style: cf(size: 16, w: FontWeight.w700, color: Colors.white)),
        ),
        body: Stack(children: [
          MobileScanner(
            onDetect: (captura) {
              if (_listo) return;
              final v = captura.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
              if (v == null || v.isEmpty) return;
              _listo = true;
              HapticFeedback.mediumImpact();
              Navigator.pop(context, v);
            },
            errorBuilder: (_, e) => Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text('No se pudo abrir la cámara. Revisa el permiso de cámara de la app.',
                    textAlign: TextAlign.center, style: cf(size: 14, color: Colors.white)),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260, height: 160,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2.5),
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 40,
              child: Text('Apunta al código de barras', textAlign: TextAlign.center,
                  style: cf(size: 14, w: FontWeight.w600, color: Colors.white))),
        ]),
      );
}
