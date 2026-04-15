class Producto {
  final int    id;
  String nombre;
  String referencia;
  String descripcion;
  double precio;
  double precioCompra;
  String categoria;
  String unidadMedida;
  double stockActual;
  double stockMinimo;
  bool   activo;

  Producto({
    required this.id,
    required this.nombre,
    this.referencia  = '',
    this.descripcion = '',
    required this.precio,
    this.precioCompra = 0,
    required this.categoria,
    this.unidadMedida = 'unidad',
    this.stockActual  = 0,
    this.stockMinimo  = 0,
    this.activo       = true,
  });

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
    id:           json['id'],
    nombre:       json['nombre']           ?? '',
    referencia:   json['codigo_barras']    ?? '',
    descripcion:  json['descripcion']      ?? '',
    precio:       double.parse((json['precio_venta']  ?? 0).toString()),
    precioCompra: double.parse((json['precio_compra'] ?? 0).toString()),
    categoria:    json['categoria_nombre'] ?? 'Sin categoría',
    unidadMedida: json['unidad_medida']    ?? 'unidad',
    stockActual:  double.parse((json['stock_actual']  ?? 0).toString()),
    stockMinimo:  double.parse((json['stock_minimo']  ?? 0).toString()),
    activo:       json['activo']           ?? true,
  );

  // ✅ NUEVO — mapea de vuelta a los nombres que espera el backend
  Map<String, dynamic> toJson() => {
    'id':              id,
    'nombre':          nombre,
    'codigo_barras':   referencia,
    'descripcion':     descripcion,
    'precio_venta':    precio.toString(),
    'precio_compra':   precioCompra.toString(),
    'categoria_nombre': categoria,
    'unidad_medida':   unidadMedida,
    'stock_actual':    stockActual.toString(),
    'stock_minimo':    stockMinimo.toString(),
    'activo':          activo,
  };
}