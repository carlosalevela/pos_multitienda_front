// lib/services/windows_printer_service.dart
//
// Impresión ESC/POS en Windows exe usando la API WritePrinter (modo RAW).
// Los bytes van directo al spooler → driver → impresora sin pasar por GDI/PDF.
// Funciona con CUALQUIER puerto: COM3, USB001, red, etc. — solo necesita el nombre.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowsPrinterService {
  static const _kPrinterName = 'native_selected_printer';

  static bool get isSupported => !kIsWeb;

  // ── Gestión de impresora seleccionada ───────────────────
  static Future<List<Printer>> listPrinters() async {
    if (kIsWeb) return [];
    return Printing.listPrinters();
  }

  static Future<String?> getSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrinterName);
  }

  static Future<bool> hasSavedPrinter() async =>
      (await getSavedName()) != null;

  static Future<Printer?> getSavedPrinter() async {
    final name = await getSavedName();
    if (name == null) return null;
    try {
      final printers = await Printing.listPrinters();
      return printers.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePrinter(Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrinterName, printer.name);
  }

  static Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrinterName);
  }

  // ── ESC/POS RAW via WritePrinter API ────────────────────
  //
  // Envía bytes ESC/POS crudos a través del spooler de Windows usando
  // el nombre de la impresora. Funciona con cualquier puerto (COM, USB, red).
  // Equivalente a WebUSB pero para el exe nativo.
  static Future<bool> printRaw(List<int> bytes) async {
    if (kIsWeb) return false;
    final printerName = await getSavedName();
    if (printerName == null) return false;

    try {
      final dir     = await getTemporaryDirectory();
      final datFile = File('${dir.path}\\receipt_escpos.bin');
      final psFile  = File('${dir.path}\\print_raw.ps1');

      await datFile.writeAsBytes(bytes);

      // Script PS1 con parámetros — evita problemas de escaping en Dart
      const psScript = r'''
param(
  [string]$PrinterName,
  [string]$DataFile
)
$ErrorActionPreference = 'Stop'
Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class RawPrint {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public struct DOCINFO {
    public string pDocName;
    public string pOutputFile;
    public string pDataType;
  }
  [DllImport("winspool.drv", CharSet = CharSet.Ansi)]
  public static extern bool OpenPrinter(string p, out IntPtr h, IntPtr d);
  [DllImport("winspool.drv")]
  public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.drv", CharSet = CharSet.Ansi)]
  public static extern bool StartDocPrinter(IntPtr h, int l, ref DOCINFO d);
  [DllImport("winspool.drv")]
  public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.drv")]
  public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.drv")]
  public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.drv")]
  public static extern bool WritePrinter(IntPtr h, IntPtr p, int c, out int w);
  public static bool Send(string printer, byte[] data) {
    IntPtr h;
    if (!OpenPrinter(printer, out h, IntPtr.Zero)) return false;
    var di = new DOCINFO { pDocName = "ESC/POS", pDataType = "RAW" };
    if (!StartDocPrinter(h, 1, ref di)) { ClosePrinter(h); return false; }
    StartPagePrinter(h);
    IntPtr ptr = Marshal.AllocCoTaskMem(data.Length);
    Marshal.Copy(data, 0, ptr, data.Length);
    int written = 0;
    WritePrinter(h, ptr, data.Length, out written);
    Marshal.FreeCoTaskMem(ptr);
    EndPagePrinter(h);
    EndDocPrinter(h);
    ClosePrinter(h);
    return written > 0;
  }
}
"@
$bytes = [IO.File]::ReadAllBytes($DataFile)
$ok = [RawPrint]::Send($PrinterName, $bytes)
if (-not $ok) { exit 1 }
''';

      await psFile.writeAsString(psScript);

      final result = await Process.run('powershell', [
        '-ExecutionPolicy', 'Bypass',
        '-NonInteractive',
        '-File',        psFile.path,
        '-PrinterName', printerName,
        '-DataFile',    datFile.path,
      ]);

      try { await datFile.delete(); } catch (_) {}
      try { await psFile.delete(); } catch (_) {}

      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // ── PDF via directPrintPdf (fallback impresoras no térmicas) ──
  static Future<bool> printPdf(List<int> bytes, String name) async {
    if (kIsWeb) return false;
    final printer = await getSavedPrinter();
    if (printer == null) return false;
    return Printing.directPrintPdf(
      printer: printer,
      onLayout: (_) async => Uint8List.fromList(bytes),
      name: name,
    );
  }
}
