// lib/screens/compras/movil/orden_movil.dart
//
// En el celular: detalle de una orden de compra, recibir la mercancía
// fijando precios (con el margen en color) y la hoja para pagarle al
// proveedor (efectivo o cuenta, y si salió del cajón).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cuenta_bancaria.dart';
import '../../clientes/widgets/cliente_contacto.dart'
    show abrirWhatsAppNumero, llamarNumero, pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import 'compras_movil.dart' show estadoOrden, etiquetaCompra;
import 'compras_reglas.dart';

const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
String _fecha(DateTime f) => '${f.day} ${_meses[f.month]} ${f.year}';
String _hora(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  return '$h:${f.minute.toString().padLeft(2, '0')} ${f.hour < 12 ? 'a. m.' : 'p. m.'}';
}

String _miles(num v) => v.round().toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
double? _leer(String t) {
  final d = t.replaceAll(RegExp(r'[^\d]'), '');
  return d.isEmpty ? null : double.tryParse(d);
}

Widget _tarjeta(Widget child, {Color borde = CM.borde, EdgeInsets? padding}) => Container(
      padding: padding ?? const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borde, width: 1.5)),
      child: child,
    );

Widget _barraAbajo(List<Widget> hijos) => Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CM.borde))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos)),
    );

ButtonStyle botonVerde({Color c = CM.verde}) => FilledButton.styleFrom(
      backgroundColor: c, minimumSize: const Size(0, 48),
      disabledBackgroundColor: CM.borde,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

// ══════════════════════════════════════════════════════════════
// DETALLE DE LA ORDEN
// ══════════════════════════════════════════════════════════════

class OrdenDetalleMovil extends StatelessWidget {
  final Map<String, dynamic> orden;
  final String? telefonoProveedor;
  final bool cargando;
  final DateTime hoy;
  final VoidCallback onRecibir;
  final VoidCallback onPagar;
  final VoidCallback onPdf;
  final VoidCallback onCancelar;

  const OrdenDetalleMovil({super.key, required this.orden, required this.hoy,
      required this.onRecibir, required this.onPagar, required this.onPdf,
      required this.onCancelar, this.telefonoProveedor, this.cargando = false});

  @override
  Widget build(BuildContext context) {
    final c = orden;
    final (txt, col, bg) = estadoOrden(c);
    final detalles = [for (final d in (c['detalles'] as List? ?? const [])) Map<String, dynamic>.from(d as Map)];
    final f = fechaDe(c['fecha_orden']);
    final venc = fechaDe(c['fecha_vencimiento']);
    final dias = diasParaPagar(c, hoy);
    final unidades = detalles.fold<double>(0, (a, d) => a + numDe(d['cantidad']));
    final prov = '${c['proveedor_nombre'] ?? ''}';
    final tel = telefonoProveedor ?? '';
    return Scaffold(
      backgroundColor: CM.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: CM.verdeOs,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${c['numero_orden'] ?? 'Orden'}', style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
          if (f != null)
            Text('Creada el ${_fecha(f)} ${_hora(f)}'
                '${'${c['empleado_nombre'] ?? ''}'.isEmpty ? '' : ' por ${c['empleado_nombre']}'}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 11, color: CM.gris2)),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => v == 'pdf' ? onPdf() : onCancelar(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pdf', child: Text('PDF de la orden')),
              if (esPendiente(c))
                const PopupMenuItem(value: 'cancelar',
                    child: Text('Cancelar orden', style: TextStyle(color: CM.rojo))),
            ],
          ),
        ],
      ),
      body: cargando && detalles.isEmpty
          ? const Center(child: CircularProgressIndicator(color: CM.verde))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              children: [
                _tarjeta(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    etiquetaCompra(txt, col, bg),
                    if (esCredito(c))
                      etiquetaCompra(
                          c['pagado'] == true ? 'Crédito · pagada'
                              : venc == null ? 'Crédito'
                              : porPagar(c) && dias != null ? 'Crédito · ${textoPago(dias).toLowerCase()}'
                              : 'Crédito · paga el ${venc.day} ${_meses[venc.month]}',
                          const Color(0xFF5B21B6), const Color(0xFFEDE9FE))
                    else if (esRecibida(c))
                      etiquetaCompra('De contado', CM.verdeOs, CM.borde),
                  ]),
                  const SizedBox(height: 8),
                  Text(prov, style: cf(size: 15, w: FontWeight.w800)),
                  Text(textoTiendas(c), style: cf(size: 12, color: CM.gris)),
                  if ('${c['observaciones'] ?? ''}'.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('${c['observaciones']}', style: cf(size: 12, color: const Color(0xFF334155))),
                  ],
                  if (tel.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => llamarNumero(context, tel, prov),
                        icon: const Icon(Icons.phone_outlined, size: 16, color: CM.verdeOs),
                        label: Text('Llamar', style: cf(size: 12.5, w: FontWeight.w800, color: CM.verdeOs)),
                        style: _borde(),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => abrirWhatsAppNumero(context, tel, prov,
                            mensaje: 'Hola, le escribimos por la orden ${c['numero_orden']}.'),
                        icon: const Icon(Icons.chat_outlined, size: 16, color: Color(0xFF15803D)),
                        label: Text('WhatsApp', style: cf(size: 12.5, w: FontWeight.w800, color: const Color(0xFF15803D))),
                        style: _borde(),
                      )),
                    ]),
                  ],
                ])),
                const SizedBox(height: 14),
                Text('PRODUCTOS · ${detalles.length}', style: cf(size: 10.5, w: FontWeight.w800, color: CM.verdeOs, ls: .8)),
                const SizedBox(height: 8),
                for (final d in detalles) ...[_producto(d), const SizedBox(height: 8)],
              ],
            ),
      bottomNavigationBar: _barraAbajo([
        Row(children: [
          Expanded(child: Text('${detalles.length} productos · ${_miles(unidades)} unidades',
              style: cf(size: 12.5, color: CM.gris))),
          Text(pesosCO(numDe(c['total'])), style: cf(size: 17, w: FontWeight.w800, color: CM.oscuro)),
        ]),
        if (esPendiente(c)) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: cargando ? null : onRecibir,
            style: botonVerde(),
            icon: const Icon(Icons.local_shipping_outlined, size: 19),
            label: Text('Recibir mercancía', style: cf(size: 14, w: FontWeight.w800, color: Colors.white)),
          ),
        ] else if (porPagar(c)) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onPagar,
            style: botonVerde(c: CM.morado),
            icon: const Icon(Icons.payments_outlined, size: 19),
            label: Text('Pagar al proveedor', style: cf(size: 14, w: FontWeight.w800, color: Colors.white)),
          ),
        ] else ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPdf,
            style: _borde().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 46))),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: CM.verdeOs),
            label: Text('PDF de la orden', style: cf(size: 13.5, w: FontWeight.w800, color: CM.verdeOs)),
          ),
        ],
      ]),
    );
  }

  ButtonStyle _borde() => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        side: const BorderSide(color: CM.borde2, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _producto(Map<String, dynamic> d) {
    final reps = [for (final r in (d['distribuciones'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
    final nuevo = d['producto'] == null;
    final cod = '${d['codigo_barras_input'] ?? ''}';
    return _tarjeta(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: nombreProducto(d), style: cf(size: 13, w: FontWeight.w800)),
              if (nuevo) TextSpan(text: '  nuevo', style: cf(size: 11, w: FontWeight.w800, color: CM.ambar)),
            ])),
            if (cod.isNotEmpty || '${d['categoria_nombre'] ?? ''}'.isNotEmpty)
              Text([if (cod.isNotEmpty) cod, if ('${d['categoria_nombre'] ?? ''}'.isNotEmpty) '${d['categoria_nombre']}']
                  .join(' · '), style: cf(size: 11, color: CM.gris2)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_miles(numDe(d['cantidad']))} × ${pesosCO(numDe(d['precio_unitario']))}',
              style: cf(size: 11, color: CM.gris2)),
          Text(pesosCO(numDe(d['subtotal'])), style: cf(size: 13.5, w: FontWeight.w800)),
        ]),
      ]),
      if (reps.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in reps)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
              child: Text('${r['tienda_nombre'] ?? 'Tienda'} · ${_miles(numDe(r['cantidad']))}',
                  style: cf(size: 11, w: FontWeight.w700, color: CM.verdeOs)),
            ),
        ]),
      ],
    ]));
  }
}

