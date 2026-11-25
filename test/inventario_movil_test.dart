// Render de la vista móvil de inventario.
//
// - Falla si algo se desborda en los anchos típicos de celular (el bug
//   original: textos partidos letra por letra y tarjetas aplastadas).
// - Verifica que las acciones del detalle llamen a su callback.
// - Con --dart-define=SHOT_DIR=<carpeta> guarda capturas PNG para revisar
//   el diseño a ojo.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/models/producto.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/inventario_movil.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/producto_form_dialog.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _iconos =
    r'C:\dev\flutter_windows_3.35.4-stable\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';

final _marco = GlobalKey();

/// Carga una fuente real (si existe en la máquina) para que las capturas
/// se lean. Sin ella el test igual corre, con la fuente de pruebas.
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

List<Producto> _productos() => [
      Producto(id: 1, nombre: 'Aretes Corazón Plata', referencia: 'AC-0012',
          categoria: 'Aretes', precio: 32000, precioCompra: 18000,
          stockActual: 48, stockMinimo: 10, stockMaximo: 80),
      Producto(id: 2, nombre: 'Collar Perlas Blancas', referencia: 'CP-0045',
          categoria: 'Collares', precio: 85000, precioCompra: 52000,
          stockActual: 8, stockMinimo: 12),
      Producto(id: 3, nombre: 'Pulsera Oro 18K', referencia: 'PO-0021',
          categoria: 'Pulseras', precio: 125000, precioCompra: 78000,
          stockActual: 0, stockMinimo: 5),
      Producto(id: 4,
          nombre: 'Set de anillos ajustables chapados en oro rosa edición especial',
          referencia: '7701234567890123',
          categoria: 'Anillos y accesorios para regalo',
          precio: 1250000, precioCompra: 700000, stockActual: 1240),
      Producto(id: 5, nombre: 'Bolso Cuero Azul', referencia: 'BC-0088',
          categoria: 'Bolsos', precio: 210000, precioCompra: 130000,
          stockActual: 15, stockMinimo: 6),
      Producto(id: 6, nombre: 'Reloj Acero Mate', referencia: '',
          categoria: 'Relojes', precio: 340000, precioCompra: 210000,
          stockActual: 3, stockMinimo: 4, activo: false),
    ];

const _kpis = [
  KpiMovil(etiqueta: 'Valor inventario', valor: r'$186.3M',
      detalle: '100 productos', icono: Icons.account_balance_wallet_rounded,
      tono: TonoMovil.verde),
  KpiMovil(etiqueta: 'Alertas de stock', valor: '38', sufijo: 'ítems',
      detalle: '14 críticos (agotados)', icono: Icons.warning_rounded,
      tono: TonoMovil.rojo, detalleDestacado: true),
  KpiMovil(etiqueta: 'Ingresos del mes', valor: '43', sufijo: 'uds',
      detalle: 'Unidades recibidas', icono: Icons.move_to_inbox_rounded,
      tono: TonoMovil.turquesa),
  KpiMovil(etiqueta: 'Daños / pérdidas', valor: '1', sufijo: 'unid.',
      detalle: 'Reportadas este mes', icono: Icons.report_rounded,
      tono: TonoMovil.ambar),
];

Future<void> _pantalla(
  WidgetTester t,
  double ancho, {
  void Function(String)? registro,
  bool conTiendas = true,
  bool conFab = true,
}) async {
  t.view.physicalSize = Size(ancho * 3, 780 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);

  final ctrl = TextEditingController();
  addTearDown(ctrl.dispose);

  AccionMovil a(String e, IconData i, TonoMovil tono) => AccionMovil(
      etiqueta: e, icono: i, tono: tono, onTap: () => registro?.call(e));

  await t.pumpWidget(RepaintBoundary(
    key: _marco,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => InventarioMovil(
            subtitulo: 'Consentida Accesorios Unicentro',
            tiendas: conTiendas
                ? const [
                    TiendaMovil(null, 'Todas'),
                    TiendaMovil(1, 'Consentida Accesorios Unicentro'),
                    TiendaMovil(2, 'Consentida Boutique 27'),
                  ]
                : const [],
            tiendaSeleccionada: 1,
            onTienda: (_) {},
            kpis: _kpis,
            agotados: 14,
            bajos: 24,
            onAlerta: () => registro?.call('alerta'),
            buscar: ctrl,
            onBuscar: (_) {},
            filtrosActivos: 2,
            onFiltros: () => registro?.call('filtros'),
            onEscanear: () => registro?.call('escanear'),
            estado: 'true',
            onEstado: (_) {},
            productos: _productos(),
            onProducto: (p) => mostrarDetalleProductoMovil(ctx,
                producto: p,
                acciones: [
                  a('Editar', Icons.edit_rounded, TonoMovil.verde),
                  a('Kardex', Icons.receipt_long_rounded, TonoMovil.turquesa),
                  a('Ajustar stock', Icons.tune_rounded, TonoMovil.lima),
                  a('Transferir', Icons.swap_horiz_rounded, TonoMovil.turquesa),
                  a('Avería', Icons.report_rounded, TonoMovil.ambar),
                  a('Desactivar', Icons.block_rounded, TonoMovil.rojo),
                ]),
            onInsights: () => registro?.call('insights'),
            accionesFab: conFab
                ? [
                    a('Nuevo producto', Icons.add_box_rounded, TonoMovil.verde),
                    a('Reportar avería', Icons.report_rounded, TonoMovil.ambar),
                    a('Importar Excel', Icons.upload_file_rounded,
                        TonoMovil.turquesa),
                    a('Exportar Excel', Icons.download_rounded, TonoMovil.lima),
                  ]
                : const [],
            accionesMas: [
              a('Escanear código', Icons.qr_code_scanner_rounded,
                  TonoMovil.turquesa),
            ],
          ),
        ),
      ),
    ),
  ));
  await t.pumpAndSettle();
}

