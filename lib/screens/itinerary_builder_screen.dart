import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/theme.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:wanderwell/services/photon_service.dart';
import 'package:wanderwell/models/place_suggestion.dart';
import 'package:wanderwell/services/itinerary_ai_service.dart';
import 'package:wanderwell/services/premium_service.dart';


class ItineraryBuilderScreen extends StatefulWidget {
  final String? initialDestination;
  const ItineraryBuilderScreen({super.key, this.initialDestination});

  @override
  State<ItineraryBuilderScreen> createState() => _ItineraryBuilderScreenState();
}

class _ItineraryBuilderScreenState extends State<ItineraryBuilderScreen> {
  final TextEditingController _destinationCtrl = TextEditingController();
  final PhotonService _photon = PhotonService();
  PlaceSuggestion? _selectedPlace;

  TextEditingController? _typeAheadController;
  FocusNode? _destinationFocusNode;

  DateTime? _startDate;
  DateTime? _endDate;

  final List<_StyleOption> _styles = const [
    _StyleOption('Adventure', Icons.hiking, AweColors.accentTeal),
    _StyleOption('Foodie', Icons.restaurant_menu, AweColors.accentTerracotta),
    _StyleOption('Culture', Icons.museum_outlined, AweColors.categorySound),
    _StyleOption('Romantic', Icons.favorite_border, Color(0xFF8A6B55)),
    _StyleOption('Nature', Icons.park_outlined, AweColors.accentTeal),
    _StyleOption('Nightlife', Icons.local_bar, AweColors.categoryStory),
  ];
  final Set<String> _selectedStyles = {'Adventure', 'Culture'};

  final List<String> _affordability = const ['Budget', 'Moderate', 'Luxury'];
  int _affordabilityIndex = 1;

  final List<String> _flexOptions = const ['Structured', 'Balanced', 'Relaxed'];
  int _flexIndex = 1;

  final List<String> _diversityOptions = const [
    'Stay mostly in one place',
    'Visit 2–3 places',
    'Visit 3–5 places',
  ];
  int _diversityIndex = 1;

  final List<String> _partyOptions = const ['Couple', 'Family', 'Friends', 'Solo'];
  int _partyIndex = 0;

  final List<String> _dietaryOptions = const [
    'No preference', 'Vegetarian', 'Vegan', 'Pescatarian',
    'Halal', 'Kosher', 'Gluten-free', 'Jain',
  ];
  int _dietaryIndex = 0;

