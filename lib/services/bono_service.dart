import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/bono.dart';

class BonoService {
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is Map) {
      if (data.containsKey('error'))  return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return fallback;
  }

  /// Crea un bono nuevo (al venderlo).
  Future<Map<String, dynamic>> venderBono({
    required int    empresaId,
    required int    tiendaId,
    required double valor,
    String          metodoPago    = 'efectivo',
    double?         montoRecibido,
    int?            sesionCajaId,
    int?            clienteId,
  }) async {
    try {
      final body = <String, dynamic>{
        'empresa_id':    empresaId,
        'tienda_id':     tiendaId,
        'valor':         valor,
        'metodo_pago':   metodoPago,
      };
      if (montoRecibido != null) body['monto_recibido'] = montoRecibido;
      if (sesionCajaId  != null) body['sesion_caja_id'] = sesionCajaId;
      if (clienteId     != null) body['cliente_id']     = clienteId;
      final r = await ApiClient.instance.post('/bonos/vender/', data: body);
      final raw = r.data as Map<String, dynamic>;
      return {
        'success':       true,
        'data':          Bono.fromJson(raw),
        'vuelta':        (raw['vuelta'] as num?)?.toDouble() ?? 0.0,
        'numeroFactura': (raw['numero_factura'] as String?) ?? '',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al crear bono')};
    }
  }

  /// Valida un código de bono y devuelve su información.
  Future<Map<String, dynamic>> validarBono(String codigo) async {
    try {
      final r = await ApiClient.instance.get(
        '/bonos/validar/',
        queryParameters: {'codigo': codigo.trim().toUpperCase()},
      );
      return {'success': true, 'data': Bono.fromJson(r.data as Map<String, dynamic>)};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'success': false, 'error': 'Código de bono no encontrado'};
      }
      return {'success': false, 'error': _extractError(e, 'Error al validar bono')};
    }
  }

  /// Redime (descuenta) un monto del bono y lo asocia a una venta.
  Future<Map<String, dynamic>> redimirBono({
    required String codigo,
    required double monto,
    required int    ventaId,
    required int    tiendaId,
  }) async {
    try {
      final r = await ApiClient.instance.post('/bonos/redimir/', data: {
        'codigo':    codigo.trim().toUpperCase(),
        'monto':     monto,
        'venta_id':  ventaId,
        'tienda_id': tiendaId,
      });
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al redimir bono')};
    }
  }

  /// Lista los bonos de una empresa (con filtros opcionales).
  Future<Map<String, dynamic>> listarBonos({
    int?    empresaId,
    int?    tiendaId,
    String? estado,
  }) async {
    try {
      final r = await ApiClient.instance.get(
        '/bonos/',
        queryParameters: {
          'empresa_id': empresaId?.toString(),
          'tienda_id':  tiendaId?.toString(),
          'estado':     estado,
        }..removeWhere((_, v) => v == null),
      );
      final items = (r.data as List).map((e) => Bono.fromJson(e as Map<String, dynamic>)).toList();
      return {'success': true, 'data': items};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al listar bonos')};
    }
  }

  /// Obtiene el detalle de un bono por su código.
  Future<Map<String, dynamic>> detalleBono(String codigo) async {
    try {
      final r = await ApiClient.instance.get('/bonos/${Uri.encodeComponent(codigo)}/');
      return {'success': true, 'data': Bono.fromJson(r.data as Map<String, dynamic>)};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al obtener bono')};
    }
  }

  /// Cancela un bono (solo admin/superadmin). Pone saldo=0 y estado='cancelado'.
  Future<Map<String, dynamic>> cancelarBono(String codigo) async {
    try {
      final r = await ApiClient.instance.patch(
        '/bonos/${Uri.encodeComponent(codigo.trim().toUpperCase())}/cancelar/',
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      return {'success': false, 'error': _extractError(e, 'Error al cancelar bono')};
    }
  }
}
