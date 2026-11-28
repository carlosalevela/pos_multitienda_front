// lib/screens/separados/movil/nuevo_separado_movil.dart
//
// Nuevo separado en el celular, en 3 pasos:
//   ① el cliente (buscar o crear)
//   ② los productos (buscar o escanear)
//   ③ hasta cuándo se guarda y el abono inicial
// No habla con el servidor: usa los servicios que le pasan (así se prueba).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/cliente.dart';
import '../../../models/cuenta_bancaria.dart';
import '../../../models/producto.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO, telefonoBonito;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import 'hojas_separado_movil.dart';
import 'separados_movil.dart';
import 'separados_reglas.dart';

class LineaSep {
  final Producto producto;
  double cantidad;
  LineaSep(this.producto, {this.cantidad = 1});
  double get subtotal => producto.precio * cantidad;
}

class PedidoSeparado {
  final Cliente cliente;
  final List<LineaSep> lineas;
  final DateTime fecha;
  final double abono;
  final String metodo;
  final int? cuentaId;
  final bool imprimir;
  const PedidoSeparado({required this.cliente, required this.lineas, required this.fecha,
      required this.abono, required this.metodo, this.cuentaId, this.imprimir = true});

  double get total => lineas.fold(0, (s, l) => s + l.subtotal);

  Map<String, dynamic> datos(int tiendaId) => {
        'tienda': tiendaId,
        'cliente': cliente.id,
        'fecha_limite': fechaApi(fecha),
        'detalles': [
          for (final l in lineas)
            {'producto': l.producto.id, 'cantidad': l.cantidad, 'precio_unitario': l.producto.precio},
        ],
        'abono_inicial': abono,
        'metodo_pago': metodo,
        if (metodo != 'efectivo' && cuentaId != null) 'cuenta_destino': cuentaId,
      };
}

class ServiciosNuevoSep {
  final Future<List<Cliente>> Function(String q) buscarClientes;
  /// Abre el formulario de cliente; devuelve el creado o null.
  final Future<Cliente?> Function(BuildContext context) crearCliente;
  final Future<List<Producto>> Function(String q) buscarProductos;
  final Future<String?> Function(BuildContext context) escanear;
  /// null si quedó creado; si no, el error para mostrar.
  final Future<String?> Function(PedidoSeparado p) crear;

  const ServiciosNuevoSep({
    required this.buscarClientes,
    required this.crearCliente,
    required this.buscarProductos,
    required this.escanear,
    required this.crear,
  });
}

class NuevoSeparadoMovil extends StatefulWidget {
  final ServiciosNuevoSep servicios;
  final List<CuentaBancaria> cuentas;
  final bool? cajaAbierta;
  final Cliente? clienteInicial;
  final DateTime? hoy;

  const NuevoSeparadoMovil({super.key, required this.servicios, this.cuentas = const [], this.cajaAbierta,
      this.clienteInicial, this.hoy});

  @override
  State<NuevoSeparadoMovil> createState() => _NuevoSeparadoMovilState();
}

class _NuevoSeparadoMovilState extends State<NuevoSeparadoMovil> {
  late int _paso = widget.clienteInicial == null ? 1 : 2;
  bool _ocupado = false;

  // ①
  final _qCliente = TextEditingController();
  List<Cliente> _clientes = [];
  bool _buscandoClientes = false;
  late Cliente? _cliente = widget.clienteInicial;
  Timer? _espera;
  int _pedido = 0;

  // ②
  final List<LineaSep> _lineas = [];

  // ③
  int? _plazo = 30;
  late DateTime _fecha = fechaPlazo(_hoy, 30);
  final _abono = TextEditingController();
  late String _metodo = widget.cajaAbierta == false ? 'transferencia' : 'efectivo';
  int? _cuenta;
  bool _imprimir = true;

  DateTime get _hoy => widget.hoy ?? DateTime.now();
  double get _total => _lineas.fold(0, (s, l) => s + l.subtotal);
  double get _abonoValor => leerPesosSep(_abono.text);

  @override
  void initState() {
    super.initState();
    _ponerCuenta();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _qCliente.dispose();
    _abono.dispose();
    super.dispose();
  }

  void _ponerCuenta() {
    final l = cuentasDeMetodo(widget.cuentas, _metodo);
    _cuenta = l.length == 1 ? l.first.id : null;
  }

