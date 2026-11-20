import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../../models/sesion_historial.dart';
import '../../providers/auth_provider.dart';
import '../../services/caja_service.dart';
import '../caja/widgets/registro_movimiento_diario.dart';

const _cGreen   = Color(0xFF006C49);
const _cNavy    = Color(0xFF131B2E);
const _cSurface = Color(0xFFF7F9FB);
const _cWhite   = Color(0xFFFFFFFF);
const _cBorder  = Color(0xFFC6C6CD);
const _cMuted   = Color(0xFF76777D);
const _cOnSurf  = Color(0xFF191C1E);

class FormatosDiariosScreen extends StatefulWidget {
  const FormatosDiariosScreen({super.key});

  @override
  State<FormatosDiariosScreen> createState() => _FormatosDiariosScreenState();
}

class _FormatosDiariosScreenState extends State<FormatosDiariosScreen> {
  final _service = CajaService();
  List<SesionHistorial> _sesiones = [];
  bool  _cargando = true;
  bool  _hasMore  = false;
  int   _offset   = 0;
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar({bool reset = true}) async {
    if (reset) setState(() { _cargando = true; _offset = 0; });
    final auth = context.read<AuthProvider>();
    final esCajero = auth.rol == 'cajero';

    final r = await _service.getHistorialSesiones(
      tiendaId:    auth.tiendaId,
      estado:      'cerrada',
      misSesiones: esCajero,
      limit:       _limit,
      offset:      reset ? 0 : _offset,
    );

    final items = (r['items'] as List<Map<String, dynamic>>)
        .map(SesionHistorial.fromJson)
        .toList();

    if (!mounted) return;
    setState(() {
      _cargando = false;
      _sesiones = reset ? items : [..._sesiones, ...items];
      _hasMore  = r['hasMore'] as bool? ?? false;
      _offset   = _sesiones.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cSurface,
      child: Column(children: [
        _Header(onRefresh: _cargar),
        if (_cargando && _sesiones.isEmpty)
          const Expanded(child: Center(
            child: CircularProgressIndicator(color: _cGreen),
          ))
        else if (_sesiones.isEmpty)
          const Expanded(child: _Empty())
        else
          Expanded(
            child: RefreshIndicator(
              color: _cGreen,
              onRefresh: () => _cargar(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                itemCount: _sesiones.length + (_hasMore ? 1 : 0),
                separatorBuilder: (ctx2, i2) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  if (i == _sesiones.length) {
                    return _LoadMoreButton(
                        onTap: () => _cargar(reset: false),
                        cargando: _cargando);
                  }
                  return _FormatoCard(
                    sesion: _sesiones[i],
                    onTap: () => _abrirFormato(ctx, _sesiones[i]),
                  );
                },
              ),
            ),
          ),
      ]),
    );
  }

