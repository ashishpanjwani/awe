import 'dart:math' as _math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/models/weather_data.dart';
import 'package:wanderwell/theme.dart';

class WeatherCard extends StatefulWidget {
  final WeatherData weather;
  final bool showEnableLocation;
  final VoidCallback? onEnableLocation;

  const WeatherCard({
    super.key,
    required this.weather,
    this.showEnableLocation = false,
    this.onEnableLocation,
  });

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  // Dev-only overrides to preview animations/conditions
  WeatherData? _overrideWeather;
  bool? _overrideIsDay;

  IconData _getWeatherIcon(String condition, {required bool isDay}) {
    switch (condition.toLowerCase()) {
      case 'sunny':
        return isDay ? Icons.wb_sunny : Icons.nights_stay;
      case 'cloudy':
        return Icons.cloud;
      case 'partly cloudy':
        return isDay ? Icons.wb_cloudy : Icons.cloud;
      case 'clear':
        return isDay ? Icons.wb_sunny_outlined : Icons.nights_stay;
      case 'rain':
      case 'showers':
        return Icons.grain; // raindrops style
      case 'drizzle':
        return Icons.grain;
      case 'snow':
        return Icons.ac_unit;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'fog':
        return Icons.dehaze;
      default:
        return isDay ? Icons.wb_sunny : Icons.nights_stay;
    }
  }

  void _openDebugSheet() {
    if (!kDebugMode) return;
    final conditions = <String>[
      'clear',
      'sunny',
      'partly cloudy',
      'cloudy',
      'rain',
      'drizzle',
      'snow',
      'thunderstorm',
      'fog',
    ];
    final current =
        (_overrideWeather ?? widget.weather).condition.toLowerCase();
    bool isDay =
        _overrideIsDay ?? (_overrideWeather?.isDay ?? widget.weather.isDay);
    showModalBottomSheet(
      context: context,
      backgroundColor: FlowColors.cardSurfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Weather Debug',
                        style: TextStyle(
                            color: FlowColors.textLight,
                            fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          color: FlowColors.textLight, size: 20),
                      onPressed: () {
                        setState(() {
                          _overrideWeather = null;
                          _overrideIsDay = null;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in conditions)
                      ChoiceChip(
                        label: Text(c,
                            style:
                                const TextStyle(color: FlowColors.textLight)),
                        selected: current == c,
                        onSelected: (_) {
                          setState(() {
                            final base = _overrideWeather ?? widget.weather;
                            _overrideWeather = base.copyWith(condition: c);
                          });
                        },
                        selectedColor: FlowColors.chipBgDark,
                        backgroundColor: FlowColors.primaryDarkVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Time:',
                        style: TextStyle(color: FlowColors.textGrey)),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Day',
                          style: TextStyle(color: FlowColors.textLight)),
                      selected: isDay,
                      onSelected: (_) {
                        setState(() {
                          _overrideIsDay = true;
                        });
                      },
                      selectedColor: FlowColors.chipBgDark,
                      backgroundColor: FlowColors.primaryDarkVariant,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Night',
                          style: TextStyle(color: FlowColors.textLight)),
                      selected: !isDay,
                      onSelected: (_) {
                        setState(() {
                          _overrideIsDay = false;
                        });
                      },
                      selectedColor: FlowColors.chipBgDark,
                      backgroundColor: FlowColors.primaryDarkVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWeather = _overrideWeather ?? widget.weather;
    final isDay = _overrideIsDay ?? effectiveWeather.isDay;
    final showEnableLocation = widget.showEnableLocation;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Background layer: only animate when we actually have weather and location is enabled
          if (!showEnableLocation &&
              effectiveWeather.condition.trim().isNotEmpty)
            Positioned.fill(
              child: _AnimatedWeatherBackdrop(
                condition: effectiveWeather.condition,
                isDay: isDay,
              ),
            )
          else
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FlowColors.primaryDarkDeep,
                ),
              ),
            ),
          // Subtle overlay to ensure text contrast
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FlowColors.primaryDark.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Foreground content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!showEnableLocation) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              effectiveWeather.city,
                              style: GoogleFonts.raleway(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: FlowColors.textLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              effectiveWeather.condition,
                              style: GoogleFonts.raleway(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color:
                                    FlowColors.textLight.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            _getWeatherIcon(effectiveWeather.condition,
                                isDay: isDay),
                            size: 28,
                            color: isDay
                                ? FlowColors.warmOrange
                                : FlowColors.paleBlue,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${effectiveWeather.temperature.round()}°',
                            style: GoogleFonts.raleway(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: FlowColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          effectiveWeather.city.isNotEmpty
                              ? effectiveWeather.city
                              : 'Location Off',
                          style: GoogleFonts.raleway(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: FlowColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Turn on location to see your local weather.',
                          style: GoogleFonts.raleway(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: FlowColors.textLight.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // if (showEnableLocation) ...[
                //   const SizedBox(height: 12),
                //   Align(
                //     alignment: Alignment.centerLeft,
                //     child: SizedBox(
                //       height: 38,
                //       child: FilledButton.icon(
                //         style: ButtonStyle(
                //           backgroundColor: WidgetStateProperty.all(FlowColors.softTealLight),
                //           foregroundColor: WidgetStateProperty.all(FlowColors.primaryDark),
                //           padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14)),
                //           shape: WidgetStateProperty.all(
                //             RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                //           ),
                //         ),
                //         onPressed: widget.onEnableLocation,
                //         icon: const Icon(Icons.my_location, size: 18, color: Colors.black),
                //         label: Text(
                //           'Enable location',
                //           style: GoogleFonts.raleway(
                //             fontSize: 14,
                //             fontWeight: FontWeight.w600,
                //             color: Colors.black,
                //           ),
                //         ),
                //       ),
                //     ),
                //   ),
                // ],
              ],
            ),
          ),

          // Dev-only debug trigger
          if (kDebugMode)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                iconSize: 18,
                onPressed: _openDebugSheet,
                icon: const Icon(Icons.bug_report, color: FlowColors.textLight),
                tooltip: 'Preview weather animations',
              ),
            ),
        ],
      ),
    );
  }
}

