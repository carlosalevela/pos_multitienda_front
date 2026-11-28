// Devoluciones en el celular: reglas y pantallas con capturas.
//
// Con --dart-define=SHOT_DIR=<carpeta> guarda capturas PNG.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/models/cuenta_bancaria.dart';
import 'package:pos_multitienda_app/models/devolucion_model.dart';
import 'package:pos_multitienda_app/models/producto.dart';
import 'package:pos_multitienda_app/models/venta_model.dart';
import 'package:pos_multitienda_app/screens/devoluciones/movil/devolucion_detalle_movil.dart';
import 'package:pos_multitienda_app/screens/devoluciones/movil/devoluciones_movil.dart';
import 'package:pos_multitienda_app/screens/devoluciones/movil/devoluciones_reglas.dart';
import 'package:pos_multitienda_app/screens/devoluciones/movil/nueva_devolucion_movil.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/inventario_movil.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _iconos =
    r'C:\dev\flutter_windows_3.35.4-stable\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
final _marco = GlobalKey();
final _hoy = DateTime(2026, 11, 27, 11);

Future<void> _fuentes() async {
  Future<ByteData> leer(String p) async => ByteData.sublistView(await File(p).readAsBytes());
  const sans = [r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\seguisb.ttf', r'C:\Windows\Fonts\segoeuib.ttf'];
  if (sans.every((p) => File(p).existsSync())) {
    final f = FontLoader('TestSans');
    for (final p in sans) {
      f.addFont(leer(p));
    }
    await f.load();
    InventarioMovil.fuenteDePrueba = 'TestSans';
  } else {
    InventarioMovil.fuenteDePrueba = 'Roboto';
  }
  if (File(_iconos).existsSync()) await (FontLoader('MaterialIcons')..addFont(leer(_iconos))).load();
}

Future<void> _foto(WidgetTester t, String n) async {
  if (_shotDir.isEmpty) return;
  final ro = _marco.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 1.5);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$_shotDir${Platform.pathSeparator}$n').writeAsBytes(png!.buffer.asUint8List());
  });
}

Future<void> _montar(WidgetTester t, Widget w, {double ancho = 390, double alto = 844}) async {
  t.view.physicalSize = Size(ancho * 2, alto * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: _marco, child: w)));
  await t.pump();
}

// ── Datos de ejemplo ───────────────────────────────────────

DetalleDevolucionModel _det(String n, double c, double p, {bool averia = true, String motivo = ''}) =>
    DetalleDevolucionModel(id: 0, productoId: n.hashCode, productoNombre: n, cantidad: c,
        precioUnitario: p, subtotal: c * p, motivo: motivo, aAverias: averia);

DevolucionModel _dev(int id, {String tipo = 'devolucion', String estado = 'procesada', double total = 0,
        String metodo = 'efectivo', double abonado = 0, String venta = 'FV-1203', String cliente = 'Emma Castillo',
        DateTime? cuando, List<DetalleDevolucionModel>? det, List<DetalleReemplazoModel> reemp = const [],
        double? dif, String? tipoDif, String? metodoDif, double? recibido, double? vueltas, double? totalReemp}) =>
    DevolucionModel(
      id: id, ventaId: 1, ventaNumero: venta, tiendaId: 1, tiendaNombre: 'Consentida Accesorios',
      empleadoNombre: 'Leidy Estrada', clienteNombre: cliente, totalDevuelto: total,
      metodoDevolucion: metodo, tipo: tipo, estado: estado, observaciones: '',
      createdAt: cuando ?? _hoy, detalles: det ?? const [], reemplazos: reemp, abonadoCredito: abonado,
      diferencia: dif, tipoDiferencia: tipoDif, metodoPagoDiferencia: metodoDif, montoRecibido: recibido,
      cambioEntregado: vueltas, totalReemplazo: totalReemp,
    );

List<DevolucionModel> _lista() => [
      _dev(212, total: 45000, cuando: DateTime(2026, 11, 27, 10, 42), det: [
        _det('Bolso Lía café', 1, 30000, averia: false),
        _det('Aretes perla', 1, 15000, motivo: 'broche partido'),
      ]),
      _dev(211, tipo: 'cambio', total: 45000, venta: 'FV-1198', cliente: 'Consumidor Final',
          cuando: DateTime(2026, 11, 27, 9, 15), det: [_det('Correa negra', 1, 45000, averia: false)],
          reemp: const [DetalleReemplazoModel(id: 1, productoId: 9, productoNombre: 'Correa café', cantidad: 1,
              precioUnitario: 57000, subtotal: 57000)],
          dif: 12000, tipoDif: 'cobrar', metodoDif: 'transferencia', totalReemp: 57000),
      _dev(209, total: 40000, metodo: 'nota_credito', abonado: 40000, venta: 'FV-1150', cliente: 'Julia Rosero',
          cuando: DateTime(2026, 11, 26, 16), det: [_det('Billetera Nova', 1, 40000)]),
      _dev(205, total: 30000, estado: 'cancelada', venta: 'FV-1101', cliente: 'Sara Chamorro',
          cuando: DateTime(2026, 11, 24, 12), det: [_det('Gafas sol', 1, 30000)]),
    ];

