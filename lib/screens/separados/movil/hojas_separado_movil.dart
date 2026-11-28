// lib/screens/separados/movil/hojas_separado_movil.dart
//
// Hojas del detalle de un separado en el celular: abonar, cambiar un
// producto y cancelar. Devuelven lo elegido; la pantalla habla con el servidor.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cuenta_bancaria.dart';
import '../../../models/pago_abono.dart';
import '../../../models/producto.dart';
import '../../../models/separado.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import 'separados_movil.dart';
import 'separados_reglas.dart';

// ── Piezas ────────────────────────────────────────────────────

String milesSep(num v) => v.round().toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

double leerPesosSep(String t) => double.tryParse(t.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

class MilesFormatterSep extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue viejo, TextEditingValue nuevo) {
    final d = nuevo.text.replaceAll(RegExp(r'[^\d]'), '');
    if (d.isEmpty) return const TextEditingValue();
    final t = milesSep(int.parse(d));
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

InputDecoration decoSep(String? label, {String? hint, IconData? icono, String? prefijo, bool grande = false}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: cf(size: 13, color: CM.gris2),
      hintStyle: cf(size: 13, color: CM.gris2),
      prefixIcon: icono == null ? null : Icon(icono, size: 19, color: CM.gris2),
      prefixText: prefijo,
      prefixStyle: cf(size: grande ? 20 : 14, w: FontWeight.w800),
      filled: true, fillColor: Colors.white, isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: grande ? 15 : 13, horizontal: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CM.borde, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CM.verde, width: 1.6)),
    );

Widget metodosSep(String actual, ValueChanged<String> f, {bool? cajaAbierta, void Function()? sinCaja}) => Row(children: [
      for (final (m, t, i) in [('efectivo', 'Efectivo', Icons.payments_outlined),
                               ('transferencia', 'Transferencia', Icons.account_balance_outlined),
                               ('tarjeta', 'Tarjeta', Icons.credit_card_rounded)]) ...[
        Expanded(child: _metodo(m, t, i, actual == m, m == 'efectivo' && cajaAbierta == false,
            () => m == 'efectivo' && cajaAbierta == false ? sinCaja?.call() : f(m))),
        if (m != 'tarjeta') const SizedBox(width: 6),
      ],
    ]);

Widget _metodo(String m, String t, IconData i, bool on, bool apagado, VoidCallback f) => Opacity(
      opacity: apagado ? .45 : 1,
      child: Material(
        color: on && !apagado ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on && !apagado ? CM.verde : CM.borde, width: on ? 1.8 : 1.5)),
            child: Column(children: [
              Icon(i, size: 19, color: CM.verdeOs),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, child: Text(t, maxLines: 1,
                  style: cf(size: 12, w: FontWeight.w700, color: on ? CM.verdeOs : const Color(0xFF334155)))),
              if (apagado) Text('sin caja', style: cf(size: 10, color: CM.gris2)),
            ]),
          ),
        ),
      ),
    );

List<CuentaBancaria> cuentasDeMetodo(List<CuentaBancaria> todas, String m) {
  if (m != 'transferencia' && m != 'tarjeta') return const [];
  return todas.where((c) => c.activo && (m == 'tarjeta' ? c.tipo == 'tarjeta' : c.tipo != 'tarjeta')).toList();
}

Widget hojaBase(BuildContext context, List<Widget> hijos) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)))),
            ...hijos,
          ]),
        ),
      ),
    );

Future<T?> abrirHojaSep<T>(BuildContext context, Widget hoja) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => hoja,
    );

void avisoSep(BuildContext context, String t, {bool error = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(t, style: cf(size: 13, color: Colors.white)),
      backgroundColor: error ? CM.rojo : CM.verde,
      behavior: SnackBarBehavior.floating,
    ));
}

// ══════════════════════════════════════════════════════════════
// ABONAR
// ══════════════════════════════════════════════════════════════

