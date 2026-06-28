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

  // true cuando la cantidad actual alcanza el umbral mayoreo
  bool get aplicaMayoreo {
    if (!producto.manejaMayoreo) return false;
    if (producto.precioMayoreo == null) return false;
    final umbral = producto.umbralMayoreo;
    if (umbral == null) return false;
    return cantidad >= umbral;
  }

  // Precio unitario efectivo (precedencia: manual → mayoreo → normal - descuento)
  double get precioUnitario {
    if (precioPersonalizado != null) return precioPersonalizado!;
    if (aplicaMayoreo) return producto.precioMayoreo!;
    return producto.precio - descuento;
  }

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