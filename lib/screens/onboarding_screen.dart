import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/widgets/cta_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});
  final VoidCallback? onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final _pages = const [
    _OnbPage(
      imagePath: 'assets/images/onboarding1.png',
      title: 'Discover Your Awe',
      subtitle: 'Find the trips, stories, and places that make you feel alive.',
    ),
    _OnbPage(
      imagePath: 'assets/images/onboarding2.png',
      title: 'AI Crafted Itineraries',
      subtitle: 'Get clean, simple itineraries crafted uniquely for your travel style.',
    ),
    _OnbPage(
      imagePath: 'assets/images/onboarding3.png',
      title: 'Start Your Quests',
      subtitle: "Take on micro-adventures, complete travel challenges, and unlock new experiences.",
    ),
  ];

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      widget.onFinished?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Subtle gradient header accent
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              FlowColors.primaryDarkDeep.withValues(alpha: 0.9),
                              FlowColors.primaryDark,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => _pages[i],
                  ),
                  Positioned(
                    top: 8,
                    right: 16,
                    child: TextButton(
                      onPressed: widget.onFinished,
                      child: Text('Skip', style: GoogleFonts.raleway(color: FlowColors.paleBlue, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  height: 8,
                  width: active ? 20 : 8,
                  decoration: BoxDecoration(
                    color: active ? FlowColors.softTealLight : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: CtaButton(
                label: _index == _pages.length - 1 ? 'Get Started' : 'Next',
                onPressed: _next,
                //leadingIcon: _index == _pages.length - 1 ? Icons.rocket_launch_outlined : Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnbPage extends StatelessWidget {
  const _OnbPage({required this.imagePath, required this.title, required this.subtitle});
  final String imagePath;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          // Hero icon in soft card
          Image.asset(imagePath),
          // Container(
          //   height: 180,
          //   width: double.infinity,
          //   decoration: BoxDecoration(
          //     color: FlowColors.cardSurfaceDark,
          //     borderRadius: BorderRadius.circular(24),
          //     border: Border.all(color: FlowColors.cardBorderDark.withValues(alpha: 0.06)),
          //   ),
          //   child: Center(
          //     child: Icon(icon, size: 88, color: FlowColors.softTealLight),
          //   ),
          // ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: FlowColors.textLight),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: 0.85,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: FlowColors.promoTextPaleBlue),
            ),
          ),
        ],
      ),
    );
  }
}
