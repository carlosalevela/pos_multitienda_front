// lib/services/thermal_usb_web.dart
// WebUSB bindings — solo web (Chrome/Edge). Importado condicionalmente.
// No importar directamente; usar thermal_printer_service.dart.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── WebUSB JS bindings ───────────────────────────────────────

@JS('navigator.usb')
external JSAny? get _usbRaw;

extension type _USB._(JSObject _) implements JSObject {
  external JSPromise<JSArray<_UsbDev>> getDevices();
  external JSPromise<_UsbDev> requestDevice(JSObject options);
}

extension type _UsbDev._(JSObject _) implements JSObject {
  external String  get productName;
  external String? get manufacturerName;
  external int     get vendorId;
  external int     get productId;
  external JSPromise<JSAny?> open();
  external JSPromise<JSAny?> close();
  external JSPromise<JSAny?> selectConfiguration(int v);
  external JSPromise<JSAny?> claimInterface(int n);
  external JSPromise<JSAny?> releaseInterface(int n);
  external JSPromise<JSObject> transferOut(int ep, JSUint8Array data);
}

// ─── Modelo ───────────────────────────────────────────────────

class ThermalDevice {
  final String  name;
  final String  manufacturer;
  final int     vendorId;
  final int     productId;
  // ignore: library_private_types_in_public_api
  final _UsbDev _raw;

  ThermalDevice._({
    required this.name,
    required this.manufacturer,
    required this.vendorId,
    required this.productId,
    required _UsbDev raw,
  }) : _raw = raw;

  String get displayName => name.isNotEmpty
      ? name
      : '${vendorId.toRadixString(16).padLeft(4, '0')}:'
        '${productId.toRadixString(16).padLeft(4, '0')}';
}

// ─── Prefs keys ───────────────────────────────────────────────

const String _kVid  = 'thermal_vid';
const String _kPid  = 'thermal_pid';
const String _kName = 'thermal_name';

// ─── Helpers internos ─────────────────────────────────────────

bool get isWebUsbSupported {
  try { return _usbRaw != null; } catch (_) { return false; }
}

_USB? get _usb {
  final raw = _usbRaw;
  if (raw == null) return null;
  return _USB._(raw as JSObject);
}

ThermalDevice _fromRaw(_UsbDev d) => ThermalDevice._(
  name:         d.productName,
  manufacturer: d.manufacturerName ?? '',
  vendorId:     d.vendorId,
  productId:    d.productId,
  raw:          d,
);

// ─── API pública ──────────────────────────────────────────────

Future<List<ThermalDevice>> getGrantedDevices() async {
  final usb = _usb;
  if (usb == null) return [];
  try {
    final arr = await usb.getDevices().toDart;
    return arr.toDart.map(_fromRaw).toList();
  } catch (_) {
    return [];
  }
}

Future<ThermalDevice?> requestDevice() async {
  final usb = _usb;
  if (usb == null) return null;
  try {
    final filter = JSObject();
    filter['classCode'] = 7.toJS;
    final opts = JSObject();
    opts['filters'] = [filter].toJS;
    final raw = await usb.requestDevice(opts).toDart;
    final dev = _fromRaw(raw);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kVid, dev.vendorId);
    await prefs.setInt(_kPid, dev.productId);
    await prefs.setString(_kName, dev.displayName);
    return dev;
  } catch (_) {
    return null;
  }
}

Future<ThermalDevice?> getAutoDevice() async {
  final prefs    = await SharedPreferences.getInstance();
  final savedVid = prefs.getInt(_kVid);
  final savedPid = prefs.getInt(_kPid);
  if (savedVid == null || savedPid == null) return null;
  final devices = await getGrantedDevices();
  try {
    return devices.firstWhere(
      (d) => d.vendorId == savedVid && d.productId == savedPid,
    );
  } catch (_) {
    return devices.isNotEmpty ? devices.first : null;
  }
}

Future<String?> getSavedName() async =>
    (await SharedPreferences.getInstance()).getString(_kName);

Future<ThermalDevice?> getOrRequestDevice() async {
  final dev = await getAutoDevice();
  if (dev != null) return dev;
  final prefs    = await SharedPreferences.getInstance();
  final savedVid = prefs.getInt(_kVid);
  if (savedVid == null) return null;
  return requestDevice();
}

Future<void> clearSaved() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kVid);
  await prefs.remove(_kPid);
  await prefs.remove(_kName);
}

Future<void> printBytes(ThermalDevice dev, List<int> bytes) async {
  final d = dev._raw;
  await d.open().toDart;
  int iface = 0;
  try {
    await d.selectConfiguration(1).toDart;
    try {
      await d.claimInterface(0).toDart;
    } catch (_) {
      await d.claimInterface(1).toDart;
      iface = 1;
    }
    await d.transferOut(1, Uint8List.fromList(bytes).toJS).toDart;
  } finally {
    try { await d.releaseInterface(iface).toDart; } catch (_) {}
    try { await d.close().toDart; } catch (_) {}
  }
}

Future<void> kickDrawer(ThermalDevice dev) async {
  final profile = await CapabilityProfile.load();
  final gen     = Generator(PaperSize.mm80, profile);
  await printBytes(dev, gen.drawer(pin: PosDrawer.pin2));
}
