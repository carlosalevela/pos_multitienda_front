// lib/screens/separados/movil/recordatorios_movil.dart
//
// Recordatorios por WhatsApp: se eligen los separados vencidos o por vencer
// y se ve con qué datos le llega a cada cliente. Lo envía el servidor con la
// plantilla aprobada de WhatsApp.

import 'package:flutter/material.dart';

import '../../../models/alerta_separado.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import 'separados_movil.dart';
import 'separados_reglas.dart';

class RecordatoriosMovil extends StatefulWidget {
  final List<AlertaSeparado> alertas;
  final String tiendaNombre;
  /// Envía a los separados elegidos; devuelve el texto del resultado o lanza
  /// el error para mostrar.
  final Future<String> Function(List<int> ids) enviar;
  final DateTime? hoy;

  const RecordatoriosMovil({super.key, required this.alertas, required this.enviar, this.tiendaNombre = '', this.hoy});

  @override
  State<RecordatoriosMovil> createState() => _RecordatoriosMovilState();
}

class _RecordatoriosMovilState extends State<RecordatoriosMovil> {
  late final Set<int> _elegidos = {
    for (final a in widget.alertas)
      if (a.telefono.trim().isNotEmpty) a.id,
  };
  bool _enviando = false;

  List<AlertaSeparado> get _orden => [...widget.alertas]..sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final r = await widget.enviar(_elegidos.toList());
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r, style: cf(size: 13, color: Colors.white)),
        backgroundColor: CM.verde,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'.replaceFirst('Exception: ', ''), style: cf(size: 13, color: Colors.white)),
        backgroundColor: CM.rojo,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _cuando(AlertaSeparado a) {
    final d = a.diasRestantes;
    if (d < 0) return 'venció hace ${plural(-d, 'día', 'días')}';
    if (d == 0) return 'vence hoy';
    return 'vence en ${plural(d, 'día', 'días')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = _orden;
    final ejemplo = l.where((a) => _elegidos.contains(a.id)).firstOrNull;
    final n = _elegidos.length;
    return Scaffold(
      backgroundColor: CM.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: CM.verdeOs,
        elevation: 0,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recordar por WhatsApp', style: cf(size: 16, w: FontWeight.w800, color: CM.oscuro)),
          Text(plural(l.length, 'separado vencido o por vencer', 'separados vencidos o por vencer'),
              style: cf(size: 11.5, color: CM.gris2)),
        ]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: CM.borde)),
      ),
      body: l.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(30),
              child: Text('No hay separados vencidos ni por vencer.', textAlign: TextAlign.center,
                  style: cf(size: 13.5, color: CM.gris))))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                Row(children: [
                  Expanded(child: Text('¿A QUIÉN LE ESCRIBIMOS?',
                      style: cf(size: 11, w: FontWeight.w800, color: CM.verdeOs, ls: .5))),
                  TextButton(
                    onPressed: () => setState(() {
                      final todos = l.where((a) => a.telefono.trim().isNotEmpty).map((a) => a.id).toSet();
                      _elegidos.length == todos.length ? _elegidos.clear() : _elegidos.addAll(todos);
                    }),
                    child: Text(_elegidos.isEmpty ? 'Elegir todos' : 'Quitar todos',
                        style: cf(size: 12, w: FontWeight.w700, color: CM.verdeOs)),
                  ),
                ]),
                for (final a in l) ...[
                  _fila(a),
                  const SizedBox(height: 7),
                ],
                if (ejemplo != null) ...[
                  tituloSep('Así le llega a ${nombreCorto(ejemplo.cliente)}'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCF8C6),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12), bottomLeft: Radius.circular(4)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Recordatorio de separado', style: cf(size: 12.5, w: FontWeight.w800,
                          color: const Color(0xFF1F2937))),
                      const SizedBox(height: 6),
                      for (final (k, v) in [
                        ('Cliente', ejemplo.cliente),
                        ('Separado', '#${ejemplo.id}'),
                        ('Tienda', ejemplo.tienda.isNotEmpty ? ejemplo.tienda : widget.tiendaNombre),
                        ('Fecha límite', _fechaBonita(ejemplo.fechaLimite)),
                        ('Saldo', pesosCO(ejemplo.saldoPendiente)),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '$k: ', style: cf(size: 12.5, color: const Color(0xFF374151))),
                            TextSpan(text: v, style: cf(size: 12.5, w: FontWeight.w700, color: const Color(0xFF1F2937))),
                          ])),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text('Se envía con la plantilla aprobada de WhatsApp de la empresa, con estos datos.',
                      style: cf(size: 11.5, color: CM.gris2)),
                ],
              ],
            ),
      bottomNavigationBar: l.isEmpty ? null : Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CM.borde))),
        child: SafeArea(
          top: false,
          child: FilledButton.icon(
            onPressed: n == 0 || _enviando ? null : _enviar,
            style: botonSep(c: const Color(0xFF16A34A)),
            icon: _enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(n == 0 ? 'Elige a quién' : 'Enviar a ${plural(n, 'cliente', 'clientes')}',
                style: cf(size: 14.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  String _fechaBonita(String f) {
    final d = DateTime.tryParse(f);
    return d == null ? f : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _fila(AlertaSeparado a) {
    final sin = a.telefono.trim().isEmpty;
    final on = _elegidos.contains(a.id);
    return Opacity(
      opacity: sin ? .55 : 1,
      child: Material(
        color: on ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: sin ? null : () => setState(() => on ? _elegidos.remove(a.id) : _elegidos.add(a.id)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? CM.verde : const Color(0xFFE2E8F0), width: on ? 1.8 : 1.5)),
            child: Row(children: [
              Checkbox(
                value: on,
                onChanged: sin ? null : (v) => setState(() => v == true ? _elegidos.add(a.id) : _elegidos.remove(a.id)),
                activeColor: CM.verde,
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.cliente, maxLines: 1, overflow: TextOverflow.ellipsis, style: cf(size: 13, w: FontWeight.w800)),
                  Text('SEP-${a.id} · ${sin ? 'sin celular' : _cuando(a)}',
                      style: cf(size: 11.5, color: a.diasRestantes < 0 && !sin ? CM.rojo : CM.gris2)),
                ]),
              ),
              Text(pesosCO(a.saldoPendiente), style: cf(size: 13, w: FontWeight.w800, color: CM.rojo)),
            ]),
          ),
        ),
      ),
    );
  }
}
