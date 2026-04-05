class VentasCierre {
  final double efectivo, tarjeta, transferencia, mixto, total;
  final int numTransacciones;

  VentasCierre({
    required this.efectivo, required this.tarjeta,
    required this.transferencia, required this.mixto,
    required this.total, required this.numTransacciones,
  });

  // ✅ tryParse — aguanta String y num del backend
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
  final double total, efectivo, transferencia; // ✅ breakdown por método
  final int    cantidad;

  AbonosCierre({
    required this.total,
    required this.efectivo,
    required this.transferencia,
    required this.cantidad,
  });

  factory AbonosCierre.fromJson(Map<String, dynamic> j) => AbonosCierre(
    total:         double.tryParse(j['total']?.toString()         ?? '0') ?? 0.0,
    efectivo:      double.tryParse(j['efectivo']?.toString()      ?? '0') ?? 0.0,
    transferencia: double.tryParse(j['transferencia']?.toString() ?? '0') ?? 0.0,
    cantidad:      j['cantidad'] ?? 0,
  );

  factory AbonosCierre.vacio() => AbonosCierre(
    total: 0, efectivo: 0, transferencia: 0, cantidad: 0);
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


class ResumenCierre {
  final int    sesionId;
  final String tiendaNombre, empleadoNombre, fechaApertura;
  final double montoInicial, montoEsperadoCaja;
  final VentasCierre ventas;
  final GastosCierre gastos;
  final AbonosCierre abonos;

  ResumenCierre({
    required this.sesionId,       required this.tiendaNombre,
    required this.empleadoNombre, required this.fechaApertura,
    required this.montoInicial,   required this.montoEsperadoCaja,
    required this.ventas,         required this.gastos,
    required this.abonos,
  });

  factory ResumenCierre.fromJson(Map<String, dynamic> j) => ResumenCierre(
    sesionId:          j['sesion_id']      ?? 0,
    tiendaNombre:      j['tienda_nombre']  ?? '',
    empleadoNombre:    j['empleado_nombre'] ?? '',
    fechaApertura:     j['fecha_apertura'] ?? '',
    montoInicial:      double.tryParse(j['monto_inicial']?.toString()       ?? '0') ?? 0.0,
    montoEsperadoCaja: double.tryParse(j['monto_esperado_caja']?.toString() ?? '0') ?? 0.0,
    abonos: j['abonos'] != null
        ? AbonosCierre.fromJson(j['abonos'])
        : AbonosCierre.vacio(),
    ventas: VentasCierre.fromJson(j['ventas'] ?? {}),
    gastos: GastosCierre.fromJson(j['gastos'] ?? {}),
  );
}