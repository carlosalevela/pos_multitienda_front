import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/item_carrito.dart';
import '../services/producto_service.dart';
import '../services/venta_service.dart';

class PosProvider extends ChangeNotifier {
  final ProductoService _productoService = ProductoService();
  final VentaService    _ventaService    = VentaService();

  List<Producto>    _resultados  = [];
  List<ItemCarrito> _carrito     = [];
  bool   _buscando    = false;
  bool   _procesando  = false;
  String _errorMsg    = '';
  String _successMsg  = '';
  String _metodoPago  = 'efectivo';
  double _montoRecibido = 0;

  List<Producto>    get resultados    => _resultados;
  List<ItemCarrito> get carrito       => _carrito;
  bool   get buscando     => _buscando;
  bool   get procesando   => _procesando;
  String get errorMsg     => _errorMsg;
  String get successMsg   => _successMsg;
  String get metodoPago   => _metodoPago;
  double get montoRecibido => _montoRecibido;

  double get total => _carrito.fold(0, (sum, item) => sum + item.subtotal);
  double get vuelto => (_montoRecibido - total).clamp(0, double.infinity);

  void setMetodoPago(String metodo) {
    _metodoPago = metodo;
    notifyListeners();
  }

  void setMontoRecibido(double monto) {
    _montoRecibido = monto;
    notifyListeners();
  }

  Future<void> buscarProductos(String query, int tiendaId) async {
    if (query.isEmpty) {
      _resultados = [];
      notifyListeners();
      return;
    }
    _buscando = true;
    notifyListeners();
    _resultados = await _productoService.buscarProductos(query, tiendaId);
    _buscando   = false;
    notifyListeners();
  }

  void agregarAlCarrito(Producto producto) {
    final index = _carrito.indexWhere((i) => i.producto.id == producto.id);
    if (index >= 0) {
      _carrito[index].cantidad++;
    } else {
      _carrito.add(ItemCarrito(producto: producto));
    }
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }

  void incrementar(int index) {
    _carrito[index].cantidad++;
    notifyListeners();
  }

  void decrementar(int index) {
    if (_carrito[index].cantidad > 1) {
      _carrito[index].cantidad--;
    } else {
      _carrito.removeAt(index);
    }
    notifyListeners();
  }

  void eliminarItem(int index) {
    _carrito.removeAt(index);
    notifyListeners();
  }

  void limpiarCarrito() {
    _carrito       = [];
    _resultados    = [];
    _montoRecibido = 0;
    _metodoPago    = 'efectivo';
    _errorMsg      = '';
    _successMsg    = '';
    notifyListeners();
  }

  Future<bool> cobrar(int tiendaId) async {
    if (_carrito.isEmpty) {
      _errorMsg = 'El carrito está vacío';
      notifyListeners();
      return false;
    }
    if (_metodoPago == 'efectivo' && _montoRecibido < total) {
      _errorMsg = 'El monto recibido es menor al total';
      notifyListeners();
      return false;
    }

    _procesando = true;
    _errorMsg   = '';
    notifyListeners();

    final detalles = _carrito.map((item) => {
      'producto':        item.producto.id,
      'cantidad':        item.cantidad.toString(),
      'precio_unitario': item.producto.precio.toString(),
      'descuento':       item.descuento.toString(),
    }).toList();

    final result = await _ventaService.crearVenta(
      tiendaId:      tiendaId,
      metodoPago:    _metodoPago,
      montoRecibido: _montoRecibido,
      detalles:      detalles,
    );

    _procesando = false;

    if (result['success']) {
      _successMsg = '✅ Venta registrada — Vuelto: \$${vuelto.toStringAsFixed(0)}';
      limpiarCarrito();
      notifyListeners();
      return true;
    } else {
      _errorMsg = result['error'];
      notifyListeners();
      return false;
    }
  }
}