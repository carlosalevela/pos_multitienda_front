// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/empleado_service.dart';
import 'widgets/empleado_form_dialog.dart';

// ── palette (mirrors admin dashboard) ─────────────────────────────────────────
class _C {
  static const bg          = Color(0xFFF5F7F8);
  static const surface     = Color(0xFFFFFFFF);
  static const border      = Color(0xFFE5E7EB);
  static const divider     = Color(0xFFEEF1F4);
  static const textPrimary = Color(0xFF111827);
  static const textSecond  = Color(0xFF6B7280);
  static const textFaint   = Color(0xFF9CA3AF);
  static const green       = Color(0xFF61DDAA);
  static const greenLight  = Color(0xFFE8FFF4);
  static const greenDark   = Color(0xFF0B7A53);
  static const amber       = Color(0xFFB45309);
  static const amberLight  = Color(0xFFFEF3C7);
  static const rose        = Color(0xFFBE123C);
  static const roseLight   = Color(0xFFFFF1F2);
  static const indigo      = Color(0xFF3730A3);
  static const indigoLight = Color(0xFFEEF2FF);
  static const purple      = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF5F3FF);
}

class EmpleadosScreen extends StatefulWidget {
  const EmpleadosScreen({super.key});

  @override
  State<EmpleadosScreen> createState() => _EmpleadosScreenState();
}

class _EmpleadosScreenState extends State<EmpleadosScreen> {
  final _service = EmpleadoService();

  List<Map<String, dynamic>> _empleados = [];
  bool   _cargando    = false;
  String _successMsg  = '';
  String _errorMsg    = '';

