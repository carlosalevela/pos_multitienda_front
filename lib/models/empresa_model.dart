// lib/models/empresa_model.dart

class Empresa {
  final int id;
  final String nombre;
  final String nit;
  final String email;
  final String telefono;
  final String direccion;
  final String ciudad;
  final String logo;
  final bool activo;
  final String createdAt;

  Empresa({
    required this.id,
    required this.nombre,
    required this.nit,
    required this.email,
    required this.telefono,
    required this.direccion,
    required this.ciudad,
    required this.logo,
    required this.activo,
    required this.createdAt,
  });

  factory Empresa.fromJson(Map<String, dynamic> j) => Empresa(
        id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
        nombre: j['nombre']?.toString() ?? '',
        nit: j['nit']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        telefono: j['telefono']?.toString() ?? '',
        direccion: j['direccion']?.toString() ?? '',
        ciudad: j['ciudad']?.toString() ?? '',
        logo: j['logo']?.toString() ?? '',
        activo: j['activo'] == null ? true : j['activo'] == true,
        createdAt: j['created_at']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'nit': nit,
        'email': email,
        'telefono': telefono,
        'direccion': direccion,
        'ciudad': ciudad,
        'activo': activo,
      };
}