import '../core/api_client.dart';

class VentaService {

  Future<Map<String, dynamic>> crearVenta({
    required int    tiendaId,
    required String metodoPago,
    required double montoRecibido,
    int?            clienteId,
    required List<Map<String, dynamic>> detalles,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/ventas/',
        data: {
          'tienda':          tiendaId,
          'metodo_pago':     metodoPago,
          'monto_recibido':  montoRecibido.toString(),
          if (clienteId != null) 'cliente': clienteId,
          'detalles': detalles,
        },
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al registrar la venta'};
    }
  }


  Future<List<Map<String, dynamic>>> listarVentas({
    int? tiendaId,
    String? fecha,   // '2026-03-27'
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '/ventas/lista/',
        queryParameters: {
          if (tiendaId != null) 'tienda_id': tiendaId.toString(),
          if (fecha != null && fecha.isNotEmpty) 'fecha': fecha,
        },
      );
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

    Future<Map<String, dynamic>?> obtenerVenta(int id) async {
    try {
      final response = await ApiClient.instance.get('/ventas/$id/');
      
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      print('Error obteniendo venta $id: $e');
      return null;
    }
  }
}