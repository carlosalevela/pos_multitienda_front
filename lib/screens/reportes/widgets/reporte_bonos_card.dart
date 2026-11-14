import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/bono.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/bono_service.dart';

const _kGreen     = Color(0xFF006C49);
const _kGreenLight = Color(0xFFECFDF5);
const _kPurple    = Color(0xFF7C3AED);
const _kPurpleLight = Color(0xFFF5F3FF);
const _kAmber     = Color(0xFFB45309);
const _kRed       = Color(0xFFBA1A1A);
const _kRedLight  = Color(0xFFFFF1F2);
const _kSurface   = Color(0xFFF7F9FB);
const _kBorder    = Color(0xFFE2E4E6);
const _kText      = Color(0xFF191C1E);
const _kMuted     = Color(0xFF76777D);

class ReporteBonos extends StatefulWidget {
  const ReporteBonos({super.key});

  @override
  State<ReporteBonos> createState() => _ReporteBonos();
}

class _ReporteBonos extends State<ReporteBonos> {
  final _svc           = BonoService();
  final _codigoCtrl    = TextEditingController();
  final _valorCtrl     = TextEditingController();

  List<Bono> _bonos       = [];
  bool       _cargando    = false;
  bool       _validando   = false;
  bool       _vendiendo   = false;
  Bono?      _bonoValidado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarBonos());
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarBonos() async {
    final auth = context.read<AuthProvider>();
    setState(() => _cargando = true);
    final r = await _svc.listarBonos(
      empresaId: int.tryParse(auth.empresaId) ?? 0,
      tiendaId:  auth.tiendaId,
      estado:    'activo',
    );
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _bonos = r['success'] == true
          ? (r['data'] as List<Bono>)
          : [];
    });
  }

  Future<void> _validarBono() async {
    final codigo = _codigoCtrl.text.trim().toUpperCase();
    if (codigo.isEmpty) return;
    setState(() { _validando = true; _bonoValidado = null; });
    final r = await _svc.validarBono(codigo);
    if (!mounted) return;
    setState(() {
      _validando    = false;
      _bonoValidado = r['success'] == true ? r['data'] as Bono : null;
    });
    if (r['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r['error'] ?? 'Bono no encontrado'),
        backgroundColor: _kRed,
      ));
    }
  }

  Future<void> _venderBono() async {
    final valor = double.tryParse(_valorCtrl.text.trim());
    if (valor == null || valor <= 0) return;
    final auth = context.read<AuthProvider>();
    setState(() => _vendiendo = true);
    final r = await _svc.venderBono(
      empresaId: int.tryParse(auth.empresaId) ?? 0,
      tiendaId:  auth.tiendaId,
      valor:     valor,
    );
    if (!mounted) return;
    setState(() => _vendiendo = false);
    if (r['success'] == true) {
      final bono = r['data'] as Bono;
      _valorCtrl.clear();
      _mostrarCodigoGenerado(bono);
      _cargarBonos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r['error'] ?? 'Error al crear bono'),
        backgroundColor: _kRed,
      ));
    }
  }

  void _mostrarCodigoGenerado(Bono bono) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.card_giftcard_rounded, color: _kPurple, size: 22),
          const SizedBox(width: 10),
          Text('Bono creado',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kPurpleLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kPurple.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Text('Código del Bono',
                  style: GoogleFonts.inter(fontSize: 11, color: _kMuted)),
              const SizedBox(height: 8),
              Text(bono.codigo,
                  style: GoogleFonts.inter(
                      fontSize: 24, fontWeight: FontWeight.w900,
                      color: _kPurple, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text('\$${bono.valorOriginal.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _kText)),
              const SizedBox(height: 4),
              Text('Vence en 1 año',
                  style: GoogleFonts.inter(fontSize: 11, color: _kMuted)),
            ]),
          ),
          const SizedBox(height: 12),
          Text('Entrega este código al cliente.',
              style: GoogleFonts.inter(fontSize: 12, color: _kMuted)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: bono.codigo));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Código copiado'),
                duration: Duration(seconds: 2),
              ));
            },
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: Text('Copiar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Listo', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Título sección ────────────────────────────────────
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kPurpleLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.card_giftcard_rounded, size: 18, color: _kPurple),
        ),
        const SizedBox(width: 10),
        Text('Bonos de regalo',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
        const Spacer(),
        IconButton(
          onPressed: _cargando ? null : _cargarBonos,
          icon: _cargando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen))
              : const Icon(Icons.refresh_rounded, size: 18, color: _kMuted),
          tooltip: 'Actualizar',
        ),
      ]),
      const SizedBox(height: 14),

      // ── Fila: Vender + Validar ────────────────────────────
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Panel vender
        Expanded(child: _PanelVender(
          ctrl:      _valorCtrl,
          vendiendo: _vendiendo,
          onVender:  _venderBono,
        )),
        const SizedBox(width: 12),
        // Panel validar
        Expanded(child: _PanelValidar(
          ctrl:        _codigoCtrl,
          validando:   _validando,
          bonoValidado: _bonoValidado,
          onValidar:   _validarBono,
          onLimpiar:   () => setState(() {
            _bonoValidado = null;
            _codigoCtrl.clear();
          }),
        )),
      ]),

      const SizedBox(height: 20),

      // ── Lista bonos activos ───────────────────────────────
      if (_bonos.isEmpty && !_cargando)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          alignment: Alignment.center,
          child: Text('No hay bonos activos',
              style: GoogleFonts.inter(fontSize: 13, color: _kMuted)),
        )
      else
        ..._bonos.map((b) => _FilaBono(bono: b)),
    ]);
  }
}

