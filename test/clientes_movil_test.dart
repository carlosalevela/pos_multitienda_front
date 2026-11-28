// Clientes en el celular: reglas (filtros, orden, resumen, teléfono,
// WhatsApp) y la pantalla con capturas.
//
// Con --dart-define=SHOT_DIR=<carpeta> guarda capturas PNG.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/models/cliente.dart';
import 'package:pos_multitienda_app/models/separado.dart';
import 'package:pos_multitienda_app/models/tier_model.dart';
import 'package:pos_multitienda_app/screens/clientes/widgets/cliente_detalle_movil.dart';
import 'package:pos_multitienda_app/providers/cliente_provider.dart';
import 'package:pos_multitienda_app/screens/clientes/widgets/cliente_contacto.dart';
import 'package:pos_multitienda_app/screens/clientes/widgets/cliente_form.dart';
import 'package:provider/provider.dart';
import 'package:pos_multitienda_app/screens/clientes/widgets/clientes_movil.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/inventario_movil.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _iconos =
    r'C:\dev\flutter_windows_3.35.4-stable\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
final _marco = GlobalKey();
final _hoy = DateTime(2026, 11, 26, 10);

Future<void> _cargarFuentes() async {
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
  if (File(_iconos).existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(leer(_iconos))).load();
  }
}

Future<void> _foto(WidgetTester t, String nombre) async {
  if (_shotDir.isEmpty) return;
  final ro = _marco.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 1.5);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$_shotDir${Platform.pathSeparator}$nombre').writeAsBytes(png!.buffer.asUint8List());
  });
}

