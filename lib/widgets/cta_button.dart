import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A standardized bottom CTA button used across the app.
///
/// Matches the Welcome screen “Hop In” dimensions and style:
/// - Height: 56
/// - Pill radius: 28
/// - Background: Theme.of(context).colorScheme.secondary
/// - Foreground: Theme.of(context).colorScheme.onSecondary
/// - Optional leading widget or auto icon
/// - Optional loading state (shows a small spinner and disables tap)
class CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? leading;
  final IconData? leadingIcon;

  const CtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.leading,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = loading || onPressed == null;

    // We keep a consistent tap target and rounded pill appearance
    final child = AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled ? 0.85 : 1.0,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.secondary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: cs.secondary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
              ] else if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ] else if (leadingIcon != null) ...[
                Icon(leadingIcon, color: cs.onSecondary),
                const SizedBox(width: 12),
              ],
              Text(
                label,
                style: GoogleFonts.sourceSans3(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (disabled) {
      return child;
    }

    // Gentle press scale (without ripple splash effects)
    return _PressScale(
      onTap: onPressed!,
      child: child,
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(TapDownDetails d) => _controller.forward();
  void _up(TapUpDetails d) {
    _controller.reverse();
    widget.onTap();
  }
  void _cancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(scale: _scale.value, child: widget.child),
      ),
    );
  }
}
