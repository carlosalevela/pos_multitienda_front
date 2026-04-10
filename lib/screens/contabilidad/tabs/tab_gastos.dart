import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants.dart';


enum _Rango { hoy, semana, mes, custom }


class TabGastos extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;
  final bool                 esCajero;
  final AuthProvider         auth;

  const TabGastos({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.esCajero,
    required this.auth,
  });

  @override
  State<TabGastos> createState() => _TabGastosState();
}


class _TabGastosState extends State<TabGastos> {

  static const _categoriasAdmin = [
    'Arriendo', 'Nómina', 'Servicios', 'Mercancía',
    'Insumos', 'Transporte', 'Mantenimiento', 'Publicidad', 'Otros',
  ];

  static const _categoriasCajero = [
    'Insumos', 'Transporte', 'Mantenimiento', 'Publicidad', 'Otros',
  ];

  static const _metodos = ['efectivo', 'transferencia', 'tarjeta'];

  static const _restringidas = {
    'arriendo', 'nómina', 'nomina', 'servicios',
    'mercancía', 'mercancia', 'proveedor',
  };

  _Rango   _rangoSel    = _Rango.hoy;
  String?  _categoriaSel;
  DateTime _customIni   = DateTime.now();
  DateTime _customFin   = DateTime.now();

  List<String> get _categorias =>
      widget.esCajero ? _categoriasCajero : _categoriasAdmin;

  @override
  void initState() {
    super.initState();
    _aplicarFiltro();
  }

  Future<void> _aplicarFiltro() async {
    final now = DateTime.now();

    if (widget.esCajero) {
      await widget.cont.cargarGastos(
        tiendaId: widget.tiendaId,
        fecha:    _strFecha(now),
      );
      return;
    }

    switch (_rangoSel) {
      case _Rango.hoy:
        await widget.cont.cargarGastos(
          tiendaId:  widget.tiendaId,
          fecha:     _strFecha(now),
          categoria: _categoriaSel?.toLowerCase(),
        );
      case _Rango.semana:
        final ini = now.subtract(Duration(days: now.weekday - 1));
        await widget.cont.cargarGastos(
          tiendaId:  widget.tiendaId,
          fechaIni:  _strFecha(ini),
          fechaFin:  _strFecha(now),
          categoria: _categoriaSel?.toLowerCase(),
        );
      case _Rango.mes:
        final ini = DateTime(now.year, now.month, 1);
        await widget.cont.cargarGastos(
          tiendaId:  widget.tiendaId,
          fechaIni:  _strFecha(ini),
          fechaFin:  _strFecha(now),
          categoria: _categoriaSel?.toLowerCase(),
        );
      case _Rango.custom:
        await widget.cont.cargarGastos(
          tiendaId:  widget.tiendaId,
          fechaIni:  _strFecha(_customIni),
          fechaFin:  _strFecha(_customFin),
          categoria: _categoriaSel?.toLowerCase(),
        );
    }
  }

  String _strFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _tituloRango() {
    switch (_rangoSel) {
      case _Rango.hoy:    return 'Gastos de hoy';
      case _Rango.semana: return 'Gastos de esta semana';
      case _Rango.mes:    return 'Gastos de este mes';
      case _Rango.custom:
        return 'Del ${DateFormat('dd/MM').format(_customIni)} '
               'al ${DateFormat('dd/MM').format(_customFin)}';
    }
  }