void _tam(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

Cliente _c(int id, String n, String a, String tel,
    {double compro = 0, double sep = 0, int nSep = 0, DateTime? vence, double cred = 0,
    bool activo = true, double limite = 0, DateTime? creado}) =>
    Cliente(
      id: id, nombre: n, apellido: a, telefono: tel, email: '', direccion: '',
      activo: activo, createdAt: creado ?? DateTime(2026, 1, id), totalAcumulado: compro,
      limiteCredito: limite,
      saldos: SaldosCliente(separados: sep, separadosActivos: nSep, proximoVencimiento: vence, credito: cred),
    );

List<Cliente> _lista() => [
      _c(1, 'Emma', 'Castillo', '573117374019', compro: 420000, sep: 72900, nSep: 1,
          vence: DateTime(2026, 11, 24), limite: 300000),
      _c(2, 'Aida', 'Sánchez', '573164445112', compro: 282000),
      _c(3, 'Sara', 'Chamorro', '573218670446', sep: 86900, nSep: 1, vence: DateTime(2026, 11, 27)),
      _c(4, 'Alba', 'Martínez', '573128338634', compro: 527000),
      _c(5, 'Alba', 'Palacios', '573006193540', compro: 144000, cred: 40000, limite: 200000),
      _c(6, 'Marta', 'Ríos', '573150000000', activo: false, compro: 10000),
      _c(7, 'Julia', 'Rosero', '3105521188', sep: 300000, nSep: 2, vence: DateTime(2026, 12, 20),
          cred: 112000, compro: 1240000, limite: 500000, creado: DateTime(2026, 11, 20)),
    ];

void main() {
  group('Teléfono y WhatsApp', () {
    test('quita el 57 y lo escribe bonito', () {
      expect(celularLocal('573117374019'), '3117374019');
      expect(telefonoBonito('573117374019'), '311 737 4019');
      expect(telefonoBonito('3117374019'), '311 737 4019');
      expect(telefonoBonito('+57 311-737-4019'), '311 737 4019');
      expect(numeroWhatsApp('3117374019'), '573117374019');
      expect(numeroWhatsApp('7234567'), isNull);
      expect(numeroWhatsApp(''), isNull);
    });

    test('el enlace lleva el mensaje codificado', () {
      final u = enlaceWhatsApp('573117374019', 'Hola Emma & cía, ¿cómo vas?');
      expect(u.toString(), startsWith('https://wa.me/573117374019?text='));
      expect(Uri.decodeComponent(u.query.substring(5)), 'Hola Emma & cía, ¿cómo vas?');
    });

    test('mensaje de separado vencido con saldo y fecha', () {
      final m = mensajeWhatsApp(PlantillaWA.separado, _lista()[0], 'Consentida Accesorios', _hoy);
      expect(m, contains('Hola Emma'));
      expect(m, contains('Consentida Accesorios'));
      expect(m, contains(r'$72.900'));
      expect(m, contains('venció el 24 de noviembre'));
    });

    test('mensaje de crédito y plantilla sugerida', () {
      final palacios = _lista()[4];
      expect(plantillaSugerida(palacios), PlantillaWA.credito);
      expect(mensajeWhatsApp(PlantillaWA.credito, palacios, 'X', _hoy), contains(r'$40.000'));
      expect(plantillaSugerida(_lista()[1]), PlantillaWA.saludo);
      expect(mensajeWhatsApp(PlantillaWA.separado, _lista()[6], 'X', _hoy), contains('tus 2 separados'));
    });

    test('textos de vencimiento', () {
      expect(textoVencimiento(-2), 'Vencido hace 2 días');
      expect(textoVencimiento(-1), 'Venció ayer');
      expect(textoVencimiento(0), 'Vence hoy');
      expect(textoVencimiento(1), 'Vence mañana');
      expect(textoVencimiento(5), 'Vence en 5 días');
    });
  });

  group('Filtros, orden y resumen', () {
    test('resumen de la tienda', () {
      final r = resumirClientes(_lista(), _hoy);
      expect(r.activos, 6);
      expect(r.inactivos, 1);
      expect(r.deben, 4);
      expect(r.totalDeuda, 72900 + 86900 + 40000 + 412000);
      expect(r.separados, 4);
      expect(r.conSeparado, 3);
      expect(r.vencidos, 1);
      expect(r.totalVencido, 72900);
      expect(r.porVencer, 1);
      expect(r.conCredito, 3);
    });

    test('cada filtro', () {
      List<int> ids(FiltroClientes f) =>
          clientesVisibles(_lista(), f, OrdenClientes.nombre, _hoy).map((c) => c.id).toList();
      expect(ids(FiltroClientes.todos), [2, 4, 5, 1, 7, 3]);
      expect(ids(FiltroClientes.deben).toSet(), {1, 3, 5, 7});
      expect(ids(FiltroClientes.vencidos), [1]);
      expect(ids(FiltroClientes.alerta).toSet(), {1, 3});
      expect(ids(FiltroClientes.inactivos), [6]);
      expect(ids(FiltroClientes.credito).toSet(), {1, 5, 7});
    });

    test('órdenes', () {
      List<int> ids(OrdenClientes o) =>
          clientesVisibles(_lista(), FiltroClientes.todos, o, _hoy).map((c) => c.id).toList();
      expect(ids(OrdenClientes.deuda).first, 7);
      expect(ids(OrdenClientes.vence).take(3).toList(), [1, 3, 7]);
      expect(ids(OrdenClientes.compras).first, 7);
      expect(ids(OrdenClientes.recientes).first, 7);
    });
  });

  group('Pantalla', () {
    setUpAll(_cargarFuentes);

    Future<List<String>> montar(WidgetTester t, {FiltroClientes filtro = FiltroClientes.todos,
        OrdenClientes orden = OrdenClientes.nombre, String? tienda = 'Consentida Accesorios',
        double ancho = 390, List<Cliente>? clientes}) async {
      _tam(t, ancho, 1100);
      final log = <String>[];
      final ctrl = TextEditingController();
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: _marco,
          child: Scaffold(
            body: ClientesMovil(
              buscador: ctrl,
              datos: DatosClientesMovil(clientes: clientes ?? _lista(), hoy: _hoy,
                  tiendaNombre: tienda, filtro: filtro, orden: orden),
              acciones: AccionesClientesMovil(
                onTienda: () => log.add('tienda'),
                onFiltro: (f) => log.add('filtro ${f.name}'),
                onOrden: () => log.add('orden'),
                onBuscar: (q) => log.add('buscar $q'),
                onCliente: (c) => log.add('cliente ${c.nombre}'),
                onLlamar: (c) => log.add('llamar ${c.nombre}'),
                onWhatsApp: (c) => log.add('wa ${c.nombre}'),
                onNuevo: () => log.add('nuevo'),
                onRefrescar: () async {},
              ),
            ),
          ),
        ),
      ));
      await t.pump();
      return log;
    }

    for (final ancho in [390.0, 320.0]) {
      testWidgets('lista a ${ancho.toInt()} px', (t) async {
        final log = await montar(t, ancho: ancho);
        expect(t.takeException(), isNull);
        expect(find.textContaining(r'Debe $72.900', findRichText: true), findsOneWidget);
        expect(find.textContaining('Vencido hace 2 días', findRichText: true), findsOneWidget);
        expect(find.text('311 737 4019'), findsOneWidget);
        expect(find.text('Marta Ríos'), findsNothing);
        await _foto(t, 'clientes_movil_${ancho.toInt()}.png');
        await t.tap(find.text('Emma Castillo'));
        await t.tap(find.byTooltip('WhatsApp a Emma').first);
        await t.tap(find.byTooltip('Llamar a Emma').first);
        await t.tap(find.text('Consentida Accesorios'));
        await t.tap(find.byTooltip('Nuevo cliente').hitTestable().evaluate().isEmpty
            ? find.byIcon(Icons.person_add_alt_1_rounded)
            : find.byTooltip('Nuevo cliente'));
        expect(log, ['cliente Emma', 'wa Emma', 'llamar Emma', 'tienda', 'nuevo']);
      });
    }

    testWidgets('las tarjetas y el aviso filtran', (t) async {
      final log = await montar(t);
      await t.tap(find.text('Deben'));
      await t.tap(find.textContaining('vencido'));
      await t.tap(find.text('A-Z'));
      expect(log, ['filtro deben', 'filtro alerta', 'orden']);
    });

    testWidgets('filtro Deben con el total', (t) async {
      await montar(t, filtro: FiltroClientes.deben, orden: OrdenClientes.deuda);
      expect(t.takeException(), isNull);
      expect(find.textContaining(r'$611.800'), findsWidgets);
      await _foto(t, 'clientes_movil_deben.png');
    });

    testWidgets('inactivos', (t) async {
      await montar(t, filtro: FiltroClientes.inactivos);
      expect(find.text('Marta Ríos'), findsOneWidget);
      expect(find.text('INACTIVO'), findsOneWidget);
    });

    testWidgets('sin tienda (superadmin)', (t) async {
      final log = await montar(t, tienda: null, clientes: const []);
      expect(find.text('Elige la tienda para ver sus clientes'), findsOneWidget);
      await _foto(t, 'clientes_movil_sin_tienda.png');
      await t.tap(find.text('Elegir tienda').last);
      expect(log, ['tienda']);
    });

    testWidgets('hoja de WhatsApp', (t) async {
      _tam(t, 390, 900);
      String? enviado;
      await t.pumpWidget(MaterialApp(
        home: RepaintBoundary(key: _marco, child: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: HojaWhatsApp(
            cliente: _lista()[0], tienda: 'Consentida Accesorios', hoy: _hoy,
            onEnviar: (m) async {
              enviado = m;
              return null;
            },
          )),
        )),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      await _foto(t, 'clientes_whatsapp.png');
      await t.tap(find.text('Saldo de crédito'));
      await t.pump();
      await t.tap(find.text('Separado pendiente'));
      await t.pump();
      await t.tap(find.text('Abrir WhatsApp'));
      await t.pump();
      expect(enviado, contains(r'$72.900'));
    });

    for (final ancho in [390.0, 320.0]) {
      testWidgets('formulario nuevo cliente a ${ancho.toInt()} px', (t) async {
        _tam(t, ancho, 1000);
        await t.pumpWidget(ChangeNotifierProvider(
          create: (_) => ClienteProvider(),
          child: MaterialApp(home: RepaintBoundary(key: _marco, child: Scaffold(
            body: Align(alignment: Alignment.bottomCenter,
                child: ClienteForm(tiendaId: 1, tiendaNombre: 'Consentida Accesorios')),
          ))),
        ));
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.text('Límite de crédito'), findsNothing);
        await t.enterText(find.byType(TextFormField).at(0), 'Laura');
        await t.enterText(find.byType(TextFormField).at(1), 'Gómez Ruiz');
        await t.enterText(find.byType(TextFormField).at(2), '311 737 4019');
        await t.tap(find.byType(Switch));
        await t.pump();
        expect(find.text('Límite de crédito'), findsOneWidget);
        await t.enterText(find.byType(TextFormField).last, '300.000');
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await _foto(t, 'clientes_form_${ancho.toInt()}.png');
      });
    }

    test('el límite con puntos de miles', () {
      expect(leerPesos('300.000'), 300000);
      expect(leerPesos(r'$ 1.250.000'), 1250000);
      expect(leerPesos(''), isNull);
    });

    Separado sep(int id, double total, double abonado, String? limite, String estado,
            List<(String, double)> prods) =>
        Separado(id: id, tienda: 1, tiendaNombre: 'X', cliente: 1, clienteNombre: 'Emma',
            total: total, abonoAcumulado: abonado, saldoPendiente: total - abonado,
            fechaLimite: limite, estado: estado, createdAt: DateTime(2026, 10, id),
            detalles: [for (final (n, c) in prods)
              DetalleSeparado(id: 1, producto: 1, productoNombre: n, cantidad: c,
                  precioUnitario: 1, subtotal: 1)],
            abonos: const []);

    Future<void> enTelefono(WidgetTester t, Widget w, String foto) async {
      _tam(t, 390, 844);
      await t.pumpWidget(MaterialApp(home: RepaintBoundary(key: _marco,
          child: Scaffold(backgroundColor: const Color(0xFFF0FDF4), body: w))));
      await t.pump();
      expect(t.takeException(), isNull);
      await _foto(t, foto);
    }

    testWidgets('detalle: separados', (t) async {
      final log = <String>[];
      await enTelefono(t, SeparadosMovil(
        activos: [
          sep(123, 150000, 77100, '2026-11-24', 'activo', [('Bolso Lía café', 1), ('Aretes perla', 2)]),
          sep(131, 58000, 45000, '2026-12-03', 'activo', [('Billetera Nova negra', 1)]),
        ],
        historial: [
          sep(90, 80000, 80000, null, 'pagado', [('Correa', 1)]),
          sep(95, 40000, 0, null, 'cancelado', [('Gafas', 1)]),
        ],
        hoy: _hoy, esAdmin: true,
        onAbonar: (s) => log.add('abonar ${s.id}'),
        onRecibos: (s) => log.add('recibos ${s.id}'),
        onDetalle: (s) => log.add('detalle ${s.id}'),
        onCancelar: (s) => log.add('cancelar ${s.id}'),
      ), 'detalle_separados.png');
      expect(find.text('Vencido hace 2 días'), findsOneWidget);
      expect(find.text('Al día'), findsOneWidget);
      expect(find.text('Bolso Lía café, Aretes perla x2'), findsOneWidget);
      await t.tap(find.text('Abonar').first);
      await t.tap(find.text('Recibos').first);
      expect(log, ['abonar 123', 'recibos 123']);
    });

    testWidgets('detalle: crédito', (t) async {
      await enTelefono(t, CreditoMovil(
        cliente: _lista()[0],
        datos: {'limite_credito': 300000, 'deuda_total': 82700, 'ventas': [
          {'id': 1, 'numero_factura': 'V-01844', 'total': 120000, 'total_pagado': 37300,
           'saldo_pendiente': 82700, 'fecha': '2026-11-12T10:00:00'},
          {'id': 2, 'numero_factura': 'V-01702', 'total': 64000, 'total_pagado': 64000,
           'saldo_pendiente': 0, 'fecha': '2026-10-28T10:00:00'},
        ]},
        cargando: false, onAbonar: (_) {}, onRefrescar: () async {},
      ), 'detalle_credito.png');
      expect(find.textContaining(r'$217.300', findRichText: true), findsOneWidget);
    });

    testWidgets('detalle: compras y datos', (t) async {
      await enTelefono(t, ComprasMovil(ventas: [
        {'id': 1, 'numero_factura': 'FV-1203', 'total': '84000', 'estado': 'completada',
         'metodo_pago': 'efectivo', 'created_at': '2026-11-20T10:00:00'},
        {'id': 2, 'numero_factura': 'FV-1150', 'total': '120000', 'estado': 'anulada',
         'metodo_pago': 'tarjeta', 'created_at': '2026-11-02T10:00:00'},
      ], cargando: false, onRefrescar: () async {}), 'detalle_compras.png');
      final c = Cliente(id: 1, nombre: 'Emma', apellido: 'Castillo', telefono: '573117374019',
          email: 'emma@correo.com', direccion: 'Cra 25 # 18-40', activo: true,
          createdAt: DateTime(2025, 3, 2), totalAcumulado: 1240000, cedulaNit: '1085221447',
          tierInfo: const TierInfo(id: 1, nombre: 'Plata', descuentoPct: 5, colorHex: '#64748B'));
      await enTelefono(t, DatosMovil(cliente: c, puedeEditar: true, onEditar: () {}, onDesactivar: () {},
        tiers: const [
          TierModel(nombre: 'Plata', umbralMin: 1000000, descuentoPct: 5, colorHex: '#64748B', activo: true, orden: 1),
          TierModel(nombre: 'Oro', umbralMin: 2000000, descuentoPct: 10, colorHex: '#B45309', activo: true, orden: 2),
        ]), 'detalle_datos.png');
      expect(find.textContaining(r'Le faltan $760.000 para Oro'), findsOneWidget);
    });
  });
}
