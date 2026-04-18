// lib/providers/cambio_pos_provider.dart

import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/venta_model.dart';        // VentaDisponibleModel, ProductoDisponibleModel
import '../services/venta_service.dart';
import '../services/inventario_service.dart';


// ── Modelos internos del carrito ──────────────────────────────

class ItemDevuelto {
  final ProductoDisponibleModel producto;
  double cantidad;

  ItemDevuelto({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precioUnitario * cantidad;

  Map<String, dynamic> toPayload() => {
    'producto': producto.productoId,
    'cantidad': cantidad.toString(),
  };
}


class ItemNuevo {
  final Producto producto;
  double cantidad;
  double? precioPersonalizado;

  ItemNuevo({required this.producto, this.cantidad = 1});

  double get precioUnitario => precioPersonalizado ?? producto.precio;
  double get subtotal       => precioUnitario * cantidad;

  Map<String, dynamic> toPayload() => {
    'producto':        producto.id,
    'cantidad':        cantidad.toString(),
    'precio_unitario': precioUnitario.toString(),
    'descuento':       '0',
  };
}


class PagoCambio {
  String metodo;
  double monto;

  PagoCambio({required this.metodo, required this.monto});

  Map<String, dynamic> toPayload() => {
    'metodo': metodo,
    'monto':  monto,
  };
}


// ── Provider principal ────────────────────────────────────────

class CambioPOSProvider extends ChangeNotifier {
  final VentaService      _ventaService      = VentaService();
  final InventarioService _inventarioService = InventarioService();

  // ── Pasos del flujo (1→4) ─────────────────────────────
  int _paso = 1;
  int get paso => _paso;

  // ── Paso 1: buscar venta original ─────────────────────
  VentaDisponibleModel? _ventaOriginal;
  VentaDisponibleModel? get ventaOriginal => _ventaOriginal;

  bool   _buscandoVenta = false;
  bool   get buscandoVenta => _buscandoVenta;

  // ── Paso 2: carrito de productos devueltos ────────────
  final List<ItemDevuelto> _itemsDevueltos = [];
  List<ItemDevuelto> get itemsDevueltos => List.unmodifiable(_itemsDevueltos);

  // ── Paso 3: carrito de productos nuevos ───────────────
  final List<ItemNuevo>    _carritoNuevo  = [];
  List<ItemNuevo>    get carritoNuevo  => List.unmodifiable(_carritoNuevo);

  List<Producto>     _resultadosBusqueda = [];
  List<Producto>     get resultadosBusqueda => _resultadosBusqueda;
  bool               _buscandoProducto  = false;
  bool               get buscandoProducto => _buscandoProducto;

  // ── Paso 4: pagos ─────────────────────────────────────
  final List<PagoCambio> _pagos = [];
  List<PagoCambio> get pagos => List.unmodifiable(_pagos);

  // ── Totales calculados ────────────────────────────────
  double get totalDevuelto =>
      _itemsDevueltos.fold(0, (s, i) => s + i.subtotal);

  double get totalNuevo =>
      _carritoNuevo.fold(0, (s, i) => s + i.subtotal);

  double get totalPagadoCaja =>
      _pagos.fold(0, (s, p) => s + p.monto);

  /// Cuánto falta por pagar. Negativo = vuelto a favor del cliente.
  double get saldoPendiente =>
      totalNuevo - totalDevuelto - totalPagadoCaja;

  bool get saldoCubierto => saldoPendiente <= 0;

  // ── Estado general ────────────────────────────────────
  bool   _procesando = false;
  bool   get procesando => _procesando;

  String _errorMsg   = '';
  String get errorMsg => _errorMsg;

  String _successMsg = '';
  String get successMsg => _successMsg;

  // ─────────────────────────────────────────────────────
  // PASO 1 — Buscar venta original
  // ─────────────────────────────────────────────────────

  Future<void> buscarVenta(int ventaId) async {
    _buscandoVenta = true;
    _errorMsg      = '';
    _ventaOriginal = null;
    notifyListeners();

    final data = await _ventaService.ventaDisponibleDevolucion(ventaId);

    _buscandoVenta = false;

    if (data == null) {
      _errorMsg = 'No se encontró la venta o no está disponible.';
      notifyListeners();
      return;
    }

    final venta = VentaDisponibleModel.fromJson(data);

    if (venta.todosDevueltos) {
      _errorMsg = 'Esta venta ya fue devuelta completamente.';
      notifyListeners();
      return;
    }

    _ventaOriginal = venta;
    notifyListeners();
  }

  void confirmarVentaYAvanzar() {
    if (_ventaOriginal == null) return;
    _paso = 2;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  // PASO 2 — Seleccionar productos a devolver
  // ─────────────────────────────────────────────────────

  void agregarDevuelto(ProductoDisponibleModel producto) {
    final idx = _itemsDevueltos.indexWhere(
        (i) => i.producto.productoId == producto.productoId);

    if (idx >= 0) {
      if (_itemsDevueltos[idx].cantidad >= producto.disponible) {
        _errorMsg = 'Máximo disponible: ${producto.disponible.toStringAsFixed(0)}';
        notifyListeners();
        return;
      }
      _itemsDevueltos[idx].cantidad++;
    } else {
      _itemsDevueltos.add(ItemDevuelto(producto: producto));
    }
    _errorMsg = '';
    notifyListeners();
  }

  void incrementarDevuelto(int idx) {
    final item = _itemsDevueltos[idx];
    if (item.cantidad >= item.producto.disponible) {
      _errorMsg = 'Máximo disponible: ${item.producto.disponible.toStringAsFixed(0)}';
      notifyListeners();
      return;
    }
    item.cantidad++;
    _errorMsg = '';
    notifyListeners();
  }

  void decrementarDevuelto(int idx) {
    if (_itemsDevueltos[idx].cantidad > 1) {
      _itemsDevueltos[idx].cantidad--;
    } else {
      _itemsDevueltos.removeAt(idx);
    }
    notifyListeners();
  }

  void eliminarDevuelto(int idx) {
    _itemsDevueltos.removeAt(idx);
    notifyListeners();
  }

  void confirmarDevueltosYAvanzar() {
    if (_itemsDevueltos.isEmpty) {
      _errorMsg = 'Selecciona al menos un producto a devolver.';
      notifyListeners();
      return;
    }
    _errorMsg = '';
    _paso     = 3;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  // PASO 3 — Armar carrito de productos nuevos
  // ─────────────────────────────────────────────────────

  Future<void> buscarProductosNuevos(String query, int tiendaId) async {
    if (query.isEmpty) {
      _resultadosBusqueda = [];
      notifyListeners();
      return;
    }
    _buscandoProducto = true;
    notifyListeners();

    _resultadosBusqueda = await _inventarioService.getProductos(
      q:        query,
      tiendaId: tiendaId,
    );

    _buscandoProducto = false;
    notifyListeners();
  }

  void agregarNuevo(Producto producto) {
    final idx = _carritoNuevo.indexWhere(
        (i) => i.producto.id == producto.id);

    if (idx >= 0) {
      if (_carritoNuevo[idx].cantidad >= producto.stockActual) {
        _errorMsg = 'Stock máximo: ${producto.stockActual.toStringAsFixed(0)}';
        notifyListeners();
        return;
      }
      _carritoNuevo[idx].cantidad++;
    } else {
      _carritoNuevo.add(ItemNuevo(producto: producto));
    }
    _errorMsg = '';
    notifyListeners();
  }

  void incrementarNuevo(int idx) {
    final item = _carritoNuevo[idx];
    if (item.cantidad >= item.producto.stockActual) {
      _errorMsg = 'Stock máximo: ${item.producto.stockActual.toStringAsFixed(0)}';
      notifyListeners();
      return;
    }
    item.cantidad++;
    _errorMsg = '';
    notifyListeners();
  }

  void decrementarNuevo(int idx) {
    if (_carritoNuevo[idx].cantidad > 1) {
      _carritoNuevo[idx].cantidad--;
    } else {
      _carritoNuevo.removeAt(idx);
    }
    notifyListeners();
  }

  void eliminarNuevo(int idx) {
    _carritoNuevo.removeAt(idx);
    notifyListeners();
  }

  void confirmarNuevosYAvanzar() {
    if (_carritoNuevo.isEmpty) {
      _errorMsg = 'Agrega al menos un producto nuevo.';
      notifyListeners();
      return;
    }
    _errorMsg = '';
    _paso     = 4;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  // PASO 4 — Pagos y confirmación
  // ─────────────────────────────────────────────────────

  void agregarPago({required String metodo, required double monto}) {
    if (monto <= 0) {
      _errorMsg = 'El monto debe ser mayor a 0.';
      notifyListeners();
      return;
    }
    _pagos.add(PagoCambio(metodo: metodo, monto: monto));
    _errorMsg = '';
    notifyListeners();
  }

  void eliminarPago(int idx) {
    _pagos.removeAt(idx);
    notifyListeners();
  }

  Future<bool> procesarCambio({
    required int    sesionCajaId,
    int?            clienteId,
    String          observaciones = '',
  }) async {
    if (!saldoCubierto) {
      _errorMsg = 'Saldo pendiente: \$${saldoPendiente.toStringAsFixed(0)}. '
                  'Agrega un pago para cubrir la diferencia.';
      notifyListeners();
      return false;
    }

    _procesando = true;
    _errorMsg   = '';
    notifyListeners();

    final result = await _ventaService.procesarCambioPOS(
      sesionCajaId:      sesionCajaId,
      clienteId:         clienteId,
      detallesDevueltos: _itemsDevueltos.map((i) => i.toPayload()).toList(),
      productosNuevos:   _carritoNuevo.map((i)   => i.toPayload()).toList(),
      pagos:             _pagos.map((p)           => p.toPayload()).toList(),
      observaciones:     observaciones,
    );

    _procesando = false;

    if (result['success'] == true) {
      final factura = result['data']?['numero_factura'] ?? '';
      _successMsg = '✅ Cambio procesado — Factura: $factura';
      _resetEstado();
      notifyListeners();
      return true;
    }

    _errorMsg = result['error'] ?? 'Error al procesar el cambio';
    notifyListeners();
    return false;
  }

  // ─────────────────────────────────────────────────────
  // Navegación entre pasos
  // ─────────────────────────────────────────────────────

  void retrocederPaso() {
    if (_paso > 1) {
      _paso--;
      _errorMsg = '';
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────
  // Reset
  // ─────────────────────────────────────────────────────

  void _resetEstado() {
    _paso               = 1;
    _ventaOriginal      = null;
    _itemsDevueltos.clear();
    _carritoNuevo.clear();
    _pagos.clear();
    _resultadosBusqueda = [];
    _errorMsg           = '';
    // _successMsg se mantiene para que la UI lo muestre antes de limpiar
  }

  void resetCompleto() {
    _resetEstado();
    _successMsg = '';
    notifyListeners();
  }

  void limpiarMensajes() {
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }
}
