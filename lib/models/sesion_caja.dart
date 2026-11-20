class SesionCaja {
  final int     id;
  final String  estado;
  final double  saldo_inicial;
  final double  saldo_final;
  final DateTime  fecha_apertura;
  final DateTime? fecha_cierre;
  // KPIs from SesionCajaSerializer (populated by /caja/activa/{id}/)
  final double ventasTotal;
  final double ventasEfectivo;
  final double ventasTarjeta;
  final double ventasTransferencia;
  final double ventasMixtoEfectivo;
  final double ventasBono;
  final int    numTransacciones;
  final double gastosTotal;
  final int    numGastos;
  final double montoEsperado;
  final String tiendaNombre;
  final String empleadoNombre;
  // Abonos posteriores (ABONOS PAGOS CLIENTES)
  final double abonosTotal;
  final double abonosEfectivo;
  final double abonosTarjeta;
  final double abonosTransferencia;
  final int    numAbonos;
  // Depósitos iniciales (INGRESOS SEPARADOS)
  final double ingresosSepEfectivo;
  final double ingresosSepTarjeta;
  final double ingresosSepTransferencia;
  final int    numIngresosSep;
  // Devoluciones por método de pago
  final double cambiosCobrarEf;
  final double cambiosCobrarTar;
  final double cambiosDevTar;
  final double cambiosCobrarTra;
  final double cambiosDevTra;
  final String observaciones;

  SesionCaja({
    required this.id,
    required this.estado,
    required this.saldo_inicial,
    required this.saldo_final,
    required this.fecha_apertura,
    this.fecha_cierre,
    this.ventasTotal         = 0,
    this.ventasEfectivo      = 0,
    this.ventasTarjeta       = 0,
    this.ventasTransferencia = 0,
    this.ventasMixtoEfectivo = 0,
    this.ventasBono          = 0,
    this.numTransacciones    = 0,
    this.gastosTotal         = 0,
    this.numGastos           = 0,
    this.montoEsperado       = 0,
    this.tiendaNombre        = '',
    this.empleadoNombre      = '',
    this.abonosTotal              = 0,
    this.abonosEfectivo           = 0,
    this.abonosTarjeta            = 0,
    this.abonosTransferencia      = 0,
    this.numAbonos                = 0,
    this.ingresosSepEfectivo      = 0,
    this.ingresosSepTarjeta       = 0,
    this.ingresosSepTransferencia = 0,
    this.numIngresosSep           = 0,
    this.cambiosCobrarEf     = 0,
    this.cambiosCobrarTar    = 0,
    this.cambiosDevTar       = 0,
    this.cambiosCobrarTra    = 0,
    this.cambiosDevTra       = 0,
    this.observaciones       = '',
  });

  double get netoCambiosTarjeta       => cambiosCobrarTar - cambiosDevTar;
  double get netoCambiosTransferencia => cambiosCobrarTra - cambiosDevTra;

  factory SesionCaja.fromJson(Map<String, dynamic> json) => SesionCaja(
    id: (json['sesion_id'] ?? json['id'] ?? 0) as int,
    estado: json['estado'] ?? 'abierta',
    saldo_inicial: double.parse(
        (json['monto_inicial'] ?? json['saldo_inicial'] ?? 0).toString()),
    saldo_final: double.parse(
        (json['monto_final_real'] ?? json['saldo_final'] ?? 0).toString()),
    fecha_apertura: DateTime.parse(
        json['fecha_apertura'] ?? DateTime.now().toIso8601String()).toLocal(),
    fecha_cierre: json['fecha_cierre'] != null
        ? DateTime.parse(json['fecha_cierre']).toLocal()
        : null,
    ventasTotal:         double.tryParse(json['ventas_total']?.toString()         ?? '0') ?? 0,
    ventasEfectivo:      double.tryParse(json['ventas_efectivo']?.toString()      ?? '0') ?? 0,
    ventasTarjeta:       double.tryParse(json['ventas_tarjeta']?.toString()       ?? '0') ?? 0,
    ventasTransferencia: double.tryParse(json['ventas_transferencia']?.toString() ?? '0') ?? 0,
    ventasMixtoEfectivo: double.tryParse(json['ventas_mixto_efectivo']?.toString() ?? '0') ?? 0,
    ventasBono:          double.tryParse(json['ventas_bono']?.toString()          ?? '0') ?? 0,
    numTransacciones:    (json['num_transacciones'] as num?)?.toInt()                      ?? 0,
    gastosTotal:         double.tryParse(json['gastos_total']?.toString()         ?? '0') ?? 0,
    numGastos:           (json['num_gastos'] as num?)?.toInt()                           ?? 0,
    montoEsperado:       double.tryParse(json['monto_esperado']?.toString()
                           ?? json['monto_final_sistema']?.toString()             ?? '0') ?? 0,
    tiendaNombre:        json['tienda_nombre']   ?? '',
    empleadoNombre:      json['empleado_nombre'] ?? '',
    abonosTotal:              double.tryParse(json['abonos_total']?.toString()              ?? '0') ?? 0,
    abonosEfectivo:           double.tryParse(json['abonos_efectivo']?.toString()           ?? '0') ?? 0,
    abonosTarjeta:            double.tryParse(json['abonos_tarjeta']?.toString()            ?? '0') ?? 0,
    abonosTransferencia:      double.tryParse(json['abonos_transferencia']?.toString()      ?? '0') ?? 0,
    numAbonos:                (json['num_abonos'] as num?)?.toInt()                                  ?? 0,
    ingresosSepEfectivo:      double.tryParse(json['ingresos_sep_efectivo']?.toString()      ?? '0') ?? 0,
    ingresosSepTarjeta:       double.tryParse(json['ingresos_sep_tarjeta']?.toString()       ?? '0') ?? 0,
    ingresosSepTransferencia: double.tryParse(json['ingresos_sep_transferencia']?.toString() ?? '0') ?? 0,
    numIngresosSep:           (json['num_ingresos_sep'] as num?)?.toInt()                            ?? 0,
    cambiosCobrarEf:     double.tryParse(
                           (json['devoluciones']?['cambios_cobrar']
                            ?? json['cambios_cobrar_ef'])?.toString() ?? '0') ?? 0,
    cambiosCobrarTar:    double.tryParse(
                           (json['devoluciones']?['cambios_cobrar_tar']
                            ?? json['cambios_cobrar_tar'])?.toString() ?? '0') ?? 0,
    cambiosDevTar:       double.tryParse(
                           (json['devoluciones']?['cambios_devolver_tar']
                            ?? json['cambios_devolver_tar'])?.toString() ?? '0') ?? 0,
    cambiosCobrarTra:    double.tryParse(
                           (json['devoluciones']?['cambios_cobrar_tra']
                            ?? json['cambios_cobrar_tra'])?.toString() ?? '0') ?? 0,
    cambiosDevTra:       double.tryParse(
                           (json['devoluciones']?['cambios_devolver_tra']
                            ?? json['cambios_devolver_tra'])?.toString() ?? '0') ?? 0,
    observaciones:       json['observaciones']?.toString() ?? '',
  );

  bool get abierta => estado == 'abierta';
}
