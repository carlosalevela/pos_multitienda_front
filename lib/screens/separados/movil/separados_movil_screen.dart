// lib/screens/separados/movil/separados_movil_screen.dart
//
// Separados en el celular: carga los datos y une la lista, el detalle, las
// hojas, el nuevo separado y los recordatorios con el servidor.

import 'dart:async';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' show PaperSize;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/alerta_separado.dart';
import '../../../models/cliente.dart';
import '../../../models/producto.dart';
import '../../../models/separado.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cliente_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../services/caja_service.dart';
import '../../../services/cliente_service.dart';
import '../../../services/inventario_service.dart';
import '../../../services/recibo_pdf_service.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../services/windows_printer_service.dart';
import '../../clientes/widgets/cliente_contacto.dart' show abrirWhatsAppNumero, llamarNumero, pesosCO;
import '../../clientes/widgets/cliente_form.dart';
import '../../clientes/widgets/clientes_movil.dart' show CM, cf;
import '../../compras/movil/nueva_orden_movil.dart' show escanearConCamara;
import 'hojas_separado_movil.dart';
import 'nuevo_separado_movil.dart';
import 'recordatorios_movil.dart';
import 'separado_detalle_movil.dart';
import 'separados_movil.dart';
import 'separados_reglas.dart';

class SeparadosMovilScreen extends StatefulWidget {
  const SeparadosMovilScreen({super.key});

  @override
  State<SeparadosMovilScreen> createState() => _SeparadosMovilScreenState();
}

class _SeparadosMovilScreenState extends State<SeparadosMovilScreen> {
  final _svc = ClienteService();
  final _inv = InventarioService();
  final _buscador = TextEditingController();
  List<Separado> _seps = [];
  FiltroSep _filtro = FiltroSep.activos;
  String _busqueda = '';
  bool _cargando = false;
  String? _error;
  double _abonosHoy = 0;
  int _nAbonosHoy = 0;
  int _pedido = 0;

