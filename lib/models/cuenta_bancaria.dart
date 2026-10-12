// lib/models/cuenta_bancaria.dart

class CuentaBancaria {
  final int    id;
  final String nombre;
  final String tipo;
  final String tipoDisplay;
  final String numero;
  final bool   activo;
  final int    orden;

  const CuentaBancaria({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.tipoDisplay,
    required this.numero,
    required this.activo,
    required this.orden,
  });

  factory CuentaBancaria.fromJson(Map<String, dynamic> j) => CuentaBancaria(
    id:          (j['id']    as num).toInt(),
    nombre:      j['nombre']       ?? '',
    tipo:        j['tipo']         ?? '',
    tipoDisplay: j['tipo_display'] ?? '',
    numero:      j['numero']       ?? '',
    activo:      j['activo']       ?? true,
    orden:       (j['orden'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'tipo':   tipo,
    'numero': numero,
    'activo': activo,
    'orden':  orden,
  };
}
