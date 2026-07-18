import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../core/api_client.dart';

class TabVendedores extends StatefulWidget {
  final int? tiendaId;
  const TabVendedores({super.key, required this.tiendaId});

  @override
  State<TabVendedores> createState() => _TabVendedoresState();
}

class _TabVendedoresState extends State<TabVendedores> {
  final _fmt     = NumberFormat('#,##0', 'es_CO');
  final _fmtDate = DateFormat('d MMM', 'es');

  List<Map<String, dynamic>> _empleados = [];
  bool   _cargando = false;
  String _error    = '';
  DateTime _desde  = DateTime.now().copyWith(day: 1);
  DateTime _hasta  = DateTime.now();

  static const _surface   = Colors.white;
  static const _border    = Color(0xFFE2E8F0);
  static const _text      = Color(0xFF1E293B);
  static const _muted     = Color(0xFF64748B);
  static const _card      = Color(0xFFF8FAFC);
  static const _green     = Color(0xFF16A34A);
  static const _greenBg   = Color(0xFFDCFCE7);
  static const _amber     = Color(0xFFD97706);
  static const _amberBg   = Color(0xFFFEF3C7);
  static const _blue      = Color(0xFF2563EB);
  static const _blueBg    = Color(0xFFEFF6FF);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabVendedores old) {
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
      };
      final r = await ApiClient.instance.get(
        '/contabilidad/reportes/ventas-por-empleado/',
        queryParameters: params,
      );
      final data = r.data as Map<String, dynamic>;
      setState(() {
        _empleados = (data['empleados'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _cargando = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar datos.'; _cargando = false; });
    }
  }

  Future<void> _elegirFecha(bool esDesdde) async {
    final inicial = esDesdde ? _desde : _hasta;
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (esDesdde) {
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
      child: Row(children: [
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
    if (_empleados.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 48, color: _muted),
          const SizedBox(height: 12),
          Text('Sin ventas en el período',
              style: GoogleFonts.inter(color: _muted, fontSize: 15)),
        ],
      ));
    }

    final totalVentas = _empleados.fold<double>(
        0, (s, e) => s + (e['total_ventas'] as num).toDouble());

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _empleados.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildKpis(totalVentas);
        return _buildEmpleadoCard(_empleados[i - 1], i, totalVentas);
      },
    );
  }

  Widget _buildKpis(double totalVentas) {
    final totalTx = _empleados.fold<int>(0, (s, e) => s + (e['num_ventas'] as int));
    final promedio = totalTx > 0 ? totalVentas / totalTx : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        _kpi('Total período', '\$${_fmt.format(totalVentas)}', _green, _greenBg),
        const SizedBox(width: 12),
        _kpi('Transacciones', '$totalTx', _blue, _blueBg),
        const SizedBox(width: 12),
        _kpi('Ticket prom.', '\$${_fmt.format(promedio)}', _amber, _amberBg),
      ]),
    );
  }

  Widget _kpi(String label, String value, Color color, Color bg) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, color: color,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800,
                color: color),
            overflow: TextOverflow.ellipsis),
      ]),
    ));
  }

  Widget _buildEmpleadoCard(
      Map<String, dynamic> emp, int rank, double totalGlobal) {
    final total    = (emp['total_ventas'] as num).toDouble();
    final nVentas  = emp['num_ventas'] as int;
    final promedio = (emp['promedio_venta'] as num).toDouble();
    final descto   = (emp['total_descuentos'] as num).toDouble();
    final pct      = totalGlobal > 0 ? total / totalGlobal : 0.0;

    final rankColors = [
      const Color(0xFFD97706),
      const Color(0xFF64748B),
      const Color(0xFFB45309),
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : _muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: rank <= 3 ? rankColor.withAlpha(25) : _card,
                shape: BoxShape.circle,
                border: Border.all(color: rankColor.withAlpha(80)),
              ),
              child: Center(child: Text('$rank',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: rankColor))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(emp['nombre'] as String,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _text))),
            Text('\$${_fmt.format(total)}',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _green)),
          ]),
          const SizedBox(height: 10),
          // Barra de participación
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: _border,
              valueColor: AlwaysStoppedAnimation(
                  rank == 1 ? const Color(0xFFD97706) : AppColors.secondary),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _stat(Icons.receipt_long, '$nVentas ventas'),
            const SizedBox(width: 16),
            _stat(Icons.trending_up, 'Prom \$${_fmt.format(promedio)}'),
            const SizedBox(width: 16),
            if (descto > 0)
              _stat(Icons.local_offer, 'Dscto \$${_fmt.format(descto)}',
                  color: _amber),
            const Spacer(),
            Text('${(pct * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
          ]),
        ]),
      ),
    );
  }

  Widget _stat(IconData icon, String text, {Color color = _muted}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(text,
          style: GoogleFonts.inter(fontSize: 12, color: color,
              fontWeight: FontWeight.w500)),
    ]);
  }
}
