import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/bloc/collections_cubit.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/models/wonder_collection.dart';
import 'package:wanderwell/services/premium_service.dart';
import 'package:wanderwell/theme.dart';

class CollectionDetailScreen extends StatelessWidget {
  final String collectionId;
  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CollectionsCubit()..loadCollection(collectionId),
      child: Scaffold(
        backgroundColor: AweColors.background,
        body: BlocBuilder<CollectionsCubit, CollectionsState>(
          builder: (context, state) {
            if (state is CollectionDetailLoaded) {
              return _DetailContent(
                collection: state.collection,
                wonders: state.wonders,
              );
            }
            if (state is CollectionsError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load collection:\n${state.message}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AweColors.textSecondary),
                  ),
                ),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: AweColors.accentTeal),
            );
          },
        ),
      ),
    );
  }
}

class _DetailContent extends StatefulWidget {
  final WonderCollection collection;
  final List<Wonder> wonders;
  const _DetailContent({required this.collection, required this.wonders});

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  StreamSubscription<bool>? _premiumSub;

  @override
  void initState() {
    super.initState();
    _premiumSub = PremiumService().onPremiumActivated.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final wonders = widget.wonders;
    final category = WonderCategory.fromString(collection.category);

    return CustomScrollView(
      slivers: [
        // Hero
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: collection.coverImageUrl.isEmpty
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        category.color.withValues(alpha: 0.3),
                        category.color.withValues(alpha: 0.8),
                        category.color,
                      ],
                    )
                  : null,
              image: collection.coverImageUrl.isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(collection.coverImageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x5014101E), Color(0xD014101E)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                                  '${wonders.length} wonders',
                                  style: GoogleFonts.ibmPlexMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (collection.isFree) ...[
                                const SizedBox(width: 8),
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
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            collection.title,
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 30,
                              height: 1.08,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            collection.description,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 14,
                              height: 1.45,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Wonder list
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final wonder = wonders[index];
                return _WonderRow(
                  wonder: wonder,
                  index: index,
                  isLocked: !collection.isFree && !PremiumService().isPremium,
                );
              },
              childCount: wonders.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _WonderRow extends StatelessWidget {
  final Wonder wonder;
  final int index;
  final bool isLocked;
  const _WonderRow({required this.wonder, required this.index, required this.isLocked});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(wonder.category);

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          Navigator.of(context).pushNamed('/paywall');
          return;
        }
        Navigator.of(context).pushNamed('/wonder/read/${wonder.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AweColors.border),
        ),
        child: Row(
          children: [
            // Number
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
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 16,
                    color: category.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '◆ ${category.label.toUpperCase()}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: category.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wonder.title,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 17,
                      height: 1.15,
                      color: isLocked
                          ? AweColors.textPrimary.withValues(alpha: 0.5)
                          : AweColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    wonder.subtitle,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12.5,
                      color: AweColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLocked)
              Icon(Icons.lock_outline, size: 18, color: AweColors.navInactive)
            else
              Icon(Icons.chevron_right, size: 20, color: AweColors.navInactive),
          ],
        ),
      ),
    );
  }
}
