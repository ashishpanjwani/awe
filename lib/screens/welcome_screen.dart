import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/screens/home_screen.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/widgets/cta_button.dart';
import 'dart:ui' as ui show ImageFilter;

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService().signInWithGoogle();
      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed. Please try again.'),
            backgroundColor: FlowColors.warmCoral,
          ),
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      body: Stack(
        children: [
          // Subtle drifting coordinate field
          const _FloatingCoordinates(seed: 200),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          // Center title + tagline
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset("assets/icons/awe_icon.png"),
                              const SizedBox(height: 14),
                              Opacity(
                                opacity: 0.86,
                                child: Text(
                                  'Let The World',
                                  style: GoogleFonts.raleway(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: FlowColors.textLight,
                                    height: 1.35,
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 4),
                               Opacity(
                                opacity: 0.86,
                                child: Text(
                                  'Surprise You',
                                  style: GoogleFonts.raleway(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: FlowColors.textLight,
                                    height: 1.35,
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(flex: 2),
                          // Sign-in button (standardized CTA)
                          CtaButton(
                            label: _isLoading ? 'Logging in...' : 'Continue with Google',
                            onPressed: _handleGoogleSignIn,
                            loading: _isLoading,
                            leading: _isLoading
                                ? null
                                : _GoogleLogoOrIcon(color: cs.onSecondary),
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
        ],
      ),
    );
  }
}

// Replace existing _FloatingCoordinates and _CoordSpec with this code.

class _FloatingCoordinates extends StatefulWidget {
  const _FloatingCoordinates({this.debug = false, this.seed});
  final bool debug;
  final int? seed; // optional deterministic seed for testing

  @override
  State<_FloatingCoordinates> createState() => _FloatingCoordinatesState();
}

class _FloatingCoordinatesState extends State<_FloatingCoordinates>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _rand = Random();
  late List<_CoordState> _stateCoords;

  // list of coordinate strings to display (add/remove as you like)
  final List<String> _texts = const [
    '24.57°N, 80.12°E',
    '51.50°N, 0.12°W',
    '35.68°N, 139.69°E',
    '46.95°N, 7.44°E',
    '40.71°N, 74.00°W',
    '34.05°N, 118.24°W',
    '48.85°N, 2.35°E',
    '19.07°N, 72.87°E',
  ];

  @override
  void initState() {
    super.initState();
    // generate deterministic positions if seed provided (useful for testing)
    _stateCoords = (widget.seed != null) ? _generateCoords(Random(widget.seed)) : _generateCoords(_rand);

    // longer loop for subtle motion in production, faster in debug to verify movement
    _controller = AnimationController(
      vsync: this,
      duration: widget.debug ? const Duration(seconds: 6) : const Duration(seconds: 20),
    )..repeat();
  }

  List<_CoordState> _generateCoords(Random r) {
    // central exclusion rectangle (fractions) - tune to match where your logo/tagline sits
    const centerLeft = 0.22;
    const centerTop = 0.28;
    const centerRight = 0.78;
    const centerBottom = 0.60;

    List<_CoordState> out = [];
    for (var i = 0; i < _texts.length; i++) {
      double x, y;
      int tries = 0;
      do {
        x = r.nextDouble() * 0.96 + 0.02; // avoid exact edges
        y = r.nextDouble() * 0.92 + 0.02;
        tries++;
      } while (x >= centerLeft && x <= centerRight && y >= centerTop && y <= centerBottom && tries < 20);

      // random drift up to ~12% of screen dims (can be negative to move in any direction)
      final driftX = (r.nextDouble() * 0.12) * (r.nextBool() ? 1 : -1);
      final driftY = (r.nextDouble() * 0.12) * (r.nextBool() ? 1 : -1);

      // duration per item slight variance
      final seconds = 10 + r.nextInt(12); // 10..21s

      out.add(_CoordState(
        text: _texts[i],
        startXFrac: x,
        startYFrac: y,
        driftXFrac: driftX,
        driftYFrac: driftY,
        seconds: seconds,
      ));
    }
    return out;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // compute eased local t per item (0..1)
  double _localT(double global, int itemSeconds) {
    final base = widget.debug ? 6.0 : 20.0;
    final local = (global * (base / itemSeconds)) % 1.0;
    return Curves.easeInOut.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final baseColor = widget.debug ? Colors.white : FlowColors.promoTextPaleBlue;

    // Visual tuning constants (tweak these if you want a stronger or subtler look)
    final double baseFontSize = widget.debug ? 15.0 : 13.0;
    final double baseAlphaMul = widget.debug ? 0.95 : 0.40; // main text alpha multiplier (higher -> more visible)
    final double glowAlphaMul = widget.debug ? 0.40 : 0.12; // glow alpha behind label
    final double glowBlur = widget.debug ? 6.0 : 8.0; // blur radius for glow
    final double glowScale = 1.45; // glow text scale relative to main text
    final double pulseAmount = reduceMotion ? 0.0 : 0.035; // how much each label pulses (disabled if reduce-motion)
    final double shadowOpacity = widget.debug ? 0.25 : 0.10; // subtle shadow for legibility

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: _stateCoords.map((c) {
              // if reduced-motion is on, use a static t so text stays visible and not moving
              final rawGlobal = _controller.value;
              final global = reduceMotion ? 0.5 : rawGlobal;
              final t = _localT(global, c.seconds);

              // compute current fractional position = start + drift * t
              final curXFrac = (c.startXFrac + c.driftXFrac * t).clamp(0.02, 0.98);
              final curYFrac = (c.startYFrac + c.driftYFrac * t).clamp(0.02, 0.95);

              // convert to pixels
              final leftPx = curXFrac * size.width;
              final topPx = curYFrac * size.height;

              // fade in/out: peak at t ~ 0.5
              final fade = (1 - ((t - 0.5).abs() * 2)).clamp(0.0, 1.0);

              // slight organic wiggle so motion doesn't feel perfectly linear
              final wiggleX = 8.0 * (0.5 - (t - 0.5).abs());
              final wiggleY = 6.0 * (0.5 - (t - 0.5).abs());

              // local pulse (scale) — peaks at t=0.5
              final pulse = 1.0 + pulseAmount * (0.5 - (t - 0.5).abs()) * 2.0;

              // main color and text style
              final mainColor = baseColor.withOpacity((baseAlphaMul * fade).clamp(0.0, 0.95));
              final mainStyle = GoogleFonts.robotoMono(
                fontSize: baseFontSize,
                fontWeight: FontWeight.w500,
                color: mainColor,
                letterSpacing: 0.35,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(shadowOpacity),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              );

              // glow color & style (larger, blurred behind)
              final glowColor = baseColor.withOpacity((glowAlphaMul * fade).clamp(0.0, 0.6));
              final glowStyle = GoogleFonts.robotoMono(
                fontSize: baseFontSize * glowScale,
                fontWeight: FontWeight.w600,
                color: glowColor,
                letterSpacing: 0.35,
              );

              return Positioned(
                left: (leftPx + (c.driftXFrac >= 0 ? wiggleX : -wiggleX)),
                top: (topPx + (c.driftYFrac >= 0 ? -wiggleY : wiggleY)),
                child: Transform.scale(
                  scale: pulse.clamp(0.96, 1.06),
                  child: SizedBox(
                    // give room for glow so it doesn't clip
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // glow layer: blurred, larger text behind
                        ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(sigmaX: glowBlur, sigmaY: glowBlur),
                          child: Opacity(
                            opacity: glowColor.opacity,
                            child: Transform.translate(
                              offset: const Offset(0, 0),
                              child: Text(c.text, style: glowStyle),
                            ),
                          ),
                        ),

                        // main readable text on top
                        Text(c.text, style: mainStyle),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CoordState {
  final String text;
  final double startXFrac;
  final double startYFrac;
  final double driftXFrac;
  final double driftYFrac;
  final int seconds;

  _CoordState({
    required this.text,
    required this.startXFrac,
    required this.startYFrac,
    required this.driftXFrac,
    required this.driftYFrac,
    required this.seconds,
  });
}

// Small helper to render Google logo if present in assets, fallback to icon
class _GoogleLogoOrIcon extends StatelessWidget {
  final Color color;
  const _GoogleLogoOrIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    // We attempt to load 'assets/icons/google_logo.png' if developer uploads it.
    // If not available, gracefully fallback to a login icon.
    return SizedBox(
      width: 22,
      height: 22,
      child: Image.asset(
        'assets/icons/google_logo.png',
        errorBuilder: (context, error, stackTrace) => Icon(Icons.login, color: color, size: 22),
        fit: BoxFit.contain,
      ),
    );
  }
}