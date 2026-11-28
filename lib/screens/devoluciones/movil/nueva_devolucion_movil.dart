// lib/screens/devoluciones/movil/nueva_devolucion_movil.dart
//
// Nueva devolución o cambio en el celular, en 4 pasos:
//   ① la venta (escanear el ticket o buscarla)
//   ② qué trae el cliente y si viene bien o dañado
//   ③ devolución de plata o cambio por otro producto
//   ④ la plata (método, cuenta, recibido y vueltas)
// No habla con el servidor: usa los servicios que le pasan (así se prueba).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cuenta_bancaria.dart';
import '../../../models/producto.dart';
import '../../../models/venta_model.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import '../../compras/movil/orden_movil.dart' show botonVerde;
import 'devolucion_detalle_movil.dart' show filaKV, tarjetaDev;
import 'devoluciones_reglas.dart';

/// Lo que se manda a registrar.
class PedidoDev {
  final TipoOp tipo;
  final int ventaId;
  final List<Map<String, dynamic>> detalles;
  final List<Map<String, dynamic>> reemplazos;
  /// Método de la plata que se mueve (null si no se mueve nada).
  final String? metodo;
  final int? cuentaId;
  final double? montoRecibido;
  final String motivoCambio;
  final String observaciones;
  final bool imprimir;

  const PedidoDev({
    required this.tipo,
    required this.ventaId,
    required this.detalles,
    this.reemplazos = const [],
    this.metodo,
    this.cuentaId,
    this.montoRecibido,
    this.motivoCambio = 'gusto',
    this.observaciones = '',
    this.imprimir = true,
  });
}

class ServiciosNuevaDev {
  final Future<List<VentaResumenModel>> Function(DateTime dia) ventasDelDia;
  final Future<List<VentaResumenModel>> Function(String numero) buscarFactura;
  /// Productos que todavía se pueden devolver. Devuelve (venta, error).
  final Future<(VentaDisponibleModel?, String?)> Function(VentaResumenModel v) disponible;
  final Future<List<Producto>> Function(String q) buscarProductos;
  final Future<String?> Function(BuildContext context) escanear;
  /// null si quedó registrada; si no, el error para mostrar.
  final Future<String?> Function(PedidoDev p) registrar;

  const ServiciosNuevaDev({
    required this.ventasDelDia,
    required this.buscarFactura,
    required this.disponible,
    required this.buscarProductos,
    required this.escanear,
    required this.registrar,
  });
}

class NuevaDevolucionMovil extends StatefulWidget {
  final ServiciosNuevaDev servicios;
  final List<CuentaBancaria> cuentas;
  /// false: no hay caja abierta (solo transferencia o tarjeta). null: no se sabe.
  final bool? cajaAbierta;
  /// Número de factura leído antes de abrir (lector de barras).
  final String? facturaInicial;
  final DateTime? hoy;

  const NuevaDevolucionMovil({
    super.key,
    required this.servicios,
    this.cuentas = const [],
    this.cajaAbierta,
    this.facturaInicial,
    this.hoy,
  });

  @override
  State<NuevaDevolucionMovil> createState() => _NuevaDevolucionMovilState();
}

class _NuevaDevolucionMovilState extends State<NuevaDevolucionMovil> {
  int _paso = 1;
  bool _ocupado = false;

  // ① venta
  final _buscaVenta = TextEditingController();
  late DateTime _dia = _hoy;
  List<VentaResumenModel> _ventas = [];
  bool _cargandoVentas = false;
  VentaResumenModel? _venta;
  VentaDisponibleModel? _disp;

  // ② qué trae
  final List<LineaTrae> _trae = [];
  final Map<int, TextEditingController> _notas = {};

  // ③ tipo
  TipoOp? _tipo;
  final List<LineaLleva> _lleva = [];

  // ④ plata
  late String _metodo = widget.cajaAbierta == false ? 'transferencia' : 'efectivo';
  int? _cuentaId;
  final _recibido = TextEditingController();
  final _obs = TextEditingController();
  bool _imprimir = true;

