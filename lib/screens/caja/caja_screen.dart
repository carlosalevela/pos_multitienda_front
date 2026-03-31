import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/caja_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/resumen_cierre.dart';
import '../../core/constants.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  final _saldoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<CajaProvider>().verificarSesion(auth.tiendaId);
    });
  }

  @override
  void dispose() {
    _saldoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caja = context.watch<CajaProvider>();
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(Constants.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.point_of_sale_rounded,
                  color: Color(Constants.primaryColor)),
            ),
            const SizedBox(width: 12),
            Text('Caja',
              style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E))),
          ]),
          const SizedBox(height: 24),

          if (caja.successMsg.isNotEmpty)
            _banner(caja.successMsg, isError: false, onClose: caja.limpiarMensajes),
          if (caja.errorMsg.isNotEmpty)
            _banner(caja.errorMsg, isError: true, onClose: caja.limpiarMensajes),

          Expanded(
            child: caja.cargando
                ? const Center(child: CircularProgressIndicator())
                : caja.cajaAbierta
                    ? _buildCajaAbierta(caja, auth)
                    : _buildCajaCerrada(caja, auth),
          ),
        ],
      ),
    );
  }

  Widget _buildCajaCerrada(CajaProvider caja, AuthProvider auth) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(50)),
            child: Icon(Icons.lock_outline_rounded,
                size: 48, color: Colors.orange.shade600),
          ),
          const SizedBox(height: 20),
          Text('Caja cerrada',
            style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('Ingresa el saldo inicial para abrir la caja',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 28),
          TextField(
            controller: _saldoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Saldo inicial',
              labelStyle: GoogleFonts.poppins(fontSize: 13),
              prefixText: '\$ ',
              filled: true, fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(Constants.primaryColor), width: 2)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              icon: caja.procesando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.lock_open_rounded),
              label: Text(caja.procesando ? 'Abriendo...' : 'Abrir Caja',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              onPressed: caja.procesando ? null
                  : () => caja.abrirCaja(
                      tiendaId: auth.tiendaId,
                      saldoInicial: double.tryParse(_saldoCtrl.text) ?? 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(Constants.primaryColor),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCajaAbierta(CajaProvider caja, AuthProvider auth) {
    final sesion = caja.sesionActiva!;
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(50)),
            child: Icon(Icons.lock_open_rounded,
                size: 48, color: Colors.green.shade600),
          ),
          const SizedBox(height: 20),
          Text('Caja abierta ✅',
            style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.bold,
              color: Colors.green.shade700)),
          const SizedBox(height: 20),
          _infoRow('Sesión ID', '#${sesion.id}'),
          _infoRow('Estado', sesion.estado.toUpperCase()),
          _infoRow('Saldo inicial', '\$${sesion.saldo_inicial.toStringAsFixed(0)}'),
          _infoRow('Apertura',
              sesion.fecha_apertura.toLocal().toString().substring(0, 16)),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              icon: caja.procesando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.lock_rounded),
              label: Text(caja.procesando ? 'Cargando...' : 'Cerrar Caja',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              onPressed: caja.procesando ? null : () => _abrirCorteCaja(caja),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _abrirCorteCaja(CajaProvider caja) async {
    await caja.cargarResumenCierre();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CorteCajaDialog(),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
      Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
    ]),
  );

  Widget _banner(String msg, {required bool isError, required VoidCallback onClose}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? const Color(Constants.errorColor).withOpacity(0.1)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? const Color(Constants.errorColor).withOpacity(0.3)
              : Colors.green.shade200),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? const Color(Constants.errorColor) : Colors.green.shade700,
            size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
          style: GoogleFonts.poppins(
            color: isError ? const Color(Constants.errorColor) : Colors.green.shade700,
            fontSize: 13))),
        IconButton(icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onClose, color: Colors.grey),
      ]),
    );
}

// ════════════════════════════════════════════════════════
// DIALOG DE CORTE DE CAJA — 3 pasos
// ════════════════════════════════════════════════════════
class _CorteCajaDialog extends StatefulWidget {
  const _CorteCajaDialog();

