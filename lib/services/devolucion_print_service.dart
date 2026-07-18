import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/devolucion_model.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import 'thermal_printer_service.dart';
import 'recibo_pdf_service.dart';
import 'windows_printer_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class DevolucionPrintService {
  /// Imprime directo a la impresora térmica si está configurada.
  /// Si no hay impresora USB vinculada, abre el diálogo PDF del navegador.
  static Future<void> imprimir(BuildContext context, DevolucionModel dev) async {
    final auth   = context.read<AuthProvider>();
    final config = context.read<ConfigProvider>();

    try {
      final paperSize = config.tipoPapel == '58mm' ? PaperSize.mm58 : PaperSize.mm80;

      if (config.tipoPapel != 'pdf' && ThermalPrinterService.isWebUsbSupported) {
        // Web: WebUSB ESC/POS
        final device = await ThermalPrinterService.getOrRequestDevice();
        if (device != null) {
          final bytes = await ThermalPrinterService.buildComprobanteDevolucion(
            dev: dev, empresaNombre: auth.empresaNombre, paperSize: paperSize,
          );
          await ThermalPrinterService.printBytes(device, bytes);
          return;
        }
      } else if (!kIsWeb && await WindowsPrinterService.hasSavedPrinter()) {
        // Exe: ESC/POS RAW via WritePrinter (cualquier puerto: COM, USB, red)
        final bytes = await ThermalPrinterService.buildComprobanteDevolucion(
          dev: dev, empresaNombre: auth.empresaNombre, paperSize: paperSize,
        );
        await WindowsPrinterService.printRaw(bytes);
        return;
      }
      // Fallback: PDF
      await ReciboPdfService.imprimirComprobanteDevolucion(
        dev:          dev,
        empresaNombre: auth.empresaNombre,
      );
    } catch (e, st) {
      debugPrint('DevolucionPrintService: $e\n$st');
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
