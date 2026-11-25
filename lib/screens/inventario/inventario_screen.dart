// lib/screens/inventario/inventario_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/file_downloader.dart';
import '../../utils/numero_excel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/inventario_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';
import '../../models/producto.dart';
import '../../models/separado.dart';
import '../../services/empleado_service.dart';
import '../../services/inventario_service.dart';
import '../../services/barcode_service.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../services/cliente_service.dart';
import 'widgets/producto_form_dialog.dart';
import 'widgets/importar_excel_dialog.dart';
import 'widgets/averias_dialog.dart';
import 'widgets/producto_detalle_sheet.dart';
import 'widgets/camera_scanner_sheet.dart';
import 'widgets/inventario_movil.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen>
    with TickerProviderStateMixin {
  final _searchCtrl      = TextEditingController();
  final _empleadoService = EmpleadoService();
  final _service         = InventarioService();

  List<Map<String, dynamic>> _tiendas     = [];
  int?                       _tiendaFiltro;
  String                     _activoFiltro = 'true';
  int?                       _hoveredRow;
  bool                       _exportando = false;

  // Filtros avanzados
  int?    _filtCategoriaId;
  String? _filtCategoriaName;
  double? _filtPrecioMin;
  double? _filtPrecioMax;
  String? _filtAlerta; // null | 'bajo' | 'agotado' | 'con_averias'
  String  _filtOrden = 'nombre'; // celular: ordenesInventario
  bool get _hayFiltrosActivos =>
      _filtCategoriaId != null ||
      _filtPrecioMin   != null ||
      _filtPrecioMax   != null ||
      _filtAlerta      != null;

  // Insights panel data
  Map<String, dynamic>?      _dashboard;
  List<Map<String, dynamic>> _topProductos     = [];
  List<Map<String, dynamic>> _movimientos      = [];
  List<Map<String, dynamic>> _alertasAgotado   = [];
  List<Map<String, dynamic>> _alertasBajo      = [];
  bool                       _cargandoInsights = false;

  // Cajero panel data
  List<Separado> _separadosActivos   = [];
  bool           _cargandoCajeroPanel = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // Barcode scanner
  StreamSubscription<String>? _barcodeSub;
  bool   _scanActivo    = false;
  Timer? _scanPulseTimer;

  // KPI carrusel (móvil)
  final PageController _kpiPageCtrl = PageController(viewportFraction: 0.46);
  int _kpiPage = 0;

  // ── Design tokens ──────────────────────────────────────
  static const _bg       = Color(0xFFF7F9FB);
  static const _surface  = Colors.white;
  static const _border   = Color(0xFFC6C6CD);
  static const _text     = Color(0xFF191C1E);
  static const _muted    = Color(0xFF45464D);
  static const _muted2   = Color(0xFF76777D);
  static const _green    = Color(0xFF006C49);
  static const _greenBg  = Color(0xFF6CF8BB);
  static const _danger   = Color(0xFFBA1A1A);
  static const _dangerBg = Color(0xFFFFDAD6);
  static const _warning  = Color(0xFFF59E0B);
  static const _surfLow  = Color(0xFFF2F4F6);
  static const _surfHigh = Color(0xFFE6E8EA);

  TextStyle _t({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize:      size,
        fontWeight:    weight,
        color:         color ?? _text,
        letterSpacing: letterSpacing,
        height:        height,
      );

  // ══════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _barcodeSub = BarcodeService.instance.onBarcode.listen(_onBarcode);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final inv  = context.read<InventarioProvider>();

      if (auth.rol == 'admin' || auth.rol == 'superadmin') {
        final tiendas = await _empleadoService.getTiendas();
        if (!mounted) return;
        setState(() {
          _tiendas      = tiendas;
          _tiendaFiltro = tiendas.isNotEmpty ? tiendas.first['id'] : null;
        });
        inv.cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro);
      } else {
        inv.cargarProductos(
          tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
          activo:   _activoFiltro,
        );
      }
      _cargarInsights();
      if (auth.rol == 'cajero') _cargarPanelCajero();
    });
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _scanPulseTimer?.cancel();
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    _kpiPageCtrl.dispose();
    super.dispose();
  }

  void _onBarcode(String codigo) {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _searchCtrl.text = codigo;
    context.read<InventarioProvider>().cargarProductos(
      q: codigo, tiendaId: _tiendaActiva, activo: _activoFiltro,
    );
    setState(() => _scanActivo = true);
    _scanPulseTimer?.cancel();
    _scanPulseTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scanActivo = false);
    });
  }

  Future<void> _abrirCameraScanner() async {
    if (!Platform.isAndroid) return;
    await showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => CameraScannerSheet(onDetect: _onBarcode),
    );
  }

  // ══════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int)    return v;
    if (v is num)    return v.toInt();
    if (v is String) return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? 0);
    return 0;
  }

  int? get _tiendaActiva {
    final auth = context.read<AuthProvider>();
    if (auth.rol == 'admin' || auth.rol == 'superadmin') return _tiendaFiltro;
    return auth.tiendaId == 0 ? null : auth.tiendaId;
  }

  int? get _empresaActiva {
    if (_tiendaFiltro == null) return null;
    final t   = _tiendas.where((t) => t['id'] == _tiendaFiltro).firstOrNull;
    final raw = t?['empresa'];
    if (raw is int)    return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String _nombreTiendaActual() {
    if (_tiendaFiltro == null) return 'Todas las tiendas';
    final t = _tiendas.where((t) => t['id'] == _tiendaFiltro).firstOrNull;
    return t?['nombre'] ?? 'Tienda';
  }

  Future<void> _cargarInsights() async {
    setState(() => _cargandoInsights = true);
    try {
      final results = await Future.wait([
        _service.getDashboard(tiendaId: _tiendaActiva, empresaId: _empresaActiva),
        _service.getTopProductos(tiendaId: _tiendaActiva, limite: 5),
        _service.getMovimientosRecientes(tiendaId: _tiendaActiva, limite: 8),
        _service.getInventario(tiendaId: _tiendaActiva, alerta: 'agotado'),
        _service.getInventario(tiendaId: _tiendaActiva, alerta: 'bajo'),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard      = results[0]['data'] as Map<String, dynamic>?;
        _topProductos   = (results[1]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _movimientos    = (results[2]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _alertasAgotado = (results[3]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _alertasBajo    = (results[4]['data'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _cargandoInsights = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoInsights = false);
    }
  }

  Future<void> _cargarPanelCajero() async {
    if (!mounted) return;
    setState(() => _cargandoCajeroPanel = true);
    final tid = context.read<AuthProvider>().tiendaId;
    try {
      final seps = await ClienteService().getSeparados(
        tiendaId: tid > 0 ? tid : null,
        estado: 'activo',
      );
      if (mounted) setState(() => _separadosActivos = seps);
    } catch (_) {}
    if (mounted) setState(() => _cargandoCajeroPanel = false);
  }

  Color _avatarColor(String nombre) {
    const cols = [
      Color(0xFF6366F1), Color(0xFF0891B2), Color(0xFF059669),
      Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF7C3AED),
      Color(0xFF0284C7), Color(0xFF16A34A),
    ];
    if (nombre.isEmpty) return cols[0];
    return cols[nombre.codeUnitAt(0) % cols.length];
  }

  String _formatNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  String _tiempoRelativo(String? iso) {
    if (iso == null) return '';
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60)  return 'hace ${diff.inMinutes}m';
      if (diff.inHours   < 24)  return 'hace ${diff.inHours}h';
      if (diff.inDays    < 7)   return 'hace ${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  // ══════════════════════════════════════════════════════
  void _abrirDetalleDesdeAlerta(int? productoId, String nombre) {
    final inv    = context.read<InventarioProvider>();
    final esAdmin = context.read<AuthProvider>().rol == 'admin' ||
        context.read<AuthProvider>().rol == 'superadmin';
    // Buscar en la lista ya cargada
    final p = productoId != null
        ? inv.productos.where((p) => p.id == productoId).firstOrNull
        : null;
    if (p != null) {
      ProductoDetalleSheet.show(context,
        producto:     p,
        esAdmin:      esAdmin,
        onEditar:     esAdmin ? () => _abrirFormulario(context, inv, producto: p) : null,
        onKardex:     () => _abrirKardex(p),
        onAjuste:     !esAdmin ? null : () => _abrirAjuste(p),
        onTransferir: (esAdmin && _tiendas.length >= 2)
            ? () => _abrirTransferencia(p) : null,
      );
    } else {
      // Fallback: filtrar lista por nombre
      setState(() => _searchCtrl.text = nombre);
      _aplicarFiltros();
    }
  }

  // DIALOGS
  // ══════════════════════════════════════════════════════
  void _abrirImportarExcel(InventarioProvider inv) {
    showDialog<bool>(
      context:          context,
      barrierDismissible: false,
      builder: (_) => ImportarExcelDialog(
        tiendaId:     _tiendaActiva ?? 0,
        empresaId:    _empresaActiva,
        nombreTienda: _nombreTiendaActual(),
      ),
    );
  }

  Future<void> _abrirAverias() async {
    await showDialog(
      context: context,
      builder: (_) => AveriasDialog(
        tiendaId:     _tiendaActiva,
        nombreTienda: _nombreTiendaActual(),
      ),
    );
    if (!mounted) return;
    context.read<InventarioProvider>().cargarProductos(
      tiendaId: _tiendaActiva,
      activo:   _activoFiltro,
    );
    _cargarInsights();
  }

  // ── Hojas del Excel: se recuerda lo último elegido ──────────
  // Celular: solo Inventario la primera vez (archivo liviano para
  // compartir). PC: las 4, como siempre fue.
  static const _prefHojasMovil = 'export_hojas_movil';
  static const _prefHojasPc    = 'export_hojas_pc';

  static Future<Set<String>> _leerHojas(String clave, Set<String> porDefecto) async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList(clave);
      return l == null ? porDefecto : l.where(hojasExtraExport.contains).toSet();
    } catch (_) {
      return porDefecto;
    }
  }

  static Future<void> _guardarHojas(String clave, Set<String> hojas) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(clave, hojas.toList());
    } catch (_) {}
  }

  /// Diálogo del PC para elegir las hojas. null si cancela.
  Future<Set<String>?> _elegirHojasPc() async {
    final sel = await _leerHojas(_prefHojasPc, hojasExtraExport.toSet());
    if (!mounted) return null;
    const nombres = {
      'averias': ('Averías', 'Productos con unidades dañadas y su pérdida'),
      'danos':   ('Historial de daños', 'Últimos 500 reportes de avería'),
      'ajustes': ('Ajustes y transferencias', 'Últimos 500 movimientos manuales'),
    };
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Exportar inventario a Excel'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CheckboxListTile(
                value: true,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
                title: Text('Inventario'),
                subtitle: Text('Siempre se incluye'),
              ),
              for (final h in hojasExtraExport)
                CheckboxListTile(
                  value: sel.contains(h),
                  activeColor: _green,
                  contentPadding: EdgeInsets.zero,
                  title: Text(nombres[h]!.$1),
                  subtitle: Text(nombres[h]!.$2),
                  onChanged: (v) => setD(() => v == true ? sel.add(h) : sel.remove(h)),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _green),
              onPressed: () => Navigator.pop(ctx, Set.of(sel)),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Exportar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportarExcel() async {
    final hojas = await _elegirHojasPc();
    if (hojas == null || !mounted) return;
    await _guardarHojas(_prefHojasPc, hojas);
    if (!mounted) return;

    setState(() => _exportando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _service.exportarInventario(
        tiendaId:  _tiendaActiva,
        empresaId: _empresaActiva,
        activo:    _activoFiltro,
        hojas:     hojas,
      );

      if (result['success'] != true) {
        messenger.showSnackBar(SnackBar(
          content: Text(result['error'] ?? 'Error al exportar'),
          backgroundColor: _danger,
        ));
        return;
      }

      final bytes    = result['bytes'] as List<int>;
      final now      = DateTime.now();
      final stamp    = '${now.year}${now.month.toString().padLeft(2, '0')}'
                       '${now.day.toString().padLeft(2, '0')}';
      final fileName = 'inventario_$stamp.xlsx';

      final saved = await guardarArchivoExcel(bytes, fileName);

      messenger.showSnackBar(SnackBar(
        content: Text('Guardado: $saved'),
        backgroundColor: _green,
        duration: const Duration(seconds: 4),
      ));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  /// Exportar en el celular: hoja para elegir qué productos van, con el
  /// conteo del servidor, y al final un botón para abrir el archivo.
  Future<void> _abrirExportarMovil({required String tienda}) async {
    final tiendaId  = _tiendaActiva;
    final empresaId = _empresaActiva;

    final res = await _service.getCategorias(tiendaId: tiendaId);
    final hojas = await _leerHojas(_prefHojasMovil, const {});
    if (!mounted) return;
    final categorias = ((res['data'] as List?) ?? const [])
        .whereType<Map>()
        .where((c) => c['id'] is int)
        .map((c) => CategoriaMovil(
            c['id'] as int, (c['nombre'] ?? 'Categoría').toString()))
        .toList()
      ..sort((a, b) =>
          a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    await mostrarExportarMovil(context, (cerrar) => ExportarMovil(
          tienda: tienda,
          categorias: categorias,
          estadoInicial: _activoFiltro,
          lugar: lugarDelExcel,
          hojasIniciales: hojas,
          onHojas: (h) => _guardarHojas(_prefHojasMovil, h),
          onCerrar: cerrar,
          onContar: (categoriaId, estado) async {
            final r = await _service.contarExportacion(
              tiendaId: tiendaId,
              empresaId: empresaId,
              categoriaId: categoriaId,
              activo: estado,
            );
            if (r['success'] != true) {
              throw Exception(r['error'] ?? 'No se pudo contar los productos');
            }
            final data = r['data'] as Map<String, dynamic>;
            int n(Object? v) => (v as num? ?? 0).toInt();
            final extra = data['hojas'] is Map ? data['hojas'] as Map : const {};
            return ConteosExportMovil(
              {
                for (final k in const ['todos', 'bajo', 'agotado'])
                  if (data[k] is Map)
                    k: ConteoExportMovil(
                      n(data[k]['productos']),
                      (data[k]['valor'] as num? ?? 0).toDouble(),
                      averias: n(data[k]['averias']),
                    ),
              },
              danos: n(extra['danos']),
              ajustes: n(extra['ajustes']),
            );
          },
          onExportar: (f) async {
            final r = await _service.exportarInventario(
              tiendaId: tiendaId,
              empresaId: empresaId,
              activo: f.estado,
              alerta: f.alerta == 'todos' ? null : f.alerta,
              categoriaId: f.categoriaId,
              hojas: f.hojas,
            );
            if (r['success'] != true) {
              throw Exception(r['error'] ?? 'Error al exportar');
            }
            final bytes = r['bytes'] as List<int>;
            final nombre = _nombreExcel(f);
            final ruta = await guardarArchivoExcel(bytes, nombre);
            return ArchivoExportMovil(
                nombre: nombre, ruta: ruta, bytes: bytes.length);
          },
          onAbrir: kIsWeb ? null : (a) => abrirArchivo(a.ruta),
        ));
  }

  /// inventario_stock-bajo_bisuteria_20261125.xlsx
  static String _nombreExcel(FiltroExportMovil f) {
    String slug(String s) {
      const con = 'áéíóúüñÁÉÍÓÚÜÑ';
      const sin = 'aeiouunAEIOUUN';
      final b = StringBuffer();
      for (final ch in s.split('')) {
        final i = con.indexOf(ch);
        b.write(i >= 0 ? sin[i] : ch);
      }
      return b
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
    }

    final now = DateTime.now();
    final fecha = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final partes = [
      'inventario',
      if (f.alerta == 'bajo') 'stock-bajo',
      if (f.alerta == 'agotado') 'agotados',
      if (f.categoriaNombre != null && slug(f.categoriaNombre!).isNotEmpty)
        slug(f.categoriaNombre!),
      if (f.estado == 'false') 'inactivos',
      fecha,
    ];
    return '${partes.join('_')}.xlsx';
  }

  void _abrirFormulario(BuildContext ctx, InventarioProvider inv,
      {Producto? producto}) {
    showDialog(
      context: ctx,
      builder: (_) => ProductoFormDialog(
        producto:  producto,
        tiendaId:  _tiendaActiva ?? 0,
        empresaId: _empresaActiva,
        onGuardar: (data) async {
          producto == null
              ? await inv.crearProducto(data)
              : await inv.editarProducto(producto.id, data);
        },
      ),
    );
  }

  void _confirmarEliminar(
      BuildContext ctx, InventarioProvider inv, Producto p) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   Text('Desactivar producto',
            style: _t(size: 16, weight: FontWeight.w700)),
        content: Text(
          '¿Desactivar "${p.nombre}"? No aparecerá en ventas ni búsquedas.',
          style: _t(size: 13, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: _t(size: 13, color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await inv.eliminarProducto(p.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Desactivar',
                style: _t(size: 13, weight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarReactivar(
      BuildContext ctx, InventarioProvider inv, Producto p) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   Text('Reactivar producto',
            style: _t(size: 16, weight: FontWeight.w700)),
        content: Text('¿Reactivar "${p.nombre}"?',
            style: _t(size: 13, color: _muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: _t(size: 13, color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await inv.reactivarProducto(p.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reactivar',
                style: _t(size: 13, weight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final inv      = context.watch<InventarioProvider>();
    final auth     = context.watch<AuthProvider>();
    final esCajero    = auth.rol == 'cajero';
    final esAdmin     = auth.rol == 'admin' || auth.rol == 'superadmin';
    final esSupervisor = auth.rol == 'supervisor';
    final puedeGestionar = esAdmin || esSupervisor;

    // En celular va un diseño propio (widgets/inventario_movil.dart).
    // El de escritorio, con tabla y paneles laterales, no cabe en un
    // teléfono: partía los textos letra por letra.
    if (MediaQuery.sizeOf(context).width < 600) {
      return FadeTransition(
        opacity: _fadeAnim,
        child: _buildMovil(inv,
            esCajero: esCajero,
            esAdmin: esAdmin,
            puedeGestionar: puedeGestionar),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: _bg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(esCajero, esAdmin, inv),
              const SizedBox(height: 14),
              if (esAdmin && _tiendas.isNotEmpty) ...[
                _selectorTienda(),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (_, c) => c.maxWidth < 580
                    ? _buildKPICarousel(inv.productos, esCajero: esCajero)
                    : _buildKPIGrid(inv.productos, esCajero: esCajero),
              ),
              const SizedBox(height: 10),
              _buildAlertaBanner(),
              const SizedBox(height: 10),
              _buildToolbar(esCajero, inv),
              const SizedBox(height: 12),
              if (inv.successMsg != null)
                _banner(inv.successMsg!,
                    isError: false, onClose: inv.limpiarMensajes),
              if (inv.errorMsg != null)
                _banner(inv.errorMsg!,
                    isError: true, onClose: inv.limpiarMensajes),
              Expanded(
                child: LayoutBuilder(builder: (_, constraints) {
                  final mostrarPanel = constraints.maxWidth >= 780;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Tabla principal ──────────────────
                      Expanded(
                        flex: 3,
                        child: inv.cargando
                            ? _loadingState()
                            : inv.productos.isEmpty
                                ? _emptyState(esCajero)
                                : constraints.maxWidth < 580
                                    ? _buildListaMobile(inv.productos, esCajero, esAdmin, inv)
                                    : _buildTabla(inv.productos, esCajero, esAdmin, inv),
                      ),
                      // ── Panel insights (admin/supervisor) ─
                      if (puedeGestionar && mostrarPanel) ...[
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 280,
                          child: _buildInsightsPanel(),
                        ),
                      ],
                      // ── Panel turno (cajero) ──────────────
                      if (esCajero && mostrarPanel) ...[
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 280,
                          child: _buildCajeroPanel(inv.productos),
                        ),
                      ],
                    ],
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _seleccionarTienda(int? id) {
    if (_tiendaFiltro == id) return;
    setState(() {
      _tiendaFiltro      = id;
      _searchCtrl.clear();
      _filtCategoriaId   = null;
      _filtCategoriaName = null;
    });
    _aplicarFiltros();
    _cargarInsights();
    context.read<InventarioProvider>().cargarCategorias(tiendaId: id);
  }

  // ══════════════════════════════════════════════════════
  // MÓVIL
  // ══════════════════════════════════════════════════════

  Widget _buildMovil(
    InventarioProvider inv, {
    required bool esCajero,
    required bool esAdmin,
    required bool puedeGestionar,
  }) {
    final auth = context.read<AuthProvider>();

    // Un rango de precio cuenta como un solo filtro.
    final filtros = [
      _filtCategoriaId,
      _filtPrecioMin ?? _filtPrecioMax,
      _filtAlerta,
    ].where((f) => f != null).length;

    final accionesGestion = <AccionMovil>[
      AccionMovil(
          etiqueta: 'Nuevo producto',
          icono: Icons.add_box_rounded,
          tono: TonoMovil.verde,
          onTap: () => _abrirFormulario(context, inv)),
      AccionMovil(
          etiqueta: 'Gestionar averías',
          icono: Icons.warning_amber_rounded,
          tono: TonoMovil.ambar,
          onTap: _abrirAverias),
      if (_tiendaActiva != null)
        AccionMovil(
            etiqueta: 'Importar Excel',
            icono: Icons.upload_file_rounded,
            tono: TonoMovil.turquesa,
            onTap: () => _abrirImportarExcel(inv)),
      AccionMovil(
          etiqueta: 'Exportar Excel',
          icono: Icons.download_rounded,
          tono: TonoMovil.lima,
          onTap: () => _abrirExportarMovil(
              tienda: esAdmin ? _nombreTiendaActual() : auth.tiendaNombre)),
    ];

    return InventarioMovil(
      subtitulo: esAdmin ? _nombreTiendaActual() : auth.tiendaNombre,
      tiendas: esAdmin && _tiendas.length > 1
          ? [
              const TiendaMovil(null, 'Todas'),
              ..._tiendas.map((t) => TiendaMovil(
                  t['id'] as int?, t['nombre'] as String? ?? 'Tienda')),
            ]
          : const [],
      tiendaSeleccionada: _tiendaFiltro,
      onTienda: _seleccionarTienda,
      kpis: _kpisMovil(inv.productos, esCajero: esCajero),
      agotados: _alertasAgotado.length,
      bajos: _alertasBajo.length,
      onAlerta: () {
        setState(() => _filtAlerta =
            _alertasAgotado.isNotEmpty ? 'agotado' : 'bajo');
        _aplicarFiltros();
      },
      buscar: _searchCtrl,
      onBuscar: (_) => _aplicarFiltros(),
      filtrosActivos: filtros,
      onFiltros: () => _abrirFiltros(context),
      filtrosAplicados: [
        if (_filtAlerta != null)
          FiltroActivoMovil(alertasInventario[_filtAlerta] ?? _filtAlerta!, () {
            setState(() => _filtAlerta = null);
            _aplicarFiltros();
          }),
        if (_filtCategoriaId != null)
          FiltroActivoMovil(_filtCategoriaName ?? 'Categoría', () {
            setState(() {
              _filtCategoriaId = null;
              _filtCategoriaName = null;
            });
            _aplicarFiltros();
          }),
        if (_filtPrecioMin != null || _filtPrecioMax != null)
          FiltroActivoMovil(etiquetaPrecio(_filtPrecioMin, _filtPrecioMax), () {
            setState(() {
              _filtPrecioMin = null;
              _filtPrecioMax = null;
            });
            _aplicarFiltros();
          }),
        if (_filtOrden != 'nombre')
          FiltroActivoMovil(ordenesInventario[_filtOrden] ?? _filtOrden,
              () => setState(() => _filtOrden = 'nombre')),
      ],
      onLimpiarFiltros: _limpiarFiltros, // el orden ya se ve en su chip
      onEscanear: _abrirCameraScanner,
      estado: _activoFiltro,
      onEstado: (v) {
        setState(() => _activoFiltro = v);
        _aplicarFiltros();
      },
      productos: ordenarProductos(inv.productos, _filtOrden),
      cargando: inv.cargando,
      onProducto: (p) => _abrirDetalleMovil(p, inv,
          esCajero: esCajero, esAdmin: esAdmin),
      onInsights: puedeGestionar
          ? () => mostrarPanelMovil(context,
              titulo: 'Análisis',
              subtitulo: esAdmin
                  ? _nombreTiendaActual()
                  : auth.tiendaNombre,
              panel: _analisisMovil)
          : esCajero
              ? () => mostrarPanelMovil(context,
                  titulo: 'Mi turno',
                  panel: () => _buildCajeroPanel(inv.productos))
              : null,
      iconoInsights:
          esCajero ? Icons.badge_rounded : Icons.insights_rounded,
      accionesFab: esCajero ? const [] : accionesGestion,
      accionesMas: [
        AccionMovil(
            etiqueta: 'Escanear código',
            icono: Icons.qr_code_scanner_rounded,
            tono: TonoMovil.turquesa,
            onTap: _abrirCameraScanner),
        if (!esCajero) ...accionesGestion,
      ],
      aviso: inv.successMsg != null
          ? _banner(inv.successMsg!,
              isError: false, onClose: inv.limpiarMensajes)
          : inv.errorMsg != null
              ? _banner(inv.errorMsg!,
                  isError: true, onClose: inv.limpiarMensajes)
              : null,
      onRefrescar: () async {
        _aplicarFiltros();
        await _cargarInsights();
      },
    );
  }

  /// Datos del panel de análisis, en la forma que usa la vista móvil.
  Widget _analisisMovil() {
    AlertaStockMovil alerta(Map<String, dynamic> m) => AlertaStockMovil(
          nombre:    m['producto_nombre']?.toString() ?? '—',
          categoria: m['categoria_nombre']?.toString() ?? '',
          stock:     _toDouble(m['stock_actual']),
          minimo:    _toDouble(m['stock_minimo']),
        );

    return AnalisisMovil(
      cargando: _cargandoInsights,
      agotados: _alertasAgotado.map(alerta).toList(),
      bajos:    _alertasBajo.map(alerta).toList(),
      vendidos: _topProductos.map((t) => VendidoMovil(
            nombre: (t['producto'] ?? t['producto_nombre'])?.toString() ?? '—',
            categoria: t['categoria']?.toString() ?? '',
            unidades:  _toDouble(t['total_vendido']),
            ingresos:  _toDouble(t['total_ingresos']),
          )).toList(),
      movimientos: _movimientos.map((m) {
        final tipo = m['tipo'] as String? ?? '';
        // Mismos colores que usa el detalle del movimiento en escritorio.
        final (color, fondo, signo) = switch (tipo) {
          'entrada'       => (_green, _greenBg, '+'),
          'salida'        => (_danger, _dangerBg, '-'),
          'dano'          => (_danger, _dangerBg, '-'),
          'transferencia' => (const Color(0xFF3F465C),
              const Color(0xFFDAE2FD), '↔'),
          _               => (_muted, _surfHigh, '~'),
        };
        return MovimientoMovil(
          producto: m['producto_nombre']?.toString() ?? '—',
          tipo:     tipo,
          cantidad: _toDouble(m['cantidad']),
          fecha: DateTime.tryParse(m['created_at']?.toString() ?? '')
              ?.toLocal(),
          empleado: m['empleado_nombre']?.toString() ?? '',
          detalle:  m['observacion']?.toString() ?? '',
          onTap: () => _mostrarDetalleMovimiento(m, color, fondo, signo),
        );
      }).toList(),
      onVerAlertas: (tipo) {
        setState(() => _filtAlerta = tipo);
        _aplicarFiltros();
      },
    );
  }

  /// Mismos números que las tarjetas de escritorio.
  List<KpiMovil> _kpisMovil(List<Producto> productos,
      {required bool esCajero}) {
    final d = _dashboard;
    final valorTotal = d != null
        ? _toDouble(d['total_valor_inventario'])
        : productos.fold<double>(0, (s, p) => s + p.precio * p.stockActual);
    final alertasBajo = d != null
        ? _toInt(d['alertas_stock_bajo'])
        : productos.where((p) => p.stockActual > 0 && p.stockMinimo > 0 &&
            p.stockActual <= p.stockMinimo).length; // regla del servidor
    final alertasCrit = d != null
        ? _toInt(d['alertas_criticas'])
        : productos.where((p) => p.stockActual <= 0).length;
    final ingresosMes = d != null ? _toDouble(d['ingresos_mes_unidades']) : 0.0;
    final perdidasMes = d != null ? _toDouble(d['perdidas_mes_valor']) : 0.0;
    final perdidasCantidad = d != null
        ? (d['perdidas_mes_cantidad'] as num? ?? 0).toInt() : 0;

    return [
      if (!esCajero)
        KpiMovil(
          etiqueta: 'Valor inventario',
          valor: '${Constants.moneda}${formatoCompacto(valorTotal)}',
          detalle: '${productos.length} productos',
          icono: Icons.account_balance_wallet_rounded,
          tono: TonoMovil.verde,
        ),
      KpiMovil(
        etiqueta: 'Alertas de stock',
        valor: '${alertasBajo + alertasCrit}',
        sufijo: 'ítems',
        detalle: '$alertasCrit críticos (agotados)',
        icono: Icons.warning_rounded,
        tono: TonoMovil.rojo,
        detalleDestacado: alertasCrit > 0,
      ),
      KpiMovil(
        etiqueta: 'Ingresos del mes',
        valor: _formatNum(ingresosMes),
        sufijo: 'uds',
        detalle: 'Unidades recibidas',
        icono: Icons.move_to_inbox_rounded,
        tono: TonoMovil.turquesa,
      ),
      KpiMovil(
        etiqueta: 'Daños / pérdidas',
        valor: perdidasMes > 0
            ? '${Constants.moneda}${formatoCompacto(perdidasMes)}'
            : '$perdidasCantidad',
        sufijo: perdidasMes > 0 ? null : 'unid.',
        detalle: 'Reportadas este mes',
        icono: Icons.report_rounded,
        tono: perdidasCantidad > 0 ? TonoMovil.ambar : TonoMovil.lima,
      ),
    ];
  }

  /// Detalle de un producto con las acciones que el rol permite
  /// (las mismas reglas que la tabla de escritorio).
  void _abrirDetalleMovil(
    Producto p,
    InventarioProvider inv, {
    required bool esCajero,
    required bool esAdmin,
  }) {
    final inactivo = !p.activo || _activoFiltro == 'false';
    mostrarDetalleProductoMovil(context, producto: p, acciones: [
      if (esAdmin)
        AccionMovil(
            etiqueta: 'Editar',
            icono: Icons.edit_rounded,
            tono: TonoMovil.verde,
            onTap: () => _abrirFormulario(context, inv, producto: p)),
      AccionMovil(
          etiqueta: 'Kardex',
          icono: Icons.receipt_long_rounded,
          tono: TonoMovil.turquesa,
          onTap: () => _abrirKardex(p)),
      if (!esCajero)
        AccionMovil(
            etiqueta: 'Ajustar stock',
            icono: Icons.tune_rounded,
            tono: TonoMovil.lima,
            onTap: () => _abrirAjuste(p)),
      if (esAdmin && _tiendas.length >= 2)
        AccionMovil(
            etiqueta: 'Transferir',
            icono: Icons.swap_horiz_rounded,
            tono: TonoMovil.turquesa,
            onTap: () => _abrirTransferencia(p)),
      if (!esCajero)
        AccionMovil(
            etiqueta: 'Avería',
            icono: Icons.report_rounded,
            tono: TonoMovil.ambar,
            // Reporta la avería de ESTE producto (antes abría la lista
            // general, que solo gestiona averías ya reportadas).
            onTap: () => _abrirAjuste(p, tipo: 'averia')),
      if (esAdmin)
        inactivo
            ? AccionMovil(
                etiqueta: 'Reactivar',
                icono: Icons.restart_alt_rounded,
                tono: TonoMovil.verde,
                onTap: () => _confirmarReactivar(context, inv, p))
            : AccionMovil(
                etiqueta: 'Desactivar',
                icono: Icons.block_rounded,
                tono: TonoMovil.rojo,
                onTap: () => _confirmarEliminar(context, inv, p)),
    ]);
  }

  // ══════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════
  Widget _buildHeader(
      bool esCajero, bool esAdmin, InventarioProvider inv) {
    return LayoutBuilder(builder: (_, c) {
      final iconBox = Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.inventory_2_rounded,
            color: Colors.white, size: 22),
      );

      final titleCol = Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Control de Inventario',
                style: _t(size: 20, weight: FontWeight.w700,
                    letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text(
              esAdmin
                  ? 'Vista general · ${_tiendas.isEmpty ? 'Cargando…' : _nombreTiendaActual()}'
                  : 'Supervisa existencias, precios y disponibilidad',
              style: _t(size: 13, color: _muted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

      // En móvil (< 600px) los botones colapsan a un PopupMenuButton
      if (!esCajero && c.maxWidth < 600) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            iconBox,
            const SizedBox(width: 14),
            titleCol,
            if (Platform.isAndroid)
              IconButton(
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: _scanActivo ? _green : _muted2,
                ),
                tooltip: 'Escanear código de barras',
                onPressed: _abrirCameraScanner,
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'exportar' && !_exportando) _exportarExcel();
                if (v == 'importar' && _tiendaActiva != null) _abrirImportarExcel(inv);
                if (v == 'averias') _abrirAverias();
                if (v == 'nuevo') _abrirFormulario(context, inv);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'exportar',
                  child: Row(children: [
                    Icon(Icons.download_rounded, size: 16,
                        color: _exportando ? Colors.grey : null),
                    const SizedBox(width: 8),
                    Text(_exportando ? 'Exportando…' : 'Exportar Excel'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'importar',
                  child: Row(children: [
                    Icon(Icons.table_chart_rounded, size: 16,
                        color: _tiendaActiva == null ? Colors.grey : null),
                    const SizedBox(width: 8),
                    const Text('Importar Excel'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'averias',
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Averías'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'nuevo',
                  child: Row(children: [
                    Icon(Icons.add_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Nuevo producto'),
                  ]),
                ),
              ],
            ),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconBox,
          const SizedBox(width: 14),
          titleCol,
          if (!esCajero) ...[
            _btnSecundario(
              icon:  Icons.download_rounded,
              label: _exportando ? 'Exportando…' : 'Exportar Excel',
              onTap: _exportando ? null : _exportarExcel,
            ),
            const SizedBox(width: 10),
            _btnSecundario(
              icon:  Icons.table_chart_rounded,
              label: 'Importar Excel',
              onTap: _tiendaActiva != null ? () => _abrirImportarExcel(inv) : null,
            ),
            const SizedBox(width: 10),
            _btnSecundario(
              icon:  Icons.warning_amber_rounded,
              label: 'Averías',
              onTap: () => _abrirAverias(),
            ),
            const SizedBox(width: 10),
            _btnPrimario(
              icon:  Icons.add_rounded,
              label: 'Nuevo producto',
              onTap: () => _abrirFormulario(context, inv),
            ),
          ],
        ],
      );
    });
  }

  // ══════════════════════════════════════════════════════
  // SELECTOR TIENDA
  // ══════════════════════════════════════════════════════
  Widget _selectorTienda() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chipTienda(id: null, nombre: 'Todas',
            icono: Icons.store_mall_directory_rounded),
        const SizedBox(width: 8),
        ..._tiendas.asMap().entries.map((e) {
          final t = e.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _chipTienda(
              id:     t['id'] as int,
              nombre: t['nombre'] as String? ?? 'Tienda',
              icono:  Icons.store_rounded,
            ),
          );
        }),
      ]),
    ),
  );

  Widget _chipTienda({
    required int?    id,
    required String  nombre,
    required IconData icono,
  }) {
    final sel = _tiendaFiltro == id;
    return GestureDetector(
      onTap: () => _seleccionarTienda(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:  sel ? _greenBg  : _surfLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? _green : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14, color: sel ? _green : _muted2),
          const SizedBox(width: 7),
          Text(nombre, style: _t(size: 12, weight: FontWeight.w600,
              color: sel ? _green : _muted)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // KPI GRID
  // ══════════════════════════════════════════════════════
  Widget _buildKPIGrid(List<Producto> productos, {bool esCajero = false}) {
    final d          = _dashboard;
    final valorTotal = d != null
        ? _toDouble(d['total_valor_inventario'])
        : productos.fold<double>(0, (s, p) => s + p.precio * p.stockActual);
    final alertasBajo = d != null
        ? _toInt(d['alertas_stock_bajo'])
        : productos.where((p) =>
            p.stockActual > 0 &&
            (p.stockMinimo > 0 && p.stockActual <= p.stockMinimo)).length;
    final alertasCrit = d != null
        ? _toInt(d['alertas_criticas'])
        : productos.where((p) => p.stockActual <= 0).length;
    final ingresosMes = d != null
        ? _toDouble(d['ingresos_mes_unidades'])
        : 0.0;
    final perdidasMes = d != null
        ? _toDouble(d['perdidas_mes_valor'])
        : 0.0;
    final perdidasCantidad = d != null
        ? (d['perdidas_mes_cantidad'] as num? ?? 0).toInt()
        : 0;

    return Row(children: [
      if (!esCajero) ...[
        Expanded(child: _kpiCard(
          icon:      Icons.payments_rounded,
          iconBg:    const Color(0xFFDAE2FD),
          iconColor: const Color(0xFF3F465C),
          label:     'VALOR DE INVENTARIO',
          value:     '${Constants.moneda}${_formatNum(valorTotal)}',
          sub:       '${productos.length} productos en stock',
          accent:    _green,
          barValue:  null,
        )),
        const SizedBox(width: 12),
      ],
      Expanded(child: _kpiCard(
        icon:        Icons.warning_rounded,
        iconBg:      _dangerBg,
        iconColor:   _danger,
        label:       'ALERTAS STOCK BAJO',
        value:       '${alertasBajo + alertasCrit}',
        valueSuffix: ' ítems',
        sub:         '$alertasCrit críticos (agotados)',
        accent:      _danger,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:      Icons.input_rounded,
        iconBg:    _greenBg,
        iconColor: _green,
        label:     'INGRESOS DEL MES',
        value:     _formatNum(ingresosMes),
        sub:       'Unidades recibidas este mes',
        accent:    _green,
        barValue:  null,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:      Icons.inventory_2_rounded,
        iconBg:    perdidasCantidad > 0 ? _dangerBg : _surfHigh,
        iconColor: perdidasCantidad > 0 ? _danger   : _muted2,
        label:     'DAÑOS / PÉRDIDAS',
        value:     perdidasMes > 0
            ? '${Constants.moneda}${_formatNum(perdidasMes)}'
            : '$perdidasCantidad',
        valueSuffix: perdidasMes > 0 ? null : ' unid.',
        sub:       perdidasCantidad > 0
            ? '$perdidasCantidad unid. reportadas este mes'
            : 'Reportados este mes',
        accent:    perdidasCantidad > 0 ? _danger : _muted2,
      )),
    ]);
  }

  Widget _kpiCard({
    required IconData  icon,
    required Color     iconBg,
    required Color     iconColor,
    required String    label,
    required String    value,
    String?            valueSuffix,
    required String    sub,
    required Color     accent,
    double?            barValue,
  }) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:         iconBg,
                    borderRadius:  BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(label,
                style: _t(size: 11, weight: FontWeight.w600,
                    color: _muted, letterSpacing: 0.05)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(value,
                      style: _t(size: 26, weight: FontWeight.w700,
                          letterSpacing: -0.5, height: 1.1)),
                ),
                if (valueSuffix != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Text(valueSuffix,
                        style: _t(size: 15, weight: FontWeight.w600,
                            color: _muted)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (barValue != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value:           barValue.clamp(0.0, 1.0),
                  minHeight:       4,
                  backgroundColor: _surfHigh,
                  valueColor:      AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(sub, style: _t(size: 11, color: _muted)),
          ],
        ),
      );

  // ══════════════════════════════════════════════════════
  // TOOLBAR
  // ══════════════════════════════════════════════════════
  Widget _buildToolbar(bool esCajero, InventarioProvider inv) =>
      LayoutBuilder(builder: (_, c) {
        final compact = c.maxWidth < 580;

        final searchField = Container(
          height: 40,
          decoration: BoxDecoration(
            color: _surfLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: _t(size: 14),
            decoration: InputDecoration(
              hintText: 'Buscar producto o código…',
              hintStyle: _t(size: 14, color: _muted2),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF76777D), size: 18),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
            onChanged: (val) => context.read<InventarioProvider>().cargarProductos(
                  q: val,
                  tiendaId: _tiendaActiva,
                  activo: _activoFiltro,
                  categoriaId: _filtCategoriaId,
                  precioMin: _filtPrecioMin,
                  precioMax: _filtPrecioMax,
                  alerta: _filtAlerta,
                ),
          ),
        );

        final filtrosBtn = GestureDetector(
          onTap: () => _abrirFiltros(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _hayFiltrosActivos
                  ? _green
                  : (compact ? const Color(0xFF131B2E) : _surfLow),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _hayFiltrosActivos
                    ? _green
                    : (compact ? const Color(0xFF131B2E) : _border),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune_rounded,
                  size: 16,
                  color: (_hayFiltrosActivos || compact) ? Colors.white : _muted2),
              const SizedBox(width: 5),
              Text('Filtros',
                  style: _t(
                      size: 12,
                      weight: FontWeight.w700,
                      color: (_hayFiltrosActivos || compact)
                          ? Colors.white
                          : _muted2)),
              if (_hayFiltrosActivos) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(_contarFiltros().toString(),
                      style: _t(
                          size: 10,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ]),
          ),
        );

        if (compact) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: searchField),
              const SizedBox(width: 8),
              filtrosBtn,
            ]),
            if (!esCajero) ...[
              const SizedBox(height: 8),
              _filtroEstado(),
            ],
          ]);
        }

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: _scanActivo ? const Color(0xFFE8FFF4) : _surfLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _scanActivo ? _green : _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_scanner_rounded,
                    size: 16,
                    color: _scanActivo ? _green : _muted2),
                if (_scanActivo) ...[
                  const SizedBox(width: 5),
                  Text('OK',
                      style: _t(
                          size: 11, weight: FontWeight.w700, color: _green)),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            filtrosBtn,
            if (!esCajero) ...[
              const SizedBox(width: 10),
              _filtroEstado(),
            ],
          ]),
        );
      });

  Widget _filtroEstado() {
    final ops = [
      ('true',  'Activos',   Icons.check_circle_outline_rounded, _green),
      ('false', 'Inactivos', Icons.block_rounded,                _danger),
      ('all',   'Todos',     Icons.all_inclusive_rounded,        _muted),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _surfLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ops.map((op) {
          final (valor, label, icon, color) = op;
          final sel = _activoFiltro == valor;
          return GestureDetector(
            onTap: () {
              setState(() => _activoFiltro = valor);
              context.read<InventarioProvider>().cargarProductos(
                  tiendaId: _tiendaActiva, activo: valor);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: sel
                    ? [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 13,
                    color: sel ? color : _muted2),
                const SizedBox(width: 5),
                Text(label,
                    style: _t(size: 12,
                        weight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? color : _muted)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _contarFiltros() {
    int n = 0;
    if (_filtCategoriaId != null) n++;
    if (_filtPrecioMin   != null) n++;
    if (_filtPrecioMax   != null) n++;
    if (_filtAlerta      != null) n++;
    return n;
  }

  void _aplicarFiltros() {
    context.read<InventarioProvider>().cargarProductos(
      q:           _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      tiendaId:    _tiendaActiva,
      activo:      _activoFiltro,
      categoriaId: _filtCategoriaId,
      precioMin:   _filtPrecioMin,
      precioMax:   _filtPrecioMax,
      alerta:      _filtAlerta,
    );
  }

  void _limpiarFiltros() {
    setState(() {
      _filtCategoriaId   = null;
      _filtCategoriaName = null;
      _filtPrecioMin     = null;
      _filtPrecioMax     = null;
      _filtAlerta        = null;
      _filtOrden         = 'nombre';
    });
    _aplicarFiltros();
  }

  Future<void> _abrirFiltros(BuildContext ctx) async {
    final inv = ctx.read<InventarioProvider>();
    await inv.cargarCategorias(tiendaId: _tiendaActiva);
    if (!ctx.mounted) return;
    final categorias = inv.categorias; // List<Map<String,dynamic>>

    if (MediaQuery.sizeOf(ctx).width < 600) {
      await mostrarFiltrosMovil(ctx, (cerrar) => FiltrosMovil(
            categorias: [
              for (final c in categorias)
                if (c['id'] is int)
                  CategoriaMovil(c['id'] as int, (c['nombre'] ?? '').toString()),
            ],
            inicial: FiltrosInventarioMovil(
              alerta:          _filtAlerta,
              categoriaId:     _filtCategoriaId,
              categoriaNombre: _filtCategoriaName,
              precioMin:       _filtPrecioMin,
              precioMax:       _filtPrecioMax,
              orden:           _filtOrden,
            ),
            onCerrar: cerrar,
            onAplicar: (f) {
              cerrar();
              setState(() {
                _filtAlerta        = f.alerta;
                _filtCategoriaId   = f.categoriaId;
                _filtCategoriaName = f.categoriaNombre;
                _filtPrecioMin     = f.precioMin;
                _filtPrecioMax     = f.precioMax;
                _filtOrden         = f.orden;
              });
              _aplicarFiltros();
            },
          ));
      return;
    }

    // Controladores locales al sheet
    final precioMinCtrl = TextEditingController(
        text: _filtPrecioMin != null ? _filtPrecioMin!.toStringAsFixed(0) : '');
    final precioMaxCtrl = TextEditingController(
        text: _filtPrecioMax != null ? _filtPrecioMax!.toStringAsFixed(0) : '');

    int?    tmpCatId   = _filtCategoriaId;
    String? tmpCatName = _filtCategoriaName;
    String? tmpAlerta  = _filtAlerta;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(99),
                ),
              )),
              const SizedBox(height: 16),

              // Header
              Row(children: [
                const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF191C1E)),
                const SizedBox(width: 8),
                Text('Filtros avanzados',
                    style: _t(size: 16, weight: FontWeight.w700, color: _text)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx2);
                    _limpiarFiltros();
                  },
                  child: Text('Limpiar',
                      style: _t(size: 13, color: _danger, weight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Categoría ─────────────────────────────
              Text('Categoría', style: _t(size: 12, weight: FontWeight.w600, color: _muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  _chipFiltro(
                    label: 'Todas',
                    sel: tmpCatId == null,
                    onTap: () => setS(() { tmpCatId = null; tmpCatName = null; }),
                  ),
                  ...categorias.map((c) {
                    final id   = c['id'] as int;
                    final nom  = c['nombre'] as String? ?? '';
                    return _chipFiltro(
                      label: nom,
                      sel:   tmpCatId == id,
                      onTap: () => setS(() { tmpCatId = id; tmpCatName = nom; }),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // ── Rango de precio ────────────────────────
              Text('Rango de precio', style: _t(size: 12, weight: FontWeight.w600, color: _muted)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _precioField('Precio mínimo', precioMinCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _precioField('Precio máximo', precioMaxCtrl)),
              ]),
              const SizedBox(height: 16),

              // ── Alerta de stock ────────────────────────
              Text('Estado de stock', style: _t(size: 12, weight: FontWeight.w600, color: _muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _chipFiltro(label: 'Todos',       sel: tmpAlerta == null,          onTap: () => setS(() => tmpAlerta = null)),
                  _chipFiltro(label: 'Stock bajo',  sel: tmpAlerta == 'bajo',        onTap: () => setS(() => tmpAlerta = 'bajo')),
                  _chipFiltro(label: 'Agotados',    sel: tmpAlerta == 'agotado',     onTap: () => setS(() => tmpAlerta = 'agotado')),
                  _chipFiltro(label: 'Con averías', sel: tmpAlerta == 'con_averias', onTap: () => setS(() => tmpAlerta = 'con_averias')),
                ],
              ),
              const SizedBox(height: 20),

              // ── Aplicar ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // "12.500" son doce mil quinientos (antes quedaba en 12,5).
                    double? precio(String t) =>
                        RegExp(r'\d').hasMatch(t) ? leerNumeroExcel(t) : null;
                    final pMin = precio(precioMinCtrl.text);
                    final pMax = precio(precioMaxCtrl.text);
                    setState(() {
                      _filtCategoriaId   = tmpCatId;
                      _filtCategoriaName = tmpCatName;
                      _filtPrecioMin     = pMin;
                      _filtPrecioMax     = pMax;
                      _filtAlerta        = tmpAlerta;
                    });
                    Navigator.pop(ctx2);
                    _aplicarFiltros();
                  },
                  child: Text('Aplicar filtros',
                      style: _t(size: 14, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipFiltro({
    required String   label,
    required bool     sel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:        sel ? _green : _surfLow,
          borderRadius: BorderRadius.circular(99),
          border:       Border.all(color: sel ? _green : _border),
        ),
        child: Text(label,
            style: _t(size: 12, weight: FontWeight.w600,
                color: sel ? Colors.white : _muted)),
      ),
    );
  }

  Widget _precioField(String hint, TextEditingController ctrl) => TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: _t(size: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _t(size: 12, color: _muted2),
          prefixText: '\$ ',
          prefixStyle: _t(size: 13, weight: FontWeight.w600),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: _surfLow,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _green, width: 1.5)),
        ),
      );

  // ══════════════════════════════════════════════════════
  // TABLA PLANA
  // ══════════════════════════════════════════════════════
  /// Transferir en el celular. Con una tienda elegida, esa es el origen;
  /// en "Todas" se elige en la hoja. Cada tienda muestra su stock.
  Future<void> _abrirTransferenciaMovil(Producto p) async {
    if (_tiendas.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Se necesitan al menos 2 tiendas para transferir.'),
        backgroundColor: _warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    double n(Object? v) => double.tryParse('${v ?? ''}') ?? 0;
    final r = await _service.getInventario(productoId: p.id, activo: 'all');
    if (!mounted) return;
    final stockPorTienda = <int, double>{
      for (final f in (r['data'] as List? ?? const []).whereType<Map>())
        if (f['tienda'] is int) f['tienda'] as int: n(f['stock_actual']),
    };
    final tiendas = <(TiendaMovil, double)>[
      for (final t in _tiendas)
        if (t['id'] is int)
          (TiendaMovil(t['id'] as int, (t['nombre'] ?? 'Tienda').toString()),
           stockPorTienda[t['id']] ?? 0),
    ];
    final messenger = ScaffoldMessenger.of(context);
    final inv = context.read<InventarioProvider>();
    String c(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

    await mostrarTransferirMovil(context, (cerrar) => TransferirMovil(
          producto:    p.nombre,
          tiendas:     tiendas,
          origenFijo:  _tiendaActiva,
          soloEnteros: p.unidadMedida == 'unidad',
          onCerrar:    cerrar,
          onConfirmar: (origen, destino, cantidad, nota) async {
            final res = await _service.transferirStock(
              productoId:  p.id,
              origenId:    origen,
              destinoId:   destino,
              cantidad:    cantidad,
              observacion: nota,
            );
            if (res['success'] != true) {
              return (res['error'] ?? 'No se pudo transferir').toString();
            }
            cerrar();
            inv.cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro);
            _cargarInsights();
            final d = res['data'] is Map ? res['data'] as Map : const {};
            messenger.showSnackBar(SnackBar(
              content: Text('Listo · ${c(cantidad)} de ${p.nombre} a '
                  '${d['tienda_destino'] ?? 'la otra tienda'}. '
                  'Quedan ${c(n(d['stock_origen']))} en '
                  '${d['tienda_origen'] ?? 'origen'} y '
                  '${c(n(d['stock_destino']))} en '
                  '${d['tienda_destino'] ?? 'destino'}.'),
              backgroundColor: _green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ));
            return null;
          },
        ));
  }

  void _abrirTransferencia(Producto p) {
    if (MediaQuery.sizeOf(context).width < 600) {
      _abrirTransferenciaMovil(p);
      return;
    }
    final tiendaId = _tiendaActiva;
    if (tiendaId == null || _tiendas.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            _tiendas.length < 2
                ? 'Se necesitan al menos 2 tiendas para transferir.'
                : 'Selecciona una tienda específica de origen.',
            style: _t(size: 13, color: Colors.white)),
        backgroundColor: _warning,
      ));
      return;
    }
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _TransferenciaSheet(
        producto:         p,
        tiendaOrigenId:   tiendaId,
        tiendas:          _tiendas,
        onTransferida: () => context.read<InventarioProvider>()
            .cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro),
      ),
    );
  }

  void _abrirAjuste(Producto p, {String tipo = 'entrada'}) {
    if (MediaQuery.sizeOf(context).width < 600) {
      _abrirAjusteMovil(p, tipo);
      return;
    }
    final tiendaId = _tiendaActiva;
    if (tiendaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecciona una tienda específica para ajustar stock.',
            style: _t(size: 13, color: Colors.white)),
        backgroundColor: _danger,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AjusteStockSheet(
        tipoInicial: tipo,
        producto:  p,
        tiendaId:  tiendaId,
        onAjustado: () => context
            .read<InventarioProvider>()
            .cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro),
      ),
    );
  }

  /// Tienda donde ver o hacer algo con [p], con su stock y averías al día.
  /// - Con una tienda elegida (o si es cajero/supervisor): esa, directo.
  /// - En "Todas": si el producto está en una sola tienda, esa; si está en
  ///   varias, pregunta mostrando el stock de cada una.
  /// null si no hay tienda o el usuario cierra la pregunta.
  Future<({int id, String nombre, double stock, double? averias})?>
      _tiendaDelProducto(Producto p, {required String explicacion}) async {
    double n(Object? v) => double.tryParse('${v ?? ''}') ?? 0;
    final r = await _service.getInventario(productoId: p.id, activo: 'all');
    if (!mounted) return null;
    final filas = (r['data'] as List? ?? const [])
        .whereType<Map>()
        .where((f) => f['tienda'] is int)
        .toList();

    final activa = _tiendaActiva;
    if (activa != null) {
      final f = filas.where((f) => f['tienda'] == activa).firstOrNull;
      final auth = context.read<AuthProvider>();
      return (
        id: activa,
        nombre: auth.rol == 'admin' || auth.rol == 'superadmin'
            ? _nombreTiendaActual()
            : auth.tiendaNombre,
        stock: f != null ? n(f['stock_actual']) : p.stockActual,
        averias: f != null ? n(f['stock_averias']) : null,
      );
    }

    if (filas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r['success'] == true
            ? 'Este producto no está en ninguna tienda.'
            : (r['error'] ?? 'No se pudo consultar el stock').toString()),
        backgroundColor: _danger,
        behavior: SnackBarBehavior.floating,
      ));
      return null;
    }

    ({int id, String nombre, double stock, double? averias}) de(Map f) => (
          id: f['tienda'] as int,
          nombre: (f['tienda_nombre'] ?? 'Tienda').toString(),
          stock: n(f['stock_actual']),
          averias: n(f['stock_averias']),
        );

    if (filas.length == 1) return de(filas.first);

    final elegida = await mostrarElegirTiendaMovil(context,
        titulo: '¿De qué tienda?',
        subtitulo: '$explicacion ${p.nombre} está en:',
        tiendas: [
          for (final f in filas)
            (TiendaMovil(f['tienda'] as int,
                    (f['tienda_nombre'] ?? 'Tienda').toString()),
                n(f['stock_actual'])),
        ]);
    if (elegida == null || !mounted) return null;
    return de(filas.firstWhere((f) => f['tienda'] == elegida));
  }

  /// Kardex en el celular.
  Future<void> _abrirKardexMovil(Producto p) async {
    final t = await _tiendaDelProducto(p,
        explicacion: 'El kardex es por tienda.');
    if (t == null || !mounted) return;
    await mostrarKardexMovil(context, (_) => _KardexMovilCarga(
          producto: p,
          tiendaId: t.id,
          tienda:   t.nombre,
          stock:    t.stock,
          service:  _service,
        ));
  }

  /// Ajustar stock en el celular: entrada, salida, conteo o avería.
  Future<void> _abrirAjusteMovil(Producto p, String tipo) async {
    final t = await _tiendaDelProducto(p,
        explicacion: 'El ajuste se hace en una sola tienda.');
    if (t == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final inv = context.read<InventarioProvider>();

    await mostrarAjusteStockMovil(context, (cerrar) => AjusteStockMovil(
          producto:    p.nombre,
          tienda:      t.nombre,
          stock:       t.stock,
          averias:     t.averias,
          tipoInicial: tipo,
          soloEnteros: p.unidadMedida == 'unidad',
          onCerrar:    cerrar,
          onConfirmar: (tipo, cantidad, obs) async {
            final r = await _service.ajustarStock(
              productoId:  p.id,
              tiendaId:    t.id,
              cantidad:    cantidad,
              tipo:        tipo,
              observacion: obs,
            );
            if (r['success'] != true) {
              return (r['error'] ?? 'No se pudo ajustar el stock').toString();
            }
            cerrar();
            inv.cargarProductos(tiendaId: _tiendaFiltro, activo: _activoFiltro);
            _cargarInsights();
            double n(Object? v) => double.tryParse('${v ?? ''}') ?? 0;
            String c(double v) => v == v.roundToDouble()
                ? v.toInt().toString()
                : v.toStringAsFixed(1);
            final data = r['data'] is Map ? r['data'] as Map : const {};
            final stock = c(n(data['stock_actual']));
            messenger.showSnackBar(SnackBar(
              content: Text(tipo == 'averia'
                  ? 'Avería registrada · ${p.nombre}: quedan $stock en stock '
                      'y ${c(n(data['stock_averias']))} en averías'
                  : 'Listo · ${p.nombre} quedó con $stock en stock'),
              backgroundColor: tipo == 'averia' ? _warning : _green,
              behavior: SnackBarBehavior.floating,
            ));
            return null;
          },
        ));
  }

  void _abrirKardex(Producto p) {
    if (MediaQuery.sizeOf(context).width < 600) {
      _abrirKardexMovil(p);
      return;
    }
    final tiendaId = _tiendaActiva;
    if (tiendaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecciona una tienda específica para ver el kardex.',
            style: _t(size: 13, color: Colors.white)),
        backgroundColor: _warning,
      ));
      return;
    }
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _KardexSheet(
        producto:  p,
        tiendaId:  tiendaId,
        service:   _service,
      ),
    );
  }

  Widget _buildTabla(List<Producto> productos, bool esCajero,
      bool esAdmin, InventarioProvider inv) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          _tablaHeader(esAdmin, esCajero),
          const Divider(height: 1, color: Color(0xFFC6C6CD)),
          Expanded(
            child: ListView.builder(
              padding:     EdgeInsets.zero,
              itemCount:   productos.length,
              itemBuilder: (_, i) =>
                  _tablaFila(productos[i], i, esCajero, esAdmin, inv),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tablaHeader(bool esAdmin, bool esCajero) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
    color: _surfLow,
    child: Row(children: [
      Expanded(flex: 3, child: _th('Producto y código')),
      Expanded(flex: 2, child: _th('Categoría')),
      if (esAdmin) ...[
        Expanded(flex: 2, child: _th('Costo', right: true)),
        Expanded(flex: 2, child: _th('Precio venta', right: true)),
        Expanded(flex: 2, child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _th('Margen'),
        )),
      ] else
        Expanded(flex: 2, child: _th('Precio', right: true)),
      Expanded(flex: 1, child: _th('Stock', right: true)),
      Expanded(flex: 2, child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _th('Estado'),
      )),
      if (!esCajero) const SizedBox(width: 44),
    ]),
  );

  Widget _th(String t, {bool right = false}) => Text(
    t,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: _t(size: 11, weight: FontWeight.w600,
        color: _muted2, letterSpacing: 0.04),
  );

  Widget _tablaFila(Producto p, int idx, bool esCajero,
      bool esAdmin, InventarioProvider inv) {
    final esInactivo = _activoFiltro == 'false';
    final agotado    = p.stockActual <= 0;
    final bajo       = !agotado && (p.stockMinimo > 0 && p.stockActual <= p.stockMinimo);
    final isHovered  = _hoveredRow == idx;

    final (estadoText, estadoColor) = esInactivo
        ? ('Inactivo', _muted2)
        : agotado
            ? ('Agotado', _muted2)
            : bajo
                ? ('Stock bajo', _warning)
                : ('Óptimo', _green);

    final costo  = p.precioCompra;
    final venta  = p.precio;
    final margen = costo > 0 ? (venta - costo) / costo * 100 : 0.0;
    final mColor = margen < 0 ? _danger : margen < 10 ? _warning : _green;

    final avatarColor = _avatarColor(p.nombre);
    final inicial     = p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRow = idx),
      onExit:  (_) => setState(() => _hoveredRow = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => ProductoDetalleSheet.show(
          context,
          producto:     p,
          esAdmin:      esAdmin,
          onEditar:     esAdmin ? () => _abrirFormulario(context, inv, producto: p) : null,
          onKardex:     () => _abrirKardex(p),
          onAjuste:     (!esCajero) ? () => _abrirAjuste(p) : null,
          onTransferir: (esAdmin && _tiendas.length >= 2) ? () => _abrirTransferencia(p) : null,
        ),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: isHovered
            ? const Color(0xFFECEEF0)
            : idx.isEven ? _surface : _surfLow.withValues(alpha: 0.35),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(children: [
              // ── Producto & SKU ────────────────────────
              Expanded(
                flex: 3,
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color:         avatarColor.withValues(alpha: 0.12),
                      borderRadius:  BorderRadius.circular(9),
                    ),
                    child: Center(child: Text(inicial,
                        style: _t(size: 14, weight: FontWeight.w700,
                            color: avatarColor))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 13, weight: FontWeight.w600,
                              color: esInactivo ? _muted2 : _text)),
                      if (p.referencia.isNotEmpty)
                        Text('SKU: ${p.referencia}',
                            style: _t(size: 11, color: _muted2)),
                    ],
                  )),
                ]),
              ),
              // ── Categoría ────────────────────────────
              Expanded(
                flex: 2,
                child: p.categoria.isNotEmpty &&
                        p.categoria != 'Sin categoría'
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _surfHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(p.categoria,
                            overflow: TextOverflow.ellipsis,
                            style: _t(size: 11, weight: FontWeight.w600,
                                color: _muted)))
                    : Text('—',
                        style: _t(size: 12, color: _muted2)),
              ),
              // ── Precios ──────────────────────────────
              if (esAdmin) ...[
                Expanded(flex: 2, child: Text(
                    '${Constants.moneda}${costo.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: _t(size: 13, weight: FontWeight.w600,
                        color: _muted))),
                Expanded(flex: 2, child: Text(
                    '${Constants.moneda}${venta.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: _t(size: 13, weight: FontWeight.w700,
                        color: esInactivo ? _muted2 : _text))),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: esInactivo
                      ? Text('—',
                          style: _t(size: 12, color: _muted2))
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: mColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              Icon(
                                margen >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                size: 11, color: mColor),
                              const SizedBox(width: 3),
                              Text('${margen.toStringAsFixed(1)}%',
                                  style: _t(size: 11, weight: FontWeight.w700,
                                      color: mColor)),
                            ]),
                          ),
                        ),
                  ),
                ),
              ] else
                Expanded(flex: 2, child: Text(
                    '${Constants.moneda}${venta.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: _t(size: 13, weight: FontWeight.w700,
                        color: esInactivo ? _muted2 : _text))),
              // ── Stock ────────────────────────────────
              Expanded(flex: 1, child: Text(
                  p.stockActual.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: _t(size: 14, weight: FontWeight.w700,
                      color: esInactivo
                          ? _muted2
                          : agotado
                              ? _danger
                              : bajo ? _warning : _text))),
              // ── Estado ───────────────────────────────
              Expanded(
                flex: 2,
                child: Row(children: [
                  const SizedBox(width: 12),
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: estadoColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(estadoText,
                        overflow: TextOverflow.ellipsis,
                        style: _t(size: 12, weight: FontWeight.w600,
                            color: estadoColor)),
                  ),
                ]),
              ),
              // ── Acciones ─────────────────────────────
              if (!esCajero)
                SizedBox(
                  width: 44,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 130),
                    opacity:  isHovered ? 1.0 : 0.0,
                    child: esInactivo
                        ? (esAdmin
                            ? _actionBtn(
                                icon:    Icons.refresh_rounded,
                                color:   _green,
                                tooltip: 'Reactivar',
                                onTap:   () =>
                                    _confirmarReactivar(context, inv, p))
                            : const SizedBox())
                        : PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                size: 18, color: _muted),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (v) {
                              if (v == 'edit') {
                                _abrirFormulario(context, inv, producto: p);
                              }
                              if (v == 'kardex') {
                                _abrirKardex(p);
                              }
                              if (v == 'transfer') {
                                _abrirTransferencia(p);
                              }
                              if (v == 'adjust') {
                                _abrirAjuste(p);
                              }
                              if (v == 'del') {
                                _confirmarEliminar(context, inv, p);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit_rounded,
                                      size: 16, color: _muted),
                                  const SizedBox(width: 10),
                                  Text('Editar', style: _t(size: 13)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'kardex',
                                child: Row(children: [
                                  Icon(Icons.timeline_rounded,
                                      size: 16, color: _muted),
                                  const SizedBox(width: 10),
                                  Text('Kardex', style: _t(size: 13)),
                                ]),
                              ),
                              if (_tiendas.length >= 2)
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(children: [
                                    Icon(Icons.swap_horiz_rounded,
                                        size: 16, color: _muted),
                                    const SizedBox(width: 10),
                                    Text('Transferir', style: _t(size: 13)),
                                  ]),
                                ),
                              if (!esCajero)
                                PopupMenuItem(
                                  value: 'adjust',
                                  child: Row(children: [
                                    Icon(Icons.tune_rounded,
                                        size: 16, color: _muted),
                                    const SizedBox(width: 10),
                                    Text('Ajustar stock', style: _t(size: 13)),
                                  ]),
                                ),
                              PopupMenuItem(
                                value: 'del',
                                child: Row(children: [
                                  const Icon(Icons.block_rounded,
                                      size: 16, color: _danger),
                                  const SizedBox(width: 10),
                                  Text('Desactivar',
                                      style: _t(size: 13, color: _danger)),
                                ]),
                              ),
                            ],
                          ),
                  ),
                ),
            ]),
          ),
          if (!isHovered)
            const Divider(height: 1, color: Color(0xFFF0F0F2)),
        ]),
      ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // HELPERS CATEGORÍA
  // ══════════════════════════════════════════════════════
  static const _chipPaletteBg = [
    Color(0xFFD1FAE5), Color(0xFFFEF3C7), Color(0xFFFFE4E6),
    Color(0xFFE0E7FF), Color(0xFFFCE7F3), Color(0xFFD1D5DB),
  ];
  static const _chipPaletteFg = [
    Color(0xFF065F46), Color(0xFF92400E), Color(0xFF9F1239),
    Color(0xFF3730A3), Color(0xFF831843), Color(0xFF374151),
  ];

  Color _categoriaChipBg(String cat) {
    if (cat.isEmpty) return _chipPaletteBg[0];
    return _chipPaletteBg[cat.codeUnitAt(0) % _chipPaletteBg.length];
  }

  Color _categoriaChipFg(String cat) {
    if (cat.isEmpty) return _chipPaletteFg[0];
    return _chipPaletteFg[cat.codeUnitAt(0) % _chipPaletteFg.length];
  }

  // ══════════════════════════════════════════════════════
  // KPI CARRUSEL (MÓVIL)
  // ══════════════════════════════════════════════════════
  Widget _buildKPICarousel(List<Producto> productos, {bool esCajero = false}) {
    final d = _dashboard;
    final valorTotal = d != null
        ? _toDouble(d['total_valor_inventario'])
        : productos.fold<double>(0, (s, p) => s + p.precio * p.stockActual);
    final alertasBajo = d != null
        ? _toInt(d['alertas_stock_bajo'])
        : productos.where((p) => p.stockActual > 0 && p.stockMinimo > 0 &&
            p.stockActual <= p.stockMinimo).length; // regla del servidor
    final alertasCrit = d != null
        ? _toInt(d['alertas_criticas'])
        : productos.where((p) => p.stockActual <= 0).length;
    final ingresosMes = d != null ? _toDouble(d['ingresos_mes_unidades']) : 0.0;
    final perdidasMes = d != null ? _toDouble(d['perdidas_mes_valor']) : 0.0;
    final perdidasCantidad = d != null
        ? (d['perdidas_mes_cantidad'] as num? ?? 0).toInt() : 0;

    final cards = <Widget>[
      if (!esCajero)
        _kpiCarouselCard(
          icon: Icons.payments_rounded,
          iconBg: const Color(0xFFDAE2FD),
          iconColor: const Color(0xFF3F465C),
          accent: const Color(0xFF3F465C),
          label: 'VALOR INVENTARIO',
          value: '${Constants.moneda}${_formatNum(valorTotal)}',
          sub: '${productos.length} productos',
        ),
      _kpiCarouselCard(
        icon: Icons.warning_rounded,
        iconBg: _dangerBg,
        iconColor: _danger,
        accent: _danger,
        label: 'ALERTAS STOCK',
        value: '${alertasBajo + alertasCrit}',
        suffix: ' ítems',
        sub: '$alertasCrit críticos',
      ),
      _kpiCarouselCard(
        icon: Icons.input_rounded,
        iconBg: const Color(0xFFD1FAE5),
        iconColor: _green,
        accent: _green,
        label: 'INGRESOS MES',
        value: _formatNum(ingresosMes),
        suffix: ' uds',
        sub: 'Recibidas este mes',
      ),
      _kpiCarouselCard(
        icon: Icons.inventory_2_rounded,
        iconBg: perdidasCantidad > 0 ? _dangerBg : _surfHigh,
        iconColor: perdidasCantidad > 0 ? _danger : _muted2,
        accent: perdidasCantidad > 0 ? _danger : _muted2,
        label: 'DAÑOS / PÉRDIDAS',
        value: perdidasMes > 0
            ? '${Constants.moneda}${_formatNum(perdidasMes)}'
            : '$perdidasCantidad',
        suffix: perdidasMes > 0 ? null : ' unid.',
        sub: 'Reportadas este mes',
      ),
    ];

    return Column(children: [
      SizedBox(
        height: 136,
        child: PageView.builder(
          controller: _kpiPageCtrl,
          padEnds: false,
          itemCount: cards.length,
          onPageChanged: (i) => setState(() => _kpiPage = i),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: cards[i],
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(cards.length, (i) {
          final active = _kpiPage == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? _green : _border,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    ]);
  }

  Widget _kpiCarouselCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color accent,
    required String label,
    required String value,
    String? suffix,
    required String sub,
  }) =>
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: iconBg, borderRadius: BorderRadius.circular(9)),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const Spacer(),
                  Text(label,
                      style: _t(size: 9, weight: FontWeight.w700,
                          color: _muted2, letterSpacing: 0.05),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Flexible(child: Text(value,
                        style: _t(size: 21, weight: FontWeight.w700,
                            letterSpacing: -0.4, height: 1.1),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (suffix != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1, left: 2),
                        child: Text(suffix,
                            style: _t(size: 11, weight: FontWeight.w600,
                                color: _muted)),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(sub, style: _t(size: 10, color: _muted2),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ]),
      );

  // ══════════════════════════════════════════════════════
  // ALERTA BANNER
  // ══════════════════════════════════════════════════════
  Widget _buildAlertaBanner() {
    final agotados = _alertasAgotado.length;
    final bajos    = _alertasBajo.length;
    if (agotados == 0 && bajos == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        setState(() => _filtAlerta = agotados > 0 ? 'agotado' : 'bajo');
        _aplicarFiltros();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: agotados > 0 ? _dangerBg : const Color(0xFFFEF9EC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: agotados > 0
                ? _danger.withValues(alpha: 0.3)
                : _warning.withValues(alpha: 0.4),
          ),
        ),
        child: Row(children: [
          Icon(Icons.notifications_active_rounded, size: 16,
              color: agotados > 0 ? _danger : _warning),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (agotados > 0)
                Text(
                  '$agotados producto${agotados != 1 ? 's' : ''} agotado${agotados != 1 ? 's' : ''}',
                  style: _t(size: 12, weight: FontWeight.w700, color: _danger),
                ),
              if (bajos > 0)
                Text(
                  '$bajos más con stock bajo · Toca para ver',
                  style: _t(size: 11, color: agotados > 0 ? _muted : _warning),
                ),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 16,
              color: agotados > 0 ? _danger : _warning),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // LISTA MÓVIL (cards)
  // ══════════════════════════════════════════════════════
  Widget _buildListaMobile(List<Producto> productos, bool esCajero,
      bool esAdmin, InventarioProvider inv) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text('PRODUCTOS',
              style: _t(size: 11, weight: FontWeight.w700, color: _muted2,
                  letterSpacing: 0.08)),
          const Spacer(),
          Text('${productos.length} resultado${productos.length != 1 ? 's' : ''}',
              style: _t(size: 11, color: _muted2)),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: productos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) =>
              _buildProductoCardMobile(productos[i], esCajero, esAdmin, inv),
        ),
      ),
    ]);
  }

  Widget _buildProductoCardMobile(Producto p, bool esCajero,
      bool esAdmin, InventarioProvider inv) {
    final agotado = p.stockActual <= 0;
    final bajo = !agotado && (p.stockMinimo > 0 && p.stockActual <= p.stockMinimo);
    final estadoText  = agotado ? 'Agotado' : bajo ? 'Stock bajo' : 'Óptimo';
    final estadoColor = agotado ? _danger : bajo ? _warning : _green;
    final stockIcon   = agotado
        ? Icons.close_rounded
        : bajo ? Icons.warning_rounded : Icons.trending_up_rounded;
    final avatarColor = _avatarColor(p.nombre);
    final inicial     = p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => ProductoDetalleSheet.show(
        context,
        producto:     p,
        esAdmin:      esAdmin,
        onEditar:     esAdmin ? () => _abrirFormulario(context, inv, producto: p) : null,
        onKardex:     () => _abrirKardex(p),
        onAjuste:     !esCajero ? () => _abrirAjuste(p) : null,
        onTransferir: (esAdmin && _tiendas.length >= 2)
            ? () => _abrirTransferencia(p) : null,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(inicial,
                style: _t(size: 17, weight: FontWeight.w700,
                    color: avatarColor))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nombre,
                  style: _t(size: 13, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              if (p.referencia.isNotEmpty)
                Text('SKU: ${p.referencia}',
                    style: _t(size: 11, color: _muted2)),
              if (p.categoria.isNotEmpty && p.categoria != 'Sin categoría') ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _categoriaChipBg(p.categoria),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(p.categoria,
                      style: _t(size: 10, weight: FontWeight.w600,
                          color: _categoriaChipFg(p.categoria))),
                ),
              ],
            ],
          )),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${Constants.moneda}${p.precio.toStringAsFixed(0)}',
                style: _t(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(stockIcon, size: 11, color: estadoColor),
              const SizedBox(width: 3),
              Text('${p.stockActual.toInt()} uds',
                  style: _t(size: 11, weight: FontWeight.w600,
                      color: estadoColor)),
            ]),
            const SizedBox(height: 2),
            Text(estadoText,
                style: _t(size: 10, weight: FontWeight.w600,
                    color: estadoColor)),
          ]),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // PANEL INSIGHTS (Top Sellers + Movimientos)
  // ══════════════════════════════════════════════════════
  Widget _buildInsightsPanel() {
    final hayAlertas = _alertasAgotado.isNotEmpty || _alertasBajo.isNotEmpty;
    return SingleChildScrollView(
      child: Column(children: [
        if (hayAlertas || _cargandoInsights) ...[
          _alertasStockCard(),
          const SizedBox(height: 14),
        ],
        _topSellersCard(),
        const SizedBox(height: 14),
        _movimientosCard(),
      ]),
    );
  }

  Widget _alertasStockCard() {
    final total = _alertasAgotado.length + _alertasBajo.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _alertasAgotado.isNotEmpty
            ? _dangerBg.withValues(alpha: 0.5)
            : const Color(0xFFFEF9EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _alertasAgotado.isNotEmpty
              ? _danger.withValues(alpha: 0.25)
              : _warning.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _alertasAgotado.isNotEmpty ? _dangerBg : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              size: 16,
              color: _alertasAgotado.isNotEmpty ? _danger : _warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alertas de stock',
                  style: _t(size: 13, weight: FontWeight.w700)),
              Text(
                '$total producto${total != 1 ? 's' : ''} requiere${total == 1 ? '' : 'n'} atención',
                style: _t(size: 10, color: _muted2),
              ),
            ],
          )),
          if (_cargandoInsights)
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: Color(0xFF006C49))),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF0F0F2)),
        const SizedBox(height: 12),
        if (_alertasAgotado.isNotEmpty) ...[
          _seccionLabel('AGOTADOS', _danger),
          ..._alertasAgotado.take(4).map((item) {
            final nombre = item['producto_nombre'] as String? ?? '—';
            final cat    = item['categoria_nombre'] as String? ?? '';
            final pid    = item['producto'] as int?;
            return _stockRow(nombre, cat, 'Agotado', _danger, _dangerBg,
              onTap: () => _abrirDetalleDesdeAlerta(pid, nombre));
          }),
          if (_alertasAgotado.length > 4)
            _verMasTxt('+${_alertasAgotado.length - 4} más agotados', _danger,
              onTap: () {
                setState(() => _filtAlerta = 'agotado');
                _aplicarFiltros();
              }),
          if (_alertasBajo.isNotEmpty) const SizedBox(height: 8),
        ],
        if (_alertasBajo.isNotEmpty) ...[
          _seccionLabel('STOCK BAJO', _warning),
          ..._alertasBajo.take(5).map((item) {
            final nombre  = item['producto_nombre'] as String? ?? '—';
            final cat     = item['categoria_nombre'] as String? ?? '';
            final actual  = _toInt(item['stock_actual']);
            final minimo  = _toInt(item['stock_minimo']);
            final label   = minimo > 0 ? '$actual / $minimo uds' : '$actual uds';
            final pid     = item['producto'] as int?;
            return _stockRow(nombre, cat, label, _warning,
                const Color(0xFFFEF3C7),
                onTap: () => _abrirDetalleDesdeAlerta(pid, nombre));
          }),
          if (_alertasBajo.length > 5)
            _verMasTxt('+${_alertasBajo.length - 5} más con stock bajo', _warning,
              onTap: () {
                setState(() => _filtAlerta = 'bajo');
                _aplicarFiltros();
              }),
        ],
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // PANEL TURNO CAJERO
  // ══════════════════════════════════════════════════
  Widget _buildCajeroPanel(List<Producto> productos) {
    final agotados = productos.where((p) => p.stockActual <= 0).toList();
    // Si stockMinimo está configurado úsalo; si no, considera crítico ≤ 10 uds
    final criticos = productos.where((p) =>
        p.stockActual > 0 &&
        (p.stockMinimo > 0 && p.stockActual <= p.stockMinimo)).toList();
    final fmtMoney  = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final fmtDate   = DateFormat('d MMM', 'es');

    return SingleChildScrollView(
      child: Column(children: [

        // ── Encabezado ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informe de turno',
                    style: _t(size: 13, weight: FontWeight.w700,
                        color: Colors.white)),
                Text(DateFormat('EEEE d MMM · HH:mm', 'es')
                        .format(DateTime.now()),
                    style: _t(size: 10, color: Colors.white60)),
              ],
            )),
            GestureDetector(
              onTap: () {
                _cargarPanelCajero();
                _cargarInsights();
              },
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white54, size: 16),
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // ── 1. Stock crítico ────────────────────────
        _cajeroCard(
          icon: Icons.warning_rounded,
          iconColor: agotados.isNotEmpty ? _danger : _warning,
          iconBg: agotados.isNotEmpty ? _dangerBg : const Color(0xFFFEF3C7),
          title: 'Stock crítico',
          subtitle: '${agotados.length} agotados · ${criticos.length} bajos',
          loading: false,
          empty: agotados.isEmpty && criticos.isEmpty,
          emptyMsg: 'Todo el stock está bien',
          emptyIcon: Icons.check_circle_outline_rounded,
          child: Column(children: [
            if (agotados.isNotEmpty) ...[
              _seccionLabel('AGOTADOS', _danger),
              ...agotados.take(5).map((p) => _stockRow(
                p.nombre, p.categoria,
                '0 uds', _danger, _dangerBg,
              )),
              if (agotados.length > 5)
                _verMasTxt('${agotados.length - 5} más agotados', _danger),
            ],
            if (criticos.isNotEmpty) ...[
              if (agotados.isNotEmpty) const SizedBox(height: 8),
              _seccionLabel('STOCK BAJO', _warning),
              ...criticos.take(4).map((p) => _stockRow(
                p.nombre, p.categoria,
                '${p.stockActual.toInt()} uds', _warning,
                const Color(0xFFFEF3C7),
              )),
              if (criticos.length > 4)
                _verMasTxt('${criticos.length - 4} más con stock bajo',
                    _warning),
            ],
          ]),
        ),

        const SizedBox(height: 12),

        // ── 2. Separados activos ────────────────────
        _cajeroCard(
          icon: Icons.bookmark_rounded,
          iconColor: _green,
          iconBg: _greenBg,
          title: 'Separados activos',
          subtitle: '${_separadosActivos.length} pedido${_separadosActivos.length != 1 ? 's' : ''} reservado${_separadosActivos.length != 1 ? 's' : ''}',
          loading: _cargandoCajeroPanel,
          empty: _separadosActivos.isEmpty,
          emptyMsg: 'Sin separados activos',
          emptyIcon: Icons.bookmark_border_rounded,
          child: Column(
            children: _separadosActivos.take(5).map((s) {
              final vencido = s.fechaLimite != null &&
                  DateTime.tryParse(s.fechaLimite!)
                          ?.isBefore(DateTime.now()) ==
                      true;
              final porVencer = !vencido && s.fechaLimite != null &&
                  DateTime.tryParse(s.fechaLimite!)
                          ?.isBefore(DateTime.now().add(
                              const Duration(days: 3))) ==
                      true;
              final alertColor = vencido
                  ? _danger
                  : porVencer
                      ? _warning
                      : _green;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        s.clienteNombre.isNotEmpty
                            ? s.clienteNombre[0].toUpperCase() : '?',
                        style: _t(size: 13, weight: FontWeight.w800,
                            color: alertColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.clienteNombre,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 12, weight: FontWeight.w600)),
                      if (s.fechaLimite != null)
                        Text(
                          vencido ? 'Vencido' :
                          'Límite: ${fmtDate.format(DateTime.parse(s.fechaLimite!))}',
                          style: _t(size: 10, color: alertColor,
                              weight: FontWeight.w600),
                        ),
                    ],
                  )),
                  Text(fmtMoney.format(s.saldoPendiente),
                      style: _t(size: 12, weight: FontWeight.w700,
                          color: alertColor)),
                ]),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // ── 3. Movimientos recientes ────────────────
        _cajeroCard(
          icon: Icons.swap_horiz_rounded,
          iconColor: const Color(0xFF3F465C),
          iconBg: const Color(0xFFDAE2FD),
          title: 'Movimientos hoy',
          subtitle: '${_movimientos.length} registrado${_movimientos.length != 1 ? 's' : ''}',
          loading: _cargandoInsights,
          empty: _movimientos.isEmpty,
          emptyMsg: 'Sin movimientos hoy',
          emptyIcon: Icons.swap_horiz_rounded,
          child: Column(
            children: _movimientos.take(6).map((m) {
              final tipo     = m['tipo'] as String? ?? '';
              final nombre   = m['producto_nombre'] as String? ?? '—';
              final cantidad = m['cantidad'];
              final hora     = m['created_at'] != null
                  ? DateFormat('HH:mm').format(
                      (DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now()).toLocal())
                  : '';
              final (color, icon, prefix) = switch (tipo) {
                'entrada'  => (_green,   Icons.arrow_downward_rounded, '+'),
                'salida'   => (_danger,  Icons.arrow_upward_rounded,   '-'),
                'averia'   => (_warning, Icons.report_rounded,         ''),
                _          => (_muted2,  Icons.swap_horiz_rounded,     ''),
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(nombre,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 12, weight: FontWeight.w600))),
                  const SizedBox(width: 4),
                  Text('$prefix$cantidad',
                      style: _t(size: 12, weight: FontWeight.w700,
                          color: color)),
                  if (hora.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(hora, style: _t(size: 10, color: _muted2)),
                  ],
                ]),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _cajeroCard({
    required IconData icon,
    required Color    iconColor,
    required Color    iconBg,
    required String   title,
    required String   subtitle,
    required bool     loading,
    required bool     empty,
    required String   emptyMsg,
    required IconData emptyIcon,
    required Widget   child,
  }) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _t(size: 13, weight: FontWeight.w700)),
              Text(subtitle, style: _t(size: 10, color: _muted2)),
            ],
          )),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF0F0F2)),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: Color(0xFF006C49))))
        else if (empty)
          Row(children: [
            Icon(emptyIcon, size: 15, color: _muted2),
            const SizedBox(width: 6),
            Text(emptyMsg, style: _t(size: 12, color: _muted2)),
          ])
        else
          child,
      ]),
    );

  Widget _seccionLabel(String label, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label,
        style: _t(size: 9, weight: FontWeight.w800,
            color: color, letterSpacing: 0.8)),
  );

  Widget _stockRow(String nombre, String cat, String stock,
      Color color, Color bg, {VoidCallback? onTap}) {
    bool hovered = false;
    return StatefulBuilder(builder: (_, setH) => MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setH(() => hovered = true),
      onExit:  (_) => setH(() => hovered = false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 7),
          padding: onTap != null
              ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
              : EdgeInsets.zero,
          decoration: onTap != null ? BoxDecoration(
            color: hovered ? bg.withValues(alpha: 0.6) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ) : null,
          child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(7)),
          child: Icon(Icons.inventory_2_outlined, size: 13, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre, overflow: TextOverflow.ellipsis,
                style: _t(size: 12, weight: FontWeight.w600)),
            Text(cat.toUpperCase(),
                style: _t(size: 9, color: _muted2, letterSpacing: 0.5)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Text(stock,
              style: _t(size: 10, weight: FontWeight.w700, color: color)),
        ),
      ]),
        ),
      ),
    ));
  }

  Widget _verMasTxt(String label, Color color, {VoidCallback? onTap}) =>
    MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(label,
              style: _t(size: 10, weight: FontWeight.w600, color: color).copyWith(
                  decoration: onTap != null ? TextDecoration.underline : null,
                  decorationColor: color)),
        ),
      ),
    );

  Widget _topSellersCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Más vendidos',
            style: _t(size: 15, weight: FontWeight.w700))),
        Text('Ver reporte',
            style: _t(size: 12, weight: FontWeight.w600, color: _green)),
      ]),
      const SizedBox(height: 16),
      if (_cargandoInsights)
        const Center(child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2,
              color: Color(0xFF006C49)),
        ))
      else if (_topProductos.isEmpty)
        Text('Sin datos de ventas',
            style: _t(size: 13, color: _muted2))
      else
        ...List.generate(_topProductos.length, (i) {
          final item     = _topProductos[i];
          // El backend manda la clave 'producto' (no 'producto_nombre'):
          // por eso todos los puestos salían con "—".
          final nombre   = (item['producto'] ?? item['producto_nombre'])
                  ?.toString() ?? '—';
          final vendido  = _toDouble(item['total_vendido']);
          final ingresos = _toDouble(item['total_ingresos']);
          // La lista viene ordenada por plata vendida, así que la barra
          // también se mide en plata, contra el mayor de la lista. Antes se
          // medía en unidades contra el primero, y cualquiera que vendiera
          // más unidades que el #1 salía con la barra llena.
          final maxIng   = _topProductos.fold<double>(
              0, (m, e) => _toDouble(e['total_ingresos']) > m
                  ? _toDouble(e['total_ingresos']) : m);
          final pct      = maxIng > 0 ? ingresos / maxIng : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: i == 0
                      ? const Color(0xFF131B2E)
                      : _surfHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(child: Text('${i + 1}',
                    style: _t(size: 11, weight: FontWeight.w700,
                        color: i == 0 ? Colors.white : _muted))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(nombre,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 13, weight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Text('${_formatNum(vendido)} uds',
                        style: _t(size: 11, color: _muted2)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value:           pct.clamp(0.0, 1.0),
                          minHeight:       6,
                          backgroundColor: _surfHigh,
                          valueColor:      const AlwaysStoppedAnimation(
                              Color(0xFF006C49)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${Constants.moneda}${_formatNum(ingresos)}',
                        style: _t(size: 11, weight: FontWeight.w700,
                            color: _muted)),
                  ]),
                ],
              )),
            ]),
          );
        }),
    ]),
  );

  Widget _movimientosCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Movimientos Recientes',
            style: _t(size: 15, weight: FontWeight.w700))),
        Icon(Icons.history_rounded, color: _muted2, size: 18),
      ]),
      const SizedBox(height: 16),
      if (_cargandoInsights)
        const Center(child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2,
              color: Color(0xFF006C49)),
        ))
      else if (_movimientos.isEmpty)
        Text('Sin movimientos recientes',
            style: _t(size: 13, color: _muted2))
      else
        ...List.generate(_movimientos.length, (i) {
          final mov      = _movimientos[i];
          final tipo     = mov['tipo'] as String? ?? '';
          final producto = mov['producto_nombre'] as String? ?? '—';
          final empleado = mov['empleado_nombre'] as String? ?? 'Sistema';
          final cantidad = _toDouble(mov['cantidad']);
          final fecha    = _tiempoRelativo(mov['created_at'] as String?);

          final (dotColor, dotBg, signo) = switch (tipo) {
            'entrada'       => (_green, _greenBg, '+'),
            'salida'        => (_danger, _dangerBg, '-'),
            'dano'          => (_danger, _dangerBg, '-'),
            'transferencia' => (const Color(0xFF3F465C),
                const Color(0xFFDAE2FD), '↔'),
            _               => (_muted, _surfHigh, '~'),
          };

          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _mostrarDetalleMovimiento(mov, dotColor, dotBg, signo),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                      color: dotBg, shape: BoxShape.circle),
                  child: Center(child: Text(signo,
                      style: _t(size: 14, weight: FontWeight.w700,
                          color: dotColor))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(producto,
                        overflow: TextOverflow.ellipsis,
                        style: _t(size: 13, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${_tipoLabel(tipo)} · ${cantidad.toStringAsFixed(0)} uds',
                        style: _t(size: 11, color: _muted)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.person_outline_rounded,
                          size: 11, color: _muted2),
                      const SizedBox(width: 4),
                      Text(empleado,
                          style: _t(size: 11, color: _muted2)),
                      const SizedBox(width: 6),
                      Text(fecha,
                          style: _t(size: 11, color: _muted2)),
                    ]),
                  ],
                )),
                Icon(Icons.chevron_right_rounded, size: 16, color: _muted2),
              ]),
            ),
          );
        }),
    ]),
  );

  String _tipoLabel(String tipo) => switch (tipo) {
    'entrada'       => 'Entrada',
    'salida'        => 'Salida',
    'ajuste'        => 'Ajuste',
    'transferencia' => 'Transferencia',
    'dano'          => 'Daño/Pérdida',
    _               => tipo,
  };

  void _mostrarDetalleMovimiento(
    Map<String, dynamic> mov,
    Color dotColor,
    Color dotBg,
    String signo,
  ) {
    final tipo        = mov['tipo']             as String? ?? '';
    final producto    = mov['producto_nombre']  as String? ?? '—';
    final categoria   = mov['categoria_nombre'] as String? ?? '';
    final empleado    = mov['empleado_nombre']  as String? ?? 'Sistema';
    final cantidad    = _toDouble(mov['cantidad']);
    final referencia  = mov['referencia_tipo']  as String? ?? '';
    final observacion = mov['observacion']      as String? ?? '';
    final precio      = _toDouble(mov['precio_venta']);
    final codigo      = mov['codigo_barras']    as String? ?? '';
    final fmt         = NumberFormat('#,##0', 'es_CO');

    // Fecha completa parseada
    String fechaCompleta = '—';
    final rawFecha = mov['created_at'] as String?;
    if (rawFecha != null) {
      try {
        final dt = DateTime.parse(rawFecha).toLocal();
        fechaCompleta =
            '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'
            '  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) {}
    }

    // Referencia legible
    final referenciaLabel = switch (referencia) {
      'venta'       => 'Venta (salida por FAC)',
      'compra'      => 'Compra / Entrada',
      'ajuste'      => 'Ajuste manual',
      'transferencia' => 'Transferencia',
      'devolucion'  => 'Devolución',
      ''            => '',
      _             => referencia,
    };

    final (badgeColor, badgeBg) = switch (tipo) {
      'entrada'       => (const Color(0xFF006C49), const Color(0xFFDCFCE7)),
      'salida'        => (const Color(0xFFBE123C), const Color(0xFFFEE2E2)),
      'dano'          => (const Color(0xFFBE123C), const Color(0xFFFEE2E2)),
      'transferencia' => (const Color(0xFF3F465C), const Color(0xFFDAE2FD)),
      _               => (_muted, _surfHigh),
    };

    Widget seccion(String titulo) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(titulo.toUpperCase(),
          style: _t(size: 10, weight: FontWeight.w700,
              color: _muted2, letterSpacing: .8)),
    );

    Widget fila(IconData icon, String label, String valor, {Color? valColor}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 15, color: _muted2),
            const SizedBox(width: 10),
            SizedBox(width: 90,
                child: Text(label, style: _t(size: 12, color: _muted))),
            Expanded(child: Text(
              valor.isEmpty ? '—' : valor,
              style: _t(size: 12, weight: FontWeight.w600,
                  color: valColor),
            )),
          ]),
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20,
            20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // handle
            Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: _muted2.withOpacity(.35),
                borderRadius: BorderRadius.circular(2),
              ),
            )),

            // ── Header ──────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: dotBg, shape: BoxShape.circle),
                child: Center(child: Text(signo,
                    style: _t(size: 18, weight: FontWeight.w700,
                        color: dotColor))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(producto,
                    style: _t(size: 15, weight: FontWeight.w700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_tipoLabel(tipo),
                        style: _t(size: 11, weight: FontWeight.w600,
                            color: badgeColor)),
                  ),
                  if (categoria.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _surfHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(categoria,
                          style: _t(size: 11, color: _muted)),
                    ),
                  ],
                ]),
              ])),
            ]),
            const SizedBox(height: 20),
            Divider(color: _surfHigh, height: 1),
            const SizedBox(height: 14),

            // ── Movimiento ──────────────────────────────────────
            seccion('Detalle del movimiento'),
            fila(Icons.swap_vert_rounded, 'Cantidad',
                '${cantidad % 1 == 0 ? cantidad.toInt() : cantidad} uds'),
            fila(Icons.calendar_today_outlined, 'Fecha', fechaCompleta),
            fila(Icons.person_outline_rounded, 'Empleado', empleado),
            if (referenciaLabel.isNotEmpty)
              fila(Icons.link_rounded, 'Origen', referenciaLabel),
            if (observacion.isNotEmpty)
              fila(Icons.notes_rounded, 'Observación', observacion),

            const SizedBox(height: 4),
            Divider(color: _surfHigh, height: 1),
            const SizedBox(height: 14),

            // ── Producto ────────────────────────────────────────
            seccion('Información del producto'),
            if (categoria.isNotEmpty)
              fila(Icons.category_outlined, 'Categoría', categoria),
            if (precio > 0)
              fila(Icons.sell_outlined, 'Precio venta',
                  '\$${fmt.format(precio)}',
                  valColor: const Color(0xFF006C49)),
            if (codigo.isNotEmpty)
              fila(Icons.qr_code_rounded, 'Código', codigo),

            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // STATES
  // ══════════════════════════════════════════════════════
  Widget _loadingState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(
                color: Color(0xFF006C49), strokeWidth: 2.5),
          ),
        ),
        const SizedBox(height: 14),
        Text('Cargando inventario…',
            style: _t(size: 13, weight: FontWeight.w600, color: _muted)),
      ],
    ),
  );

  Widget _emptyState(bool esCajero) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _surfHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 34, color: _muted2),
          ),
          const SizedBox(height: 16),
          Text(
            _activoFiltro == 'false'
                ? 'No hay productos inactivos'
                : 'No hay productos registrados',
            style: _t(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _activoFiltro == 'false'
                ? 'Todo tu inventario está activo.'
                : 'Agrega el primero con "Nuevo producto".',
            textAlign: TextAlign.center,
            style: _t(size: 13, color: _muted),
          ),
        ],
      ),
    ),
  );

  Widget _banner(String msg,
      {required bool isError, required VoidCallback onClose}) {
    final color = isError ? _danger : _green;
    final bg    = isError ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: color, size: 17),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: _t(size: 13, weight: FontWeight.w600, color: color))),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close_rounded,
                size: 14, color: color.withValues(alpha: 0.7)),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUTTONS
  // ══════════════════════════════════════════════════════
  Widget _btnPrimario({
    required IconData     icon,
    required String       label,
    required VoidCallback onTap,
  }) =>
      ElevatedButton.icon(
        onPressed: onTap,
        icon:  Icon(icon, size: 17),
        label: Text(label,
            style: _t(size: 13, weight: FontWeight.w700, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          elevation:       0,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _btnSecundario({
    required IconData      icon,
    required String        label,
    required VoidCallback? onTap,
  }) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon:  Icon(icon, size: 17),
        label: Text(label,
            style: _t(size: 13, weight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          elevation:       0,
          foregroundColor: _text,
          backgroundColor: _surface,
          side: const BorderSide(color: Color(0xFFC6C6CD)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _actionBtn({
    required IconData     icon,
    required Color        color,
    required String       tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color:         color.withValues(alpha: 0.08),
              borderRadius:  BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
// KARDEX MÓVIL (carga los movimientos y los muestra con KardexMovil)
// ═══════════════════════════════════════════════════════════════
class _KardexMovilCarga extends StatefulWidget {
  final Producto          producto;
  final int               tiendaId;
  final String            tienda;
  final double?           stock;
  final InventarioService service;

  const _KardexMovilCarga({
    required this.producto,
    required this.tiendaId,
    required this.tienda,
    required this.stock,
    required this.service,
  });

  @override
  State<_KardexMovilCarga> createState() => _KardexMovilCargaState();
}

class _KardexMovilCargaState extends State<_KardexMovilCarga> {
  List<MovimientoKardexMovil> _movs = const [];
  bool    _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final r = await widget.service.getMovimientosProducto(
      productoId: widget.producto.id,
      tiendaId:   widget.tiendaId,
    );
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (r['success'] == true) {
        _movs = (r['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MovimientoKardexMovil.fromJson)
            .toList();
      } else {
        _error = (r['error'] ?? 'No se pudo cargar el kardex').toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) => KardexMovil(
        producto:     widget.producto.nombre,
        tienda:       widget.tienda,
        stockActual:  widget.stock,
        movimientos:  _movs,
        cargando:     _cargando,
        error:        _error,
        onReintentar: _cargar,
      );
}

// KARDEX SHEET
// ═══════════════════════════════════════════════════════════════
class _KardexSheet extends StatefulWidget {
  final Producto          producto;
  final int               tiendaId;
  final InventarioService service;

  const _KardexSheet({
    required this.producto,
    required this.tiendaId,
    required this.service,
  });

  @override
  State<_KardexSheet> createState() => _KardexSheetState();
}

class _KardexSheetState extends State<_KardexSheet> {
  List<Map<String, dynamic>> _movimientos = [];
  bool   _cargando = true;
  String _error    = '';

  static const _bg      = Color(0xFFF7F9FB);
  static const _surface = Colors.white;
  static const _border  = Color(0xFFE2E8F0);
  static const _text    = Color(0xFF1E293B);
  static const _muted   = Color(0xFF64748B);
  static const _muted2  = Color(0xFF94A3B8);
  static const _green   = Color(0xFF006C49);
  static const _greenBg = Color(0xFFDCFCE7);
  static const _danger  = Color(0xFFBA1A1A);
  static const _amber   = Color(0xFFF59E0B);
  static const _blue    = Color(0xFF0284C7);
  static const _blueBg  = Color(0xFFE0F2FE);

  static final _fmt     = NumberFormat('#,##0.##', 'es_CO');
  static final _fmtDate = DateFormat('d MMM yyyy · HH:mm', 'es');

  TextStyle _t({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight,
          color: color ?? _text);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = ''; });
    final res = await widget.service.getMovimientosProducto(
      productoId: widget.producto.id,
      tiendaId:   widget.tiendaId,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _movimientos = (res['data'] as List).cast<Map<String, dynamic>>();
        _cargando    = false;
      });
    } else {
      setState(() {
        _error    = res['error'] ?? 'Error al cargar movimientos';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.80;

    return Container(
      height:      h,
      decoration:  const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.timeline_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kardex',
                    style: _t(size: 16, weight: FontWeight.w700)),
                Text(widget.producto.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: _t(size: 12, color: _muted)),
              ],
            )),
            GestureDetector(
              onTap: _cargar,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 16, color: _muted),
              ),
            ),
          ]),
        ),

        const Divider(height: 1, color: Color(0xFFEBEFF3)),

        // Contenido
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(
          color: Color(0xFF006C49), strokeWidth: 2));
    }
    if (_error.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _danger, size: 32),
          const SizedBox(height: 12),
          Text(_error, style: _t(size: 13, color: _muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: _cargar,
              child: Text('Reintentar', style: _t(size: 13, color: _green))),
        ]),
      ));
    }
    if (_movimientos.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.timeline_rounded,
                size: 28, color: _muted2),
          ),
          const SizedBox(height: 16),
          Text('Sin movimientos registrados',
              style: _t(size: 14, weight: FontWeight.w600, color: _muted)),
          const SizedBox(height: 6),
          Text('Los movimientos de este producto\naparecerán aquí.',
              textAlign: TextAlign.center,
              style: _t(size: 12, color: _muted2)),
        ],
      ));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount:      _movimientos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder:   (_, i) => _movCard(_movimientos[i]),
    );
  }

  Widget _movCard(Map<String, dynamic> m) {
    final tipo       = m['tipo'] as String? ?? '';
    final cantidad   = _toDouble(m['cantidad']);
    final empleado   = m['empleado_nombre'] as String?;
    final refTipo    = m['referencia_tipo'] as String?;
    final obs        = m['observacion'] as String?;
    final createdAt  = m['created_at'] as String?;
    DateTime? dt;
    try { dt = createdAt != null ? DateTime.parse(createdAt).toLocal() : null; } catch (_) {}

    final (icon, color, bg, label, signo) = _tipoConfig(tipo);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: bg,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label,
                    style: _t(size: 9, weight: FontWeight.w800,
                        color: color)),
              ),
              const Spacer(),
              Text('$signo${_fmt.format(cantidad)} uds',
                  style: _t(size: 14, weight: FontWeight.w800, color: color)),
            ]),
            if (dt != null) ...[
              const SizedBox(height: 4),
              Text(_fmtDate.format(dt),
                  style: _t(size: 11, color: _muted2)),
            ],
            if (empleado != null || refTipo != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                if (empleado != null) ...[
                  const Icon(Icons.person_outline_rounded,
                      size: 11, color: _muted2),
                  const SizedBox(width: 4),
                  Flexible(child: Text(empleado,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 11, color: _muted))),
                ],
                if (refTipo != null) ...[
                  if (empleado != null) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_labelRef(refTipo),
                        style: _t(size: 9, color: _muted2,
                            weight: FontWeight.w600)),
                  ),
                ],
              ]),
            ],
            if (obs != null && obs.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(obs,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: _t(size: 11, color: _muted2,
                      weight: FontWeight.w400)),
            ],
          ],
        )),
      ]),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  (IconData, Color, Color, String, String) _tipoConfig(String tipo) {
    return switch (tipo) {
      'entrada'       => (Icons.add_circle_rounded,     _green,  _greenBg,
                          'ENTRADA',     '+'),
      'salida'        => (Icons.remove_circle_rounded,  _danger,
                          const Color(0xFFFFDAD6),      'SALIDA',      '-'),
      'ajuste'        => (Icons.tune_rounded,           _amber,
                          const Color(0xFFFEF3C7),      'AJUSTE',      ''),
      'transferencia' => (Icons.swap_horiz_rounded,     _blue,   _blueBg,
                          'TRANSFERENCIA', ''),
      'daño'          => (Icons.broken_image_rounded,   _danger,
                          const Color(0xFFFFDAD6),      'DAÑO',        '-'),
      _               => (Icons.circle_outlined,        _muted,
                          const Color(0xFFF1F5F9),      tipo.toUpperCase(), ''),
    };
  }

  String _labelRef(String ref) {
    return switch (ref) {
      'venta'           => 'Venta',
      'compra'          => 'Compra',
      'devolucion'      => 'Devolución',
      'ajuste_manual'   => 'Ajuste',
      'transferencia'   => 'Transferencia',
      'separado'        => 'Separado',
      _                 => ref,
    };
  }
}


