// lib/screens/compras/widgets/nueva_orden_dialog.dart

import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/barcode_service.dart';
import '../../../services/compra_service.dart';
import '../../../services/compras_pdf_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../compras_theme.dart'; // solo fmt(), esAdmin()
import 'fila_producto_widget.dart';
import 'pdf_preview_dialog.dart';

class NuevaOrdenDialog extends StatefulWidget {
  const NuevaOrdenDialog({super.key});

  @override
  State<NuevaOrdenDialog> createState() => _NuevaOrdenDialogState();
}

class _NuevaOrdenDialogState extends State<NuevaOrdenDialog> {
  final _formKey = GlobalKey<FormState>();
  final _obsCtrl = TextEditingController();

  int?                             _proveedorId;
  int?                             _tiendaId;
  bool                             _multiTienda = false;
  final Set<int>                   _tiendasSeleccionadas = {};
  final List<Map<String, dynamic>> _detalles = [];
  bool                             _parseando      = false;
  bool                             _buscandoBarcode = false;
  bool                             _scanActivo     = false;
  Timer?                           _scanPulseTimer;
  StreamSubscription<String>?      _barcodeSub;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (!ComprasTheme.esAdmin(auth.rol)) {
      _tiendaId = auth.tiendaId == 0 ? null : auth.tiendaId;
    }
    _barcodeSub = BarcodeService.instance.onBarcode.listen(_onBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDatos());
  }

  // ── Escáner de código de barras ──────────────────────────────

  void _pulsarEscaner() {
    setState(() => _scanActivo = true);
    _scanPulseTimer?.cancel();
    _scanPulseTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scanActivo = false);
    });
  }

  Future<void> _onBarcode(String codigo) async {
    if (!mounted) return;
    _pulsarEscaner();

    setState(() => _buscandoBarcode = true);
    // Búsqueda a nivel empresa (sin tiendaId) para encontrar cualquier
    // producto existente sin importar en qué tienda tenga inventario.
    final prov = context.read<ProveedoresProvider>();
    final resultados = await prov.buscarProductos(q: codigo);
    if (!mounted) return;
    setState(() => _buscandoBarcode = false);

    if (resultados.isNotEmpty) {
      final p      = resultados.first;
      final id     = p['id'] as int;
      final nombre = p['nombre'] as String? ?? '';
      setState(() => _detalles.add({
        'producto':         id,
        'nombre':           nombre,
        'cantidad':         '1',
        'precio_unitario':  '',
        'categoria_nombre': '',
      }));
    } else {
      await _alertaProductoNoEncontrado(codigo);
    }
  }

  Future<void> _alertaProductoNoEncontrado(String codigo) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        title: Row(children: [
          const Icon(Icons.qr_code_rounded,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Text('Producto no encontrado',
              style: AppTextStyles.headlineSm),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text('El código escaneado no existe en el inventario:',
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Text(codigo,
                  style: AppTextStyles.bodyMd.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ),
            const SizedBox(height: 12),
            Text(
              '¿Deseas agregar este código como producto nuevo '
              'en la orden para crearlo al recibirla?',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _detalles.add({
                'producto':            null,
                'nombre':              '',
                'codigo_barras_input': codigo,
                'cantidad':            '1',
                'precio_unitario':     '',
                'categoria_nombre':    '',
              }));
            },
            icon:  const Icon(Icons.add_rounded, size: 16),
            label: Text('Agregar como nuevo',
                style: AppTextStyles.bodyMd
                    .copyWith(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.onSecondary,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.xl),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarDatos() async {
    final prov = context.read<ProveedoresProvider>();
    await Future.wait([
      prov.cargarProveedoresSimple(),
      prov.cargarTiendasSimple(),
      prov.cargarCategoriasSimple(),
    ]);
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    _barcodeSub?.cancel();
    _scanPulseTimer?.cancel();
    super.dispose();
  }

  double get _total => _detalles.fold(0, (s, d) {
    final cant = double.tryParse(d['cantidad'].toString()) ?? 0;
    final prec = double.tryParse(d['precio_unitario'].toString()) ?? 0;
    return s + cant * prec;
  });

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<ProveedoresProvider>();
    final auth    = context.watch<AuthProvider>();
    final esAdmin = ComprasTheme.esAdmin(auth.rol);

    return AlertDialog(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
      titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(children: [
        const Icon(Icons.shopping_cart_rounded,
            color: AppColors.secondary, size: 22),
        const SizedBox(width: 10),
        Text('Nueva orden de compra', style: AppTextStyles.headlineSm),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color:        _scanActivo
                ? AppColors.secondary.withValues(alpha: 0.12)
                : AppColors.surfaceContainerLow,
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: _scanActivo
                  ? AppColors.secondary
                  : AppColors.outlineVariant),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _buscandoBarcode
                ? const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.secondary))
                : Icon(Icons.qr_code_scanner_rounded,
                    size: 14,
                    color: _scanActivo
                        ? AppColors.secondary
                        : AppColors.onSurfaceVariant),
            if (_scanActivo && !_buscandoBarcode) ...[
              const SizedBox(width: 4),
              Text('OK',
                  style: AppTextStyles.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary)),
            ],
          ]),
        ),
      ]),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                // ── Tienda / Multi-tienda (solo admin) ──
                if (esAdmin) ...[
                  Row(children: [
                    _label('Tienda'),
                    const Spacer(),
                    Text('Multi-tienda',
                        style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant)),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value:          _multiTienda,
                        activeColor:    AppColors.secondary,
                        onChanged: (v) => setState(() {
                          _multiTienda = v;
                          if (v) {
                            _tiendaId = null;
                          } else {
                            _tiendasSeleccionadas.clear();
                          }
                        }),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  if (!_multiTienda) ...[
                    DropdownButtonFormField<int>(
                      value:      _tiendaId,
                      decoration: _dropdownDeco(Icons.store_rounded),
                      style: AppTextStyles.bodyMd
                          .copyWith(fontSize: 13, color: AppColors.onSurface),
                      hint: Text('Seleccionar tienda',
                          style: AppTextStyles.bodyMd
                              .copyWith(fontSize: 13,
                                  color: AppColors.outlineVariant)),
                      validator: (v) => v == null
                          ? 'Selecciona una tienda' : null,
                      items: prov.tiendasSimple.map((t) =>
                        DropdownMenuItem<int>(
                          value: t['id'] as int,
                          child: Text(t['nombre'],
                              style: AppTextStyles.bodyMd
                                  .copyWith(fontSize: 13)),
                        ),
                      ).toList(),
                      onChanged: (v) => setState(() => _tiendaId = v),
                    ),
                  ] else ...[
                    if (prov.tiendasSimple.isEmpty)
                      Text('Cargando tiendas...',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.onSurfaceVariant))
                    else ...[
                      Text('Selecciona las tiendas que recibirán este pedido:',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: prov.tiendasSimple.map((t) {
                          final id       = t['id'] as int;
                          final selected = _tiendasSeleccionadas.contains(id);
                          return FilterChip(
                            label: Text(t['nombre'] as String),
                            selected: selected,
                            onSelected: (v) => setState(() {
                              if (v) {
                                _tiendasSeleccionadas.add(id);
                              } else {
                                _tiendasSeleccionadas.remove(id);
                              }
                            }),
                            selectedColor: AppColors.secondary
                                .withValues(alpha: 0.15),
                            checkmarkColor: AppColors.secondary,
                            backgroundColor:
                                AppColors.surfaceContainerLow,
                            side: BorderSide(
                              color: selected
                                  ? AppColors.secondary
                                  : AppColors.outlineVariant,
                            ),
                            labelStyle: AppTextStyles.bodySm.copyWith(
                              color: selected
                                  ? AppColors.secondary
                                  : AppColors.onSurface,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_tiendasSeleccionadas.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Selecciona al menos una tienda',
                            style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.error, fontSize: 11),
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: 14),
                ],

                // ── Proveedor ───────────────────────────
                _label('Proveedor *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value:      _proveedorId,
                  decoration: _dropdownDeco(Icons.local_shipping_rounded),
                  style: AppTextStyles.bodyMd
                      .copyWith(fontSize: 13, color: AppColors.onSurface),
                  hint: Text('Seleccionar proveedor',
                      style: AppTextStyles.bodyMd
                          .copyWith(fontSize: 13,
                              color: AppColors.outlineVariant)),
                  validator: (v) =>
                      v == null ? 'Selecciona un proveedor' : null,
                  items: prov.proveedoresSimple.map((p) =>
                    DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Text(
                        '${p['nombre']}${p['nit'] != null ? ' — ${p['nit']}' : ''}',
                        style: AppTextStyles.bodyMd
                            .copyWith(fontSize: 13)),
                    ),
                  ).toList(),
                  onChanged: (v) => setState(() => _proveedorId = v),
                ),
                const SizedBox(height: 14),

                // ── Observaciones ───────────────────────
                _label('Observaciones'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _obsCtrl,
                  maxLines:   2,
                  style:      AppTextStyles.bodyMd.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Notas adicionales (opcional)',
                    hintStyle: AppTextStyles.bodyMd
                        .copyWith(fontSize: 13,
                            color: AppColors.outlineVariant),
                    filled:    true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: const OutlineInputBorder(
                        borderRadius: AppRadius.lg,
                        borderSide:
                            BorderSide(color: AppColors.outlineVariant)),
                    enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.lg,
                        borderSide:
                            BorderSide(color: AppColors.outlineVariant)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.lg,
                        borderSide: BorderSide(
                            color: AppColors.secondary, width: 1.5)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Subir factura del proveedor ─────────
                _buildSubirFactura(),
                const SizedBox(height: 20),

                // ── Productos ───────────────────────────
                Row(children: [
                  Text('Productos',
                      style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() =>
                      _detalles.add({
                        'producto':         null,
                        'nombre':           '',
                        'cantidad':         '1',
                        'precio_unitario':  '',
                        'categoria_nombre': '',
                      }),
                    ),
                    icon:  const Icon(Icons.add_rounded, size: 16),
                    label: Text('Agregar producto',
                        style: AppTextStyles.bodySm),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondary),
                  ),
                ]),
                const SizedBox(height: 8),

                if (_detalles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadius.lg,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Center(child: Text(
                      'Agrega al menos un producto',
                      style: AppTextStyles.bodySm)),
                  )
                else
                  ..._detalles.asMap().entries.map((e) =>
                    FilaProductoWidget(
                      key:               ValueKey(e.key),
                      index:             e.key,
                      fila:              e.value,
                      tiendaId:          _tiendaId,
                      multiTienda:       _multiTienda,
                      tiendasDisponibles: _multiTienda
                          ? prov.tiendasSimple
                              .where((t) => _tiendasSeleccionadas
                                  .contains(t['id'] as int))
                              .toList()
                          : const [],
                      onEliminar: () =>
                          setState(() => _detalles.removeAt(e.key)),
                      onCambio: (fila) =>
                          setState(() => _detalles[e.key] = fila),
                    ),
                  ),

                // ── Total ───────────────────────────────
                if (_detalles.isNotEmpty) ...[
                  const Divider(height: 24,
                      color: AppColors.outlineVariant),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Total estimado: ',
                          style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant)),
                      Text('\$${ComprasTheme.fmt(_total)}',
                          style: AppTextStyles.numericData
                              .copyWith(color: AppColors.secondary)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant))),
        Consumer<ProveedoresProvider>(
          builder: (ctx2, p, child) => ElevatedButton.icon(
            onPressed: p.guardando ||
                    _detalles.isEmpty ||
                    (!_multiTienda && _tiendaId == null) ||
                    (_multiTienda && _tiendasSeleccionadas.isEmpty)
                ? null
                : _crear,
            icon: p.guardando
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onSecondary))
                : const Icon(Icons.send_rounded, size: 16),
            label: Text('Crear orden',
                style: AppTextStyles.bodyMd
                    .copyWith(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.onSecondary,
              disabledBackgroundColor:
                  AppColors.outlineVariant.withValues(alpha: 0.4),
              elevation: 0,
              shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.xl),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ── Subir e interpretar factura PDF ──────────────────────────

  Widget _buildSubirFactura() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.picture_as_pdf_rounded,
                size: 16, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Importar desde factura del proveedor',
              style: AppTextStyles.labelMd
                  .copyWith(color: AppColors.onSurface),
            ),
            const Spacer(),
            if (_parseando)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.secondary),
              )
            else
              TextButton.icon(
                onPressed: _subirFactura,
                icon: const Icon(Icons.upload_file_rounded, size: 14),
                label: Text('Subir PDF', style: AppTextStyles.bodySm),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Sube la factura en PDF y revisa los productos antes de importarlos.',
            style: AppTextStyles.bodySm
                .copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _subirFactura() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _parseando = true);
    List<Map<String, dynamic>> productos = [];
    try {
      productos = await CompraService().parsearFactura(File(path));
    } finally {
      if (mounted) setState(() => _parseando = false);
    }

    if (!mounted) return;

    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'No se encontraron productos en el PDF. '
          'Agrega los ítems manualmente.',
          style: AppTextStyles.bodyMd
              .copyWith(color: AppColors.onSecondary)),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    // ── Mostrar preview y esperar confirmación ────────────────
    final confirmados = await PdfPreviewDialog.mostrar(context, productos);
    if (!mounted || confirmados == null) return;

    setState(() {
      for (final p in confirmados) {
        _detalles.add(p);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        '${confirmados.length} producto(s) importados.',
        style: AppTextStyles.bodyMd
            .copyWith(color: AppColors.onSecondary)),
      backgroundColor: AppColors.secondary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      margin: const EdgeInsets.all(16),
    ));
  }

  // Devuelve true si se puede continuar creando la orden.
  Future<bool> _chequearDuplicado() async {
    final ctx  = context; // captura antes de cualquier gap async
    final prov = ctx.read<ProveedoresProvider>();
    final ahora = DateTime.now();

    final recientes = prov.compras.where((c) {
      if ((c['proveedor'] as int?) != _proveedorId) return false;
      final fecha = DateTime.tryParse(c['fecha_orden'] ?? '');
      if (fecha == null) return false;
      return ahora.difference(fecha).inDays <= 30;
    }).toList();

    if (recientes.isEmpty) return true;

    final nombreProv = (prov.proveedoresSimple.firstWhere(
          (p) => p['id'] == _proveedorId,
          orElse: () => {'nombre': 'este proveedor'},
        )['nombre'] as String);

    if (!ctx.mounted) return false;

    return await showDialog<bool>(
          context: ctx,
          builder: (ctx) => AlertDialog(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('¿Crear otra orden?',
                    style: AppTextStyles.headlineSm),
              ),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Ya tienes ${recientes.length} orden(es) reciente(s) '
                  'de $nombreProv en los últimos 30 días:',
                  style: AppTextStyles.bodyMd,
                ),
                const SizedBox(height: 10),
                ...recientes.map((o) {
                  final fecha = DateTime.tryParse(
                      o['fecha_orden'] ?? '');
                  final dias = fecha == null
                      ? ''
                      : ' · hace ${ahora.difference(fecha).inDays}d';
                  final estado = o['estado'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: estado == 'pendiente'
                              ? AppColors.warningContainer
                              : AppColors.surfaceContainerLow,
                          borderRadius: const BorderRadius.all(
                              Radius.circular(6)),
                        ),
                        child: Text(
                          o['numero_orden'] ?? '—',
                          style: AppTextStyles.labelSm.copyWith(
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_capitalize(estado)}$dias',
                        style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 4),
                Text(
                  'Si es una reposición legítima, puedes continuar.',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar',
                    style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.onSecondary,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.xl),
                ),
                child: Text('Crear de todas formas',
                    style: AppTextStyles.bodyMd
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proveedorId == null) return;
    if (!await _chequearDuplicado()) return;
    if (!mounted) return;

    final compra = await context
        .read<ProveedoresProvider>()
        .crearCompra({
      if (!_multiTienda) 'tienda': _tiendaId,
      'proveedor':     _proveedorId,
      'observaciones': _obsCtrl.text.trim(),
      'detalles': _detalles.map((d) {
        final pv = double.tryParse(
            d['precio_venta']?.toString() ?? '');
        final distribuciones =
            (d['distribuciones'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return {
          'producto':               d['producto'],
          'nombre_libre':           d['nombre'] ?? '',
          'codigo_barras_input':    d['codigo_barras_input'] ?? '',
          'categoria_nombre_input': d['categoria_nombre'] ?? '',
          'cantidad':        double.tryParse(
              d['cantidad'].toString()) ?? 0,
          'precio_unitario': double.tryParse(
              d['precio_unitario'].toString()) ?? 0,
          if (pv != null && pv > 0) 'precio_venta': pv,
          if (_multiTienda && distribuciones.isNotEmpty)
            'distribuciones': distribuciones.map((dist) => {
              'tienda':   dist['tienda'],
              'cantidad': dist['cantidad'],
            }).toList(),
        };
      }).toList(),
    });

    if (!mounted) return;
    Navigator.pop(context);

    if (compra != null) {
      ComprasPDFService.instance.abrirOrdenCompra(compra).ignore();
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        compra != null
            ? 'Orden ${compra['numero_orden']} creada — PDF guardado'
            : 'Error al crear la orden',
        style: AppTextStyles.bodyMd
            .copyWith(color: AppColors.onSecondary)),
      backgroundColor: compra != null
          ? AppColors.secondary
          : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _label(String texto) => Text(texto,
      style: AppTextStyles.bodySm
          .copyWith(color: AppColors.onSurfaceVariant));

  InputDecoration _dropdownDeco(IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, size: 18, color: AppColors.outline),
    filled:    true,
    fillColor: AppColors.surfaceContainerLow,
    border: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(color: AppColors.outlineVariant)),
    enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(color: AppColors.outlineVariant)),
    focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(
            color: AppColors.secondary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 4, vertical: 12),
  );
}
