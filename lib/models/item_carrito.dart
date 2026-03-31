import 'producto.dart';

class ItemCarrito {
  final Producto producto;
  int            cantidad;
  double         descuento;

  ItemCarrito({
    required this.producto,
    this.cantidad  = 1,
    this.descuento = 0,
  });

  double get subtotal => (producto.precio - descuento) * cantidad;
}