class VentasCierre {
  final double efectivo, tarjeta, transferencia, mixto, mixtoEfectivo, bono, total;
  final double bonoEfectivo, bonoTarjeta, bonoTransferencia;
  final int    numTransacciones, bonoNum;
  // Porción bono usada en transacciones mixtas (bono + efectivo/tarjeta/transferencia)
  final double bonoDifBonoParte;
  final int    bonoDifNum;

  VentasCierre({
    required this.efectivo, required this.tarjeta,
    required this.transferencia, required this.mixto,
    required this.mixtoEfectivo, this.bono = 0, this.bonoNum = 0,
    this.bonoEfectivo = 0, this.bonoTarjeta = 0, this.bonoTransferencia = 0,
    this.bonoDifBonoParte = 0, this.bonoDifNum = 0,
    required this.total, required this.numTransacciones,
  });

  factory VentasCierre.fromJson(Map<String, dynamic> j) => VentasCierre(
    efectivo:          double.tryParse(j['efectivo']?.toString()               ?? '0') ?? 0.0,
    tarjeta:           double.tryParse(j['tarjeta']?.toString()                ?? '0') ?? 0.0,
    transferencia:     double.tryParse(j['transferencia']?.toString()          ?? '0') ?? 0.0,
    mixto:             double.tryParse(j['mixto']?.toString()                  ?? '0') ?? 0.0,
    mixtoEfectivo:     double.tryParse(j['mixto_efectivo']?.toString()         ?? '0') ?? 0.0,
    bono:              double.tryParse(j['bono']?.toString()                   ?? '0') ?? 0.0,
    bonoNum:           (j['bono_num'] as num?)?.toInt() ?? 0,
    bonoEfectivo:      double.tryParse(j['bono_efectivo']?.toString()          ?? '0') ?? 0.0,
    bonoTarjeta:       double.tryParse(j['bono_tarjeta']?.toString()           ?? '0') ?? 0.0,
    bonoTransferencia: double.tryParse(j['bono_transferencia']?.toString()     ?? '0') ?? 0.0,
    bonoDifBonoParte:  double.tryParse(j['bono_dif_bono_parte']?.toString()    ?? '0') ?? 0.0,
    bonoDifNum:        (j['bono_dif_num'] as num?)?.toInt() ?? 0,
    total:             double.tryParse(j['total']?.toString()                  ?? '0') ?? 0.0,
    numTransacciones:  j['num_transacciones'] ?? 0,
  );
}


class AbonosCierre {
  // Abonos posteriores → ABONOS PAGOS CLIENTES
  final double total, efectivo, transferencia, tarjeta, creditoEfectivo;
  final double cancelacionesEfectivo, ingresosManual;
  final int    cantidad;
  final List<Map<String, dynamic>> detalle;
  // Depósitos iniciales → INGRESOS SEPARADOS
  final double ingresosSepEfectivo, ingresosSepTarjeta, ingresosSepTransferencia;
  final int    numIngresosSep;

  AbonosCierre({
    required this.total, required this.efectivo,
    required this.transferencia, required this.tarjeta,
    required this.creditoEfectivo, required this.cantidad,
    this.cancelacionesEfectivo = 0, this.ingresosManual = 0,
    this.detalle = const [],
    this.ingresosSepEfectivo = 0, this.ingresosSepTarjeta = 0,
    this.ingresosSepTransferencia = 0, this.numIngresosSep = 0,
  });

