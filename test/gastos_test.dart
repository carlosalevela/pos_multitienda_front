// Gastos y nómina: reglas, lectura de lo que manda el servidor y las
// pantallas (computador y celular) con capturas.
//
// Con --dart-define=SHOT_DIR=<carpeta> guarda capturas PNG.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/models/cuenta_bancaria.dart';
import 'package:pos_multitienda_app/screens/gastos/gastos_formularios.dart';
import 'package:pos_multitienda_app/screens/gastos/gastos_screen.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/inventario_movil.dart';
import 'package:pos_multitienda_app/services/gastos_service.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _iconos =
    r'C:\dev\flutter_windows_3.35.4-stable\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
const _scratch =
    r'C:\Users\XzCar\AppData\Local\Temp\claude\160e7d60e6dbc836\a73dd243-0ffc-4b1b-83a6-b47decf936a5\scratchpad\';
final _marco = GlobalKey();
final _hoy = DateTime(2026, 11, 25, 15);

Future<void> _cargarFuentes() async {
  Future<ByteData> leer(String p) async =>
      ByteData.sublistView(await File(p).readAsBytes());
  const sans = [
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\seguisb.ttf',
    r'C:\Windows\Fonts\segoeuib.ttf',
  ];
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
    await File('$_shotDir${Platform.pathSeparator}$nombre')
        .writeAsBytes(png!.buffer.asUint8List());
  });
}

void _tam(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

// ── Datos de ejemplo ──────────────────────────────────────────

const _tiendas = [
  TiendaOpcion(1, 'Consentida Boutique 27'),
  TiendaOpcion(2, 'Consentida Boutique Novacentro'),
];

List<GastoItem> _gastos() => [
      GastoItem(id: 1, tiendaId: 1, tiendaNombre: 'Consentida Boutique 27',
          categoria: 'Nómina', monto: 750000, fecha: DateTime(2026, 11, 25),
          metodoPago: 'transferencia', cuentaNombre: 'Bancolombia',
          beneficiario: 'Laura Gómez', periodo: '2.ª quincena nov 2026',
          salario: 800000, extras: 50000, descuentos: 100000,
          registradoPor: 'Admin Boutique'),
      GastoItem(id: 2, tiendaId: 2, tiendaNombre: 'Consentida Boutique Novacentro',
          categoria: 'Servicios', monto: 184300, fecha: DateTime(2026, 11, 24),
          descripcion: 'Recibo de luz · octubre', metodoPago: 'transferencia'),
      GastoItem(id: 3, tiendaId: 1, tiendaNombre: 'Consentida Boutique 27',
          categoria: 'Aseo', monto: 38500, fecha: DateTime(2026, 11, 24),
          descripcion: 'Bolsas, jabón, límpido', deCaja: true),
      GastoItem(id: 4, tiendaId: 1, tiendaNombre: 'Consentida Boutique 27',
          categoria: 'Arriendo', monto: 2400000, fecha: DateTime(2026, 11, 20),
          descripcion: 'Arriendo local noviembre', metodoPago: 'transferencia'),
      GastoItem(id: 5, tiendaId: 2, tiendaNombre: 'Consentida Boutique Novacentro',
          categoria: 'Transporte', monto: 15000, fecha: DateTime(2026, 11, 18),
          descripcion: 'Domicilio mercancía', deCaja: true,
          registradoPor: 'Ginna Montilla'),
    ];

const _panel = PanelGastos(
  total: 3387800, cantidad: 5, totalMesAnterior: 3190000, variacionPct: 6.2,
  nominaTotal: 750000, nominaPagos: 1, nominaPersonas: 1,
  arriendoServicios: 2584300, deCaja: 53500,
  porCategoria: [
    ('Arriendo', 2400000, 1), ('Nómina', 750000, 1), ('Servicios', 184300, 1),
    ('Aseo', 38500, 1), ('Transporte', 15000, 1),
  ],
);

DatosGastos _datos({String? categoria, bool vacio = false, int? tienda}) =>
    DatosGastos(
      mes: DateTime(2026, 11),
      tiendas: _tiendas,
      tienda: tienda,
      categoria: categoria,
      panel: vacio ? const PanelGastos() : _panel,
      gastos: vacio ? const [] : _gastos(),
      hoy: _hoy,
    );

AccionesGastos _acciones(List<String> log) => AccionesGastos(
      onMes: (d) => log.add('mes $d'),
      onTienda: (t) => log.add('tienda $t'),
      onCategoria: (c) => log.add('categoria $c'),
      onRegistrarGasto: () => log.add('gasto'),
      onRegistrarNomina: () => log.add('nomina'),
      onRegistrar: () => log.add('registrar'),
      onGasto: (g) => log.add('ver ${g.id}'),
      onRefrescar: () async {},
    );

Future<void> _montar(WidgetTester t, Widget w) async {
  await t.pumpWidget(RepaintBoundary(
    key: _marco,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: w),
    ),
  ));
  await t.pumpAndSettle();
}

