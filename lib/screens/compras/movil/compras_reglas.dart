// lib/screens/compras/movil/compras_reglas.dart
//
// Reglas de Compras en el celular (sin pantalla: se prueban solas). Las
// órdenes llegan del servidor como mapas.

double numDe(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

DateTime? fechaDe(Object? v) =>
    v == null || '$v'.isEmpty ? null : DateTime.tryParse('$v')?.toLocal();

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

enum FiltroOrdenes { todas, pendientes, recibidas, canceladas, credito }

bool esCredito(Map c) => c['a_credito'] == true;
bool esPendiente(Map c) => c['estado'] == 'pendiente';
bool esRecibida(Map c) => c['estado'] == 'recibida';

/// A crédito, recibida y sin pagar: se le debe al proveedor.
bool porPagar(Map c) => esCredito(c) && esRecibida(c) && c['pagado'] != true;

/// Días para pagar (negativo = vencida hace N días); null sin fecha.
int? diasParaPagar(Map c, DateTime hoy) {
  final v = fechaDe(c['fecha_vencimiento']);
  return v == null ? null : _dia(v).difference(_dia(hoy)).inDays;
}

bool vencida(Map c, DateTime hoy) {
  final d = diasParaPagar(c, hoy);
  return porPagar(c) && d != null && d < 0;
}

/// "Vencida hace 7 días", "Vence hoy", "Vence mañana", "Vence en 5 días".
String textoPago(int dias) {
  if (dias < -1) return 'Vencida hace ${-dias} días';
  if (dias == -1) return 'Venció ayer';
  if (dias == 0) return 'Vence hoy';
  if (dias == 1) return 'Vence mañana';
  return 'Vence en $dias días';
}

bool cumpleFiltroOrden(Map c, FiltroOrdenes f) => switch (f) {
      FiltroOrdenes.todas      => true,
      FiltroOrdenes.pendientes => esPendiente(c),
      FiltroOrdenes.recibidas  => esRecibida(c),
      FiltroOrdenes.canceladas => c['estado'] == 'cancelada',
      FiltroOrdenes.credito    => esCredito(c) && c['estado'] != 'cancelada',
    };

bool coincideBusqueda(Map c, String q) {
  final t = q.trim().toLowerCase();
  if (t.isEmpty) return true;
  return '${c['numero_orden'] ?? ''}'.toLowerCase().contains(t) ||
      '${c['proveedor_nombre'] ?? ''}'.toLowerCase().contains(t);
}

List<Map<String, dynamic>> ordenesVisibles(List<Map<String, dynamic>> l,
        FiltroOrdenes f, String q) =>
    l.where((c) => cumpleFiltroOrden(c, f) && coincideBusqueda(c, q)).toList();

/// Las tiendas a las que llega: la de la orden o las del reparto.
List<String> tiendasDeOrden(Map c) {
  final una = '${c['tienda_nombre'] ?? ''}';
  if (c['tienda'] != null && una.isNotEmpty) return [una];
  final s = <String>{};
  for (final d in (c['detalles'] as List? ?? const [])) {
    for (final r in ((d as Map)['distribuciones'] as List? ?? const [])) {
      final n = '${(r as Map)['tienda_nombre'] ?? ''}';
      if (n.isNotEmpty) s.add(n);
    }
  }
  return s.toList();
}

String textoTiendas(Map c) {
  final t = tiendasDeOrden(c);
  if (t.isEmpty) return '${c['tienda_nombre'] ?? 'Sin tienda'}';
  if (t.length <= 2) return t.join(' · ');
  return '${t.length} tiendas';
}

String nombreProducto(Map d) {
  final n = '${d['producto_nombre'] ?? ''}'.trim();
  return n.isNotEmpty ? n : '${d['nombre_libre'] ?? 'Producto'}'.trim();
}

class ResumenOrdenes {
  final int porRecibir, recibidasMes, porPagar, vencidas, credito;
  final double totalPorRecibir, totalRecibidasMes, totalPorPagar, totalVencido;
  const ResumenOrdenes({
    this.porRecibir = 0, this.recibidasMes = 0, this.porPagar = 0, this.vencidas = 0,
    this.credito = 0, this.totalPorRecibir = 0, this.totalRecibidasMes = 0,
    this.totalPorPagar = 0, this.totalVencido = 0,
  });
}

ResumenOrdenes resumirOrdenes(List<Map<String, dynamic>> l, DateTime hoy) {
  var pr = 0, rm = 0, pp = 0, ve = 0, cr = 0;
  var tpr = 0.0, trm = 0.0, tpp = 0.0, tve = 0.0;
  for (final c in l) {
    final total = numDe(c['total']);
    if (esPendiente(c)) {
      pr++;
      tpr += total;
    }
    if (esRecibida(c)) {
      final f = fechaDe(c['fecha_recepcion']) ?? fechaDe(c['fecha_orden']);
      if (f != null && f.year == hoy.year && f.month == hoy.month) {
        rm++;
        trm += total;
      }
    }
    if (porPagar(c)) {
      pp++;
      tpp += total;
      if (vencida(c, hoy)) {
        ve++;
        tve += total;
      }
    }
    if (esCredito(c) && c['estado'] != 'cancelada') cr++;
  }
  return ResumenOrdenes(porRecibir: pr, recibidasMes: rm, porPagar: pp, vencidas: ve,
      credito: cr, totalPorRecibir: tpr, totalRecibidasMes: trm, totalPorPagar: tpp,
      totalVencido: tve);
}

/// Margen sobre el costo: (venta − costo) / costo, en %.
double margen(double costo, double venta) =>
    costo <= 0 || venta <= 0 ? 0 : (venta - costo) / costo * 100;

/// (texto, nivel): 0 = bien, 1 = margen muy bajo, 2 = bajo el costo.
(String, int) textoMargen(double costo, double venta) {
  final m = margen(costo, venta);
  if (venta > 0 && venta < costo) return ('Bajo el costo', 2);
  if (m < 10) return ('Margen muy bajo · ${m.round()} %', 1);
  return ('Gana ${m.round()} %', 0);
}

/// Precio sugerido: el que ya tenía, o costo + 30 % (mayoreo + 15 %).
double precioSugerido(Map d, {bool mayoreo = false}) {
  final actual = numDe(d[mayoreo ? 'precio_mayoreo' : 'precio_venta']);
  if (actual > 0) return actual;
  return (numDe(d['precio_unitario']) * (mayoreo ? 1.15 : 1.30)).roundToDouble();
}
