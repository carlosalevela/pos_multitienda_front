// lib/screens/compras/widgets/resultado_recepcion_dialog.dart

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class ResultadoRecepcionDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const ResultadoRecepcionDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final productos = (data['productos'] as List?) ?? [];

    return AlertDialog(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
      titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: AppColors.secondary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(
          data['detail'] ?? 'Orden recibida',
          style: AppTextStyles.headlineSm.copyWith(fontSize: 15))),
      ]),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.store_rounded,
                    size: 14, color: AppColors.outline),
                const SizedBox(width: 6),
                Text(data['tienda'] ?? '',
                    style: AppTextStyles.bodySm),
              ]),
              const SizedBox(height: 12),
              Text('Productos actualizados:',
                  style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              ...productos.map((p) => _itemProducto(p)),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.onSecondary,
            elevation: 0,
            shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.xl),
          ),
          child: Text('Entendido',
              style: AppTextStyles.bodyMd
                  .copyWith(fontWeight: FontWeight.w600,
                      color: AppColors.onSecondary)),
        ),
      ],
    );
  }

  Widget _itemProducto(Map<String, dynamic> p) {
    final esNuevo = p['es_nuevo'] == true;

    final bgColor     = esNuevo ? AppColors.warningContainer : AppColors.mintLight;
    final borderColor = esNuevo
        ? AppColors.warning.withOpacity(0.35)
        : AppColors.secondaryContainer.withOpacity(0.6);
    final iconBg    = esNuevo
        ? AppColors.warning.withOpacity(0.18)
        : AppColors.secondaryContainer.withOpacity(0.5);
    final iconColor = esNuevo ? AppColors.warning : AppColors.secondary;
    final accentColor = iconColor;

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: AppRadius.xl,
        border:       Border.all(color: borderColor),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:        iconBg,
            borderRadius: AppRadius.lg,
          ),
          child: Icon(
            esNuevo ? Icons.add_box_rounded : Icons.inventory_2_rounded,
            size:  16,
            color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(p['producto'] ?? '',
                  style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600, fontSize: 12))),
              if (esNuevo)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color:        AppColors.warning,
                    borderRadius: AppRadius.full,
                  ),
                  child: Text('NUEVO',
                      style: AppTextStyles.labelSm.copyWith(
                          color: Colors.white, letterSpacing: 0.4)),
                ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              _stockChip(
                Icons.remove_circle_outline_rounded,
                'Antes: ${p['stock_anterior'] ?? 0}',
                isGreen: false),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  size: 12, color: AppColors.outline),
              const SizedBox(width: 6),
              _stockChip(
                Icons.add_circle_outline_rounded,
                'Ahora: ${p['stock_actual'] ?? 0}',
                isGreen: true),
              const SizedBox(width: 8),
              Text(
                '+${p['cantidad_recibida'] ?? 0} uds',
                style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accentColor)),
            ]),
          ],
        )),
      ]),
    );
  }

  Widget _stockChip(IconData icon, String texto, {required bool isGreen}) {
    final bg     = isGreen ? AppColors.mintLight       : AppColors.surfaceContainerLow;
    final border = isGreen ? AppColors.secondaryContainer.withOpacity(0.5)
                           : AppColors.outlineVariant;
    final ic     = isGreen ? AppColors.secondary       : AppColors.outline;
    final tx     = isGreen ? AppColors.mintDark        : AppColors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: AppRadius.lg,
        border:       Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: ic),
        const SizedBox(width: 3),
        Text(texto, style: AppTextStyles.labelSm.copyWith(color: tx)),
      ]),
    );
  }
}
