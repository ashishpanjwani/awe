import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/models/wonder_collection.dart';
import 'package:wanderwell/services/collection_service.dart';
import 'package:wanderwell/services/premium_service.dart';
import 'package:wanderwell/theme.dart';

String _formatWonderDate(String dateId) {
  final date = DateTime.tryParse(dateId);
  if (date == null) return dateId;
  final now = DateTime.now();
  if (date.year == now.year) {
    return DateFormat('d MMMM').format(date);
  }
  return DateFormat('d MMM yyyy').format(date);
}

class LibraryTabScreen extends StatefulWidget {
  const LibraryTabScreen({super.key});

  @override
  State<LibraryTabScreen> createState() => _LibraryTabScreenState();
}

class _LibraryTabScreenState extends State<LibraryTabScreen> {
  List<Wonder> _trail = [];
  List<WonderCollection> _collections = [];
  bool _loading = true;
  StreamSubscription<bool>? _premiumSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _premiumSub = PremiumService().onPremiumActivated.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      CollectionService().getWonderTrail(limit: 20),
      CollectionService().getCollections(),
    ]);
    if (mounted) {
      setState(() {
        _trail = results[0] as List<Wonder>;
        _collections = results[1] as List<WonderCollection>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AweColors.accentTeal))
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNEARTH',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 10,
                              letterSpacing: 1.8,
                              color: const Color(0xFFA08A64),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your world\nof wonder',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 28,
                              height: 1.1,
                              color: AweColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Wonder Trail section
                  if (_trail.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                        child: Row(
                          children: [
                            Text(
                              'Wonder Trail',
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 20,
                                color: AweColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_trail.length} WONDERS',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                color: AweColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _trail.length > 5 ? 6 : _trail.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final isPremium = PremiumService().isPremium;
                            if (index == 5) {
                              return _SeeAllCard(
                                count: _trail.length - 5,
                                onTap: () => Navigator.of(context).pushNamed(
                                  isPremium ? '/wonder/past' : '/paywall',
                                ),
                              );
                            }
                            final isLocked = index >= 7 && !isPremium;
                            return _WonderTrailCard(
                              wonder: _trail[index],
                              isLocked: isLocked,
                              onTap: () {
                                if (isLocked) {
                                  Navigator.of(context).pushNamed('/paywall');
                                } else {
                                  Navigator.of(context).pushNamed('/wonder/daily/${_trail[index].id}');
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // Collections section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                      child: Row(
                        children: [
                          Text(
                            'Collections',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 20,
                              color: AweColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_collections.length} SETS',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              color: AweColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _CollectionCard(
                              collection: _collections[index],
                              onTap: () {
                                final c = _collections[index];
                                if (!c.isFree && !PremiumService().isPremium) {
                                  Navigator.of(context).pushNamed('/paywall');
                                } else {
                                  Navigator.of(context).pushNamed('/collections/${c.id}');
                                }
                              },
                            ),
                          );
                        },
                        childCount: _collections.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WonderTrailCard extends StatelessWidget {
  final Wonder wonder;
  final VoidCallback onTap;
  final bool isLocked;
  const _WonderTrailCard({required this.wonder, required this.onTap, this.isLocked = false});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(wonder.category);
    final hasImage = wonder.imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: wonder.imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [category.color.withValues(alpha: 0.3), category.color],
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [category.color.withValues(alpha: 0.3), category.color],
                              ),
                            ),
                          ),
                  ),
                ),
                if (isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock_outline, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Date + category
            Text(
              '${_formatWonderDate(wonder.id)} · ${category.label.toUpperCase()}',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 9,
                letterSpacing: 0.6,
                color: category.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Title
            Text(
              wonder.title,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 15,
                height: 1.15,
                color: AweColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeeAllCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _SeeAllCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AweColors.accentSlate.withValues(alpha: 0.08),
                border: Border.all(color: const Color(0xFFECE3D4)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 24, color: AweColors.accentSlate),
                    const SizedBox(height: 8),
                    Text(
                      '+$count more',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AweColors.accentSlate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'See all past',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 15,
                height: 1.15,
                color: AweColors.accentSlate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final WonderCollection collection;
  final VoidCallback onTap;
  const _CollectionCard({required this.collection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(collection.category);
    final hasCover = collection.coverImageUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: hasCover
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    category.color.withValues(alpha: 0.3),
                    category.color.withValues(alpha: 0.8),
                    category.color,
                  ],
                ),
          boxShadow: [
            BoxShadow(
              color: category.color.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasCover)
              CachedNetworkImage(
                imageUrl: collection.coverImageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                placeholder: (context, url) => const SizedBox.shrink(),
              ),
            Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x2014101E), Color(0xB014101E)],
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${collection.wonderCount} wonders',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (collection.isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6F8C6A).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'FREE',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.lock_outline, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                ],
              ),
              const Spacer(),
              Text(
                collection.title,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 24,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                collection.subtitle,
                style: GoogleFonts.sourceSans3(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}
