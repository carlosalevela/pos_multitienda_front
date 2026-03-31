import '../core/api_client.dart';
import '../models/producto.dart';

class ProductoService {

  Future<List<Producto>> buscarProductos(String query, int tiendaId) async {
    try {
      final response = await ApiClient.instance.get(
        '/productos/',
        queryParameters: {
          'q': query,
          if (tiendaId != 0) 'tienda_id': tiendaId, // ← admin no filtra por tienda
        },
      );

      // ✅ Fix: el backend devuelve array directo, no {results: [...]}
      final List data = response.data is List
          ? response.data
          : response.data['results'] ?? [];

      return data.map((e) => Producto.fromJson(e)).toList();
    } catch (e) {
      print('ERROR buscarProductos: $e');
      return [];
    }
  }
}