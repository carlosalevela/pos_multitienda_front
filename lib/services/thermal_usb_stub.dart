// lib/services/thermal_usb_stub.dart
// Stub para plataformas no-web (Windows, macOS, Linux, Android, iOS).
// WebUSB es solo-navegador; en desktop la impresión va por el paquete Printing.

class ThermalDevice {
  final String name;
  final String manufacturer;
  final int    vendorId;
  final int    productId;

  ThermalDevice._({
    required this.name,
    required this.manufacturer,
    required this.vendorId,
    required this.productId,
  });

  String get displayName => name.isNotEmpty
      ? name
      : '${vendorId.toRadixString(16).padLeft(4, '0')}:'
        '${productId.toRadixString(16).padLeft(4, '0')}';
}

bool get isWebUsbSupported                                    => false;
Future<List<ThermalDevice>> getGrantedDevices()        async => [];
Future<ThermalDevice?>      requestDevice()            async => null;
Future<ThermalDevice?>      getAutoDevice()            async => null;
Future<String?>             getSavedName()             async => null;
Future<ThermalDevice?>      getOrRequestDevice()       async => null;
Future<void>                clearSaved()               async {}
Future<void> printBytes(ThermalDevice dev, List<int> bytes) async {}
Future<void> kickDrawer(ThermalDevice dev)             async {}
