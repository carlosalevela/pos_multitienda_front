class Bono {
  final int    id;
  final String codigo;
  final double valorOriginal;
  final double saldo;
  final String estado;
  final bool   estaVigente;
  final String fechaVencimiento;
  final String createdAt;
  final String? tiendaOrigenNombre;
  final String? clienteNombre;

  const Bono({
    required this.id,
    required this.codigo,
    required this.valorOriginal,
    required this.saldo,
    required this.estado,
    required this.estaVigente,
    required this.fechaVencimiento,
    required this.createdAt,
    this.tiendaOrigenNombre,
    this.clienteNombre,
  });

  factory Bono.fromJson(Map<String, dynamic> j) => Bono(
        id:                 j['id'] as int,
        codigo:             j['codigo'] as String,
        valorOriginal:      double.parse(j['valor_original'].toString()),
        saldo:              double.parse(j['saldo'].toString()),
        estado:             j['estado'] as String,
        estaVigente:        j['esta_vigente'] as bool? ?? false,
        fechaVencimiento:   j['fecha_vencimiento'] as String? ?? '',
        createdAt:          j['created_at'] as String? ?? '',
        tiendaOrigenNombre: j['tienda_origen_nombre'] as String?,
        clienteNombre:      j['cliente_nombre'] as String?,
      );
}