// ══════════════════════════════════════════════════════════════
// PAGO AL PROVEEDOR (hoja) — también se usa al recibir de contado
// ══════════════════════════════════════════════════════════════

/// Lo que se manda al servidor: metodo_pago, cuenta_bancaria, fecha, de_caja.
class FormaPago extends StatefulWidget {
  final List<CuentaBancaria> cuentas;
  final bool cajaAbierta;
  final DateTime hoy;
  final ValueChanged<Map<String, dynamic>> onCambio;
  const FormaPago({super.key, required this.cuentas, required this.cajaAbierta,
      required this.hoy, required this.onCambio});

  @override
  State<FormaPago> createState() => _FormaPagoState();
}

class _FormaPagoState extends State<FormaPago> {
  String _metodo = 'transferencia';
  int? _cuenta;
  bool _deCaja = false;
  late DateTime _fecha = widget.hoy;

  @override
  void initState() {
    super.initState();
    if (widget.cuentas.length == 1) _cuenta = widget.cuentas.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _avisar());
  }

  bool get _esHoy => _fecha.year == widget.hoy.year && _fecha.month == widget.hoy.month && _fecha.day == widget.hoy.day;

  void _avisar() => widget.onCambio({
        'metodo_pago': _metodo,
        if (_metodo == 'transferencia' && _cuenta != null) 'cuenta_bancaria': _cuenta,
        'fecha': '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
        'de_caja': _metodo == 'efectivo' && _esHoy && widget.cajaAbierta && _deCaja,
      });

  void _set(VoidCallback f) {
    setState(f);
    _avisar();
  }

  @override
  Widget build(BuildContext context) {
    Widget opcion(String k, String t, IconData i) {
      final on = _metodo == k;
      return Expanded(
        child: Material(
          color: on ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _set(() => _metodo = k),
            child: Container(
              height: 46,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? CM.verde : const Color(0xFFE2E8F0), width: 1.5)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, size: 18, color: CM.verdeOs),
                const SizedBox(width: 6),
                Text(t, style: cf(size: 13, w: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('¿DE DÓNDE SALIÓ LA PLATA?', style: cf(size: 10.5, w: FontWeight.w800, color: CM.verdeOs, ls: .8)),
      const SizedBox(height: 8),
      Row(children: [
        opcion('efectivo', 'Efectivo', Icons.payments_outlined),
        const SizedBox(width: 8),
        opcion('transferencia', 'Transferencia', Icons.account_balance_outlined),
      ]),
      if (_metodo == 'transferencia' && widget.cuentas.isNotEmpty) ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _cuenta,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Cuenta', isDense: true,
            labelStyle: cf(size: 12, color: CM.gris),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CM.borde, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CM.verde, width: 1.6)),
          ),
          style: cf(size: 13.5, w: FontWeight.w700),
          items: [
            for (final c in widget.cuentas)
              DropdownMenuItem(value: c.id, child: Text(c.numero.isEmpty ? c.nombre : '${c.nombre} · ${c.numero}',
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => _set(() => _cuenta = v),
        ),
      ],
      const SizedBox(height: 10),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final f = await showDatePicker(
              context: context, initialDate: _fecha,
              firstDate: DateTime(widget.hoy.year - 1), lastDate: widget.hoy,
              helpText: 'Fecha del pago', cancelText: 'Cancelar', confirmText: 'Listo',
            );
            if (f != null) _set(() => _fecha = f);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5)),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: CM.verdeOs),
              const SizedBox(width: 8),
              Text('Fecha del pago: ', style: cf(size: 12.5, color: CM.gris)),
              Text(_esHoy ? 'Hoy' : _fecha2(_fecha),
                  style: cf(size: 12.5, w: FontWeight.w800)),
            ]),
          ),
        ),
      ),
      if (_metodo == 'efectivo' && _esHoy && widget.cajaAbierta) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.5), color: const Color(0xFFFFFBEB)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Salió del cajón de la caja', style: cf(size: 13, w: FontWeight.w700)),
                Text('Se descuenta en el cierre de hoy', style: cf(size: 11.5, color: CM.gris)),
              ]),
            ),
            Switch(value: _deCaja, activeTrackColor: CM.ambar, activeThumbColor: Colors.white,
                onChanged: (v) => _set(() => _deCaja = v)),
          ]),
        ),
      ],
    ]);
  }

  String _fecha2(DateTime f) => '${f.day} ${_meses[f.month]}';
}