  // ── ① ──

  void _cambioCliente(String t) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 300), () => _buscarClientes(t));
    setState(() {});
  }

  Future<void> _buscarClientes(String t) async {
    final q = t.trim();
    if (q.length < 2) {
      setState(() => _clientes = []);
      return;
    }
    final n = ++_pedido;
    setState(() => _buscandoClientes = true);
    final l = await widget.servicios.buscarClientes(q);
    if (!mounted || n != _pedido) return;
    setState(() {
      _clientes = l;
      _buscandoClientes = false;
    });
  }

  void _elegirCliente(Cliente c) => setState(() {
        _cliente = c;
        _paso = 2;
      });

  Future<void> _nuevoCliente() async {
    final c = await widget.servicios.crearCliente(context);
    if (c != null && mounted) _elegirCliente(c);
  }

  // ── ② ──

  void _agregar(Producto p) {
    final i = _lineas.indexWhere((l) => l.producto.id == p.id);
    setState(() {
      if (p.stockActual <= 0) {
        avisoSep(context, '${p.nombre} no tiene stock en esta tienda.');
      } else if (i >= 0) {
        if (_lineas[i].cantidad < p.stockActual) {
          _lineas[i].cantidad++;
        } else {
          avisoSep(context, 'De ${p.nombre} quedan ${cantidadTexto(p.stockActual)}.');
        }
      } else {
        _lineas.add(LineaSep(p));
      }
    });
  }

  Future<void> _buscarProducto() async {
    final p = await abrirHojaSep<Producto>(context, _HojaProductos(buscar: widget.servicios.buscarProductos));
    if (p != null && mounted) _agregar(p);
  }

  Future<void> _escanearProducto() async {
    final c = await widget.servicios.escanear(context);
    if (c == null || c.trim().isEmpty || !mounted) return;
    setState(() => _ocupado = true);
    final l = await widget.servicios.buscarProductos(c.trim());
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (l.isEmpty) {
      avisoSep(context, 'Ningún producto con el código "$c".');
    } else if (l.length == 1) {
      _agregar(l.first);
    } else {
      final p = await abrirHojaSep<Producto>(context,
          _HojaProductos(buscar: widget.servicios.buscarProductos, inicial: c.trim(), resultados: l));
      if (p != null && mounted) _agregar(p);
    }
  }

  // ── ③ ──

  Future<void> _otraFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: soloDia(_hoy),
      lastDate: soloDia(_hoy).add(const Duration(days: 365)),
    );
    if (f != null && mounted) {
      setState(() {
        _fecha = f;
        _plazo = null;
      });
    }
  }

  bool get _faltaCuenta =>
      _metodo != 'efectivo' && _cuenta == null && cuentasDeMetodo(widget.cuentas, _metodo).isNotEmpty;

  Future<void> _crear() async {
    final e = problemaNuevo(3, fecha: _fecha, abono: _abonoValor, total: _total, hoy: _hoy,
        metodo: _metodo, cajaAbierta: widget.cajaAbierta, faltaCuenta: _faltaCuenta);
    if (e != null) {
      avisoSep(context, e);
      return;
    }
    setState(() => _ocupado = true);
    final error = await widget.servicios.crear(PedidoSeparado(
      cliente: _cliente!, lineas: _lineas, fecha: _fecha, abono: _abonoValor, metodo: _metodo,
      cuentaId: _metodo == 'efectivo' ? null : _cuenta, imprimir: _imprimir,
    ));
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (error != null) avisoSep(context, error);
  }

  // ── Navegación ──

  void _siguiente() {
    final e = problemaNuevo(_paso, cliente: _cliente, productos: _lineas.length);
    if (e != null) {
      avisoSep(context, e);
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _paso++);
  }

  void _atras() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (_paso <= 1 || (_paso == 2 && widget.clienteInicial != null)) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _paso--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primero = _paso == 1 || (_paso == 2 && widget.clienteInicial != null);
    final sub = _cliente == null || _paso == 1
        ? null
        : _paso == 3 ? '${_cliente!.nombreCompleto} · ${pesosCO(_total)}' : _cliente!.nombreCompleto;
    return PopScope(
      canPop: primero,
      onPopInvokedWithResult: (hizo, _) {
        if (!hizo) _atras();
      },
      child: Scaffold(
        backgroundColor: CM.fondo,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: CM.verdeOs,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: primero ? 'Cerrar' : 'Volver',
            icon: Icon(primero ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: _atras,
          ),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nuevo separado', style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
            if (sub != null)
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 11.5, color: CM.gris2)),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(38), child: _pasos()),
        ),
        body: Stack(children: [
          switch (_paso) {
            1 => _pasoCliente(),
            2 => _pasoProductos(),
            _ => _pasoFecha(),
          },
          if (_ocupado)
            const Positioned(left: 0, right: 0, top: 0,
                child: LinearProgressIndicator(minHeight: 2.5, color: CM.verde, backgroundColor: Colors.transparent)),
        ]),
        bottomNavigationBar: _barra(),
      ),
    );
  }

  Widget _pasos() {
    const nombres = ['Cliente', 'Productos', 'Fecha y abono'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: LayoutBuilder(builder: (_, c) => Row(children: [
        for (var i = 1; i <= 3; i++) ...[
          _bolita(i, c.maxWidth < 330 && i != _paso ? '' : nombres[i - 1]),
          if (i < 3) Expanded(child: Container(height: 1.5, color: CM.borde, margin: const EdgeInsets.symmetric(horizontal: 5))),
        ],
      ])),
    );
  }

  Widget _bolita(int i, String t) {
    final on = i == _paso, ok = i < _paso;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 20, height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? CM.verde : ok ? const Color(0xFFD1FAE5) : Colors.white,
          border: Border.all(color: on ? CM.verde : ok ? CM.borde2 : const Color(0xFFCBD5E1), width: 1.5),
        ),
        child: ok
            ? const Icon(Icons.check_rounded, size: 12, color: CM.verdeOs)
            : Text('$i', style: cf(size: 10.5, w: FontWeight.w700, color: on ? Colors.white : CM.gris2)),
      ),
      if (t.isNotEmpty) ...[
        const SizedBox(width: 5),
        Text(t, style: cf(size: 10.5, w: FontWeight.w700, color: on ? CM.verdeOs : CM.gris2)),
      ],
    ]);
  }

  Widget? _barra() {
    if (_paso == 1) return null;
    final hijos = <Widget>[];
    if (_paso == 2) {
      final n = _lineas.fold<double>(0, (s, l) => s + l.cantidad);
      hijos.addAll([
        Row(children: [
          Expanded(child: Text(n == 0 ? 'Sin productos' : '${cantidadTexto(n)} producto${n == 1 ? '' : 's'}',
              style: cf(size: 13, color: CM.gris))),
          Text(pesosCO(_total), style: cf(size: 16, w: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        FilledButton(onPressed: _siguiente, style: botonSep(),
            child: Text('Siguiente', style: cf(size: 14.5, w: FontWeight.w700, color: Colors.white))),
      ]);
    } else {
      hijos.add(FilledButton.icon(
        onPressed: _ocupado ? null : _crear,
        style: botonSep(),
        icon: _ocupado
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_rounded, size: 18),
        label: Text(_imprimir ? 'Crear separado e imprimir' : 'Crear separado',
            style: cf(size: 14.5, w: FontWeight.w700, color: Colors.white)),
      ));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CM.borde))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos)),
    );
  }

  Widget _pasoCliente() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          TextField(
            controller: _qCliente,
            autofocus: true,
            onChanged: _cambioCliente,
            style: cf(size: 13.5),
            decoration: decoSep(null, hint: 'Nombre, cédula o celular', icono: Icons.search_rounded),
          ),
          if (_buscandoClientes)
            const LinearProgressIndicator(minHeight: 2, color: CM.verde, backgroundColor: Colors.transparent),
          const SizedBox(height: 10),
          if (_qCliente.text.trim().length >= 2 && _clientes.isEmpty && !_buscandoClientes)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Nadie con "${_qCliente.text.trim()}".', textAlign: TextAlign.center,
                  style: cf(size: 13, color: CM.gris)),
            ),
          for (final c in _clientes) ...[
            _tarjetaCliente(c),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _nuevoCliente,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text('Crear cliente nuevo', style: cf(size: 13.5, w: FontWeight.w700, color: CM.verdeOs)),
            style: botonContornoSep(),
          ),
          const SizedBox(height: 10),
          Text('El separado necesita un cliente con celular para avisarle.', textAlign: TextAlign.center,
              style: cf(size: 12, color: CM.gris2)),
        ],
      );

  Widget _tarjetaCliente(Cliente c) {
    final saldo = c.saldos;
    final extra = saldo == null
        ? null
        : saldo.separadosActivos > 0
            ? etiquetaSep(EstadoSep(plural(saldo.separadosActivos, 'separado', 'separados'), TonoSep.verde))
            : saldo.credito > 0
                ? etiquetaSep(EstadoSep('Debe ${pesosCO(saldo.credito)}', TonoSep.rojo))
                : null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _elegirCliente(c),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5)),
          child: Row(children: [
            avatarSep(c.nombreCompleto, t: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.nombreCompleto, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: cf(size: 13.5, w: FontWeight.w800)),
                Text([
                  if ((c.cedulaNit ?? '').isNotEmpty) 'C.C. ${c.cedulaNit}',
                  if (c.telefono.isNotEmpty) telefonoBonito(c.telefono) else 'sin celular',
                ].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 11.5, color: CM.gris2)),
              ]),
            ),
            ?extra,
          ]),
        ),
      ),
    );
  }

  Widget _pasoProductos() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _ocupado ? null : _buscarProducto,
              icon: const Icon(Icons.search_rounded, size: 17),
              label: Text('Buscar', style: cf(size: 13, w: FontWeight.w700, color: CM.verdeOs)),
              style: botonContornoSep().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 44))),
            )),
            const SizedBox(width: 6),
            Expanded(child: OutlinedButton.icon(
              onPressed: _ocupado ? null : _escanearProducto,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
              label: Text('Escanear', style: cf(size: 13, w: FontWeight.w700, color: CM.verdeOs)),
              style: botonContornoSep().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 44))),
            )),
          ]),
          const SizedBox(height: 10),
          for (final l in _lineas) ...[
            cajaSep(Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.producto.nombre, style: cf(size: 13, w: FontWeight.w800)),
                  Text('${pesosCO(l.producto.precio)} · quedan ${cantidadTexto(l.producto.stockActual)}',
                      style: cf(size: 11.5, color: CM.gris2)),
                ]),
              ),
              _cant('−', () => setState(() {
                if (l.cantidad > 1) {
                  l.cantidad--;
                } else {
                  _lineas.remove(l);
                }
              }), 'Menos ${l.producto.nombre}'),
              SizedBox(width: 30, child: Text(cantidadTexto(l.cantidad), textAlign: TextAlign.center,
                  style: cf(size: 15, w: FontWeight.w800))),
              _cant('+', l.cantidad < l.producto.stockActual ? () => setState(() => l.cantidad++) : null,
                  'Más ${l.producto.nombre}'),
            ]), padding: const EdgeInsets.fromLTRB(12, 9, 10, 9)),
            const SizedBox(height: 8),
          ],
          if (_lineas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Busca o escanea lo que va a separar.', textAlign: TextAlign.center,
                  style: cf(size: 13, color: CM.gris)),
            ),
          Text('Al guardar, estos productos salen del stock y quedan apartados para ${_cliente == null ? 'el cliente' : nombreCorto(_cliente!.nombreCompleto)}.',
              style: cf(size: 12, color: CM.gris2)),
        ],
      );

  Widget _cant(String t, VoidCallback? f, String etiqueta) => Semantics(
        button: true,
        label: etiqueta,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: f,
            child: Container(
              width: 34, height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: f == null ? CM.borde : CM.borde2, width: 1.5)),
              child: Text(t, style: cf(size: 17, w: FontWeight.w800, color: f == null ? CM.borde2 : CM.verdeOs)),
            ),
          ),
        ),
      );

  Widget _pasoFecha() {
    final queda = _total - _abonoValor;
    final cuentas = cuentasDeMetodo(widget.cuentas, _metodo);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Text('¿HASTA CUÁNDO LO GUARDAMOS?', style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in plazosDias)
            chipSep('$d días', _plazo == d, () => setState(() {
              _plazo = d;
              _fecha = fechaPlazo(_hoy, d);
            })),
          chipSep('Otra', _plazo == null, _otraFecha, icono: Icons.event_outlined),
        ]),
        const SizedBox(height: 8),
        cajaSep(Row(children: [
          const Icon(Icons.event_outlined, size: 17, color: CM.verdeOs),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Vence el ', style: cf(size: 13)),
            TextSpan(text: fechaLarga(_fecha), style: cf(size: 13, w: FontWeight.w800)),
          ]))),
        ])),
        const SizedBox(height: 14),
        Text('ABONO INICIAL', style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
        const SizedBox(height: 8),
        TextField(
          controller: _abono,
          keyboardType: TextInputType.number,
          inputFormatters: [MilesFormatterSep()],
          onChanged: (_) => setState(() {}),
          style: cf(size: 20, w: FontWeight.w800),
          decoration: decoSep(null, hint: '0', prefijo: '\$ ', grande: true),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (t, v) in abonosIniciales(_total))
            chipSep(t, _abonoValor == v, () => setState(() => _abono.text = milesSep(v))),
        ]),
        const SizedBox(height: 10),
        metodosSep(_metodo, (m) => setState(() {
          _metodo = m;
          _ponerCuenta();
        }), cajaAbierta: widget.cajaAbierta,
            sinCaja: () => avisoSep(context, 'No hay caja abierta: el efectivo no se puede recibir.')),
        if (cuentas.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('¿A qué cuenta?', style: cf(size: 11.5, w: FontWeight.w600, color: CM.gris2)),
            for (final c in cuentas) chipSep(c.nombre, _cuenta == c.id, () => setState(() => _cuenta = c.id)),
          ]),
        ],
        const SizedBox(height: 10),
        cajaSep(Column(children: [
          kvSep('Total', pesosCO(_total)),
          kvSep('Abona hoy', pesosCO(_abonoValor)),
          kvSep(queda >= 0 ? 'Le queda por pagar' : 'Es más que el total', pesosCO(queda.abs()),
              color: CM.rojo, fuerte: true, raya: true),
        ])),
        const SizedBox(height: 6),
        SwitchListTile(
          value: _imprimir,
          onChanged: (v) => setState(() => _imprimir = v),
          activeThumbColor: CM.verde,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('Imprimir el recibo', style: cf(size: 13, w: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Hoja para buscar productos ────────────────────────────────

class _HojaProductos extends StatefulWidget {
  final Future<List<Producto>> Function(String q) buscar;
  final String inicial;
  final List<Producto>? resultados;
  const _HojaProductos({required this.buscar, this.inicial = '', this.resultados});

  @override
  State<_HojaProductos> createState() => _HojaProductosState();
}

class _HojaProductosState extends State<_HojaProductos> {
  late final _ctrl = TextEditingController(text: widget.inicial);
  late List<Producto> _l = widget.resultados ?? [];
  bool _cargando = false;
  Timer? _espera;
  int _pedido = 0;

  @override
  void dispose() {
    _espera?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String t) async {
    final q = t.trim();
    if (q.isEmpty) {
      setState(() => _l = []);
      return;
    }
    final n = ++_pedido;
    setState(() => _cargando = true);
    final l = await widget.buscar(q);
    if (!mounted || n != _pedido) return;
    setState(() {
      _l = l;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: CM.borde2, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: widget.resultados == null,
                onChanged: (t) {
                  _espera?.cancel();
                  _espera = Timer(const Duration(milliseconds: 300), () => _buscar(t));
                },
                style: cf(size: 14),
                decoration: decoSep(null, hint: 'Nombre, referencia o código', icono: Icons.search_rounded),
              ),
            ),
            if (_cargando) const LinearProgressIndicator(minHeight: 2, color: CM.verde, backgroundColor: Colors.transparent),
            Expanded(
              child: _l.isEmpty
                  ? Center(child: Text(_ctrl.text.trim().isEmpty ? 'Escribe para buscar.' : 'Sin resultados.',
                      style: cf(size: 13, color: CM.gris)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: _l.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: CM.borde),
                      itemBuilder: (_, i) {
                        final p = _l[i];
                        final sin = p.stockActual <= 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          enabled: !sin,
                          onTap: () => Navigator.pop(context, p),
                          title: Text(p.nombre, style: cf(size: 13.5, w: FontWeight.w700)),
                          subtitle: Text(sin ? 'Sin stock' : 'Quedan ${cantidadTexto(p.stockActual)}',
                              style: cf(size: 11.5, color: sin ? CM.rojo : CM.gris2)),
                          trailing: Text(pesosCO(p.precio), style: cf(size: 14, w: FontWeight.w800, color: CM.oscuro)),
                        );
                      },
                    ),
            ),
          ]),
        ),
      );
}
