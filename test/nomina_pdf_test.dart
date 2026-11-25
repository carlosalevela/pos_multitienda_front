import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_multitienda_app/services/nomina_pdf_service.dart';
import 'package:pos_multitienda_app/services/nomina_service.dart';

const _dir = String.fromEnvironment('SHOT_DIR');

const sm = 1750905, aux = 249095;

FilaQuincena fila(int id, String n, String tipo, double dia, double dias,
    {bool minimo = false, int danos = 0, List<PagoNomina> pagos = const [], String fechas = ''}) {
  final c = calcularFila(tipo: tipo, valorDia: dia, dias: dias, ganaMinimo: minimo,
      salarioMinimo: sm, auxilioTransporte: aux, danos: danos);
  return FilaQuincena(id: id, trabajador: id, nombres: n, cedula: '1088234567', cargo: 'Asesora de ventas',
      tipo: tipo, valorDia: minimo ? 58363.5 : dia, dias: dias, ganaMinimo: minimo, guardada: true,
      comprobante: 8 + id, calculo: c, pagos: pagos, fechas: fechas);
}

QuincenaNomina ejemplo() => QuincenaNomina(
      id: 1, tienda: 1, anio: 2026, mes: 11, numero: 2, salarioMinimo: sm,
      auxilioTransporte: aux, tiendaNombre: 'Consentida Accesorios', periodo: periodoQuincena(2026, 11, 2),
      empleador: 'Carlos Velasco',
      filas: [
        fila(1, 'Laura Gómez Ruiz', 'nomina', 0, 15, minimo: true, pagos: [
          PagoNomina(id: 1, valor: 930000, fecha: DateTime(2026, 11, 30), metodoPago: 'transferencia',
              cuentaNombre: 'Bancolombia')]),
        fila(2, 'Daniela Paz Ortiz', 'nomina', 63000, 13, danos: 20000, pagos: [
          PagoNomina(id: 2, valor: 500000, fecha: DateTime(2026, 11, 30), metodoPago: 'transferencia',
              cuentaNombre: 'Bancolombia'),
          PagoNomina(id: 3, valor: 342000, fecha: DateTime(2026, 12, 1))]),
        fila(3, 'Pedro Ruiz Cano', 'temporal', 55000, 12, fechas: '16,17,18,19,20,21,23,24,25,26,27,28'),
      ],
    );

Future<void> guardar(String nombre, List<int> bytes) async {
  expect(bytes.length, greaterThan(1000));
  if (_dir.isEmpty) return;
  await File('$_dir/$nombre').writeAsBytes(bytes);
}

void main() {
  test('planilla de la quincena', () async {
    await guardar('planilla.pdf', await NominaPdf.planilla(ejemplo()));
  });

  test('desprendibles', () async {
    final q = ejemplo();
    await guardar('desprendibles.pdf', await NominaPdf.desprendibles(q, q.guardadas));
  });

  test('planilla del mes', () async {
    final m = MesNomina.fromJson({
      'anio': 2026, 'mes': 11,
      'valores': {'anio': 2026, 'salario_minimo': sm, 'auxilio_transporte': aux, 'arl_pct': 0.522,
                  'exonerado': true, 'redondear_mil': true},
      'personas': [
        {'trabajador': 1, 'nombres': 'Laura Gómez Ruiz', 'tipo': 'nomina', 'q1': {'pagar': 930000},
         'q2': {'pagar': 930000}, 'dias': 30, 'sueldo': 1750904, 'auxilio': 249094, 'salud': 70036,
         'pension': 70036, 'danos': 0, 'adelantos': 0, 'neto': 1859926, 'pagar': 1860000,
         'pagado': 1860000, 'costo': 2716495,
         'costo_detalle': {'aportes': 289284, 'provisiones': 426213}},
      ],
      'totales': {'sueldo': 1750904, 'auxilio': 249094, 'devengado': 1999998, 'salud': 70036,
                  'pension': 70036, 'pagar': 1860000, 'aportes': 289284, 'provisiones': 426213,
                  'costo': 2716495},
    });
    await guardar('mes.pdf', await NominaPdf.planillaMes(m, 'Consentida Accesorios'));
  });

  test('liquidación de salida', () async {
    final t = Trabajador(id: 1, tienda: 1, nombres: 'Laura Gómez Ruiz', cedula: '1088234567',
        cargo: 'Asesora de ventas', fechaIngreso: DateTime(2026, 2, 1));
    final lq = Liquidacion(comprobante: 12, empleador: 'Carlos Velasco', d: {
      'fecha_ingreso': '2026-02-01', 'fecha_retiro': '2026-12-15', 'motivo': 'renuncia',
      'motivo_texto': 'Renuncia voluntaria', 'tipo_contrato': 'indefinido', 'mensual': sm,
      'dias_total': 315, 'dias_cesantias': 315, 'dias_prima': 165, 'dias_pendientes': 15.0,
      'base_prestaciones': 2000000, 'vacaciones_dias': 13.13, 'indemnizacion_dias': 0.0,
      'cesantias_desde': '2026-02-01', 'prima_desde': '2026-07-01', 'sueldo': 875452,
      'auxilio': 124547, 'cesantias': 1750000, 'intereses': 183750, 'prima': 916667,
      'vacaciones': 766021, 'indemnizacion': 0, 'salud': 35018, 'pension': 35018,
      'otros_descuentos': 0, 'ingresos': 4616437, 'deducido': 70036, 'neto': 4546401,
      'pagar': 4547000,
    }, anexos: [
      DocumentoTrabajador(id: 1, trabajador: 1, tipo: 'renuncia', fecha: DateTime(2026, 12, 1),
          detalle: 'Carta de renuncia'),
    ]);
    await guardar('liquidacion.pdf', await NominaPdf.liquidacion(t, lq, 'Consentida Accesorios'));
  });

  test('memorando', () async {
    final t = Trabajador(id: 1, tienda: 1, nombres: 'Laura Gómez Ruiz', cedula: '1088234567',
        cargo: 'Asesora de ventas');
    final m = DocumentoTrabajador(id: 1, trabajador: 1, tipo: 'memorando', numero: 1,
        fecha: DateTime(2026, 10, 14), motivo: 'Llegadas tarde',
        hechos: 'Los días 7, 9 y 10 de octubre llegó a las 9:25, 9:40 y 9:20; la hora de entrada es 9:00 a. m.');
    await guardar('memorando.pdf', await NominaPdf.memorando(t, m,
        tienda: 'Consentida Accesorios', ciudad: '', empleador: 'Carlos Velasco'));
  });
}
