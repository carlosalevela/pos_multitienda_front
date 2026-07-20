// lib/screens/etiquetas/etiquetas_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/proveedores_provider.dart';
import '../../services/barcode_service.dart';
import '../../services/etiqueta_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// ── Colores locales ───────────────────────────────────────────
const _kBg         = Color(0xFFF5F7F8);
const _kSurface    = Color(0xFFFFFFFF);
const _kBorder     = Color(0xFFE5E7EB);
const _kText       = Color(0xFF111827);
const _kMuted      = Color(0xFF6B7280);
const _kGreen      = Color(0xFF10B981);
const _kGreenLight = Color(0xFFD1FAE5);
const _kPurple     = Color(0xFF7C3AED);
const _kPurpleLight= Color(0xFFF5F3FF);

class EtiquetasScreen extends StatefulWidget {
  const EtiquetasScreen({super.key});

  @override
  State<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends State<EtiquetasScreen> {
  final _etiquetaService = EtiquetaService();
  final _searchCtrl      = TextEditingController();

  PlantillaEtiqueta          _plantilla = PlantillaEtiqueta.defaults();
  Map<String, dynamic>?      _producto;
  List<Map<String, dynamic>> _sugerencias = [];
  bool                       _buscando   = false;
  bool                       _scanActivo = false;
  Timer?                     _scanTimer;
  StreamSubscription<String>? _barcodeSub;

  // Clave que fuerza rebuild del PdfPreview cuando cambia config
  UniqueKey _previewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _cargarPlantilla();
    _barcodeSub = BarcodeService.instance.onBarcode.listen(_onBarcode);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _barcodeSub?.cancel();
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarPlantilla() async {
    final p = await _etiquetaService.cargarPlantilla();
    if (mounted) setState(() => _plantilla = p);
  }

  void _actualizarPlantilla(PlantillaEtiqueta nueva) {
    setState(() {
      _plantilla   = nueva;
      _previewKey  = UniqueKey();
    });
    _etiquetaService.guardarPlantilla(nueva);
  }

  // ── Búsqueda de producto ──────────────────────────────────

  Future<void> _buscar(String q) async {
    if (q.length < 2) {
      setState(() => _sugerencias = []);
      return;
    }
    setState(() => _buscando = true);
    final res = await context
        .read<ProveedoresProvider>()
        .buscarProductos(q: q);
    if (mounted) setState(() { _sugerencias = res; _buscando = false; });
  }

  void _seleccionarProducto(Map<String, dynamic> p) {
    final auth     = context.read<AuthProvider>();
    final tiendaNombre = auth.tiendaNombre;
    setState(() {
      _producto   = {...p, if (tiendaNombre.isNotEmpty) 'tienda_nombre': tiendaNombre};
      _sugerencias = [];
      _previewKey  = UniqueKey();
      _searchCtrl.text = p['nombre'] as String? ?? '';
    });
  }

  // ── Escáner ───────────────────────────────────────────────

  Future<void> _onBarcode(String codigo) async {
    if (!mounted) return;
    setState(() => _scanActivo = true);
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scanActivo = false);
    });

    setState(() => _buscando = true);
    final res = await context
        .read<ProveedoresProvider>()
        .buscarProductos(q: codigo);
    if (!mounted) return;
    setState(() => _buscando = false);

    if (res.isNotEmpty) {
      _seleccionarProducto(res.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Código "$codigo" no encontrado en inventario',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.warning,
        behavior:        SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
      ));
    }
  }

  // ── PDF builder para PdfPreview ───────────────────────────

  Future<Uint8List> _buildPdf(PdfPageFormat _) async {
    if (_producto == null) {
      return _etiquetaService.generarPdfVacio(_plantilla);
    }
    return _etiquetaService.generarPdf(_plantilla, _producto!);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: Row(children: [
            // Panel izquierdo: configuración
            SizedBox(
              width: 300,
              child: _buildConfigPanel(),
            ),
            const VerticalDivider(width: 1, color: _kBorder),
            // Panel derecho: preview + imprimir
            Expanded(child: _buildPreviewPanel()),
          ]),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(children: [
        const Icon(Icons.label_rounded, color: _kPurple, size: 20),
        const SizedBox(width: 10),
        Text('Etiquetas de productos',
            style: AppTextStyles.headlineSm),
        const Spacer(),
        // Indicador escáner
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:        _scanActivo ? _kGreenLight : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _scanActivo ? _kGreen : _kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _buscando
                ? const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: _kGreen))
                : Icon(Icons.qr_code_scanner_rounded,
                    size: 14,
                    color: _scanActivo ? _kGreen : _kMuted),
            if (_scanActivo && !_buscando) ...[
              const SizedBox(width: 5),
              Text('Escaneado',
                  style: AppTextStyles.labelSm.copyWith(
                      color: _kGreen, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Panel izquierdo ───────────────────────────────────────

  Widget _buildConfigPanel() {
    return Container(
      color: _kSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buscar producto
            _sectionTitle('Producto'),
            const SizedBox(height: 8),
            _buildBuscadorProducto(),
            if (_producto != null) ...[
              const SizedBox(height: 8),
              _buildProductoSeleccionado(),
            ],
            const SizedBox(height: 20),

            // Tamaño
            _sectionTitle('Tamaño de etiqueta'),
            const SizedBox(height: 8),
            _buildTamanos(),
            const SizedBox(height: 12),
            // Dimensiones custom
            Row(children: [
              Expanded(child: _buildMmField('Ancho', _plantilla.anchoMm,
                  (v) => _actualizarPlantilla(_plantilla.copyWith(anchoMm: v)))),
              const SizedBox(width: 8),
              Expanded(child: _buildMmField('Alto', _plantilla.altoMm,
                  (v) => _actualizarPlantilla(_plantilla.copyWith(altoMm: v)))),
            ]),
            const SizedBox(height: 20),

            // Campos
            _sectionTitle('Campos visibles'),
            const SizedBox(height: 6),
            _buildToggle('Código de barras', Icons.barcode_reader,
                _plantilla.mostrarBarcode,
                (v) => _actualizarPlantilla(_plantilla.copyWith(mostrarBarcode: v))),
            _buildToggle('Nombre del producto', Icons.label_outline_rounded,
                _plantilla.mostrarNombre,
                (v) => _actualizarPlantilla(_plantilla.copyWith(mostrarNombre: v))),
            _buildToggle('Precio de venta', Icons.attach_money_rounded,
                _plantilla.mostrarPrecio,
                (v) => _actualizarPlantilla(_plantilla.copyWith(mostrarPrecio: v))),
            _buildToggle('Tienda', Icons.store_rounded,
                _plantilla.mostrarTienda,
                (v) => _actualizarPlantilla(_plantilla.copyWith(mostrarTienda: v))),
            _buildToggle('Categoría', Icons.category_rounded,
                _plantilla.mostrarCategoria,
                (v) => _actualizarPlantilla(_plantilla.copyWith(mostrarCategoria: v))),
            const SizedBox(height: 20),

            // Tamaño de fuente
            _sectionTitle('Tipografía'),
            const SizedBox(height: 8),
            _buildSlider('Nombre', _plantilla.fontSizeNombre, 6, 14,
                (v) => _actualizarPlantilla(_plantilla.copyWith(fontSizeNombre: v))),
            _buildSlider('Precio', _plantilla.fontSizePrecio, 8, 18,
                (v) => _actualizarPlantilla(_plantilla.copyWith(fontSizePrecio: v))),
            const SizedBox(height: 20),

            // Cantidad
            _sectionTitle('Cantidad a imprimir'),
            const SizedBox(height: 8),
            _buildCantidad(),
          ],
        ),
      ),
    );
  }

  Widget _buildBuscadorProducto() {
    return Column(children: [
      TextField(
        controller: _searchCtrl,
        style: AppTextStyles.bodyMd.copyWith(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o código...',
          hintStyle: AppTextStyles.bodySm.copyWith(color: _kMuted),
          prefixIcon: _buscando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kPurple)))
              : const Icon(Icons.search_rounded, size: 18, color: _kMuted),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  color: _kMuted,
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _producto    = null;
                      _sugerencias = [];
                      _previewKey  = UniqueKey();
                    });
                  })
              : null,
          filled:    true,
          fillColor: const Color(0xFFF9FAFB),
          isDense:   true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPurple, width: 1.5)),
        ),
        onChanged: _buscar,
      ),
      if (_sugerencias.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color:        _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: _sugerencias.take(6).map((p) => InkWell(
              onTap: () => _seleccionarProducto(p),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['nombre'] as String? ?? '',
                          style: AppTextStyles.bodyMd.copyWith(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(p['codigo_barras'] as String? ?? '—',
                          style: AppTextStyles.bodySm.copyWith(
                              fontSize: 10, color: _kMuted)),
                    ],
                  )),
                  const Icon(Icons.chevron_right_rounded,
                      size: 14, color: _kMuted),
                ]),
              ),
            )).toList(),
          ),
        ),
    ]);
  }

  Widget _buildProductoSeleccionado() {
    final p = _producto!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        _kPurpleLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPurple.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_rounded,
              size: 14, color: _kPurple),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p['nombre'] as String? ?? '',
                style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w600, fontSize: 12)),
            Text(p['codigo_barras'] as String? ?? 'Sin código',
                style: AppTextStyles.bodySm.copyWith(
                    fontSize: 10, color: _kMuted)),
          ],
        )),
        Icon(Icons.check_circle_rounded, size: 16, color: _kPurple),
      ]),
    );
  }

  Widget _buildTamanos() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tamanos.map((t) {
        final esPersonalizado = t.anchoMm == 0;
        final seleccionado    = esPersonalizado
            ? !tamanos.any((x) =>
                x.anchoMm != 0 &&
                x.anchoMm == _plantilla.anchoMm &&
                x.altoMm  == _plantilla.altoMm)
            : _plantilla.anchoMm == t.anchoMm &&
              _plantilla.altoMm  == t.altoMm;

        return GestureDetector(
          onTap: () {
            if (!esPersonalizado) {
              _actualizarPlantilla(_plantilla.copyWith(
                anchoMm: t.anchoMm, altoMm: t.altoMm));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: seleccionado ? _kPurpleLight : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: seleccionado ? _kPurple : _kBorder,
                  width: seleccionado ? 1.5 : 1),
            ),
            child: Text(t.nombre,
                style: AppTextStyles.labelSm.copyWith(
                    color: seleccionado ? _kPurple : _kMuted,
                    fontWeight: seleccionado
                        ? FontWeight.w700 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMmField(String label, double valor, void Function(double) onChange) {
    final ctrl = TextEditingController(text: valor.toStringAsFixed(0));
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: AppTextStyles.bodySm.copyWith(fontSize: 12),
      decoration: InputDecoration(
        labelText: '$label (mm)',
        labelStyle: AppTextStyles.labelSm.copyWith(color: _kMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kPurple, width: 1.5)),
      ),
      onSubmitted: (v) {
        final d = double.tryParse(v);
        if (d != null && d > 0) onChange(d);
      },
    );
  }

  Widget _buildToggle(String label, IconData icon,
      bool valor, void Function(bool) onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => onChange(!valor),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(children: [
            Icon(icon, size: 14,
                color: valor ? _kPurple : _kMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(label,
                style: AppTextStyles.bodySm.copyWith(
                    fontSize: 12,
                    color: valor ? _kText : _kMuted))),
            Switch(
              value:           valor,
              onChanged:       onChange,
              activeColor:     _kPurple,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double valor,
      double min, double max, void Function(double) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: AppTextStyles.labelSm.copyWith(color: _kMuted)),
          const Spacer(),
          Text('${valor.toStringAsFixed(0)} pt',
              style: AppTextStyles.labelSm.copyWith(
                  color: _kPurple, fontWeight: FontWeight.w700)),
        ]),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor:   _kPurple,
            thumbColor:         _kPurple,
            inactiveTrackColor: _kBorder,
            overlayColor:       _kPurple.withOpacity(0.1),
            trackHeight:        3,
          ),
          child: Slider(
            value: valor,
            min:   min,
            max:   max,
            divisions: (max - min).toInt(),
            onChanged: onChange,
          ),
        ),
      ],
    );
  }

  Widget _buildCantidad() {
    return Row(children: [
      IconButton(
        onPressed: _plantilla.cantidad > 1
            ? () => _actualizarPlantilla(
                _plantilla.copyWith(cantidad: _plantilla.cantidad - 1))
            : null,
        icon: const Icon(Icons.remove_rounded, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF3F4F6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(width: 12),
      Text('${_plantilla.cantidad}',
          style: AppTextStyles.headlineSm.copyWith(fontSize: 20)),
      const SizedBox(width: 4),
      Text('etiqueta(s)',
          style: AppTextStyles.bodySm.copyWith(color: _kMuted)),
      const SizedBox(width: 12),
      IconButton(
        onPressed: _plantilla.cantidad < 100
            ? () => _actualizarPlantilla(
                _plantilla.copyWith(cantidad: _plantilla.cantidad + 1))
            : null,
        icon: const Icon(Icons.add_rounded, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF3F4F6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]);
  }

  // ── Panel derecho: preview ────────────────────────────────

  Widget _buildPreviewPanel() {
    return Column(children: [
      // Barra superior del preview
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: _kSurface,
        child: Row(children: [
          const Icon(Icons.preview_rounded, size: 16, color: _kMuted),
          const SizedBox(width: 8),
          Text('Vista previa',
              style: AppTextStyles.bodySm
                  .copyWith(color: _kMuted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_plantilla.anchoMm.toStringAsFixed(0)} × '
              '${_plantilla.altoMm.toStringAsFixed(0)} mm',
              style: AppTextStyles.labelSm.copyWith(color: _kMuted),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _producto == null ? null : _imprimir,
            icon:  const Icon(Icons.print_rounded, size: 16),
            label: Text(
              'Imprimir ${_plantilla.cantidad > 1 ? "${_plantilla.cantidad} etiquetas" : "etiqueta"}',
              style: AppTextStyles.bodyMd
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kBorder,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
            ),
          ),
        ]),
      ),
      const Divider(height: 1, color: _kBorder),

      // PdfPreview
      Expanded(
        child: PdfPreview(
          key:                  _previewKey,
          build:                _buildPdf,
          allowPrinting:        false,
          allowSharing:         false,
          canChangeOrientation: false,
          canChangePageFormat:  false,
          canDebug:             false,
          initialPageFormat: PdfPageFormat(
            _plantilla.anchoMm * PdfPageFormat.mm,
            _plantilla.altoMm  * PdfPageFormat.mm,
            marginAll: 0,
          ),
          pdfFileName: 'etiqueta.pdf',
        ),
      ),
    ]);
  }

  Future<void> _imprimir() async {
    if (_producto == null) return;
    await Printing.layoutPdf(
      onLayout: (_) => _etiquetaService.generarPdf(_plantilla, _producto!),
      name: 'Etiqueta — ${_producto!['nombre'] ?? ''}',
    );
  }

  Widget _sectionTitle(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(texto,
        style: AppTextStyles.bodyMd.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: _kText)),
  );
}
