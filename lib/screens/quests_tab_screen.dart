import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderwell/bloc/quests_tab_cubit.dart';
import 'package:wanderwell/models/quest_card.dart';
import 'package:wanderwell/theme.dart';

class QuestsTabScreen extends StatelessWidget {
  const QuestsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QuestsTabCubit()..loadForCurrentLocation(),
      child: const _QuestsTabView(),
    );
  }
}

class _QuestsTabView extends StatefulWidget {
  const _QuestsTabView();

  @override
  State<_QuestsTabView> createState() => _QuestsTabViewState();
}

class _QuestsTabViewState extends State<_QuestsTabView> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  bool _cityDropdownOpen = false;

  static const _chipLabels = ['All', '📍 Places', '🍜 Food', '✨ Experiences', '🔥 Trending'];

  String _chipKey(String label) {
    if (label == 'All') return 'All';
    return label.split(' ').skip(1).join(' ');
  }

  bool _matchesFilter(QuestCard q) {
    if (_filter == 'All') return true;
    if (_filter == 'Trending') return q.source?.toLowerCase().contains('trending') ?? false;
    if (_filter == 'Places') return q.type == 'place';
    if (_filter == 'Food') return q.type == 'food';
    if (_filter == 'Experiences') return q.type == 'experience';
    return true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AweColors.background,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<QuestsTabCubit, QuestsTabState>(
          builder: (context, state) {
            final city = state is QuestsTabLoaded ? state.city
                : state is QuestsTabLoading ? state.city
                : state is QuestsTabError ? state.city : '';
            final allQuests = state is QuestsTabLoaded ? state.quests : <QuestCard>[];
            final filtered = allQuests.where(_matchesFilter).toList();
            final trendingCount = allQuests.where((q) => q.source?.toLowerCase().contains('trending') ?? false).length;

            return Stack(
              children: [
                Column(
                  children: [
                    // Header
                    _buildHeader(context, city, allQuests.length, trendingCount),
                    // Filter chips
                    _buildFilterChips(),
                    // Content
                    Expanded(child: _buildContent(context, state, filtered, allQuests, city)),
                  ],
                ),
                // City dropdown overlay
                if (_cityDropdownOpen) _buildCityDropdown(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String city, int totalCount, int trendingCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      decoration: const BoxDecoration(
        color: AweColors.background,
        border: Border(bottom: BorderSide(color: AweColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTS · DISCOVER NEARBY',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10,
              letterSpacing: 1.8,
              color: const Color(0xFFA08A64),
            ),
          ),
          const SizedBox(height: 7),
          GestureDetector(
            onTap: () => setState(() => _cityDropdownOpen = !_cityDropdownOpen),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AweColors.sparkBackground,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.location_on, size: 16, color: AweColors.accentTeal),
                ),
                const SizedBox(width: 10),
                Text(
                  city.isNotEmpty ? city : '...',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 27,
                    color: AweColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE7D6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _cityDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: const Color(0xFF7A7060),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalCount quests trending right now',
            style: GoogleFonts.sourceSans3(
              fontSize: 13,
              color: const Color(0xFF9A8C70),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _chipLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final label = _chipLabels[index];
          final key = _chipKey(label);
          final isActive = _filter == key;
          return GestureDetector(
            onTap: () => setState(() => _filter = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AweColors.textPrimary : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isActive ? AweColors.textPrimary : const Color(0xFFE3DCCD),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.sourceSans3(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AweColors.background : const Color(0xFF6E6557),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, QuestsTabState state, List<QuestCard> filtered, List<QuestCard> all, String city) {
    if (state is QuestsTabLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AweColors.accentTeal)),
            const SizedBox(height: 16),
            Text(
              'Finding quests in ${state.city}...',
              style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AweColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state is QuestsTabError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Couldn\'t load quests', style: GoogleFonts.sourceSans3(color: AweColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<QuestsTabCubit>().refresh(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    // Find featured (first trending quest)
    QuestCard? featured;
    if (_filter == 'All' || _filter == 'Trending' || _filter == 'Experiences') {
      featured = all.cast<QuestCard?>().firstWhere(
        (q) => q!.source?.toLowerCase().contains('trending') ?? false,
        orElse: () => null,
      );
    }

    final listQuests = filtered.where((q) => q != featured).toList();

    if (filtered.isEmpty && featured == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nothing here yet', style: GoogleFonts.dmSerifDisplay(fontSize: 21, color: AweColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                'No ${_filter.toLowerCase()} quests in $city right now. Try another filter.',
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceSans3(fontSize: 13.5, height: 1.5, color: AweColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AweColors.accentTeal,
      onRefresh: () => context.read<QuestsTabCubit>().refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        itemCount: (featured != null ? 1 : 0) + listQuests.length + 1,
        itemBuilder: (context, index) {
          if (featured != null && index == 0) {
            return _FeaturedHeroCard(quest: featured, city: city);
          }
          final questIndex = index - (featured != null ? 1 : 0);
          if (questIndex < listQuests.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuestListCard(quest: listQuests[questIndex], city: city),
            );
          }
          return _buildQuickLinks(context);
        },
      ),
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/itinerary'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AweColors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.route, size: 22, color: AweColors.accentSlate),
                    const SizedBox(height: 8),
                    Text('Build Itinerary', style: GoogleFonts.sourceSans3(fontSize: 13, fontWeight: FontWeight.w600, color: AweColors.textPrimary)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/saved_itineraries'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AweColors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.bookmark_outline, size: 22, color: AweColors.accentSlate),
                    const SizedBox(height: 8),
                    Text('Saved Trips', style: GoogleFonts.sourceSans3(fontSize: 13, fontWeight: FontWeight.w600, color: AweColors.textPrimary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _cityDropdownOpen = false),
          child: Container(color: Colors.black.withValues(alpha: 0.12)),
        ),
        Positioned(
          left: 20,
          top: 150,
          child: Container(
            width: 230,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AweColors.border),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 18))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Text(
                    'CHANGE CITY',
                    style: GoogleFonts.ibmPlexMono(fontSize: 9.5, letterSpacing: 1.4, color: const Color(0xFFA08A64)),
                  ),
                ),
                _CityOption(
                  name: 'Search a city...',
                  isSearch: true,
                  onTap: () {
                    setState(() => _cityDropdownOpen = false);
                    _showSearchDialog(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AweColors.background,
          title: Text('Search City', style: GoogleFonts.dmSerifDisplay(fontSize: 20)),
          content: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter a city name...',
              hintStyle: GoogleFonts.sourceSans3(color: AweColors.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AweColors.accentTeal),
              ),
            ),
            style: GoogleFonts.sourceSans3(fontSize: 16, color: AweColors.textPrimary),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                context.read<QuestsTabCubit>().loadQuests(value.trim());
                _searchController.clear();
                Navigator.of(dialogContext).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: AweColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final value = _searchController.text.trim();
                if (value.isNotEmpty) {
                  context.read<QuestsTabCubit>().loadQuests(value);
                  _searchController.clear();
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text('Search', style: TextStyle(color: AweColors.accentTeal)),
            ),
          ],
        );
      },
    );
  }
}

// ── Featured Hero Card ──────────────────────────────────────────────────────

class _FeaturedHeroCard extends StatelessWidget {
  final QuestCard quest;
  final String city;
  const _FeaturedHeroCard({required this.quest, required this.city});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(quest.actionUrl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: _gradientForType(quest.type),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 34, offset: const Offset(0, 16))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x4014101E), Color(0x2014101E), Color(0xE014101E)],
              stops: [0.0, 0.35, 1.0],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '◆ ${_typeLabel(quest.type)}',
                      style: GoogleFonts.sourceSans3(fontSize: 11, fontWeight: FontWeight.w700, color: _colorForType(quest.type)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5483D).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '🔥 #1 TRENDING',
                      style: GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
              // Title
              Text(
                quest.title,
                style: GoogleFonts.dmSerifDisplay(fontSize: 24, height: 1.1, color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                quest.description,
                style: GoogleFonts.sourceSans3(fontSize: 13.5, height: 1.45, color: Colors.white.withValues(alpha: 0.84)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Source
              if (quest.source != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sourceIcon(quest.source, Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        quest.source!,
                        style: GoogleFonts.sourceSans3(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quest List Card ─────────────────────────────────────────────────────────

class _QuestListCard extends StatelessWidget {
  final QuestCard quest;
  final String city;
  const _QuestListCard({required this.quest, required this.city});

  @override
  Widget build(BuildContext context) {
    final isTrending = quest.source?.toLowerCase().contains('trending') ?? false;

    return GestureDetector(
      onTap: () => _openUrl(quest.actionUrl),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AweColors.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _gradientForType(quest.type),
              ),
              child: isTrending
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(7),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB5483D).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '🔥',
                          style: GoogleFonts.ibmPlexMono(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '◆ ${_typeLabel(quest.type)}',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          color: _colorForType(quest.type),
                        ),
                      ),
                      const Spacer(),
                      if (quest.actionUrl != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'OPEN',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 9,
                                letterSpacing: 0.7,
                                color: const Color(0xFF9A8C70),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.north_east, size: 10, color: Color(0xFF9A8C70)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    quest.title,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 19,
                      height: 1.1,
                      color: AweColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    quest.description,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 13,
                      height: 1.42,
                      color: const Color(0xFF7A7060),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 9),
                  if (quest.source != null)
                    Row(
                      children: [
                        _sourceIcon(quest.source, null),
                        const SizedBox(width: 6),
                        Text(
                          quest.source!,
                          style: GoogleFonts.sourceSans3(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6E6557),
                          ),
                        ),
                      ],
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

// ── City Option ─────────────────────────────────────────────────────────────

class _CityOption extends StatelessWidget {
  final String name;
  final bool isSearch;
  final VoidCallback onTap;
  const _CityOption({required this.name, this.isSearch = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF3ECE0))),
        ),
        child: Row(
          children: [
            Icon(
              isSearch ? Icons.search : Icons.location_on,
              size: 16,
              color: AweColors.accentTeal,
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: GoogleFonts.sourceSans3(
                fontSize: 15,
                color: isSearch ? AweColors.accentTeal : AweColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

LinearGradient _gradientForType(String type) {
  switch (type) {
    case 'place':
      return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFCFE0EA), Color(0xFF356D8E)]);
    case 'food':
      return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFECD9A2), Color(0xFF9A6F1F)]);
    case 'experience':
      return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFDDD2E6), Color(0xFF5F4F7A)]);
    case 'trending':
      return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE6C4B8), Color(0xFFB5483D)]);
    default:
      return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFCFE0EA), Color(0xFF356D8E)]);
  }
}

