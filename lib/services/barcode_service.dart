// lib/services/barcode_service.dart
//
// Detecta input de lectores de código de barras USB HID.
// Los lectores se comportan como teclado: envían chars muy rápido (< 50 ms
// entre cada uno) y terminan con Enter. Emitimos el código al stream sin
// consumir los eventos, para que los campos de texto también reciban los chars.

import 'dart:async';
import 'package:flutter/services.dart';

class BarcodeService {
  BarcodeService._();
  static final BarcodeService instance = BarcodeService._();

  final _controller = StreamController<String>.broadcast();

  /// Stream que emite cada código leído por el escáner.
  Stream<String> get onBarcode => _controller.stream;

  final _buf = StringBuffer();
  DateTime? _lastKey;
  bool _registered = false;

  // Umbral de tiempo entre teclas: scanner < 50 ms, humano > 150 ms.
  static const _maxGapMs = 80;
  // Longitud mínima para no emitir accidentales (p. ej. un Enter solo).
  static const _minLen = 3;

  void init() {
    if (_registered) return;
    _registered = true;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void shutdown() {
    if (!_registered) return;
    _registered = false;
    HardwareKeyboard.instance.removeHandler(_onKey);
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final gap = _lastKey != null
        ? now.difference(_lastKey!).inMilliseconds
        : 9999;
    _lastKey = now;

    // Si el gap es demasiado grande, el buffer corresponde a tipeo humano → reset.
    if (gap > _maxGapMs && _buf.isNotEmpty) {
      _buf.clear();
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buf.toString().trim();
      _buf.clear();
      // Solo emitir si el último char llegó rápido (patrón escáner) y tiene longitud mínima.
      if (code.length >= _minLen && gap <= _maxGapMs) {
        _controller.add(code);
      }
      return false; // no consumir — el TextField también recibe el Enter
    }

    final ch = event.character;
    if (ch != null && ch.isNotEmpty && ch != '\n' && ch != '\r') {
      _buf.write(ch);
    }

    return false; // no consumir
  }
}
