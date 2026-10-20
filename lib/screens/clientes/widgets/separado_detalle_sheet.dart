import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/separado.dart';
import '../../../models/producto.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cliente_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../services/inventario_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' show PaperSize;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/recibo_pdf_service.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../services/windows_printer_service.dart';

// ── Paleta ────────────────────────────────────────────────
const _kTeal      = Color(0xFF006C49);
const _kTealMid   = Color(0xFF01696F);
const _kAmber     = Color(0xFFF59E0B);
const _kText      = Color(0xFF191C1E);
const _kMuted     = Color(0xFF76777D);
const _kBorder    = Color(0xFFE0E3E5);
const _kSurface   = Color(0xFFF7F9FB);
const _kRed       = Color(0xFFBA1A1A);

class SeparadoDetalleSheet extends StatefulWidget {
  final Separado      separado;
  final NumberFormat  fmt;
  final bool          mostrarAcciones;
  final VoidCallback? onAbonar;
  final VoidCallback? onCancelar;
  final void Function(Separado)? onProductoCambiado;

  const SeparadoDetalleSheet({
    super.key,
    required this.separado,
    required this.fmt,
    this.mostrarAcciones = false,
    this.onAbonar,
    this.onCancelar,
    this.onProductoCambiado,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required Separado     separado,
    required NumberFormat fmt,
    bool                  mostrarAcciones = false,
    VoidCallback?         onAbonar,
    VoidCallback?         onCancelar,
    void Function(Separado)? onProductoCambiado,
  }) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => SeparadoDetalleSheet(
        separado:          separado,
        fmt:               fmt,
        mostrarAcciones:   mostrarAcciones,
        onAbonar:          onAbonar,
        onCancelar:        onCancelar,
        onProductoCambiado: onProductoCambiado,
      ),
    );
  }

  @override
  State<SeparadoDetalleSheet> createState() => _SeparadoDetalleSheetState();
}

class _SeparadoDetalleSheetState extends State<SeparadoDetalleSheet> {
  late Separado _separado;

  @override
  void initState() {
    super.initState();
    _separado = widget.separado;
  }

  // ── Estado helpers ─────────────────────────────────────
  String _labelEstado() => switch (_separado.estado) {
    'pagado'    => 'Pagado',
    'cancelado' => 'Cancelado',
    _           => 'Activo',
  };

  IconData _iconEstado() => switch (_separado.estado) {
    'pagado'    => Icons.verified_rounded,
    'cancelado' => Icons.cancel_outlined,
    _           => Icons.bookmark_rounded,
  };