  factory AbonosCierre.fromJson(Map<String, dynamic> j) => AbonosCierre(
    total:                  double.tryParse(j['total']?.toString()                  ?? '0') ?? 0.0,
    efectivo:               double.tryParse(j['efectivo']?.toString()               ?? '0') ?? 0.0,
    transferencia:          double.tryParse(j['transferencia']?.toString()           ?? '0') ?? 0.0,
    tarjeta:                double.tryParse(j['tarjeta']?.toString()                ?? '0') ?? 0.0,
    creditoEfectivo:        double.tryParse(j['credito_efectivo']?.toString()       ?? '0') ?? 0.0,
    cancelacionesEfectivo:  double.tryParse(j['cancelaciones_efectivo']?.toString() ?? '0') ?? 0.0,
    ingresosManual:         double.tryParse(j['ingresos_manual']?.toString()        ?? '0') ?? 0.0,
    cantidad:               j['cantidad'] ?? 0,
    detalle:                (j['detalle'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
    ingresosSepEfectivo:      double.tryParse(j['ingreso_sep_efectivo']?.toString()      ?? '0') ?? 0.0,
    ingresosSepTarjeta:       double.tryParse(j['ingreso_sep_tarjeta']?.toString()       ?? '0') ?? 0.0,
    ingresosSepTransferencia: double.tryParse(j['ingreso_sep_transferencia']?.toString() ?? '0') ?? 0.0,
    numIngresosSep:           (j['num_ingresos_sep'] as num?)?.toInt() ?? 0,
  );

  factory AbonosCierre.vacio() => AbonosCierre(
      total: 0, efectivo: 0, transferencia: 0, tarjeta: 0, creditoEfectivo: 0, cantidad: 0);
}


class GastoDetalle {
  final String categoria, metodoPago;
  final double monto;

  GastoDetalle({
    required this.categoria, required this.metodoPago, required this.monto,
  });

  factory GastoDetalle.fromJson(Map<String, dynamic> j) => GastoDetalle(
    categoria:  j['categoria']   ?? '',
    metodoPago: j['metodo_pago'] ?? '',
    monto:      double.tryParse(j['monto']?.toString() ?? '0') ?? 0.0,
  );
}


class GastosCierre {
  final double efectivo, otros, total;
  final int    cantidad;
  final List<GastoDetalle> detalle;

  GastosCierre({
    required this.efectivo, required this.otros,
    required this.total,    required this.detalle,
    this.cantidad = 0,
  });

  factory GastosCierre.fromJson(Map<String, dynamic> j) => GastosCierre(
    efectivo: double.tryParse(j['efectivo']?.toString() ?? '0') ?? 0.0,
    otros:    double.tryParse(j['otros']?.toString()    ?? '0') ?? 0.0,
    total:    double.tryParse(j['total']?.toString()    ?? '0') ?? 0.0,
    cantidad: (j['cantidad'] as num?)?.toInt() ?? 0,
    detalle:  (j['detalle'] as List? ?? [])
        .map((e) => GastoDetalle.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}


// ── NUEVO ─────────────────────────────────────────────────────
class DevolucionesCierre {
  final double efectivo, cambiosCobrar, cambiosDevolver, netoEfectivo;
  final double cambiosCobrarTar, cambiosDevTar;
  final double cambiosCobrarTra, cambiosDevTra;
  final int    cantidad;
  final int    cambiosProducto;
  final List<Map<String, dynamic>> detalle;

  DevolucionesCierre({
    required this.efectivo,
    required this.cambiosCobrar,
    required this.cambiosDevolver,
    required this.netoEfectivo,
    this.cambiosCobrarTar = 0,
    this.cambiosDevTar    = 0,
    this.cambiosCobrarTra = 0,
    this.cambiosDevTra    = 0,
    required this.cantidad,
    required this.cambiosProducto,
    this.detalle = const [],
  });

  double get netoCambiosTarjeta      => cambiosCobrarTar - cambiosDevTar;
  double get netoCambiosTransferencia => cambiosCobrarTra - cambiosDevTra;

  factory DevolucionesCierre.fromJson(Map<String, dynamic> j) =>
      DevolucionesCierre(
        efectivo:         double.tryParse(j['efectivo']?.toString()            ?? '0') ?? 0.0,
        cambiosCobrar:    double.tryParse(j['cambios_cobrar']?.toString()      ?? '0') ?? 0.0,
        cambiosDevolver:  double.tryParse(j['cambios_devolver']?.toString()    ?? '0') ?? 0.0,
        netoEfectivo:     double.tryParse(j['neto_efectivo']?.toString()       ?? '0') ?? 0.0,
        cambiosCobrarTar: double.tryParse(j['cambios_cobrar_tar']?.toString()  ?? '0') ?? 0.0,
        cambiosDevTar:    double.tryParse(j['cambios_devolver_tar']?.toString() ?? '0') ?? 0.0,
        cambiosCobrarTra: double.tryParse(j['cambios_cobrar_tra']?.toString()  ?? '0') ?? 0.0,
        cambiosDevTra:    double.tryParse(j['cambios_devolver_tra']?.toString() ?? '0') ?? 0.0,
        cantidad:         (j['cantidad'] as num?)?.toInt() ?? 0,
        cambiosProducto:  (j['cambios_producto'] as num?)?.toInt() ?? 0,
        detalle:          (j['detalle'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? const [],
      );

  factory DevolucionesCierre.vacio() => DevolucionesCierre(
      efectivo: 0, cambiosCobrar: 0,
      cambiosDevolver: 0, netoEfectivo: 0, cantidad: 0, cambiosProducto: 0);
}


class AnulacionesCierre {
  final int    cantidad;
  final double totalAnulado;
  final List<Map<String, dynamic>> detalle;

  AnulacionesCierre({
    required this.cantidad,
    required this.totalAnulado,
    this.detalle = const [],
  });

  factory AnulacionesCierre.fromJson(Map<String, dynamic> j) => AnulacionesCierre(
    cantidad:     (j['cantidad'] as num?)?.toInt() ?? 0,
    totalAnulado: double.tryParse(j['total_anulado']?.toString() ?? '0') ?? 0.0,
    detalle:      (j['detalle'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
  );

  factory AnulacionesCierre.vacio() =>
      AnulacionesCierre(cantidad: 0, totalAnulado: 0);
}


class CompraBonos {
  final double efectivo, tarjeta, transferencia, total;
  final int    cantidad;

  CompraBonos({
    this.efectivo = 0, this.tarjeta = 0,
    this.transferencia = 0, this.total = 0, this.cantidad = 0,
  });

  factory CompraBonos.fromJson(Map<String, dynamic> j) => CompraBonos(
    efectivo:      (j['efectivo']      as num?)?.toDouble() ?? 0,
    tarjeta:       (j['tarjeta']       as num?)?.toDouble() ?? 0,
    transferencia: (j['transferencia'] as num?)?.toDouble() ?? 0,
    total:         (j['total']         as num?)?.toDouble() ?? 0,
    cantidad:      (j['cantidad']      as num?)?.toInt()    ?? 0,
  );

  static CompraBonos get empty => CompraBonos();
}


class ResumenCierre {
  final int    sesionId;
  final String tiendaNombre, empleadoNombre, fechaApertura;
  final double montoInicial, montoEsperadoCaja;
  final VentasCierre       ventas;
  final GastosCierre       gastos;
  final AbonosCierre       abonos;
  final DevolucionesCierre devoluciones;
  final AnulacionesCierre  anulaciones;
  final CompraBonos        compraBonos;
  final List<Map<String, dynamic>> ventasDetalle;

  ResumenCierre({
    required this.sesionId,       required this.tiendaNombre,
    required this.empleadoNombre, required this.fechaApertura,
    required this.montoInicial,   required this.montoEsperadoCaja,
    required this.ventas,         required this.gastos,
    required this.abonos,         required this.devoluciones,
    AnulacionesCierre? anulaciones,
    CompraBonos? compraBonos,
    this.ventasDetalle = const [],
  }) : anulaciones = anulaciones ?? AnulacionesCierre.vacio(),
       compraBonos = compraBonos ?? CompraBonos.empty;

  factory ResumenCierre.fromJson(Map<String, dynamic> j) => ResumenCierre(
    sesionId:          j['sesion_id']       ?? 0,
    tiendaNombre:      j['tienda_nombre']   ?? '',
    empleadoNombre:    j['empleado_nombre'] ?? '',
    fechaApertura:     j['fecha_apertura']  ?? '',
    montoInicial:      double.tryParse(j['monto_inicial']?.toString()       ?? '0') ?? 0.0,
    montoEsperadoCaja: double.tryParse(j['monto_esperado_caja']?.toString() ?? '0') ?? 0.0,
    ventas:       VentasCierre.fromJson(j['ventas']   ?? {}),
    gastos:       GastosCierre.fromJson(j['gastos']   ?? {}),
    abonos:       j['abonos'] != null
        ? AbonosCierre.fromJson(j['abonos'])
        : AbonosCierre.vacio(),
    devoluciones: j['devoluciones'] != null
        ? DevolucionesCierre.fromJson(j['devoluciones'])
        : DevolucionesCierre.vacio(),
    anulaciones: j['anulaciones'] != null
        ? AnulacionesCierre.fromJson(j['anulaciones'])
        : AnulacionesCierre.vacio(),
    compraBonos: j['compra_bonos'] != null
        ? CompraBonos.fromJson(j['compra_bonos'] as Map<String, dynamic>)
        : CompraBonos.empty,
    ventasDetalle: (j['ventas_detalle'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
  );
}