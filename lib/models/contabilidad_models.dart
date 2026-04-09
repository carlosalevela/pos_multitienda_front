class ResumenDiario {
  final String fecha;
  final double totalVentas;
  final int    numVentas;
  final double totalGastos;
  final double utilidadBruta;
  final List<Map<String, dynamic>> ventasPorMetodo;

  ResumenDiario({
    required this.fecha, required this.totalVentas,
    required this.numVentas, required this.totalGastos,
    required this.utilidadBruta, required this.ventasPorMetodo,
  });

  factory ResumenDiario.fromJson(Map<String, dynamic> j) => ResumenDiario(
    fecha:          j['fecha'] ?? '',
    totalVentas:    (j['total_ventas'] ?? 0).toDouble(),
    numVentas:      j['num_ventas'] ?? 0,
    totalGastos:    (j['total_gastos'] ?? 0).toDouble(),
    utilidadBruta:  (j['utilidad_bruta'] ?? 0).toDouble(),
    ventasPorMetodo: List<Map<String, dynamic>>.from(
        j['ventas_por_metodo_pago'] ?? []),
  );
}

class ResumenMensual {
  final int    anio, mes;
  final double totalVentas, totalGastos, utilidadBruta;
  final List<Map<String, dynamic>> ventasPorDia;

  ResumenMensual({
    required this.anio, required this.mes,
    required this.totalVentas, required this.totalGastos,
    required this.utilidadBruta, required this.ventasPorDia,
  });

  factory ResumenMensual.fromJson(Map<String, dynamic> j) => ResumenMensual(
    anio:          j['anio'] ?? 0,
    mes:           j['mes'] ?? 0,
    totalVentas:   (j['total_ventas'] ?? 0).toDouble(),
    totalGastos:   (j['total_gastos'] ?? 0).toDouble(),
    utilidadBruta: (j['utilidad_bruta'] ?? 0).toDouble(),
    ventasPorDia:  List<Map<String, dynamic>>.from(j['ventas_por_dia'] ?? []),
  );
}

class TopProducto {
  final String producto;
  final String categoria;      // ✅ nuevo campo
  final double totalVendido;
  final double totalIngresos;

  TopProducto({
    required this.producto,
    required this.categoria,   // ✅
    required this.totalVendido,
    required this.totalIngresos,
  });

  factory TopProducto.fromJson(Map<String, dynamic> j) => TopProducto(
    producto:      j['producto']      ?? '',
    categoria:     j['categoria']     ?? 'Sin categoría',  // ✅
    totalVendido:  (j['total_vendido']  ?? 0).toDouble(),
    totalIngresos: (j['total_ingresos'] ?? 0).toDouble(),
  );
}

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
    required this.id, required this.tienda,
    required this.tiendaNombre, required this.empleadoNombre,
    required this.categoria, required this.descripcion,
    required this.monto, required this.metodoPago,
    this.visibilidad = 'todos',
    required this.createdAt,
  });

  factory Gasto.fromJson(Map<String, dynamic> j) => Gasto(
    id:             j['id'] ?? 0,
    tienda:         j['tienda'] ?? 0,
    tiendaNombre:   j['tienda_nombre'] ?? '',
    empleadoNombre: j['empleado_nombre'] ?? 'Sin empleado',
    categoria:      j['categoria'] ?? '',
    descripcion:    j['descripcion'] ?? '',
    monto:          double.parse((j['monto'] ?? '0').toString()), // ✅ FIX
    metodoPago:     j['metodo_pago'] ?? 'efectivo',
    visibilidad:    j['visibilidad']    ?? 'todos',
    createdAt:      j['created_at'] ?? '',
  );
}