// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api_client.dart';
import '../../services/documento_service.dart';

// ── palette ───────────────────────────────────────────────────────────────────
const _teal      = Color(0xFF006C49);
const _tealBg    = Color(0xFFE8FFF4);
const _bg        = Color(0xFFF7F9FB);
const _surface   = Colors.white;
const _border    = Color(0xFFE0E3E5);
const _textPri   = Color(0xFF191C1E);
const _textMuted = Color(0xFF76777D);
const _rose      = Color(0xFFBA1A1A);

// ── tipo metadata ─────────────────────────────────────────────────────────────
class _Tipo {
  static const _colors = <String, Color>{
    'venta':      Color(0xFF006C49),
    'separado':   Color(0xFF3730A3),
    'abono':      Color(0xFFB45309),
    'cierre':     Color(0xFF374151),
    'devolucion': Color(0xFFBA1A1A),
    'reporte':    Color(0xFF0284C7),
    'inventario': Color(0xFF7C3AED),
    'compra':     Color(0xFF0369A1),
    'recepcion':  Color(0xFF047857),
  };
  static const _bgs = <String, Color>{
    'venta':      Color(0xFFE8FFF4),
    'separado':   Color(0xFFEEF2FF),
    'abono':      Color(0xFFFEF3C7),
    'cierre':     Color(0xFFF3F4F6),
    'devolucion': Color(0xFFFFF1F2),
    'reporte':    Color(0xFFE0F2FE),
    'inventario': Color(0xFFF5F3FF),
    'compra':     Color(0xFFE0F2FE),
    'recepcion':  Color(0xFFECFDF5),
  };
  static const _icons = <String, IconData>{
    'venta':      Icons.receipt_rounded,
    'separado':   Icons.bookmark_rounded,
    'abono':      Icons.payments_rounded,
    'cierre':     Icons.lock_clock_rounded,
    'devolucion': Icons.assignment_return_rounded,
    'reporte':    Icons.bar_chart_rounded,
    'inventario': Icons.inventory_2_rounded,
    'compra':     Icons.shopping_cart_rounded,
    'recepcion':  Icons.local_shipping_rounded,
  };
  static const _labels = <String, String>{
    'venta':      'VENTA',
    'separado':   'SEPARADO',
    'abono':      'ABONO',
    'cierre':     'CIERRE',
    'devolucion': 'DEVOLUCIÓN',
    'reporte':    'REPORTE',
    'inventario': 'INVENTARIO',
    'compra':     'COMPRA',
    'recepcion':  'RECEPCIÓN',
  };
  static Color    color(String t) => _colors[t] ?? const Color(0xFF374151);
  static Color    bg(String t)    => _bgs[t]    ?? const Color(0xFFF3F4F6);
  static IconData icon(String t)  => _icons[t]  ?? Icons.description_rounded;
  static String   label(String t) => _labels[t] ?? t.toUpperCase();
}

// ── models ────────────────────────────────────────────────────────────────────

class _DocRemoto {
  final int      id;
  final String   tipo;
  final String   nombre;
  final DateTime fecha;
  final int      sizeKb;
  final String   empleadoNombre;
  final String   tiendaNombre;
  final String   empresaNombre;
  const _DocRemoto({
    required this.id, required this.tipo, required this.nombre,
    required this.fecha, required this.sizeKb, required this.empleadoNombre,
    required this.tiendaNombre, required this.empresaNombre,
  });
  factory _DocRemoto.fromJson(Map<String, dynamic> j) => _DocRemoto(
    id: j['id'] as int, tipo: j['tipo'] as String, nombre: j['nombre'] as String,
    fecha: DateTime.parse(j['fecha'] as String).toLocal(),
    sizeKb: j['size_kb'] as int,
    empleadoNombre: (j['empleado_nombre'] as String?) ?? '',
    tiendaNombre:   (j['tienda_nombre']   as String?) ?? '',
    empresaNombre:  (j['empresa_nombre']  as String?) ?? '',
  );
  String get displayNombre => nombre.endsWith('.pdf')
      ? nombre.substring(0, nombre.length - 4) : nombre;
}

class _DocLocal {
  final File          file;
  final TipoDocumento tipo;
  _DocLocal({required this.file, required this.tipo});
  String get displayId {
    final base = file.uri.pathSegments.last.replaceAll('.pdf', '');
    return base
        .replaceAll(RegExp(r'_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}$'), '')
        .replaceAll(RegExp(r'_\d{13}$'), '');
  }
  DateTime get fecha  => file.lastModifiedSync();
  int      get sizeKb => (file.lengthSync() / 1024).ceil();
}

