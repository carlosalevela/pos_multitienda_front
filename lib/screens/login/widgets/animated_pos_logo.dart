import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedPosLogo extends StatefulWidget {
  const AnimatedPosLogo({super.key});

  @override
  State<AnimatedPosLogo> createState() => _AnimatedPosLogoState();
}

class _AnimatedPosLogoState extends State<AnimatedPosLogo>
    with TickerProviderStateMixin {

  late final AnimationController _billCtrl;
  late final AnimationController _registerCtrl;
  late final AnimationController _textCtrl;

  // Fade del billete al "entrar" en la caja
  late final Animation<double> _billFadeIn;
  late final Animation<double> _billFadeOut;

  // Bounce de la caja
  late final Animation<double> _registerScale;
  late final Animation<double> _glowOpacity;

  // Texto
  late final Animation<double>  _textFade;
  late final Animation<Offset>  _textSlide;
  late final Animation<double>  _subtitleFade;

  @override
  void initState() {
    super.initState();

    // ── Controlador principal del billete (2.8s para que se vea suave) ──
    _billCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _registerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // El billete aparece en los primeros 200ms
    _billFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _billCtrl,
        curve: const Interval(0.0, 0.08, curve: Curves.easeIn),
      ),
    );

    // El billete desaparece al entrar en la caja (último 12%)
    _billFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _billCtrl,
        curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
      ),
    );

    // Caja: bounce tipo cartoon cuando recibe el billete
    _registerScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.30)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.30, end: 0.88)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.06)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_registerCtrl);

    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _registerCtrl, curve: Curves.easeOut),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
      ),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _billCtrl.forward();                               // billete vuela
    await _registerCtrl.forward();                           // caja hace bounce
    await Future.delayed(const Duration(milliseconds: 250));
    await _textCtrl.forward();                               // texto aparece
  }

  @override
  void dispose() {
    _billCtrl.dispose();
    _registerCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // ── Zona del logo ──────────────────────────────────
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [

              // Glow al recibir el billete
              AnimatedBuilder(
                animation: _glowOpacity,
                builder: (_, __) => Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white
                            .withOpacity(0.30 * _glowOpacity.value),
                        blurRadius: 50 * _glowOpacity.value,
                        spreadRadius: 15 * _glowOpacity.value,
                      ),
                    ],
                  ),
                ),
              ),

              // Caja registradora
              ScaleTransition(
                scale: _registerScale,
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  size: 115,
                  color: Colors.white,
                ),
              ),

              // ── Billete con path ondulante tipo cartoon ──
              AnimatedBuilder(
                animation: _billCtrl,
                builder: (context, child) {
                  final t = _billCtrl.value; // 0.0 → 1.0

                  // Decaimiento del efecto viento (fuerte al inicio, cero al final)
                  final decay = 1.0 - Curves.easeIn.transform(t);

                  // ── Posición base: de (-140, -120) a (0, 0) ──
                  final baseX = -140.0 * (1.0 - t);
                  final baseY = -120.0 * (1.0 - t);

                  // ── Zigzag lateral suave (el "viento") ──
                  final windX = sin(t * 3 * pi) * 38.0 * decay;

                  // ── Bobbing vertical suave ──
                  final windY = sin(t * 4 * pi + pi / 4) * 18.0 * decay;

                  // ── Rotación oscilante como hoja ──
                  // Empieza rotado ~15°, luego oscila y termina a 0°
                  final rotationRad =
                      sin(t * 3 * pi) * 0.42 * decay + (0.26 * (1.0 - t));

                  // ── Escala: shrink al entrar en la caja ──
                  final scale = t > 0.85
                      ? (1.0 - ((t - 0.85) / 0.15)).clamp(0.0, 1.0)
                      : 1.0;

                  // ── Opacidad combinada ──
                  final opacity =
                      (_billFadeIn.value * _billFadeOut.value).clamp(0.0, 1.0);

                  return Transform.translate(
                    offset: Offset(baseX + windX, baseY + windY),
                    child: Transform.rotate(
                      angle: rotationRad,
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: const _CartoonBill(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Nombre y subtítulo ─────────────────────────────
        FadeTransition(
          opacity: _textFade,
          child: SlideTransition(
            position: _textSlide,
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFBBDEFB)],
                  ).createShader(b),
                  child: Text(
                    'POS Multitienda',
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _subtitleFade,
                  child: Text(
                    'Sistema de punto de venta\npara múltiples tiendas',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.72),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Billete estilo cartoon ─────────────────────────────────
class _CartoonBill extends StatelessWidget {
  const _CartoonBill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(10),
        // Borde blanco estilo cartoon
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 2),
        boxShadow: [
          // Sombra principal
          BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 12,
            offset: const Offset(3, 6),
          ),
          // Brillo superior estilo cartoon
          BoxShadow(
            color: Colors.white.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Franja horizontal central decorativa
          Positioned(
            top: 0, bottom: 0, left: 14, right: 14,
            child: Center(
              child: Container(
                height: 1.5,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),
          // Óvalo izquierdo
          Positioned(
            left: 6, top: 0, bottom: 0,
            child: Center(
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25), width: 1.5),
                ),
              ),
            ),
          ),
          // Óvalo derecho
          Positioned(
            right: 6, top: 0, bottom: 0,
            child: Center(
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25), width: 1.5),
                ),
              ),
            ),
          ),
          // Centro: "$100" bold
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '\$',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '100',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          // Brillo esquina superior izquierda (estilo cartoon)
          Positioned(
            top: 3, left: 3,
            child: Container(
              width: 20, height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}