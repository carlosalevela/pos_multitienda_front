class Cliente {
  final int      id;
  final String   nombre;
  final String   apellido;
  final String?  cedulaNit;
  final String   telefono;
  final String   email;
  final String   direccion;
  final bool     activo;
  final DateTime createdAt;   // ✅ DateTime en lugar de String

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
    id:        j['id']        as int,
    nombre:    j['nombre']    as String? ?? '',
    apellido:  j['apellido']  as String? ?? '',
    cedulaNit: j['cedula_nit'] as String?,
    telefono:  j['telefono']  as String? ?? '',
    email:     j['email']     as String? ?? '',
    direccion: j['direccion'] as String? ?? '',
    activo:    j['activo']    as bool?   ?? true,
    createdAt: j['created_at'] != null            // ✅ parseo seguro
        ? DateTime.parse(j['created_at'] as String)
        : DateTime.now(),
  );

  // Para crear / editar
  Map<String, dynamic> toJson() => {
    'nombre':    nombre,
    'apellido':  apellido,
    if (cedulaNit != null && cedulaNit!.isNotEmpty)
      'cedula_nit': cedulaNit,              // ✅ excluye string vacío también
    'telefono':  telefono,
    'email':     email,
    'direccion': direccion,
    'activo':    activo,                    // ✅ incluido
  };

  // ✅ copyWith para edición en formularios
  Cliente copyWith({
    int?     id,
    String?  nombre,
    String?  apellido,
    String?  cedulaNit,
    String?  telefono,
    String?  email,
    String?  direccion,
    bool?    activo,
    DateTime? createdAt,
  }) =>
      Cliente(
        id:        id        ?? this.id,
        nombre:    nombre    ?? this.nombre,
        apellido:  apellido  ?? this.apellido,
        cedulaNit: cedulaNit ?? this.cedulaNit,
        telefono:  telefono  ?? this.telefono,
        email:     email     ?? this.email,
        direccion: direccion ?? this.direccion,
        activo:    activo    ?? this.activo,
        createdAt: createdAt ?? this.createdAt,
      );

  // ✅ Nombre completo sin espacio doble cuando no hay apellido
  String get nombreCompleto =>
      apellido.isNotEmpty ? '$nombre $apellido' : nombre;

  @override
  String toString() => 'Cliente($id, $nombreCompleto)';

  @override
  bool operator ==(Object other) =>
      other is Cliente && other.id == id;

  @override
  int get hashCode => id.hashCode;
}