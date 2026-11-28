// lib/screens/devoluciones/movil/devoluciones_reglas.dart
//
// Reglas de Devoluciones en el celular: filtros, resumen de las tarjetas,
// textos de cada operación y las cuentas del flujo (qué trae, qué se lleva,
// cuánto va a la deuda y cuánta plata se mueve). Sin widgets: se prueban solas.

import 'dart:math' as math;
import 'dart:ui' show Color;

import '../../../models/devolucion_model.dart';
import '../../../models/producto.dart';
import '../../../models/venta_model.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM;

// ── Filtros de la lista ───────────────────────────────────────

enum FiltroDevs { todas, devoluciones, cambios, canceladas }

bool cumpleFiltroDev(DevolucionModel d, FiltroDevs f) => switch (f) {
      FiltroDevs.todas        => true,
      FiltroDevs.devoluciones => d.tipo != 'cambio' && d.estado != 'cancelada',
      FiltroDevs.cambios      => d.tipo == 'cambio' && d.estado != 'cancelada',
      FiltroDevs.canceladas   => d.estado == 'cancelada',
    };

List<DevolucionModel> devsVisibles(List<DevolucionModel> l, FiltroDevs f, String busqueda) {
  final q = busqueda.trim().toLowerCase();
  return l.where((d) {
    if (!cumpleFiltroDev(d, f)) return false;
    if (q.isEmpty) return true;
    final texto = [
      'dev-${d.id}', d.ventaNumero, d.clienteNombre, d.empleadoNombre,
      ...d.detalles.map((x) => x.productoNombre),
      ...d.reemplazos.map((x) => x.productoNombre),
    ].join(' ').toLowerCase();
    return texto.contains(q);
  }).toList();
}

// ── Periodo ───────────────────────────────────────────────────

enum RangoDevs { hoy, semana, mes, elegido }

String nombreRango(RangoDevs r) => switch (r) {
      RangoDevs.hoy     => 'Hoy',
      RangoDevs.semana  => 'Esta semana',
      RangoDevs.mes     => 'Este mes',
      RangoDevs.elegido => 'Fechas',
    };

/// Primer y último día del periodo (incluidos).
(DateTime, DateTime) fechasDeRango(RangoDevs r, DateTime hoy, {DateTime? desde, DateTime? hasta}) {
  final d = DateTime(hoy.year, hoy.month, hoy.day);
  return switch (r) {
    RangoDevs.hoy     => (d, d),
    RangoDevs.semana  => (d.subtract(Duration(days: d.weekday - 1)), d),
    RangoDevs.mes     => (DateTime(d.year, d.month, 1), d),
    RangoDevs.elegido => (desde ?? d, hasta ?? desde ?? d),
  };
}

