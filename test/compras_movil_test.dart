// Compras en el celular: reglas y pantallas con capturas.
//
// Con --dart-define=SHOT_DIR=<carpeta> guarda capturas PNG.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/models/cuenta_bancaria.dart';
import 'package:pos_multitienda_app/screens/compras/movil/compras_movil.dart';
import 'package:pos_multitienda_app/screens/compras/movil/compras_reglas.dart';
import 'package:pos_multitienda_app/screens/compras/movil/nueva_orden_movil.dart';
import 'package:pos_multitienda_app/screens/compras/movil/orden_movil.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/inventario_movil.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _iconos =
    r'C:\dev\flutter_windows_3.35.4-stable\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
final _marco = GlobalKey();
final _hoy = DateTime(2026, 11, 27, 10);

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

void _tam(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

Future<void> _montar(WidgetTester t, Widget w, {double ancho = 390, double alto = 900}) async {
  _tam(t, ancho, alto);
  await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: _marco, child: w)));
  await t.pump();
}

Map<String, dynamic> _orden(int id, String prov, String estado, num total,
        {bool credito = false, String? vence, bool pagado = false, String fecha = '2026-11-25T10:00:00',
        String? recibida, List<Map<String, dynamic>>? detalles, int? tienda = 1}) =>
    {
      'id': id, 'numero_orden': 'OC-${id.toString().padLeft(5, '0')}', 'proveedor': id,
      'proveedor_nombre': prov, 'estado': estado, 'total': '$total', 'a_credito': credito,
      'fecha_vencimiento': vence, 'pagado': pagado, 'fecha_orden': fecha, 'fecha_recepcion': recibida,
      'tienda': tienda, 'tienda_nombre': tienda == null ? null : 'Consentida Accesorios',
      'empleado_nombre': 'Leidy Estrada', 'detalles': detalles ?? const [],
    };

List<Map<String, dynamic>> _ordenes() => [
      _orden(27, 'Distribuidora Andina', 'pendiente', 2340000, credito: true, vence: '2026-12-27',
          fecha: '2026-11-27T09:40:00', tienda: null, detalles: [
            {'id': 1, 'producto': 5, 'producto_nombre': 'Bolso Lía café', 'cantidad': '12', 'precio_unitario': '85000',
             'subtotal': '1020000', 'codigo_barras_input': '770123456001',
             'distribuciones': [{'tienda': 1, 'tienda_nombre': 'Boutique 27', 'cantidad': '6'},
                                {'tienda': 2, 'tienda_nombre': 'Unicentro', 'cantidad': '6'}]},
            {'id': 2, 'producto': 6, 'producto_nombre': 'Aretes perla', 'cantidad': '40', 'precio_unitario': '18000',
             'subtotal': '720000', 'precio_venta': '22000',
             'distribuciones': [{'tienda': 1, 'tienda_nombre': 'Boutique 27', 'cantidad': '20'},
                                {'tienda': 2, 'tienda_nombre': 'Unicentro', 'cantidad': '20'}]},
            {'id': 3, 'producto': null, 'nombre_libre': 'Billetera Nova', 'cantidad': '20', 'precio_unitario': '30000',
             'subtotal': '600000', 'precio_venta': '28000', 'categoria_nombre': 'Billeteras',
             'distribuciones': [{'tienda': 2, 'tienda_nombre': 'Unicentro', 'cantidad': '20'}]},
          ]),
      _orden(26, 'Bolsos del Sur', 'pendiente', 1180000, fecha: '2026-11-25T10:00:00'),
      _orden(25, 'Importadora Lía', 'recibida', 3920000, credito: true, vence: '2026-12-22',
          recibida: '2026-11-22T10:00:00', fecha: '2026-11-22T10:00:00'),
      _orden(19, 'Importadora Lía', 'recibida', 1200000, credito: true, vence: '2026-11-20',
          recibida: '2026-11-02T10:00:00', fecha: '2026-11-01T10:00:00'),
      _orden(24, 'Accesorios Nova', 'recibida', 640000, pagado: true, recibida: '2026-11-20T10:00:00'),
      _orden(20, 'Bolsos del Sur', 'cancelada', 300000),
    ];

