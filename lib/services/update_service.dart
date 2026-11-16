import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api_client.dart';

const _currentVersion = '1.5.5';

/// Versión actual expuesta para mostrar en UI.
const currentVersion = _currentVersion;

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
  /// Notifica cuando hay una actualización disponible.
  /// null = sin actualización, non-null = {version, url, obligatoria}
  static final updateDisponible = ValueNotifier<Map<String, dynamic>?>(null);

  /// Mensaje de error si la verificación falla. null = sin error.
  static final updateError = ValueNotifier<String?>(null);

  static Future<void> chequear(BuildContext context) async {
    updateError.value = null;
    try {
      final r = await ApiClient.instance.get(
        '/config/version/',
        queryParameters: {'v': _currentVersion},
      );
      final data        = r.data as Map<String, dynamic>;
      final remoteVer   = data['version']      as String? ?? '';
      final downloadUrl = data['download_url'] as String? ?? '';
      final obligatoria = data['obligatoria']  as bool?   ?? false;

      if (!_esNueva(_currentVersion, remoteVer)) {
        updateDisponible.value = null;
        return;
      }
      if (downloadUrl.isEmpty) return;

      updateDisponible.value = {
        'version': remoteVer,
        'url': downloadUrl,
        'obligatoria': obligatoria,
      };

      if (!context.mounted) return;
      await mostrarDialogo(context);
    } catch (e, st) {
      final msg = e.toString();
      debugPrint('[UpdateService] Error al verificar versión: $msg');
      debugPrint('[UpdateService] StackTrace: $st');
      updateError.value = msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
    }
  }

  /// Muestra el diálogo de actualización con la info ya almacenada (o la provista).
  static Future<void> mostrarDialogo(BuildContext context, {Map<String, dynamic>? info}) async {
    final datos = info ?? updateDisponible.value;
    if (datos == null) return;
    if (!context.mounted) return;
    await showDialog(
      context:            context,
      barrierDismissible: !(datos['obligatoria'] as bool? ?? false),
      builder: (_) => _UpdateDialog(
        version:     datos['version'] as String,
        downloadUrl: datos['url'] as String,
        obligatoria: datos['obligatoria'] as bool? ?? false,
      ),
    );
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
  double  _progreso   = 0;
  bool    _descargando = false;
  String  _estado     = '';
  String? _error;

  Future<void> _descargar() async {
    setState(() { _descargando = true; _estado = 'Descargando...'; _error = null; _progreso = 0; });
    try {
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}\\SIS_POS_${widget.version}_setup.exe';
      final dio  = Dio(BaseOptions(
        followRedirects: true,
        maxRedirects:    5,
        receiveTimeout:  const Duration(minutes: 10),
        connectTimeout:  const Duration(seconds: 30),
      ));
      await dio.download(
        widget.downloadUrl,
        path,
        onReceiveProgress: (rec, total) {
          if (total > 0) setState(() => _progreso = rec / total);
        },
      );
      setState(() => _estado = 'Lanzando instalador...');
      // Lanzar desconectado para que el instalador pueda pedir UAC
      // y no dependa del proceso de Flutter
      await Process.start(
        path, [],
        runInShell: false,
        mode: ProcessStartMode.detached,
      );
      // Dar 1 segundo y cerrar la app
      await Future.delayed(const Duration(seconds: 1));
      exit(0);
    } catch (e) {
      setState(() { _descargando = false; _error = e.toString(); });
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
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
