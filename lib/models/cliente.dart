class Cliente {
  final int     id;
  final String  nombre;
  final String  apellido;
  final String? cedulaNit;
  final String  telefono;
  final String  email;
  final String  direccion;
  final bool    activo;
  final String  createdAt;

  Cliente({
    required this.id,
    required this.nombre,
    required this.apellido,
    this.cedulaNit,
    required this.telefono,
    required this.email,
    required this.direccion,
    required this.activo,
    required this.createdAt,
  });

  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
    id:        j['id'],
    nombre:    j['nombre']     ?? '',
    apellido:  j['apellido']   ?? '',
    cedulaNit: j['cedula_nit'],          // puede ser null
    telefono:  j['telefono']   ?? '',
    email:     j['email']      ?? '',
    direccion: j['direccion']  ?? '',
    activo:    j['activo']     ?? true,
    createdAt: j['created_at'] ?? '',
  );

  // Para crear / editar — solo campos editables
  Map<String, dynamic> toJson() => {
    'nombre':     nombre,
    'apellido':   apellido,
    if (cedulaNit != null) 'cedula_nit': cedulaNit,
    'telefono':   telefono,
    'email':      email,
    'direccion':  direccion,
  };

  // Nombre completo para mostrar en UI
  String get nombreCompleto => '$nombre $apellido'.trim();
}