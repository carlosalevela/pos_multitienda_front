// lib/screens/etiquetas/etiquetas_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../providers/proveedores_provider.dart';
import '../../services/barcode_service.dart';
import '../../services/etiqueta_service.dart';
import '../../services/raw_label_printer.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'lote_dialog.dart';

const _kBg          = Color(0xFFF0F2F5);
const _kSurface     = Color(0xFFFFFFFF);
const _kBorder      = Color(0xFFE5E7EB);
const _kText        = Color(0xFF111827);
const _kMuted       = Color(0xFF6B7280);
const _kGreen       = Color(0xFF10B981);
const _kGreenLight  = Color(0xFFD1FAE5);
const _kPurple      = Color(0xFF7C3AED);
const _kPurpleLight = Color(0xFFF5F3FF);
const _kRed         = Color(0xFFEF4444);

// ─── Labels de elementos ──────────────────────────────────────
const _elemLabels = {
  'nombre':         'Nombre',
  'precio':         'Precio',
  'precio_mayoreo': 'Precio mayoreo',
  'barcode':        'Código de barras',
  'tienda':         'Tienda',
  'categoria':      'Categoría',
};

class EtiquetasScreen extends StatefulWidget {
  const EtiquetasScreen({super.key});
  @override
  State<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends State<EtiquetasScreen> {
  final _etiquetaService  = EtiquetaService();
  final _searchCtrl       = TextEditingController();
  final _anchoCtrl        = TextEditingController();
  final _altoCtrl         = TextEditingController();
  final _anchoFocus       = FocusNode();
  final _altoFocus        = FocusNode();
  final _textoCustomCtrl  = TextEditingController();

  PlantillaEtiqueta           _plantilla          = PlantillaEtiqueta.defaults();
  List<PlantillaGuardada>     _plantillasGuardadas = [];
  Map<String, dynamic>?       _producto;
  List<Map<String, dynamic>>  _sugerencias        = [];
  bool                        _buscando           = false;
  bool                        _scanActivo         = false;
  String?                    _elemSel;      // key del elemento seleccionado
  bool                       _snapV          = false;
  bool                       _snapH          = false;
  Offset?                    _panStartGlobal;
  Offset?                    _panStartPosMm;
  // Resize handle
  Offset?                    _resizeStartGlobal;
  double?                    _resizeStartFs;
  double?                    _resizeStartHMm;
  double?                    _resizeStartWMm;
  Timer?                     _scanTimer;
  StreamSubscription<String>? _barcodeSub;
  String?  _nombreImpresora;
  Printer? _impresora;   // cache en memoria (no requiere lookup)

  // ── Zoom y grid del canvas ────────────────────────────────
  double _zoom     = 1.0;
  bool   _snapGrid = false;
  double _gridMm   = 1.0;  // tamaño del grid en mm

  // ── Impresora y protocolo ─────────────────────────────────

  static const _kPrefsImpresora = 'etiqueta_printer_v1';
  static const _kPrefsLang     = 'etiqueta_lang_v1';

  Future<void> _cargarImpresora() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString(_kPrefsImpresora);
    // Cargar protocolo guardado ('Driver' por defecto)
    RawLabelPrinter.printerLanguage =
        prefs.getString(_kPrefsLang) ?? 'Driver';
    if (!mounted || nombre == null) return;
    setState(() => _nombreImpresora = nombre);
    final printers = await Printing.listPrinters();
    final found = _buscarImpresora(printers, nombre);
    if (found != null && mounted) setState(() => _impresora = found);
  }

  Printer? _buscarImpresora(List<Printer> list, String nombre) {
    final n = nombre.trim().toLowerCase();
    for (final p in list) {
      if (p.name.trim().toLowerCase() == n) return p;
    }
    for (final p in list) {
      if (p.name.trim().toLowerCase().contains(n)) return p;
    }
    return null;
  }