  String _formatLongDate(DateTime d) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const monthsAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final w = weekdays[(d.weekday - 1).clamp(0, 6)];
    final m = monthsAbbr[(d.month - 1).clamp(0, 11)];
    return '$w, ${d.day} $m ${d.year}';
  }

  @override
  void initState() {
    super.initState();
    _photon.prewarm();
    if (widget.initialDestination != null && widget.initialDestination!.isNotEmpty) {
      _destinationCtrl.text = widget.initialDestination!;
    }
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AweColors.background,
      body: _ItineraryScrollBody(
        destinationCard: _buildDestinationCard(),
        datesSection: _buildDatesSection(),
        partySection: _buildPartySection(),
        travelStyleSection: _buildTravelStyleSection(),
        budgetSection: _buildAffordabilitySection(),
        flexibilitySection: _buildFlexibilitySection(),
        dietarySection: _buildDietarySection(),
        diversitySection: _buildDiversitySection(),
        includeSection: _buildIncludeSection(),
      ),
      bottomNavigationBar: _buildBottomCTA(context),
    );
  }

  Widget _buildDestinationCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AweColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3C2D14).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dropdownWidth = constraints.maxWidth;
          return TypeAheadField<PlaceSuggestion>(
            hideOnEmpty: true,
            hideOnLoading: true,
            debounceDuration: const Duration(milliseconds: 250),
            constraints: BoxConstraints(
              minWidth: dropdownWidth,
              maxWidth: dropdownWidth,
              maxHeight: 280,
            ),
            suggestionsCallback: (pattern) async {
              try {
                return await _photon.autocomplete(pattern, limit: 8, lang: 'en');
              } catch (e) {
                debugPrint('Typeahead search error: $e');
                return [];
              }
            },
            builder: (context, controller, focusNode) {
              _typeAheadController = controller;
              _destinationFocusNode = focusNode;
              if (controller.text != _destinationCtrl.text) {
                controller.text = _destinationCtrl.text;
              }
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AweColors.accentTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_outlined, color: AweColors.accentTeal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (v) => _destinationCtrl.text = v,
                      style: GoogleFonts.sourceSans3(
                        color: AweColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: AweColors.accentTeal,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Where are you going?',
                        hintStyle: GoogleFonts.sourceSans3(
                          color: AweColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              );
            },
            itemBuilder: (context, place) {
              final meta = [place.city, place.state, place.country]
                  .where((e) => e != null && e.isNotEmpty)
                  .map((e) => e!)
                  .toList()
                  .join(', ');
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AweColors.divider, width: 1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AweColors.accentTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.place_outlined, color: AweColors.accentTeal, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sourceSans3(
                              color: AweColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          if (meta.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sourceSans3(
                                  color: AweColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            emptyBuilder: (context) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              color: Colors.white,
              child: Text(
                'No matches found',
                style: GoogleFonts.sourceSans3(color: AweColors.textSecondary),
              ),
            ),
            onSelected: (place) {
              final label = place.label;
              setState(() {
                _selectedPlace = place;
                _destinationCtrl
                  ..text = label
                  ..selection = TextSelection.collapsed(offset: label.length);
              });
              if (_typeAheadController != null) {
                _typeAheadController!
                  ..text = label
                  ..selection = TextSelection.collapsed(offset: label.length);
              }
              if (_destinationFocusNode?.hasFocus == true) {
                _destinationFocusNode!.unfocus();
              } else {
                FocusScope.of(context).unfocus();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildDatesSection() {
    return _SectionBlock(
      title: 'Dates',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectionRow(
            icon: Icons.calendar_today_outlined,
            label: _startDate == null ? 'Select Start Date' : _formatLongDate(_startDate!),
            onTap: () async {
              final now = DateTime.now();
              final first = DateTime(now.year, now.month, now.day);
              final initial = _startDate ?? first;
              final picked = await showDatePicker(
                context: context,
                firstDate: first,
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                initialDate: initial.isBefore(first) ? first : initial,
                builder: (ctx, child) {
                  return Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(ctx).colorScheme.copyWith(
                        primary: AweColors.accentSlate,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: AweColors.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _startDate = DateTime(picked.year, picked.month, picked.day);
                  if (_endDate != null && _endDate!.isBefore(_startDate!)) _endDate = null;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          _SelectionRow(
            icon: Icons.event_outlined,
            label: _endDate == null ? 'Select End Date' : _formatLongDate(_endDate!),
            onTap: () async {
              final now = DateTime.now();
              final baseFirst = DateTime(now.year, now.month, now.day);
              final first = _startDate ?? baseFirst;
              final initial = _endDate ?? first;
              final picked = await showDatePicker(
                context: context,
                firstDate: first,
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                initialDate: initial.isBefore(first) ? first : initial,
                builder: (ctx, child) {
                  return Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(ctx).colorScheme.copyWith(
                        primary: AweColors.accentSlate,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: AweColors.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _endDate = DateTime(picked.year, picked.month, picked.day));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAffordabilitySection() {
    return _SectionBlock(
      title: 'Affordability',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_affordability.length, (i) {
          return _PillChip(
            label: _affordability[i],
            selected: _affordabilityIndex == i,
            accent: AweColors.accentTeal,
            onTap: () => setState(() => _affordabilityIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildPartySection() {
    return _SectionBlock(
      title: 'Travel Party',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_partyOptions.length, (i) {
          final accent = switch (_partyOptions[i]) {
            'Couple' => AweColors.accentGold,
            'Family' => AweColors.categorySound,
            'Friends' => AweColors.accentTeal,
            _ => AweColors.accentTerracotta,
          };
          return _PillChip(
            label: _partyOptions[i],
            selected: _partyIndex == i,
            accent: accent,
            onTap: () => setState(() => _partyIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildTravelStyleSection() {
    return _SectionBlock(
      title: 'Travel Style',
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _styles.length,
        itemBuilder: (context, index) {
          final opt = _styles[index];
          final selected = _selectedStyles.contains(opt.label);
          return _SquareTile(
            option: opt,
            selected: selected,
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedStyles.remove(opt.label);
                } else {
                  _selectedStyles.add(opt.label);
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildFlexibilitySection() {
    return _SectionBlock(
      title: 'Daily pace',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_flexOptions.length, (i) {
          return _PillChip(
            label: _flexOptions[i],
            selected: _flexIndex == i,
            accent: AweColors.categorySound,
            onTap: () => setState(() => _flexIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildDiversitySection() {
    return _SectionBlock(
      title: 'How many stops?',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_diversityOptions.length, (i) {
          return _PillChip(
            label: _diversityOptions[i],
            selected: _diversityIndex == i,
            accent: AweColors.accentTeal,
            onTap: () => setState(() => _diversityIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildDietarySection() {
    return _SectionBlock(
      title: 'Dietary Preference',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_dietaryOptions.length, (i) {
          return _PillChip(
            label: _dietaryOptions[i],
            selected: _dietaryIndex == i,
            accent: AweColors.accentTerracotta,
            onTap: () => setState(() => _dietaryIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AweColors.background,
        border: const Border(top: BorderSide(color: AweColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => _onGenerateTap(context),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: AweColors.accentSlate,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Generate Itinerary',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on _ItineraryBuilderScreenState {
  void _onGenerateTap(BuildContext context) {
    if (!PremiumService().isPremium) {
      Navigator.of(context).pushNamed('/paywall');
      return;
    }
    final dest = _destinationCtrl.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a destination.')));
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a start date.')));
      return;
    }
    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an end date.')));
      return;
    }

    final affordability = _affordability[_affordabilityIndex];
    final styles = _selectedStyles.toList();
    final flexibility = _flexOptions[_flexIndex];
    Navigator.of(context).pushNamed(
      '/loading',
      arguments: {
        'generateTask': _generate(dest, affordability, styles, flexibility, null),
      },
    );
  }

  Future<Map<String, dynamic>> _generate(
    String dest, String affordability, List<String> styles, String flexibility, StreamController<String>? progress,
  ) async {
    final ai = ItineraryAIService();
    final diversity = switch (_diversityIndex) {
      0 => 'deep_dive',
      2 => 'wide',
      _ => 'balanced',
    };
    final party = _partyOptions[_partyIndex];
    final travelers = switch (party) {
      'Solo' => 1,
      'Couple' => 2,
      'Friends' => 3,
      'Family' => 4,
      _ => 2,
    };
    return ai.generateItineraryArchitectBuilders(
      destination: dest,
      startDate: _startDate!,
      endDate: _endDate!,
      affordability: affordability,
      travelStyles: styles,
      flexibility: flexibility,
      travelParty: party,
      travelers: travelers,
      dietaryPreference: _dietaryOptions[_dietaryIndex] == 'No preference' ? null : _dietaryOptions[_dietaryIndex],
      diversityPreference: diversity,
      onProgress: (s) => progress?.add(s),
      mustSee: _parseMustInclude(),
    );
  }
}

extension _IncludePlaces on _ItineraryBuilderScreenState {
  static final TextEditingController _includeCtrl = TextEditingController();

  Widget _buildIncludeSection() {
    return _SectionBlock(
      title: 'Include Places (optional)',
      child: TextField(
        controller: _includeCtrl,
        style: GoogleFonts.sourceSans3(
          color: AweColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Comma separated: e.g., Jeju, Seoul',
          hintStyle: GoogleFonts.sourceSans3(
            color: AweColors.textSecondary,
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AweColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AweColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AweColors.accentTeal),
          ),
          fillColor: Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  List<String>? _parseMustInclude() {
    final raw = _IncludePlaces._includeCtrl.text.trim();
    if (raw.isEmpty) return null;
    final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? null : parts;
  }
}

// ─── Scroll body with collapsing header ────────────────────────────────────

class _ItineraryScrollBody extends StatefulWidget {
  final Widget destinationCard;
  final Widget datesSection;
  final Widget partySection;
  final Widget budgetSection;
  final Widget travelStyleSection;
  final Widget flexibilitySection;
  final Widget dietarySection;
  final Widget diversitySection;
  final Widget includeSection;

  const _ItineraryScrollBody({
    required this.destinationCard,
    required this.datesSection,
    required this.partySection,
    required this.budgetSection,
    required this.travelStyleSection,
    required this.flexibilitySection,
    required this.dietarySection,
    required this.diversitySection,
    required this.includeSection,
  });

  @override
  State<_ItineraryScrollBody> createState() => _ItineraryScrollBodyState();
}

class _ItineraryScrollBodyState extends State<_ItineraryScrollBody> {
  final ScrollController _ctrl = ScrollController();

  static const double _expandedHeight = 260.0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _ctrl,
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: false,
          elevation: 0,
          backgroundColor: AweColors.background,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          expandedHeight: _expandedHeight,
          toolbarHeight: kToolbarHeight,
          collapsedHeight: kToolbarHeight,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AweColors.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              color: AweColors.background,
              child: Stack(
                children: [
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ITINERARY',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10.5,
                            letterSpacing: 1.8,
                            color: const Color(0xFFA08A64),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Dream. Plan.\nGo.',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 36,
                            height: 1.08,
                            color: AweColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Let's start with the basics",
                          style: GoogleFonts.sourceSans3(
                            fontSize: 16,
                            color: AweColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.destinationCard,
                const SizedBox(height: 24),
                const _WarmDivider(),
                const SizedBox(height: 24),
                widget.datesSection,
                const SizedBox(height: 24),
                const _WarmDivider(),
                const SizedBox(height: 24),
                widget.partySection,
                const SizedBox(height: 24),
                const _WarmDivider(),
                const SizedBox(height: 24),
                widget.travelStyleSection,
                const SizedBox(height: 24),
                const _WarmDivider(),
                const SizedBox(height: 24),
                widget.budgetSection,
                const SizedBox(height: 24),
                const _WarmDivider(),
                const SizedBox(height: 24),
                widget.flexibilitySection,
                const SizedBox(height: 24),
                const _WarmDivider(),
                const SizedBox(height: 24),
                widget.dietarySection,
                const SizedBox(height: 24),
                const _WarmDivider(),
                const SizedBox(height: 24),
                widget.diversitySection,
                const SizedBox(height: 24),
                const _WarmDivider(),
                const SizedBox(height: 24),
                widget.includeSection,
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────

class _WarmDivider extends StatelessWidget {
  const _WarmDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AweColors.divider);
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSerifDisplay(fontSize: 18, color: AweColors.textPrimary),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _SelectionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SelectionRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AweColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AweColors.accentTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AweColors.accentTeal, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sourceSans3(
                  color: AweColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text('>', style: TextStyle(fontSize: 20, color: const Color(0xFFCDC3B0))),
          ],
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _PillChip({required this.label, required this.selected, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: selected ? accent.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(
            color: selected ? accent : AweColors.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.sourceSans3(
            color: selected ? accent : AweColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StyleOption {
  final String label;
  final IconData icon;
  final Color color;
  const _StyleOption(this.label, this.icon, this.color);
}

class _SquareTile extends StatelessWidget {
  final _StyleOption option;
  final bool selected;
  final VoidCallback onTap;
  const _SquareTile({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? option.color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? option.color : AweColors.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon, color: selected ? option.color : AweColors.textSecondary, size: 22),
            const SizedBox(height: 10),
            Text(
              option.label,
              style: GoogleFonts.sourceSans3(
                color: selected ? option.color : AweColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