  @override
  State<_CorteCajaDialog> createState() => _CorteCajaDialogState();
}

class _CorteCajaDialogState extends State<_CorteCajaDialog> {
  int    _paso           = 1;
  double _montoIngresado = 0;
  final  _montoCtrl      = TextEditingController();
  final  _obsCtrl        = TextEditingController();
  final  _fmt            = NumberFormat('#,##0', 'en_US');

  @override
  void dispose() {
    _montoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  String _f(double v) => '\$${_fmt.format(v)}';

  double get _diferencia =>
      _montoIngresado - (context.read<CajaProvider>().resumenCierre?.montoEsperadoCaja ?? 0);

  @override
  Widget build(BuildContext context) {
    final cont    = context.watch<CajaProvider>();
    final resumen = cont.resumenCierre;

    if (resumen == null) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando resumen del turno...'),
          ]),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: const Color(0xFF1A1A2E),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Corte de Caja',
                    style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(resumen.tiendaNombre,
                    style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
                ],
              )),
              Row(children: [1, 2, 3].map((s) => Container(
                margin: const EdgeInsets.only(left: 6),
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _paso >= s ? Colors.orange.shade500 : Colors.white24,
                ),
                child: Center(child: Text('$s',
                  style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              )).toList()),
            ]),
          ),

          // ── Contenido ───────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _paso == 1 ? _buildPaso1(resumen)
                     : _paso == 2 ? _buildPaso2(resumen)
                     : _buildPaso3(resumen),
              ),
            ),
          ),

          // ── Acciones ────────────────────────────────
          _buildAcciones(cont, resumen),
        ]),
      ),
    );
  }

  // ── PASO 1 ───────────────────────────────────────────
  Widget _buildPaso1(ResumenCierre r) => Column(
    key: const ValueKey(1),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1A1A2E),
            child: Text(
              r.empleadoNombre.isNotEmpty ? r.empleadoNombre[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.empleadoNombre,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('Apertura: ${r.fechaApertura.substring(0, 16).replaceAll('T', ' ')}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),

      _tituloSeccion('📊 Ventas del turno', Colors.blue.shade700),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          _fila('Efectivo',      r.ventas.efectivo,      Colors.green.shade700),
          _fila('Tarjeta',       r.ventas.tarjeta,       Colors.blue.shade700),
          _fila('Transferencia', r.ventas.transferencia, Colors.purple.shade700),
          if (r.ventas.mixto > 0) _fila('Mixto', r.ventas.mixto, Colors.orange.shade700),
          const Divider(height: 16),
          _fila('TOTAL VENTAS', r.ventas.total, Colors.black87, bold: true),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight,
            child: Text('${r.ventas.numTransacciones} transacciones',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500))),
        ]),
      ),
      const SizedBox(height: 16),

      _tituloSeccion('📉 Gastos del turno', Colors.red.shade700),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: r.gastos.detalle.isEmpty
            ? Text('Sin gastos en este turno',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500))
            : Column(children: [
                ...r.gastos.detalle.map((g) => _fila(
                  '${g.categoria} (${g.metodoPago})',
                  g.monto, Colors.red.shade600, negativo: true)),
                const Divider(height: 16),
                _fila('TOTAL GASTOS', r.gastos.total, Colors.red.shade700,
                  bold: true, negativo: true),
              ]),
      ),
      const SizedBox(height: 16),

      _tituloSeccion('💵 Cálculo de caja física', Colors.green.shade700),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200, width: 1.5)),
        child: Column(children: [
          _fila('Saldo inicial',     r.montoInicial,      Colors.black87),
          _fila('+ Ventas efectivo', r.ventas.efectivo,   Colors.green.shade700),
          if (r.ventas.mixto > 0)
            _fila('+ Ventas mixto',  r.ventas.mixto,      Colors.green.shade700),
          _fila('- Gastos efectivo', r.gastos.efectivo,   Colors.red.shade600, negativo: true),
          const Divider(height: 16),
          _fila('ESPERADO EN CAJA',  r.montoEsperadoCaja, Colors.green.shade800, bold: true),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.info_outline, size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Expanded(child: Text(
          'Tarjeta ${_f(r.ventas.tarjeta)} y transferencia ${_f(r.ventas.transferencia)} van al banco.',
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500))),
      ]),
    ],
  );

  // ── PASO 2 ───────────────────────────────────────────
  Widget _buildPaso2(ResumenCierre r) => Column(
    key: const ValueKey(2),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade500]),
          borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text('Esperado en caja',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(_f(r.montoEsperadoCaja),
            style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)),
        ]),
      ),
      const SizedBox(height: 24),
      Text('¿Cuánto dinero hay físicamente en el cajón?',
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
      const SizedBox(height: 12),
      TextField(
        controller: _montoCtrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: 'Monto contado',
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          prefixText: '\$ ',
          prefixStyle: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _obsCtrl,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'Observaciones (opcional)',
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          hintText: 'Ej: billetes contados, diferencias encontradas...',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
        ),
      ),
    ],
  );

  // ── PASO 3 ───────────────────────────────────────────
  Widget _buildPaso3(ResumenCierre r) {
    final dif        = _diferencia;
    final esExacto   = dif.abs() < 0.01;
    final esSobrante = dif > 0;

    final color    = esExacto ? Colors.green.shade600
        : esSobrante ? Colors.blue.shade600 : Colors.red.shade600;
    final icono    = esExacto ? '✅' : esSobrante ? '💰' : '⚠️';
    final resultado = esExacto ? 'CUADRE EXACTO'
        : esSobrante ? 'SOBRANTE' : 'FALTANTE';

    final now  = DateTime.now();
    final hora = '${now.day.toString().padLeft(2,'0')}/'
                 '${now.month.toString().padLeft(2,'0')}/'
                 '${now.year}  '
                 '${now.hour.toString().padLeft(2,'0')}:'
                 '${now.minute.toString().padLeft(2,'0')}';

    return Column(
      key: const ValueKey(3),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 2)),
          child: Column(children: [
            Text('$icono $resultado',
              style: GoogleFonts.poppins(
                color: color, fontWeight: FontWeight.bold, fontSize: 22)),
            if (!esExacto) ...[
              const SizedBox(height: 4),
              Text(_f(dif.abs()),
                style: GoogleFonts.poppins(
                  color: color, fontWeight: FontWeight.bold, fontSize: 30)),
            ],
          ]),
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Column(children: [
              _mono('══════════════════════════', Colors.grey.shade400),
              _mono('  CORTE DE CAJA #${r.sesionId}  ', Colors.black87, bold: true),
              _mono('  ${r.tiendaNombre}  ', Colors.black87),
              _mono('  $hora  ', Colors.grey.shade500),
              _mono('══════════════════════════', Colors.grey.shade400),
            ])),
            const SizedBox(height: 12),

            _rSeccion('RESPONSABLE'),
            _rFila('Cajero',   r.empleadoNombre),
            _rFila('Apertura', r.fechaApertura.substring(0, 16).replaceAll('T', ' ')),
            _rFila('Cierre',   hora),
            const SizedBox(height: 10),

            _rSeccion('VENTAS DEL TURNO'),
            _rFila('Efectivo',      _f(r.ventas.efectivo)),
            _rFila('Tarjeta',       _f(r.ventas.tarjeta)),
            _rFila('Transferencia', _f(r.ventas.transferencia)),
            if (r.ventas.mixto > 0) _rFila('Mixto', _f(r.ventas.mixto)),
            _rDivider(),
            _rFila('TOTAL VENTAS',  _f(r.ventas.total), bold: true),
            _rFila('Transacciones', '${r.ventas.numTransacciones}'),
            const SizedBox(height: 10),

            _rSeccion('GASTOS DEL TURNO'),
            if (r.gastos.detalle.isEmpty)
              _rFila('Sin gastos', _f(0))
            else ...[
              ...r.gastos.detalle.map((g) => _rFila(g.categoria, '-${_f(g.monto)}')),
              _rDivider(),
              _rFila('TOTAL GASTOS', '-${_f(r.gastos.total)}', bold: true),
            ],
            const SizedBox(height: 10),

            _rSeccion('CÁLCULO CAJA FÍSICA'),
            _rFila('Saldo inicial',    _f(r.montoInicial)),
            _rFila('+ Ef. ventas',     '+${_f(r.ventas.efectivo)}'),
            if (r.ventas.mixto > 0)
              _rFila('+ Mixto',        '+${_f(r.ventas.mixto)}'),
            _rFila('- Ef. gastos',     '-${_f(r.gastos.efectivo)}'),
            _rDivider(),
            _rFila('ESPERADO EN CAJA', _f(r.montoEsperadoCaja), bold: true),
            const SizedBox(height: 10),

            _rSeccion('RESULTADO FINAL'),
            _rFila('Contado',  _f(_montoIngresado)),
            _rFila('Esperado', _f(r.montoEsperadoCaja)),
            _rDivider(),
            _rFila(resultado,
              '${dif >= 0 ? '+' : ''}${_f(dif)}',
              bold: true, color: color),

            if (_obsCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              _rSeccion('OBSERVACIONES'),
              _mono(_obsCtrl.text, Colors.grey.shade600),
            ],

            const SizedBox(height: 12),
            Center(child: _mono('── POS Multitienda ──', Colors.grey.shade400)),
          ]),
        ),
      ],
    );
  }

  // ── Acciones ─────────────────────────────────────────
  Widget _buildAcciones(CajaProvider cont, ResumenCierre resumen) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        if (_paso > 1)
          TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text('Atrás', style: GoogleFonts.poppins()),
            onPressed: () => setState(() => _paso--),
          ),
        const Spacer(),
        if (_paso == 1)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
              style: GoogleFonts.poppins(color: Colors.grey)),
          ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: _paso == 3
              ? (cont.procesando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.lock_rounded, size: 16))
              : const Icon(Icons.arrow_forward_rounded, size: 16),
          label: Text(
            _paso == 1 ? 'Continuar'
                : _paso == 2 ? 'Ver resultado'
                : cont.procesando ? 'Cerrando...' : 'Confirmar cierre',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          onPressed: cont.procesando ? null : () async {
            if (_paso == 1) {
              setState(() => _paso = 2);
            } else if (_paso == 2) {
              final monto = double.tryParse(_montoCtrl.text);
              if (monto == null || monto < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Ingresa un monto válido'),
                  backgroundColor: Colors.red));
                return;
              }
              setState(() {
                _montoIngresado = monto;
                _paso = 3;
              });
            } else {
              final ok = await cont.cerrarCaja(
                montoFinalReal: _montoIngresado,
                observaciones:  _obsCtrl.text.trim(),
              );
              if (ok && context.mounted) Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _paso == 3 ? Colors.red.shade600 : const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ]),
    );

  // ── Helpers generales ────────────────────────────────
  Widget _tituloSeccion(String titulo, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(titulo,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.bold, fontSize: 13, color: color)),
  );

  Widget _fila(String label, double valor, Color color,
      {bool bold = false, bool negativo = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
          style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.black87,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text('${negativo ? '-' : ''}${_f(valor)}',
          style: GoogleFonts.poppins(
            fontSize: 13, color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
      ]),
    );

  // ── Helpers ticket (recibo) ──────────────────────────
  Widget _mono(String texto, Color color, {bool bold = false}) => Text(
    texto,
    style: TextStyle(
      fontFamily: 'monospace', fontSize: 12, color: color,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal),
  );

  Widget _rSeccion(String titulo) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 2),
    child: Text(titulo,
      style: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.bold,
        color: Colors.grey.shade600, letterSpacing: 0.8)),
  );

  Widget _rFila(String label, String valor,
      {bool bold = false, Color? color}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
          style: TextStyle(
            fontFamily: 'monospace', fontSize: 12,
            color: color ?? Colors.black87,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(valor,
          style: TextStyle(
            fontFamily: 'monospace', fontSize: 12,
            color: color ?? Colors.black87,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]),
    );

  Widget _rDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('──────────────────────────',
      style: TextStyle(
        fontFamily: 'monospace', fontSize: 11, color: Colors.grey.shade400)),
  );
}