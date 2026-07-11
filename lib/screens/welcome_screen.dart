import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/widgets/cta_button.dart';
import 'package:wanderwell/utils/browser_info.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _floatController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    try {
      if (isInAppBrowser()) {
        try {
          debugPrint('[Welcome] In-app browser detected. UA: ${userAgentString()}');
        } catch (_) {}
      }
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AuthService().isLoggedIn) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2250),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService().signInWithGoogle();
      if (user != null && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.52),
            radius: 1.2,
            colors: [
              Color(0xFFFBF6EC),
              Color(0xFFF3ECDC),
              Color(0xFFECE2CD),
            ],
            stops: [0.0, 0.54, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        AnimatedBuilder(
                          animation: _floatController,
                          builder: (context, child) {
                            final t = Curves.easeInOut
                                .transform(_floatController.value);
                            return Transform.translate(
                              offset: Offset(0, -8.0 * t),
                              child: child,
                            );
                          },
                          child: Image.asset(
                            'assets/icons/awe_mascot.png',
                            width: 200,
                          ),
                        ),
                        Container(
                          width: 180,
                          height: 22,
                          decoration: const BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Color(0x30211D18),
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.72],
                              transform: _EllipticalGradient(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Awe',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 66,
                            height: 1,
                            color: AweColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 34,
                          height: 1,
                          color: const Color(0xFFCDBFA6),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'LET THE WORLD',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 11,
                            letterSpacing: 2.86,
                            color: const Color(0xFFA08A64),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'surprise you.',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 30,
                            fontStyle: FontStyle.italic,
                            height: 1.1,
                            color: AweColors.textPrimary,
                          ),
                        ),
                        const Spacer(flex: 2),
                        CtaButton(
                          label: _isLoading
                              ? 'Logging in...'
                              : 'Continue with Google',
                          onPressed: _handleGoogleSignIn,
                          loading: _isLoading,
                          leading: _isLoading
                              ? null
                              : const _GoogleLogoOrIcon(),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
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

class _GoogleLogoOrIcon extends StatelessWidget {
  const _GoogleLogoOrIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Image.asset(
        'assets/icons/google_logo.png',
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.login, color: Theme.of(context).colorScheme.onSecondary, size: 22),
        fit: BoxFit.contain,
      ),
    );
  }
}