AccionesComprasMovil _acc(List<String> log) => AccionesComprasMovil(
      onPestana: (p) => log.add('pestana ${p.name}'),
      onFiltro: (f) => log.add('filtro ${f.name}'),
      onBuscar: (q) => log.add('buscar $q'),
      onOrden: (o) => log.add('orden ${o['numero_orden']}'),
      onNuevaOrden: () => log.add('nueva'),
      onFiltroProveedores: (f) => log.add('prov $f'),
      onProveedor: (p) => log.add('proveedor ${p['nombre']}'),
      onNuevoProveedor: () => log.add('nuevo proveedor'),
      onPagar: (c) => log.add('pagar ${c['numero_orden']}'),
      onRefrescar: () async {},
    );

void main() {
  group('Reglas', () {
    test('resumen', () {
      final r = resumirOrdenes(_ordenes(), _hoy);
      expect(r.porRecibir, 2);
      expect(r.totalPorRecibir, 3520000);
      expect(r.recibidasMes, 3);
      expect(r.porPagar, 2);
      expect(r.totalPorPagar, 5120000);
      expect(r.vencidas, 1);
      expect(r.totalVencido, 1200000);
    });

    test('filtros y búsqueda', () {
      List<int> ids(FiltroOrdenes f, [String q = '']) =>
          ordenesVisibles(_ordenes(), f, q).map((c) => c['id'] as int).toList();
      expect(ids(FiltroOrdenes.pendientes), [27, 26]);
      expect(ids(FiltroOrdenes.credito), [27, 25, 19]);
      expect(ids(FiltroOrdenes.canceladas), [20]);
      expect(ids(FiltroOrdenes.todas, 'lía'), [25, 19]);
      expect(ids(FiltroOrdenes.todas, 'oc-00026'), [26]);
    });

    test('tiendas y márgenes', () {
      expect(textoTiendas(_ordenes()[0]), 'Boutique 27 · Unicentro');
      expect(textoTiendas(_ordenes()[1]), 'Consentida Accesorios');
      expect(textoMargen(85000, 149900).$2, 0);
      expect(textoMargen(18000, 19000).$2, 1);
      expect(textoMargen(30000, 28000), ('Bajo el costo', 2));
      expect(textoPago(-7), 'Vencida hace 7 días');
      expect(precioSugerido({'precio_unitario': '10000'}), 13000);
      expect(precioSugerido({'precio_unitario': '10000', 'precio_venta': '15000'}), 15000);
    });

    test('nueva orden: pasos y cuerpo', () {
      final filas = [
        FilaOrden(producto: 5, nombre: 'Bolso', costo: 85000, reparto: {1: 6, 2: 6}),
        FilaOrden(nombre: 'Billetera Nova', categoria: 'Billeteras', costo: 30000, reparto: {2: 20}),
      ];
      expect(problemaPaso(1, tiendas: {}, filas: filas), 'Elige el proveedor.');
      expect(problemaPaso(1, proveedor: 1, tiendas: {}, filas: filas), 'Elige al menos una tienda.');
      expect(problemaPaso(2, tiendas: {1}, filas: [FilaOrden(nombre: 'X', costo: 0, reparto: {1: 2})]),
          contains('costo'));
      expect(problemaPaso(3, tiendas: {1}, filas: filas, credito: true), contains('fecha'));
      final c = cuerpoOrden(proveedor: 3, tiendas: {1, 2}, filas: filas, credito: true,
          vence: DateTime(2026, 12, 27), obs: ' ojo ');
      expect(c['tienda'], isNull);
      expect(c['a_credito'], isTrue);
      expect(c['fecha_vencimiento'], '2026-12-27');
      expect(c['observaciones'], 'ojo');
      final d = (c['detalles'] as List);
      expect(d[0]['cantidad'], 12);
      expect(d[0]['distribuciones'], [{'tienda': 1, 'cantidad': 6.0}, {'tienda': 2, 'cantidad': 6.0}]);
      expect(d[1]['nombre_libre'], 'Billetera Nova');
      final una = cuerpoOrden(proveedor: 3, tiendas: {1}, filas: [filas[0]..reparto.remove(2)], credito: false);
      expect(una['tienda'], 1);
      expect((una['detalles'] as List)[0].containsKey('distribuciones'), isFalse);
      expect(una.containsKey('fecha_vencimiento'), isFalse);
    });
  });

  group('Pantallas', () {
    setUpAll(_fuentes);

    for (final ancho in [390.0, 320.0]) {
      testWidgets('órdenes a ${ancho.toInt()} px', (t) async {
        final log = <String>[];
        await _montar(t, Scaffold(body: ComprasMovil(buscador: TextEditingController(),
            datos: DatosComprasMovil(hoy: _hoy, ordenes: _ordenes()), acciones: _acc(log))), ancho: ancho);
        expect(t.takeException(), isNull);
        expect(find.text('OC-00027'), findsOneWidget);
        await _foto(t, 'compras_ordenes_${ancho.toInt()}.png');
        await t.tap(find.text('OC-00027'));
        await t.tap(find.text('Por pagar').first);
        await t.tap(find.byTooltip('Nueva orden'));
        expect(log, ['orden OC-00027', 'pestana porPagar', 'nueva']);
      });
    }

    testWidgets('proveedores', (t) async {
      final log = <String>[];
      await _montar(t, Scaffold(body: ComprasMovil(buscador: TextEditingController(),
          datos: DatosComprasMovil(hoy: _hoy, pestana: PestanaCompras.proveedores, proveedores: [
            {'id': 1, 'nombre': 'Distribuidora Andina', 'nit': '900123456', 'telefono': '3124559087',
             'n_ordenes': 8, 'total_comprado': '14200000', 'deuda': '2340000', 'deuda_vencida': null},
            {'id': 2, 'nombre': 'Importadora Lía', 'nit': '901552018', 'telefono': '3158821043',
             'n_ordenes': 11, 'total_comprado': '22800000', 'deuda': '1200000', 'deuda_vencida': '1200000'},
            {'id': 3, 'nombre': 'Bolsos del Sur', 'nit': '830441220', 'telefono': '573001256678',
             'n_ordenes': 5, 'total_comprado': '6100000', 'deuda': null},
          ]), acciones: _acc(log))));
      expect(t.takeException(), isNull);
      expect(find.textContaining('Le debemos'), findsWidgets);
      expect(find.textContaining('300 125 6678'), findsOneWidget);
      await _foto(t, 'compras_proveedores.png');
      await t.tap(find.text('Bolsos del Sur'));
      expect(log, ['proveedor Bolsos del Sur']);
    });

    testWidgets('por pagar', (t) async {
      final log = <String>[];
      await _montar(t, Scaffold(body: ComprasMovil(buscador: TextEditingController(),
          datos: DatosComprasMovil(hoy: _hoy, pestana: PestanaCompras.porPagar, porPagar: {
            'total_deuda': 2620000,
            'compras': [
              {'id': 19, 'numero_orden': 'OC-00019', 'proveedor_nombre': 'Importadora Lía', 'total': 1200000,
               'fecha_vencimiento': '2026-11-20', 'vencida': true},
              {'id': 23, 'numero_orden': 'OC-00023', 'proveedor_nombre': 'Bolsos del Sur', 'total': 1420000,
               'fecha_vencimiento': '2026-12-02', 'vencida': false},
            ],
            'por_recibir': [
              {'id': 27, 'numero_orden': 'OC-00027', 'proveedor_nombre': 'Distribuidora Andina', 'total': 2340000,
               'fecha_vencimiento': '2026-12-27'},
            ],
          }), acciones: _acc(log))));
      expect(t.takeException(), isNull);
      expect(find.text('Vencida hace 7 días'), findsOneWidget);
      expect(find.text('Vence en 5 días'), findsOneWidget);
      expect(find.text('Pagar'), findsNWidgets(2));
      await _foto(t, 'compras_por_pagar.png');
      await t.tap(find.text('Pagar').first);
      expect(log, ['pagar OC-00019']);
    });

    testWidgets('detalle de la orden', (t) async {
      final log = <String>[];
      await _montar(t, OrdenDetalleMovil(orden: _ordenes()[0], telefonoProveedor: '3124559087', hoy: _hoy,
          onRecibir: () => log.add('recibir'), onPagar: () {}, onPdf: () {}, onCancelar: () {}), alto: 1100);
      expect(t.takeException(), isNull);
      expect(find.text('Billetera Nova'), findsNothing);
      expect(find.textContaining('Billetera Nova', findRichText: true), findsOneWidget);
      await _foto(t, 'compras_detalle.png');
      await t.tap(find.text('Recibir mercancía'));
      expect(log, ['recibir']);
    });

    testWidgets('recibir de contado con pago', (t) async {
      ResultadoRecibir? r;
      final o = {..._ordenes()[0], 'a_credito': false, 'fecha_vencimiento': null};
      await _montar(t, RecibirMovil(orden: o, manejaMayoreo: true, hoy: _hoy, cajaAbierta: true,
          cuentas: const [CuentaBancaria(id: 9, nombre: 'Bancolombia', tipo: 'transferencia',
              tipoDisplay: 'Transferencia', numero: '1234', activo: true, orden: 0)],
          onConfirmar: (x) async {
            r = x;
            return null;
          }), alto: 1500);
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('Bajo el costo'), findsOneWidget);
      await _foto(t, 'compras_recibir.png');
      await t.tap(find.text('Confirmar recepción'));
      await t.pump();
      expect(r?.precios['1'], 110500);
      expect(r?.pago?['metodo_pago'], 'transferencia');
      expect(r?.pago?['cuenta_bancaria'], 9);
    });

    testWidgets('hoja de pago: efectivo de la caja', (t) async {
      Map<String, dynamic>? pago;
      await _montar(t, Scaffold(body: Align(alignment: Alignment.bottomCenter, child: HojaPagoProveedor(
        compra: {'numero_orden': 'OC-00019', 'proveedor_nombre': 'Importadora Lía', 'total': 1200000},
        cuentas: const [], cajaAbierta: true, hoy: _hoy,
        onPagar: (p) async {
          pago = p;
          return null;
        },
      ))));
      await t.pump();
      await t.tap(find.text('Efectivo'));
      await t.pump();
      expect(find.text('Salió del cajón de la caja'), findsOneWidget);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await _foto(t, 'compras_pagar.png');
      await t.tap(find.text('Registrar pago'));
      await t.pump();
      expect(pago?['metodo_pago'], 'efectivo');
      expect(pago?['de_caja'], isTrue);
      expect(pago?['fecha'], '2026-11-27');
    });

    testWidgets('nueva orden: los tres pasos', (t) async {
      Map<String, dynamic>? cuerpo;
      await _montar(t, NuevaOrdenMovil(
        hoy: _hoy,
        proveedores: const [{'id': 3, 'nombre': 'Distribuidora Andina', 'nit': '900123456'},
                            {'id': 4, 'nombre': 'Bolsos del Sur', 'nit': ''}],
        tiendas: const [{'id': 1, 'nombre': 'Boutique 27'}, {'id': 2, 'nombre': 'Unicentro'}],
        buscar: (q) async => [{'id': 5, 'nombre': 'Bolso Lía café', 'codigo_barras': '770123456001', 'precio_compra': 85000}],
        escanear: () async => '770123456001',
        onCrear: (c) async {
          cuerpo = c;
          return null;
        },
      ), alto: 1100);
      await t.tap(find.text('Siguiente: productos'));
      await t.pump();
      expect(find.text('Elige el proveedor.'), findsOneWidget);
      await t.tap(find.text('Distribuidora Andina'));
      await t.tap(find.text('Boutique 27'));
      await t.tap(find.text('Unicentro'));
      await t.pump();
      await _foto(t, 'compras_nueva_1.png');
      await t.tap(find.text('Siguiente: productos'));
      await t.pump();
      await t.tap(find.text('Escanear'));
      await t.pumpAndSettle();
      expect(find.text('Bolso Lía café'), findsOneWidget);
      await t.enterText(find.byType(TextFormField).at(1), '6');
      await t.pump();
      await _foto(t, 'compras_nueva_2.png');
      await t.tap(find.text('Siguiente: resumen'));
      await t.pump();
      await t.tap(find.text('A crédito'));
      await t.pump();
      await _foto(t, 'compras_nueva_3.png');
      await t.tap(find.text('Crear orden y sacar PDF'));
      await t.pump();
      expect(cuerpo?['proveedor'], 3);
      expect(cuerpo?['a_credito'], isTrue);
      expect(cuerpo?['fecha_vencimiento'], '2026-12-27');
      final d = (cuerpo?['detalles'] as List).single;
      expect(d['cantidad'], 7);
      expect(d['precio_unitario'], 85000);
    });
  });
}
