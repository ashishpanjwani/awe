import 'package:flutter/material.dart';

/// AppViewport centers the entire app at a mobile width on large screens,
/// leaving elegant side gutters using the theme surface color.
///
/// This is applied globally via MaterialApp.builder so we don't have to
/// touch each screen's Scaffold.
class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});

  /// The subtree provided by MaterialApp (Navigator/Scaffold trees, etc.)
  final Widget? child;

  static const double _maxMobileWidth = 430; // iPhone 14 Pro Max logical width-ish

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final screenSize = MediaQuery.sizeOf(context);
    final targetWidth = screenSize.width < _maxMobileWidth
        ? screenSize.width
        : _maxMobileWidth;

    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: SizedBox(
          width: targetWidth,
          height: screenSize.height,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
