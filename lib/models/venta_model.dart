// Modelo simplificado para el listado del día
class VentaResumenModel {
  final int      id;
  final String   numeroFactura;
  final String   clienteNombre;
  final double   total;
  final String   estado;
  final DateTime createdAt;

  const VentaResumenModel({
    required this.id,
    required this.numeroFactura,
    required this.clienteNombre,
    required this.total,
    required this.estado,
    required this.createdAt,
  });

  factory VentaResumenModel.fromJson(Map<String, dynamic> j) =>
      VentaResumenModel(
        id:            j['id']             as int,
        numeroFactura: j['numero_factura'] as String? ?? '',
        clienteNombre: j['cliente_nombre'] as String? ?? 'Consumidor Final',
        total:         double.tryParse(j['total'].toString()) ?? 0,
        estado:        j['estado']         as String? ?? '',
        createdAt:     DateTime.parse(j['created_at'] as String),
      );
}


// Modelo para el endpoint disponible-devolucion
class VentaDisponibleModel {
  final int                        ventaId;
  final String                     numeroFactura;
  final double                     total;
  final bool                       todosDevueltos;
  final List<ProductoDisponibleModel> productos;

  const VentaDisponibleModel({
    required this.ventaId,
    required this.numeroFactura,
    required this.total,
    required this.todosDevueltos,
    required this.productos,
  });

  factory VentaDisponibleModel.fromJson(Map<String, dynamic> j) =>
      VentaDisponibleModel(
        ventaId:        j['venta_id']        as int,
        numeroFactura:  j['numero_factura']  as String? ?? '',
        total:          double.tryParse(j['total'].toString()) ?? 0,
        todosDevueltos: j['todos_devueltos'] as bool? ?? false,
        productos: (j['productos'] as List? ?? [])
            .map((p) => ProductoDisponibleModel.fromJson(p))
            .toList(),
      );
}


class ProductoDisponibleModel {
  final int    productoId;
  final String productoNombre;
  final double precioUnitario;
  final double cantidadVendida;
  final double yaDevuelta;
  final double disponible;

  const ProductoDisponibleModel({
    required this.productoId,
    required this.productoNombre,
    required this.precioUnitario,
    required this.cantidadVendida,
    required this.yaDevuelta,
    required this.disponible,
  });

  factory ProductoDisponibleModel.fromJson(Map<String, dynamic> j) =>
      ProductoDisponibleModel(
        productoId:     j['producto_id']      as int,
        productoNombre: j['producto_nombre']  as String? ?? '',
        precioUnitario: double.tryParse(j['precio_unitario'].toString()) ?? 0,
        cantidadVendida:double.tryParse(j['cantidad_vendida'].toString()) ?? 0,
        yaDevuelta:     double.tryParse(j['ya_devuelta'].toString()) ?? 0,
        disponible:     double.tryParse(j['disponible'].toString()) ?? 0,
      );
}