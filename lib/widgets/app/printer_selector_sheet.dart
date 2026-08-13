// lib/widgets/app/printer_selector_sheet.dart
//
// Bottom sheet para seleccionar impresora antes de imprimir.
// Funciona tanto en Windows exe (Printing.listPrinters) como en
// Chrome/Edge web (WebUSB vía ThermalPrinterService).
//
// Uso:
//   final ok = await PrinterSelectorSheet.show(
//     context,
//     onPrint: (printerName) async { /* llamar ReciboPdfService, etc. */ },
//   );
//
// onPrint recibe el nombre de la impresora seleccionada.
// Si el usuario cierra el sheet sin imprimir, onPrint no se llama.

// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../services/thermal_printer_service.dart';
import '../../services/windows_printer_service.dart';
import '../../theme/app_colors.dart';

export '../../services/thermal_printer_service.dart' show ThermalDevice;

class PrinterSelectorSheet extends StatefulWidget {
  final Future<void> Function(String printerName) onPrint;

  const PrinterSelectorSheet({super.key, required this.onPrint});

  /// Muestra el sheet. Retorna true si se imprimió, false si se canceló.
  static Future<bool> show(
    BuildContext context, {
    required Future<void> Function(String printerName) onPrint,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context:        context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrinterSelectorSheet(onPrint: onPrint),
    );
    return result ?? false;
  }

  @override
  State<PrinterSelectorSheet> createState() => _PrinterSelectorSheetState();
}

class _PrinterSelectorSheetState extends State<PrinterSelectorSheet> {
  // Windows exe
  List<Printer> _winPrinters  = [];
  String?       _winSelected;   // nombre guardado o seleccionado en este sheet
  bool          _cargandoWin   = false;

  // Web USB
  ThermalDevice? _webDevice;
  bool           _cargandoWeb  = false;

  bool _imprimiendo = false;
  String? _error;