// ── Modal de Transferencia ─────────────────────────────────────
class _TransferenciaSheet extends StatefulWidget {
  final Producto               producto;
  final int                    tiendaOrigenId;
  final List<Map<String, dynamic>> tiendas;
  final VoidCallback           onTransferida;

  const _TransferenciaSheet({
    required this.producto,
    required this.tiendaOrigenId,
    required this.tiendas,
    required this.onTransferida,
  });

  @override
  State<_TransferenciaSheet> createState() => _TransferenciaSheetState();
}

class _TransferenciaSheetState extends State<_TransferenciaSheet> {
  final _cantCtrl = TextEditingController();
  final _obsCtrl  = TextEditingController();
  int?   _tiendaDestinoId;
  bool   _enviando = false;
  String _error    = '';

  static const _green    = Color(0xFF16A34A);
  static const _greenDk  = Color(0xFF15803D);
  static const _surface  = Color(0xFFF8FAFC);
  static const _border   = Color(0xFFE2E8F0);
  static const _text     = Color(0xFF1E293B);
  static const _muted    = Color(0xFF64748B);
  static const _red      = Color(0xFFDC2626);

  @override
  void dispose() {
    _cantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _tiendasDestino =>
      widget.tiendas.where((t) => t['id'] != widget.tiendaOrigenId).toList();

  String _nombreTienda(int id) =>
      widget.tiendas.firstWhere(
          (t) => t['id'] == id,
          orElse: () => {'nombre': 'Tienda $id'})['nombre'] as String;

  Future<void> _enviar() async {
    final txt  = _cantCtrl.text.trim();
    final cant = RegExp(r'\d').hasMatch(txt) ? leerNumeroExcel(txt) : 0.0;
    if (cant <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor a cero.');
      return;
    }
    if (widget.producto.unidadMedida == 'unidad' &&
        cant != cant.roundToDouble()) {
      setState(() => _error = 'Solo unidades enteras.');
      return;
    }
    if (_tiendaDestinoId == null) {
      setState(() => _error = 'Selecciona la tienda de destino.');
      return;
    }
    setState(() { _enviando = true; _error = ''; });
    try {
      await ApiClient.instance.post('/productos/transferencias/', data: {
        'producto_id':       widget.producto.id,
        'tienda_origen_id':  widget.tiendaOrigenId,
        'tienda_destino_id': _tiendaDestinoId,
        'cantidad':          cant,
        'observacion':       _obsCtrl.text.trim(),
      });
      widget.onTransferida();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${cant.toStringAsFixed(cant % 1 == 0 ? 0 : 1)} u. de "${widget.producto.nombre}" '
            'transferidas a ${_nombreTienda(_tiendaDestinoId!)}.',
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      String msg = 'Error al transferir.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          msg = data['error'].toString();
        }
      } else if (e is Exception) {
        msg = e.toString().replaceAll('Exception: ', '');
      }
      setState(() {
        _error    = msg;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinos = _tiendasDestino;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: _border, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // Título
        Row(children: [
          const Icon(Icons.swap_horiz_rounded, color: _green, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Transferir ${widget.producto.nombre}',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: _text),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
        const SizedBox(height: 4),
        Text(
          'Origen: ${_nombreTienda(widget.tiendaOrigenId)}',
          style: GoogleFonts.inter(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 16),

        // Tienda destino
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
            color: _surface,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _tiendaDestinoId,
              isExpanded: true,
              hint: Text('Tienda de destino',
                  style: GoogleFonts.inter(fontSize: 13, color: _muted)),
              items: destinos.map((t) => DropdownMenuItem<int>(
                value: t['id'] as int,
                child: Text(t['nombre'] as String,
                    style: GoogleFonts.inter(fontSize: 13, color: _text)),
              )).toList(),
              onChanged: (v) => setState(() => _tiendaDestinoId = v),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Cantidad
        TextField(
          controller: _cantCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(fontSize: 14, color: _text),
          decoration: InputDecoration(
            labelText: 'Cantidad a transferir',
            labelStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
            filled: true, fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 2)),
          ),
        ),
        const SizedBox(height: 12),

        // Observación
        TextField(
          controller: _obsCtrl,
          style: GoogleFonts.inter(fontSize: 13, color: _text),
          decoration: InputDecoration(
            labelText: 'Observación (opcional)',
            labelStyle: GoogleFonts.inter(fontSize: 12, color: _muted),
            filled: true, fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 2)),
          ),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withAlpha(80)),
            ),
            child: Text(_error,
                style: GoogleFonts.inter(fontSize: 12, color: _red)),
          ),
        ],
        const SizedBox(height: 16),

