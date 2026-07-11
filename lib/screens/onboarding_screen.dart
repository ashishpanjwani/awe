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
      title: 'One Wonder, Every Day',
      subtitle: 'A hidden story from somewhere in the world — delivered fresh each morning.',
    ),
    _OnbPage(
      imagePath: 'assets/images/onboarding2.png',
      title: 'Your Atlas Grows',
      subtitle: 'Every wonder you like pins a new place on your personal globe.',
    ),
    _OnbPage(
      imagePath: 'assets/images/onboarding3.png',
      title: 'Unearth Collections',
      subtitle: 'Dive deeper into curated sets — from lost cities to sounds nobody expected.',
    ),
  ];

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onFinished?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AweColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
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
                      child: Text(
                        'Skip',
                        style: GoogleFonts.sourceSans3(
                          color: AweColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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
                    color: active
                        ? AweColors.accentTerracotta
                        : AweColors.border,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnbPage extends StatelessWidget {
  const _OnbPage({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
  final String imagePath;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              AweColors.accentSlate,
              BlendMode.srcIn,
            ),
            child: Image.asset(imagePath),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AweColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
