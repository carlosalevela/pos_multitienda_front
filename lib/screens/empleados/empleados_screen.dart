import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../services/empleado_service.dart';
import 'widgets/empleado_form_dialog.dart';

class EmpleadosScreen extends StatefulWidget {
  const EmpleadosScreen({super.key});

  @override
  State<EmpleadosScreen> createState() => _EmpleadosScreenState();
}

class _EmpleadosScreenState extends State<EmpleadosScreen> {
  final _service = EmpleadoService();
  List<Map<String, dynamic>> _empleados = [];
  bool _cargando = false;
  String _successMsg = '';
  String _errorMsg = '';

  int? _empresaIdActiva;

  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
  }

  Future<void> _cargarEmpleados() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final empleados = await _service.getEmpleados(
        empresaId: _empresaIdActiva,
      );

      if (!mounted) return;
      setState(() {
        _empleados = empleados;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorMsg = 'Error al cargar empleados';
        _successMsg = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(Constants.primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_rounded,
                  color: Color(Constants.primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Empleados',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_rounded),
                label: Text(
                  'Nuevo Empleado',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                onPressed: () => _abrirFormulario(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(Constants.primaryColor),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_successMsg.isNotEmpty) _banner(_successMsg, isError: false),
          if (_errorMsg.isNotEmpty) _banner(_errorMsg, isError: true),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _empleados.isEmpty
                    ? _emptyState()
                    : _buildTabla(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabla() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1A2E)),
            headingTextStyle: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            dataTextStyle: GoogleFonts.poppins(fontSize: 13),
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Cédula')),
              DataColumn(label: Text('Rol')),
              DataColumn(label: Text('Tienda')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: _empleados.map((e) => _buildRow(e)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> e) {
    final activo = e['activo'] ?? true;

    return DataRow(
      cells: [
        DataCell(
          Text(
            '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text((e['email'] ?? '').toString())),
        DataCell(Text((e['cedula'] ?? '').toString())),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _rolColor(e['rol']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (e['rol'] ?? '').toString().toUpperCase(),
              style: GoogleFonts.poppins(
                color: _rolColor(e['rol']),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(Text((e['tienda_nombre'] ?? 'Sin tienda').toString())),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: activo ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              activo ? '✅ Activo' : '❌ Inactivo',
              style: GoogleFonts.poppins(
                color: activo ? Colors.green.shade700 : Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  color: Color(Constants.primaryColor),
                  size: 18,
                ),
                tooltip: 'Editar',
                onPressed: () => _abrirFormulario(empleado: e),
              ),
              IconButton(
                icon: Icon(
                  activo ? Icons.person_off_rounded : Icons.person_rounded,
                  color: activo ? Colors.redAccent : Colors.green,
                  size: 18,
                ),
                tooltip: activo ? 'Desactivar' : 'Activar',
                onPressed: () => _confirmarDesactivar(e),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _rolColor(String? rol) {
    switch (rol) {
      case 'admin':
        return const Color(Constants.primaryColor);
      case 'supervisor':
        return Colors.orange;
      case 'cajero':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _abrirFormulario({Map<String, dynamic>? empleado}) {
    showDialog(
      context: context,
      builder: (_) => EmpleadoFormDialog(
        empleado: empleado,
        onGuardar: (data) async {
          final result = empleado == null
              ? await _service.crearEmpleado(
                  nombre: data['nombre'],
                  apellido: data['apellido'],
                  cedula: data['cedula'],
                  email: data['email'],
                  password: data['password'],
                  rol: data['rol'],
                  tiendaId: data['tienda'],
                  empresaId: data['empresa'],
                )
              : await _service.editarEmpleado(empleado['id'], data);

          if (result['success'] != true) {
            throw Exception(result['error'] ?? 'Error desconocido');
          }

          if (mounted) {
            setState(() {
              _successMsg = empleado == null
                  ? '✅ Empleado creado correctamente'
                  : '✅ Empleado actualizado';
              _errorMsg = '';
            });
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
        title: Text(
          activo ? '¿Desactivar empleado?' : '¿Activar empleado?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${e['nombre']} ${e['apellido']}',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await _service.editarEmpleado(
                e['id'],
                {'activo': !activo},
              );

              if (!context.mounted) return;
              Navigator.pop(context);

              if (result['success'] == true) {
                setState(() {
                  _successMsg = activo
                      ? '❌ Empleado desactivado'
                      : '✅ Empleado activado';
                  _errorMsg = '';
                });
                await _cargarEmpleados();
              } else {
                setState(() {
                  _errorMsg = result['error'] ?? 'Error al cambiar estado';
                  _successMsg = '';
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: activo ? Colors.redAccent : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(activo ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No hay empleados registrados',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade400,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String msg, {required bool isError}) {
    return Container(
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
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError
                ? const Color(Constants.errorColor)
                : Colors.green.shade700,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.poppins(
                color: isError
                    ? const Color(Constants.errorColor)
                    : Colors.green.shade700,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => setState(() {
              _successMsg = '';
              _errorMsg = '';
            }),
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}