// Animated, asset‑free backdrop that adapts to weather + time of day.
class _AnimatedWeatherBackdrop extends StatefulWidget {
  final String condition;
  final bool isDay;
  const _AnimatedWeatherBackdrop(
      {required this.condition, required this.isDay});

  @override
  State<_AnimatedWeatherBackdrop> createState() =>
      _AnimatedWeatherBackdropState();
}

class _AnimatedWeatherBackdropState extends State<_AnimatedWeatherBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _lastCondition;
  bool? _lastIsDay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _lastCondition = widget.condition;
    _lastIsDay = widget.isDay;
    debugPrint(
        '[WeatherBackdrop] init condition=${widget.condition}, isDay=${widget.isDay}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AnimatedWeatherBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.condition != _lastCondition || widget.isDay != _lastIsDay) {
      debugPrint(
          '[WeatherBackdrop] change condition=${widget.condition}, isDay=${widget.isDay}');
      _lastCondition = widget.condition;
      _lastIsDay = widget.isDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WeatherScenePainter(
              t: _controller.value,
              condition: widget.condition,
              isDay: widget.isDay,
            ),
          );
        },
      ),
    );
  }
}

class _WeatherScenePainter extends CustomPainter {
  final double t; // 0..1 animation time
  final String condition;
  final bool isDay;
  _WeatherScenePainter(
      {required this.t, required this.condition, required this.isDay});

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient varies by time of day
    final bgTop =
        isDay ? FlowColors.primaryDarkVariant : FlowColors.primaryDarkDeep;
    final bgBottom =
        isDay ? FlowColors.featurePrimaryEndDark : FlowColors.primaryDark;

    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bgTop, bgBottom],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Normalize condition into buckets
    final c = condition.toLowerCase();
    if (c.contains('thunder')) {
      _drawRain(canvas, size, density: 0.9);
      _drawClouds(canvas, size, layer: 2);
      _drawLightning(canvas, size);
    } else if (c.contains('rain') ||
        c.contains('drizzle') ||
        c.contains('showers')) {
      _drawRain(canvas, size, density: 0.7);
      _drawClouds(canvas, size, layer: 2);
    } else if (c.contains('snow')) {
      _drawSnow(canvas, size);
      _drawClouds(canvas, size, layer: 2);
    } else if (c.contains('fog')) {
      _drawFog(canvas, size);
    } else if (c.contains('cloud')) {
      _drawClouds(canvas, size, layer: 3);
      if (isDay) _drawSun(canvas, size, subtle: true);
    } else if (c.contains('clear') || c.contains('sunny')) {
      if (isDay) {
        _drawSun(canvas, size);
      } else {
        _drawStars(canvas, size);
        _drawMoon(canvas, size);
      }
    } else {
      // default: partly cloudy day/night
      _drawClouds(canvas, size, layer: 2);
      if (isDay) {
        _drawSun(canvas, size, subtle: true);
      } else {
        _drawStars(canvas, size);
      }
    }
  }

  void _drawSun(Canvas canvas, Size size, {bool subtle = false}) {
    final center = Offset(size.width * 0.18, size.height * 0.28);
    final radius = subtle ? 16.0 : 22.0;
    final glowPaint = Paint()
      ..color = FlowColors.accentAmber.withValues(alpha: subtle ? 0.25 : 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius * 1.6, glowPaint);

    final sunPaint = Paint()..color = FlowColors.accentAmber;
    canvas.drawCircle(center, radius, sunPaint);

    // Rays rotate with time t
    final rays = 10;
    final rayPaint = Paint()
      ..strokeWidth = 2
      ..color = FlowColors.accentAmber.withValues(alpha: 0.7);
    final angle = t * 6.28318; // 2pi
    for (int i = 0; i < rays; i++) {
      final a = angle + (i * 6.28318 / rays);
      final dir = Offset(Maths.cos(a), Maths.sin(a));
      final start = center + dir * (radius + 4);
      final end = center + dir * (radius + 12);
      canvas.drawLine(start, end, rayPaint);
    }
  }

  void _drawMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.2, size.height * 0.25);
    final r = 16.0;
    final moonPaint = Paint()
      ..color = FlowColors.paleBlue.withValues(alpha: 0.9);
    canvas.drawCircle(center, r, moonPaint);
    final cutPaint = Paint()..color = FlowColors.primaryDarkDeep;
    canvas.drawCircle(center + const Offset(6, -2), r * 0.9, cutPaint);
  }

  void _drawStars(Canvas canvas, Size size) {
    final starPaint = Paint()
      ..color = FlowColors.paleBlue.withValues(alpha: 0.9);
    final count = 24;
    for (int i = 0; i < count; i++) {
      final phase = (t + i * 0.07) % 1.0;
      final alpha = 0.3 + 0.7 * (0.5 + 0.5 * Maths.sin(phase * 6.28318));
      starPaint.color = FlowColors.paleBlue.withValues(alpha: alpha);
      final x = (i * 37 % size.width).toDouble();
      final y = (i * 53 % (size.height * 0.6)).toDouble() + 4;
      canvas.drawCircle(Offset(x, y), 1.3, starPaint);
    }
  }

  void _drawClouds(Canvas canvas, Size size, {int layer = 2}) {
    // Ensure clouds never "pop" into view by:
    // 1) Spawning the entire cluster offscreen (both sides) with an extra spread buffer
    // 2) Applying a smooth edge fade-in/out per individual puff
    final baseColor = FlowColors.paleBlue.withValues(alpha: 0.75);
    for (int l = 0; l < layer; l++) {
      // Parallax speed: nearer layers move faster
      final speed = 0.15 + l * 0.12; // cycles per controller duration
      final phase = (t * speed + l * 0.17) % 1.0;

      // Cluster spread ensures even the left-most puff of the cluster starts offscreen
      const clusterSpread = 260.0; // wider than farthest negative offset below
      final startX = size.width + clusterSpread;
      final endX = -clusterSpread;
      final baseX = _lerp(startX, endX, phase);
      final y = size.height * (0.18 + l * 0.12);

      // Layer depth affects scale slightly
      final s0 = 1.0 - l * 0.1;
      final s1 = 0.9 - l * 0.1;
      final s2 = 0.8 - l * 0.1;

      // Paint each puff with per-puff edge fading
      _drawCloud(canvas, baseColor, Offset(baseX, y),
          scale: s0, width: size.width);
      _drawCloud(canvas, baseColor, Offset(baseX - 120, y + 12),
          scale: s1, width: size.width);
      _drawCloud(canvas, baseColor, Offset(baseX - 220, y - 6),
          scale: s2, width: size.width);
    }
  }

  void _drawCloud(Canvas canvas, Color color, Offset c,
      {double scale = 1, required double width}) {
    // Edge fade-in/out near screen bounds to avoid popping
    const fade = 64.0; // fade span in px on each side
    double edgeFade(double x) {
      final fadeIn =
          _smoothstep(width + fade, width - 4, x); // from offscreen -> edge
      final fadeOut = _smoothstep(-fade, 4, x); // from edge -> offscreen left
      // When within viewport, both functions ~1; outside, one of them reduces alpha
      final a = _clamp01(fadeIn) * _clamp01(fadeOut);
      return a;
    }

    final alpha = edgeFade(c.dx);
    if (alpha <= 0.01) return;
    final paint = Paint()
      ..color = color.withValues(alpha: color.opacity * alpha);

    final r = 14.0 * scale;
    // Draw puffs
    void puff(Offset o, double s) {
      final a = edgeFade((c + o).dx);
      if (a <= 0.01) return;
      paint.color = color.withValues(alpha: color.opacity * a);
      canvas.drawCircle(c + o, r * s, paint);
    }

    puff(const Offset(0, 0), 1.0);
    puff(const Offset(18, -6), 0.9);
    puff(const Offset(-14, -4), 0.8);

    // Body
    final bodyX = c.dx - 26 * scale;
    final bodyAlpha = edgeFade(bodyX + 26 * scale);
    if (bodyAlpha > 0.01) {
      paint.color = color.withValues(alpha: color.opacity * bodyAlpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bodyX, c.dy - 6 * scale, 52 * scale, 18 * scale),
          Radius.circular(10 * scale),
        ),
        paint,
      );
    }
  }

  // Helpers
  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  // Smoothstep: remaps x between edge0..edge1 to 0..1 smoothly
  double _smoothstep(double edge0, double edge1, double x) {
    final t = _clamp01((x - edge0) / (edge1 - edge0));
    return t * t * (3 - 2 * t);
  }

  void _drawRain(Canvas canvas, Size size, {double density = 0.6}) {
    final drops = (60 * density).toInt();
    final paint = Paint()
      ..color = FlowColors.softTealLight.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < drops; i++) {
      final px = (i * 23 % size.width).toDouble();
      final speed = 40 + (i % 5) * 12;
      final py = (t * speed + i * 7) % (size.height);
      canvas.drawLine(Offset(px, py), Offset(px + 2, py + 8), paint);
    }
  }

  void _drawSnow(Canvas canvas, Size size) {
    final flakes = 36;
    final paint = Paint()
      ..color = FlowColors.cardBorderDark.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < flakes; i++) {
      final px = (i * 31 % size.width).toDouble();
      final base = (i * 17) % size.height;
      final py = (base + t * 30 + (i % 5) * 8) % size.height;
      final r = 1.2 + (i % 3) * 0.3;
      canvas.drawCircle(Offset(px, py), r, paint);
    }
  }

  void _drawFog(Canvas canvas, Size size) {
    final layers = 3;
    for (int i = 0; i < layers; i++) {
      final alpha = 0.08 + i * 0.06;
      final paint = Paint()
        ..color = FlowColors.paleBlue.withValues(alpha: alpha);
      final y = size.height * (0.25 + i * 0.16);
      final dx = size.width * (0.2 * Maths.sin((t + i * 0.2) * 6.28318));
      final rect = Rect.fromLTWH(-20 + dx, y, size.width + 40, 18);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)), paint);
    }
  }

  void _drawLightning(Canvas canvas, Size size) {
    // Flash occasionally
    final phase = (t * 4) % 1.0; // four cycles per loop
    if (phase < 0.08) {
      final flash = Paint()..color = Colors.white.withValues(alpha: 0.06);
      canvas.drawRect(Offset.zero & size, flash);
    }
    // Bolt
    if (phase < 0.12) {
      final x = size.width * 0.7;
      final y = size.height * 0.1;
      final p = Path()
        ..moveTo(x, y)
        ..lineTo(x - 10, y + 24)
        ..lineTo(x + 2, y + 24)
        ..lineTo(x - 16, y + 56)
        ..lineTo(x + 12, y + 34)
        ..lineTo(x, y);
      final bolt = Paint()
        ..color = FlowColors.accentAmber.withValues(alpha: 0.9);
      canvas.drawPath(p, bolt);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherScenePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.condition != condition ||
        oldDelegate.isDay != isDay;
  }
}

// Light helpers for math without importing dart:math directly in painter logic
class Maths {
  static const double pi = 3.1415926535897932;
  static double sin(double x) => MathCore.sin(x);
  static double cos(double x) => MathCore.cos(x);
}

// Use a tiny math core to keep names short
class MathCore {
  static double sin(double x) => _sin(x);
  static double cos(double x) => _cos(x);
}

// Dart's math functions proxied so we don't pollute namespace in painter
double _sin(double x) => _MathLib.sin(x);
double _cos(double x) => _MathLib.cos(x);

// Actual math import hidden behind a private class to keep painter tidy
class _MathLib {
  static double sin(double x) => _math.sin(x);
  static double cos(double x) => _math.cos(x);
}
