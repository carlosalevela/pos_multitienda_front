// lib/models/contabilidad_models.dart

// ── TopCliente ─────────────────────────────────────────

class TopCliente {
  final int    clienteId;
  final String nombre;
  final double totalPeriodo;
  final int    numCompras;
  final double totalAcumulado;
  final String? tierNombre;
  final String? tierColorHex;
  final double? tierDescuentoPct;

  const TopCliente({
    required this.clienteId,
    required this.nombre,
    required this.totalPeriodo,
    required this.numCompras,
    required this.totalAcumulado,
    this.tierNombre,
    this.tierColorHex,
    this.tierDescuentoPct,
  });

  factory TopCliente.fromJson(Map<String, dynamic> j) => TopCliente(
    clienteId:       j['cliente_id'] as int,
    nombre:          j['nombre'] as String? ?? '',
    totalPeriodo:    double.parse((j['total_periodo']   ?? 0).toString()),
    numCompras:      j['num_compras'] as int? ?? 0,
    totalAcumulado:  double.parse((j['total_acumulado'] ?? 0).toString()),
    tierNombre:      j['tier']?['nombre']       as String?,
    tierColorHex:    j['tier']?['color_hex']    as String?,
    tierDescuentoPct: j['tier']?['descuento_pct'] != null
        ? double.parse(j['tier']['descuento_pct'].toString())
        : null,
  );
}

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
  final String tipoGasto;
  final String createdAt;

  Gasto({
    required this.id,             required this.tienda,
    required this.tiendaNombre,   required this.empleadoNombre,
    required this.categoria,      required this.descripcion,
    required this.monto,          required this.metodoPago,
    this.visibilidad = 'todos',
    this.tipoGasto   = 'fijo',
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
    tipoGasto:      j['tipo_gasto']      ?? 'fijo',
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


// ── EstadoResultados (P&L real con COGS) ───────────────

class EstadoResultados {
  final String desde, hasta;
  // Ingresos
  final double ventasBrutas, menosDescuentos, menosDevoluciones;
  final double ingresosNetos, impuestosCobrados;
  final int    numVentas, numDevoluciones;
  // COGS + Margen
  final double costoVentas, margenBruto, margenBrutoPct;
  // Gastos
  final double totalGastos;
  final List<Map<String, dynamic>> gastosDetalle;
  // Averías
  final double perdidasBrutas, valorRecuperado, perdidaNeta;
  // Resultado
  final double utilidadOperativa, utilidadOperativaPct;

  EstadoResultados({
    required this.desde,              required this.hasta,
    required this.ventasBrutas,       required this.menosDescuentos,
    required this.menosDevoluciones,  required this.ingresosNetos,
    required this.impuestosCobrados,  required this.numVentas,
    required this.numDevoluciones,    required this.costoVentas,
    required this.margenBruto,        required this.margenBrutoPct,
    required this.totalGastos,        required this.gastosDetalle,
    required this.perdidasBrutas,     required this.valorRecuperado,
    required this.perdidaNeta,        required this.utilidadOperativa,
    required this.utilidadOperativaPct,
  });

  factory EstadoResultados.fromJson(Map<String, dynamic> j) {
    final per = j['periodo']          ?? {};
    final ing = j['ingresos']         ?? {};
    final gop = j['gastos_operativos']?? {};
    final av  = j['averias']          ?? {};
    return EstadoResultados(
      desde:                 per['desde']             ?? '',
      hasta:                 per['hasta']             ?? '',
      ventasBrutas:          (ing['ventas_brutas']      ?? 0).toDouble(),
      menosDescuentos:       (ing['menos_descuentos']   ?? 0).toDouble(),
      menosDevoluciones:     (ing['menos_devoluciones'] ?? 0).toDouble(),
      ingresosNetos:         (ing['ingresos_netos']     ?? 0).toDouble(),
      impuestosCobrados:     (ing['impuestos_cobrados'] ?? 0).toDouble(),
      numVentas:              ing['num_ventas']         ?? 0,
      numDevoluciones:        ing['num_devoluciones']   ?? 0,
      costoVentas:           (j['costo_ventas']         ?? 0).toDouble(),
      margenBruto:           (j['margen_bruto']         ?? 0).toDouble(),
      margenBrutoPct:        (j['margen_bruto_pct']     ?? 0).toDouble(),
      totalGastos:           (gop['total']              ?? 0).toDouble(),
      gastosDetalle: List<Map<String, dynamic>>.from(gop['detalle'] ?? []),
      perdidasBrutas:        (av['perdidas_brutas']     ?? 0).toDouble(),
      valorRecuperado:       (av['valor_recuperado']    ?? 0).toDouble(),
      perdidaNeta:           (av['perdida_neta']        ?? 0).toDouble(),
      utilidadOperativa:     (j['utilidad_operativa']     ?? 0).toDouble(),
      utilidadOperativaPct:  (j['utilidad_operativa_pct'] ?? 0).toDouble(),
    );
  }
}


// ── PuntoEquilibrio ────────────────────────────────────

class PuntoEquilibrio {
  final double ingresosNetos, costoVentas;
  final double gastosFijos, gastosVariables;
  final double margenContribucion, margenContribucionPct;
  final double? puntoEquilibrioIngresos;
  final bool   alcanzado;
  final double? excedenteDeficit;
  final List<Map<String, dynamic>> detalleFijos, detalleVariables;

  PuntoEquilibrio({
    required this.ingresosNetos,    required this.costoVentas,
    required this.gastosFijos,      required this.gastosVariables,
    required this.margenContribucion, required this.margenContribucionPct,
    required this.puntoEquilibrioIngresos,
    required this.alcanzado,        required this.excedenteDeficit,
    required this.detalleFijos,     required this.detalleVariables,
  });

  factory PuntoEquilibrio.fromJson(Map<String, dynamic> j) => PuntoEquilibrio(
    ingresosNetos:           (j['ingresos_netos']            ?? 0).toDouble(),
    costoVentas:             (j['costo_ventas']              ?? 0).toDouble(),
    gastosFijos:             (j['gastos_fijos']              ?? 0).toDouble(),
    gastosVariables:         (j['gastos_variables']          ?? 0).toDouble(),
    margenContribucion:      (j['margen_contribucion']       ?? 0).toDouble(),
    margenContribucionPct:   (j['margen_contribucion_pct']   ?? 0).toDouble(),
    puntoEquilibrioIngresos: j['punto_equilibrio_ingresos'] != null
        ? (j['punto_equilibrio_ingresos']).toDouble() : null,
    alcanzado:               j['punto_equilibrio_alcanzado'] == true,
    excedenteDeficit:        j['excedente_deficit'] != null
        ? (j['excedente_deficit']).toDouble() : null,
    detalleFijos:     List<Map<String, dynamic>>.from(j['detalle_gastos_fijos']     ?? []),
    detalleVariables: List<Map<String, dynamic>>.from(j['detalle_gastos_variables'] ?? []),
  );
}


// ── TiendaComparativo ──────────────────────────────────

class TiendaComparativo {
  final int    tiendaId;
  final String tiendaNombre;
  final double ventasBrutas, devoluciones, ingresosNetos;
  final double costoVentas, margenBruto, margenBrutoPct;
  final double gastos, perdidaAverias, utilidadOperativa;
  final int    numVentas, numDevoluciones;

  TiendaComparativo({
    required this.tiendaId,          required this.tiendaNombre,
    required this.ventasBrutas,      required this.devoluciones,
    required this.ingresosNetos,     required this.costoVentas,
    required this.margenBruto,       required this.margenBrutoPct,
    required this.gastos,            required this.perdidaAverias,
    required this.utilidadOperativa, required this.numVentas,
    required this.numDevoluciones,
  });

  factory TiendaComparativo.fromJson(Map<String, dynamic> j) => TiendaComparativo(
    tiendaId:          j['tienda_id']          ?? 0,
    tiendaNombre:      j['tienda_nombre']       ?? '',
    ventasBrutas:      (j['ventas_brutas']      ?? 0).toDouble(),
    devoluciones:      (j['devoluciones']       ?? 0).toDouble(),
    ingresosNetos:     (j['ingresos_netos']     ?? 0).toDouble(),
    costoVentas:       (j['costo_ventas']       ?? 0).toDouble(),
    margenBruto:       (j['margen_bruto']       ?? 0).toDouble(),
    margenBrutoPct:    (j['margen_bruto_pct']   ?? 0).toDouble(),
    gastos:            (j['gastos']             ?? 0).toDouble(),
    perdidaAverias:    (j['perdida_averias']    ?? 0).toDouble(),
    utilidadOperativa: (j['utilidad_operativa'] ?? 0).toDouble(),
    numVentas:          j['num_ventas']         ?? 0,
    numDevoluciones:    j['num_devoluciones']   ?? 0,
  );
}


// ── VentaEmpleado ──────────────────────────────────────

class VentaEmpleado {
  final int    empleadoId;
  final String nombre;
  final int    numVentas;
  final double totalVentas, totalDescuentos, promedioVenta;

  VentaEmpleado({
    required this.empleadoId,    required this.nombre,
    required this.numVentas,     required this.totalVentas,
    required this.totalDescuentos, required this.promedioVenta,
  });

  factory VentaEmpleado.fromJson(Map<String, dynamic> j) => VentaEmpleado(
    empleadoId:      j['empleado_id']      ?? 0,
    nombre:          j['nombre']           ?? 'Sin nombre',
    numVentas:       j['num_ventas']       ?? 0,
    totalVentas:     (j['total_ventas']     ?? 0).toDouble(),
    totalDescuentos: (j['total_descuentos'] ?? 0).toDouble(),
    promedioVenta:   (j['promedio_venta']   ?? 0).toDouble(),
  );
}


// ── FlujoCajaResumen ───────────────────────────────────

class FlujoCajaResumen {
  final double totalEntradas, totalSalidas, flujoNeto, totalDiferencias;
  final int    numSesiones;
  final List<Map<String, dynamic>> sesiones;

  FlujoCajaResumen({
    required this.totalEntradas,   required this.totalSalidas,
    required this.flujoNeto,       required this.totalDiferencias,
    required this.numSesiones,     required this.sesiones,
  });

  factory FlujoCajaResumen.fromJson(Map<String, dynamic> j) {
    final res = j['resumen'] ?? {};
    return FlujoCajaResumen(
      totalEntradas:    (res['total_entradas']    ?? 0).toDouble(),
      totalSalidas:     (res['total_salidas']     ?? 0).toDouble(),
      flujoNeto:        (res['flujo_neto']        ?? 0).toDouble(),
      totalDiferencias: (res['total_diferencias'] ?? 0).toDouble(),
      numSesiones:       res['num_sesiones']      ?? 0,
      sesiones: List<Map<String, dynamic>>.from(j['sesiones'] ?? []),
    );
  }
}