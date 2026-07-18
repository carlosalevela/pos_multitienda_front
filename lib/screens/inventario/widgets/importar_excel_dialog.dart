// lib/screens/inventario/widgets/importar_excel_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/inventario_provider.dart';
import '../../../utils/file_downloader.dart';

// ── Design tokens (consistentes con inventario_screen) ────
const _text    = Color(0xFF191C1E);
const _muted   = Color(0xFF45464D);
const _muted2  = Color(0xFF76777D);
const _border  = Color(0xFFC6C6CD);
const _surfLow = Color(0xFFF2F4F6);
const _green   = Color(0xFF006C49);
const _greenBg = Color(0xFFE6F4EE);
const _danger  = Color(0xFFBA1A1A);
const _dangerBg = Color(0xFFFFDAD6);

TextStyle _inter({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _muted,
  double? letterSpacing,
}) =>
    GoogleFonts.inter(
      fontSize:      size,
      fontWeight:    weight,
      color:         color,
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

  List<Map<String, dynamic>> _filas      = [];
  List<Map<String, dynamic>> _filasError = [];
  bool                       _cargando   = false;
  String                     _msgCarga   = '';
  Map<String, dynamic>?      _resultado;

  List<int>? _bytesArchivo;
  String     _nombreArchivoRaw = '';

  String _busqueda = '';
  late final TextEditingController _busCtrl;

  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  // ══════════════════════════════════════════════════════
  // MAPEO DE COLUMNAS
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
    'precio_mayoreo': [
      'precio_mayoreo', 'mayoreo', 'precio_mayor', 'precio_al_por_mayor',
      'precio_mayorista', 'mayorista', 'wholesale', 'wholesale_price',
      'p_mayoreo', 'precio_por_mayor',
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
  // NORMALIZACIÓN Y MATCHING
  // ══════════════════════════════════════════════════════
  String _norm(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\(\)\[\]\{\}\.\:\;\/\\\-\+\*\#\@\!\?\=\%\&\|]'), ' ')
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'),   'e')
      .replaceAll(RegExp(r'[ìíîï]'),   'i')
      .replaceAll(RegExp(r'[òóôõö]'),  'o')
      .replaceAll(RegExp(r'[ùúûü]'),   'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  bool _matchAlias(String rawHeader, List<String> aliases) {
    final h = _norm(rawHeader);
    if (h.isEmpty) return false;
    for (final alias in aliases) {
      final a = alias;
      if (h == a) return true;
      if (h.contains(a)) return true;
      if (a.contains(h)) return true;
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
  // LECTURA DE CELDAS
  // ══════════════════════════════════════════════════════
  String _readCell(Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v == null) return '';
    if (v is TextCellValue)     return v.value.toString().trim();
    if (v is IntCellValue)      return v.value.toString().trim();
    if (v is DoubleCellValue) {
      final d = v.value;
      return (d == d.truncateToDouble())
          ? d.truncate().toString()
          : d.toString().trim();
    }
    if (v is BoolCellValue)     return v.value.toString().trim();
    if (v is DateCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2,'0')}-${v.day.toString().padLeft(2,'0')}';
    }
    if (v is DateTimeCellValue) return v.asDateTimeUtc().toIso8601String();
    if (v is TimeCellValue)     return v.toString().trim();
    final raw   = v.toString().trim();
    final match = RegExp(r'^[A-Za-z]+CellValue\((.+)\)$').firstMatch(raw);
    if (match != null) return match.group(1)?.trim() ?? '';
    return raw;
  }

  // ══════════════════════════════════════════════════════
  // PARSEO DE NÚMEROS
  // ══════════════════════════════════════════════════════
  double _parseNum(String s) {
    if (s.isEmpty) return 0;
    String clean = s.replaceAll(RegExp(r'[^\d.,]'), '');
    if (clean.isEmpty) return 0;
    if (clean.contains(',') && clean.contains('.')) {
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      final parts = clean.split(',');
      if (parts.length == 2 && parts.last.length <= 2) {
        clean = clean.replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    }
    return double.tryParse(clean) ?? 0;
  }

  // ══════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════
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
  // LÓGICA DE IMPORTACIÓN (sin cambios)
  // ══════════════════════════════════════════════════════
  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() { _cargando = true; _msgCarga = 'Leyendo archivo…'; });

    _bytesArchivo     = result.files.single.bytes!.toList();
    _nombreArchivoRaw = result.files.single.name;

    try {
      final bytes = result.files.single.bytes!;
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) { _mostrarError('El archivo no tiene hojas de datos.'); return; }

      Sheet? sheet;
      for (final s in excel.tables.values) {
        if (s.rows.isNotEmpty) { sheet = s; break; }
      }
      if (sheet == null) { _mostrarError('El archivo está vacío.'); return; }

      final rows = sheet.rows;
      if (rows.length < 2) {
        _mostrarError('El archivo debe tener al menos encabezados y una fila de datos.');
        return;
      }

      int headerRowIdx     = 0;
      List<String> headers = [];
      for (int ri = 0; ri < rows.length && ri < 10; ri++) {
        final candidatos = rows[ri].map(_readCell).toList();
        final matches    = candidatos.where((h) =>
          _mapa.entries.any((e) => _matchAlias(h, e.value))).length;
        if (matches >= 1) { headerRowIdx = ri; headers = candidatos; break; }
      }

      if (headers.isEmpty) {
        _mostrarError('No se reconoció ninguna columna. Asegúrate de que la fila 1 sea el encabezado.');
        return;
      }

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

      debugPrint('📊 Encabezados detectados: $headers');
      debugPrint('📌 Columnas mapeadas:      $colMap');

      if (!colMap.containsKey('nombre')) {
        _mostrarError(
          'No se encontró la columna "nombre".\n'
          'Detectados: ${headers.where((h) => h.isNotEmpty).join(', ')}',
        );
        return;
      }

      String cellStr(List<Data?> row, String campo) {
        final idx = colMap[campo];
        if (idx == null || idx >= row.length) return '';
        return _readCell(row[idx]);
      }

      final filas   = <Map<String, dynamic>>[];
      final errores = <Map<String, dynamic>>[];

      for (int i = headerRowIdx + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => _readCell(c).isEmpty)) continue;
        final nombre = cellStr(row, 'nombre');
        if (nombre.isEmpty) continue;

        final precioVenta   = _parseNum(cellStr(row, 'precio_venta'));
        final precioCompra  = _parseNum(cellStr(row, 'precio_compra'));
        final stockActual   = _parseNum(cellStr(row, 'stock_actual'));
        final stockMinimo   = _parseNum(cellStr(row, 'stock_minimo'));
        final rawMayoreo    = cellStr(row, 'precio_mayoreo');
        final precioMayoreo = rawMayoreo.isNotEmpty ? _parseNum(rawMayoreo) : null;

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
          'precio_mayoreo':   precioMayoreo,
        };

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
        _mostrarError('No se encontraron filas de datos válidas.');
        return;
      }

      _cambiarPaso(() {
        _filas         = filas;
        _filasError    = errores;
        _paso          = _Paso.previsualizar;
        _cargando      = false;
        _busqueda      = '';
        _busCtrl.clear();
      });

    } catch (e) {
      debugPrint('⚠️ Parseo local fallido, enviando al servidor: $e');
      await _importarDirecto();
    }
  }

  Future<void> _importarDirecto() async {
    if (_bytesArchivo == null) return;
    setState(() { _cargando = true; _msgCarga = 'Enviando archivo al servidor…'; });
    final inv = context.read<InventarioProvider>();
    final res = await inv.importarProductosExcel(
      fileBytes:  _bytesArchivo!,
      fileName:   _nombreArchivoRaw,
      tiendaId:   widget.tiendaId,
      empresaId:  widget.empresaId,
    );
    if (res['success'] != true) {
      setState(() => _cargando = false);
      _mostrarError(res['error'] ?? 'Error al conectar con el servidor');
      return;
    }
    _cambiarPaso(() {
      _cargando  = false;
      _resultado = res['data'] as Map<String, dynamic>?;
      _paso      = _Paso.resultado;
    });
  }

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
    if (res['success'] != true) {
      setState(() => _cargando = false);
      _mostrarError(res['error'] ?? 'Error al conectar con el servidor');
      return;
    }
    _cambiarPaso(() {
      _cargando  = false;
      _resultado = res['data'] as Map<String, dynamic>?;
      _paso      = _Paso.resultado;
    });
  }

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
      content: Text(msg, style: _inter(color: Colors.white, size: 12)),
      backgroundColor: _danger,
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SizedBox(
          width: 620,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  _buildStepper(),
                  Flexible(child: _buildCuerpo()),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════
  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.table_chart_rounded,
            color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Importar desde Excel',
              style: _inter(size: 17, weight: FontWeight.w700, color: _text)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.storefront_rounded, size: 12, color: _muted2),
            const SizedBox(width: 5),
            Text(widget.nombreTienda,
                style: _inter(size: 12, weight: FontWeight.w500,
                    color: _muted2)),
          ]),
        ],
      )),
      if (_paso == _Paso.previsualizar && !_cargando) ...[
        _statusChip('${_filas.length} listos', _green, _greenBg),
        if (_filasError.isNotEmpty) ...[
          const SizedBox(width: 6),
          _statusChip('${_filasError.length} errores', _danger, _dangerBg),
        ],
        const SizedBox(width: 8),
      ],
      InkWell(
        onTap: () => Navigator.pop(context,
            _resultado != null && (_resultado!['creados'] ?? 0) > 0),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close_rounded, size: 18, color: _muted),
        ),
      ),
    ]),
  );

  Widget _statusChip(String label, Color text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label,
        style: _inter(size: 11, weight: FontWeight.w700, color: text)),
  );

  // ══════════════════════════════════════════════════════
  // STEPPER
  // ══════════════════════════════════════════════════════
  Widget _buildStepper() {
    const pasos = ['Seleccionar', 'Vista previa', 'Resultado'];
    final idx   = _paso.index;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: Row(
        children: List.generate(pasos.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = (i ~/ 2) < idx;
            return Expanded(child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: done ? _green : _border,
                borderRadius: BorderRadius.circular(999),
              ),
            ));
          }
          final pIdx  = i ~/ 2;
          final active = pIdx == idx;
          final done   = pIdx < idx;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: done
                    ? _green
                    : active
                        ? const Color(0xFF131B2E)
                        : Colors.white,
                border: Border.all(
                  color: done || active ? Colors.transparent : _border,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(child: done
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14)
                : Text('${pIdx + 1}',
                    style: _inter(size: 12, weight: FontWeight.w700,
                        color: active ? Colors.white : _muted2))),
            ),
            const SizedBox(width: 8),
            Text(pasos[pIdx],
                style: _inter(size: 13, weight: FontWeight.w600,
                    color: active
                        ? _text
                        : done ? _green : _muted2)),
          ]);
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CUERPO
  // ══════════════════════════════════════════════════════
  Widget _buildCuerpo() {
    if (_cargando) return _loadingView();
    return switch (_paso) {
      _Paso.seleccionar   => _vistaSeleccionar(),
      _Paso.previsualizar => _vistaPrevisualizar(),
      _Paso.resultado     => _vistaResultado(),
    };
  }

  // ── Vista 1: Seleccionar ───────────────────────────────
  Future<void> _descargarPlantilla() async {
    final excel = Excel.createExcel();
    final sheet = excel['Inventario'];

    // Elimina la hoja por defecto que crea Excel.createExcel()
    excel.delete('Sheet1');

    // ── Headers ────────────────────────────────────────────
    const headers = [
      'nombre',
      'codigo_barras',
      'categoria',
      'precio_venta',
      'precio_compra',
      'precio_mayoreo',
      'stock_actual',
      'stock_minimo',
      'descripcion',
    ];

    const requeridos = {'nombre', 'precio_venta', 'stock_actual'};

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('FF006C49'),
      fontColorHex:       ExcelColor.fromHexString('FFFFFFFF'),
      bold:               true,
      fontSize:           11,
    );

    final reqStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('FF004030'),
      fontColorHex:       ExcelColor.fromHexString('FFFFFFFF'),
      bold:               true,
      fontSize:           11,
    );

    for (var i = 0; i < headers.length; i++) {
      final col  = headers[i];
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(
          requeridos.contains(col) ? '$col *' : col);
      cell.cellStyle = requeridos.contains(col) ? reqStyle : headerStyle;
      sheet.setColumnWidth(i, col == 'descripcion' ? 30 : 18);
    }

    // ── Fila de ejemplo ────────────────────────────────────
    const ejemplo = [
      'Camiseta Básica Blanca',
      '7501234567890',
      'Ropa',
      '45000',
      '22000',
      '38000',
      '50',
      '5',
      'Talla M, algodón 100%',
    ];

    final exampleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('FFE8FFF4'),
      fontColorHex:       ExcelColor.fromHexString('FF333333'),
      italic:             true,
    );

    for (var i = 0; i < ejemplo.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value      = TextCellValue(ejemplo[i]);
      cell.cellStyle  = exampleStyle;
    }

    // ── Fila de instrucciones ──────────────────────────────
    final instrCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
    instrCell.value = TextCellValue('← Fila de ejemplo — puedes borrarla y agregar tus productos desde la fila 3');
    instrCell.cellStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF888888'),
      italic:       true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
      CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: 2),
    );

    // Filas vacías para llenar (visual)
    for (var r = 3; r <= 22; r++) {
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.cellStyle = CellStyle(
          backgroundColorHex: r.isEven
              ? ExcelColor.fromHexString('FFFFFFFF')
              : ExcelColor.fromHexString('FFF7F9FB'),
        );
      }
    }

    final bytes = excel.save();
    if (bytes == null) return;

    await guardarArchivoExcel(bytes, 'plantilla_inventario.xlsx');
  }

  Widget _vistaSeleccionar() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      // Drop zone
      GestureDetector(
        onTap: _seleccionarArchivo,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: _surfLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 1.5,
                  style: BorderStyle.solid),
            ),
            child: Column(children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: _greenBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.cloud_upload_rounded,
                    color: _green, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Haz clic para seleccionar tu archivo',
                  style: _inter(size: 15, weight: FontWeight.w700,
                      color: _text)),
              const SizedBox(height: 6),
              Text('o arrastra y suelta tu archivo Excel aquí',
                  style: _inter(size: 13, color: _muted2)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.description_outlined,
                      size: 14, color: _muted2),
                  const SizedBox(width: 6),
                  Text('Formatos aceptados: .xlsx, .xls',
                      style: _inter(size: 12, color: _muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),

      const SizedBox(height: 14),

      // Descargar plantilla
      GestureDetector(
        onTap: _descargarPlantilla,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _greenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.download_rounded,
                    color: _green, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Descargar plantilla Excel',
                      style: _inter(size: 13, weight: FontWeight.w700,
                          color: _green)),
                  Text('Plantilla lista para llenar con tus productos',
                      style: _inter(size: 11, color: _muted2)),
                ],
              )),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: _muted2),
            ]),
          ),
        ),
      ),

      const SizedBox(height: 14),

      // Info columnas
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _greenBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: _green, size: 17),
            const SizedBox(width: 8),
            Text('Columnas reconocidas automáticamente',
                style: _inter(size: 13, weight: FontWeight.w700,
                    color: _green)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Asegúrate de que tu archivo contenga al menos las siguientes '
            'columnas obligatorias para una importación exitosa.',
            style: _inter(size: 12, color: _green.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _colChip('nombre *', required: true),
            _colChip('precio_venta *', required: true),
            _colChip('stock_actual *', required: true),
            _colChip('categoría'),
            _colChip('precio_compra'),
            _colChip('precio_mayoreo'),
            _colChip('stock_minimo'),
            _colChip('codigo_barras'),
            _colChip('descripcion'),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_fix_high_rounded,
                size: 13, color: _muted2),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Reconocemos variaciones: mayúsculas, minúsculas, tildes, '
              'espacios y nombres similares (ej. "Precio de Venta", '
              '"COSTO", "SKU").',
              style: _inter(size: 11, color: _muted),
            )),
          ]),
        ]),
      ),
    ]),
  );

  Widget _colChip(String label, {bool required = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: required
          ? _green.withValues(alpha: 0.1)
          : Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
          color: required
              ? _green.withValues(alpha: 0.4)
              : _border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (required) ...[
        const Icon(Icons.star_rounded, size: 10, color: _green),
        const SizedBox(width: 4),
      ],
      Text(label,
          style: _inter(size: 12, weight: FontWeight.w600,
              color: required ? _green : _muted)),
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
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _surfLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _busCtrl,
                onChanged: (v) => setState(() => _busqueda = v),
                style: _inter(size: 13, color: _text),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, categoría o código…',
                  hintStyle: _inter(size: 13, color: _muted2),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _muted2, size: 18),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: _muted2, size: 16),
                          onPressed: () => setState(() {
                            _busqueda = '';
                            _busCtrl.clear();
                          }))
                      : null,
                  border:        InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _surfLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Text('${filtradas.length} / ${_filas.length}',
                style: _inter(size: 13, weight: FontWeight.w700,
                    color: _text)),
          ),
        ]),
      ),

      if (_filasError.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _dangerBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _danger.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: _danger, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${_filasError.length} fila(s) con errores no se importarán.',
              style: _inter(size: 12, weight: FontWeight.w600, color: _danger))),
          ]),
        ),

      const SizedBox(height: 12),

      Expanded(
        child: filtradas.isEmpty
            ? _emptySearch()
            : Column(children: [
                _tablaHeader(),
                const Divider(height: 1, color: Color(0xFFE8EAED)),
                Expanded(child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtradas.length,
                  itemBuilder: (_, i) => _tablaFila(filtradas[i], i),
                )),
              ]),
      ),
    ]);
  }

  Widget _emptySearch() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_off_rounded, color: _border, size: 48),
      const SizedBox(height: 12),
      Text('Sin resultados para "$_busqueda"',
          style: _inter(size: 14, color: _muted2)),
    ]),
  );

  Widget _tablaHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    color: _surfLow,
    child: Row(children: [
      _th('#',         flex: 1),
      _th('Nombre',    flex: 3),
      _th('Categoría', flex: 2),
      _th('P. Venta',  flex: 2),
      _th('Stock',     flex: 1),
      _th('Código',    flex: 2),
    ]),
  );

  Widget _th(String t, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(t, style: _inter(size: 11, weight: FontWeight.w600,
        color: _muted2, letterSpacing: 0.4)),
  );

  Widget _tablaFila(Map<String, dynamic> f, int idx) {
    final hasCode = (f['codigo_barras'] as String).isNotEmpty;
    final cat     = f['categoria_nombre'] as String;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        color: idx.isEven ? Colors.white : _surfLow.withValues(alpha: 0.4),
        border: const Border(
            bottom: BorderSide(color: Color(0xFFF0F0F2))),
      ),
      child: Row(children: [
        Expanded(flex: 1, child: Text('${f['fila']}',
            style: _inter(size: 11, color: _muted2))),
        Expanded(flex: 3, child: Text(f['nombre'] ?? '',
            overflow: TextOverflow.ellipsis,
            style: _inter(size: 13, weight: FontWeight.w600, color: _text))),
        Expanded(flex: 2, child: cat.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(cat, overflow: TextOverflow.ellipsis,
                    style: _inter(size: 11, weight: FontWeight.w600,
                        color: _muted)))
            : Text('—', style: _inter(size: 12, color: _muted2))),
        Expanded(flex: 2, child: Text(
            '\$${(f['precio_venta'] as num).toStringAsFixed(0)}',
            style: _inter(size: 12, weight: FontWeight.w700, color: _text))),
        Expanded(flex: 1, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _greenBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              (f['stock_actual'] as num).toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: _inter(size: 12, weight: FontWeight.w700, color: _green)))),
        Expanded(flex: 2, child: Text(
            hasCode ? f['codigo_barras'] : 'Auto',
            overflow: TextOverflow.ellipsis,
            style: _inter(size: 11,
                color: hasCode ? _muted : _muted2))),
      ]),
    );
  }

  // ── Vista 3: Resultado ─────────────────────────────────
  Widget _vistaResultado() {
    final data         = _resultado ?? {};
    final creados      = (data['creados']  as int?) ?? 0;
    final fallidos     = (data['fallidos'] as int?) ?? 0;
    final total        = (data['total']    as int?) ?? 0;
    final resultados   = (data['resultados'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final fallidosList = resultados.where((r) => r['success'] != true).toList();
    final exito        = creados > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // Banner resultado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: exito ? _greenBg : _dangerBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: (exito ? _green : _danger).withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: exito ? _green : _danger,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                exito
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exito
                      ? '¡Importación completada!'
                      : 'No se importó ningún producto',
                  style: _inter(size: 15, weight: FontWeight.w700,
                      color: exito ? _green : _danger)),
                const SizedBox(height: 3),
                Text(
                  fallidos > 0
                      ? '$creados de $total productos importados.'
                      : 'Todos los $total productos fueron importados.',
                  style: _inter(size: 13, color: _muted)),
              ],
            )),
          ]),
        ),

        const SizedBox(height: 16),

        // Cards resumen
        Row(children: [
          _resumenCard(creados,  'Creados',  _green,   Icons.check_circle_rounded),
          const SizedBox(width: 12),
          _resumenCard(fallidos, 'Fallidos', _danger,  Icons.cancel_rounded),
          const SizedBox(width: 12),
          _resumenCard(total,    'Total',    _text,    Icons.table_rows_rounded),
        ]),

        // Errores detalle
        if (fallidosList.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _danger.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: _danger, size: 17),
                const SizedBox(width: 8),
                Text('Filas no importadas',
                    style: _inter(size: 14, weight: FontWeight.w700,
                        color: _text)),
              ]),
              const SizedBox(height: 12),
              ...fallidosList.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _dangerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Fila ${f['fila']}',
                          style: _inter(size: 11, weight: FontWeight.w700,
                              color: _danger))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f['nombre'] ?? '',
                            style: _inter(size: 13, weight: FontWeight.w600,
                                color: _text)),
                        const SizedBox(height: 3),
                        Text(f['error'] ?? '',
                            style: _inter(size: 12, color: _danger)),
                      ],
                    )),
                  ],
                ),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _resumenCard(int value, String label, Color color, IconData icon) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text('$value',
              style: _inter(size: 28, weight: FontWeight.w700, color: color)),
          Text(label,
              style: _inter(size: 12, weight: FontWeight.w600, color: _muted)),
        ]),
      ));

  // ── Loading ────────────────────────────────────────────
  Widget _loadingView() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.all(15),
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          ),
        ),
        const SizedBox(height: 18),
        Text(_msgCarga,
            style: _inter(size: 14, weight: FontWeight.w600, color: _text)),
        const SizedBox(height: 4),
        Text('Por favor espera…',
            style: _inter(size: 12, color: _muted2)),
      ]),
    ),
  );

  // ══════════════════════════════════════════════════════
  // FOOTER
  // ══════════════════════════════════════════════════════
  Widget _buildFooter() => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE8EAED))),
    ),
    child: Row(children: [
      if (_paso == _Paso.previsualizar && !_cargando)
        TextButton.icon(
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text('Cambiar archivo',
              style: _inter(size: 13, weight: FontWeight.w600, color: _muted)),
          onPressed: () => _cambiarPaso(() {
            _paso = _Paso.seleccionar;
            _filas.clear();
            _filasError.clear();
            _busqueda = '';
            _busCtrl.clear();
          }),
          style: TextButton.styleFrom(foregroundColor: _muted),
        ),
      const Spacer(),
      if (!_cargando) ...[
        if (_paso != _Paso.resultado)
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _muted,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cancelar',
                style: _inter(size: 13, weight: FontWeight.w600,
                    color: _muted)),
          ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: switch (_paso) {
            _Paso.seleccionar   => _seleccionarArchivo,
            _Paso.previsualizar => _filas.isNotEmpty ? _importar : null,
            _Paso.resultado     => () => Navigator.pop(context,
                (_resultado?['creados'] ?? 0) > 0),
          },
          icon: Icon(switch (_paso) {
            _Paso.seleccionar   => Icons.upload_file_rounded,
            _Paso.previsualizar => Icons.cloud_upload_rounded,
            _Paso.resultado     => Icons.check_rounded,
          }, size: 17),
          label: Text(switch (_paso) {
            _Paso.seleccionar   => 'Seleccionar Excel',
            _Paso.previsualizar => 'Importar ${_filas.length} productos',
            _Paso.resultado     => 'Cerrar',
          }, style: _inter(size: 13, weight: FontWeight.w700,
              color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ]),
  );
}
