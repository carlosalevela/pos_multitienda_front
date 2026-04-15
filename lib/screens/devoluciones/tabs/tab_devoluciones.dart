// lib/screens/devoluciones/tabs/tab_devoluciones.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pos_multitienda_app/providers/devoluciones_provider.dart';
import 'package:pos_multitienda_app/providers/auth_provider.dart';
import 'package:pos_multitienda_app/models/devolucion_model.dart';
import 'package:pos_multitienda_app/core/constants.dart';
// ✅ import inventario_service eliminado — el sheet lo maneja internamente
import 'package:pos_multitienda_app/screens/devoluciones/forms/form_devolucion.dart';
import 'package:pos_multitienda_app/screens/devoluciones/widgets/devolucion_tipo_sheet.dart';
import 'package:pos_multitienda_app/screens/devoluciones/widgets/devolucion_producto_sheet.dart';

enum _Rango { hoy, semana, mes, custom }

class TabDevoluciones extends StatefulWidget {
  final NumberFormat fmt;
  final int?         tiendaId;
  final bool         esCajero;
  final AuthProvider auth;

  const TabDevoluciones({
    super.key,
    required this.fmt,
    required this.tiendaId,
    required this.esCajero,
    required this.auth,
  });

  @override
  State<TabDevoluciones> createState() => _TabDevolucionesState();
}

class _TabDevolucionesState extends State<TabDevoluciones> {

  _Rango   _rangoSel  = _Rango.hoy;
  String?  _estadoSel;
  DateTime _customIni = DateTime.now();
  DateTime _customFin = DateTime.now();

