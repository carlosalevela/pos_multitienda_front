// lib/screens/clientes/widgets/cliente_contacto.dart
//
// Llamar y escribir por WhatsApp a un cliente, con el mensaje ya armado
// (separado vencido, saldo de crédito o saludo). Las reglas no dependen de la
// pantalla y se prueban solas.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/cliente.dart';
import '../../inventario/widgets/inventario_movil.dart' show InventarioMovil;
import 'package:google_fonts/google_fonts.dart';

// ── Reglas ────────────────────────────────────────────────────

/// Solo los dígitos del celular colombiano (10), sin el 57 que guarda el
/// servidor. Otro formato se deja como venga.
String celularLocal(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('57')) return d.substring(2);
  return d;
}

/// "573117374019" → "311 737 4019".
String telefonoBonito(String raw) {
  final d = celularLocal(raw);
  if (d.length == 10) return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  return raw.trim();
}

/// Número para WhatsApp (con 57); null si no parece un celular.
String? numeroWhatsApp(String raw) {
  final d = celularLocal(raw);
  if (d.length == 10 && d.startsWith('3')) return '57$d';
  if (d.length >= 11) return d;
  return null;
}

String pesosCO(num v) {
  final s = v.round().abs().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return '${v < 0 ? '-' : ''}\$$s';
}

const _mesesLargos = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

String fechaLarga(DateTime f) => '${f.day} de ${_mesesLargos[f.month]}';

/// Días entre hoy y el vencimiento (negativo = vencido hace N días).
int? diasParaVencer(SaldosCliente? s, DateTime hoy) {
  final v = s?.proximoVencimiento;
  if (v == null) return null;
  return DateTime(v.year, v.month, v.day)
      .difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
}

/// "Vencido hace 2 días", "Vence hoy", "Vence mañana", "Vence en 5 días".
String textoVencimiento(int dias) {
  if (dias < -1) return 'Vencido hace ${-dias} días';
  if (dias == -1) return 'Venció ayer';
  if (dias == 0) return 'Vence hoy';
  if (dias == 1) return 'Vence mañana';
  return 'Vence en $dias días';
}

enum PlantillaWA { separado, credito, saludo }

String nombrePlantilla(PlantillaWA p) => switch (p) {
      PlantillaWA.separado => 'Separado pendiente',
      PlantillaWA.credito  => 'Saldo de crédito',
      PlantillaWA.saludo   => 'Solo saludar',
    };

/// Mensaje listo para enviar; el usuario lo puede cambiar antes.
String mensajeWhatsApp(PlantillaWA p, Cliente c, String tienda, DateTime hoy) {
  final hola = 'Hola ${c.nombre.trim().split(' ').first}, te saludamos de $tienda.';
  final s = c.saldos;
  switch (p) {
    case PlantillaWA.separado:
      if (s == null || s.separados <= 0) {
        return '$hola Queríamos recordarte que tienes un separado con nosotros. ¡Te esperamos!';
      }
      final n = s.separadosActivos;
      final cual = n > 1 ? 'tus $n separados tienen' : 'tu separado tiene';
      final dias = diasParaVencer(s, hoy);
      final cuando = dias == null
          ? ''
          : dias < 0
              ? ' y venció el ${fechaLarga(s.proximoVencimiento!)}'
              : ' y vence el ${fechaLarga(s.proximoVencimiento!)}';
      return '$hola Te recordamos que $cual un saldo de ${pesosCO(s.separados)}$cuando. '
          '¿Cuándo puedes pasar a abonar o recogerlo? Gracias.';
    case PlantillaWA.credito:
      final deuda = s?.credito ?? 0;
      if (deuda <= 0) return '$hola Tu cuenta de crédito está al día. ¡Gracias por tu compra!';
      return '$hola Te recordamos que tienes un saldo de ${pesosCO(deuda)} en tu cuenta de crédito. '
          'Puedes abonar en la tienda o por transferencia. Gracias.';
    case PlantillaWA.saludo:
      return '$hola ';
  }
}

/// La plantilla que tiene sentido para el cliente.
PlantillaWA plantillaSugerida(Cliente c) {
  final s = c.saldos;
  if (s != null && s.separados > 0) return PlantillaWA.separado;
  if (s != null && s.credito > 0) return PlantillaWA.credito;
  return PlantillaWA.saludo;
}

Uri enlaceWhatsApp(String numero, String mensaje) =>
    Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');

// ── Acciones ──────────────────────────────────────────────────

