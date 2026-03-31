import 'package:flutter/material.dart';
import '../services/venta_service.dart';

class ReportesProvider extends ChangeNotifier {
  final VentaService _service = VentaService();

  List<Map<String, dynamic>> _ventas = [];
  bool   _cargando   = false;
  String _errorMsg   = '';

  List<Map<String, dynamic>> get ventas   => _ventas;
  bool   get cargando   => _cargando;
  String get errorMsg   => _errorMsg;

  double get totalDia => _ventas.fold(
      0, (sum, v) => sum + (double.tryParse(v['total'].toString()) ?? 0));

  Future<void> cargarVentas({int? tiendaId, String? fecha}) async {
    _cargando = true;
    _errorMsg = '';
    notifyListeners();

    _ventas = await _service.listarVentas(tiendaId: tiendaId, fecha: fecha);

    _cargando = false;
    notifyListeners();
  }
}