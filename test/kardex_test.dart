// Cómo se cuenta cada movimiento del kardex.
//
// El mismo "tipo" no siempre significa lo mismo (un ajuste manual guarda en
// cuánto quedó el stock; una cancelación guardada como ajuste guarda
// unidades), así que se prueba cada combinación de tipo y referencia que
// crea el servidor.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/screens/inventario/widgets/inventario_movil.dart';

LineaKardex d(String tipo, String ref, double cant, [String obs = '']) =>
    describirMovimiento(MovimientoKardexMovil(
        tipo: tipo, referencia: ref, cantidad: cant, observacion: obs));

void main() {
  test('cada combinación del servidor tiene su texto y su efecto', () {
    // (tipo, referencia, cantidad, obs) → (título, cantidad, nota, efecto, a averías)
    final casos = <(String, String, double, String), (String, String, String?, double, double)>{
      ('salida', 'venta', 2, ''):            ('Venta', '−2', null, -2, 0),
      ('salida', 'cambio', 1, ''):           ('Cambio · entregado al cliente', '−1', null, -1, 0),
      ('salida', 'cambio_pos', 1, ''):       ('Cambio · entregado al cliente', '−1', null, -1, 0),
      ('salida', 'separado', 1, ''):         ('Separado', '−1', null, -1, 0),
      ('salida', 'cambio_separado', 1, ''):  ('Cambio en separado · sale', '−1', null, -1, 0),
      ('salida', 'manual', 3, ''):           ('Salida manual', '−3', null, -3, 0),
      ('entrada', 'compra', 30, ''):         ('Compra recibida', '+30', null, 30, 0),
      ('entrada', 'devolucion', 1, ''):      ('Devolución de cliente', '+1', null, 1, 0),
      ('entrada', 'cambio', 1, ''):          ('Cambio · devuelto a inventario', '+1', null, 1, 0),
      ('entrada', 'anulacion', 2, ''):       ('Venta anulada', '+2', null, 2, 0),
      ('entrada', 'cancelacion_separado', 1, ''): ('Separado cancelado', '+1', null, 1, 0),
      ('entrada', 'cambio_separado', 1, ''): ('Cambio en separado · vuelve', '+1', null, 1, 0),
      ('entrada', 'cancelacion_cambio', 1, ''): ('Cambio cancelado · vuelve', '+1', null, 1, 0),
      ('entrada', 'recuperacion_averia', 1, ''): ('Recuperado de averías', '+1', null, 1, 0),
      ('entrada', 'manual', 5, ''):          ('Entrada manual', '+5', null, 5, 0),
      // Ajuste manual: la cantidad es en cuánto quedó, no unidades movidas.
      ('ajuste', 'manual', 45, ''):          ('Ajuste manual', '=45', 'quedó en', 0, 0),
      ('ajuste', 'cancelacion_devolucion', 1, ''): ('Devolución cancelada', '1', 'sale de averías', 0, 0),
      ('ajuste', 'cancelacion_cambio', 1, 'Cancelación DEV-4 | producto revertido de inventario'):
          ('Cambio cancelado', '−1', null, -1, 0),
      ('ajuste', 'cancelacion_cambio', 1, 'Cancelación DEV-4 | producto revertido de averías'):
          ('Cambio cancelado', '1', 'sale de averías', 0, 0),
      ('transferencia', 'transferencia', -4, 'Transferencia a Unicentro'):
          ('Enviado a Unicentro', '−4', null, -4, 0),
      ('transferencia', 'transferencia', 4, 'Recibido desde Boutique 27'):
          ('Recibido de Boutique 27', '+4', null, 4, 0),
      // Avería reportada a mano: sale del stock y pasa a averías.
      ('dano', 'manual', 1, ''):             ('Avería reportada', '−1', 'a averías', -1, 1),
      // Lo trajo el cliente dañado: el stock no cambia.
      ('dano', 'devolucion', 1, ''):         ('Avería por devolución', '1', 'a averías', 0, 1),
      ('dano', 'cambio', 1, ''):             ('Avería por cambio', '1', 'a averías', 0, 1),
      ('dano', 'cambio_pos', 1, ''):         ('Avería por cambio', '1', 'a averías', 0, 1),
      ('dano', 'descarte_averia', 2, ''):    ('Descartado de averías', '2', 'baja definitiva', 0, 0),
    };
    for (final e in casos.entries) {
      final (tipo, ref, cant, obs) = e.key;
      final (titulo, cantidad, nota, efecto, aAv) = e.value;
      final l = d(tipo, ref, cant, obs);
      final r = '$tipo/$ref';
      expect(l.titulo, titulo, reason: r);
      expect(l.cantidad, cantidad, reason: r);
      expect(l.nota, nota, reason: r);
      expect(l.efectoStock, efecto, reason: r);
      expect(l.aAverias, aAv, reason: r);
      expect(l.titulo.toLowerCase(), isNot(contains('dano')), reason: r);
      expect(l.titulo, isNot(contains('_')), reason: r);
    }
  });

  test('la observación automática no se repite debajo del título', () {
    expect(d('transferencia', 'transferencia', -2, 'Transferencia a Unicentro')
        .observacion, isNull);
    expect(d('entrada', 'recuperacion_averia', 1,
            'Recuperado de averías → stock normal').observacion, isNull);
    expect(d('dano', 'descarte_averia', 1,
            'Descartado de averías (baja definitiva)').observacion, isNull);
    // Una nota escrita por alguien sí se muestra.
    expect(d('transferencia', 'transferencia', -2, 'Para la vitrina nueva')
        .titulo, 'Enviado a otra tienda');
    expect(d('transferencia', 'transferencia', -2, 'Para la vitrina nueva')
        .observacion, 'Para la vitrina nueva');
    expect(d('dano', 'devolucion', 1, 'Devolución DEV-12 | FAC-0001 → avería')
        .observacion, 'Devolución DEV-12 | FAC-0001 → avería');
  });

  test('una transferencia con nota no pierde a qué tienda fue', () {
    final envio = d('transferencia', 'transferencia', -2,
        'Transferencia a Unicentro · Para la vitrina nueva');
    expect(envio.titulo, 'Enviado a Unicentro');
    expect(envio.observacion, 'Para la vitrina nueva');
    final recibo = d('transferencia', 'transferencia', 2,
        'Recibido desde Boutique 27 · Para la vitrina nueva');
    expect(recibo.titulo, 'Recibido de Boutique 27');
    expect(recibo.observacion, 'Para la vitrina nueva');
  });

  test('tipos o referencias desconocidos no revientan', () {
    expect(d('salida', 'algo_nuevo', 1).titulo, 'Salida');
    expect(d('entrada', '', 1).titulo, 'Entrada');
    expect(d('ajuste', 'otro', 3).titulo, 'Ajuste');
    expect(d('dano', 'otro', 1).titulo, 'Avería');
    expect(d('raro', '', 1).titulo, 'raro');
  });

  test('días y horas en español', () {
    final ahora = DateTime(2026, 11, 25, 10);
    expect(diaKardex(DateTime(2026, 11, 25, 8), ahora), 'Hoy');
    expect(diaKardex(DateTime(2026, 11, 24, 23, 59), ahora), 'Ayer');
    expect(diaKardex(DateTime(2026, 11, 23), ahora), 'Lun 23 nov');
    expect(diaKardex(DateTime(2025, 12, 31), ahora), 'Mié 31 dic 2025');
    expect(horaKardex(DateTime(2026, 1, 1, 0, 5)), '12:05 a. m.');
    expect(horaKardex(DateTime(2026, 1, 1, 12, 0)), '12:00 p. m.');
    expect(horaKardex(DateTime(2026, 1, 1, 15, 42)), '3:42 p. m.');
  });

  test('el kardex real del servidor se lee completo', () {
    const ruta =
        r'C:\Users\XzCar\AppData\Local\Temp\claude\160e7d60e6dbc836\a73dd243-0ffc-4b1b-83a6-b47decf936a5\scratchpad\kardex_real.json';
    final f = File(ruta);
    if (!f.existsSync()) return; // solo en la máquina donde se sacó
    final lista = (jsonDecode(f.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    expect(lista, isNotEmpty);
    for (final j in lista) {
      final m = MovimientoKardexMovil.fromJson(j);
      final l = describirMovimiento(m);
      final r = '${j['tipo']}/${j['referencia_tipo']}';
      expect(m.fecha, isNotNull, reason: r);
      expect(m.cantidad, greaterThan(0), reason: r);
      expect(l.filtros, isNotEmpty, reason: r);
      expect(l.titulo, isNot(contains('_')), reason: r);
      expect(['Salida', 'Entrada', 'Ajuste', 'Avería'], isNot(contains(l.titulo)),
          reason: 'sin texto específico: $r');
    }
  });
}