        // Botones
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: _enviando ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text('Cancelar',
                style: GoogleFonts.inter(fontSize: 13, color: _muted)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _enviando ? null : _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _greenDk,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _enviando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Transferir',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: Colors.white)),
          )),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AJUSTE DE STOCK SHEET
// ═══════════════════════════════════════════════════════════════

class _AjusteStockSheet extends StatefulWidget {
  final Producto     producto;
  final int          tiendaId;
  final VoidCallback onAjustado;
  final String       tipoInicial; // 'entrada' | 'salida' | 'ajuste' | 'averia'

  const _AjusteStockSheet({
    required this.producto,
    required this.tiendaId,
    required this.onAjustado,
    this.tipoInicial = 'entrada',
  });

  @override
  State<_AjusteStockSheet> createState() => _AjusteStockSheetState();
}

class _AjusteStockSheetState extends State<_AjusteStockSheet> {
  final _cantCtrl = TextEditingController();
  final _obsCtrl  = TextEditingController();
  final _service  = InventarioService();

  late String _tipo = widget.tipoInicial; // 'entrada' | 'salida' | 'ajuste' | 'averia'
  bool   _enviando = false;
  String _error    = '';

  static const _greenDk = Color(0xFF15803D);
  static const _surface = Color(0xFFF8FAFC);
  static const _border  = Color(0xFFE2E8F0);
  static const _text    = Color(0xFF1E293B);
  static const _muted   = Color(0xFF64748B);
  static const _red     = Color(0xFFDC2626);
  static const _indigo  = Color(0xFF3730A3);
  static const _orange  = Color(0xFFB45309);

