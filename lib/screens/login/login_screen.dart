// lib/screens/login/login_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────
// PALETA — consistente con admin_dashboard / cajero_dashboard
// ─────────────────────────────────────────────────────────────
class _C {
  // Fondo general y paneles
  static const bodyBg      = Color(0xFFF5F7F8);
  static const leftBg      = Color(0xFFF0FDF4);
  static const leftBorder  = Color(0xFFBBF7D0);
  static const rightBg     = Color(0xFFFFFFFF);

  // Textos
  static const textPrimary = Color(0xFF111827);
  static const textSecond  = Color(0xFF6B7280);
  static const textHint    = Color(0xFF9CA3AF);

  // Verde marca (= _C.green / greenDark del dashboard)
  static const green       = Color(0xFF61DDAA);
  static const greenDark   = Color(0xFF0B7A53);
  static const greenLight  = Color(0xFFE8FFF4);
  static const greenBorder = Color(0xFF61DDAA);

  // Índigo (reportes)
  static const indigo      = Color(0xFF3730A3);
  static const indigoLight = Color(0xFFEEF2FF);
  static const indigoBorder= Color(0xFFA5B4FC);

  // Ámbar (cambios)
  static const amber       = Color(0xFFB45309);
  static const amberLight  = Color(0xFFFEF3C7);
  static const amberBorder = Color(0xFFFCD34D);

  // Morado (roles)
  static const purple      = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF5F3FF);
  static const purpleBorder= Color(0xFFC4B5FD);

  // Inputs / error
  static const surface     = Color(0xFFF5F7FA);
  static const borderColor = Color(0xFFE2E8F0);
  static const error       = Color(0xFFD32F2F);
}

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _userCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _passFocus = FocusNode();
  bool  _obscure   = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthProvider>().clearError();
    await context.read<AuthProvider>().login(
      _userCtrl.text.trim(),
      _passCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final isWide = MediaQuery.of(context).size.width > 780;

    final formPanel = _FormPanel(
      formKey:         _formKey,
      userCtrl:        _userCtrl,
      passCtrl:        _passCtrl,
      passFocus:       _passFocus,
      obscure:         _obscure,
      auth:            auth,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onLogin:         _login,
    );

    return Scaffold(
      backgroundColor: _C.bodyBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1060),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: isWide
                  ? SizedBox(
                      height: 660,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 46, child: const _LeftPanel()),
                          Expanded(flex: 54, child: formPanel),
                        ],
                      ),
                    )
                  : formPanel,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL IZQUIERDO