VentaResumenModel _venta(int id, String fv, String cliente, double total, DateTime f) => VentaResumenModel(
    id: id, numeroFactura: fv, clienteNombre: cliente, total: total, estado: 'completada', createdAt: f);

ProductoDisponibleModel _pd(int id, String n, double p, double disp) => ProductoDisponibleModel(
    productoId: id, productoNombre: n, precioUnitario: p, cantidadVendida: disp, yaDevuelta: 0, disponible: disp);

final _ventasHoy = [
  _venta(1203, 'FV-1203', 'Emma Castillo', 124000, DateTime(2026, 11, 27, 10, 20)),
  _venta(1202, 'FV-1202', 'Consumidor Final', 38000, DateTime(2026, 11, 27, 10, 2)),
  _venta(1199, 'FV-1199', 'Aida Sánchez', 212500, DateTime(2026, 11, 27, 9, 31)),
  _venta(1150, 'FV-1150', 'Julia Rosero', 95000, DateTime(2026, 11, 27, 9, 5)),
];

final _disponibles = {
  1203: VentaDisponibleModel(ventaId: 1203, numeroFactura: 'FV-1203', total: 124000, todosDevueltos: false,
      clienteNombre: 'Emma Castillo', productos: [
        _pd(1, 'Bolso Lía café', 30000, 1), _pd(2, 'Aretes perla', 15000, 2), _pd(3, 'Correa negra', 79000, 1)]),
  1150: VentaDisponibleModel(ventaId: 1150, numeroFactura: 'FV-1150', total: 95000, todosDevueltos: false,
      aCredito: true, saldoPendiente: 40000, clienteNombre: 'Julia Rosero', productos: [
        _pd(4, 'Billetera Nova', 30000, 1), _pd(5, 'Gafas sol', 25000, 1)]),
  1202: const VentaDisponibleModel(ventaId: 1202, numeroFactura: 'FV-1202', total: 38000, todosDevueltos: true,
      productos: []),
};

final _bolsoNegro = Producto(id: 30, nombre: 'Bolso Lía negro', precio: 57000, categoria: 'Bolsos', stockActual: 4);

ServiciosNuevaDev _servicios({required void Function(PedidoDev) alRegistrar, String? codigo}) => ServiciosNuevaDev(
      ventasDelDia: (_) async => _ventasHoy,
      buscarFactura: (n) async => _ventasHoy.where((v) => v.numeroFactura == n).toList(),
      disponible: (v) async => (_disponibles[v.id], _disponibles[v.id] == null ? 'no' : null),
      buscarProductos: (q) async => q == '770999' || q.toLowerCase().contains('bolso') ? [_bolsoNegro] : [],
      escanear: (_) async => codigo,
      registrar: (p) async {
        alRegistrar(p);
        return null;
      },
    );

final _cuentas = [
  CuentaBancaria(id: 1, nombre: 'Nequi', tipo: 'nequi', tipoDisplay: 'Nequi', numero: '300', activo: true, orden: 0),
  CuentaBancaria(id: 2, nombre: 'Bancolombia', tipo: 'ahorros', tipoDisplay: 'Ahorros', numero: '123', activo: true, orden: 1),
];

/// Botón (+ / −) en la misma fila que el nombre del producto.
Finder _enFila(String producto, String boton) => find.descendant(
    of: find.ancestor(of: find.ancestor(of: find.text(producto), matching: find.byType(Column)).first,
        matching: find.byType(Row)).first,
    matching: find.text(boton));

