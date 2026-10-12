// lib/services/windows_printer_service.dart
//
// Impresión ESC/POS en Windows exe usando la API WritePrinter (modo RAW).
// Los bytes van directo al spooler → driver → impresora sin pasar por GDI/PDF.
// Funciona con CUALQUIER puerto: COM3, USB001, red, etc. — solo necesita el nombre.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // ── FFI → winspool.drv (lazily initialized) ─────────────
  // Solo se inicializa la primera vez que se llama printRaw en Windows.
  static final _ws = DynamicLibrary.open('winspool.drv');

  static final _openPrinterW = _ws.lookupFunction<
      Int32 Function(Pointer<Uint16>, Pointer<IntPtr>, Pointer<Void>),
      int   Function(Pointer<Uint16>, Pointer<IntPtr>, Pointer<Void>)>('OpenPrinterW');

  static final _startDocW = _ws.lookupFunction<
      Uint32 Function(IntPtr, Uint32, Pointer<Void>),
      int    Function(int,   int,    Pointer<Void>)>('StartDocPrinterW');

  static final _writePrinter = _ws.lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
      int   Function(int,    Pointer<Uint8>, int,    Pointer<Uint32>)>('WritePrinter');

  static final _endDocPrinter = _ws.lookupFunction<
      Int32 Function(IntPtr), int Function(int)>('EndDocPrinter');

  static final _closePrinter = _ws.lookupFunction<
      Int32 Function(IntPtr), int Function(int)>('ClosePrinter');

  static Pointer<Uint16> _utf16(String s) {
    final units = s.codeUnits;
    final ptr   = malloc<Uint16>(units.length + 1);
    for (int i = 0; i < units.length; i++) {
      ptr[i] = units[i];
    }
    ptr[units.length] = 0;
    return ptr;
  }

  // ── ESC/POS RAW via WritePrinter API ────────────────────
  //
  // Envía bytes ESC/POS crudos directamente al spooler de Windows usando
  // FFI a winspool.drv — sin PowerShell, sin compilación C#, respuesta inmediata.
  static Future<bool> printRaw(List<int> bytes) async {
    if (kIsWeb) return false;
    if (!Platform.isWindows) return false;
    final printerName = await getSavedName();
    if (printerName == null) return false;

    try {
      final data  = Uint8List.fromList(bytes);
      final nameW = _utf16(printerName);
      final hPtr  = malloc<IntPtr>();
      hPtr.value  = 0;

      final opened = _openPrinterW(nameW, hPtr, nullptr);
      malloc.free(nameW);
      if (opened == 0 || hPtr.value == 0) {
        malloc.free(hPtr);
        return false;
      }
      final handle = hPtr.value;
      malloc.free(hPtr);

      // DOC_INFO_1W: pDocName, pOutputFile (null), pDatatype
      final docName = _utf16('ESC/POS');
      final dtRaw   = _utf16('RAW');
      final docInfo = malloc<IntPtr>(3);
      docInfo[0]    = docName.address;
      docInfo[1]    = 0;
      docInfo[2]    = dtRaw.address;

      final jobId = _startDocW(handle, 1, docInfo.cast<Void>());
      malloc.free(docInfo);
      malloc.free(docName);
      malloc.free(dtRaw);

      if (jobId == 0) {
        _closePrinter(handle);
        return false;
      }

      final buf     = malloc<Uint8>(data.length);
      final written = malloc<Uint32>();
      bool ok = false;
      try {
        for (int i = 0; i < data.length; i++) { buf[i] = data[i]; }
        ok = _writePrinter(handle, buf, data.length, written) != 0;
      } finally {
        malloc.free(buf);
        malloc.free(written);
        _endDocPrinter(handle);
        _closePrinter(handle);
      }
      return ok;
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