  @override
  void dispose() {
    _cantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  // Accent color según el tipo de ajuste
  Color get _accentColor => switch (_tipo) {
    'entrada' => _greenDk,
    'salida'  => _red,
    'ajuste'  => _indigo,
    'averia'  => _orange,
    _         => _greenDk,
  };

  Future<void> _enviar() async {
    // Acepta "12,5" y "12.5". El conteo ("ajuste") puede dejar el stock en 0.
    final txt  = _cantCtrl.text.trim();
    final cant = RegExp(r'\d').hasMatch(txt) ? leerNumeroExcel(txt) : -1.0;
    if (cant < 0 || (_tipo != 'ajuste' && cant == 0)) {
      setState(() => _error = _tipo == 'ajuste'
          ? 'Escribe cuántas unidades hay (puede ser 0).'
          : 'Ingresa una cantidad mayor a cero.');
      return;
    }
    // Por unidad no se parte: 2,5 aretes no existen.
    if (widget.producto.unidadMedida == 'unidad' &&
        cant != cant.roundToDouble()) {
      setState(() => _error = 'Solo unidades enteras.');
      return;
    }
    setState(() { _enviando = true; _error = ''; });
    try {
      final result = await _service.ajustarStock(
        productoId:  widget.producto.id,
        tiendaId:    widget.tiendaId,
        cantidad:    cant,
        tipo:        _tipo,
        observacion: _obsCtrl.text.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final nuevoStock   = result['data']?['stock_actual'] ?? '—';
        final stockAverias = result['data']?['stock_averias'];
        widget.onAjustado();
        Navigator.pop(context);
        final msg = _tipo == 'averia'
            ? 'Avería registrada · ${widget.producto.nombre} · averías: $stockAverias u.'
            : 'Stock ajustado · ${widget.producto.nombre} → $nuevoStock u.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: _tipo == 'averia' ? _orange : _greenDk,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      } else {
        setState(() {
          _error   = result['error'] ?? 'Error al ajustar stock.';
          _enviando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error    = e.toString().replaceAll('Exception: ', '');
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final stockActual = widget.producto.stockActual;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: _border, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // Título + stock actual
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.tune_rounded, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ajustar stock',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
            Text(widget.producto.nombre,
              style: GoogleFonts.inter(fontSize: 12, color: _muted),
              overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Stock actual',
                style: GoogleFonts.inter(fontSize: 9, color: _muted,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              Text('${stockActual.toStringAsFixed(stockActual % 1 == 0 ? 0 : 1)} u.',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800,
                    color: stockActual <= 0 ? _red : _text)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        // Selector de tipo
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            _tipoBtn('entrada', 'Entrada',  Icons.add_circle_outline_rounded,    _greenDk),
            _tipoBtn('salida',  'Salida',   Icons.remove_circle_outline_rounded,  _red),
            _tipoBtn('ajuste',  'Ajuste',   Icons.swap_vert_rounded,              _indigo),
            _tipoBtn('averia',  'Avería',   Icons.warning_amber_rounded,          _orange),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          switch (_tipo) {
            'entrada' => 'Suma unidades al stock actual',
            'salida'  => 'Resta unidades del stock actual',
            'ajuste'  => 'Reemplaza el stock con el valor exacto',
            'averia'  => 'Mueve unidades al stock de averías',
            _         => '',
          },
          style: GoogleFonts.inter(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 16),

        // Campo cantidad
        TextField(
          controller: _cantCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: switch (_tipo) {
              'ajuste'  => 'Nuevo stock total',
              'averia'  => 'Unidades averiadas',
              _         => 'Cantidad',
            },
            labelStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
            prefixIcon: Icon(switch (_tipo) {
              'entrada' => Icons.add_rounded,
              'salida'  => Icons.remove_rounded,
              'averia'  => Icons.warning_amber_rounded,
              _         => Icons.sync_rounded,
            }, size: 18, color: accent),
            suffixText: 'u.',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.5)),
          ),
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          autofocus: true,
        ),
        const SizedBox(height: 10),

        // Campo observación
        TextField(
          controller: _obsCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Motivo / observación (opcional)',
            labelStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
            prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.5)),
          ),
          style: GoogleFonts.inter(fontSize: 13),
        ),
        const SizedBox(height: 10),

        // Error
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDAD6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 15, color: _red),
              const SizedBox(width: 8),
              Expanded(child: Text(_error,
                  style: GoogleFonts.inter(fontSize: 12, color: _red))),
            ]),
          ),

        // Botones
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cancelar',
                style: GoogleFonts.inter(fontSize: 13, color: _muted)),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: _enviando ? null : _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _enviando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('Confirmar ajuste',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700)),
          )),
        ]),
      ]),
    );
  }

  Widget _tipoBtn(String value, String label, IconData icon, Color color) {
    final active = _tipo == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _tipo = value; _error = ''; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: active ? Border.all(color: color.withValues(alpha: 0.4)) : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: active ? color : _muted),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: active ? color : _muted)),
          ]),
        ),
      ),
    );
  }
}
