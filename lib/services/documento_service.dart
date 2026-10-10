// lib/services/documento_service.dart
//
// 1. Guarda PDFs localmente en Documents/POS_{tienda}/{tipo}/{año}/{mes}/
// 2. Los sube al backend en segundo plano para que admin/superadmin los vea

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api_client.dart';

enum TipoDocumento { venta, separado, abono, cierre, devolucion, reporte, inventario, compra, recepcion }

class DocumentoService {
  DocumentoService._();
  static final DocumentoService instance = DocumentoService._();

  String _tiendaNombre = 'POS';
  int?   _tiendaId;

  /// Llamar al hacer login o al cargar la tienda activa.
  void setTienda(String nombre, {int? id}) {
    _tiendaNombre = _sanitizar(nombre.isEmpty ? 'POS' : nombre);
    _tiendaId     = id;
    _crearEstructura();
  }

  Future<void> _crearEstructura() async {
    try {
      for (final tipo in TipoDocumento.values) {
        final dir = await _carpeta(tipo);
        if (!dir.existsSync()) await dir.create(recursive: true);
      }
    } catch (_) {}
  }

  // ── Guardar (local + subida al backend) ───────────────────

  Future<File> guardarVenta({required List<int> bytes, required String numeroFactura}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.venta, nombre: 'venta_$numeroFactura');

  Future<File> guardarSeparado({required List<int> bytes, required String numeroSeparado}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.separado, nombre: 'separado_$numeroSeparado');

  Future<File> guardarAbono({required List<int> bytes, required String referencia}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.abono, nombre: 'abono_$referencia');

  Future<File> guardarCierre({required List<int> bytes, required String referencia}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.cierre, nombre: 'cierre_$referencia');

  Future<File> guardarDevolucion({required List<int> bytes, required String referencia}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.devolucion, nombre: 'devolucion_$referencia');

  Future<File> guardarReporte({required List<int> bytes, required String nombre}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.reporte, nombre: 'reporte_$nombre');

  Future<File> guardarInventario({required List<int> bytes, required String nombre}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.inventario, nombre: 'inventario_$nombre');

  Future<File> guardarOrdenCompra({required List<int> bytes, required String numeroOrden}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.compra, nombre: 'OC_$numeroOrden');

  Future<File> guardarRecepcion({required List<int> bytes, required String numeroOrden}) =>
      _guardar(bytes: bytes, tipo: TipoDocumento.recepcion, nombre: 'recepcion_$numeroOrden');

  // ── Listar local ───────────────────────────────────────────

  Future<List<File>> listar(TipoDocumento tipo) async {
    try {
      final dir = await _carpeta(tipo);
      if (!dir.existsSync()) return [];
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.pdf'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (_) {
      return [];
    }
  }

  Future<String> rutaRaiz() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}\\POS_$_tiendaNombre';
  }

  // ── Internos ────────────────────────────────────────────────

  Future<File> _guardar({
    required List<int>     bytes,
    required TipoDocumento tipo,
    required String        nombre,
  }) async {
    // 1. Guardar local
    final dir      = await _carpetaMes(tipo, DateTime.now());
    final fileName = '${_sanitizar(nombre)}.pdf';
    final file     = File('${dir.path}\\$fileName');
    await file.writeAsBytes(bytes, flush: true);

    // 2. Subir al backend en segundo plano (no bloquea UI)
    _subirAlBackend(bytes: bytes, tipo: tipo, nombre: fileName);

    return file;
  }

  Future<void> _subirAlBackend({
    required List<int>     bytes,
    required TipoDocumento tipo,
    required String        nombre,
  }) async {
    if (_tiendaId == null) return;
    try {
      final formData = FormData.fromMap({
        'tienda_id': _tiendaId,
        'tipo':      _tipoStr(tipo),
        'nombre':    nombre,
        'archivo':   MultipartFile.fromBytes(bytes, filename: nombre),
      });
      await ApiClient.instance.post('/documentos/subir/', data: formData);
    } catch (_) {
      // Error silencioso — el PDF local ya está guardado
    }
  }

  Future<Directory> _carpetaMes(TipoDocumento tipo, DateTime fecha) async {
    final base = await _carpeta(tipo);
    final mes  = Directory('${base.path}\\${fecha.year}\\${fecha.month.toString().padLeft(2, '0')}');
    await mes.create(recursive: true);
    return mes;
  }

  Future<Directory> _carpeta(TipoDocumento tipo) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}\\POS_$_tiendaNombre\\${_nombreCarpeta(tipo)}');
  }

  String _nombreCarpeta(TipoDocumento tipo) => switch (tipo) {
    TipoDocumento.venta      => 'ventas',
    TipoDocumento.separado   => 'separados',
    TipoDocumento.abono      => 'abonos',
    TipoDocumento.cierre     => 'cierres',
    TipoDocumento.devolucion => 'devoluciones',
    TipoDocumento.reporte    => 'reportes',
    TipoDocumento.inventario => 'inventarios',
    TipoDocumento.compra     => 'compras',
    TipoDocumento.recepcion  => 'recepciones',
  };

  String _tipoStr(TipoDocumento tipo) => switch (tipo) {
    TipoDocumento.venta      => 'venta',
    TipoDocumento.separado   => 'separado',
    TipoDocumento.abono      => 'abono',
    TipoDocumento.cierre     => 'cierre',
    TipoDocumento.devolucion => 'devolucion',
    TipoDocumento.reporte    => 'reporte',
    TipoDocumento.inventario => 'inventario',
    TipoDocumento.compra     => 'compra',
    TipoDocumento.recepcion  => 'recepcion',
  };

  String _sanitizar(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
}