  // ✅ REEMPLAZADO — dialog compacto en lugar de pantalla completa
  Future<void> _elegirRangoCustom() async {
    DateTime? inicioTemp = _customIni;
    DateTime? finTemp    = _customFin;
    // true = esperando selección de inicio, false = esperando fin
    bool seleccionandoInicio = true;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 32, vertical: 40),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Título ──────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(Constants.primaryColor)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.date_range_rounded,
                          color: Color(Constants.primaryColor), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('Rango personalizado',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: const Color(0xFF1A1A2E))),
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

                  // ── Indicador desde / hasta ──────────
                  Row(children: [
                    Expanded(child: _fechaBox(
                      label:    'Desde',
                      valor:    inicioTemp != null
                          ? DateFormat('dd/MM/yyyy').format(inicioTemp!)
                          : 'Selecciona',
                      activo:   seleccionandoInicio,
                      onTap: () => setLocal(
                          () => seleccionandoInicio = true),
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
                      onTap: () => setLocal(
                          () => seleccionandoInicio = false),
                    )),
                  ]),
                  const SizedBox(height: 4),

                  // ── Instrucción ──────────────────────
                  Text(
                    seleccionandoInicio
                        ? '👆 Toca la fecha de inicio'
                        : '👆 Toca la fecha de fin',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(Constants.primaryColor)),
                  ),
                  const SizedBox(height: 8),

                  // ── Calendario compacto ──────────────
                  SizedBox(
                    height: 270,
                    child: CalendarDatePicker(
                      initialDate: seleccionandoInicio
                          ? (inicioTemp ?? DateTime.now())
                          : (finTemp ?? inicioTemp ?? DateTime.now()),
                      firstDate:   DateTime(2024),
                      lastDate:    DateTime.now(),
                      onDateChanged: (date) {
                        setLocal(() {
                          if (seleccionandoInicio) {
                            inicioTemp = date;
                            // Si fin es anterior al nuevo inicio, lo limpia
                            if (finTemp != null &&
                                finTemp!.isBefore(date)) {
                              finTemp = null;
                            }
                            // Avanza automáticamente a seleccionar fin
                            seleccionandoInicio = false;
                          } else {
                            if (inicioTemp != null &&
                                date.isBefore(inicioTemp!)) {
                              // Si elige antes del inicio, reinicia
                              inicioTemp = date;
                              finTemp    = null;
                            } else {
                              finTemp = date;
                            }
                          }
                        });
                      },
                    ),
                  ),

                  const Divider(height: 20),

                  // ── Acciones ─────────────────────────
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
                        // Activo solo cuando ambas fechas están elegidas
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
                          backgroundColor:
                              const Color(Constants.primaryColor),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.grey.shade200,
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
            );
          },
        ),
      ),
    );
  }

  // ── Caja de fecha (desde/hasta) ──────────────────────
  Widget _fechaBox({
    required String  label,
    required String  valor,
    required bool    activo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo
              ? const Color(Constants.primaryColor).withOpacity(0.08)
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

  @override
  Widget build(BuildContext context) {
    final gastos = widget.cont.gastos;
    final total  = gastos.fold(0.0, (s, g) => s + g.monto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header ──────────────────────────────────
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.esCajero ? 'Gastos de hoy' : _tituloRango(),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1A1A2E)),
              ),
              Text(
                '${gastos.length} registros  •  Total: ${widget.fmt.format(total)}',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          )),
          ElevatedButton.icon(
            onPressed: () => _mostrarDialogAgregar(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Agregar',
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

        // ── Filtros (solo admin/supervisor) ──────────
        if (!widget.esCajero) ...[
          _barraFiltros(),
          const SizedBox(height: 12),
        ],

        // ── Lista ────────────────────────────────────
        if (widget.cont.cargando)
          const Expanded(
              child: Center(child: CircularProgressIndicator()))
        else if (gastos.isEmpty)
          _sinGastos(context)
        else
          Expanded(child: ListView.builder(
            itemCount: gastos.length,
            itemBuilder: (_, i) => _gastoCard(context, gastos[i]),
          )),
      ],
    );
  }

  // ── Barra de filtros ─────────────────────────────────
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
            value: _categoriaSel,
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
            hint: Text('Todas las categorías',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade500)),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las categorías',
                    style: GoogleFonts.poppins(fontSize: 12)),
              ),
              ..._categoriasAdmin.map((c) => DropdownMenuItem<String?>(
                value: c,
                child: Text(c,
                    style: GoogleFonts.poppins(fontSize: 12)),
              )),
            ],
            onChanged: (v) {
              setState(() => _categoriaSel = v);
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
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
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

  Widget _sinGastos(BuildContext context) {
    return Expanded(child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long_rounded,
            size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Sin gastos en este período',
            style: GoogleFonts.poppins(
                color: Colors.grey.shade400, fontSize: 15)),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _mostrarDialogAgregar(context),
          icon: const Icon(Icons.add_rounded),
          label: Text('Registrar gasto',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(
              foregroundColor: const Color(Constants.primaryColor)),
        ),
      ],
    )));
  }

  Widget _gastoCard(BuildContext context, gasto) {
    final color     = _colorCategoria(gasto.categoria);
    final soloAdmin = gasto.visibilidad == 'solo_admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: soloAdmin
            ? Border.all(color: Colors.orange.shade200)
            : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_iconoCategoria(gasto.categoria),
              color: color, size: 22),
        ),
        title: Row(children: [
          Expanded(child: Text(
            gasto.categoria.isEmpty
                ? 'Sin categoría'
                : gasto.categoria,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: const Color(0xFF1A1A2E)),
          )),
          if (soloAdmin && !widget.esCajero) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_rounded,
                    size: 10, color: Colors.orange.shade700),
                const SizedBox(width: 3),
                Text('Admin',
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700)),
              ]),
            ),
            const SizedBox(width: 6),
          ],
          Text(widget.fmt.format(gasto.monto),
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.red.shade600)),
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gasto.descripcion.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(gasto.descripcion,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 4),
            Row(children: [
              _chip(_metodoPagoLabel(gasto.metodoPago),
                  _metodoPagoColor(gasto.metodoPago)),
              const SizedBox(width: 6),
              _chip(gasto.empleadoNombre ?? 'Sin empleado',
                  Colors.grey.shade600),
            ]),
          ],
        ),
        trailing: widget.esCajero
            ? null
            : IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400, size: 20),
                onPressed: () =>
                    _confirmarEliminar(context, gasto.id),
              ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  IconData _iconoCategoria(String cat) {
    switch (cat.toLowerCase()) {
      case 'arriendo':      return Icons.home_work_rounded;
      case 'nómina':
      case 'nomina':        return Icons.people_rounded;
      case 'servicios':     return Icons.bolt_rounded;
      case 'mercancía':
      case 'mercancia':     return Icons.store_rounded;
      case 'insumos':       return Icons.inventory_2_rounded;
      case 'transporte':    return Icons.local_shipping_rounded;
      case 'mantenimiento': return Icons.build_rounded;
      case 'publicidad':    return Icons.campaign_rounded;
      case 'proveedor':     return Icons.local_shipping_rounded;
      default:              return Icons.receipt_long_rounded;
    }
  }

  Color _colorCategoria(String cat) {
    switch (cat.toLowerCase()) {
      case 'arriendo':      return Colors.blue.shade600;
      case 'nómina':
      case 'nomina':        return Colors.purple.shade600;
      case 'servicios':     return Colors.orange.shade600;
      case 'mercancía':
      case 'mercancia':     return Colors.indigo.shade600;
      case 'insumos':       return Colors.green.shade600;
      case 'transporte':    return Colors.teal.shade600;
      case 'mantenimiento': return Colors.brown.shade600;
      case 'publicidad':    return Colors.pink.shade600;
      case 'proveedor':     return Colors.deepOrange.shade600;
      default:              return Colors.grey.shade600;
    }
  }

  String _metodoPagoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      default:              return 'Efectivo';
    }
  }

  Color _metodoPagoColor(String m) {
    switch (m) {
      case 'transferencia': return Colors.blue.shade600;
      case 'tarjeta':       return Colors.purple.shade600;
      default:              return Colors.green.shade600;
    }
  }

  void _confirmarEliminar(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar gasto?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Esta acción no se puede deshacer.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.cont.eliminarGasto(id, tiendaId: widget.tiendaId);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Eliminar',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogAgregar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormGasto(
        cont:         widget.cont,
        fmt:          widget.fmt,
        tiendaId:     widget.tiendaId,
        esCajero:     widget.esCajero,
        categorias:   _categorias,
        metodos:      _metodos,
        restringidas: _restringidas,
      ),
    );
  }
}


