// Nómina: pantallas (computador y celular) y formularios.
//
// Con --dart-define=SHOT_DIR=<carpeta> guarda capturas PNG.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/models/cuenta_bancaria.dart';
import 'package:pos_multitienda_app/screens/gastos/gastos_formularios.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/inventario_movil.dart';
import 'package:pos_multitienda_app/screens/nomina/nomina_formularios.dart';
import 'package:pos_multitienda_app/screens/nomina/nomina_screen.dart';
import 'package:pos_multitienda_app/services/nomina_service.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _iconos =
    r'C:\dev\flutter_windows_3.35.4-stable\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
final _marco = GlobalKey();

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

Future<void> _montar(WidgetTester t, Widget w) async {
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(key: _marco, child: Scaffold(body: w)),
  ));
  await t.pump();
}

const sm = 1750905, aux = 249095;

FilaQuincena _fila(int id, String n, String tipo, double dia, double dias,
    {bool minimo = false, int danos = 0, List<PagoNomina> pagos = const [], bool guardada = true}) {
  final c = calcularFila(tipo: tipo, valorDia: dia, dias: dias, ganaMinimo: minimo,
      salarioMinimo: sm, auxilioTransporte: aux, danos: danos);
  return FilaQuincena(id: guardada ? id : null, trabajador: id, nombres: n, cedula: '108823456$id',
      cargo: tipo == 'nomina' ? 'Asesora de ventas' : 'Apoyo', tipo: tipo,
      valorDia: minimo ? 58363.5 : dia, dias: guardada ? dias : 0, ganaMinimo: minimo,
      guardada: guardada, comprobante: guardada ? 8 + id : null, calculo: guardada ? c : const CalculoFila(),
      pagos: pagos);
}

QuincenaNomina _q() => QuincenaNomina(
      id: 1, tienda: 1, anio: 2026, mes: 11, numero: 2, salarioMinimo: sm, auxilioTransporte: aux,
      tiendaNombre: 'Consentida Accesorios', periodo: periodoQuincena(2026, 11, 2), empleador: 'Carlos Velasco',
      filas: [
        _fila(1, 'Laura Gómez Ruiz', 'nomina', 0, 15, minimo: true, pagos: [
          PagoNomina(id: 1, valor: 930000, fecha: DateTime(2026, 11, 30), metodoPago: 'transferencia',
              cuentaNombre: 'Bancolombia')]),
        _fila(2, 'Daniela Paz Ortiz', 'nomina', 63000, 13, danos: 20000, pagos: [
          PagoNomina(id: 2, valor: 500000, fecha: DateTime(2026, 11, 30))]),
        _fila(3, 'Pedro Ruiz Cano', 'temporal', 55000, 12),
        _fila(4, 'Sofía Lara Muñoz', 'temporal', 55000, 0, guardada: false),
      ],
    );

DatosNomina _datos({String vista = 'quincena', List<FilaEditable>? filas, MesNomina? mes,
        List<Trabajador> personas = const []}) =>
    DatosNomina(
      tiendas: const [TiendaOpcion(1, 'Consentida Accesorios'), TiendaOpcion(2, 'Boutique 27')],
      tienda: 1, anio: 2026, mes: 11, numero: 2, vista: vista, quincena: _q(),
      filas: filas ?? [for (final f in _q().filas) FilaEditable(f)], mesDatos: mes, personas: personas,
    );

AccionesNomina _acciones(List<String> log, {VoidCallback? cambio}) => AccionesNomina(
      onTienda: (t) => log.add('tienda $t'),
      onVista: (v) => log.add('vista $v'),
      onNumero: (n) => log.add('numero $n'),
      onMoverQuincena: (d) => log.add('q $d'),
      onMoverMes: (d) => log.add('m $d'),
      onCambio: cambio ?? () => log.add('cambio'),
      onGuardar: () => log.add('guardar'),
      onEmpleador: () => log.add('empleador'),
      onPagar: (f) => log.add('pagar ${f.nombres}'),
      onVerPagos: (f) => log.add('pagos ${f.nombres}'),
      onDesprendible: (f) => log.add('pdf ${f.nombres}'),
      onPlanilla: () => log.add('planilla'),
      onDesprendibles: () => log.add('desprendibles'),
      onPlanillaMes: () => log.add('planilla mes'),
      onValores: () => log.add('valores'),
      onNuevaPersona: () => log.add('nueva'),
      onPersona: (p) => log.add('persona ${p.nombres}'),
      onEstadoPersonas: (e) => log.add('estado $e'),
      onRefrescar: () async {},
    );

