// lib/screens/compras/compras_modulo_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/proveedores_provider.dart';
import '../../core/api_client.dart';
import '../../services/compras_pdf_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'compras_theme.dart';
import 'widgets/nueva_orden_dialog.dart';
import 'widgets/detalle_compra_dialog.dart';
import 'widgets/modal_precios_recibir.dart';
import 'widgets/recepcion_resultado_dialog.dart';
import '../proveedores/widgets/proveedor_form_dialog.dart';

class ComprasModuloScreen extends StatefulWidget {
  const ComprasModuloScreen({super.key});

  @override
  State<ComprasModuloScreen> createState() => _ComprasModuloScreenState();
}

class _ComprasModuloScreenState extends State<ComprasModuloScreen>
    with SingleTickerProviderStateMixin {
  // ── Tabs ──────────────────────────────────────────────────
  late TabController _tabCtrl;
  int _currentTab = 0;

  // ── Búsqueda y filtros ────────────────────────────────────
  final _searchProvCtrl = TextEditingController();
  Timer? _debounce;
  String? _filtroEstado;

  // ── Selección ─────────────────────────────────────────────
  Map<String, dynamic>? _provSel;
  Map<String, dynamic>? _ordSel;
  Map<String, dynamic>? _ordDetalle;
  bool _cargandoOrdDetalle = false;

  // ── Cuentas por pagar ─────────────────────────────────────
  List<Map<String, dynamic>> _cuentasPagar = [];
  bool   _cargandoCuentas = false;
  double _totalDeuda      = 0;
  int?   _marcandoPagada;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTodo());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchProvCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Carga de datos ────────────────────────────────────────

  void _cargarTodo() {
    final auth = context.read<AuthProvider>();
    final prov = context.read<ProveedoresProvider>();
    prov.cargarProveedores();
    prov.cargarCompras(
      tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
      estado: _filtroEstado,
    );
    final empId = int.tryParse(auth.empresaId) ?? 0;
    if (empId > 0) prov.cargarConfigMayoreo(empId);
  }

  // ── Navegación entre tabs ─────────────────────────────────

  void _switchTab(int t) {
    setState(() => _currentTab = t);
    _tabCtrl.animateTo(t);
    if (t == 2 && _cuentasPagar.isEmpty && !_cargandoCuentas) {
      _cargarCuentasPagar();
    }
  }

  Future<void> _cargarCuentasPagar() async {
    setState(() => _cargandoCuentas = true);
    try {
      final r = await ApiClient.instance.get('/proveedores/cuentas-pagar/');
      final data = r.data as Map<String, dynamic>;
      setState(() {
        _cuentasPagar = (data['compras'] as List?)
                ?.cast<Map<String, dynamic>>() ?? [];
        _totalDeuda   = (data['total_deuda'] as num?)?.toDouble() ?? 0;
        _cargandoCuentas = false;
      });
    } catch (_) {
      setState(() => _cargandoCuentas = false);
    }
  }

  Future<void> _marcarPagada(Map<String, dynamic> compra) async {
    final id = compra['id'] as int;
    setState(() => _marcandoPagada = id);
    try {
      await ApiClient.instance.patch('/proveedores/compras/$id/marcar-pagada/');
      setState(() {
        _cuentasPagar.removeWhere((c) => c['id'] == id);
        _totalDeuda = _cuentasPagar.fold(0, (s, c) => s + (c['total'] as num));
        _marcandoPagada = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compra marcada como pagada'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      setState(() => _marcandoPagada = null);
    }
  }

  // ── Búsqueda proveedores ──────────────────────────────────

  void _onSearchProv(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => context.read<ProveedoresProvider>().cargarProveedores(q: v),
    );
  }

  void _clearSearchProv() {
    _searchProvCtrl.clear();
    context.read<ProveedoresProvider>().cargarProveedores();
  }

  // ── Filtro estado órdenes ─────────────────────────────────

  void _setFiltroEstado(String? v) {
    setState(() => _filtroEstado = v);
    final auth = context.read<AuthProvider>();
    context.read<ProveedoresProvider>().cargarCompras(
      tiendaId: auth.tiendaId == 0 ? null : auth.tiendaId,
      estado: v,
    );
  }

  // ── Selección de orden (carga detalle async) ──────────────

  Future<void> _selOrden(Map<String, dynamic> c) async {
    setState(() {
      _ordSel = c;
      _ordDetalle = null;
      _cargandoOrdDetalle = true;
    });
    final d = await context.read<ProveedoresProvider>().obtenerCompra(c['id'] as int);
    if (mounted) {
      setState(() {
        _ordDetalle = d;
        _cargandoOrdDetalle = false;
      });
    }
  }

  // ── Acciones ──────────────────────────────────────────────

  void _nuevaOrden() =>
      showDialog(context: context, builder: (_) => const NuevaOrdenDialog())
          .then((_) => _cargarTodo());

  void _verDetalleOrden(int id) =>
      showDialog(context: context, builder: (_) => DetalleCompraDialog(id: id));

  void _nuevoProveedor() {
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProveedorFormDialog(
        esSuperadmin: auth.esSuperadmin,
        empresaIdFija: auth.esSuperadmin ? null : auth.empresaId,
        tiendaIdFijo: auth.esSuperadmin ? null : auth.tiendaId,
        onGuardado: (ok, _) {
          if (!mounted) return;
          _showSnack(ok ? 'Proveedor creado correctamente' : 'Error al crear proveedor', ok);
          if (ok) _cargarTodo();
        },
      ),
    );
  }

  void _editarProveedor(Map<String, dynamic> p) {
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProveedorFormDialog(
        proveedor: p,
        esSuperadmin: auth.esSuperadmin,
        empresaIdFija: auth.esSuperadmin ? null : auth.empresaId,
        tiendaIdFijo: auth.esSuperadmin ? null : auth.tiendaId,
        onGuardado: (ok, _) {
          if (!mounted) return;
          _showSnack(ok ? 'Proveedor actualizado' : 'Error al actualizar', ok);
          if (ok) {
            _cargarTodo();
            setState(() => _provSel = null);
          }
        },
      ),
    );
  }

  Future<void> _recibirOrden(Map<String, dynamic> c) async {
    final prov = context.read<ProveedoresProvider>();
    final result = await showModalPreciosRecibir(
      context: context,
      compra: _ordDetalle ?? c,
      manejaM: prov.manejaM,
      cantidadM: prov.cantidadM,
    );
    if (result == null || !mounted) return;
    final data = await prov.recibirCompra(
      c['id'],
      precios: result.precios,
      preciosMayoreo: result.preciosMayoreo,
    );
    if (!mounted) return;
    if (data != null) {
      // Genera y guarda el recibo de recepción en segundo plano
      ComprasPDFService.instance.abrirRecepcion(
        compra: c,
        resultado: data,
      ).ignore();
      setState(() {
        _ordSel = null;
        _ordDetalle = null;
      });
      _cargarTodo();
      showDialog(context: context, builder: (_) => ResultadoRecepcionDialog(data: data));
    } else {
      _showSnack(prov.errorMsg ?? 'Error al recibir la orden', false);
    }
  }

  Future<void> _cancelarOrden(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: Text('Cancelar orden',
            style: AppTextStyles.headlineSm.copyWith(fontWeight: FontWeight.w800)),
        content: Text(
          '¿Seguro que deseas cancelar ${c['numero_orden']}? Esta acción no se puede deshacer.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantener'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await context.read<ProveedoresProvider>().cancelarCompra(c['id']);
    if (!mounted) return;
    _showSnack(res ? 'Orden cancelada' : 'Error al cancelar', res);
    if (res) {
      setState(() {
        _ordSel = null;
        _ordDetalle = null;
      });
      _cargarTodo();
    }
  }

  void _showSnack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: ok ? AppColors.secondary : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      margin: const EdgeInsets.all(AppSpacing.md),
    ));
  }

  // ─────────────────────────────────────────── BUILD ────────

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProveedoresProvider>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildTabBar(),
          _buildKpiRow(prov),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildProveedoresTab(prov),
                _buildOrdenesTab(prov),
                _buildCuentasPagarTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    final auth = context.watch<AuthProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Compras',
            style: AppTextStyles.headlineMd.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: AppRadius.full,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_outlined,
                    size: 13, color: AppColors.secondary),
                const SizedBox(width: 5),
                Text(
                  auth.tiendaNombre,
                  style: AppTextStyles.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab switcher ──────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      color: AppColors.surfaceContainerLowest,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: AppRadius.lg,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tabBtn(0, Icons.business_outlined, 'Proveedores'),
                const SizedBox(width: 2),
                _tabBtn(1, Icons.receipt_long_outlined, 'Órdenes de Compra'),
                const SizedBox(width: 2),
                _tabBtn(2, Icons.account_balance_wallet_outlined, 'Cuentas × Pagar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(int index, IconData icon, String label) {
    final active = _currentTab == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceContainerLowest : Colors.transparent,
          borderRadius: AppRadius.md,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active
                  ? AppColors.onSecondaryContainer
                  : AppColors.outline,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMd.copyWith(
                color: active
                    ? AppColors.onSecondaryContainer
                    : AppColors.outline,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── KPI row ───────────────────────────────────────────────

  Widget _buildKpiRow(ProveedoresProvider prov) {
    final pendientes = prov.compras.where((c) => c['estado'] == 'pendiente').length;
    final total = prov.compras.length;

    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: _kpiCard(
              icon: Icons.attach_money_rounded,
              iconBg: const Color(0xFFDAE2FD),
              iconColor: const Color(0xFF3B4BA0),
              label: 'Total invertido',
              value: '\$${ComprasTheme.fmt(prov.totalComprasRecibidas)}',
              hint: 'en órdenes recibidas',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _kpiCard(
              icon: Icons.pending_actions_rounded,
              iconBg: AppColors.warningContainer,
              iconColor: AppColors.warning,
              label: 'Órdenes pendientes',
              value: '$pendientes',
              hint: 'de $total totales',
              valueColor: pendientes > 0 ? AppColors.warning : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _kpiCard(
              icon: Icons.business_rounded,
              iconBg: AppColors.secondaryContainer,
              iconColor: AppColors.onSecondaryContainer,
              label: 'Proveedores activos',
              value: '${prov.totalProveedores}',
              hint: 'en catálogo',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _kpiCard(
              icon: Icons.receipt_long_rounded,
              iconBg: AppColors.surfaceContainerHighest,
              iconColor: AppColors.onSurfaceVariant,
              label: 'Total órdenes',
              value: '$total',
              hint: 'en el período',
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String hint,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.xl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: iconBg, borderRadius: AppRadius.lg),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSm),
                Text(
                  value,
                  style: AppTextStyles.numericData.copyWith(
                    fontSize: 18,
                    color: valueColor ?? AppColors.onSurface,
                  ),
                ),
                Text(hint,
                    style: AppTextStyles.bodySm.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── TAB: PROVEEDORES ─────────────────

  Widget _buildProveedoresTab(ProveedoresProvider prov) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildProveedoresTable(prov)),
          const SizedBox(width: 16),
          SizedBox(width: 280, child: _buildProveedorPanel(prov)),
        ],
      ),
    );
  }

  Widget _buildProveedoresTable(ProveedoresProvider prov) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.xl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xl,
        child: Column(
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.surfaceContainerLow,
              child: Row(
                children: [
                  Text(
                    'Proveedores',
                    style: AppTextStyles.headlineSm.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 210,
                    child: TextField(
                      controller: _searchProvCtrl,
                      onChanged: _onSearchProv,
                      style: AppTextStyles.bodyMd.copyWith(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar…',
                        hintStyle: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.outline,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 16, color: AppColors.outline),
                        suffixIcon: _searchProvCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 14, color: AppColors.outline),
                                onPressed: _clearSearchProv,
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.lg,
                          borderSide:
                              const BorderSide(color: AppColors.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.lg,
                          borderSide:
                              const BorderSide(color: AppColors.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.lg,
                          borderSide:
                              const BorderSide(color: AppColors.secondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _nuevoProveedor,
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Nuevo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.lg),
                      textStyle: AppTextStyles.labelMd
                          .copyWith(letterSpacing: 0.2),
                    ),
                  ),
                ],
              ),
            ),
            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceContainerLow,
              child: Row(
                children: [
                  const SizedBox(width: 42),
                  Expanded(
                      flex: 3,
                      child: Text('PROVEEDOR', style: _colHdrStyle)),
                  Expanded(
                      flex: 2,
                      child: Text('CIUDAD / NIT', style: _colHdrStyle)),
                  Expanded(
                      flex: 2,
                      child: Text('TELÉFONO', style: _colHdrStyle)),
                  SizedBox(
                      width: 72, child: Text('ESTADO', style: _colHdrStyle)),
                  const SizedBox(width: 20),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outlineVariant),
            // Rows
            Expanded(
              child: prov.cargandoProveedores
                  ? const Center(child: CircularProgressIndicator())
                  : prov.proveedores.isEmpty
                      ? _emptyState(
                          'No hay proveedores',
                          Icons.business_outlined,
                          _nuevoProveedor,
                          'Agregar proveedor',
                        )
                      : ListView.separated(
                          itemCount: prov.proveedores.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.outlineVariant),
                          itemBuilder: (_, i) =>
                              _buildProvRow(prov.proveedores[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvRow(Map<String, dynamic> p) {
    final sel = _provSel?['id'] == p['id'];
    final activo = p['activo'] as bool? ?? true;
    final nombre = p['nombre'] as String? ?? '';

    return InkWell(
      onTap: () => setState(() => _provSel = p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: sel
            ? AppColors.secondaryContainer.withOpacity(0.35)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.secondaryContainer
                    : AppColors.surfaceContainerHighest,
                borderRadius: AppRadius.md,
              ),
              child: Center(
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: AppTextStyles.labelMd.copyWith(
                    color: sel
                        ? AppColors.onSecondaryContainer
                        : AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Nombre
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  if ((p['empresa_nombre'] ?? '').toString().isNotEmpty)
                    Text(
                      p['empresa_nombre'].toString(),
                      style:
                          AppTextStyles.bodySm.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ),
            // Ciudad / NIT
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _valOrDash(p['ciudad']),
                    style: AppTextStyles.bodyMd.copyWith(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant),
                  ),
                  Text(
                    _valOrDash(p['nit']),
                    style:
                        AppTextStyles.bodySm.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            // Teléfono
            Expanded(
              flex: 2,
              child: Text(
                _valOrDash(p['telefono']),
                style: AppTextStyles.bodyMd
                    .copyWith(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ),
            // Estado chip
            SizedBox(
              width: 72,
              child: _activoChip(activo),
            ),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: sel ? AppColors.secondary : AppColors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ── Panel proveedor ───────────────────────────────────────

  Widget _buildProveedorPanel(ProveedoresProvider prov) {
    if (_provSel == null) {
      return _emptyPanel(
        icon: Icons.business_outlined,
        message:
            'Selecciona un proveedor\npara ver su información',
      );
    }

    final p = _provSel!;
    final nombre = p['nombre'] as String? ?? '';
    final activo = p['activo'] as bool? ?? true;
    final comprasProv = prov.compras
        .where((c) => c['proveedor_nombre'] == nombre)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.xl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xl,
        child: Column(
          children: [
            // Panel header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surfaceContainerLow,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: AppTextStyles.headlineSm.copyWith(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        if ((p['empresa_nombre'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Text(
                            p['empresa_nombre'].toString(),
                            style: AppTextStyles.bodySm
                                .copyWith(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  _activoChip(activo),
                ],
              ),
            ),
            // Panel body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Información'),
                    _infoRow('Teléfono', _valOrDash(p['telefono'])),
                    _infoRow('Email', _valOrDash(p['email'])),
                    _infoRow('Ciudad', _valOrDash(p['ciudad'])),
                    _infoRow('NIT', _valOrDash(p['nit'])),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.outlineVariant),
                    const SizedBox(height: 8),
                    _sectionLabel(
                        'Órdenes recientes (${comprasProv.length})'),
                    if (comprasProv.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Sin órdenes registradas',
                          style: AppTextStyles.bodySm,
                        ),
                      )
                    else
                      ...comprasProv
                          .take(4)
                          .map((c) => _miniOrdRow(c)),
                  ],
                ),
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.outlineVariant)),
                color: AppColors.surfaceContainerLow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editarProveedor(_provSel!),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        side: const BorderSide(
                            color: AppColors.outlineVariant),
                        padding:
                            const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.lg),
                        textStyle: AppTextStyles.labelMd
                            .copyWith(letterSpacing: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nuevaOrden,
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Nueva OC'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.onSecondary,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.lg),
                        textStyle: AppTextStyles.labelMd
                            .copyWith(letterSpacing: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniOrdRow(Map<String, dynamic> c) {
    final estado = c['estado'] as String? ?? '';
    final total = double.tryParse(c['total'].toString()) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['numero_orden'] ?? '—',
                  style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.secondary,
                      letterSpacing: 0.3,
                      fontSize: 11),
                ),
                Text(
                  '\$${ComprasTheme.fmt(total)}',
                  style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          _estadoBadge(estado),
        ],
      ),
    );
  }

  // ──────────────────────── TAB: ÓRDENES ────────────────────

  Widget _buildOrdenesTab(ProveedoresProvider prov) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildOrdenesTable(prov)),
          const SizedBox(width: 16),
          SizedBox(width: 280, child: _buildOrdenPanel()),
        ],
      ),
    );
  }

  Widget _buildOrdenesTable(ProveedoresProvider prov) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.xl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xl,
        child: Column(
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.surfaceContainerLow,
              child: Row(
                children: [
                  // Estado dropdown
                  Container(
                    height: 36,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      border: Border.all(color: AppColors.outlineVariant),
                      borderRadius: AppRadius.lg,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _filtroEstado,
                        hint: Text(
                          'Todos los estados',
                          style: AppTextStyles.bodyMd.copyWith(
                              fontSize: 12, color: AppColors.outline),
                        ),
                        style: AppTextStyles.bodyMd.copyWith(
                            fontSize: 12, color: AppColors.onSurface),
                        icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.outline),
                        onChanged: _setFiltroEstado,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              'Todos',
                              style: AppTextStyles.bodyMd
                                  .copyWith(fontSize: 12),
                            ),
                          ),
                          ...['pendiente', 'recibida', 'cancelada']
                              .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  Icon(ComprasTheme.iconEstado(e),
                                      size: 12,
                                      color:
                                          ComprasTheme.colorEstado(e)),
                                  const SizedBox(width: 5),
                                  Text(
                                    ComprasTheme.labelEstado(e),
                                    style: AppTextStyles.bodyMd
                                        .copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _nuevaOrden,
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Nueva Orden'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.lg),
                      textStyle: AppTextStyles.labelMd
                          .copyWith(letterSpacing: 0.2),
                    ),
                  ),
                ],
              ),
            ),
            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceContainerLow,
              child: Row(
                children: [
                  SizedBox(
                      width: 88,
                      child: Text('ORDER ID', style: _colHdrStyle)),
                  Expanded(
                      flex: 2,
                      child: Text('PROVEEDOR', style: _colHdrStyle)),
                  Expanded(
                      child: Text('FECHA', style: _colHdrStyle)),
                  Expanded(
                      child: Text('SUCURSAL', style: _colHdrStyle)),
                  SizedBox(
                      width: 88,
                      child: Text('TOTAL',
                          style: _colHdrStyle,
                          textAlign: TextAlign.right)),
                  SizedBox(
                      width: 80,
                      child: Text('ESTADO', style: _colHdrStyle)),
                  const SizedBox(width: 20),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outlineVariant),
            // Rows
            Expanded(
              child: prov.cargandoCompras
                  ? const Center(child: CircularProgressIndicator())
                  : prov.compras.isEmpty
                      ? _emptyState(
                          'No hay órdenes de compra',
                          Icons.shopping_cart_outlined,
                          _nuevaOrden,
                          'Crear orden',
                        )
                      : ListView.separated(
                          itemCount: prov.compras.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.outlineVariant),
                          itemBuilder: (_, i) =>
                              _buildOrdRow(prov.compras[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdRow(Map<String, dynamic> c) {
    final sel = _ordSel?['id'] == c['id'];
    final estado = c['estado'] as String? ?? '';
    final proveedor = c['proveedor_nombre'] as String? ?? '—';
    final total = double.tryParse(c['total'].toString()) ?? 0;
    final fechaRaw = c['fecha_orden']?.toString() ?? '';
    final fecha = fechaRaw.length >= 10 ? fechaRaw.substring(0, 10) : '—';
    final tienda = c['tienda_nombre'] as String? ?? '—';

    return InkWell(
      onTap: () => _selOrden(c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: sel
            ? AppColors.secondaryContainer.withOpacity(0.35)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Número orden
            SizedBox(
              width: 88,
              child: Text(
                c['numero_orden'] ?? '—',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.secondary,
                  letterSpacing: 0.2,
                  fontSize: 11,
                ),
              ),
            ),
            // Proveedor
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.secondaryContainer
                          : AppColors.surfaceContainerHighest,
                      borderRadius: AppRadius.sm,
                    ),
                    child: Center(
                      child: Text(
                        proveedor.isNotEmpty
                            ? proveedor[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.labelSm.copyWith(
                          color: sel
                              ? AppColors.onSecondaryContainer
                              : AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      proveedor,
                      style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w700, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Fecha
            Expanded(
              child: Text(
                fecha,
                style: AppTextStyles.bodyMd.copyWith(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ),
            // Sucursal
            Expanded(
              child: Text(
                tienda,
                style: AppTextStyles.bodyMd.copyWith(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Total
            SizedBox(
              width: 88,
              child: Text(
                '\$${ComprasTheme.fmt(total)}',
                style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w700, fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
            // Estado
            SizedBox(width: 80, child: _estadoBadge(estado)),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: sel ? AppColors.secondary : AppColors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ── Panel orden ───────────────────────────────────────────

  Widget _buildOrdenPanel() {
    if (_ordSel == null) {
      return _emptyPanel(
        icon: Icons.receipt_long_outlined,
        message: 'Selecciona una orden\npara ver su resumen',
      );
    }

    final c = _ordSel!;
    final estado = c['estado'] as String? ?? '';
    final total = double.tryParse(c['total'].toString()) ?? 0;
    final fechaRaw = c['fecha_orden']?.toString() ?? '';
    final fecha = fechaRaw.length >= 10 ? fechaRaw.substring(0, 10) : '—';

    final detalles = (_ordDetalle?['detalles'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.xl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xl,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de orden',
                    style: AppTextStyles.labelSm
                        .copyWith(letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c['numero_orden'] ?? '—',
                          style: AppTextStyles.headlineSm.copyWith(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      _estadoBadge(estado),
                    ],
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Proveedor'),
                              Text(
                                c['proveedor_nombre'] ?? '—',
                                style: AppTextStyles.bodyMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Fecha'),
                              Text(
                                fecha,
                                style: AppTextStyles.bodyMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoRow('Sucursal', _valOrDash(c['tienda_nombre'])),
                    _infoRow('Empleado', _valOrDash(c['empleado_nombre'])),
                    const SizedBox(height: 10),
                    const Divider(color: AppColors.outlineVariant),
                    const SizedBox(height: 6),
                    _sectionLabel(
                        'Productos${detalles.isNotEmpty ? " (${detalles.length})" : ""}'),
                    if (_cargandoOrdDetalle)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (detalles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextButton.icon(
                          onPressed: () =>
                              _verDetalleOrden(c['id'] as int),
                          icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 13),
                          label:
                              const Text('Cargar en detalle completo'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            padding: EdgeInsets.zero,
                            textStyle: AppTextStyles.labelMd.copyWith(
                                letterSpacing: 0.2, fontSize: 11),
                          ),
                        ),
                      )
                    else
                      ...detalles.map((d) => _detalleItemRow(d)),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.outlineVariant)),
                color: AppColors.surfaceContainerLow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: AppTextStyles.headlineSm.copyWith(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '\$${ComprasTheme.fmt(total)}',
                        style: AppTextStyles.numericData
                            .copyWith(fontSize: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (estado == 'pendiente') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelarOrden(c),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 13),
                            label: const Text('Cancelar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                  color: AppColors.error
                                      .withOpacity(0.5)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.lg),
                              textStyle: AppTextStyles.labelMd.copyWith(
                                  letterSpacing: 0.2, fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _recibirOrden(c),
                            icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 13),
                            label: const Text('Recibir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: AppColors.onSecondary,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.lg),
                              textStyle: AppTextStyles.labelMd.copyWith(
                                  letterSpacing: 0.2, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _verDetalleOrden(c['id'] as int),
                      icon: const Icon(Icons.open_in_new_rounded,
                          size: 13),
                      label: const Text('Ver detalle completo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        side: const BorderSide(
                            color: AppColors.outlineVariant),
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.lg),
                        textStyle: AppTextStyles.labelMd.copyWith(
                            letterSpacing: 0.2, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detalleItemRow(Map<String, dynamic> d) {
    final nombre = d['producto_nombre'] ?? d['nombre_libre'] ?? '—';
    final cantidad =
        double.tryParse(d['cantidad']?.toString() ?? '0') ?? 0;
    final precio =
        double.tryParse(d['precio_unitario']?.toString() ?? '0') ?? 0;
    final sub = double.tryParse(d['subtotal']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.toString(),
                  style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w700, fontSize: 11),
                ),
                Text(
                  '${cantidad.toStringAsFixed(cantidad.truncateToDouble() == cantidad ? 0 : 1)} uds'
                  ' × \$${ComprasTheme.fmt(precio)}',
                  style: AppTextStyles.bodySm.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '\$${ComprasTheme.fmt(sub)}',
            style: AppTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────

  Widget _activoChip(bool activo) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: activo
              ? AppColors.secondaryContainer
              : AppColors.surfaceContainerHighest,
          borderRadius: AppRadius.full,
        ),
        child: Text(
          activo ? 'Activo' : 'Inactivo',
          style: AppTextStyles.labelSm.copyWith(
            color: activo
                ? AppColors.onSecondaryContainer
                : AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      );

  Widget _estadoBadge(String estado) {
    late Color bg, fg;
    switch (estado) {
      case 'pendiente':
        bg = const Color(0xFFDAE2FD);
        fg = const Color(0xFF3B4BA0);
        break;
      case 'recibida':
        bg = AppColors.secondaryContainer;
        fg = AppColors.onSecondaryContainer;
        break;
      case 'cancelada':
        bg = AppColors.errorContainer;
        fg = AppColors.onErrorContainer;
        break;
      default:
        bg = AppColors.surfaceContainerHighest;
        fg = AppColors.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.full),
      child: Text(
        ComprasTheme.labelEstado(estado),
        style: AppTextStyles.labelSm
            .copyWith(color: fg, fontSize: 10, letterSpacing: 0.4),
      ),
    );
  }

  Widget _emptyPanel({required IconData icon, required String message}) =>
      Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: AppRadius.xl,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: AppColors.outlineVariant),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      );

  Widget _emptyState(
    String msg,
    IconData icon,
    VoidCallback onAction,
    String btnLabel,
  ) =>
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppColors.outlineVariant),
            const SizedBox(height: 10),
            Text(msg, style: AppTextStyles.bodySm),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 14),
              label: Text(btnLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(borderRadius: AppRadius.lg),
                textStyle:
                    AppTextStyles.labelMd.copyWith(letterSpacing: 0.2),
              ),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSm.copyWith(
              letterSpacing: 0.8, fontSize: 10, color: AppColors.outline),
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant),
              ),
            ),
            Text(
              value,
              style: AppTextStyles.bodyMd.copyWith(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );

  TextStyle get _colHdrStyle => AppTextStyles.labelSm.copyWith(
        letterSpacing: 0.8,
        fontSize: 10,
        color: AppColors.outline,
      );

  String _valOrDash(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  // ── Cuentas por Pagar Tab ─────────────────────────────────

  Widget _buildCuentasPagarTab() {
    final fmt     = NumberFormat('#,##0', 'es_CO');
    final fmtDate = DateFormat('d MMM yyyy', 'es');
    const green   = Color(0xFF16A34A);
    const greenBg = Color(0xFFDCFCE7);
    const red     = Color(0xFFDC2626);
    const redBg   = Color(0xFFFEE2E2);
    const amber   = Color(0xFFD97706);
    const amberBg = Color(0xFFFEF3C7);
    const border  = Color(0xFFE2E8F0);
    const card    = Color(0xFFF8FAFC);
    const text    = Color(0xFF1E293B);
    const muted   = Color(0xFF64748B);

    if (_cargandoCuentas) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cuentasPagar.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, size: 56, color: green),
        const SizedBox(height: 12),
        Text('Sin deudas pendientes con proveedores',
            style: GoogleFonts.inter(fontSize: 15, color: muted)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _cargarCuentasPagar,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Actualizar'),
        ),
      ]));
    }

    final vencidas = _cuentasPagar.where((c) => c['vencida'] == true).length;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cuentasPagar.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          // Resumen banner
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Row(children: [
                _cpKpi('\$ Total adeudado', '\$${fmt.format(_totalDeuda)}',
                    red, redBg),
                const SizedBox(width: 10),
                _cpKpi('Compras pendientes',
                    '${_cuentasPagar.length}', amber, amberBg),
                const SizedBox(width: 10),
                _cpKpi('Vencidas', '$vencidas',
                    vencidas > 0 ? red : green,
                    vencidas > 0 ? redBg : greenBg),
              ]),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _cargarCuentasPagar,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text('Actualizar',
                      style: GoogleFonts.inter(fontSize: 12)),
                ),
              ),
            ]),
          );
        }

        final c          = _cuentasPagar[i - 1];
        final total      = (c['total'] as num).toDouble();
        final vencida    = c['vencida'] as bool;
        final diasVenc   = c['dias_vencido'] as int?;
        final fVenc      = c['fecha_vencimiento'] as String?;
        final id         = c['id'] as int;
        final marcando   = _marcandoPagada == id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
                color: vencida ? red.withAlpha(80) : border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: vencida ? redBg : amberBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vencida
                        ? 'Vencida ${diasVenc != null ? "($diasVenc días)" : ""}'
                        : 'Pendiente',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: vencida ? red : amber),
                  ),
                ),
                const Spacer(),
                Text('\$${fmt.format(total)}',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: text)),
              ]),
              const SizedBox(height: 8),
              Text(c['proveedor_nombre'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: text)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.receipt_long, size: 12, color: muted),
                const SizedBox(width: 4),
                Text('Orden ${c['numero_orden']}',
                    style: GoogleFonts.inter(fontSize: 12, color: muted)),
                const SizedBox(width: 12),
                if (c['tienda_nombre'] != null) ...[
                  const Icon(Icons.store, size: 12, color: muted),
                  const SizedBox(width: 4),
                  Text(c['tienda_nombre'] as String,
                      style: GoogleFonts.inter(fontSize: 12, color: muted)),
                ],
              ]),
              if (fVenc != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.event, size: 12,
                      color: vencida ? red : muted),
                  const SizedBox(width: 4),
                  Text(
                    'Vence: ${fmtDate.format(DateTime.parse(fVenc))}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: vencida ? red : muted),
                  ),
                ]),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: marcando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _marcarPagada(c),
                        icon: const Icon(Icons.check, size: 14),
                        label: Text('Marcar pagada',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _cpKpi(String label, String value, Color color, Color bg) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(height: 3),
        Text(value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800,
                color: color),
            overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}
