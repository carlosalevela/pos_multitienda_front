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
  final double ventasMixtoTarjeta;
  final double ventasMixtoTransferencia;
  final double ventasBono;
  final int    ventasBonoNum;
  final double ventasBonoEfectivo;
  final double ventasBonoTarjeta;
  final double ventasBonoTransferencia;
  final double ventasBonoDifBonoParte;
  final int    ventasBonoDifNum;
  final double ventasTotal;
  // Gastos
  final double gastosTotal;
  final int    numGastos;
  // Abonos posteriores (ABONOS PAGOS CLIENTES)
  final double abonosEfectivo;
  final double abonosTarjeta;
  final double abonosTransferencia;
  final double abonosTotal;
  final double abonosCreditoEfectivo;
  final int    numAbonos;
  // Depósitos iniciales (INGRESOS SEPARADOS)
  final double ingresosSepEfectivo;
  final double ingresosSepTarjeta;
  final double ingresosSepTransferencia;
  final int    numIngresosSep;
  // Devoluciones
  final double devolucionesEfectivo;
  final double devolucionesDirectasEf;
  final double cambiosCobrarEf;
  final double cambiosDevEf;
  final double cambiosCobrarTar;
  final double cambiosDevTar;
  final double cambiosCobrarTra;
  final double cambiosDevTra;
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
  // Compra de bonos
  final double compraBonasEfectivo;
  final double compraBonaTarjeta;
  final double compraBonasTransferencia;
  final double compraBonasTotal;
  final int    numCompraBonos;
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
    this.ventasMixtoTarjeta       = 0,
    this.ventasMixtoTransferencia = 0,
    this.ventasBono = 0,
    this.ventasBonoNum = 0,
    this.ventasBonoEfectivo = 0,
    this.ventasBonoTarjeta = 0,
    this.ventasBonoTransferencia = 0,
    this.ventasBonoDifBonoParte = 0,
    this.ventasBonoDifNum = 0,
    required this.ventasTotal,
    required this.gastosTotal,
    this.numGastos = 0,
    // Abonos posteriores
    required this.abonosEfectivo,
    required this.abonosTarjeta,
    required this.abonosTransferencia,
    required this.abonosTotal,
    required this.abonosCreditoEfectivo,
    required this.numAbonos,
    // Depósitos iniciales
    this.ingresosSepEfectivo = 0,
    this.ingresosSepTarjeta = 0,
    this.ingresosSepTransferencia = 0,
    this.numIngresosSep = 0,
    //
    required this.devolucionesEfectivo,
    this.devolucionesDirectasEf = 0,
    this.cambiosCobrarEf  = 0,
    this.cambiosDevEf     = 0,
    this.cambiosCobrarTar = 0,
    this.cambiosDevTar    = 0,
    this.cambiosCobrarTra = 0,
    this.cambiosDevTra    = 0,
    required this.numDevoluciones,
    required this.numCambiosProducto,
    this.cancelacionesEfectivo = 0,
    this.ingresosManual = 0,
    this.gastosDetalle = const [],
    this.ventasDetalle = const [],
    this.devolucionesDetalle = const [],
    this.abonosDetalle = const [],
    this.cuentasResumen = const [],
    this.compraBonasEfectivo = 0,
    this.compraBonaTarjeta = 0,
    this.compraBonasTransferencia = 0,
    this.compraBonasTotal = 0,
    this.numCompraBonos = 0,
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
    ventasMixtoEfectivo:     double.tryParse(j['ventas_mixto_efectivo']?.toString()      ?? '0') ?? 0.0,
    ventasMixtoTarjeta:      double.tryParse(j['ventas_mixto_tarjeta']?.toString()       ?? '0') ?? 0.0,
    ventasMixtoTransferencia:double.tryParse(j['ventas_mixto_transferencia']?.toString() ?? '0') ?? 0.0,
    ventasBono:               double.tryParse(j['ventas_bono']?.toString()                   ?? '0') ?? 0.0,
    ventasBonoNum:            (j['ventas_bono_num'] as num?)?.toInt() ?? 0,
    ventasBonoEfectivo:       double.tryParse(j['ventas_bono_efectivo']?.toString()          ?? '0') ?? 0.0,
    ventasBonoTarjeta:        double.tryParse(j['ventas_bono_tarjeta']?.toString()           ?? '0') ?? 0.0,
    ventasBonoTransferencia:  double.tryParse(j['ventas_bono_transferencia']?.toString()     ?? '0') ?? 0.0,
    ventasBonoDifBonoParte:   double.tryParse(j['ventas_bono_dif_bono_parte']?.toString()    ?? '0') ?? 0.0,
    ventasBonoDifNum:         (j['ventas_bono_dif_num'] as num?)?.toInt() ?? 0,
    ventasTotal:           double.tryParse(j['ventas_total']?.toString()               ?? '0') ?? 0.0,
    gastosTotal:           double.tryParse(j['gastos_total']?.toString()               ?? '0') ?? 0.0,
    numGastos:             (j['num_gastos'] as num?)?.toInt() ?? 0,
    abonosEfectivo:           double.tryParse(j['abonos_efectivo']?.toString()            ?? '0') ?? 0.0,
    abonosTarjeta:            double.tryParse(j['abonos_tarjeta']?.toString()             ?? '0') ?? 0.0,
    abonosTransferencia:      double.tryParse(j['abonos_transferencia']?.toString()       ?? '0') ?? 0.0,
    abonosTotal:              double.tryParse(j['abonos_total']?.toString()               ?? '0') ?? 0.0,
    abonosCreditoEfectivo:    double.tryParse(j['abonos_credito_efectivo']?.toString()    ?? '0') ?? 0.0,
    numAbonos:                (j['num_abonos'] as num?)?.toInt() ?? 0,
    ingresosSepEfectivo:      double.tryParse(j['ingresos_sep_efectivo']?.toString()      ?? '0') ?? 0.0,
    ingresosSepTarjeta:       double.tryParse(j['ingresos_sep_tarjeta']?.toString()       ?? '0') ?? 0.0,
    ingresosSepTransferencia: double.tryParse(j['ingresos_sep_transferencia']?.toString() ?? '0') ?? 0.0,
    numIngresosSep:           (j['num_ingresos_sep'] as num?)?.toInt() ?? 0,
    //
    devolucionesEfectivo:    double.tryParse(j['devoluciones_efectivo']?.toString()       ?? '0') ?? 0.0,
    devolucionesDirectasEf:  double.tryParse(j['devoluciones_directas_ef']?.toString()   ?? '0') ?? 0.0,
    cambiosCobrarEf:         double.tryParse(j['cambios_cobrar_ef']?.toString()           ?? '0') ?? 0.0,
    cambiosDevEf:            double.tryParse(j['cambios_devolver_ef']?.toString()         ?? '0') ?? 0.0,
    cambiosCobrarTar:        double.tryParse(j['cambios_cobrar_tar']?.toString()          ?? '0') ?? 0.0,
    cambiosDevTar:           double.tryParse(j['cambios_devolver_tar']?.toString()        ?? '0') ?? 0.0,
    cambiosCobrarTra:        double.tryParse(j['cambios_cobrar_tra']?.toString()          ?? '0') ?? 0.0,
    cambiosDevTra:           double.tryParse(j['cambios_devolver_tra']?.toString()        ?? '0') ?? 0.0,
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
    cuentasResumen:          (j['cuentas_resumen'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
    compraBonasEfectivo:      double.tryParse(j['compra_bonos_efectivo']?.toString()       ?? '0') ?? 0.0,
    compraBonaTarjeta:        double.tryParse(j['compra_bonos_tarjeta']?.toString()        ?? '0') ?? 0.0,
    compraBonasTransferencia: double.tryParse(j['compra_bonos_transferencia']?.toString()  ?? '0') ?? 0.0,
    compraBonasTotal:         double.tryParse(j['compra_bonos_total']?.toString()          ?? '0') ?? 0.0,
    numCompraBonos:           (j['num_compra_bonos'] as num?)?.toInt() ?? 0,
    montoFinalSistema:     double.tryParse(
                             (j['monto_esperado'] ?? j['monto_final_sistema'])?.toString() ?? '0') ?? 0.0,
    montoFinalReal:        double.tryParse(j['monto_final_real']?.toString()           ?? '0') ?? 0.0,
    diferencia:            double.tryParse(j['diferencia']?.toString()                 ?? '0') ?? 0.0,
    numTransacciones:      (j['num_transacciones'] as num?)?.toInt() ?? 0,
  );

  double get netoCambiosTarjeta       => cambiosCobrarTar - cambiosDevTar;
  double get netoCambiosTransferencia => cambiosCobrarTra - cambiosDevTra;
}