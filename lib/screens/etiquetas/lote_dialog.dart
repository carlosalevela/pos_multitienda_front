// lib/screens/etiquetas/lote_dialog.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/proveedores_provider.dart';
import '../../services/barcode_service.dart';
import '../../services/etiqueta_service.dart';
import '../../theme/app_text_styles.dart';

const _kBorder      = Color(0xFFE5E7EB);
const _kMuted       = Color(0xFF6B7280);
const _kText        = Color(0xFF111827);
const _kPurple      = Color(0xFF7C3AED);
const _kPurpleLight = Color(0xFFF5F3FF);
const _kGreen       = Color(0xFF10B981);
const _kGreenLight  = Color(0xFFD1FAE5);
const _kRed         = Color(0xFFEF4444);

class LoteDialog extends StatefulWidget {
  final PlantillaEtiqueta plantilla;
  final EtiquetaService   etiquetaService;

  const LoteDialog({
    super.key,
    required this.plantilla,
    required this.etiquetaService,
  });

  @override
  State<LoteDialog> createState() => _LoteDialogState();
}

class _LoteDialogState extends State<LoteDialog> {
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  // Un controller por ítem (clave = id del producto) para que el campo
  // de cantidad no se resetee al hacer rebuild tras pulsar +/-.
  final Map<Object, TextEditingController> _cantidadCtrls = {};

  final List<LoteItem>        _items               = [];
  List<Map<String, dynamic>>  _sugerencias         = [];
  List<PlantillaGuardada>     _plantillasGuardadas = [];
  late PlantillaEtiqueta      _plantillaActual;
  String?                     _selectedPlantillaId;
  bool                        _buscando            = false;
  bool                        _scanActivo          = false;
  bool                        _imprimiendo         = false;
  bool                        _modoHoja            = false;
  String                      _papelHoja           = 'a4';
  Timer?                      _scanTimer;
  StreamSubscription<String>? _barcodeSub;

  int get _totalEtiquetas => _items.fold(0, (s, i) => s + i.cantidad);

  // Devuelve (o crea) el controller persistente para un ítem.
  TextEditingController _ctrlCantidad(LoteItem item) {
    final key = item.producto['id'] ?? item.producto['nombre'];
    return _cantidadCtrls.putIfAbsent(
        key, () => TextEditingController(text: '${item.cantidad}'));
  }

  // Elimina y libera el controller de un ítem concreto.
  void _removeCtrl(LoteItem item) {
    final key = item.producto['id'] ?? item.producto['nombre'];
    _cantidadCtrls.remove(key)?.dispose();
  }

  @override
  void initState() {
    super.initState();
    _plantillaActual = widget.plantilla;
    _barcodeSub      = BarcodeService.instance.onBarcode.listen(_onBarcode);
    _cargarPlantillas();
  }

  Future<void> _cargarPlantillas() async {
    final lista = await widget.etiquetaService.listarPlantillas();
    if (mounted) setState(() => _plantillasGuardadas = lista);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    for (final c in _cantidadCtrls.values) { c.dispose(); }
    _barcodeSub?.cancel();
    _scanTimer?.cancel();
    super.dispose();
  }

  // ── Búsqueda ──────────────────────────────────────────────

  Future<void> _buscar(String q) async {
    if (q.length < 2) { setState(() => _sugerencias = []); return; }
    setState(() => _buscando = true);
    final res = await context.read<ProveedoresProvider>().buscarProductos(q: q);
    if (mounted) setState(() { _sugerencias = res; _buscando = false; });
  }

  void _agregarProducto(Map<String, dynamic> p) {
    final tienda = context.read<AuthProvider>().tiendaNombre;
    final prod   = {...p, if (tienda.isNotEmpty) 'tienda_nombre': tienda};
    final idx    = _items.indexWhere(
        (i) => i.producto['id'] == prod['id']);

    setState(() {
      if (idx >= 0) {
        _items[idx].cantidad++;
        // Sincronizar el controller para que el TextField muestre el nuevo valor.
        _ctrlCantidad(_items[idx]).text = '${_items[idx].cantidad}';
      } else {
        _items.add(LoteItem(producto: prod));
      }
      _sugerencias     = [];
      _searchCtrl.clear();
    });

    // Scroll al final de la lista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Escáner ───────────────────────────────────────────────

  Future<void> _onBarcode(String codigo) async {
    if (!mounted) return;
    setState(() => _scanActivo = true);
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 1500),
        () { if (mounted) setState(() => _scanActivo = false); });