  // ── Cambiar producto ────────────────────────────────────
  Future<void> _onCambiarDetalle(DetalleSeparado detalle) async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _CambiarProductoSheet(
        separadoId: _separado.id,
        tiendaId:   _separado.tienda,
        detalle:    detalle,
        fmt:        widget.fmt,
      ),
    );
    if (result == null || !mounted) return;

    // Actualiza el estado local optimistamente con los datos devueltos
    final nuevoNombre  = result['nuevo_producto_nombre'] as String;
    final nuevoId      = result['nuevo_producto_id'] as int;
    final nuevaCant    = (result['nueva_cantidad'] as num).toDouble();
    final nuevoPrecio  = (result['nuevo_precio'] as num).toDouble();
    final nuevoSub     = (result['nuevo_subtotal'] as num).toDouble();

    final nuevosDetalles = _separado.detalles.map((d) {
      if (d.id != detalle.id) return d;
      return DetalleSeparado(
        id:             d.id,
        producto:       nuevoId,
        productoNombre: nuevoNombre,
        cantidad:       nuevaCant,
        precioUnitario: nuevoPrecio,
        subtotal:       nuevoSub,
      );
    }).toList();

    final actualizado = _separado.copyWith(
      total:          (result['total'] as num).toDouble(),
      saldoPendiente: (result['saldo_pendiente'] as num).toDouble(),
      abonoAcumulado: (result['abono_acumulado'] as num).toDouble(),
      detalles:       nuevosDetalles,
    );

    setState(() => _separado = actualizado);
    widget.onProductoCambiado?.call(actualizado);
  }

  @override
  Widget build(BuildContext context) {
    final fmtInt = NumberFormat('#,##0', 'es_CO');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Handle ───────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // ── Contenido scrollable ──────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Tarjeta cliente (header) ──────────────
                  _clienteCard(fmtInt),

                  const SizedBox(height: 16),

                  // ── Info general ──────────────────────────
                  _infoCard(),

                  const SizedBox(height: 16),

                  // ── Productos ─────────────────────────────
                  _seccionTitle(
                    icon:  Icons.shopping_bag_outlined,
                    label: 'Productos',
                    count: _separado.detalles.length,
                    color: _kTeal,
                  ),
                  const SizedBox(height: 8),
                  ..._separado.detalles.map(_productoItem),

                  // ── Abonos ────────────────────────────────
                  if (_separado.abonos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _seccionTitle(
                      icon:  Icons.payments_rounded,
                      label: 'Abonos',
                      count: _separado.abonos.length,
                      color: _kTeal,
                    ),
                    const SizedBox(height: 8),
                    ..._separado.abonos.map(_abonoItem),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Botones fijos abajo ───────────────────────────
          if (widget.mostrarAcciones && _separado.esActivo) ...[
            const Divider(height: 1, color: _kBorder),
            _bottomActions(context),
          ] else ...[
            // Solo botón imprimir
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _imprimir(context),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text('Imprimir factura',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTeal,
                    side: const BorderSide(color: _kTeal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tarjeta principal con degradado ──────────────────────
  Widget _clienteCard(NumberFormat fmtInt) {
    final progreso = _separado.progreso.clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kTeal, _kTealMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _kTeal.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Nombre + SEP id + estado + imprimir
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _separado.clienteNombre.isNotEmpty
                    ? _separado.clienteNombre[0].toUpperCase() : '?',
                style: GoogleFonts.inter(fontSize: 18,
                    fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(_separado.clienteNombre,
                  style: GoogleFonts.inter(fontSize: 14,
                      fontWeight: FontWeight.w700, color: Colors.white)),
              Text('SEP-${_separado.id}',
                  style: GoogleFonts.inter(fontSize: 12,
                      color: Colors.white70)),
            ]),
          ),
          // Chip estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_iconEstado(), size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(_labelEstado(),
                  style: GoogleFonts.inter(fontSize: 11,
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          const SizedBox(width: 8),
          // Botón imprimir
          Builder(builder: (ctx) => GestureDetector(
              onTap: () => _imprimir(ctx),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.print_rounded,
                    size: 16, color: Colors.white),
              ),
            )),
        ]),

        const SizedBox(height: 14),

        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:      progreso,
            minHeight:  6,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),

        const SizedBox(height: 12),

        // Stats
        Row(children: [
          _stat('Total',    '\$${fmtInt.format(_separado.total)}',
              Colors.white70, Colors.white),
          _statDiv(),
          _stat('Abonado',  '\$${fmtInt.format(_separado.abonoAcumulado)}',
              Colors.white70, const Color(0xFF86EFAC)),
          _statDiv(),
          _stat('Pendiente','\$${fmtInt.format(_separado.saldoPendiente)}',
              Colors.white70, const Color(0xFFFFD580)),
        ]),
      ]),
    );
  }

  // ── Tarjeta info general ──────────────────────────────────
  Widget _infoCard() {
    final fecha = DateFormat('d MMM yyyy · HH:mm', 'es')
        .format(_separado.createdAt);
    String? fechaLimiteStr;
    if (_separado.fechaLimite != null) {
      try {
        final dt = DateTime.parse(_separado.fechaLimite!);
        fechaLimiteStr = DateFormat('d MMM yyyy', 'es').format(dt);
        final diff = dt.difference(DateTime.now()).inDays;
        if (diff < 0) {
          fechaLimiteStr += ' · vencido';
        } else if (diff == 0) {
          fechaLimiteStr += ' · hoy';
        } else if (diff <= 3) {
          fechaLimiteStr += ' · $diff días';
        }
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        _infoRow(Icons.store_outlined,        'Tienda',    _separado.tiendaNombre),
        if (_separado.empleadoNombre != null)
          _infoRow(Icons.badge_outlined,      'Empleado',  _separado.empleadoNombre!),
        _infoRow(Icons.calendar_today_rounded,'Fecha',     fecha),
        if (fechaLimiteStr != null)
          _infoRow(Icons.event_rounded,       'Límite',    fechaLimiteStr,
              valueColor: fechaLimiteStr.contains('vencido')
                  ? _kRed
                  : fechaLimiteStr.contains('días') || fechaLimiteStr.contains('hoy')
                      ? _kAmber
                      : null),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String valor,
      {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: _kMuted),
          const SizedBox(width: 8),
          Text('$label  ',
              style: GoogleFonts.inter(fontSize: 12, color: _kMuted)),
          Expanded(
            child: Text(valor,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? _kText)),
          ),
        ]),
      );

  // ── Título de sección ─────────────────────────────────────
  Widget _seccionTitle({
    required IconData icon,
    required String   label,
    required int      count,
    required Color    color,
  }) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(fontSize: 14,
                fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: GoogleFonts.inter(fontSize: 11,
                  fontWeight: FontWeight.w700, color: color)),
        ),
      ]);

  // ── Card producto ─────────────────────────────────────────
  Widget _productoItem(DetalleSeparado d) {
    final cant = d.cantidad % 1 == 0
        ? d.cantidad.toInt().toString()
        : d.cantidad.toStringAsFixed(2);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shopping_bag_outlined,
              size: 17, color: _kTeal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(d.productoNombre,
                style: GoogleFonts.inter(fontSize: 13,
                    fontWeight: FontWeight.w600, color: _kText)),
            Text('x$cant  ·  ${widget.fmt.format(d.precioUnitario)} c/u',
                style: GoogleFonts.inter(fontSize: 11, color: _kMuted)),
          ]),
        ),
        Text(widget.fmt.format(d.subtotal),
            style: GoogleFonts.inter(fontSize: 13,
                fontWeight: FontWeight.w700, color: _kTeal)),
        if (widget.mostrarAcciones && _separado.esActivo) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Cambiar producto',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _onCambiarDetalle(d),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.swap_horiz_rounded,
                    size: 16, color: Color(0xFF2563EB)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Card abono ────────────────────────────────────────────
  Widget _abonoItem(AbonoSeparado a) {
    final (metodoLabel, metodoColor, metodoIcon) = switch (a.metodoPago) {
      'transferencia' => ('Transferencia', const Color(0xFF2563EB),
          Icons.swap_horiz_rounded),
      'tarjeta'       => ('Tarjeta', const Color(0xFF7C3AED),
          Icons.credit_card_outlined),
      _               => ('Efectivo', _kTeal, Icons.payments_outlined),
    };
    final fecha = DateFormat('d MMM · HH:mm', 'es').format(a.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: metodoColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(metodoIcon, size: 17, color: metodoColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(metodoLabel,
                style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w600, color: _kText)),
            Text(
              a.empleadoNombre != null
                  ? '${a.empleadoNombre}  ·  $fecha'
                  : fecha,
              style: GoogleFonts.inter(fontSize: 11, color: _kMuted),
            ),
          ]),
        ),
        Text(widget.fmt.format(a.monto),
            style: GoogleFonts.inter(fontSize: 14,
                fontWeight: FontWeight.w800, color: _kTeal)),
      ]),
    );
  }

  // ── Botones de acción ─────────────────────────────────────
  Widget _bottomActions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        // Cancelar separado
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancelar?.call();
            },
            icon: Icon(Icons.cancel_outlined, size: 16,
                color: Colors.red.shade400),
            label: Text('Cancelar',
                style: GoogleFonts.inter(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.red.shade200),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Registrar abono
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onAbonar?.call();
            },
            icon: const Icon(Icons.payments_rounded,
                size: 17, color: Colors.white),
            label: Text('Registrar abono',
                style: GoogleFonts.inter(fontSize: 14,
                    fontWeight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Stat helpers ──────────────────────────────────────────
  Widget _stat(String label, String valor,
      Color labelColor, Color valorColor) =>
      Expanded(
        child: Column(children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: labelColor)),
          const SizedBox(height: 2),
          Text(valor,
              style: GoogleFonts.inter(fontSize: 12,
                  fontWeight: FontWeight.w700, color: valorColor)),
        ]),
      );

  Widget _statDiv() => Container(
      width: 1, height: 24,
      color: Colors.white.withValues(alpha: 0.2));

  // ── Imprimir ──────────────────────────────────────────────
  Future<void> _imprimir(BuildContext context) async {
    final tipoPapel = context.read<ConfigProvider>().tipoPapel;
    final paperSize = tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;
    final auth      = context.read<AuthProvider>();
    final empresaNombre = auth.empresaNombre.isNotEmpty
        ? auth.empresaNombre
        : _separado.tiendaNombre;

    if (ThermalPrinterService.isWebUsbSupported) {
      try {
        final dev = await ThermalPrinterService.getAutoDevice();
        if (dev != null) {
          final bytes = await ThermalPrinterService.buildSeparadoRecibo(
              _separado, empresaNombre: empresaNombre, paperSize: paperSize);
          await ThermalPrinterService.printBytes(dev, bytes);
          return;
        }
      } catch (_) {}
    } else if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
      try {
        final bytes = await ThermalPrinterService.buildSeparadoRecibo(
            _separado, empresaNombre: empresaNombre, paperSize: paperSize);
        await WindowsPrinterService.printRaw(bytes);
        return;
      } catch (_) {}
    }

    if (!context.mounted) return;
    await ReciboPdfService.imprimirSeparado(
        separado: _separado, empresaNombre: empresaNombre);
  }
}


