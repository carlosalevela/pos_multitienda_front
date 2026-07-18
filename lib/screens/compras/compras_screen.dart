// lib/screens/compras/compras_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/proveedores_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'compras_theme.dart';
import 'widgets/compras_tabla.dart';
import 'widgets/detalle_compra_dialog.dart';
import 'widgets/nueva_orden_dialog.dart';
import 'widgets/recepcion_resultado_dialog.dart';
import 'widgets/modal_precios_recibir.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  String? _filtroEstado;
  final _searchCtrl = TextEditingController();
  String  _busqueda = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
      _cargarMayoreo();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Siempre carga TODAS las órdenes — el filtro es client-side.
  void _cargar() {
    final auth = context.read<AuthProvider>();
    context.read<ProveedoresProvider>().cargarCompras(
      tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
    );
  }

  Future<void> _cargarMayoreo() async {
    final auth      = context.read<AuthProvider>();
    final empresaId = int.tryParse(auth.empresaId) ?? 0;
    if (empresaId == 0) return;
    await context.read<ProveedoresProvider>().cargarConfigMayoreo(empresaId);
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> todas) {
    return todas.where((c) {
      final estadoOk = _filtroEstado == null ||
          c['estado'] == _filtroEstado;
      final q = _busqueda.toLowerCase().trim();
      final textOk = q.isEmpty ||
          (c['numero_orden']    ?? '').toString().toLowerCase().contains(q) ||
          (c['proveedor_nombre'] ?? '').toString().toLowerCase().contains(q);
      return estadoOk && textOk;
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProveedoresProvider>();
    final auth = context.watch<AuthProvider>();
    final todas    = prov.compras;
    final filtradas = _filtrar(todas);

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: Column(children: [
        _buildHeader(auth),
        Expanded(
          child: prov.cargandoCompras
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.secondary))
              : _buildBody(todas, filtradas, prov, auth),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader(AuthProvider auth) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      boxShadow: [BoxShadow(
        color:      Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset:     const Offset(0, 2),
      )],
    ),
    child: Row(children: [
      // Ícono + título
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:        AppColors.mintLight,
          borderRadius: AppRadius.lg,
        ),
        child: const Icon(Icons.shopping_cart_rounded,
            color: AppColors.secondary, size: 24),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Órdenes de compra', style: AppTextStyles.headlineMd),
        Text(auth.tiendaNombre,
            style: AppTextStyles.bodySm),
      ]),
      const SizedBox(width: 24),

      // Búsqueda
      SizedBox(
        width: 220,
        height: 38,
        child: TextField(
          controller: _searchCtrl,
          onChanged:  (v) => setState(() => _busqueda = v),
          style: AppTextStyles.bodyMd.copyWith(fontSize: 13),
          decoration: InputDecoration(
            hintText:  'Buscar orden o proveedor…',
            hintStyle: AppTextStyles.bodySm,
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: AppColors.outline),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.outline),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _busqueda = '');
                    },
                  )
                : null,
            isDense:   true,
            filled:    true,
            fillColor: AppColors.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 0),
            border: const OutlineInputBorder(
                borderRadius: AppRadius.lg,
                borderSide: BorderSide(color: AppColors.outlineVariant)),
            enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.lg,
                borderSide: BorderSide(color: AppColors.outlineVariant)),
            focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.lg,
                borderSide: BorderSide(
                    color: AppColors.secondary, width: 1.5)),
          ),
        ),
      ),
      const SizedBox(width: 12),

      // Filtro estado
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:        AppColors.surfaceContainerLow,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _filtroEstado,
            hint: Text('Todos los estados',
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant)),
            style: AppTextStyles.bodyMd
                .copyWith(fontSize: 13, color: AppColors.onSurface),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.outline),
            onChanged: (v) => setState(() => _filtroEstado = v),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text('Todos',
                    style: AppTextStyles.bodyMd.copyWith(fontSize: 13))),
              ...['pendiente', 'recibida', 'cancelada'].map((e) =>
                DropdownMenuItem(
                  value: e,
                  child: Row(children: [
                    Icon(ComprasTheme.iconEstado(e),
                        size: 14,
                        color: ComprasTheme.colorEstado(e)),
                    const SizedBox(width: 6),
                    Text(ComprasTheme.labelEstado(e),
                        style: AppTextStyles.bodyMd
                            .copyWith(fontSize: 13)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),

      // Nueva orden
      ElevatedButton.icon(
        onPressed: () => _abrirNuevaOrden(context),
        icon:  const Icon(Icons.add_rounded, size: 18),
        label: Text('Nueva orden',
            style: AppTextStyles.bodyMd
                .copyWith(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        ),
      ),
    ]),
  );

  // ── Body ──────────────────────────────────────────────────────

  Widget _buildBody(
    List<Map<String, dynamic>> todas,
    List<Map<String, dynamic>> filtradas,
    ProveedoresProvider prov,
    AuthProvider auth,
  ) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPIs calculan siempre sobre TODAS las órdenes
            _buildKpis(todas, prov),
            const SizedBox(height: 16),
            ComprasTabla(
              compras:      filtradas,
              auth:         auth,
              hayFiltro:    _filtroEstado != null || _busqueda.isNotEmpty,
              onNuevaOrden: () => _abrirNuevaOrden(context),
              onVerDetalle: (id) => _verDetalle(context, id),
              onRecibir:    (c)  => _confirmarRecibir(context, c),
              onCancelar:   (c)  => _confirmarCancelar(context, c),
            ),
          ],
        ),
      );

  // ── KPIs (siempre sobre el total real) ────────────────────────

  Widget _buildKpis(
    List<Map<String, dynamic>> todas,
    ProveedoresProvider prov,
  ) {
    final pendientes = todas.where((c) => c['estado'] == 'pendiente').length;
    final recibidas  = todas.where((c) => c['estado'] == 'recibida').length;
    final canceladas = todas.where((c) => c['estado'] == 'cancelada').length;
    final invertido  = todas
        .where((c) => c['estado'] == 'recibida')
        .fold(0.0, (s, c) => s + (double.tryParse(c['total'].toString()) ?? 0));

    return Row(children: [
      Expanded(child: _kpiCard(
        icon:  Icons.receipt_long_rounded,
        label: 'Total órdenes',
        valor: '${todas.length}',
        color: AppColors.primary,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:  Icons.pending_actions_rounded,
        label: 'Pendientes',
        valor: '$pendientes',
        color: AppColors.warning,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:  Icons.check_circle_rounded,
        label: 'Recibidas',
        valor: '$recibidas',
        color: AppColors.secondary,
      )),
      const SizedBox(width: 12),
      Expanded(child: _kpiCard(
        icon:  Icons.attach_money_rounded,
        label: 'Total invertido',
        valor: '\$${ComprasTheme.fmt(invertido)}',
        color: AppColors.mintDark,
      )),
      if (canceladas > 0) ...[
        const SizedBox(width: 12),
        Expanded(child: _kpiCard(
          icon:  Icons.cancel_rounded,
          label: 'Canceladas',
          valor: '$canceladas',
          color: AppColors.error,
        )),
      ],
    ]);
  }

  Widget _kpiCard({
    required IconData icon,
    required String   label,
    required String   valor,
    required Color    color,
  }) =>
      Container(
        height: 86,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.lg,
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.10),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Text(valor,
                    style: AppTextStyles.numericData
                        .copyWith(fontSize: 18, color: color)),
                Text(label, style: AppTextStyles.bodySm),
              ],
            ),
          ),
        ]),
      );

  // ── Acciones ──────────────────────────────────────────────────

  void _abrirNuevaOrden(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const NuevaOrdenDialog(),
    ).then((_) => _cargar());
  }

  void _verDetalle(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => DetalleCompraDialog(id: id),
    );
  }

  void _confirmarRecibir(
      BuildContext context, Map<String, dynamic> c) async {
    final prov = context.read<ProveedoresProvider>();

    final result = await showModalPreciosRecibir(
      context:   context,
      compra:    c,
      manejaM:   prov.manejaM,
      cantidadM: prov.cantidadM,
    );

    if (result == null || !mounted) return;

    final data = await prov.recibirCompra(
      c['id'],
      precios:        result.precios,
      preciosMayoreo: result.preciosMayoreo,
    );

    if (!mounted) return;

    if (data != null) {
      _cargar();
      showDialog(
        context: context,
        builder: (_) => ResultadoRecepcionDialog(data: data),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          prov.errorMsg ?? 'Error al recibir la orden',
          style: AppTextStyles.bodyMd
              .copyWith(color: AppColors.onSecondary)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  void _confirmarCancelar(
      BuildContext context, Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: Row(children: [
          const Icon(Icons.cancel_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Text('Cancelar orden', style: AppTextStyles.headlineSm),
        ]),
        content: RichText(
          text: TextSpan(
            style: AppTextStyles.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
            children: [
              const TextSpan(text: 'Seguro que deseas cancelar la orden '),
              TextSpan(
                text: c['numero_orden'],
                style: const TextStyle(fontWeight: FontWeight.bold,
                    color: AppColors.onSurface)),
              const TextSpan(text: '? Esta acción no se puede deshacer.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No, mantener',
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant))),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await context
                  .read<ProveedoresProvider>()
                  .cancelarCompra(c['id']);
              if (!mounted) return;
              _cargar();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  ok ? 'Orden cancelada' : 'Error al cancelar la orden',
                  style: AppTextStyles.bodyMd
                      .copyWith(color: AppColors.onSecondary)),
                backgroundColor: ok ? AppColors.warning : AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lg),
                margin: const EdgeInsets.all(16),
              ));
            },
            icon:  const Icon(Icons.cancel_rounded, size: 16),
            label: Text('Sí, cancelar',
                style: AppTextStyles.bodyMd
                    .copyWith(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onSecondary,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.xl),
            ),
          ),
        ],
      ),
    );
  }
}
