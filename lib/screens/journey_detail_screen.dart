import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/bloc/journey_cubit.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/journey.dart';
import 'package:wanderwell/theme.dart';

class JourneyDetailScreen extends StatelessWidget {
  final String journeyId;
  const JourneyDetailScreen({super.key, required this.journeyId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => JourneyCubit()..loadJourney(journeyId),
      child: Scaffold(
        backgroundColor: AweColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<JourneyCubit, JourneyState>(
          builder: (context, state) {
            if (state is JourneyDetailLoaded) {
              return _JourneyDetailContent(journey: state.journey);
            }
            if (state is JourneyError) {
              return Center(
                child: Text(
                  'Journey not found',
                  style: GoogleFonts.sourceSans3(color: AweColors.textSecondary),
                ),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: AweColors.accentTerracotta),
            );
          },
        ),
      ),
    );
  }
}

class _JourneyDetailContent extends StatelessWidget {
  final Journey journey;
  const _JourneyDetailContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(journey.category);
    final emotion = WonderEmotion.fromString(journey.emotion);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(category.icon, size: 16, color: category.color),
                    const SizedBox(width: 5),
                    Text(
                      category.label,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: category.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: emotion.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  emotion.label,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: emotion.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            journey.title,
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AweColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            journey.description,
            style: GoogleFonts.sourceSans3(
              fontSize: 16,
              color: AweColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AweColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _InfoTile(label: 'Days', value: '${journey.dayCount}'),
                Container(
                  width: 1,
                  height: 32,
                  color: AweColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                ),
                _InfoTile(label: 'Type', value: category.label),
                Container(
                  width: 1,
                  height: 32,
                  color: AweColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                ),
                _InfoTile(label: 'Mood', value: emotion.label),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Day-by-day placeholder
          Text(
            'Journey Wonders',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AweColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(journey.dayCount, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AweColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AweColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: category.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        index < journey.wonderIds.length
                            ? 'Wonder: ${journey.wonderIds[index]}'
                            : 'Day ${index + 1} — Wonder coming soon',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 15,
                          color: AweColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      index < journey.wonderIds.length
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 20,
                      color: index < journey.wonderIds.length
                          ? category.color
                          : AweColors.border,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sourceSans3(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AweColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.sourceSans3(
              fontSize: 12,
              color: AweColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
