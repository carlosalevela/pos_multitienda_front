import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api_client.dart';

const _currentVersion = '1.0.0';

/// Compara versiones semánticas. Devuelve true si [remote] > [local].
bool _esNueva(String local, String remote) {
  final l = local.split('.').map(int.parse).toList();
  final r = remote.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final lv = i < l.length ? l[i] : 0;
    final rv = i < r.length ? r[i] : 0;
    if (rv > lv) return true;
    if (rv < lv) return false;
  }
  return false;
}

class UpdateService {
  static Future<void> chequear(BuildContext context) async {
    try {
      final r = await ApiClient.instance.get('/configuracion/version/');
      final data         = r.data as Map<String, dynamic>;
      final remoteVer    = data['version']      as String? ?? '';
      final downloadUrl  = data['download_url'] as String? ?? '';
      final obligatoria  = data['obligatoria']  as bool?   ?? false;

      if (!_esNueva(_currentVersion, remoteVer)) return;
      if (downloadUrl.isEmpty) return;
      if (!context.mounted) return;

      await showDialog(
        context:             context,
        barrierDismissible:  !obligatoria,
        builder: (_) => _UpdateDialog(
          version:      remoteVer,
          downloadUrl:  downloadUrl,
          obligatoria:  obligatoria,
        ),
      );
    } catch (_) {
      // Falla silenciosa — no interrumpir el inicio si no hay conexión
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String downloadUrl;
  final bool   obligatoria;
  const _UpdateDialog({
    required this.version,
    required this.downloadUrl,
    required this.obligatoria,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progreso = 0;
  bool   _descargando = false;
  String _estado = '';

  Future<void> _descargar() async {
    setState(() { _descargando = true; _estado = 'Descargando...'; });
    try {
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}\\SIS_POS_${widget.version}_setup.exe';
      await Dio().download(
        widget.downloadUrl,
        path,
        onReceiveProgress: (rec, total) {
          if (total > 0) setState(() => _progreso = rec / total);
        },
      );
      setState(() => _estado = 'Instalando...');
      await Process.run(path, [], runInShell: true);
      // Cerrar la app para que el instalador tome el control
      exit(0);
    } catch (e) {
      setState(() { _descargando = false; _estado = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva versión disponible'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Versión ${widget.version} está disponible.\n'
               'Tu versión actual es $_currentVersion.'),
          if (_descargando) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progreso > 0 ? _progreso : null),
            const SizedBox(height: 8),
            Text(_estado, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
      actions: [
        if (!widget.obligatoria && !_descargando)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Más tarde'),
          ),
        if (!_descargando)
          FilledButton(
            onPressed: _descargar,
            child: const Text('Actualizar ahora'),
          ),
      ],
    );
  }
}
