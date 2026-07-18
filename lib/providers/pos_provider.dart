// lib/providers/pos_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto.dart';
import '../models/item_carrito.dart';
import '../services/inventario_service.dart';
import '../services/venta_service.dart';

// ── Snapshot de un ticket parkado ─────────────────────────────
class TicketParkado {
  final List<ItemCarrito> carrito;
  final String            metodoPago;
  final double            montoRecibido;
  final double            descuento;
  final int               numero;

  const TicketParkado({
    required this.carrito,
    required this.metodoPago,
    required this.montoRecibido,
    required this.descuento,
    required this.numero,
  });

  double get total => carrito.fold(0, (s, i) => s + i.subtotal);
  int    get items => carrito.fold(0, (s, i) => s + i.cantidad);

  Map<String, dynamic> toJson() => {
    'numero':         numero,
    'metodoPago':     metodoPago,
    'montoRecibido':  montoRecibido,
    'descuento':      descuento,
    'items': carrito.map((i) => {
      'producto':           i.producto.toJson(),
      'cantidad':           i.cantidad,
      'descuento':          i.descuento,
      'precioPersonalizado': i.precioPersonalizado,
    }).toList(),
  };

  factory TicketParkado.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List).map((e) {
      final item = ItemCarrito(
        producto:  Producto.fromJson(e['producto'] as Map<String, dynamic>),
        cantidad:  (e['cantidad'] as num).toInt(),
        descuento: (e['descuento'] as num).toDouble(),
      );
      if (e['precioPersonalizado'] != null) {
        item.precioPersonalizado = (e['precioPersonalizado'] as num).toDouble();
      }
      return item;
    }).toList();
    return TicketParkado(
      numero:        (j['numero'] as num).toInt(),
      metodoPago:    j['metodoPago'] as String,
      montoRecibido: (j['montoRecibido'] as num).toDouble(),
      descuento:     (j['descuento'] as num).toDouble(),
      carrito:       items,
    );
  }
}

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
  bool   _cargandoVentas = false;
  String _errorMsg      = '';
  String _successMsg    = '';
  String _metodoPago    = 'efectivo';
  double _montoRecibido = 0;
  double _descuento     = 0;

  // ── Tickets parkados ──────────────────────────────────
  static const _kStorageKey = 'pos_tickets_parkados';
  final List<TicketParkado> _ticketsParkados = [];
  int  _contadorTickets = 1;
  int? _numeroActual;

  // ── Última venta (para recibo) ────────────────────────
  Map<String, dynamic>? _ultimaVenta;

  // ── Getters ───────────────────────────────────────────
  List<Producto>             get resultados        => _resultados;
  List<ItemCarrito>          get carrito           => _carrito;
  List<Map<String, dynamic>> get ventas            => _ventas;
  Map<String, dynamic>?      get ventaDetalle      => _ventaDetalle;
  bool                       get buscando          => _buscando;
  bool                       get procesando        => _procesando;
  bool                       get cargandoVentas    => _cargandoVentas;
  String                     get errorMsg          => _errorMsg;
  String                     get successMsg        => _successMsg;
  String                     get metodoPago        => _metodoPago;
  double                     get montoRecibido     => _montoRecibido;
  double                     get descuento         => _descuento;
  List<TicketParkado>        get ticketsParkados   => List.unmodifiable(_ticketsParkados);
  bool                       get hayTicketsParkados => _ticketsParkados.isNotEmpty;
  int                        get numTicketsParkados => _ticketsParkados.length;
  int?                       get numeroActual       => _numeroActual;
  Map<String, dynamic>?      get ultimaVenta        => _ultimaVenta;

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
    await cargarProductos(q: query, tiendaId: tiendaId);
  }

  /// Carga productos sin restricción de query vacío.
  /// Usado para browsing por categoría o carga inicial del POS.
  Future<void> cargarProductos({
    String? q,
    int?    tiendaId,
    int?    categoriaId,
  }) async {
    _buscando = true;
    notifyListeners();

    final result = await _inventarioService.getProductos(
      q:           q,
      tiendaId:    tiendaId,
      categoriaId: categoriaId,
    );

    if (result['success'] == true) {
      _resultados = result['data'] as List<Producto>;
    } else {
      _resultados = [];
      _errorMsg   = result['error'] ?? 'Error al cargar productos';
    }

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
      final eraMayoreo = _carrito[index].aplicaMayoreo;
      _carrito[index].cantidad++;
      if (!eraMayoreo && _carrito[index].aplicaMayoreo) {
        _successMsg = '¡Precio mayoreo activado: \$${_carrito[index].precioUnitario.toStringAsFixed(0)}/ud!';
      } else {
        _successMsg = '';
      }
    } else {
      _carrito.add(ItemCarrito(producto: producto));
      _successMsg = '';
    }
    _errorMsg = '';
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
    final eraMayoreo = item.aplicaMayoreo;
    item.cantidad++;
    if (!eraMayoreo && item.aplicaMayoreo) {
      _successMsg = '¡Precio mayoreo activado: \$${item.precioUnitario.toStringAsFixed(0)}/ud!';
    } else if (eraMayoreo && !item.aplicaMayoreo) {
      _successMsg = '';
    }
    _errorMsg = '';
    notifyListeners();
  }

  // ✅ FIX: ajusta descuento si el total baja al decrementar
  void decrementar(int index) {
    if (_carrito[index].cantidad > 1) {
      final eraMayoreo = _carrito[index].aplicaMayoreo;
      _carrito[index].cantidad--;
      if (eraMayoreo && !_carrito[index].aplicaMayoreo) {
        _successMsg = '';
      }
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
    _montoRecibido = 0;
    _metodoPago    = 'efectivo';
    _errorMsg      = '';
    _successMsg    = '';
    _descuento     = 0;
    _numeroActual  = null;
    notifyListeners();
  }

  // ── Tickets parkados ──────────────────────────────────

  /// Guarda el carrito actual como ticket parkado y limpia para uno nuevo.
  /// Solo parka si hay items en el carrito.
  bool parquearTicket() {
    if (_carrito.isEmpty) return false;
    _ticketsParkados.add(TicketParkado(
      carrito:       List.from(_carrito),
      metodoPago:    _metodoPago,
      montoRecibido: _montoRecibido,
      descuento:     _descuento,
      numero:        _numeroActual ?? _contadorTickets++,
    ));
    _carrito       = [];
    _montoRecibido = 0;
    _metodoPago    = 'efectivo';
    _descuento     = 0;
    _errorMsg      = '';
    _successMsg    = '';
    _numeroActual  = null;
    _guardarTickets();
    notifyListeners();
    return true;
  }

  /// Restaura un ticket parkado al carrito activo.
  /// Si el carrito activo tiene items, lo parka primero (conservando su número).
  void restaurarTicket(int index) {
    if (index < 0 || index >= _ticketsParkados.length) return;
    if (_carrito.isNotEmpty) {
      _ticketsParkados.add(TicketParkado(
        carrito:       List.from(_carrito),
        metodoPago:    _metodoPago,
        montoRecibido: _montoRecibido,
        descuento:     _descuento,
        numero:        _numeroActual ?? _contadorTickets++,
      ));
    }
    final snap    = _ticketsParkados.removeAt(index);
    _carrito       = List.from(snap.carrito);
    _metodoPago    = snap.metodoPago;
    _montoRecibido = snap.montoRecibido;
    _descuento     = snap.descuento;
    _numeroActual  = snap.numero;
    _errorMsg      = '';
    _successMsg    = '';
    _guardarTickets();
    notifyListeners();
  }

  /// Descarta un ticket parkado sin restaurarlo.
  void descartarTicketParkado(int index) {
    if (index < 0 || index >= _ticketsParkados.length) return;
    _ticketsParkados.removeAt(index);
    _guardarTickets();
    notifyListeners();
  }

  // ── Persistencia de tickets parkados ──────────────────

  /// Serializa y guarda todos los tickets parkados en disco.
  void _guardarTickets() {
    SharedPreferences.getInstance().then((prefs) {
      final payload = jsonEncode({
        'contador': _contadorTickets,
        'tickets':  _ticketsParkados.map((t) => t.toJson()).toList(),
      });
      prefs.setString(_kStorageKey, payload);
    });
  }

  /// Carga los tickets parkados que quedaron guardados en disco.
  /// Llamar una vez al iniciar la app (en main.dart o en el widget raíz).
  Future<void> cargarTicketsGuardados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kStorageKey);
      if (raw == null || raw.isEmpty) return;

      final data    = jsonDecode(raw) as Map<String, dynamic>;
      _contadorTickets = (data['contador'] as num?)?.toInt() ?? 1;

      final lista = (data['tickets'] as List?) ?? [];
      _ticketsParkados.clear();
      for (final item in lista) {
        try {
          _ticketsParkados.add(
            TicketParkado.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // Ticket corrupto — ignorar ese ticket en lugar de romper todo
        }
      }
      if (_ticketsParkados.isNotEmpty) notifyListeners();
    } catch (_) {
      // Si el storage está corrupto, empezar limpio
    }
  }

  /// Borra los tickets guardados (llamar al hacer logout o cambio de tienda).
  Future<void> limpiarTicketsGuardados() async {
    _ticketsParkados.clear();
    _contadorTickets = 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStorageKey);
    notifyListeners();
  }

  // ── Helper privado ────────────────────────────────────

  // ✅ FIX: evita descuento mayor al total cuando se reducen ítems
  void _ajustarDescuento() {
    if (_descuento > total) _descuento = total;
  }

  // ── Cobrar ────────────────────────────────────────────

  Future<bool> cobrar(int tiendaId, {int? clienteId}) async {
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
      clienteId:     clienteId,
      detalles:      detalles,
    );

    _procesando = false;

    if (result['success'] == true) {
      final msg = '✅ Venta registrada — Vuelto: \$${vuelto.toStringAsFixed(0)}';
      _ultimaVenta = result['data'] as Map<String, dynamic>?;
      limpiarCarrito();
      _successMsg = msg;
      notifyListeners();
      return true;
    }

    _errorMsg = result['error'] ?? 'Error desconocido';

    // Si el error es de stock, refrescar inventario del carrito para que
    // el cajero vea inmediatamente la cantidad real disponible.
    if (_errorMsg.toLowerCase().contains('stock')) {
      await _refrescarStockCarrito(tiendaId);
    }

    notifyListeners();
    return false;
  }

  Future<void> _refrescarStockCarrito(int tiendaId) async {
    if (_carrito.isEmpty) return;
    final result = await _inventarioService.getProductos(tiendaId: tiendaId);
    if (result['success'] != true) return;

    final Map<int, Producto> frescos = {
      for (final p in result['data'] as List<Producto>) p.id: p,
    };

    final nuevos = <ItemCarrito>[];
    for (final item in _carrito) {
      final fresco = frescos[item.producto.id] ?? item.producto;
      final stockDisp = fresco.stockActual.toInt();
      if (stockDisp <= 0) continue; // sin stock — sacar del carrito
      final nuevaCantidad = item.cantidad.clamp(1, stockDisp);
      nuevos.add(ItemCarrito(
        producto:           fresco,
        cantidad:           nuevaCantidad,
        descuento:          item.descuento,
      )..precioPersonalizado = item.precioPersonalizado);
    }
    _carrito = nuevos;
    _ajustarDescuento();
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