Future<bool> _abrir(Uri uri) async {
  try {
    if (!kIsWeb && Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', uri.toString()]);
      return true;
    }
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Llamar a cualquier número (proveedores, por ejemplo).
Future<void> llamarNumero(BuildContext context, String tel, String nombre) async {
  final d = celularLocal(tel);
  if (d.isEmpty) return _aviso(context, '$nombre no tiene teléfono.');
  final ok = await _abrir(Uri(scheme: 'tel', path: d));
  if (!ok && context.mounted) _aviso(context, 'No se pudo abrir el marcador.');
}

/// Abrir el chat de WhatsApp de un número, con un mensaje opcional.
Future<void> abrirWhatsAppNumero(BuildContext context, String tel, String nombre,
    {String mensaje = ''}) async {
  final n = numeroWhatsApp(tel);
  if (n == null) {
    return _aviso(context, tel.isEmpty ? '$nombre no tiene celular registrado.'
        : 'El número de $nombre no parece un celular.');
  }
  final ok = await _abrir(enlaceWhatsApp(n, mensaje));
  if (!ok && context.mounted) _aviso(context, 'No se pudo abrir WhatsApp.');
}

Future<void> llamarCliente(BuildContext context, Cliente c) async {
  final d = celularLocal(c.telefono);
  if (d.isEmpty) return _aviso(context, '${c.nombre} no tiene teléfono.');
  final ok = await _abrir(Uri(scheme: 'tel', path: d));
  if (!ok && context.mounted) _aviso(context, 'No se pudo abrir el marcador.');
}

void _aviso(BuildContext context, String t) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFB91C1C),
    ));

/// Abre la hoja para elegir y editar el mensaje, y luego WhatsApp.
Future<void> escribirWhatsApp(BuildContext context, Cliente c, String tienda,
    {DateTime? hoy}) async {
  final numero = numeroWhatsApp(c.telefono);
  if (numero == null) {
    return _aviso(context, c.telefono.isEmpty
        ? '${c.nombre} no tiene celular registrado.'
        : 'El número de ${c.nombre} no parece un celular.');
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: HojaWhatsApp(
        cliente: c,
        tienda: tienda,
        hoy: hoy ?? DateTime.now(),
        onEnviar: (msg) async {
          final ok = await _abrir(enlaceWhatsApp(numero, msg));
          if (!ok) return 'No se pudo abrir WhatsApp.';
          if (ctx.mounted) Navigator.pop(ctx);
          return null;
        },
      ),
    ),
  );
}

// ── Hoja ──────────────────────────────────────────────────────

TextStyle _f({double size = 13, FontWeight w = FontWeight.w500,
    Color color = const Color(0xFF0F172A), double? h}) {
  final fuente = InventarioMovil.fuenteDePrueba;
  if (fuente != null) {
    return TextStyle(fontFamily: fuente, fontSize: size, fontWeight: w, color: color, height: h);
  }
  return GoogleFonts.inter(fontSize: size, fontWeight: w, color: color, height: h);
}

class HojaWhatsApp extends StatefulWidget {
  final Cliente cliente;
  final String tienda;
  final DateTime hoy;
  /// null si se abrió; si no, el error a mostrar.
  final Future<String?> Function(String mensaje) onEnviar;

  const HojaWhatsApp({super.key, required this.cliente, required this.tienda,
      required this.hoy, required this.onEnviar});

  @override
  State<HojaWhatsApp> createState() => _HojaWhatsAppState();
}

class _HojaWhatsAppState extends State<HojaWhatsApp> {
  late PlantillaWA _p = plantillaSugerida(widget.cliente);
  late final _ctrl = TextEditingController(text: _texto());
  String? _error;
  bool _abriendo = false;

  String _texto() => mensajeWhatsApp(_p, widget.cliente, widget.tienda, widget.hoy);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF15803D);
    final c = widget.cliente;
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Expanded(child: Text('WhatsApp a ${c.nombre.trim().split(' ').first}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: _f(size: 17, w: FontWeight.w800))),
            Text(telefonoBonito(c.telefono), style: _f(size: 12, color: const Color(0xFF64748B))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in PlantillaWA.values)
              ChoiceChip(
                label: Text(nombrePlantilla(p)),
                selected: _p == p,
                showCheckmark: false,
                selectedColor: const Color(0xFF059669),
                backgroundColor: Colors.white,
                side: BorderSide(color: _p == p ? const Color(0xFF059669) : const Color(0xFFD1FAE5)),
                labelStyle: _f(size: 12, w: FontWeight.w700,
                    color: _p == p ? Colors.white : const Color(0xFF334155)),
                onSelected: (_) => setState(() {
                  _p = p;
                  _ctrl.text = _texto();
                }),
              ),
          ]),
          const SizedBox(height: 10),
          Text('Lo puedes cambiar antes de enviar', style: _f(size: 11.5, w: FontWeight.w700, color: const Color(0xFF334155))),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            minLines: 4,
            maxLines: 7,
            style: _f(size: 13.5, h: 1.4),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1FAE5), width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.6)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: _f(size: 12, w: FontWeight.w700, color: const Color(0xFFB91C1C))),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _abriendo ? null : () async {
                final m = _ctrl.text.trim();
                if (m.isEmpty) {
                  setState(() => _error = 'Escribe el mensaje.');
                  return;
                }
                setState(() {
                  _abriendo = true;
                  _error = null;
                });
                final e = await widget.onEnviar(m);
                if (mounted) {
                  setState(() {
                    _abriendo = false;
                    _error = e;
                  });
                }
              },
              style: FilledButton.styleFrom(backgroundColor: verde,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text('Abrir WhatsApp', style: _f(size: 14, w: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 6),
          Text('Se abre el chat con el mensaje escrito; tú lo envías.',
              textAlign: TextAlign.center, style: _f(size: 11.5, color: const Color(0xFF64748B))),
        ]),
      ),
    );
  }
}
