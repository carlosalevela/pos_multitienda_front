import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/contabilidad_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants.dart';


class TabGastos extends StatelessWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;
  final bool                 esCajero;
  final AuthProvider         auth;
  final BuildContext         dialogContext;

  const TabGastos({
    super.key,
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.esCajero,
    required this.auth,
    required this.dialogContext,
  });

  // ✅ Categorías separadas por rol
  static const _categoriasAdmin = [
    'Arriendo', 'Nómina', 'Servicios', 'Mercancía',
    'Insumos', 'Transporte', 'Mantenimiento', 'Publicidad', 'Otros',
  ];

  static const _categoriasCajero = [
    'Insumos', 'Transporte', 'Mantenimiento', 'Publicidad', 'Otros',
  ];

  static const _metodos = ['efectivo', 'transferencia', 'tarjeta'];

  // ✅ Categorías según rol
  List<String> get _categorias =>
      esCajero ? _categoriasCajero : _categoriasAdmin;

  // ✅ Categorías que generan visibilidad solo_admin
  static const _restringidas = {
    'arriendo', 'nómina', 'nomina', 'servicios',
    'mercancía', 'mercancia', 'proveedor',
  };

  IconData _iconoCategoria(String cat) {
    switch (cat.toLowerCase()) {
      case 'arriendo':      return Icons.home_work_rounded;
      case 'nómina':
      case 'nomina':        return Icons.people_rounded;
      case 'servicios':     return Icons.bolt_rounded;
      case 'mercancía':
      case 'mercancia':     return Icons.store_rounded;
      case 'insumos':       return Icons.inventory_2_rounded;
      case 'transporte':    return Icons.local_shipping_rounded;
      case 'mantenimiento': return Icons.build_rounded;
      case 'publicidad':    return Icons.campaign_rounded;
      case 'proveedor':     return Icons.local_shipping_rounded;
      default:              return Icons.receipt_long_rounded;
    }
  }

  Color _colorCategoria(String cat) {
    switch (cat.toLowerCase()) {
      case 'arriendo':      return Colors.blue.shade600;
      case 'nómina':
      case 'nomina':        return Colors.purple.shade600;
      case 'servicios':     return Colors.orange.shade600;
      case 'mercancía':
      case 'mercancia':     return Colors.indigo.shade600;
      case 'insumos':       return Colors.green.shade600;
      case 'transporte':    return Colors.teal.shade600;
      case 'mantenimiento': return Colors.brown.shade600;
      case 'publicidad':    return Colors.pink.shade600;
      case 'proveedor':     return Colors.deepOrange.shade600;
      default:              return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastos = cont.gastos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gastos del día', style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF1A1A2E))),
              Text('${gastos.length} registros  •  '
                  'Total: ${fmt.format(gastos.fold(0.0, (s, g) => s + g.monto))}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          )),
          ElevatedButton.icon(
            onPressed: () => _mostrarDialogAgregar(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Agregar', style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(Constants.primaryColor),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Lista ────────────────────────────────────────────
        if (cont.cargando)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (gastos.isEmpty)
          _sinGastos(context)
        else
          Expanded(child: ListView.builder(
            itemCount: gastos.length,
            itemBuilder: (_, i) => _gastoCard(context, gastos[i]),
          )),
      ],
    );
  }

  // ── Sin gastos ─────────────────────────────────────────────
  Widget _sinGastos(BuildContext context) {
    return Expanded(child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long_rounded, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Sin gastos registrados hoy',
            style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 15)),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _mostrarDialogAgregar(context),
          icon: const Icon(Icons.add_rounded),
          label: Text('Registrar primer gasto',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(
              foregroundColor: const Color(Constants.primaryColor)),
        ),
      ],
    )));
  }

  // ── Card de gasto ──────────────────────────────────────────
  Widget _gastoCard(BuildContext context, gasto) {
    final color     = _colorCategoria(gasto.categoria);
    final soloAdmin = gasto.visibilidad == 'solo_admin'; // ✅

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        // ✅ Borde naranja sutil para gastos solo_admin
        border: soloAdmin
            ? Border.all(color: Colors.orange.shade200, width: 1)
            : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_iconoCategoria(gasto.categoria), color: color, size: 22),
        ),
        title: Row(children: [
          Expanded(child: Text(
            gasto.categoria.isEmpty ? 'Sin categoría' : gasto.categoria,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 14,
                color: const Color(0xFF1A1A2E)),
          )),
          // ✅ Badge solo_admin — solo lo ve el admin/supervisor
          if (soloAdmin && !esCajero) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_rounded, size: 10, color: Colors.orange.shade700),
                const SizedBox(width: 3),
                Text('Admin', style: GoogleFonts.poppins(
                    fontSize: 9, fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700)),
              ]),
            ),
            const SizedBox(width: 6),
          ],
          Text(fmt.format(gasto.monto),
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14,
                  color: Colors.red.shade600)),
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gasto.descripcion.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(gasto.descripcion,
                  overflow: TextOverflow.ellipsis, maxLines: 1,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 4),
            Row(children: [
              _chip(_metodoPagoLabel(gasto.metodoPago),
                  _metodoPagoColor(gasto.metodoPago)),
              const SizedBox(width: 6),
              _chip(gasto.empleadoNombre ?? 'Sin empleado', Colors.grey.shade600),
            ]),
          ],
        ),
        trailing: esCajero
            ? null
            : IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400, size: 20),
                onPressed: () => _confirmarEliminar(context, gasto.id),
              ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.poppins(
          fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _metodoPagoLabel(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      default:              return 'Efectivo';
    }
  }

  Color _metodoPagoColor(String m) {
    switch (m) {
      case 'transferencia': return Colors.blue.shade600;
      case 'tarjeta':       return Colors.purple.shade600;
      default:              return Colors.green.shade600;
    }
  }

  // ── Dialog confirmar eliminar ──────────────────────────────
  void _confirmarEliminar(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar gasto?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Esta acción no se puede deshacer.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              cont.eliminarGasto(id, tiendaId: tiendaId);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Eliminar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Dialog agregar gasto ───────────────────────────────────
  void _mostrarDialogAgregar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormGasto(
        cont:       cont,
        fmt:        fmt,
        tiendaId:   tiendaId,
        esCajero:   esCajero,     // ✅
        categorias: _categorias,  // ✅ ya filtradas por rol
        metodos:    _metodos,
        restringidas: _restringidas,
      ),
    );
  }
}


