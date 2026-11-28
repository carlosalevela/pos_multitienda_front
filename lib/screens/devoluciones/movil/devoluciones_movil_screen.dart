// lib/screens/devoluciones/movil/devoluciones_movil_screen.dart
//
// Devoluciones en el celular: carga los datos y une la lista, el detalle y
// el flujo nuevo con el servidor.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/devolucion_model.dart';
import '../../../models/producto.dart';
import '../../../models/venta_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/devoluciones_provider.dart';
import '../../../services/caja_service.dart';
import '../../../services/devolucion_print_service.dart';
import '../../../services/inventario_service.dart';
import '../../../services/venta_service.dart';
import '../../clientes/widgets/cliente_contacto.dart' show pesosCO;
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import '../../compras/movil/nueva_orden_movil.dart' show escanearConCamara;
import 'devolucion_detalle_movil.dart';
import 'devoluciones_movil.dart';
import 'devoluciones_reglas.dart';
import 'nueva_devolucion_movil.dart';

class DevolucionesMovilScreen extends StatefulWidget {
  const DevolucionesMovilScreen({super.key});

  @override
  State<DevolucionesMovilScreen> createState() => _DevolucionesMovilScreenState();
}

class _DevolucionesMovilScreenState extends State<DevolucionesMovilScreen> {
  final _buscador = TextEditingController();
  final _ventas = VentaService();
  final _inventario = InventarioService();
  FiltroDevs _filtro = FiltroDevs.todas;
  RangoDevs _rango = RangoDevs.mes;
  DateTime? _desde, _hasta;
  String _busqueda = '';

