// lib/providers/pos_provider.dart

import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/item_carrito.dart';
import '../services/inventario_service.dart';
import '../services/venta_service.dart';

class PosProvider extends ChangeNotifier {
  final InventarioService _inventarioService = InventarioService();
  final VentaService      _ventaService      = VentaService();

  // ── Estado ────────────────────────────────────────────
  List<Producto>             _resultados    = [];
  List<ItemCarrito>          _carrito       = [];
  List<Map<String, dynamic>> _ventas        = [];
  Map<String, dynamic>?      _ventaDetalle;

  bool   _buscando      = false;
  bool   _procesando    = false;
  // ✅ FIX: flag separado para cargar ventas — no conflicto con cobrar
  bool   _cargandoVentas = false;
  String _errorMsg      = '';
  String _successMsg    = '';
  String _metodoPago    = 'efectivo';
  double _montoRecibido = 0;
  double _descuento     = 0;

  // ── Getters ───────────────────────────────────────────
  List<Producto>             get resultados     => _resultados;
  List<ItemCarrito>          get carrito        => _carrito;
  List<Map<String, dynamic>> get ventas         => _ventas;
  Map<String, dynamic>?      get ventaDetalle   => _ventaDetalle;
  bool                       get buscando       => _buscando;
  bool                       get procesando     => _procesando;
  bool                       get cargandoVentas => _cargandoVentas;
  String                     get errorMsg       => _errorMsg;
  String                     get successMsg     => _successMsg;
  String                     get metodoPago     => _metodoPago;
  double                     get montoRecibido  => _montoRecibido;
  double                     get descuento      => _descuento;

  double get total             => _carrito.fold(0, (sum, item) => sum + item.subtotal);
  double get totalConDescuento => (total - _descuento).clamp(0, double.infinity);
  double get vuelto            => (_montoRecibido - totalConDescuento).clamp(0, double.infinity);

  // ── Setters ───────────────────────────────────────────

  void setMetodoPago(String metodo) {
    _metodoPago = metodo;
    notifyListeners();
  }

  void setMontoRecibido(double monto) {
    _montoRecibido = monto;
    notifyListeners();
  }

  void setDescuento(double valor) {
    _descuento = valor.clamp(0, total);
    notifyListeners();
  }

  void setDescuentoPorcentaje(int pct) {
    _descuento = total * pct.clamp(0, 100) / 100;
    notifyListeners();
  }

  void setPrecioItem(int index, double nuevoPrecio) {
    if (index < 0 || index >= _carrito.length) return;
    _carrito[index].precioPersonalizado =
        (nuevoPrecio > 0) ? nuevoPrecio : null;
    notifyListeners();
  }

  // ── Búsqueda ──────────────────────────────────────────

  Future<void> buscarProductos(String query, int tiendaId) async {
    if (query.isEmpty) {
      _resultados = [];
      notifyListeners();
      return;
    }
    _buscando = true;
    notifyListeners();

    _resultados = await _inventarioService.getProductos(
      q:        query,
      tiendaId: tiendaId,
    );

    _buscando = false;
    notifyListeners();
  }

  // ── Carrito ───────────────────────────────────────────

  // ✅ FIX: verifica stock al agregar
  void agregarAlCarrito(Producto producto) {
    final index    = _carrito.indexWhere((i) => i.producto.id == producto.id);
    final stockMax = producto.stockActual.toInt();

    if (index >= 0) {
      if (_carrito[index].cantidad >= stockMax) {
        _errorMsg = 'Stock máximo: $stockMax unidades';
        notifyListeners();
        return;
      }
      _carrito[index].cantidad++;
    } else {
      _carrito.add(ItemCarrito(producto: producto));
    }
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }

  // ✅ FIX: verifica stock al incrementar
  void incrementar(int index) {
    final item     = _carrito[index];
    final stockMax = item.producto.stockActual.toInt();
    if (item.cantidad >= stockMax) {
      _errorMsg = 'Stock máximo: $stockMax unidades';
      notifyListeners();
      return;
    }
    item.cantidad++;
    _errorMsg = '';
    notifyListeners();
  }