    setState(() => _buscando = true);
    final res = await context.read<ProveedoresProvider>().buscarProductos(q: codigo);
    if (!mounted) return;
    setState(() => _buscando = false);

    if (res.isNotEmpty) {
      _agregarProducto(res.first);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Código "$codigo" no encontrado'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10))),
        ));
      }
    }
  }

  // ── Imprimir ──────────────────────────────────────────────

  Future<void> _imprimir() async {
    if (_items.isEmpty) return;
    final nombre  = 'Lote etiquetas — $_totalEtiquetas etiqueta(s)';
    final formato = _modoHoja
        ? (_papelHoja == 'letter' ? PdfPageFormat.letter : PdfPageFormat.a4)
        : PdfPageFormat(
            _plantillaActual.anchoMm * PdfPageFormat.mm,
            _plantillaActual.altoMm  * PdfPageFormat.mm,
            marginAll: 0,
          );

    setState(() => _imprimiendo = true);
    try {
      await Printing.layoutPdf(
        name:     nombre,
        format:   formato,
        onLayout: (_) => _modoHoja
            ? widget.etiquetaService.generarPdfHoja(
                _plantillaActual, _items, papel: _papelHoja)
            : widget.etiquetaService.generarPdfLote(_plantillaActual, _items),
      );
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 640,
        height: 600,
        child: Column(children: [
          _buildHeader(),
          _buildPlantillaBar(),
          Expanded(
            child: Row(children: [
              SizedBox(width: 280, child: _buildPanelBusqueda()),
              const VerticalDivider(width: 1, color: _kBorder),
              Expanded(child: _buildPanelLista()),
            ]),
          ),
          _buildFooter(),
        ]),
      ),
    );
  }

  // ── Barra de selección de plantilla ──────────────────────────

  Widget _buildPlantillaBar() {
    final dimLabel =
        '${_plantillaActual.anchoMm.toStringAsFixed(0)}×'
        '${_plantillaActual.altoMm.toStringAsFixed(0)} mm';

    final (cols, rows) = widget.etiquetaService.calcGrid(
        _plantillaActual, papel: _papelHoja);
    final porHoja = cols * rows;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 9),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFF),
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Fila 1: plantilla + modo
        Row(children: [
          const Icon(Icons.label_rounded, size: 14, color: _kMuted),
          const SizedBox(width: 8),
          Text('Plantilla:',
              style: AppTextStyles.bodySm.copyWith(
                  color: _kMuted, fontSize: 11)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedPlantillaId,
                isDense: true,
                style: AppTextStyles.bodySm.copyWith(
                    fontSize: 12, color: const Color(0xFF111827)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: _kMuted),
                borderRadius: BorderRadius.circular(10),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Predeterminada (editor)',
                        style: AppTextStyles.bodySm.copyWith(fontSize: 12)),
                  ),
                  ..._plantillasGuardadas.map((pg) => DropdownMenuItem<String?>(
                        value: pg.id,
                        child: Text(pg.nombre,
                            style: AppTextStyles.bodySm.copyWith(fontSize: 12)),
                      )),
                ],
                onChanged: (id) {
                  setState(() {
                    _selectedPlantillaId = id;
                    _plantillaActual = id == null
                        ? widget.plantilla
                        : _plantillasGuardadas.firstWhere((p) => p.id == id).plantilla;
                  });
                },
              ),
            ),
          ),
          // Chip dimensión
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(dimLabel,
                style: AppTextStyles.labelSm.copyWith(
                    color: _kMuted, fontSize: 10)),
          ),
          const SizedBox(width: 10),
          // Toggle modo
          _buildModoToggle(),
        ]),

        // Fila 2: selector de papel (solo modo hoja)
        if (_modoHoja) ...[
          const SizedBox(height: 7),
          Row(children: [
            const Icon(Icons.article_outlined, size: 13, color: _kMuted),
            const SizedBox(width: 6),
            Text('Papel:',
                style: AppTextStyles.bodySm.copyWith(
                    color: _kMuted, fontSize: 11)),
            const SizedBox(width: 8),
            _papelChip('a4',     'A4'),
            const SizedBox(width: 6),
            _papelChip('letter', 'Carta'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kPurpleLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kPurple.withOpacity(0.25)),
              ),
              child: Text(
                'Caben $cols×$rows = $porHoja por hoja',
                style: AppTextStyles.labelSm.copyWith(
                    color: _kPurple, fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildModoToggle() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _modoBtn(
        label: 'Rollo',
        icon: Icons.receipt_long_rounded,
        active: !_modoHoja,
        onTap: () => setState(() => _modoHoja = false),
        isLeft: true,
      ),
      _modoBtn(
        label: 'Hoja',
        icon: Icons.picture_as_pdf_rounded,
        active: _modoHoja,
        onTap: () => setState(() => _modoHoja = true),
        isLeft: false,
      ),
    ]);
  }

  Widget _modoBtn({
    required String   label,
    required IconData icon,
    required bool     active,
    required VoidCallback onTap,
    required bool     isLeft,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color:  active ? _kPurple : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.horizontal(
            left:  Radius.circular(isLeft ? 7 : 0),
            right: Radius.circular(isLeft ? 0 : 7),
          ),
          border: Border.all(
            color: active ? _kPurple : _kBorder,
            width: active ? 1.0 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: active ? Colors.white : _kMuted),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelSm.copyWith(
                  fontSize: 11,
                  color:        active ? Colors.white : _kMuted,
                  fontWeight:   active ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _papelChip(String value, String label) {
    final active = _papelHoja == value;
    return GestureDetector(
      onTap: () => setState(() => _papelHoja = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:  active ? _kPurpleLight : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? _kPurple : _kBorder,
              width: active ? 1.2 : 0.8),
        ),
        child: Text(label,
            style: AppTextStyles.labelSm.copyWith(
                fontSize: 11,
                color:      active ? _kPurple : _kMuted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _kPurpleLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.print_rounded, size: 18, color: _kPurple),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Impresión en lote',
              style: AppTextStyles.headlineSm.copyWith(fontSize: 15)),
          Text('Agrega productos y define la cantidad por cada uno',
              style: AppTextStyles.bodySm.copyWith(
                  color: _kMuted, fontSize: 11)),
        ]),
        const Spacer(),
        // Indicador escáner
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _scanActivo ? _kGreenLight : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _scanActivo ? _kGreen : _kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _buscando
                ? const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: _kGreen))
                : Icon(Icons.qr_code_scanner_rounded,
                    size: 14, color: _scanActivo ? _kGreen : _kMuted),
            if (_scanActivo && !_buscando) ...[
              const SizedBox(width: 5),
              Text('Escaneado',
                  style: AppTextStyles.labelSm.copyWith(
                      color: _kGreen, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 20, color: _kMuted),
        ),
      ]),
    );
  }

  // ── Panel izquierdo: búsqueda ─────────────────────────────

  Widget _buildPanelBusqueda() {
    return Container(
      color: const Color(0xFFFAFAFF),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Agregar producto',
            style: AppTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 8),
        // Campo de búsqueda
        TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: AppTextStyles.bodyMd.copyWith(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar o escanear...',
            hintStyle: AppTextStyles.bodySm.copyWith(color: _kMuted),
            prefixIcon: _buscando
                ? const Padding(padding: EdgeInsets.all(12),
                    child: SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kPurple)))
                : const Icon(Icons.search_rounded, size: 18, color: _kMuted),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    color: _kMuted,
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _sugerencias = []);
                    })
                : null,
            filled: true,
            fillColor: Colors.white,
            isDense: true,
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
        const SizedBox(height: 8),
        // Sugerencias
        if (_sugerencias.isNotEmpty)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: _sugerencias.take(8).map((p) => InkWell(
                  onTap: () => _agregarProducto(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kPurpleLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('+ Agregar',
                            style: AppTextStyles.labelSm.copyWith(
                                color: _kPurple,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                )).toList(),
              ),
            ),
          )
        else ...[
          const Spacer(),
          // Hint cuando la lista está vacía
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.qr_code_scanner_rounded,
                  size: 40, color: _kMuted.withOpacity(0.3)),
              const SizedBox(height: 10),
              Text('Busca por nombre o\nescanea el código de barras',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(
                      color: _kMuted.withOpacity(0.6), fontSize: 12)),
            ]),
          ),
          const Spacer(),
        ],
      ]),
    );
  }

  // ── Panel derecho: lista ──────────────────────────────────

  Widget _buildPanelLista() {
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.label_off_rounded,
              size: 48, color: _kMuted.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text('No hay productos en el lote',
              style: AppTextStyles.bodyMd.copyWith(color: _kMuted)),
          const SizedBox(height: 4),
          Text('Agrega productos desde el panel izquierdo',
              style: AppTextStyles.bodySm.copyWith(
                  color: _kMuted.withOpacity(0.7), fontSize: 12)),
        ]),
      );
    }

    return Column(children: [
      // Cabecera de la tabla
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(children: [
          Expanded(child: Text('Producto',
              style: AppTextStyles.labelSm.copyWith(color: _kMuted))),
          SizedBox(width: 120, child: Center(
              child: Text('Cantidad',
                  style: AppTextStyles.labelSm.copyWith(color: _kMuted)))),
          const SizedBox(width: 36),
        ]),
      ),
      // Lista
      Expanded(
        child: ListView.separated(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _items.length,
          separatorBuilder: (context, i) =>
              const Divider(height: 1, color: _kBorder, indent: 16, endIndent: 16),
          itemBuilder: (context, i) => _buildItemRow(i),
        ),
      ),
    ]);
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    final prod = item.producto;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        // Icono
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kPurpleLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_rounded,
              size: 14, color: _kPurple),
        ),
        const SizedBox(width: 10),
        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prod['nombre'] as String? ?? '',
                style: AppTextStyles.bodyMd.copyWith(
                    fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            Text(prod['codigo_barras'] as String? ?? 'Sin código',
                style: AppTextStyles.bodySm.copyWith(
                    fontSize: 10, color: _kMuted)),
          ],
        )),
        const SizedBox(width: 8),
        // Cantidad
        SizedBox(
          width: 120,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _miniBtnCantidad(
              icon: Icons.remove_rounded,
              onPressed: item.cantidad > 1
                  ? () => setState(() {
                      item.cantidad--;
                      _ctrlCantidad(item).text = '${item.cantidad}';
                    })
                  : null,
            ),
            SizedBox(
              width: 44,
              child: TextField(
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: _ctrlCantidad(item),
                style: AppTextStyles.bodyMd.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n > 0) setState(() => item.cantidad = n);
                },
              ),
            ),
            _miniBtnCantidad(
              icon: Icons.add_rounded,
              onPressed: item.cantidad < 999
                  ? () => setState(() {
                      item.cantidad++;
                      _ctrlCantidad(item).text = '${item.cantidad}';
                    })
                  : null,
            ),
          ]),
        ),
        // Eliminar
        IconButton(
          onPressed: () => setState(() {
            _removeCtrl(item);
            _items.removeAt(index);
          }),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: _kRed.withOpacity(0.7),
          tooltip: 'Quitar del lote',
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }

  Widget _miniBtnCantidad({required IconData icon, VoidCallback? onPressed}) =>
      SizedBox(
        width: 26, height: 26,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 14),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF3F4F6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
        ),
      );

  // ── Footer ────────────────────────────────────────────────

  Widget _buildFooter() {
    final total = _totalEtiquetas;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: resumen del lote — sólo cuando hay productos
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.label_rounded, size: 14, color: _kMuted),
                    const SizedBox(width: 6),
                    Text(
                      '${_items.length} producto${_items.length != 1 ? 's' : ''}',
                      style: AppTextStyles.bodySm.copyWith(color: _kMuted),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 14, color: _kBorder),
                    const SizedBox(width: 8),
                    Text(
                      '$total etiqueta${total != 1 ? 's' : ''}',
                      style: AppTextStyles.bodySm.copyWith(
                          color: _kText, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() {
                    for (final c in _cantidadCtrls.values) { c.dispose(); }
                    _cantidadCtrls.clear();
                    _items.clear();
                  }),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Limpiar todo'),
                  style: TextButton.styleFrom(
                    foregroundColor: _kRed,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
              ]),
            ),

          // Fila 2: botones de acción (siempre visibles)
          Row(children: [
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _items.isEmpty || _imprimiendo ? null : _imprimir,
              icon: _imprimiendo
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print_rounded, size: 16),
              label: Text(
                _imprimiendo
                    ? 'Generando PDF...'
                    : 'Imprimir $total etiqueta${total != 1 ? 's' : ''}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kBorder,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 11),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
