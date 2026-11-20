import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contabilidad_models.dart';
import '../models/sesion_caja.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import 'caja_service.dart';
import 'cuenta_bancaria_service.dart';
import 'reporte_pdf_service.dart';
import 'thermal_printer_service.dart';
import 'windows_printer_service.dart';

class CierreTurnoPrintService {
  static Future<void> imprimir({
    required BuildContext               context,
    required SesionCaja                 sesion,
    required String                     fecha,
    required String                     tiendaNombre,
    required String                     empresaNombre,
    required Map<String, double>        metodosPago,
    required List<Map<String, dynamic>> gastosSesion,
    required double                     totalGastos,
    List<TopProducto>                   topProductos  = const [],
    List<Map<String, dynamic>>          separadosDia  = const [],
    List<Map<String, dynamic>>          ventasDia     = const [],
    List<Map<String, dynamic>>          abonosDia     = const [],
  }) async {
    final config   = context.read<ConfigProvider>();
    final tiendaId = context.read<AuthProvider>().tiendaId;

    try {
      // Fetch resumen por cuenta destino — se pasa a todos los caminos
      final resumenCuentas = tiendaId > 0
          ? await CuentaBancariaService().resumen(tiendaId, sesionId: sesion.id)
          : <Map<String, dynamic>>[];

      // Fetch detalle completo de la sesión — necesario porque el historial usa
      // un serializer ligero que omite saldo_inicial, num_transacciones y monto_esperado.
      List<Map<String, dynamic>> devolucionesDia = const [];
      SesionCaja sesionRich = sesion;
      try {
        final detRes = await CajaService().getDetalleSesion(sesion.id);
        if (detRes['success'] == true && detRes['data'] != null) {
          final data = detRes['data'] as Map<String, dynamic>;
          devolucionesDia = (data['devoluciones_detalle'] as List?)
                  ?.cast<Map<String, dynamic>>() ?? [];
          sesionRich = SesionCaja.fromJson(data);
        }
      } catch (_) {}

      final paperSize = config.tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;

      if (config.tipoPapel != 'pdf' && ThermalPrinterService.isWebUsbSupported) {
        // Web: WebUSB ESC/POS
        final device = await ThermalPrinterService.getOrRequestDevice();
        if (device != null) {
          final bytes = await ThermalPrinterService.buildCierreTurno(
            sesion: sesionRich, empresaNombre: empresaNombre,
            metodosPago: metodosPago, totalGastos: totalGastos,
            nit: config.nit, direccion: config.direccion, telefono: config.telefono,
            paperSize: paperSize, resumenCuentas: resumenCuentas,
            gastosSesion: gastosSesion, topProductos: topProductos,
            separadosDia: separadosDia,
            ventasDia: ventasDia, abonosDia: abonosDia,
            devolucionesDia: devolucionesDia,
          );
          await ThermalPrinterService.printBytes(device, bytes);
          return;
        }
      } else if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
        // Exe: ESC/POS RAW via WritePrinter
        final bytes = await ThermalPrinterService.buildCierreTurno(
          sesion: sesionRich, empresaNombre: empresaNombre,
          metodosPago: metodosPago, totalGastos: totalGastos,
          nit: config.nit, direccion: config.direccion, telefono: config.telefono,
          paperSize: paperSize, resumenCuentas: resumenCuentas,
          gastosSesion: gastosSesion, topProductos: topProductos,
          separadosDia: separadosDia,
          ventasDia: ventasDia, abonosDia: abonosDia,
          devolucionesDia: devolucionesDia,
        );
        await WindowsPrinterService.printRaw(bytes);
        return;
      }

      // Fallback: PDF A4
      await ReportePdfService.generarCierreTurno(
        sesion: sesionRich, fecha: fecha, tiendaNombre: tiendaNombre,
        empresaNombre: empresaNombre, metodosPago: metodosPago,
        gastosSesion: gastosSesion, totalGastos: totalGastos,
        topProductos: topProductos, separadosDia: separadosDia,
        resumenCuentas: resumenCuentas,
        ventasDia: ventasDia, abonosDia: abonosDia,
      );
    } catch (e, st) {
      debugPrint('CierreTurnoPrintService: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al imprimir: $e'),
            backgroundColor: const Color(0xFFBE123C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }
}
