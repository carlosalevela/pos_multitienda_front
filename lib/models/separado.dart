// ── Helper global del archivo ─────────────────────────
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

// ═════════════════════════════════════════════════════
class DetalleSeparado {
  final int    id;
  final int    producto;
  final String productoNombre;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  DetalleSeparado({
    required this.id,
    required this.producto,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory DetalleSeparado.fromJson(Map<String, dynamic> j) => DetalleSeparado(
    id:             j['id'],
    producto:       j['producto'],
    productoNombre: j['producto_nombre'] ?? '',
    cantidad:       _toDouble(j['cantidad']),
    precioUnitario: _toDouble(j['precio_unitario']),
    subtotal:       _toDouble(j['subtotal']),
  );

  Map<String, dynamic> toJson() => {
    'producto':        producto,
    'cantidad':        cantidad,
    'precio_unitario': precioUnitario,
  };
}

// ═════════════════════════════════════════════════════
class AbonoSeparado {
  final int     id;
  final int     separado;
  final String? empleadoNombre;
  final double  monto;
  final String  metodoPago;
  final String  createdAt;

  AbonoSeparado({
    required this.id,
    required this.separado,
    this.empleadoNombre,
    required this.monto,
    required this.metodoPago,
    required this.createdAt,
  });

  factory AbonoSeparado.fromJson(Map<String, dynamic> j) => AbonoSeparado(
    id:             j['id'],
    separado:       j['separado'],
    empleadoNombre: j['empleado_nombre'],
    monto:          _toDouble(j['monto']),
    metodoPago:     j['metodo_pago'] ?? 'efectivo',
    createdAt:      j['created_at']  ?? '',
  );
}

// ═════════════════════════════════════════════════════
class Separado {
  final int                   id;
  final int                   tienda;
  final String                tiendaNombre;
  final int                   cliente;
  final String                clienteNombre;
  final String?               empleadoNombre;
  final double                total;
  final double                abonoAcumulado;
  final double                saldoPendiente;
  final String?               fechaLimite;
  final String                estado;
  final String                createdAt;
  final List<DetalleSeparado> detalles;
  final List<AbonoSeparado>   abonos;

  Separado({
    required this.id,
    required this.tienda,
    required this.tiendaNombre,
    required this.cliente,
    required this.clienteNombre,
    this.empleadoNombre,
    required this.total,
    required this.abonoAcumulado,
    required this.saldoPendiente,
    this.fechaLimite,
    required this.estado,
    required this.createdAt,
    required this.detalles,
    required this.abonos,
  });

  factory Separado.fromJson(Map<String, dynamic> j) => Separado(
    id:             j['id'],
    tienda:         j['tienda'],
    tiendaNombre:   j['tienda_nombre']   ?? '',
    cliente:        j['cliente'],
    clienteNombre:  j['cliente_nombre']  ?? '',
    empleadoNombre: j['empleado_nombre'],
    total:          _toDouble(j['total']),
    abonoAcumulado: _toDouble(j['abono_acumulado']),
    saldoPendiente: _toDouble(j['saldo_pendiente']),
    fechaLimite:    j['fecha_limite'],
    estado:         j['estado']      ?? 'activo',
    createdAt:      j['created_at']  ?? '',
    detalles: (j['detalles'] as List? ?? [])
        .map((e) => DetalleSeparado.fromJson(e)).toList(),
    abonos: (j['abonos'] as List? ?? [])
        .map((e) => AbonoSeparado.fromJson(e)).toList(),
  );

  // ── Getters de estado ────────────────────────────────
  bool   get esActivo    => estado == 'activo';
  bool   get esPagado    => estado == 'pagado';
  bool   get esCancelado => estado == 'cancelado';
  double get progreso    => total > 0 ? abonoAcumulado / total : 0.0;

  // ── Para actualización local en provider ─────────────
  Map<String, dynamic> toJsonUpdate() => {
    'id':              id,
    'tienda':          tienda,
    'tienda_nombre':   tiendaNombre,
    'cliente':         cliente,
    'cliente_nombre':  clienteNombre,
    'empleado_nombre': empleadoNombre,
    'total':           total,
    'abono_acumulado': abonoAcumulado,
    'saldo_pendiente': saldoPendiente,
    'fecha_limite':    fechaLimite,
    'estado':          estado,
    'created_at':      createdAt,
    'detalles': detalles.map((d) => {
      'id':              d.id,
      'producto':        d.producto,
      'producto_nombre': d.productoNombre,
      'cantidad':        d.cantidad,
      'precio_unitario': d.precioUnitario,
      'subtotal':        d.subtotal,
    }).toList(),
    'abonos': abonos.map((a) => {
      'id':              a.id,
      'separado':        a.separado,
      'empleado_nombre': a.empleadoNombre,
      'monto':           a.monto,
      'metodo_pago':     a.metodoPago,
      'created_at':      a.createdAt,
    }).toList(),
  };
}