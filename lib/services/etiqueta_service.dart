// lib/services/etiqueta_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

// ── Modelo de plantilla ───────────────────────────────────────

class PlantillaEtiqueta {
  double anchoMm;
  double altoMm;
  bool   mostrarBarcode;
  bool   mostrarNombre;
  bool   mostrarPrecio;
  bool   mostrarTienda;
  bool   mostrarCategoria;
  double fontSizeNombre;
  double fontSizePrecio;
  int    cantidad;

  PlantillaEtiqueta({
    required this.anchoMm,
    required this.altoMm,
    required this.mostrarBarcode,
    required this.mostrarNombre,
    required this.mostrarPrecio,
    required this.mostrarTienda,
    required this.mostrarCategoria,
    required this.fontSizeNombre,
    required this.fontSizePrecio,
    required this.cantidad,
  });

  factory PlantillaEtiqueta.defaults() => PlantillaEtiqueta(
    anchoMm:          58,
    altoMm:           30,
    mostrarBarcode:   true,
    mostrarNombre:    true,
    mostrarPrecio:    true,
    mostrarTienda:    false,
    mostrarCategoria: false,
    fontSizeNombre:   8,
    fontSizePrecio:   10,
    cantidad:         1,
  );

  Map<String, dynamic> toJson() => {
    'anchoMm':          anchoMm,
    'altoMm':           altoMm,
    'mostrarBarcode':   mostrarBarcode,
    'mostrarNombre':    mostrarNombre,
    'mostrarPrecio':    mostrarPrecio,
    'mostrarTienda':    mostrarTienda,
    'mostrarCategoria': mostrarCategoria,
    'fontSizeNombre':   fontSizeNombre,
    'fontSizePrecio':   fontSizePrecio,
    'cantidad':         cantidad,
  };

  factory PlantillaEtiqueta.fromJson(Map<String, dynamic> j) =>
    PlantillaEtiqueta(
      anchoMm:          (j['anchoMm']  as num?)?.toDouble() ?? 58,
      altoMm:           (j['altoMm']   as num?)?.toDouble() ?? 30,
      mostrarBarcode:   j['mostrarBarcode']   as bool? ?? true,
      mostrarNombre:    j['mostrarNombre']    as bool? ?? true,
      mostrarPrecio:    j['mostrarPrecio']    as bool? ?? true,
      mostrarTienda:    j['mostrarTienda']    as bool? ?? false,
      mostrarCategoria: j['mostrarCategoria'] as bool? ?? false,
      fontSizeNombre:   (j['fontSizeNombre']  as num?)?.toDouble() ?? 8,
      fontSizePrecio:   (j['fontSizePrecio']  as num?)?.toDouble() ?? 10,
      cantidad:         j['cantidad'] as int? ?? 1,
    );

  PlantillaEtiqueta copyWith({
    double? anchoMm,
    double? altoMm,
    bool?   mostrarBarcode,
    bool?   mostrarNombre,
    bool?   mostrarPrecio,
    bool?   mostrarTienda,
    bool?   mostrarCategoria,
    double? fontSizeNombre,
    double? fontSizePrecio,
    int?    cantidad,
  }) => PlantillaEtiqueta(
    anchoMm:          anchoMm          ?? this.anchoMm,
    altoMm:           altoMm           ?? this.altoMm,
    mostrarBarcode:   mostrarBarcode   ?? this.mostrarBarcode,
    mostrarNombre:    mostrarNombre    ?? this.mostrarNombre,
    mostrarPrecio:    mostrarPrecio    ?? this.mostrarPrecio,
    mostrarTienda:    mostrarTienda    ?? this.mostrarTienda,
    mostrarCategoria: mostrarCategoria ?? this.mostrarCategoria,
    fontSizeNombre:   fontSizeNombre   ?? this.fontSizeNombre,
    fontSizePrecio:   fontSizePrecio   ?? this.fontSizePrecio,
    cantidad:         cantidad         ?? this.cantidad,
  );
}

// ── Tamaños predefinidos ──────────────────────────────────────

class TamanoEtiqueta {
  final String nombre;
  final double anchoMm;
  final double altoMm;
  const TamanoEtiqueta(this.nombre, this.anchoMm, this.altoMm);
}

