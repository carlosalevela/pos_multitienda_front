class VentasCierre {
  final double efectivo, tarjeta, transferencia, mixto, total;
  final int numTransacciones;

  VentasCierre({
    required this.efectivo, required this.tarjeta,
    required this.transferencia, required this.mixto,
    required this.total, required this.numTransacciones,
  });

  factory VentasCierre.fromJson(Map<String, dynamic> j) => VentasCierre(
    efectivo:         double.tryParse(j['efectivo']?.toString()      ?? '0') ?? 0.0,
    tarjeta:          double.tryParse(j['tarjeta']?.toString()       ?? '0') ?? 0.0,
    transferencia:    double.tryParse(j['transferencia']?.toString() ?? '0') ?? 0.0,
    mixto:            double.tryParse(j['mixto']?.toString()         ?? '0') ?? 0.0,
    total:            double.tryParse(j['total']?.toString()         ?? '0') ?? 0.0,
    numTransacciones: j['num_transacciones'] ?? 0,
  );
}


class AbonosCierre {
  final double total, efectivo, transferencia;
  final int    cantidad;

  AbonosCierre({
    required this.total, required this.efectivo,
    required this.transferencia, required this.cantidad,
  });

  factory AbonosCierre.fromJson(Map<String, dynamic> j) => AbonosCierre(
    total:         double.tryParse(j['total']?.toString()         ?? '0') ?? 0.0,
    efectivo:      double.tryParse(j['efectivo']?.toString()      ?? '0') ?? 0.0,
    transferencia: double.tryParse(j['transferencia']?.toString() ?? '0') ?? 0.0,
    cantidad:      j['cantidad'] ?? 0,
  );

  factory AbonosCierre.vacio() =>
      AbonosCierre(total: 0, efectivo: 0, transferencia: 0, cantidad: 0);
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
  final List<GastoDetalle> detalle;

  GastosCierre({
    required this.efectivo, required this.otros,
    required this.total,    required this.detalle,
  });

  factory GastosCierre.fromJson(Map<String, dynamic> j) => GastosCierre(
    efectivo: double.tryParse(j['efectivo']?.toString() ?? '0') ?? 0.0,
    otros:    double.tryParse(j['otros']?.toString()    ?? '0') ?? 0.0,
    total:    double.tryParse(j['total']?.toString()    ?? '0') ?? 0.0,
    detalle:  (j['detalle'] as List? ?? [])
        .map((e) => GastoDetalle.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}


// ── NUEVO ─────────────────────────────────────────────────────
class DevolucionesCierre {
  final double efectivo, cambiosCobrar, cambiosDevolver, netoEfectivo;
  final int    cantidad;
  final int    cambiosProducto;

  DevolucionesCierre({
    required this.efectivo,
    required this.cambiosCobrar,
    required this.cambiosDevolver,
    required this.netoEfectivo,
    required this.cantidad,
    required this.cambiosProducto,
  });

  factory DevolucionesCierre.fromJson(Map<String, dynamic> j) =>
      DevolucionesCierre(
        efectivo:        double.tryParse(j['efectivo']?.toString()         ?? '0') ?? 0.0,
        cambiosCobrar:   double.tryParse(j['cambios_cobrar']?.toString()   ?? '0') ?? 0.0,
        cambiosDevolver: double.tryParse(j['cambios_devolver']?.toString() ?? '0') ?? 0.0,
        netoEfectivo:    double.tryParse(j['neto_efectivo']?.toString()    ?? '0') ?? 0.0,
        cantidad:        (j['cantidad'] as num?)?.toInt() ?? 0,
        cambiosProducto: (j['cambios_producto'] as num?)?.toInt() ?? 0,  // ← AGREGAR
      );

  factory DevolucionesCierre.vacio() => DevolucionesCierre(
      efectivo: 0, cambiosCobrar: 0,
      cambiosDevolver: 0, netoEfectivo: 0, cantidad: 0, cambiosProducto: 0);
}


class ResumenCierre {
  final int    sesionId;
  final String tiendaNombre, empleadoNombre, fechaApertura;
  final double montoInicial, montoEsperadoCaja;
  final VentasCierre      ventas;
  final GastosCierre      gastos;
  final AbonosCierre      abonos;
  final DevolucionesCierre devoluciones;  // ← NUEVO

  ResumenCierre({
    required this.sesionId,       required this.tiendaNombre,
    required this.empleadoNombre, required this.fechaApertura,
    required this.montoInicial,   required this.montoEsperadoCaja,
    required this.ventas,         required this.gastos,
    required this.abonos,
    required this.devoluciones,   // ← NUEVO
  });

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
    devoluciones: j['devoluciones'] != null           // ← NUEVO
        ? DevolucionesCierre.fromJson(j['devoluciones'])
        : DevolucionesCierre.vacio(),
  );
}