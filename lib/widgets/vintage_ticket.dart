import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/theme.dart';

/// A vintage, ticket-styled banner with a passport stamp on the left
/// and a random travel/place fact on the right.
///
/// Design notes:
/// - Dark-mode friendly parchment-like gradient using theme tokens
/// - Ticket cutouts on left/right edges via custom clipper
/// - Subtle grain overlay using a one-time random dot painter
/// - Perforated divider between stamp and fact
class VintageTicket extends StatelessWidget {
  const VintageTicket({super.key, required this.fact});

  final String fact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: ClipPath(
        clipper: _TicketClipper(notchRadius: 12),
        child: Stack(
          children: [
            // Background surface (flat, no gradient) with daily paper color
            _TicketSurface(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Stamp area (left) — do NOT apply any overlays to this image
                    SizedBox(
                     height: 80,
                     width: 80,
                      child: Transform.rotate(
                        angle: -0.30,
                        child: Image.asset(
                          'assets/images/vintage_passport_stamp.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.local_activity_outlined,
                              color: FlowColors.accentBrown,
                              size: 44,
                            );
                          },
                        ),
                      ),
                    ),

                    // // Perforation divider
                     const SizedBox(width: 8),
                    SizedBox(
                      height: 54,
                      width: 1,
                      child: CustomPaint(
                        painter: _PerforationPainter(
                           color: _TicketSurface.onPaperColor(context),
                    //      color: FlowColors.cardBorderDark.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Fact text — we will add a right-side grain overlay above this area
                    Expanded(
                      child: _GrainyTextArea(
                        child: Text(
                          fact,
                          style: GoogleFonts.raleway(
                            color: _TicketSurface.onPaperColor(context),
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  _TicketClipper({required this.notchRadius});
  final double notchRadius;

  @override
  Path getClip(Size size) {
    final r = notchRadius;
    final path = Path();

    // Rounded rectangle base
    const corner = 18.0;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(corner),
    );
    path.addRRect(rect);

    // Subtract circular notches on left and right edges (centered vertically)
    final notchCenterY = size.height / 2;

    final leftNotch = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchCenterY), radius: r));
    final rightNotch = Path()
      ..addOval(Rect.fromCircle(center: Offset(size.width, notchCenterY), radius: r));

    // Use Path.combine to subtract ovals
    final withLeft = Path.combine(PathOperation.difference, path, leftNotch);
    final withBoth = Path.combine(PathOperation.difference, withLeft, rightNotch);
    return withBoth;
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldClipper) => oldClipper.notchRadius != notchRadius;
}

class _PerforationPainter extends CustomPainter {
  _PerforationPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dash = 3.0;
    const gap = 3.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), const Offset(0, 0).translate(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter oldDelegate) => false;
}

/// Flat colored ticket surface that rotates paper color daily.
class _TicketSurface extends StatelessWidget {
  const _TicketSurface({required this.child});
  final Widget child;

  static Color _paperColorForDay(DateTime date) {
    final palette = <Color>[
      FlowColors.ticketPaperCream,
      FlowColors.ticketPaperKraft,
      FlowColors.ticketPaperMint,
      FlowColors.ticketPaperPowder,
      FlowColors.ticketPaperRose,
      FlowColors.ticketPaperGrey,
    ];
    final base = DateTime.utc(2020, 1, 1);
    final days = date.toUtc().difference(base).inDays;
    return palette[days % palette.length];
  }

  static Color onPaperColor(BuildContext context) {
    final c = _paperColorForDay(DateTime.now());
    final lum = c.computeLuminance();
    // For our light papers, use dark ink; keep white if paper ever gets too dark
    return lum > 0.55 ? FlowColors.ticketInkDark : FlowColors.textLight;
  }

  @override
  Widget build(BuildContext context) {
    final paper = _paperColorForDay(DateTime.now());
    final borderColor = FlowColors.ticketInkDark.withValues(alpha: 0.14);
    return Stack(
      children: [
        // Paper surface
        DecoratedBox(
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
        // Background grain on the paper itself (very subtle), placed under content
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GrainPainter(
                seed: DateTime.now().day + DateTime.now().month * 31,
                density: 0.08,
                dotAlpha: 0.05,
                dotColor: FlowColors.ticketInkDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Applies a gentle grain overlay above its child to give a vintage ink feel.
/// We scope it to the right text area so the left stamp image remains pristine.
class _GrainyTextArea extends StatelessWidget {
  const _GrainyTextArea({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GrainPainter(
                seed: 4242 + DateTime.now().weekday,
                density: 0.18,
                dotAlpha: 0.06,
                dotColor: FlowColors.ticketInkDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.seed, required this.density, required this.dotAlpha, required this.dotColor});
  final int seed;
  final double density; // 0..1 (fraction of pixels to dot)
  final double dotAlpha; // 0..1
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final paint = Paint()
      ..color = dotColor.withValues(alpha: dotAlpha)
      ..style = PaintingStyle.fill;

    // Sample a limited number of dots based on area and density
    final area = size.width * size.height;
    final count = (area * 0.0025 * density).clamp(40, 600).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.5 + rnd.nextDouble() * 0.8; // tiny speckles
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}

// Note: VintageTicket no longer generates its own facts. The daily fact is
// selected and persisted by DailyFactService and passed in via `fact`.
