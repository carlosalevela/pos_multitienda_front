import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  // ✅ instancia única — se configura UNA sola vez
  static final Dio _dio = _buildDio();

  static Dio get instance => _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl:        Constants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers:        {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        // ── Inyectar token ──────────────────────────────
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        // ── Refresh automático al 401 ───────────────────
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // ✅ reintenta el request original con el nuevo token
              final prefs = await SharedPreferences.getInstance();
              final newToken = prefs.getString('access_token');
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {
                // si falla el reintento, forzar logout
                await _clearSession();
                return handler.next(error);
              }
            } else {
              // refresh falló — limpiar sesión
              await _clearSession();
            }
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  // ── Renovar access_token con el refresh_token ───────────
  static Future<bool> _tryRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) return false;

    try {
      // ✅ usa Dio aparte sin interceptores para evitar loop infinito
      final tempDio = Dio(BaseOptions(baseUrl: Constants.baseUrl));
      final response = await tempDio.post(
        '/api/token/refresh/',
        data: {'refresh': refreshToken},
      );
      final newAccess = response.data['access'] as String?;
      if (newAccess == null) return false;

      await prefs.setString('access_token', newAccess);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Limpiar sesión al expirar ────────────────────────────
  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('empresa_id');       // ✅ limpiar empresa también
    await prefs.remove('empresa_nombre');
    await prefs.remove('usuario');
  }
}