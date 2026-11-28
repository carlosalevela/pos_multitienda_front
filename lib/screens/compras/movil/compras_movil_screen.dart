// lib/screens/compras/movil/compras_movil_screen.dart
//
// Compras en el celular: carga los datos y une la vista (ComprasMovil) con
// el detalle de la orden, recibir, pagar y la nueva orden por pasos.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/cuenta_bancaria.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/proveedores_provider.dart';
import '../../../services/compra_service.dart';
import '../../../services/compras_pdf_service.dart';
import '../../../services/cuenta_bancaria_service.dart';
import '../../../services/gastos_service.dart';
import '../../clientes/widgets/cliente_contacto.dart'
    show abrirWhatsAppNumero, llamarNumero, pesosCO, telefonoBonito;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf, compactoPesos;
import '../../proveedores/widgets/proveedor_form_dialog.dart';
import '../widgets/pdf_preview_dialog.dart';
import 'compras_movil.dart';
import 'compras_reglas.dart';
import 'nueva_orden_movil.dart';
import 'orden_movil.dart';

class ComprasMovilScreen extends StatefulWidget {
  const ComprasMovilScreen({super.key});

  @override
  State<ComprasMovilScreen> createState() => _ComprasMovilScreenState();
}

class _ComprasMovilScreenState extends State<ComprasMovilScreen> {
  final _buscador = TextEditingController();
  final _compraService = CompraService();
  PestanaCompras _pestana = PestanaCompras.ordenes;
  FiltroOrdenes _filtro = FiltroOrdenes.todas;
  String _filtroProv = 'activos';
  Map<String, dynamic>? _porPagar;
  bool _cargandoPagar = false;
  String? _error;

