// lib/services/compra_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class CompraService {

  // ── Helper extractor de errores ────────────────────────
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      if (data.containsKey('error'))  return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
      final msgs = data.values
          .expand((v) => v is List ? v : [v])
          .join(', ');
      return msgs.isNotEmpty ? msgs : fallback;
    }
    return fallback;
  }

  // ── Lista con filtros ──────────────────────────────────
  Future<List<Map<String, dynamic>>> listar({
    int?    tiendaId,
    String? estado,
    String? fechaIni,
    String? fechaFin,
  }) async {
    try {
      final res = await ApiClient.instance.get(
        '/proveedores/compras/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          if (estado   != null) 'estado':    estado,
          if (fechaIni != null) 'fecha_ini': fechaIni,
          if (fechaFin != null) 'fecha_fin': fechaFin,
        },
      );
      final List data = res.data is List
          ? res.data
          : res.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      debugPrint('❌ listarCompras error: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ listarCompras error: $e');
      return [];
    }
  }

  // ── Detalle ────────────────────────────────────────────
  Future<Map<String, dynamic>?> obtener(int id) async {
    try {
      final res = await ApiClient.instance.get(
          '/proveedores/compras/$id/');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      debugPrint('❌ obtenerCompra error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ obtenerCompra error: $e');
      return null;
    }
  }

  // ── Crear orden de compra ──────────────────────────────
  Future<Map<String, dynamic>> crear(Map<String, dynamic> data) async {
    try {
      data.remove('empresa');
      final res = await ApiClient.instance.post(
          '/proveedores/compras/', data: data);
      return {'success': true, 'data': res.data};
    } on DioException catch (e) {
      return {'success': false,
              'error': _extractError(e, 'Error al crear la orden de compra')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Recibir → actualiza inventario + precios ──────────
  // ✅ precios:        {detalleId: precioVenta}
  // ✅ preciosMayoreo: {detalleId: precioMayoreo} (opcional)
  Future<Map<String, dynamic>> recibir(
    int id, {
    required Map<String, double> precios,
    Map<String, double>?         preciosMayoreo,
    /// Cómo se pagó (solo compras de contado): metodo_pago, cuenta_bancaria,
    /// fecha y de_caja.
    Map<String, dynamic>?        pago,
  }) async {
    try {
      final body = <String, dynamic>{
        'precios': precios,
        if (preciosMayoreo != null && preciosMayoreo.isNotEmpty)
          'precios_mayoreo': preciosMayoreo,
        ...?pago,
      };
      final res = await ApiClient.instance.post(
        '/proveedores/compras/$id/recibir/',
        data: body,
      );
      return {'success': true, 'data': res.data};
    } on DioException catch (e) {
      return {'success': false,
              'error': _extractError(e, 'Error al recibir la compra')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Cancelar (solo admin) ──────────────────────────────
  Future<Map<String, dynamic>> cancelar(int id) async {
    try {
      final res = await ApiClient.instance.post(
          '/proveedores/compras/$id/cancelar/');
      return {'success': true, 'data': res.data};
    } on DioException catch (e) {
      return {'success': false,
              'error': _extractError(e, 'Error al cancelar la compra')};
    } catch (e) {
      return {'success': false, 'error': 'Error inesperado'};
    }
  }

  // ── Parsear factura PDF de proveedor ───────────────────
  /// Sube el PDF al backend y retorna la lista de productos parseados.
  /// Retorna [] si falla.
  Future<List<Map<String, dynamic>>> parsearFactura(File archivo) async {
    try {
      final formData = FormData.fromMap({
        'archivo': await MultipartFile.fromFile(
          archivo.path,
          filename: archivo.path.split(Platform.pathSeparator).last,
        ),
      });
      final res = await ApiClient.instance.post(
        '/proveedores/compras/parsear-factura/',
        data: formData,
      );
      final lista = res.data['productos'];
      if (lista is List) {
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ parsearFactura error: $e');
      return [];
    }
  }

  /// Registra el pago de una compra a crédito (crea el gasto de Proveedor).
  Future<String?> pagar(int id, Map<String, dynamic> pago) async {
    try {
      await ApiClient.instance.patch('/proveedores/compras/$id/marcar-pagada/', data: pago);
      return null;
    } on DioException catch (e) {
      return _extractError(e, 'No se pudo registrar el pago');
    } catch (_) {
      return 'No se pudo registrar el pago';
    }
  }

  /// Compras a crédito por pagar (y las que aún no llegan).
  Future<Map<String, dynamic>> cuentasPorPagar({int? tiendaId}) async {
    final r = await ApiClient.instance.get('/proveedores/cuentas-pagar/',
        queryParameters: {if (tiendaId != null) 'tienda_id': tiendaId});
    return Map<String, dynamic>.from(r.data as Map);
  }
}
