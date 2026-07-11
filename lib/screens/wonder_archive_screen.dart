import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/services/wonder_user_service.dart';
import 'package:wanderwell/theme.dart';

class WonderArchiveScreen extends StatefulWidget {
  const WonderArchiveScreen({super.key});

  @override
  State<WonderArchiveScreen> createState() => _WonderArchiveScreenState();
}

class _WonderArchiveScreenState extends State<WonderArchiveScreen> {
  final _db = FirebaseFirestore.instance;
  List<Wonder> _wonders = [];
  bool _isLoading = true;
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadLikedWonders();
  }

  Future<void> _loadLikedWonders() async {
    try {
      final userState = await WonderUserService().getState();
      final likedIds = userState.savedWonderIds;

      if (likedIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final wonders = <Wonder>[];
      // Fetch in batches of 10 (Firestore whereIn limit)
      for (var i = 0; i < likedIds.length; i += 10) {
        final batch = likedIds.sublist(i, i + 10 > likedIds.length ? likedIds.length : i + 10);
        final snap = await _db
            .collection('daily_wonders')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          data.remove('updatedAt');
          if (data['status'] == 'ready') {
            wonders.add(Wonder.fromJson(data));
          }
        }
      }

      // Sort by date descending
      wonders.sort((a, b) => b.id.compareTo(a.id));

      if (mounted) {
        setState(() {
          _wonders = wonders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[LikedWonders] Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Wonder> get _filteredWonders {
    if (_filterCategory == null) return _wonders;
    return _wonders.where((w) => w.category == _filterCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AweColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AweColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AweColors.textPrimary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            centerTitle: true,
            expandedHeight: 140,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: AweColors.background,
                padding: const EdgeInsets.only(left: 24, bottom: 16),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIKED',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10.5,
                        letterSpacing: 1.8,
                        color: const Color(0xFFA08A64),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wonders you loved',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 26,
                        color: AweColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Category filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _filterCategory == null,
                    onTap: () => setState(() => _filterCategory = null),
                  ),
                  ...WonderCategory.values.map((cat) => _FilterChip(
                        label: cat.label,
                        isSelected: _filterCategory == cat.name,
                        color: cat.color,
                        onTap: () => setState(() => _filterCategory = cat.name),
                      )),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AweColors.accentTeal)),
            )
          else if (_filteredWonders.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 56, color: AweColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 14),
                    Text(
                      _wonders.isEmpty ? 'No liked wonders yet' : 'No matches in this category',
                      style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _wonders.isEmpty ? 'Like a daily wonder to save it here.' : 'Try another filter.',
                      style: GoogleFonts.sourceSans3(fontSize: 15, color: AweColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _LikedWonderCard(
                        wonder: _filteredWonders[index],
                        onTap: () => Navigator.of(context).pushNamed(
                          '/wonder/daily/${_filteredWonders[index].id}',
                        ),
                      ),
                    );
                  },
                  childCount: _filteredWonders.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AweColors.accentSlate;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? chipColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? chipColor : const Color(0xFFECE3D4),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.sourceSans3(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AweColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LikedWonderCard extends StatelessWidget {
  final Wonder wonder;
  final VoidCallback onTap;
  const _LikedWonderCard({required this.wonder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(wonder.category);
    final hasImage = wonder.imageUrl.isNotEmpty;
    final date = DateTime.tryParse(wonder.id);
    final dateStr = date != null ? DateFormat('d MMM yyyy').format(date) : wonder.id;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECE3D4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3C2D14).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Thumbnail
            Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: wonder.imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 220,
                          placeholder: (context, url) => Container(color: category.color.withValues(alpha: 0.2)),
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
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '◆ ${category.label.toUpperCase()} · $dateStr'.toUpperCase(),
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        color: category.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      wonder.title,
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 16,
                        height: 1.15,
                        color: AweColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '${wonder.place.name}, ${wonder.place.country}',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 12,
                        color: AweColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
