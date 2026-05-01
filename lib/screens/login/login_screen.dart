// lib/screens/login/login_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';

// ─────────────────────────────────────────────────────────────
// PALETA
// ─────────────────────────────────────────────────────────────
class _C {
  static const navy0    = Color(0xFF050A18);
  static const navy1    = Color(0xFF0B1528);
  static const navy2    = Color(0xFF111E38);
  static const navy3    = Color(0xFF1A2D4E);
  static const gold0    = Color(0xFFFFD166);
  static const gold1    = Color(0xFFFFC233);
  static const gold2    = Color(0xFFE5A800);
  static const goldGlow = Color(0x55FFD166);
  static const white    = Colors.white;
  static const white60  = Color(0x99FFFFFF);
  static const white20  = Color(0x33FFFFFF);
  static const white10  = Color(0x1AFFFFFF);
  static const error    = Color(0xFFFF6B6B);
}

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  // Form
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _passFocus    = FocusNode();
  bool  _obscure      = true;

  // Animaciones de la secuencia del logo
  late final AnimationController _seqCtrl;   // secuenciador maestro 0→1 en 3.2s
  late final AnimationController _glowCtrl;  // glow pulsante infinito
  late final AnimationController _titleCtrl; // título aparece al final

  // Sub-animaciones derivadas de _seqCtrl
  late Animation<Offset> _billPos;      // trayectoria del billete
  late Animation<double>  _billAngle;   // rotación del billete en vuelo
  late Animation<double>  _billScale;   // el billete se achica al entrar
  late Animation<double>  _billOpacity; // desaparece al entrar en caja
  late Animation<double>  _slotGlow;    // brillo de la ranura al recibir
  late Animation<double>  _dingFlash;   // destello dorado de la caja
  late Animation<double>  _registerBounce; // pequeño bounce de la caja
  late Animation<double>  _titleOpacity;
  late Animation<Offset>  _titleSlide;
  late Animation<double>  _subtitleOpacity;

  @override
  void initState() {
    super.initState();

    // ── Secuenciador maestro ──────────────────────────────────
    _seqCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3400));

    // Billete: empieza fuera (arriba-derecha) y vuela hacia la ranura
    _billPos = Tween<Offset>(
      begin: const Offset(2.0, -2.2),   // fuera del panel
      end:   const Offset(0.0,  0.08),  // encima de la ranura
    ).animate(CurvedAnimation(
      parent: _seqCtrl,
      curve:  const Interval(0.0, 0.42, curve: Curves.easeInBack),
    ));

    _billAngle = Tween<double>(begin: 0.45, end: -0.05)
        .animate(CurvedAnimation(
          parent: _seqCtrl,
          curve:  const Interval(0.0, 0.42, curve: Curves.easeOut),
        ));

    _billScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _seqCtrl,
      curve:  const Interval(0.30, 0.55, curve: Curves.easeIn),
    ));

    _billOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _seqCtrl,
      curve:  const Interval(0.30, 0.58),
    ));

    // Ranura brilla al recibir el billete
    _slotGlow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _seqCtrl,
      curve:  const Interval(0.45, 0.65),
    ));

    // Destello dorado de la caja (ding!)
    _dingFlash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: _seqCtrl,
      curve:  const Interval(0.55, 0.78),
    ));

    // Bounce de la caja al recibir el billete
    _registerBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 4.0),  weight: 35),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: -2.0),  weight: 20),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 0.0),  weight: 20),
    ]).animate(CurvedAnimation(
      parent: _seqCtrl,
      curve:  const Interval(0.55, 0.80),
    ));

    // Título principal
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
          parent: _seqCtrl,
          curve:  const Interval(0.72, 0.90, curve: Curves.easeOut),
        ));

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _seqCtrl,
      curve:  const Interval(0.72, 0.90, curve: Curves.easeOut),
    ));

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
          parent: _seqCtrl,
          curve:  const Interval(0.85, 1.00, curve: Curves.easeOut),
        ));

    // ── Glow pulsante (infinito) ─────────────────────────────
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);

    // ── Controlador del título (no necesario, usamos _seqCtrl) ─
    _titleCtrl = AnimationController(vsync: this);

    // Arranca
    _seqCtrl.forward();
  }

  @override
  void dispose() {
    _seqCtrl.dispose();
    _glowCtrl.dispose();
    _titleCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthProvider>().clearError();
    await context.read<AuthProvider>().login(
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final w    = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _C.navy0,
      body: Row(children: [

        // ══ PANEL IZQUIERDO — Logo animado ══════════════════════
        if (w > 820)
          Expanded(
            flex: 5,
            child: _LeftPanel(
              seqCtrl:         _seqCtrl,
              glowCtrl:        _glowCtrl,
              billPos:         _billPos,
              billAngle:       _billAngle,
              billScale:       _billScale,
              billOpacity:     _billOpacity,
              slotGlow:        _slotGlow,
              dingFlash:       _dingFlash,
              registerBounce:  _registerBounce,
              titleOpacity:    _titleOpacity,
              titleSlide:      _titleSlide,
              subtitleOpacity: _subtitleOpacity,
            ),
          ),

        // ══ PANEL DERECHO — Formulario ══════════════════════════
        Expanded(
          flex: 4,
          child: _RightPanel(
            formKey:   _formKey,
            emailCtrl: _emailCtrl,
            passCtrl:  _passCtrl,
            passFocus: _passFocus,
            obscure:   _obscure,
            auth:      auth,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onLogin:   _login,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL IZQUIERDO
// ─────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  final AnimationController seqCtrl, glowCtrl;
  final Animation<Offset> billPos, titleSlide;
  final Animation<double> billAngle, billScale, billOpacity,
      slotGlow, dingFlash, registerBounce,
      titleOpacity, subtitleOpacity;

  const _LeftPanel({
    required this.seqCtrl,
    required this.glowCtrl,
    required this.billPos,
    required this.billAngle,
    required this.billScale,
    required this.billOpacity,
    required this.slotGlow,
    required this.dingFlash,
    required this.registerBounce,
    required this.titleOpacity,
    required this.titleSlide,
    required this.subtitleOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.navy0, _C.navy1, _C.navy2],
          begin:  Alignment.topRight,
          end:    Alignment.bottomLeft,
        ),
        border: Border(right: BorderSide(color: _C.white10)),
      ),
      child: Stack(children: [

        // Patrón de puntos de fondo
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        // Círculo de brillo central detrás de la caja
        AnimatedBuilder(
          animation: glowCtrl,
          builder: (_, __) {
            final r = 0.7 + 0.3 * glowCtrl.value;
            return Center(
              child: Container(
                width:  280 * r,
                height: 280 * r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _C.gold0.withOpacity(0.07 * r),
                    Colors.transparent,
                  ]),
                ),
              ),
            );
          },
        ),

        // Contenido central
        Center(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Escena animada ─────────────────────────────
                SizedBox(
                  height: 280,
                  child: AnimatedBuilder(
                    animation: seqCtrl,
                    builder: (_, __) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [

                          // Destello de ding
                          if (dingFlash.value > 0)
                            Container(
                              width:  200 * (1 + dingFlash.value * 0.4),
                              height: 200 * (1 + dingFlash.value * 0.4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  _C.gold0.withOpacity(0.55 * dingFlash.value),
                                  Colors.transparent,
                                ]),
                              ),
                            ),

                          // Caja registradora (con bounce)
                          Transform.translate(
                            offset: Offset(0, registerBounce.value),
                            child: CustomPaint(
                              size: const Size(180, 160),
                              painter: _CashRegisterPainter(
                                slotGlow:  slotGlow.value,
                                dingFlash: dingFlash.value,
                              ),
                            ),
                          ),

                          // Billete volador
                          if (billOpacity.value > 0)
                            Positioned.fill(
                              child: SlideTransition(
                                position: billPos,
                                child: Center(
                                  child: Transform.rotate(
                                    angle: billAngle.value,
                                    child: Transform.scale(
                                      scale: billScale.value,
                                      child: Opacity(
                                        opacity: billOpacity.value,
                                        child: CustomPaint(
                                          size: const Size(110, 52),
                                          painter: _BillPainter(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // ── Título POS Multitienda ─────────────────────
                AnimatedBuilder(
                  animation: seqCtrl,
                  builder: (_, __) => FadeTransition(
                    opacity: titleOpacity,
                    child: SlideTransition(
                      position: titleSlide,
                      child: Column(children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [_C.gold1, _C.gold0, _C.white],
                            stops:  [0.0, 0.5, 1.0],
                          ).createShader(b),
                          child: Text('POS Multitienda',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.1)),
                        ),
                        const SizedBox(height: 10),
                        FadeTransition(
                          opacity: subtitleOpacity,
                          child: Text(
                            'Sistema de punto de venta\npara múltiples tiendas',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: _C.white60,
                                height: 1.6,
                                fontWeight: FontWeight.w400),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Feature chips ──────────────────────────────
                AnimatedBuilder(
                  animation: seqCtrl,
                  builder: (_, __) => FadeTransition(
                    opacity: subtitleOpacity,
                    child: Wrap(
                      spacing: 10, runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: const [
                        _FeatureChip(
                            icon: Icons.store_rounded,
                            label: 'Multi-tienda'),
                        _FeatureChip(
                            icon: Icons.point_of_sale_rounded,
                            label: 'Ventas en tiempo real'),
                        _FeatureChip(
                            icon: Icons.bar_chart_rounded,
                            label: 'Reportes'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Versión — esquina inferior izquierda
        const Positioned(
          left: 20, bottom: 18,
          child: Text('v1.0.0',
              style: TextStyle(color: _C.white20, fontSize: 11)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL DERECHO — Formulario
// ─────────────────────────────────────────────────────────────
class _RightPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passCtrl;
  final FocusNode passFocus;
  final bool obscure;
  final AuthProvider auth;
  final VoidCallback onToggleObscure, onLogin;

  const _RightPanel({
    required this.formKey,
    required this.emailCtrl,
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.navy1, _C.navy0],
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Icono dorado pequeño + "Iniciar sesión"
                  Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                            colors: [_C.gold2, _C.gold0]),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 18, color: _C.navy0),
                    ),
                    const SizedBox(width: 12),
                    Text('Acceso seguro',
                        style: GoogleFonts.dmSans(
                            color: _C.gold0,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                  ]),

                  const SizedBox(height: 18),

                  Text('Bienvenido\nde vuelta',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: _C.white,
                          height: 1.1,
                          letterSpacing: -0.5)),

                  const SizedBox(height: 10),

                  Text('Ingresa tus credenciales para acceder\nal panel de gestión.',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: _C.white60, height: 1.6)),

                  const SizedBox(height: 36),

                  // ── Divisor dorado ─────────────────────────
                  Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        _C.gold2,
                        Colors.transparent,
                      ]),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Campo email ────────────────────────────
                  _FieldLabel(label: 'Correo electrónico'),
                  const SizedBox(height: 8),
                  _PremiumField(
                    controller:      emailCtrl,
                    hint:            'usuario@empresa.com',
                    icon:            Icons.alternate_email_rounded,
                    keyboardType:    TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofocus:       true,
                    onSubmit:        (_) =>
                        FocusScope.of(context).requestFocus(passFocus),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Ingresa tu correo';
                      if (!v.contains('@'))
                        return 'Correo inválido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Campo contraseña ───────────────────────
                  _FieldLabel(label: 'Contraseña'),
                  const SizedBox(height: 8),
                  _PremiumField(
                    controller:      passCtrl,
                    hint:            '••••••••',
                    icon:            Icons.shield_outlined,
                    obscureText:     obscure,
                    focusNode:       passFocus,
                    textInputAction: TextInputAction.done,
                    onSubmit:        (_) {
                      if (!auth.isLoading) onLogin();
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18, color: _C.white20,
                      ),
                      onPressed: onToggleObscure,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Ingresa tu contraseña';
                      if (v.length < 6)
                        return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Error ──────────────────────────────────
                  if (auth.errorMsg.isNotEmpty)
                    _ErrorBox(msg: auth.errorMsg),

                  const SizedBox(height: 28),

                  // ── Botón login ────────────────────────────
                  _LoginButton(
                      loading: auth.isLoading, onPressed: onLogin),

                  const SizedBox(height: 24),

                  // ── Pie de formulario ──────────────────────
                  Center(
                    child: Text(
                      '© ${DateTime.now().year} POS Multitienda · Todos los derechos reservados',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: _C.white20),
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
// WIDGETS AUXILIARES — formulario
// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.dmSans(
          color: _C.white60,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));
}

class _PremiumField extends StatefulWidget {
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

  const _PremiumField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofocus    = false,
    this.obscureText  = false,
    this.focusNode,
    this.suffixIcon,
    this.onSubmit,
    this.validator,
  });

  @override
  State<_PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<_PremiumField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _focused ? _C.gold0.withOpacity(0.7) : _C.white10,
            width: _focused ? 1.5 : 1,
          ),
          boxShadow: _focused
              ? [BoxShadow(color: _C.gold0.withOpacity(0.12),
                    blurRadius: 14, spreadRadius: 1)]
              : [],
        ),
        child: TextFormField(
          controller:      widget.controller,
          autofocus:       widget.autofocus,
          obscureText:     widget.obscureText,
          focusNode:       widget.focusNode,
          keyboardType:    widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmit,
          validator:       widget.validator,
          style: GoogleFonts.dmSans(color: _C.white, fontSize: 14),
          decoration: InputDecoration(
            hintText:  widget.hint,
            hintStyle: GoogleFonts.dmSans(
                color: _C.white20, fontSize: 14),
            prefixIcon: Icon(widget.icon,
                size: 18,
                color: _focused ? _C.gold0 : _C.white20),
            suffixIcon: widget.suffixIcon,
            filled:     true,
            fillColor:  _C.white10,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 16),
            border:        _border(),
            enabledBorder: _border(),
            focusedBorder: _border(),
            errorBorder:   _border(error: true),
            focusedErrorBorder: _border(error: true),
            errorStyle: GoogleFonts.dmSans(
                color: _C.error, fontSize: 11),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border({bool error = false}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: BorderSide.none,
  );
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.error.withOpacity(0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _C.error.withOpacity(0.30)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: _C.error, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.dmSans(
                  color: _C.error, fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _LoginButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _LoginButton({required this.loading, required this.onPressed});
  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() { _hoverCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) { setState(() => _hovered = true);  _hoverCtrl.forward(); },
      onExit:  (_) { setState(() => _hovered = false); _hoverCtrl.reverse(); },
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _hoverCtrl,
          builder: (_, __) {
            final t = _hoverCtrl.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(_C.gold2, _C.gold1, t)!,
                    Color.lerp(_C.gold0, Colors.white, t * 0.1)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.gold0.withOpacity(0.15 + 0.25 * t),
                    blurRadius: 14 + 8 * t,
                    offset: Offset(0, 4 + 2 * t),
                  ),
                ],
              ),
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: _C.navy0, strokeWidth: 2.5))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ingresar al sistema',
                              style: GoogleFonts.dmSans(
                                  color: _C.navy0,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2)),
                          const SizedBox(width: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.translationValues(
                                4 * t, 0, 0),
                            child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 17, color: _C.navy0),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.white10),
        color: _C.white10,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _C.gold0),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.dmSans(
                color: _C.white60, fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────

/// Cuadrícula de puntos sutiles en el fondo del panel
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color  = _C.white.withOpacity(0.025)
      ..style  = PaintingStyle.fill;
    const step = 28.0;
    for (double x = step; x < size.width;  x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}

/// Billete verde con detalles dorados
class _BillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rr = Radius.circular(5);

    // Cuerpo verde oscuro
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF1A6B3C), const Color(0xFF2E9E5B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), rr), bodyPaint);

    // Marco dorado interior
    final border = Paint()
      ..color = _C.gold0.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(4, 3, w - 8, h - 6), Radius.circular(3)),
        border);

    // Óvalo central (símbolo de moneda)
    final oval = Paint()..color = _C.gold0.withOpacity(0.18);
    canvas.drawOval(Rect.fromCenter(
        center: Offset(w / 2, h / 2), width: 28, height: 22), oval);

    // Símbolo "$"
    final tp = TextPainter(
      text: TextSpan(
          text: '\$',
          style: GoogleFonts.playfairDisplay(
              color: _C.gold0,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(w / 2 - tp.width / 2, h / 2 - tp.height / 2));

    // Números de serie (líneas)
    final lineP = Paint()
      ..color = _C.gold0.withOpacity(0.30)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
          Offset(10, 10.0 + i * 5), Offset(28, 10.0 + i * 5), lineP);
      canvas.drawLine(
          Offset(w - 28, 10.0 + i * 5), Offset(w - 10, 10.0 + i * 5), lineP);
    }
  }
  @override bool shouldRepaint(_) => false;
}

/// Caja registradora con ranura iluminable y pantalla
class _CashRegisterPainter extends CustomPainter {
  final double slotGlow, dingFlash;
  const _CashRegisterPainter({required this.slotGlow, required this.dingFlash});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // ── Base / cuerpo ─────────────────────────────────────────
    final body = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF1A2D4E), const Color(0xFF0F1E36)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.05, h * 0.32, w * 0.90, h * 0.68),
            const Radius.circular(10)),
        body);

    // Borde exterior dorado
    final outerBorder = Paint()
      ..color = _C.gold2.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.05, h * 0.32, w * 0.90, h * 0.68),
            const Radius.circular(10)),
        outerBorder);

    // ── Pantalla / display ─────────────────────────────────────
    final screenBg = Paint()..color = const Color(0xFF060E1A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.36, w * 0.76, h * 0.26),
            const Radius.circular(6)),
        screenBg);

    // Brillo de pantalla al ding
    if (dingFlash > 0) {
      final screenGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            _C.gold0.withOpacity(0.6 * dingFlash),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(
            w * 0.12, h * 0.36, w * 0.76, h * 0.26));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.12, h * 0.36, w * 0.76, h * 0.26),
              const Radius.circular(6)),
          screenGlow);
    }

    // Texto del display: "$" estático + flash
    final displayText = TextPainter(
      text: TextSpan(
        text: dingFlash > 0.3 ? '  \$ LISTO  ' : '  LISTO  ',
        style: TextStyle(
          color: dingFlash > 0
              ? Color.lerp(_C.gold0, Colors.white, dingFlash)
              : const Color(0xFF4AE54A),
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    displayText.paint(
        canvas,
        Offset(w / 2 - displayText.width / 2,
               h * 0.36 + (h * 0.26) / 2 - displayText.height / 2));

    // ── Teclas decorativas ─────────────────────────────────────
    final keyPaint = Paint()..color = const Color(0xFF0D1828);
    final keyGold  = Paint()
      ..color = _C.gold2.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final cols = 4, rows = 2;
    final kw = (w * 0.72) / cols, kh = 10.0;
    final kStartX = w * 0.14, kStartY = h * 0.70;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rx = kStartX + c * (kw + 3);
        final ry = kStartY + r * (kh + 5);
        final krr = RRect.fromRectAndRadius(
            Rect.fromLTWH(rx, ry, kw - 2, kh),
            const Radius.circular(2));
        canvas.drawRRect(krr, keyPaint);
        canvas.drawRRect(krr, keyGold);
      }
    }

    // ── Cajón inferior ─────────────────────────────────────────
    final drawer = Paint()..color = const Color(0xFF0A1525);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.10, h * 0.90, w * 0.80, h * 0.10),
            const Radius.circular(4)),
        drawer);
    final handle = Paint()
      ..color = _C.gold2.withOpacity(0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(w * 0.42, h * 0.95), Offset(w * 0.58, h * 0.95), handle);

    // ── Cuerpo superior (lomo) ─────────────────────────────────
    final top = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF203858), const Color(0xFF152840)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.10, h * 0.06, w * 0.80, h * 0.30));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.10, h * 0.06, w * 0.80, h * 0.30),
            const Radius.circular(8)),
        top);

    // ── RANURA del billete ─────────────────────────────────────
    final slotY  = h * 0.05;
    final slotX1 = w * 0.22, slotX2 = w * 0.78;

    // Glow de la ranura
    if (slotGlow > 0) {
      final glowP = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _C.gold0.withOpacity(0.8 * slotGlow),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(slotX1, slotY - 6, slotX2 - slotX1, 12));
      canvas.drawRect(
          Rect.fromLTWH(slotX1, slotY - 6, slotX2 - slotX1, 12), glowP);
    }

    // Línea de la ranura
    final slot = Paint()
      ..color = Color.lerp(
          _C.gold2.withOpacity(0.5),
          _C.gold0,
          slotGlow)!
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(slotX1, slotY), Offset(slotX2, slotY), slot);

    // Flechas indicadoras de la ranura
    final arrow = Paint()
      ..color = _C.gold0.withOpacity(0.3 + 0.7 * slotGlow)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final dx in [-6.0, 0.0, 6.0]) {
      final cx = w / 2 + dx;
      canvas.drawLine(Offset(cx - 3, slotY - 5), Offset(cx, slotY - 1), arrow);
      canvas.drawLine(Offset(cx + 3, slotY - 5), Offset(cx, slotY - 1), arrow);
    }

    // ── Sombra inferior de la caja ─────────────────────────────
    final shadow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = Colors.black.withOpacity(0.5);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, h * 0.98),
            width: w * 0.75,
            height: h * 0.05),
        shadow);
  }

  @override
  bool shouldRepaint(covariant _CashRegisterPainter old) =>
      old.slotGlow != slotGlow || old.dingFlash != dingFlash;
}