class ResultadoAbono {
  final List<PagoAbono> pagos;
  final bool imprimir;
  const ResultadoAbono(this.pagos, this.imprimir);
  double get total => pagos.fold(0, (s, p) => s + p.monto);
}

class HojaAbonarSep extends StatefulWidget {
  final Separado sep;
  final List<CuentaBancaria> cuentas;
  final bool? cajaAbierta;
  const HojaAbonarSep({super.key, required this.sep, this.cuentas = const [], this.cajaAbierta});

  @override
  State<HojaAbonarSep> createState() => _HojaAbonarSepState();
}

class _ParteAbono {
  final monto = TextEditingController();
  String metodo;
  int? cuenta;
  _ParteAbono(this.metodo);
}

class _HojaAbonarSepState extends State<HojaAbonarSep> {
  late final List<_ParteAbono> _partes = [_ParteAbono(widget.cajaAbierta == false ? 'transferencia' : 'efectivo')];
  bool _imprimir = true;

  double get _saldo => widget.sep.saldoPendiente;

  @override
  void initState() {
    super.initState();
    _ponerCuenta(_partes.first);
  }

  @override
  void dispose() {
    for (final p in _partes) {
      p.monto.dispose();
    }
    super.dispose();
  }

  void _ponerCuenta(_ParteAbono p) {
    final l = cuentasDeMetodo(widget.cuentas, p.metodo);
    p.cuenta = l.length == 1 ? l.first.id : null;
  }

  List<PagoAbono> get _pagos => [
        for (final p in _partes)
          PagoAbono(metodoPago: p.metodo, monto: leerPesosSep(p.monto.text),
              cuentaId: p.metodo == 'efectivo' ? null : p.cuenta),
      ];

  void _registrar() {
    final pagos = _pagos;
    final e = problemaAbono(pagos, _saldo, cajaAbierta: widget.cajaAbierta,
        cuentasDe: (m) => cuentasDeMetodo(widget.cuentas, m).length);
    if (e != null) {
      avisoSep(context, e);
      return;
    }
    Navigator.pop(context, ResultadoAbono(pagos, _imprimir));
  }

