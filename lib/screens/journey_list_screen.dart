import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/bloc/journey_cubit.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/journey.dart';
import 'package:wanderwell/theme.dart';

class JourneyListScreen extends StatelessWidget {
  const JourneyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => JourneyCubit()..loadJourneys(),
      child: Scaffold(
        backgroundColor: AweColors.background,
        appBar: AppBar(
          title: Text(
            'Themed Journeys',
            style: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<JourneyCubit, JourneyState>(
          builder: (context, state) {
            if (state is JourneyListLoaded) {
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: state.journeys.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _JourneyCard(journey: state.journeys[index]);
                },
              );
            }
            if (state is JourneyError) {
              return Center(
                child: Text(
                  'Could not load journeys',
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

class _JourneyCard extends StatelessWidget {
  final Journey journey;
  const _JourneyCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(journey.category);
    final emotion = WonderEmotion.fromString(journey.emotion);

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        '/journeys/${journey.id}',
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AweColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AweColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(category.icon, size: 14, color: category.color),
                      const SizedBox(width: 4),
                      Text(
                        category.label,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: category.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AweColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    emotion.label,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AweColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${journey.dayCount} days',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AweColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              journey.title,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AweColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              journey.description,
              style: GoogleFonts.sourceSans3(
                fontSize: 14,
                color: AweColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (journey.premium) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.star, size: 14, color: AweColors.accentGold),
                  const SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AweColors.accentGold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