  String _query        = '';
  String _filtroRol    = 'todos';   // todos / admin / supervisor / cajero
  String _filtroActivo = 'activos'; // todos / activos / inactivos

  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
  }

  Future<void> _cargarEmpleados() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final result = await _service.getEmpleados();
      if (!mounted) return;
      setState(() { _empleados = result; _cargando = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _cargando = false; _errorMsg = 'Error al cargar empleados'; });
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _query.toLowerCase();
    return _empleados.where((e) {
      final nombre = '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}'.toLowerCase();
      final email  = (e['email']  ?? '').toString().toLowerCase();
      final cedula = (e['cedula'] ?? '').toString().toLowerCase();
      if (q.isNotEmpty && !nombre.contains(q) && !email.contains(q) && !cedula.contains(q)) return false;
      if (_filtroRol    != 'todos'    && e['rol']   != _filtroRol) return false;
      if (_filtroActivo == 'activos'  && !(e['activo'] ?? true))   return false;
      if (_filtroActivo == 'inactivos' && (e['activo'] ?? true))   return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total      = _empleados.length;
    final activos    = _empleados.where((e) => e['activo'] == true).length;
    final cajeros    = _empleados.where((e) => e['rol'] == 'cajero').length;
    final supervisores = _empleados.where((e) => e['rol'] == 'supervisor').length;
    final filtrados  = _filtrados;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _C.indigoLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.people_rounded, color: _C.indigo, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Empleados', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: _C.textPrimary)),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: Text('Nuevo', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            onPressed: () => _abrirFormulario(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.indigo, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // KPI strip
        Row(children: [
          _kpiChip('Total',       '$total',       Icons.people_outline_rounded,      _C.indigo,   _C.indigoLight),
          const SizedBox(width: 10),
          _kpiChip('Activos',     '$activos',     Icons.check_circle_outline_rounded, _C.greenDark, _C.greenLight),
          const SizedBox(width: 10),
          _kpiChip('Cajeros',     '$cajeros',     Icons.point_of_sale_outlined,       _C.amber,    _C.amberLight),
          const SizedBox(width: 10),
          _kpiChip('Supervisores','$supervisores', Icons.manage_accounts_outlined,     _C.purple,   _C.purpleLight),
        ]),
        const SizedBox(height: 16),

        // Search bar
        Container(
          height: 40,
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.inter(fontSize: 13, color: _C.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, email o cédula…',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: _C.textFaint),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _C.textFaint),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Text('Rol:', style: GoogleFonts.inter(fontSize: 11, color: _C.textFaint, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            _segmentedFilter(
              options: ['todos', 'cajero', 'supervisor', 'admin'],
              labels:  ['Todos', 'Cajeros', 'Supervisores', 'Admins'],
              current: _filtroRol,
              onSelect: (v) => setState(() => _filtroRol = v),
            ),
            const SizedBox(width: 16),
            Text('Estado:', style: GoogleFonts.inter(fontSize: 11, color: _C.textFaint, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            _segmentedFilter(
              options: ['todos', 'activos', 'inactivos'],
              labels:  ['Todos', 'Activos', 'Inactivos'],
              current: _filtroActivo,
              onSelect: (v) => setState(() => _filtroActivo = v),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Banners
        if (_successMsg.isNotEmpty) _banner(_successMsg, isError: false),
        if (_errorMsg.isNotEmpty)   _banner(_errorMsg,   isError: true),

        // Grid de cards
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : filtrados.isEmpty
                  ? _emptyState()
                  : LayoutBuilder(builder: (_, c) {
                      final cols = c.maxWidth >= 1200 ? 3 : c.maxWidth >= 700 ? 2 : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 172,
                        ),
                        itemCount: filtrados.length,
                        itemBuilder: (_, i) => _EmpleadoCard(
                          empleado: filtrados[i],
                          onEditar:  () => _abrirFormulario(empleado: filtrados[i]),
                          onToggle:  () => _confirmarDesactivar(filtrados[i]),
                          onResetPw: () => _resetPasswordDialog(filtrados[i]),
                        ),
                      );
                    }),
        ),
      ]),
    );
  }

  // ── helpers de UI ──────────────────────────────────────────────────────────

  Widget _kpiChip(String label, String value, IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: color.withOpacity(0.7), fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }

  Widget _segmentedFilter({required List<String> options, required List<String> labels, required String current, required void Function(String) onSelect}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _C.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(options.length, (i) {
        final active = current == options[i];
        return GestureDetector(
          onTap: () => onSelect(options[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active ? _C.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))] : [],
            ),
            child: Text(labels[i], style: GoogleFonts.inter(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? _C.textPrimary : _C.textFaint)),
          ),
        );
      })),
    );
  }

  Widget _banner(String msg, {required bool isError}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? _C.roseLight : _C.greenLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isError ? _C.rose.withOpacity(0.3) : _C.green.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: isError ? _C.rose : _C.greenDark, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: GoogleFonts.inter(color: isError ? _C.rose : _C.greenDark, fontSize: 12, fontWeight: FontWeight.w600))),
        GestureDetector(
          onTap: () => setState(() { _successMsg = ''; _errorMsg = ''; }),
          child: const Icon(Icons.close_rounded, size: 14, color: _C.textFaint),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    final filtered = _query.isNotEmpty || _filtroRol != 'todos' || _filtroActivo != 'activos';
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(color: _C.indigoLight, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.people_outline_rounded, size: 26, color: _C.indigo)),
      const SizedBox(height: 14),
      Text(filtered ? 'Sin resultados para este filtro' : 'No hay empleados registrados', style: GoogleFonts.inter(color: _C.textFaint, fontSize: 14)),
      if (filtered) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() { _query = ''; _filtroRol = 'todos'; _filtroActivo = 'activos'; }),
          child: Text('Limpiar filtros', style: GoogleFonts.inter(fontSize: 12, color: _C.indigo)),
        ),
      ],
    ]));
  }

  // ── acciones ───────────────────────────────────────────────────────────────

  void _abrirFormulario({Map<String, dynamic>? empleado}) {
    showDialog(
      context: context,
      builder: (_) => EmpleadoFormDialog(
        empleado: empleado,
        onGuardar: (data) async {
          final result = empleado == null
              ? await _service.crearEmpleado(
                  nombre: data['nombre'], apellido: data['apellido'],
                  cedula: data['cedula'], email: data['email'],
                  password: data['password'], rol: data['rol'],
                  tiendaId: data['tienda'], empresaId: data['empresa'],
                )
              : await _service.editarEmpleado(empleado['id'], data);

          if (result['success'] != true) throw Exception(result['error'] ?? 'Error desconocido');
          if (mounted) {
            setState(() { _successMsg = empleado == null ? 'Empleado creado' : 'Empleado actualizado'; _errorMsg = ''; });
            await _cargarEmpleados();
          }
        },
      ),
    );
  }

  void _confirmarDesactivar(Map<String, dynamic> e) {
    final activo = e['activo'] ?? true;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(activo ? '¿Desactivar empleado?' : '¿Activar empleado?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('${e['nombre']} ${e['apellido']}', style: GoogleFonts.inter(fontSize: 14, color: _C.textSecond)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () async {
              final result = await _service.editarEmpleado(e['id'], {'activo': !activo});
              if (!context.mounted) return;
              Navigator.pop(context);
              if (result['success'] == true) {
                setState(() { _successMsg = activo ? 'Empleado desactivado' : 'Empleado activado'; _errorMsg = ''; });
                await _cargarEmpleados();
              } else {
                setState(() { _errorMsg = result['error'] ?? 'Error'; _successMsg = ''; });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: activo ? _C.rose : _C.greenDark, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(activo ? 'Desactivar' : 'Activar', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  void _resetPasswordDialog(Map<String, dynamic> e) {
    final ctrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Restablecer contraseña', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e['nombre']} ${e['apellido']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _C.textSecond)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              obscureText: obscure,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                labelStyle: GoogleFonts.inter(fontSize: 13, color: _C.textSecond),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                  onPressed: () => setLocal(() => obscure = !obscure),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Mínimo 6 caracteres', style: GoogleFonts.inter(fontSize: 11, color: _C.textFaint)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: GoogleFonts.inter())),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().length < 6) return;
                final result = await _service.editarEmpleado(e['id'], {'password': ctrl.text.trim()});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                setState(() {
                  if (result['success'] == true) { _successMsg = 'Contraseña restablecida'; _errorMsg = ''; }
                  else { _errorMsg = result['error'] ?? 'Error al restablecer'; _successMsg = ''; }
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: _C.indigo, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('Restablecer', style: GoogleFonts.inter()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empleado Card ──────────────────────────────────────────────────────────────

class _EmpleadoCard extends StatelessWidget {
  final Map<String, dynamic> empleado;
  final VoidCallback onEditar;
  final VoidCallback onToggle;
  final VoidCallback onResetPw;
  const _EmpleadoCard({required this.empleado, required this.onEditar, required this.onToggle, required this.onResetPw});

  Color  _rolColor(String? r) => r == 'admin' ? _C.indigo : r == 'supervisor' ? _C.amber : r == 'cajero' ? _C.greenDark : _C.textFaint;
  Color  _rolBg(String? r)    => r == 'admin' ? _C.indigoLight : r == 'supervisor' ? _C.amberLight : r == 'cajero' ? _C.greenLight : _C.bg;
  String _rolLabel(String? r) => r == 'admin' ? 'ADMIN' : r == 'supervisor' ? 'SUPERVISOR' : r == 'cajero' ? 'CAJERO' : (r ?? '').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final nombre  = '${empleado['nombre'] ?? ''} ${empleado['apellido'] ?? ''}'.trim();
    final email   = (empleado['email'] ?? '').toString();
    final tienda  = (empleado['tienda_nombre'] ?? 'Sin tienda').toString();
    final rol     = empleado['rol'] as String?;
    final activo  = empleado['activo'] ?? true;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: activo ? _C.border : _C.border.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Avatar + nombre + estado
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _rolBg(rol), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(inicial, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _rolColor(rol)))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: activo ? _C.textPrimary : _C.textFaint), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(email, style: GoogleFonts.inter(fontSize: 10, color: _C.textFaint), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: activo ? _C.greenLight : _C.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activo ? _C.green.withOpacity(0.3) : _C.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 5, height: 5, decoration: BoxDecoration(color: activo ? _C.green : _C.textFaint, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(activo ? 'Activo' : 'Inactivo', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: activo ? _C.greenDark : _C.textFaint)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Divider(color: _C.divider, height: 1),
        const SizedBox(height: 10),

        // Rol + tienda
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: _rolBg(rol), borderRadius: BorderRadius.circular(4)),
            child: Text(_rolLabel(rol), style: GoogleFonts.inter(color: _rolColor(rol), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.store_outlined, size: 11, color: _C.textFaint),
          const SizedBox(width: 4),
          Expanded(child: Text(tienda, style: GoogleFonts.inter(fontSize: 11, color: _C.textSecond), overflow: TextOverflow.ellipsis)),
        ]),

        const Spacer(),

        // Botones de acción
        Row(children: [
          _actionBtn(icon: Icons.edit_rounded,        tooltip: 'Editar',             color: _C.indigo,    onTap: onEditar),
          const SizedBox(width: 6),
          _actionBtn(icon: Icons.lock_reset_rounded,  tooltip: 'Reset contraseña',   color: _C.amber,     onTap: onResetPw),
          const SizedBox(width: 6),
          _actionBtn(
            icon:    activo ? Icons.person_off_rounded : Icons.person_rounded,
            tooltip: activo ? 'Desactivar' : 'Activar',
            color:   activo ? _C.rose : _C.greenDark,
            onTap:   onToggle,
          ),
        ]),
      ]),
    );
  }

  Widget _actionBtn({required IconData icon, required String tooltip, required Color color, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
