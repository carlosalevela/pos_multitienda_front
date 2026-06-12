// lib/screens/empresa/config_mayoreo_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/proveedores_provider.dart';

class ConfigMayoreoScreen extends StatefulWidget {
  const ConfigMayoreoScreen({super.key});

  @override
  State<ConfigMayoreoScreen> createState() => _ConfigMayoreoScreenState();
}

class _ConfigMayoreoScreenState extends State<ConfigMayoreoScreen> {
  final _ctrlCantidad = TextEditingController();
  bool  _manejaM      = false;
  bool  _cargando     = true;
  bool  _guardando    = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _ctrlCantidad.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final auth      = context.read<AuthProvider>();
    final provider  = context.read<ProveedoresProvider>();
    final empresaId = int.tryParse(auth.empresaId) ?? 0;

    if (empresaId == 0) {
      setState(() => _cargando = false);
      return;
    }

    await provider.cargarConfigMayoreo(empresaId);
    if (!mounted) return;

    setState(() {
      _manejaM           = provider.manejaM;
      _ctrlCantidad.text = provider.cantidadM.toString();
      _cargando          = false;
    });
  }

  Future<void> _guardar() async {
    final auth      = context.read<AuthProvider>();
    final provider  = context.read<ProveedoresProvider>();
    final empresaId = int.tryParse(auth.empresaId) ?? 0;

    final cantidad = int.tryParse(_ctrlCantidad.text.trim()) ?? 0;
    if (_manejaM && cantidad < 2) {
      _snack('La cantidad mínima debe ser al menos 2 unidades.',
          Colors.red.shade600);
      return;
    }

    setState(() => _guardando = true);
    final error = await provider.guardarConfigMayoreo(
      empresaId,
      manejaM:   _manejaM,
      cantidadM: cantidad,
    );
    if (!mounted) return;
    setState(() => _guardando = false);

    error == null
        ? _snack('Configuración guardada ✅', Colors.green.shade600)
        : _snack(error, Colors.red.shade600);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.esAdmin && !auth.esSuperadmin) {
      return const Scaffold(
        body: Center(
            child: Text('No tienes permiso para ver esta sección.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Precios al por mayor',
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Card principal ──────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [

                        // Toggle ON/OFF
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _manejaM
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.store_mall_directory_rounded,
                                color: _manejaM
                                    ? Colors.green.shade600
                                    : Colors.grey.shade400,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Manejar precios al por mayor',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                  Text(
                                    'Activa precios especiales por volumen',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _manejaM,
                              activeColor: Colors.green.shade600,
                              onChanged: (v) =>
                                  setState(() => _manejaM = v),
                            ),
                          ]),
                        ),

                        // Campo cantidad — animado
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 250),
                          crossFadeState: _manejaM
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: Column(children: [
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [

                                  // Banner info
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.amber.shade200),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.info_outline_rounded,
                                          size: 16,
                                          color: Colors.amber.shade700),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Desde esta cantidad en adelante '
                                          'se aplica el precio mayoreo '
                                          'en cada producto.',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color:
                                                  Colors.amber.shade800),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(height: 16),

                                  Text(
                                    'Cantidad mínima para mayoreo',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),

                                  // Stepper + input
                                  Row(children: [
                                    _BtnStepper(
                                      icon: Icons.remove_rounded,
                                      onTap: () {
                                        final v = int.tryParse(
                                                _ctrlCantidad.text) ??
                                            2;
                                        if (v > 2) {
                                          setState(() =>
                                              _ctrlCantidad.text =
                                                  (v - 1).toString());
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _ctrlCantidad,
                                        textAlign: TextAlign.center,
                                        keyboardType:
                                            TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly
                                        ],
                                        style: GoogleFonts.poppins(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87),
                                        decoration: InputDecoration(
                                          hintText: '12',
                                          suffixText: 'unidades',
                                          suffixStyle:
                                              GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors
                                                      .grey.shade500),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    10),
                                            borderSide: BorderSide(
                                                color:
                                                    Colors.grey.shade300),
                                          ),
                                          focusedBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    10),
                                            borderSide: BorderSide(
                                                color: Colors
                                                    .green.shade400,
                                                width: 2),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _BtnStepper(
                                      icon: Icons.add_rounded,
                                      onTap: () {
                                        final v = int.tryParse(
                                                _ctrlCantidad.text) ??
                                            2;
                                        setState(() =>
                                            _ctrlCantidad.text =
                                                (v + 1).toString());
                                      },
                                    ),
                                  ]),
                                  const SizedBox(height: 12),

                                  // Chips rápidos
                                  Text('Valores comunes:',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey.shade500)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [6, 12, 24, 48]
                                        .map((v) => _ChipCantidad(
                                              valor: v,
                                              seleccionado:
                                                  _ctrlCantidad.text ==
                                                      v.toString(),
                                              onTap: () => setState(
                                                  () => _ctrlCantidad
                                                      .text =
                                                      v.toString()),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                          secondChild: const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Nota informativa ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Esta configuración aplica a toda la empresa. '
                            'El precio mayoreo de cada producto se puede '
                            'ajustar al registrar o editar el producto.',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Botón guardar ───────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : Text(
                              'Guardar configuración',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Botón stepper +/- ──────────────────────────────────────
class _BtnStepper extends StatelessWidget {
  const _BtnStepper({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

// ── Chip de cantidad rápida ────────────────────────────────
class _ChipCantidad extends StatelessWidget {
  const _ChipCantidad({
    required this.valor,
    required this.seleccionado,
    required this.onTap,
  });
  final int          valor;
  final bool         seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado
              ? Colors.green.shade600
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado
                ? Colors.green.shade600
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          '$valor uds',
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color:
                  seleccionado ? Colors.white : Colors.black54),
        ),
      ),
    );
  }
}