// ─────────────────────────────────────────────────────────────
// SHEET — CAMBIAR PRODUCTO
// Retorna Map<String,dynamic> con los datos del servidor al
// cerrar con Navigator.pop(ctx, data), o null si cancela.
// ─────────────────────────────────────────────────────────────
class _CambiarProductoSheet extends StatefulWidget {
  final int             separadoId;
  final int             tiendaId;
  final DetalleSeparado detalle;
  final NumberFormat    fmt;

  const _CambiarProductoSheet({
    required this.separadoId,
    required this.tiendaId,
    required this.detalle,
    required this.fmt,
  });

  @override
  State<_CambiarProductoSheet> createState() => _CambiarProductoSheetState();
}

class _CambiarProductoSheetState extends State<_CambiarProductoSheet> {
  final _buscarCtrl   = TextEditingController();
  final _cantCtrl     = TextEditingController();
  final _precioCtrl   = TextEditingController();
  final _fmtInt       = NumberFormat('#,##0', 'es_CO');
  final _inventarioSvc = InventarioService();

  List<Producto> _resultados = [];
  Producto?      _seleccionado;
  bool           _buscando   = false;
  bool           _guardando  = false;
  String?        _error;
  Timer?         _debounce;

  @override
  void initState() {
    super.initState();
    _cantCtrl.text = widget.detalle.cantidad % 1 == 0
        ? widget.detalle.cantidad.toInt().toString()
        : widget.detalle.cantidad.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onBuscarChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _resultados = []; _buscando = false; });
      return;
    }
    setState(() => _buscando = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final res = await _inventarioSvc.buscarProductoPos(
          q: q.trim(), tiendaId: widget.tiendaId);
      if (!mounted) return;
      setState(() {
        _buscando  = false;
        _resultados = (res['data'] as List<Producto>? ?? []);
      });
    });
  }

  void _seleccionarProducto(Producto p) {
    setState(() {
      _seleccionado = p;
      _resultados   = [];
      _buscarCtrl.text = p.nombre;
      _precioCtrl.text = p.precio.toStringAsFixed(0);
      _error = null;
    });
  }

  Future<void> _confirmar() async {
    if (_seleccionado == null || _guardando) return;
    final cantidad = double.tryParse(_cantCtrl.text.trim());
    final precio   = double.tryParse(_precioCtrl.text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(() => _error = 'Ingresa una cantidad válida.');
      return;
    }
    if (precio == null || precio <= 0) {
      setState(() => _error = 'Ingresa un precio válido.');
      return;
    }

    setState(() { _guardando = true; _error = null; });

    final prov   = context.read<ClienteProvider>();
    final result = await prov.cambiarProductoSeparado(
      separadoId:      widget.separadoId,
      detalleId:       widget.detalle.id,
      nuevoProductoId: _seleccionado!.id,
      nuevaCantidad:   cantidad,
      nuevoPrecio:     precio,
    );

    if (!mounted) return;
    setState(() => _guardando = false);

    if (result['success'] == true) {
      Navigator.pop(context, result['data'] as Map<String, dynamic>);
    } else {
      setState(() => _error = result['error'] ?? 'Error al cambiar producto');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // Título
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                size: 20, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Cambiar producto',
                  style: GoogleFonts.inter(fontSize: 16,
                      fontWeight: FontWeight.w800, color: _kText)),
              Text(widget.detalle.productoNombre,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: _kMuted)),
            ]),
          ),
        ]),

        const SizedBox(height: 16),

        // Campo búsqueda
        TextField(
          controller:   _buscarCtrl,
          autofocus:    true,
          onChanged:    _onBuscarChanged,
          style: GoogleFonts.inter(fontSize: 14, color: _kText),
          decoration: InputDecoration(
            hintText:   'Buscar nuevo producto…',
            prefixIcon: const Icon(Icons.search_rounded, color: _kMuted),
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kTeal),
                    ),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F9FB),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kTeal, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),

        // Resultados de búsqueda
        if (_resultados.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap:  true,
              padding:     const EdgeInsets.symmetric(vertical: 4),
              itemCount:   _resultados.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 48),
              itemBuilder: (_, i) {
                final p = _resultados[i];
                return ListTile(
                  dense:   true,
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _kTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        size: 15, color: _kTeal),
                  ),
                  title: Text(p.nombre,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _kText)),
                  subtitle: Text(
                    '\$${_fmtInt.format(p.precio)}  ·  '
                    'Stock: ${p.stockActual.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _kMuted),
                  ),
                  onTap: () => _seleccionarProducto(p),
                );
              },
            ),
          ),
        ],

        // Cantidad y precio (solo si hay producto seleccionado)
        if (_seleccionado != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller:  _cantCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                style: GoogleFonts.inter(fontSize: 14, color: _kText),
                decoration: InputDecoration(
                  labelText:  'Cantidad',
                  filled:     true,
                  fillColor:  const Color(0xFFF7F9FB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: _kTeal, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:  _precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                style: GoogleFonts.inter(fontSize: 14, color: _kText),
                decoration: InputDecoration(
                  labelText:  'Precio unitario',
                  prefixText: '\$ ',
                  filled:     true,
                  fillColor:  const Color(0xFFF7F9FB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: _kTeal, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ]),
        ],

        // Error
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text(_error!,
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFFDC2626))),
          ),
        ],

        const SizedBox(height: 16),

        // Botón confirmar
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _seleccionado == null || _guardando
                ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: _kTeal.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _guardando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text('Confirmar cambio',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
