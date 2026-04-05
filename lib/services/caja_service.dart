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

  // ✅ Ahora parsea efectivo y transferencia del breakdown
  Future<AbonosCierre> getAbonosSesion(DateTime fechaApertura) async {
    try {
      final fecha = fechaApertura.toLocal().toString().substring(0, 10);
      final resp  = await ApiClient.instance.get(
        '/clientes/abonos/',
        queryParameters: {'fecha': fecha},
      );

      final data   = resp.data as Map<String, dynamic>;
      final lista  = (data['abonos'] as List? ?? []);

      // Suma por método de pago iterando la lista
      double totalEfectivo      = 0;
      double totalTransferencia = 0;
      double totalGeneral       = 0;

      for (final a in lista) {
        final monto  = double.tryParse(a['monto']?.toString() ?? '0') ?? 0.0;
        final metodo = a['metodo_pago']?.toString() ?? '';
        totalGeneral += monto;
        if (metodo == 'efectivo')      totalEfectivo      += monto;
        if (metodo == 'transferencia') totalTransferencia += monto;
      }

      // Si el backend ya retorna el total directamente úsalo, si no usa la suma
      final totalBackend = double.tryParse(data['total']?.toString() ?? '0') ?? 0.0;

      return AbonosCierre(
        total:         totalBackend > 0 ? totalBackend : totalGeneral,
        efectivo:      totalEfectivo,
        transferencia: totalTransferencia,
        cantidad:      lista.length,
      );
    } catch (_) {
      return AbonosCierre.vacio();
    }
  }

  Future<Map<String, dynamic>> cerrarCaja(
    int sesionId, {
    required double montoFinalReal,
    String observaciones = '',
  }) async {
    try {
      final r = await ApiClient.instance.post(
        '/caja/$sesionId/cerrar/',
        data: {
          'monto_final_real': montoFinalReal.toString(),
          'observaciones':    observaciones,
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