Future<void> _foto(WidgetTester t, String nombre) async {
  if (_shotDir.isEmpty) return;
  final ro = _marco.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$_shotDir${Platform.pathSeparator}$nombre')
        .writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_cargarFuentes);

  for (final ancho in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets('pantalla principal sin desbordes a ${ancho.toInt()}px',
        (t) async {
      await _pantalla(t, ancho);
      expect(find.text('MÉTRICAS CLAVE'), findsOneWidget);
      expect(find.text('PRODUCTOS'), findsOneWidget);
      expect(find.text('14 productos agotados'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _foto(t, 'principal_${ancho.toInt()}.png');
    });
  }

  testWidgets('la lista baja hasta el final sin desbordes', (t) async {
    await _pantalla(t, 360);
    await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await t.pumpAndSettle();
    expect(find.text('Reloj Acero Mate'), findsOneWidget);
    expect(find.text('Inactivo'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'lista_abajo_360.png');
  });

  testWidgets('detalle de producto y sus acciones', (t) async {
    final llamadas = <String>[];
    await _pantalla(t, 390, registro: llamadas.add);

    await t.tap(find.text('Aretes Corazón Plata'));
    await t.pumpAndSettle();
    expect(find.text('ACCIONES'), findsOneWidget);
    expect(find.text('+77.8%'), findsOneWidget); // margen sobre costo
    expect(t.takeException(), isNull);
    await _foto(t, 'detalle_390.png');

    await t.tap(find.text('Kardex'));
    await t.pumpAndSettle();
    expect(llamadas, ['Kardex']);
    expect(find.text('ACCIONES'), findsNothing); // la hoja se cerró
  });

  testWidgets('detalle con nombre y categoría muy largos a 320px', (t) async {
    await _pantalla(t, 320);
    final largo = find.textContaining('Set de anillos');
    await t.ensureVisible(largo);
    await t.pumpAndSettle();
    await t.tap(largo);
    await t.pumpAndSettle();
    expect(find.text('ACCIONES'), findsOneWidget); // la hoja sí abrió
    expect(t.takeException(), isNull);
    await _foto(t, 'detalle_largo_320.png');
  });

  testWidgets('menú del botón + abre y ejecuta', (t) async {
    final llamadas = <String>[];
    await _pantalla(t, 390, registro: llamadas.add);

    await t.tap(find.byIcon(Icons.add_rounded));
    await t.pumpAndSettle();
    expect(find.text('Importar Excel'), findsOneWidget);
    await _foto(t, 'fab_390.png');

    await t.tap(find.text('Nuevo producto'));
    await t.pumpAndSettle();
    expect(llamadas, ['Nuevo producto']);
    expect(find.text('Importar Excel'), findsNothing);
  });

  testWidgets('cajero: sin botón + y sin chips de tienda', (t) async {
    await _pantalla(t, 360, conTiendas: false, conFab: false);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.text('Consentida Accesorios Unicentro'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  // ── Análisis ────────────────────────────────────────────────
  Future<void> abrirAnalisis(
    WidgetTester t,
    double ancho, {
    List<String>? registro,
    bool vacio = false,
  }) async {
    t.view.physicalSize = Size(ancho * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final ahora = DateTime(2026, 11, 24, 12);
    AlertaStockMovil al(String n, String c, double s, double m) =>
        AlertaStockMovil(nombre: n, categoria: c, stock: s, minimo: m);
    MovimientoMovil mv(String p, String tipo, double c, DateTime f,
            String emp, String det) =>
        MovimientoMovil(
            producto: p, tipo: tipo, cantidad: c, fecha: f,
            empleado: emp, detalle: det,
            onTap: () => registro?.add('mov:$p'));

    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => mostrarPanelMovil(ctx,
                    titulo: 'Análisis',
                    subtitulo: 'Consentida Accesorios Unicentro',
                    panel: () => AnalisisMovil(
                          ahora: ahora,
                          agotados: vacio
                              ? const []
                              : [
                                  al('PULSERA FANTASÍA', 'BISUTERÍA', 0, 5),
                                  al('PULSERA FINA ORO', 'BISUTERÍA', 0, 3),
                                  al('BOLSO', 'BOLSOS', 0, 2),
                                  al('PULSERA FLORAL', '', 0, 4),
                                  al('ARETES PLATA', 'BISUTERÍA', 0, 6),
                                ],
                          bajos: vacio
                              ? const []
                              : [
                                  al('GORRA CERRADA', 'ACCESORIOS', 2, 5),
                                  al('ANILLO RODIO', 'BISUTERÍA', 3, 10),
                                ],
                          vendidos: vacio
                              ? const []
                              : const [
                                  VendidoMovil(nombre: 'GORRA CERRADA',
                                      categoria: 'ACCESORIOS',
                                      unidades: 33, ingresos: 1980000),
                                  VendidoMovil(nombre: 'BOLSO',
                                      categoria: 'BOLSOS',
                                      unidades: 19, ingresos: 1710000),
                                  VendidoMovil(nombre: 'ARETES PLATA',
                                      categoria: 'BISUTERÍA',
                                      unidades: 101, ingresos: 1145700),
                                  VendidoMovil(nombre: 'ANILLO RODIO',
                                      categoria: 'BISUTERÍA',
                                      unidades: 60, ingresos: 750000),
                                  VendidoMovil(nombre: 'PAÑOLETAS',
                                      categoria: 'PRENDAS',
                                      unidades: 62, ingresos: 713000),
                                ],
                          movimientos: vacio
                              ? const []
                              : [
                                  mv('PAÑOLETAS', 'salida', 1,
                                      DateTime(2026, 11, 24, 9, 15),
                                      'Viviana Romo', 'Venta FAC-000080'),
                                  mv('ARETES PLATA', 'entrada', 20,
                                      DateTime(2026, 11, 23, 16, 2),
                                      'Leidy Estrada', 'Compra OC-0014'),
                                  mv('GORRA CERRADA', 'salida', 1,
                                      DateTime(2026, 11, 7, 15, 38),
                                      'Viviana Romo', 'Venta FAC-000073'),
                                  mv('ANILLO RODIO', 'ajuste', -2,
                                      DateTime(2026, 11, 7, 8, 40),
                                      'Leidy Estrada', 'Ajuste por conteo'),
                                  mv('BOLSO', 'transferencia', 3,
                                      DateTime(2025, 10, 26, 11, 5),
                                      'Carlos Velasco', ''),
                                ],
                          onVerAlertas: (tipo) => registro?.add('ver:$tipo'),
                        )),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets('análisis sin desbordes a ${ancho.toInt()}px', (t) async {
      await abrirAnalisis(t, ancho);
      expect(find.text('Análisis'), findsOneWidget);
      expect(find.text('Agotados · 5'), findsOneWidget);
      expect(find.text('Más vendidos'), findsOneWidget);
      expect(find.text('+1 más'), findsOneWidget); // 5 agotados, se ven 4
      expect(find.text('Sin categoría'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _foto(t, 'analisis_${ancho.toInt()}.png');

      await t.drag(find.byType(ListView).last, const Offset(0, -700));
      await t.pumpAndSettle();
      expect(find.text('Movimientos recientes'), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('AYER'), findsOneWidget);
      expect(find.text('7 NOV'), findsOneWidget);
      expect(find.text('26 OCT 2025'), findsOneWidget); // otro año
      expect(find.text('−2 uds'), findsOneWidget);       // ajuste negativo
      expect(t.takeException(), isNull);
      await _foto(t, 'analisis_abajo_${ancho.toInt()}.png');
    });
  }

  testWidgets('análisis: pestañas, ver en la lista y abrir movimiento',
      (t) async {
    final llamadas = <String>[];
    await abrirAnalisis(t, 390, registro: llamadas);

    await t.tap(find.text('Stock bajo · 2'));
    await t.pumpAndSettle();
    expect(find.text('mín. 10'), findsOneWidget);
    expect(find.text('Ver los 2 en la lista'), findsOneWidget);
    await _foto(t, 'analisis_stock_bajo_390.png');

    await t.tap(find.text('Ver los 2 en la lista'));
    await t.pumpAndSettle();
    expect(llamadas, ['ver:bajo']);
    expect(find.text('Más vendidos'), findsNothing); // la hoja se cerró

    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView).last, const Offset(0, -700));
    await t.pumpAndSettle();
    await t.tap(find.text('GORRA CERRADA').last);
    await t.pumpAndSettle();
    expect(llamadas.last, 'mov:GORRA CERRADA');
  });

  testWidgets('análisis sin datos muestra mensajes, no tarjetas vacías',
      (t) async {
    await abrirAnalisis(t, 360, vacio: true);
    expect(find.text('Todo en orden'), findsOneWidget);
    expect(find.text('Todavía no hay ventas registradas.'), findsOneWidget);
    expect(find.text('Sin movimientos recientes.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  // ── Formulario de producto (móvil) ─────────────────────────
  Future<void> abrirFormulario(
    WidgetTester t,
    double ancho, {
    Producto? producto,
    void Function(Map<String, dynamic>)? alGuardar,
  }) async {
    t.view.physicalSize = Size(ancho * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => ProductoFormDialog(
                    producto: producto,
                    tiendaId: 1,
                    onGuardar: (data) async => alGuardar?.call(data),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets('formulario nuevo sin desbordes a ${ancho.toInt()}px',
        (t) async {
      await abrirFormulario(t, ancho);
      expect(find.text('Nuevo producto'), findsOneWidget);
      expect(find.text('DATOS DEL PRODUCTO'), findsOneWidget);
      expect(find.text('Guardar producto'), findsOneWidget);
      // El recuadro de imagen no hacía nada: en móvil ya no aparece.
      expect(find.textContaining('arrastra'), findsNothing);
      // Que ningún botón se parta en dos líneas ("Cancel / ar").
      for (final b in ['Cancelar', 'Guardar producto']) {
        expect(t.getSize(find.text(b)).height, lessThan(26),
            reason: '"$b" se partió en dos líneas a ${ancho.toInt()}px');
      }
      expect(t.takeException(), isNull);
      await _foto(t, 'form_nuevo_${ancho.toInt()}.png');

      await t.drag(find.byType(SingleChildScrollView).last,
          const Offset(0, -900));
      await t.pumpAndSettle();
      expect(find.text('INVENTARIO'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _foto(t, 'form_nuevo_abajo_${ancho.toInt()}.png');
    });
  }

  testWidgets('formulario: editar muestra los datos y el margen', (t) async {
    await abrirFormulario(t, 360, producto: _productos()[0]);
    expect(find.text('Editar producto'), findsOneWidget);
    expect(find.text('Aretes Corazón Plata'), findsWidgets);
    expect(find.text('Margen 77.8%'), findsOneWidget);
    expect(find.text('Margen sano'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'form_editar_360.png');
  });

  testWidgets('formulario: no deja guardar sin nombre ni precio', (t) async {
    var guardo = false;
    await abrirFormulario(t, 390, alGuardar: (_) => guardo = true);
    await t.tap(find.text('Guardar producto'));
    await t.pumpAndSettle();
    expect(find.text('Escribe el nombre'), findsOneWidget);
    expect(guardo, isFalse);
    expect(t.takeException(), isNull);
    await _foto(t, 'form_errores_390.png');
  });

  testWidgets('formulario: guarda con los datos escritos', (t) async {
    Map<String, dynamic>? enviado;
    await abrirFormulario(t, 390, alGuardar: (d) => enviado = d);

    final campos = find.byType(TextFormField);
    await t.enterText(campos.at(0), 'Collar perlas');      // nombre
    await t.enterText(campos.at(1), '7701234567890');      // código
    await t.enterText(campos.at(2), 'Bisutería');          // categoría
    await t.enterText(campos.at(4), '20000');              // costo
    await t.enterText(campos.at(5), '35000');              // venta
    await t.pumpAndSettle();
    expect(find.text('Margen 75.0%'), findsOneWidget);

    await t.tap(find.text('Guardar producto'));
    await t.pumpAndSettle();
    expect(enviado, isNotNull);
    expect(enviado!['nombre'], 'Collar perlas');
    expect(enviado!['codigo_barras'], '7701234567890');
    expect(enviado!['categoria_nombre'], 'Bisutería');
    expect(enviado!['precio_compra'], 20000);
    expect(enviado!['precio_venta'], 35000);
    expect(find.text('Nuevo producto'), findsNothing); // se cerró
  });

  // ── Averías (móvil) ────────────────────────────────────────
  Future<void> abrirAverias(
    WidgetTester t,
    double ancho, {
    List<AveriaMovil>? items,
    String? error,
    List<String>? registro,
    String? errorServidor,
  }) async {
    t.view.physicalSize = Size(ancho * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final datos = items ??
        const [
          AveriaMovil(nombre: 'ANILLO RODIO', categoria: 'BISUTERIA', unidades: 1),
          AveriaMovil(nombre: 'Set de anillos ajustables chapados en oro rosa edición especial',
              categoria: '', unidades: 12),
          AveriaMovil(nombre: 'PAÑOLETAS', categoria: 'PRENDAS', unidades: 3),
        ];

    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          body: AveriasMovil(
            tienda: 'Consentida Boutique Novacentro',
            items: datos,
            error: error,
            onReintentar: () => registro?.add('reintentar'),
            onAccion: (a, accion, c) async {
              registro?.add('$accion:${a.nombre}:$c');
              return errorServidor;
            },
            onHistorial: (a) async => [
              HistorialAveriaMovil(cantidad: 1,
                  fecha: DateTime(2026, 11, 20, 16, 5),
                  empleado: 'Leidy Estrada', observacion: 'Se cayó de la vitrina'),
              HistorialAveriaMovil(cantidad: 2,
                  fecha: DateTime(2026, 11, 2, 10, 30),
                  empleado: 'Viviana Romo'),
            ],
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets('averías sin desbordes a ${ancho.toInt()}px', (t) async {
      await abrirAverias(t, ancho);
      expect(find.text('16 unidades en averías'), findsOneWidget);
      expect(find.text('3 productos afectados'), findsOneWidget);
      expect(find.text('BISUTERIA'), findsOneWidget);
      expect(find.text('Sin categoría'), findsOneWidget);
      // La categoría ya no sale letra por letra: ocupa una sola línea.
      expect(t.getSize(find.text('BISUTERIA')).height, lessThan(20));
      for (final b in ['Historial', 'Recuperar', 'Descartar']) {
        expect(t.getSize(find.text(b).first).height, lessThan(20),
            reason: '"$b" se partió en dos líneas');
      }
      expect(t.takeException(), isNull);
      await _foto(t, 'averias_${ancho.toInt()}.png');
    });
  }

  testWidgets('averías: recuperar con el contador y aviso de éxito', (t) async {
    final llamadas = <String>[];
    await abrirAverias(t, 360, registro: llamadas);

    await t.tap(find.text('Recuperar').at(1)); // el 2º producto, el de 12 uds
    await t.pumpAndSettle();
    expect(find.text('Recuperar al stock'), findsOneWidget);
    expect(find.text('Máximo 12'), findsOneWidget);

    await t.tap(find.byIcon(Icons.add_rounded));
    await t.tap(find.byIcon(Icons.add_rounded));
    await t.pumpAndSettle();
    expect(find.text('2'), findsWidgets);
    expect(t.takeException(), isNull);
    await _foto(t, 'averias_recuperar_360.png');

    await t.tap(find.widgetWithText(FilledButton, 'Recuperar'));
    await t.pumpAndSettle();
    expect(llamadas.single, startsWith('recuperar:Set de anillos'));
    expect(llamadas.single, endsWith(':2.0'));
    expect(find.textContaining('volvieron al stock'), findsOneWidget);
    expect(find.text('Recuperar al stock'), findsNothing); // se cerró
  });

  testWidgets('averías: descartar avisa que no se deshace y valida', (t) async {
    final llamadas = <String>[];
    await abrirAverias(t, 390, registro: llamadas);

    await t.tap(find.text('Descartar').first);
    await t.pumpAndSettle();
    expect(find.text('Dar de baja'), findsWidgets);
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);

    await t.enterText(find.byType(TextField), '5'); // hay solo 1
    await t.tap(find.widgetWithText(FilledButton, 'Dar de baja'));
    await t.pumpAndSettle();
    expect(find.text('Solo hay 1 en averías.'), findsOneWidget);
    expect(llamadas, isEmpty);
    await _foto(t, 'averias_descartar_390.png');
  });

  testWidgets('averías: si el servidor falla se muestra su mensaje', (t) async {
    await abrirAverias(t, 390, errorServidor: 'Stock de averías insuficiente');
    await t.tap(find.text('Recuperar').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Usar todas'));
    await t.tap(find.widgetWithText(FilledButton, 'Recuperar'));
    await t.pumpAndSettle();
    expect(find.text('Stock de averías insuficiente'), findsOneWidget);
    expect(find.text('Recuperar al stock'), findsOneWidget); // sigue abierto
  });

  testWidgets('averías: historial en hoja', (t) async {
    await abrirAverias(t, 360);
    await t.tap(find.text('Historial').first);
    await t.pumpAndSettle();
    expect(find.text('Historial de averías'), findsOneWidget);
    expect(find.text('Se cayó de la vitrina'), findsOneWidget);
    expect(find.text('Sin observación'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'averias_historial_360.png');
  });

  testWidgets('averías: vacío y error', (t) async {
    final llamadas = <String>[];
    await abrirAverias(t, 360, items: const []);
    expect(find.text('Sin averías'), findsOneWidget);
    expect(find.textContaining('toca «Avería»'), findsOneWidget);
    expect(t.takeException(), isNull);

    await abrirAverias(t, 360, items: const [], error: 'Sin conexión',
        registro: llamadas);
    expect(find.text('No se pudieron cargar las averías'), findsOneWidget);
    await t.tap(find.text('Reintentar'));
    expect(llamadas, ['reintentar']);
  });

  // ── Importar Excel (móvil) ─────────────────────────────────
  Future<void> abrirImportar(
    WidgetTester t,
    double ancho,
    PasoImportacion paso, {
    List<String>? registro,
    String? error,
    bool cargando = false,
    ResultadoImportMovil? resultado,
  }) async {
    t.view.physicalSize = Size(ancho * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final listas = List.generate(9, (i) => FilaImportMovil(
          fila: i + 2,
          nombre: i == 0
              ? 'Set de anillos ajustables chapados en oro rosa edición especial'
              : 'Producto de prueba ${i + 1}',
          codigo: '77012345678${i.toString().padLeft(2, '0')}',
          categoria: i.isEven ? 'BISUTERIA' : '',
          precio: 12500.0 * (i + 1),
          stock: (i * 3).toDouble(),
        ));

    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          body: ImportarExcelMovil(
            tienda: 'Consentida Boutique Novacentro',
            paso: paso,
            cargando: cargando,
            mensajeCarga: 'Importando 9 productos…',
            nombreArchivo: 'inventario_noviembre_2026_definitivo.xlsx',
            listas: listas,
            conError: const [
              FilaImportMovil(fila: 14, nombre: 'GORRA CERRADA',
                  precio: -5000, stock: 3, error: 'Precio de venta negativo'),
              FilaImportMovil(fila: 21, nombre: 'PAÑOLETAS',
                  categoria: 'PRENDAS', precio: 9000, stock: -2,
                  error: 'Stock negativo'),
            ],
            resultado: resultado,
            error: error,
            onElegirArchivo: () => registro?.add('elegir'),
            onPlantilla: () => registro?.add('plantilla'),
            onImportar: () => registro?.add('importar'),
            onVolver: () => registro?.add('volver'),
            onCerrar: () => registro?.add('cerrar'),
          ),
        ),
      ),
    ));
    // El indicador de carga gira sin parar: ahí no se espera a que se quede
    // quieto, solo se pinta un cuadro.
    if (cargando) {
      await t.pump(const Duration(milliseconds: 100));
    } else {
      await t.pumpAndSettle();
    }
  }

  /// En una sola línea y sin cortarse con "…".
  bool unaLinea(WidgetTester t, String texto) =>
      t.getSize(find.text(texto)).height < 26 &&
      !t.renderObject<RenderParagraph>(find.text(texto)).didExceedMaxLines;

  for (final ancho in [320.0, 390.0]) {
    testWidgets('importar: paso 1 sin desbordes a ${ancho.toInt()}px',
        (t) async {
      final llamadas = <String>[];
      await abrirImportar(t, ancho, PasoImportacion.archivo,
          registro: llamadas);
      expect(find.text('PASO 1 DE 3 · ELEGIR ARCHIVO'), findsOneWidget);
      expect(find.text('nombre *'), findsOneWidget);
      expect(find.textContaining('arrastra'), findsNothing); // es celular
      expect(t.takeException(), isNull);
      await _foto(t, 'importar_archivo_${ancho.toInt()}.png');

      await t.tap(find.text('Elegir archivo de Excel'));
      await t.tap(find.text('Descargar plantilla'));
      expect(llamadas, ['elegir', 'plantilla']);
    });

    testWidgets('importar: revisar sin desbordes a ${ancho.toInt()}px',
        (t) async {
      final llamadas = <String>[];
      await abrirImportar(t, ancho, PasoImportacion.revisar,
          registro: llamadas);
      expect(find.text('Listos · 9'), findsOneWidget);
      expect(find.text('Con error · 2'), findsOneWidget);
      expect(find.textContaining('2 filas con error'), findsOneWidget);
      expect(unaLinea(t, 'Volver'), isTrue);
      expect(unaLinea(t, 'Importar 9 productos'), isTrue);
      expect(t.takeException(), isNull);
      await _foto(t, 'importar_revisar_${ancho.toInt()}.png');

      await t.tap(find.text('Importar 9 productos'));
      expect(llamadas, ['importar']);
    });
  }

  testWidgets('importar: pestaña de errores y búsqueda', (t) async {
    await abrirImportar(t, 360, PasoImportacion.revisar);
    await t.tap(find.text('Con error · 2'));
    await t.pumpAndSettle();
    expect(find.text('Precio de venta negativo'), findsOneWidget);
    expect(find.text('Stock negativo'), findsOneWidget);
    expect(find.text('Fila 14'), findsOneWidget);
    await _foto(t, 'importar_errores_360.png');

    await t.tap(find.text('Listos · 9'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'prueba 7');
    await t.pumpAndSettle();
    expect(find.text('Producto de prueba 7'), findsOneWidget);
    expect(find.text('Producto de prueba 2'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('importar: resultado parcial con las filas no importadas',
      (t) async {
    await abrirImportar(t, 360, PasoImportacion.resultado,
        resultado: const ResultadoImportMovil(
          creados: 7, fallidos: 2, total: 9,
          noImportadas: [
            FilaImportMovil(fila: 5, nombre: 'Producto de prueba 4',
                error: 'Ya existe un producto con ese código de barras',
                conDetalle: false),
            FilaImportMovil(fila: 8, nombre: 'Producto de prueba 7',
                error: 'Categoría inválida', conDetalle: false),
          ],
        ));
    expect(find.text('Se importaron 7 de 9 productos'), findsOneWidget);
    expect(find.text('NO SE IMPORTARON'), findsOneWidget);
    expect(find.text('Ya existe un producto con ese código de barras'),
        findsOneWidget);
    expect(find.text(r'$0'), findsNothing); // sin ceros inventados
    expect(t.takeException(), isNull);
    await _foto(t, 'importar_resultado_360.png');
  });

  testWidgets('importar: cargando y error visibles dentro de la pantalla',
      (t) async {
    await abrirImportar(t, 360, PasoImportacion.revisar, cargando: true);
    expect(find.text('Importando 9 productos…'), findsOneWidget);
    expect(find.text('Volver'), findsNothing); // sin pie mientras carga

    await abrirImportar(t, 360, PasoImportacion.archivo,
        error: 'No se encontraron filas de datos válidas.');
    expect(find.text('No se encontraron filas de datos válidas.'),
        findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'importar_error_360.png');
  });

  testWidgets('alerta, escáner y filtros llaman a su acción', (t) async {
    final llamadas = <String>[];
    await _pantalla(t, 390, registro: llamadas.add);
    await t.tap(find.text('14 productos agotados'));
    await t.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await t.tap(find.byIcon(Icons.tune_rounded));
    expect(llamadas, ['alerta', 'escanear', 'filtros']);
  });

  // ── Exportar ────────────────────────────────────────────────

  const categoriasExport = [
    CategoriaMovil(1, 'Bisutería'),
    CategoriaMovil(2, 'Bolsos'),
    CategoriaMovil(3, 'Accesorios para el cabello'),
    CategoriaMovil(4, 'Relojes'),
  ];

  /// Abre la hoja de exportar desde un botón, como en la app.
  Future<void> abrirExportar(
    WidgetTester t,
    double ancho, {
    Future<Map<String, ConteoExportMovil>> Function(int?, String)? contar,
    Future<ArchivoExportMovil> Function(FiltroExportMovil)? exportar,
    Future<String?> Function(ArchivoExportMovil)? abrir,
    void Function()? cerrar,
    int danos = 9,
    int ajustes = 6,
    Set<String> hojasIniciales = const {},
    ValueChanged<Set<String>>? onHojas,
  }) async {
    final porOpcion = contar ??
        (cat, estado) async => {
              'todos': ConteoExportMovil(cat == null ? 248 : 41, 18420500,
                  averias: 3),
              'bajo': ConteoExportMovil(cat == null ? 17 : 9, 312000,
                  averias: 1),
              'agotado': const ConteoExportMovil(6, 0),
            };
    t.view.physicalSize = Size(ancho * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => mostrarExportarMovil(
                  ctx,
                  (c) => ExportarMovil(
                    tienda: 'Consentida Boutique 27',
                    categorias: categoriasExport,
                    hojasIniciales: hojasIniciales,
                    onHojas: onHojas,
                    onContar: (cat, estado) async => ConteosExportMovil(
                        await porOpcion(cat, estado),
                        danos: danos,
                        ajustes: ajustes),
                    onExportar: exportar ??
                        (f) async => const ArchivoExportMovil(
                            nombre: 'inventario_20261125.xlsx',
                            ruta: '/datos/inventario_20261125.xlsx',
                            bytes: 14200),
                    onAbrir: abrir,
                    onCerrar: () {
                      cerrar?.call();
                      c();
                    },
                  ),
                ),
                child: const Text('abrir hoja'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir hoja'));
    await t.pumpAndSettle();
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets('exportar: elegir sin desbordes a ${ancho.toInt()}px',
        (t) async {
      await abrirExportar(t, ancho);
      expect(find.text('Exportar a Excel'), findsOneWidget);
      expect(find.text('248'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.textContaining(r'valor a precio de venta $18.420.500'),
          findsOneWidget);
      expect(find.text('QUÉ HOJAS'), findsOneWidget);
      expect(find.text('Siempre'), findsOneWidget);
      expect(find.text('3 productos con averías'), findsOneWidget);
      expect(find.text('9 movimientos'), findsOneWidget);
      expect(find.textContaining('Excel con 1 hoja'), findsOneWidget);
      expect(unaLinea(t, 'Cancelar'), isTrue);
      expect(unaLinea(t, 'Exportar'), isTrue);
      expect(t.takeException(), isNull);
      await _foto(t, 'exportar_elegir_${ancho.toInt()}.png');
    });
  }

  testWidgets('exportar: los filtros elegidos llegan al servidor y se ve '
      'cada paso', (t) async {
    final conteos = <String>[];
    FiltroExportMovil? pedido;
    final descarga = Completer<ArchivoExportMovil>();
    final abiertos = <String>[];

    await abrirExportar(t, 360,
        contar: (cat, estado) async {
          conteos.add('$cat/$estado');
          return {
            'todos': ConteoExportMovil(cat == null ? 248 : 41, 18420500),
            'bajo': ConteoExportMovil(cat == null ? 17 : 9, 312000),
            'agotado': const ConteoExportMovil(6, 0),
          };
        },
        exportar: (f) {
          pedido = f;
          return descarga.future;
        },
        abrir: (a) async {
          abiertos.add(a.ruta);
          return 'No hay ninguna app para abrir Excel. Instala Excel, '
              'Google Sheets o WPS Office.';
        });

    await t.tap(find.text('Stock bajo'));
    await t.tap(find.text('Bisutería'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Inactivos'));
    await t.tap(find.text('Inactivos'));
    await t.pumpAndSettle();
    expect(conteos, ['null/true', '1/true', '1/false']);
    expect(find.text('9'), findsOneWidget); // bajo en Bisutería
    expect(find.textContaining('9 productos'), findsOneWidget);

    await t.tap(find.text('Exportar'));
    await t.pump(const Duration(milliseconds: 100));
    expect(pedido!.alerta, 'bajo');
    expect(pedido!.categoriaId, 1);
    expect(pedido!.estado, 'false');
    expect(pedido!.hojas, isEmpty); // por defecto solo Inventario
    expect(find.text('Generando el Excel…'), findsOneWidget);
    expect(find.text('Stock bajo · Bisutería · Inactivos'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'exportar_generando_360.png');

    descarga.complete(const ArchivoExportMovil(
        nombre: 'inventario_stock-bajo_bisuteria_inactivos_20261125.xlsx',
        ruta: '/datos/Exportes/inventario_stock-bajo.xlsx',
        bytes: 14200));
    await t.pumpAndSettle();
    expect(find.text('Excel listo'), findsOneWidget);
    expect(find.text('9 productos · 14 KB'), findsOneWidget);
    expect(find.textContaining('compartirlo por WhatsApp'), findsOneWidget);
    expect(unaLinea(t, 'Abrir Excel'), isTrue);
    expect(t.takeException(), isNull);
    await _foto(t, 'exportar_listo_360.png');

    await t.tap(find.text('Abrir Excel'));
    await t.pumpAndSettle();
    expect(abiertos, ['/datos/Exportes/inventario_stock-bajo.xlsx']);
    expect(find.textContaining('No hay ninguna app'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('exportar: si el servidor falla vuelve a elegir con el mensaje',
      (t) async {
    await abrirExportar(t, 360,
        exportar: (_) async => throw Exception('Error al exportar inventario'));
    await t.tap(find.text('Exportar'));
    await t.pumpAndSettle();
    expect(find.text('Error al exportar inventario'), findsOneWidget);
    expect(find.text('QUÉ PRODUCTOS'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('exportar: sin productos en la opción no deja exportar',
      (t) async {
    var exporto = false;
    await abrirExportar(t, 360,
        contar: (_, _) async => {
              'todos': const ConteoExportMovil(5, 100000),
              'bajo': const ConteoExportMovil(0, 0),
              'agotado': const ConteoExportMovil(0, 0),
            },
        exportar: (_) async {
          exporto = true;
          throw Exception('no debía llamarse');
        });
    await t.tap(find.text('Agotados'));
    await t.pumpAndSettle();
    expect(find.text('Nada que exportar'), findsOneWidget);
    await t.tap(find.text('Nada que exportar'));
    await t.pumpAndSettle();
    expect(exporto, isFalse);
    expect(find.textContaining('0 productos · Excel con 1 hoja'), findsOneWidget);
  });

  testWidgets('exportar: una respuesta vieja no pisa la nueva', (t) async {
    final lento = Completer<Map<String, ConteoExportMovil>>();
    await abrirExportar(t, 360, contar: (cat, _) {
      if (cat == 1) return lento.future; // Bisutería tarda
      return Future.value({
        'todos': ConteoExportMovil(cat == null ? 248 : 12, 0),
        'bajo': const ConteoExportMovil(0, 0),
        'agotado': const ConteoExportMovil(0, 0),
      });
    });
    await t.tap(find.text('Bisutería'));
    await t.pump();
    await t.tap(find.text('Bolsos'));
    await t.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);

    lento.complete({
      'todos': const ConteoExportMovil(999, 0),
      'bajo': const ConteoExportMovil(0, 0),
      'agotado': const ConteoExportMovil(0, 0),
    });
    await t.pumpAndSettle();
    expect(find.text('999'), findsNothing);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('exportar: cancelar cierra la hoja', (t) async {
    var cerro = false;
    await abrirExportar(t, 360, cerrar: () => cerro = true);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(cerro, isTrue);
    expect(find.text('Exportar a Excel'), findsNothing);
  });

  testWidgets('exportar: elegir hojas, recordarlas y mandarlas', (t) async {
    final recordadas = <Set<String>>[];
    FiltroExportMovil? pedido;
    await abrirExportar(t, 390,
        ajustes: 0,
        onHojas: recordadas.add,
        exportar: (f) async {
          pedido = f;
          return const ArchivoExportMovil(
              nombre: 'inventario.xlsx', ruta: '/x.xlsx', bytes: 9000);
        });

    // Inventario no se puede quitar.
    await t.ensureVisible(find.text('Inventario'));
    await t.tap(find.text('Inventario'));
    await t.pumpAndSettle();
    expect(recordadas, isEmpty);

    await t.tap(find.text('Averías'));
    await t.pumpAndSettle();
    await t.tap(find.text('Historial de daños'));
    await t.pumpAndSettle();
    expect(recordadas.last, {'averias', 'danos'});
    expect(find.textContaining('Excel con 3 hojas'), findsOneWidget);

    // Sin movimientos: avisa y no la cuenta.
    await t.tap(find.text('Ajustes y transferencias'));
    await t.pumpAndSettle();
    expect(find.text('Sin movimientos · no saldrá en el Excel'),
        findsOneWidget);
    expect(find.textContaining('Excel con 3 hojas'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'exportar_hojas_390.png');

    // Desmarcar quita la hoja.
    await t.tap(find.text('Ajustes y transferencias'));
    await t.pumpAndSettle();
    expect(recordadas.last, {'averias', 'danos'});

    await t.tap(find.text('Exportar'));
    await t.pumpAndSettle();
    expect(pedido!.hojas, {'averias', 'danos'});
  });

  testWidgets('exportar: abre con las hojas que se usaron la última vez',
      (t) async {
    await abrirExportar(t, 360, hojasIniciales: {'ajustes', 'fotos'});
    expect(find.textContaining('Excel con 2 hojas'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('exportar: averías cuenta los productos de la opción elegida',
      (t) async {
    await abrirExportar(t, 360);
    expect(find.text('3 productos con averías'), findsOneWidget);
    await t.tap(find.text('Stock bajo'));
    await t.pumpAndSettle();
    expect(find.text('1 producto con averías'), findsOneWidget);
    await t.tap(find.text('Agotados'));
    await t.pumpAndSettle();
    expect(find.text('Ningún producto con averías'), findsOneWidget);
  });

  // ── Kardex ──────────────────────────────────────────────────

  final hoyK = DateTime(2026, 11, 25, 17);
  List<MovimientoKardexMovil> movsKardex() => [
        MovimientoKardexMovil(tipo: 'salida', referencia: 'venta', cantidad: 2,
            fecha: DateTime(2026, 11, 25, 15, 42), empleado: 'Laura Gómez'),
        MovimientoKardexMovil(tipo: 'dano', referencia: 'devolucion',
            cantidad: 1, fecha: DateTime(2026, 11, 25, 11, 5),
            empleado: 'Laura Gómez',
            observacion: 'Devolución DEV-12 | FAC-00231 → avería'),
        MovimientoKardexMovil(tipo: 'entrada', referencia: 'compra',
            cantidad: 30, fecha: DateTime(2026, 11, 24, 9, 20),
            empleado: 'Admin Boutique'),
        MovimientoKardexMovil(tipo: 'ajuste', referencia: 'manual',
            cantidad: 18, fecha: DateTime(2026, 11, 24, 8, 2),
            empleado: 'Admin Boutique', observacion: 'Conteo físico'),
        MovimientoKardexMovil(tipo: 'transferencia',
            referencia: 'transferencia', cantidad: -4,
            fecha: DateTime(2026, 11, 23, 17, 15), empleado: 'Admin Boutique',
            observacion: 'Transferencia a Consentida Accesorios Unicentro'),
        MovimientoKardexMovil(tipo: 'dano', referencia: 'manual', cantidad: 1,
            fecha: DateTime(2026, 11, 19, 16, 30), empleado: 'Admin Boutique',
            observacion: 'Se cayó de la vitrina'),
        MovimientoKardexMovil(tipo: 'entrada',
            referencia: 'recuperacion_averia', cantidad: 1,
            fecha: DateTime(2026, 11, 19, 14, 10), empleado: 'Admin Boutique',
            observacion: 'Recuperado de averías → stock normal'),
      ];

  Future<void> abrirKardex(
    WidgetTester t,
    double ancho, {
    List<MovimientoKardexMovil>? movs,
    bool cargando = false,
    String? error,
    VoidCallback? reintentar,
    String producto = 'Aretes corazón plata',
  }) async {
    t.view.physicalSize = Size(ancho * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => mostrarKardexMovil(
                    ctx,
                    (_) => KardexMovil(
                          producto: producto,
                          tienda: 'Consentida Boutique 27',
                          stockActual: 24,
                          movimientos: movs ?? movsKardex(),
                          cargando: cargando,
                          error: error,
                          onReintentar: reintentar,
                          ahora: hoyK,
                        )),
                child: const Text('abrir kardex'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir kardex'));
    if (cargando) {
      await t.pump(const Duration(milliseconds: 400));
    } else {
      await t.pumpAndSettle();
    }
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets('kardex sin desbordes a ${ancho.toInt()}px', (t) async {
      await abrirKardex(t, ancho,
          producto: 'Set de anillos ajustables chapados en oro rosa edición '
              'especial');
      expect(find.text('Kardex · Consentida Boutique 27'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      // Entradas: compra 30 + recuperado 1. Salidas: venta 2 + envío 4 +
      // avería manual 1. Averías: 1 por devolución + 1 reportada.
      expect(find.text('+31'), findsOneWidget);
      expect(find.text('−7'), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('AYER'), findsOneWidget);
      expect(find.text('Venta'), findsOneWidget);
      expect(find.text('3:42 p. m. · Laura Gómez'), findsOneWidget);
      expect(find.text('Avería por devolución'), findsOneWidget);
      expect(find.text('=18'), findsOneWidget);
      expect(find.text('QUEDÓ EN'), findsOneWidget);
      expect(find.text('DANO'), findsNothing);
      expect(t.takeException(), isNull);
      await _foto(t, 'kardex_${ancho.toInt()}.png');
    });
  }

  testWidgets('kardex: filtro de averías con su conteo', (t) async {
    await abrirKardex(t, 360);
    await t.tap(find.text('Averías').last); // el chip, no el resumen
    await t.pumpAndSettle();
    expect(find.text('Averías · 3'), findsOneWidget);
    expect(find.text('Avería por devolución'), findsOneWidget);
    expect(find.text('Avería reportada'), findsOneWidget);
    expect(find.text('Recuperado de averías'), findsOneWidget);
    expect(find.text('Venta'), findsNothing);
    expect(find.text('Compra recibida'), findsNothing);
    // La observación automática no se repite.
    expect(find.text('Recuperado de averías → stock normal'), findsNothing);
    expect(t.takeException(), isNull);
    await _foto(t, 'kardex_averias_360.png');

    await t.ensureVisible(find.text('Ajustes'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ajustes'));
    await t.pumpAndSettle();
    expect(find.text('Ajustes · 1'), findsOneWidget);
    expect(find.text('Ajuste manual'), findsOneWidget);
    expect(find.text('Conteo físico'), findsOneWidget);
  });

  testWidgets('kardex: el envío a otra tienda dice a cuál', (t) async {
    await abrirKardex(t, 360);
    await t.drag(find.byType(ListView), const Offset(0, -500));
    await t.pumpAndSettle();
    expect(find.text('Enviado a Consentida Accesorios Unicentro'),
        findsOneWidget);
    expect(find.text('Transferencia a Consentida Accesorios Unicentro'),
        findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('kardex: vacío sin resumen de ceros', (t) async {
    await abrirKardex(t, 360, movs: const []);
    expect(find.text('Sin movimientos todavía'), findsOneWidget);
    expect(find.text('ENTRADAS'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('kardex: cargando', (t) async {
    await abrirKardex(t, 360, cargando: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('ENTRADAS'), findsNothing);
  });

  testWidgets('kardex: error con reintentar', (t) async {
    var reintentos = 0;
    await abrirKardex(t, 360,
        error: 'No se pudo cargar el kardex', reintentar: () => reintentos++);
    expect(find.text('No se pudo cargar el kardex'), findsOneWidget);
    await t.tap(find.text('Reintentar'));
    expect(reintentos, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('kardex con datos reales del servidor', (t) async {
    const ruta =
        r'C:\Users\XzCar\AppData\Local\Temp\claude\160e7d60e6dbc836\a73dd243-0ffc-4b1b-83a6-b47decf936a5\scratchpad\kardex_real.json';
    final f = File(ruta);
    if (!f.existsSync()) return;
    final movs = (jsonDecode(f.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map(MovimientoKardexMovil.fromJson)
        .toList();
    await abrirKardex(t, 360, movs: movs, producto: 'ARETES PLATA');
    expect(find.text('Separado'), findsWidgets);
    expect(t.takeException(), isNull);
    await _foto(t, 'kardex_real_360.png');
  });

  testWidgets('elegir tienda: muestra el stock y devuelve la elegida',
      (t) async {
    t.view.physicalSize = const Size(360 * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    int? elegida;
    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () async {
                  elegida = await mostrarElegirTiendaMovil(ctx,
                      titulo: '¿De qué tienda?',
                      subtitulo: 'El kardex es por tienda. Aretes corazón '
                          'plata está en:',
                      tiendas: const [
                        (TiendaMovil(1, 'Consentida Boutique 27'), 24),
                        (TiendaMovil(2, 'Consentida Accesorios Unicentro'), 9),
                        (TiendaMovil(3, 'Consentida Novacentro'), 0),
                        (TiendaMovil(4, 'Tienda sin el producto'), null),
                      ]);
                },
                child: const Text('elegir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('elegir'));
    await t.pumpAndSettle();
    expect(find.text('¿De qué tienda?'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'kardex_tienda_360.png');

    await t.tap(find.text('Consentida Accesorios Unicentro'));
    await t.pumpAndSettle();
    expect(elegida, 2);
  });

  // ── Ajustar stock ───────────────────────────────────────────

  test('ajuste: enteros por unidad', () {
    expect(problemaAjuste('entrada', 2.5, 24), 'Solo unidades enteras.');
    expect(problemaAjuste('ajuste', 0.5, 24), 'Solo unidades enteras.');
    expect(problemaAjuste('entrada', 2.5, 24, soloEnteros: false), isNull);
    // Lo negativo se avisa primero.
    expect(problemaAjuste('entrada', -0.5, 24), 'La cantidad no puede ser negativa.');
  });

  test('ajuste: qué se puede confirmar y qué no', () {
    expect(problemaAjuste('entrada', 5, 24), isNull);
    expect(problemaAjuste('entrada', 0, 24), 'La cantidad debe ser mayor a cero.');
    expect(problemaAjuste('entrada', null, 24), 'Escribe una cantidad.');
    expect(problemaAjuste('salida', 24, 24), isNull);
    expect(problemaAjuste('salida', 30, 24), 'Solo hay 24 unidades en esta tienda.');
    expect(problemaAjuste('salida', 2, 1), 'Solo hay 1 unidad en esta tienda.');
    expect(problemaAjuste('averia', 1, 0), 'No hay unidades en esta tienda.');
    // El conteo puede dejar el stock en 0, pero no igual al que ya hay.
    expect(problemaAjuste('ajuste', 0, 24), isNull);
    expect(problemaAjuste('ajuste', 24, 24), 'El stock ya está en 24 unidades.');
    expect(problemaAjuste('ajuste', -1, 24), 'La cantidad no puede ser negativa.');
  });

  test('ajuste: el motivo y la nota se guardan juntos', () {
    expect(observacionAjuste('Conteo físico', ''), 'Conteo físico');
    expect(observacionAjuste('Conteo físico', ' revisado con Laura '),
        'Conteo físico · revisado con Laura');
    expect(observacionAjuste('Otro', ''), '');
    expect(observacionAjuste('Otro', 'Para exhibición'), 'Para exhibición');
  });

  Future<void> abrirAjuste(
    WidgetTester t,
    double ancho, {
    String tipo = 'entrada',
    double stock = 24,
    double? averias = 2,
    bool soloEnteros = true,
    Future<String?> Function(String, double, String)? confirmar,
  }) async {
    t.view.physicalSize = Size(ancho * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => mostrarAjusteStockMovil(
                    ctx,
                    (cerrar) => AjusteStockMovil(
                          producto: 'Aretes corazón plata',
                          tienda: 'Consentida Boutique 27',
                          stock: stock,
                          averias: averias,
                          tipoInicial: tipo,
                          soloEnteros: soloEnteros,
                          onCerrar: cerrar,
                          onConfirmar: confirmar ?? (_, _, _) async => null,
                        )),
                child: const Text('abrir ajuste'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir ajuste'));
    await t.pumpAndSettle();
  }

  Future<void> escribir(WidgetTester t, String v) async {
    await t.enterText(find.byType(TextField).first, v);
    await t.pumpAndSettle();
  }

  for (final ancho in [320.0, 390.0]) {
    for (final tipo in tiposAjusteMovil) {
      testWidgets('ajuste $tipo sin desbordes a ${ancho.toInt()}px',
          (t) async {
        await abrirAjuste(t, ancho, tipo: tipo);
        if (tipo == 'ajuste') await escribir(t, '18');
        if (tipo != 'ajuste' && tipo != 'averia') await escribir(t, '5');
        expect(t.takeException(), isNull);
        expect(unaLinea(t, 'Cancelar'), isTrue);
        await _foto(t, 'ajuste_${tipo}_${ancho.toInt()}.png');
      });
    }
  }

  testWidgets('ajuste: entrada con + y −, vista previa y envío', (t) async {
    final enviados = <String>[];
    await abrirAjuste(t, 360, confirmar: (tipo, c, obs) async {
      enviados.add('$tipo|$c|$obs');
      return null;
    });
    expect(find.text('Sumar 1 unidad'), findsOneWidget);
    await t.tap(find.byIcon(Icons.add_rounded).last);
    await t.tap(find.byIcon(Icons.add_rounded).last);
    await t.pumpAndSettle();
    expect(find.text('Sumar 3 unidades'), findsOneWidget);
    expect(find.text('27'), findsOneWidget); // 24 + 3
    await t.tap(find.text('Estaba en bodega'));
    await t.enterText(find.byType(TextField).last, 'caja 4');
    await t.pumpAndSettle();
    await t.tap(find.text('Sumar 3 unidades'));
    await t.pumpAndSettle();
    expect(enviados, ['entrada|3.0|Estaba en bodega · caja 4']);
  });

  testWidgets('ajuste: por unidad no acepta medias unidades', (t) async {
    var enviado = false;
    await abrirAjuste(t, 360, confirmar: (_, _, _) async {
      enviado = true;
      return null;
    });
    for (final v in ['2,5', '2.5', '0,1']) {
      await escribir(t, v);
      expect(find.text('Solo unidades enteras.'), findsOneWidget, reason: v);
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
    }
    expect(enviado, isFalse);
    // "2,0" es un entero escrito con coma: sí vale.
    await escribir(t, '2,0');
    expect(find.text('Solo unidades enteras.'), findsNothing);
  });

  testWidgets('ajuste: un producto por peso o metro sí acepta decimales',
      (t) async {
    await abrirAjuste(t, 360, soloEnteros: false);
    await escribir(t, '2,5');
    expect(find.text('Sumar 2.5 unidades'), findsOneWidget);
    expect(find.text('26.5'), findsOneWidget);
  });

  testWidgets('ajuste: salida de más no deja confirmar', (t) async {
    var enviado = false;
    await abrirAjuste(t, 360, tipo: 'salida', confirmar: (_, _, _) async {
      enviado = true;
      return null;
    });
    await escribir(t, '30');
    expect(find.text('Solo hay 24 unidades en esta tienda.'), findsOneWidget);
    await t.tap(find.text('Sacar 30 unidades'));
    await t.pumpAndSettle();
    expect(enviado, isFalse);
    expect(t.takeException(), isNull);
    await _foto(t, 'ajuste_salida_demas_360.png');
  });

  testWidgets('ajuste: conteo arranca en el stock, deja en 0 y avisa faltantes',
      (t) async {
    final enviados = <String>[];
    await abrirAjuste(t, 360, tipo: 'ajuste', confirmar: (tipo, c, obs) async {
      enviados.add('$tipo|$c|$obs');
      return null;
    });
    expect(find.text('Sin cambios'), findsOneWidget);
    await escribir(t, '18');
    expect(find.text('FALTAN'), findsOneWidget);
    expect(find.text('−6'), findsOneWidget);
    expect(find.text('Dejar en 18 unidades'), findsOneWidget);
    await escribir(t, '30');
    expect(find.text('SOBRAN'), findsOneWidget);
    await escribir(t, '0');
    await t.tap(find.text('Dejar en 0 unidades'));
    await t.pumpAndSettle();
    expect(enviados, ['ajuste|0.0|Conteo físico']);
  });

  testWidgets('ajuste: avería muestra stock y averías', (t) async {
    await abrirAjuste(t, 360, tipo: 'averia');
    expect(find.text('Reportar avería'), findsOneWidget);
    expect(find.text('24 → 23'), findsOneWidget);
    expect(find.text('2 → 3'), findsOneWidget);
    expect(find.text('Reportar 1 avería'), findsOneWidget);
  });

  testWidgets('ajuste: el error del servidor se muestra y la hoja sigue',
      (t) async {
    await abrirAjuste(t, 360, tipo: 'salida',
        confirmar: (_, _, _) async => 'Solo hay 20 unidades en esta tienda.');
    await t.tap(find.text('Sacar 1 unidad'));
    await t.pumpAndSettle();
    expect(find.text('Solo hay 20 unidades en esta tienda.'), findsOneWidget);
    expect(find.text('Ajustar stock'), findsOneWidget);
    // Cambiar la cantidad borra el aviso viejo.
    await escribir(t, '2');
    expect(find.text('Solo hay 20 unidades en esta tienda.'), findsNothing);
  });

  testWidgets('ajuste: cambiar de tipo reinicia cantidad y motivo', (t) async {
    await abrirAjuste(t, 360);
    await escribir(t, '7');
    await t.tap(find.text('Conteo'));
    await t.pumpAndSettle();
    expect(find.text('Conteo físico'), findsOneWidget);
    expect(find.text('Sin cambios'), findsOneWidget); // arranca en 24
    await t.tap(find.text('Salida'));
    await t.pumpAndSettle();
    expect(find.text('Sacar 1 unidad'), findsOneWidget);
    expect(find.text('Uso interno'), findsOneWidget);
  });

  for (final tipo in tiposAjusteMovil) {
    testWidgets('ajuste $tipo: no acepta negativos de ninguna forma',
        (t) async {
      var enviados = 0;
      await abrirAjuste(t, 360, tipo: tipo, confirmar: (_, _, _) async {
        enviados++;
        return null;
      });
      for (final v in ['-5', '−5', '-0,5', '(5)', '- 5']) {
        await escribir(t, v);
        expect(find.text('La cantidad no puede ser negativa.'), findsOneWidget,
            reason: '$tipo "$v"');
        final boton = t.widget<FilledButton>(find.byType(FilledButton));
        expect(boton.onPressed, isNull, reason: '$tipo "$v"');
        await t.tap(find.byType(FilledButton));
        await t.pumpAndSettle();
      }
      expect(enviados, 0);

      // El botón − no baja de 0.
      await escribir(t, '1');
      await t.tap(find.byIcon(Icons.remove_rounded).last);
      await t.pumpAndSettle();
      final campo = t.widget<TextField>(find.byType(TextField).first);
      expect(campo.controller!.text, '0');
      final menos = t.widget<OutlinedButton>(find.ancestor(
          of: find.byIcon(Icons.remove_rounded).last,
          matching: find.byType(OutlinedButton)));
      expect(menos.onPressed, isNull, reason: 'en 0 el − queda apagado');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('ajuste: con stock negativo no deja sacar ni reportar avería',
      (t) async {
    await abrirAjuste(t, 360, tipo: 'salida', stock: -3);
    expect(find.text('No hay unidades en esta tienda.'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    // El conteo sí deja corregirlo.
    await t.tap(find.text('Conteo'));
    await t.pumpAndSettle();
    await escribir(t, '0');
    expect(find.text('SOBRAN'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await _foto(t, 'ajuste_stock_negativo_360.png');
  });

  // ── Transferir ──────────────────────────────────────────────

  test('transferir: qué se puede enviar y qué no', () {
    String? pr(double? c, {double? stock = 24, bool destino = true,
            bool enteros = true}) =>
        problemaTransferencia(cantidad: c, stockOrigen: stock,
            hayDestino: destino, origen: 'Boutique 27', soloEnteros: enteros);
    expect(pr(5), isNull);
    expect(pr(24), isNull);
    expect(pr(25), 'Boutique 27 solo tiene 24 unidades.');
    expect(pr(1, stock: 0), 'Boutique 27 no tiene unidades.');
    expect(pr(0), 'La cantidad debe ser mayor a cero.');
    expect(pr(-3), 'La cantidad no puede ser negativa.');
    expect(pr(2.5), 'Solo unidades enteras.');
    expect(pr(2.5, enteros: false), isNull);
    expect(pr(null), 'Escribe una cantidad.');
    expect(pr(5, stock: null), 'Elige desde qué tienda.');
    expect(pr(5, destino: false), 'Elige a qué tienda.');
  });

  const tiendasT = [
    (TiendaMovil(1, 'Consentida Boutique 27'), 24.0),
    (TiendaMovil(2, 'Consentida Accesorios Unicentro'), 9.0),
    (TiendaMovil(3, 'Consentida Boutique Novacentro'), 0.0),
  ];

  Future<void> abrirTransferir(
    WidgetTester t,
    double ancho, {
    List<(TiendaMovil, double)> tiendas = tiendasT,
    int? origen = 1,
    bool soloEnteros = true,
    Future<String?> Function(int, int, double, String)? confirmar,
  }) async {
    t.view.physicalSize = Size(ancho * 3, 820 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => mostrarTransferirMovil(
                    ctx,
                    (cerrar) => TransferirMovil(
                          producto: 'Aretes corazón plata',
                          tiendas: tiendas,
                          origenFijo: origen,
                          soloEnteros: soloEnteros,
                          onCerrar: cerrar,
                          onConfirmar:
                              confirmar ?? (_, _, _, _) async => null,
                        )),
                child: const Text('abrir transferir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir transferir'));
    await t.pumpAndSettle();
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets('transferir sin desbordes a ${ancho.toInt()}px', (t) async {
      await abrirTransferir(t, ancho);
      expect(find.text('DESDE'), findsOneWidget);
      expect(find.text('HACIA'), findsOneWidget);
      // Con 3 tiendas hay que elegir destino.
      expect(find.text('Elige a qué tienda'), findsOneWidget);
      await t.tap(find.text('Consentida Accesorios Unicentro'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, '5');
      await t.pumpAndSettle();
      expect(find.text('24 → 19'), findsOneWidget);
      expect(find.text('9 → 14'), findsOneWidget);
      expect(unaLinea(t, 'Enviar 5 unidades'), isTrue);
      expect(t.takeException(), isNull);
      await _foto(t, 'transferir_${ancho.toInt()}.png');
    });
  }

  testWidgets('transferir: con 2 tiendas el destino ya viene elegido',
      (t) async {
    await abrirTransferir(t, 360, tiendas: const [
      (TiendaMovil(1, 'Consentida Boutique 27'), 2.0),
      (TiendaMovil(2, 'Consentida Boutique Novacentro'), 20.0),
    ]);
    expect(unaLinea(t, 'Enviar 1 unidad'), isTrue);
    expect(find.text('2 → 1'), findsOneWidget);
    expect(find.text('20 → 21'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'transferir_dos_tiendas_360.png');
  });

  testWidgets('transferir: "Todo", más de lo que hay y envío', (t) async {
    final enviados = <String>[];
    await abrirTransferir(t, 360, confirmar: (o, d, c, nota) async {
      enviados.add('$o→$d|$c|$nota');
      return null;
    });
    await t.tap(find.text('Consentida Accesorios Unicentro'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '30');
    await t.pumpAndSettle();
    expect(find.text('Consentida Boutique 27 solo tiene 24 unidades.'),
        findsOneWidget);
    await t.tap(find.byType(FilledButton));
    await t.pumpAndSettle();
    expect(enviados, isEmpty);
    await _foto(t, 'transferir_demas_360.png');

    await t.tap(find.text('Todo'));
    await t.pumpAndSettle();
    expect(find.text('24 → 0'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'Para la vitrina nueva');
    await t.pumpAndSettle();
    await t.tap(find.byType(FilledButton));
    await t.pumpAndSettle();
    expect(enviados, ['1→2|24.0|Para la vitrina nueva']);
  });

  testWidgets('transferir: no acepta negativos, cero ni medias unidades',
      (t) async {
    var enviados = 0;
    await abrirTransferir(t, 360, confirmar: (_, _, _, _) async {
      enviados++;
      return null;
    });
    await t.tap(find.text('Consentida Accesorios Unicentro'));
    await t.pumpAndSettle();
    for (final (v, msg) in const [
      ('-5', 'La cantidad no puede ser negativa.'),
      ('(2)', 'La cantidad no puede ser negativa.'),
      ('0', 'La cantidad debe ser mayor a cero.'),
      ('2,5', 'Solo unidades enteras.'),
    ]) {
      await t.enterText(find.byType(TextField).first, v);
      await t.pumpAndSettle();
      expect(find.text(msg), findsOneWidget, reason: v);
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
    }
    expect(enviados, 0);
  });

  testWidgets('transferir: en "Todas" se elige el origen y sin stock no se puede',
      (t) async {
    await abrirTransferir(t, 360, origen: null);
    // Arranca en la primera tienda con stock.
    expect(find.text('24 → 23'), findsNothing); // sin destino aún
    expect(find.text('sin stock'), findsOneWidget);
    // Novacentro (sin stock) no se puede elegir como origen.
    await t.tap(find.text('Consentida Boutique Novacentro').first);
    await t.pumpAndSettle();
    // Elegir Unicentro como origen la saca de los destinos.
    await t.tap(find.text('Consentida Accesorios Unicentro').first);
    await t.pumpAndSettle();
    expect(find.text('Consentida Accesorios Unicentro'), findsOneWidget);
    await t.tap(find.text('Consentida Boutique 27').last);
    await t.pumpAndSettle();
    expect(find.text('9 → 8'), findsOneWidget);
    expect(find.text('24 → 25'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'transferir_todas_360.png');
  });

  testWidgets('transferir: el error del servidor se muestra', (t) async {
    await abrirTransferir(t, 360,
        confirmar: (_, _, _, _) async =>
            'Solo el administrador puede hacer esto.');
    await t.tap(find.text('Consentida Accesorios Unicentro'));
    await t.pumpAndSettle();
    await t.tap(find.byType(FilledButton));
    await t.pumpAndSettle();
    expect(find.text('Solo el administrador puede hacer esto.'),
        findsOneWidget);
    expect(find.text('Transferir'), findsOneWidget);
  });

  // ── Filtros ─────────────────────────────────────────────────

  test('filtros: precio con puntos de miles y validaciones', () {
    expect(leerPrecioFiltro('12.500'), 12500); // antes quedaba en 12,5
    expect(leerPrecioFiltro(r'$ 20.000'), 20000);
    expect(leerPrecioFiltro('20000'), 20000);
    expect(leerPrecioFiltro(''), isNull);
    expect(leerPrecioFiltro('abc')!.isNaN, isTrue);
    expect(problemaPrecio(20000, 50000), isNull);
    expect(problemaPrecio(null, 50000), isNull);
    expect(problemaPrecio(80000, 30000), '“Desde” es mayor que “Hasta”.');
    expect(problemaPrecio(-5, null), 'El precio no puede ser negativo.');
    expect(problemaPrecio(double.nan, null),
        'Escribe el precio solo con números.');
    expect(etiquetaPrecio(20000, 50000), r'$20.000 – $50.000');
    expect(etiquetaPrecio(null, 20000), r'Hasta $20.000');
    expect(etiquetaPrecio(50000, null), r'Desde $50.000');
  });

  test('filtros: ordenar sin pedir de nuevo al servidor', () {
    final ps = _productos();
    String nombres(String orden) =>
        ordenarProductos(ps, orden).map((p) => p.id).join(',');
    expect(nombres('stock'), '3,6,2,5,1,4'); // 0, 3, 8, 15, 48, 1240
    expect(nombres('precio_desc'), '4,6,5,3,2,1');
    expect(nombres('precio_asc'), '1,2,3,5,6,4');
    expect(ordenarProductos(ps, 'nombre').first.nombre, 'Aretes Corazón Plata');
    expect(ps.first.id, 1, reason: 'no cambia la lista original');
  });

  Future<void> abrirFiltrosMovil(
    WidgetTester t,
    double ancho, {
    FiltrosInventarioMovil inicial = const FiltrosInventarioMovil(),
    ValueChanged<FiltrosInventarioMovil>? aplicar,
  }) async {
    t.view.physicalSize = Size(ancho * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => mostrarFiltrosMovil(
                    ctx,
                    (cerrar) => FiltrosMovil(
                          inicial: inicial,
                          categorias: const [
                            CategoriaMovil(1, 'Bisutería'),
                            CategoriaMovil(2, 'Bolsos'),
                            CategoriaMovil(3, 'Prendas'),
                            CategoriaMovil(4, 'Relojes'),
                            CategoriaMovil(5, 'Accesorios para el cabello'),
                          ],
                          onCerrar: cerrar,
                          onAplicar: (f) {
                            aplicar?.call(f);
                            cerrar();
                          },
                        )),
                child: const Text('abrir filtros'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir filtros'));
    await t.pumpAndSettle();
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets('filtros sin desbordes a ${ancho.toInt()}px', (t) async {
      await abrirFiltrosMovil(t, ancho,
          inicial: const FiltrosInventarioMovil(
              alerta: 'bajo', categoriaId: 1, precioMin: 20000,
              precioMax: 50000));
      expect(find.text('ESTADO DE STOCK'), findsOneWidget);
      expect(find.text('20.000'), findsOneWidget); // con puntos de miles
      expect(unaLinea(t, 'Ver resultados'), isTrue);
      expect(unaLinea(t, 'Cancelar'), isTrue);
      expect(t.takeException(), isNull);
      await _foto(t, 'filtros_${ancho.toInt()}.png');
    });
  }

  testWidgets('filtros: elegir y aplicar', (t) async {
    FiltrosInventarioMovil? r;
    await abrirFiltrosMovil(t, 390, aplicar: (f) => r = f);
    await t.tap(find.text('Agotados'));
    await t.tap(find.text('Bolsos'));
    await t.tap(find.text(r'$20.000 – $50.000'));
    await t.pumpAndSettle();
    expect(find.text('20.000'), findsOneWidget);
    expect(find.text('50.000'), findsOneWidget);
    await t.ensureVisible(find.text('Menos stock'));
    await t.tap(find.text('Menos stock'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ver resultados'));
    await t.pumpAndSettle();
    expect(r!.alerta, 'agotado');
    expect(r!.categoriaId, 2);
    expect(r!.categoriaNombre, 'Bolsos');
    expect(r!.precioMin, 20000);
    expect(r!.precioMax, 50000);
    expect(r!.orden, 'stock');
  });

  testWidgets('filtros: "12.500" escrito a mano es doce mil quinientos',
      (t) async {
    FiltrosInventarioMovil? r;
    await abrirFiltrosMovil(t, 360, aplicar: (f) => r = f);
    await t.enterText(find.byType(TextField).first, '12.500');
    await t.pumpAndSettle();
    await t.tap(find.text('Ver resultados'));
    await t.pumpAndSettle();
    expect(r!.precioMin, 12500);
    expect(r!.precioMax, isNull);
  });

  testWidgets('filtros: rango al revés no deja aplicar', (t) async {
    var aplicado = false;
    await abrirFiltrosMovil(t, 360, aplicar: (_) => aplicado = true);
    await t.enterText(find.byType(TextField).first, '80.000');
    await t.enterText(find.byType(TextField).last, '30.000');
    await t.pumpAndSettle();
    expect(find.text('“Desde” es mayor que “Hasta”.'), findsOneWidget);
    await t.tap(find.text('Ver resultados'));
    await t.pumpAndSettle();
    expect(aplicado, isFalse);
    expect(t.takeException(), isNull);
    await _foto(t, 'filtros_rango_mal_360.png');
  });

  testWidgets('filtros: limpiar todo deja todo en cero', (t) async {
    FiltrosInventarioMovil? r;
    await abrirFiltrosMovil(t, 360,
        inicial: const FiltrosInventarioMovil(
            alerta: 'bajo', categoriaId: 1, precioMin: 1000, orden: 'stock'),
        aplicar: (f) => r = f);
    await t.tap(find.text('Limpiar todo'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ver resultados'));
    await t.pumpAndSettle();
    expect(r!.alerta, isNull);
    expect(r!.categoriaId, isNull);
    expect(r!.precioMin, isNull);
    expect(r!.orden, 'nombre');
  });

  testWidgets('lista: filtros aplicados a la vista y se quitan uno a uno',
      (t) async {
    final quitados = <String>[];
    t.view.physicalSize = const Size(360 * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await t.pumpWidget(RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: InventarioMovil(
            subtitulo: 'Consentida Boutique 27',
            tiendas: const [],
            tiendaSeleccionada: 1,
            onTienda: (_) {},
            kpis: const [],
            agotados: 0,
            bajos: 0,
            buscar: ctrl,
            onBuscar: (_) {},
            filtrosActivos: 3,
            onFiltros: () {},
            filtrosAplicados: [
              FiltroActivoMovil('Stock bajo', () => quitados.add('alerta')),
              FiltroActivoMovil('Bisutería', () => quitados.add('categoria')),
              FiltroActivoMovil(r'$20.000 – $50.000',
                  () => quitados.add('precio')),
              FiltroActivoMovil('Menos stock', () => quitados.add('orden')),
            ],
            onLimpiarFiltros: () => quitados.add('todo'),
            onEscanear: () {},
            estado: 'true',
            onEstado: (_) {},
            productos: ordenarProductos(
                _productos().where((p) => p.id == 2 || p.id == 5).toList(),
                'stock'),
            onProducto: (_) {},
            iconoInsights: Icons.insights_rounded,
            accionesFab: const [],
            accionesMas: const [],
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('2 resultados'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _foto(t, 'filtros_activos_360.png');
    await t.tap(find.text('Bisutería'));
    await t.tap(find.text('Limpiar'));
    expect(quitados, ['categoria', 'todo']);
  });
}