const _cuenta = CuentaBancaria(
    id: 7, nombre: 'Bancolombia ahorros', tipo: 'transferencia',
    tipoDisplay: 'Transferencia', numero: '…4321', activo: true, orden: 0);

void main() {
  setUpAll(_cargarFuentes);

  // ── Reglas ──────────────────────────────────────────────────

  test('nómina: total y validaciones', () {
    expect(totalNomina(800000, 50000, 100000), 750000);
    expect(totalNomina(800000, null, null), 800000);
    expect(problemaNomina(hayBeneficiario: true, salario: 800000,
        extras: 50000, descuentos: 100000), isNull);
    expect(problemaNomina(hayBeneficiario: false, salario: 1),
        'Elige a quién se le paga.');
    expect(problemaNomina(hayBeneficiario: true, salario: null),
        'Escribe el salario.');
    expect(problemaNomina(hayBeneficiario: true, salario: 100, descuentos: 100),
        contains('no pueden ser iguales o mayores'));
    expect(problemaNomina(hayBeneficiario: true, salario: -5),
        'Los valores no pueden ser negativos.');
    expect(problemaNomina(hayBeneficiario: true, salario: double.nan),
        'Escribe los valores solo con números.');
  });

  test('gasto: validaciones', () {
    expect(problemaGasto(categoria: 'Aseo', monto: 38500,
        necesitaCuenta: false, hayCuenta: false), isNull);
    expect(problemaGasto(categoria: null, monto: 1,
        necesitaCuenta: false, hayCuenta: false), 'Elige la categoría.');
    expect(problemaGasto(categoria: 'Aseo', monto: 0,
        necesitaCuenta: false, hayCuenta: false), 'El monto debe ser mayor a cero.');
    expect(problemaGasto(categoria: 'Aseo', monto: 5,
        necesitaCuenta: true, hayCuenta: false), 'Elige la cuenta.');
  });

  test('periodo de nómina en palabras', () {
    expect(periodoNomina('q2', DateTime(2026, 11, 25)), '2.ª quincena nov 2026');
    expect(periodoNomina('q1', DateTime(2026, 1, 3)), '1.ª quincena ene 2026');
    expect(periodoNomina('mes', DateTime(2026, 11, 30)), 'Mes completo nov 2026');
    expect(periodoNomina('otro', DateTime(2026, 6, 30), otro: ' Prima junio '),
        'Prima junio');
    expect(quincenaDe(DateTime(2026, 11, 15)), 'q1');
    expect(quincenaDe(DateTime(2026, 11, 16)), 'q2');
  });

  test('textos: título, desglose y resumen del mes', () {
    final g = _gastos();
    expect(tituloGasto(g[0]), 'Laura Gómez · 2.ª quincena nov 2026');
    expect(desgloseNomina(g[0]), r'$800.000 + $50.000 − $100.000');
    expect(tituloGasto(g[1]), 'Recibo de luz · octubre');
    expect(desgloseNomina(g[1]), isNull);
    expect(resumenMes(_panel),
        r'Van $3.387.800 en 5 gastos: 22 % nómina, 76 % arriendo y servicios.');
    expect(resumenMes(const PanelGastos()),
        'Todavía no hay gastos registrados en este mes.');
    expect(porcentaje(15000, 3387800), '<1 %');
    expect(porcentaje(750000, 3387800), '22 %');
    expect(porcentaje(0, 0), '0 %');
    expect(fechaCorta(DateTime(2026, 11, 25), _hoy), 'Hoy');
    expect(fechaCorta(DateTime(2026, 11, 24), _hoy), 'Ayer');
    expect(fechaCorta(DateTime(2026, 11, 3), _hoy), '3 nov');
    expect(fechaCorta(DateTime(2025, 12, 3), _hoy), '3 dic 2025');
  });

  test('lo que manda el servidor se lee bien', () {
    final fl = File('${_scratch}gastos_lista_real.json');
    final fp = File('${_scratch}gastos_panel_real.json');
    if (!fl.existsSync() || !fp.existsSync()) return;
    final lista = (jsonDecode(fl.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map(GastoItem.fromJson)
        .toList();
    expect(lista, isNotEmpty);
    final nomina = lista.firstWhere((g) => g.esNomina);
    expect(nomina.monto, 750000);
    expect(nomina.salario, 800000);
    expect(nomina.beneficiario, isNotEmpty);
    expect(nomina.deCaja, isFalse);
    expect(lista.any((g) => g.deCaja), isTrue);
    final luz = lista.firstWhere((g) => g.categoria == 'Servicios');
    expect(luz.fecha, DateTime(2026, 11, 24));
    final panel = PanelGastos.fromJson(
        jsonDecode(fp.readAsStringSync()) as Map<String, dynamic>);
    expect(panel.total, greaterThan(0));
    expect(panel.nominaTotal, 750000);
    expect(panel.porCategoria, isNotEmpty);
  });

  // ── Computador ──────────────────────────────────────────────

  for (final ancho in [1366.0, 1000.0]) {
    testWidgets('computador sin desbordes a ${ancho.toInt()}px', (t) async {
      _tam(t, ancho, 1000);
      final log = <String>[];
      await _montar(t, GastosEscritorio(datos: _datos(), acciones: _acciones(log)));
      expect(find.text('GASTOS Y NÓMINA'), findsOneWidget);
      expect(find.text('Noviembre 2026'), findsWidgets);
      expect(find.text('Laura Gómez · 2.ª quincena nov 2026'), findsOneWidget);
      expect(find.text(r'$800.000 + $50.000 − $100.000'), findsOneWidget);
      expect(find.text('CAJA'), findsNWidgets(2));
      expect(find.text(r'$3.39M'), findsOneWidget);
      expect(find.textContaining('<1 %'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _foto(t, 'gastos_pc_${ancho.toInt()}.png');

      await t.tap(find.text('Registrar gasto'));
      await t.tap(find.text('Liquidar nómina'));
      await t.tap(find.text('Recibo de luz · octubre'));
      // El mes actual no deja ir al siguiente.
      await t.tap(find.byTooltip('Mes siguiente'));
      await t.tap(find.byTooltip('Mes anterior'));
      expect(log, ['gasto', 'nomina', 'ver 2', 'mes -1']);
    });
  }

  testWidgets('computador: filtro por categoría y mes vacío', (t) async {
    _tam(t, 1366, 1000);
    final log = <String>[];
    await _montar(t, GastosEscritorio(
        datos: _datos(categoria: 'Aseo'), acciones: _acciones(log)));
    expect(find.text('Bolsas, jabón, límpido'), findsOneWidget);
    expect(find.text('Recibo de luz · octubre'), findsNothing);
    await t.tap(find.text('Todos'));
    expect(log, ['categoria null']);

    await _montar(t, GastosEscritorio(
        datos: _datos(vacio: true), acciones: _acciones(log)));
    expect(find.textContaining('Sin gastos en este mes'), findsOneWidget);
    expect(find.text('Todavía no hay gastos registrados en este mes.'),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  // ── Celular ─────────────────────────────────────────────────

  for (final ancho in [320.0, 390.0]) {
    testWidgets('celular sin desbordes a ${ancho.toInt()}px', (t) async {
      _tam(t, ancho, 780);
      final log = <String>[];
      await _montar(t, GastosMovil(datos: _datos(), acciones: _acciones(log)));
      expect(find.text('Gastos y nómina'), findsOneWidget);
      expect(find.text('Noviembre 2026'), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('AYER'), findsOneWidget);
      expect(find.text('DE LA CAJA'), findsWidgets);
      expect(t.takeException(), isNull);
      await _foto(t, 'gastos_movil_${ancho.toInt()}.png');

      await t.tap(find.byTooltip('Registrar'));
      await t.tap(find.text('Laura Gómez · 2.ª quincena nov 2026'));
      expect(log, ['registrar', 'ver 1']);
    });
  }

  testWidgets('celular: elegir gasto o nómina', (t) async {
    _tam(t, 360, 780);
    final log = <String>[];
    await _montar(t, Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OpcionesRegistro(
            onGasto: () => log.add('gasto'), onNomina: () => log.add('nomina')),
      ),
    ));
    expect(t.takeException(), isNull);
    await _foto(t, 'gastos_opciones_360.png');
    await t.tap(find.text('Gasto'));
    await t.tap(find.text('Nómina'));
    expect(log, ['gasto', 'nomina']);
  });

  // ── Formularios ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> abrirFormGasto(WidgetTester t,
      {bool cajaAbierta = true, List<CuentaBancaria> cuentas = const [_cuenta],
      String? errorServidor, double ancho = 360}) async {
    _tam(t, ancho, 820);
    final enviados = <Map<String, dynamic>>[];
    await _montar(t, FormGasto(
      tiendas: _tiendas,
      tiendaInicial: 1,
      hoy: _hoy,
      cargarCuentas: (_) async => cuentas,
      cajaAbierta: (_) async => cajaAbierta,
      onCancelar: () {},
      onGuardar: (d) async {
        enviados.add(d);
        return errorServidor;
      },
    ));
    return enviados;
  }

  testWidgets('gasto: aseo en efectivo, "de la caja" apagado por defecto',
      (t) async {
    final enviados = await abrirFormGasto(t, ancho: 320);
    await t.tap(find.text('Aseo'));
    await t.enterText(find.byType(TextField).first, 'Bolsas y jabón');
    await t.enterText(find.byType(TextField).at(1), '38.500');
    await t.pumpAndSettle();
    expect(find.textContaining('Salió del cajón'), findsOneWidget);
    expect(t.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(t.renderObject<RenderParagraph>(find.text('Cancelar'))
        .didExceedMaxLines, isFalse);
    expect(t.takeException(), isNull);
    await _foto(t, 'gastos_form_320.png');
    await t.tap(find.text('Guardar gasto'));
    await t.pumpAndSettle();
    expect(enviados.single['categoria'], 'Aseo');
    expect(enviados.single['monto'], '38500.00');
    expect(enviados.single['metodo_pago'], 'efectivo');
    expect(enviados.single['fecha'], '2026-11-25');
    expect(enviados.single.containsKey('de_caja'), isFalse);
    expect(enviados.single['tipo_gasto'], 'variable');
  });

  testWidgets('gasto: marcado "de la caja" lo manda', (t) async {
    final enviados = await abrirFormGasto(t);
    await t.tap(find.text('Aseo'));
    await t.enterText(find.byType(TextField).at(1), '12000');
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(Switch));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    await t.tap(find.text('Guardar gasto'));
    await t.pumpAndSettle();
    expect(enviados.single['de_caja'], isTrue);
  });

  testWidgets('gasto: sin caja abierta no aparece "de la caja"', (t) async {
    await abrirFormGasto(t, cajaAbierta: false);
    expect(find.textContaining('Salió del cajón'), findsNothing);
  });

  testWidgets('gasto: transferencia elige la única cuenta y la manda',
      (t) async {
    final enviados = await abrirFormGasto(t);
    await t.tap(find.text('Servicios'));
    await t.enterText(find.byType(TextField).at(1), '184.300');
    await t.ensureVisible(find.text('Transferencia'));
    await t.tap(find.text('Transferencia'));
    await t.pumpAndSettle();
    expect(find.textContaining('Salió del cajón'), findsNothing);
    expect(find.text('Bancolombia ahorros · …4321'), findsOneWidget);
    await t.tap(find.text('Guardar gasto'));
    await t.pumpAndSettle();
    expect(enviados.single['cuenta_bancaria'], 7);
    expect(enviados.single['monto'], '184300.00');
    expect(enviados.single['tipo_gasto'], 'fijo');
  });

  testWidgets('gasto: avisa lo que falta y el error del servidor', (t) async {
    final enviados = await abrirFormGasto(t,
        errorServidor: 'Esa tienda no tiene la caja abierta.');
    await t.tap(find.text('Guardar gasto'));
    await t.pumpAndSettle();
    expect(find.text('Elige la categoría.'), findsOneWidget);
    expect(enviados, isEmpty);
    await t.tap(find.text('Insumos'));
    await t.enterText(find.byType(TextField).at(1), '-5');
    await t.pumpAndSettle();
    expect(find.text('El monto debe ser mayor a cero.'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(1), '5000');
    await t.pumpAndSettle();
    await t.tap(find.text('Guardar gasto'));
    await t.pumpAndSettle();
    expect(find.text('Esa tienda no tiene la caja abierta.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  Future<List<Map<String, dynamic>>> abrirFormNomina(WidgetTester t,
      {double ancho = 360}) async {
    _tam(t, ancho, 860);
    final enviados = <Map<String, dynamic>>[];
    await _montar(t, FormNomina(
      tiendas: _tiendas,
      empleados: const [
        EmpleadoOpcion(2, 'Laura Gómez', detalle: 'Cajero(a) · Boutique 27',
            tiendaId: 1),
        EmpleadoOpcion(3, 'Ginna Montilla', detalle: 'Cajero(a) · Novacentro',
            tiendaId: 2),
      ],
      tiendaInicial: 1,
      hoy: _hoy,
      cargarCuentas: (_) async => const [_cuenta],
      onCancelar: () {},
      onGuardar: (d) async {
        enviados.add(d);
        return null;
      },
    ));
    return enviados;
  }

  testWidgets('nómina: calcula el total y manda todo', (t) async {
    final enviados = await abrirFormNomina(t, ancho: 320);
    await t.tap(find.byType(DropdownButtonFormField<int>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Laura Gómez · Cajero(a) · Boutique 27').last);
    await t.pumpAndSettle();
    final campos = find.byType(TextField);
    await t.enterText(campos.at(0), '800.000');
    await t.enterText(campos.at(1), '50.000');
    await t.enterText(campos.at(2), '100.000');
    await t.pumpAndSettle();
    expect(find.text(r'$750.000'), findsOneWidget);
    // Hoy es 25: la 2.ª quincena viene elegida.
    expect(t.takeException(), isNull);
    await _foto(t, 'gastos_nomina_320.png');
    await t.tap(find.text('Registrar pago'));
    await t.pumpAndSettle();
    final d = enviados.single;
    expect(d['categoria'], 'Nómina');
    expect(d['beneficiario'], 2);
    expect(d['periodo'], '2.ª quincena nov 2026');
    expect(d['salario'], '800000.00');
    expect(d['extras'], '50000.00');
    expect(d['descuentos'], '100000.00');
    expect(d['metodo_pago'], 'transferencia');
    expect(d['cuenta_bancaria'], 7);
  });

  testWidgets('nómina: otra persona, periodo libre y descuentos de más',
      (t) async {
    final enviados = await abrirFormNomina(t);
    await t.tap(find.byType(DropdownButtonFormField<int>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Otra persona').last);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Pedro (aseo)');
    await t.tap(find.text('Otro'));
    await t.pumpAndSettle();
    final campos = find.byType(TextField);
    await t.enterText(campos.at(1), 'Prima de diciembre');
    await t.enterText(campos.at(2), '100000');
    await t.enterText(campos.at(4), '150000');
    await t.pumpAndSettle();
    await t.tap(find.text('Registrar pago'));
    await t.pumpAndSettle();
    expect(find.textContaining('no pueden ser iguales o mayores'), findsOneWidget);
    expect(enviados, isEmpty);
    await t.enterText(campos.at(4), '0');
    await t.pumpAndSettle();
    await t.tap(find.text('Registrar pago'));
    await t.pumpAndSettle();
    expect(enviados.single['beneficiario_nombre'], 'Pedro (aseo)');
    expect(enviados.single.containsKey('beneficiario'), isFalse);
    expect(enviados.single['periodo'], 'Prima de diciembre');
  });

  testWidgets('detalle: eliminar pide confirmación', (t) async {
    _tam(t, 360, 780);
    var borrados = 0;
    await _montar(t, DetalleGasto(
      gasto: _gastos()[0],
      hoy: _hoy,
      onCerrar: () {},
      onEliminar: () async {
        borrados++;
        return 'No se puede eliminar un gasto de una sesión ya cerrada.';
      },
    ));
    expect(find.text('Salario'), findsOneWidget);
    expect(find.text(r'$800.000'), findsOneWidget);
    await _foto(t, 'gastos_detalle_360.png');
    await t.tap(find.text('Eliminar'));
    await t.pumpAndSettle();
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);
    expect(borrados, 0);
    await t.tap(find.text('Sí, eliminar'));
    await t.pumpAndSettle();
    expect(borrados, 1);
    expect(find.text('No se puede eliminar un gasto de una sesión ya cerrada.'),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