void main() {
  setUpAll(_fuentes);

  group('reglas', () {
    test('filtros', () {
      final l = _lista();
      expect(devsVisibles(l, FiltroDevs.todas, '').length, 4);
      expect(devsVisibles(l, FiltroDevs.devoluciones, '').map((d) => d.id), [212, 209]);
      expect(devsVisibles(l, FiltroDevs.cambios, '').map((d) => d.id), [211]);
      expect(devsVisibles(l, FiltroDevs.canceladas, '').map((d) => d.id), [205]);
      expect(devsVisibles(l, FiltroDevs.todas, 'correa café').map((d) => d.id), [211]);
      expect(devsVisibles(l, FiltroDevs.todas, 'dev-209').map((d) => d.id), [209]);
    });

    test('resumen: solo cuenta la plata que salió o entró', () {
      final r = resumirDevs(_lista(), _hoy);
      expect(r.hoy, 2);
      expect(textoHoy(r), '1 devolución · 1 cambio');
      expect(r.devuelto, 45000); // la de crédito no sacó plata; la cancelada no cuenta
      expect(r.cobrado, 12000);
      expect(r.unidadesAverias, 2); // aretes + billetera
    });

    test('monto y destino de cada tarjeta', () {
      final l = _lista();
      expect(montoDev(l[0]).texto, '− \$45.000');
      expect(montoDev(l[0]).sentido, Sentido.sale);
      expect(destinoDev(l[0]), 'Mixto');
      expect(montoDev(l[1]).texto, '+ \$12.000');
      expect(montoDev(l[1]).detalle, 'Te pagó · Transferencia');
      expect(montoDev(l[2]).texto, '\$40.000 a su deuda');
      expect(destinoDev(l[2]), 'Avería');
      expect(montoDev(l[3]).detalle, 'Cancelada');
      expect(productosDev(l[1]), 'Correa negra → Correa café');
    });

    test('crédito: primero abona a la deuda', () {
      final v = _disponibles[1150]!;
      final t = [LineaTrae(v.productos[0], cantidad: 1), LineaTrae(v.productos[1], cantidad: 1)];
      final c = cuentasOp(TipoOp.devolucion, v, t, const []);
      expect(c.trae, 55000);
      expect(c.aDeuda, 40000);
      expect(c.reembolso, 15000);
      final solo = cuentasOp(TipoOp.devolucion, v, [t[1]], const []);
      expect(solo.aDeuda, 25000);
      expect(solo.reembolso, 0);
      expect(plataQueSeMueve(TipoOp.devolucion, solo), 0);
    });

    test('cambio: diferencia y pasos', () {
      final v = _disponibles[1203]!;
      final t = [LineaTrae(v.productos[0], cantidad: 1, danado: false), LineaTrae(v.productos[1], cantidad: 1)];
      final c = cuentasOp(TipoOp.cambio, v, t, [LineaLleva(_bolsoNegro)]);
      expect(c.diferencia, 12000);
      expect(problemaPasoDev(2, trae: [LineaTrae(v.productos[0])]), 'Marca qué trae el cliente.');
      expect(problemaPasoDev(3, tipo: TipoOp.cambio), 'Agrega lo que se lleva.');
      expect(problemaPasoDev(3, tipo: TipoOp.cambio, lleva: [LineaLleva(_bolsoNegro, cantidad: 5)]),
          'Bolso Lía negro: quedan 4.');
      final d = detallesPedido(t);
      expect(d.map((x) => x['estado']), ['bueno', 'danado']);
      expect(billetesSugeridos(12000), [20000, 50000, 100000]);
      expect(billetesSugeridos(45000), [50000, 60000, 100000]);
    });

    test('rangos', () {
      expect(fechasDeRango(RangoDevs.mes, _hoy), (DateTime(2026, 11, 1), DateTime(2026, 11, 27)));
      expect(fechasDeRango(RangoDevs.semana, _hoy).$1, DateTime(2026, 11, 23)); // lunes
      expect(cuandoDev(DateTime(2026, 11, 26, 9), _hoy), 'Ayer');
      expect(cuandoDev(DateTime(2026, 11, 24, 9), _hoy), '24 nov');
      expect(cuandoDev(DateTime(2026, 11, 27, 10, 42), _hoy), '10:42 a. m.');
    });
  });

  group('pantallas', () {
    testWidgets('lista', (t) async {
      final ctrl = TextEditingController();
      FiltroDevs? filtro;
      await _montar(t, Scaffold(body: DevolucionesMovil(
        buscador: ctrl,
        datos: DatosDevsMovil(devoluciones: _lista(), hoy: _hoy),
        acciones: AccionesDevsMovil(onFiltro: (f) => filtro = f, onRango: () {}, onBuscar: (_) {},
            onAbrir: (_) {}, onNueva: () {}, onRefrescar: () async {}),
      )));
      expect(find.text('DEV-212'), findsOneWidget);
      expect(find.text('\$40.000 a su deuda'), findsOneWidget);
      expect(find.text('Mixto'), findsOneWidget);
      await _foto(t, 'dev_1_lista.png');
      await t.tap(find.textContaining('Cambios', findRichText: true));
      expect(filtro, FiltroDevs.cambios);
    });

    testWidgets('lista angosta (320)', (t) async {
      await _montar(t, Scaffold(body: DevolucionesMovil(
        buscador: TextEditingController(),
        datos: DatosDevsMovil(devoluciones: _lista(), hoy: _hoy),
        acciones: AccionesDevsMovil(onFiltro: (_) {}, onRango: () {}, onBuscar: (_) {},
            onAbrir: (_) {}, onNueva: () {}, onRefrescar: () async {}),
      )), ancho: 320);
      expect(t.takeException(), isNull);
      await _foto(t, 'dev_1b_lista_320.png');
    });

    testWidgets('flujo de cambio: venta → qué trae → cambio → plata', (t) async {
      PedidoDev? pedido;
      await _montar(t, NuevaDevolucionMovil(
        hoy: _hoy,
        cuentas: _cuentas,
        cajaAbierta: true,
        servicios: _servicios(alRegistrar: (p) => pedido = p, codigo: '770999'),
      ));
      await t.pumpAndSettle();
      expect(find.text('FV-1203'), findsOneWidget);
      await _foto(t, 'dev_2_venta.png');

      // Venta ya devuelta completa: avisa y no avanza.
      await t.tap(find.text('FV-1202'));
      await t.pumpAndSettle();
      expect(find.text('Esa venta ya se devolvió completa.'), findsOneWidget);
      ScaffoldMessenger.of(t.element(find.byType(Scaffold).first)).removeCurrentSnackBar();
      await t.pumpAndSettle();

      await t.tap(find.text('FV-1203'));
      await t.pumpAndSettle();
      expect(find.text('¿QUÉ TRAE EL CLIENTE?'), findsOneWidget);
      // Sin marcar nada no deja seguir.
      await t.tap(find.text('Siguiente'));
      await t.pump();
      expect(find.text('Marca qué trae el cliente.'), findsOneWidget);

      await t.tap(_enFila('Bolso Lía café', '+'));
      await t.pump();
      await t.tap(find.text('Está bien · al stock'));
      await t.pump();
      await t.tap(_enFila('Aretes perla', '+'));
      await t.pumpAndSettle();
      expect(find.text('¿Qué tiene? (opcional)'), findsOneWidget); // aretes: dañado por defecto
      await t.enterText(find.widgetWithText(TextField, '¿Qué tiene? (opcional)'), 'broche partido');
      await t.pumpAndSettle();
      await _foto(t, 'dev_3_trae.png');

      await t.tap(find.text('Siguiente'));
      await t.pumpAndSettle();
      await t.tap(find.text('Llevarse otro producto'));
      await t.pump();
      await t.tap(find.text('Escanear'));
      await t.pumpAndSettle();
      expect(find.text('Bolso Lía negro'), findsOneWidget);
      expect(find.text('Te paga la diferencia'), findsOneWidget);
      expect(find.text('\$12.000'), findsOneWidget);
      await _foto(t, 'dev_4_cambio.png');

      await t.tap(find.text('Siguiente: la plata'));
      await t.pumpAndSettle();
      expect(find.text('El cliente te paga'), findsOneWidget);
      await t.tap(find.text('\$20.000'));
      await t.pumpAndSettle();
      expect(find.text('\$8.000'), findsOneWidget); // vueltas
      await _foto(t, 'dev_5_plata.png');

      await t.tap(find.text('Registrar cambio e imprimir'));
      await t.pumpAndSettle();
      expect(pedido, isNotNull);
      expect(pedido!.tipo, TipoOp.cambio);
      expect(pedido!.metodo, 'efectivo');
      expect(pedido!.montoRecibido, 20000);
      expect(pedido!.motivoCambio, 'averia');
      expect(pedido!.reemplazos, [{'producto': 30, 'cantidad': 1.0}]);
      expect(pedido!.detalles.map((d) => (d['producto'], d['estado'], d['motivo'])),
          [(1, 'bueno', null), (2, 'danado', 'broche partido')]);
    });

    testWidgets('venta a crédito sin caja: abona a la deuda y pide cuenta', (t) async {
      PedidoDev? pedido;
      await _montar(t, NuevaDevolucionMovil(
        hoy: _hoy,
        cuentas: _cuentas,
        cajaAbierta: false,
        servicios: _servicios(alRegistrar: (p) => pedido = p),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('FV-1150'));
      await t.pumpAndSettle();
      expect(find.text('Venta a crédito · debe \$40.000'), findsOneWidget);
      await t.tap(_enFila('Billetera Nova', '+'));
      await t.pump();
      await t.tap(_enFila('Gafas sol', '+'));
      await t.pump();
      await t.tap(find.text('Siguiente'));
      await t.pumpAndSettle();
      expect(find.text('Primero abona a lo que debe'), findsOneWidget);
      await t.tap(find.text('Que le devuelvan la plata'));
      await t.pump();
      await t.tap(find.text('Siguiente: la plata'));
      await t.pumpAndSettle();
      expect(find.text('\$40.000 a su deuda'), findsOneWidget);
      expect(find.text('sin caja'), findsOneWidget);
      // Dos cuentas de transferencia: hay que elegir.
      await t.tap(find.text('Registrar devolución e imprimir'));
      await t.pump();
      expect(find.text('¿A qué cuenta? Elige una.'), findsOneWidget);
      expect(pedido, isNull);
      await t.tap(find.text('Nequi'));
      await t.pumpAndSettle();
      await _foto(t, 'dev_6_credito.png');
      await t.tap(find.text('Registrar devolución e imprimir'));
      await t.pumpAndSettle();
      expect(pedido!.metodo, 'transferencia');
      expect(pedido!.cuentaId, 1);
      expect(pedido!.detalles.every((d) => d['estado'] == 'danado'), isTrue);
    });

    testWidgets('crédito que cubre todo: no se mueve plata', (t) async {
      PedidoDev? pedido;
      await _montar(t, NuevaDevolucionMovil(
        hoy: _hoy, cajaAbierta: true,
        servicios: _servicios(alRegistrar: (p) => pedido = p),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('FV-1150'));
      await t.pumpAndSettle();
      await t.tap(_enFila('Gafas sol', '+'));
      await t.pump();
      await t.tap(find.text('Siguiente'));
      await t.pumpAndSettle();
      await t.tap(find.text('Que le devuelvan la plata'));
      await t.pump();
      await t.tap(find.text('Siguiente: la plata'));
      await t.pumpAndSettle();
      expect(find.textContaining('No se le entrega plata'), findsOneWidget);
      expect(find.text('Efectivo'), findsNothing);
      await t.tap(find.text('Registrar devolución e imprimir'));
      await t.pumpAndSettle();
      expect(pedido!.metodo, 'nota_credito');
    });

    testWidgets('flujo angosto (320) no se desborda', (t) async {
      await _montar(t, NuevaDevolucionMovil(
        hoy: _hoy, cuentas: _cuentas, cajaAbierta: true,
        servicios: _servicios(alRegistrar: (_) {}, codigo: '770999'),
      ), ancho: 320, alto: 700);
      await t.pumpAndSettle();
      await t.tap(find.text('FV-1203'));
      await t.pumpAndSettle();
      await t.tap(_enFila('Aretes perla', '+'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _foto(t, 'dev_9_trae_320.png');
      await t.tap(find.text('Siguiente'));
      await t.pumpAndSettle();
      await t.tap(find.text('Llevarse otro producto'));
      await t.pump();
      await t.tap(find.text('Escanear'));
      await t.pumpAndSettle();
      await t.tap(find.text('Siguiente: la plata'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _foto(t, 'dev_10_plata_320.png');
    });

    testWidgets('detalle', (t) async {
      var cancelar = 0;
      await _montar(t, DevolucionDetalleMovil(
        dev: _lista()[0], hoy: _hoy, puedeCancelar: true,
        onImprimir: () {}, onCancelar: () => cancelar++,
      ));
      expect(find.text('Volvió al stock'), findsOneWidget);
      expect(find.text('A averías'), findsOneWidget);
      expect(find.text('1 × \$15.000 · “broche partido”'), findsOneWidget);
      await _foto(t, 'dev_7_detalle.png');
      await t.tap(find.text('Cancelar'));
      expect(cancelar, 1);
    });

    testWidgets('detalle de cambio y de crédito', (t) async {
      await _montar(t, DevolucionDetalleMovil(
        dev: _lista()[1], hoy: _hoy, puedeCancelar: false, onImprimir: () {}, onCancelar: () {},
      ));
      expect(find.text('Lo que se llevó'.toUpperCase()), findsOneWidget);
      expect(find.text('Te pagó la diferencia'), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);
      await _foto(t, 'dev_8_detalle_cambio.png');
      await _montar(t, DevolucionDetalleMovil(
        dev: _lista()[2], hoy: _hoy, puedeCancelar: true, onImprimir: () {}, onCancelar: () {},
      ));
      expect(find.text('Abonó a su deuda'), findsOneWidget);
    });
  });
}
