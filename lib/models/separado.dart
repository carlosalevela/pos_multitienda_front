// ── Helper global del archivo ──────────────────────────
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
    id:             j['id']              as int,
    producto:       j['producto']        as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    cantidad:       _toDouble(j['cantidad']),
    precioUnitario: _toDouble(j['precio_unitario']),
    subtotal:       _toDouble(j['subtotal']),
  );

  Map<String, dynamic> toJson() => {
    'producto':        producto,
    'cantidad':        cantidad,
    'precio_unitario': precioUnitario,
  };

  // ✅ toJsonUpdate para reconstrucción local
  Map<String, dynamic> toJsonFull() => {
    'id':              id,
    'producto':        producto,
    'producto_nombre': productoNombre,
    'cantidad':        cantidad,
    'precio_unitario': precioUnitario,
    'subtotal':        subtotal,
  };
}


// ═════════════════════════════════════════════════════
class AbonoSeparado {
  final int     id;
  final int     separado;
  final String? empleadoNombre;
  final double  monto;
  final String  metodoPago;
  final DateTime createdAt;   // ✅ DateTime en lugar de String
  final String? cuentaNombre;

  AbonoSeparado({
    required this.id,
    required this.separado,
    this.empleadoNombre,
    required this.monto,
    required this.metodoPago,
    required this.createdAt,
    this.cuentaNombre,
  });

  factory AbonoSeparado.fromJson(Map<String, dynamic> j) => AbonoSeparado(
    id:             j['id']      as int,
    separado:       j['separado'] as int,
    empleadoNombre: j['empleado_nombre'] as String?,
    monto:          _toDouble(j['monto']),
    metodoPago:     j['metodo_pago'] as String? ?? 'efectivo',
    createdAt:      j['created_at'] != null        // ✅ parseo seguro
        ? DateTime.parse(j['created_at'] as String).toLocal()
        : DateTime.now(),
    cuentaNombre:   j['cuenta_nombre'] as String?,
  );

  Map<String, dynamic> toJsonFull() => {
    'id':              id,
    'separado':        separado,
    'empleado_nombre': empleadoNombre,
    'monto':           monto,
    'metodo_pago':     metodoPago,
    'created_at':      createdAt.toIso8601String(),
  };
}


// ═════════════════════════════════════════════════════
class Separado {
  final int                   id;
  final int                   tienda;
  final String                tiendaNombre;
  final int                   cliente;
  final String                clienteNombre;
  final String?               clienteCedulaNit;
  final String?               clienteTelefono;
  final String?               empleadoNombre;
  final double                total;
  final double                abonoAcumulado;
  final double                saldoPendiente;
  final String?               fechaLimite;
  final String                estado;
  final DateTime              createdAt;
  final List<DetalleSeparado> detalles;
  final List<AbonoSeparado>   abonos;
  /// Cuándo recogió el producto (solo pagados).
  final DateTime?             entregadoAt;
  final String?               entregadoPorNombre;
  /// Al cancelar, lo abonado queda en un bono a nombre del cliente.
  final String?               bonoCodigo;
  final double?               bonoSaldo;
  final String?               bonoEstado;
  final String?               bonoVence;
  final String                motivoCancelacion;

  Separado({
    required this.id,
    required this.tienda,
    required this.tiendaNombre,
    required this.cliente,
    required this.clienteNombre,
    this.clienteCedulaNit,
    this.clienteTelefono,
    this.empleadoNombre,
    required this.total,
    required this.abonoAcumulado,
    required this.saldoPendiente,
    this.fechaLimite,
    required this.estado,
    required this.createdAt,
    required this.detalles,
    required this.abonos,
    this.entregadoAt,
    this.entregadoPorNombre,
    this.bonoCodigo,
    this.bonoSaldo,
    this.bonoEstado,
    this.bonoVence,
    this.motivoCancelacion = '',
  });

  factory Separado.fromJson(Map<String, dynamic> j) => Separado(
    id:               j['id']     as int,
    tienda:           j['tienda'] as int,
    tiendaNombre:     j['tienda_nombre']     as String? ?? '',
    cliente:          j['cliente']           as int,
    clienteNombre:    j['cliente_nombre']    as String? ?? '',
    clienteCedulaNit: j['cliente_cedula_nit'] as String?,
    clienteTelefono:  j['cliente_telefono']  as String?,
    empleadoNombre:   j['empleado_nombre']   as String?,
    total:            _toDouble(j['total']),
    abonoAcumulado: _toDouble(j['abono_acumulado']),
    saldoPendiente: _toDouble(j['saldo_pendiente']),
    fechaLimite:    j['fecha_limite'] as String?,
    estado:         j['estado']      as String? ?? 'activo',
    createdAt:      j['created_at'] != null           // ✅ parseo seguro
        ? DateTime.parse(j['created_at'] as String).toLocal()
        : DateTime.now(),
    detalles: (j['detalles'] as List? ?? [])
        .map((e) => DetalleSeparado.fromJson(e as Map<String, dynamic>))
        .toList(),
    abonos: (j['abonos'] as List? ?? [])
        .map((e) => AbonoSeparado.fromJson(e as Map<String, dynamic>))
        .toList(),
    entregadoAt: j['entregado_at'] != null
        ? DateTime.tryParse(j['entregado_at'].toString())?.toLocal()
        : null,
    entregadoPorNombre: j['entregado_por_nombre'] as String?,
    bonoCodigo: j['bono_codigo'] as String?,
    bonoSaldo:  j['bono_saldo'] == null ? null : _toDouble(j['bono_saldo']),
    bonoEstado: j['bono_estado'] as String?,
    bonoVence:  j['bono_vence'] as String?,
    motivoCancelacion: j['motivo_cancelacion'] as String? ?? '',
  );

