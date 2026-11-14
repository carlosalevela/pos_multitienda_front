import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Envuelve el [showDateRangePicker] en un Dialog compacto
/// con los colores de la app. Úsalo como builder del picker.
Widget rangePickerDialog(BuildContext ctx, Widget child) {
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 580),
      child: Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:    AppColors.secondary,
            onPrimary:  Colors.white,
            surface:    Colors.white,
            onSurface:  Color(0xFF1A1A2E),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
            ),
          ),
        ),
        child: child,
      ),
    ),
  );
}
