// lib/models/tier_model.dart

class TierModel {
  final int?   id;
  final String nombre;
  final double umbralMin;
  final double? umbralMax;
  final double descuentoPct;
  final String colorHex;
  final bool   activo;
  final int    orden;

  const TierModel({
    this.id,
    required this.nombre,
    required this.umbralMin,
    this.umbralMax,
    required this.descuentoPct,
    required this.colorHex,
    required this.activo,
    required this.orden,
  });

  factory TierModel.fromJson(Map<String, dynamic> j) => TierModel(
    id:           j['id'] as int?,
    nombre:       j['nombre'] as String,
    umbralMin:    double.parse(j['umbral_min'].toString()),
    umbralMax:    j['umbral_max'] != null
                      ? double.parse(j['umbral_max'].toString())
                      : null,
    descuentoPct: double.parse(j['descuento_pct'].toString()),
    colorHex:     j['color_hex'] as String? ?? '#76777D',
    activo:       j['activo'] as bool? ?? true,
    orden:        j['orden'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'nombre':       nombre,
    'umbral_min':   umbralMin,
    'umbral_max':   umbralMax,
    'descuento_pct': descuentoPct,
    'color_hex':    colorHex,
    'activo':       activo,
    'orden':        orden,
  };
}
