// Separados en el celular: reglas y pantallas con capturas.
//
// Con --dart-define=SHOT_DIR=<carpeta> guarda capturas PNG.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/models/alerta_separado.dart';
import 'package:pos_multitienda_app/models/cliente.dart';
import 'package:pos_multitienda_app/models/cuenta_bancaria.dart';
import 'package:pos_multitienda_app/models/pago_abono.dart';
import 'package:pos_multitienda_app/models/producto.dart';
import 'package:pos_multitienda_app/models/separado.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/inventario_movil.dart';
import 'package:pos_multitienda_app/screens/separados/movil/hojas_separado_movil.dart';
import 'package:pos_multitienda_app/screens/separados/movil/nuevo_separado_movil.dart';
import 'package:pos_multitienda_app/screens/separados/movil/recordatorios_movil.dart';
import 'package:pos_multitienda_app/screens/separados/movil/separado_detalle_movil.dart';
import 'package:pos_multitienda_app/screens/separados/movil/separados_movil.dart';
import 'package:pos_multitienda_app/screens/separados/movil/separados_reglas.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _iconos =
    r'C:\dev\flutter_windows_3.35.4-stable\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
final _marco = GlobalKey();
final _hoy = DateTime(2026, 11, 28, 11);

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
  // El marco envuelve todo el navegador: así las hojas salen en la captura.
  await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false,
      builder: (_, hijo) => RepaintBoundary(key: _marco, child: hijo), home: w));
  await t.pump();
}

/// Abre una hoja desde un botón y devuelve lo que retorna.
Future<void> _conHoja<T>(WidgetTester t, Widget hoja, void Function(T?) alCerrar, {double alto = 844}) async {
  await _montar(t, Scaffold(body: Builder(builder: (ctx) => Center(child: TextButton(
    onPressed: () async => alCerrar(await abrirHojaSep<T>(ctx, hoja)),
    child: const Text('abrir'),
  )))), alto: alto);
  await t.tap(find.text('abrir'));
  await t.pumpAndSettle();
}

// ── Datos de ejemplo ───────────────────────────────────────

DetalleSeparado _d(int id, String n, double c, double p, {int prod = 0}) => DetalleSeparado(
    id: id, producto: prod == 0 ? id : prod, productoNombre: n, cantidad: c, precioUnitario: p, subtotal: c * p);

AbonoSeparado _a(int id, double m, String met, DateTime f, {String? cuenta, String quien = 'Leidy Estrada'}) =>
    AbonoSeparado(id: id, separado: 0, empleadoNombre: quien, monto: m, metodoPago: met, createdAt: f,
        cuentaNombre: cuenta);

Separado _sep(int id, String cliente, List<DetalleSeparado> det, double abonado,
    {String estado = 'activo', String? limite, DateTime? creado, List<AbonoSeparado> abonos = const [],
     DateTime? entregado, String? bono, double? bonoSaldo, String motivo = ''}) {
  final total = det.fold<double>(0, (s, x) => s + x.subtotal);
  return Separado(
    id: id, tienda: 1, tiendaNombre: 'Boutique 27', cliente: id, clienteNombre: cliente,
    clienteCedulaNit: '1.085.221.447', clienteTelefono: '3117374019', empleadoNombre: 'Leidy Estrada',
    total: total, abonoAcumulado: abonado, saldoPendiente: estado == 'activo' ? total - abonado : 0,
    fechaLimite: limite, estado: estado, createdAt: creado ?? DateTime(2026, 11, 9, 10, 12),
    detalles: det, abonos: abonos, entregadoAt: entregado, entregadoPorNombre: entregado == null ? null : 'Karen Ortiz',
    bonoCodigo: bono, bonoSaldo: bonoSaldo, bonoEstado: bono == null ? null : 'activo',
    bonoVence: bono == null ? null : '2027-11-28', motivoCancelacion: motivo,
  );
}