// ── Panel Vender Bono ─────────────────────────────────────

class _PanelVender extends StatelessWidget {
  final TextEditingController ctrl;
  final bool vendiendo;
  final VoidCallback onVender;
  const _PanelVender({
    required this.ctrl,
    required this.vendiendo,
    required this.onVender,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kPurpleLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kPurple.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Vender bono',
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700, color: _kPurple)),
      const SizedBox(height: 10),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _kText),
        decoration: InputDecoration(
          prefixText: '\$ ',
          hintText: '50000',
          hintStyle: GoogleFonts.inter(color: _kMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kPurple.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kPurple.withValues(alpha: 0.3)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: vendiendo ? null : onVender,
          icon: vendiendo
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add_rounded, size: 16),
          label: Text(vendiendo ? 'Creando...' : 'Crear bono',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ),
    ]),
  );
}

// ── Panel Validar Bono ────────────────────────────────────

class _PanelValidar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool    validando;
  final Bono?   bonoValidado;
  final VoidCallback onValidar;
  final VoidCallback onLimpiar;
  const _PanelValidar({
    required this.ctrl,
    required this.validando,
    required this.bonoValidado,
    required this.onValidar,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    final bono = bonoValidado;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bono != null
            ? (bono.estaVigente ? _kGreenLight : _kRedLight)
            : _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bono != null
              ? (bono.estaVigente
                  ? _kGreen.withValues(alpha: 0.3)
                  : _kRed.withValues(alpha: 0.3))
              : _kBorder,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Consultar bono',
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: _kText, letterSpacing: 1.1),
              decoration: InputDecoration(
                hintText: 'BON-XXXXXX',
                hintStyle: GoogleFonts.inter(color: _kMuted, letterSpacing: 0),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: validando ? null : onValidar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: validando
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Ver', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ]),
        if (bono != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(
              bono.estaVigente ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 15,
              color: bono.estaVigente ? _kGreen : _kRed,
            ),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Saldo: \$${bono.saldo.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: bono.estaVigente ? _kGreen : _kRed)),
              Text('Vence: ${bono.fechaVencimiento}  ·  ${bono.estado}',
                  style: GoogleFonts.inter(fontSize: 10, color: _kMuted)),
            ])),
            GestureDetector(
              onTap: onLimpiar,
              child: const Icon(Icons.close_rounded, size: 16, color: _kMuted),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── Fila de un bono en la lista ───────────────────────────

class _FilaBono extends StatelessWidget {
  final Bono bono;
  const _FilaBono({required this.bono});

  @override
  Widget build(BuildContext context) {
    final pct = bono.valorOriginal > 0
        ? (bono.saldo / bono.valorOriginal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        // Código
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bono.codigo,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: _kPurple, letterSpacing: 1)),
            if (bono.tiendaOrigenNombre != null)
              Text(bono.tiendaOrigenNombre!,
                  style: GoogleFonts.inter(fontSize: 10, color: _kMuted)),
          ]),
        ),
        // Barra de saldo
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: _kBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                    pct > 0.5 ? _kGreen : pct > 0.2 ? _kAmber : _kRed),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${bono.saldo.toStringAsFixed(0)} / \$${bono.valorOriginal.toStringAsFixed(0)}',
              style: GoogleFonts.inter(fontSize: 10, color: _kMuted),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        // Vencimiento
        Text(
          bono.fechaVencimiento.length >= 10
              ? bono.fechaVencimiento.substring(0, 10)
              : bono.fechaVencimiento,
          style: GoogleFonts.inter(fontSize: 10, color: _kMuted),
        ),
      ]),
    );
  }
}