const tamanos = [
  TamanoEtiqueta('58 × 30 mm', 58, 30),
  TamanoEtiqueta('80 × 40 mm', 80, 40),
  TamanoEtiqueta('100 × 50 mm', 100, 50),
  TamanoEtiqueta('Personalizado', 0, 0),
];

// ── Servicio ──────────────────────────────────────────────────

class EtiquetaService {
  static const _prefsKey = 'plantilla_etiqueta_v1';

  static String _fmt(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    if (d == null) return '—';
    return d.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
  }

  Future<void> guardarPlantilla(PlantillaEtiqueta p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(p.toJson()));
  }

  Future<PlantillaEtiqueta> cargarPlantilla() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return PlantillaEtiqueta.defaults();
      return PlantillaEtiqueta.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PlantillaEtiqueta.defaults();
    }
  }

  Future<Uint8List> generarPdf(
    PlantillaEtiqueta p,
    Map<String, dynamic> producto,
  ) async {
    final pdf    = pw.Document();
    final ancho  = p.anchoMm  * PdfPageFormat.mm;
    final alto   = p.altoMm   * PdfPageFormat.mm;
    final margin = 2.0        * PdfPageFormat.mm;
    final format = PdfPageFormat(ancho, alto,
        marginAll: margin);

    final codigo  = (producto['codigo_barras'] as String?)?.trim() ?? '';
    final nombre  = (producto['nombre']        as String?) ?? '';
    final precio  = producto['precio_venta'];
    final tienda  = (producto['tienda_nombre'] as String?) ?? '';
    final cat     = (producto['categoria_nombre'] as String?) ?? '';

    for (int i = 0; i < p.cantidad; i++) {
      pdf.addPage(pw.Page(
        pageFormat: format,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment:  pw.MainAxisAlignment.spaceEvenly,
          children: [

            if (p.mostrarNombre && nombre.isNotEmpty)
              pw.Text(
                nombre,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: p.fontSizeNombre,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 2,
              ),

            if (p.mostrarBarcode && codigo.isNotEmpty)
              pw.BarcodeWidget(
                barcode:   pw.Barcode.code128(),
                data:      codigo,
                height:    (p.altoMm * 0.4) * PdfPageFormat.mm,
                drawText:  true,
                textStyle: const pw.TextStyle(fontSize: 6),
              )
            else if (p.mostrarBarcode && codigo.isEmpty)
              pw.Container(
                height: (p.altoMm * 0.35) * PdfPageFormat.mm,
                child: pw.Center(
                  child: pw.Text('Sin código',
                      style: const pw.TextStyle(fontSize: 6)),
                ),
              ),

            if (p.mostrarPrecio && precio != null)
              pw.Text(
                '\$${_fmt(precio)}',
                style: pw.TextStyle(
                  fontSize: p.fontSizePrecio,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

            if (p.mostrarTienda && tienda.isNotEmpty)
              pw.Text(tienda,
                  style: const pw.TextStyle(fontSize: 6)),

            if (p.mostrarCategoria && cat.isNotEmpty)
              pw.Text(cat,
                  style: const pw.TextStyle(fontSize: 6)),
          ],
        ),
      ));
    }

    return pdf.save();
  }

  /// Genera un PDF de placeholder (sin producto) para la preview vacía.
  Future<Uint8List> generarPdfVacio(PlantillaEtiqueta p) async {
    final pdf    = pw.Document();
    final ancho  = p.anchoMm * PdfPageFormat.mm;
    final alto   = p.altoMm  * PdfPageFormat.mm;
    final format = PdfPageFormat(ancho, alto, marginAll: 2 * PdfPageFormat.mm);

    pdf.addPage(pw.Page(
      pageFormat: format,
      build: (_) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(
              width: (p.anchoMm - 8) * PdfPageFormat.mm,
              height: 2,
              color: PdfColors.grey300,
            ),
            pw.SizedBox(height: 4 * PdfPageFormat.mm),
            pw.Text('Selecciona un producto',
                style: pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey400)),
          ],
        ),
      ),
    ));
    return pdf.save();
  }
}
