import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/sesion_caja.dart';
import '../models/resumen_cierre.dart';

class CajaService {

  Future<SesionCaja?> getSesionActiva(int tiendaId) async {
    if (tiendaId <= 0) return null;
    try {
      final r = await ApiClient.instance.get('/caja/activa/$tiendaId/');
      return SesionCaja.fromJson(r.data);
    } catch (_) { return null; }
  }

  Future<ResumenCierre?> getResumenCierre(int sesionId) async {
    try {
      final r = await ApiClient.instance.get('/caja/$sesionId/resumen-cierre/');
      return ResumenCierre.fromJson(r.data);
    } catch (e) {
      print('❌ getResumenCierre error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> abrirCaja({
    required double saldoInicial,
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/caja/abrir/',
        data: {'monto_inicial': saldoInicial},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final data     = e.response?.data as Map<String, dynamic>?;
        final sesionId = data?['sesion_id'];
        if (sesionId != null) {
          return {
            'success':    false,
            'ya_abierta': true,
            'sesion_id':  sesionId,
            'error':      data?['error'] ?? 'La caja ya está abierta',
          };
        }
        return {'success': false, 'error': data?['error'] ?? 'Error al abrir la caja'};
      }
      return {'success': false, 'error': 'Error de conexión'};
    }
  }

  Future<Map<String, dynamic>> cerrarCaja(
    int sesionId, {
    required double montoFinalReal,
    String observaciones = '',               // ← nuevo
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/caja/$sesionId/cerrar/',
        data: {
          'monto_final_real': montoFinalReal.toString(),
          'observaciones':    observaciones,  // ← nuevo
        },
      );
      return {'success': true, 'data': r.data};
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error'] ?? 'Error al cerrar la caja';
      return {'success': false, 'error': msg};
    } catch (_) {
      return {'success': false, 'error': 'Error al cerrar la caja'};
    }
  }
}