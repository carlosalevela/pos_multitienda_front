import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/resumen_cierre.dart';
import '../../../providers/caja_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../services/windows_printer_service.dart';
import 'registro_movimiento_diario.dart';

class CajaCerradaCard extends StatelessWidget {
  final CajaProvider          caja;
  final AuthProvider          auth;
  final TextEditingController saldoCtrl;
  final VoidCallback?         onCajaAbierta;
  final ResumenCierre?        ultimoResumen;
  final double                ultimoMontoFinal;

  const CajaCerradaCard({
    super.key,
    required this.caja,
    required this.auth,
    required this.saldoCtrl,
    this.onCajaAbierta,
    this.ultimoResumen,
    this.ultimoMontoFinal = 0,
  });

  static const _green          = Color(0xFF006C49);
  static const _greenContainer = Color(0xFF6CF8BB);
  static const _surface        = Color(0xFFFFFFFF);
  static const _border         = Color(0xFFC6C6CD);
  static const _surfaceLow     = Color(0xFFF2F4F6);
  static const _textPrimary    = Color(0xFF191C1E);
  static const _textSecond     = Color(0xFF45464D);
  static const _textFaint      = Color(0xFF76777D);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Cabecera
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: const BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _greenContainer,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.point_of_sale_rounded,
                  size: 32, color: _green),
            ),
            const SizedBox(height: 16),
            Text('Apertura de Caja',
                style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Ingresa el monto inicial para comenzar el turno.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: _textSecond)),
          ]),
        ),

        // Formulario
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            // Label
            Align(
              alignment: Alignment.centerLeft,
              child: Text('MONTO INICIAL / BASE',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _textFaint, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 8),
            // Input
            Container(
              decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.5),
              ),
              child: Row(children: [
                const SizedBox(width: 16),
                Text('\$',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: _textFaint)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: saldoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 20, color: _border,
                          fontWeight: FontWeight.w700),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 16),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            // Botón Abrir
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: caja.procesando ? null : () async {
                  final ok = await caja.abrirCaja(
                    tiendaId:     auth.tiendaId,
                    saldoInicial: double.tryParse(saldoCtrl.text) ?? 0,
                  );
                  if (ok) {
                    unawaited(_abrirCajon());
                    onCajaAbierta?.call();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _greenContainer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: caja.procesando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('ABRIR CAJA',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            if (ultimoResumen != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 46,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: Text('Ver Formato de Movimiento Diario',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: () => _mostrarRegistro(context, ultimoResumen!, ultimoMontoFinal),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSecond,
                    side: const BorderSide(color: _border, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  void _mostrarRegistro(BuildContext context, ResumenCierre r, double montoFinalReal) {
    DateTime fecha;
    try { fecha = DateTime.parse(r.fechaApertura).toLocal(); }
    catch (_) { fecha = DateTime.now(); }

    final diferencia = montoFinalReal - r.montoEsperadoCaja;
    final sobrante   = diferencia > 0 ? diferencia : 0.0;
    final faltante   = diferencia < 0 ? diferencia.abs() : 0.0;
    final cb        = r.compraBonos;
    final efVentas  = r.ventas.efectivo + r.ventas.mixtoEfectivo - cb.efectivo;
    final dtTotal   = r.ventas.tarjeta  + r.abonos.tarjeta + r.abonos.ingresosSepTarjeta - cb.tarjeta;
    final trTotal   = r.ventas.transferencia + r.abonos.transferencia + r.abonos.ingresosSepTransferencia - cb.transferencia;
    final nVentas   = r.ventas.numTransacciones - cb.cantidad;
    final dtCount   = r.ventasDetalle.where((v) => v['metodo_pago'] == 'tarjeta').length - (cb.tarjeta > 0 ? 1 : 0);
    final trCount   = r.ventasDetalle.where((v) => v['metodo_pago'] == 'transferencia').length - (cb.transferencia > 0 ? 1 : 0);
    final bonoCount = r.ventasDetalle.where((v) =>
        (v['metodo_pago'] as String? ?? '').contains('bono')).length;

    final data = RegistroMovimientoData(
      almacen:      r.tiendaNombre.toUpperCase(),
      fecha:        fecha,
      encargado:    r.empleadoNombre.toUpperCase(),
      numeroVentas: r.ventas.numTransacciones,
      totalVentas:  r.ventas.total,
      realizo:      r.empleadoNombre,
      observaciones: '',
      filas: [
        FilaRegistro(signo: '+', concepto: 'VENTAS EN FACTURERO FÍSICO',
            cantidad: nVentas,
            montos: efVentas > 0 ? {MedioPago.efectivo: efVentas} : {}),
        FilaRegistro(signo: '+', concepto: 'INGRESOS SEPARADOS',
            cantidad: r.abonos.numIngresosSep,
            montos: {
              if (r.abonos.ingresosSepEfectivo > 0)      MedioPago.efectivo:    r.abonos.ingresosSepEfectivo,
              if (r.abonos.ingresosSepTarjeta > 0)       MedioPago.datafono:    r.abonos.ingresosSepTarjeta,
              if (r.abonos.ingresosSepTransferencia > 0) MedioPago.bancolombia: r.abonos.ingresosSepTransferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'ABONOS PAGOS CLIENTES',
            cantidad: r.abonos.cantidad,
            montos: {
              if ((r.abonos.efectivo + r.abonos.creditoEfectivo) > 0) MedioPago.efectivo: r.abonos.efectivo + r.abonos.creditoEfectivo,
              if (r.abonos.tarjeta > 0)       MedioPago.datafono:    r.abonos.tarjeta,
              if (r.abonos.transferencia > 0) MedioPago.bancolombia: r.abonos.transferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'DEVOLUCIONES',
            cantidad: r.devoluciones.cantidad,
            montos: r.devoluciones.efectivo > 0
                ? {MedioPago.efectivo: r.devoluciones.efectivo} : {}),
        FilaRegistro(signo: '+', concepto: 'COMPRA DE BONOS',
            cantidad: r.compraBonos.cantidad,
            montos: {
              if (r.compraBonos.efectivo > 0)      MedioPago.efectivo:    r.compraBonos.efectivo,
              if (r.compraBonos.tarjeta > 0)        MedioPago.datafono:    r.compraBonos.tarjeta,
              if (r.compraBonos.transferencia > 0)  MedioPago.bancolombia: r.compraBonos.transferencia,
            }),
        FilaRegistro(signo: '+', concepto: 'DATÁFONO',
            cantidad: dtCount,
            montos: dtTotal > 0 ? {MedioPago.datafono: dtTotal} : {}),
        FilaRegistro(signo: '+', concepto: 'TRANSFERENCIAS',
            cantidad: trCount,
            montos: trTotal > 0 ? {MedioPago.bancolombia: trTotal} : {}),
        FilaRegistro(signo: '+', concepto: 'BONOS REDIMIDOS',
            cantidad: r.ventas.bonoNum,
            montos: r.ventas.bono > 0
                ? {MedioPago.bono: r.ventas.bono} : {}),
        FilaRegistro(signo: '+', concepto: 'BONOS + DIFERENCIA',
            cantidad: r.ventas.bonoDifNum,
            montos: {
              if (r.ventas.bonoEfectivo > 0)        MedioPago.efectivo:    r.ventas.bonoEfectivo,
              if (r.ventas.bonoTarjeta > 0)          MedioPago.datafono:    r.ventas.bonoTarjeta,
              if (r.ventas.bonoTransferencia > 0)    MedioPago.bancolombia: r.ventas.bonoTransferencia,
              if (r.ventas.bonoDifBonoParte > 0)     MedioPago.bono:        r.ventas.bonoDifBonoParte,
            }),
        FilaRegistro(signo: '+', concepto: 'TOTAL EFECTIVO',
            cantidad: r.ventas.numTransacciones,
            montos: {MedioPago.efectivo: r.montoEsperadoCaja + r.gastos.efectivo}),
        FilaRegistro(signo: '−', concepto: 'GASTOS',
            cantidad: r.gastos.cantidad,
            montos: r.gastos.efectivo > 0
                ? {MedioPago.efectivo: r.gastos.efectivo} : {}),
        if (sobrante > 0)
          FilaRegistro(signo: '+', concepto: 'SOBRANTES',
              cantidad: 1,
              montos: {MedioPago.efectivo: sobrante}),
        if (faltante > 0)
          FilaRegistro(signo: '−', concepto: 'FALTANTE',
              cantidad: 1,
              montos: {MedioPago.efectivo: faltante}),
      ],
      totalEntregado: FilaRegistro(
        signo: '+',
        concepto: 'TOTAL EFECTIVO ENTREGADO',
        cantidad: r.ventas.numTransacciones,
        montos: {MedioPago.efectivo: r.montoEsperadoCaja},
      ),
    );

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFFE9ECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 900,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF131B2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.table_chart_outlined,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Registro de Movimiento Diario',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white60, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(2),
                  child: RegistroMovimientoDiario(data: data),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> _abrirCajon() async {
  try {
    if (ThermalPrinterService.isWebUsbSupported) {
      if (!await ThermalPrinterService.hasCashDrawer()) return;
      final dev = await ThermalPrinterService.getOrRequestDevice();
      if (dev != null) await ThermalPrinterService.kickDrawer(dev);
    } else if (!kIsWeb && await ThermalPrinterService.hasCashDrawer()) {
      final bytes = await ThermalPrinterService.buildDrawerBytes();
      await WindowsPrinterService.printRaw(bytes);
    }
  } catch (_) {}
}
