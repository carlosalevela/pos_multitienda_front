// lib/screens/compras/widgets/modal_precios_recibir.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

// ── Resultado del modal ───────────────────────────────────
class PreciosRecibir {
  final Map<String, double> precios;
  final Map<String, double> preciosMayoreo;
  const PreciosRecibir({
    required this.precios,
    required this.preciosMayoreo,
  });
}

// ── Helper para abrir el modal ────────────────────────────
Future<PreciosRecibir?> showModalPreciosRecibir({
  required BuildContext         context,
  required Map<String, dynamic> compra,
  required bool                 manejaM,
  required int                  cantidadM,
}) {
  return showDialog<PreciosRecibir>(
    context:            context,
    barrierDismissible: false,
    builder: (_) => _ModalPreciosRecibir(
      compra:    compra,
      manejaM:   manejaM,
      cantidadM: cantidadM,
    ),
  );
}

// ── Widget modal ──────────────────────────────────────────
class _ModalPreciosRecibir extends StatefulWidget {
  const _ModalPreciosRecibir({
    required this.compra,
    required this.manejaM,
    required this.cantidadM,
  });
  final Map<String, dynamic> compra;
  final bool                 manejaM;
  final int                  cantidadM;

  @override
  State<_ModalPreciosRecibir> createState() =>
      _ModalPreciosRecibirState();
}

