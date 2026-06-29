import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Surfaces (fondos, tarjetas) ───────────────────────
  static const surface                 = Color(0xFFF7F9FB);
  static const surfaceContainerLowest  = Color(0xFFFFFFFF);
  static const surfaceContainerLow     = Color(0xFFF2F4F6);
  static const surfaceContainer        = Color(0xFFECEEF0);
  static const surfaceContainerHigh    = Color(0xFFE6E8EA);
  static const surfaceContainerHighest = Color(0xFFE0E3E5);
  static const surfaceDim              = Color(0xFFD8DADC);

  // ── On-surface (texto sobre fondos) ──────────────────
  static const onSurface        = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF45464D);
  static const outline          = Color(0xFF76777D);
  static const outlineVariant   = Color(0xFFC6C6CD);

  // ── Primary (negro — botones oscuros, sidebar) ───────
  static const primary          = Color(0xFF000000);
  static const onPrimary        = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF131B2E);

  // ── Secondary (verde esmeralda — acento principal) ───
  static const secondary              = Color(0xFF006C49);
  static const onSecondary            = Color(0xFFFFFFFF);
  static const secondaryContainer     = Color(0xFF6CF8BB);
  static const onSecondaryContainer   = Color(0xFF00714D);

  // ── Verde mint (variante clara — badges, highlights) ─
  static const mint      = Color(0xFF61DDAA);
  static const mintLight = Color(0xFFE8FFF4);
  static const mintDark  = Color(0xFF0B7A53);

  // ── Warning (stock bajo, vencimientos próximos) ──────
  static const warning          = Color(0xFFF59E0B);
  static const warningContainer = Color(0xFFFEF3C7);

  // ── Error ─────────────────────────────────────────────
  static const error            = Color(0xFFBA1A1A);
  static const onError          = Color(0xFFFFFFFF);
  static const errorContainer   = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
}