class HojaPagoProveedor extends StatefulWidget {
  final Map<String, dynamic> compra;
  final List<CuentaBancaria> cuentas;
  final bool cajaAbierta;
  final DateTime hoy;
  final Future<String?> Function(Map<String, dynamic> pago) onPagar;
  const HojaPagoProveedor({super.key, required this.compra, required this.cuentas,
      required this.cajaAbierta, required this.hoy, required this.onPagar});

  @override
  State<HojaPagoProveedor> createState() => _HojaPagoProveedorState();
}

class _HojaPagoProveedorState extends State<HojaPagoProveedor> {
  Map<String, dynamic> _pago = const {};
  bool _guardando = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final c = widget.compra;
    final falta = _pago['metodo_pago'] == 'transferencia' && widget.cuentas.isNotEmpty &&
        _pago['cuenta_bancaria'] == null;
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          Text('Pagar ${c['numero_orden'] ?? ''}', style: cf(size: 17, w: FontWeight.w800)),
          Text('${c['proveedor_nombre'] ?? ''} · ${pesosCO(numDe(c['total']))}', style: cf(size: 12.5, color: CM.gris)),
          const SizedBox(height: 14),
          FormaPago(cuentas: widget.cuentas, cajaAbierta: widget.cajaAbierta, hoy: widget.hoy,
              onCambio: (p) => setState(() => _pago = p)),
          const SizedBox(height: 10),
          Text('Se registra como gasto de Proveedor en Gastos y nómina.',
              style: cf(size: 11.5, color: CM.gris2)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: cf(size: 12.5, w: FontWeight.w700, color: CM.rojo)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _guardando || falta ? null : () async {
              setState(() {
                _guardando = true;
                _error = null;
              });
              final e = await widget.onPagar(_pago);
              if (mounted) {
                setState(() {
                  _guardando = false;
                  _error = e;
                });
              }
            },
            style: botonVerde(),
            child: _guardando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(falta ? 'Elige la cuenta' : 'Registrar pago',
                    style: cf(size: 14, w: FontWeight.w800, color: falta ? CM.verdeOs : Colors.white)),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RECIBIR
// ══════════════════════════════════════════════════════════════

class ResultadoRecibir {
  final Map<String, double> precios;
  final Map<String, double> preciosMayoreo;
  final Map<String, dynamic>? pago;
  const ResultadoRecibir(this.precios, this.preciosMayoreo, this.pago);
}

class RecibirMovil extends StatefulWidget {
  final Map<String, dynamic> orden;
  final bool manejaMayoreo;
  final List<CuentaBancaria> cuentas;
  final bool cajaAbierta;
  final DateTime hoy;
  /// null si se recibió; si no, el error.
  final Future<String?> Function(ResultadoRecibir r) onConfirmar;
  const RecibirMovil({super.key, required this.orden, required this.manejaMayoreo,
      required this.cuentas, required this.cajaAbierta, required this.hoy, required this.onConfirmar});

  @override
  State<RecibirMovil> createState() => _RecibirMovilState();
}

class _RecibirMovilState extends State<RecibirMovil> {
  late final List<Map<String, dynamic>> _det = [
    for (final d in (widget.orden['detalles'] as List? ?? const [])) Map<String, dynamic>.from(d as Map),
  ];
  final Map<String, TextEditingController> _venta = {}, _mayoreo = {};
  Map<String, dynamic>? _pago;
  bool _guardando = false;
  String? _error;

  bool get _contado => !esCredito(widget.orden);

  @override
  void initState() {
    super.initState();
    for (final d in _det) {
      final id = '${d['id']}';
      final venta = precioSugerido(d);
      var mayoreo = precioSugerido(d, mayoreo: true);
      // El de mayoreo sugerido nunca por encima del de venta.
      if (numDe(d['precio_mayoreo']) <= 0 && mayoreo > venta) mayoreo = venta;
      _venta[id] = TextEditingController(text: _miles(venta));
      _mayoreo[id] = TextEditingController(text: _miles(mayoreo));
    }
  }

  @override
  void dispose() {
    for (final c in [..._venta.values, ..._mayoreo.values]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _bajoCosto => [
        for (final d in _det)
          if ((_leer(_venta['${d['id']}']!.text) ?? 0) > 0 &&
              (_leer(_venta['${d['id']}']!.text) ?? 0) < numDe(d['precio_unitario']))
            nombreProducto(d),
      ];

  Future<void> _confirmar() async {
    final precios = <String, double>{}, mayoreo = <String, double>{};
    for (final d in _det) {
      final id = '${d['id']}';
      final v = _leer(_venta[id]!.text);
      if (v == null || v <= 0) {
        setState(() => _error = 'Escribe el precio de venta de ${nombreProducto(d)}.');
        return;
      }
      precios[id] = v;
      if (widget.manejaMayoreo) {
        final m = _leer(_mayoreo[id]!.text);
        if (m != null && m > 0) mayoreo[id] = m;
      }
    }
    if (_contado && _pago?['metodo_pago'] == 'transferencia' && widget.cuentas.isNotEmpty &&
        _pago?['cuenta_bancaria'] == null) {
      setState(() => _error = 'Elige de qué cuenta salió el pago.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final e = await widget.onConfirmar(ResultadoRecibir(precios, mayoreo, _contado ? _pago : null));
    if (mounted) {
      setState(() {
        _guardando = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.orden;
    final venc = fechaDe(o['fecha_vencimiento']);
    final bajos = _bajoCosto;
    return Scaffold(
      backgroundColor: CM.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white, surfaceTintColor: Colors.white, foregroundColor: CM.verdeOs,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recibir ${o['numero_orden'] ?? ''}', style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
          Text('Revisa los precios de venta antes de confirmar', style: cf(size: 11, color: CM.gris2)),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          for (final d in _det) ...[_tarjetaPrecio(d), const SizedBox(height: 8)],
          if (bajos.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3), width: 1.5)),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: CM.rojo, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('${bajos.join(', ')} quedaría${bajos.length == 1 ? '' : 'n'} a menos de lo que costó.',
                    style: cf(size: 12.5, w: FontWeight.w600, color: const Color(0xFF9F1239)))),
              ]),
            ),
          if (_contado) ...[
            const SizedBox(height: 14),
            _tarjeta(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Es de contado: se paga ahora', style: cf(size: 13.5, w: FontWeight.w800)),
              Text('Queda como gasto de Proveedor por ${pesosCO(numDe(o['total']))}.',
                  style: cf(size: 12, color: CM.gris)),
              const SizedBox(height: 12),
              FormaPago(cuentas: widget.cuentas, cajaAbierta: widget.cajaAbierta, hoy: widget.hoy,
                  onCambio: (p) => _pago = p),
            ])),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: cf(size: 12.5, w: FontWeight.w700, color: CM.rojo)),
          ],
        ],
      ),
      bottomNavigationBar: _barraAbajo([
        Row(children: [
          Expanded(child: Text(
              _contado ? 'De contado' : venc == null ? 'A crédito' : 'Es a crédito: se paga el ${venc.day} ${_meses[venc.month]}',
              style: cf(size: 12.5, color: CM.gris))),
          Text(pesosCO(numDe(o['total'])), style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
        ]),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _guardando ? null : _confirmar,
          style: botonVerde(),
          icon: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 19),
          label: Text('Confirmar recepción', style: cf(size: 14, w: FontWeight.w800, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _tarjetaPrecio(Map<String, dynamic> d) {
    final id = '${d['id']}';
    final costo = numDe(d['precio_unitario']);
    final venta = _leer(_venta[id]!.text) ?? 0;
    final (txt, nivel) = textoMargen(costo, venta);
    final (col, bg) = switch (nivel) {
      0 => (CM.verdeOs, CM.borde),
      1 => (const Color(0xFF92400E), const Color(0xFFFEF3C7)),
      _ => (CM.rojo, const Color(0xFFFFE4E6)),
    };
    Widget campo(String t, TextEditingController c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: cf(size: 10.5, w: FontWeight.w600, color: CM.gris2)),
            const SizedBox(height: 3),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (_) => setState(() {}),
              style: cf(size: 13.5, w: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true, prefixText: r'$ ', prefixStyle: cf(size: 13, w: FontWeight.w700, color: CM.gris2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: CM.borde, width: 1.4)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: CM.verde, width: 1.6)),
              ),
            ),
          ]),
        );
    return _tarjeta(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(nombreProducto(d), style: cf(size: 13, w: FontWeight.w800))),
        Text('Llegan ${_miles(numDe(d['cantidad']))}', style: cf(size: 11, w: FontWeight.w600, color: CM.gris2)),
      ]),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Costo', style: cf(size: 10.5, w: FontWeight.w600, color: CM.gris2)),
            const SizedBox(height: 3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Text(pesosCO(costo), style: cf(size: 13.5, w: FontWeight.w800, color: CM.gris)),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        campo('Precio venta', _venta[id]!),
        if (widget.manejaMayoreo) ...[
          const SizedBox(width: 8),
          campo('Mayoreo', _mayoreo[id]!),
        ],
      ]),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: etiquetaCompra(txt, col, bg)),
    ]));
  }
}
