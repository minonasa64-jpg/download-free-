import 'dart:async';
import 'package:flutter/material.dart';
// استدعاء ملف main.dart للوصول إلى واجهة MainNavigation
import 'main.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _glowController;
  late AnimationController _arrowController;
  late AnimationController _textController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glow;
  late Animation<double> _arrow;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // =========================
    // Logo animation
    // =========================

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    _logoOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(
          0.0,
          0.55,
          curve: Curves.easeOut,
        ),
      ),
    );

    // =========================
    // Glow animation
    // =========================

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glow = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // =========================
    // Download arrow animation
    // =========================

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _arrow = Tween<double>(
      begin: -7,
      end: 7,
    ).animate(
      CurvedAnimation(
        parent: _arrowController,
        curve: Curves.easeInOut,
      ),
    );

    // =========================
    // Text animation
    // =========================

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Start animations
    _logoController.forward();

    Future.delayed(
      const Duration(milliseconds: 450),
      () {
        if (mounted) {
          _textController.forward();
        }
      },
    );

    // الانتقال إلى الشاشة الرئيسية للتطبيق
    Timer(
      const Duration(milliseconds: 2800),
      () {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (
              context,
              animation,
              secondaryAnimation,
            ) {
              // هنا تم التعديل للانتقال إلى MainNavigation الخاصة بتطبيقك
              return const MainNavigation();
            },
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(
              milliseconds: 500,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _arrowController.dispose();
    _textController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050509),
      body: Stack(
        children: [

          // =========================
          // Background glow
          // =========================

          Center(
            child: AnimatedBuilder(
              animation: _glow,
              builder: (context, child) {
                return Container(
                  width: 280 * _glow.value,
                  height: 280 * _glow.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8A2BE2)
                            .withOpacity(0.18 * _glow.value),
                        const Color(0xFF00CFFF)
                            .withOpacity(0.08 * _glow.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // =========================
          // Main content
          // =========================

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Logo
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _logoController,
                    _glowController,
                  ]),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: 0.55 +
                            (_logoScale.value * 0.45),
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(38),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF00D9FF),
                                Color(0xFF4169E1),
                                Color(0xFFB000FF),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00D9FF)
                                    .withOpacity(
                                      0.30 +
                                          (_glow.value * 0.25),
                                    ),
                                blurRadius:
                                    30 + (_glow.value * 25),
                                spreadRadius:
                                    2 + (_glow.value * 5),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [

                              // B
                              const Text(
                                'B',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 105,
                                  fontWeight:
                                      FontWeight.w900,
                                  height: 1,
                                ),
                              ),

                              // Download arrow
                              AnimatedBuilder(
                                animation:
                                    _arrowController,
                                builder:
                                    (context, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      0,
                                      _arrow.value,
                                    ),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration:
                                          BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          15,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors
                                                .white
                                                .withOpacity(
                                                    0.35),
                                            blurRadius: 15,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons
                                            .arrow_downward_rounded,
                                        color:
                                            Color(0xFF6A00FF),
                                        size: 32,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // =========================
                // Boykta
                // =========================

                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [

                        ShaderMask(
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                              colors: [
                                Color(0xFF00D9FF),
                                Color(0xFFB000FF),
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'Boykta',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 7),

                        const Text(
                          'Download Videos',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.play_circle_fill,
                              color: Color(0xFF00D9FF),
                              size: 16,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Vidéos • Musiques • Tout ce que tu veux',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =========================
          // Bottom loading
          // =========================

          Positioned(
            left: 0,
            right: 0,
            bottom: 45,
            child: FadeTransition(
              opacity: _textOpacity,
              child: Column(
                children: [

                  SizedBox(
                    width: 80,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius:
                          BorderRadius.circular(10),
                      backgroundColor:
                          Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<
                              Color>(
                        Color(0xFF00D9FF),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Préparation...',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
