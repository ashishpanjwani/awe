import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _floatController;
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    print('[Splash] Animations set up');
    _initializeApp();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _fadeController.forward();

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2250),
      vsync: this,
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    )..repeat();
  }

  Future<void> _initializeApp() async {
    print('[Splash] Initializing auth...');
    try {
      await AuthService().initialize();
    } catch (e) {
      print('[Splash] Auth init error: $e');
    }
    print('[Splash] Auth initialized');

    await Future.delayed(const Duration(milliseconds: 2500));
    print('[Splash] Animation delay complete');

    if (!mounted) return;

    final bool isLoggedIn = AuthService().isLoggedIn;
    print('[Splash] isLoggedIn=$isLoggedIn, navigating next');
    Navigator.of(context).pushNamedAndRemoveUntil(
      isLoggedIn ? '/' : '/welcome',
      (route) => false,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.4),
            radius: 1.2,
            colors: [
              Color(0xFFFBF6EC),
              Color(0xFFF3ECDC),
              Color(0xFFECE2CD),
            ],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _floatController,
                      builder: (context, child) {
                        final t = Curves.easeInOut
                            .transform(_floatController.value);
                        return Transform.translate(
                          offset: Offset(0, -12.0 * t),
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/icons/awe_mascot.png',
                        width: 176,
                      ),
                    ),
                    Container(
                      width: 200,
                      height: 26,
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Color(0x33211D18),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.72],
                          transform: _EllipticalGradient(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Awe',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 62,
                        height: 1,
                        color: AweColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: _LoadingDots(controller: _dotsController),
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

class _EllipticalGradient extends GradientTransform {
  const _EllipticalGradient();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double sx = bounds.width / bounds.height;
    final m = Matrix4.identity();
    m.setEntry(0, 0, sx);
    m.setEntry(0, 3, bounds.center.dx * (1 - sx));
    return m;
  }
}

class _LoadingDots extends StatelessWidget {
  final AnimationController controller;
  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = i * 0.138;
            final t = (controller.value + 1.0 - phase) % 1.0;
            double opacity;
            double scale;
            if (t < 0.4) {
              final p = t / 0.4;
              opacity = 0.25 + 0.75 * p;
              scale = 0.85 + 0.15 * p;
            } else if (t < 0.8) {
              final p = (t - 0.4) / 0.4;
              opacity = 1.0 - 0.75 * p;
              scale = 1.0 - 0.15 * p;
            } else {
              opacity = 0.25;
              scale = 0.85;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.5),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16344E),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
