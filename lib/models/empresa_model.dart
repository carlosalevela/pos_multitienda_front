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

  // ✅ Configuración de mayoreo
  final bool manejaMayoreo;
  final int cantidadMayoreo;

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
    required this.manejaMayoreo,
    required this.cantidadMayoreo,
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
        manejaMayoreo: j['maneja_mayoreo'] == true,
        cantidadMayoreo:
            int.tryParse(j['cantidad_mayoreo']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'nit': nit,
        'email': email,
        'telefono': telefono,
        'direccion': direccion,
        'ciudad': ciudad,
        'activo': activo,
        'maneja_mayoreo': manejaMayoreo,
        'cantidad_mayoreo': cantidadMayoreo,
      };
}