MesNomina _mes() => MesNomina.fromJson({
      'anio': 2026, 'mes': 11,
      'valores': {'anio': 2026, 'salario_minimo': sm, 'auxilio_transporte': aux, 'arl_pct': 0.522,
                  'exonerado': true, 'redondear_mil': true, 'guardado': true},
      'personas': [
        {'trabajador': 1, 'nombres': 'Laura Gómez Ruiz', 'tipo': 'nomina', 'q1': {'pagar': 930000},
         'q2': {'pagar': 930000}, 'dias': 30, 'sueldo': 1750904, 'auxilio': 249094, 'salud': 70036,
         'pension': 70036, 'danos': 0, 'adelantos': 0, 'neto': 1859926, 'pagar': 1860000, 'pagado': 1860000,
         'costo': 2715495 + 74, 'costo_detalle': {'pension': 210108, 'salud': 0, 'arl': 9140, 'caja': 70036,
           'icbf': 0, 'sena': 0, 'prima': 166600, 'cesantias': 166600, 'intereses': 20000, 'vacaciones': 73013,
           'aportes': 289284, 'provisiones': 426213}},
        {'trabajador': 3, 'nombres': 'Pedro Ruiz Cano', 'tipo': 'temporal', 'q1': {'pagar': 770000},
         'q2': {'pagar': 660000}, 'dias': 26, 'sueldo': 1430000, 'auxilio': 0, 'salud': 0, 'pension': 0,
         'danos': 0, 'adelantos': 0, 'neto': 1430000, 'pagar': 1430000, 'pagado': 1430000, 'costo': 1430000,
         'costo_detalle': {'aportes': 0, 'provisiones': 0}},
      ],
      'totales': {'sueldo': 3180904, 'auxilio': 249094, 'devengado': 3429998, 'salud': 70036, 'pension': 70036,
                  'danos': 0, 'adelantos': 0, 'neto': 3289926, 'pagar': 3290000, 'pagado': 3290000,
                  'aportes': 289284, 'provisiones': 426213, 'costo': 4145569},
    });

final _personas = [
  Trabajador(id: 1, tienda: 1, nombres: 'Laura Gómez Ruiz', cargo: 'Asesora de ventas', ganaMinimo: true,
      fechaIngreso: DateTime(2026, 2, 1)),
  const Trabajador(id: 2, tienda: 1, nombres: 'Daniela Paz Ortiz', cargo: 'Cajera', valorDia: 63000),
  const Trabajador(id: 3, tienda: 1, nombres: 'Pedro Ruiz Cano', tipo: 'temporal', valorDia: 55000),
  Trabajador(id: 5, tienda: 1, nombres: 'Marta Ríos', activo: false, fechaRetiro: DateTime(2026, 9, 30)),
];