String fechaApi(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Fechas cortas ─────────────────────────────────────────────

const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String horaCorta(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  return '$h:${f.minute.toString().padLeft(2, '0')} ${f.hour < 12 ? 'a. m.' : 'p. m.'}';
}

bool mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "10:42 a. m." si es de hoy, "Ayer", o "24 nov".
String cuandoDev(DateTime f, DateTime hoy) {
  if (mismoDia(f, hoy)) return horaCorta(f);
  if (mismoDia(f, hoy.subtract(const Duration(days: 1)))) return 'Ayer';
  return f.year == hoy.year ? '${f.day} ${_meses[f.month]}' : '${f.day} ${_meses[f.month]} ${f.year}';
}

/// "Hoy 10:42 a. m." / "Ayer 3:05 p. m." / "24 nov 9:15 a. m."
String cuandoLargo(DateTime f, DateTime hoy) {
  final dia = mismoDia(f, hoy)
      ? 'Hoy'
      : mismoDia(f, hoy.subtract(const Duration(days: 1)))
          ? 'Ayer'
          : '${f.day} ${_meses[f.month]}${f.year == hoy.year ? '' : ' ${f.year}'}';
  return '$dia ${horaCorta(f)}';
}

// ── Textos de cada operación ──────────────────────────────────

String nombreMetodo(String m) => switch (m) {
      'efectivo'      => 'Efectivo',
      'transferencia' => 'Transferencia',
      'tarjeta'       => 'Tarjeta',
      'nota_credito'  => 'Nota crédito',
      _               => m.isEmpty ? '—' : m,
    };

String cantidadTexto(double c) => c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toString();

/// "Bolso Lía café · Aretes perla" o, en un cambio, "Correa negra → Correa café".
String productosDev(DevolucionModel d) {
  final trae = d.detalles.map((x) => x.productoNombre).join(' · ');
  if (d.tipo != 'cambio') return trae;
  final lleva = d.reemplazos.isNotEmpty
      ? d.reemplazos.map((x) => x.productoNombre).join(' · ')
      : (d.productoReemplazoNombre ?? '');
  return lleva.isEmpty ? trae : '$trae → $lleva';
}

/// A dónde fue lo que trajo: "Al stock", "Avería" o "Mixto" (parte y parte).
String? destinoDev(DevolucionModel d) {
  if (d.detalles.isEmpty || d.estado == 'cancelada') return null;
  final dan = d.detalles.where((x) => x.aAverias).length;
  if (dan == 0) return 'Al stock';
  if (dan == d.detalles.length) return 'Avería';
  return 'Mixto';
}

enum Sentido { sale, entra, deuda, nada }

/// Monto que se muestra en la tarjeta, si salió o entró plata y el método.
class MontoDev {
  final String texto;
  final String detalle;
  final Sentido sentido;
  const MontoDev(this.texto, this.detalle, this.sentido);

  Color get color => switch (sentido) {
        Sentido.sale  => CM.rojo,
        Sentido.entra => CM.verdeOs,
        Sentido.deuda => CM.morado,
        Sentido.nada  => CM.gris,
      };
}

MontoDev montoDev(DevolucionModel d) {
  if (d.estado == 'cancelada') return MontoDev(pesosCO(d.totalDevuelto), 'Cancelada', Sentido.nada);
  if (d.tipo == 'cambio') {
    final dif = d.diferencia ?? 0;
    final met = nombreMetodo(d.metodoPagoDiferencia ?? '');
    return switch ((d.tipoDiferencia ?? '').toLowerCase()) {
      'cobrar'   => MontoDev('+ ${pesosCO(dif)}', 'Te pagó · $met', Sentido.entra),
      'devolver' => MontoDev('− ${pesosCO(dif)}', 'Le devolviste · $met', Sentido.sale),
      _          => const MontoDev('Sin diferencia', 'Cambio exacto', Sentido.nada),
    };
  }
  if (d.abonadoCredito > 0 && d.reembolsado <= 0) {
    return MontoDev('${pesosCO(d.abonadoCredito)} a su deuda', 'Venta a crédito', Sentido.deuda);
  }
  final det = d.abonadoCredito > 0
      ? '${nombreMetodo(d.metodoDevolucion)} · ${pesosCO(d.abonadoCredito)} a deuda'
      : nombreMetodo(d.metodoDevolucion);
  return MontoDev('− ${pesosCO(d.reembolsado)}', det, Sentido.sale);
}

// ── Resumen de las tarjetas ───────────────────────────────────

class ResumenDevs {
  final int hoy, hoyDevoluciones, hoyCambios;
  /// Plata que salió de la tienda (reembolsos y vueltas de cambios).
  final double devuelto;
  /// Plata que entró por diferencias de cambios.
  final double cobrado;
  /// Unidades que quedaron en averías.
  final double unidadesAverias;
  const ResumenDevs({this.hoy = 0, this.hoyDevoluciones = 0, this.hoyCambios = 0,
      this.devuelto = 0, this.cobrado = 0, this.unidadesAverias = 0});
}

ResumenDevs resumirDevs(List<DevolucionModel> l, DateTime hoy) {
  var nHoy = 0, nDev = 0, nCam = 0;
  double devuelto = 0, cobrado = 0, averias = 0;
  for (final d in l) {
    if (d.estado == 'cancelada') continue;
    if (mismoDia(d.createdAt, hoy)) {
      nHoy++;
      d.tipo == 'cambio' ? nCam++ : nDev++;
    }
    if (d.tipo == 'cambio') {
      final t = (d.tipoDiferencia ?? '').toLowerCase();
      if (t == 'cobrar') cobrado += d.diferencia ?? 0;
      if (t == 'devolver') devuelto += d.diferencia ?? 0;
    } else {
      devuelto += d.reembolsado;
    }
    for (final x in d.detalles) {
      if (x.aAverias) averias += x.cantidad;
    }
  }
  return ResumenDevs(hoy: nHoy, hoyDevoluciones: nDev, hoyCambios: nCam,
      devuelto: devuelto, cobrado: cobrado, unidadesAverias: averias);
}

String textoHoy(ResumenDevs r) {
  if (r.hoy == 0) return 'ninguna todavía';
  String p(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';
  return [
    if (r.hoyDevoluciones > 0) p(r.hoyDevoluciones, 'devolución', 'devoluciones'),
    if (r.hoyCambios > 0) p(r.hoyCambios, 'cambio', 'cambios'),
  ].join(' · ');
}

// ── El flujo nuevo ────────────────────────────────────────────

/// Un producto de la venta: cuántos trae y si viene bien o dañado.
class LineaTrae {
  final ProductoDisponibleModel producto;
  double cantidad;
  /// Por defecto dañado (como siempre: a averías para revisarlo).
  bool danado;
  String nota;
  LineaTrae(this.producto, {this.cantidad = 0, this.danado = true, this.nota = ''});
  double get subtotal => producto.precioUnitario * cantidad;
}

/// Un producto que se lleva en un cambio.
class LineaLleva {
  final Producto producto;
  double cantidad;
  LineaLleva(this.producto, {this.cantidad = 1});
  double get subtotal => producto.precio * cantidad;
}

enum TipoOp { devolucion, cambio }

class CuentasOp {
  final double trae, lleva;
  /// Solo devoluciones a crédito: lo que abona a la deuda.
  final double aDeuda;
  const CuentasOp({required this.trae, this.lleva = 0, this.aDeuda = 0});

  /// > 0 el cliente paga; < 0 la tienda le devuelve.
  double get diferencia => lleva - trae;
  /// Devolución: plata que se le entrega después de abonar a la deuda.
  double get reembolso => math.max(0, trae - aDeuda);
}

CuentasOp cuentasOp(TipoOp tipo, VentaDisponibleModel venta, List<LineaTrae> trae, List<LineaLleva> lleva) {
  final t = trae.fold<double>(0, (s, x) => s + x.subtotal);
  if (tipo == TipoOp.cambio) {
    return CuentasOp(trae: t, lleva: lleva.fold<double>(0, (s, x) => s + x.subtotal));
  }
  final deuda = venta.aCredito ? math.min(t, math.max(0.0, venta.saldoPendiente)) : 0.0;
  return CuentasOp(trae: t, aDeuda: deuda);
}

/// Plata que se mueve en el paso ④ (0 si no hay que pedir método).
double plataQueSeMueve(TipoOp tipo, CuentasOp c) =>
    tipo == TipoOp.cambio ? c.diferencia.abs() : c.reembolso;

/// Qué falta para pasar de cada paso (null si está listo).
String? problemaPasoDev(int paso, {VentaDisponibleModel? venta, List<LineaTrae> trae = const [],
    TipoOp? tipo, List<LineaLleva> lleva = const []}) {
  switch (paso) {
    case 1:
      return venta == null ? 'Elige la venta.' : null;
    case 2:
      if (!trae.any((x) => x.cantidad > 0)) return 'Marca qué trae el cliente.';
      for (final x in trae) {
        if (x.cantidad > x.producto.disponible) {
          return '${x.producto.productoNombre}: máximo ${cantidadTexto(x.producto.disponible)}.';
        }
      }
      return null;
    case 3:
      if (tipo == null) return 'Elige devolución o cambio.';
      if (tipo == TipoOp.cambio && !lleva.any((x) => x.cantidad > 0)) return 'Agrega lo que se lleva.';
      for (final x in lleva) {
        if (x.cantidad > x.producto.stockActual) {
          return '${x.producto.nombre}: quedan ${cantidadTexto(x.producto.stockActual)}.';
        }
      }
      return null;
  }
  return null;
}

/// Billetes sugeridos para "Recibido" (el exacto va aparte).
List<double> billetesSugeridos(double monto) {
  if (monto <= 0) return const [];
  final r = <double>{};
  for (final b in [10000.0, 20000.0, 50000.0, 100000.0]) {
    final v = (monto / b).ceil() * b;
    if (v > monto) r.add(v);
    if (r.length == 3) break;
  }
  return r.toList()..sort();
}

/// Detalles para el servidor.
List<Map<String, dynamic>> detallesPedido(List<LineaTrae> trae) => [
      for (final x in trae.where((x) => x.cantidad > 0))
        {
          'producto': x.producto.productoId,
          'cantidad': x.cantidad,
          'precio_unitario': x.producto.precioUnitario,
          'estado': x.danado ? 'danado' : 'bueno',
          if (x.nota.trim().isNotEmpty) 'motivo': x.nota.trim(),
        },
    ];
