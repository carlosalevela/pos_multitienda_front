// lib/models/devolucion_model.dart

class DevolucionModel {
  final int    id;
  final int    ventaId;
  final String ventaNumero;
  final int    tiendaId;
  final String tiendaNombre;
  final int?   empleadoId;
  final String empleadoNombre;
  final double totalDevuelto;
  final String metodoDevolucion;
  final String estado;
  final String observaciones;
  final DateTime createdAt;
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
    required this.estado,
    required this.observaciones,
    required this.createdAt,
    required this.detalles,
  });

  factory DevolucionModel.fromJson(Map<String, dynamic> j) =>
      DevolucionModel(
        id:               j['id']              as int,
        ventaId:          j['venta']           as int,
        ventaNumero:      j['venta_numero']    as String? ?? '',
        tiendaId:         j['tienda']          as int,
        tiendaNombre:     j['tienda_nombre']   as String? ?? '',
        empleadoId:       j['empleado']        as int?,
        empleadoNombre:   j['empleado_nombre'] as String? ?? 'Sin empleado',
        totalDevuelto:    double.tryParse(j['total_devuelto'].toString()) ?? 0,
        metodoDevolucion: j['metodo_devolucion'] as String? ?? 'efectivo',
        estado:           j['estado']          as String? ?? 'procesada',
        observaciones:    j['observaciones']   as String? ?? '',
        createdAt:        DateTime.parse(j['created_at'] as String),
        detalles:         (j['detalles'] as List? ?? [])
            .map((d) => DetalleDevolucionModel.fromJson(d))
            .toList(),
      );
}


class DetalleDevolucionModel {
  final int    id;
  final int    productoId;
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

  factory DetalleDevolucionModel.fromJson(Map<String, dynamic> j) =>
      DetalleDevolucionModel(
        id:             j['id']              as int,
        productoId:     j['producto']        as int,
        productoNombre: j['producto_nombre'] as String? ?? '',
        cantidad:       double.tryParse(j['cantidad'].toString())        ?? 0,
        precioUnitario: double.tryParse(j['precio_unitario'].toString()) ?? 0,
        subtotal:       double.tryParse(j['subtotal'].toString())        ?? 0,
        motivo:         j['motivo']          as String? ?? '',
      );
}