  Future<void> _abrirFormato(BuildContext ctx, SesionHistorial s) async {
    // El endpoint de lista devuelve solo campos básicos; cargar el detalle completo
    SesionHistorial full = s;
    try {
      final r = await _service.getDetalleSesion(s.id);
      if (r['success'] == true && r['data'] != null) {
        full = SesionHistorial.fromJson(r['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    if (!mounted) return;

    DateTime fecha;
    try { fecha = DateTime.parse(full.fechaApertura.replaceAll(' ', 'T')).toLocal(); }
    catch (_) { fecha = DateTime.now(); }

    final diferencia = full.montoFinalReal - full.montoFinalSistema;
    final sobrante   = diferencia > 0 ? diferencia : 0.0;
    final faltante   = diferencia < 0 ? diferencia.abs() : 0.0;
    final efVentas   = full.ventasEfectivo + full.ventasMixtoEfectivo - full.compraBonasEfectivo;
    // neto devoluciones: cobros − devolvers − devoluciones_puras = -netoEfectivo (positivo = entró dinero)
    final devEfNeto  = full.cambiosCobrarEf - full.cambiosDevEf - full.devolucionesDirectasEf;
    final dtTotal    = full.ventasTarjeta + full.abonosTarjeta + full.ingresosSepTarjeta - full.compraBonaTarjeta;
    final trTotal    = full.ventasTransferencia + full.abonosTransferencia + full.ingresosSepTransferencia - full.compraBonasTransferencia;
    final nVentas    = full.numTransacciones - full.numCompraBonos;
    final dtCount    = full.ventasDetalle.where((v) => v['metodo_pago'] == 'tarjeta').length - (full.compraBonaTarjeta > 0 ? 1 : 0);
    final trCount    = full.ventasDetalle.where((v) => v['metodo_pago'] == 'transferencia').length - (full.compraBonasTransferencia > 0 ? 1 : 0);
    final bonoCount  = full.ventasDetalle.where((v) =>
        (v['metodo_pago'] as String? ?? '').contains('bono')).length;

    final data = RegistroMovimientoData(
      almacen:      full.tiendaNombre.toUpperCase(),
      fecha:        fecha,
      encargado:    full.empleadoNombre.toUpperCase(),
      numeroVentas: (full.numTransacciones - full.ventasBonoNum) + full.numIngresosSep + full.numAbonos,
      totalVentas:  (full.ventasTotal - full.ventasBono) + full.ingresosSepEfectivo + full.ingresosSepTarjeta + full.ingresosSepTransferencia + full.abonosEfectivo + full.abonosCreditoEfectivo + full.abonosTarjeta + full.abonosTransferencia,
      realizo:      full.empleadoNombre,
      observaciones: full.observaciones,
      filas: [
        FilaRegistro(signo: '+', concepto: 'VENTAS EN CAJA',
            cantidad: nVentas,
            montos: efVentas > 0 ? {MedioPago.efectivo: efVentas} : {}),
        FilaRegistro(signo: '+', concepto: 'INGRESOS SEPARADOS',
            cantidad: full.numIngresosSep,
            montos: {
              if (full.ingresosSepEfectivo > 0)      MedioPago.efectivo:    full.ingresosSepEfectivo,
              if (full.ingresosSepTarjeta > 0)       MedioPago.datafono:    full.ingresosSepTarjeta,
              if (full.ingresosSepTransferencia > 0) MedioPago.bancolombia: full.ingresosSepTransferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'ABONOS PAGOS CLIENTES',
            cantidad: full.numAbonos,
            montos: {
              if ((full.abonosEfectivo + full.abonosCreditoEfectivo) > 0) MedioPago.efectivo: full.abonosEfectivo + full.abonosCreditoEfectivo,
              if (full.abonosTarjeta > 0)       MedioPago.datafono:    full.abonosTarjeta,
              if (full.abonosTransferencia > 0) MedioPago.bancolombia: full.abonosTransferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'DEVOLUCIONES',
            cantidad: full.numDevoluciones,
            montos: {
              if (devEfNeto != 0)                            MedioPago.efectivo:    devEfNeto,
              if (full.netoCambiosTarjeta != 0)              MedioPago.datafono:    full.netoCambiosTarjeta,
              if (full.netoCambiosTransferencia != 0)        MedioPago.bancolombia: full.netoCambiosTransferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'COMPRA DE BONOS',
            cantidad: full.numCompraBonos,
            montos: {
              if (full.compraBonasEfectivo > 0)      MedioPago.efectivo:    full.compraBonasEfectivo,
              if (full.compraBonaTarjeta > 0)          MedioPago.datafono:    full.compraBonaTarjeta,
              if (full.compraBonasTransferencia > 0)   MedioPago.bancolombia: full.compraBonasTransferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'DATÁFONO',
            cantidad: dtCount,
            montos: dtTotal > 0 ? {MedioPago.datafono: dtTotal} : {}),
        FilaRegistro(signo: '+', concepto: 'TRANSFERENCIAS',
            cantidad: trCount,
            montos: trTotal > 0 ? {MedioPago.bancolombia: trTotal} : {}),
        FilaRegistro(signo: '+', concepto: 'BONOS REDIMIDOS',
            cantidad: full.ventasBonoNum,
            montos: full.ventasBono > 0
                ? {MedioPago.bono: full.ventasBono} : {}),
        FilaRegistro(signo: '+', concepto: 'BONOS + DIFERENCIA',
            cantidad: full.ventasBonoDifNum,
            montos: {
              if (full.ventasBonoEfectivo > 0)        MedioPago.efectivo:    full.ventasBonoEfectivo,
              if (full.ventasBonoTarjeta > 0)          MedioPago.datafono:    full.ventasBonoTarjeta,
              if (full.ventasBonoTransferencia > 0)    MedioPago.bancolombia: full.ventasBonoTransferencia,
              if (full.ventasBonoDifBonoParte > 0)     MedioPago.bono:        full.ventasBonoDifBonoParte,
            }),
        FilaRegistro(signo: '+', concepto: 'TOTAL EFECTIVO',
            cantidad: full.numTransacciones,
            montos: {MedioPago.efectivo: full.montoFinalSistema + full.gastosTotal - full.saldoInicial}),
        FilaRegistro(signo: '−', concepto: 'GASTOS',
            cantidad: full.numGastos,
            montos: full.gastosTotal > 0
                ? {MedioPago.efectivo: full.gastosTotal} : {}),
        FilaRegistro(signo: '+', concepto: 'SOBRANTES',
            cantidad: sobrante > 0 ? 1 : 0,
            montos: sobrante > 0 ? {MedioPago.efectivo: sobrante} : {}),
        FilaRegistro(signo: '−', concepto: 'FALTANTE',
            cantidad: faltante > 0 ? 1 : 0,
            montos: faltante > 0 ? {MedioPago.efectivo: faltante} : {}),
      ],
      totalEntregado: FilaRegistro(
        signo: '+',
        concepto: 'TOTAL EFECTIVO ENTREGADO',
        cantidad: full.numTransacciones,
        montos: {MedioPago.efectivo: full.montoFinalReal - full.saldoInicial},
      ),
    );

    final captureKey = GlobalKey();

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setState) {
          bool enviando = false;

          Future<void> enviarWA() async {
            setState(() => enviando = true);
            try {
              // Capturar el widget como imagen y convertir a PDF
              final boundary = captureKey.currentContext!
                  .findRenderObject() as RenderRepaintBoundary;
              final uiImage = await boundary.toImage(pixelRatio: 2.0);
              final byteData = await uiImage.toByteData(
                  format: ui.ImageByteFormat.png);
              final pngBytes = byteData!.buffer.asUint8List();

              final pageW = PdfPageFormat.a4.landscape.width;
              final pageH = uiImage.height * pageW / uiImage.width;
              final pdfDoc = pw.Document();
              pdfDoc.addPage(pw.Page(
                pageFormat: PdfPageFormat(pageW, pageH),
                margin: pw.EdgeInsets.zero,
                build: (_) => pw.Image(pw.MemoryImage(pngBytes)),
              ));
              final bytes = Uint8List.fromList(await pdfDoc.save());

              final ts = DateTime.now().millisecondsSinceEpoch;
              final filename =
                  'REGISTRO_${full.id}_${ts}_${full.tiendaNombre.replaceAll(' ', '_')}.pdf';
              final res = await CajaService().enviarFormatoDiarioWhatsApp(
                full.id, bytes, filename,
              );
              if (!ctx2.mounted) return;
              final ok = res['success'] == true;
              ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Formato enviado por WhatsApp ✓'
                    : 'Error: ${res['error'] ?? 'No se pudo enviar'}'),
                backgroundColor: ok ? _cGreen : const Color(0xFFBA1A1A),
              ));
            } catch (e) {
              if (!ctx2.mounted) return;
              ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
                content: Text('Error al generar PDF: $e'),
                backgroundColor: const Color(0xFFBA1A1A),
              ));
            } finally {
              if (ctx2.mounted) setState(() => enviando = false);
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFFE9ECEF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              width: 960,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Cabecera
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
                  decoration: const BoxDecoration(
                    color: _cNavy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.table_chart_outlined,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Registro de Movimiento Diario',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('Sesión #${full.id} · ${full.tiendaNombre}',
                              style: GoogleFonts.inter(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    // Botón WhatsApp
                    enviando
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white70),
                            ),
                          )
                        : IconButton(
                            onPressed: enviarWA,
                            tooltip: 'Enviar a WhatsApp',
                            icon: const Icon(Icons.send_rounded,
                                color: Color(0xFF25D366), size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx2),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white60, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ]),
                ),
                // Cuerpo
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: RepaintBoundary(
                      key: captureKey,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(2),
                        child: RegistroMovimientoDiario(data: data),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    decoration: const BoxDecoration(
      color: _cWhite,
      border: Border(bottom: BorderSide(color: _cBorder)),
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.table_chart_outlined,
            color: _cGreen, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Formatos Diarios',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: _cOnSurf, letterSpacing: -0.3)),
          Text('Registro de movimiento de cada turno',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _cMuted)),
        ]),
      ),
      IconButton(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded, color: _cMuted, size: 20),
        tooltip: 'Actualizar',
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFECEEF0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}

// ── Card ──────────────────────────────────────────────────

class _FormatoCard extends StatelessWidget {
  final SesionHistorial sesion;
  final VoidCallback    onTap;
  const _FormatoCard({required this.sesion, required this.onTap});

