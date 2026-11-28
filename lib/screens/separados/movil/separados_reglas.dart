// lib/screens/separados/movil/separados_reglas.dart
//
// Reglas de Separados en el celular: filtros, estado de cada separado,
// resumen de las tarjetas, cuentas del abono y del cambio de producto,
// plazos y mensajes de WhatsApp. Sin widgets: se prueban solas.

import 'dart:math' as math;
import 'dart:ui' show Color;

import '../../../models/pago_abono.dart';
import '../../../models/separado.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;

// ── Fechas ────────────────────────────────────────────────────

const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _dias = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _mesesLargos = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
  'septiembre', 'octubre', 'noviembre', 'diciembre'];

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

String fechaCorta(DateTime f, DateTime hoy) =>
    f.year == hoy.year ? '${f.day} ${_meses[f.month]}' : '${f.day} ${_meses[f.month]} ${f.year}';

String fechaLarga(DateTime f) => '${_dias[f.weekday]} ${f.day} de ${_mesesLargos[f.month]}';

String horaCorta(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  return '$h:${f.minute.toString().padLeft(2, '0')} ${f.hour < 12 ? 'a. m.' : 'p. m.'}';
}

String fechaApi(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? limiteDe(Separado s) => s.fechaLimite == null ? null : DateTime.tryParse(s.fechaLimite!);

/// Días que le quedan (negativo = vencido). null si no tiene fecha.
int? diasRestantes(Separado s, DateTime hoy) {
  final l = limiteDe(s);
  return l == null ? null : soloDia(l).difference(soloDia(hoy)).inDays;
}

String plural(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

// ── Estado ────────────────────────────────────────────────────

enum TonoSep { verde, ambar, rojo, azul, gris, morado }

class EstadoSep {
  final String texto;
  final TonoSep tono;
  const EstadoSep(this.texto, this.tono);

  Color get color => switch (tono) {
        TonoSep.verde  => const Color(0xFF047857),
        TonoSep.ambar  => const Color(0xFF92400E),
        TonoSep.rojo   => const Color(0xFFBE123C),
        TonoSep.azul   => const Color(0xFF075985),
        TonoSep.gris   => const Color(0xFF475569),
        TonoSep.morado => const Color(0xFF5B21B6),
      };

  Color get fondo => switch (tono) {
        TonoSep.verde  => const Color(0xFFD1FAE5),
        TonoSep.ambar  => const Color(0xFFFEF3C7),
        TonoSep.rojo   => const Color(0xFFFFE4E6),
        TonoSep.azul   => const Color(0xFFE0F2FE),
        TonoSep.gris   => const Color(0xFFF1F5F9),
        TonoSep.morado => const Color(0xFFEDE9FE),
      };
}

/// Cuántos días antes se considera "por vencer".
const diasPorVencer = 3;

EstadoSep estadoSep(Separado s, DateTime hoy) {
  if (s.esCancelado) {
    return s.bonoCodigo != null ? const EstadoSep('Cancelado · bono', TonoSep.morado)
        : const EstadoSep('Cancelado', TonoSep.gris);
  }
  if (s.esPagado) {
    return s.entregado ? const EstadoSep('Entregado', TonoSep.gris)
        : const EstadoSep('Por entregar', TonoSep.azul);
  }
  final d = diasRestantes(s, hoy);
  if (d == null) return const EstadoSep('Activo', TonoSep.verde);
  if (d < 0) return EstadoSep('Vencido hace ${plural(-d, 'día', 'días')}', TonoSep.rojo);
  if (d == 0) return const EstadoSep('Vence hoy', TonoSep.ambar);
  if (d <= diasPorVencer) return EstadoSep('Vence en ${plural(d, 'día', 'días')}', TonoSep.ambar);
  return const EstadoSep('Al día', TonoSep.verde);
}

bool vencido(Separado s, DateTime hoy) => s.esActivo && (diasRestantes(s, hoy) ?? 1) < 0;
bool porVencer(Separado s, DateTime hoy) {
  final d = diasRestantes(s, hoy);
  return s.esActivo && d != null && d >= 0 && d <= diasPorVencer;
}

/// Texto pequeño a la derecha de la tarjeta.
String cuandoSep(Separado s, DateTime hoy) {
  if (s.esCancelado) return 'Separado ${fechaCorta(s.createdAt, hoy)}';
  if (s.entregado) return 'Entregado ${fechaCorta(s.entregadoAt!, hoy)}';
  if (s.esPagado) {
    final ultimo = s.abonos.isEmpty ? null
        : s.abonos.map((a) => a.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    if (ultimo == null) return 'Pagado';
    final d = soloDia(hoy).difference(soloDia(ultimo)).inDays;
    return d == 0 ? 'Pagado hoy' : d == 1 ? 'Pagado ayer' : 'Pagado ${fechaCorta(ultimo, hoy)}';
  }
  final l = limiteDe(s);
  if (l == null) return '';
  return vencido(s, hoy) || porVencer(s, hoy) ? fechaCorta(l, hoy) : 'Vence ${fechaCorta(l, hoy)}';
}

String productosSep(Separado s) => s.detalles
    .map((d) => d.cantidad == 1 ? d.productoNombre : '${d.productoNombre} ×${cantidadTexto(d.cantidad)}')
    .join(' · ');

String cantidadTexto(double c) => c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toString();

// ── Filtros ───────────────────────────────────────────────────

enum FiltroSep { activos, porVencer, vencidos, porEntregar, pagados, cancelados }

String nombreFiltro(FiltroSep f) => switch (f) {
      FiltroSep.activos     => 'Activos',
      FiltroSep.porVencer   => 'Por vencer',
      FiltroSep.vencidos    => 'Vencidos',
      FiltroSep.porEntregar => 'Por entregar',
      FiltroSep.pagados     => 'Entregados',
      FiltroSep.cancelados  => 'Cancelados',
    };

bool cumpleFiltroSep(Separado s, FiltroSep f, DateTime hoy) => switch (f) {
      FiltroSep.activos     => s.esActivo,
      FiltroSep.porVencer   => porVencer(s, hoy),
      FiltroSep.vencidos    => vencido(s, hoy),
      FiltroSep.porEntregar => s.porEntregar,
      FiltroSep.pagados     => s.esPagado && s.entregado,
      FiltroSep.cancelados  => s.esCancelado,
    };

List<Separado> sepsVisibles(List<Separado> l, FiltroSep f, String busqueda, DateTime hoy) {
  final q = busqueda.trim().toLowerCase().replaceAll('sep-', '').replaceAll('#', '');
  final r = l.where((s) {
    if (!cumpleFiltroSep(s, f, hoy)) return false;
    if (q.isEmpty) return true;
    final texto = [s.id.toString(), s.clienteNombre, s.clienteCedulaNit ?? '', s.clienteTelefono ?? '',
      ...s.detalles.map((d) => d.productoNombre)].join(' ').toLowerCase();
    return texto.contains(q);
  }).toList();
  // Lo más urgente primero: vencidos, luego por fecha límite.
  int clave(Separado s) => diasRestantes(s, hoy) ?? 9999;
  if (f == FiltroSep.activos || f == FiltroSep.porVencer || f == FiltroSep.vencidos) {
    r.sort((a, b) => clave(a).compareTo(clave(b)));
  } else {
    r.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return r;
}

// ── Resumen de las tarjetas ───────────────────────────────────

class ResumenSeps {
  final int activos, vencidos, porVencer, porEntregar;
  final double porCobrar, saldoVencido;
  const ResumenSeps({this.activos = 0, this.vencidos = 0, this.porVencer = 0, this.porEntregar = 0,
      this.porCobrar = 0, this.saldoVencido = 0});
}

ResumenSeps resumirSeps(List<Separado> l, DateTime hoy) {
  var act = 0, ven = 0, pv = 0, ent = 0;
  double cobrar = 0, sv = 0;
  for (final s in l) {
    if (s.esActivo) {
      act++;
      cobrar += s.saldoPendiente;
      if (vencido(s, hoy)) {
        ven++;
        sv += s.saldoPendiente;
      } else if (porVencer(s, hoy)) {
        pv++;
      }
    }
    if (s.porEntregar) ent++;
  }
  return ResumenSeps(activos: act, vencidos: ven, porVencer: pv, porEntregar: ent,
      porCobrar: cobrar, saldoVencido: sv);
}

String? textoAlerta(ResumenSeps r) {
  if (r.vencidos == 0 && r.porVencer == 0) return null;
  final partes = [
    if (r.vencidos > 0) plural(r.vencidos, 'vencido', 'vencidos'),
    if (r.porVencer > 0) '${r.porVencer} ${r.porVencer == 1 ? 'vence' : 'vencen'} en $diasPorVencer días o menos',
  ];
  return '${partes.join(' y ')}.';
}

// ── Abonar ────────────────────────────────────────────────────

/// Botones rápidos de monto: todo, mitad y billetes redondos menores al saldo.
List<(String, double)> montosRapidos(double saldo) {
  if (saldo <= 0) return const [];
  final r = <(String, double)>[('Todo · ${pesosCO(saldo)}', saldo)];
  final mitad = (saldo / 2 / 1000).ceil() * 1000.0;
  if (mitad < saldo) r.add(('Mitad', mitad));
  for (final b in [20000.0, 50000.0, 100000.0]) {
    if (b < saldo && b != mitad) r.add((pesosCO(b), b));
  }
  return r.take(4).toList();
}

/// Qué falta para registrar el abono (null si está listo).
String? problemaAbono(List<PagoAbono> pagos, double saldo, {bool? cajaAbierta, int Function(String) cuentasDe = _sinCuentas}) {
  final total = pagos.fold<double>(0, (s, p) => s + p.monto);
  if (pagos.any((p) => p.monto <= 0)) return 'Escribe cuánto abona.';
  if (total > saldo + 0.5) return 'Es más de lo que le falta (${pesosCO(saldo)}).';
  if (cajaAbierta == false && pagos.any((p) => p.esEfectivo)) {
    return 'No hay caja abierta: el efectivo no se puede recibir. Usa transferencia o tarjeta.';
  }
  for (final p in pagos) {
    if (!p.esEfectivo && p.cuentaId == null && cuentasDe(p.metodoPago) > 0) return '¿A qué cuenta entró? Elige una.';
  }
  if (pagos.length == 2 && pagos[0].metodoPago == pagos[1].metodoPago && pagos[0].cuentaId == pagos[1].cuentaId) {
    return 'Las dos partes tienen el mismo método: déjalo en una sola.';
  }
  return null;
}

int _sinCuentas(String _) => 0;

// ── Cambiar producto ──────────────────────────────────────────

class CambioSep {
  final double totalAntes, totalDespues, abonado;
  const CambioSep({required this.totalAntes, required this.totalDespues, required this.abonado});

  double get faltaAntes => math.max(0, totalAntes - abonado);
  double get faltaDespues => math.max(0, totalDespues - abonado);
  /// No se puede quedar por debajo de lo que ya abonó.
  bool get permitido => totalDespues >= abonado;
  bool get quedaPagado => permitido && faltaDespues <= 0;
}

CambioSep cambioSep(Separado s, DetalleSeparado viejo, double precioNuevo, double cantidad) => CambioSep(
      totalAntes: s.total,
      totalDespues: s.total - viejo.subtotal + precioNuevo * cantidad,
      abonado: s.abonoAcumulado,
    );

// ── Nuevo separado ────────────────────────────────────────────

const plazosDias = [15, 30, 45];

DateTime fechaPlazo(DateTime hoy, int dias) => soloDia(hoy).add(Duration(days: dias));

List<(String, double)> abonosIniciales(double total) {
  if (total <= 0) return const [];
  final veinte = (total * .2 / 100).ceil() * 100.0;
  final r = <(String, double)>[('20% · ${pesosCO(veinte)}', veinte)];
  for (final b in [50000.0, 100000.0]) {
    if (b < total && b != veinte) r.add((pesosCO(b), b));
  }
  r.add(('Todo', total));
  return r;
}

String? problemaNuevo(int paso, {Object? cliente, int productos = 0, DateTime? fecha, double abono = 0,
    double total = 0, DateTime? hoy, String metodo = 'efectivo', bool? cajaAbierta, bool faltaCuenta = false}) {
  switch (paso) {
    case 1:
      return cliente == null ? 'Elige el cliente.' : null;
    case 2:
      return productos == 0 ? 'Agrega al menos un producto.' : null;
    case 3:
      if (fecha == null) return 'Elige hasta cuándo se guarda.';
      if (hoy != null && soloDia(fecha).isBefore(soloDia(hoy))) return 'La fecha no puede ser en el pasado.';
      if (abono <= 0) return 'El abono inicial es obligatorio.';
      if (abono > total) return 'El abono no puede pasar del total (${pesosCO(total)}).';
      if (metodo == 'efectivo' && cajaAbierta == false) {
        return 'No hay caja abierta: usa transferencia o tarjeta, o abre la caja.';
      }
      if (faltaCuenta) return '¿A qué cuenta entró? Elige una.';
      return null;
  }
  return null;
}

// ── WhatsApp ──────────────────────────────────────────────────

String nombreCorto(String completo) => completo.trim().split(RegExp(r'\s+')).first;

String mensajeBono(Separado s, String tienda) {
  final vence = DateTime.tryParse(s.bonoVence ?? '');
  final saldo = s.bonoSaldo ?? s.abonoAcumulado;
  return 'Hola ${nombreCorto(s.clienteNombre)}, cancelamos tu separado SEP-${s.id}. '
      'Los ${pesosCO(saldo)} que abonaste quedan a tu favor en el bono ${s.bonoCodigo}'
      '${vence != null ? ', válido hasta el ${vence.day} ${_meses[vence.month]} ${vence.year}' : ''}'
      '${tienda.isNotEmpty ? ' en $tienda' : ''}. Muéstralo al pagar tu próxima compra. ¡Te esperamos!';
}

String mensajeEntrega(Separado s, String tienda) =>
    'Hola ${nombreCorto(s.clienteNombre)}, tu separado SEP-${s.id} ya está pagado completo. '
    'Puedes pasar a recogerlo${tienda.isNotEmpty ? ' en $tienda' : ''} cuando quieras. ¡Gracias!';

String metodoTexto(String m) => switch (m) {
      'efectivo'      => 'Efectivo',
      'transferencia' => 'Transferencia',
      'tarjeta'       => 'Tarjeta',
      'nota_credito'  => 'Nota crédito',
      _               => m.isEmpty ? '—' : m[0].toUpperCase() + m.substring(1),
    };