  Future<void> _guardarImpresora(Printer p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsImpresora, p.name);
    if (mounted) setState(() { _impresora = p; _nombreImpresora = p.name; });
  }

  Future<Printer?> _getImpresora() async {
    if (_impresora != null) return _impresora;
    if (_nombreImpresora == null) return null;
    final printers = await Printing.listPrinters();
    final found = _buscarImpresora(printers, _nombreImpresora!);
    if (found != null && mounted) setState(() => _impresora = found);
    return found;
  }

  Future<void> _seleccionarImpresora(StateSetter setSt) async {
    final printers = await Printing.listPrinters();
    if (!mounted) return;
    final sel = await showDialog<Printer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar impresora'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: printers.length,
            itemBuilder: (ctx, i) {
              final p = printers[i];
              return ListTile(
                leading: const Icon(Icons.print_rounded, size: 18, color: _kMuted),
                title: Text(p.name,
                    style: AppTextStyles.bodySm.copyWith(fontSize: 13)),
                subtitle: p.isDefault
                    ? Text('Predeterminada',
                        style: AppTextStyles.labelSm.copyWith(
                            color: _kGreen, fontSize: 11))
                    : null,
                onTap: () => Navigator.pop(ctx, p),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
        ],
      ),
    );
    if (sel != null) {
      await _guardarImpresora(sel);
      setSt(() {});
    }
  }

  void _applyAnchoChange(double v) {
    if (v == _plantilla.anchoMm) return;
    final newPos = <String, ElemPos>{};
    final scaleX = (_plantilla.anchoMm > 0) ? v / _plantilla.anchoMm : 1.0;
    _plantilla.posiciones.forEach((k, pos) {
      newPos[k] = pos.copyWith(
        x:   (pos.x * scaleX).clamp(0.0, v - 1.0),
        wMm: pos.wMm != null ? (pos.wMm! * scaleX).clamp(2.0, v) : null,
      );
    });
    _upd(_plantilla.copyWith(anchoMm: v, posiciones: newPos));
  }

  void _applyAltoChange(double v) {
    if (v == _plantilla.altoMm) return;
    final newPos = <String, ElemPos>{};
    final scaleY = (_plantilla.altoMm > 0) ? v / _plantilla.altoMm : 1.0;
    _plantilla.posiciones.forEach((k, pos) {
      newPos[k] = pos.copyWith(
        y:   (pos.y * scaleY).clamp(0.0, v - 1.0),
        hMm: pos.hMm != null ? (pos.hMm! * scaleY).clamp(1.5, v) : null,
      );
    });
    _upd(_plantilla.copyWith(altoMm: v, posiciones: newPos));
  }

  @override
  void initState() {
    super.initState();
    _anchoFocus.addListener(() {
      if (!_anchoFocus.hasFocus) {
        final d = double.tryParse(_anchoCtrl.text);
        if (d != null && d >= 10) _applyAnchoChange(d);
      }
    });
    _altoFocus.addListener(() {
      if (!_altoFocus.hasFocus) {
        final d = double.tryParse(_altoCtrl.text);
        if (d != null && d >= 10) _applyAltoChange(d);
      }
    });
    _cargarPlantilla();
    _recargarPlantillasGuardadas();
    _cargarImpresora();
    _barcodeSub = BarcodeService.instance.onBarcode.listen(_onBarcode);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _anchoCtrl.dispose();
    _altoCtrl.dispose();
    _anchoFocus.dispose();
    _altoFocus.dispose();
    _textoCustomCtrl.dispose();
    _barcodeSub?.cancel();
    _scanTimer?.cancel();
    super.dispose();
  }

  // ── Selección de elemento ─────────────────────────────────
  void _setElemSel(String? key) {
    final pos = key != null ? _plantilla.posiciones[key] : null;
    setState(() {
      _elemSel = key;
      _snapV   = false;
      _snapH   = false;
      // Si el elemento tiene texto custom, mostrarlo.
      // Si no, pre-llenar con el valor formateado del producto
      // (así el usuario edita desde el valor real, no desde vacío).
      _textoCustomCtrl.text = pos?.textoCustom ?? _valorInicialCampo(key);
    });
  }

  // Valor inicial para el campo de texto cuando textoCustom es null.
  // Solo pre-llena los campos de precio (tienen formato con $).
  // Los demás quedan vacíos; el hint del campo ya muestra el valor del producto.
  String _valorInicialCampo(String? key) {
    if (key == null || _producto == null) return '';
    return switch (key) {
      'precio' when _producto!['precio_venta'] != null =>
          '\$${fmtPrecio(_producto!['precio_venta'])}',
      'precio_mayoreo' when _producto!['precio_mayoreo'] != null =>
          'Mayor: \$${fmtPrecio(_producto!['precio_mayoreo'])}',
      _ => '',
    };
  }

  // ── Estimación de dimensiones de elementos (para centrado) ──

  /// Ancho estimado del elemento en mm (basado en wMm o en texto+fuente).
  double _elemWidthMm(String key, ElemPos pos) {
    if (pos.wMm != null) return pos.wMm!;
    final aw = _plantilla.anchoMm;
    switch (key) {
      case 'barcode': return aw * 0.85;
      case 'nombre':  return aw * 0.86;
      default:
        // Estimación por texto: ancho promedio de caracter ≈ fontSize * 0.19 mm
        final txt = pos.textoCustom?.isNotEmpty == true
            ? pos.textoCustom!
            : _hintTexto(key);
        return (txt.length * pos.fontSize * 0.19).clamp(4.0, aw);
    }
  }

  /// Alto estimado del elemento en mm.
  double _elemHeightMm(String key, ElemPos pos) {
    final ah = _plantilla.altoMm;
    if (key == 'barcode') return pos.hMm ?? (ah * 0.32);
    // Texto: altura de línea ≈ fontSize(pt) * 0.3528 mm/pt * 1.2 interlineado
    return pos.fontSize * 0.3528 * 1.2;
  }

  // Devuelve el valor actual del campo del producto para un key
  String _hintTexto(String key) {
    if (_producto == null) return '';
    return switch (key) {
      'nombre'         => _producto!['nombre']            as String? ?? '',
      'precio'         => '\$${fmtPrecio(_producto!['precio_venta'])}',
      'precio_mayoreo' => 'Mayor: \$${fmtPrecio(_producto!['precio_mayoreo'])}',
      'barcode'        => (_producto!['codigo_barras']    as String?)?.trim() ?? '',
      'tienda'         => _producto!['tienda_nombre']     as String? ?? '',
      'categoria'      => _producto!['categoria_nombre']  as String? ?? '',
      _                => '',
    };
  }

  // ── Plantilla ─────────────────────────────────────────────

  Future<void> _cargarPlantilla() async {
    final p = await _etiquetaService.cargarPlantilla();
    if (!mounted) return;
    setState(() {
      _plantilla = p;
      _anchoCtrl.text = p.anchoMm.toStringAsFixed(0);
      _altoCtrl.text  = p.altoMm.toStringAsFixed(0);
    });
  }

  Future<void> _recargarPlantillasGuardadas() async {
    final lista = await _etiquetaService.listarPlantillas();
    if (mounted) setState(() => _plantillasGuardadas = lista);
  }

  void _upd(PlantillaEtiqueta nueva) {
    setState(() => _plantilla = nueva);
    _etiquetaService.guardarPlantilla(nueva);
  }

  Future<void> _guardarComoPlantilla() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Guardar como plantilla',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Nombre de la plantilla',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kPurple, width: 1.5)),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    await _etiquetaService.guardarComoPlantilla(nombre, _plantilla);
    await _recargarPlantillasGuardadas();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Plantilla "$nombre" guardada'),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
      ));
    }
  }

  // ── Búsqueda ──────────────────────────────────────────────

  Future<void> _buscar(String q) async {
    if (q.length < 2) { setState(() => _sugerencias = []); return; }
    setState(() => _buscando = true);
    final res = await context.read<ProveedoresProvider>().buscarProductos(q: q);
    if (mounted) setState(() { _sugerencias = res; _buscando = false; });
  }

  void _seleccionarProducto(Map<String, dynamic> p) {
    final tienda = context.read<AuthProvider>().tiendaNombre;
    setState(() {
      _producto    = {...p, if (tienda.isNotEmpty) 'tienda_nombre': tienda};
      _sugerencias = [];
      _searchCtrl.text = p['nombre'] as String? ?? '';
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
      _seleccionarProducto(res.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Código "$codigo" no encontrado'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
      ));
    }
  }

  // ── Lote ─────────────────────────────────────────────────

  void _abrirLote() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoteDialog(
        plantilla:       _plantilla,
        etiquetaService: _etiquetaService,
      ),
    );
  }

  // ── Producto de muestra para vista previa / impresión de plantilla ──

  Map<String, dynamic> _placeholderProducto() => {
    'nombre':           'Nombre del producto',
    'precio_venta':     '9999',
    'precio_mayoreo':   '8500',
    'codigo_barras':    '012345678901',
    'tienda_nombre':    'Tienda ejemplo',
    'categoria_nombre': 'Categoría',
  };

  // ── Dialog de impresión ───────────────────────────────────

  static const _kPrefsPgAncho = 'etiqueta_driver_pg_ancho_v1';
  static const _kPrefsPgAlto  = 'etiqueta_driver_pg_alto_v1';

  Future<(double, double)> _cargarPaginaDriver() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble(_kPrefsPgAncho) ?? 101.6;
    final h = prefs.getDouble(_kPrefsPgAlto)  ?? 101.6;
    return (w, h);
  }

  Future<void> _guardarPaginaDriver(double w, double h) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrefsPgAncho, w);
    await prefs.setDouble(_kPrefsPgAlto,  h);
  }

  Future<void> _showPrintDialog() async {
    final esMuestra = _producto == null;
    int    cantidad  = 1;
    bool   modoHoja  = false;
    String papelHoja = 'a4';
    final (pgAncho0, pgAlto0) = await _cargarPaginaDriver();
    final dlgPrefs = await SharedPreferences.getInstance();
    double pgAncho = pgAncho0;
    double pgAlto  = pgAlto0;
    // Default inteligente: si no hay guardado, calcula cuántas cols caben basado en pgAncho guardado
    int    numCols        = dlgPrefs.getInt('etiqueta_driver_cols_v1')
        ?? (pgAncho0 / _plantilla.anchoMm).round().clamp(1, 4);
    bool   negritaForzada = dlgPrefs.getBool('etiqueta_negrita_v1') ?? true;
    String protocolo = RawLabelPrinter.printerLanguage;
    final pgAnchoCtrl = TextEditingController(
        text: pgAncho.toStringAsFixed(1));
    final pgAltoCtrl  = TextEditingController(
        text: pgAlto.toStringAsFixed(1));

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final (cols, rows) = _etiquetaService.calcGrid(
              _plantilla, papel: papelHoja);
          final porHoja = cols * rows;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPurpleLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.print_rounded, size: 18, color: _kPurple),
              ),
              const SizedBox(width: 10),
              const Text('Confirmar impresión',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            content: SizedBox(
              width: 320,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Banner cuando no hay producto real
                if (esMuestra) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                          'Sin producto seleccionado — se imprimirá con datos de ejemplo',
                          style: AppTextStyles.bodySm.copyWith(
                              fontSize: 11, color: const Color(0xFF92400E)))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Info del producto real
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kPurpleLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kPurple.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_rounded, size: 16, color: _kPurple),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_producto!['nombre'] as String? ?? '',
                              style: AppTextStyles.bodyMd.copyWith(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(_producto!['codigo_barras'] as String? ?? 'Sin código',
                              style: AppTextStyles.bodySm.copyWith(
                                  color: _kMuted, fontSize: 11)),
                        ],
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // Toggle modo impresión
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(child: _modoSegBtn(
                      label: 'Rollo térmico',
                      icon: Icons.receipt_long_rounded,
                      active: !modoHoja,
                      onTap: () => setSt(() => modoHoja = false),
                    )),
                    const SizedBox(width: 3),
                    Expanded(child: _modoSegBtn(
                      label: 'Hoja (A4/Carta)',
                      icon: Icons.picture_as_pdf_rounded,
                      active: modoHoja,
                      onTap: () => setSt(() => modoHoja = true),
                    )),
                  ]),
                ),

                // ── Columnas del rollo (Driver mode) ──────────
                if (!modoHoja && protocolo == 'Driver') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Columnas de etiquetas en el rollo',
                            style: AppTextStyles.labelSm.copyWith(
                                color: _kMuted, fontSize: 11)),
                        const SizedBox(height: 8),
                        Row(children: [
                          for (final n in [1, 2, 3, 4])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () {
                                  setSt(() => numCols = n);
                                  dlgPrefs.setInt('etiqueta_driver_cols_v1', n);
                                },
                                child: Container(
                                  width: 36, height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: numCols == n ? _kPurpleLight : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: numCols == n ? _kPurple : _kBorder,
                                      width: numCols == n ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text('$n', style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: numCols == n ? _kPurple : _kMuted)),
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            'Página: ${(numCols * _plantilla.anchoMm).toStringAsFixed(0)}×${_plantilla.altoMm.toStringAsFixed(0)} mm',
                            style: AppTextStyles.labelSm.copyWith(
                                color: _kPurple, fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          '$numCols etiqueta${numCols != 1 ? 's' : ''} por fila  ·  '
                          'Ancho total: ${(numCols * _plantilla.anchoMm).toStringAsFixed(0)} mm',
                          style: AppTextStyles.labelSm.copyWith(
                              color: _kMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Toggle negrita forzada (mejora intensidad en impresoras térmicas)
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      setSt(() => negritaForzada = !negritaForzada);
                      dlgPrefs.setBool('etiqueta_negrita_v1', negritaForzada);
                    },
                    child: Row(children: [
                      SizedBox(
                        width: 34, height: 20,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Switch(
                            value: negritaForzada,
                            onChanged: (v) {
                              setSt(() => negritaForzada = v);
                              dlgPrefs.setBool('etiqueta_negrita_v1', v);
                            },
                            activeColor: _kPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Texto en negrita (mayor intensidad térmica)',
                        style: AppTextStyles.labelSm.copyWith(fontSize: 11),
                      )),
                    ]),
                  ),
                  // Aviso: dimensiones del sticker
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        'Sticker configurado: ${_plantilla.anchoMm.toStringAsFixed(0)}×'
                        '${_plantilla.altoMm.toStringAsFixed(0)} mm  —  '
                        'Debe coincidir con el sticker físico. '
                        'Ajusta en el panel izquierdo si es distinto.',
                        style: AppTextStyles.bodySm.copyWith(
                            fontSize: 10, color: const Color(0xFF92400E)),
                      )),
                    ]),
                  ),
                ],
                // ── Tamaño de página (RAW mode: ZPL / TSPL) ───
                if (!modoHoja && protocolo != 'Driver') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Página configurada en el driver',
                            style: AppTextStyles.labelSm.copyWith(
                                color: _kMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        Row(children: [
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: pgAnchoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6)),
                                suffixText: 'mm',
                              ),
                              style: const TextStyle(fontSize: 13),
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null && val > 0) {
                                  setSt(() => pgAncho = val);
                                  _guardarPaginaDriver(pgAncho, pgAlto);
                                }
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('×', style: TextStyle(fontSize: 16)),
                          ),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: pgAltoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6)),
                                suffixText: 'mm',
                              ),
                              style: const TextStyle(fontSize: 13),
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null && val > 0) {
                                  setSt(() => pgAlto = val);
                                  _guardarPaginaDriver(pgAncho, pgAlto);
                                }
                              },
                            ),
                          ),
                          const Spacer(),
                          Builder(builder: (_) {
                            final cols = (pgAncho / _plantilla.anchoMm).floor().clamp(1, 30);
                            final rows = (pgAlto  / _plantilla.altoMm ).floor().clamp(1, 30);
                            return Text(
                              '$cols×$rows = ${cols * rows} por página',
                              style: AppTextStyles.labelSm.copyWith(
                                  color: _kPurple, fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            );
                          }),
                        ]),
                      ],
                    ),
                  ),
                ],

                // Toggle protocolo (solo rollo en Windows)
                if (!modoHoja && Platform.isWindows) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Protocolo:',
                        style: TextStyle(fontSize: 12, color: _kMuted)),
                    const SizedBox(width: 8),
                    _langBtn(label: 'Driver',  active: protocolo == 'Driver',
                        onTap: () async {
                          setSt(() => protocolo = 'Driver');
                          RawLabelPrinter.printerLanguage = 'Driver';
                          final p = await SharedPreferences.getInstance();
                          await p.setString(_kPrefsLang, 'Driver');
                        }),
                    const SizedBox(width: 6),
                    _langBtn(label: 'ZPL',  active: protocolo == 'ZPL',
                        onTap: () async {
                          setSt(() => protocolo = 'ZPL');
                          RawLabelPrinter.printerLanguage = 'ZPL';
                          final p = await SharedPreferences.getInstance();
                          await p.setString(_kPrefsLang, 'ZPL');
                        }),
                    const SizedBox(width: 6),
                    _langBtn(label: 'TSPL', active: protocolo == 'TSPL',
                        onTap: () async {
                          setSt(() => protocolo = 'TSPL');
                          RawLabelPrinter.printerLanguage = 'TSPL';
                          final p = await SharedPreferences.getInstance();
                          await p.setString(_kPrefsLang, 'TSPL');
                        }),
                  ]),
                ],

                // Selector de papel (solo modo hoja)
                if (modoHoja) ...[
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _papelSegBtn(value: 'a4',     label: 'A4',    current: papelHoja,
                        onTap: () => setSt(() => papelHoja = 'a4')),
                    const SizedBox(width: 6),
                    _papelSegBtn(value: 'letter', label: 'Carta', current: papelHoja,
                        onTap: () => setSt(() => papelHoja = 'letter')),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kPurpleLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kPurple.withOpacity(0.25)),
                      ),
                      child: Text('Caben $cols×$rows = $porHoja',
                          style: AppTextStyles.labelSm.copyWith(
                              color: _kPurple, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ],

                // Fila impresora
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.print_rounded, size: 15, color: _kMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      _nombreImpresora ?? 'Sin impresora (usará diálogo del sistema)',
                      style: AppTextStyles.bodySm.copyWith(
                        fontSize: 12,
                        color: _nombreImpresora != null ? _kText : _kMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _seleccionarImpresora(setSt),
                      child: Text(
                        _nombreImpresora != null ? 'Cambiar' : 'Seleccionar',
                        style: AppTextStyles.labelSm.copyWith(
                            color: _kPurple, fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),
                Text('¿Cuántas etiquetas deseas imprimir?',
                    style: AppTextStyles.bodySm.copyWith(color: _kMuted)),
                const SizedBox(height: 14),
                // Selector de cantidad
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                    color: const Color(0xFFF9FAFB),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _qtyBtn(Icons.remove_rounded,
                        cantidad > 1 ? () => setSt(() => cantidad--) : null),
                    SizedBox(
                      width: 72,
                      child: Center(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          controller: TextEditingController(text: '$cantidad')
                            ..selection = TextSelection.collapsed(offset: '$cantidad'.length),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: AppTextStyles.headlineSm.copyWith(fontSize: 22),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) setSt(() => cantidad = n);
                          },
                        ),
                      ),
                    ),
                    _qtyBtn(Icons.add_rounded,
                        cantidad < 999 ? () => setSt(() => cantidad++) : null),
                  ]),
                ),
                const SizedBox(height: 4),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _imprimir(cantidad, modoHoja: modoHoja, papelHoja: papelHoja,
                      pgAncho: protocolo == 'Driver'
                          ? numCols * _plantilla.anchoMm
                          : pgAncho,
                      pgAlto: pgAlto,
                      negritaForzada: protocolo == 'Driver' ? negritaForzada : false);
                },
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text('Imprimir $cantidad etiqueta${cantidad != 1 ? 's' : ''}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _modoSegBtn({
    required String   label,
    required IconData icon,
    required bool     active,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13,
                color: active ? _kPurple : _kMuted),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.bodySm.copyWith(
                    fontSize: 11,
                    color:      active ? _kPurple : _kMuted,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      );

  Widget _papelSegBtn({
    required String value,
    required String label,
    required String current,
    required VoidCallback onTap,
  }) {
    final active = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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

  Widget _zoomBtn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: _kBorder),
        ),
        child: Icon(icon, size: 14, color: _kMuted),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: btn);
    return btn;
  }

  void _showGridMenu() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tamaño del grid', style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 1.0, 2.0, 5.0].map((v) => RadioListTile<double>(
            title: Text('$v mm'),
            value: v,
            groupValue: _gridMm,
            onChanged: (val) {
              if (val != null) setState(() => _gridMm = val);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _langBtn({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active ? _kPurpleLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: active ? _kPurple : _kBorder,
                width: active ? 1.2 : 0.8),
          ),
          child: Text(label,
              style: AppTextStyles.labelSm.copyWith(
                  fontSize: 12,
                  color:      active ? _kPurple : _kMuted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ),
      );

  Widget _qtyBtn(IconData icon, VoidCallback? onPressed) => SizedBox(
    width: 36, height: 36,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: _kBorder),
        padding: EdgeInsets.zero,
      ),
    ),
  );

  Future<void> _imprimir(
    int cantidad, {
    bool   modoHoja       = false,
    String papelHoja      = 'a4',
    double pgAncho        = 101.6,   // mm — tamaño de página configurado en el driver
    double pgAlto         = 101.6,
    bool   negritaForzada = false,
  }) async {
    final producto = _producto ?? _placeholderProducto();
    final nombre   = 'Etiqueta — ${producto['nombre'] ?? ''}';

    // Modo rollo en Windows: TSPL directo, bypasa Windows GDI por completo.
    // El tamaño lo controla el comando SIZE en TSPL, no el driver.
    if (!modoHoja && Platform.isWindows && _nombreImpresora != null) {
      final lang = RawLabelPrinter.printerLanguage;

      // ── Modo Driver: configura el DEVMODE del driver y usa PDF normal ──
      if (lang == 'Driver') {
        try {
          // Ancho = ancho total del rollo (pgAncho, ej. 101.6mm para 3-across).
          // Alto  = alto de UNA etiqueta (altoMm), no el alto total del rollo.
          // Así el driver avanza exactamente 1 fila por página.
          RawLabelPrinter.setDriverPaperSize(
              _nombreImpresora!, pgAncho, _plantilla.altoMm);
        } catch (e) {
          debugPrint('setDriverPaperSize falló: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Aviso: no se pudo configurar el tamaño en el driver ($e). '
                  'Intenta imprimir de todos modos.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ));
          }
        }
        // Cae al flujo PDF normal debajo con pgAncho=rollo, pgAlto=1 fila.
      } else {
        // ── Modo RAW (ZPL / TSPL) ──
        final cmds = lang == 'ZPL'
            ? RawLabelPrinter.buildZpl(_plantilla, producto, cantidad)
            : RawLabelPrinter.buildTspl(_plantilla, producto, cantidad);
        final portName = await RawLabelPrinter.getPortName(_nombreImpresora!);
        debugPrint('══ $lang a enviar ══\n$cmds══════════════');
        debugPrint('Impresora: $_nombreImpresora  →  Puerto: ${portName ?? "(nombre)"}');
        try {
          await RawLabelPrinter.printLabel(
              _nombreImpresora!, _plantilla, producto, cantidad);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Enviado ($lang) a ${portName ?? _nombreImpresora} ($cantidad etiq.)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ));
          }
          return;
        } catch (e) {
          debugPrint('Error $lang: $e');
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Error de impresión $lang'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Impresora: $_nombreImpresora',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Error: $e', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      Text('Comandos $lang:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SelectableText(cmds,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                actions: [TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'))],
              ),
            );
          }
          return;
        }
      }
    }

    // En modo Driver: página = ancho del rollo × alto de 1 fila de etiquetas.
    // generarPdfPaginaDriver calcula cols=floor(pgAncho/anchoMm) etiquetas por fila.
    final esDriver = !modoHoja &&
        Platform.isWindows &&
        RawLabelPrinter.printerLanguage == 'Driver';
    final pdfAncho = pgAncho;                                 // ancho del rollo
    final pdfAlto  = esDriver ? _plantilla.altoMm : pgAlto;  // 1 fila en modo driver

    // Modo hoja (A4/Carta) o primera vez sin impresora → PDF con diálogo.
    final formato = modoHoja
        ? (papelHoja == 'letter' ? PdfPageFormat.letter : PdfPageFormat.a4)
        : PdfPageFormat(pdfAncho * PdfPageFormat.mm, pdfAlto * PdfPageFormat.mm,
            marginAll: 0);

    Future<Uint8List> buildPdf(PdfPageFormat _) => modoHoja
        ? _etiquetaService.generarPdfHojaSingle(
            _plantilla, producto, cantidad, papel: papelHoja)
        : _etiquetaService.generarPdfPaginaDriver(
            _plantilla, producto, cantidad,
            pgAncho: pdfAncho, pgAlto: pdfAlto,
            negritaForzada: negritaForzada);

    final printer = await _getImpresora();
    if (printer != null) {
      // En modo Driver: usePrinterSettings=true para que el paquete use el DEVMODE
      // que seteamos con SetPrinterW (no cree uno propio que puede ignorar nuestras dims).
      // En otros modos: usePrinterSettings=false + forceCustomPrintPaper=true para
      // que el formato del PDF controle el tamaño de papel.
      await Printing.directPrintPdf(
        printer: printer, onLayout: buildPdf, name: nombre, format: formato,
        usePrinterSettings: esDriver, forceCustomPrintPaper: !esDriver);
      return;
    }
    await Printing.layoutPdf(name: nombre, format: formato, onLayout: buildPdf);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: Row(children: [
          SizedBox(width: 260, child: _buildPanelIzq()),
          const VerticalDivider(width: 1, color: _kBorder),
          Expanded(child: _buildPanelDer()),
        ])),
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
        Text('Etiquetas de productos', style: AppTextStyles.headlineSm),
        const Spacer(),
        // Botón guardar plantilla
        OutlinedButton.icon(
          onPressed: _guardarComoPlantilla,
          icon: const Icon(Icons.bookmark_add_rounded, size: 16),
          label: const Text('Guardar plantilla'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kMuted,
            side: const BorderSide(color: _kBorder),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          ),
        ),
        const SizedBox(width: 8),
        // Botón lote
        OutlinedButton.icon(
          onPressed: _abrirLote,
          icon: const Icon(Icons.checklist_rounded, size: 16),
          label: const Text('Imprimir lote'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kPurple,
            side: const BorderSide(color: _kPurple),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          ),
        ),
        const SizedBox(width: 10),
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
                : Icon(Icons.qr_code_scanner_rounded, size: 14,
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

  Widget _buildPanelIzq() {
    return Container(
      color: _kSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sec('Producto'),
          const SizedBox(height: 8),
          _buildBuscador(),
          if (_producto != null) ...[
            const SizedBox(height: 8),
            _buildProductoChip(),
          ],
          const SizedBox(height: 20),

          _sec('Tamaño'),
          const SizedBox(height: 8),
          _buildTamanos(),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildMmField('Ancho', _anchoCtrl,
                _applyAnchoChange, focusNode: _anchoFocus)),
            const SizedBox(width: 8),
            Expanded(child: _buildMmField('Alto', _altoCtrl,
                _applyAltoChange, focusNode: _altoFocus)),
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _upd(_plantilla.copyWith(
                posiciones: PlantillaEtiqueta.defaultPos(
                    _plantilla.anchoMm, _plantilla.altoMm))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.refresh_rounded, size: 13, color: _kPurple),
              const SizedBox(width: 4),
              Text('Restablecer posiciones',
                  style: AppTextStyles.labelSm.copyWith(
                      color: _kPurple, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 16),

          _sec('Elementos visibles'),
          const SizedBox(height: 6),
          _toggle('Código de barras', Icons.barcode_reader,
              _plantilla.mostrarBarcode,
              (v) => _upd(_plantilla.copyWith(mostrarBarcode: v))),
          _toggle('Nombre', Icons.label_outline_rounded,
              _plantilla.mostrarNombre,
              (v) => _upd(_plantilla.copyWith(mostrarNombre: v))),
          _toggle('Precio normal', Icons.attach_money_rounded,
              _plantilla.mostrarPrecio,
              (v) => _upd(_plantilla.copyWith(mostrarPrecio: v))),
          _toggle('Precio mayoreo', Icons.local_offer_rounded,
              _plantilla.mostrarPrecioMayoreo,
              (v) => _upd(_plantilla.copyWith(mostrarPrecioMayoreo: v))),
          _toggle('Tienda', Icons.store_rounded,
              _plantilla.mostrarTienda,
              (v) => _upd(_plantilla.copyWith(mostrarTienda: v))),
          _toggle('Categoría', Icons.category_rounded,
              _plantilla.mostrarCategoria,
              (v) => _upd(_plantilla.copyWith(mostrarCategoria: v))),

          const SizedBox(height: 20),

          // ── Mis plantillas ─────────────────────────────────
          Row(children: [
            Expanded(child: _sec('Mis plantillas')),
            if (_plantillasGuardadas.isNotEmpty)
              Text('${_plantillasGuardadas.length} guardada${_plantillasGuardadas.length != 1 ? 's' : ''}',
                  style: AppTextStyles.labelSm.copyWith(
                      color: _kMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          if (_plantillasGuardadas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Ninguna guardada. Usa "Guardar plantilla" en la barra superior.',
                  style: AppTextStyles.bodySm.copyWith(
                      fontSize: 11, color: _kMuted)),
            )
          else
            ..._plantillasGuardadas.map((pg) => _buildPlantillaGuardadaRow(pg)),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGreen.withOpacity(0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.open_with_rounded, size: 14, color: _kGreen),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Arrastra los elementos directamente en la etiqueta para reposicionarlos. '
                'Tócalos para ajustar el tamaño de fuente.',
                style: AppTextStyles.bodySm.copyWith(
                    fontSize: 11, color: const Color(0xFF065F46)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Panel derecho: canvas ─────────────────────────────────

  Widget _buildPanelDer() {
    return Column(children: [
      // Barra superior
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: _kSurface,
        child: Row(children: [
          const Icon(Icons.design_services_rounded, size: 16, color: _kMuted),
          const SizedBox(width: 6),
          Text('Editor', style: AppTextStyles.bodySm.copyWith(
              color: _kMuted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          _dimChip(),
          const SizedBox(width: 10),
          // ── Zoom controls ──────────────────────────
          _zoomBtn(Icons.remove_rounded, () {
            setState(() => _zoom = (_zoom - 0.25).clamp(0.5, 4.0));
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 38,
              child: Text(
                '${(_zoom * 100).round()}%',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSm.copyWith(
                    fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          _zoomBtn(Icons.add_rounded, () {
            setState(() => _zoom = (_zoom + 0.25).clamp(0.5, 4.0));
          }),
          _zoomBtn(Icons.fit_screen_rounded, () {
            setState(() => _zoom = 1.0);
          }, tooltip: 'Ajustar'),
          const SizedBox(width: 8),
          // ── Grid toggle ────────────────────────────
          Tooltip(
            message: 'Snap a grid (${_gridMm.toStringAsFixed(1)} mm)',
            child: GestureDetector(
              onTap: () => setState(() => _snapGrid = !_snapGrid),
              onLongPress: () => _showGridMenu(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: _snapGrid ? _kPurpleLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _snapGrid ? _kPurple : _kBorder,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.grid_4x4_rounded, size: 13,
                      color: _snapGrid ? _kPurple : _kMuted),
                  const SizedBox(width: 3),
                  Text('Grid', style: AppTextStyles.labelSm.copyWith(
                      fontSize: 10,
                      color: _snapGrid ? _kPurple : _kMuted,
                      fontWeight: _snapGrid ? FontWeight.w700 : FontWeight.w500)),
                ]),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showPrintDialog,
            icon: const Icon(Icons.print_rounded, size: 16),
            label: Text('Imprimir',
                style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
          ),
        ]),
      ),
      const Divider(height: 1, color: _kBorder),

      // Barra de propiedades (visible sólo cuando hay elemento seleccionado)
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: _elemSel != null
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                _buildPropBar(),
                const Divider(height: 1, color: _kBorder),
              ])
            : const SizedBox(width: double.infinity),
      ),

      // Canvas
      Expanded(
        child: _buildCanvas(),
      ),
    ]);
  }

  Widget _dimChip() => Container(
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
  );

  Widget _buildPropBar() {
    final key = _elemSel;
    if (key == null) return const SizedBox(width: double.infinity);
    final pos   = _plantilla.posiciones[key];
    if (pos == null) return const SizedBox(width: double.infinity);
    final label = _elemLabels[key] ?? key;
    final isBar = key == 'barcode';
    final hint  = _hintTexto(key);

    return Container(
      color: const Color(0xFFFAFAFF),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: chip del elemento + controles de fuente + botón cerrar
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kGreenLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kGreen.withOpacity(0.4)),
              ),
              child: Text(label,
                  style: AppTextStyles.labelSm.copyWith(
                      color: const Color(0xFF065F46), fontWeight: FontWeight.w700)),
            ),
            if (!isBar) ...[
              const SizedBox(width: 14),
              Text('Fuente:', style: AppTextStyles.bodySm.copyWith(
                  color: _kMuted, fontSize: 11)),
              const SizedBox(width: 6),
              _propBtn(Icons.remove_rounded,
                  pos.fontSize > 5
                      ? () => _upd(_plantilla.conPosicion(
                            key, pos.copyWith(fontSize: pos.fontSize - 1)))
                      : null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${pos.fontSize.toStringAsFixed(0)} pt',
                    style: AppTextStyles.labelSm.copyWith(
                        color: _kPurple, fontWeight: FontWeight.w700)),
              ),
              _propBtn(Icons.add_rounded,
                  pos.fontSize < 72
                      ? () => _upd(_plantilla.conPosicion(
                            key, pos.copyWith(fontSize: pos.fontSize + 1)))
                      : null),
              const SizedBox(width: 8),
              _boldToggle(key, pos),
            ],
            const Spacer(),
            // ── Botones de alineación ──────────────────────
            Container(
              height: 28,
              width: 1,
              color: _kBorder,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            _alignBtn(
              Icons.align_horizontal_center_rounded,
              'Centrar horizontalmente',
              () {
                final cx = ((_plantilla.anchoMm - _elemWidthMm(key, pos)) / 2)
                    .clamp(0.0, _plantilla.anchoMm - 2.0);
                _upd(_plantilla.conPosicion(key, pos.copyWith(x: cx)));
              },
            ),
            _alignBtn(
              Icons.align_vertical_center_rounded,
              'Centrar verticalmente',
              () {
                final cy = ((_plantilla.altoMm - _elemHeightMm(key, pos)) / 2)
                    .clamp(0.0, _plantilla.altoMm - 2.0);
                _upd(_plantilla.conPosicion(key, pos.copyWith(y: cy)));
              },
            ),
            _alignBtn(
              Icons.align_horizontal_left_rounded,
              'Alinear al margen izquierdo (3 mm)',
              () => _upd(_plantilla.conPosicion(
                  key, pos.copyWith(x: 3.0))),
            ),
            _alignBtn(
              Icons.align_vertical_top_rounded,
              'Alinear al margen superior (3 mm)',
              () => _upd(_plantilla.conPosicion(
                  key, pos.copyWith(y: 3.0))),
            ),
            const SizedBox(width: 6),
            // Inputs numéricos de posición
            _EtqMmField(
              label: 'X',
              value: pos.x,
              min: 0, max: _plantilla.anchoMm,
              onChanged: (v) => _upd(_plantilla.conPosicion(
                  key, pos.copyWith(x: v.clamp(0, _plantilla.anchoMm - 1)))),
            ),
            const SizedBox(width: 4),
            _EtqMmField(
              label: 'Y',
              value: pos.y,
              min: 0, max: _plantilla.altoMm,
              onChanged: (v) => _upd(_plantilla.conPosicion(
                  key, pos.copyWith(y: v.clamp(0, _plantilla.altoMm - 1)))),
            ),
            // W/H solo para barcode
            if (isBar) ...[
              const SizedBox(width: 4),
              _EtqMmField(
                label: 'W',
                value: pos.wMm ?? _plantilla.anchoMm * 0.85,
                min: 4, max: _plantilla.anchoMm,
                onChanged: (v) => _upd(_plantilla.conPosicion(
                    key, pos.copyWith(wMm: v))),
              ),
              const SizedBox(width: 4),
              _EtqMmField(
                label: 'H',
                value: pos.hMm ?? _plantilla.altoMm * 0.32,
                min: 2, max: _plantilla.altoMm,
                onChanged: (v) => _upd(_plantilla.conPosicion(
                    key, pos.copyWith(hMm: v))),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _setElemSel(null),
              icon: const Icon(Icons.close_rounded, size: 16, color: _kMuted),
            ),
          ]),

          // Fila 2 (solo barcode): selector de tipo
          if (isBar) ...[
            const SizedBox(height: 8),
            _buildBarcodeTypeSelector(),
          ],

          // Fila 3: edición de texto del elemento
          const SizedBox(height: 6),
          TextField(
            controller: _textoCustomCtrl,
            style: AppTextStyles.bodySm.copyWith(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint.isEmpty ? '(usa el valor del producto)' : hint,
              hintStyle: AppTextStyles.bodySm.copyWith(
                  color: _kMuted.withOpacity(0.55), fontSize: 12),
              labelText: 'Texto en etiqueta',
              labelStyle: AppTextStyles.labelSm.copyWith(
                  color: _kMuted, fontSize: 11),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: _textoCustomCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 14),
                      color: _kMuted,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _textoCustomCtrl.clear();
                        _upd(_plantilla.conPosicion(
                            key, pos.copyWith(textoCustom: null)));
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kGreen, width: 1.5)),
            ),
            onChanged: (v) {
              _upd(_plantilla.conPosicion(
                  key, pos.copyWith(textoCustom: v.trim().isEmpty ? null : v)));
            },
          ),
        ],
      ),
    );
  }

  static const _barcodeTypes = [
    ('code128', 'Code 128'),
    ('ean13',   'EAN-13'),
    ('ean8',    'EAN-8'),
    ('qrcode',  'QR Code'),
    ('code39',  'Code 39'),
  ];

  Widget _buildBarcodeTypeSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: _barcodeTypes.map((t) {
        final (type, label) = t;
        final sel = _plantilla.barcodeType == type;
        return GestureDetector(
          onTap: () => _upd(_plantilla.copyWith(barcodeType: type)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? _kGreenLight : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: sel ? _kGreen : _kBorder,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(label,
                style: AppTextStyles.labelSm.copyWith(
                    fontSize: 11,
                    color: sel ? const Color(0xFF065F46) : _kMuted,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  Widget _propBtn(IconData icon, VoidCallback? onPressed) => SizedBox(
    width: 28, height: 28,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFF3F4F6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
  );

  Widget _boldToggle(String key, ElemPos pos) {
    final isBold = pos.boldParaKey(key);
    return Tooltip(
      message: isBold ? 'Quitar negrilla' : 'Poner negrilla',
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: () => _upd(_plantilla.conPosicion(key, pos.copyWith(bold: !isBold))),
        child: Container(
          width: 28, height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:        isBold ? _kPurpleLight : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border:       Border.all(color: isBold ? _kPurple : _kBorder),
          ),
          child: Text('B',
              style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.bold,
                  color:      isBold ? _kPurple : _kMuted)),
        ),
      ),
    );
  }

  Widget _alignBtn(IconData icon, String tooltip, VoidCallback onPressed) =>
      Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: SizedBox(
          width: 28, height: 28,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            padding: EdgeInsets.zero,
            color: _kMuted,
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      );

  // ── Canvas ────────────────────────────────────────────────

  Widget _buildCanvas() {
    return LayoutBuilder(builder: (context, constraints) {
      final availW = constraints.maxWidth  - 80;
      final availH = constraints.maxHeight - 80;
      if (availW <= 0 || availH <= 0) return const SizedBox();

      final scale  = min(availW / _plantilla.anchoMm, availH / _plantilla.altoMm) * _zoom;
      final labelW = _plantilla.anchoMm * scale;
      final labelH = _plantilla.altoMm  * scale;

      return Container(
        color: _kBg,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
          child: Center(
          child: Container(
            width: labelW,
            height: labelH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                // Tap en fondo → deseleccionar
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _setElemSel(null),
                    child: const SizedBox.expand(),
                  ),
                ),

                // ── Guías de edición ─────────────────────────
                if (_elemSel != null) ...[
                  // Márgenes (3 mm desde cada borde)
                  ..._guiasMargen(scale, labelW, labelH),
                  // Centro vertical
                  _guiaLinea(
                    left: labelW / 2, top: 0,
                    width: _snapV ? 2 : 1, height: labelH,
                    vertical: true,
                    color: _snapV ? _kGreen : const Color(0xFF93C5FD),
                  ),
                  // Centro horizontal
                  _guiaLinea(
                    left: 0, top: labelH / 2,
                    width: labelW, height: _snapH ? 2 : 1,
                    vertical: false,
                    color: _snapH ? _kGreen : const Color(0xFF93C5FD),
                  ),
                  // Badge "Centro" cuando snap activo
                  if (_snapV || _snapH)
                    Positioned(
                      left:  labelW / 2 + 4,
                      top:   labelH / 2 + 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _snapV && _snapH ? 'Centro' : (_snapV ? 'Centrado H' : 'Centrado V'),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],

                // ── Elementos ────────────────────────────────
                if (_plantilla.mostrarNombre)
                  _elemCanvas('nombre', scale, labelW, labelH),
                if (_plantilla.mostrarPrecio)
                  _elemCanvas('precio', scale, labelW, labelH),
                if (_plantilla.mostrarPrecioMayoreo)
                  _elemCanvas('precio_mayoreo', scale, labelW, labelH),
                if (_plantilla.mostrarBarcode)
                  _elemCanvas('barcode', scale, labelW, labelH),
                if (_plantilla.mostrarTienda)
                  _elemCanvas('tienda', scale, labelW, labelH),
                if (_plantilla.mostrarCategoria)
                  _elemCanvas('categoria', scale, labelW, labelH),
              ]),
            ),
          ),
          ),   // Center
          ),   // inner SingleChildScrollView (vertical)
          ),   // outer SingleChildScrollView (horizontal)
      );
    });
  }

  Widget _elemCanvas(String key, double scale, double labelW, double labelH) {
    final pos      = _plantilla.posiciones[key]!;
    final selected = _elemSel == key;
    final pxX      = (pos.x * scale).clamp(0.0, labelW - 8);
    final pxY      = (pos.y * scale).clamp(0.0, labelH - 8);
    final fontPx   = (pos.fontSize * 0.3528 * scale).clamp(4.0, 300.0);

    // Contenido visual del elemento
    Widget content = _elemContent(key, pos, fontPx, labelW, labelH, scale);

    return Positioned(
      key:  ValueKey(key),
      left: pxX,
      top:  pxY,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Elemento principal (mover) ──────────────────
          GestureDetector(
            onTap: () => _setElemSel(selected ? null : key),
            onPanStart: (d) {
              _panStartGlobal = d.globalPosition;
              _panStartPosMm  = Offset(pos.x, pos.y);
              _setElemSel(key);
            },
            onPanUpdate: (d) {
              if (_panStartGlobal == null || _panStartPosMm == null) return;
              final total = d.globalPosition - _panStartGlobal!;
              double newX = (_panStartPosMm!.dx + total.dx / scale)
                  .clamp(0.0, _plantilla.anchoMm - 2.0);
              double newY = (_panStartPosMm!.dy + total.dy / scale)
                  .clamp(0.0, _plantilla.altoMm - 2.0);

              // Snap a grid (tiene precedencia sobre el snap a márgenes/centro)
              if (_snapGrid) {
                newX = (newX / _gridMm).round() * _gridMm;
                newY = (newY / _gridMm).round() * _gridMm;
              }

              bool sv = false, sh = false;
              final cx = _plantilla.anchoMm / 2;
              final cy = _plantilla.altoMm  / 2;
              // Snap al centro usando el CENTRO del elemento (no su borde izquierdo)
              final halfW = _elemWidthMm(key, pos) / 2;
              final halfH = _elemHeightMm(key, pos) / 2;
              if (!_snapGrid) {
                if ((newX + halfW - cx).abs() < 1.5) { newX = cx - halfW; sv = true; }
                if ((newY + halfH - cy).abs() < 1.5) { newY = cy - halfH; sh = true; }
              }
              const mg = 3.0;
              if ((newX - mg).abs() < 1.5)                        newX = mg;
              if ((newY - mg).abs() < 1.5)                        newY = mg;
              if ((newX - (_plantilla.anchoMm - mg)).abs() < 1.5) newX = _plantilla.anchoMm - mg;
              if ((newY - (_plantilla.altoMm  - mg)).abs() < 1.5) newY = _plantilla.altoMm  - mg;

              setState(() {
                _plantilla = _plantilla.conPosicion(
                    key, pos.copyWith(x: newX, y: newY));
                _snapV = sv; _snapH = sh;
              });
            },
            onPanEnd: (_) {
              _panStartGlobal = null;
              _panStartPosMm  = null;
              _etiquetaService.guardarPlantilla(_plantilla);
              setState(() { _snapV = false; _snapH = false; });
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: selected
                    ? Border.all(color: _kGreen, width: 1.5)
                    : Border.all(color: Colors.transparent, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: content,
            ),
          ),

          // ── Handle de resize (esquina inferior-derecha) ─
          if (selected)
            Positioned(
              right:  -6,
              bottom: -6,
              child: GestureDetector(
                onPanStart: (d) {
                  _resizeStartGlobal = d.globalPosition;
                  _resizeStartFs     = pos.fontSize;
                  _resizeStartHMm    = pos.hMm;
                  _resizeStartWMm    = pos.wMm;
                },
                onPanUpdate: (d) => _onResize(d, key, pos, scale),
                onPanEnd:    (_) {
                  _resizeStartGlobal = null;
                  _resizeStartFs     = null;
                  _resizeStartHMm    = null;
                  _resizeStartWMm    = null;
                  _etiquetaService.guardarPlantilla(_plantilla);
                },
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color:  _kGreen,
                    shape:  BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3, offset: const Offset(0, 1),
                    )],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _elemContent(
      String key, ElemPos pos, double fontPx, double labelW, double labelH, double scale) {
    // Valores del producto (fallback cuando no hay textoCustom)
    final codigo = (_producto?['codigo_barras'] as String?)?.trim() ?? '';
    final nombre = _producto?['nombre'] as String? ?? 'Nombre del producto';
    final precio = _producto?['precio_venta'];
    final tienda = _producto?['tienda_nombre'] as String? ?? 'Tienda';
    final cat    = _producto?['categoria_nombre'] as String? ?? 'Categoría';

    switch (key) {
      case 'nombre':
        final nW = pos.wMm != null
            ? (pos.wMm! * scale).clamp(20.0, labelW)
            : labelW * 0.86;
        return SizedBox(
          width: nW,
          child: Text(
            pos.textoCustom ?? nombre,
            style: TextStyle(
              fontSize:   fontPx,
              fontWeight: pos.boldParaKey('nombre') ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
              height: 1.2,
            ),
            softWrap:  true,
            maxLines:  null,
          ),
        );

      case 'precio':
        final pW = pos.wMm != null
            ? (pos.wMm! * scale).clamp(20.0, labelW)
            : null;
        final txt = pos.textoCustom
            ?? (precio != null ? '\$${fmtPrecio(precio)}' : '\$0');
        return SizedBox(
          width: pW,
          child: Text(
            txt,
            style: TextStyle(
              fontSize:   fontPx,
              fontWeight: pos.boldParaKey('precio') ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
        );

      case 'precio_mayoreo':
        final pmW = pos.wMm != null
            ? (pos.wMm! * scale).clamp(20.0, labelW)
            : null;
        final precioMayoreo = _producto?['precio_mayoreo'];
        final txtMayor = pos.textoCustom
            ?? (precioMayoreo != null
                ? 'Mayor: \$${fmtPrecio(precioMayoreo)}'
                : 'Mayor: \$—');
        return SizedBox(
          width: pmW,
          child: Text(
            txtMayor,
            style: TextStyle(
              fontSize:   fontPx,
              fontWeight: pos.boldParaKey('precio_mayoreo')
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        );

      case 'barcode':
        final displayCodigo  = pos.textoCustom?.trim() ?? codigo;
        final barcodeType    = _plantilla.barcodeType;
        final isQr           = barcodeType == 'qrcode';
        final bw = pos.wMm != null
            ? (pos.wMm! * scale).clamp(20.0, labelW)
            : (labelW * 0.85).clamp(40.0, labelW);
        // QR necesita área cuadrada en el canvas
        final bh = isQr
            ? bw
            : (pos.hMm != null
                ? (pos.hMm! * scale).clamp(12.0, labelH * 0.8)
                : (labelH * 0.30).clamp(18.0, labelH * 0.45));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: bw,
            height: bh,
            child: CustomPaint(
              painter: _BarcodePainter(
                displayCodigo.isEmpty ? '0000000000000' : displayCodigo,
                type: barcodeType,
              ),
            ),
          ),
          if (!isQr)
            Text(
              displayCodigo.isEmpty ? '—————' : displayCodigo,
              style: TextStyle(
                fontSize: (fontPx * 0.75).clamp(6.0, 12.0),
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
        ]);

      case 'tienda':
        final tW = pos.wMm != null ? (pos.wMm! * scale).clamp(10.0, labelW) : null;
        return SizedBox(
          width: tW,
          child: Text(pos.textoCustom ?? tienda,
              style: TextStyle(
                  fontSize:   fontPx,
                  fontWeight: pos.boldParaKey('tienda') ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black54)),
        );

      case 'categoria':
        final cW = pos.wMm != null ? (pos.wMm! * scale).clamp(10.0, labelW) : null;
        return SizedBox(
          width: cW,
          child: Text(pos.textoCustom ?? cat,
              style: TextStyle(
                  fontSize:   fontPx,
                  fontWeight: pos.boldParaKey('categoria') ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black54)),
        );

      default:
        return const SizedBox();
    }
  }

  // ── Widgets del panel izquierdo ───────────────────────────

  Widget _buildBuscador() {
    return Column(children: [
      TextField(
        controller: _searchCtrl,
        style: AppTextStyles.bodyMd.copyWith(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o código...',
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
                    setState(() { _producto = null; _sugerencias = []; });
                  })
              : null,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            color: _kSurface,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  const Icon(Icons.chevron_right_rounded, size: 14, color: _kMuted),
                ]),
              ),
            )).toList(),
          ),
        ),
    ]);
  }

  Widget _buildProductoChip() {
    final p = _producto!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kPurpleLight,
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
          child: const Icon(Icons.inventory_2_rounded, size: 14, color: _kPurple),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['nombre'] as String? ?? '',
              style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 12)),
          Text(p['codigo_barras'] as String? ?? 'Sin código',
              style: AppTextStyles.bodySm.copyWith(fontSize: 10, color: _kMuted)),
        ])),
        const Icon(Icons.check_circle_rounded, size: 16, color: _kPurple),
      ]),
    );
  }

  void _cambiarTamano(double nuevoAncho, double nuevoAlto) {
    final oldAncho = _plantilla.anchoMm;
    final oldAlto  = _plantilla.altoMm;
    final scaleX  = (oldAncho > 0) ? nuevoAncho / oldAncho : 1.0;
    final scaleY  = (oldAlto  > 0) ? nuevoAlto  / oldAlto  : 1.0;
    final scaleFs = (scaleX + scaleY) / 2;
    final newPos  = <String, ElemPos>{};
    _plantilla.posiciones.forEach((k, pos) {
      newPos[k] = pos.copyWith(
        x:        (pos.x * scaleX).clamp(0.0, nuevoAncho - 1.0),
        y:        (pos.y * scaleY).clamp(0.0, nuevoAlto  - 1.0),
        fontSize: (pos.fontSize * scaleFs).clamp(5.0, 72.0),
        wMm:      pos.wMm != null ? (pos.wMm! * scaleX).clamp(2.0, nuevoAncho) : null,
        hMm:      pos.hMm != null ? (pos.hMm! * scaleY).clamp(1.5, nuevoAlto)  : null,
      );
    });
    _anchoCtrl.text = nuevoAncho.toStringAsFixed(0);
    _altoCtrl.text  = nuevoAlto.toStringAsFixed(0);
    _upd(_plantilla.copyWith(anchoMm: nuevoAncho, altoMm: nuevoAlto, posiciones: newPos));
  }

  Widget _buildTamanos() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tamanos.map((t) {
        final esPersonalizado = t.anchoMm == 0;
        final sel = esPersonalizado
            ? !tamanos.any((x) =>
                x.anchoMm != 0 &&
                x.anchoMm == _plantilla.anchoMm &&
                x.altoMm  == _plantilla.altoMm)
            : _plantilla.anchoMm == t.anchoMm && _plantilla.altoMm == t.altoMm;
        return GestureDetector(
          onTap: esPersonalizado
              ? () => _anchoFocus.requestFocus()
              : () => _cambiarTamano(t.anchoMm, t.altoMm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? _kPurpleLight : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? _kPurple : _kBorder,
                  width: sel ? 1.5 : 1),
            ),
            child: Text(t.nombre,
                style: AppTextStyles.labelSm.copyWith(
                    color:      sel ? _kPurple : _kMuted,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMmField(
      String label, TextEditingController ctrl, void Function(double) onChange,
      {FocusNode? focusNode}) {
    return TextField(
      controller:       ctrl,
      focusNode:        focusNode,
      keyboardType:     const TextInputType.numberWithOptions(decimal: true),
      inputFormatters:  [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      style: AppTextStyles.bodySm.copyWith(fontSize: 12),
      decoration: InputDecoration(
        labelText: '$label (mm)',
        labelStyle: AppTextStyles.labelSm.copyWith(color: _kMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        if (d != null && d >= 10) onChange(d);
      },
    );
  }

  Widget _toggle(String label, IconData icon, bool valor,
      void Function(bool) onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => onChange(!valor),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: Row(children: [
            Icon(icon, size: 14, color: valor ? _kPurple : _kMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(label,
                style: AppTextStyles.bodySm.copyWith(
                    fontSize: 12, color: valor ? _kText : _kMuted))),
            Switch(
              value: valor,
              onChanged: onChange,
              activeColor: _kPurple,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPlantillaGuardadaRow(PlantillaGuardada pg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          const Icon(Icons.label_outline_rounded, size: 13, color: _kMuted),
          const SizedBox(width: 6),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pg.nombre,
                  style: AppTextStyles.bodySm.copyWith(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              Text(
                '${pg.plantilla.anchoMm.toStringAsFixed(0)}×${pg.plantilla.altoMm.toStringAsFixed(0)} mm',
                style: AppTextStyles.labelSm.copyWith(
                    color: _kMuted, fontSize: 10),
              ),
            ],
          )),
          TextButton(
            onPressed: () {
              _upd(pg.plantilla);
              _anchoCtrl.text = pg.plantilla.anchoMm.toStringAsFixed(0);
              _altoCtrl.text  = pg.plantilla.altoMm.toStringAsFixed(0);
            },
            style: TextButton.styleFrom(
              foregroundColor: _kPurple,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Cargar', style: TextStyle(fontSize: 11)),
          ),
          IconButton(
            onPressed: () async {
              await _etiquetaService.eliminarPlantilla(pg.id);
              _recargarPlantillasGuardadas();
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 14),
            color: _kRed.withOpacity(0.6),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Eliminar',
          ),
        ]),
      ),
    );
  }

  Widget _sec(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(texto,
        style: AppTextStyles.bodyMd.copyWith(
            fontWeight: FontWeight.w700, fontSize: 12, color: _kText)),
  );

  // ── Resize ───────────────────────────────────────────────────

  void _onResize(DragUpdateDetails d, String key, ElemPos pos, double scale) {
    if (_resizeStartGlobal == null) return;
    final delta = d.globalPosition - _resizeStartGlobal!;

    // Horizontal → ancho del elemento
    final defaultW  = key == 'barcode'
        ? _plantilla.anchoMm * 0.85
        : _plantilla.anchoMm * 0.50;
    final startW    = _resizeStartWMm ?? defaultW;
    final newW      = (startW + delta.dx / scale)
        .clamp(5.0, _plantilla.anchoMm);

    if (key == 'barcode') {
      // Vertical → altura del barcode
      final startH = _resizeStartHMm ?? _plantilla.altoMm * 0.32;
      final newH   = (startH + delta.dy / scale)
          .clamp(3.0, _plantilla.altoMm * 0.75);
      setState(() => _plantilla = _plantilla.conPosicion(
          key, pos.copyWith(wMm: newW, hMm: newH)));
    } else {
      // Vertical → tamaño de fuente (abajo = más grande)
      final startFs = _resizeStartFs ?? pos.fontSize;
      final newFs   = (startFs + delta.dy / scale * 0.9)
          .clamp(6.0, 72.0);
      setState(() => _plantilla = _plantilla.conPosicion(
          key, pos.copyWith(wMm: newW, fontSize: newFs)));
    }
  }

  // ── Helpers de guías ─────────────────────────────────────────

  Widget _guiaLinea({
    required double left,
    required double top,
    required double width,
    required double height,
    required bool   vertical,
    required Color  color,
  }) =>
      Positioned(
        left: left, top: top,
        width: width, height: height,
        child: CustomPaint(
          painter: _GuidePainter(color: color, vertical: vertical),
        ),
      );

  List<Widget> _guiasMargen(double scale, double labelW, double labelH) {
    const mg  = 3.0;
    final mpx = mg * scale;
    const c   = Color(0xFFFBBF24);
    return [
      _guiaLinea(left: mpx,            top: 0,            width: 1,     height: labelH, vertical: true,  color: c),
      _guiaLinea(left: labelW - mpx,   top: 0,            width: 1,     height: labelH, vertical: true,  color: c),
      _guiaLinea(left: 0,              top: mpx,          width: labelW, height: 1,     vertical: false, color: c),
      _guiaLinea(left: 0,              top: labelH - mpx, width: labelW, height: 1,     vertical: false, color: c),
    ];
  }
}

// ── Campo numérico en mm para el editor de etiquetas ─────────

class _EtqMmField extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final void Function(double) onChanged;

  const _EtqMmField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
  });

  @override
  State<_EtqMmField> createState() => _EtqMmFieldState();
}

class _EtqMmFieldState extends State<_EtqMmField> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController(text: widget.value.toStringAsFixed(1));
    _focus = FocusNode()..addListener(() { if (!_focus.hasFocus) _apply(); });
  }

  @override
  void didUpdateWidget(_EtqMmField old) {
    super.didUpdateWidget(old);
    // Sincroniza cuando cambia desde fuera (drag) pero no cuando el usuario escribe
    if (!_focus.hasFocus && (old.value - widget.value).abs() > 0.05) {
      _ctrl.text = widget.value.toStringAsFixed(1);
    }
  }

  void _apply() {
    final v = double.tryParse(_ctrl.text);
    if (v != null) {
      widget.onChanged(v.clamp(widget.min, widget.max));
    } else {
      _ctrl.text = widget.value.toStringAsFixed(1); // revertir
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: TextField(
        controller:   _ctrl,
        focusNode:    _focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style:        const TextStyle(fontSize: 11),
        textAlign:    TextAlign.center,
        decoration: InputDecoration(
          labelText:  widget.label,
          labelStyle: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
          suffixText: 'mm',
          suffixStyle: const TextStyle(fontSize: 8, color: Color(0xFF6B7280)),
          isDense:    true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          border:      OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
          ),
        ),
        onSubmitted: (_) => _apply(),
      ),
    );
  }
}

