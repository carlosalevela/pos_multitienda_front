import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sesion_caja.dart';
import '../providers/config_provider.dart';
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
  }) async {
    final config = context.read<ConfigProvider>();

    try {
      final paperSize = config.tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;

      if (config.tipoPapel != 'pdf' && ThermalPrinterService.isWebUsbSupported) {
        // Web: WebUSB ESC/POS
        final device = await ThermalPrinterService.getOrRequestDevice();
        if (device != null) {
          final bytes = await ThermalPrinterService.buildCierreTurno(
            sesion: sesion, empresaNombre: empresaNombre,
            metodosPago: metodosPago, totalGastos: totalGastos,
            paperSize: paperSize,
          );
          await ThermalPrinterService.printBytes(device, bytes);
          return;
        }
      } else if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
        // Exe: ESC/POS RAW via WritePrinter
        final bytes = await ThermalPrinterService.buildCierreTurno(
          sesion: sesion, empresaNombre: empresaNombre,
          metodosPago: metodosPago, totalGastos: totalGastos,
          paperSize: paperSize,
        );
        await WindowsPrinterService.printRaw(bytes);
        return;
      }

      // Fallback: PDF A4
      await ReportePdfService.generarCierreTurno(
        sesion: sesion, fecha: fecha, tiendaNombre: tiendaNombre,
        empresaNombre: empresaNombre, metodosPago: metodosPago,
        gastosSesion: gastosSesion, totalGastos: totalGastos,
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
