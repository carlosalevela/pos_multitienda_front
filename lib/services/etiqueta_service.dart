// lib/services/etiqueta_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

// ── Formato de precio ─────────────────────────────────────────

String fmtPrecio(dynamic v) {
  final d = double.tryParse(v?.toString() ?? '');
  if (d == null) return '—';
  return d.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

// ── Posición de un elemento en la etiqueta ────────────────────

class ElemPos {
  double  x;
  double  y;
  double  fontSize;
  double? hMm;         // altura explícita en mm (barcode)
  double? wMm;         // ancho explícito en mm (todos)
  String? textoCustom; // reemplaza el campo del producto en pantalla e impresión
  bool?   bold;        // null = usar el default del tipo de elemento

  ElemPos({
    required this.x,
    required this.y,
    required this.fontSize,
    this.hMm,
    this.wMm,
    this.textoCustom,
    this.bold,
  });

  Map<String, dynamic> toJson() => {
    'x': x, 'y': y, 'fs': fontSize,
    if (hMm         != null) 'hMm': hMm,
    if (wMm         != null) 'wMm': wMm,
    if (textoCustom != null) 'tc':  textoCustom,
    if (bold        != null) 'b':   bold,
  };

  factory ElemPos.fromJson(Map<String, dynamic> j) => ElemPos(
        x:           (j['x']   as num?)?.toDouble() ?? 0,
        y:           (j['y']   as num?)?.toDouble() ?? 0,
        fontSize:    (j['fs']  as num?)?.toDouble() ?? 8,
        hMm:         (j['hMm'] as num?)?.toDouble(),
        wMm:         (j['wMm'] as num?)?.toDouble(),
        textoCustom: j['tc']   as String?,
        bold:        j['b']    as bool?,
      );

  ElemPos copyWith({
    double?  x,
    double?  y,
    double?  fontSize,
    Object?  hMm         = _sentinel,
    Object?  wMm         = _sentinel,
    Object?  textoCustom = _sentinel,
    Object?  bold        = _sentinel,
  }) =>
      ElemPos(
        x:           x        ?? this.x,
        y:           y        ?? this.y,
        fontSize:    fontSize ?? this.fontSize,
        hMm:         hMm         == _sentinel ? this.hMm         : hMm         as double?,
        wMm:         wMm         == _sentinel ? this.wMm         : wMm         as double?,
        textoCustom: textoCustom == _sentinel ? this.textoCustom : textoCustom as String?,
        bold:        bold        == _sentinel ? this.bold        : bold        as bool?,
      );

  /// Negrilla efectiva según el tipo de elemento.
  /// nombre y precio son bold por defecto (compatibilidad hacia atrás).
  bool boldParaKey(String key) => bold ?? (key == 'nombre' || key == 'precio');
}

const _sentinel = Object();

// ── Modelo de plantilla ───────────────────────────────────────

class PlantillaEtiqueta {
  double anchoMm;
  double altoMm;
  bool   mostrarBarcode;
  bool   mostrarNombre;
  bool   mostrarPrecio;
  bool   mostrarPrecioMayoreo;
  bool   mostrarTienda;
  bool   mostrarCategoria;
  String barcodeType; // 'code128' | 'ean13' | 'ean8' | 'qrcode' | 'code39'
  Map<String, ElemPos> posiciones;

  PlantillaEtiqueta({
    required this.anchoMm,
    required this.altoMm,
    required this.mostrarBarcode,
    required this.mostrarNombre,
    required this.mostrarPrecio,
    required this.mostrarPrecioMayoreo,
    required this.mostrarTienda,
    required this.mostrarCategoria,
    this.barcodeType = 'code128',
    required this.posiciones,
  });

  // Layout: nombre arriba-izq · barcode izq · precio/categoria derecha
  // Proporcional al tamaño para escalar correctamente con cualquier etiqueta.
  static Map<String, ElemPos> defaultPos(double aw, double ah) => {
    'nombre':         ElemPos(
      x: aw * 0.03, y: ah * 0.05,
      fontSize: (aw * 0.16).clamp(5.0, 9.0), bold: true),
    'tienda':         ElemPos(
      x: aw * 0.03, y: ah * 0.05,
      fontSize: (aw * 0.14).clamp(4.5, 8.0), bold: false),
    'barcode':        ElemPos(
      x: aw * 0.03, y: ah * 0.27,
      fontSize: 5, wMm: aw * 0.60, hMm: ah * 0.52),
    'precio':         ElemPos(
      x: aw * 0.68, y: ah * 0.27,
      fontSize: (aw * 0.22).clamp(7.0, 12.0), bold: true),
    'precio_mayoreo': ElemPos(
      x: aw * 0.68, y: ah * 0.55,
      fontSize: (aw * 0.14).clamp(4.5, 8.0)),
    'categoria':      ElemPos(
      x: aw * 0.68, y: ah * 0.72,
      fontSize: (aw * 0.13).clamp(4.0, 7.5)),
  };

  static Map<String, ElemPos> _defaultPos(double aw, double ah) =>
      defaultPos(aw, ah);

  factory PlantillaEtiqueta.defaults() {
    const aw = 58.0;
    const ah = 30.0;
    return PlantillaEtiqueta(
      anchoMm:              aw,
      altoMm:               ah,
      mostrarBarcode:       true,
      mostrarNombre:        true,
      mostrarPrecio:        true,
      mostrarPrecioMayoreo: false,
      mostrarTienda:        false,
      mostrarCategoria:     false,
      barcodeType:          'code128',
      posiciones:           _defaultPos(aw, ah),
    );
  }

  Map<String, dynamic> toJson() => {
    'anchoMm':              anchoMm,
    'altoMm':               altoMm,
    'mostrarBarcode':       mostrarBarcode,
    'mostrarNombre':        mostrarNombre,
    'mostrarPrecio':        mostrarPrecio,
    'mostrarPrecioMayoreo': mostrarPrecioMayoreo,
    'mostrarTienda':        mostrarTienda,
    'mostrarCategoria':     mostrarCategoria,
    'barcodeType':          barcodeType,
    'posiciones': posiciones.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory PlantillaEtiqueta.fromJson(Map<String, dynamic> j) {
    final aw = (j['anchoMm'] as num?)?.toDouble() ?? 58;
    final ah = (j['altoMm']  as num?)?.toDouble() ?? 30;
    final Map<String, ElemPos> pos = {};
    final rawPos = j['posiciones'] as Map<String, dynamic>?;
    if (rawPos != null) {
      rawPos.forEach((k, v) => pos[k] = ElemPos.fromJson(v as Map<String, dynamic>));
    }
    final defs = _defaultPos(aw, ah);
    defs.forEach((k, v) => pos.putIfAbsent(k, () => v));
    return PlantillaEtiqueta(
      anchoMm:              aw,
      altoMm:               ah,
      mostrarBarcode:       j['mostrarBarcode']       as bool?   ?? true,
      mostrarNombre:        j['mostrarNombre']        as bool?   ?? true,
      mostrarPrecio:        j['mostrarPrecio']        as bool?   ?? true,
      mostrarPrecioMayoreo: j['mostrarPrecioMayoreo'] as bool?   ?? false,
      mostrarTienda:        j['mostrarTienda']        as bool?   ?? false,
      mostrarCategoria:     j['mostrarCategoria']     as bool?   ?? false,
      barcodeType:          j['barcodeType']          as String? ?? 'code128',
      posiciones:           pos,
    );
  }

  PlantillaEtiqueta copyWith({
    double?               anchoMm,
    double?               altoMm,
    bool?                 mostrarBarcode,
    bool?                 mostrarNombre,
    bool?                 mostrarPrecio,
    bool?                 mostrarPrecioMayoreo,
    bool?                 mostrarTienda,
    bool?                 mostrarCategoria,
    String?               barcodeType,
    Map<String, ElemPos>? posiciones,
  }) =>
      PlantillaEtiqueta(
        anchoMm:              anchoMm              ?? this.anchoMm,
        altoMm:               altoMm               ?? this.altoMm,
        mostrarBarcode:       mostrarBarcode       ?? this.mostrarBarcode,
        mostrarNombre:        mostrarNombre        ?? this.mostrarNombre,
        mostrarPrecio:        mostrarPrecio        ?? this.mostrarPrecio,
        mostrarPrecioMayoreo: mostrarPrecioMayoreo ?? this.mostrarPrecioMayoreo,
        mostrarTienda:        mostrarTienda        ?? this.mostrarTienda,
        mostrarCategoria:     mostrarCategoria     ?? this.mostrarCategoria,
        barcodeType:          barcodeType          ?? this.barcodeType,
        posiciones:           posiciones           ?? Map.from(this.posiciones),
      );

  /// Devuelve una copia con la posición de un elemento actualizada.
  PlantillaEtiqueta conPosicion(String key, ElemPos pos) {
    final m = Map<String, ElemPos>.from(posiciones);
    m[key] = pos;
    return copyWith(posiciones: m);
  }
}

// ── Tamaños predefinidos ──────────────────────────────────────

class TamanoEtiqueta {
  final String nombre;
  final double anchoMm;
  final double altoMm;
  const TamanoEtiqueta(this.nombre, this.anchoMm, this.altoMm);
}

const tamanos = [
  TamanoEtiqueta('58 × 30 mm',   58,  30),
  TamanoEtiqueta('80 × 40 mm',   80,  40),
  TamanoEtiqueta('100 × 50 mm', 100,  50),
  TamanoEtiqueta('Personalizado',  0,   0),
];

// ── Servicio ──────────────────────────────────────────────────

class EtiquetaService {
  static const _prefsKey        = 'plantilla_etiqueta_v2';
  static const _plantillasKey   = 'plantillas_guardadas_v1';

  Future<void> guardarPlantilla(PlantillaEtiqueta p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(p.toJson()));
  }

  Future<PlantillaEtiqueta> cargarPlantilla() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return PlantillaEtiqueta.defaults();
      return PlantillaEtiqueta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PlantillaEtiqueta.defaults();
    }
  }

  // ── Plantillas guardadas ──────────────────────────────────────

  Future<List<PlantillaGuardada>> listarPlantillas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_plantillasKey);
      if (raw == null) return [];
      final list  = jsonDecode(raw) as List;
      return list
          .map((e) => PlantillaGuardada.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarComoPlantilla(String nombre, PlantillaEtiqueta p) async {
    final prefs  = await SharedPreferences.getInstance();
    final lista  = await listarPlantillas();
    final nueva  = PlantillaGuardada(
      id:       DateTime.now().millisecondsSinceEpoch.toString(),
      nombre:   nombre,
      plantilla: p,
    );
    lista.add(nueva);
    await prefs.setString(
        _plantillasKey, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  Future<void> eliminarPlantilla(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await listarPlantillas();
    lista.removeWhere((e) => e.id == id);
    await prefs.setString(
        _plantillasKey, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  // ── PDF helpers ───────────────────────────────────────────────

  // Selecciona el tipo de barcode según la configuración y valida el dato.
  // Si el dato no es compatible (ej. EAN-13 necesita 12-13 dígitos),
  // cae a Code 128 automáticamente.
  pw.Barcode _resolveBarcode(String type, String data) {
    switch (type) {
      case 'ean13':
        if (RegExp(r'^\d{12,13}$').hasMatch(data)) return pw.Barcode.ean13();
        return pw.Barcode.code128();
      case 'ean8':
        if (RegExp(r'^\d{7,8}$').hasMatch(data)) return pw.Barcode.ean8();
        return pw.Barcode.code128();
      case 'qrcode':
        return pw.Barcode.qrCode();
      case 'code39':
        if (RegExp(r'^[A-Z0-9 \-\.$/+%]*$').hasMatch(data.toUpperCase())) {
          return pw.Barcode.code39();
        }
        return pw.Barcode.code128();
      case 'code128':
      default:
        return pw.Barcode.code128();
    }
  }

  PdfPageFormat _format(PlantillaEtiqueta p) => PdfPageFormat(
        p.anchoMm * PdfPageFormat.mm,
        p.altoMm  * PdfPageFormat.mm,
        marginAll: 0,
      );

  // Construye el widget de una etiqueta individual (usado tanto para páginas
  // individuales en rollo como para la cuadrícula en modo hoja).
  // [negritaForzada]: true → todos los textos en negrita para mayor densidad
  // en impresoras térmicas donde el driver no tiene darkness configurable.
  pw.Widget _buildLabelWidget(
    PlantillaEtiqueta    p,
    Map<String, dynamic> producto, {
    bool negritaForzada = false,
  }) {
    final pos = p.posiciones;

    final codigoBase         = (producto['codigo_barras']   as String?)?.trim() ?? '';
    final nombreBase         = (producto['nombre']          as String?) ?? '';
    final precio             = producto['precio_venta'];
    final precioMayoreo      = producto['precio_mayoreo'];
    final tiendaBase         = (producto['tienda_nombre']    as String?) ?? '';
    final catBase            = (producto['categoria_nombre'] as String?) ?? '';

    final nombreFinal        = pos['nombre']!.textoCustom          ?? nombreBase;
    final tiendaFinal        = pos['tienda']!.textoCustom          ?? tiendaBase;
    final catFinal           = pos['categoria']!.textoCustom       ?? catBase;
    final codigoFinal        = pos['barcode']!.textoCustom?.trim() ?? codigoBase;
    final precioFinal        = pos['precio']!.textoCustom
        ?? (precio != null ? '\$${fmtPrecio(precio)}' : null);
    final precioMayoreoFinal = pos['precio_mayoreo']!.textoCustom
        ?? (precioMayoreo != null ? 'Mayor: \$${fmtPrecio(precioMayoreo)}' : null);

    return pw.SizedBox(
      width:  p.anchoMm * PdfPageFormat.mm,
      height: p.altoMm  * PdfPageFormat.mm,
      child: pw.Stack(children: [
        if (p.mostrarNombre && nombreFinal.isNotEmpty)
          pw.Positioned(
            left: pos['nombre']!.x * PdfPageFormat.mm,
            top:  pos['nombre']!.y * PdfPageFormat.mm,
            child: pw.ConstrainedBox(
              constraints: pw.BoxConstraints(
                  maxWidth: (pos['nombre']!.wMm ?? p.anchoMm * 0.86) * PdfPageFormat.mm),
              child: pw.Text(nombreFinal,
                  style: pw.TextStyle(
                      fontSize:   pos['nombre']!.fontSize,
                      fontWeight: (negritaForzada || pos['nombre']!.boldParaKey('nombre'))
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal)),
            ),
          ),

        if (p.mostrarPrecio && precioFinal != null)
          pw.Positioned(
            left: pos['precio']!.x * PdfPageFormat.mm,
            top:  pos['precio']!.y * PdfPageFormat.mm,
            child: pw.Text(precioFinal,
                style: pw.TextStyle(
                    fontSize:   pos['precio']!.fontSize,
                    fontWeight: (negritaForzada || pos['precio']!.boldParaKey('precio'))
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal)),
          ),

        if (p.mostrarBarcode && codigoFinal.isNotEmpty)
          pw.Positioned(
            left: pos['barcode']!.x * PdfPageFormat.mm,
            top:  pos['barcode']!.y * PdfPageFormat.mm,
            child: pw.SizedBox(
              width:  (pos['barcode']!.wMm ?? p.anchoMm * 0.85) * PdfPageFormat.mm,
              height: (pos['barcode']!.hMm ?? p.altoMm  * 0.32) * PdfPageFormat.mm,
              child: pw.BarcodeWidget(
                barcode:   _resolveBarcode(p.barcodeType, codigoFinal),
                data:      codigoFinal,
                drawText:  p.barcodeType != 'qrcode',
                textStyle: const pw.TextStyle(fontSize: 6),
              ),
            ),
          )
        else if (p.mostrarBarcode)
          pw.Positioned(
            left: pos['barcode']!.x * PdfPageFormat.mm,
            top:  pos['barcode']!.y * PdfPageFormat.mm,
            child: pw.Text('Sin código',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
          ),

        if (p.mostrarPrecioMayoreo && precioMayoreoFinal != null)
          pw.Positioned(
            left: pos['precio_mayoreo']!.x * PdfPageFormat.mm,
            top:  pos['precio_mayoreo']!.y * PdfPageFormat.mm,
            child: pw.Text(precioMayoreoFinal,
                style: pw.TextStyle(
                    fontSize:   pos['precio_mayoreo']!.fontSize,
                    fontWeight: (negritaForzada || pos['precio_mayoreo']!.boldParaKey('precio_mayoreo'))
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color:      PdfColors.grey700)),
          ),

        if (p.mostrarTienda && tiendaFinal.isNotEmpty)
          pw.Positioned(
            left: pos['tienda']!.x * PdfPageFormat.mm,
            top:  pos['tienda']!.y * PdfPageFormat.mm,
            child: pw.Text(tiendaFinal,
                style: pw.TextStyle(
                    fontSize:   pos['tienda']!.fontSize,
                    fontWeight: (negritaForzada || pos['tienda']!.boldParaKey('tienda'))
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal)),
          ),

        if (p.mostrarCategoria && catFinal.isNotEmpty)
          pw.Positioned(
            left: pos['categoria']!.x * PdfPageFormat.mm,
            top:  pos['categoria']!.y * PdfPageFormat.mm,
            child: pw.Text(catFinal,
                style: pw.TextStyle(
                    fontSize:   pos['categoria']!.fontSize,
                    fontWeight: (negritaForzada || pos['categoria']!.boldParaKey('categoria'))
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal)),
          ),
      ]),
    );
  }

  void _agregarPagina(
    pw.Document pdf,
    PlantillaEtiqueta p,
    Map<String, dynamic> producto,
  ) {
    pdf.addPage(pw.Page(
      pageFormat: _format(p),
      build:      (_) => _buildLabelWidget(p, producto),
    ));
  }

  // ── API pública ───────────────────────────────────────────────

  Future<Uint8List> generarPdf(
    PlantillaEtiqueta p,
    Map<String, dynamic> producto,
    int cantidad,
  ) async {
    final pdf = pw.Document();
    for (int i = 0; i < cantidad; i++) {
      _agregarPagina(pdf, p, producto);
    }
    return pdf.save();
  }

  /// Genera un PDF donde las etiquetas se distribuyen en filas del ancho del
  /// rollo. Si el rollo tiene [cols] columnas, cada fila ocupa
  /// cols×anchoMm de ancho. Las posiciones vacías de la última fila se
  /// dejan en blanco (como hace Bartender).
  Future<Uint8List> generarPdfRollo(
    PlantillaEtiqueta    p,
    Map<String, dynamic> producto,
    int                  cantidad, {
    int    cols  = 1,
    double gapMm = 0.0,
  }) async {
    if (cols <= 1) return generarPdf(p, producto, cantidad);

    final rows    = (cantidad / cols).ceil();
    final pageW   = cols * p.anchoMm + (cols - 1) * gapMm;
    final pageH   = rows * p.altoMm  + (rows - 1) * gapMm;
    final fmt     = PdfPageFormat(
        pageW * PdfPageFormat.mm, pageH * PdfPageFormat.mm);

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: fmt,
      margin:     pw.EdgeInsets.zero,
      build:      (_) {
        final children = <pw.Widget>[];
        for (int i = 0; i < cantidad; i++) {
          final col  = i % cols;
          final row  = i ~/ cols;
          children.add(pw.Positioned(
            left: col * (p.anchoMm + gapMm) * PdfPageFormat.mm,
            top:  row * (p.altoMm  + gapMm) * PdfPageFormat.mm,
            child: _buildLabelWidget(p, producto),
          ));
        }
        return pw.Stack(children: children);
      },
    ));
    return pdf.save();
  }

  /// Genera un PDF con el tamaño exacto de página que tiene configurado el
  /// driver de Windows (ej. 101.6×101.6mm para SAT TT448-2 en modo USER).
  /// Las etiquetas se tilearon en esa página para que el driver imprima
  /// exactamente el papel que ya tendría que avanzar de todas formas.
  Future<Uint8List> generarPdfPaginaDriver(
    PlantillaEtiqueta    p,
    Map<String, dynamic> producto,
    int                  cantidad, {
    double pgAncho        = 101.6,   // mm — debe coincidir con la config del driver
    double pgAlto         = 101.6,   // mm
    bool   negritaForzada = false,   // true → todos los textos en negrita
  }) async {
    final pageFormat = PdfPageFormat(
      pgAncho * PdfPageFormat.mm, pgAlto * PdfPageFormat.mm);
    final cols    = (pgAncho / p.anchoMm).floor().clamp(1, 30);
    final rows    = (pgAlto  / p.altoMm ).floor().clamp(1, 30);
    final perPage = cols * rows;
    final pdf     = pw.Document();

    int done = 0;
    while (done < cantidad) {
      final count = (cantidad - done).clamp(1, perPage);
      done += count;
      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          final children = <pw.Widget>[];
          for (int i = 0; i < count; i++) {
            final col = i % cols;
            final row = i ~/ cols;
            children.add(pw.Positioned(
              left: col * p.anchoMm * PdfPageFormat.mm,
              top:  row * p.altoMm  * PdfPageFormat.mm,
              child: _buildLabelWidget(p, producto,
                  negritaForzada: negritaForzada),
            ));
          }
          return pw.Stack(children: children);
        },
      ));
    }
    return pdf.save();
  }

  Future<Uint8List> generarPdfLote(
    PlantillaEtiqueta p,
    List<LoteItem> items,
  ) async {
    final pdf = pw.Document();
    for (final item in items) {
      for (int i = 0; i < item.cantidad; i++) {
        _agregarPagina(pdf, p, item.producto);
      }
    }
    return pdf.save();
  }

  /// Cuántas columnas y filas de etiquetas caben en una hoja de papel.
  (int cols, int rows) calcGrid(
    PlantillaEtiqueta p, {
    String papel    = 'a4',
    double margenMm = 10.0,
    double gapMm    = 2.0,
  }) {
    final fmt = papel == 'letter' ? PdfPageFormat.letter : PdfPageFormat.a4;
    final wMm = fmt.width  / PdfPageFormat.mm;
    final hMm = fmt.height / PdfPageFormat.mm;
    final c = ((wMm - 2 * margenMm + gapMm) / (p.anchoMm + gapMm))
        .floor().clamp(1, 30);
    final r = ((hMm - 2 * margenMm + gapMm) / (p.altoMm  + gapMm))
        .floor().clamp(1, 30);
    return (c, r);
  }

  /// Genera un PDF donde las etiquetas se organizan en cuadrícula sobre
  /// hojas A4 o Carta, en lugar de una etiqueta por página (modo rollo).
  Future<Uint8List> generarPdfHoja(
    PlantillaEtiqueta p,
    List<LoteItem>    items, {
    String papel    = 'a4',
    double margenMm = 10.0,
    double gapMm    = 2.0,
    bool   borde    = false,
  }) async {
    final pageFormat      = papel == 'letter' ? PdfPageFormat.letter : PdfPageFormat.a4;
    final (cols, rows)    = calcGrid(p, papel: papel, margenMm: margenMm, gapMm: gapMm);
    final labelsPerPage   = cols * rows;

    final all = <Map<String, dynamic>>[];
    for (final item in items) {
      for (int i = 0; i < item.cantidad; i++) { all.add(item.producto); }
    }

    final pdf = pw.Document();

    for (int start = 0; start < all.length; start += labelsPerPage) {
      final batch = all.skip(start).take(labelsPerPage).toList();

      // Recorta la altura de la página a las filas realmente usadas.
      // Así una impresora de rollo solo avanza el papel necesario.
      final rowsUsed   = (batch.length / cols).ceil().clamp(1, rows);
      final trimHMm    = margenMm * 2 + rowsUsed * p.altoMm + (rowsUsed - 1) * gapMm;
      final trimFormat = PdfPageFormat(pageFormat.width, trimHMm * PdfPageFormat.mm);

      pdf.addPage(pw.Page(
        pageFormat: trimFormat,
        margin: pw.EdgeInsets.all(margenMm * PdfPageFormat.mm),
        build: (_) {
          final children = <pw.Widget>[];
          final lw = p.anchoMm * PdfPageFormat.mm;
          final lh = p.altoMm  * PdfPageFormat.mm;

          for (int i = 0; i < batch.length; i++) {
            final col  = i % cols;
            final row  = i ~/ cols;
            final left = col * (p.anchoMm + gapMm) * PdfPageFormat.mm;
            final top  = row * (p.altoMm  + gapMm) * PdfPageFormat.mm;

            if (borde) {
              children.add(pw.Positioned(
                left: left, top: top,
                child: pw.Container(
                  width: lw, height: lh,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColors.grey400, width: 0.5),
                  ),
                ),
              ));
            }

            children.add(pw.Positioned(
              left: left, top: top,
              child: _buildLabelWidget(p, batch[i]),
            ));
          }

          return pw.Stack(children: children);
        },
      ));
    }

    return pdf.save();
  }

  /// Variante de [generarPdfHoja] para un solo producto con cantidad.
  Future<Uint8List> generarPdfHojaSingle(
    PlantillaEtiqueta    p,
    Map<String, dynamic> producto,
    int                  cantidad, {
    String papel    = 'a4',
    double margenMm = 10.0,
    double gapMm    = 2.0,
    bool   borde    = false,
  }) =>
      generarPdfHoja(
        p,
        [LoteItem(producto: producto, cantidad: cantidad)],
        papel:    papel,
        margenMm: margenMm,
        gapMm:    gapMm,
        borde:    borde,
      );
}

// ── Modelo de ítem para lote ──────────────────────────────────

class LoteItem {
  final Map<String, dynamic> producto;
  int cantidad;

  LoteItem({required this.producto, this.cantidad = 1});
}

// ── Plantilla guardada con nombre ─────────────────────────────

class PlantillaGuardada {
  final String          id;
  final String          nombre;
  final PlantillaEtiqueta plantilla;

  PlantillaGuardada({
    required this.id,
    required this.nombre,
    required this.plantilla,
  });

  Map<String, dynamic> toJson() => {
    'id':       id,
    'nombre':   nombre,
    'plantilla': plantilla.toJson(),
  };

  factory PlantillaGuardada.fromJson(Map<String, dynamic> j) => PlantillaGuardada(
    id:       j['id']     as String,
    nombre:   j['nombre'] as String,
    plantilla: PlantillaEtiqueta.fromJson(j['plantilla'] as Map<String, dynamic>),
  );
}
