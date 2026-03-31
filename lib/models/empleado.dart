class Empleado {
  final int    id;
  final String nombre;
  final String apellido;
  final String email;
  final String rol;

  Empleado({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
  });

  factory Empleado.fromJson(Map<String, dynamic> json) => Empleado(
    id:       json['id'],
    nombre:   json['nombre'],
    apellido: json['apellido'],
    email:    json['email'],
    rol:      json['rol'],
  );

  String get nombreCompleto => '$nombre $apellido';
}