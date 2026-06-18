class SesionCaja {
  final int     id;
  final String  estado;
  final double  saldo_inicial;
  final double  saldo_final;
  final DateTime  fecha_apertura;
  final DateTime? fecha_cierre;
  // KPIs from SesionCajaSerializer (populated by /caja/activa/{id}/)
  final double ventasTotal;
  final int    numTransacciones;
  final double gastosTotal;
  final double montoEsperado;
  final String tiendaNombre;
  final String empleadoNombre;

  SesionCaja({
    required this.id,
    required this.estado,
    required this.saldo_inicial,
    required this.saldo_final,
    required this.fecha_apertura,
    this.fecha_cierre,
    this.ventasTotal       = 0,
    this.numTransacciones  = 0,
    this.gastosTotal       = 0,
    this.montoEsperado     = 0,
    this.tiendaNombre      = '',
    this.empleadoNombre    = '',
  });

  factory SesionCaja.fromJson(Map<String, dynamic> json) => SesionCaja(
    id: (json['sesion_id'] ?? json['id'] ?? 0) as int,
    estado: json['estado'] ?? 'abierta',
    saldo_inicial: double.parse(
        (json['monto_inicial'] ?? json['saldo_inicial'] ?? 0).toString()),
    saldo_final: double.parse(
        (json['monto_final_real'] ?? json['saldo_final'] ?? 0).toString()),
    fecha_apertura: DateTime.parse(
        json['fecha_apertura'] ?? DateTime.now().toIso8601String()),
    fecha_cierre: json['fecha_cierre'] != null
        ? DateTime.parse(json['fecha_cierre'])
        : null,
    ventasTotal:      double.tryParse(json['ventas_total']?.toString()   ?? '0') ?? 0,
    numTransacciones: (json['num_transacciones'] as num?)?.toInt()               ?? 0,
    gastosTotal:      double.tryParse(json['gastos_total']?.toString()   ?? '0') ?? 0,
    montoEsperado:    double.tryParse(json['monto_esperado']?.toString() ?? '0') ?? 0,
    tiendaNombre:     json['tienda_nombre']   ?? '',
    empleadoNombre:   json['empleado_nombre'] ?? '',
  );

  bool get abierta => estado == 'abierta';
}
