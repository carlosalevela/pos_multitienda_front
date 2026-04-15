// lib/models/contabilidad_models.dart

// ── ResumenDiario ──────────────────────────────────────

class ResumenDiario {
  final String fecha;
  final double totalVentas;
  final int    numVentas;
  final double totalGastos;
  // ✅ NUEVO
  final double totalDevoluciones;
  final int    numDevoluciones;
  final double totalNeto;
  final double utilidadBruta;
  final List<Map<String, dynamic>> ventasPorMetodo;
  // ✅ NUEVO
  final List<Map<String, dynamic>> devolucionesPorMetodo;

  ResumenDiario({
    required this.fecha,
    required this.totalVentas,
    required this.numVentas,
    required this.totalGastos,
    required this.totalDevoluciones,  // ✅
    required this.numDevoluciones,    // ✅
    required this.totalNeto,          // ✅
    required this.utilidadBruta,
    required this.ventasPorMetodo,
    required this.devolucionesPorMetodo, // ✅
  });

  factory ResumenDiario.fromJson(Map<String, dynamic> j) => ResumenDiario(
    fecha:               j['fecha']         ?? '',
    totalVentas:         (j['total_ventas'] ?? 0).toDouble(),
    numVentas:           j['num_ventas']    ?? 0,
    totalGastos:         (j['total_gastos'] ?? 0).toDouble(),
    // ✅ NUEVO — con fallback a 0 por compatibilidad
    totalDevoluciones:   (j['total_devoluciones'] ?? 0).toDouble(),
    numDevoluciones:     j['num_devoluciones']    ?? 0,
    totalNeto:           (j['total_neto'] ?? j['total_ventas'] ?? 0).toDouble(),
    utilidadBruta:       (j['utilidad_bruta'] ?? 0).toDouble(),
    ventasPorMetodo:     List<Map<String, dynamic>>.from(
        j['ventas_por_metodo_pago']   ?? []),
    // ✅ NUEVO
    devolucionesPorMetodo: List<Map<String, dynamic>>.from(
        j['devoluciones_por_metodo'] ?? []),
  );
}


// ── ResumenMensual ─────────────────────────────────────

class ResumenMensual {
  final int    anio, mes;
  final double totalVentas, totalGastos;
  // ✅ NUEVO
  final double totalDevoluciones;
  final double totalNeto;
  final double utilidadBruta;
  final List<Map<String, dynamic>> ventasPorDia;
  // ✅ NUEVO
  final List<Map<String, dynamic>> devolucionesPorDia;

  ResumenMensual({
    required this.anio,
    required this.mes,
    required this.totalVentas,
    required this.totalGastos,
    required this.totalDevoluciones,  // ✅
    required this.totalNeto,          // ✅
    required this.utilidadBruta,
    required this.ventasPorDia,
    required this.devolucionesPorDia, // ✅
  });

  factory ResumenMensual.fromJson(Map<String, dynamic> j) => ResumenMensual(
    anio:               j['anio'] ?? 0,
    mes:                j['mes']  ?? 0,
    totalVentas:        (j['total_ventas'] ?? 0).toDouble(),
    totalGastos:        (j['total_gastos'] ?? 0).toDouble(),
    // ✅ NUEVO — con fallback a 0
    totalDevoluciones:  (j['total_devoluciones'] ?? 0).toDouble(),
    totalNeto:          (j['total_neto'] ?? j['total_ventas'] ?? 0).toDouble(),
    utilidadBruta:      (j['utilidad_bruta'] ?? 0).toDouble(),
    ventasPorDia:       List<Map<String, dynamic>>.from(
        j['ventas_por_dia']       ?? []),
    // ✅ NUEVO
    devolucionesPorDia: List<Map<String, dynamic>>.from(
        j['devoluciones_por_dia'] ?? []),
  );
}


// ── TopProducto ────────────────────────────────────────
// Sin cambios

class TopProducto {
  final String producto;
  final String categoria;
  final double totalVendido;
  final double totalIngresos;

  TopProducto({
    required this.producto,
    required this.categoria,
    required this.totalVendido,
    required this.totalIngresos,
  });

  factory TopProducto.fromJson(Map<String, dynamic> j) => TopProducto(
    producto:      j['producto']       ?? '',
    categoria:     j['categoria']      ?? 'Sin categoría',
    totalVendido:  (j['total_vendido']  ?? 0).toDouble(),
    totalIngresos: (j['total_ingresos'] ?? 0).toDouble(),
  );
}


// ── Gasto ──────────────────────────────────────────────
// Sin cambios

