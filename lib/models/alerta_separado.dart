// models/alerta_separado.dart
class AlertaSeparado {
  final int    id;
  final String cliente;
  final String tienda;
  final double saldoPendiente;
  final String fechaLimite;
  final int    diasRestantes;

  AlertaSeparado({
    required this.id,
    required this.cliente,
    required this.tienda,
    required this.saldoPendiente,
    required this.fechaLimite,
    required this.diasRestantes,
  });

  factory AlertaSeparado.fromJson(Map<String, dynamic> j) => AlertaSeparado(
    id:             j['id'],
    cliente:        j['cliente']          ?? '',
    tienda:         j['tienda']           ?? '',
    saldoPendiente: _toDouble(j['saldo_pendiente']),
    fechaLimite:    j['fecha_limite']     ?? '',
    diasRestantes:  j['dias_restantes']   ?? 0,
  );

  bool get esVencido => diasRestantes < 0;

  String get etiquetaDias {
    if (diasRestantes < 0) return 'Venció hace ${diasRestantes.abs()} día(s)';
    if (diasRestantes == 0) return 'Vence hoy';
    return 'Vence en $diasRestantes día(s)';
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}