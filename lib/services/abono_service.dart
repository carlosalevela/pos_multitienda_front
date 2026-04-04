import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class AbonoService {
  Future<List<Map<String, dynamic>>> listarAbonos({
    int?    tiendaId,
    String? fecha,
  }) async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final token  = prefs.getString('access_token') ?? '';

      final params = <String, String>{};
      if (fecha    != null) params['fecha']     = fecha;
      if (tiendaId != null) params['tienda_id'] = '$tiendaId';

      final uri = Uri.parse(
        '${Constants.baseUrl}/clientes/abonos/',
      ).replace(queryParameters: params);

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(data['abonos'] ?? []);
      }
    } catch (e) {
      debugPrint('AbonoService error: $e');
    }
    return [];
  }
}