final _emma = _sep(123, 'Emma Castillo', [_d(1, 'Bolso Lía café', 1, 120000), _d(2, 'Aretes perla', 2, 15000)], 77100,
    limite: '2026-11-24', abonos: [
      _a(1, 40000, 'efectivo', DateTime(2026, 11, 9, 10, 12)),
      _a(2, 20000, 'transferencia', DateTime(2026, 11, 16, 16, 40), cuenta: 'Nequi'),
      _a(3, 17100, 'efectivo', DateTime(2026, 11, 21, 11, 5), quien: 'Karen Ortiz'),
    ]);

List<Separado> _lista() => [
      _emma,
      _sep(131, 'Julia Rosero', [_d(3, 'Billetera Nova negra', 1, 58000)], 45000, limite: '2026-11-30'),
      _sep(140, 'Aida Sánchez', [_d(4, 'Correa café', 1, 54000), _d(5, 'Gafas sol', 1, 70000)], 124000,
          estado: 'pagado', limite: '2026-12-02',
          abonos: [_a(4, 124000, 'efectivo', DateTime(2026, 11, 27, 17, 10))]),
      _sep(142, 'Sara Chamorro', [_d(6, 'Bolso Mia beige', 1, 189000)], 40000, limite: '2026-12-18'),
      _sep(101, 'Lucía Erazo', [_d(7, 'Gafas sol', 1, 70000)], 70000, estado: 'pagado',
          entregado: DateTime(2026, 11, 20, 15)),
      _sep(99, 'Marta Bravo', [_d(8, 'Bolso Mini rosa', 1, 69000)], 30000, estado: 'cancelado',
          bono: 'BON-7IQ4VB', bonoSaldo: 30000),
    ];

Producto _prod(int id, String n, double p, double stock) =>
    Producto(id: id, nombre: n, precio: p, categoria: 'Bolsos', stockActual: stock);

final _cuentas = [
  CuentaBancaria(id: 1, nombre: 'Nequi', tipo: 'nequi', tipoDisplay: 'Nequi', numero: '300', activo: true, orden: 0),
  CuentaBancaria(id: 2, nombre: 'Bancolombia', tipo: 'ahorros', tipoDisplay: 'Ahorros', numero: '1', activo: true, orden: 1),
];

AccionesDetalleSep _accionesVacias({VoidCallback? cancelar, VoidCallback? entregar, ValueChanged<DetalleSeparado>? cambiar}) =>
    AccionesDetalleSep(onLlamar: () {}, onWhatsApp: () {}, onImprimir: () {}, onAbonar: () {},
        onCancelar: cancelar, onCambiar: cambiar, onEntregar: entregar, onEnviarBono: () {}, onImprimirBono: () {});