  // ✅ FIX: ajusta descuento si el total baja al decrementar
  void decrementar(int index) {
    if (_carrito[index].cantidad > 1) {
      _carrito[index].cantidad--;
    } else {
      _carrito.removeAt(index);
    }
    _ajustarDescuento();
    notifyListeners();
  }

  // ✅ FIX: ajusta descuento si el total baja al eliminar
  void eliminarItem(int index) {
    _carrito.removeAt(index);
    _ajustarDescuento();
    notifyListeners();
  }

  void limpiarCarrito() {
    _carrito       = [];
    _resultados    = [];
    _montoRecibido = 0;
    _metodoPago    = 'efectivo';
    _errorMsg      = '';
    _successMsg    = '';
    _descuento     = 0;
    notifyListeners();
  }

  // ── Helper privado ────────────────────────────────────

  // ✅ FIX: evita descuento mayor al total cuando se reducen ítems
  void _ajustarDescuento() {
    if (_descuento > total) _descuento = total;
  }

  // ── Cobrar ────────────────────────────────────────────

  Future<bool> cobrar(int tiendaId) async {
    if (_carrito.isEmpty) {
      _errorMsg = 'El carrito está vacío';
      notifyListeners();
      return false;
    }
    if (_metodoPago == 'efectivo' && _montoRecibido < totalConDescuento) {
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
      'precio_unitario': item.precioUnitario.toString(),
      'descuento':       item.descuento.toString(),
    }).toList();

    final result = await _ventaService.crearVenta(
      tiendaId:      tiendaId,
      metodoPago:    _metodoPago,
      montoRecibido: _montoRecibido,
      descuento:     _descuento,
      detalles:      detalles,
    );

    _procesando = false;

    if (result['success'] == true) {
      // ✅ guardar msg ANTES de limpiar — limpiarCarrito() borra _successMsg
      final msg = '✅ Venta registrada — Vuelto: \$${vuelto.toStringAsFixed(0)}';
      limpiarCarrito();
      _successMsg = msg;
      notifyListeners();
      return true;
    }

    _errorMsg = result['error'] ?? 'Error desconocido';
    notifyListeners();
    return false;
  }

  // ── Listar ventas ─────────────────────────────────────

  // ✅ FIX: usa _cargandoVentas — no interfiere con _procesando de cobrar
  Future<void> cargarVentas({
    int?    tiendaId,
    String? fecha,
    int?    sesionId,
    int?    clienteId,
  }) async {
    _cargandoVentas = true;
    notifyListeners();

    _ventas = await _ventaService.listarVentas(
      tiendaId:  tiendaId,
      fecha:     fecha,
      sesionId:  sesionId,
      clienteId: clienteId,
    );

    _cargandoVentas = false;
    notifyListeners();
  }

  // ── Detalle venta ─────────────────────────────────────

  // ✅ FIX: usa _cargandoVentas
  Future<void> cargarVentaDetalle(int id) async {
    _cargandoVentas = true;
    _ventaDetalle   = null;
    notifyListeners();

    _ventaDetalle = await _ventaService.obtenerVenta(id);

    _cargandoVentas = false;
    notifyListeners();
  }

  // ── Anular venta ──────────────────────────────────────

  Future<bool> anularVenta(int id) async {
    _procesando = true;
    _errorMsg   = '';
    notifyListeners();

    final result = await _ventaService.anularVenta(id);
    _procesando  = false;

    if (result['success'] == true) {
      _successMsg = '✅ Venta anulada correctamente';
      _ventas = _ventas.map((v) =>
          v['id'] == id ? {...v, 'estado': 'anulada'} : v
      ).toList();
    } else {
      _errorMsg = result['error'] ?? 'Error al anular la venta';
    }

    notifyListeners();
    return result['success'] == true;
  }

  // ── Limpiar mensajes ──────────────────────────────────

  void limpiarMensajes() {
    _errorMsg   = '';
    _successMsg = '';
    notifyListeners();
  }
}