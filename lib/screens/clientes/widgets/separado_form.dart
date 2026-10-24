// lib/screens/clientes/widgets/separado_form.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pos_multitienda_app/models/item_carrito.dart';
import 'package:pos_multitienda_app/providers/caja_provider.dart';
import 'package:provider/provider.dart';
import '../../../models/cliente.dart';
import '../../../models/separado.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cliente_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/recibo_pdf_service.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../services/windows_printer_service.dart';
import '../../../models/producto.dart';
import '../../../services/barcode_service.dart';
import '../../../services/inventario_service.dart';
import '../../../providers/config_provider.dart';
import '../../../models/cuenta_bancaria.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' show PaperSize;

// ── Paleta del sistema de diseño ─────────────────────────────
const _kGreen     = Color(0xFF10B981);   // emerald
const _kGreenDark = Color(0xFF0B7A53);   // verde oscuro para texto/iconos
const _kDark      = Color(0xFF0F172A);
const _kCard      = Colors.white;
const _kBorder    = Color(0xFFE2E8F0);
const _kTextSub   = Color(0xFF94A3B8);
const _kTextBody  = Color(0xFF475569);
const _kTextHead  = Color(0xFF1E293B);
const _kAmber     = Color(0xFFF59E0B);
const _kRed       = Color(0xFFEF4444);
const _kSurface   = Color(0xFFF8F9FC);

class SeparadoForm extends StatefulWidget {
  final int?              tiendaId;
  final NumberFormat      fmt;
  final VoidCallback?     onCreado;
  final Cliente?          clienteInicial;
  final DateTime?         fechaInicial;
  final List<ItemCarrito> itemsIniciales;

  const SeparadoForm({
    super.key,
    required this.tiendaId,
    required this.fmt,
    this.onCreado,
    this.clienteInicial,
    this.fechaInicial,
    required this.itemsIniciales,
  });

  /// Abre el panel como diálogo que desliza desde la derecha.
  static Future<void> mostrar(
    BuildContext context, {
    required int?              tiendaId,
    required NumberFormat      fmt,
    VoidCallback?              onCreado,
    Cliente?                   clienteInicial,
    DateTime?                  fechaInicial,
    required List<ItemCarrito> itemsInciales,
  }) {
    return showGeneralDialog(
      context:          context,
      barrierDismissible: true,
      barrierLabel:     '',
      barrierColor:     Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end:   Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      pageBuilder: (ctx, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width:  min(580, max(300, MediaQuery.of(ctx).size.width * 0.95)),
          height: double.infinity,
          child: SeparadoForm(
            tiendaId:       tiendaId,
            fmt:            fmt,
            onCreado:       onCreado,
            clienteInicial: clienteInicial,
            fechaInicial:   fechaInicial,
            itemsIniciales: itemsInciales,
          ),
        ),
      ),
    );
  }

  @override
  State<SeparadoForm> createState() => _SeparadoFormState();
}

// ── Ítem interno ──────────────────────────────────────────────
class _ItemSep {
  final int?   productoId;
  String       nombre;
  int          cantidad;
  double       precio;

  // Controllers solo para ítems manuales
  final nombreCtrl   = TextEditingController();
  final precioCtrl   = TextEditingController();

  _ItemSep({
    this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
  });

  void initCtrls() {
    nombreCtrl.text = nombre;
    precioCtrl.text = precio.toStringAsFixed(0);
  }

  double get subtotal => cantidad * precio;

  void dispose() {
    nombreCtrl.dispose();
    precioCtrl.dispose();
  }
}

class _SeparadoFormState extends State<SeparadoForm> {
  final _formKey   = GlobalKey<FormState>();
  final _abonoCtrl = TextEditingController();

  String    _metodoPago  = 'efectivo';
  int?      _cuentaId;
  DateTime? _fechaLimite;
  bool      _fechaError  = false;
  final List<_ItemSep> _items = [];
  StreamSubscription<String>? _barcodeSub;

  static const _metodos = [
    ('efectivo',      'Efectivo',      Icons.payments_rounded),
    ('transferencia', 'Transferencia', Icons.swap_horiz_rounded),
    ('tarjeta',       'Tarjeta',       Icons.credit_card_rounded),
  ];

