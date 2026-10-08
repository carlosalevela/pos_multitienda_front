import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onActionPressed,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final isNarrow = c.maxWidth < 540;

      final iconBox = Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(Constants.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: const Color(Constants.primaryColor),
          size: 22,
        ),
      );

      final titleCol = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: isNarrow ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      );

      final actionBtn = ElevatedButton.icon(
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          actionLabel,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        onPressed: onActionPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(Constants.primaryColor),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      );

      if (isNarrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                const SizedBox(width: 12),
                Expanded(child: titleCol),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: actionBtn),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconBox,
          const SizedBox(width: 12),
          Expanded(child: titleCol),
          const SizedBox(width: 12),
          actionBtn,
        ],
      );
    });
  }
}