void main() {
  setUpAll(_fuentes);

  group('reglas', () {
    test('estado de cada separado', () {
      final l = _lista();
      expect(estadoSep(l[0], _hoy).texto, 'Vencido hace 4 días');
      expect(estadoSep(l[1], _hoy).texto, 'Vence en 2 días');
      expect(estadoSep(l[2], _hoy).texto, 'Por entregar');
      expect(estadoSep(l[3], _hoy).texto, 'Al día');
      expect(estadoSep(l[4], _hoy).texto, 'Entregado');
      expect(estadoSep(l[5], _hoy).texto, 'Cancelado · bono');
    });

    test('filtros y orden (lo más urgente primero)', () {
      final l = _lista();
      expect(sepsVisibles(l, FiltroSep.activos, '', _hoy).map((s) => s.id), [123, 131, 142]);
      expect(sepsVisibles(l, FiltroSep.vencidos, '', _hoy).map((s) => s.id), [123]);
      expect(sepsVisibles(l, FiltroSep.porVencer, '', _hoy).map((s) => s.id), [131]);
      expect(sepsVisibles(l, FiltroSep.porEntregar, '', _hoy).map((s) => s.id), [140]);
      expect(sepsVisibles(l, FiltroSep.pagados, '', _hoy).map((s) => s.id), [101]);
      expect(sepsVisibles(l, FiltroSep.cancelados, '', _hoy).map((s) => s.id), [99]);
      expect(sepsVisibles(l, FiltroSep.activos, 'SEP-142', _hoy).map((s) => s.id), [142]);
      expect(sepsVisibles(l, FiltroSep.activos, 'aretes', _hoy).map((s) => s.id), [123]);
    });

    test('resumen y alerta', () {
      final r = resumirSeps(_lista(), _hoy);
      expect(r.activos, 3);
      expect(r.porCobrar, 72900 + 13000 + 149000);
      expect(r.vencidos, 1);
      expect(r.saldoVencido, 72900);
      expect(r.porEntregar, 1);
      expect(textoAlerta(r), '1 vencido y 1 vence en 3 días o menos.');
    });

    test('abono: montos rápidos y validaciones', () {
      expect(montosRapidos(72900).map((x) => x.$2), [72900, 37000, 20000, 50000]);
      const p = PagoAbono(metodoPago: 'efectivo', monto: 80000);
      expect(problemaAbono([p], 72900), startsWith('Es más'));
      expect(problemaAbono([const PagoAbono(metodoPago: 'efectivo', monto: 1000)], 72900, cajaAbierta: false),
          startsWith('No hay caja abierta'));
      expect(problemaAbono([const PagoAbono(metodoPago: 'transferencia', monto: 1000)], 72900, cuentasDe: (_) => 2),
          '¿A qué cuenta entró? Elige una.');
      expect(problemaAbono([const PagoAbono(metodoPago: 'transferencia', monto: 1000, cuentaId: 1)], 72900,
          cajaAbierta: false, cuentasDe: (_) => 2), isNull);
    });

    test('cambio: no por menos de lo abonado; igual queda pagado', () {
      final viejo = _emma.detalles.first; // 120.000, total 150.000, abonó 77.100
      final caro = cambioSep(_emma, viejo, 142000, 1);
      expect(caro.totalDespues, 172000);
      expect(caro.faltaDespues, 94900);
      expect(caro.permitido, isTrue);
      expect(cambioSep(_emma, viejo, 40000, 1).permitido, isFalse); // 70.000 < 77.100
      final justo = cambioSep(_emma, viejo, 47100, 1); // 77.100
      expect(justo.quedaPagado, isTrue);
    });

    test('nuevo: plazos, abono inicial y validaciones', () {
      expect(fechaPlazo(_hoy, 30), DateTime(2026, 12, 28));
      expect(fechaLarga(DateTime(2026, 12, 28)), 'lunes 28 de diciembre');
      expect(abonosIniciales(237000).map((x) => x.$2), [47400, 50000, 100000, 237000]);
      expect(problemaNuevo(3, fecha: _hoy, abono: 0, total: 100, hoy: _hoy), 'El abono inicial es obligatorio.');
      expect(problemaNuevo(3, fecha: _hoy, abono: 50, total: 100, hoy: _hoy, cajaAbierta: false),
          startsWith('No hay caja abierta'));
      expect(problemaNuevo(3, fecha: _hoy, abono: 50, total: 100, hoy: _hoy, metodo: 'transferencia',
          cajaAbierta: false), isNull);
    });

    test('mensajes', () {
      expect(mensajeBono(_lista()[5], 'Consentida'),
          'Hola Marta, cancelamos tu separado SEP-99. Los \$30.000 que abonaste quedan a tu favor en el bono '
          'BON-7IQ4VB, válido hasta el 28 nov 2027 en Consentida. Muéstralo al pagar tu próxima compra. ¡Te esperamos!');
    });
  });

  group('pantallas', () {
    testWidgets('lista', (t) async {
      FiltroSep? filtro;
      Separado? abierto;
      var recordar = 0;
      await _montar(t, Scaffold(body: SeparadosMovil(
        buscador: TextEditingController(),
        datos: DatosSepsMovil(separados: _lista(), hoy: _hoy, tiendaNombre: 'Boutique 27', abonosHoy: 210000, nAbonosHoy: 5),
        acciones: AccionesSepsMovil(onFiltro: (f) => filtro = f, onBuscar: (_) {}, onAbrir: (s) => abierto = s,
            onNuevo: () {}, onEscanear: () {}, onRecordar: () => recordar++, onAbonosHoy: () {},
            onRefrescar: () async {}),
      )));
      expect(find.text('SEP-123'), findsOneWidget);
      expect(find.text('Vencido hace 4 días'), findsOneWidget);
      expect(find.text('SEP-140'), findsNothing); // por entregar no está en Activos
      await _foto(t, 'sep_1_lista.png');
      await t.tap(find.textContaining('Mándales'));
      expect(recordar, 1);
      await t.tap(find.textContaining('Por entregar', findRichText: true).last);
      expect(filtro, FiltroSep.porEntregar);
      await t.tap(find.text('Emma Castillo'));
      expect(abierto?.id, 123);
    });

    testWidgets('lista angosta (320)', (t) async {
      await _montar(t, Scaffold(body: SeparadosMovil(
        buscador: TextEditingController(),
        datos: DatosSepsMovil(separados: _lista(), hoy: _hoy, tiendaNombre: 'Consentida Boutique 27'),
        acciones: AccionesSepsMovil(onFiltro: (_) {}, onBuscar: (_) {}, onAbrir: (_) {}, onNuevo: () {},
            onEscanear: () {}, onRecordar: () {}, onAbonosHoy: () {}, onRefrescar: () async {}),
      )), ancho: 320);
      expect(t.takeException(), isNull);
      await _foto(t, 'sep_1b_lista_320.png');
    });

    testWidgets('detalle activo', (t) async {
      DetalleSeparado? cambiar;
      var cancelar = 0;
      await _montar(t, SeparadoDetalleMovil(sep: _emma, hoy: _hoy,
          acciones: _accionesVacias(cancelar: () => cancelar++, cambiar: (d) => cambiar = d)));
      expect(find.text('Le falta'), findsOneWidget);
      expect(find.text('\$72.900'), findsOneWidget);
      expect(find.text('Venció el 24 nov · hace 4 días'), findsOneWidget);
      expect(find.text('Transferencia · Nequi'), findsOneWidget);
      await _foto(t, 'sep_2_detalle.png');
      await t.tap(find.byTooltip('Cambiar Bolso Lía café'));
      expect(cambiar?.productoNombre, 'Bolso Lía café');
      await t.tap(find.byTooltip('Cancelar separado'));
      expect(cancelar, 1);
    });

    testWidgets('detalle sin permiso de cancelar ni cambiar', (t) async {
      await _montar(t, SeparadoDetalleMovil(sep: _emma, hoy: _hoy, acciones: _accionesVacias()));
      expect(find.byTooltip('Cancelar separado'), findsNothing);
      expect(find.byTooltip('Cambiar Bolso Lía café'), findsNothing);
    });

    testWidgets('por entregar y entregado', (t) async {
      var entregar = 0;
      await _montar(t, SeparadoDetalleMovil(sep: _lista()[2], hoy: _hoy,
          acciones: _accionesVacias(entregar: () => entregar++)));
      expect(find.text('Pagado completo · falta que lo recoja'), findsOneWidget);
      await _foto(t, 'sep_3_por_entregar.png');
      await t.tap(find.text('Marcar entregado'));
      expect(entregar, 1);
      await _montar(t, SeparadoDetalleMovil(sep: _lista()[4], hoy: _hoy, acciones: _accionesVacias()));
      expect(find.text('Lo entregó Karen Ortiz'), findsOneWidget);
      expect(find.text('Marcar entregado'), findsNothing);
    });

    testWidgets('cancelado con bono', (t) async {
      final s = _sep(123, 'Emma Castillo', _emma.detalles, 77100, estado: 'cancelado', bono: 'BON-7IQ4VB',
          bonoSaldo: 77100, motivo: 'ya no lo quiere', abonos: _emma.abonos);
      await _montar(t, SeparadoDetalleMovil(sep: s, hoy: _hoy, acciones: _accionesVacias()));
      expect(find.text('BON-7IQ4VB'), findsOneWidget);
      expect(find.text('Saldo a favor de Emma Castillo'), findsOneWidget);
      expect(find.text('Enviárselo'), findsOneWidget);
      expect(find.text('Motivo: ya no lo quiere'), findsOneWidget);
      await _foto(t, 'sep_4_cancelado.png');
    });

    testWidgets('hoja abonar: rápido, dos métodos y cuenta', (t) async {
      ResultadoAbono? r;
      await _conHoja<ResultadoAbono>(t, HojaAbonarSep(sep: _emma, cuentas: _cuentas, cajaAbierta: true), (x) => r = x);
      await t.tap(find.text('Mitad'));
      await t.pump();
      await t.tap(find.text('Pagar una parte con otro método'));
      await t.pumpAndSettle();
      expect(find.text('PARTE 2'), findsOneWidget);
      await t.tap(find.text('Nequi'));
      await t.pumpAndSettle();
      await _foto(t, 'sep_5_abonar.png');
      await t.tap(find.text('Registrar abono e imprimir'));
      await t.pumpAndSettle();
      expect(r!.pagos.map((p) => (p.metodoPago, p.monto, p.cuentaId)),
          [('efectivo', 37000.0, null), ('transferencia', 35900.0, 1)]);
      expect(r!.imprimir, isTrue);
    });

    testWidgets('hoja abonar sin caja: no deja efectivo', (t) async {
      ResultadoAbono? r;
      await _conHoja<ResultadoAbono>(t, HojaAbonarSep(sep: _emma, cuentas: _cuentas, cajaAbierta: false), (x) => r = x);
      expect(find.text('sin caja'), findsOneWidget);
      await t.tap(find.text('\$20.000'));
      await t.pump();
      await t.tap(find.text('Registrar abono e imprimir'));
      await t.pump();
      expect(find.text('¿A qué cuenta entró? Elige una.'), findsOneWidget);
      expect(r, isNull);
    });

    testWidgets('hoja cambiar: los más baratos no se pueden', (t) async {
      ResultadoCambio? r;
      final negro = _prod(30, 'Bolso Lía negro', 142000, 3);
      final mini = _prod(31, 'Bolso Mini rosa', 40000, 5);
      await _conHoja<ResultadoCambio>(t, HojaCambiarSep(sep: _emma, detalle: _emma.detalles.first,
          buscar: (_) async => [negro, mini], escanear: (_) async => null), (x) => r = x);
      await t.enterText(find.byType(TextField), 'bolso');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.text('\$40.000 · vale menos de lo que ya abonó'), findsOneWidget);
      await t.tap(find.text('Bolso Mini rosa'));
      await t.pumpAndSettle();
      expect(find.text('Confirmar cambio'), findsOneWidget);
      await t.tap(find.text('Bolso Lía negro'));
      await t.pumpAndSettle();
      expect(find.text('\$72.900 → \$94.900'), findsOneWidget);
      await _foto(t, 'sep_6_cambiar.png');
      await t.tap(find.text('Confirmar cambio'));
      await t.pumpAndSettle();
      expect(r?.producto.id, 30);
      expect(r?.cantidad, 1);
    });

    testWidgets('hoja cancelar', (t) async {
      ResultadoCancelar? r;
      await _conHoja<ResultadoCancelar>(t, HojaCancelarSep(sep: _emma), (x) => r = x);
      expect(find.textContaining('a su favor', findRichText: true), findsOneWidget);
      await t.enterText(find.byType(TextField), 'ya no lo quiere');
      await t.pumpAndSettle();
      await _foto(t, 'sep_7_cancelar.png');
      await t.tap(find.text('Sí, cancelar y crear bono'));
      await t.pumpAndSettle();
      expect(r?.motivo, 'ya no lo quiere');
    });

    testWidgets('nuevo separado: cliente → productos → fecha y abono', (t) async {
      PedidoSeparado? pedido;
      final sara = Cliente(id: 7, nombre: 'Sara', apellido: 'Chamorro', cedulaNit: '1085993120', telefono: '3152204471',
          email: '', direccion: '', activo: true, createdAt: _hoy,
          saldos: const SaldosCliente(separadosActivos: 1));
      final mia = _prod(40, 'Bolso Mia beige', 189000, 2);
      final nova = _prod(41, 'Billetera Nova café', 48000, 6);
      await _montar(t, NuevoSeparadoMovil(
        hoy: _hoy, cuentas: _cuentas, cajaAbierta: true,
        servicios: ServiciosNuevoSep(
          buscarClientes: (_) async => [sara],
          crearCliente: (_) async => null,
          buscarProductos: (q) async => q == '770' ? [nova] : [mia, nova],
          escanear: (_) async => '770',
          crear: (p) async {
            pedido = p;
            return null;
          },
        ),
      ));
      await t.enterText(find.byType(TextField), 'sar');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await _foto(t, 'sep_8_nuevo_cliente.png');
      await t.tap(find.text('Sara Chamorro'));
      await t.pumpAndSettle();
      await t.tap(find.text('Siguiente'));
      await t.pump();
      expect(find.text('Agrega al menos un producto.'), findsOneWidget);
      await t.tap(find.text('Escanear'));
      await t.pumpAndSettle();
      await t.tap(find.text('Buscar'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'bolso');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await t.tap(find.text('Bolso Mia beige'));
      await t.pumpAndSettle();
      expect(find.text('\$237.000'), findsOneWidget);
      await _foto(t, 'sep_9_nuevo_productos.png');
      await t.tap(find.text('Siguiente'));
      await t.pumpAndSettle();
      expect(find.textContaining('lunes 28 de diciembre', findRichText: true), findsOneWidget);
      await t.tap(find.text('Crear separado e imprimir'));
      await t.pump();
      expect(find.text('El abono inicial es obligatorio.'), findsOneWidget);
      await t.tap(find.text('\$50.000'));
      await t.pumpAndSettle();
      await _foto(t, 'sep_10_nuevo_fecha.png');
      await t.tap(find.text('Crear separado e imprimir'));
      await t.pumpAndSettle();
      expect(pedido, isNotNull);
      final d = pedido!.datos(1);
      expect(d['cliente'], 7);
      expect(d['fecha_limite'], '2026-12-28');
      expect(d['abono_inicial'], 50000);
      expect(d['metodo_pago'], 'efectivo');
      expect((d['detalles'] as List).map((x) => x['producto']), [41, 40]);
    });

    testWidgets('recordatorios', (t) async {
      List<int>? enviados;
      await _montar(t, RecordatoriosMovil(
        alertas: [
          AlertaSeparado(id: 123, cliente: 'Emma Castillo', tienda: 'Boutique 27', saldoPendiente: 72900,
              fechaLimite: '2026-11-24', diasRestantes: -4, telefono: '3117374019'),
          AlertaSeparado(id: 131, cliente: 'Julia Rosero', tienda: 'Boutique 27', saldoPendiente: 13000,
              fechaLimite: '2026-11-30', diasRestantes: 2, telefono: '3001112233'),
          AlertaSeparado(id: 135, cliente: 'Diana Pantoja', tienda: 'Boutique 27', saldoPendiente: 40000,
              fechaLimite: '2026-11-29', diasRestantes: 1),
        ],
        enviar: (ids) async {
          enviados = ids;
          return 'Enviados: 2';
        },
      ));
      expect(find.text('Enviar a 2 clientes'), findsOneWidget);
      expect(find.text('SEP-135 · sin celular'), findsOneWidget);
      await _foto(t, 'sep_11_recordatorios.png');
      await t.tap(find.text('Julia Rosero'));
      await t.pump();
      await t.tap(find.text('Enviar a 1 cliente'));
      await t.pumpAndSettle();
      expect(enviados, [123]);
    });
  });
}