  ProveedoresProvider get _prov => context.read<ProveedoresProvider>();
  AuthProvider get _auth => context.read<AuthProvider>();
  int? get _tiendaUsuario => _auth.tiendaId == 0 ? null : _auth.tiendaId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final empId = int.tryParse(_auth.empresaId) ?? 0;
    await Future.wait([
      _prov.cargarCompras(tiendaId: _tiendaUsuario),
      _prov.cargarProveedores(estado: _filtroProv == 'inactivos' ? 'inactivos' : null),
      _cargarPorPagar(),
      if (empId > 0) _prov.cargarConfigMayoreo(empId),
    ]);
  }

  Future<void> _cargarPorPagar() async {
    setState(() => _cargandoPagar = true);
    try {
      final d = await _compraService.cuentasPorPagar();
      if (mounted) setState(() => _porPagar = d);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar Por pagar.');
    }
    if (mounted) setState(() => _cargandoPagar = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t), behavior: SnackBarBehavior.floating,
      backgroundColor: error ? CM.rojo : const Color(0xFF006C49),
    ));
  }

  Future<(List<CuentaBancaria>, bool)> _pagoDe(int? tiendaId) async {
    final t = tiendaId ?? _tiendaUsuario;
    if (t == null) return (const <CuentaBancaria>[], false);
    final r = await Future.wait([
      CuentaBancariaService().listar(t),
      GastosService().cajaAbierta(t),
    ]);
    return ((r[0] as List<CuentaBancaria>).where((c) => c.activo).toList(), r[1] as bool);
  }

  int? _tiendaDe(Map<String, dynamic> c) {
    if (c['tienda'] is int) return c['tienda'] as int;
    if (c['tienda_id'] is int) return c['tienda_id'] as int;
    for (final d in (c['detalles'] as List? ?? const [])) {
      for (final r in ((d as Map)['distribuciones'] as List? ?? const [])) {
        if ((r as Map)['tienda'] is int) return r['tienda'] as int;
      }
    }
    return null;
  }

  // ── Orden ─────────────────────────────────────────────────

  Future<void> _verOrden(Map<String, dynamic> resumen) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _OrdenPagina(
          id: resumen['id'] as int,
          inicial: resumen,
          telefono: _telefonoProveedor(resumen['proveedor']),
          onRecibir: _recibir,
          onPagar: _pagar,
          onCancelar: _cancelar,
        )),
      );

  String? _telefonoProveedor(Object? id) =>
      _prov.proveedores.where((p) => p['id'] == id).firstOrNull?['telefono'] as String?;

  /// true si se recibió.
  Future<bool> _recibir(Map<String, dynamic> orden) async {
    final (cuentas, caja) = await _pagoDe(_tiendaDe(orden));
    if (!mounted) return false;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (ctx) => RecibirMovil(
        orden: orden,
        manejaMayoreo: _prov.manejaM,
        cuentas: cuentas,
        cajaAbierta: caja,
        hoy: DateTime.now(),
        onConfirmar: (r) async {
          final data = await _prov.recibirCompra(orden['id'] as int,
              precios: r.precios, preciosMayoreo: r.preciosMayoreo, pago: r.pago);
          if (data == null) return _prov.errorMsg ?? 'No se pudo recibir la orden.';
          ComprasPDFService.instance.abrirRecepcion(compra: orden, resultado: data).ignore();
          if (ctx.mounted) Navigator.pop(ctx, true);
          return null;
        },
      ),
    ));
    if (ok == true) {
      _msg('Mercancía recibida: ya está en el inventario.');
      unawaited(_cargar());
    }
    return ok == true;
  }

  /// true si se pagó.
  Future<bool> _pagar(Map<String, dynamic> compra) async {
    final (cuentas, caja) = await _pagoDe(_tiendaDe(compra));
    if (!mounted) return false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HojaPagoProveedor(
        compra: compra, cuentas: cuentas, cajaAbierta: caja, hoy: DateTime.now(),
        onPagar: (pago) async {
          final e = await _compraService.pagar(compra['id'] as int, pago);
          if (e == null && ctx.mounted) Navigator.pop(ctx, true);
          return e;
        },
      ),
    );
    if (ok == true) {
      _msg('Pago registrado; quedó en Gastos como Proveedor.');
      unawaited(_cargar());
    }
    return ok == true;
  }

  Future<bool> _cancelar(Map<String, dynamic> c) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Cancelar ${c['numero_orden']}?', style: cf(size: 16, w: FontWeight.w800)),
        content: Text('La orden queda cancelada y no se puede recibir.', style: cf(size: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: CM.rojo), child: const Text('Cancelar orden')),
        ],
      ),
    );
    if (si != true) return false;
    final ok = await _prov.cancelarCompra(c['id'] as int);
    _msg(ok ? 'Orden cancelada' : (_prov.errorMsg ?? 'No se pudo cancelar'), error: !ok);
    if (ok) unawaited(_cargar());
    return ok;
  }

  // ── Nueva orden ───────────────────────────────────────────

  Future<void> _nuevaOrden() async {
    await Future.wait([
      _prov.cargarProveedoresSimple(),
      _prov.cargarTiendasSimple(),
      _prov.cargarCategoriasSimple(),
    ]);
    if (!mounted) return;
    final esAdmin = _auth.rol == 'admin' || _auth.rol == 'superadmin';
    final movil = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => NuevaOrdenMovil(
        proveedores: _prov.proveedoresSimple,
        tiendas: _prov.tiendasSimple,
        categorias: [for (final c in _prov.categoriasSimple) '${c['nombre'] ?? ''}'],
        tiendaFija: esAdmin ? null : _tiendaUsuario,
        hoy: DateTime.now(),
        buscar: (q) => _prov.buscarProductos(q: q),
        escanear: movil ? () => escanearConCamara(ctx) : null,
        factura: () => _leerFactura(ctx),
        onCrear: (cuerpo) async {
          final compra = await _prov.crearCompra(cuerpo);
          if (compra == null) return _prov.errorMsg ?? 'No se pudo crear la orden.';
          ComprasPDFService.instance.abrirOrdenCompra(compra).ignore();
          if (ctx.mounted) Navigator.pop(ctx);
          _msg('Orden ${compra['numero_orden']} creada');
          unawaited(_cargar());
          return null;
        },
      ),
    ));
  }

  Future<List<Map<String, dynamic>>?> _leerFactura(BuildContext ctx) async {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = r?.files.single.path;
    if (path == null) return null;
    final productos = await _compraService.parsearFactura(File(path));
    if (!ctx.mounted) return null;
    if (productos.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('No se encontraron productos en el PDF. Agrégalos a mano.'),
          behavior: SnackBarBehavior.floating));
      return null;
    }
    return PdfPreviewDialog.mostrar(ctx, productos);
  }

  // ── Proveedores ───────────────────────────────────────────

  void _formProveedor([Map<String, dynamic>? p]) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProveedorFormDialog(
          proveedor: p,
          esSuperadmin: _auth.esSuperadmin,
          empresaIdFija: _auth.esSuperadmin ? null : _auth.empresaId,
          tiendaIdFijo: _auth.esSuperadmin ? null : _auth.tiendaId,
          onGuardado: (ok, _) {
            _msg(ok ? (p == null ? 'Proveedor creado' : 'Proveedor actualizado') : 'No se pudo guardar', error: !ok);
            if (ok) unawaited(_cargar());
          },
        ),
      );

  void _verProveedor(Map<String, dynamic> p) {
    final ordenes = context.read<ProveedoresProvider>().compras
        .where((c) => c['proveedor'] == p['id']).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HojaProveedor(
        proveedor: p,
        ordenes: ordenes,
        onEditar: () {
          Navigator.pop(ctx);
          _formProveedor(p);
        },
        onOrden: (o) {
          Navigator.pop(ctx);
          _verOrden(o);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProveedoresProvider>();
    return ComprasMovil(
      buscador: _buscador,
      datos: DatosComprasMovil(
        hoy: DateTime.now(),
        pestana: _pestana,
        ordenes: prov.compras,
        filtro: _filtro,
        busqueda: _buscador.text,
        proveedores: prov.proveedores,
        filtroProveedores: _filtroProv,
        porPagar: _porPagar,
        cargando: prov.cargandoCompras || prov.cargandoProveedores || _cargandoPagar,
        error: _error,
      ),
      acciones: AccionesComprasMovil(
        onPestana: (p) => setState(() {
          _pestana = p;
          _buscador.clear();
        }),
        onFiltro: (f) => setState(() => _filtro = f),
        onBuscar: (_) => setState(() {}),
        onOrden: _verOrden,
        onNuevaOrden: _nuevaOrden,
        onFiltroProveedores: (f) {
          final antes = _filtroProv;
          setState(() => _filtroProv = f);
          if ((antes == 'inactivos') != (f == 'inactivos')) {
            _prov.cargarProveedores(estado: f == 'inactivos' ? 'inactivos' : null);
          }
        },
        onProveedor: _verProveedor,
        onNuevoProveedor: () => _formProveedor(),
        onPagar: _pagar,
        onRefrescar: _cargar,
      ),
    );
  }
}

// ── Página del detalle (carga la orden completa) ───────────────

class _OrdenPagina extends StatefulWidget {
  final int id;
  final Map<String, dynamic> inicial;
  final String? telefono;
  final Future<bool> Function(Map<String, dynamic>) onRecibir;
  final Future<bool> Function(Map<String, dynamic>) onPagar;
  final Future<bool> Function(Map<String, dynamic>) onCancelar;
  const _OrdenPagina({required this.id, required this.inicial, required this.onRecibir,
      required this.onPagar, required this.onCancelar, this.telefono});

  @override
  State<_OrdenPagina> createState() => _OrdenPaginaState();
}

class _OrdenPaginaState extends State<_OrdenPagina> {
  late Map<String, dynamic> _orden = widget.inicial;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final d = await context.read<ProveedoresProvider>().obtenerCompra(widget.id);
    if (!mounted) return;
    setState(() {
      if (d != null) _orden = d;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) => OrdenDetalleMovil(
        orden: _orden,
        telefonoProveedor: widget.telefono,
        cargando: _cargando,
        hoy: DateTime.now(),
        onRecibir: () async {
          if (await widget.onRecibir(_orden)) await _cargar();
        },
        onPagar: () async {
          if (await widget.onPagar(_orden)) await _cargar();
        },
        onPdf: () => ComprasPDFService.instance.abrirOrdenCompra(_orden),
        onCancelar: () async {
          if (await widget.onCancelar(_orden) && context.mounted) Navigator.pop(context);
        },
      );
}

// ── Hoja del proveedor ────────────────────────────────────────

class _HojaProveedor extends StatelessWidget {
  final Map<String, dynamic> proveedor;
  final List<Map<String, dynamic>> ordenes;
  final VoidCallback onEditar;
  final ValueChanged<Map<String, dynamic>> onOrden;
  const _HojaProveedor({required this.proveedor, required this.ordenes,
      required this.onEditar, required this.onOrden});

  @override
  Widget build(BuildContext context) {
    final p = proveedor;
    final nombre = '${p['nombre'] ?? ''}';
    final tel = '${p['telefono'] ?? ''}';
    final deuda = numDe(p['deuda']);
    Widget dato(String k, String v, {Color? col}) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CM.borde, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: cf(size: 10.5, w: FontWeight.w600, color: CM.gris2)),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                  child: Text(v, style: cf(size: 15, w: FontWeight.w800, color: col ?? CM.oscuro))),
            ]),
          ),
        );
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          Text(nombre, style: cf(size: 18, w: FontWeight.w800)),
          Text([
            if ('${p['nit'] ?? ''}'.isNotEmpty) 'NIT ${p['nit']}',
            if (tel.isNotEmpty) telefonoBonito(tel),
            if ('${p['ciudad'] ?? ''}'.isNotEmpty) '${p['ciudad']}',
          ].join(' · '), style: cf(size: 12, color: CM.gris)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => llamarNumero(context, tel, nombre),
              icon: const Icon(Icons.phone_outlined, size: 16, color: CM.verdeOs),
              label: Text('Llamar', style: cf(size: 12.5, w: FontWeight.w800, color: CM.verdeOs)),
              style: _borde(),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => abrirWhatsAppNumero(context, tel, nombre),
              icon: const Icon(Icons.chat_outlined, size: 16, color: Color(0xFF15803D)),
              label: Text('WhatsApp', style: cf(size: 12.5, w: FontWeight.w800, color: const Color(0xFF15803D))),
              style: _borde(),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined, size: 16, color: CM.verdeOs),
              label: Text('Editar', style: cf(size: 12.5, w: FontWeight.w800, color: CM.verdeOs)),
              style: _borde(),
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            dato('Le debemos', deuda > 0 ? pesosCO(deuda) : 'Nada', col: deuda > 0 ? CM.morado : CM.verdeOs),
            const SizedBox(width: 8),
            dato('Comprado', compactoPesos(numDe(p['total_comprado']))),
            const SizedBox(width: 8),
            dato('Órdenes', '${p['n_ordenes'] ?? ordenes.length}'),
          ]),
          const SizedBox(height: 12),
          Text('ÓRDENES', style: cf(size: 10.5, w: FontWeight.w800, color: CM.verdeOs, ls: .8)),
          const SizedBox(height: 6),
          Flexible(
            child: ordenes.isEmpty
                ? Padding(padding: const EdgeInsets.all(16),
                    child: Text('Sin órdenes en esta tienda.', textAlign: TextAlign.center,
                        style: cf(size: 13, color: CM.gris)))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: ordenes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: CM.borde),
                    itemBuilder: (_, i) {
                      final o = ordenes[i];
                      final (t, c, bg) = estadoOrden(o);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        onTap: () => onOrden(o),
                        title: Row(children: [
                          Text('${o['numero_orden']}', style: cf(size: 13, w: FontWeight.w800)),
                          const SizedBox(width: 8),
                          etiquetaCompra(t, c, bg),
                        ]),
                        subtitle: Text(fechaCortaCompra(fechaDe(o['fecha_orden']), DateTime.now()),
                            style: cf(size: 11.5, color: CM.gris2)),
                        trailing: Text(pesosCO(numDe(o['total'])), style: cf(size: 13.5, w: FontWeight.w800)),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  ButtonStyle _borde() => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        side: const BorderSide(color: CM.borde2, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}
