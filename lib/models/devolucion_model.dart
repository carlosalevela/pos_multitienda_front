class DevolucionModel {
  final int id;
  final int ventaId;
  final String ventaNumero;
  final int tiendaId;
  final String tiendaNombre;
  final int? empleadoId;
  final String empleadoNombre;
  final double totalDevuelto;
  final String metodoDevolucion;
  final String tipo;
  final String estado;
  final String observaciones;
  final DateTime createdAt;

  final int? productoReemplazoId;
  final String? productoReemplazoNombre;
  final double? cantidadReemplazo;
  final double? precioReemplazo;
  final double? subtotalReemplazo;

  final double? totalReemplazo;
  final double? diferencia;
  final String? tipoDiferencia;
  final String? metodoPagoDiferencia;
  final double? montoRecibido;
  final double? cambioEntregado;

  final List<DetalleDevolucionModel> detalles;

  const DevolucionModel({
    required this.id,
    required this.ventaId,
    required this.ventaNumero,
    required this.tiendaId,
    required this.tiendaNombre,
    this.empleadoId,
    required this.empleadoNombre,
    required this.totalDevuelto,
    required this.metodoDevolucion,
    required this.tipo,
    required this.estado,
    required this.observaciones,
    required this.createdAt,
    this.productoReemplazoId,
    this.productoReemplazoNombre,
    this.cantidadReemplazo,
    this.precioReemplazo,
    this.subtotalReemplazo,
    this.totalReemplazo,
    this.diferencia,
    this.tipoDiferencia,
    this.metodoPagoDiferencia,
    this.montoRecibido,
    this.cambioEntregado,
    required this.detalles,
  });

  factory DevolucionModel.fromJson(Map<String, dynamic> j) {
    return DevolucionModel(
      id: j['id'] as int? ?? 0,
      ventaId: j['venta'] as int? ?? 0,
      ventaNumero: j['venta_numero'] as String? ?? '',
      tiendaId: j['tienda'] as int? ?? 0,
      tiendaNombre: j['tienda_nombre'] as String? ?? '',
      empleadoId: j['empleado'] as int?,
      empleadoNombre: j['empleado_nombre'] as String? ?? 'Sin empleado',
      totalDevuelto: double.tryParse(j['total_devuelto']?.toString() ?? '') ?? 0,
      metodoDevolucion: j['metodo_devolucion'] as String? ?? 'efectivo',
      tipo: j['tipo'] as String? ?? 'devolucion',
      estado: j['estado'] as String? ?? 'procesada',
      observaciones: j['observaciones'] as String? ?? '',
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),

      productoReemplazoId: j['producto_reemplazo'] as int?,
      productoReemplazoNombre: j['producto_reemplazo_nombre'] as String?,
      cantidadReemplazo: j['cantidad_reemplazo'] != null
          ? double.tryParse(j['cantidad_reemplazo'].toString())
          : null,
      precioReemplazo: j['precio_reemplazo'] != null
          ? double.tryParse(j['precio_reemplazo'].toString())
          : null,
      subtotalReemplazo: j['subtotal_reemplazo'] != null
          ? double.tryParse(j['subtotal_reemplazo'].toString())
          : null,

      totalReemplazo: j['total_reemplazo'] != null
          ? double.tryParse(j['total_reemplazo'].toString())
          : null,
      diferencia: j['diferencia'] != null
          ? double.tryParse(j['diferencia'].toString())
          : null,
      tipoDiferencia: j['tipo_diferencia'] as String?,
      metodoPagoDiferencia: j['metodo_pago_diferencia'] as String?,
      montoRecibido: j['monto_recibido'] != null
          ? double.tryParse(j['monto_recibido'].toString())
          : null,
      cambioEntregado: j['cambio_entregado'] != null
          ? double.tryParse(j['cambio_entregado'].toString())
          : null,

      detalles: (j['detalles'] as List? ?? [])
          .map((d) => DetalleDevolucionModel.fromJson(
                Map<String, dynamic>.from(d as Map),
              ))
          .toList(),
    );
  }

  DevolucionModel copyWith({
    int? id,
    int? ventaId,
    String? ventaNumero,
    int? tiendaId,
    String? tiendaNombre,
    int? empleadoId,
    String? empleadoNombre,
    double? totalDevuelto,
    String? metodoDevolucion,
    String? tipo,
    String? estado,
    String? observaciones,
    DateTime? createdAt,
    int? productoReemplazoId,
    String? productoReemplazoNombre,
    double? cantidadReemplazo,
    double? precioReemplazo,
    double? subtotalReemplazo,
    double? totalReemplazo,
    double? diferencia,
    String? tipoDiferencia,
    String? metodoPagoDiferencia,
    double? montoRecibido,
    double? cambioEntregado,
    List<DetalleDevolucionModel>? detalles,
  }) {
    return DevolucionModel(
      id: id ?? this.id,
      ventaId: ventaId ?? this.ventaId,
      ventaNumero: ventaNumero ?? this.ventaNumero,
      tiendaId: tiendaId ?? this.tiendaId,
      tiendaNombre: tiendaNombre ?? this.tiendaNombre,
      empleadoId: empleadoId ?? this.empleadoId,
      empleadoNombre: empleadoNombre ?? this.empleadoNombre,
      totalDevuelto: totalDevuelto ?? this.totalDevuelto,
      metodoDevolucion: metodoDevolucion ?? this.metodoDevolucion,
      tipo: tipo ?? this.tipo,
      estado: estado ?? this.estado,
      observaciones: observaciones ?? this.observaciones,
      createdAt: createdAt ?? this.createdAt,
      productoReemplazoId: productoReemplazoId ?? this.productoReemplazoId,
      productoReemplazoNombre:
          productoReemplazoNombre ?? this.productoReemplazoNombre,
      cantidadReemplazo: cantidadReemplazo ?? this.cantidadReemplazo,
      precioReemplazo: precioReemplazo ?? this.precioReemplazo,
      subtotalReemplazo: subtotalReemplazo ?? this.subtotalReemplazo,
      totalReemplazo: totalReemplazo ?? this.totalReemplazo,
      diferencia: diferencia ?? this.diferencia,
      tipoDiferencia: tipoDiferencia ?? this.tipoDiferencia,
      metodoPagoDiferencia:
          metodoPagoDiferencia ?? this.metodoPagoDiferencia,
      montoRecibido: montoRecibido ?? this.montoRecibido,
      cambioEntregado: cambioEntregado ?? this.cambioEntregado,
      detalles: detalles ?? this.detalles,
    );
  }
}

class DetalleDevolucionModel {
  final int id;
  final int productoId;
  final String productoNombre;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final String motivo;

  const DetalleDevolucionModel({
    required this.id,
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    required this.motivo,
  });

  factory DetalleDevolucionModel.fromJson(Map<String, dynamic> j) {
    return DetalleDevolucionModel(
      id: j['id'] as int? ?? 0,
      productoId: j['producto'] as int? ?? 0,
      productoNombre: j['producto_nombre'] as String? ?? '',
      cantidad: double.tryParse(j['cantidad']?.toString() ?? '') ?? 0,
      precioUnitario:
          double.tryParse(j['precio_unitario']?.toString() ?? '') ?? 0,
      subtotal: double.tryParse(j['subtotal']?.toString() ?? '') ?? 0,
      motivo: j['motivo'] as String? ?? '',
    );
  }

  DetalleDevolucionModel copyWith({
    int? id,
    int? productoId,
    String? productoNombre,
    double? cantidad,
    double? precioUnitario,
    double? subtotal,
    String? motivo,
  }) {
    return DetalleDevolucionModel(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      productoNombre: productoNombre ?? this.productoNombre,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      subtotal: subtotal ?? this.subtotal,
      motivo: motivo ?? this.motivo,
    );
  }
}