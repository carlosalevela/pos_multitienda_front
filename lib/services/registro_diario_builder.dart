// lib/services/registro_diario_builder.dart
//
// Constructor UNICO del Registro de Movimiento Diario.
//
// Lo usan los dos lugares que generan este formato, para que el PDF
// sea identico en ambos:
//   - formatos_diarios_screen.dart  (envio manual desde Formatos Diarios)
//   - corte_caja_dialog.dart        (envio automatico al cerrar caja)
//
// Si cambias una fila aqui, cambia en los dos lados a la vez.

import '../models/sesion_historial.dart';
import '../screens/caja/widgets/registro_movimiento_diario.dart';

/// Reparte un gasto a su columna segun el metodo con que se pago.
/// Mantiene la regla "efectivo solo si es efectivo": un gasto pagado con
/// datafono o transferencia NO ensucia la columna de EFECTIVO.
MedioPago _columnaGasto(String? metodoPago) => switch (metodoPago) {
      'tarjeta' => MedioPago.datafono,
      'transferencia' => MedioPago.bancolombia,
      _ => MedioPago.efectivo,
    };

/// Columna del formato que le corresponde a una cuenta bancaria, segun su
/// tipo (CuentaBancaria.TIPO_CHOICES en el backend).
MedioPago _columnaCuenta(String? tipoCuenta) => switch (tipoCuenta) {
      'nequi' => MedioPago.nequi,
      'daviplata' => MedioPago.daviplata,
      'tarjeta' => MedioPago.datafono,
      _ => MedioPago.bancolombia,
    };

/// Suma por columna las filas de un detalle que entraron por transferencia.
///
/// [campoMonto] y [campoMetodo] cambian porque cada detalle nombra distinto
/// sus campos: ventas traen 'total', devoluciones traen 'metodo' y
/// 'diferencia'. [signo] permite restar, como las devoluciones que se
/// devuelven al cliente.
Map<MedioPago, double> _transferPorColumna(
  Iterable<Map<String, dynamic>> filas, {
  String campoMonto = 'monto',
  String campoMetodo = 'metodo_pago',
  bool Function(Map<String, dynamic> fila)? donde,
  double Function(Map<String, dynamic> fila)? signo,
}) {
  final out = <MedioPago, double>{};
  for (final f in filas) {
    if (donde != null && !donde(f)) continue;
    final metodo = (f[campoMetodo] ?? f['metodo'] ?? '').toString();
    if (!metodo.contains('transferencia')) continue;
    var monto = double.tryParse(f[campoMonto]?.toString() ?? '0') ?? 0.0;
    if (signo != null) monto *= signo(f);
    if (monto == 0) continue;
    final col = _columnaCuenta(f['cuenta_tipo'] as String?);
    out[col] = (out[col] ?? 0) + monto;
  }
  return out;
}

Map<MedioPago, double> _sumarMapas(
    Map<MedioPago, double> a, Map<MedioPago, double> b) {
  final out = Map<MedioPago, double>.from(a);
  b.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
  return out;
}

/// Reparte [total] entre Nequi / DaviPlata / Bancolombia usando [observado]
/// como proporcion.
///
/// El total de la fila NUNCA cambia. Si no hay informacion de cuentas, o la
/// proporcion no es creible, todo va a TRANSF. BANCOLOMBIA, que es el
/// comportamiento de siempre.
Map<MedioPago, double> _repartir(
    double total, Map<MedioPago, double> observado) {
  if (total == 0) return {};
  final suma = observado.values.fold<double>(0, (t, v) => t + v);
  if (observado.isEmpty || suma == 0) return {MedioPago.bancolombia: total};

  // Caso normal: el detalle explica exactamente el total de la fila.
  if ((suma - total).abs() < 0.01) return observado;

  // Quedan conceptos sin detalle por cuenta: se escala para conservar el
  // total, pero solo si la proporcion tiene sentido. Asi se evitan repartos
  // absurdos cuando el total es un neto cercano a cero.
  final factor = total / suma;
  if (factor <= 0 || factor > 5) return {MedioPago.bancolombia: total};
  return observado.map((c, m) => MapEntry(c, m * factor));
}

/// Los depositos iniciales de un separado se describen "Abono inicial ...".
/// El formato los lleva a INGRESOS SEPARADOS, no a ABONOS PAGOS CLIENTES.
bool _esAbonoInicial(Map<String, dynamic> a) =>
    (a['descripcion']?.toString() ?? '')
        .toLowerCase()
        .contains('abono inicial');

