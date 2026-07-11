import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/services/collection_service.dart';
import 'package:wanderwell/services/wonder_service.dart';
import 'package:wanderwell/services/wonder_user_service.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/widgets/related_wonders.dart';

class WonderReaderScreen extends StatefulWidget {
  final String wonderId;
  final String source;
  const WonderReaderScreen({super.key, required this.wonderId, this.source = 'wonders'});

  @override
  State<WonderReaderScreen> createState() => _WonderReaderScreenState();
}

class _WonderReaderScreenState extends State<WonderReaderScreen> {
  Wonder? _wonder;
  bool _loading = true;
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadWonder();
  }

  Future<void> _loadWonder() async {
    Wonder? wonder;
    if (widget.source == 'daily') {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('daily_wonders')
            .doc(widget.wonderId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id;
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          data.remove('updatedAt');
          wonder = Wonder.fromJson(data);
        }
      } catch (e) {
        debugPrint('[WonderReader] Daily wonder load error: $e');
      }
    } else {
      wonder = await CollectionService().getWonderById(widget.wonderId);
    }

    if (wonder == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final enriched = await WonderService().enrichWithImage(wonder);
    final userState = await WonderUserService().getState();
    final likeCount = await WonderUserService().getLikeCount(enriched.id);
    if (mounted) {
      setState(() {
        _wonder = enriched;
        _isLiked = userState.isWonderSaved(enriched.id);
        _likeCount = likeCount;
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_wonder == null) return;
    final wasLiked = _isLiked;
    await WonderUserService().toggleSave(_wonder!.id);
    if (!wasLiked) {
      await WonderUserService().markEngaged(_wonder!);
    }
    final userState = await WonderUserService().getState();
    final likeCount = await WonderUserService().getLikeCount(_wonder!.id);
    if (mounted) {
      setState(() {
        _isLiked = userState.isWonderSaved(_wonder!.id);
        _likeCount = likeCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AweColors.background,
        body: Center(child: CircularProgressIndicator(color: AweColors.accentTeal)),
      );
    }
    if (_wonder == null) {
      return Scaffold(
        backgroundColor: AweColors.background,
        appBar: AppBar(),
        body: Center(
          child: Text('Wonder not found', style: GoogleFonts.sourceSans3(color: AweColors.textSecondary)),
        ),
      );
    }

    final wonder = _wonder!;
    final category = WonderCategory.fromString(wonder.category);
    final emotion = WonderEmotion.fromString(wonder.emotion);
    final storyParagraphs = wonder.story.split('\n').where((p) => p.trim().isNotEmpty).toList();

    // Published date from the wonder ID (date key) or createdAt
    final publishedDate = DateTime.tryParse(wonder.id) ?? wonder.createdAt;
    final dateStr = DateFormat('d MMMM yyyy').format(publishedDate).toUpperCase();

    return Scaffold(
      backgroundColor: AweColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero — full-bleed, no overlay
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroImage(wonder),
                  // Back button — top left
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
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
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: category.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            category.label.toUpperCase(),
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11, letterSpacing: 1.0,
                              fontWeight: FontWeight.w500, color: AweColors.textPrimary,
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
                        fontSize: 9.5, letterSpacing: 1.2,
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
                    '${emotion.label.toUpperCase()} · $dateStr',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10.5, letterSpacing: 1.4, color: emotion.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    wonder.title,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 36, height: 1.1,
                      color: AweColors.accentSlate, letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    wonder.subtitle,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 16, fontStyle: FontStyle.italic,
                      height: 1.5, color: AweColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(width: 40, height: 2, color: AweColors.accentGold),
                ],
              ),
            ),
          ),
          // Place + coordinates
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${wonder.place.name.toUpperCase()} · ${wonder.place.region.toUpperCase()}, ${wonder.place.country.toUpperCase()}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10, letterSpacing: 0.3,
                      color: AweColors.textSecondary, height: 1.5,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${wonder.place.lat.toStringAsFixed(2)}°${wonder.place.lat >= 0 ? 'N' : 'S'}, ${wonder.place.lon.toStringAsFixed(2)}°${wonder.place.lon >= 0 ? 'E' : 'W'}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10, letterSpacing: 0.3,
                      color: AweColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 17),
                    child: Text(
                      storyParagraphs[index],
                      style: GoogleFonts.sourceSans3(fontSize: 16.5, height: 1.74, color: AweColors.textBody),
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
                        style: GoogleFonts.ibmPlexMono(fontSize: 11, letterSpacing: 1.5, color: AweColors.sparkAccent),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        wonder.curiositySpark,
                        style: GoogleFonts.sourceSans3(fontSize: 15.5, height: 1.62, color: const Color(0xFF2C3A42)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Actions
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  // Like
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleLike,
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: _isLiked ? AweColors.sparkBackground : AweColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _isLiked ? AweColors.accentTeal.withValues(alpha: 0.3) : AweColors.divider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 22,
                              color: _isLiked ? const Color(0xFFB5483D) : AweColors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLiked ? 'Liked' : 'Like',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _isLiked ? const Color(0xFFB5483D) : AweColors.textPrimary,
                                  ),
                                ),
                                if (_likeCount > 0)
                                  Text(
                                    '$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}',
                                    style: GoogleFonts.ibmPlexMono(fontSize: 10, color: AweColors.textSecondary),
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
                            Text('Share', style: GoogleFonts.sourceSans3(fontSize: 12.5, color: AweColors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                              style: GoogleFonts.sourceSans3(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
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
          const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
        ],
      ),
    );
  }

  Widget _buildHeroImage(Wonder wonder) {
    if (wonder.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: wonder.imageUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildGradient(wonder),
      );
    }
    return _buildGradient(wonder);
  }

  Widget _buildGradient(Wonder wonder) {
    final category = WonderCategory.fromString(wonder.category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [category.color.withValues(alpha: 0.4), AweColors.accentSlate],
        ),
      ),
    );
  }
}
