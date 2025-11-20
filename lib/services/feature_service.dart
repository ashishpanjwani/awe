import 'package:flutter/material.dart';
import 'package:wanderwell/models/feature_card.dart';
import 'package:wanderwell/theme.dart';

class FeatureService {
  static final FeatureService _instance = FeatureService._internal();
  factory FeatureService() => _instance;
  FeatureService._internal();

  // Fully local, non-dynamic features list
  static final List<FeatureCard> _features = _buildLocalFeatures();

  // Public API stays async for compatibility with existing callers
  Future<List<FeatureCard>> getFeatures() async {
    // Simulate tiny delay for smoother transition if needed
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _features;
  }

  // Optional stream for future use; emits the same local list
  Stream<List<FeatureCard>> getFeaturesStream() => Stream.value(_features);

  static List<FeatureCard> _buildLocalFeatures() {
    final now = DateTime.now();
    return [
      FeatureCard(
        id: 'itinerary',
        title: 'Itinerary',
        subtitle: 'Builder',
        icon: Icons.map_outlined,
        gradientColors: [
           // Use dark-friendly, fully opaque tones (no translucency)
           FlowColors.featurePrimaryEndDark,
           FlowColors.featurePrimaryStartDark,
        ],
        route: '/itinerary',
        createdAt: now,
        updatedAt: now,
      ),
      FeatureCard(
        id: 'quest',
        title: 'Quest',
        subtitle: '',
        icon: Icons.flight_takeoff,
        gradientColors: [
          FlowColors.featureTealEndDark,
          FlowColors.featureTealStartDark,
        ],
        route: '/quest',
        createdAt: now,
        updatedAt: now,
      ),
      FeatureCard(
        id: 'discover',
        title: 'Discover',
        subtitle: '',
        icon: Icons.explore_outlined,
        gradientColors: [
          FlowColors.featureCoralEndDark,
          FlowColors.featureCoralStartDark,
        ],
        route: '/discover',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
