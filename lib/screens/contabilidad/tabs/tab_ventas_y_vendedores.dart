import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import 'tab_ventas.dart';
import 'tab_vendedores.dart';

class TabVentasYVendedores extends StatefulWidget {
  final int?         tiendaId;
  final AuthProvider auth;

  const TabVentasYVendedores({
    super.key,
    required this.tiendaId,
    required this.auth,
  });

  @override
  State<TabVentasYVendedores> createState() => _TabVentasYVendedoresState();
}

class _TabVentasYVendedoresState extends State<TabVentasYVendedores> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubSelector(
          labels: const ['Transacciones', 'Por vendedor'],
          selected: _sel,
          onChanged: (i) => setState(() => _sel = i),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: IndexedStack(
            index: _sel,
            children: [
              TabVentas(tiendaId: widget.tiendaId, auth: widget.auth),
              TabVendedores(tiendaId: widget.tiendaId),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubSelector extends StatelessWidget {
  final List<String>    labels;
  final int             selected;
  final ValueChanged<int> onChanged;

  const _SubSelector({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.mintDark : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[i],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
