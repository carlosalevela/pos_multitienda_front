class VentasCierre {
  final double efectivo, tarjeta, transferencia, mixto, total;
  final int numTransacciones;

  VentasCierre({
    required this.efectivo, required this.tarjeta,
    required this.transferencia, required this.mixto,
    required this.total, required this.numTransacciones,
  });

  factory VentasCierre.fromJson(Map<String, dynamic> j) => VentasCierre(
    efectivo:         (j['efectivo']      ?? 0).toDouble(),
    tarjeta:          (j['tarjeta']       ?? 0).toDouble(),
    transferencia:    (j['transferencia'] ?? 0).toDouble(),
    mixto:            (j['mixto']         ?? 0).toDouble(),
    total:            (j['total']         ?? 0).toDouble(),
    numTransacciones: j['num_transacciones'] ?? 0,
  );
}

class GastoDetalle {
  final String categoria, metodoPago;
  final double monto;

  GastoDetalle({
    required this.categoria, required this.metodoPago, required this.monto,
  });

  factory GastoDetalle.fromJson(Map<String, dynamic> j) => GastoDetalle(
    categoria:  j['categoria']  ?? '',
    metodoPago: j['metodo_pago'] ?? '',
    monto:      double.parse((j['monto'] ?? '0').toString()),
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
    efectivo: (j['efectivo'] ?? 0).toDouble(),
    otros:    (j['otros']    ?? 0).toDouble(),
    total:    (j['total']    ?? 0).toDouble(),
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

  ResumenCierre({
    required this.sesionId,       required this.tiendaNombre,
    required this.empleadoNombre, required this.fechaApertura,
    required this.montoInicial,   required this.montoEsperadoCaja,
    required this.ventas,         required this.gastos,
  });

  factory ResumenCierre.fromJson(Map<String, dynamic> j) => ResumenCierre(
    sesionId:          j['sesion_id']           ?? 0,
    tiendaNombre:      j['tienda_nombre']        ?? '',
    empleadoNombre:    j['empleado_nombre']      ?? '',
    fechaApertura:     j['fecha_apertura']       ?? '',
    montoInicial:      (j['monto_inicial']       ?? 0).toDouble(),
    montoEsperadoCaja: (j['monto_esperado_caja'] ?? 0).toDouble(),
    ventas:  VentasCierre.fromJson(j['ventas']  ?? {}),
    gastos:  GastosCierre.fromJson(j['gastos']  ?? {}),
  );
}