  DevolucionesProvider get _prov => context.read<DevolucionesProvider>();
  AuthProvider get _auth => context.read<AuthProvider>();
  int? get _tienda => _auth.tiendaId == 0 ? null : _auth.tiendaId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
      final t = _tienda;
      if (t != null) {
        context.read<ConfigProvider>().asegurarCargada(t,
            empresaId: int.tryParse(_auth.empresaId));
      }
    });
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargar() {
    final (a, b) = fechasDeRango(_rango, DateTime.now(), desde: _desde, hasta: _hasta);
    return _prov.cargarDevoluciones(
      tiendaId: _tienda,
      fecha: mismoDia(a, b) ? fechaApi(a) : null,
      fechaIni: mismoDia(a, b) ? null : fechaApi(a),
      fechaFin: mismoDia(a, b) ? null : fechaApi(b),
    );
  }

  String get _textoRango {
    if (_rango != RangoDevs.elegido) return nombreRango(_rango);
    final (a, b) = fechasDeRango(_rango, DateTime.now(), desde: _desde, hasta: _hasta);
    String f(DateTime d) => '${d.day}/${d.month}';
    return mismoDia(a, b) ? f(a) : '${f(a)} – ${f(b)}';
  }

  Future<void> _elegirRango() async {
    final r = await showModalBottomSheet<RangoDevs>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: CM.borde2, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          for (final (x, t) in [(RangoDevs.hoy, 'Hoy'), (RangoDevs.semana, 'Esta semana'),
                                (RangoDevs.mes, 'Este mes'), (RangoDevs.elegido, 'Elegir fechas…')])
            ListTile(
              title: Text(t, style: cf(size: 14, w: FontWeight.w600)),
              trailing: _rango == x ? const Icon(Icons.check_rounded, color: CM.verde) : null,
              onTap: () => Navigator.pop(ctx, x),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (r == null || !mounted) return;
    if (r == RangoDevs.elegido) {
      final hoy = DateTime.now();
      final f = await showDateRangePicker(
        context: context,
        firstDate: DateTime(hoy.year - 2),
        lastDate: hoy,
        initialDateRange: _desde == null ? null : DateTimeRange(start: _desde!, end: _hasta ?? _desde!),
      );
      if (f == null || !mounted) return;
      _desde = f.start;
      _hasta = f.end;
    }
    setState(() => _rango = r);
    await _cargar();
  }

  // ── Detalle ─────────────────────────────────────────────

  Future<void> _abrir(DevolucionModel d) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Consumer<DevolucionesProvider>(
          builder: (ctx, prov, _) {
            final actual = prov.devoluciones.firstWhere((x) => x.id == d.id, orElse: () => d);
            return DevolucionDetalleMovil(
              dev: actual,
              puedeCancelar: _auth.esAdminOSupervisor,
              onImprimir: () => DevolucionPrintService.imprimir(ctx, actual, esCopia: true),
              onCancelar: () => _cancelar(ctx, actual),
            );
          },
        ),
      ));

  Future<void> _cancelar(BuildContext ctx, DevolucionModel d) async {
    final cambio = d.tipo == 'cambio';
    final si = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(cambio ? '¿Cancelar el cambio?' : '¿Cancelar la devolución?',
            style: cf(size: 16, w: FontWeight.w800)),
        content: Text('${[
          'Lo que trajo sale otra vez del stock o de averías',
          if (cambio) 'y lo que se llevó vuelve al stock',
          if (d.abonadoCredito > 0) 'y su deuda vuelve a subir ${pesosCO(d.abonadoCredito)}',
        ].join(' ')}. No se puede deshacer.', style: cf(size: 13, color: CM.gris)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
              child: Text('Volver', style: cf(size: 13.5, w: FontWeight.w700, color: CM.gris))),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: CM.rojo),
            child: Text('Sí, cancelar', style: cf(size: 13.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
    if (si != true || !ctx.mounted) return;
    final ok = await _prov.cancelarDevolucion(d.id);
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(ok ? 'DEV-${d.id} cancelada.' : _prov.error ?? 'No se pudo cancelar.',
          style: cf(size: 13, color: Colors.white)),
      backgroundColor: ok ? CM.verde : CM.rojo,
      behavior: SnackBarBehavior.floating,
    ));
    if (ok) await _cargar();
  }

  // ── Nueva ───────────────────────────────────────────────

  Future<void> _nueva({String? factura}) async {
    bool? caja;
    final t = _tienda;
    if (t != null) {
      try {
        caja = await CajaService().getSesionActiva(t) != null;
      } catch (_) {
        caja = null; // sin red: que decida el servidor
      }
    }
    if (!mounted) return;
    final cuentas = context.read<ConfigProvider>().cuentas;
    DevolucionModel? creada;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (pageCtx) => NuevaDevolucionMovil(
        cuentas: cuentas,
        cajaAbierta: caja,
        facturaInicial: factura,
        servicios: ServiciosNuevaDev(
          ventasDelDia: (d) async => (await _ventas.listarVentas(tiendaId: _tienda, fecha: fechaApi(d)))
              .map(VentaResumenModel.fromJson)
              .toList(),
          buscarFactura: (n) async => (await _ventas.buscarPorNumeroOrden(n, tiendaId: _tienda))
              .map(VentaResumenModel.fromJson)
              .toList(),
          disponible: (v) async {
            final raw = await _ventas.ventaDisponibleDevolucion(v.id);
            return raw == null
                ? (null, 'No se pudo cargar la venta ${v.numeroFactura}.')
                : (VentaDisponibleModel.fromJson(raw), null);
          },
          buscarProductos: (q) async {
            final r = await _inventario.buscarProductoPos(q: q, tiendaId: _tienda);
            return r['success'] == true ? (r['data'] as List<Producto>) : <Producto>[];
          },
          escanear: escanearConCamara,
          registrar: (p) async {
            final r = await _registrar(p);
            if (r.$2 != null) return r.$2;
            creada = r.$1;
            if (pageCtx.mounted) Navigator.of(pageCtx).pop();
            return null;
          },
        ),
      ),
    ));
    if (!mounted) return;
    await _cargar();
    final d = creada;
    if (d == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_mensajeCreada(d), style: cf(size: 13, color: Colors.white)),
      backgroundColor: CM.verde,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
    if (_imprimirUltima) await DevolucionPrintService.imprimir(context, d);
  }

  bool _imprimirUltima = true;

  String _mensajeCreada(DevolucionModel d) {
    if (d.tipo == 'cambio') return 'Cambio DEV-${d.id} registrado.';
    if (d.abonadoCredito > 0) {
      return d.reembolsado > 0
          ? 'DEV-${d.id}: ${pesosCO(d.abonadoCredito)} abonaron a su deuda y se le devuelven ${pesosCO(d.reembolsado)}.'
          : 'DEV-${d.id}: los ${pesosCO(d.abonadoCredito)} abonaron a su deuda. No se le entrega plata.';
    }
    return 'Devolución DEV-${d.id} registrada.';
  }

  /// (devolución creada, error)
  Future<(DevolucionModel?, String?)> _registrar(PedidoDev p) async {
    _imprimirUltima = p.imprimir;
    final Map<String, dynamic> r;
    if (p.tipo == TipoOp.cambio) {
      r = await _prov.crearCambio(
        ventaId: p.ventaId,
        metodoPago: 'efectivo',
        detalles: p.detalles,
        productosReemplazo: p.reemplazos,
        motivoCambio: p.motivoCambio,
        observaciones: p.observaciones.isEmpty ? null : p.observaciones,
        metodoPagoDiferencia: p.metodo,
        montoRecibido: p.montoRecibido,
        cuentaDestinoId: p.cuentaId,
      );
    } else {
      r = await _prov.crearDevolucion(
        ventaId: p.ventaId,
        metodoPago: p.metodo ?? 'efectivo',
        detalles: p.detalles,
        observaciones: p.observaciones,
        cuentaDestinoId: p.cuentaId,
      );
    }
    if (r['success'] != true) return (null, r['error']?.toString() ?? 'No se pudo registrar.');
    try {
      final raw = r['data'];
      if (raw is Map<String, dynamic>) {
        final src = raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw;
        var d = DevolucionModel.fromJson(src);
        final ab = (raw['abonado_credito'] as num?)?.toDouble();
        if (ab != null && d.abonadoCredito == 0 && ab > 0) {
          d = DevolucionModel.fromJson({...src, 'abonado_credito': ab});
        }
        return (d, null);
      }
    } catch (_) {}
    return (null, null);
  }

  @override
  Widget build(BuildContext context) => Consumer<DevolucionesProvider>(
        builder: (_, prov, _) => DevolucionesMovil(
          buscador: _buscador,
          datos: DatosDevsMovil(
            devoluciones: prov.devoluciones,
            filtro: _filtro,
            rango: _rango,
            textoRango: _textoRango,
            busqueda: _busqueda,
            cargando: prov.cargando,
            error: prov.error,
            hoy: DateTime.now(),
          ),
          acciones: AccionesDevsMovil(
            onFiltro: (f) => setState(() => _filtro = f),
            onRango: _elegirRango,
            onBuscar: (t) => setState(() => _busqueda = t),
            onAbrir: _abrir,
            onNueva: _nueva,
            onRefrescar: _cargar,
          ),
        ),
      );
}
