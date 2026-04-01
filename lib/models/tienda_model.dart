class Tienda {
  final int    id;
  final String nombre;
  final String direccion;
  final String telefono;
  final String ciudad;
  final String nit;
  final bool   activo;
  final int    totalEmpleados;
  final String createdAt;

  Tienda({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.telefono,
    required this.ciudad,
    required this.nit,
    required this.activo,
    required this.totalEmpleados,
    required this.createdAt,
  });

  factory Tienda.fromJson(Map<String, dynamic> j) => Tienda(
    id:             j['id']              ?? 0,
    nombre:         j['nombre']          ?? '',
    direccion:      j['direccion']       ?? '',
    telefono:       j['telefono']        ?? '',
    ciudad:         j['ciudad']          ?? '',
    nit:            j['nit']             ?? '',
    activo:         j['activo']          ?? true,
    totalEmpleados: j['total_empleados'] ?? 0,
    createdAt:      j['created_at']      ?? '',
  );

  Map<String, dynamic> toJson() => {
    'nombre':    nombre,
    'direccion': direccion,
    'telefono':  telefono,
    'ciudad':    ciudad,
    'nit':       nit,
    'activo':    activo,
  };
}