enum _Tab { nube, local }

// ── screen ────────────────────────────────────────────────────────────────────

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});
  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final _service    = DocumentoService.instance;
  final _searchCtrl = TextEditingController();

  _Tab _tab = _Tab.nube;

  // remote
  List<_DocRemoto> _remoteDocs    = [];
  bool             _loadingRemote = false;
  String?          _remoteError;
  String?          _filtroRemote;        // tipo string
  final Set<int>   _abriendo = {};
  _DocRemoto?      _selectedRemoto;

  // local
  List<_DocLocal> _localDocs    = [];
  bool            _loadingLocal = false;
  String?         _localError;
  TipoDocumento?  _filtroLocal;
  _DocLocal?      _selectedLocal;
  String          _rutaRaiz = '';

  String _query = '';

  @override
  void initState() {
    super.initState();
    _cargarRemote();
    _cargarLocal();
    _loadRuta();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadRuta() async {
    if (kIsWeb) return;
    try {
      final r = await _service.rutaRaiz();
      if (mounted) setState(() => _rutaRaiz = r);
    } catch (_) {}
  }

  // ── remote ──────────────────────────────────────────────────────────────────

  Future<void> _cargarRemote() async {
    if (!mounted) return;
    setState(() { _loadingRemote = true; _remoteError = null; });
    try {
      final params = <String, dynamic>{};
      if (_filtroRemote != null) params['tipo'] = _filtroRemote;
      final res = await ApiClient.instance.get('/documentos/', queryParameters: params.isEmpty ? null : params);
      final list = (res.data as List).map((j) => _DocRemoto.fromJson(j as Map<String, dynamic>)).toList();
      if (mounted) setState(() { _remoteDocs = list; _loadingRemote = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingRemote = false; _remoteError = 'No se pudo conectar al servidor.'; });
    }
  }

  Future<void> _abrirRemoto(_DocRemoto doc) async {
    if (kIsWeb || _abriendo.contains(doc.id)) return;
    setState(() => _abriendo.add(doc.id));
    try {
      final res = await ApiClient.instance.get(
        '/documentos/${doc.id}/pdf/',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes  = res.data as List<int>;
      final tmpDir = await getTemporaryDirectory();
      final safe   = doc.nombre.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path   = '${tmpDir.path}${Platform.pathSeparator}$safe';
      await File(path).writeAsBytes(bytes, flush: true);
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo abrir el documento');
    } finally {
      if (mounted) setState(() => _abriendo.remove(doc.id));
    }
  }

  // ── local ────────────────────────────────────────────────────────────────────

  Future<void> _cargarLocal() async {
    if (!mounted) return;
    setState(() => _loadingLocal = true);
    try {
      List<_DocLocal> docs;
      if (_filtroLocal == null) {
        final results = await Future.wait(
          TipoDocumento.values.map((t) => _service
              .listar(t)
              .then((fs) => fs.map((f) => _DocLocal(file: f, tipo: t)).toList())),
        );
        docs = results.expand((l) => l).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
      } else {
        final files = await _service.listar(_filtroLocal!);
        docs = files.map((f) => _DocLocal(file: f, tipo: _filtroLocal!)).toList();
      }
      if (mounted) setState(() { _localDocs = docs; _loadingLocal = false; _localError = null; });
    } catch (_) {
      if (mounted) setState(() { _loadingLocal = false; _localError = 'Error al cargar documentos locales.'; });
    }
  }

  Future<void> _abrirLocal(_DocLocal doc) async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', doc.file.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [doc.file.path]);
      } else {
        await Process.run('xdg-open', [doc.file.path]);
      }
    } catch (_) {
      _snack('No se pudo abrir el archivo');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: _rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── filtered lists ───────────────────────────────────────────────────────────

  List<_DocRemoto> get _remotoFiltrados => _remoteDocs.where((d) {
    if (_query.isEmpty) return true;
    return d.displayNombre.toLowerCase().contains(_query.toLowerCase()) ||
           d.tiendaNombre.toLowerCase().contains(_query.toLowerCase()) ||
           d.empleadoNombre.toLowerCase().contains(_query.toLowerCase());
  }).toList();

  List<_DocLocal> get _localFiltrados => _localDocs.where((d) {
    if (_query.isEmpty) return true;
    return d.displayId.toLowerCase().contains(_query.toLowerCase());
  }).toList();

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide  = MediaQuery.of(context).size.width >= 900;
    final isNube  = _tab == _Tab.nube;

    final hasSelected = isWide && (isNube ? _selectedRemoto != null : _selectedLocal != null);

    final listColumn = Column(children: [
      _buildHeader(),
      if (isNube  && _remoteError != null) _errorBanner(_remoteError!, _cargarRemote),
      if (!isNube && _localError  != null) _errorBanner(_localError!,  _cargarLocal),
      Expanded(child: isNube ? _buildNubeList(isWide) : _buildLocalList(isWide)),
    ]);

    if (!hasSelected) {
      return Scaffold(backgroundColor: _bg, body: listColumn);
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Row(children: [
        SizedBox(width: 420, child: listColumn),
        const VerticalDivider(width: 1, color: _border),
        Expanded(child: isNube
            ? _buildRemotoDetail(_selectedRemoto!)
            : _buildLocalDetail(_selectedLocal!)),
      ]),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isNube  = _tab == _Tab.nube;
    final loading = isNube ? _loadingRemote : _loadingLocal;
    final count   = isNube ? _remotoFiltrados.length : _localFiltrados.length;

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Título + tabs + refresh
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _tealBg, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.folder_copy_rounded, color: _teal, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Documentos', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: _textPri)),
          const Spacer(),
          // Tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _tabBtn(_Tab.nube,  Icons.cloud_rounded,    'Nube'),
              _tabBtn(_Tab.local, Icons.computer_rounded, 'Local'),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18, color: _textMuted),
            tooltip: 'Actualizar',
            padding: const EdgeInsets.all(8),
            onPressed: () {
              _query = '';
              _searchCtrl.clear();
              isNube ? _cargarRemote() : _cargarLocal();
            },
          ),
        ]),
        const SizedBox(height: 12),

        // Búsqueda
        TextField(
          controller: _searchCtrl,
          onChanged: (q) => setState(() { _query = q; _selectedRemoto = null; _selectedLocal = null; }),
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText:       isNube ? 'Buscar por nombre, tienda, cajero…' : 'Buscar por nombre…',
            hintStyle:      GoogleFonts.inter(color: _textMuted, fontSize: 13),
            prefixIcon:     const Icon(Icons.search_rounded, size: 18, color: _textMuted),
            filled:         true,
            fillColor:      _bg,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border:         OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () { _searchCtrl.clear(); setState(() { _query = ''; }); },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),

        // Chips + conteo
        Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: isNube ? _chipsNube() : _chipsLocal()),
            ),
          ),
          const SizedBox(width: 8),
          if (!loading)
            Text(
              '$count doc${count != 1 ? 's' : ''}',
              style: GoogleFonts.inter(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500),
            ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: _border),
      ]),
    );
  }

  Widget _tabBtn(_Tab tab, IconData icon, String label) {
    final active = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = tab;
        _query = '';
        _searchCtrl.clear();
        _selectedRemoto = null;
        _selectedLocal  = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _teal : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? Colors.white : _textMuted),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? Colors.white : _textMuted)),
        ]),
      ),
    );
  }

  Widget _errorBanner(String msg, VoidCallback onRetry) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _rose.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: _rose, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: GoogleFonts.inter(color: _rose, fontSize: 12, fontWeight: FontWeight.w600))),
      GestureDetector(onTap: onRetry, child: const Icon(Icons.refresh_rounded, size: 16, color: _rose)),
    ]),
  );

  List<Widget> _chipsNube() {
    const tipos = [
      (null,         'Todos',        Icons.folder_rounded),
      ('venta',      'Ventas',       Icons.receipt_rounded),
      ('separado',   'Separados',    Icons.bookmark_rounded),
      ('cierre',     'Cierres',      Icons.lock_clock_rounded),
      ('compra',     'Compras',      Icons.shopping_cart_rounded),
      ('devolucion', 'Devoluciones', Icons.assignment_return_rounded),
      ('abono',      'Abonos',       Icons.payments_rounded),
      ('reporte',    'Reportes',     Icons.bar_chart_rounded),
    ];
    return tipos.expand((t) => [
      _chip(
        active: _filtroRemote == t.$1, label: t.$2, icon: t.$3,
        onTap: () { setState(() { _filtroRemote = t.$1; _selectedRemoto = null; }); _cargarRemote(); },
      ),
      const SizedBox(width: 6),
    ]).toList();
  }

  List<Widget> _chipsLocal() {
    const tipos = [
      (null,                     'Todos',        Icons.folder_rounded),
      (TipoDocumento.venta,      'Ventas',       Icons.receipt_rounded),
      (TipoDocumento.separado,   'Separados',    Icons.bookmark_rounded),
      (TipoDocumento.cierre,     'Cierres',      Icons.lock_clock_rounded),
      (TipoDocumento.compra,     'Compras',      Icons.shopping_cart_rounded),
      (TipoDocumento.devolucion, 'Devoluciones', Icons.assignment_return_rounded),
      (TipoDocumento.abono,      'Abonos',       Icons.payments_rounded),
      (TipoDocumento.reporte,    'Reportes',     Icons.bar_chart_rounded),
    ];
    return tipos.expand((t) => [
      _chip(
        active: _filtroLocal == t.$1, label: t.$2, icon: t.$3,
        onTap: () { setState(() { _filtroLocal = t.$1; _selectedLocal = null; }); _cargarLocal(); },
      ),
      const SizedBox(width: 6),
    ]).toList();
  }

  Widget _chip({required bool active, required String label, required IconData icon, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:  active ? _teal : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _teal : _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: active ? Colors.white : _textMuted),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
              color: active ? Colors.white : _textMuted)),
        ]),
      ),
    );

  // ── lists ─────────────────────────────────────────────────────────────────────

  Widget _buildNubeList(bool isWide) {
    if (_loadingRemote) return const Center(child: CircularProgressIndicator(color: _teal));
    final docs = _remotoFiltrados;
    if (docs.isEmpty) {
      return _emptyState(
        icon: _remoteError != null ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
        msg:  _remoteError != null ? 'Sin conexión al servidor'
            : _query.isNotEmpty    ? 'Sin resultados para "$_query"'
            :                        'Sin documentos en la nube',
        sub:  _remoteError != null
            ? 'Verifica tu conexión e intenta de nuevo'
            : _query.isNotEmpty ? null
            : 'Los PDFs se suben automáticamente\nal generar documentos',
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarRemote,
      color: _teal,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: docs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _RemotoTile(
          doc:      docs[i],
          selected: isWide && _selectedRemoto?.id == docs[i].id,
          onTap: () {
            if (isWide) {
              setState(() => _selectedRemoto = docs[i]);
            } else {
              _abrirRemoto(docs[i]);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLocalList(bool isWide) {
    if (_loadingLocal) return const Center(child: CircularProgressIndicator(color: _teal));
    final docs = _localFiltrados;
    if (docs.isEmpty) {
      return _emptyState(
        icon: Icons.folder_off_rounded,
        msg:  _query.isNotEmpty ? 'Sin resultados para "$_query"' : 'Sin documentos en este dispositivo',
        sub:  _query.isNotEmpty ? null
            : (_rutaRaiz.isNotEmpty ? 'Carpeta:\n$_rutaRaiz' : 'Los PDFs se guardan al generar documentos'),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarLocal,
      color: _teal,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: docs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _LocalTile(
          doc:      docs[i],
          selected: isWide && _selectedLocal?.file.path == docs[i].file.path,
          onTap: () {
            if (isWide) {
              setState(() => _selectedLocal = docs[i]);
            } else {
              _abrirLocal(docs[i]);
            }
          },
        ),
      ),
    );
  }

  // ── detail panels ─────────────────────────────────────────────────────────────

  Widget _buildRemotoDetail(_DocRemoto doc) {
    final color = _Tipo.color(doc.tipo);
    final bg    = _Tipo.bg(doc.tipo);
    final icon  = _Tipo.icon(doc.tipo);
    final label = _Tipo.label(doc.tipo);
    final fmt   = DateFormat('EEEE d \'de\' MMMM yyyy · HH:mm', 'es');
    final abriendo = _abriendo.contains(doc.id);

    return Container(
      color: _surface,
      child: Column(children: [
        // Panel header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
          child: Row(children: [
            Text('Detalle del documento',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _textPri)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => _selectedRemoto = null),
              color: _textMuted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Tipo icon + badge
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 26, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
                    child: Text(label, style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6)),
                  ),
                  const SizedBox(height: 5),
                  Text(doc.displayNombre,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _textPri)),
                ])),
              ]),

              const SizedBox(height: 20),
              const Divider(color: _border),
              const SizedBox(height: 16),

              _infoRow(Icons.calendar_today_rounded, 'Fecha', fmt.format(doc.fecha), color: color),
              if (doc.tiendaNombre.isNotEmpty)
                _infoRow(Icons.store_rounded, 'Sucursal', doc.tiendaNombre, color: color),
              if (doc.empresaNombre.isNotEmpty)
                _infoRow(Icons.business_rounded, 'Empresa', doc.empresaNombre, color: color),
              if (doc.empleadoNombre.isNotEmpty)
                _infoRow(Icons.person_rounded, 'Generado por', doc.empleadoNombre, color: color),
              _infoRow(Icons.data_usage_rounded, 'Tamaño', '${doc.sizeKb} KB', color: color),

              const SizedBox(height: 24),
              const Divider(color: _border),
              const SizedBox(height: 16),

              // Botón abrir
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: abriendo ? null : () => _abrirRemoto(doc),
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    disabledBackgroundColor: _teal.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: abriendo
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(abriendo ? 'Descargando…' : 'Abrir PDF',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildLocalDetail(_DocLocal doc) {
    final tipoStr = doc.tipo.name;
    final color   = _Tipo.color(tipoStr);
    final bg      = _Tipo.bg(tipoStr);
    final icon    = _Tipo.icon(tipoStr);
    final label   = _Tipo.label(tipoStr);
    final fmt     = DateFormat('EEEE d \'de\' MMMM yyyy · HH:mm', 'es');

    return Container(
      color: _surface,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
          child: Row(children: [
            Text('Detalle del documento',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _textPri)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => _selectedLocal = null),
              color: _textMuted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 26, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
                    child: Text(label, style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6)),
                  ),
                  const SizedBox(height: 5),
                  Text(doc.displayId,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _textPri)),
                ])),
              ]),

              const SizedBox(height: 20),
              const Divider(color: _border),
              const SizedBox(height: 16),

              _infoRow(Icons.calendar_today_rounded, 'Fecha', fmt.format(doc.fecha), color: color),
              _infoRow(Icons.data_usage_rounded, 'Tamaño', '${doc.sizeKb} KB', color: color),
              _infoRow(Icons.folder_rounded, 'Ruta', doc.file.path, color: color),

              const SizedBox(height: 24),
              const Divider(color: _border),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _abrirLocal(doc),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('Abrir PDF',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color color = _teal}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
            color: _textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _textPri)),
      ])),
    ]),
  );

  Widget _emptyState({required IconData icon, required String msg, String? sub}) =>
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(color: _tealBg, shape: BoxShape.circle),
        child: Icon(icon, size: 28, color: _teal),
      ),
      const SizedBox(height: 14),
      Text(msg, style: GoogleFonts.inter(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center),
      if (sub != null) ...[
        const SizedBox(height: 6),
        Text(sub, style: GoogleFonts.inter(color: _textMuted.withOpacity(0.7), fontSize: 11),
            textAlign: TextAlign.center),
      ],
    ]));
}