Color _colorForType(String type) {
  switch (type) {
    case 'place': return const Color(0xFF2F6F8F);
    case 'food': return const Color(0xFFC0902F);
    case 'experience': return const Color(0xFF7A6A93);
    case 'trending': return const Color(0xFFB5483D);
    default: return const Color(0xFF2F6F8F);
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'place': return 'PLACE';
    case 'food': return 'FOOD';
    case 'experience': return 'EXPERIENCE';
    case 'trending': return 'TRENDING';
    default: return 'QUEST';
  }
}

Widget _sourceIcon(String? source, Color? overrideColor) {
  if (source == null) return const SizedBox.shrink();
  final s = source.toLowerCase();
  if (s.contains('instagram')) {
    return Icon(Icons.camera_alt_outlined, size: 13, color: overrideColor ?? const Color(0xFFB5483D));
  }
  if (s.contains('reddit')) {
    return Icon(Icons.forum_outlined, size: 13, color: overrideColor ?? const Color(0xFFC0694A));
  }
  if (s.contains('local')) {
    return Icon(Icons.location_on, size: 13, color: overrideColor ?? const Color(0xFF6F8C6A));
  }
  return Icon(Icons.language, size: 13, color: overrideColor ?? const Color(0xFF7A6A93));
}

Future<void> _openUrl(String? url) async {
  if (url == null) return;
  final uri = Uri.tryParse(url);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
