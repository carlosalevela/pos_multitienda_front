// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/documento_service.dart';

// ── palette ───────────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFFF5F7F8);
  static const surface     = Color(0xFFFFFFFF);
  static const border      = Color(0xFFE5E7EB);
  static const divider     = Color(0xFFEEF1F4);
  static const textPrimary = Color(0xFF111827);
  static const textSecond  = Color(0xFF6B7280);
  static const textFaint   = Color(0xFF9CA3AF);
  static const indigo      = Color(0xFF3730A3);
  static const indigoLight = Color(0xFFEEF2FF);
  static const purple      = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF5F3FF);
  static const rose        = Color(0xFFBE123C);
}

// ── data model ────────────────────────────────────────────────────────────────
class _DocEntry {
  final File          file;
  final TipoDocumento tipo;
  _DocEntry({required this.file, required this.tipo});

  /// Nombre limpio: sin extensión ni timestamps residuales.
  String get displayId {
    final base = file.uri.pathSegments.last.replaceAll('.pdf', '');
    return base
        // timestamp antiguo: _2026-08-12_14-30
        .replaceAll(RegExp(r'_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}$'), '')
        // epoch ms de abonos: _1723478912345
        .replaceAll(RegExp(r'_\d{13}$'), '');
  }

  DateTime get fecha  => file.lastModifiedSync();
  int      get sizeKb => (file.lengthSync() / 1024).ceil();
}

// ── screen ────────────────────────────────────────────────────────────────────
class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final _service = DocumentoService.instance;

  List<_DocEntry> _docs     = [];
  bool            _cargando = false;
  TipoDocumento?  _filtro;         // null = todos
  String          _rutaRaiz = '';

  @override
  void initState() {
    super.initState();
    _cargar();
    _loadRuta();
  }

  Future<void> _loadRuta() async {
    if (kIsWeb) return;
    try {
      final r = await _service.rutaRaiz();
      if (mounted) setState(() => _rutaRaiz = r);
    } catch (_) {}
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      List<_DocEntry> docs;
      if (_filtro == null) {
        final results = await Future.wait(
          TipoDocumento.values.map((t) => _service
              .listar(t)
              .then((fs) => fs.map((f) => _DocEntry(file: f, tipo: t)).toList())),
        );
        docs = results.expand((l) => l).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
      } else {
        final files = await _service.listar(_filtro!);
        docs = files.map((f) => _DocEntry(file: f, tipo: _filtro!)).toList();
      }
      if (mounted) setState(() { _docs = docs; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirArchivo(_DocEntry doc) async {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo abrir el archivo', style: GoogleFonts.inter()),
        backgroundColor: _C.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _C.purpleLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.folder_copy_rounded, color: _C.purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Documentos Guardados',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: _C.textPrimary)),
              if (_rutaRaiz.isNotEmpty)
                Text(_rutaRaiz,
                    style: GoogleFonts.inter(fontSize: 10, color: _C.textFaint),
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: _C.textSecond),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ]),
        const SizedBox(height: 20),

        // ── Filtros ──────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip(null,                     'Todos',        Icons.folder_rounded),
            const SizedBox(width: 6),
            _chip(TipoDocumento.venta,      'Ventas',       Icons.receipt_rounded),
            const SizedBox(width: 6),
            _chip(TipoDocumento.separado,   'Separados',    Icons.bookmark_rounded),
            const SizedBox(width: 6),
            _chip(TipoDocumento.cierre,     'Cierres',      Icons.lock_clock_rounded),
            const SizedBox(width: 6),
            _chip(TipoDocumento.compra,     'Compras',      Icons.shopping_cart_rounded),
            const SizedBox(width: 6),
            _chip(TipoDocumento.devolucion, 'Devoluciones', Icons.assignment_return_rounded),
            const SizedBox(width: 6),
            _chip(TipoDocumento.abono,      'Abonos',       Icons.payments_rounded),
            const SizedBox(width: 6),
            _chip(TipoDocumento.reporte,    'Reportes',     Icons.bar_chart_rounded),
          ]),
        ),
        const SizedBox(height: 12),

        // Conteo
        if (!_cargando)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${_docs.length} documento${_docs.length != 1 ? 's' : ''}',
              style: GoogleFonts.inter(fontSize: 12, color: _C.textFaint),
            ),
          ),

        // ── Lista ────────────────────────────────────────────────
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _docs.isEmpty
                  ? _emptyState()
                  : Container(
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _C.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ListView.separated(
                          itemCount: _docs.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: _C.divider),
                          itemBuilder: (_, i) => _DocTile(
                            doc: _docs[i],
                            onAbrir: () => _abrirArchivo(_docs[i]),
                          ),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _chip(TipoDocumento? tipo, String label, IconData icon) {
    final active = _filtro == tipo;
    return GestureDetector(
      onTap: () {
        setState(() => _filtro = tipo);
        _cargar();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:  active ? _C.indigo : _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _C.indigo : _C.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? Colors.white : _C.textSecond),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? Colors.white : _C.textSecond)),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(color: _C.purpleLight, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.folder_off_rounded, size: 26, color: _C.purple),
      ),
      const SizedBox(height: 14),
      Text('Sin documentos guardados',
          style: GoogleFonts.inter(color: _C.textFaint, fontSize: 14)),
      if (_rutaRaiz.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Los PDFs se guardan en:\n$_rutaRaiz',
            style: GoogleFonts.inter(color: _C.textFaint, fontSize: 11),
            textAlign: TextAlign.center),
      ],
    ]));
  }
}

