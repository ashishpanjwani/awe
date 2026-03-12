import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/widgets/cta_button.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:wanderwell/services/photon_service.dart';
import 'package:wanderwell/models/place_suggestion.dart';
import 'package:wanderwell/services/itinerary_ai_service.dart';
import 'package:wanderwell/screens/loading_screen.dart';

class ItineraryBuilderScreen extends StatefulWidget {
  const ItineraryBuilderScreen({super.key});

  @override
  State<ItineraryBuilderScreen> createState() => _ItineraryBuilderScreenState();
}

class _ItineraryBuilderScreenState extends State<ItineraryBuilderScreen> {
  final TextEditingController _destinationCtrl = TextEditingController();
  final PhotonService _photon = PhotonService();
  PlaceSuggestion? _selectedPlace;

  // Keep references to the internal TypeAhead controller/focus to manage UX precisely
  TextEditingController? _typeAheadController;
  FocusNode? _destinationFocusNode;

  // Dates (start & end separately)
  DateTime? _startDate;
  DateTime? _endDate;

  // Travel style multi-select
  final List<_StyleOption> _styles = const [
    _StyleOption('Adventure', Icons.hiking, FlowColors.accentTeal),
    _StyleOption('Foodie', Icons.restaurant_menu, FlowColors.accentOrange),
    _StyleOption('Culture', Icons.museum_outlined, FlowColors.accentGreen),
    _StyleOption('Romantic', Icons.favorite_border, FlowColors.accentBrown),
    _StyleOption('Nature', Icons.park_outlined, FlowColors.accentTeal),
    _StyleOption('Nightlife', Icons.local_bar, FlowColors.vibrantViolet),
  ];
  final Set<String> _selectedStyles = {'Adventure', 'Culture'};

  // Affordability single-select
  final List<String> _affordability = const ['Budget', 'Moderate', 'Luxury'];
  int _affordabilityIndex = 1;

  // Daily schedule pacing (formerly Flexibility)
  final List<String> _flexOptions = const [
    'Structured',
    'Balanced',
    'Relaxed',
  ];
  int _flexIndex = 1;

  // Trip shape: how many stops
  final List<String> _diversityOptions = const [
    'Stay mostly in one place',
    'Visit 2–3 places',
    'Visit 3–5 places',
  ];
  int _diversityIndex = 1;

  // Travel party (who's traveling)
  final List<String> _partyOptions = const [
    'Couple',
    'Family',
    'Friends',
    'Solo',
  ];
  int _partyIndex = 0;

  // Dietary preference (optional)
  final List<String> _dietaryOptions = const [
    'No preference',
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Halal',
    'Kosher',
    'Gluten-free',
    'Jain',
  ];
  int _dietaryIndex = 0;

