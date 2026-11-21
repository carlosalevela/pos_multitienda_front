import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api_client.dart';

const _currentVersion = '1.5.8';

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

      final apkUrl = data['apk_url'] as String? ?? '';

      updateDisponible.value = {
        'version':    remoteVer,
        'url':        downloadUrl,
        'apk_url':    apkUrl,
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
    await showModalBottomSheet(
      context:            context,
      isDismissible:      !(datos['obligatoria'] as bool? ?? false),
      enableDrag:         !(datos['obligatoria'] as bool? ?? false),
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _UpdateDialog(
        version:     datos['version'] as String,
        downloadUrl: datos['url'] as String,
        apkUrl:      datos['apk_url'] as String? ?? '',
        obligatoria: datos['obligatoria'] as bool? ?? false,
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String downloadUrl;
  final String apkUrl;
  final bool   obligatoria;
  const _UpdateDialog({
    required this.version,
    required this.downloadUrl,
    required this.apkUrl,
    required this.obligatoria,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double  _progreso    = 0;
  bool    _descargando = false;
  String  _estado      = '';
  String? _error;

  // Paleta exacta de la app
  static const _greenDark   = Color(0xFF006C49);
  static const _greenMid    = Color(0xFF059669);
  static const _greenBright = Color(0xFF10B981);
  static const _greenLight  = Color(0xFFE8FFF4);
  static const _greenPillBg = Color(0xFFD1FAE5);
  static const _greenPillFg = Color(0xFF065F46);
  static const _errorColor  = Color(0xFFBA1A1A);
  static const _errorBg     = Color(0xFFFFDAD6);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted   = Color(0xFF6B7280);
  static const _border      = Color(0xFFE5E7EB);

  Future<void> _descargar() async {
    setState(() { _descargando = true; _estado = 'Descargando...'; _error = null; _progreso = 0; });
    try {
      final dio = Dio(BaseOptions(
        followRedirects: true,
        maxRedirects:    5,
        receiveTimeout:  const Duration(minutes: 10),
        connectTimeout:  const Duration(seconds: 30),
      ));
      final dir = await getTemporaryDirectory();

      if (Platform.isAndroid) {
        final url = widget.apkUrl;
        if (url.isEmpty) {
          setState(() { _descargando = false; _error = 'URL de APK no disponible'; });
          return;
        }
        final path = '${dir.path}/SIS_POS_${widget.version}.apk';
        await dio.download(url, path, onReceiveProgress: (rec, total) {
          if (total > 0) setState(() => _progreso = rec / total);
        });
        setState(() => _estado = 'Abriendo instalador...');
        await OpenFilex.open(path);
      } else {
        final path = '${dir.path}\\SIS_POS_${widget.version}_setup.exe';
        await dio.download(widget.downloadUrl, path, onReceiveProgress: (rec, total) {
          if (total > 0) setState(() => _progreso = rec / total);
        });
        setState(() => _estado = 'Lanzando instalador...');
        await Process.start(path, [], runInShell: false, mode: ProcessStartMode.detached);
        await Future.delayed(const Duration(seconds: 1));
        exit(0);
      }
    } catch (e) {
      setState(() { _descargando = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_progreso * 100).round();

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Icon badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _greenMid.withAlpha(38), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.store_rounded, color: _greenMid, size: 38),
                ),
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: _greenMid,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.download_rounded, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'Actualización disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Hay una nueva versión de SIS POS lista para instalar.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _textMuted, height: 1.5),
            ),

            const SizedBox(height: 20),

            // Version pills
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Pill(label: 'v$_currentVersion', bg: _errorBg,     fg: _errorColor),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: _textMuted),
                ),
                _Pill(label: 'v${widget.version}', bg: _greenPillBg, fg: _greenPillFg),
              ],
            ),

            const SizedBox(height: 24),

            // Progreso
            if (_descargando) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_estado, style: const TextStyle(fontSize: 12, color: _textMuted)),
                  Text('$pct%', style: const TextStyle(fontSize: 12, color: _textMuted)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progreso > 0 ? _progreso : null,
                  minHeight: 8,
                  backgroundColor: _border,
                  valueColor: const AlwaysStoppedAnimation<Color>(_greenMid),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Error
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _errorBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: _errorColor)),
              ),
              const SizedBox(height: 16),
            ],

            // Botón primario
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _descargando ? null : _descargar,
                style: FilledButton.styleFrom(
                  backgroundColor: _greenMid,
                  disabledBackgroundColor: _greenMid.withAlpha(153),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ).copyWith(
                  shadowColor: WidgetStatePropertyAll(_greenMid.withAlpha(76)),
                  elevation: const WidgetStatePropertyAll(4),
                ),
                child: Text(_descargando ? 'Descargando...' : (_error != null ? 'Reintentar' : 'Actualizar ahora')),
              ),
            ),

            // Botón secundario
            if (!widget.obligatoria && !_descargando) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  child: const Text('Más tarde'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;
  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