// ─────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.leftBg,
        border: Border(right: BorderSide(color: _C.leftBorder, width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Logo
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _C.greenLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.greenBorder, width: 1.5),
              ),
              child: const Icon(Icons.storefront_rounded,
                  size: 17, color: _C.greenDark),
            ),
            const SizedBox(width: 10),
            Text('SIS · POS',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: _C.textSecond)),
          ]),

          const SizedBox(height: 28),

          // Headline
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -1.0),
              children: const [
                TextSpan(text: 'POS\n', style: TextStyle(color: _C.textPrimary)),
                TextSpan(text: 'MULTI',
                    style: TextStyle(color: _C.greenDark)),
                TextSpan(text: 'TIENDA',
                    style: TextStyle(
                        color: _C.textHint,
                        fontWeight: FontWeight.w300)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Plataforma unificada de ventas, inventario\ny reportes para tu negocio.',
            style: GoogleFonts.inter(
                fontSize: 12, color: _C.textSecond, height: 1.5),
          ),

          const SizedBox(height: 20),

          // Grid de módulos 3×2
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: const [
              _ModuleCard(
                icon: Icons.point_of_sale_rounded,
                label: 'Punto\nde venta',
                bg: _C.greenLight,
                border: _C.greenBorder,
                iconColor: _C.greenDark,
              ),
              _ModuleCard(
                icon: Icons.inventory_2_rounded,
                label: 'Inventario\n& Stock',
                bg: _C.greenLight,
                border: _C.greenBorder,
                iconColor: _C.greenDark,
              ),
              _ModuleCard(
                icon: Icons.bar_chart_rounded,
                label: 'Reportes\n& Cierre',
                bg: _C.indigoLight,
                border: _C.indigoBorder,
                iconColor: _C.indigo,
              ),
              _ModuleCard(
                icon: Icons.swap_horiz_rounded,
                label: 'Cambios\n& Devol.',
                bg: _C.amberLight,
                border: _C.amberBorder,
                iconColor: _C.amber,
              ),
              _ModuleCard(
                icon: Icons.store_rounded,
                label: 'Multi\ntienda',
                bg: _C.greenLight,
                border: _C.greenBorder,
                iconColor: _C.greenDark,
              ),
              _ModuleCard(
                icon: Icons.manage_accounts_rounded,
                label: 'Roles\n& Acceso',
                bg: _C.purpleLight,
                border: _C.purpleBorder,
                iconColor: _C.purple,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Footer
          Divider(color: _C.leftBorder, thickness: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('© ${DateTime.now().year} POS Multitienda Inc.',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: _C.textHint)),
              Text('Soporte técnico',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: _C.greenDark,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// Card de módulo
class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg, border, iconColor;
  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.bg,
    required this.border,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                  height: 1.35)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL DERECHO — Formulario
// ─────────────────────────────────────────────────────────────
class _FormPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController userCtrl, passCtrl;
  final FocusNode passFocus;
  final bool obscure;
  final AuthProvider auth;
  final VoidCallback onToggleObscure, onLogin;

  const _FormPanel({
    required this.formKey,
    required this.userCtrl,
    required this.passCtrl,
    required this.passFocus,
    required this.obscure,
    required this.auth,
    required this.onToggleObscure,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.rightBg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Badge "Sistema activo"
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _C.greenLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _C.greenBorder.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: _C.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Sistema activo',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _C.greenDark)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Título
                  Text('Bienvenido',
                      style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                          letterSpacing: -0.5)),

                  const SizedBox(height: 6),

                  Text('Ingresa tus credenciales para continuar.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _C.textSecond,
                          height: 1.5)),

                  const SizedBox(height: 32),

                  // Usuario
                  _Label(text: 'USUARIO'),
                  const SizedBox(height: 8),
                  _Field(
                    controller:      userCtrl,
                    hint:            'Tu usuario',
                    icon:            Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autofocus:       true,
                    onSubmit:        (_) =>
                        FocusScope.of(context).requestFocus(passFocus),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa tu usuario';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Contraseña
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _Label(text: 'CONTRASEÑA'),
                      Text('¿Olvidaste tu clave?',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _C.greenDark,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller:      passCtrl,
                    hint:            '••••••••',
                    icon:            Icons.lock_outline_rounded,
                    obscureText:     obscure,
                    focusNode:       passFocus,
                    textInputAction: TextInputAction.done,
                    onSubmit:        (_) { if (!auth.isLoading) onLogin(); },
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18, color: _C.textHint,
                      ),
                      onPressed: onToggleObscure,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                      if (v.length < 6)           return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Error
                  if (auth.errorMsg.isNotEmpty) ...[
                    _ErrorBox(msg: auth.errorMsg),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 16),

                  // Botón
                  _LoginButton(loading: auth.isLoading, onPressed: onLogin),

                  const SizedBox(height: 28),

                  // Ayuda
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.inter(
                            fontSize: 12, color: _C.textSecond),
                        children: [
                          const TextSpan(text: '¿Problemas para ingresar? '),
                          TextSpan(
                            text: 'Contacta al administrador',
                            style: const TextStyle(
                                color: _C.greenDark,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _C.textSecond,
          letterSpacing: 0.8));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputAction? textInputAction;
  final bool autofocus, obscureText;
  final FocusNode? focusNode;
  final Widget? suffixIcon;
  final void Function(String)? onSubmit;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.textInputAction,
    this.autofocus   = false,
    this.obscureText = false,
    this.focusNode,
    this.suffixIcon,
    this.onSubmit,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:       controller,
      autofocus:        autofocus,
      obscureText:      obscureText,
      focusNode:        focusNode,
      textInputAction:  textInputAction,
      onFieldSubmitted: onSubmit,
      validator:        validator,
      style: GoogleFonts.inter(color: _C.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.inter(color: _C.textHint, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: _C.textHint),
        suffixIcon: suffixIcon,
        filled:    true,
        fillColor: _C.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.greenDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.error, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(color: _C.error, fontSize: 11),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.error.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: _C.error, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.inter(
                  color: _C.error, fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _LoginButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF006c49), Color(0xFF00a870)],
            begin: Alignment.centerLeft,
            end:   Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: _C.greenDark.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor:     Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.0))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ingresar',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ),
        ),
      ),
    );
  }
}