  // ✅ _inventarioService eliminado — ya no se usa en el tab

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _aplicarFiltro());
  }

  // ── Filtro ────────────────────────────────────────────
  Future<void> _aplicarFiltro() async {
    final prov = context.read<DevolucionesProvider>();
    final now  = DateTime.now();

    switch (_rangoSel) {
      case _Rango.hoy:
        await prov.cargarDevoluciones(
          tiendaId: widget.tiendaId,
          fecha:    _strFecha(now),
          estado:   _estadoSel,
        );
      case _Rango.semana:
        final ini = now.subtract(Duration(days: now.weekday - 1));
        await prov.cargarDevoluciones(
          tiendaId: widget.tiendaId,
          fechaIni: _strFecha(ini),
          fechaFin: _strFecha(now),
          estado:   _estadoSel,
        );
      case _Rango.mes:
        final ini = DateTime(now.year, now.month, 1);
        await prov.cargarDevoluciones(
          tiendaId: widget.tiendaId,
          fechaIni: _strFecha(ini),
          fechaFin: _strFecha(now),
          estado:   _estadoSel,
        );
      case _Rango.custom:
        await prov.cargarDevoluciones(
          tiendaId: widget.tiendaId,
          fechaIni: _strFecha(_customIni),
          fechaFin: _strFecha(_customFin),
          estado:   _estadoSel,
        );
    }
  }

  String _strFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  String _tituloRango() {
    switch (_rangoSel) {
      case _Rango.hoy:    return 'Devoluciones de hoy';
      case _Rango.semana: return 'Devoluciones de esta semana';
      case _Rango.mes:    return 'Devoluciones de este mes';
      case _Rango.custom:
        return 'Del ${DateFormat('dd/MM').format(_customIni)} '
               'al ${DateFormat('dd/MM').format(_customFin)}';
    }
  }

  // ── Flujo nueva devolución ────────────────────────────
  Future<void> _iniciarDevolucion() async {
    // Paso 1: elegir modalidad (sin total aún, se calculará en el form)
    final tipo = await DevolucionTipoSheet.show(context, 0);
    if (tipo == null || !mounted) return;

    if (tipo == 'efectivo') {
      _abrirFormEfectivo();
    } else if (tipo == 'producto') {
      // ✅ FIX — firma correcta: auth (no tiendaId suelto)
      final result = await DevolucionProductoSheet.show(
        context,
        totalDevuelto: 0,       // el sheet calcula el crédito real
        auth:          widget.auth,  // ✅ corregido
      );

      if (result == null || !mounted) return;
      _procesarCambioProducto(result);
    }
  }

  // ── Flujo efectivo ────────────────────────────────────
  void _abrirFormEfectivo() {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => FormDevolucion(
        auth:     widget.auth,
        tiendaId: widget.tiendaId,
        onCreada: _aplicarFiltro,
      ),
    );
  }

  // ── Flujo producto: resumen y confirmación ────────────
  void _procesarCambioProducto(Map<String, dynamic> result) {
    final diferencia = (result['diferencia']  as num).toDouble();
    final totalNuevo = (result['total_nuevo'] as num).toDouble();
    final productos  = result['productos'] as List;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Resumen del cambio',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resumenFila(
              Icons.shopping_bag_outlined,
              '${productos.length} producto${productos.length != 1 ? 's' : ''} elegidos',
              Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            _resumenFila(
              Icons.receipt_outlined,
              'Total nuevos: \$${_fmtNum(totalNuevo)}',
              Colors.grey.shade600,
            ),
            const Divider(height: 20),
            if (diferencia > 0)
              _resumenFila(
                Icons.payments_outlined,
                'Cliente paga: \$${_fmtNum(diferencia)}',
                const Color(0xFFE65100),
                bold: true,
              )
            else if (diferencia < 0)
              _resumenFila(
                Icons.price_check_rounded,
                'Vuelto al cliente: \$${_fmtNum(-diferencia)}',
                const Color(0xFF2E7D32),
                bold: true,
              )
            else
              _resumenFila(
                Icons.check_circle_outline_rounded,
                '¡Cambio exacto!',
                const Color(0xFF1565C0),
                bold: true,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final prov = context.read<DevolucionesProvider>();
              final resp = await prov.crearCambioProducto(result);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  resp['success'] == true
                      ? 'Cambio registrado ✅'
                      : prov.error ?? 'Error al registrar',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                backgroundColor: resp['success'] == true
                    ? Colors.green.shade600
                    : Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
              ));

              if (resp['success'] == true) _aplicarFiltro();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(Constants.primaryColor),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Confirmar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _resumenFila(IconData icon, String texto, Color color,
      {bool bold = false}) =>
    Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(texto,
          style: GoogleFonts.poppins(
              fontSize: 13,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ),
    ]);

  String _fmtNum(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  // ── Rango custom ──────────────────────────────────────
  Future<void> _elegirRangoCustom() async {
    DateTime? inicioTemp = _customIni;
    DateTime? finTemp    = _customFin;
    bool seleccionandoInicio = true;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 32, vertical: 40),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(Constants.primaryColor)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.date_range_rounded,
                        color: Color(Constants.primaryColor), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Rango personalizado',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: Colors.grey.shade400),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _fechaBox(
                    label:  'Desde',
                    valor:  inicioTemp != null
                        ? DateFormat('dd/MM/yyyy').format(inicioTemp!)
                        : 'Selecciona',
                    activo: seleccionandoInicio,
                    onTap:  () => setLocal(() => seleccionandoInicio = true),
                  )),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Colors.grey.shade400),
                  ),
                  Expanded(child: _fechaBox(
                    label:  'Hasta',
                    valor:  finTemp != null
                        ? DateFormat('dd/MM/yyyy').format(finTemp!)
                        : 'Selecciona',
                    activo: !seleccionandoInicio,
                    onTap:  () => setLocal(() => seleccionandoInicio = false),
                  )),
                ]),
                const SizedBox(height: 4),
                Text(
                  seleccionandoInicio
                      ? '👆 Toca la fecha de inicio'
                      : '👆 Toca la fecha de fin',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(Constants.primaryColor)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 270,
                  child: CalendarDatePicker(
                    initialDate: seleccionandoInicio
                        ? (inicioTemp ?? DateTime.now())
                        : (finTemp ?? inicioTemp ?? DateTime.now()),
                    firstDate: DateTime(2024),
                    lastDate:  DateTime.now(),
                    onDateChanged: (date) => setLocal(() {
                      if (seleccionandoInicio) {
                        inicioTemp = date;
                        if (finTemp != null && finTemp!.isBefore(date)) {
                          finTemp = null;
                        }
                        seleccionandoInicio = false;
                      } else {
                        if (inicioTemp != null && date.isBefore(inicioTemp!)) {
                          inicioTemp = date;
                          finTemp    = null;
                        } else {
                          finTemp = date;
                        }
                      }
                    }),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancelar',
                          style: GoogleFonts.poppins(
                              color: Colors.grey.shade600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: inicioTemp != null && finTemp != null
                          ? () {
                              setState(() {
                                _customIni = inicioTemp!;
                                _customFin = finTemp!;
                                _rangoSel  = _Rango.custom;
                              });
                              Navigator.pop(ctx);
                              _aplicarFiltro();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(Constants.primaryColor),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Aplicar',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fechaBox({
    required String       label,
    required String       valor,
    required bool         activo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo
              ? const Color(Constants.primaryColor).withValues(alpha: 0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo
                ? const Color(Constants.primaryColor)
                : Colors.grey.shade200,
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: activo
                        ? const Color(Constants.primaryColor)
                        : Colors.grey.shade500)),
            Text(valor,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: activo
                        ? const Color(Constants.primaryColor)
                        : const Color(0xFF1A1A2E))),
          ],
        ),
      ),
    );
  }

  // ── Build principal ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<DevolucionesProvider>(
      builder: (_, prov, __) {
        final devoluciones = prov.devoluciones;
        final total = devoluciones
            .where((d) => d.estado == 'procesada')
            .fold(0.0, (s, d) => s + d.totalDevuelto);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──────────────────────────────────
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tituloRango(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF1A1A2E))),
                  Text(
                    '${devoluciones.length} registros  •  '
                    'Total: ${widget.fmt.format(total)}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              )),
              ElevatedButton.icon(
                onPressed: _iniciarDevolucion,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Nueva',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(Constants.primaryColor),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Filtros ──────────────────────────────────
            _barraFiltros(),
            const SizedBox(height: 12),

            // ── Error ────────────────────────────────────
            if (prov.error != null) ...[
              Container(
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
                    child: Text(prov.error!,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.red.shade600)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // ── Lista ────────────────────────────────────
            if (prov.cargando)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (devoluciones.isEmpty)
              _sinDevoluciones()
            else
              Expanded(
                child: ListView.builder(
                  itemCount: devoluciones.length,
                  itemBuilder: (_, i) =>
                      _devolucionCard(context, devoluciones[i], prov),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Barra de filtros ──────────────────────────────────
  Widget _barraFiltros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chipRango('Hoy',    _Rango.hoy),
            const SizedBox(width: 8),
            _chipRango('Semana', _Rango.semana),
            const SizedBox(width: 8),
            _chipRango('Mes',    _Rango.mes),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _elegirRangoCustom,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _rangoSel == _Rango.custom
                      ? const Color(Constants.primaryColor)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.date_range_rounded,
                      size: 14,
                      color: _rangoSel == _Rango.custom
                          ? Colors.white
                          : Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text('Personalizado',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _rangoSel == _Rango.custom
                              ? Colors.white
                              : Colors.grey.shade700)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: DropdownButtonFormField<String?>(
            value: _estadoSel,
            isDense: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              filled:    true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
            hint: Text('Todos los estados',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade500)),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos los estados',
                    style: GoogleFonts.poppins(fontSize: 12)),
              ),
              DropdownMenuItem<String?>(
                value: 'procesada',
                child: Text('Procesadas',
                    style: GoogleFonts.poppins(fontSize: 12)),
              ),
              DropdownMenuItem<String?>(
                value: 'cancelada',
                child: Text('Canceladas',
                    style: GoogleFonts.poppins(fontSize: 12)),
              ),
            ],
            onChanged: (v) {
              setState(() => _estadoSel = v);
              _aplicarFiltro();
            },
          ),
        ),
      ],
    );
  }

  Widget _chipRango(String label, _Rango rango) {
    final sel = _rangoSel == rango;
    return GestureDetector(
      onTap: () {
        setState(() => _rangoSel = rango);
        _aplicarFiltro();
      },
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

  // ── Sin devoluciones ──────────────────────────────────
  Widget _sinDevoluciones() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Sin devoluciones en este período',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade400, fontSize: 15)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _iniciarDevolucion,
              icon: const Icon(Icons.add_rounded),
              label: Text('Registrar devolución',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(Constants.primaryColor)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card de devolución ────────────────────────────────
  Widget _devolucionCard(
    BuildContext context,
    DevolucionModel dev,
    DevolucionesProvider prov,
  ) {
    final cancelada = dev.estado == 'cancelada';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cancelada ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: cancelada ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: cancelada
            ? null
            : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: cancelada
                ? Colors.grey.shade100
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.assignment_return_rounded,
            color: cancelada
                ? Colors.grey.shade400
                : Colors.orange.shade600,
            size: 22,
          ),
        ),
        title: Row(children: [
          Expanded(
            child: Text(
              'DEV-${dev.id}  •  ${dev.ventaNumero}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: cancelada
                      ? Colors.grey.shade400
                      : const Color(0xFF1A1A2E)),
            ),
          ),
          const SizedBox(width: 6),
          _chipEstado(dev.estado),
          const SizedBox(width: 6),
          Text(
            widget.fmt.format(dev.totalDevuelto),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: cancelada
                    ? Colors.grey.shade400
                    : Colors.orange.shade700),
          ),
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(children: [
              _chip(_metodoLabel(dev.metodoDevolucion),
                  _metodoColor(dev.metodoDevolucion)),
              const SizedBox(width: 6),
              _chip(dev.empleadoNombre, Colors.grey.shade600),
              const SizedBox(width: 6),
              _chip(
                '${dev.detalles.length} producto'
                '${dev.detalles.length != 1 ? 's' : ''}',
                Colors.blueGrey.shade400,
              ),
            ]),
            if (dev.observaciones.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                dev.observaciones,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
        trailing: (!widget.esCajero && !cancelada)
            ? IconButton(
                icon: Icon(Icons.cancel_outlined,
                    color: Colors.red.shade400, size: 20),
                tooltip: 'Cancelar devolución',
                onPressed: () => _confirmarCancelar(context, dev, prov),
              )
            : null,
        onTap: () => _mostrarDetalle(context, dev),
      ),
    );
  }

  Widget _chipEstado(String estado) {
    final esCancel = estado == 'cancelada';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: esCancel ? Colors.grey.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: esCancel ? Colors.grey.shade300 : Colors.green.shade200,
        ),
      ),
      child: Text(
        esCancel ? 'Cancelada' : 'Procesada',
        style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: esCancel
                ? Colors.grey.shade500
                : Colors.green.shade700),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  // ── Helpers ───────────────────────────────────────────
  String _metodoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      case 'notacredito':   return 'Nota Crédito';
      default:              return 'Efectivo';
    }
  }

  Color _metodoColor(String m) {
    switch (m) {
      case 'transferencia': return Colors.blue.shade600;
      case 'tarjeta':       return Colors.purple.shade600;
      case 'notacredito':   return Colors.teal.shade600;
      default:              return Colors.green.shade600;
    }
  }

  // ── Confirmar cancelar ────────────────────────────────
  void _confirmarCancelar(
    BuildContext context,
    DevolucionModel dev,
    DevolucionesProvider prov,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('¿Cancelar devolución?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Se revertirá el stock de ${dev.detalles.length} '
          'producto${dev.detalles.length != 1 ? 's' : ''}. '
          'Esta acción no se puede deshacer.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Volver',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await prov.cancelarDevolucion(dev.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    ok
                        ? 'Devolución cancelada ✅'
                        : prov.error ?? 'Error al cancelar',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  backgroundColor: ok
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                ));
                if (ok) _aplicarFiltro();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Cancelar devolución',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Detalle ───────────────────────────────────────────
  void _mostrarDetalle(BuildContext context, DevolucionModel dev) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _DetalleSheet(dev: dev, fmt: widget.fmt),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Sheet de detalle
// ═══════════════════════════════════════════════════════
class _DetalleSheet extends StatelessWidget {
  final DevolucionModel dev;
  final NumberFormat    fmt;

  const _DetalleSheet({required this.dev, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            Text('DEV-${dev.id}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF1A1A2E))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: dev.estado == 'cancelada'
                    ? Colors.grey.shade100
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dev.estado == 'cancelada'
                      ? Colors.grey.shade300
                      : Colors.green.shade200,
                ),
              ),
              child: Text(
                dev.estado == 'cancelada' ? 'Cancelada' : 'Procesada',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dev.estado == 'cancelada'
                        ? Colors.grey.shade600
                        : Colors.green.shade700),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Venta: ${dev.ventaNumero}',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          _infoRow(Icons.person_outline_rounded, 'Empleado',  dev.empleadoNombre),
          _infoRow(Icons.store_outlined,         'Tienda',    dev.tiendaNombre),
          _infoRow(Icons.payment_rounded,        'Método',    _metodoLabel(dev.metodoDevolucion)),
          _infoRow(Icons.calendar_today_rounded, 'Fecha',
              DateFormat('dd/MM/yyyy HH:mm').format(dev.createdAt)),
          if (dev.observaciones.isNotEmpty)
            _infoRow(Icons.notes_rounded, 'Observaciones', dev.observaciones),
          const Divider(height: 24),
          Text('Productos devueltos',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 10),
          ...dev.detalles.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.inventory_2_outlined,
                    size: 18, color: Colors.orange.shade600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.productoNombre,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    if (d.motivo.isNotEmpty)
                      Text(d.motivo,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'x${d.cantidad.toStringAsFixed(d.cantidad % 1 == 0 ? 0 : 2)}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade500)),
                  Text(fmt.format(d.subtotal),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orange.shade700)),
                ],
              ),
            ]),
          )),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total devuelto',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(fmt.format(dev.totalDevuelto),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.orange.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text('$label: ',
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey.shade500)),
        Expanded(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A2E))),
        ),
      ]),
    );
  }

  String _metodoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      case 'notacredito':   return 'Nota Crédito';
      default:              return 'Efectivo';
    }
  }
}