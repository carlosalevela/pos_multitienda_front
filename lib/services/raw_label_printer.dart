// lib/services/raw_label_printer.dart
//
// Impresión de etiquetas enviando comandos TSPL directamente al puerto USB
// usando CreateFileW / WriteFile de kernel32.dll.
// Bypasa el driver de BarTender (USE) y Windows GDI por completo.
// El tamaño lo controla el comando TSPL SIZE, no el driver.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'etiqueta_service.dart'; // PlantillaEtiqueta, ElemPos, fmtPrecio

/// Genera comandos TSPL y los escribe directamente al puerto USB de la
/// impresora via CreateFileW, sin pasar por Windows GDI ni el driver.
class RawLabelPrinter {
  RawLabelPrinter._();

  /// DPI del SAT TT448-2. Cambiar a 300 si la impresora tiene resolución 300ppp.
  static const int dpi = 203;

  static int _d(double mm) => (mm * dpi / 25.4).round();

  // Cola genérica que creamos una vez para enviar RAW sin BarTender
  static const _rawQueueName = 'Etiquetas Raw (POS)';

  /// Protocolo a usar: 'TSPL' o 'ZPL'. Se puede cambiar desde la UI.
  static String printerLanguage = 'ZPL';

  // ── API pública ───────────────────────────────────────────────

  /// Devuelve el nombre del puerto físico (ej. "USB002") via WMI.
  static Future<String?> getPortName(String printerName) async {
    try {
      final safe   = printerName.replaceAll("'", "\\'");
      final result = await Process.run('powershell', [
        '-NonInteractive', '-NoProfile', '-Command',
        "(Get-WmiObject Win32_Printer -Filter \"Name='$safe'\").PortName",
      ]);
      final port = result.stdout.toString().trim();
      return (result.exitCode == 0 && port.isNotEmpty) ? port : null;
    } catch (_) {
      return null;
    }
  }

  /// Crea la cola genérica "Etiquetas Raw (POS)" en [portName] si no existe.
  /// Usa el driver "Generic / Text Only" (incluido en Windows por defecto).
  /// Retorna el nombre de la cola creada, o null si falló.
  static Future<String?> prepararColaRaw(String portName) async {
    try {
      // Verificar si ya existe
      final check = await Process.run('powershell', [
        '-NonInteractive', '-NoProfile', '-Command',
        "(Get-Printer -Name '$_rawQueueName' -ErrorAction SilentlyContinue).Name",
      ]);
      if (check.stdout.toString().trim() == _rawQueueName) {
        return _rawQueueName; // ya existe
      }

      // Buscar o instalar el driver "Generic / Text Only" (inbox driver de Windows)
      final driverRes = await Process.run('powershell', [
        '-NonInteractive', '-NoProfile', '-Command',
        r'''
$d = (Get-PrinterDriver | Where-Object { $_.Name -like 'Generic*' -or $_.Name -like '*Text Only*' } | Select-Object -First 1).Name
if (-not $d) {
    try { Add-PrinterDriver -Name "Generic / Text Only" -ErrorAction Stop } catch {}
    $d = (Get-PrinterDriver | Where-Object { $_.Name -like 'Generic*' -or $_.Name -like '*Text Only*' } | Select-Object -First 1).Name
}
if (-not $d) { $d = "" }
$d
''',
      ]);
      final driver = driverRes.stdout.toString().trim();
      if (driver.isEmpty) {
        throw Exception(
            'No se pudo instalar el driver "Generic / Text Only".\n'
            'Abre PowerShell como administrador y ejecuta:\n'
            '  Add-PrinterDriver -Name "Generic / Text Only"\n'
            'Luego intenta imprimir de nuevo.');
      }

      // Crear la cola
      final add = await Process.run('powershell', [
        '-NonInteractive', '-NoProfile', '-Command',
        "Add-Printer -Name '$_rawQueueName' -DriverName '$driver' -PortName '$portName'",
      ]);
      if (add.exitCode != 0) {
        throw Exception('Add-Printer falló (código ${add.exitCode}):\n${add.stderr}');
      }

      // Confirmar
      final verify = await Process.run('powershell', [
        '-NonInteractive', '-NoProfile', '-Command',
        "(Get-Printer -Name '$_rawQueueName' -ErrorAction SilentlyContinue).Name",
      ]);
      if (verify.stdout.toString().trim() != _rawQueueName) {
        throw Exception('La cola fue creada pero no se puede verificar.');
      }
      return _rawQueueName;
    } catch (e) {
      throw Exception('No se pudo crear la cola de impresión directa:\n$e');
    }
  }