// ── Remote tile ───────────────────────────────────────────────────────────────

class _RemotoTile extends StatelessWidget {
  final _DocRemoto   doc;
  final bool         selected;
  final VoidCallback onTap;
  const _RemotoTile({required this.doc, required this.selected, required this.onTap});

  static final _fmt = DateFormat('dd MMM yy · HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final color = _Tipo.color(doc.tipo);
    final bg    = _Tipo.bg(doc.tipo);
    final icon  = _Tipo.icon(doc.tipo);
    final label = _Tipo.label(doc.tipo);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color:        selected ? _tealBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: selected ? _teal.withOpacity(0.4) : _border),
        ),
        child: Stack(children: [
          // Left color stripe
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
                    child: Text(label, style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(doc.displayNombre,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPri),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(_fmt.format(doc.fecha),
                    style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
                if (doc.tiendaNombre.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.store_rounded, size: 10, color: _textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        [doc.tiendaNombre, if (doc.empleadoNombre.isNotEmpty) doc.empleadoNombre].join(' · '),
                        style: GoogleFonts.inter(fontSize: 10, color: _textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ])),
              const SizedBox(width: 8),
              Text('${doc.sizeKb} KB',
                  style: GoogleFonts.inter(fontSize: 10, color: _textMuted, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Local tile ────────────────────────────────────────────────────────────────

class _LocalTile extends StatelessWidget {
  final _DocLocal    doc;
  final bool         selected;
  final VoidCallback onTap;
  const _LocalTile({required this.doc, required this.selected, required this.onTap});

  static final _fmt = DateFormat('dd MMM yy · HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final tipoStr = doc.tipo.name;
    final color   = _Tipo.color(tipoStr);
    final bg      = _Tipo.bg(tipoStr);
    final icon    = _Tipo.icon(tipoStr);
    final label   = _Tipo.label(tipoStr);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color:        selected ? _tealBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: selected ? _teal.withOpacity(0.4) : _border),
        ),
        child: Stack(children: [
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
                    child: Text(label, style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(doc.displayId,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPri),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(_fmt.format(doc.fecha),
                    style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
              ])),
              const SizedBox(width: 8),
              Text('${doc.sizeKb} KB',
                  style: GoogleFonts.inter(fontSize: 10, color: _textMuted, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
    );
  }
}
