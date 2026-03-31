import '../core/api_client.dart';
import '../models/producto.dart';

class InventarioService {

    Future<List<Producto>> getProductos({String? q, int? tiendaId}) async {
  try {
    final response = await ApiClient.instance.get(
      '/productos/',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (tiendaId != null) 'tienda_id': tiendaId.toString(),
      },
    );
    final List data = response.data is List
        ? response.data
        : response.data['results'] ?? [];
    return data.map((e) => Producto.fromJson(e)).toList();
  } catch (e) {
    return [];
  }
}

  Future<Map<String, dynamic>> crearProducto(
      Map<String, dynamic> data) async {
    try {
      final response =
          await ApiClient.instance.post('/productos/', data: data);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al crear producto'};
    }
  }

  Future<Map<String, dynamic>> editarProducto(
      int id, Map<String, dynamic> data) async {
    try {
      final response =
          await ApiClient.instance.patch('/productos/$id/', data: data);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': 'Error al editar producto'};
    }
  }

  Future<bool> eliminarProducto(int id) async {
    try {
      await ApiClient.instance.delete('/productos/$id/');
      return true;
    } catch (_) {
      return false;
    }
  }
}