void main() {
  setUpAll(_cargarFuentes);

  group('Computador', () {
    testWidgets('quincena: tabla con tipo, valor del día, días y pagos', (t) async {
      _tam(t, 1110, 820);
      final log = <String>[];
      await _montar(t, NominaEscritorio(datos: _datos(), acciones: _acciones(log)));
      expect(t.takeException(), isNull);
      expect(find.text('NÓMINA'), findsWidgets);
      expect(find.text(r'$930.000'), findsWidgets);
      expect(find.text(r'$842.000'), findsOneWidget);
      expect(find.text('Pagado'), findsOneWidget);
      expect(find.text(r'Falta $342.000'), findsOneWidget);
      expect(find.text('Sin pagar'), findsOneWidget);
      await _foto(t, 'nomina_pc_quincena.png');
      await t.tap(find.text('Guardar quincena'));
      await t.tap(find.text(r'Falta $342.000'));
      await t.tap(find.text('Mes completo'));
      expect(log, ['guardar', 'pagos Daniela Paz Ortiz', 'vista mes']);
    });

    testWidgets('quincena: escribir días marca la fila como cambiada', (t) async {
      _tam(t, 1366, 820);
      final log = <String>[];
      final filas = [for (final f in _q().filas) FilaEditable(f)];
      late StateSetter set;
      await t.pumpWidget(MaterialApp(home: RepaintBoundary(key: _marco, child: Scaffold(
        body: StatefulBuilder(builder: (c, s) {
          set = s;
          return NominaEscritorio(datos: _datos(filas: filas), acciones: _acciones(log, cambio: () => set(() {})));
        }),
      ))));
      final sofia = filas.last;
      sofia.dias.text = '6,5';
      set(() {});
      await t.pump();
      expect(sofia.cambiada, isTrue);
      expect(find.text(r'$358.000'), findsOneWidget);
      expect(find.text('Guarda para pagar'), findsOneWidget);
      sofia.dias.text = '6,3';
      set(() {});
      await t.pump();
      expect(find.textContaining('medio en medio'), findsOneWidget);
      await _foto(t, 'nomina_pc_cambios.png');
    });

    testWidgets('mes completo: costo para la empresa', (t) async {
      _tam(t, 1366, 900);
      await _montar(t, NominaEscritorio(datos: _datos(vista: 'mes', mes: _mes()), acciones: _acciones([])));
      expect(t.takeException(), isNull);
      expect(find.text('Costo total de nómina'), findsOneWidget);
      expect(find.text('Exonerado'), findsOneWidget);
      await _foto(t, 'nomina_pc_mes.png');
    });

    testWidgets('personas', (t) async {
      _tam(t, 1366, 700);
      final log = <String>[];
      await _montar(t, NominaEscritorio(datos: _datos(vista: 'personas', personas: _personas),
          acciones: _acciones(log)));
      expect(t.takeException(), isNull);
      expect(find.text('Laura Gómez Ruiz'), findsOneWidget);
      expect(find.text('Marta Ríos'), findsNothing);
      await _foto(t, 'nomina_pc_personas.png');
      await t.tap(find.text('Laura Gómez Ruiz'));
      await t.tap(find.text('Retiradas (1)'));
      expect(log, ['persona Laura Gómez Ruiz', 'estado retirados']);
    });
  });

  group('Celular', () {
    for (final ancho in [390.0, 320.0]) {
      testWidgets('quincena a ${ancho.toInt()} px', (t) async {
        _tam(t, ancho, 1400);
        final log = <String>[];
        await _montar(t, NominaMovil(datos: _datos(), acciones: _acciones(log)));
        expect(t.takeException(), isNull);
        expect(find.text('Nómina'), findsWidgets);
        await _foto(t, 'nomina_movil_${ancho.toInt()}.png');
        await t.tap(find.text('Registrar pago').first);
        await t.tap(find.text('Desprendible').first);
        expect(log, ['pagar Daniela Paz Ortiz', 'pdf Laura Gómez Ruiz']);
      });
    }

    testWidgets('el − y + de los días van de medio en medio', (t) async {
      _tam(t, 390, 1400);
      final filas = [for (final f in _q().filas) FilaEditable(f)];
      late StateSetter set;
      await t.pumpWidget(MaterialApp(home: RepaintBoundary(key: _marco, child: Scaffold(
        body: StatefulBuilder(builder: (c, s) {
          set = s;
          return NominaMovil(datos: _datos(filas: filas), acciones: _acciones([], cambio: () => set(() {})));
        }),
      ))));
      final sofia = filas.last;
      await t.ensureVisible(find.text('Sofía Lara Muñoz'));
      final mas = find.byIcon(Icons.add_rounded).last;
      await t.ensureVisible(mas);
      await t.pump();
      await t.tap(mas);
      await t.pump();
      expect(sofia.dias.text, '0,5');
      await t.tap(mas);
      await t.pump();
      expect(sofia.dias.text, '1');
      expect(find.textContaining('Guardar quincena'), findsOneWidget);
    });

    testWidgets('mes en el celular', (t) async {
      _tam(t, 390, 1300);
      await _montar(t, NominaMovil(datos: _datos(vista: 'mes', mes: _mes()), acciones: _acciones([])));
      expect(t.takeException(), isNull);
      await _foto(t, 'nomina_movil_mes.png');
    });
  });

  group('Formularios', () {
    Future<void> enHoja(WidgetTester t, Widget w, {double ancho = 390, double alto = 900}) async {
      _tam(t, ancho, alto);
      await _montar(t, Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxHeight: alto * .94),
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.only(top: 16),
          child: w,
        ),
      ));
      expect(t.takeException(), isNull);
    }

    testWidgets('nueva persona', (t) async {
      Map<String, dynamic>? enviado;
      await enHoja(t, FormPersona(tiendas: const [TiendaOpcion(1, 'Consentida Accesorios')], salarioMinimo: sm,
          acento: const Color(0xFF059669), onCancelar: () {},
          onGuardar: (d) async {
            enviado = d;
            return null;
          }), alto: 1300);
      await _foto(t, 'nomina_form_persona.png');
      await t.tap(find.text('Guardar'));
      await t.pump();
      expect(find.text('Escribe nombres y apellidos.'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Nombres y apellidos'), 'Ana María Pérez');
      await t.tap(find.textContaining('Gana el mínimo ('));
      await t.pump();
      await t.ensureVisible(find.text('Guardar'));
      await t.tap(find.text('Guardar'));
      await t.pump();
      expect(enviado?['gana_minimo'], isTrue);
      expect(enviado?['tienda'], 1);
      expect(enviado?['tipo'], 'nomina');
    });

    testWidgets('pago en partes', (t) async {
      Map<String, dynamic>? enviado;
      await enHoja(t, FormPagoNomina(persona: 'Daniela Paz Ortiz', concepto: '2.ª quincena', falta: 342000,
          tienda: 1, acento: const Color(0xFF059669), hoy: DateTime(2026, 12, 1),
          cargarCuentas: (_) async => const [],
          onCancelar: () {}, onGuardar: (d) async {
            enviado = d;
            return null;
          }));
      await t.pump();
      await _foto(t, 'nomina_form_pago.png');
      await t.enterText(find.widgetWithText(TextField, 'Valor'), '400.000');
      await t.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
      await t.pump();
      expect(find.textContaining('Solo falta pagarle'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Valor'), '342.000');
      await t.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
      await t.pump();
      expect(enviado, {'valor': 342000, 'fecha': '2026-12-01', 'metodo_pago': 'efectivo'});
    });

    testWidgets('liquidación de salida: calcula y luego guarda', (t) async {
      final persona = Trabajador(id: 1, tienda: 1, nombres: 'Laura Gómez Ruiz', ganaMinimo: true,
          fechaIngreso: DateTime(2026, 2, 1));
      Map<String, dynamic>? guardado;
      await enHoja(t, FormSalida(
        persona: persona, hoy: DateTime(2026, 12, 15), acento: const Color(0xFF059669),
        documentos: [DocumentoTrabajador(id: 7, trabajador: 1, tipo: 'renuncia', fecha: DateTime(2026, 12, 1),
            detalle: 'Carta de renuncia')],
        calcular: (d) async => Liquidacion.calculo({
          'dias_pendientes': 15.0, 'dias_cesantias': 315, 'dias_prima': 165, 'vacaciones_dias': 13.13,
          'sueldo': 875452, 'auxilio': 124547, 'cesantias': 1750000, 'intereses': 183750, 'prima': 916667,
          'vacaciones': 766021, 'indemnizacion': 0, 'salud': 35018, 'pension': 35018, 'otros_descuentos': 0,
          'neto': 4546401, 'pagar': 4547000, 'mora_diaria': 58364, 'empleador': 'Carlos Velasco',
        }),
        onCancelar: () {},
        onGuardar: (d) async {
          guardado = d;
          return null;
        },
      ), alto: 1500);
      await t.tap(find.text('Calcular'));
      await t.pump();
      expect(find.text('Elige el motivo de la salida.'), findsOneWidget);
      await t.tap(find.text('Renuncia'));
      await t.pump();
      await t.tap(find.text('Calcular'));
      await t.pumpAndSettle();
      expect(find.text(r'$4.547.000'), findsOneWidget);
      await _foto(t, 'nomina_form_salida.png');
      await t.tap(find.text('Guardar liquidación'));
      await t.pump();
      expect(guardado?['motivo'], 'renuncia');
      expect(guardado?['anexos'], [7]);
    });

    testWidgets('subir documento: pide archivo y testigos si se negó', (t) async {
      (Map<String, dynamic>, Archivos)? enviado;
      await enHoja(t, FormDocumento(persona: 'Laura Gómez Ruiz', acento: const Color(0xFF059669),
          elegir: () async => [('memorando.jpg', Uint8List.fromList([1, 2, 3]))],
          onCancelar: () {}, onGuardar: (d, a) async {
            enviado = (d, a);
            return null;
          }), alto: 1100);
      await t.tap(find.text('Memorando'));
      await t.tap(find.text('Se negó a firmar'));
      await t.pump();
      await t.tap(find.text('Elegir archivo'));
      await t.pump();
      await t.tap(find.text('Guardar en su carpeta'));
      await t.pump();
      expect(find.textContaining('dos testigos'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Testigo 1'), 'Marta Ríos');
      await t.enterText(find.widgetWithText(TextField, 'Testigo 2'), 'Juan Pérez');
      await t.tap(find.text('Guardar en su carpeta'));
      await t.pumpAndSettle();
      await _foto(t, 'nomina_form_documento.png');
      expect(enviado?.$1['tipo'], 'memorando');
      expect(enviado?.$1['firma'], 'negado');
      expect(enviado?.$1['testigos'], 'Marta Ríos, Juan Pérez');
      expect(enviado?.$2.single.$1, 'memorando.jpg');
    });

    testWidgets('memorando', (t) async {
      Map<String, dynamic>? enviado;
      await enHoja(t, FormMemorando(persona: 'Laura Gómez Ruiz', acento: const Color(0xFF059669),
          onCancelar: () {}, onGuardar: (d) async {
            enviado = d;
            return null;
          }), ancho: 320, alto: 1000);
      await t.tap(find.text('Llegadas tarde'));
      await t.enterText(find.byType(TextField).last, 'Llegó a las 9:25 el 7 de octubre.');
      await t.pump();
      await _foto(t, 'nomina_form_memorando.png');
      await t.tap(find.text('Crear y sacar PDF'));
      await t.pump();
      expect(enviado?['motivo'], 'Llegadas tarde');
      expect(enviado?['firma'], 'pendiente');
    });
  });
}

// Evita el aviso de import sin usar cuando no hay cuentas en las pruebas.
// ignore: unused_element
const _cuentas = <CuentaBancaria>[];
