// lib/screens/login/login_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/update_service.dart' show UpdateService, currentVersion;

Future<void> _abrirWhatsAppAdmin() async {
  const url = 'https://wa.me/573167525926';
  try {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    }
  } catch (_) {}
}

// ─────────────────────────────────────────────────────────────
// PALETA
// ─────────────────────────────────────────────────────────────
class _C {
  // Fondo general y paneles (desktop)
  static const bodyBg      = Color(0xFFF5F7F8);
  static const leftBg      = Color(0xFFF0FDF4);
  static const leftBorder  = Color(0xFFBBF7D0);
  static const rightBg     = Color(0xFFFFFFFF);

  // Textos
  static const textPrimary = Color(0xFF111827);
  static const textSecond  = Color(0xFF6B7280);
  static const textHint    = Color(0xFF9CA3AF);

  // Verde marca
  static const green       = Color(0xFF61DDAA);
  static const greenDark   = Color(0xFF0B7A53);
  static const greenMid    = Color(0xFF0F9B6A);
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) UpdateService.chequear(context);
    });
  }

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
      _passCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final size     = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

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

    if (isMobile) {
      return _MobileLoginLayout(
        formKey:         _formKey,
        userCtrl:        _userCtrl,
        passCtrl:        _passCtrl,
        passFocus:       _passFocus,
        obscure:         _obscure,
        auth:            auth,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onLogin:         _login,
      );
    }

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
              child: SizedBox(
                height: 660,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 46, child: const _LeftPanel()),
                    Expanded(flex: 54, child: formPanel),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LOGO MARK