  final bool _esWeb    = kIsWeb;
  final bool _webUsb   = ThermalPrinterService.isWebUsbSupported;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    if (_webUsb) {
      setState(() => _cargandoWeb = true);
      try {
        final dev  = await ThermalPrinterService.getAutoDevice();
        if (!mounted) return;
        setState(() { _webDevice = dev; _cargandoWeb = false; });
      } catch (_) {
        if (mounted) setState(() => _cargandoWeb = false);
      }
    } else if (!_esWeb) {
      // Windows exe
      setState(() => _cargandoWin = true);
      try {
        final printers = await WindowsPrinterService.listPrinters();
        final saved    = await WindowsPrinterService.getSavedName();
        if (!mounted) return;
        setState(() {
          _winPrinters  = printers;
          _winSelected  = saved ?? printers.firstWhere(
              (p) => p.isDefault,
              orElse: () => printers.isNotEmpty ? printers.first : printers.first,
            ).name;
          _cargandoWin  = false;
        });
      } catch (_) {
        if (mounted) setState(() => _cargandoWin = false);
      }
    }
  }

  Future<void> _imprimir() async {
    if (_imprimiendo) return;

    String printerName;
    if (_webUsb) {
      if (_webDevice == null) return;
      printerName = _webDevice!.displayName;
    } else if (!_esWeb) {
      if (_winSelected == null) return;
      // Guardar la selección actual para las próximas veces
      final selected = _winPrinters.firstWhere(
        (p) => p.name == _winSelected,
        orElse: () => _winPrinters.first,
      );
      await WindowsPrinterService.savePrinter(selected);
      printerName = selected.name;
    } else {
      // Fallback: sin impresora específica (Firefox/Safari — layoutPdf)
      printerName = 'sistema';
    }

    setState(() { _imprimiendo = true; _error = null; });
    try {
      await widget.onPrint(printerName);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _imprimiendo = false; _error = e.toString(); });
    }
  }

  Future<void> _cambiarWebUsb() async {
    setState(() => _cargandoWeb = true);
    try {
      final dev = await ThermalPrinterService.requestDevice();
      if (!mounted) return;
      setState(() { _webDevice = dev; _cargandoWeb = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoWeb = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPrint = _webUsb
        ? _webDevice != null
        : !_esWeb
            ? _winSelected != null && _winPrinters.isNotEmpty
            : true;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.3,
      maxChildSize:     0.85,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.print_rounded,
                      color: AppColors.secondary, size: 19),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Seleccionar impresora',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  Text('Elige el destino antes de imprimir',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.onSurfaceVariant)),
                ]),
              ]),
            ),

            const Divider(height: 1, color: AppColors.surfaceContainerLow),

            // Cuerpo
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [

                  // ── Error ───────────────────────────────────────
                  if (_error != null) ...[
                    _Banner(
                      icon: Icons.error_outline_rounded,
                      text: _error!,
                      color: AppColors.error,
                      bg:   AppColors.errorContainer,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Web USB ─────────────────────────────────────
                  if (_webUsb) ...[
                    _SectionLabel('Impresora USB (WebUSB)'),
                    if (_cargandoWeb)
                      _LoadingRow()
                    else if (_webDevice != null)
                      _PrinterTile(
                        name:      _webDevice!.displayName,
                        subtitle:  _webDevice!.manufacturer.isNotEmpty
                                       ? _webDevice!.manufacturer
                                       : 'USB térmica',
                        selected:  true,
                        isDefault: false,
                        onTap:     null,
                        trailing: TextButton.icon(
                          onPressed: _imprimiendo ? null : _cambiarWebUsb,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                          label: const Text('Cambiar'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              padding: EdgeInsets.zero,
                              textStyle: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      )
                    else ...[
                      _Banner(
                        icon: Icons.usb_rounded,
                        text: 'No hay impresora USB conectada. '
                              'Toca "Conectar" para seleccionarla.',
                        color: const Color(0xFF0284C7),
                        bg:    const Color(0xFFF0F9FF),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _cargandoWeb ? null : _cambiarWebUsb,
                          icon: const Icon(Icons.usb_rounded, size: 16),
                          label: const Text('Conectar impresora USB'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.secondary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],

                  // ── Windows exe ─────────────────────────────────
                  ] else if (!_esWeb) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionLabel('Impresoras instaladas'),
                        if (!_cargandoWin)
                          GestureDetector(
                            onTap: _inicializar,
                            child: Row(children: [
                              const Icon(Icons.refresh_rounded,
                                  size: 14, color: AppColors.secondary),
                              const SizedBox(width: 3),
                              Text('Actualizar',
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: AppColors.secondary,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_cargandoWin)
                      _LoadingRow()
                    else if (_winPrinters.isEmpty)
                      _Banner(
                        icon: Icons.warning_amber_rounded,
                        text: 'No se encontraron impresoras instaladas. '
                              'Instala el driver y toca Actualizar.',
                        color: AppColors.warning,
                        bg:    AppColors.warningContainer,
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Column(
                          children: _winPrinters.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final p   = entry.value;
                            final isFirst = idx == 0;
                            final isLast  = idx == _winPrinters.length - 1;
                            final sel     = p.name == _winSelected;
                            return _PrinterTile(
                              name:      p.name,
                              subtitle:  p.isDefault ? 'Predeterminada de Windows' : null,
                              selected:  sel,
                              isDefault: p.isDefault,
                              isFirst:   isFirst,
                              isLast:    isLast,
                              onTap: _imprimiendo
                                  ? null
                                  : () => setState(() => _winSelected = p.name),
                            );
                          }).toList(),
                        ),
                      ),

                  // ── Firefox / Safari ─────────────────────────────
                  ] else ...[
                    _Banner(
                      icon: Icons.info_outline_rounded,
                      text: 'Se usará el diálogo de impresión del navegador.',
                      color: AppColors.secondary,
                      bg:    AppColors.mintLight,
                    ),
                  ],

                  const SizedBox(height: 80), // espacio para el botón fijo
                ],
              ),
            ),

            // ── Botón Imprimir (fijo al fondo) ─────────────────
            const Divider(height: 1, color: AppColors.surfaceContainerLow),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _imprimiendo
                        ? null
                        : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      side: const BorderSide(color: AppColors.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancelar',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: canPrint && !_imprimiendo ? _imprimir : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      disabledBackgroundColor:
                          AppColors.secondary.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _imprimiendo
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(
                      _imprimiendo ? 'Imprimiendo…' : 'Imprimir',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]),
            ),

          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets internos ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.5)),
  );
}

class _LoadingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: CircularProgressIndicator(
          color: AppColors.secondary, strokeWidth: 2),
    ),
  );
}

class _PrinterTile extends StatelessWidget {
  final String  name;
  final String? subtitle;
  final bool    selected;
  final bool    isDefault;
  final bool    isFirst;
  final bool    isLast;
  final VoidCallback?  onTap;
  final Widget?        trailing;

  const _PrinterTile({
    required this.name,
    required this.selected,
    required this.isDefault,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isFirst = true,
    this.isLast  = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mintLight : Colors.white,
      borderRadius: BorderRadius.vertical(
        top:    isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast  ? const Radius.circular(12) : Radius.zero,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top:    isFirst ? const Radius.circular(12) : Radius.zero,
          bottom: isLast  ? const Radius.circular(12) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            // Icono
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.secondary.withValues(alpha: 0.12)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDefault ? Icons.print_rounded : Icons.print_outlined,
                size: 18,
                color: selected ? AppColors.secondary : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.secondary
                              : AppColors.onSurface),
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),

            // Checkmark / trailing
            if (trailing != null)
              trailing!
            else if (selected)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: AppColors.secondary)
            else
              const Icon(Icons.radio_button_unchecked,
                  size: 20, color: AppColors.outlineVariant),

            // Separador inferior (no en el último)
            if (!isLast)
              const SizedBox(width: 0),
          ]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color    color;
  final Color    bg;

  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: GoogleFonts.inter(fontSize: 12, color: color))),
    ]),
  );
}
