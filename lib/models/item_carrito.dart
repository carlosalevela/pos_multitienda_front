// models/item_carrito.dart

import 'producto.dart';

class ItemCarrito {
  final Producto producto;
  int            cantidad;
  double         descuento;           // ← se mantiene (compatibilidad)
  double?        precioPersonalizado; // ← NUEVO

  ItemCarrito({
    required this.producto,
    this.cantidad   = 1,
    this.descuento  = 0,
  });

  // Precio unitario efectivo:
  // Si hay precio personalizado → lo usa
  // Si no → precio original menos descuento fijo
  double get precioUnitario =>
      precioPersonalizado ?? (producto.precio - descuento);

  // Subtotal siempre usa precioUnitario
  double get subtotal => precioUnitario * cantidad;

  // Porcentaje de descuento calculado automáticamente
  double get descuentoPct {
    if (producto.precio <= 0) return 0;
    return ((producto.precio - precioUnitario) / producto.precio * 100)
        .clamp(0.0, 100.0);
  }

  bool get tieneDescuento =>
      precioUnitario < producto.precio;
}