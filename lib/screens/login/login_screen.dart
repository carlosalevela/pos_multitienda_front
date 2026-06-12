// lib/screens/login/login_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';

// ─────────────────────────────────────────────────────────────
// PALETA
// ─────────────────────────────────────────────────────────────
class _C {
  // Panel izquierdo
  static const overlayDark  = Color(0xCC0D2B1A); // overlay verde oscuro semitransparente
  static const overlayLight = Color(0x880D2B1A); // overlay más claro
  static const green        = Color(0xFF1A8A4A); // verde marca

  // Panel derecho (blanco)
  static const bg           = Color(0xFFFFFFFF);
  static const surface      = Color(0xFFF6F8F6);
  static const borderColor  = Color(0xFFD8E4DC);
  static const textPrimary  = Color(0xFF111B16);
  static const textSecondary= Color(0xFF637068);
  static const textHint     = Color(0xFFAAB8B0);

  // Acento verde SIS POS
  static const accent       = Color(0xFF1B7A45);
  static const accentHover  = Color(0xFF145E35);
  static const accentLight  = Color(0xFFE8F5EE);

  // Error
  static const error        = Color(0xFFD32F2F);

  // Comunes
  static const white        = Colors.white;
  static const white80      = Color(0xCCFFFFFF);
  static const white50      = Color(0x80FFFFFF);
  static const white20      = Color(0x33FFFFFF);
}

// ─────────────────────────────────────────────────────────────
// SCREEN — sin animaciones, StatefulWidget solo para form state
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
    final auth = context.watch<AuthProvider>();
    final w    = MediaQuery.of(context).size.width;
    final isWide = w > 780;

    return Scaffold(
      backgroundColor: _C.bg,
      body: isWide
          ? Row(children: [
              // Panel izquierdo — imagen + overlay
              Expanded(flex: 55, child: _LeftPanel()),
              // Panel derecho — formulario
              Expanded(
                flex: 45,
                child: _FormPanel(
                  formKey:         _formKey,
                  userCtrl:        _userCtrl,
                  passCtrl:        _passCtrl,
                  passFocus:       _passFocus,
                  obscure:         _obscure,
                  auth:            auth,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  onLogin:         _login,
                ),
              ),
            ])
          // Mobile: solo formulario
          : _FormPanel(
              formKey:         _formKey,
              userCtrl:        _userCtrl,
              passCtrl:        _passCtrl,
              passFocus:       _passFocus,
              obscure:         _obscure,
              auth:            auth,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onLogin:         _login,
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo degradado verde oscuro (reemplazar por Image.asset si se tiene foto)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF071A0F), Color(0xFF0D2E1A), Color(0xFF143D24)],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
          ),
        ),

        // Patrón sutil — líneas diagonales muy tenues
        CustomPaint(painter: _SubtlePatternPainter()),

        // Contenido
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo SIS POS
              Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text('SIS POS',
                    style: GoogleFonts.inter(
                        color: _C.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ]),

              const Spacer(),

              // Título principal
              Text('POS MULTIMEDIA',
                  style: GoogleFonts.inter(
                      color: _C.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5)),

              const SizedBox(height: 16),

              Text(
                'Soluciones avanzadas de punto de venta e\ninventario diseñadas para los sectores\nmás exigentes.',
                style: GoogleFonts.inter(
                    color: _C.white80,
                    fontSize: 13,
                    height: 1.7,
                    fontWeight: FontWeight.w400),
              ),

              const SizedBox(height: 40),

              // Chips de características
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _Chip(label: 'Multi-tienda'),
                  _Chip(label: 'Inventario en tiempo real'),
                  _Chip(label: 'Reportes'),
                ],
              ),

              const Spacer(),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('© ${DateTime.now().year} POS Multimedia Inc.',
                      style: GoogleFonts.inter(
                          color: _C.white50, fontSize: 11)),
                  Row(children: [
                    _FooterLink(label: 'Privacy'),
                    const SizedBox(width: 16),
                    _FooterLink(label: 'Terms'),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _C.white20,
        border: Border.all(color: _C.white20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: _C.white80, fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  const _FooterLink({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: GoogleFonts.inter(
            color: _C.white50, fontSize: 11,
            decoration: TextDecoration.underline,
            decorationColor: _C.white50));
  }
}

// Painter: cuadrícula puntada sutil
class _SubtlePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    for (double x = 24; x < size.width;  x += 32)
      for (double y = 24; y < size.height; y += 32)
        canvas.drawCircle(Offset(x, y), 1.0, p);
  }
  @override bool shouldRepaint(_) => false;
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
      color: _C.bg,
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

                  // Título
                  Text('BIENVENIDO',
                      style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                          letterSpacing: 0.5)),

                  const SizedBox(height: 8),

                  Text('Access your dashboard to manage sales and stock.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _C.textSecondary,
                          height: 1.5)),

                  const SizedBox(height: 36),

                  // Campo USERNAME
                  _Label(text: 'USERNAME'),
                  const SizedBox(height: 8),
                  _Field(
                    controller:      userCtrl,
                    hint:            'Enter your username',
                    icon:            Icons.person_outline_rounded,
                    keyboardType:    TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofocus:       true,
                    onSubmit:        (_) =>
                        FocusScope.of(context).requestFocus(passFocus),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa tu usuario';
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Campo PASSWORD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Label(text: 'PASSWORD'),
                      GestureDetector(
                        onTap: () {/* TODO: forgot password */},
                        child: Text('Forgot password?',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _C.accent,
                                fontWeight: FontWeight.w600)),
                      ),
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

                  const SizedBox(height: 32),

                  // Footer badge
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_outlined,
                            size: 13, color: _C.textHint),
                        const SizedBox(width: 6),
                        Text('ENTERPRISE POS IDENTITY v4.0',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _C.textHint,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w500)),
                      ],
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
          color: _C.textSecondary,
          letterSpacing: 0.8));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
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
    this.keyboardType,
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
      keyboardType:     keyboardType,
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
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _C.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _C.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _C.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _C.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
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
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _C.accent.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.0))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Iniciar Sesión',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
      ),
    );
  }
}