  @override
  Widget build(BuildContext context) {
    final total = _pagos.fold<double>(0, (s, p) => s + p.monto);
    final queda = _saldo - total;
    final dos = _partes.length == 2;
    return hojaBase(context, [
      Row(children: [
        Expanded(child: Text('Abonar a SEP-${widget.sep.id}', style: cf(size: 17, w: FontWeight.w800))),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Le falta ', style: cf(size: 12, color: CM.gris)),
          TextSpan(text: pesosCO(_saldo), style: cf(size: 12, w: FontWeight.w800, color: CM.rojo)),
        ])),
      ]),
      const SizedBox(height: 12),
      for (var i = 0; i < _partes.length; i++) ...[
        if (dos) Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Text('PARTE ${i + 1}', style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5)),
            const Spacer(),
            if (i == 1)
              TextButton(
                onPressed: () => setState(() => _partes.removeAt(1).monto.dispose()),
                child: Text('Quitar', style: cf(size: 12, w: FontWeight.w700, color: CM.rojo)),
              ),
          ]),
        ),
        _parte(_partes[i], i),
        const SizedBox(height: 12),
      ],
      if (!dos)
        OutlinedButton.icon(
          onPressed: () => setState(() {
            final p = _ParteAbono(_partes.first.metodo == 'efectivo' ? 'transferencia' : 'efectivo');
            if (p.metodo == 'efectivo' && widget.cajaAbierta == false) p.metodo = 'tarjeta';
            _ponerCuenta(p);
            final resto = _saldo - leerPesosSep(_partes.first.monto.text);
            if (resto > 0) p.monto.text = milesSep(resto);
            _partes.add(p);
          }),
          icon: const Icon(Icons.add_rounded, size: 17),
          label: Text('Pagar una parte con otro método', style: cf(size: 12.5, w: FontWeight.w700, color: CM.verdeOs)),
          style: botonContornoSep().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 42))),
        ),
      const SizedBox(height: 10),
      cajaSep(kvSep(queda >= 0 ? 'Después del abono le falta' : 'Es más de lo que le falta',
          pesosCO(queda.abs()), color: queda > 0 ? CM.rojo : queda == 0 ? CM.verdeOs : CM.rojo),
          fondo: const Color(0xFFF8FAFC)),
      if (queda == 0 && total > 0) ...[
        const SizedBox(height: 6),
        Text('Queda pagado completo: luego lo marcas como entregado cuando lo recoja.',
            style: cf(size: 11.5, color: CM.verdeOs)),
      ],
      const SizedBox(height: 6),
      SwitchListTile(
        value: _imprimir,
        onChanged: (v) => setState(() => _imprimir = v),
        activeThumbColor: CM.verde,
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text('Imprimir el recibo', style: cf(size: 13, w: FontWeight.w700)),
      ),
      FilledButton.icon(
        onPressed: _registrar,
        style: botonSep(),
        icon: const Icon(Icons.check_rounded, size: 18),
        label: Text(_imprimir ? 'Registrar abono e imprimir' : 'Registrar abono',
            style: cf(size: 14.5, w: FontWeight.w700, color: Colors.white)),
      ),
    ]);
  }

  Widget _parte(_ParteAbono p, int i) {
    final cuentas = cuentasDeMetodo(widget.cuentas, p.metodo);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: p.monto,
        keyboardType: TextInputType.number,
        inputFormatters: [MilesFormatterSep()],
        onChanged: (_) => setState(() {}),
        style: cf(size: 20, w: FontWeight.w800),
        decoration: decoSep(i == 0 ? '¿Cuánto abona?' : '¿Cuánto con este método?', prefijo: '\$ ', grande: true),
      ),
      if (i == 0 && _partes.length == 1) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (t, v) in montosRapidos(_saldo))
            chipSep(t, leerPesosSep(p.monto.text) == v, () => setState(() => p.monto.text = milesSep(v))),
        ]),
      ],
      const SizedBox(height: 10),
      metodosSep(p.metodo, (m) => setState(() {
        p.metodo = m;
        _ponerCuenta(p);
      }), cajaAbierta: widget.cajaAbierta,
          sinCaja: () => avisoSep(context, 'No hay caja abierta: el efectivo no se puede recibir.')),
      if (cuentas.length > 1) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('¿A qué cuenta?', style: cf(size: 11.5, w: FontWeight.w600, color: CM.gris2)),
          for (final c in cuentas) chipSep(c.nombre, p.cuenta == c.id, () => setState(() => p.cuenta = c.id)),
        ]),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// CAMBIAR PRODUCTO
// ══════════════════════════════════════════════════════════════

class ResultadoCambio {
  final Producto producto;
  final double cantidad;
  const ResultadoCambio(this.producto, this.cantidad);
}

class HojaCambiarSep extends StatefulWidget {
  final Separado sep;
  final DetalleSeparado detalle;
  final Future<List<Producto>> Function(String q) buscar;
  final Future<String?> Function(BuildContext context) escanear;

  const HojaCambiarSep({super.key, required this.sep, required this.detalle, required this.buscar,
      required this.escanear});

  @override
  State<HojaCambiarSep> createState() => _HojaCambiarSepState();
}

class _HojaCambiarSepState extends State<HojaCambiarSep> {
  final _q = TextEditingController();
  List<Producto> _l = [];
  Producto? _elegido;
  double _cant = 1;
  bool _cargando = false;
  Timer? _espera;
  int _pedido = 0;

  @override
  void initState() {
    super.initState();
    _cant = widget.detalle.cantidad;
  }

