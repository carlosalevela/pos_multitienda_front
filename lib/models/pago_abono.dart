// lib/models/pago_abono.dart
//
// Una linea de pago de un abono a separado.
//
// Un abono normal es una sola linea; un abono mixto son varias
// (por ejemplo 150.000 en efectivo + 80.000 por Nequi).
// El backend crea un MovimientoCaja por linea, cada uno con su
// metodo y su cuenta, para que el cierre y el formato diario cuadren.

class PagoAbono {
  final String metodoPago; // efectivo | transferencia | tarjeta
  final double monto;
  final int? cuentaId; // null en efectivo

  const PagoAbono({
    required this.metodoPago,
    required this.monto,
    this.cuentaId,
  });

  bool get esEfectivo => metodoPago == 'efectivo';

  /// Necesita cuenta destino y todavia no la tiene.
  bool get faltaCuenta => !esEfectivo && cuentaId == null;

  PagoAbono copyWith({String? metodoPago, double? monto, int? cuentaId}) =>
      PagoAbono(
        metodoPago: metodoPago ?? this.metodoPago,
        monto: monto ?? this.monto,
        // Al cambiar a efectivo la cuenta se descarta siempre.
        cuentaId: (metodoPago ?? this.metodoPago) == 'efectivo'
            ? null
            : (cuentaId ?? this.cuentaId),
      );

  Map<String, dynamic> toJson() => {
        'monto': monto.toStringAsFixed(2),
        'metodo_pago': metodoPago,
        if (cuentaId != null) 'cuenta_destino': cuentaId,
      };

  @override
  String toString() => '$metodoPago:$monto${cuentaId != null ? '@$cuentaId' : ''}';
}