// ── Painter de barcode simplificado para el canvas ────────────

class _BarcodePainter extends CustomPainter {
  final String data;
  final String type;
  const _BarcodePainter(this.data, {this.type = 'code128'});

  @override
  void paint(Canvas canvas, Size size) {
    type == 'qrcode' ? _paintQr(canvas, size) : _paintBars(canvas, size);
  }

  void _paintBars(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    double x = 0;
    int i = 0;
    while (x < size.width) {
      final ci  = i % data.length;
      final bit = (data.codeUnitAt(ci) >> (i % 8)) & 1;
      final w   = (i % 4 == 0) ? 2.5 : 1.5;
      if (bit == 1) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w;
      i++;
    }
  }

  void _paintQr(Canvas canvas, Size size) {
    final black = Paint()..color = Colors.black;
    final white = Paint()..color = Colors.white;
    const cells   = 21;
    final cell    = size.width / cells;
    final hash    = data.hashCode;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), white);

    // Módulos pseudoaleatorios basados en los datos
    for (int r = 0; r < cells; r++) {
      for (int c = 0; c < cells; c++) {
        final bit = ((hash ^ (r * 13 + c * 7)) & 1) == 1;
        if (bit) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), black);
        }
      }
    }

    // Patrones de esquina (finder patterns)
    _finder(canvas, black, white, 0,              0,              cell);
    _finder(canvas, black, white, (cells - 7) * cell, 0,              cell);
    _finder(canvas, black, white, 0,              (cells - 7) * cell, cell);
  }

  void _finder(Canvas c, Paint black, Paint white, double x, double y, double cell) {
    c.drawRect(Rect.fromLTWH(x,           y,           7 * cell, 7 * cell), black);
    c.drawRect(Rect.fromLTWH(x + cell,    y + cell,    5 * cell, 5 * cell), white);
    c.drawRect(Rect.fromLTWH(x + 2*cell,  y + 2*cell,  3 * cell, 3 * cell), black);
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.data != data || old.type != type;
}

// ── Painter de líneas guía (dashed) ──────────────────────────

class _GuidePainter extends CustomPainter {
  final Color color;
  final bool  vertical; // true = línea vertical, false = horizontal

  const _GuidePainter({required this.color, required this.vertical});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = 0.8
      ..style       = PaintingStyle.stroke;

    const dashLen = 3.5;
    const gapLen  = 2.5;

    if (vertical) {
      double y = 0;
      while (y < size.height) {
        canvas.drawLine(
          Offset(0, y),
          Offset(0, (y + dashLen).clamp(0, size.height)),
          paint,
        );
        y += dashLen + gapLen;
      }
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, 0),
          Offset((x + dashLen).clamp(0, size.width), 0),
          paint,
        );
        x += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.color != color;
}
