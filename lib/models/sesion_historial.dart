// lib/models/sesion_historial.dart

class SesionHistorial {
  final int    id;
  final String empleadoNombre;
  final String tiendaNombre;
  final String fechaApertura;
  final String fechaCierre;
  final String estado;
  final String observaciones;
  final double saldoInicial;
  // Ventas desglosadas
  final double ventasEfectivo;
  final double ventasTarjeta;
  final double ventasTransferencia;
  final double ventasMixto;
  final double ventasTotal;
  // Gastos
  final double gastosTotal;
  // Devoluciones
  final double devolucionesEfectivo;
  final int    numDevoluciones;
  // Cuadre
  final double montoFinalSistema;
  final double montoFinalReal;
  final double diferencia;
  // Stats
  final int    numTransacciones;

  SesionHistorial({
    required this.id,
    required this.empleadoNombre,
    required this.tiendaNombre,
    required this.fechaApertura,
    required this.fechaCierre,
    required this.estado,
    required this.observaciones,
    required this.saldoInicial,
    required this.ventasEfectivo,
    required this.ventasTarjeta,
    required this.ventasTransferencia,
    required this.ventasMixto,
    required this.ventasTotal,
    required this.gastosTotal,
    required this.devolucionesEfectivo,
    required this.numDevoluciones,
    required this.montoFinalSistema,
    required this.montoFinalReal,
    required this.diferencia,
    required this.numTransacciones,
  });

  factory SesionHistorial.fromJson(Map<String, dynamic> j) => SesionHistorial(
    id:                    j['id']                ?? 0,
    empleadoNombre:        j['empleado_nombre']   ?? '',
    tiendaNombre:          j['tienda_nombre']     ?? '',
    fechaApertura:         j['fecha_apertura']    ?? '',
    fechaCierre:           j['fecha_cierre']      ?? '',
    estado:                j['estado']            ?? '',
    observaciones:         j['observaciones']     ?? '',
    saldoInicial:          double.tryParse(j['saldo_inicial']?.toString()          ?? '0') ?? 0.0,
    ventasEfectivo:        double.tryParse(j['ventas_efectivo']?.toString()        ?? '0') ?? 0.0,
    ventasTarjeta:         double.tryParse(j['ventas_tarjeta']?.toString()         ?? '0') ?? 0.0,
    ventasTransferencia:   double.tryParse(j['ventas_transferencia']?.toString()   ?? '0') ?? 0.0,
    ventasMixto:           double.tryParse(j['ventas_mixto']?.toString()           ?? '0') ?? 0.0,
    ventasTotal:           double.tryParse(j['ventas_total']?.toString()           ?? '0') ?? 0.0,
    gastosTotal:           double.tryParse(j['gastos_total']?.toString()           ?? '0') ?? 0.0,
    devolucionesEfectivo:  double.tryParse(j['devoluciones_efectivo']?.toString()  ?? '0') ?? 0.0,
    numDevoluciones:       (j['num_devoluciones']  as num?)?.toInt() ?? 0,
    montoFinalSistema:     double.tryParse(j['monto_esperado']?.toString()         ?? '0') ?? 0.0,
    montoFinalReal:        double.tryParse(j['monto_final_real']?.toString()       ?? '0') ?? 0.0,
    diferencia:            double.tryParse(j['diferencia']?.toString()             ?? '0') ?? 0.0,
    numTransacciones:      (j['num_transacciones'] as num?)?.toInt() ?? 0,
  );
}