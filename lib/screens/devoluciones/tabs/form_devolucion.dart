// lib/screens/devoluciones/tabs/form_devolucion.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pos_multitienda_app/core/constants.dart';
import 'package:pos_multitienda_app/providers/auth_provider.dart';
import 'package:pos_multitienda_app/providers/devoluciones_provider.dart';
import 'package:pos_multitienda_app/services/devoluciones_service.dart';


// ── Modelos ligeros solo para este formulario ─────────────────────────────────

class _VentaResumen {
  final int      id;
  final String   numeroFactura;
  final double   total;
  final String   cliente;
  final DateTime createdAt;

  _VentaResumen.fromJson(Map<String, dynamic> j)
      : id            = j['id'],
        numeroFactura = j['numero_factura'] ?? '',
        total         = double.tryParse(j['total'].toString()) ?? 0,
        cliente       = j['cliente'] ?? 'Consumidor Final',
        createdAt     = DateTime.parse(j['created_at']);
}

class _ProductoSeleccionable {
  final int    productoId;
  final String nombre;
  final double precioUnitario;
  final double disponible;

  bool   seleccionado = false;
  double cantidad;
  final motivoCtrl = TextEditingController();

  _ProductoSeleccionable({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
    required this.disponible,
  }) : cantidad = disponible;

  void dispose() => motivoCtrl.dispose();

  Map<String, dynamic> toDetalle() => {
        'producto':       productoId,
        'cantidad':       cantidad,
        'precio_unitario': precioUnitario,
        if (motivoCtrl.text.trim().isNotEmpty) 'motivo': motivoCtrl.text.trim(),
      };
}


// ── Widget principal ──────────────────────────────────────────────────────────

class FormDevolucion extends StatefulWidget {
  final AuthProvider auth;
  final int?         tiendaId;
  final VoidCallback onCreada;

  const FormDevolucion({
    super.key,
    required this.auth,
    required this.tiendaId,
    required this.onCreada,
  });

  @override
  State<FormDevolucion> createState() => _FormDevolucionState();
}

class _FormDevolucionState extends State<FormDevolucion> {
  final _service = DevolucionesService();
  final _fmt     = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final _obsCtrl = TextEditingController();

  static const _metodos = ['efectivo', 'transferencia', 'tarjeta', 'notacredito'];

  // ── Paso 1
  DateTime            _fechaSel       = DateTime.now();
  List<_VentaResumen> _ventas         = [];
  bool                _cargandoVentas = false;
  String?             _errorVentas;

  // ── Paso 2
  _VentaResumen?               _ventaSel;
  List<_ProductoSeleccionable> _productos    = [];
  bool                         _cargandoProd = false;
  String?                      _errorProd;
  String                       _metodoPago   = 'efectivo';
  bool                         _guardando    = false;

