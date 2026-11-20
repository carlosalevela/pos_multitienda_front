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
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'Content-Type': 'application/json',
          'Accept':        'application/json',
          // Cloudflare bloquea user-agents no-browser (Dart/X.X); usamos uno de Chrome
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        // ── Inyectar token ──────────────────────────────
        onRequest: (options, handler) async {
          try {
            final prefs = await SharedPreferences.getInstance()
                .timeout(const Duration(seconds: 3));
            final token = prefs.getString('access_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {
            // Si SharedPreferences falla o tarda, omitir el token
            // pero SIEMPRE continuar — sin esto el request queda colgado
          }
          return handler.next(options);
        },

        // ── Retry automático para errores de red ────────
        onError: (error, handler) async {
          final isNetworkError =
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout  ||
              error.type == DioExceptionType.sendTimeout     ||
              error.type == DioExceptionType.connectionError;

          final retries = error.requestOptions.extra['_retries'] as int? ?? 0;

          // No reintentar en endpoints de autenticación — falla rápido para dar feedback inmediato
          final isAuthEndpoint = error.requestOptions.path.contains('/auth/');

          if (isNetworkError && retries < 3 && !isAuthEndpoint) {
            // Espera exponencial: 1s, 2s, 4s
            await Future.delayed(Duration(seconds: 1 << retries));
            final opts = error.requestOptions;
            opts.extra['_retries'] = retries + 1;
            // Re-inyectar token antes de reintentar
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('access_token');
            if (token != null) opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }

          // ── Refresh automático al 401 ───────────────
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final prefs = await SharedPreferences.getInstance();
              final newToken = prefs.getString('access_token');
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {
                await _clearSession();
                return handler.next(error);
              }
            } else {
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