  DateTime get _hoy => widget.hoy ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _cuentaId = _cuentaUnica(_metodo);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarVentas();
      final f = widget.facturaInicial;
      if (f != null && f.trim().isNotEmpty) _buscarFactura(f.trim());
    });
  }

  @override
  void dispose() {
    _buscaVenta.dispose();
    _recibido.dispose();
    _obs.dispose();
    for (final c in _notas.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _aviso(String t, {bool error = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(t, style: cf(size: 13, color: Colors.white)),
        backgroundColor: error ? CM.rojo : CM.verde,
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ── ① La venta ─────────────────────────────────────────────

  Future<void> _cargarVentas() async {
    setState(() => _cargandoVentas = true);
    final l = await widget.servicios.ventasDelDia(_dia);
    if (!mounted) return;
    setState(() {
      _ventas = l.where((v) => v.estado != 'anulada').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cargandoVentas = false;
    });
  }

  Future<void> _buscarFactura(String numero) async {
    setState(() => _ocupado = true);
    final l = await widget.servicios.buscarFactura(numero);
    if (!mounted) return;
    setState(() => _ocupado = false);
    final validas = l.where((v) => v.estado != 'anulada').toList();
    if (validas.isEmpty) {
      _aviso('No se encontró la factura "$numero".');
      return;
    }
    await _elegirVenta(validas.first);
  }

  Future<void> _escanearTicket() async {
    final c = await widget.servicios.escanear(context);
    if (c == null || c.trim().isEmpty || !mounted) return;
    await _buscarFactura(c.trim());
  }

  Future<void> _elegirVenta(VentaResumenModel v) async {
    setState(() => _ocupado = true);
    final (disp, error) = await widget.servicios.disponible(v);
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (disp == null) {
      _aviso(error ?? 'No se pudo cargar la venta.');
      return;
    }
    if (disp.todosDevueltos || disp.productos.isEmpty) {
      _aviso('Esa venta ya se devolvió completa.');
      return;
    }
    for (final c in _notas.values) {
      c.dispose();
    }
    _notas.clear();
    setState(() {
      _venta = v;
      _disp = disp;
      _trae
        ..clear()
        ..addAll(disp.productos.map((p) => LineaTrae(p,
            cantidad: disp.productos.length == 1 && p.disponible <= 1 ? p.disponible : 0)));
      _tipo = null;
      _lleva.clear();
      _recibido.clear();
      _paso = 2;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  // ── ③ Productos que se lleva ───────────────────────────────

  void _agregarLleva(Producto p) {
    final i = _lleva.indexWhere((x) => x.producto.id == p.id);
    setState(() {
      if (i >= 0) {
        if (_lleva[i].cantidad < p.stockActual) {
          _lleva[i].cantidad++;
        } else {
          _aviso('De ${p.nombre} quedan ${cantidadTexto(p.stockActual)}.');
        }
      } else if (p.stockActual <= 0) {
        _aviso('${p.nombre} no tiene stock en esta tienda.');
      } else {
        _lleva.add(LineaLleva(p));
      }
    });
  }

  Future<void> _buscarLleva() async {
    final p = await showModalBottomSheet<Producto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _HojaProductos(buscar: widget.servicios.buscarProductos),
    );
    if (p != null && mounted) _agregarLleva(p);
  }

  Future<void> _escanearLleva() async {
    final c = await widget.servicios.escanear(context);
    if (c == null || c.trim().isEmpty || !mounted) return;
    setState(() => _ocupado = true);
    final l = await widget.servicios.buscarProductos(c.trim());
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (l.isEmpty) {
      _aviso('Ningún producto con el código "$c".');
    } else if (l.length == 1) {
      _agregarLleva(l.first);
    } else {
      final p = await showModalBottomSheet<Producto>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _HojaProductos(buscar: widget.servicios.buscarProductos, inicial: c.trim(), resultados: l),
      );
      if (p != null && mounted) _agregarLleva(p);
    }
  }

  // ── ④ La plata ─────────────────────────────────────────────

  CuentasOp get _cuentas => cuentasOp(_tipo ?? TipoOp.devolucion, _disp!, _trae, _lleva);

  List<CuentaBancaria> _cuentasDe(String m) {
    if (m != 'transferencia' && m != 'tarjeta') return const [];
    return widget.cuentas
        .where((c) => c.activo && (m == 'tarjeta' ? c.tipo == 'tarjeta' : c.tipo != 'tarjeta'))
        .toList();
  }

  int? _cuentaUnica(String m) {
    final l = _cuentasDe(m);
    return l.length == 1 ? l.first.id : null;
  }

  double get _recibidoValor => double.tryParse(_recibido.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  String? _problemaPlata() {
    final monto = plataQueSeMueve(_tipo!, _cuentas);
    if (monto <= 0) return null;
    if (_metodo == 'efectivo' && widget.cajaAbierta == false) {
      return 'No hay caja abierta: elige transferencia o tarjeta.';
    }
    if (_metodo != 'efectivo' && _cuentaId == null && _cuentasDe(_metodo).isNotEmpty) {
      return '¿A qué cuenta? Elige una.';
    }
    if (_tipo == TipoOp.cambio && _cuentas.diferencia > 0 && _metodo == 'efectivo' && _recibidoValor < monto) {
      return _recibidoValor <= 0 ? 'Escribe cuánto te entregó.' : 'Falta ${pesosCO(monto - _recibidoValor)}.';
    }
    return null;
  }

  Future<void> _registrar() async {
    final p = _problemaPlata();
    if (p != null) {
      _aviso(p);
      return;
    }
    final c = _cuentas;
    final monto = plataQueSeMueve(_tipo!, c);
    final mueve = monto > 0;
    final cambio = _tipo == TipoOp.cambio;
    final detalles = detallesPedido(_trae);
    final pedido = PedidoDev(
      tipo: _tipo!,
      ventaId: _disp!.ventaId,
      detalles: detalles,
      reemplazos: [
        for (final x in _lleva.where((x) => x.cantidad > 0)) {'producto': x.producto.id, 'cantidad': x.cantidad},
      ],
      metodo: mueve ? _metodo : (cambio ? null : 'nota_credito'),
      cuentaId: mueve && _metodo != 'efectivo' ? _cuentaId : null,
      montoRecibido: cambio && c.diferencia > 0
          ? (_metodo == 'efectivo' ? _recibidoValor : c.diferencia)
          : null,
      motivoCambio: _trae.any((x) => x.cantidad > 0 && x.danado) ? 'averia' : 'gusto',
      observaciones: _obs.text.trim(),
      imprimir: _imprimir,
    );
    setState(() => _ocupado = true);
    final error = await widget.servicios.registrar(pedido);
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (error != null) _aviso(error);
  }

  // ── Navegación ─────────────────────────────────────────────

  void _siguiente() {
    final p = problemaPasoDev(_paso, venta: _disp, trae: _trae, tipo: _tipo, lleva: _lleva);
    if (p != null) {
      _aviso(p);
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _paso++;
      if (_paso == 4) {
        _recibido.clear();
        if (_tipo == TipoOp.cambio && _cuentas.diferencia > 0) {
          _recibido.text = _miles(_cuentas.diferencia);
        }
      }
    });
  }

  void _atras() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (_paso <= 1) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _paso--);
    }
  }

  // ── Vista ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final titulo = _paso == 1 || _venta == null
        ? 'Nueva devolución o cambio'
        : '${_venta!.numeroFactura} · ${_disp?.clienteNombre ?? _venta!.clienteNombre}';
    final sub = _paso == 1 || _venta == null
        ? null
        : _disp!.aCredito && _disp!.saldoPendiente > 0
            ? 'Venta a crédito · debe ${pesosCO(_disp!.saldoPendiente)}'
            : 'Comprada ${cuandoLargo(_venta!.createdAt, _hoy).replaceFirst('Hoy', 'hoy').replaceFirst('Ayer', 'ayer')} · ${pesosCO(_venta!.total)}';
    return PopScope(
      canPop: _paso == 1,
      onPopInvokedWithResult: (hizoPop, _) {
        if (!hizoPop) _atras();
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
            tooltip: _paso == 1 ? 'Cerrar' : 'Volver',
            icon: Icon(_paso == 1 ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: _atras,
          ),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
            if (sub != null)
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 11.5, color: CM.gris2)),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(38), child: _pasos()),
        ),
        body: Stack(children: [
          switch (_paso) {
            1 => _pasoVenta(),
            2 => _pasoTrae(),
            3 => _pasoTipo(),
            _ => _pasoPlata(),
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
    const nombres = ['Venta', 'Qué trae', 'Tipo', 'Plata'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      // En pantallas angostas solo el paso actual lleva nombre.
      child: LayoutBuilder(builder: (_, c) => Row(children: [
        for (var i = 1; i <= 4; i++) ...[
          _paso1(i, c.maxWidth < 330 && i != _paso ? '' : nombres[i - 1]),
          if (i < 4) Expanded(child: Container(height: 1.5, color: CM.borde, margin: const EdgeInsets.symmetric(horizontal: 5))),
        ],
      ])),
    );
  }

  Widget _paso1(int i, String t) {
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
      final n = _trae.where((x) => x.cantidad > 0).fold<double>(0, (s, x) => s + x.cantidad);
      final total = _trae.fold<double>(0, (s, x) => s + x.subtotal);
      hijos.add(Row(children: [
        Expanded(child: Text(n == 0 ? 'Nada marcado' : '${cantidadTexto(n)} producto${n == 1 ? '' : 's'}',
            style: cf(size: 13, color: CM.gris))),
        Text(pesosCO(total), style: cf(size: 15, w: FontWeight.w800)),
      ]));
      hijos.add(const SizedBox(height: 8));
      hijos.add(FilledButton(onPressed: _siguiente, style: botonVerde(), child: Text('Siguiente', style: _txtBoton)));
    } else if (_paso == 3) {
      hijos.add(FilledButton(
          onPressed: _siguiente, style: botonVerde(), child: Text('Siguiente: la plata', style: _txtBoton)));
    } else {
      final cambio = _tipo == TipoOp.cambio;
      final t = '${cambio ? 'Registrar cambio' : 'Registrar devolución'}${_imprimir ? ' e imprimir' : ''}';
      hijos.add(FilledButton.icon(
        onPressed: _ocupado ? null : _registrar,
        style: botonVerde(),
        icon: _ocupado
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_rounded, size: 18),
        label: Text(t, style: _txtBoton),
      ));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CM.borde))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos)),
    );
  }

  TextStyle get _txtBoton => cf(size: 14.5, w: FontWeight.w700, color: Colors.white);

  // ── ① ──

  Widget _pasoVenta() {
    final q = _buscaVenta.text.trim().toLowerCase();
    final lista = q.isEmpty
        ? _ventas
        : _ventas.where((v) => '${v.numeroFactura} ${v.clienteNombre}'.toLowerCase().contains(q)).toList();
    final esHoy = mismoDia(_dia, _hoy);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: _ocupado ? null : _escanearTicket,
            style: botonVerde(),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
            label: Text('Escanear el ticket', style: cf(size: 15, w: FontWeight.w700, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _buscaVenta,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          onSubmitted: (t) {
            if (t.trim().isNotEmpty && lista.isEmpty) _buscarFactura(t.trim());
          },
          style: cf(size: 13.5),
          decoration: _deco('Número de factura o cliente', icono: Icons.search_rounded),
        ),
        if (q.isNotEmpty && lista.isEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _buscarFactura(_buscaVenta.text.trim()),
            icon: const Icon(Icons.search_rounded, size: 17),
            label: Text('Buscar la factura "${_buscaVenta.text.trim()}" en todas las fechas',
                style: cf(size: 12.5, w: FontWeight.w700, color: CM.verdeOs)),
            style: OutlinedButton.styleFrom(foregroundColor: CM.verdeOs, minimumSize: const Size(0, 44),
                side: const BorderSide(color: CM.borde2, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text(esHoy ? 'VENTAS DE HOY' : 'VENTAS DEL ${_diaTexto(_dia).toUpperCase()}',
              style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5))),
          _chipChico(Icons.calendar_today_outlined, esHoy ? 'Hoy' : _diaTexto(_dia), () async {
            final f = await showDatePicker(
              context: context,
              initialDate: _dia,
              firstDate: _hoy.subtract(const Duration(days: 365)),
              lastDate: _hoy,
            );
            if (f != null && mounted) {
              setState(() => _dia = f);
              _cargarVentas();
            }
          }),
        ]),
        const SizedBox(height: 8),
        if (_cargandoVentas)
          Padding(padding: const EdgeInsets.all(24),
              child: Center(child: Text('Cargando ventas…', style: cf(size: 13, color: CM.gris))))
        else if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(q.isEmpty ? 'No hubo ventas ese día.' : 'Ninguna venta de ese día coincide.',
                textAlign: TextAlign.center, style: cf(size: 13, color: CM.gris)),
          )
        else
          for (final v in lista) ...[
            _tarjetaVenta(v),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 6),
        Text('Si la venta ya se devolvió completa, la app te avisa al tocarla.',
            textAlign: TextAlign.center, style: cf(size: 12, color: CM.gris2)),
      ],
    );
  }

  Widget _tarjetaVenta(VentaResumenModel v) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _ocupado ? null : () => _elegirVenta(v),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CM.borde, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(v.numeroFactura, style: cf(size: 13.5, w: FontWeight.w800)),
                const Spacer(),
                Text(horaCorta(v.createdAt), style: cf(size: 11, w: FontWeight.w600, color: CM.gris2)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text(v.clienteNombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: cf(size: 12.5, color: const Color(0xFF334155)))),
                Text(pesosCO(v.total), style: cf(size: 14, w: FontWeight.w800, color: CM.oscuro)),
              ]),
            ]),
          ),
        ),
      );

  // ── ② ──

  Widget _pasoTrae() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Text('¿QUÉ TRAE EL CLIENTE?', style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
          const SizedBox(height: 8),
          for (final x in _trae) ...[
            _lineaTrae(x),
            const SizedBox(height: 8),
          ],
          Text('Lo que está bien vuelve a venderse; lo dañado queda en averías para revisarlo.',
              style: cf(size: 12, color: CM.gris2)),
        ],
      );

  Widget _lineaTrae(LineaTrae x) {
    final activo = x.cantidad > 0;
    final nota = _notas.putIfAbsent(x.producto.productoId, () => TextEditingController(text: x.nota));
    return Opacity(
      opacity: activo ? 1 : .55,
      child: tarjetaDev(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x.producto.productoNombre, style: cf(size: 13, w: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${pesosCO(x.producto.precioUnitario)} c/u · puede devolver ${cantidadTexto(x.producto.disponible)}',
                  style: cf(size: 11.5, color: CM.gris2)),
            ]),
          ),
          _cantidad(
            x.cantidad,
            menos: x.cantidad > 0 ? () => setState(() => x.cantidad = (x.cantidad - 1).clamp(0, x.producto.disponible)) : null,
            mas: x.cantidad < x.producto.disponible
                ? () => setState(() => x.cantidad = (x.cantidad + 1).clamp(0, x.producto.disponible))
                : null,
            nombre: x.producto.productoNombre,
          ),
        ]),
        if (activo) ...[
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: _duo('Está bien · al stock', Icons.check_circle_outline_rounded, !x.danado,
                CM.verdeOs, const Color(0xFFECFDF5), CM.verde, () => setState(() => x.danado = false))),
            const SizedBox(width: 6),
            Expanded(child: _duo('Dañado · a averías', Icons.broken_image_outlined, x.danado,
                const Color(0xFF92400E), const Color(0xFFFFFBEB), const Color(0xFFD97706),
                () => setState(() => x.danado = true))),
          ]),
          if (x.danado) ...[
            const SizedBox(height: 8),
            TextField(
              controller: nota,
              onChanged: (t) => x.nota = t,
              style: cf(size: 13),
              decoration: _deco('¿Qué tiene? (opcional)'),
            ),
          ],
        ],
      ]), padding: const EdgeInsets.fromLTRB(12, 11, 12, 11)),
    );
  }

  Widget _duo(String t, IconData i, bool on, Color c, Color bg, Color borde, VoidCallback f) => Material(
        color: on ? bg : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: f,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                border: Border.all(color: on ? borde : const Color(0xFFE2E8F0), width: 1.5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(i, size: 15, color: on ? c : CM.gris2),
              const SizedBox(width: 5),
              Flexible(child: Text(t, maxLines: 2, textAlign: TextAlign.center,
                  style: cf(size: 11.5, w: FontWeight.w700, color: on ? c : const Color(0xFF334155)))),
            ]),
          ),
        ),
      );

  Widget _cantidad(double v, {VoidCallback? menos, VoidCallback? mas, required String nombre}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        _botonCant('−', menos, 'Menos $nombre'),
        SizedBox(width: 30, child: Text(cantidadTexto(v), textAlign: TextAlign.center,
            style: cf(size: 15, w: FontWeight.w800))),
        _botonCant('+', mas, 'Más $nombre'),
      ]);

  Widget _botonCant(String t, VoidCallback? f, String etiqueta) => Semantics(
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

  // ── ③ ──

  Widget _pasoTipo() {
    final c = _cuentas;
    final credito = _disp!.aCredito && _disp!.saldoPendiente > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Text('¿QUÉ QUIERE EL CLIENTE?', style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _opcion(TipoOp.devolucion, 'Que le devuelvan la plata',
                credito ? 'Primero abona a lo que debe' : 'Devolución de ${pesosCO(c.trae)}')),
            const SizedBox(width: 8),
            Expanded(child: _opcion(TipoOp.cambio, 'Llevarse otro producto', 'Cambio por algo de la tienda')),
          ]),
        ),
        if (_tipo == TipoOp.cambio) ...[
          const SizedBox(height: 14),
          Text('LO QUE SE LLEVA', style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _botonContorno(Icons.search_rounded, 'Buscar', _buscarLleva)),
            const SizedBox(width: 6),
            Expanded(child: _botonContorno(Icons.qr_code_scanner_rounded, 'Escanear', _escanearLleva)),
          ]),
          const SizedBox(height: 8),
          for (final x in _lleva) ...[
            tarjetaDev(Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.producto.nombre, style: cf(size: 13, w: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${pesosCO(x.producto.precio)} · quedan ${cantidadTexto(x.producto.stockActual)}',
                      style: cf(size: 11.5, color: CM.gris2)),
                ]),
              ),
              _cantidad(x.cantidad,
                  menos: () => setState(() {
                        if (x.cantidad > 1) {
                          x.cantidad--;
                        } else {
                          _lleva.remove(x);
                        }
                      }),
                  mas: x.cantidad < x.producto.stockActual ? () => setState(() => x.cantidad++) : null,
                  nombre: x.producto.nombre),
            ]), padding: const EdgeInsets.fromLTRB(12, 10, 12, 10)),
            const SizedBox(height: 8),
          ],
          if (_lleva.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Busca o escanea lo que se va a llevar.', textAlign: TextAlign.center,
                  style: cf(size: 12.5, color: CM.gris)),
            ),
          tarjetaDev(Column(children: [
            filaKV('Trae', pesosCO(c.trae)),
            filaKV('Se lleva', pesosCO(c.lleva)),
            if (c.diferencia > 0)
              filaKV('Te paga la diferencia', pesosCO(c.diferencia), color: CM.verdeOs, fuerte: true, raya: true)
            else if (c.diferencia < 0)
              filaKV('Le devuelves', pesosCO(-c.diferencia), color: CM.rojo, fuerte: true, raya: true)
            else
              filaKV('Diferencia', 'Sin diferencia', fuerte: true, raya: true),
          ]), padding: const EdgeInsets.fromLTRB(12, 8, 12, 9)),
        ],
      ],
    );
  }

  Widget _opcion(TipoOp t, String titulo, String sub) {
    final on = _tipo == t;
    return Material(
      color: on ? const Color(0xFFECFDF5) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _tipo = t),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? CM.verde : CM.borde, width: on ? 1.8 : 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 18, color: on ? CM.verde : CM.gris2),
              const SizedBox(width: 6),
              Expanded(child: Text(titulo, style: cf(size: 13, w: FontWeight.w800))),
            ]),
            const SizedBox(height: 4),
            Text(sub, style: cf(size: 11.5, color: CM.gris2)),
          ]),
        ),
      ),
    );
  }

  Widget _botonContorno(IconData i, String t, VoidCallback f) => OutlinedButton.icon(
        onPressed: _ocupado ? null : f,
        icon: Icon(i, size: 17),
        label: Text(t, style: cf(size: 13, w: FontWeight.w700, color: CM.verdeOs)),
        style: OutlinedButton.styleFrom(
          foregroundColor: CM.verdeOs, minimumSize: const Size(0, 44),
          side: const BorderSide(color: CM.borde2, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  // ── ④ ──

  Widget _pasoPlata() {
    final c = _cuentas;
    final cambio = _tipo == TipoOp.cambio;
    final monto = plataQueSeMueve(_tipo!, c);
    final cobra = cambio && c.diferencia > 0;
    final efectivo = _metodo == 'efectivo';
    final vueltas = _recibidoValor - monto;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        ..._resumenPlata(c, cambio),
        if (monto > 0) ...[
          const SizedBox(height: 14),
          Text(cobra ? '¿CÓMO PAGA?' : '¿CÓMO SE LOS DEVUELVES?',
              style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
          const SizedBox(height: 8),
          Row(children: [
            for (final (m, t, i) in [('efectivo', 'Efectivo', Icons.payments_outlined),
                                     ('transferencia', 'Transferencia', Icons.account_balance_outlined),
                                     ('tarjeta', 'Tarjeta', Icons.credit_card_rounded)]) ...[
              Expanded(child: _metodoBtn(m, t, i,
                  deshabilitado: m == 'efectivo' && widget.cajaAbierta == false)),
              if (m != 'tarjeta') const SizedBox(width: 6),
            ],
          ]),
          if (!efectivo && _cuentasDe(_metodo).length > 1) ...[
            const SizedBox(height: 12),
            Text(cobra ? '¿A QUÉ CUENTA ENTRA?' : '¿DE QUÉ CUENTA SALE?',
                style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final cta in _cuentasDe(_metodo))
                _chipChico(null, cta.nombre, () => setState(() => _cuentaId = cta.id), on: _cuentaId == cta.id),
            ]),
          ],
          if (cobra && efectivo) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _recibido,
              keyboardType: TextInputType.number,
              inputFormatters: [_MilesFormatter()],
              onChanged: (_) => setState(() {}),
              style: cf(size: 18, w: FontWeight.w800),
              decoration: _deco('Recibido', prefijo: '\$ '),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _chipChico(null, 'Exacto', () => setState(() => _recibido.text = _miles(monto)),
                  on: _recibidoValor == monto),
              for (final b in billetesSugeridos(monto))
                _chipChico(null, pesosCO(b), () => setState(() => _recibido.text = _miles(b)),
                    on: _recibidoValor == b),
            ]),
            const SizedBox(height: 10),
            tarjetaDev(Row(children: [
              Expanded(child: Text(vueltas >= 0 ? 'Vueltas' : 'Falta',
                  style: cf(size: 13, color: CM.gris))),
              Text(pesosCO(vueltas.abs()), style: cf(size: 17, w: FontWeight.w800,
                  color: vueltas >= 0 ? CM.oscuro : CM.rojo)),
            ]), padding: const EdgeInsets.fromLTRB(12, 10, 12, 10)),
          ],
          const SizedBox(height: 10),
          Text(_notaPlata(cobra), style: cf(size: 12, color: CM.gris2)),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _obs,
          maxLines: 2,
          minLines: 1,
          style: cf(size: 13),
          decoration: _deco('Observaciones (opcional)'),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: SwitchListTile(
            value: _imprimir,
            onChanged: (v) => setState(() => _imprimir = v),
            activeThumbColor: CM.verde,
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: CM.borde, width: 1.5)),
            title: Text('Imprimir el comprobante', style: cf(size: 13, w: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  String _notaPlata(bool cobra) {
    if (widget.cajaAbierta == false) return 'No hay caja abierta: solo transferencia o tarjeta.';
    if (_metodo == 'efectivo') {
      return cobra ? 'Entra a la caja abierta de hoy.' : 'Sale de la caja abierta de hoy.';
    }
    return cobra ? 'Queda registrado en la cuenta que elijas.' : 'Sale de la cuenta que elijas.';
  }

  List<Widget> _resumenPlata(CuentasOp c, bool cambio) {
    if (!cambio && c.aDeuda > 0) {
      return [
        tarjetaDev(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Era a crédito', style: cf(size: 12, w: FontWeight.w600, color: const Color(0xFF5B21B6))),
          const SizedBox(height: 2),
          Text('${pesosCO(c.aDeuda)} a su deuda', style: cf(size: 24, w: FontWeight.w800, color: const Color(0xFF5B21B6))),
          const SizedBox(height: 4),
          Text(c.reembolso > 0
              ? 'Devuelve ${pesosCO(c.trae)}: ${pesosCO(c.aDeuda)} pagan lo que debía y se le entregan ${pesosCO(c.reembolso)}.'
              : 'Devuelve ${pesosCO(c.trae)} y todo abona a lo que debe. No se le entrega plata.',
              style: cf(size: 12.5, color: const Color(0xFF334155))),
        ]), fondo: const Color(0xFFF5F3FF), borde: const Color(0xFFDDD6FE), padding: const EdgeInsets.all(14)),
        const SizedBox(height: 10),
        tarjetaDev(Column(children: [
          filaKV('Devuelve', pesosCO(c.trae)),
          filaKV('Abona a su deuda', '− ${pesosCO(c.aDeuda)}', color: CM.morado),
          filaKV('Le devuelves', pesosCO(c.reembolso), color: CM.rojo, fuerte: true, raya: true),
        ]), padding: const EdgeInsets.fromLTRB(12, 8, 12, 9)),
        if (c.reembolso <= 0) ...[
          const SizedBox(height: 10),
          Text('Si cancelas la devolución, la deuda vuelve.', style: cf(size: 12, color: CM.gris2)),
        ],
      ];
    }
    final (titulo, monto, color, fondo, borde) = !cambio
        ? ('Le devuelves', c.reembolso, CM.rojo, const Color(0xFFFFF1F2), const Color(0xFFFECDD3))
        : c.diferencia > 0
            ? ('El cliente te paga', c.diferencia, CM.verdeOs, const Color(0xFFECFDF5), CM.borde2)
            : c.diferencia < 0
                ? ('Le devuelves', -c.diferencia, CM.rojo, const Color(0xFFFFF1F2), const Color(0xFFFECDD3))
                : ('Cambio exacto', 0.0, CM.oscuro, Colors.white, CM.borde);
    final sub = cambio
        ? (c.diferencia == 0
            ? 'Trae ${pesosCO(c.trae)} y se lleva lo mismo: no hay plata que mover.'
            : 'Cambio: trae ${pesosCO(c.trae)} · se lleva ${pesosCO(c.lleva)}')
        : 'Devolución de ${cantidadTexto(_trae.fold<double>(0, (s, x) => s + x.cantidad))} producto(s)';
    return [
      tarjetaDev(Column(children: [
        Text(titulo, style: cf(size: 12, w: FontWeight.w600, color: color)),
        const SizedBox(height: 2),
        Text(monto == 0 && cambio ? pesosCO(0) : pesosCO(monto),
            style: cf(size: 26, w: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(sub, textAlign: TextAlign.center, style: cf(size: 12, color: CM.gris2)),
      ]), fondo: fondo, borde: borde, padding: const EdgeInsets.all(14)),
    ];
  }

  Widget _metodoBtn(String m, String t, IconData i, {bool deshabilitado = false}) {
    final on = _metodo == m && !deshabilitado;
    return Opacity(
      opacity: deshabilitado ? .45 : 1,
      child: Material(
        color: on ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: deshabilitado
              ? () => _aviso('No hay caja abierta: elige transferencia o tarjeta.')
              : () => setState(() {
                    _metodo = m;
                    _cuentaId = _cuentaUnica(m);
                  }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? CM.verde : CM.borde, width: on ? 1.8 : 1.5)),
            child: Column(children: [
              Icon(i, size: 19, color: CM.verdeOs),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown,
                  child: Text(t, maxLines: 1, style: cf(size: 12, w: FontWeight.w700,
                      color: on ? CM.verdeOs : const Color(0xFF334155)))),
              if (deshabilitado)
                Text('sin caja', style: cf(size: 10, color: CM.gris2)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Piezas ──

  Widget _chipChico(IconData? i, String t, VoidCallback f, {bool on = false}) => Material(
        color: on ? CM.verde : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? CM.verde : CM.borde2, width: 1.3)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (i != null) ...[Icon(i, size: 13, color: on ? Colors.white : CM.verdeOs), const SizedBox(width: 5)],
              Text(t, style: cf(size: 12, w: FontWeight.w700, color: on ? Colors.white : CM.verdeOs)),
            ]),
          ),
        ),
      );

  InputDecoration _deco(String t, {IconData? icono, String? prefijo}) => InputDecoration(
        labelText: icono == null ? t : null,
        hintText: icono != null ? t : null,
        labelStyle: cf(size: 13, color: CM.gris2),
        hintStyle: cf(size: 13, color: CM.gris2),
        prefixIcon: icono == null ? null : Icon(icono, size: 19, color: CM.gris2),
        prefixText: prefijo,
        prefixStyle: cf(size: 18, w: FontWeight.w800),
        filled: true, fillColor: Colors.white, isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: CM.borde, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: CM.verde, width: 1.6)),
      );
}

const _mesesLargos = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
String _diaTexto(DateTime d) => '${d.day} ${_mesesLargos[d.month]}';

String _miles(num v) => v.round().toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

class _MilesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue viejo, TextEditingValue nuevo) {
    final d = nuevo.text.replaceAll(RegExp(r'[^\d]'), '');
    if (d.isEmpty) return const TextEditingValue();
    final t = _miles(int.parse(d));
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// ── Hoja para buscar lo que se lleva ─────────────────────────

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

  void _cambio(String t) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 300), () => _buscar(t));
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
                onChanged: _cambio,
                style: cf(size: 14),
                decoration: InputDecoration(
                  hintText: 'Nombre, referencia o código',
                  hintStyle: cf(size: 13, color: CM.gris2),
                  prefixIcon: const Icon(Icons.search_rounded, size: 19, color: CM.gris2),
                  filled: true, fillColor: CM.fondo, isDense: true,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CM.borde, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CM.verde, width: 1.6)),
                ),
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