  int _paso = 1;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    for (final p in _productos) p.dispose();
    super.dispose();
  }

  // ── Lógica ────────────────────────────────────────────────────────────────

  Future<void> _cargarVentas() async {
    setState(() { _cargandoVentas = true; _errorVentas = null; });
    try {
      final data = await _service.listarVentasPorFecha(
        fecha:    DateFormat('yyyy-MM-dd').format(_fechaSel),
        tiendaId: widget.tiendaId,
      );
      setState(() =>
          _ventas = data.map((e) => _VentaResumen.fromJson(e)).toList());
    } catch (e) {
      setState(() =>
          _errorVentas = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _cargandoVentas = false);
    }
  }

  Future<void> _seleccionarVenta(_VentaResumen venta) async {
    setState(() {
      _ventaSel     = venta;
      _cargandoProd = true;
      _errorProd    = null;
      _paso         = 2;
    });
    try {
      final data  = await _service.ventaDisponible(venta.id);
      final prods = data['productos'] as List;

      if (data['todos_devueltos'] == true) {
        setState(() {
          _errorProd    = 'Esta venta ya tiene todos sus productos devueltos.';
          _cargandoProd = false;
        });
        return;
      }

      for (final p in _productos) p.dispose();
      setState(() {
        _productos = prods.map((p) => _ProductoSeleccionable(
          productoId:     p['producto_id'],
          nombre:         p['producto_nombre'],
          precioUnitario: double.tryParse(p['precio_unitario'].toString()) ?? 0,
          disponible:     double.tryParse(p['disponible'].toString()) ?? 0,
        )).toList();
      });
    } catch (e) {
      setState(() =>
          _errorProd = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _cargandoProd = false);
    }
  }

  Future<void> _guardar() async {
    final seleccionados = _productos.where((p) => p.seleccionado).toList();

    if (seleccionados.isEmpty) {
      _snack('Selecciona al menos un producto.', error: true);
      return;
    }
    for (final p in seleccionados) {
      if (p.cantidad <= 0 || p.cantidad > p.disponible) {
        _snack(
            '${p.nombre}: cantidad inválida (máx ${_cantStr(p.disponible)}).',
            error: true);
        return;
      }
    }

    setState(() => _guardando = true);
    final prov = context.read<DevolucionesProvider>();
    final resp = await prov.crearDevolucion(
      ventaId:       _ventaSel!.id,
      metodoPago:    _metodoPago,
      detalles:      seleccionados.map((p) => p.toDetalle()).toList(),
      observaciones: _obsCtrl.text.trim(),
      tiendaId:      widget.tiendaId,
    );
    setState(() => _guardando = false);

    if (!mounted) return;
    if (resp != null) {
      Navigator.pop(context);
      widget.onCreada();
      _snack('Devolución registrada ✅');
    } else {
      _snack(prov.error ?? 'Error al registrar devolución', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header con indicador de paso
          Row(children: [
            if (_paso == 2)
              GestureDetector(
                onTap: () => setState(() { _paso = 1; _ventaSel = null; }),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_back_rounded,
                      color: const Color(0xFF1A1A2E), size: 22),
                ),
              ),
            Expanded(
              child: Text(
                _paso == 1 ? 'Registrar devolución' : 'Seleccionar productos',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF1A1A2E)),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(Constants.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Paso $_paso de 2',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(Constants.primaryColor))),
            ),
          ]),
          const SizedBox(height: 16),
          Flexible(child: _paso == 1 ? _buildPaso1() : _buildPaso2()),
        ],
      ),
    );
  }

  // ── Paso 1: elegir fecha y venta ──────────────────────────────────────────

  Widget _buildPaso1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fecha de la venta',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        // Chips de fecha rápida
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chipFecha('Hoy',         DateTime.now()),
            const SizedBox(width: 8),
            _chipFecha('Ayer',        DateTime.now().subtract(const Duration(days: 1))),
            const SizedBox(width: 8),
            _chipFecha('Hace 2 días', DateTime.now().subtract(const Duration(days: 2))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _elegirFechaCustom,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.date_range_rounded,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text('Otra fecha',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Ventas del ${DateFormat('dd/MM/yyyy').format(_fechaSel)}',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        if (_cargandoVentas)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (_errorVentas != null)
          _errorBox(_errorVentas!)
        else if (_ventas.isEmpty)
          _emptyVentas()
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _ventas.length,
              itemBuilder: (_, i) => _ventaCard(_ventas[i]),
            ),
          ),
      ],
    );
  }

  Widget _chipFecha(String label, DateTime fecha) {
    final sel = DateFormat('yyyy-MM-dd').format(_fechaSel) ==
        DateFormat('yyyy-MM-dd').format(fecha);
    return GestureDetector(
      onTap: () { setState(() => _fechaSel = fecha); _cargarVentas(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel
              ? const Color(Constants.primaryColor)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }

  Widget _ventaCard(_VentaResumen v) {
    return GestureDetector(
      onTap: () => _seleccionarVenta(v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.receipt_long_rounded,
                color: Colors.orange.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(v.numeroFactura,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF1A1A2E))),
              Text(v.cliente,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt.format(v.total),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange.shade700)),
            Text(DateFormat('HH:mm').format(v.createdAt),
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade400)),
          ]),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _emptyVentas() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No hay ventas en esta fecha',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400, fontSize: 14)),
          ]),
        ),
      );

  Future<void> _elegirFechaCustom() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _fechaSel,
      firstDate:   DateTime(2024),
      lastDate:    DateTime.now(),
      locale:      const Locale('es', 'CO'),
    );
    if (picked != null) {
      setState(() => _fechaSel = picked);
      _cargarVentas();
    }
  }

  // ── Paso 2: elegir productos ──────────────────────────────────────────────

  Widget _buildPaso2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner venta seleccionada
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: Row(children: [
            Icon(Icons.receipt_long_rounded,
                color: Colors.orange.shade600, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_ventaSel!.numeroFactura} · ${_ventaSel!.cliente}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF1A1A2E)),
              ),
            ),
            Text(_fmt.format(_ventaSel!.total),
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700)),
          ]),
        ),
        const SizedBox(height: 14),
        if (_cargandoProd)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (_errorProd != null)
          _errorBox(_errorProd!)
        else ...[
          Text('Selecciona productos a devolver',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(children: [
                ..._productos.map((p) => _productoTile(p)),
                const SizedBox(height: 12),
                // Método de devolución
                DropdownButtonFormField<String>(
                  value: _metodoPago,
                  decoration: _inputDeco(
                      'Método de devolución', Icons.payment_rounded),
                  items: _metodos
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_metodoLabel(m),
                                style: GoogleFonts.poppins(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _metodoPago = v!),
                ),
                const SizedBox(height: 10),
                // Observaciones
                TextFormField(
                  controller: _obsCtrl,
                  decoration: _inputDeco(
                      'Observaciones (opcional)', Icons.notes_rounded),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                // Botón guardar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(Constants.primaryColor),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text('Guardar devolución',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _productoTile(_ProductoSeleccionable p) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.seleccionado
            ? const Color(Constants.primaryColor).withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.seleccionado
              ? const Color(Constants.primaryColor).withOpacity(0.4)
              : Colors.grey.shade200,
          width: p.seleccionado ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(
            value: p.seleccionado,
            activeColor: const Color(Constants.primaryColor),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
            onChanged: (v) => setState(() => p.seleccionado = v!),
          ),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(p.nombre,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: const Color(0xFF1A1A2E))),
              Text(
                  'Disponible: ${_cantStr(p.disponible)} · ${_fmt.format(p.precioUnitario)}/u',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ),
        ]),
        // Campos cantidad + motivo solo si está seleccionado
        if (p.seleccionado) ...[
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: _cantStr(p.disponible),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'))
                ],
                decoration: _inputDecoSm('Cantidad'),
                onChanged: (v) =>
                    p.cantidad = double.tryParse(v) ?? p.disponible,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: p.motivoCtrl,
                decoration: _inputDecoSm('Motivo (opcional)'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade400, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.red.shade600))),
        ]),
      );

  String _cantStr(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toString();

  String _metodoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      case 'notacredito':   return 'Nota Crédito';
      default:              return 'Efectivo';
    }
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
        prefixIcon: Icon(icon,
            size: 20, color: const Color(Constants.primaryColor)),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(Constants.primaryColor), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  InputDecoration _inputDecoSm(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: Color(Constants.primaryColor), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      );
}