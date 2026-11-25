import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/services/nomina_service.dart';

void main() {
  const sm = 1750905, aux = 249095;

  group('Cálculo de la quincena (igual al servidor y a la planilla en Excel)', () {
    test('mínimo, 15 días: neto 929.963 y se paga 930.000', () {
      final c = calcularFila(tipo: 'nomina', valorDia: 0, dias: 15, ganaMinimo: true,
          salarioMinimo: sm, auxilioTransporte: aux);
      expect(c.sueldo, 875452);
      expect(c.auxilio, 124547);
      expect(c.salud, 35018);
      expect(c.pension, 35018);
      expect(c.neto, 929963);
      expect(c.pagar, 930000);
    });

    test('valor del día, 13 días y un daño: se redondea hacia arriba', () {
      final c = calcularFila(tipo: 'nomina', valorDia: 63000, dias: 13,
          salarioMinimo: sm, auxilioTransporte: aux, danos: 20000);
      expect(c.sueldo, 819000);
      expect(c.auxilio, 107941);
      expect(c.neto, 841421);
      expect(c.pagar, 842000);
    });

    test('temporal con medio día: sin auxilio ni descuentos', () {
      final c = calcularFila(tipo: 'temporal', valorDia: 55000, dias: 6.5,
          salarioMinimo: sm, auxilioTransporte: aux);
      expect(c.auxilio, 0);
      expect(c.salud, 0);
      expect(c.neto, 357500);
      expect(c.pagar, 358000);
    });

    test('más de 2 mínimos: sin auxilio de transporte', () {
      final c = calcularFila(tipo: 'nomina', valorDia: 120000, dias: 15,
          salarioMinimo: sm, auxilioTransporte: aux);
      expect(c.auxilio, 0);
      expect(c.salud, 72000);
    });

    test('sin redondeo se paga el neto exacto', () {
      final c = calcularFila(tipo: 'nomina', valorDia: 0, dias: 15, ganaMinimo: true,
          salarioMinimo: sm, auxilioTransporte: aux, redondearMil: false);
      expect(c.pagar, 929963);
    });
  });

  group('Qué falta para guardar una fila', () {
    test('días de medio en medio', () {
      expect(problemaFila(nombre: 'Ana', valorDia: 50000, dias: 6.3, ganaMinimo: false),
          contains('medio en medio'));
      expect(problemaFila(nombre: 'Ana', valorDia: 50000, dias: 6.5, ganaMinimo: false), isNull);
    });
    test('sin valor del día (salvo si gana el mínimo)', () {
      expect(problemaFila(nombre: 'Ana', valorDia: null, dias: 15, ganaMinimo: false),
          contains('valor del día'));
      expect(problemaFila(nombre: 'Ana', valorDia: null, dias: 15, ganaMinimo: true), isNull);
    });
    test('con 0 días no se exige nada (no trabajó)', () {
      expect(problemaFila(nombre: 'Ana', valorDia: null, dias: 0, ganaMinimo: false), isNull);
    });
    test('más de 16 días', () {
      expect(problemaFila(nombre: 'Ana', valorDia: 1, dias: 17, ganaMinimo: false),
          contains('16'));
    });
    test('descuentos mayores a lo ganado', () {
      final c = calcularFila(tipo: 'temporal', valorDia: 55000, dias: 1,
          salarioMinimo: sm, auxilioTransporte: aux, danos: 90000);
      expect(problemaFila(nombre: 'Ana', valorDia: 55000, dias: 1, ganaMinimo: false,
          danos: 90000, calculo: c), contains('superan'));
    });
  });

  group('Textos', () {
    test('pesos, días y periodo', () {
      expect(pesosNomina(1750905), r'$1.750.905');
      expect(pesosNomina(0), r'$0');
      expect(diasTexto(14.5), '14,5');
      expect(diasTexto(15), '15');
      expect(periodoQuincena(2026, 11, 2), '16 al 30 de noviembre de 2026');
      expect(periodoQuincena(2026, 2, 2), '16 al 28 de febrero de 2026');
      expect(leerNumero('58.364'), 58364);
      expect(leerNumero('14,5', decimales: true), 14.5);
      expect(leerNumero('abc'), isNull);
      expect(alMil(930000), 930000);
      expect(alMil(-3), 0);
    });
  });
}
