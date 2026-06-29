import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';

class NotificacionesProvider extends ChangeNotifier {
  int                        totalAlertas = 0;
  List<Map<String, dynamic>> vencidos     = [];
  List<Map<String, dynamic>> porVencer    = [];
  bool                       cargando     = false;
  String?                    error;

  Timer? _timer;

  void iniciarPolling() {
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _cargar());
  }

  void detenerPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> recargar() => _cargar();

  Future<void> _cargar() async {
    cargando = true;
    error    = null;
    notifyListeners();

    try {
      final res = await ApiClient.instance.get('/clientes/separados/alertas/');
      final data = res.data as Map<String, dynamic>;

      totalAlertas = (data['total_alertas'] as num?)?.toInt() ?? 0;
      vencidos     = List<Map<String, dynamic>>.from(data['vencidos']   ?? []);
      porVencer    = List<Map<String, dynamic>>.from(data['por_vencer'] ?? []);
    } catch (e) {
      error = e.toString();
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    detenerPolling();
    super.dispose();
  }
}
