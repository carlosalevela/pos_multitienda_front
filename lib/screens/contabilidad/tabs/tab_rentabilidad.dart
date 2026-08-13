import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../core/api_client.dart';

class TabRentabilidad extends StatefulWidget {
  final int? tiendaId;
  const TabRentabilidad({super.key, required this.tiendaId});

  @override
  State<TabRentabilidad> createState() => _TabRentabilidadState();
}

class _TabRentabilidadState extends State<TabRentabilidad> {
  final _fmt     = NumberFormat('#,##0', 'es_CO');
  final _fmtDate = DateFormat('d MMM', 'es');

  List<Map<String, dynamic>> _productos = [];
  bool   _cargando = false;
  String _error    = '';
  DateTime _desde  = DateTime.now().copyWith(day: 1);
  DateTime _hasta  = DateTime.now();
  String _orden    = 'utilidad'; // 'utilidad' | 'margen' | 'ingresos'

  static const _surface  = Colors.white;
  static const _border   = Color(0xFFE2E8F0);
  static const _text     = Color(0xFF1E293B);
  static const _muted    = Color(0xFF64748B);
  static const _card     = Color(0xFFF8FAFC);
  static const _green    = Color(0xFF16A34A);
  static const _greenBg  = Color(0xFFDCFCE7);
  static const _red      = Color(0xFFDC2626);
  static const _redBg    = Color(0xFFFEE2E2);
  static const _amber    = Color(0xFFD97706);
  static const _amberBg  = Color(0xFFFEF3C7);
  static const _blue     = Color(0xFF2563EB);
  static const _blueBg   = Color(0xFFEFF6FF);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabRentabilidad old) {
    super.didUpdateWidget(old);
    if (old.tiendaId != widget.tiendaId) _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = ''; });
    try {
      final params = <String, String>{
        'fecha_ini': DateFormat('yyyy-MM-dd').format(_desde),
        'fecha_fin': DateFormat('yyyy-MM-dd').format(_hasta),
        if (widget.tiendaId != null) 'tienda_id': '${widget.tiendaId}',
        'limite': '100',
      };
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/rentabilidad/',
        queryParameters: params,
      );
      final data = r.data as Map<String, dynamic>;
      final lista = (data['productos'] as List?)
              ?.cast<Map<String, dynamic>>() ?? [];
      if (!mounted) return;
      setState(() {
        _productos = lista;
        _cargando = false;
      });
      _reordenar();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error al cargar datos.'; _cargando = false; });
    }
  }

  void _reordenar() {
    setState(() {
      _productos.sort((a, b) {
        final va = (a[_orden] as num).toDouble();
        final vb = (b[_orden] as num).toDouble();
        return vb.compareTo(va);
      });
    });
  }

  Future<void> _elegirFecha(bool esDesde) async {
    final inicial = esDesde ? _desde : _hasta;
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (esDesde) {
        _desde = picked;
        if (_hasta.isBefore(_desde)) _hasta = _desde;
      } else {
        _hasta = picked;
        if (_desde.isAfter(_hasta)) _desde = _hasta;
      }
    });
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildFiltros(),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildFiltros() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _chipFecha('Desde', _desde, () => _elegirFecha(true))),
          const SizedBox(width: 8),
          Expanded(child: _chipFecha('Hasta', _hasta, () => _elegirFecha(false))),
          const SizedBox(width: 8),
          InkWell(
            onTap: _cargar,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // Ordenar por
        Row(children: [
          Text('Ordenar:',
              style: GoogleFonts.inter(fontSize: 12, color: _muted)),
          const SizedBox(width: 8),
          _ordenChip('Utilidad', 'utilidad'),
          const SizedBox(width: 6),
          _ordenChip('Margen %', 'margen_pct'),
          const SizedBox(width: 6),
          _ordenChip('Ingresos', 'ingresos'),
        ]),
      ]),
    );
  }

  Widget _ordenChip(String label, String key) {
    final sel = _orden == key;
    return GestureDetector(
      onTap: () { setState(() => _orden = key); _reordenar(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? AppColors.secondary : _card,
          border: Border.all(color: sel ? AppColors.secondary : _border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: sel ? Colors.white : _muted)),
      ),
    );
  }

  Widget _chipFecha(String label, DateTime fecha, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
          color: _card,
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 14, color: _muted),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(fontSize: 10, color: _muted)),
            Text(_fmtDate.format(fecha),
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error,
          style: GoogleFonts.inter(color: Colors.red)));
    }
    if (_productos.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, size: 48, color: _muted),
          const SizedBox(height: 12),
          Text('Sin ventas en el período',
              style: GoogleFonts.inter(color: _muted, fontSize: 15)),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _productos.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildResumen();
        return _buildProductoCard(_productos[i - 1], i);
      },
    );
  }

  Widget _buildResumen() {
    final totalIngresos = _productos.fold<double>(
        0, (s, p) => s + (p['ingresos'] as num).toDouble());
    final totalCosto = _productos.fold<double>(
        0, (s, p) => s + (p['costo_total'] as num).toDouble());
    final totalUtilidad = totalIngresos - totalCosto;
    final margenGlobal = totalIngresos > 0
        ? totalUtilidad / totalIngresos * 100 : 0.0;
    final sinCosto = _productos.where((p) => !(p['tiene_costo'] as bool)).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Row(children: [
          _kpi('Ingresos', '\$${_fmt.format(totalIngresos)}', _blue, _blueBg),
          const SizedBox(width: 8),
          _kpi('Utilidad', '\$${_fmt.format(totalUtilidad)}',
              totalUtilidad >= 0 ? _green : _red,
              totalUtilidad >= 0 ? _greenBg : _redBg),
          const SizedBox(width: 8),
          _kpi('Margen global', '${margenGlobal.toStringAsFixed(1)}%',
              _margenColor(margenGlobal),
              _margenColor(margenGlobal).withAlpha(25)),
        ]),
        if (sinCosto > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _amberBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _amber.withAlpha(80)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: _amber),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '$sinCosto producto(s) sin precio de costo registrado — el margen puede estar subestimado.',
                style: GoogleFonts.inter(fontSize: 12, color: _amber),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Color _margenColor(double pct) {
    if (pct >= 30) return _green;
    if (pct >= 10) return _amber;
    return _red;
  }

  Widget _kpi(String label, String value, Color color, Color bg) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, color: color,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800,
                color: color),
            overflow: TextOverflow.ellipsis),
      ]),
    ));
  }

  Widget _buildProductoCard(Map<String, dynamic> p, int rank) {
    final ingresos  = (p['ingresos'] as num).toDouble();
    final costo     = (p['costo_total'] as num).toDouble();
    final utilidad  = (p['utilidad'] as num).toDouble();
    final margen    = (p['margen_pct'] as num).toDouble();
    final cantidad  = (p['cantidad_vendida'] as num).toDouble();
    final tieneC    = p['tiene_costo'] as bool;
    final color     = _margenColor(margen);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _card, shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Center(child: Text('$rank',
                  style: GoogleFonts.inter(fontSize: 11,
                      fontWeight: FontWeight.w700, color: _muted))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['nombre'] as String,
                  style: GoogleFonts.inter(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _text),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(p['categoria'] as String,
                  style: GoogleFonts.inter(fontSize: 11, color: _muted)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${_fmt.format(utilidad)}',
                  style: GoogleFonts.inter(fontSize: 15,
                      fontWeight: FontWeight.w800, color: color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${margen.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(fontSize: 12,
                        fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _fila('Ingresos', '\$${_fmt.format(ingresos)}', _blue),
            const SizedBox(width: 12),
            _fila('Costo', tieneC ? '\$${_fmt.format(costo)}' : '—', _muted),
            const SizedBox(width: 12),
            _fila('Unidades', '${cantidad.toStringAsFixed(cantidad % 1 == 0 ? 0 : 1)}', _muted),
          ]),
        ]),
      ),
    );
  }

  Widget _fila(String label, String value, Color color) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Text(label,
          style: GoogleFonts.inter(fontSize: 10, color: _muted)),
      Text(value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
              color: color)),
    ]));
  }
}