  @override
  void dispose() {
    _espera?.cancel();
    _q.dispose();
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
      if (l.length == 1 && _permitido(l.first, _cant)) _elegir(l.first);
    });
  }

  Future<void> _escanear() async {
    final c = await widget.escanear(context);
    if (c == null || c.trim().isEmpty || !mounted) return;
    _q.text = c.trim();
    await _buscar(c);
  }

  /// Cuánto puede tomar: lo que hay, más lo ya apartado si es el mismo producto.
  double _disponible(Producto p) =>
      p.stockActual + (p.id == widget.detalle.producto ? widget.detalle.cantidad : 0);

  bool _permitido(Producto p, double cant) =>
      cambioSep(widget.sep, widget.detalle, p.precio, cant).permitido && _disponible(p) >= cant;

  void _elegir(Producto p) {
    _elegido = p;
    _cant = _cant.clamp(1, _disponible(p).clamp(1, 9999));
  }

  @override
  Widget build(BuildContext context) {
    final p = _elegido;
    final c = p == null ? null : cambioSep(widget.sep, widget.detalle, p.precio, _cant);
    return hojaBase(context, [
      Text('Cambiar ${widget.detalle.productoNombre}', style: cf(size: 17, w: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Puede llevarse otro de igual o mayor valor; la diferencia se suma a lo que debe.',
          style: cf(size: 12, color: CM.gris)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: (t) {
              _espera?.cancel();
              _espera = Timer(const Duration(milliseconds: 300), () => _buscar(t));
            },
            style: cf(size: 13.5),
            decoration: decoSep(null, hint: 'Nombre, referencia o código', icono: Icons.search_rounded),
          ),
        ),
        const SizedBox(width: 8),
        iconoBoton(Icons.qr_code_scanner_rounded, 'Escanear', _escanear, borde: CM.borde2, t: 46),
      ]),
      if (_cargando) const LinearProgressIndicator(minHeight: 2, color: CM.verde, backgroundColor: Colors.transparent),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 230),
        child: _l.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_q.text.trim().isEmpty ? 'Busca o escanea el producto nuevo.' : 'Sin resultados.',
                    textAlign: TextAlign.center, style: cf(size: 12.5, color: CM.gris)),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _l.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _opcion(_l[i]),
              ),
      ),
      if (p != null && c != null) ...[
        const SizedBox(height: 10),
        cajaSep(Column(children: [
          kvSep('Total del separado', '${pesosCO(c.totalAntes)} → ${pesosCO(c.totalDespues)}'),
          kvSep('Ya abonó', pesosCO(c.abonado)),
          kvSep('Le falta', '${pesosCO(c.faltaAntes)} → ${pesosCO(c.faltaDespues)}',
              color: c.quedaPagado ? CM.verdeOs : CM.rojo, fuerte: true, raya: true),
        ])),
        const SizedBox(height: 6),
        Text(c.quedaPagado
            ? 'Con lo que ya abonó queda pagado completo.'
            : p.id == widget.detalle.producto
                ? 'Cambia la cantidad del mismo producto.'
                : '${widget.detalle.productoNombre} vuelve al stock y ${p.nombre} queda apartado.',
            style: cf(size: 11.5, color: CM.gris)),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: p == null || !_permitido(p, _cant)
            ? null
            : () => Navigator.pop(context, ResultadoCambio(p, _cant)),
        style: botonSep(),
        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
        label: Text('Confirmar cambio', style: cf(size: 14.5, w: FontWeight.w700, color: Colors.white)),
      ),
    ]);
  }

  Widget _opcion(Producto x) {
    final on = _elegido?.id == x.id;
    final disp = _disponible(x);
    final barato = !cambioSep(widget.sep, widget.detalle, x.precio, on ? _cant : 1).permitido;
    final sin = disp <= 0;
    final razon = sin ? 'sin stock' : barato ? 'vale menos de lo que ya abonó' : 'quedan ${cantidadTexto(disp)}';
    return Opacity(
      opacity: barato || sin ? .5 : 1,
      child: Material(
        color: on ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: barato || sin ? () => avisoSep(context, '${x.nombre}: $razon.') : () => setState(() => _elegir(x)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? CM.verde : const Color(0xFFE2E8F0), width: on ? 1.8 : 1.5)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.nombre, style: cf(size: 13, w: FontWeight.w800)),
                  Text('${pesosCO(x.precio)} · $razon', style: cf(size: 11.5, color: CM.gris2)),
                ]),
              ),
              if (on) ...[
                _boton('−', _cant > 1 ? () => setState(() => _cant--) : null, 'Menos'),
                SizedBox(width: 30, child: Text(cantidadTexto(_cant), textAlign: TextAlign.center,
                    style: cf(size: 15, w: FontWeight.w800))),
                _boton('+', _cant < disp ? () => setState(() => _cant++) : null, 'Más'),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _boton(String t, VoidCallback? f, String etiqueta) => Semantics(
        button: true,
        label: etiqueta,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: f,
            child: Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: f == null ? CM.borde : CM.borde2, width: 1.5)),
              child: Text(t, style: cf(size: 16, w: FontWeight.w800, color: f == null ? CM.borde2 : CM.verdeOs)),
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// CANCELAR
// ══════════════════════════════════════════════════════════════