class _ModalPreciosRecibirState
    extends State<_ModalPreciosRecibir> {
  // _ctrls[detalleId] = {'venta': ctrl, 'mayoreo': ctrl}
  final Map<String, Map<String, TextEditingController>> _ctrls = {};

  @override
  void initState() {
    super.initState();
    _inicializarControllers();
  }

  @override
  void dispose() {
    for (final m in _ctrls.values) {
      m['venta']?.dispose();
      m['mayoreo']?.dispose();
    }
    super.dispose();
  }

  void _inicializarControllers() {
    final detalles = (widget.compra['detalles'] as List?) ?? [];
    for (final d in detalles) {
      final id    = d['id'].toString();
      final costo = double.tryParse(
              d['precio_unitario']?.toString() ?? '0') ?? 0;

      final precioActual  = double.tryParse(
              d['precio_venta']?.toString()   ?? '0') ?? 0;
      final precioActualM = double.tryParse(
              d['precio_mayoreo']?.toString() ?? '0') ?? 0;

      final sugerido  = precioActual > 0
          ? precioActual.toStringAsFixed(0)
          : (costo * 1.30).toStringAsFixed(0);
      final sugeridoM = precioActualM > 0
          ? precioActualM.toStringAsFixed(0)
          : (costo * 1.15).toStringAsFixed(0);

      _ctrls[id] = {
        'venta':   TextEditingController(text: sugerido),
        'mayoreo': TextEditingController(text: sugeridoM),
      };
    }
  }

  double _margen(String id) {
    final detalles = (widget.compra['detalles'] as List?) ?? [];
    final d = detalles.firstWhere(
      (x) => x['id'].toString() == id,
      orElse: () => <String, dynamic>{},
    );
    final costo = double.tryParse(
            d['precio_unitario']?.toString() ?? '0') ?? 0;
    final venta = double.tryParse(
            _ctrls[id]?['venta']?.text ?? '0') ?? 0;
    if (costo <= 0 || venta <= 0) return 0;
    return ((venta - costo) / costo) * 100;
  }

  Color _colorMargen(double m) {
    if (m < 0)  return AppColors.error;
    if (m < 10) return AppColors.error;
    if (m < 20) return AppColors.warning;
    return AppColors.secondary;
  }

  bool _preciosBajoElCosto() {
    final detalles = (widget.compra['detalles'] as List?) ?? [];
    for (final d in detalles) {
      final id    = d['id'].toString();
      final costo = double.tryParse(
              d['precio_unitario']?.toString() ?? '0') ?? 0;
      final venta = double.tryParse(
              _ctrls[id]?['venta']?.text ?? '0') ?? 0;
      if (venta > 0 && venta < costo) return true;
    }
    return false;
  }

  void _confirmar() {
    if (_preciosBajoElCosto()) {
      _mostrarAdvertencia();
      return;
    }
    _enviar();
  }

  void _enviar() {
    final precios        = <String, double>{};
    final preciosMayoreo = <String, double>{};

    for (final entry in _ctrls.entries) {
      final id      = entry.key;
      final venta   = double.tryParse(
              entry.value['venta']?.text ?? '0') ?? 0;
      final mayoreo = double.tryParse(
              entry.value['mayoreo']?.text ?? '0') ?? 0;

      if (venta > 0) precios[id] = venta;
      if (widget.manejaM && mayoreo > 0) preciosMayoreo[id] = mayoreo;
    }

    Navigator.pop(
      context,
      PreciosRecibir(precios: precios, preciosMayoreo: preciosMayoreo),
    );
  }

  void _mostrarAdvertencia() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Text('Precio bajo el costo',
              style: AppTextStyles.headlineSm.copyWith(fontSize: 15)),
        ]),
        content: Text(
          'Uno o más productos tienen precio de venta '
          'menor al costo. ¿Deseas continuar de todas formas?',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Revisar',
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _enviar();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.xl),
            ),
            child: Text('Continuar',
                style: AppTextStyles.bodyMd
                    .copyWith(fontWeight: FontWeight.w600,
                        color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detalles = (widget.compra['detalles'] as List?) ?? [];
    final numero   = widget.compra['numero_orden'] ?? '';

    return Dialog(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20))),
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Header ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Row(children: [
                const Icon(Icons.price_change_rounded,
                    color: AppColors.onSecondary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fijar precios de venta',
                          style: AppTextStyles.headlineSm.copyWith(
                              color: AppColors.onSecondary)),
                      Text('Orden $numero',
                          style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.onSecondary
                                  .withOpacity(0.7))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.onSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            // ── Nota informativa ────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:  AppColors.warningContainer,
                borderRadius: AppRadius.lg,
                border: Border.all(
                    color: AppColors.warning.withOpacity(0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.manejaM
                        ? 'Precio venta normal y mayoreo '
                          '(desde ${widget.cantidadM} uds). '
                          'Sugeridos: 30% y 15% sobre el costo.'
                        : 'Revisa el precio de venta. '
                          'Sugerido: 30% sobre el costo.',
                    style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.warning,
                        letterSpacing: 0.2),
                  ),
                ),
              ]),
            ),

            // ── Lista de productos ───────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: detalles.map<Widget>((d) {
                    final id       = d['id'].toString();
                    final nombre   =
                        d['nombre_producto']?.toString() ??
                        d['nombre_libre']?.toString() ??
                        'Producto';
                    final costo    = double.tryParse(
                            d['precio_unitario']?.toString() ?? '0') ?? 0;
                    final cantidad = double.tryParse(
                            d['cantidad']?.toString() ?? '0') ?? 0;

                    return StatefulBuilder(
                      builder: (ctx, setS) {
                        final m = _margen(id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: AppRadius.xl,
                            border: Border.all(
                                color: AppColors.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Nombre + cantidad
                              Row(children: [
                                Expanded(
                                  child: Text(nombre,
                                      style: AppTextStyles.bodyMd
                                          .copyWith(
                                              fontWeight:
                                                  FontWeight.w600)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: AppRadius.lg,
                                  ),
                                  child: Text(
                                    'x${cantidad.toStringAsFixed(cantidad.truncateToDouble() == cantidad ? 0 : 2)}',
                                    style: AppTextStyles.labelSm
                                        .copyWith(
                                            color: AppColors.secondary)),
                                ),
                              ]),
                              const SizedBox(height: 4),
                              Text(
                                'Costo: \$${costo.toStringAsFixed(0)}',
                                style: AppTextStyles.bodySm,
                              ),
                              const SizedBox(height: 10),

                              // Campos precio
                              Row(children: [
                                Expanded(
                                  child: _CampoPrecio(
                                    label: 'Precio venta',
                                    controller:
                                        _ctrls[id]!['venta']!,
                                    focusColor: AppColors.secondary,
                                    onChanged: (_) => setS(() {}),
                                  ),
                                ),
                                if (widget.manejaM) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _CampoPrecio(
                                      label:
                                          'Mayoreo (≥${widget.cantidadM})',
                                      controller:
                                          _ctrls[id]!['mayoreo']!,
                                      focusColor: AppColors.mintDark,
                                      onChanged: (_) => setS(() {}),
                                    ),
                                  ),
                                ],
                              ]),

                              // Indicador margen
                              const SizedBox(height: 6),
                              Row(children: [
                                Icon(
                                  m >= 0
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 13,
                                  color: _colorMargen(m),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Margen: ${m.toStringAsFixed(1)}%',
                                  style: AppTextStyles.labelSm.copyWith(
                                      color: _colorMargen(m)),
                                ),
                                if (m < 0) ...[
                                  const SizedBox(width: 6),
                                  Text('Bajo el costo',
                                      style: AppTextStyles.labelSm
                                          .copyWith(
                                              color: AppColors.error)),
                                ] else if (m < 10 && m >= 0) ...[
                                  const SizedBox(width: 6),
                                  Text('Margen muy bajo',
                                      style: AppTextStyles.labelSm
                                          .copyWith(
                                              color: AppColors.warning)),
                                ],
                              ]),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── Botones ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      side: const BorderSide(
                          color: AppColors.outlineVariant),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.xl),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                    ),
                    child: Text('Cancelar',
                        style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _confirmar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.xl),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18),
                        const SizedBox(width: 6),
                        Text('Confirmar recepción',
                            style: AppTextStyles.bodyMd.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSecondary)),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Campo precio reutilizable ─────────────────────────────
class _CampoPrecio extends StatelessWidget {
  const _CampoPrecio({
    required this.label,
    required this.controller,
    required this.focusColor,
    required this.onChanged,
  });
  final String                label;
  final TextEditingController controller;
  final Color                 focusColor;
  final ValueChanged<String>  onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSm),
        const SizedBox(height: 4),
        TextFormField(
          controller:   controller,
          onChanged:    onChanged,
          keyboardType: TextInputType.number,
          textAlign:    TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly
          ],
          style: AppTextStyles.numericData.copyWith(fontSize: 15),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: AppTextStyles.bodySm
                .copyWith(color: AppColors.outline),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              borderSide: const BorderSide(
                  color: AppColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              borderSide:
                  BorderSide(color: focusColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              borderSide: const BorderSide(
                  color: AppColors.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }
}