  AuthProvider get _auth => context.read<AuthProvider>();
  int? get _tienda => _auth.tiendaId > 0 ? _auth.tiendaId : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
      final t = _tienda;
      if (t != null) {
        context.read<ConfigProvider>().asegurarCargada(t, empresaId: int.tryParse(_auth.empresaId));
      }
    });
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final n = ++_pedido;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        _svc.getSeparados(tiendaId: _tienda),
        _svc.getAbonosPorFecha(fecha: fechaApi(DateTime.now()), tiendaId: _tienda),
      ]);
      if (!mounted || n != _pedido) return;
      final abonos = r[1] as Map<String, dynamic>;
      setState(() {
        _seps = r[0] as List<Separado>;
        _abonosHoy = (abonos['total'] as num?)?.toDouble() ?? 0;
        _nAbonosHoy = (abonos['abonos'] as List?)?.length ?? 0;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || n != _pedido) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los separados. Desliza hacia abajo para reintentar.';
      });
    }
  }

  void _poner(Separado s) {
    final i = _seps.indexWhere((x) => x.id == s.id);
    setState(() => i >= 0 ? _seps[i] = s : _seps.insert(0, s));
  }

  Future<bool?> _cajaAbierta() async {
    final t = _tienda;
    if (t == null) return null;
    try {
      return await CajaService().getSesionActiva(t) != null;
    } catch (_) {
      return null; // sin red: que decida el servidor
    }
  }

  String get _nombreTienda {
    final e = _auth.empresaNombre;
    return e.isNotEmpty ? e : _auth.tiendaNombre;
  }

  Future<List<Producto>> _buscarProductos(String q) async {
    final r = await _inv.buscarProductoPos(q: q, tiendaId: _tienda);
    return r['success'] == true ? r['data'] as List<Producto> : <Producto>[];
  }

  // ── Escanear el recibo ──────────────────────────────────────

  Future<void> _escanearRecibo() async {
    final c = await escanearConCamara(context);
    if (c == null || !mounted) return;
    final id = int.tryParse(c.trim().toUpperCase().replaceAll('SEP-', '').replaceAll('#', ''));
    if (id == null) {
      avisoSep(context, 'Ese código no es de un recibo de separado.');
      return;
    }
    final s = _seps.where((x) => x.id == id).firstOrNull ?? await _svc.getSeparado(id);
    if (!mounted) return;
    if (s == null) {
      avisoSep(context, 'No se encontró el separado SEP-$id.');
      return;
    }
    await _abrir(s);
  }

  // ── Imprimir ────────────────────────────────────────────────

  Future<void> _imprimir(Separado s) async {
    final cfg = context.read<ConfigProvider>();
    final paper = cfg.tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;
    final empresa = _nombreTienda.isNotEmpty ? _nombreTienda : s.tiendaNombre;
    try {
      if (cfg.tipoPapel != 'pdf' && ThermalPrinterService.isWebUsbSupported) {
        final dev = await ThermalPrinterService.getAutoDevice();
        if (dev != null) {
          await ThermalPrinterService.printBytes(dev, await ThermalPrinterService.buildSeparadoRecibo(s,
              empresaNombre: empresa, paperSize: paper, nit: cfg.nit, direccion: cfg.direccion, telefono: cfg.telefono));
          return;
        }
      } else if (cfg.tipoPapel != 'pdf' && !kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
        await WindowsPrinterService.printRaw(await ThermalPrinterService.buildSeparadoRecibo(s,
            empresaNombre: empresa, paperSize: paper, nit: cfg.nit, direccion: cfg.direccion, telefono: cfg.telefono));
        return;
      }
    } catch (_) {}
    await ReciboPdfService.imprimirSeparado(separado: s, empresaNombre: empresa,
        nit: cfg.nit, direccion: cfg.direccion, telefono: cfg.telefono);
  }

  // ── Detalle ─────────────────────────────────────────────────

  Future<void> _abrir(Separado s) async {
    // Trae la versión completa (abonos con cuenta, bono, entrega).
    final completo = await _svc.getSeparado(s.id) ?? s;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _DetallePagina(inicial: completo, pantalla: this),
    ));
    if (mounted) _cargar();
  }

  // ── Nuevo ───────────────────────────────────────────────────

  Future<void> _nuevo() async {
    final t = _tienda;
    if (t == null) {
      avisoSep(context, 'Elige primero una tienda para crear el separado.');
      return;
    }
    final caja = await _cajaAbierta();
    if (!mounted) return;
    Separado? creado;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (pageCtx) => NuevoSeparadoMovil(
        cuentas: context.read<ConfigProvider>().cuentas,
        cajaAbierta: caja,
        servicios: ServiciosNuevoSep(
          buscarClientes: (q) => _svc.getClientes(q: q, tiendaId: t),
          crearCliente: (ctx) async {
            Cliente? nuevo;
            final prov = ctx.read<ClienteProvider>();
            final antes = prov.clientes.isEmpty ? null : prov.clientes.first.id;
            await ClienteForm.mostrar(ctx, tiendaId: t, tiendaNombre: _auth.tiendaNombre,
                onGuardado: () {
                  final primero = prov.clientes.isEmpty ? null : prov.clientes.first;
                  if (primero != null && primero.id != antes) nuevo = primero;
                });
            return nuevo;
          },
          buscarProductos: _buscarProductos,
          escanear: escanearConCamara,
          crear: (p) async {
            final r = await _svc.crearSeparado(p.datos(t));
            if (r['success'] != true) return r['error']?.toString() ?? 'No se pudo crear el separado.';
            creado = r['data'] as Separado;
            if (p.imprimir) unawaited(_imprimir(creado!));
            if (pageCtx.mounted) Navigator.of(pageCtx).pop();
            return null;
          },
        ),
      ),
    ));
    if (!mounted) return;
    final c = creado;
    if (c != null) {
      _poner(c);
      avisoSep(context, 'SEP-${c.id} creado. Le queda por pagar ${pesosCO(c.saldoPendiente)}.', error: false);
    }
    _cargar();
  }

  // ── Recordatorios ───────────────────────────────────────────

  Future<void> _recordatorios() async {
    final d = await _svc.getAlertasSeparados(tiendaId: _tienda);
    if (!mounted) return;
    final alertas = [
      ...(d['vencidos'] as List? ?? []),
      ...(d['por_vencer'] as List? ?? []),
    ].map((e) => AlertaSeparado.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecordatoriosMovil(
        alertas: alertas,
        tiendaNombre: _auth.tiendaNombre,
        enviar: (ids) async {
          final r = await _svc.enviarRecordatoriosSeparados(tiendaId: _tienda, separadoIds: ids);
          if (r['success'] != true) throw Exception(r['error']?.toString() ?? 'No se pudieron enviar.');
          final data = Map<String, dynamic>.from(r['data'] as Map);
          final env = (data['enviados'] as num?)?.toInt() ?? 0;
          final errores = (data['errores'] as List?)?.length ?? 0;
          final sin = (data['sin_telefono'] as List?)?.length ?? 0;
          if (env == 0 && errores > 0) {
            throw Exception('No se envió ninguno: ${(data['errores'] as List).first}');
          }
          return [
            'Enviados: $env',
            if (sin > 0) 'sin celular: $sin',
            if (errores > 0) 'con error: $errores',
          ].join(' · ');
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => SeparadosMovil(
        buscador: _buscador,
        datos: DatosSepsMovil(
          separados: _seps,
          filtro: _filtro,
          busqueda: _busqueda,
          cargando: _cargando,
          error: _error,
          tiendaNombre: _auth.tiendaNombre.isEmpty ? null : _auth.tiendaNombre,
          abonosHoy: _abonosHoy,
          nAbonosHoy: _nAbonosHoy,
          puedeRecordar: _auth.esAdminOSupervisor,
          hoy: DateTime.now(),
        ),
        acciones: AccionesSepsMovil(
          onFiltro: (f) => setState(() => _filtro = f),
          onBuscar: (t) => setState(() => _busqueda = t),
          onAbrir: _abrir,
          onNuevo: _nuevo,
          onEscanear: _escanearRecibo,
          onRecordar: _recordatorios,
          onAbonosHoy: () => avisoSep(context,
              _nAbonosHoy == 0 ? 'Hoy no hay abonos todavía.'
                  : 'Hoy: ${plural(_nAbonosHoy, 'abono', 'abonos')} por ${pesosCO(_abonosHoy)}.', error: false),
          onRefrescar: _cargar,
        ),
      );
}

// ── Página del detalle (con sus acciones) ─────────────────────

class _DetallePagina extends StatefulWidget {
  final Separado inicial;
  final _SeparadosMovilScreenState pantalla;
  const _DetallePagina({required this.inicial, required this.pantalla});

  @override
  State<_DetallePagina> createState() => _DetallePaginaState();
}

class _DetallePaginaState extends State<_DetallePagina> {
  late Separado _s = widget.inicial;
  bool _ocupado = false;

  _SeparadosMovilScreenState get _p => widget.pantalla;
  ClienteService get _svc => _p._svc;
  AuthProvider get _auth => context.read<AuthProvider>();

  Future<void> _refrescar() async {
    final n = await _svc.getSeparado(_s.id);
    if (n != null && mounted) {
      setState(() => _s = n);
      _p._poner(n);
    }
  }

  Future<void> _conOcupado(Future<void> Function() f) async {
    setState(() => _ocupado = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abonar() async {
    final caja = await _p._cajaAbierta();
    if (!mounted) return;
    final r = await abrirHojaSep<ResultadoAbono>(context, HojaAbonarSep(
        sep: _s, cuentas: context.read<ConfigProvider>().cuentas, cajaAbierta: caja));
    if (r == null || !mounted) return;
    final antes = _s;
    await _conOcupado(() async {
      final res = await _svc.abonarSeparado(_s.id, r.total, r.pagos.first.metodoPago,
          cuentaDestinoId: r.pagos.first.cuentaId, pagos: r.pagos.length > 1 ? r.pagos : null);
      if (!mounted) return;
      if (res['success'] != true) {
        avisoSep(context, res['error']?.toString() ?? 'No se pudo registrar el abono.');
        return;
      }
      await _refrescar();
      if (!mounted) return;
      avisoSep(context, _s.esPagado
          ? 'Abono de ${pesosCO(r.total)} registrado. ¡Quedó pagado completo!'
          : 'Abono de ${pesosCO(r.total)} registrado. Le falta ${pesosCO(_s.saldoPendiente)}.', error: false);
      if (r.imprimir) {
        final cfg = context.read<ConfigProvider>();
        unawaited(ReciboPdfService.imprimirReciboAbono(
          separado: antes, monto: r.total,
          metodoPago: r.pagos.length > 1 ? 'mixto' : r.pagos.first.metodoPago,
          empresaNombre: _p._nombreTienda.isNotEmpty ? _p._nombreTienda : _s.tiendaNombre,
          nit: cfg.nit, direccion: cfg.direccion, telefono: cfg.telefono,
        ));
      }
    });
  }

  Future<void> _cambiar(DetalleSeparado d) async {
    final r = await abrirHojaSep<ResultadoCambio>(context, HojaCambiarSep(
        sep: _s, detalle: d, buscar: _p._buscarProductos, escanear: escanearConCamara));
    if (r == null || !mounted) return;
    await _conOcupado(() async {
      final res = await _svc.cambiarProductoSeparado(separadoId: _s.id, detalleId: d.id,
          nuevoProductoId: r.producto.id, nuevaCantidad: r.cantidad, nuevoPrecio: r.producto.precio);
      if (!mounted) return;
      if (res['success'] != true) {
        avisoSep(context, res['error']?.toString() ?? 'No se pudo cambiar el producto.');
        return;
      }
      await _refrescar();
      if (mounted) avisoSep(context, 'Cambiado por ${r.producto.nombre}.', error: false);
    });
  }

  Future<void> _cancelar() async {
    final r = await abrirHojaSep<ResultadoCancelar>(context, HojaCancelarSep(sep: _s));
    if (r == null || !mounted) return;
    await _conOcupado(() async {
      final res = await _svc.cancelarSeparado(_s.id, motivo: r.motivo);
      if (!mounted) return;
      if (res['success'] != true) {
        avisoSep(context, res['error']?.toString() ?? 'No se pudo cancelar.');
        return;
      }
      await _refrescar();
      if (mounted) {
        avisoSep(context, res['bono_codigo'] != null
            ? 'Cancelado. Le quedó ${pesosCO((res['bono_saldo'] as num).toDouble())} a favor en el bono ${res['bono_codigo']}.'
            : 'Separado cancelado.', error: false);
      }
    });
  }

  Future<void> _entregar() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Ya se lo llevó?', style: cf(size: 16, w: FontWeight.w800)),
        content: Text('Marca SEP-${_s.id} como entregado a ${_s.clienteNombre}.',
            style: cf(size: 13, color: CM.gris)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
              child: Text('Todavía no', style: cf(size: 13.5, w: FontWeight.w700, color: CM.gris))),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: CM.verde),
            child: Text('Sí, entregado', style: cf(size: 13.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    await _conOcupado(() async {
      final res = await _svc.entregarSeparado(_s.id);
      if (!mounted) return;
      if (res['success'] != true) {
        avisoSep(context, res['error']?.toString() ?? 'No se pudo marcar como entregado.');
        return;
      }
      setState(() => _s = res['data'] as Separado);
      _p._poner(_s);
      avisoSep(context, 'SEP-${_s.id} entregado.', error: false);
    });
  }

  String _mensajeWhatsApp() {
    final tienda = _auth.tiendaNombre;
    if (_s.esCancelado && _s.bonoCodigo != null) return mensajeBono(_s, tienda);
    if (_s.porEntregar) return mensajeEntrega(_s, tienda);
    if (_s.esActivo) {
      final l = limiteDe(_s);
      return 'Hola ${nombreCorto(_s.clienteNombre)}, te escribimos de $tienda por tu separado SEP-${_s.id}: '
          'te faltan ${pesosCO(_s.saldoPendiente)}'
          '${l != null ? ' y la fecha límite es el ${l.day}/${l.month}/${l.year}' : ''}. ¡Gracias!';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cancelar = _auth.esAdminOSupervisor;
    final tel = _s.clienteTelefono ?? '';
    return SeparadoDetalleMovil(
      sep: _s,
      ocupado: _ocupado,
      acciones: AccionesDetalleSep(
        onLlamar: () => llamarNumero(context, tel, _s.clienteNombre),
        onWhatsApp: () => abrirWhatsAppNumero(context, tel, _s.clienteNombre, mensaje: _mensajeWhatsApp()),
        onImprimir: () => _p._imprimir(_s),
        onAbonar: _abonar,
        onCancelar: cancelar ? _cancelar : null,
        onCambiar: cancelar ? _cambiar : null,
        onEntregar: _entregar,
        onEnviarBono: () => abrirWhatsAppNumero(context, tel, _s.clienteNombre,
            mensaje: mensajeBono(_s, _auth.tiendaNombre)),
        onImprimirBono: () {
          final cfg = context.read<ConfigProvider>();
          ReciboPdfService.imprimirBonoSaldoFavor(separado: _s,
              empresaNombre: _p._nombreTienda, nit: cfg.nit, direccion: cfg.direccion, telefono: cfg.telefono);
        },
      ),
    );
  }
}
