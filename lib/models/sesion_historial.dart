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
  final double ventasMixtoEfectivo;
  final double ventasTotal;
  // Gastos
  final double gastosTotal;
  // Abonos desglosados ← NUEVO
  final double abonosEfectivo;
  final double abonosTarjeta;
  final double abonosTransferencia;
  final double abonosTotal;
  final double abonosCreditoEfectivo;
  final int    numAbonos;
  // Devoluciones
  final double devolucionesEfectivo;
  final double devolucionesDirectasEf;
  final double cambiosCobrarEf;
  final double cambiosDevEf;
  final int    numDevoluciones;
  // Movimientos adicionales
  final double cancelacionesEfectivo;
  final double ingresosManual;
  // Gastos detalle
  final List<Map<String, dynamic>> gastosDetalle;
  // Ventas detalle (productos por transacción)
  final List<Map<String, dynamic>> ventasDetalle;
  // Devoluciones detalle
  final List<Map<String, dynamic>> devolucionesDetalle;
  // Abonos detalle (monto, metodo_pago, cuenta_nombre, hora)
  final List<Map<String, dynamic>> abonosDetalle;
  // Cuentas bancarias del turno
  final List<Map<String, dynamic>> cuentasResumen;
  // Cuadre
  final double montoFinalSistema;
  final double montoFinalReal;
  final double diferencia;
  // Stats
  final int    numTransacciones;
  final int    numCambiosProducto;

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
    required this.ventasMixtoEfectivo,
    required this.ventasTotal,
    required this.gastosTotal,
    // Abonos ← NUEVO
    required this.abonosEfectivo,
    required this.abonosTarjeta,
    required this.abonosTransferencia,
    required this.abonosTotal,
    required this.abonosCreditoEfectivo,
    required this.numAbonos,
    //
    required this.devolucionesEfectivo,
    this.devolucionesDirectasEf = 0,
    this.cambiosCobrarEf = 0,
    this.cambiosDevEf = 0,
    required this.numDevoluciones,
    required this.numCambiosProducto,
    this.cancelacionesEfectivo = 0,
    this.ingresosManual = 0,
    this.gastosDetalle = const [],
    this.ventasDetalle = const [],
    this.devolucionesDetalle = const [],
    this.abonosDetalle = const [],
    this.cuentasResumen = const [],
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
    saldoInicial:          double.tryParse(j['saldo_inicial']?.toString()              ?? '0') ?? 0.0,
    ventasEfectivo:        double.tryParse(j['ventas_efectivo']?.toString()            ?? '0') ?? 0.0,
    ventasTarjeta:         double.tryParse(j['ventas_tarjeta']?.toString()             ?? '0') ?? 0.0,
    ventasTransferencia:   double.tryParse(j['ventas_transferencia']?.toString()       ?? '0') ?? 0.0,
    ventasMixto:           double.tryParse(j['ventas_mixto']?.toString()               ?? '0') ?? 0.0,
    ventasMixtoEfectivo:   double.tryParse(j['ventas_mixto_efectivo']?.toString()    ?? '0') ?? 0.0,
    ventasTotal:           double.tryParse(j['ventas_total']?.toString()               ?? '0') ?? 0.0,
    gastosTotal:           double.tryParse(j['gastos_total']?.toString()               ?? '0') ?? 0.0,
    // Abonos ← NUEVO
    abonosEfectivo:        double.tryParse(j['abonos_efectivo']?.toString()            ?? '0') ?? 0.0,
    abonosTarjeta:         double.tryParse(j['abonos_tarjeta']?.toString()             ?? '0') ?? 0.0,
    abonosTransferencia:   double.tryParse(j['abonos_transferencia']?.toString()       ?? '0') ?? 0.0,
    abonosTotal:           double.tryParse(j['abonos_total']?.toString()               ?? '0') ?? 0.0,
    abonosCreditoEfectivo: double.tryParse(j['abonos_credito_efectivo']?.toString() ?? '0') ?? 0.0,
    numAbonos:             (j['num_abonos']        as num?)?.toInt() ?? 0,
    //
    devolucionesEfectivo:    double.tryParse(j['devoluciones_efectivo']?.toString()      ?? '0') ?? 0.0,
    devolucionesDirectasEf:  double.tryParse(j['devoluciones_directas_ef']?.toString()  ?? '0') ?? 0.0,
    cambiosCobrarEf:         double.tryParse(j['cambios_cobrar_ef']?.toString()          ?? '0') ?? 0.0,
    cambiosDevEf:            double.tryParse(j['cambios_devolver_ef']?.toString()        ?? '0') ?? 0.0,
    numDevoluciones:         (j['num_devoluciones']       as num?)?.toInt() ?? 0,
    numCambiosProducto:      (j['num_cambios_producto']   as num?)?.toInt() ?? 0,
    cancelacionesEfectivo:   double.tryParse(j['cancelaciones_efectivo']?.toString()     ?? '0') ?? 0.0,
    ingresosManual:          double.tryParse(j['ingresos_manual']?.toString()            ?? '0') ?? 0.0,
    gastosDetalle:           (j['gastos_detalle'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
    ventasDetalle:           (j['ventas_detalle'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
    devolucionesDetalle:     (j['devoluciones_detalle'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
    abonosDetalle:           (j['abonos_detalle'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
    montoFinalSistema:     double.tryParse(
                             (j['monto_esperado'] ?? j['monto_final_sistema'])?.toString() ?? '0') ?? 0.0,
    montoFinalReal:        double.tryParse(j['monto_final_real']?.toString()           ?? '0') ?? 0.0,
    diferencia:            double.tryParse(j['diferencia']?.toString()                 ?? '0') ?? 0.0,
    numTransacciones:      (j['num_transacciones'] as num?)?.toInt() ?? 0,
  );
}