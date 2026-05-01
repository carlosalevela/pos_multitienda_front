// lib/screens/inventario/widgets/importar_excel_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
// ✅ Oculta Border Y BorderStyle del paquete excel para evitar conflicto con Flutter
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/inventario_provider.dart';

// ── Paleta ────────────────────────────────────────────────
const _c1       = Color(0xFF6366F1);
const _c2       = Color(0xFF8B5CF6);
const _bg       = Color(0xFFF8F9FC);
const _red      = Color(0xFFEF4444);
const _grn      = Color(0xFF10B981);
const _slate50  = Color(0xFFF8FAFC);
const _slate100 = Color(0xFFF1F5F9);
const _slate200 = Color(0xFFE2E8F0);
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate900 = Color(0xFF0F172A);

// ── Helper de estilo ──────────────────────────────────────
TextStyle _jakSans({
  double size = 13,
  FontWeight weight = FontWeight.w500,
  Color color = _slate500,
  double? letterSpacing,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

// ─────────────────────────────────────────────────────────
class ImportarExcelDialog extends StatefulWidget {
  final int    tiendaId;
  final int?   empresaId;
  final String nombreTienda;

  const ImportarExcelDialog({
    super.key,
    required this.tiendaId,
    required this.empresaId,
    required this.nombreTienda,
  });

  @override
  State<ImportarExcelDialog> createState() => _ImportarExcelDialogState();
}

enum _Paso { seleccionar, previsualizar, resultado }

// ─────────────────────────────────────────────────────────
class _ImportarExcelDialogState extends State<ImportarExcelDialog>
    with TickerProviderStateMixin {
  _Paso _paso = _Paso.seleccionar;

  String?                    _nombreArchivo;
  List<Map<String, dynamic>> _filas      = [];
  List<Map<String, dynamic>> _filasError = [];
  bool                       _cargando   = false;
  String                     _msgCarga   = '';
  Map<String, dynamic>?      _resultado;

  // Búsqueda en preview
  String _busqueda = '';
  late final TextEditingController _busCtrl;

  // Animación entre pasos
  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  // ══════════════════════════════════════════════════════
  // MAPEO DE COLUMNAS — aliases ampliados para máxima
  // cobertura de nombres reales en archivos de clientes.
  // ══════════════════════════════════════════════════════
  static const _mapa = <String, List<String>>{
    'nombre': [
      'nombre', 'name', 'producto', 'productos', 'descripcion_corta',
      'articulo', 'articulos', 'item', 'items', 'bien', 'servicio',
      'denominacion', 'titulo', 'title',
    ],
    'descripcion': [
      'descripcion', 'description', 'detalle', 'detalles', 'desc',
      'descripcion_larga', 'observacion', 'observaciones', 'nota', 'notas',
      'comentario', 'comentarios', 'detalle_producto',
    ],
    'codigo_barras': [
      'codigo_barras', 'codigo', 'codigos', 'barcode', 'ean', 'ean13',
      'ref', 'referencia', 'referencias', 'sku', 'upc', 'gtin',
      'cod', 'cod_barras', 'codigo_producto', 'clave', 'clave_producto',
    ],
    'categoria_nombre': [
      'categoria', 'categorias', 'categoria_nombre', 'category',
      'grupo', 'grupos', 'familia', 'familias', 'linea', 'lineas',
      'departamento', 'departamentos', 'tipo', 'tipos', 'clasificacion',
      'seccion', 'secciones', 'rubro',
    ],
    'precio_venta': [
      'precio_venta', 'precio', 'precios', 'pventa', 'price',
      'valor', 'valores', 'venta', 'precio_publico', 'p_venta',
      'precio_al_publico', 'precio_cliente', 'pvp', 'sale_price',
    ],
    'precio_compra': [
      'precio_compra', 'costo', 'costos', 'cost', 'compra',
      'pcompra', 'p_compra', 'precio_costo', 'costo_unitario',
      'purchase_price', 'landed_cost',
    ],
    'stock_actual': [
      'stock_actual', 'stock', 'cantidad', 'cantidades', 'qty',
      'existencia', 'existencias', 'inventory', 'disponible',
      'disponibles', 'unidades', 'saldo', 'inventario',
    ],
    'stock_minimo': [
      'stock_minimo', 'minimo', 'min', 'stock_min', 'min_stock',
      'cantidad_minima', 'punto_reorden', 'reorder', 'minimo_stock',
    ],
  };

  // ══════════════════════════════════════════════════════
  // NORMALIZACIÓN ROBUSTA
  // Convierte cualquier string a una forma canónica que
  // elimina mayúsculas, tildes, espacios y caracteres
  // especiales para la comparación.
  // ══════════════════════════════════════════════════════
  String _norm(String s) => s
      .trim()
      .toLowerCase()
      // Eliminar caracteres especiales frecuentes en encabezados de Excel
      .replaceAll(RegExp(r'[\(\)\[\]\{\}\.\:\;\/\\\-\+\*\#\@\!\?\=\%\&\|]'), ' ')
      // Normalizar tildes y variantes
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'),   'e')
      .replaceAll(RegExp(r'[ìíîï]'),   'i')
      .replaceAll(RegExp(r'[òóôõö]'),  'o')
      .replaceAll(RegExp(r'[ùúûü]'),   'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c')
      // Colapsar espacios y convertir a guión bajo
      .replaceAll(RegExp(r'\s+'), '_')
      // Quitar guiones bajos al inicio/final
      .replaceAll(RegExp(r'^_+|_+$'), '');

  // ══════════════════════════════════════════════════════
  // MATCHING MULTI-ESTRATEGIA
  // Estrategia 1 — Exacto:    "nombre" == "nombre"
  // Estrategia 2 — Contiene:  "nombre_producto" contiene alias "nombre"
  // Estrategia 3 — Inverso:   alias contiene el header
  // Estrategia 4 — Palabras:  todas las palabras del alias están en el header
  // ══════════════════════════════════════════════════════
  bool _matchAlias(String rawHeader, List<String> aliases) {
    final h = _norm(rawHeader);
    if (h.isEmpty) return false;

    for (final alias in aliases) {
      final a = alias; // ya normalizado en el mapa

      // Estrategia 1: exacto
      if (h == a) return true;

      // Estrategia 2: header contiene el alias
      if (h.contains(a)) return true;

      // Estrategia 3: alias contiene el header
      if (a.contains(h)) return true;

      // Estrategia 4: palabras significativas del alias presentes en header
      final aWords = a.split('_').where((w) => w.length > 2).toList();
      final hWords = h.split('_');
      if (aWords.isNotEmpty &&
          aWords.every((w) => hWords.any((hw) => hw.contains(w) || w.contains(hw)))) {
        return true;
      }
    }
    return false;
  }

  // ══════════════════════════════════════════════════════
  // LECTURA DE CELDAS — compatible con excel ^4.x
  //
  // En excel ≥4.0 CellValue es sealed y su .toString()
  // devuelve "TextCellValue(texto)" en lugar del valor puro.
  // Esta función extrae el valor real manejando todos los
  // tipos posibles de la librería.
  // ══════════════════════════════════════════════════════
  String _readCell(Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v == null) return '';

    // ── Tipos específicos de excel ^4.x ──
    if (v is TextCellValue) {
      return (v.value ?? '').toString().trim();
    }
    if (v is IntCellValue) {
      return v.value.toString().trim();
    }
    if (v is DoubleCellValue) {
      final d = v.value;
      // Evitar "1000.0" cuando el número es entero
      return (d == d.truncateToDouble())
          ? d.truncate().toString()
          : d.toString().trim();
    }
    if (v is BoolCellValue) {
      return v.value.toString().trim();
    }
    if (v is DateCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2,'0')}-${v.day.toString().padLeft(2,'0')}';
    }
    if (v is DateTimeCellValue) {
      return v.asDateTimeUtc().toIso8601String();
    }
    if (v is TimeCellValue) {
      return v.toString().trim();
    }

    // ── Fallback para versiones anteriores de excel ──
    // Algunas versiones devuelven "TextCellValue(value)" como String.
    final raw   = v.toString().trim();
    final match = RegExp(r'^[A-Za-z]+CellValue\((.+)\)$').firstMatch(raw);
    if (match != null) return match.group(1)?.trim() ?? '';

    return raw;
  }

  // ══════════════════════════════════════════════════════
  // PARSEO DE NÚMEROS — tolerante a formatos mixtos
  // Maneja: "1.000,50" / "1,000.50" / "$1.500" / "1500 und"
  // ══════════════════════════════════════════════════════
  double _parseNum(String s) {
    if (s.isEmpty) return 0;

    // Quitar símbolos no numéricos excepto punto y coma
    String clean = s.replaceAll(RegExp(r'[^\d.,]'), '');
    if (clean.isEmpty) return 0;

    if (clean.contains(',') && clean.contains('.')) {
      // Formato europeo "1.000,50" → decimal = coma
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Formato anglosajón "1,000.50" → separador miles = coma
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      final parts = clean.split(',');
      // Coma decimal: "1,50" (parte decimal ≤ 2 dígitos)
      if (parts.length == 2 && parts.last.length <= 2) {
        clean = clean.replaceAll(',', '.');
      } else {
        // Coma como separador de miles: "1,000"
        clean = clean.replaceAll(',', '');
      }
    }

    return double.tryParse(clean) ?? 0;
  }

  // ── Lifecycle ──────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _busCtrl  = TextEditingController();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _busCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  // SELECCIÓN Y PARSEO DEL ARCHIVO
  // ══════════════════════════════════════════════════════
  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    _cambiarPaso(() {
      _cargando = true;
      _msgCarga = 'Leyendo archivo…';
    });

    try {
      final bytes = result.files.single.bytes!;
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        _mostrarError('El archivo no tiene hojas de datos.');
        return;
      }

      // Buscar la primera hoja que tenga datos
      Sheet? sheet;
      for (final s in excel.tables.values) {
        if (s.rows.isNotEmpty) { sheet = s; break; }
      }
      if (sheet == null) {
        _mostrarError('El archivo está vacío (ninguna hoja tiene datos).');
        return;
      }

      final rows = sheet.rows;
      if (rows.length < 2) {
        _mostrarError(
          'El archivo debe tener al menos una fila de encabezados y una de datos.');
        return;
      }

      // ── Detectar fila de encabezados ──────────────────
      // Algunos archivos tienen títulos o logos en las primeras filas;
      // buscamos la primera fila que contenga al menos una columna conocida.
      int headerRowIdx     = 0;
      List<String> headers = [];

      for (int ri = 0; ri < rows.length && ri < 10; ri++) {
        final candidatos = rows[ri].map(_readCell).toList();
        final matches    = candidatos.where((h) =>
          _mapa.entries.any((e) => _matchAlias(h, e.value))).length;
        if (matches >= 1) {
          headerRowIdx = ri;
          headers      = candidatos;
          break;
        }
      }

      if (headers.isEmpty) {
        _mostrarError(
          'No se reconoció ninguna columna del archivo.\n'
          'Asegúrate de que la primera fila sea el encabezado con al menos "nombre".',
        );
        return;
      }

      // ── Mapear columna → índice ───────────────────────
      final colMap = <String, int>{};
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].isEmpty) continue;
        for (final entry in _mapa.entries) {
          if (!colMap.containsKey(entry.key) &&
              _matchAlias(headers[i], entry.value)) {
            colMap[entry.key] = i;
          }
        }
      }

      // Log para debug en consola de Flutter
      debugPrint('📊 Encabezados detectados: $headers');
      debugPrint('📌 Columnas mapeadas:      $colMap');

      if (!colMap.containsKey('nombre')) {
        _mostrarError(
          'No se encontró la columna "nombre".\n'
          'Encabezados detectados: ${headers.where((h) => h.isNotEmpty).join(', ')}',
        );
        return;
      }

      // ── Leer filas de datos ───────────────────────────
      String cellStr(List<Data?> row, String campo) {
        final idx = colMap[campo];
        if (idx == null || idx >= row.length) return '';
        return _readCell(row[idx]);
      }

      final filas   = <Map<String, dynamic>>[];
      final errores = <Map<String, dynamic>>[];

      for (int i = headerRowIdx + 1; i < rows.length; i++) {
        final row = rows[i];

        // Saltar filas completamente vacías
        if (row.every((c) => _readCell(c).isEmpty)) continue;

        final nombre = cellStr(row, 'nombre');
        if (nombre.isEmpty) continue;

        final precioVenta  = _parseNum(cellStr(row, 'precio_venta'));
        final precioCompra = _parseNum(cellStr(row, 'precio_compra'));
        final stockActual  = _parseNum(cellStr(row, 'stock_actual'));
        final stockMinimo  = _parseNum(cellStr(row, 'stock_minimo'));

        final item = <String, dynamic>{
          'fila':             i + 1,
          'nombre':           nombre,
          'descripcion':      cellStr(row, 'descripcion'),
          'codigo_barras':    cellStr(row, 'codigo_barras'),
          'categoria_nombre': cellStr(row, 'categoria_nombre'),
          'precio_venta':     precioVenta,
          'precio_compra':    precioCompra,
          'stock_actual':     stockActual,
          'stock_minimo':     stockMinimo,
        };

        // Validaciones en cliente
        final errItem = <String>[];
        if (nombre.length > 150) errItem.add('Nombre muy largo (máx 150 car.)');
        if (precioVenta  < 0)    errItem.add('Precio de venta negativo');
        if (precioCompra < 0)    errItem.add('Precio de compra negativo');
        if (stockActual  < 0)    errItem.add('Stock negativo');

        if (errItem.isNotEmpty) {
          errores.add({...item, '_error': errItem.join(' · ')});
        } else {
          filas.add(item);
        }
      }

      if (filas.isEmpty && errores.isEmpty) {
        _mostrarError('No se encontraron filas de datos válidas en el archivo.');
        return;
      }

      _cambiarPaso(() {
        _nombreArchivo = result.files.single.name;
        _filas         = filas;
        _filasError    = errores;
        _paso          = _Paso.previsualizar;
        _cargando      = false;
        _busqueda      = '';
        _busCtrl.clear();
      });

    } catch (e, st) {
      debugPrint('❌ ERROR leyendo Excel: $e\n$st');
      _mostrarError(
        'Error al leer el archivo.\n'
        'Asegúrate de que no esté abierto en otro programa.\n'
        'Detalle: $e',
      );
    }
  }

  // ── Importar ───────────────────────────────────────────
  Future<void> _importar() async {
    if (_filas.isEmpty) return;
    _cambiarPaso(() {
      _cargando = true;
      _msgCarga = 'Importando ${_filas.length} productos…';
    });

    final payload = _filas.map((f) {
      final m = Map<String, dynamic>.from(f)..remove('fila');
      return m;
    }).toList();

    final inv = context.read<InventarioProvider>();
    final res = await inv.importarProductos(
      productos: payload,
      tiendaId:  widget.tiendaId,
      empresaId: widget.empresaId,
    );

    _cambiarPaso(() {
      _cargando  = false;
      _resultado = res['data'] as Map<String, dynamic>?;
      _paso      = _Paso.resultado;
    });
  }

  // ── Helpers ────────────────────────────────────────────
  void _cambiarPaso(VoidCallback fn) {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(fn);
      _fadeCtrl.forward();
    });
  }

  void _mostrarError(String msg) {
    setState(() => _cargando = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _jakSans(color: Colors.white, size: 12)),
      backgroundColor: _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 6),
    ));
  }

  List<Map<String, dynamic>> get _filasFiltradas {
    if (_busqueda.isEmpty) return _filas;
    final q = _busqueda.toLowerCase();
    return _filas.where((f) =>
      (f['nombre']           as String).toLowerCase().contains(q) ||
      (f['categoria_nombre'] as String).toLowerCase().contains(q) ||
      (f['codigo_barras']    as String).toLowerCase().contains(q),
    ).toList();
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: 800,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _c1.withOpacity(0.14),
                blurRadius: 48,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildPasoIndicador(),
                Flexible(child: _buildCuerpo()),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────
  Widget _buildHeader() {
    final titulos = {
      _Paso.seleccionar:   'Importar desde Excel',
      _Paso.previsualizar: _nombreArchivo ?? 'Vista previa',
      _Paso.resultado:     'Resultado de importación',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_c1, _c2],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.table_chart_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulos[_paso]!,
              style: _jakSans(size: 16, weight: FontWeight.w800,
                  color: Colors.white),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.storefront_rounded,
                  size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(widget.nombreTienda,
                style: _jakSans(size: 12,
                    color: Colors.white.withOpacity(0.75),
                    weight: FontWeight.w500)),
            ]),
          ],
        )),
        if (_paso == _Paso.previsualizar && !_cargando) ...[
          _chip('${_filas.length} listos', _grn),
          if (_filasError.isNotEmpty) ...[
            const SizedBox(width: 6),
            _chip('${_filasError.length} errores', _red),
          ],
          const SizedBox(width: 8),
        ],
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Colors.white, size: 20),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.pop(context,
            _resultado != null && (_resultado!['creados'] ?? 0) > 0),
        ),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.22),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.45)),
    ),
    child: Text(label,
      style: _jakSans(size: 11, weight: FontWeight.w700,
          color: Colors.white)),
  );

  // ── Indicador de pasos ─────────────────────────────────
  Widget _buildPasoIndicador() {
    const pasos = ['Seleccionar', 'Vista previa', 'Resultado'];
    final idx   = _paso.index;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        children: List.generate(pasos.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = (i ~/ 2) < idx;
            return Expanded(child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 2,
              color: done ? _c1 : _slate200,
            ));
          }
          final pIdx   = i ~/ 2;
          final active = pIdx == idx;
          final done   = pIdx < idx;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: done || active ? _c1 : Colors.white,
                border: Border.all(
                  color: done || active ? _c1 : _slate200, width: 2),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text('${pIdx + 1}',
                    style: _jakSans(size: 11, weight: FontWeight.w800,
                        color: active ? Colors.white : _slate400))),
            ),
            const SizedBox(width: 6),
            Text(pasos[pIdx],
              style: _jakSans(size: 12, weight: FontWeight.w700,
                  color: active ? _c1 : done ? _slate500 : _slate400)),
          ]);
        }),
      ),
    );
  }

  // ── Cuerpo ─────────────────────────────────────────────
  Widget _buildCuerpo() {
    if (_cargando) return _loadingView();
    return switch (_paso) {
      _Paso.seleccionar   => _vistaSeleccionar(),
      _Paso.previsualizar => _vistaPrevisualizar(),
      _Paso.resultado     => _vistaResultado(),
    };
  }

  // ── Vista 1: Seleccionar ───────────────────────────────
  Widget _vistaSeleccionar() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      GestureDetector(
        onTap: _seleccionarArchivo,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 44),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _c1.withOpacity(0.28), width: 2),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: Column(children: [
              Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_c1, _c2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                    color: _c1.withOpacity(0.38),
                    blurRadius: 18, offset: const Offset(0, 8),
                  )],
                ),
                child: const Icon(Icons.upload_file_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              Text('Haz clic para seleccionar tu archivo',
                style: _jakSans(size: 16, weight: FontWeight.w800,
                    color: _slate900)),
              const SizedBox(height: 6),
              Text('Formatos aceptados: .xlsx  ·  .xls',
                style: _jakSans(size: 13, color: _slate400)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _slate200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _c1.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: _c1, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Columnas reconocidas automáticamente',
              style: _jakSans(size: 13, weight: FontWeight.w700,
                  color: _slate900)),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _colTag('nombre *', true),
            _colTag('categoria', false),
            _colTag('precio_venta', false),
            _colTag('precio_compra', false),
            _colTag('stock_actual', false),
            _colTag('stock_minimo', false),
            _colTag('codigo_barras', false),
            _colTag('descripcion', false),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _c1.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.auto_fix_high_rounded, color: _c1, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Reconocemos variaciones: mayúsculas, minúsculas, tildes, '
                'espacios y nombres similares (ej. "Precio de Venta", "COSTO", "SKU").',
                style: _jakSans(size: 11, color: _c1),
              )),
            ]),
          ),
        ]),
      ),
    ]),
  );

  Widget _colTag(String label, bool required) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: required ? _c1.withOpacity(0.08) : _slate50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
          color: required ? _c1.withOpacity(0.3) : _slate200),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (required)
        const Padding(padding: EdgeInsets.only(right: 4),
          child: Icon(Icons.star_rounded, size: 10, color: _c1)),
      Text(label,
        style: _jakSans(size: 12, weight: FontWeight.w700,
            color: required ? _c1 : _slate500)),
    ]),
  );

  // ── Vista 2: Previsualizar ─────────────────────────────
  Widget _vistaPrevisualizar() {
    final filtradas = _filasFiltradas;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _busCtrl,
              onChanged: (v) => setState(() => _busqueda = v),
              style: _jakSans(size: 13, color: _slate900),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, categoría o código…',
                hintStyle: _jakSans(size: 13, color: _slate400),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _slate400, size: 18),
                suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _slate400, size: 16),
                      onPressed: () => setState(() {
                        _busqueda = '';
                        _busCtrl.clear();
                      }))
                  : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _slate200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _c1, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _slate200),
            ),
            child: Text('${filtradas.length} / ${_filas.length}',
              style: _jakSans(size: 13, weight: FontWeight.w700, color: _c1)),
          ),
        ]),
      ),

      if (_filasError.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _red.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${_filasError.length} fila(s) con errores no se importarán.',
              style: _jakSans(size: 12, weight: FontWeight.w600, color: _red))),
          ]),
        ),

      const SizedBox(height: 12),

      Expanded(
        child: filtradas.isEmpty
          ? _emptySearch()
          : Column(children: [
              _tablaHeader(),
              const Divider(height: 1, color: _slate100),
              Expanded(child: ListView.builder(
                itemCount: filtradas.length,
                itemBuilder: (_, i) => _tablaFila(filtradas[i], i),
              )),
            ]),
      ),
    ]);
  }

  Widget _emptySearch() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_off_rounded, color: _slate200, size: 48),
      const SizedBox(height: 12),
      Text('Sin resultados para "$_busqueda"',
        style: _jakSans(size: 14, color: _slate400)),
    ]),
  );

  Widget _tablaHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    color: _slate50,
    child: Row(children: [
      _th('#',         flex: 1),
      _th('Nombre',    flex: 3),
      _th('Categoría', flex: 2),
      _th('P. Venta',  flex: 2),
      _th('P. Compra', flex: 2),
      _th('Stock',     flex: 1),
      _th('Código',    flex: 2),
    ]),
  );

  Widget _th(String t, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(t, style: _jakSans(size: 11, weight: FontWeight.w700,
        color: _slate400, letterSpacing: 0.4)),
  );

  Widget _tablaFila(Map<String, dynamic> f, int idx) {
    final hasCode = (f['codigo_barras'] as String).isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        color: idx.isEven ? Colors.white : _slate50,
        border: const Border(bottom: BorderSide(color: _slate100)),
      ),
      child: Row(children: [
        Expanded(flex: 1, child: Text('${f['fila']}',
          style: _jakSans(size: 11, color: _slate400))),
        Expanded(flex: 3, child: Text(f['nombre'] ?? '',
          overflow: TextOverflow.ellipsis,
          style: _jakSans(size: 13, weight: FontWeight.w700,
              color: _slate900))),
        Expanded(flex: 2, child:
          (f['categoria_nombre'] as String).isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _c2.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(f['categoria_nombre'],
                  overflow: TextOverflow.ellipsis,
                  style: _jakSans(size: 11, weight: FontWeight.w700,
                      color: _c2)))
            : Text('—', style: _jakSans(size: 12, color: _slate400))),
        Expanded(flex: 2, child: Text(
          '\$${(f['precio_venta'] as num).toStringAsFixed(0)}',
          style: _jakSans(size: 12, weight: FontWeight.w700,
              color: _slate900))),
        Expanded(flex: 2, child: Text(
          '\$${(f['precio_compra'] as num).toStringAsFixed(0)}',
          style: _jakSans(size: 12, color: _slate500))),
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _c1.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${(f['stock_actual'] as num).toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: _jakSans(size: 12, weight: FontWeight.w700, color: _c1)))),
        Expanded(flex: 2, child: Text(
          hasCode ? f['codigo_barras'] : 'Auto',
          overflow: TextOverflow.ellipsis,
          style: _jakSans(size: 11,
              color: hasCode ? _slate500 : _slate400))),
      ]),
    );
  }

  // ── Vista 3: Resultado ─────────────────────────────────
  Widget _vistaResultado() {
    final data         = _resultado ?? {};
    final creados      = (data['creados']  as int?) ?? 0;
    final fallidos     = (data['fallidos'] as int?) ?? 0;
    final total        = (data['total']   as int?) ?? 0;
    final resultados   = (data['resultados'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final fallidosList = resultados.where((r) => r['success'] != true).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: creados > 0
              ? [_grn.withOpacity(0.08), _grn.withOpacity(0.02)]
              : [_red.withOpacity(0.08), _red.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: (creados > 0 ? _grn : _red).withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: (creados > 0 ? _grn : _red).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                creados > 0
                  ? Icons.check_circle_rounded
                  : Icons.error_rounded,
                color: creados > 0 ? _grn : _red, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creados > 0
                    ? '¡Importación completada!'
                    : 'No se importó ningún producto',
                  style: _jakSans(size: 15, weight: FontWeight.w800,
                      color: creados > 0 ? _grn : _red)),
                const SizedBox(height: 4),
                Text(
                  fallidos > 0
                    ? '$creados de $total productos importados con éxito.'
                    : 'Todos los $total productos fueron importados.',
                  style: _jakSans(size: 13, color: _slate500)),
              ],
            )),
          ]),
        ),

        const SizedBox(height: 16),

        Row(children: [
          _resumenCard(creados,  'Creados',  _grn, Icons.check_circle_rounded),
          const SizedBox(width: 12),
          _resumenCard(fallidos, 'Fallidos', _red, Icons.cancel_rounded),
          const SizedBox(width: 12),
          _resumenCard(total,    'Total',    _c1,  Icons.table_rows_rounded),
        ]),

        if (fallidosList.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _red.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: _red, size: 18),
                  const SizedBox(width: 8),
                  Text('Filas no importadas',
                    style: _jakSans(size: 14, weight: FontWeight.w800,
                        color: _slate900)),
                ]),
                const SizedBox(height: 12),
                ...fallidosList.map((f) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Fila ${f['fila']}',
                          style: _jakSans(size: 11, weight: FontWeight.w700,
                              color: _red))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f['nombre'] ?? '',
                            style: _jakSans(size: 13, weight: FontWeight.w700,
                                color: _slate900)),
                          const SizedBox(height: 3),
                          Text(f['error'] ?? '',
                            style: _jakSans(size: 12, color: _red)),
                        ],
                      )),
                    ]),
                )),
              ]),
          ),
        ],
      ]),
    );
  }

  Widget _resumenCard(int value, String label, Color color, IconData icon) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(
          color: color.withOpacity(0.08),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Column(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text('$value',
          style: _jakSans(size: 30, weight: FontWeight.w800, color: color)),
        Text(label,
          style: _jakSans(size: 13, weight: FontWeight.w600, color: _slate400)),
      ]),
    ));

  // ── Loading ────────────────────────────────────────────
  Widget _loadingView() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_c1, _c2]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: _c1.withOpacity(0.35),
              blurRadius: 20, offset: const Offset(0, 8),
            )],
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          ),
        ),
        const SizedBox(height: 20),
        Text(_msgCarga,
          style: _jakSans(size: 14, weight: FontWeight.w600, color: _slate400)),
        const SizedBox(height: 6),
        Text('Por favor espera…',
          style: _jakSans(size: 12, color: _slate400)),
      ]),
    ),
  );

  // ── Footer ─────────────────────────────────────────────
  Widget _buildFooter() => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _slate100)),
    ),
    child: Row(children: [
      if (_paso == _Paso.previsualizar && !_cargando)
        TextButton.icon(
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text('Cambiar archivo',
            style: _jakSans(size: 13, weight: FontWeight.w700,
                color: _slate400)),
          onPressed: () => _cambiarPaso(() {
            _paso = _Paso.seleccionar;
            _filas.clear();
            _filasError.clear();
            _nombreArchivo = null;
            _busqueda = '';
            _busCtrl.clear();
          }),
          style: TextButton.styleFrom(foregroundColor: _slate400),
        ),
      const Spacer(),
      if (!_cargando) ...[
        if (_paso == _Paso.seleccionar)
          _btnPrimario(label: 'Seleccionar Excel',
              icon: Icons.upload_file_rounded, onTap: _seleccionarArchivo),
        if (_paso == _Paso.previsualizar && _filas.isNotEmpty)
          _btnPrimario(label: 'Importar ${_filas.length} productos',
              icon: Icons.cloud_upload_rounded, onTap: _importar),
        if (_paso == _Paso.resultado)
          _btnPrimario(label: 'Cerrar', icon: Icons.check_rounded,
              onTap: () => Navigator.pop(context,
                  (_resultado?['creados'] ?? 0) > 0)),
      ],
    ]),
  );

  Widget _btnPrimario({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
    Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_c1, _c2]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: _c1.withOpacity(0.38),
          blurRadius: 14, offset: const Offset(0, 5),
        )],
      ),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label,
          style: _jakSans(size: 14, weight: FontWeight.w700,
              color: Colors.white)),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
}