  // ✅ copyWith — resuelve el error del provider
  Separado copyWith({
    int?                   id,
    int?                   tienda,
    String?                tiendaNombre,
    int?                   cliente,
    String?                clienteNombre,
    String?                clienteCedulaNit,
    String?                clienteTelefono,
    String?                empleadoNombre,
    double?                total,
    double?                abonoAcumulado,
    double?                saldoPendiente,
    String?                fechaLimite,
    String?                estado,
    DateTime?              createdAt,
    List<DetalleSeparado>? detalles,
    List<AbonoSeparado>?   abonos,
    DateTime?              entregadoAt,
    String?                entregadoPorNombre,
    String?                bonoCodigo,
    double?                bonoSaldo,
    String?                bonoEstado,
    String?                bonoVence,
    String?                motivoCancelacion,
  }) =>
      Separado(
        id:               id               ?? this.id,
        tienda:           tienda           ?? this.tienda,
        tiendaNombre:     tiendaNombre     ?? this.tiendaNombre,
        cliente:          cliente          ?? this.cliente,
        clienteNombre:    clienteNombre    ?? this.clienteNombre,
        clienteCedulaNit: clienteCedulaNit ?? this.clienteCedulaNit,
        clienteTelefono:  clienteTelefono  ?? this.clienteTelefono,
        empleadoNombre:   empleadoNombre   ?? this.empleadoNombre,
        total:          total          ?? this.total,
        abonoAcumulado: abonoAcumulado ?? this.abonoAcumulado,
        saldoPendiente: saldoPendiente ?? this.saldoPendiente,
        fechaLimite:    fechaLimite    ?? this.fechaLimite,
        estado:         estado         ?? this.estado,
        createdAt:      createdAt      ?? this.createdAt,
        detalles:       detalles       ?? this.detalles,
        abonos:         abonos         ?? this.abonos,
        entregadoAt:        entregadoAt        ?? this.entregadoAt,
        entregadoPorNombre: entregadoPorNombre ?? this.entregadoPorNombre,
        bonoCodigo:         bonoCodigo         ?? this.bonoCodigo,
        bonoSaldo:          bonoSaldo          ?? this.bonoSaldo,
        bonoEstado:         bonoEstado         ?? this.bonoEstado,
        bonoVence:          bonoVence          ?? this.bonoVence,
        motivoCancelacion:  motivoCancelacion  ?? this.motivoCancelacion,
      );

  // ── Getters de estado ──────────────────────────────────────
  bool   get esActivo    => estado == 'activo';
  bool   get esPagado    => estado == 'pagado';
  bool   get esCancelado => estado == 'cancelado';
  bool   get entregado   => entregadoAt != null;
  /// Pagado completo pero el cliente todavía no lo recoge.
  bool   get porEntregar => esPagado && entregadoAt == null;
  double get progreso    => total > 0 ? (abonoAcumulado / total).clamp(0.0, 1.0) : 0.0; // ✅ clamp

  // ── Para actualización local ───────────────────────────────
  // ✅ Renombrado de toJsonUpdate a toJsonFull — más descriptivo
  //    y usa los nuevos toJsonFull de los sub-modelos
  Map<String, dynamic> toJsonFull() => {
    'id':                 id,
    'tienda':             tienda,
    'tienda_nombre':      tiendaNombre,
    'cliente':            cliente,
    'cliente_nombre':     clienteNombre,
    'cliente_cedula_nit': clienteCedulaNit,
    'cliente_telefono':   clienteTelefono,
    'empleado_nombre':    empleadoNombre,
    'total':           total,
    'abono_acumulado': abonoAcumulado,
    'saldo_pendiente': saldoPendiente,
    'fecha_limite':    fechaLimite,
    'estado':          estado,
    'created_at':      createdAt.toIso8601String(),
    'detalles':        detalles.map((d) => d.toJsonFull()).toList(),
    'abonos':          abonos.map((a) => a.toJsonFull()).toList(),
  };

  @override
  bool operator ==(Object other) => other is Separado && other.id == id;

  @override
  int get hashCode => id.hashCode;
}