// ── Formulario ─────────────────────────────────────────────
class _FormGasto extends StatefulWidget {
  final ContabilidadProvider cont;
  final NumberFormat         fmt;
  final int?                 tiendaId;
  final bool                 esCajero;   // ✅
  final List<String>         categorias;
  final List<String>         metodos;
  final Set<String>          restringidas;

  const _FormGasto({
    required this.cont,
    required this.fmt,
    required this.tiendaId,
    required this.esCajero,
    required this.categorias,
    required this.metodos,
    required this.restringidas,
  });

  @override
  State<_FormGasto> createState() => _FormGastoState();
}


class _FormGastoState extends State<_FormGasto> {
  final _formKey   = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  String _categoria  = 'Otros';
  String _metodoPago = 'efectivo';
  bool   _guardando  = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ✅ Visibilidad automática según categoría
  String _visibilidad(String cat) =>
      widget.restringidas.contains(cat.toLowerCase())
          ? 'solo_admin'
          : 'todos';

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final ok = await widget.cont.crearGasto({
      'tienda':      widget.tiendaId,
      'categoria':   _categoria,
      'descripcion': _descCtrl.text.trim(),
      'monto':       _montoCtrl.text.trim(),
      'metodo_pago': _metodoPago,
      // ✅ Cajero nunca envía solo_admin; el backend lo valida igual
      if (!widget.esCajero) 'visibilidad': _visibilidad(_categoria),
    }, tiendaId: widget.tiendaId);

    setState(() => _guardando = false);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          Text('Registrar gasto',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 18,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 20),

          // Categoría chips
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Categoría', style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: widget.categorias.map((cat) {
              final sel          = _categoria == cat;
              final esRestringida = widget.restringidas.contains(cat.toLowerCase());

              return GestureDetector(
                onTap: () => setState(() => _categoria = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(Constants.primaryColor)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cat, style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.grey.shade700)),
                    // ✅ Candado en categorías restringidas (solo admin las ve)
                    if (esRestringida && !widget.esCajero) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_rounded, size: 10,
                          color: sel
                              ? Colors.white.withOpacity(0.8)
                              : Colors.orange.shade400),
                    ],
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Monto
          TextFormField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco('Monto', Icons.attach_money_rounded),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa el monto';
              if (double.tryParse(v) == null || double.parse(v) <= 0) {
                return 'Monto inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Descripción
          TextFormField(
            controller: _descCtrl,
            decoration: _inputDeco('Descripción (opcional)', Icons.notes_rounded),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          // Método de pago
          DropdownButtonFormField<String>(
            value: _metodoPago,
            decoration: _inputDeco('Método de pago', Icons.payment_rounded),
            items: widget.metodos.map((m) => DropdownMenuItem(
              value: m,
              child: Text(_label(m), style: GoogleFonts.poppins(fontSize: 14)),
            )).toList(),
            onChanged: (v) => setState(() => _metodoPago = v!),
          ),
          const SizedBox(height: 24),

          // Botón guardar
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(Constants.primaryColor),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text('Guardar gasto',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  String _label(String m) {
    switch (m) {
      case 'transferencia': return 'Transferencia';
      case 'tarjeta':       return 'Tarjeta';
      default:              return 'Efectivo';
    }
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 20, color: const Color(Constants.primaryColor)),
      filled: true, fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(Constants.primaryColor), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}