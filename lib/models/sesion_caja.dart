class SesionCaja {
  final int      id;
  final String   estado;
  final double   saldo_inicial;
  final double   saldo_final;
  final DateTime fecha_apertura;
  final DateTime? fecha_cierre;

  SesionCaja({
    required this.id,
    required this.estado,
    required this.saldo_inicial,
    required this.saldo_final,
    required this.fecha_apertura,
    this.fecha_cierre,
  });

  factory SesionCaja.fromJson(Map<String, dynamic> json) => SesionCaja(
    // ✅ Lee 'sesion_id' (respuesta de abrirCaja) o 'id' (respuesta de sesionActiva)
    id: (json['sesion_id'] ?? json['id'] ?? 0) as int,

    estado: json['estado'] ?? 'abierta',

    // ✅ Lee 'monto_inicial' (respuesta de abrirCaja) o 'saldo_inicial' (serializer)
    saldo_inicial: double.parse(
        (json['monto_inicial'] ?? json['saldo_inicial'] ?? 0).toString()),

    saldo_final: double.parse(
        (json['monto_final_real'] ?? json['saldo_final'] ?? 0).toString()),

    fecha_apertura: DateTime.parse(
        json['fecha_apertura'] ?? DateTime.now().toIso8601String()),

    fecha_cierre: json['fecha_cierre'] != null
        ? DateTime.parse(json['fecha_cierre'])
        : null,
  );

  bool get abierta => estado == 'abierta';
}