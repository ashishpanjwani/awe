import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/theme.dart';

class PastWondersScreen extends StatefulWidget {
  const PastWondersScreen({super.key});

  @override
  State<PastWondersScreen> createState() => _PastWondersScreenState();
}

class _PastWondersScreenState extends State<PastWondersScreen> {
  final _db = FirebaseFirestore.instance;
  List<Wonder> _wonders = [];
  bool _isLoading = true;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _localDayKey() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  Future<void> _loadData() async {
    try {
      final todayKey = _localDayKey();
      final snap = await _db
          .collection('daily_wonders')
          .where('status', isEqualTo: 'ready')
          .orderBy(FieldPath.documentId, descending: true)
          .startAt([todayKey])
          .limit(100)
          .get();

      final wonders = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        data.remove('updatedAt');
        return Wonder.fromJson(data);
      }).toList();

      if (mounted) {
        setState(() {
          _wonders = wonders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PastWonders] Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Wonder> get _filteredWonders {
    if (_filter == 'All') return _wonders;
    return _wonders.where((w) => w.category == _filter.toLowerCase()).toList();
  }

  String _sinceLabel() {
    if (_wonders.isEmpty) return '';
    final oldest = _wonders.last;
    final date = DateTime.tryParse(oldest.id);
    if (date == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_wonders.length} days · since ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AweColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AweColors.accentTeal))
          : CustomScrollView(
              slivers: [
                // App bar — same pattern as Liked Wonders
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
                  expandedHeight: 160,
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
                            'WONDER TRAIL',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 10.5,
                              letterSpacing: 1.8,
                              color: AweColors.accentGold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Every day, a story',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 26,
                              color: AweColors.textPrimary,
                            ),
                          ),
                          if (_wonders.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _sinceLabel(),
                              style: GoogleFonts.sourceSans3(fontSize: 13, color: AweColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Filter chips
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _FilterChip(label: 'All', isSelected: _filter == 'All', onTap: () => setState(() => _filter = 'All')),
                        ...WonderCategory.values.map((cat) => _FilterChip(
                              label: cat.label,
                              isSelected: _filter == cat.label,
                              dotColor: cat.color,
                              onTap: () => setState(() => _filter = cat.label),
                            )),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Content
                if (_filteredWonders.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _TimelineItem(
                            wonder: _filteredWonders[i],
                            isFirst: i == 0,
                            isLast: i == _filteredWonders.length - 1,
                          ),
                        );
                      },
                      childCount: _filteredWonders.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
    );
  }


  Widget _buildEmptyState() {
    final isFiltered = _filter != 'All' && _wonders.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFFDF8),
                border: Border.all(color: const Color(0xFFDDD2BF), width: 1.5),
              ),
              child: const Icon(Icons.explore_outlined, size: 44, color: AweColors.accentTerracotta),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered
                  ? 'No ${_filter.toLowerCase()} wonders—yet'
                  : 'Your trail starts\ntomorrow morning',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSerifDisplay(fontSize: 25, height: 1.1, color: AweColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered
                  ? 'Keep opening Awe each day — one will find you.'
                  : 'Open Awe each day to collect a wonder. They\'ll gather here — a trail of everywhere your curiosity has been.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(fontSize: 14.5, height: 1.6, color: AweColors.textSecondary),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD8CDB8), width: 1.5, strokeAlign: BorderSide.strokeAlignCenter),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Text('DAY', style: GoogleFonts.ibmPlexMono(fontSize: 9, letterSpacing: 1.0, color: AweColors.accentTerracotta)),
                        Text('001', style: GoogleFonts.dmSerifDisplay(fontSize: 26, height: 1, color: AweColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tomorrow's wonder", style: GoogleFonts.dmSerifDisplay(fontSize: 16, color: const Color(0xFFBDB19C))),
                          const SizedBox(height: 3),
                          Text('ARRIVES AT SUNRISE', style: GoogleFonts.ibmPlexMono(fontSize: 9.5, letterSpacing: 0.6, color: const Color(0xFFC2B69E))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Wonder wonder;
  final bool isFirst;
  final bool isLast;
  const _TimelineItem({required this.wonder, this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(wonder.category);
    final date = DateTime.tryParse(wonder.id);
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final mon = date != null ? months[date.month - 1] : '';
    final day = date != null ? '${date.day}' : '';
    final year = date != null ? '${date.year}' : '';
    final hasImage = wonder.imageUrl.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column: line + dot + date
          SizedBox(
            width: 70,
            child: Column(
              children: [
                // Line above dot
                Container(
                  width: 2,
                  height: 16,
                  color: isFirst ? Colors.transparent : const Color(0xFFE3D9C7),
                ),
                // Dot
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: category.color,
                    border: Border.all(color: AweColors.background, width: 3),
                    boxShadow: [BoxShadow(color: category.color.withValues(alpha: 0.33), blurRadius: 0, spreadRadius: 2)],
                  ),
                ),
                const SizedBox(height: 8),
                // Date
                Text(mon, style: GoogleFonts.ibmPlexMono(fontSize: 9.5, letterSpacing: 1.2, color: category.color)),
                Text(day, style: GoogleFonts.dmSerifDisplay(fontSize: 27, height: 1, color: AweColors.textPrimary)),
                const SizedBox(height: 1),
                Text(year, style: GoogleFonts.ibmPlexMono(fontSize: 8.5, letterSpacing: 0.6, color: const Color(0xFFB0A48C))),
                const SizedBox(height: 8),
                // Line below date (extends to fill remaining space)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : const Color(0xFFE3D9C7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/wonder/daily/${wonder.id}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFECE3D4)),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3C2D14).withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: -13,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasImage)
                              CachedNetworkImage(
                                imageUrl: wonder.imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 500,
                                placeholder: (context, url) => _categoryGradient(category),
                              )
                            else
                              _categoryGradient(category),
                            // Category badge
                            Positioned(
                              left: 10,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('◆ ', style: TextStyle(fontSize: 8, color: category.color)),
                                    Text(
                                      category.label.toUpperCase(),
                                      style: GoogleFonts.ibmPlexMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                        color: category.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wonder.title,
                              style: GoogleFonts.dmSerifDisplay(fontSize: 17, height: 1.12, color: AweColors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${wonder.place.name} · ${wonder.place.country}',
                              style: GoogleFonts.ibmPlexMono(fontSize: 9.5, letterSpacing: 0.6, color: AweColors.textSecondary),
                              maxLines: 1,
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
        ],
      ),
    );
  }

  Widget _categoryGradient(WonderCategory category) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [category.color.withValues(alpha: 0.4), category.color],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? dotColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AweColors.textPrimary : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isSelected ? AweColors.textPrimary : const Color(0xFFE3DCCD)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.sourceSans3(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AweColors.background : const Color(0xFF6E6557),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