/// Arma el formato a partir del detalle completo de una sesion.
///
/// [full] debe venir del endpoint de detalle (getDetalleSesion), que es
/// el que trae todos los campos (bonos, ingresos de separados, netos de
/// cambios). El endpoint de lista devuelve solo lo basico.
RegistroMovimientoData construirRegistroDiario(
  SesionHistorial full, {
  String? observaciones,
}) {
  DateTime fecha;
  try {
    fecha = DateTime.parse(full.fechaApertura.replaceAll(' ', 'T')).toLocal();
  } catch (_) {
    fecha = DateTime.now();
  }

  final diferencia = full.montoFinalReal - full.montoFinalSistema;
  final sobrante = diferencia > 0 ? diferencia : 0.0;
  final faltante = diferencia < 0 ? diferencia.abs() : 0.0;

  final efVentas =
      full.ventasEfectivo + full.ventasMixtoEfectivo - full.compraBonasEfectivo;

  // neto devoluciones: cobros - devueltos - devoluciones puras
  // (positivo = entro dinero)
  final devEfNeto =
      full.cambiosCobrarEf - full.cambiosDevEf - full.devolucionesDirectasEf;

  final dtTotal = full.ventasTarjeta +
      full.abonosTarjeta +
      full.ingresosSepTarjeta -
      full.compraBonaTarjeta;
  final trTotal = full.ventasTransferencia +
      full.abonosTransferencia +
      full.ingresosSepTransferencia -
      full.compraBonasTransferencia;

  final nVentas = full.numTransacciones - full.numCompraBonos;
  final dtCount =
      full.ventasDetalle.where((v) => v['metodo_pago'] == 'tarjeta').length -
          (full.compraBonaTarjeta > 0 ? 1 : 0);
  final trCount = full.ventasDetalle
          .where((v) => v['metodo_pago'] == 'transferencia')
          .length -
      (full.compraBonasTransferencia > 0 ? 1 : 0);

  // -- Gastos repartidos por metodo de pago --------------
  final gastosPorMedio = <MedioPago, double>{};
  for (final g in full.gastosDetalle) {
    final monto = double.tryParse(g['monto']?.toString() ?? '0') ?? 0.0;
    if (monto == 0) continue;
    final col = _columnaGasto(g['metodo_pago'] as String?);
    gastosPorMedio[col] = (gastosPorMedio[col] ?? 0) + monto;
  }
  // Si el detalle no vino, cae al total (todo a efectivo) para no perder el dato.
  if (gastosPorMedio.isEmpty && full.gastosTotal > 0) {
    gastosPorMedio[MedioPago.efectivo] = full.gastosTotal;
  }
  final gastosEfectivo = gastosPorMedio[MedioPago.efectivo] ?? 0.0;

  return RegistroMovimientoData(
    almacen: full.tiendaNombre.toUpperCase(),
    fecha: fecha,
    encargado: full.empleadoNombre.toUpperCase(),
    // Header: todo lo que genero dinero real este turno
    // (excluye bonos redimidos puros, que no entran plata nueva)
    numeroVentas: (full.numTransacciones - full.ventasBonoNum) +
        full.numIngresosSep +
        full.numAbonos,
    totalVentas: (full.ventasTotal - full.ventasBono) +
        full.ingresosSepEfectivo +
        full.ingresosSepTarjeta +
        full.ingresosSepTransferencia +
        full.abonosEfectivo +
        full.abonosCreditoEfectivo +
        full.abonosTarjeta +
        full.abonosTransferencia,
    realizo: full.empleadoNombre,
    observaciones: observaciones ?? full.observaciones,
    filas: [
      FilaRegistro(
          signo: '+',
          concepto: 'VENTAS EN CAJA',
          cantidad: nVentas,
          montos: efVentas > 0 ? {MedioPago.efectivo: efVentas} : {}),
      FilaRegistro(
          signo: '+',
          concepto: 'INGRESOS SEPARADOS',
          cantidad: full.numIngresosSep,
          montos: {
            if (full.ingresosSepEfectivo > 0)
              MedioPago.efectivo: full.ingresosSepEfectivo,
            if (full.ingresosSepTarjeta > 0)
              MedioPago.datafono: full.ingresosSepTarjeta,
            ..._repartir(
                full.ingresosSepTransferencia,
                _transferPorColumna(full.abonosDetalle,
                    donde: _esAbonoInicial)),
          }),
      FilaRegistro(
          signo: '+',
          concepto: 'ABONOS PAGOS CLIENTES',
          cantidad: full.numAbonos,
          montos: {
            if ((full.abonosEfectivo + full.abonosCreditoEfectivo) > 0)
              MedioPago.efectivo:
                  full.abonosEfectivo + full.abonosCreditoEfectivo,
            if (full.abonosTarjeta > 0) MedioPago.datafono: full.abonosTarjeta,
            ..._repartir(
                full.abonosTransferencia,
                _transferPorColumna(full.abonosDetalle,
                    donde: (a) => !_esAbonoInicial(a))),
          }),
      FilaRegistro(
          signo: '+',
          concepto: 'DEVOLUCIONES',
          cantidad: full.numDevoluciones,
          montos: {
            if (devEfNeto != 0) MedioPago.efectivo: devEfNeto,
            if (full.netoCambiosTarjeta != 0)
              MedioPago.datafono: full.netoCambiosTarjeta,
            ..._repartir(
                full.netoCambiosTransferencia,
                _transferPorColumna(full.devolucionesDetalle,
                    campoMonto: 'diferencia',
                    campoMetodo: 'metodo',
                    signo: (d) =>
                        d['tipo_diferencia'] == 'devolver' ? -1.0 : 1.0)),
          }),
      FilaRegistro(
          signo: '+',
          concepto: 'COMPRA DE BONOS',
          cantidad: full.numCompraBonos,
          montos: {
            if (full.compraBonasEfectivo > 0)
              MedioPago.efectivo: full.compraBonasEfectivo,
            if (full.compraBonaTarjeta > 0)
              MedioPago.datafono: full.compraBonaTarjeta,
            ..._repartir(full.compraBonasTransferencia,
                _transferPorColumna(full.compraBonosDetalle)),
          }),
      FilaRegistro(
          signo: '+',
          concepto: 'DATÁFONO',
          cantidad: dtCount,
          montos: dtTotal > 0 ? {MedioPago.datafono: dtTotal} : {}),
      FilaRegistro(
          signo: '+',
          concepto: 'TRANSFERENCIAS',
          cantidad: trCount,
          montos: _repartir(
              trTotal,
              _sumarMapas(
                _transferPorColumna(full.ventasDetalle, campoMonto: 'total'),
                _transferPorColumna(full.abonosDetalle),
              ))),
      FilaRegistro(
          signo: '+',
          concepto: 'BONOS REDIMIDOS',
          cantidad: full.ventasBonoNum,
          montos: full.ventasBono > 0 ? {MedioPago.bono: full.ventasBono} : {}),
      FilaRegistro(
          signo: '+',
          concepto: 'BONOS + DIFERENCIA',
          cantidad: full.ventasBonoDifNum,
          montos: {
            if (full.ventasBonoEfectivo > 0)
              MedioPago.efectivo: full.ventasBonoEfectivo,
            if (full.ventasBonoTarjeta > 0)
              MedioPago.datafono: full.ventasBonoTarjeta,
            ..._repartir(
                full.ventasBonoTransferencia,
                _transferPorColumna(full.ventasDetalle,
                    campoMonto: 'total',
                    donde: (v) => v['metodo_pago'] == 'bono_transferencia')),
            if (full.ventasBonoDifBonoParte > 0)
              MedioPago.bono: full.ventasBonoDifBonoParte,
          }),
      FilaRegistro(
          signo: '+',
          concepto: 'TOTAL EFECTIVO',
          cantidad: full.numTransacciones,
          // montoFinalSistema ya desconto SOLO los gastos en efectivo,
          // asi que aqui se devuelve exactamente ese mismo monto.
          montos: {
            MedioPago.efectivo:
                full.montoFinalSistema + gastosEfectivo - full.saldoInicial
          }),
      FilaRegistro(
          signo: '−',
          concepto: 'GASTOS',
          cantidad: full.numGastos,
          montos: gastosPorMedio),
      FilaRegistro(
          signo: '+',
          concepto: 'SOBRANTES',
          cantidad: sobrante > 0 ? 1 : 0,
          montos: sobrante > 0 ? {MedioPago.efectivo: sobrante} : {}),
      FilaRegistro(
          signo: '−',
          concepto: 'FALTANTE',
          cantidad: faltante > 0 ? 1 : 0,
          montos: faltante > 0 ? {MedioPago.efectivo: faltante} : {}),
    ],
    totalEntregado: FilaRegistro(
      signo: '+',
      concepto: 'TOTAL EFECTIVO ENTREGADO',
      cantidad: full.numTransacciones,
      montos: {MedioPago.efectivo: full.montoFinalReal - full.saldoInicial},
    ),
  );
}
