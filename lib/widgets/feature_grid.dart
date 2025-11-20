import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/models/feature_card.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/widgets/animated_button.dart';

class FeatureGrid extends StatelessWidget {
  final List<FeatureCard> features;

  const FeatureGrid({
    super.key,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    if (features.length < 3) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          // Large card on the left (Itinerary Builder)
          Expanded(
            flex: 3,
            child: _buildFeatureCard(
              context,
              features[0],
              isLarge: true,
              isCompact: false,
            ),
          ),
          const SizedBox(width: 16),
          // Two medium cards on the right
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: _buildFeatureCard(context, features[1], isCompact: true),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildFeatureCard(context, features[2], isCompact: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext ctx, FeatureCard feature, {bool isLarge = false, bool isCompact = false}) {
    // Ensure we always have a valid gradient with at least 2 colors.
    // If the incoming list is malformed or too short, fall back to a safe default.
    final List<Color> safeGradient = (feature.gradientColors.length >= 2)
        ? <Color>[feature.gradientColors[0], feature.gradientColors[1]]
        : <Color>[FlowColors.cardGradientStartDark, FlowColors.cardGradientEndDark];

    return AnimatedButton(
      onTap: () {
        try {
          if (feature.id == 'discover') {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text("Something exciting is cooking. Stay tuned!")),
            );
            return;
          }
          if (feature.route.isNotEmpty) {
            Navigator.of(ctx).pushNamed(feature.route);
          } else {
            debugPrint('[FeatureGrid] Empty route for feature: ${feature.id}');
          }
        } catch (e) {
          debugPrint('[FeatureGrid] Navigation error: $e');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          // Use a fully opaque, dark-friendly fill to ensure visibility
          color: safeGradient.first,
          borderRadius: BorderRadius.circular(24),
          // Stronger outline for contrast on #0B1C2E background
          border: Border.all(color: FlowColors.textLight.withValues(alpha: 0.22)),
        ),
        child: Stack(
          children: [
            // Arrow indicator in top-right
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FlowColors.textLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: FlowColors.textLight,
                ),
              ),
            ),
            // Content
            Positioned(
              bottom: 16,
              left: 16,
              // Reserve a bit less space on compact cards so text doesn’t look squeezed
              right: isLarge ? 60 : (isCompact ? 44 : 54),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FlowColors.textLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      feature.icon,
                      size: isLarge ? 28 : 22,
                      color: FlowColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    feature.title,
                    style: GoogleFonts.raleway(
                      fontSize: isLarge ? 20 : 15,
                      fontWeight: FontWeight.w600,
                      color: FlowColors.textLight,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (feature.subtitle.isNotEmpty) ...[
                    Text(
                      feature.subtitle,
                      style: GoogleFonts.raleway(
                        fontSize: isLarge ? 20 : 15,
                        fontWeight: FontWeight.w600,
                        color: FlowColors.textLight,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