class Gasto {
  final int    id;
  final int    tienda;
  final String tiendaNombre;
  final String empleadoNombre;
  final String categoria;
  final String descripcion;
  final double monto;
  final String metodoPago;
  final String visibilidad;
  final String createdAt;

  Gasto({
    required this.id,             required this.tienda,
    required this.tiendaNombre,   required this.empleadoNombre,
    required this.categoria,      required this.descripcion,
    required this.monto,          required this.metodoPago,
    this.visibilidad = 'todos',
    required this.createdAt,
  });

  factory Gasto.fromJson(Map<String, dynamic> j) => Gasto(
    id:             j['id']              ?? 0,
    tienda:         j['tienda']          ?? 0,
    tiendaNombre:   j['tienda_nombre']   ?? '',
    empleadoNombre: j['empleado_nombre'] ?? 'Sin empleado',
    categoria:      j['categoria']       ?? '',
    descripcion:    j['descripcion']     ?? '',
    monto:          double.parse((j['monto'] ?? '0').toString()),
    metodoPago:     j['metodo_pago']     ?? 'efectivo',
    visibilidad:    j['visibilidad']     ?? 'todos',
    createdAt:      j['created_at']      ?? '',
  );
}


// ── VentasCierre ───────────────────────────────────────
// Sin cambios

class VentasCierre {
  final double efectivo, tarjeta, transferencia, mixto, total;
  final int numTransacciones;

  VentasCierre({
    required this.efectivo,       required this.tarjeta,
    required this.transferencia,  required this.mixto,
    required this.total,          required this.numTransacciones,
  });

  factory VentasCierre.fromJson(Map<String, dynamic> j) => VentasCierre(
    efectivo:        double.tryParse(j['efectivo']?.toString()      ?? '0') ?? 0.0,
    tarjeta:         double.tryParse(j['tarjeta']?.toString()       ?? '0') ?? 0.0,
    transferencia:   double.tryParse(j['transferencia']?.toString() ?? '0') ?? 0.0,
    mixto:           double.tryParse(j['mixto']?.toString()         ?? '0') ?? 0.0,
    total:           double.tryParse(j['total']?.toString()         ?? '0') ?? 0.0,
    numTransacciones: j['num_transacciones'] ?? 0,
  );
}


// ── AbonosCierre ───────────────────────────────────────
// Sin cambios

class AbonosCierre {
  final double total, efectivo, transferencia;
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

  factory AbonosCierre.vacio() =>
      AbonosCierre(total: 0, efectivo: 0, transferencia: 0, cantidad: 0);
}


// ── GastoDetalle ───────────────────────────────────────
// Sin cambios

class GastoDetalle {
  final String categoria, metodoPago;
  final double monto;

  GastoDetalle({
    required this.categoria,
    required this.metodoPago,
    required this.monto,
  });

  factory GastoDetalle.fromJson(Map<String, dynamic> j) => GastoDetalle(
    categoria:  j['categoria']   ?? '',
    metodoPago: j['metodo_pago'] ?? '',
    monto:      double.tryParse(j['monto']?.toString() ?? '0') ?? 0.0,
  );
}


// ── GastosCierre ───────────────────────────────────────
// Sin cambios

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


// ── ResumenCierre ──────────────────────────────────────
// Sin cambios

class ResumenCierre {
  final int    sesionId;
  final String tiendaNombre, empleadoNombre, fechaApertura;
  final double montoInicial, montoEsperadoCaja;
  final VentasCierre ventas;
  final GastosCierre gastos;
  final AbonosCierre abonos;

  ResumenCierre({
    required this.sesionId,         required this.tiendaNombre,
    required this.empleadoNombre,   required this.fechaApertura,
    required this.montoInicial,     required this.montoEsperadoCaja,
    required this.ventas,           required this.gastos,
    required this.abonos,
  });

  factory ResumenCierre.fromJson(Map<String, dynamic> j) => ResumenCierre(
    sesionId:          j['sesion_id']       ?? 0,
    tiendaNombre:      j['tienda_nombre']   ?? '',
    empleadoNombre:    j['empleado_nombre'] ?? '',
    fechaApertura:     j['fecha_apertura']  ?? '',
    montoInicial:      double.tryParse(
        j['monto_inicial']?.toString()       ?? '0') ?? 0.0,
    montoEsperadoCaja: double.tryParse(
        j['monto_esperado_caja']?.toString() ?? '0') ?? 0.0,
    abonos: j['abonos'] != null
        ? AbonosCierre.fromJson(j['abonos'])
        : AbonosCierre.vacio(),
    ventas: VentasCierre.fromJson(j['ventas'] ?? {}),
    gastos: GastosCierre.fromJson(j['gastos'] ?? {}),
  );
}