import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wanderwell/bloc/wonder_cubit.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/models/wonder_user_state.dart';
import 'package:wanderwell/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wanderwell/widgets/related_wonders.dart';

class DailyWonderScreen extends StatelessWidget {
  const DailyWonderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WonderCubit()..loadTodayWonder(),
      child: const _DailyWonderView(),
    );
  }
}

class _DailyWonderView extends StatelessWidget {
  const _DailyWonderView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WonderCubit, WonderState>(
      builder: (context, state) {
        if (state is WonderLoaded) {
          return _WonderContent(
            wonder: state.wonder,
            userState: state.userState,
            globalLikeCount: state.globalLikeCount,
          );
        }
        if (state is WonderError) {
          return Scaffold(
            backgroundColor: AweColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 48, color: AweColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('Couldn\'t load today\'s wonder', style: GoogleFonts.sourceSans3(color: AweColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.read<WonderCubit>().loadTodayWonder(refresh: true),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AweColors.background,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AweColors.accentTeal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Discovering today\'s wonder...',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    letterSpacing: 0.5,
                    color: AweColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WonderContent extends StatelessWidget {
  final Wonder wonder;
  final WonderUserState userState;
  final int globalLikeCount;
  const _WonderContent({required this.wonder, required this.userState, required this.globalLikeCount});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(wonder.category);
    final emotion = WonderEmotion.fromString(wonder.emotion);
    final isSaved = userState.isWonderSaved(wonder.id);
    final storyParagraphs = wonder.story.split('\n').where((p) => p.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: AweColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero — clean image, no overlay
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroImage(),
                  // Category pill — top right
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 14,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: category.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            category.label.toUpperCase(),
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w500,
                              color: AweColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Location — bottom right
                  Positioned(
                    right: 16,
                    bottom: 14,
                    child: Text(
                      '${wonder.place.name.toUpperCase()}, ${wonder.place.region.toUpperCase()}',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Title section — below image
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${emotion.label.toUpperCase()} · ${DateFormat('d MMMM yyyy').format(DateTime.now()).toUpperCase()}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10.5,
                      letterSpacing: 1.4,
                      color: emotion.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    wonder.title,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 36,
                      height: 1.1,
                      color: AweColors.accentSlate,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    wonder.subtitle,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: AweColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(width: 40, height: 2, color: AweColors.accentGold),
                ],
              ),
            ),
          ),
          // Meta row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${wonder.place.name.toUpperCase()} · ${wonder.place.region.toUpperCase()}, ${wonder.place.country.toUpperCase()}',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            letterSpacing: 0.3,
                            color: AweColors.textSecondary,
                            height: 1.5,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${wonder.place.lat.toStringAsFixed(2)}°${wonder.place.lat >= 0 ? 'N' : 'S'}, ${wonder.place.lon.toStringAsFixed(2)}°${wonder.place.lon >= 0 ? 'E' : 'W'}',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            letterSpacing: 0.3,
                            color: AweColors.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (userState.currentStreak > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: AweColors.streakBackground,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department, size: 13, color: AweColors.streakFlame),
                          const SizedBox(width: 6),
                          Text(
                            '${userState.currentStreak}',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AweColors.accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Story body
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= storyParagraphs.length) return null;
                  final para = storyParagraphs[index];
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 17),
                      child: Text(
                        para,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 16.5,
                          height: 1.74,
                          color: AweColors.textBody,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 17),
                    child: Text(
                      para,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 16.5,
                        height: 1.74,
                        color: AweColors.textBody,
                      ),
                    ),
                  );
                },
                childCount: storyParagraphs.length,
              ),
            ),
          ),
          // Did you know
          if (wonder.curiositySpark.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AweColors.sparkBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✦ DID YOU KNOW',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: AweColors.sparkAccent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        wonder.curiositySpark,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 15.5,
                          height: 1.62,
                          color: const Color(0xFF2C3A42),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Actions
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 34),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  // Save
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.read<WonderCubit>().toggleLike(wonder.id),
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: isSaved ? AweColors.sparkBackground : AweColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSaved ? AweColors.accentTeal.withValues(alpha: 0.3) : AweColors.divider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSaved ? Icons.favorite : Icons.favorite_border,
                              size: 22,
                              color: isSaved ? const Color(0xFFB5483D) : AweColors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSaved ? 'Liked' : 'Like',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSaved ? const Color(0xFFB5483D) : AweColors.textPrimary,
                                  ),
                                ),
                                if (globalLikeCount > 0)
                                  Text(
                                    '$globalLikeCount ${globalLikeCount == 1 ? 'like' : 'likes'}',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 10,
                                      color: AweColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Share
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        SharePlus.instance.share(
                          ShareParams(
                            title: wonder.title,
                            text: '${wonder.title}\n\n"${wonder.subtitle}"\n\n— Discovered on Awe\nhttps://play.google.com/store/apps/details?id=com.feelsgood.awe',
                          ),
                        );
                      },
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: AweColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AweColors.divider),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.north_east, size: 18, color: AweColors.textPrimary),
                            const SizedBox(height: 5),
                            Text(
                              'Share',
                              style: GoogleFonts.sourceSans3(fontSize: 12.5, color: AweColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Plan a trip
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed(
                        '/itinerary',
                        arguments: {'destination': '${wonder.place.name}, ${wonder.place.country}'},
                      ),
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: AweColors.buttonPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('✈ ', style: const TextStyle(fontSize: 15)),
                            Text(
                              'Plan a trip',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Related Wonders
          SliverToBoxAdapter(
            child: RelatedWonders(currentWonder: wonder),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    if (wonder.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: wonder.imageUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildHeroGradient(),
      );
    }
    return _buildHeroGradient();
  }

  Widget _buildHeroGradient() {
    final category = WonderCategory.fromString(wonder.category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            category.color.withValues(alpha: 0.4),
            AweColors.accentSlate,
          ],
        ),
      ),
    );
  }
}