  double get _total => _items.fold(0, (s, i) => s + i.subtotal);
  double get _abono => double.tryParse(_abonoCtrl.text) ?? 0;
  double get _saldo => (_total - _abono).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _fechaLimite = widget.fechaInicial;
    _barcodeSub  = BarcodeService.instance.onBarcode.listen(_onBarcode);
    if (widget.itemsIniciales.isNotEmpty) {
      for (final ic in widget.itemsIniciales) {
        final item = _ItemSep(
          productoId: ic.producto.id,
          nombre:     ic.producto.nombre,
          cantidad:   ic.cantidad,
          precio:     ic.precioUnitario,
        );
        item.initCtrls();
        _items.add(item);
      }
    } else {
      _agregarItemManual();
    }
  }

  void _agregarItemManual() {
    final item = _ItemSep(nombre: '', cantidad: 1, precio: 0);
    item.initCtrls();
    setState(() => _items.add(item));
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _abonoCtrl.dispose();
    for (final i in _items) { i.dispose(); }
    super.dispose();
  }

  // ── Lector de código de barras ────────────────────────────

  Future<void> _onBarcode(String codigo) async {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;

    final result = await InventarioService().buscarProductoPos(
      q: codigo, tiendaId: widget.tiendaId,
    );
    if (!mounted) return;

    final productos = result['data'] as List<Producto>;
    if (productos.isEmpty) {
      _snack('Código no encontrado: $codigo', isError: true);
      return;
    }

    // Usar el primer resultado (el backend ya priorizó match exacto en codigo_barras)
    final p   = productos.first;
    final idx = _items.indexWhere((i) => i.productoId == p.id);
    if (idx >= 0) {
      setState(() => _items[idx].cantidad++);
      _snack('${p.nombre} · ${_items[idx].cantidad} unidades');
    } else {
      final item = _ItemSep(
        productoId: p.id,
        nombre:     p.nombre,
        cantidad:   1,
        precio:     p.precio,
      );
      item.initCtrls();
      setState(() => _items.add(item));
      _snack('${p.nombre} agregado');
    }
  }

  // ── Guardar ───────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaLimite == null) {
      setState(() => _fechaError = true);
      _snack('Selecciona una fecha límite', isError: true); return;
    }
    if (widget.clienteInicial == null) {
      _snack('No hay cliente seleccionado', isError: true); return;
    }
    if (_items.isEmpty) {
      _snack('Agrega al menos un producto', isError: true); return;
    }
    final cajaAbierta = context.read<CajaProvider>().cajaAbierta;
    if (!cajaAbierta) {
      _snack('No hay caja abierta. Abre la caja primero.', isError: true);
      return;
    }
    if (_abono <= 0) {
      _snack('El abono inicial es obligatorio', isError: true); return;
    }
    if (_abono > _total) {
      _snack('El abono no puede superar el total', isError: true); return;
    }
    // Ítems manuales (sin productoId) no están soportados por el backend todavía
    if (_items.any((i) => i.productoId == null)) {
      _snack('Solo puedes agregar productos del catálogo o escáner', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();

    // Sincronizar ítems manuales
    for (final item in _items) {
      if (item.productoId == null) {
        item.nombre = item.nombreCtrl.text.trim();
        item.precio = double.tryParse(item.precioCtrl.text) ?? 0;
      }
    }

    final data = {
      'tienda':       widget.tiendaId,
      'cliente':      widget.clienteInicial!.id,
      'fecha_limite': DateFormat('yyyy-MM-dd').format(_fechaLimite!),
      'detalles': _items.map((i) => {
        if (i.productoId != null) 'producto': i.productoId,
        'nombre_libre':    i.nombre,
        'cantidad':        i.cantidad,
        'precio_unitario': i.precio,
      }).toList(),
      'abono_inicial':   _abono,
      'metodo_pago':     _metodoPago,
      if (_cuentaId != null) 'cuenta_destino': _cuentaId,
    };

    final prov   = context.read<ClienteProvider>();
    final creado = await prov.crearSeparado(data);
    if (!mounted) return;

    if (creado != null) {
      // 0 = no imprimir, 1 = solo cliente, 2 = cliente + comercio
      final copias = await showDialog<int>(
        context: context,
        builder: (ctx) => _DialogSeparadoCreado(
          separado: creado, fmt: widget.fmt,
        ),
      );

      if (!mounted) return;

      if (copias != null && copias > 0) {
        await _imprimirSeparado(creado);
        if (!mounted) return;
        if (copias == 2) {
          await _imprimirSeparado(creado);
          if (!mounted) return;
        }
      } else {
        final empNombre = context.read<AuthProvider>().empresaNombre;
        unawaited(ReciboPdfService.imprimirSeparado(
          separado: creado,
          empresaNombre: empNombre.isNotEmpty ? empNombre : creado.tiendaNombre,
          soloGuardar: true,
        ));
      }

      // Guardar el messenger ANTES del pop para evitar usar contexto desactivado
      final messenger = ScaffoldMessenger.of(context);
      final msg = _abono > 0
          ? 'Separado creado con abono ${widget.fmt.format(_abono)}'
          : 'Separado creado correctamente';
      Navigator.pop(context);
      widget.onCreado?.call();
      messenger.showSnackBar(SnackBar(
        content: Text(msg,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        backgroundColor: _kGreenDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    } else {
      _snack(prov.error ?? 'Error al crear separado', isError: true);
    }
  }

  Future<void> _imprimirSeparado(Separado separado) async {
    final empresaNombre = context.read<AuthProvider>().empresaNombre;
    final nombre        = empresaNombre.isNotEmpty ? empresaNombre : separado.tiendaNombre;
    final tipoPapel     = context.read<ConfigProvider>().tipoPapel;
    final paperSize     = tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;

    if (ThermalPrinterService.isWebUsbSupported) {
      try {
        final dev = await ThermalPrinterService.getAutoDevice();
        if (dev != null) {
          final bytes = await ThermalPrinterService.buildSeparadoRecibo(
              separado, empresaNombre: nombre, paperSize: paperSize);
          await ThermalPrinterService.printBytes(dev, bytes);
          unawaited(ReciboPdfService.imprimirSeparado(
            separado: separado, empresaNombre: nombre, soloGuardar: true,
          ));
          return;
        }
      } catch (_) {}
    } else if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
      try {
        final bytes = await ThermalPrinterService.buildSeparadoRecibo(
            separado, empresaNombre: nombre, paperSize: paperSize);
        await WindowsPrinterService.printRaw(bytes);
        unawaited(ReciboPdfService.imprimirSeparado(
          separado: separado, empresaNombre: nombre, soloGuardar: true,
        ));
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    await ReciboPdfService.imprimirSeparado(
        separado: separado, empresaNombre: nombre);
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? _kRed : _kGreenDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: _kSurface,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 32,
                offset: Offset(-4, 0)),
          ],
        ),
        child: Column(children: [
          _buildHeader(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Resumen cliente + fecha ──────────────
                    _resumenClienteFecha(),
                    const SizedBox(height: 20),

                    // ── Productos ────────────────────────────
                    Row(children: [
                      _sectionLabel('Productos', Icons.inventory_2_rounded,
                          obligatorio: true),
                      const Spacer(),
                      _addBtn(),
                    ]),
                    const SizedBox(height: 10),
                    ...List.generate(_items.length,
                        (i) => _productCard(i, _items[i])),
                    _totalBar(),

                    const SizedBox(height: 20),

                    // ── Abono inicial ────────────────────────
                    _sectionLabel('Abono inicial', Icons.payments_rounded,
                        obligatorio: true),
                    const SizedBox(height: 10),
                    _abonoSection(),

                    const SizedBox(height: 28),
                    _guardarBtn(),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SECCIONES
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
    decoration: const BoxDecoration(
      color: _kCard,
      border: Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_kGreenDark, _kGreen],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: _kGreen.withValues(alpha: 0.3),
                blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.bookmark_add_rounded,
            color: Colors.white, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nuevo separado',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _kDark)),
          Text('Revisa los detalles y confirma',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: _kTextSub)),
        ]),
      ),
      // Cerrar
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.close_rounded, size: 18, color: _kTextBody),
        ),
      ),
    ]),
  );

  // ── Resumen cliente + fecha (con date picker) ───────────────
  Widget _resumenClienteFecha() {
    final c = widget.clienteInicial;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // — Card del cliente —
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: c != null
                  ? const LinearGradient(colors: [_kGreenDark, _kGreen])
                  : null,
              color: c == null ? const Color(0xFFE2E8F0) : null,
              borderRadius: BorderRadius.circular(11),
            ),
            child: c != null
                ? Center(
                    child: Text(c.nombre[0].toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)))
                : const Icon(Icons.person_off_rounded,
                    size: 20, color: _kTextSub),
          ),
          const SizedBox(width: 12),
          Expanded(child: c != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.nombreCompleto,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 14,
                          color: _kTextHead)),
                  if (c.cedulaNit != null)
                    Text(c.cedulaNit!,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: _kTextSub)),
                ])
              : Text('Sin cliente',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: _kTextSub))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Cliente',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kGreenDark)),
          ),
        ]),
      ),

      const SizedBox(height: 16),

      // — Fecha límite (picker obligatorio) —
      _sectionLabel('Fecha límite', Icons.event_rounded, obligatorio: true),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _seleccionarFecha,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _fechaError
                  ? _kRed
                  : _fechaLimite != null
                      ? _kGreenDark.withValues(alpha: 0.5)
                      : _kBorder,
              width: _fechaError || _fechaLimite != null ? 1.5 : 1.0,
            ),
          ),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _fechaLimite != null
                    ? _kAmber.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.calendar_month_rounded,
                  size: 17,
                  color: _fechaLimite != null ? _kAmber : _kTextSub),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _fechaLimite != null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, children: [
                      Text('Fecha límite de recogida',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, color: _kTextSub)),
                      const SizedBox(height: 1),
                      Text(
                        DateFormat("d 'de' MMMM, yyyy", 'es').format(_fechaLimite!),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _kTextHead),
                      ),
                    ])
                  : Text('Seleccionar fecha límite',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: _fechaError ? _kRed : _kTextSub)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: _fechaLimite != null ? _kGreenDark : _kTextSub),
          ]),
        ),
      ),
      if (_fechaError)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 5),
          child: Text('La fecha límite es obligatoria',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: _kRed)),
        ),
    ]);
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? hoy.add(const Duration(days: 7)),
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      helpText: 'Fecha límite de recogida',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() {
        _fechaLimite = picked;
        _fechaError  = false;
      });
    }
  }

  Widget _sectionLabel(String label, IconData icon,
      {bool obligatorio = false}) =>
    Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: _kGreenDark),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w700, color: _kTextHead)),
      if (obligatorio) ...[
        const SizedBox(width: 4),
        Text('*', style: GoogleFonts.plusJakartaSans(
            color: _kRed, fontWeight: FontWeight.w800)),
      ],
    ]);

  Widget _addBtn() => GestureDetector(
    onTap: _agregarItemManual,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.add_rounded, size: 15, color: _kGreenDark),
        const SizedBox(width: 5),
        Text('Agregar',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w700, color: _kGreenDark)),
      ]),
    ),
  );

  // ── Tarjeta de producto ─────────────────────────────────────
  Widget _productCard(int idx, _ItemSep item) {
    final fromPOS = item.productoId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Nombre del producto
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fromPOS ? Icons.inventory_2_rounded : Icons.add_box_rounded,
                size: 15, color: _kGreenDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: fromPOS
                  ? Text(item.nombre,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _kTextHead),
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : _miniField(
                      ctrl:      item.nombreCtrl,
                      hint:      'Nombre del producto',
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requerido' : null,
                    ),
            ),
            if (_items.length > 1) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  item.dispose();
                  _items.removeAt(idx);
                }),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: _kRed),
                ),
              ),
            ],
          ]),

          const SizedBox(height: 10),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 10),

          // Cantidad · Precio · Subtotal
          Row(children: [

            // Cantidad
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cantidad',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: _kTextSub)),
              const SizedBox(height: 5),
              _qtyControl(item),
            ]),

            const SizedBox(width: 14),

            // Precio
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Precio unitario',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: _kTextSub)),
                const SizedBox(height: 5),
                _miniField(
                  ctrl:    item.precioCtrl,
                  hint:    '0',
                  tipo:    const TextInputType.numberWithOptions(decimal: true),
                  prefijo: '\$',
                  onChanged: (_) => setState(() =>
                      item.precio = double.tryParse(item.precioCtrl.text) ?? 0),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Req.';
                    if ((double.tryParse(v) ?? 0) <= 0) return '> 0';
                    return null;
                  },
                ),
              ],
            )),

            const SizedBox(width: 14),

            // Subtotal
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Subtotal',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: _kTextSub)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.fmt.format(item.subtotal),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: _kGreenDark),
                ),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _qtyControl(_ItemSep item) => Row(children: [
    _qtyBtn(Icons.remove_rounded, () {
      if (item.cantidad > 1) setState(() => item.cantidad--);
    }),
    Container(
      width: 34, alignment: Alignment.center,
      child: Text('${item.cantidad}',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w800, color: _kTextHead)),
    ),
    _qtyBtn(Icons.add_rounded, () => setState(() => item.cantidad++)),
  ]);

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 14, color: _kGreenDark),
    ),
  );

  Widget _totalBar() => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E2A45)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total del separado',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: Colors.white60)),
          Text('${_items.length} producto${_items.length != 1 ? 's' : ''}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: Colors.white38)),
        ]),
        Text(widget.fmt.format(_total),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: Colors.white)),
      ],
    ),
  );

  // ── Sección de abono ────────────────────────────────────────
  Widget _abonoSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _miniField(
        ctrl:    _abonoCtrl,
        hint:    'Monto del abono',
        tipo:    const TextInputType.numberWithOptions(decimal: true),
        prefijo: '\$',
        onChanged: (_) => setState(() {}),
        validator: (v) {
          if (v == null || v.isEmpty) return 'El abono es obligatorio';
          final m = double.tryParse(v);
          if (m == null || m <= 0) return 'Ingresa un monto mayor a 0';
          if (m > _total) return 'No puede superar el total';
          return null;
        },
      ),

      const SizedBox(height: 14),
      Text('Método de pago del abono',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSub)),
      const SizedBox(height: 8),
      Row(children: _metodos.map((m) {
        final activo = _metodoPago == m.$1;
        final isLast = m.$1 == _metodos.last.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _metodoPago = m.$1;
              _cuentaId   = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(right: isLast ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: activo ? _kGreenDark : _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: activo ? _kGreenDark : _kBorder),
                boxShadow: activo ? [
                  BoxShadow(color: _kGreen.withValues(alpha: 0.3),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ] : null,
              ),
              child: Column(children: [
                Icon(m.$3, size: 18,
                    color: activo ? Colors.white : _kTextBody),
                const SizedBox(height: 4),
                Text(m.$2,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: activo ? Colors.white : _kTextBody)),
              ]),
            ),
          ),
        );
      }).toList()),

      // ── Selector de cuenta destino (Tarjeta / Transferencia) ──
      Builder(builder: (ctx) {
        if (_metodoPago == 'efectivo') return const SizedBox.shrink();
        final cuentas = ctx.watch<ConfigProvider>().cuentas
            .where((c) => _metodoPago == 'tarjeta'
                ? c.tipo == 'tarjeta'
                : c.tipo != 'tarjeta')
            .toList();
        if (cuentas.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text('Cuenta destino',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: _kTextSub)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: cuentas.map((CuentaBancaria c) {
                final sel = _cuentaId == c.id;
                return GestureDetector(
                  onTap: () => setState(() =>
                      _cuentaId = sel ? null : c.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? _kGreenDark.withValues(alpha: 0.08)
                          : _kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? _kGreenDark : _kBorder,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 13,
                          color: sel ? _kGreenDark : _kTextSub),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.nombre,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? _kGreenDark : _kTextHead)),
                          Text(c.tipoDisplay,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: sel ? _kGreenDark : _kTextSub)),
                        ],
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }),

      const SizedBox(height: 12),
      if (_abono > 0) Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _saldo == 0
              ? _kGreen.withValues(alpha: 0.08)
              : _kAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _saldo == 0
                ? _kGreen.withValues(alpha: 0.25)
                : _kAmber.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(
                _saldo == 0
                    ? Icons.check_circle_rounded
                    : Icons.pending_rounded,
                size: 16,
                color: _saldo == 0 ? _kGreenDark : _kAmber,
              ),
              const SizedBox(width: 8),
              Text(
                _saldo == 0 ? 'Pagado en su totalidad' : 'Saldo pendiente',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: _saldo == 0 ? _kGreenDark : _kAmber),
              ),
            ]),
              Text(
                widget.fmt.format(_saldo),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: _saldo == 0 ? _kGreenDark : _kAmber),
              ),
            ],
          ),
        ),
    ],
  );

  // ── Botón guardar ───────────────────────────────────────────
  Widget _guardarBtn() => Selector<ClienteProvider, bool>(
    selector: (_, p) => p.guardando,
    builder: (_, guardando, _) => Container(
      width: double.infinity, height: 54,
      decoration: BoxDecoration(
        gradient: guardando ? null : const LinearGradient(
            colors: [_kGreenDark, _kGreen],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        color: guardando ? _kBorder : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: guardando ? [] : [
          BoxShadow(color: _kGreen.withValues(alpha: 0.4),
              blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: ElevatedButton.icon(
        icon: guardando
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.bookmark_add_rounded, size: 20),
        label: Text(guardando ? 'Guardando…' : 'Confirmar separado',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w800)),
        onPressed: guardando ? null : _guardar,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
  );

  // ── Helper: campo de texto ──────────────────────────────────
  Widget _miniField({
    required TextEditingController    ctrl,
    required String                   hint,
    TextInputType?                    tipo,
    List<TextInputFormatter>?         formatters,
    String?                           prefijo,
    void Function(String)?            onChanged,
    String? Function(String?)?        validator,
  }) =>
    TextFormField(
      controller:      ctrl,
      keyboardType:    tipo,
      inputFormatters: formatters,
      onChanged:       onChanged,
      validator:       validator,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 13, color: _kTextHead, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText:    hint,
        prefixText:  prefijo,
        hintStyle:   GoogleFonts.plusJakartaSans(
            fontSize: 12, color: _kTextSub),
        prefixStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w600, color: _kGreenDark),
        filled:    true, fillColor: _kCard,
        isDense:   true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGreenDark, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kRed)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
      ),
    );
}