  String _formatLongDate(DateTime d) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const monthsAbbr = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final w = weekdays[(d.weekday - 1).clamp(0, 6)];
    final m = monthsAbbr[(d.month - 1).clamp(0, 11)];
    return '$w, ${d.day} $m ${d.year}';
  }

  @override
  void initState() {
    super.initState();
    // Prewarm place suggestions to avoid first-typing cold start lag
    _photon.prewarm();
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
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

  // Hero banner now lives inside SliverAppBar within _ItineraryScrollBody

  Widget _buildDestinationCard() {
    // Single input field styled like the screenshot: dark rounded rectangle,
    // left location icon, no trailing arrow, soft border, compact spacing.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FlowColors.cardSurfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: FlowColors.cardBorderDark.withValues(alpha: 0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dropdownWidth = constraints.maxWidth;
          // Anchor the TypeAhead to the full pill width by making
          // the builder return the entire row (icons + text field).
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
                return await _photon.autocomplete(pattern,
                    limit: 8, lang: 'en');
              } catch (e) {
                // ignore: avoid_print
                debugPrint('Typeahead search error: $e');
                return [];
              }
            },
            builder: (context, controller, focusNode) {
              // Keep references so we can update/collapse properly on selection
              _typeAheadController = controller;
              _destinationFocusNode = focusNode;
              // Keep text in sync without forcing selection/caret resets
              if (controller.text != _destinationCtrl.text) {
                controller.text = _destinationCtrl.text;
              }
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FlowColors.textLight.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: FlowColors.textLight, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (v) => _destinationCtrl.text = v,
                      style: GoogleFonts.raleway(
                          color: FlowColors.textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      cursorColor: FlowColors.softTealLight,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Where are you going?',
                        hintStyle: GoogleFonts.raleway(
                            color: FlowColors.textGrey,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              );
            },
            itemBuilder: (context, place) {
              final meta = [
                place.city,
                place.state,
                place.country,
              ]
                  .where((e) => e != null && e!.isNotEmpty)
                  .map((e) => e!)
                  .toList()
                  .join(', ');

              return Container(
                decoration: BoxDecoration(
                  color: FlowColors.cardSurfaceDark,
                  border: Border(
                    bottom: BorderSide(
                        color:
                            FlowColors.cardBorderDark.withValues(alpha: 0.10),
                        width: 1),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: FlowColors.textLight.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.place_outlined,
                          color: FlowColors.textLight, size: 16),
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
                            style: GoogleFonts.raleway(
                              color: FlowColors.textLight,
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
                                style: GoogleFonts.raleway(
                                  color: FlowColors.textGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
              color: FlowColors.cardSurfaceDark,
              child: Text(
                'No matches found',
                style: GoogleFonts.raleway(
                    color: FlowColors.textGrey, fontWeight: FontWeight.w600),
              ),
            ),
            onSelected: (place) {
              // Update both controllers and collapse suggestions cleanly
              final label = place.label;
              setState(() {
                _selectedPlace = place;
                _destinationCtrl
                  ..text = label
                  ..selection = TextSelection.collapsed(offset: label.length);
              });

              // Mirror into the internal controller if available
              if (_typeAheadController != null) {
                _typeAheadController!
                  ..text = label
                  ..selection = TextSelection.collapsed(offset: label.length);
              }

              // Close the overlay by removing focus; prevents lingering dropdown
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
            label: _startDate == null
                ? 'Select Start Date'
                : _formatLongDate(_startDate!),
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
                            surface: FlowColors.surfaceVariantDark,
                            onSurface: FlowColors.textLight,
                            primary: FlowColors.softTealLight,
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _startDate = DateTime(picked.year, picked.month, picked.day);
                  if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                    _endDate = null;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          _SelectionRow(
            icon: Icons.event_outlined,
            label: _endDate == null
                ? 'Select End Date'
                : _formatLongDate(_endDate!),
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
                            surface: FlowColors.surfaceVariantDark,
                            onSurface: FlowColors.textLight,
                            primary: FlowColors.softTealLight,
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _endDate = DateTime(picked.year, picked.month, picked.day);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAffordabilitySection() {
    return _SectionCard(
      title: 'Affordability',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_affordability.length, (i) {
          final selected = _affordabilityIndex == i;
          return _PillChip(
            label: _affordability[i],
            selected: selected,
            accent: FlowColors.accentTeal,
            onTap: () => setState(() => _affordabilityIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildPartySection() {
    return _SectionCard(
      title: 'Travel Party',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_partyOptions.length, (i) {
          final selected = _partyIndex == i;
          final accent = switch (_partyOptions[i]) {
            'Couple' => FlowColors.accentAmber,
            'Family' => FlowColors.accentGreen,
            'Friends' => FlowColors.accentTeal,
            _ => FlowColors.accentOrange,
          };
          return _PillChip(
            label: _partyOptions[i],
            selected: selected,
            accent: accent,
            onTap: () => setState(() => _partyIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildTravelStyleSection() {
    // Bring back expanded set of options (as earlier): 6 tiles
    final items = _styles;

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
        itemCount: items.length,
        itemBuilder: (context, index) {
          final opt = items[index];
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_flexOptions.length, (i) {
              final selected = _flexIndex == i;
              return _PillChip(
                label: _flexOptions[i],
                selected: selected,
                accent: FlowColors.accentGreen,
                onTap: () => setState(() => _flexIndex = i),
              );
            }),
          ),
        ],
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
          final selected = _diversityIndex == i;
          return _PillChip(
            label: _diversityOptions[i],
            selected: selected,
            accent: FlowColors.accentTeal,
            onTap: () => setState(() => _diversityIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildDietarySection() {
    return _SectionCard(
      title: 'Dietary Preference',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_dietaryOptions.length, (i) {
          final selected = _dietaryIndex == i;
          return _PillChip(
            label: _dietaryOptions[i],
            selected: selected,
            accent: FlowColors.accentOrange,
            onTap: () => setState(() => _dietaryIndex = i),
          );
        }),
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(color: FlowColors.primaryDark),
      child: CtaButton(
        label: 'Generate Itinerary',
        onPressed: () => _onGenerateTap(context),
        leadingIcon: Icons.auto_awesome,
      ),
    );
  }
}

extension on _ItineraryBuilderScreenState {
  void _onGenerateTap(BuildContext context) {
    final dest = _destinationCtrl.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a destination.')),
      );
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a start date.')),
      );
      return;
    }
    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an end date.')),
      );
      return;
    }

    // Assemble parameters
    final affordability = _affordability[_affordabilityIndex];
    final styles = _selectedStyles.toList();
    final flexibility = _flexOptions[_flexIndex];
    // Navigate to the loading screen with ONLY the rotating captions.
    // We intentionally do not pass progress stream or custom text so the
    // four fixed phrases are shown consistently across all stages.
    Navigator.of(context).pushNamed(
      '/loading',
      arguments: {
        'generateTask': _generate(dest, affordability, styles, flexibility, null),
      },
    );
  }

  Future<Map<String, dynamic>> _generate(
    String dest,
    String affordability,
    List<String> styles,
    String flexibility,
    StreamController<String>? progress,
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
      dietaryPreference: _dietaryOptions[_dietaryIndex] == 'No preference'
          ? null
          : _dietaryOptions[_dietaryIndex],
      diversityPreference: diversity,
      // We still invoke progress callback for logs/analytics if provided,
      // but the LoadingScreen no longer displays these lines.
      onProgress: (s) => progress?.add(s),
      mustSee: _parseMustInclude(),
    );
  }
}

// --- Include places (chips-like text input minimal) ---
extension _IncludePlaces on _ItineraryBuilderScreenState {
  static final TextEditingController _includeCtrl = TextEditingController();

  Widget _buildIncludeSection() {
    return _SectionCard(
      title: 'Include Places (optional)',
      child: TextField(
        controller: _includeCtrl,
        style: GoogleFonts.raleway(
          color: FlowColors.textLight,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Comma separated: e.g., Jeju, Seoul',
          hintStyle: GoogleFonts.raleway(
            color: FlowColors.textGrey,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: FlowColors.cardBorderDark.withValues(alpha: 0.14),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: FlowColors.cardBorderDark.withValues(alpha: 0.14),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FlowColors.softTealLight),
          ),
          fillColor: FlowColors.cardSurfaceDark,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  List<String>? _parseMustInclude() {
    final raw = _IncludePlaces._includeCtrl.text.trim();
    if (raw.isEmpty) return null;
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts;
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? trailingLabel;
  const _SectionCard(
      {required this.title, required this.child, this.trailingLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            FlowColors.featurePrimaryStartDark,
            FlowColors.featurePrimaryEndDark
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
            color: FlowColors.cardBorderDark.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.raleway(
                      color: FlowColors.textLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
                if (trailingLabel != null)
                  Text(trailingLabel!,
                      style: GoogleFonts.raleway(
                          color: FlowColors.accentAmber,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

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
  bool _showCollapsedTitle = false;

  static const double _expandedHeight = 320.0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onScroll);
  }

  void _onScroll() {
    // Show title when toolbar is collapsed
    final threshold = _expandedHeight - kToolbarHeight - 24;
    final show = _ctrl.hasClients && _ctrl.offset > threshold;
    if (show != _showCollapsedTitle) {
      setState(() => _showCollapsedTitle = show);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    return CustomScrollView(
      controller: _ctrl,
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: false,
          snap: false,
          elevation: 0,
          backgroundColor: FlowColors.primaryDark,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          expandedHeight: _expandedHeight,
          // Standard toolbar height when collapsed
          toolbarHeight: kToolbarHeight,
          collapsedHeight: kToolbarHeight,
          centerTitle: false,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop()),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/Global_Geometric_Adventure.png',
                  fit: BoxFit.cover,
                ),
                // DARKENING OVERLAY (unify image to navy theme)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        FlowColors.primaryDark
                            .withOpacity(0.94), // strong top darkening
                        FlowColors.primaryDark
                            .withOpacity(0.86), // slightly lighter bottom
                      ],
                    ),
                  ),
                ),

                // optional subtle top vignette helps focus the title
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.5, -0.8),
                        radius: 1.2,
                        colors: [
                          Colors.transparent,
                          FlowColors.primaryDark.withOpacity(0.12),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Dark navy semi-transparent overlay to unify header
                // Container(
                //     color: FlowColors.primaryDark.withValues(alpha: 0.90)),
                // Bottom-left titles over image
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24 + topInset * 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dream. Plan. Go.',
                        style: GoogleFonts.raleway(
                          color: FlowColors.textLight,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Let’s start with the basics",
                        style: GoogleFonts.raleway(
                          color: FlowColors.textGrey,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // SOFT SKYLINE (blurred + very low opacity)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: CustomPaint(
                      painter: _SoftHeaderSkylinePainter(
                        color: FlowColors.paleBlue
                            .withOpacity(0.06), // very subtle
                        strokeWidth: 1.0,
                        blurSigma: 1.6, // small blur to soften seam
                      ),
                    ),
                  ),
                ),

                // BOTTOM FEATHER: gradient that fades header into the page background
                // This is the critical part to hide any hard seam.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 48, // how far the feather stretches
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            FlowColors.primaryDark
                                .withOpacity(1.0), // match the body bg
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.destinationCard,
                const SizedBox(height: 12),

                // Dates Section
                const _IllustratedDivider(height: 30),
                const SizedBox(height: 12),
                widget.datesSection,
                const SizedBox(height: 12),

                // Travel Party Section
                const _MountainsDivider(height: 34),
                const SizedBox(height: 12),
                widget.partySection,
                const SizedBox(height: 12),

                // Travel Style Section
                const _SkylineDivider(height: 34),
                const SizedBox(height: 12),
                widget.travelStyleSection,
                const SizedBox(height: 12),

                // Budget Section
                const _IllustratedDivider(height: 30),
                const SizedBox(height: 12),
                widget.budgetSection,
                const SizedBox(height: 12),

                // Flexibility Section
                const _MountainsDivider(height: 34),
                const SizedBox(height: 12),
                widget.flexibilitySection,
                const SizedBox(height: 12),

                // Mountains between Flexibility and Dietary 
                const _SkylineDivider(height: 34),
                const SizedBox(height: 12),
                widget.dietarySection,
                const SizedBox(height: 12),

                // Mountains between Dates and Affordability
                const _IllustratedDivider(height: 30),
                const SizedBox(height: 12),
                widget.diversitySection,
                const SizedBox(height: 12),

                const _MountainsDivider(height: 34),
                const SizedBox(height: 12),
                widget.includeSection,
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftHeaderSkylinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double blurSigma;

  _SoftHeaderSkylinePainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.blurSigma = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      // Soften edges so it merges
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(0, h * 0.66);
    path.quadraticBezierTo(w * 0.06, h * 0.52, w * 0.14, h * 0.64);
    path.quadraticBezierTo(w * 0.20, h * 0.74, w * 0.26, h * 0.62);
    path.quadraticBezierTo(w * 0.34, h * 0.48, w * 0.42, h * 0.56);
    path.quadraticBezierTo(w * 0.52, h * 0.72, w * 0.60, h * 0.64);
    path.quadraticBezierTo(w * 0.70, h * 0.54, w * 0.76, h * 0.60);
    path.quadraticBezierTo(w * 0.84, h * 0.68, w * 0.92, h * 0.60);
    path.lineTo(w, h * 0.62);

    canvas.drawPath(path, paint);

    // draw a second, even fainter stroke to add depth (optional)
    final paint2 = Paint()
      ..color = color.withOpacity((color.opacity * 0.6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma * 0.7);

    canvas.drawPath(path, paint2);
  }

  @override
  bool shouldRepaint(covariant _SoftHeaderSkylinePainter old) {
    return old.color != color ||
        old.strokeWidth != strokeWidth ||
        old.blurSigma != blurSigma;
  }
}

class _DarkChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DarkChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? FlowColors.chipSelectedDark : FlowColors.chipBgDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: FlowColors.chipBorderDark
                  .withValues(alpha: selected ? 0.26 : 0.12)),
        ),
        child: Text(
          label,
          style: GoogleFonts.raleway(
            color: FlowColors.textLight,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
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
  const _PillChip(
      {required this.label,
      required this.selected,
      required this.accent,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: FlowColors.chipBgDark,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.7)
                : FlowColors.chipBorderDark.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.raleway(
            color: FlowColors.textLight,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: FlowColors.cardSurfaceDark,
          border: Border.all(
              color: FlowColors.cardBorderDark.withValues(alpha: 0.14)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FlowColors.textLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: FlowColors.textLight, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.raleway(
                      color: FlowColors.textLight, fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: FlowColors.textGrey, size: 20),
            ],
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

class _BigStyleCard extends StatelessWidget {
  final _StyleOption option;
  final bool selected;
  final VoidCallback onTap;
  const _BigStyleCard(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: FlowColors.cardSurfaceDark,
          border: Border.all(
            color: selected
                ? option.color
                : FlowColors.cardBorderDark.withValues(alpha: 0.10),
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: selected ? 0.35 : 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(option.icon, color: FlowColors.textLight, size: 24),
            ),
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.raleway(
                color: FlowColors.textLight,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Removed legacy modes in favor of simplified UI

class _IconSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconSquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: FlowColors.chipBgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: FlowColors.chipBorderDark.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, size: 18, color: FlowColors.textLight),
      ),
    );
  }
}

class _BackSquareButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackSquareButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Custom button with no ripple/highlight during scroll gestures.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40, // generous hit target
        height: 40,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: FlowColors.textLight, // solid white square
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back_ios_new, // two-stroke back icon
              size: 14,
              color: FlowColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

// Simple section block without background card; matches minimal spec
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
          style: GoogleFonts.raleway(
            color: FlowColors.textLight,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// Selection row used for Start/End Date rows.
class _SelectionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SelectionRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: FlowColors.cardSurfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: FlowColors.cardBorderDark.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FlowColors.textLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: FlowColors.textLight, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.raleway(
                      color: FlowColors.textLight, fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: FlowColors.textGrey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Three square tiles for Adventure, Solo, Foodie
class _SquareTile extends StatelessWidget {
  final _StyleOption option;
  final bool selected;
  final VoidCallback onTap;
  const _SquareTile(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: FlowColors.cardSurfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? option.color.withValues(alpha: 0.7)
                : FlowColors.cardBorderDark.withValues(alpha: 0.12),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: option.color.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon, color: FlowColors.textLight, size: 22),
            const SizedBox(height: 10),
            Text(
              option.label,
              style: GoogleFonts.raleway(
                  color: FlowColors.textLight, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// Thin illustrated divider using waves
class _IllustratedDivider extends StatelessWidget {
  final double height;
  const _IllustratedDivider({this.height = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveLinePainter(),
      ),
    );
  }
}

class _WaveLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FlowColors.cardBorderDark.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final midY = size.height * 0.5;
    final waveWidth = size.width / 4;
    path.moveTo(0, midY);
    for (double x = 0; x <= size.width; x += waveWidth) {
      path.quadraticBezierTo(
        x + waveWidth * 0.25,
        midY - 6,
        x + waveWidth * 0.5,
        midY,
      );
      path.quadraticBezierTo(
        x + waveWidth * 0.75,
        midY + 6,
        x + waveWidth,
        midY,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Mountain peaks divider
class _MountainsDivider extends StatelessWidget {
  final double height;
  const _MountainsDivider({this.height = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _MountainLinePainter(),
      ),
    );
  }
}

class _MountainLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FlowColors.cardBorderDark.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final baseY = size.height * 0.65;
    final segment = size.width / 6;
    double x = 0;

    // Draw a sequence of mountain peaks (triangles), slight height variation
    while (x < size.width) {
      final peakX = x + segment * 0.5;
      final nextX = x + segment;
      final peakY =
          baseY - (6 + (x % (segment * 2)) / segment * 3); // subtle variance
      path.moveTo(x, baseY);
      path.lineTo(peakX, peakY);
      path.lineTo(nextX, baseY);
      x = nextX;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Skyline divider
class _SkylineDivider extends StatelessWidget {
  final double height;
  const _SkylineDivider({this.height = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SkylineLinePainter(),
      ),
    );
  }
}

class _SkylineLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FlowColors.cardBorderDark.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final baseY = size.height * 0.7;
    double x = 0;
    final step = size.width / 14; // many thin buildings

    // Draw building outlines with varying heights and occasional antenna
    while (x < size.width) {
      final width = step * (1 + (x ~/ step) % 3 * 0.2); // slight width variety
      final height = (8 + ((x / step) % 5) * 2);
      final left = x;
      final right = (x + width).clamp(0.0, size.width);
      final top = (baseY - height).clamp(0.0, size.height);

      // Building rectangle outline
      path.moveTo(left, baseY);
      path.lineTo(left, top);
      path.lineTo(right, top);
      path.lineTo(right, baseY);

      // Optional tiny roof/antenna every few buildings
      if (((x / step).round() % 4) == 0) {
        final mid = (left + right) / 2;
        path.moveTo(left, top);
        path.lineTo(mid, top - 3);
        path.lineTo(right, top);
      }

      x = right + step * 0.3; // spacing between buildings
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