class ResultadoCancelar {
  final String motivo;
  const ResultadoCancelar(this.motivo);
}

class HojaCancelarSep extends StatefulWidget {
  final Separado sep;
  const HojaCancelarSep({super.key, required this.sep});

  @override
  State<HojaCancelarSep> createState() => _HojaCancelarSepState();
}

class _HojaCancelarSepState extends State<HojaCancelarSep> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sep;
    final productos = s.detalles.map((d) => d.cantidad == 1 ? d.productoNombre
        : '${cantidadTexto(d.cantidad)} ${d.productoNombre}').join(' y ');
    final tieneAbonos = s.abonoAcumulado > 0;
    Widget linea(IconData i, Color c, InlineSpan t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 17, color: c),
            const SizedBox(width: 8),
            Expanded(child: Text.rich(t, style: cf(size: 12.5, color: const Color(0xFF334155)))),
          ]),
        );
    TextSpan b(String t) => TextSpan(text: t, style: cf(size: 12.5, w: FontWeight.w800));
    return hojaBase(context, [
      Text('¿Cancelar SEP-${s.id}?', style: cf(size: 17, w: FontWeight.w800)),
      const SizedBox(height: 10),
      cajaSep(Column(children: [
        linea(Icons.inventory_2_outlined, CM.verdeOs, TextSpan(children: [b(productos),
          TextSpan(text: s.detalles.length == 1 && s.detalles.first.cantidad == 1
              ? ' vuelve al stock.' : ' vuelven al stock.')])),
        linea(Icons.payments_outlined, CM.gris, const TextSpan(text: 'No se le devuelve plata.')),
        if (tieneAbonos)
          linea(Icons.card_giftcard_rounded, CM.morado, TextSpan(children: [
            const TextSpan(text: 'Los '),
            b(pesosCO(s.abonoAcumulado)),
            const TextSpan(text: ' que abonó quedan '),
            b('a su favor'),
            const TextSpan(text: ' en un bono a su nombre, para otra compra de igual o mayor valor.'),
          ]))
        else
          linea(Icons.info_outline_rounded, CM.gris, const TextSpan(text: 'No tenía abonos: no queda saldo a favor.')),
      ])),
      const SizedBox(height: 12),
      TextField(
        controller: _motivo,
        maxLength: 200,
        style: cf(size: 13.5),
        decoration: decoSep('Motivo (opcional)', hint: 'Ej: ya no lo quiere, no volvió…'),
      ),
      const SizedBox(height: 4),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, ResultadoCancelar(_motivo.text.trim())),
        style: botonSep(c: CM.rojo),
        icon: const Icon(Icons.undo_rounded, size: 18),
        label: Text(tieneAbonos ? 'Sí, cancelar y crear bono' : 'Sí, cancelar',
            style: cf(size: 14.5, w: FontWeight.w700, color: Colors.white)),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: botonContornoSep(),
        child: Text('Volver', style: cf(size: 14, w: FontWeight.w700, color: CM.verdeOs)),
      ),
    ]);
  }
}