  /// Imprime [cantidad] etiquetas vía TSPL directo.
  /// Primera vez: crea la cola genérica "Etiquetas Raw (POS)" automáticamente.
  static Future<void> printLabel(
    String               printerName,
    PlantillaEtiqueta    p,
    Map<String, dynamic> producto,
    int                  cantidad,
  ) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Raw label printing solo en Windows');
    }
    final cmds  = printerLanguage == 'ZPL'
        ? buildZpl(p, producto, cantidad)
        : buildTspl(p, producto, cantidad);
    final bytes = Uint8List.fromList(cmds.codeUnits);
    final portName = await getPortName(printerName);

    if (portName == null || portName.isEmpty) {
      throw Exception('No se encontró el puerto para "$printerName".');
    }

    // Crear/verificar la cola genérica (operación de 1-2 segundos la primera vez)
    final rawQueue = await prepararColaRaw(portName);

    // La cola genérica usa winprint.dll → bytes directo a usbmon.dll
    // sin que BarTender intercepte nada.
    _rawPrint(rawQueue, bytes);
  }

  // ── Escritura via Winspool RAW ────────────────────────────────

  static final _ws = DynamicLibrary.open('winspool.drv');

  // OpenPrinterW(pPrinterName, phPrinter, pDefault) → BOOL
  static final _openPrinter = _ws.lookupFunction<
      Int32 Function(Pointer<Uint16>, Pointer<IntPtr>, Pointer<Void>),
      int   Function(Pointer<Uint16>, Pointer<IntPtr>, Pointer<Void>)>('OpenPrinterW');

  // StartDocPrinterW(hPrinter, Level, pDocInfo) → DWORD jobId
  static final _startDoc = _ws.lookupFunction<
      Uint32 Function(IntPtr, Uint32, Pointer<Void>),
      int    Function(int,   int,    Pointer<Void>)>('StartDocPrinterW');

  // WritePrinter(hPrinter, pBuf, cbBuf, pcWritten) → BOOL
  static final _writePrinter = _ws.lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
      int   Function(int,    Pointer<Uint8>, int,    Pointer<Uint32>)>('WritePrinter');

  // EndDocPrinter(hPrinter) → BOOL
  static final _endDoc = _ws.lookupFunction<
      Int32 Function(IntPtr), int Function(int)>('EndDocPrinter');

  // ClosePrinter(hPrinter) → BOOL
  static final _closePrinter = _ws.lookupFunction<
      Int32 Function(IntPtr), int Function(int)>('ClosePrinter');

  // GetPrinterW(hPrinter, Level, pPrinter, cbBuf, pcbNeeded) → BOOL
  static final _getPrinterW = _ws.lookupFunction<
      Int32 Function(IntPtr, Uint32, Pointer<Void>, Uint32, Pointer<Uint32>),
      int   Function(int,    int,    Pointer<Void>, int,    Pointer<Uint32>)>('GetPrinterW');

  // SetPrinterW(hPrinter, Level, pPrinter, Command) → BOOL
  static final _setPrinterW = _ws.lookupFunction<
      Int32 Function(IntPtr, Uint32, Pointer<Void>, Uint32),
      int   Function(int,    int,    Pointer<Void>, int)>('SetPrinterW');

  // ── DEVMODE paper-size override ───────────────────────────────

  /// Modifica el DEVMODE de nivel 9 (por-usuario) del driver para usar
  /// papel personalizado [widthMm] × [heightMm].  No requiere admin.
  /// Después de llamar esto, directPrintPdf usará el tamaño correcto.
  static void setDriverPaperSize(String printerName, double widthMm, double heightMm) {
    final nameW = _utf16(printerName);
    final hPtr  = malloc<IntPtr>();
    hPtr.value  = 0;

    final opened = _openPrinter(nameW, hPtr, nullptr);
    malloc.free(nameW);
    if (opened == 0 || hPtr.value == 0) {
      malloc.free(hPtr);
      throw Exception('No se pudo abrir "$printerName" (setDriverPaperSize).');
    }
    final handle = hPtr.value;
    malloc.free(hPtr);

    try {
      // ① obtener tamaño del buffer
      final needed = malloc<Uint32>();
      needed.value = 0;
      _getPrinterW(handle, 9, nullptr, 0, needed);
      final bufSize = needed.value;
      malloc.free(needed);
      if (bufSize == 0) throw Exception('GetPrinterW: buffer size = 0.');

      // ② leer PRINTER_INFO_9
      final buf      = malloc<Uint8>(bufSize);
      final needed2  = malloc<Uint32>();
      final ok = _getPrinterW(handle, 9, buf.cast<Void>(), bufSize, needed2);
      malloc.free(needed2);
      if (ok == 0) { malloc.free(buf); throw Exception('GetPrinterW Level 9 falló.'); }

      // PRINTER_INFO_9 = { PDEVMODE pDevMode } → primeros 8 bytes = dirección del DEVMODE
      final dmAddr = buf.cast<IntPtr>()[0];
      if (dmAddr == 0) { malloc.free(buf); throw Exception('DEVMODE pointer es null.'); }

      // ③ modificar campos del DEVMODE (offsets en bytes, estructura DEVMODEW):
      //   dmFields       → offset 72 (DWORD)
      //   dmPaperSize    → offset 78 (Int16): 256 = DMPAPER_USER
      //   dmPaperLength  → offset 80 (Int16): altura en décimas de mm
      //   dmPaperWidth   → offset 82 (Int16): ancho en décimas de mm
      //   dmPrintQuality → offset 90 (Int16): DMRES_HIGH (-4) = mayor calidad
      //   dmColor        → offset 92 (Int16): DMCOLOR_MONOCHROME (1) = sin antialias
      //
      // DM_PAPERSIZE=0x02, DM_PAPERLENGTH=0x04, DM_PAPERWIDTH=0x08,
      // DM_PRINTQUALITY=0x40, DM_COLOR=0x800
      Pointer<Uint32>.fromAddress(dmAddr + 72).value |= 0x84E;
      Pointer<Int16>.fromAddress(dmAddr + 78).value = 256;              // DMPAPER_USER
      Pointer<Int16>.fromAddress(dmAddr + 80).value = (heightMm * 10).round();
      Pointer<Int16>.fromAddress(dmAddr + 82).value = (widthMm  * 10).round();
      Pointer<Int16>.fromAddress(dmAddr + 90).value = -4;               // DMRES_HIGH
      Pointer<Int16>.fromAddress(dmAddr + 92).value = 1;                // DMCOLOR_MONOCHROME

      // ④ aplicar con SetPrinterW nivel 9 (no requiere admin, solo PRINTER_ACCESS_USE)
      final setOk = _setPrinterW(handle, 9, buf.cast<Void>(), 0);
      malloc.free(buf);
      if (setOk == 0) throw Exception(
          'SetPrinterW Level 9 falló. Intenta ejecutar la app como administrador.');
    } finally {
      _closePrinter(handle);
    }
  }

  /// Envía [data] como job RAW a la cola [queueName] via Winspool.
  /// La cola genérica usa winprint.dll → pasa bytes directo a usbmon.dll.
  static void _rawPrint(String? queueName, Uint8List data) {
    if (queueName == null) throw Exception('Nombre de cola nulo.');

    final nameW   = _utf16(queueName);
    final hPtr    = malloc<IntPtr>();
    hPtr.value    = 0;

    final opened = _openPrinter(nameW, hPtr, nullptr);
    malloc.free(nameW);
    if (opened == 0 || hPtr.value == 0) {
      malloc.free(hPtr);
      throw Exception('OpenPrinterW falló para "$queueName".');
    }
    final handle = hPtr.value;
    malloc.free(hPtr);

    // DOC_INFO_1W: pDocName, pOutputFile, pDatatype
    // Struct: 3 pointers (24 bytes on x64)
    final docName   = _utf16('EtiquetaRaw');
    final dtRaw     = _utf16('RAW');
    final docInfo   = malloc<IntPtr>(3);
    docInfo[0]      = docName.address;   // pDocName
    docInfo[1]      = 0;                  // pOutputFile (null)
    docInfo[2]      = dtRaw.address;     // pDatatype

    final jobId = _startDoc(handle, 1, docInfo.cast<Void>());
    malloc.free(docInfo);
    malloc.free(docName);
    malloc.free(dtRaw);

    if (jobId == 0) {
      _closePrinter(handle);
      throw Exception('StartDocPrinterW falló (jobId=0) para "$queueName".');
    }

    final buf     = malloc<Uint8>(data.length);
    final written = malloc<Uint32>();
    try {
      for (int i = 0; i < data.length; i++) { buf[i] = data[i]; }
      final ok = _writePrinter(handle, buf, data.length, written);
      if (ok == 0) throw Exception('WritePrinter falló para "$queueName".');
    } finally {
      malloc.free(buf);
      malloc.free(written);
      _endDoc(handle);
      _closePrinter(handle);
    }
  }

  // ── ZPL builder ───────────────────────────────────────────────

  /// Genera comandos ZPL (Zebra Printer Language) para la etiqueta.
  static String buildZpl(PlantillaEtiqueta p, Map<String, dynamic> producto, int cantidad) {
    final b   = StringBuffer();
    final pos = p.posiciones;

    final codigoBase     = (producto['codigo_barras'] as String?)?.trim() ?? '';
    final nombreBase     = (producto['nombre']        as String?) ?? '';
    final precio         = producto['precio_venta'];
    final precioMay      = producto['precio_mayoreo'];
    final tiendaBase     = (producto['tienda_nombre']    as String?) ?? '';
    final catBase        = (producto['categoria_nombre'] as String?) ?? '';

    final nombreFinal    = pos['nombre']?.textoCustom         ?? nombreBase;
    final tiendaFinal    = pos['tienda']?.textoCustom         ?? tiendaBase;
    final catFinal       = pos['categoria']?.textoCustom      ?? catBase;
    final barcodeCustom  = pos['barcode']?.textoCustom?.trim() ?? '';
    final codigoFinal    = (barcodeCustom.isNotEmpty && !barcodeCustom.startsWith('\$'))
        ? barcodeCustom : codigoBase;
    final precioFinal    = pos['precio']?.textoCustom
        ?? (precio != null ? '\$${fmtPrecio(precio)}' : null);
    final precioMayFinal = pos['precio_mayoreo']?.textoCustom
        ?? (precioMay != null ? 'May:\$${fmtPrecio(precioMay)}' : null);

    final wDots = _d(p.anchoMm);
    final hDots = _d(p.altoMm);

    b.writeln('^XA');
    b.writeln('^PR3,3');   // Print rate 3 ips (más lento = más calor = más oscuro)
    b.writeln('^MD30');    // Media Darkness 0-30, 30 = máxima densidad
    b.writeln('^PW$wDots');
    b.writeln('^LL$hDots');
    b.writeln('^LH0,0');   // label home

    if (p.mostrarNombre && nombreFinal.isNotEmpty) {
      final ep = pos['nombre'];
      if (ep != null) {
        final x = _d(ep.x); final y = _d(ep.y);
        final (fh, fw) = _zplFont(ep.fontSize);
        b.writeln('^FO$x,$y^A0N,$fh,$fw^FD${_escZpl(nombreFinal)}^FS');
        if (ep.bold == true) {
          b.writeln('^FO${x + 1},$y^A0N,$fh,$fw^FD${_escZpl(nombreFinal)}^FS');
        }
      }
    }

    if (p.mostrarTienda && tiendaFinal.isNotEmpty) {
      final ep = pos['tienda'];
      if (ep != null) {
        final x = _d(ep.x); final y = _d(ep.y);
        final (fh, fw) = _zplFont(ep.fontSize);
        b.writeln('^FO$x,$y^A0N,$fh,$fw^FD${_escZpl(tiendaFinal)}^FS');
      }
    }

    if (p.mostrarBarcode && codigoFinal.isNotEmpty) {
      final ep = pos['barcode'];
      if (ep != null) {
        final x = _d(ep.x); final y = _d(ep.y);
        final h = _d(ep.hMm ?? p.altoMm * 0.40);
        if (p.barcodeType == 'qrcode') {
          b.writeln('^FO$x,$y^BQN,2,3^FD  ${_escZpl(codigoFinal)}^FS');
        } else {
          final bcCmd = _bcCmdZpl(p.barcodeType);
          // BY = barcode width module; BCN/BEN/etc + height + interp line
          b.writeln('^FO$x,$y^BY2^$bcCmd,$h,Y,N,N^FD${_escZpl(codigoFinal)}^FS');
        }
      }
    }

    if (p.mostrarPrecio && precioFinal != null) {
      final ep = pos['precio'];
      if (ep != null) {
        final x = _d(ep.x); final y = _d(ep.y);
        final (fh, fw) = _zplFont(ep.fontSize);
        b.writeln('^FO$x,$y^A0N,$fh,$fw^FD${_escZpl(precioFinal)}^FS');
        if (ep.bold == true) {
          b.writeln('^FO${x + 1},$y^A0N,$fh,$fw^FD${_escZpl(precioFinal)}^FS');
        }
      }
    }

    if (p.mostrarPrecioMayoreo && precioMayFinal != null) {
      final ep = pos['precio_mayoreo'];
      if (ep != null) {
        final x = _d(ep.x); final y = _d(ep.y);
        final (fh, fw) = _zplFont(ep.fontSize);
        b.writeln('^FO$x,$y^A0N,$fh,$fw^FD${_escZpl(precioMayFinal)}^FS');
      }
    }

    if (p.mostrarCategoria && catFinal.isNotEmpty) {
      final ep = pos['categoria'];
      if (ep != null) {
        final x = _d(ep.x); final y = _d(ep.y);
        final (fh, fw) = _zplFont(ep.fontSize);
        b.writeln('^FO$x,$y^A0N,$fh,$fw^FD${_escZpl(catFinal)}^FS');
      }
    }

    b.writeln('^PQ$cantidad');
    b.writeln('^XZ');
    return b.toString();
  }

  static (int, int) _zplFont(double pt) {
    // A0 font height/width in dots: 1pt ≈ 2.8 dots @ 203dpi
    final h = (pt * 2.8).round().clamp(8, 80);
    final w = (h * 0.7).round();
    return (h, w);
  }

  static String _bcCmdZpl(String type) {
    switch (type) {
      case 'ean13':  return 'BEN';
      case 'ean8':   return 'B8N';
      case 'code39': return 'B3N';
      default:       return 'BCN';  // Code 128
    }
  }

  static String _escZpl(String s) =>
      s.replaceAll('^', ' ').replaceAll('~', '-')
       .replaceAll('\r', '').replaceAll('\n', ' ');

  // ── TSPL builder ──────────────────────────────────────────────

  /// Genera el string de comandos TSPL para la plantilla y producto dados.
  static String buildTspl(
    PlantillaEtiqueta    p,
    Map<String, dynamic> producto,
    int                  cantidad,
  ) {
    final b   = StringBuffer();
    final pos = p.posiciones;

    // Extraer datos del producto
    final codigoBase    = (producto['codigo_barras']    as String?)?.trim() ?? '';
    final nombreBase    = (producto['nombre']           as String?) ?? '';
    final precio        = producto['precio_venta'];
    final precioMay     = producto['precio_mayoreo'];
    final tiendaBase    = (producto['tienda_nombre']    as String?) ?? '';
    final catBase       = (producto['categoria_nombre'] as String?) ?? '';

    // textoCustom solo aplica si NO es el campo de barcode (donde sería inválido)
    final nombreFinal    = pos['nombre']?.textoCustom         ?? nombreBase;
    final tiendaFinal    = pos['tienda']?.textoCustom         ?? tiendaBase;
    final catFinal       = pos['categoria']?.textoCustom      ?? catBase;
    // Para el barcode ignoramos textoCustom si contiene "$" (es precio, no código)
    final barcodeCustom  = pos['barcode']?.textoCustom?.trim() ?? '';
    final codigoFinal    = (barcodeCustom.isNotEmpty && !barcodeCustom.startsWith('\$'))
        ? barcodeCustom
        : codigoBase;
    final precioFinal    = pos['precio']?.textoCustom
        ?? (precio != null ? '\$${fmtPrecio(precio)}' : null);
    final precioMayFinal = pos['precio_mayoreo']?.textoCustom
        ?? (precioMay != null ? 'May:\$${fmtPrecio(precioMay)}' : null);

    // Cabecera TSPL
    b.writeln('SIZE ${p.anchoMm.toStringAsFixed(1)} mm, '
              '${p.altoMm.toStringAsFixed(1)} mm');
    b.writeln('GAP 2 mm, 0 mm');
    b.writeln('DIRECTION 0');
    b.writeln('DENSITY 15'); // 0-15, 15 = máxima oscuridad térmica
    b.writeln('SPEED 2');    // pulgadas/seg; menor = más calor = más oscuro
    b.writeln('CLS');

    // ── Nombre ────────────────────────────────────────────────
    if (p.mostrarNombre && nombreFinal.isNotEmpty) {
      final ep = pos['nombre'];
      if (ep != null) {
        final x = _d(ep.x);
        final y = _d(ep.y);
        final (f, mx, my) = _font(ep.fontSize);
        final txt = _esc(nombreFinal);
        b.writeln('TEXT $x,$y,"$f",0,$mx,$my,"$txt"');
        if (ep.bold == true) { b.writeln('TEXT ${x + 1},$y,"$f",0,$mx,$my,"$txt"'); }
      }
    }

    // ── Tienda ────────────────────────────────────────────────
    if (p.mostrarTienda && tiendaFinal.isNotEmpty) {
      final ep = pos['tienda'];
      if (ep != null) {
        final x = _d(ep.x);
        final y = _d(ep.y);
        final (f, mx, my) = _font(ep.fontSize);
        b.writeln('TEXT $x,$y,"$f",0,$mx,$my,"${_esc(tiendaFinal)}"');
      }
    }

    // ── Código de barras ──────────────────────────────────────
    if (p.mostrarBarcode && codigoFinal.isNotEmpty) {
      final ep = pos['barcode'];
      if (ep != null) {
        final x = _d(ep.x);
        final y = _d(ep.y);
        final h = _d(ep.hMm ?? p.altoMm * 0.40);
        if (p.barcodeType == 'qrcode') {
          b.writeln('QRCODE $x,$y,M,4,A,"${_esc(codigoFinal)}"');
        } else {
          final tsplBc = _bcType(p.barcodeType);
          b.writeln('BARCODE $x,$y,"$tsplBc",$h,1,0,2,2,"${_esc(codigoFinal)}"');
        }
      }
    }

    // ── Precio ────────────────────────────────────────────────
    if (p.mostrarPrecio && precioFinal != null) {
      final ep = pos['precio'];
      if (ep != null) {
        final x = _d(ep.x);
        final y = _d(ep.y);
        final (f, mx, my) = _font(ep.fontSize);
        final txt = _esc(precioFinal);
        b.writeln('TEXT $x,$y,"$f",0,$mx,$my,"$txt"');
        if (ep.bold == true) { b.writeln('TEXT ${x + 1},$y,"$f",0,$mx,$my,"$txt"'); }
      }
    }

    // ── Precio mayoreo ────────────────────────────────────────
    if (p.mostrarPrecioMayoreo && precioMayFinal != null) {
      final ep = pos['precio_mayoreo'];
      if (ep != null) {
        final x = _d(ep.x);
        final y = _d(ep.y);
        final (f, mx, my) = _font(ep.fontSize);
        b.writeln('TEXT $x,$y,"$f",0,$mx,$my,"${_esc(precioMayFinal)}"');
      }
    }

    // ── Categoría ─────────────────────────────────────────────
    if (p.mostrarCategoria && catFinal.isNotEmpty) {
      final ep = pos['categoria'];
      if (ep != null) {
        final x = _d(ep.x);
        final y = _d(ep.y);
        final (f, mx, my) = _font(ep.fontSize);
        b.writeln('TEXT $x,$y,"$f",0,$mx,$my,"${_esc(catFinal)}"');
      }
    }

    b.writeln('PRINT $cantidad,1');
    return b.toString();
  }

  // ── Helpers TSPL ─────────────────────────────────────────────

  static (String, int, int) _font(double pt) {
    if (pt < 5)  return ('1', 1, 1);
    if (pt < 7)  return ('2', 1, 1);
    if (pt < 9)  return ('3', 1, 1);
    if (pt < 12) return ('4', 1, 1);
    if (pt < 16) return ('3', 2, 2);
    return        ('4', 2, 2);
  }

  static String _bcType(String type) {
    switch (type) {
      case 'ean13':  return 'EAN13';
      case 'ean8':   return 'EAN8';
      case 'code39': return '39';
      default:       return '128';
    }
  }

  static String _esc(String s) =>
      s.replaceAll('"', "'").replaceAll('\r', '').replaceAll('\n', ' ');

  static Pointer<Uint16> _utf16(String s) {
    final units = s.codeUnits;
    final ptr   = malloc<Uint16>(units.length + 1);
    for (int i = 0; i < units.length; i++) { ptr[i] = units[i]; }
    ptr[units.length] = 0;
    return ptr;
  }
}
