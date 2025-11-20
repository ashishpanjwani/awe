import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/weather_service.dart';
import 'package:wanderwell/services/destination_service.dart';
import 'package:wanderwell/services/feature_service.dart';
import 'package:wanderwell/screens/welcome_screen.dart';
import 'package:wanderwell/screens/home_screen.dart';
import 'package:wanderwell/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    print('[Splash] Animations set up');
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    // Initialize only auth quickly; data loads after navigation
    print('[Splash] Initializing auth...');
    try {
      await AuthService().initialize();
    } catch (e) {
      print('[Splash] Auth init error: $e');
    }
    print('[Splash] Auth initialized');

    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 2500));
    print('[Splash] Animation delay complete');

    if (!mounted) return;

    // Navigate to appropriate screen
    final bool isLoggedIn = AuthService().isLoggedIn;
    print('[Splash] isLoggedIn=$isLoggedIn, navigating next');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            isLoggedIn ? const HomeScreen() : const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 28),
                      child: Image.asset("assets/icons/awe_icon.png")),
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
