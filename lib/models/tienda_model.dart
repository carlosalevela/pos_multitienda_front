// lib/models/tienda_model.dart

class Tienda {
  final int id;
  final String nombre;
  final String direccion;
  final String telefono;
  final String ciudad;
  final String nit;
  final bool activo;
  final int? empresaId;
  final String empresaNombre;
  final int totalEmpleados;
  final String createdAt;

  Tienda({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.telefono,
    required this.ciudad,
    required this.nit,
    required this.activo,
    required this.empresaId,
    required this.empresaNombre,
    required this.totalEmpleados,
    required this.createdAt,
  });

  factory Tienda.fromJson(Map<String, dynamic> j) => Tienda(
        id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
        nombre: j['nombre']?.toString() ?? '',
        direccion: j['direccion']?.toString() ?? '',
        telefono: j['telefono']?.toString() ?? '',
        ciudad: j['ciudad']?.toString() ?? '',
        nit: j['nit']?.toString() ?? '',
        activo: j['activo'] == null ? true : j['activo'] == true,
        empresaId: j['empresa'] == null
            ? null
            : int.tryParse(j['empresa'].toString()),
        empresaNombre: j['empresa_nombre']?.toString() ?? '',
        totalEmpleados:
            int.tryParse(j['total_empleados']?.toString() ?? '') ?? 0,
        createdAt: j['created_at']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
        'ciudad': ciudad,
        'nit': nit,
        'activo': activo,
      };

  // ── NUEVO: copyWith ──────────────────────────────────
  Tienda copyWith({
    int? id,
    String? nombre,
    String? direccion,
    String? telefono,
    String? ciudad,
    String? nit,
    bool? activo,
    int? empresaId,
    String? empresaNombre,
    int? totalEmpleados,
    String? createdAt,
  }) {
    return Tienda(
      id:             id             ?? this.id,
      nombre:         nombre         ?? this.nombre,
      direccion:      direccion      ?? this.direccion,
      telefono:       telefono       ?? this.telefono,
      ciudad:         ciudad         ?? this.ciudad,
      nit:            nit            ?? this.nit,
      activo:         activo         ?? this.activo,
      empresaId:      empresaId      ?? this.empresaId,
      empresaNombre:  empresaNombre  ?? this.empresaNombre,
      totalEmpleados: totalEmpleados ?? this.totalEmpleados,
      createdAt:      createdAt      ?? this.createdAt,
    );
  }
}