import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/utils/numero_excel.dart';

void main() {
  test('respeta el signo negativo (el bug: -6000 llegaba como 6000)', () {
    expect(leerNumeroExcel('-6000'), -6000);
    expect(leerNumeroExcel('-6.000'), -6000);
    expect(leerNumeroExcel(r'$ -6.000'), -6000);
    expect(leerNumeroExcel(r'-$6.000'), -6000);
    expect(leerNumeroExcel('  -5  '), -5);
    expect(leerNumeroExcel('−5'), -5); // signo tipográfico
    expect(leerNumeroExcel('(6.000)'), -6000); // formato contable
    expect(leerNumeroExcel('-12,5'), -12.5);
  });

  test('positivos en los formatos de siempre', () {
    expect(leerNumeroExcel('6000'), 6000);
    expect(leerNumeroExcel(r'$ 12.500'), 12500);
    expect(leerNumeroExcel('1.234,56'), 1234.56);
    expect(leerNumeroExcel('1,234.56'), 1234.56);
    expect(leerNumeroExcel('12,5'), 12.5);
    expect(leerNumeroExcel('1,234'), 1234);
    expect(leerNumeroExcel('32000.0'), 32000);
    expect(leerNumeroExcel('12.5'), 12.5);
    expect(leerNumeroExcel('1.250'), 1250);       // punto de miles
    expect(leerNumeroExcel('1.234.567'), 1234567);
  });

  test('vacío o sin números da 0', () {
    expect(leerNumeroExcel(''), 0);
    expect(leerNumeroExcel('   '), 0);
    expect(leerNumeroExcel('abc'), 0);
  });

  test('un guion que no va antes del número no lo vuelve negativo', () {
    // p. ej. un código o texto pegado después del valor
    expect(leerNumeroExcel('6000 - aprox'), 6000);
  });
}