  static String _fecha(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw.replaceAll(' ', 'T')).toLocal();
      final meses = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                     'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return '${dt.day} ${meses[dt.month]} ${dt.year}';
    } catch (_) { return raw.substring(0, raw.length.clamp(0, 10)); }
  }

  static String _dinero(double v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '\$$b';
  }

  @override
  Widget build(BuildContext context) {
    final esExacto   = sesion.diferencia.abs() < 0.5;
    final esPos      = sesion.diferencia >= 0;
    final difColor   = esExacto ? _cGreen : esPos
        ? _cGreen : const Color(0xFFBA1A1A);
    final difBg      = esExacto || esPos
        ? const Color(0xFFE6F4EE) : const Color(0xFFFFDAD6);
    final difStr     = esExacto ? '\$0' : _dinero(sesion.diferencia.abs());
    final difLabel   = esExacto ? 'CUADRE' : esPos ? 'SOBRANTE' : 'FALTANTE';

    return Material(
      color: _cWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cBorder),
          ),
          child: Row(children: [
            // Ícono izquierdo
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.table_chart_outlined,
                  color: _cGreen, size: 20),
            ),
            const SizedBox(width: 14),
            // Info principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(_fecha(sesion.fechaCierre.isNotEmpty
                            ? sesion.fechaCierre : sesion.fechaApertura),
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _cOnSurf)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: difBg,
                        borderRadius: BorderRadius.circular(8)),
                      child: Text('$difLabel $difStr',
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: difColor)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(sesion.empleadoNombre,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _cMuted,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.store_outlined,
                        size: 11, color: _cBorder),
                    const SizedBox(width: 4),
                    Text(sesion.tiendaNombre,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _cBorder,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('Ventas: ${_dinero(sesion.ventasTotal)}',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569))),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: _cBorder, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Empty ─────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.table_chart_outlined,
            size: 36, color: Color(0xFFCBD5E1)),
      ),
      const SizedBox(height: 16),
      Text('Sin formatos registrados',
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: const Color(0xFF475569))),
      const SizedBox(height: 6),
      Text('Los formatos de cada cierre aparecerán aquí',
          style: GoogleFonts.inter(
              fontSize: 13, color: const Color(0xFF94A3B8))),
    ]),
  );
}

// ── Load More ─────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool cargando;
  const _LoadMoreButton({required this.onTap, required this.cargando});

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: cargando ? null : onTap,
      child: cargando
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _cGreen))
          : Text('Cargar más',
              style: GoogleFonts.inter(
                  color: _cGreen, fontWeight: FontWeight.w700)),
    ),
  );
}
