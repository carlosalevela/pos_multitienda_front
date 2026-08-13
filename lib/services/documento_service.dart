// lib/services/documento_service.dart
//
// Guarda PDFs localmente en Documents/POS_{tienda}/{tipo}/{año}/{mes}/
// Las carpetas se crean automáticamente en el primer uso.

import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum TipoDocumento { venta, separado, abono, cierre, devolucion, reporte, inventario, compra, recepcion }

class DocumentoService {
  DocumentoService._();
  static final DocumentoService instance = DocumentoService._();

  String _tiendaNombre = 'POS';

  /// Llamar al hacer login o al cargar la tienda activa.
  /// Crea la estructura de carpetas inmediatamente si no existe.
  void setTienda(String nombre) {
    _tiendaNombre = _sanitizar(nombre.isEmpty ? 'POS' : nombre);
    _crearEstructura();
  }

  Future<void> _crearEstructura() async {
    try {
      for (final tipo in TipoDocumento.values) {
        final dir = await _carpeta(tipo);
        if (!dir.existsSync()) {
          await dir.create(recursive: true);
        }
      }
    } catch (_) {}
  }

  // ── Guardar ────────────────────────────────────────────

  Future<File> guardarVenta({
    required List<int> bytes,
    required String    numeroFactura,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.venta,
    nombre: 'venta_$numeroFactura',
  );

  Future<File> guardarSeparado({
    required List<int> bytes,
    required String    numeroSeparado,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.separado,
    nombre: 'separado_$numeroSeparado',
  );

  Future<File> guardarAbono({
    required List<int> bytes,
    required String    referencia,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.abono,
    nombre: 'abono_$referencia',
  );

  Future<File> guardarCierre({
    required List<int> bytes,
    required String    referencia,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.cierre,
    nombre: 'cierre_$referencia',
  );

  Future<File> guardarDevolucion({
    required List<int> bytes,
    required String    referencia,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.devolucion,
    nombre: 'devolucion_$referencia',
  );

  Future<File> guardarReporte({
    required List<int> bytes,
    required String    nombre,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.reporte,
    nombre: 'reporte_$nombre',
  );

  Future<File> guardarInventario({
    required List<int> bytes,
    required String    nombre,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.inventario,
    nombre: 'inventario_$nombre',
  );

  Future<File> guardarOrdenCompra({
    required List<int> bytes,
    required String    numeroOrden,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.compra,
    nombre: 'OC_$numeroOrden',
  );

  Future<File> guardarRecepcion({
    required List<int> bytes,
    required String    numeroOrden,
  }) => _guardar(
    bytes:  bytes,
    tipo:   TipoDocumento.recepcion,
    nombre: 'recepcion_$numeroOrden',
  );

  // ── Listar documentos de un tipo ───────────────────────

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

  // ── Ruta raíz visible (para mostrar al usuario) ────────

  Future<String> rutaRaiz() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}\\POS_$_tiendaNombre';
  }

  // ── Internos ────────────────────────────────────────────

  Future<File> _guardar({
    required List<int>       bytes,
    required TipoDocumento   tipo,
    required String          nombre,
  }) async {
    final dir      = await _carpetaMes(tipo, DateTime.now());
    // Nombre fijo por ID de documento: si ya existe lo sobreescribe
    // (evita duplicados al reimprimir la misma factura/devolución/separado).
    // Para abonos el llamador ya incluye un timestamp en el nombre.
    final fileName = '${_sanitizar(nombre)}.pdf';
    final file     = File('${dir.path}\\$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Directory> _carpetaMes(TipoDocumento tipo, DateTime fecha) async {
    final base  = await _carpeta(tipo);
    final mes   = Directory(
      '${base.path}\\${fecha.year}\\${fecha.month.toString().padLeft(2, '0')}',
    );
    await mes.create(recursive: true);
    return mes;
  }

  Future<Directory> _carpeta(TipoDocumento tipo) async {
    final docs   = await getApplicationDocumentsDirectory();
    final nombre = _nombreCarpeta(tipo);
    return Directory('${docs.path}\\POS_$_tiendaNombre\\$nombre');
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

  /// Reemplaza caracteres inválidos en nombres de archivo/carpeta.
  String _sanitizar(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
}