// ── Document tile ─────────────────────────────────────────────────────────────
class _DocTile extends StatelessWidget {
  final _DocEntry    doc;
  final VoidCallback onAbrir;
  const _DocTile({required this.doc, required this.onAbrir});

  static final _fmt = DateFormat('dd MMM yyyy · HH:mm', 'es');

  static const _colors = <TipoDocumento, Color>{
    TipoDocumento.venta:      Color(0xFF0B7A53),
    TipoDocumento.separado:   Color(0xFF3730A3),
    TipoDocumento.abono:      Color(0xFFB45309),
    TipoDocumento.cierre:     Color(0xFF374151),
    TipoDocumento.devolucion: Color(0xFFBE123C),
    TipoDocumento.reporte:    Color(0xFF0284C7),
    TipoDocumento.inventario: Color(0xFF7C3AED),
    TipoDocumento.compra:     Color(0xFF0369A1),
    TipoDocumento.recepcion:  Color(0xFF047857),
  };

  static const _bgs = <TipoDocumento, Color>{
    TipoDocumento.venta:      Color(0xFFE8FFF4),
    TipoDocumento.separado:   Color(0xFFEEF2FF),
    TipoDocumento.abono:      Color(0xFFFEF3C7),
    TipoDocumento.cierre:     Color(0xFFF3F4F6),
    TipoDocumento.devolucion: Color(0xFFFFF1F2),
    TipoDocumento.reporte:    Color(0xFFE0F2FE),
    TipoDocumento.inventario: Color(0xFFF5F3FF),
    TipoDocumento.compra:     Color(0xFFE0F2FE),
    TipoDocumento.recepcion:  Color(0xFFECFDF5),
  };

  static const _icons = <TipoDocumento, IconData>{
    TipoDocumento.venta:      Icons.receipt_rounded,
    TipoDocumento.separado:   Icons.bookmark_rounded,
    TipoDocumento.abono:      Icons.payments_rounded,
    TipoDocumento.cierre:     Icons.lock_clock_rounded,
    TipoDocumento.devolucion: Icons.assignment_return_rounded,
    TipoDocumento.reporte:    Icons.bar_chart_rounded,
    TipoDocumento.inventario: Icons.inventory_2_rounded,
    TipoDocumento.compra:     Icons.shopping_cart_rounded,
    TipoDocumento.recepcion:  Icons.local_shipping_rounded,
  };

  static const _labels = <TipoDocumento, String>{
    TipoDocumento.venta:      'VENTA',
    TipoDocumento.separado:   'SEPARADO',
    TipoDocumento.abono:      'ABONO',
    TipoDocumento.cierre:     'CIERRE',
    TipoDocumento.devolucion: 'DEVOLUCIÓN',
    TipoDocumento.reporte:    'REPORTE',
    TipoDocumento.inventario: 'INVENTARIO',
    TipoDocumento.compra:     'COMPRA',
    TipoDocumento.recepcion:  'RECEPCIÓN',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[doc.tipo] ?? const Color(0xFF374151);
    final bg    = _bgs[doc.tipo]    ?? const Color(0xFFF3F4F6);
    final icon  = _icons[doc.tipo]  ?? Icons.description_rounded;
    final label = _labels[doc.tipo] ?? doc.tipo.name.toUpperCase();

    return InkWell(
      onTap: onAbrir,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          // Icono de tipo
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),

          // Nombre + fecha
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w700,
                        color: color, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(doc.displayId,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              '${_fmt.format(doc.fecha)} · ${doc.sizeKb} KB',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9CA3AF)),
            ),
          ])),

          const SizedBox(width: 10),

          // Botón abrir
          Tooltip(
            message: 'Abrir PDF',
            child: InkWell(
              onTap: onAbrir,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.open_in_new_rounded, size: 16, color: color),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