// ─────────────────────────────────────────────────────────────
class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F9B6A), Color(0xFF0B7A53)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B7A53).withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo decorativo interior
          Positioned(
            right: -size * 0.08,
            top: -size * 0.08,
            child: Container(
              width: size * 0.55,
              height: size * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          // Icono
          Icon(Icons.storefront_rounded,
              size: size * 0.48,
              color: Colors.white),
          // Punto "activo" bottom-right
          Positioned(
            right: size * 0.12,
            bottom: size * 0.12,
            child: Container(
              width: size * 0.17,
              height: size * 0.17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF61DDAA),
                border: Border.all(
                  color: const Color(0xFF0B7A53),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DECORACIÓN DE FONDO MÓVIL  (círculos — fondo verde claro)
// ─────────────────────────────────────────────────────────────
class _LightBgCirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void circle(double cx, double cy, double r, Color color, double opacity) {
      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withOpacity(opacity),
      );
    }

    circle(size.width * 1.05, size.height * -0.05, size.width * 0.59,
        const Color(0xFF059669), 0.14);
    circle(size.width * 1.05, size.height * -0.05, size.width * 0.92,
        const Color(0xFF14B8A6), 0.09);
    circle(size.width * -0.09, size.height * 0.75, size.width * 0.33,
        const Color(0xFF84CC16), 0.11);
    circle(size.width * 0.10, size.height * 0.14, size.width * 0.20,
        const Color(0xFF059669), 0.08);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────
// PILL DE SALUDO
// ─────────────────────────────────────────────────────────────
class _GreetingPill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _GreetingPill({
    required this.text,
    this.icon = Icons.wb_sunny_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF059669)),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF059669),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LOGO CON ORBIT RING Y BADGES
// ─────────────────────────────────────────────────────────────
class _OrbitLogo extends StatelessWidget {
  const _OrbitLogo();

  Widget _badge({
    required String label,
    required IconData icon,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: const Color(0xFF059669)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Orbit ring
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF059669).withOpacity(0.25),
                width: 1.5,
              ),
            ),
          ),
          // Logo
          const _LogoMark(size: 92),
          // Badges
          _badge(
            label: 'Ventas',
            icon: Icons.shopping_cart_rounded,
            top: 2,
            right: -18,
          ),
          _badge(
            label: 'Turnos',
            icon: Icons.access_time_filled_rounded,
            bottom: 8,
            right: -12,
          ),
          _badge(
            label: 'Caja',
            icon: Icons.credit_card_rounded,
            bottom: 8,
            left: -12,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FONDO HERO MÓVIL (compartido por bienvenida y login)
// ─────────────────────────────────────────────────────────────
Widget _mobileHeroFondo() {
  return Stack(
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5), Color(0xFFCCFBF1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: CustomPaint(painter: _LightBgCirclesPainter()),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// LAYOUT MÓVIL — controlador de dos vistas
// ─────────────────────────────────────────────────────────────
class _MobileLoginLayout extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController userCtrl, passCtrl;
  final FocusNode passFocus;
  final bool obscure;
  final AuthProvider auth;
  final VoidCallback onToggleObscure, onLogin;

  const _MobileLoginLayout({
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
  State<_MobileLoginLayout> createState() => _MobileLoginLayoutState();
}

class _MobileLoginLayoutState extends State<_MobileLoginLayout> {
  bool _enForm = false;

  void _irAForm() => setState(() => _enForm = true);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
      child: _enForm
          ? _MobileFormView(
              key: const ValueKey('form'),
              formKey:         widget.formKey,
              userCtrl:        widget.userCtrl,
              passCtrl:        widget.passCtrl,
              passFocus:       widget.passFocus,
              obscure:         widget.obscure,
              auth:            widget.auth,
              onToggleObscure: widget.onToggleObscure,
              onLogin:         widget.onLogin,
            )
          : _MobileWelcomeView(
              key: const ValueKey('welcome'),
              onIniciar: _irAForm,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VISTA BIENVENIDA (primera pantalla móvil)
// ─────────────────────────────────────────────────────────────
class _MobileWelcomeView extends StatelessWidget {
  final VoidCallback onIniciar;
  const _MobileWelcomeView({super.key, required this.onIniciar});

  static String _saludo() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12)   return 'Buenos días';
    if (h >= 12 && h <= 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static const _msgs = [
    '¡Que las ventas de hoy superen las de ayer!',
    'Cada cliente es una oportunidad. ¡Adelante!',
    '¡Buen turno! El equipo cuenta contigo.',
    'Un gran día comienza con una gran actitud.',
    'Hoy es un buen día para cerrar con todo.',
    '¡Arranca fuerte! El turno es tuyo.',
    '¡Que fluya la caja hoy! Mucho éxito.',
  ];
  static const _dias  = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles',
    'Jueves', 'Viernes', 'Sábado',
  ];
  static const _meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final diaTxt = '${_dias[now.weekday % 7]}, ${now.day} de ${_meses[now.month - 1]}';
    final msgTxt = _msgs[now.weekday % 7];

    return Scaffold(
      body: Stack(
        children: [
          _mobileHeroFondo(),
          Column(
            children: [
              // ── Hero logo
              Expanded(
                flex: 50,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _OrbitLogo(),
                      const SizedBox(height: 18),
                      Text(
                        'POS MULTITIENDA',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF065F46),
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Sistema de gestión de ventas',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tarjeta inferior
              Expanded(
                flex: 50,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28)),
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFA7F3D0).withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA7F3D0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        _GreetingPill(text: _saludo()),
                        const SizedBox(height: 10),

                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF064E3B),
                              letterSpacing: -1.5,
                              height: 1.08,
                            ),
                            children: const [
                              TextSpan(text: '¿Listos\n'),
                              TextSpan(
                                text: 'para hoy?',
                                style: TextStyle(color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Tarjeta del día
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF0FDF8), Color(0xFFECFDF5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFA7F3D0),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF059669),
                                      Color(0xFF0D9488),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.access_time_filled_rounded,
                                  size: 20, color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      diaTxt.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0D9488),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      msgTxt,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF064E3B),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Botón CTA
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF059669),
                                  Color(0xFF0D9488),
                                  Color(0xFF14B8A6),
                                ],
                                stops: [0.0, 0.6, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669)
                                      .withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: onIniciar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Iniciar Sesión',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                      Icons.arrow_forward_rounded, size: 17),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Versión
                        Center(
                          child: ValueListenableBuilder<Map<String, dynamic>?>(
                            valueListenable: UpdateService.updateDisponible,
                            builder: (ctx, info, _) {
                              final hayUpdate = info != null;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hayUpdate
                                        ? Icons.system_update_rounded
                                        : Icons.check_circle_rounded,
                                    size: 11,
                                    color: hayUpdate
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    hayUpdate
                                        ? 'v$currentVersion → v${info!['version']} disponible'
                                        : 'v$currentVersion — al día',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: hayUpdate
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF86BFAA),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VISTA FORMULARIO (segunda pantalla móvil)
// ─────────────────────────────────────────────────────────────
class _MobileFormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController userCtrl, passCtrl;
  final FocusNode passFocus;
  final bool obscure;
  final AuthProvider auth;
  final VoidCallback onToggleObscure, onLogin;

  const _MobileFormView({
    super.key,
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
    return Scaffold(
      body: Stack(
        children: [
          _mobileHeroFondo(),
          Column(
            children: [
              // ── Hero logo (42%)
              Expanded(
                flex: 42,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _LogoMark(size: 76),
                      const SizedBox(height: 16),
                      Text(
                        'POS MULTITIENDA',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF065F46),
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Sistema de gestión de ventas',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tarjeta formulario (58%)
              Expanded(
                flex: 58,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28)),
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFA7F3D0).withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40, height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFA7F3D0),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const _GreetingPill(
                            text: 'BIENVENIDO/A',
                            icon: Icons.waving_hand_rounded,
                          ),
                          const SizedBox(height: 10),

                          Text(
                            'Inicia sesión',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF064E3B),
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ingresa tus credenciales para continuar',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: _C.textSecond,
                            ),
                          ),

                          const SizedBox(height: 20),

                          _Label(text: 'CÉDULA O CORREO'),
                          const SizedBox(height: 8),
                          _Field(
                            controller:      userCtrl,
                            hint:            'Cédula o correo electrónico',
                            icon:            Icons.badge_outlined,
                            keyboardType:    TextInputType.text,
                            textInputAction: TextInputAction.next,
                            autofocus:       false,
                            onSubmit:        (_) =>
                                FocusScope.of(context).requestFocus(passFocus),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Ingresa tu cédula o correo';
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          const _Label(text: 'CONTRASEÑA'),
                          const SizedBox(height: 8),
                          _Field(
                            controller:      passCtrl,
                            hint:            '••••••••',
                            icon:            Icons.lock_outline_rounded,
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
                                size: 18, color: _C.textHint,
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

                          if (auth.errorMsg.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _ErrorBox(msg: auth.errorMsg),
                          ],

                          const SizedBox(height: 20),

                          _LoginButton(
                              loading: auth.isLoading, onPressed: onLogin),

                          const SizedBox(height: 16),

                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                Text(
                                  '¿Problemas para ingresar? ',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: _C.textSecond),
                                ),
                                GestureDetector(
                                  onTap: _abrirWhatsAppAdmin,
                                  child: Text(
                                    'Contacta al admin',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _C.greenDark,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _C.greenDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          Center(
                            child: ValueListenableBuilder<Map<String, dynamic>?>(
                              valueListenable: UpdateService.updateDisponible,
                              builder: (ctx, info, _) {
                                final hayUpdate = info != null;
                                return GestureDetector(
                                  onTap: hayUpdate
                                      ? () => UpdateService.mostrarDialogo(ctx)
                                      : null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hayUpdate
                                            ? Icons.system_update_rounded
                                            : Icons.check_circle_rounded,
                                        size: 11,
                                        color: hayUpdate
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF059669),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        hayUpdate
                                            ? 'v$currentVersion → v${info!['version']} disponible'
                                            : 'v$currentVersion — al día',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: hayUpdate
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF86BFAA),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
              GestureDetector(
                onTap: () {
                  // Soporte técnico (sin acción)
                },
                child: Text('Soporte técnico',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _C.greenDark,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Chip de versión: error > update disponible > al día
          ValueListenableBuilder<String?>(
            valueListenable: UpdateService.updateError,
            builder: (ctx, error, _) {
              return ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: UpdateService.updateDisponible,
                builder: (ctx2, info, _) {
                  final bool hayError  = error != null;
                  final bool hayUpdate = info != null && !hayError;

                  Color chipBg, chipBorder, iconColor, textColor;
                  IconData chipIcon;
                  String chipLabel;
                  VoidCallback? onTap;

                  if (hayError) {
                    chipBg     = const Color(0xFFFFF7ED);
                    chipBorder = const Color(0xFFFBBF24);
                    iconColor  = const Color(0xFFB45309);
                    textColor  = const Color(0xFFB45309);
                    chipIcon   = Icons.warning_amber_rounded;
                    chipLabel  = 'Error al cargar versión';
                    onTap = () => showDialog(
                      context: ctx2,
                      builder: (_) => AlertDialog(
                        title: const Text('Error al verificar versión'),
                        content: SingleChildScrollView(
                          child: Text(error,
                              style: const TextStyle(fontSize: 12,
                                  fontFamily: 'monospace')),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx2);
                              UpdateService.chequear(ctx2);
                            },
                            child: const Text('Reintentar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx2),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  } else if (hayUpdate) {
                    chipBg     = const Color(0xFFFEF2F2);
                    chipBorder = const Color(0xFFFCA5A5);
                    iconColor  = const Color(0xFFDC2626);
                    textColor  = const Color(0xFFDC2626);
                    chipIcon   = Icons.system_update_rounded;
                    chipLabel  = 'v$currentVersion → v${info!['version']} disponible';
                    onTap = () => UpdateService.mostrarDialogo(ctx2);
                  } else {
                    chipBg     = _C.greenLight;
                    chipBorder = _C.greenBorder.withOpacity(0.5);
                    iconColor  = _C.greenDark;
                    textColor  = _C.greenDark;
                    chipIcon   = Icons.check_circle_rounded;
                    chipLabel  = 'v$currentVersion — al día';
                    onTap = null;
                  }

                  return GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: chipBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(chipIcon, size: 11, color: iconColor),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(chipLabel,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                )),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
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
                  _Label(text: 'CÉDULA O CORREO'),
                  const SizedBox(height: 8),
                  _Field(
                    controller:      userCtrl,
                    hint:            'Cédula o correo electrónico',
                    icon:            Icons.badge_outlined,
                    keyboardType:    TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autofocus:       true,
                    onSubmit:        (_) =>
                        FocusScope.of(context).requestFocus(passFocus),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa tu cédula o correo';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Contraseña
                  const _Label(text: 'CONTRASEÑA'),
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
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          '¿Problemas para ingresar? ',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: _C.textSecond),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _abrirWhatsAppAdmin,
                            child: Text(
                              'Contacta al administrador',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _C.greenDark,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: _C.greenDark,
                              ),
                            ),
                          ),
                        ),
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
          color: _C.textSecond,
          letterSpacing: 0.8));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
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
    this.keyboardType,
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
