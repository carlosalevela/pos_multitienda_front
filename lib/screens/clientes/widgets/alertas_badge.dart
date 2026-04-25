import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AlertasBadge extends StatelessWidget {
  final int total;
  final VoidCallback? onTap;
  final bool compacto;

  const AlertasBadge({
    super.key,
    required this.total,
    this.onTap,
    this.compacto = false,
  });

  Color get _color => total > 0
      ? const Color(0xFFA12C7B)
      : const Color(0xFF7A7974);

  Color get _bg => total > 0
      ? const Color(0xFFE0CED7)
      : const Color(0xFFF3F0EC);

  String get _label {
    if (total == 0) return 'Sin alertas';
    if (total == 1) return '1 alerta';
    return '$total alertas';
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 10 : 12,
        vertical: compacto ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                total > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: compacto ? 15 : 16,
                color: _color,
              ),

              // Punto rojo/rosa cuando hay alertas
              if (total > 0)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFA12C7B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 7),
          Text(
            _label,
            style: GoogleFonts.poppins(
              fontSize: compacto ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: child,
    );
  }
}