// ── Formulario ────────────────────────────────────────
class _FormGasto extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;
  final bool                 esCajero;
  final List<String>         categorias;
  final List<String>         metodos;
  final Set<String>          restringidas;

  const _FormGasto({
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.esCajero,
    required this.categorias,
    required this.metodos,
    required this.restringidas,
  });

  @override
  State<_FormGasto> createState() => _FormGastoState();
}

class _FormGastoState extends State<_FormGasto> {
  final _formKey   = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  String _categoria  = 'Otros';
  String _metodoPago = 'efectivo';
  bool   _guardando  = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _visibilidad(String cat) =>
      widget.restringidas.contains(cat.toLowerCase())
          ? 'solo_admin'
          : 'todos';

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final ok = await widget.cont.crearGasto({
      'tienda':      widget.tiendaId,
      'categoria':   _categoria,
      'descripcion': _descCtrl.text.trim(),
      'monto':       _montoCtrl.text.trim(),
      'metodo_pago': _metodoPago,
      if (!widget.esCajero) 'visibilidad': _visibilidad(_categoria),
    }, tiendaId: widget.tiendaId);

    setState(() => _guardando = false);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Text('Registrar gasto',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerLeft,
            child: Text('Categoría',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: widget.categorias.map((cat) {
              final sel           = _categoria == cat;
              final esRestringida =
                  widget.restringidas.contains(cat.toLowerCase());
              return GestureDetector(
                onTap: () => setState(() => _categoria = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(Constants.primaryColor)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cat,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? Colors.white
                                : Colors.grey.shade700)),
                    if (esRestringida && !widget.esCajero) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_rounded,
                          size: 10,
                          color: sel
                              ? Colors.white.withOpacity(0.8)
                              : Colors.orange.shade400),
                    ],
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco('Monto', Icons.attach_money_rounded),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa el monto';
              if (double.tryParse(v) == null || double.parse(v) <= 0) {
                return 'Monto inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _descCtrl,
            decoration: _inputDeco(
                'Descripción (opcional)', Icons.notes_rounded),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _metodoPago,
            decoration: _inputDeco(
                'Método de pago', Icons.payment_rounded),
            items: widget.metodos
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(_label(m),
                          style: GoogleFonts.poppins(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _metodoPago = v!),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity, height: 50,
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
                  : Text('Guardar gasto',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  String _label(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      default:              return 'Efectivo';
    }
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
          fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon,
          size: 20, color: const Color(Constants.primaryColor)),
      filled: true, fillColor: Colors.grey.shade50,
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
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
    );
  }
}