// ════════════════════════════════════════════════════════════════
// DIÁLOGO: Separado creado — impresión
// ════════════════════════════════════════════════════════════════

class _DialogSeparadoCreado extends StatelessWidget {
  final Separado     separado;
  final NumberFormat fmt;

  const _DialogSeparadoCreado({
    required this.separado,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final pagado = separado.saldoPendiente <= 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Header verde ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kGreenDark, _kGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
                // Icono con badge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(Icons.bookmark_added_rounded,
                        color: Colors.white, size: 32),
                  ],
                ),
                const SizedBox(height: 12),
                Text('¡Separado creado!',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(separado.clienteNombre,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 10),
                // ID badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1),
                  ),
                  child: Text('SEP-${separado.id.toString().padLeft(4, '0')}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 1.2)),
                ),
              ]),
            ),

            // ── Resumen financiero ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(children: [
                _statTile('Total', fmt.format(separado.total),
                    Icons.shopping_bag_rounded, const Color(0xFF475569)),
                const SizedBox(width: 8),
                _statTile('Abono', fmt.format(separado.abonoAcumulado),
                    Icons.payments_rounded, _kGreenDark),
                const SizedBox(width: 8),
                _statTile(
                  pagado ? 'Saldado' : 'Pendiente',
                  pagado ? '✓' : fmt.format(separado.saldoPendiente),
                  pagado ? Icons.check_circle_rounded : Icons.pending_rounded,
                  pagado ? _kGreenDark : const Color(0xFFF59E0B),
                ),
              ]),
            ),

            // ── Pregunta ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.print_rounded,
                      size: 16, color: _kGreenDark),
                ),
                const SizedBox(width: 12),
                Text('¿Imprimir recibo del separado?',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: _kTextHead)),
              ]),
            ),

            // ── Botones ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(children: [
                // Fila: Solo cliente + Cliente + Comercio
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 1),
                      icon: const Icon(Icons.person_rounded, size: 16),
                      label: Text('Solo cliente',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGreenDark,
                        side: const BorderSide(color: _kGreenDark, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kGreenDark, _kGreen]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _kGreen.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, 2),
                        icon: const Icon(Icons.store_rounded, size: 16),
                        label: Text('+ Comercio',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                // No imprimir
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, 0),
                    style: TextButton.styleFrom(
                      foregroundColor: _kTextSub,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: Text('No imprimir, cerrar',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 5),
            Text(value,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 9, fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.7))),
          ]),
        ),
      );
}
