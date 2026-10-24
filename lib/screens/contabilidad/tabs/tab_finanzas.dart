import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/contabilidad_provider.dart';
import 'tab_pl.dart';
import 'tab_rentabilidad.dart';

class TabFinanzas extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;

  const TabFinanzas({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
  });

  @override
  State<TabFinanzas> createState() => _TabFinanzasState();
}

class _TabFinanzasState extends State<TabFinanzas> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubSelector(
          labels: const ['P&L', 'Rentabilidad'],
          selected: _sel,
          onChanged: (i) => setState(() => _sel = i),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: IndexedStack(
            index: _sel,
            children: [
              TabPL(cont: widget.cont, fmt: widget.fmt, tiendaId: widget.tiendaId),
              TabRentabilidad(tiendaId: widget.tiendaId),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubSelector extends StatelessWidget {
  final List<String>      labels;
  final int               selected;
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
