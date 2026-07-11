import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/models/destination.dart';
import 'package:wanderwell/services/itinerary_ai_service.dart';
import 'package:wanderwell/services/destination_service.dart';
import 'package:wanderwell/screens/loading_screen.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/bloc/destination_detail_cubit.dart';
import 'package:wanderwell/widgets/cta_button.dart';
// Removed structured overview import; reverting to simple About section

class DestinationDetailScreen extends StatefulWidget {
  final Destination destination;
  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  late final DestinationDetailCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = DestinationDetailCubit(destination: widget.destination);
    // Always auto-enrich on open
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _cubit.fetchRichDescription(force: true));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.destination;
    return BlocProvider.value(
        value: _cubit,
        child: Scaffold(
          backgroundColor: FlowColors.primaryDark,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Collapsible hero image app bar
              SliverAppBar(
                pinned: true, // keep a compact bar visible when collapsed
                snap: false,
                floating: false,
                stretch: false,
                expandedHeight: 320, // tweak this to taste
                backgroundColor: FlowColors.primaryDark,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                // We don't want any title when collapsed, so leave title empty.
                title: const SizedBox.shrink(),
                // Provide a leading back button that appears both expanded & collapsed.
                leading: IconButton(
                  icon:
                      const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                // Flexible space holds the hero image (full bleed) and optional gradient
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'dest-image-${d.id}',
                        child: d.imageUrl.startsWith('http')
                            ? Image.network(
                                _safeImageUrl(d.imageUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: FlowColors.cardGradientStartDark,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.landscape,
                                      color: FlowColors.textGrey, size: 32),
                                ),
                              )
                            : Image.asset(
                                d.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: FlowColors.cardGradientStartDark,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.landscape,
                                      color: FlowColors.textGrey, size: 32),
                                ),
                              ),
                      ),
                      // Optional subtle top/bottom gradient to improve contrast on top/back button
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            // You can change the colors to add a darker bottom overlay
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.name,
                                  style: GoogleFonts.raleway(
                                    color: FlowColors.textLight,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.place_outlined,
                                        size: 16, color: FlowColors.textGrey),
                                    const SizedBox(width: 6),
                                    Text(
                                      d.country,
                                      style: GoogleFonts.raleway(
                                          color: FlowColors.textGrey,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox.shrink()
                        ],
                      ),

                      const SizedBox(height: 16),
                      // About section + Trip Length selector
                      BlocBuilder<DestinationDetailCubit,
                          DestinationDetailState>(
                        buildWhen: (p, n) =>
                            p.description != n.description ||
                            p.loadingDescription != n.loadingDescription ||
                            p.days != n.days ||
                            p.aiStepIndex != n.aiStepIndex,
                        builder: (context, state) {
                          final aboutText = state.description.trim();
                          final paras = _splitIntoFriendlyParagraphs(aboutText);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionTitle(label: 'About'),
                                    const SizedBox(height: 8),
                                    // Desired behavior:
                                    // - Show AgenticSteps during loading
                                    // - When steps are completed (aiStepIndex >= 4) but the text hasn't arrived yet (paras.isEmpty),
                                    //   show BOTH the checked steps and the warming message together.
                                    // - Once paragraphs arrive, show only the paragraphs.
                                    Builder(builder: (context) {
                                      final showSteps =
                                          state.loadingDescription ||
                                              (state.aiStepIndex >= 4 &&
                                                  paras.isEmpty);
                                      final showWarming =
                                          (state.aiStepIndex >= 4) &&
                                              paras.isEmpty;

                                      if (paras.isNotEmpty) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            for (int i = 0;
                                                i < paras.length;
                                                i++) ...[
                                              Text(
                                                paras[i],
                                                style: GoogleFonts.raleway(
                                                    color: FlowColors.textLight,
                                                    height: 1.5),
                                              ),
                                              if (i != paras.length - 1)
                                                const SizedBox(height: 8),
                                            ]
                                          ],
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (showSteps) ...[
                                            AgenticSteps(
                                              currentStep: state.aiStepIndex,
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                          if (showWarming)
                                            Text(
                                              'Warming up the details…',
                                              style: GoogleFonts.raleway(
                                                  color: FlowColors.textGrey),
                                            ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _Card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionTitle(label: 'Trip Length'),
                                    const SizedBox(height: 10),
                                    _DaysSelector(
                                      value: state.days,
                                      onChanged: (v) => context
                                          .read<DestinationDetailCubit>()
                                          .setDays(v),
                                      hint:
                                          'Typical: ${d.idealDays} day${d.idealDays == 1 ? '' : 's'}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context),
        ));
  }

  String _safeImageUrl(String url) {
    if (!url.contains('unsplash.com')) return url;
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params.remove('auto'); // ← this is the key line, removes auto=format
    params['fm'] = 'jpg'; // force JPEG
    return uri.replace(queryParameters: params).toString();
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(color: FlowColors.primaryDark),
        child: BlocBuilder<DestinationDetailCubit, DestinationDetailState>(
          buildWhen: (p, n) =>
              p.generatingItinerary != n.generatingItinerary ||
              p.loadingDescription != n.loadingDescription ||
              p.description != n.description,
          builder: (context, state) {
            final hasDescription = state.description.trim().isNotEmpty;
            final canGenerate = !state.generatingItinerary &&
                !state.loadingDescription &&
                hasDescription;

            if (state.generatingItinerary) {
              return CtaButton(
                label: 'Generating…',
                onPressed: () {},
                loading: true,
              );
            }

            // Always show the primary CTA. If tapped too early, show a snackbar.
            return CtaButton(
              label: 'Generate Itinerary',
              leadingIcon: Icons.auto_awesome,
              onPressed: () {
                if (!canGenerate) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(const SnackBar(
                    content: Text(
                        'Details are being generated. Please wait — then you can build your itinerary.'),
                  ));
                  return;
                }
                _onGenerate();
              },
            );
          },
        ),
      ),
    );
  }

  void _onGenerate() {
    final name = widget.destination.name;
    final now = DateTime.now();
    // Start tomorrow (season/festival awareness needs concrete dates)
    final start =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final days = _cubit.state.days;
    final end = start.add(Duration(days: (days - 1).clamp(0, 365)));

    // Use the local cubit; our BlocProvider is below this State's context
    _cubit.setGenerating(true);

    // Use the same robust Architect → Builders flow as the main Builder screen,
    // with sensible defaults. We only vary the trip length here.
    final task = ItineraryAIService().generateItineraryArchitectBuilders(
      destination: name,
      startDate: start,
      endDate: end,
      affordability: 'Moderate', // standard default
      travelStyles: const ['Adventure', 'Culture'], // standard default
      flexibility: 'Balanced', // standard default daily pace
      travelParty: 'Couple', // standard default party
      travelers: 2,
      pace: 'moderate',
      diversityPreference: 'balanced', // visit 2–3 places when days allow
      mustSee: null,
      dietaryPreference: null,
    );

    debugPrint(
        '[DestinationDetail] Pushing LoadingScreen for $name ($days days)');

    Navigator.of(context).pushNamed('/loading', arguments: {
      'generateTask': task,
    }).then((_) {
      if (mounted) _cubit.setGenerating(false);
    });
  }
}

// Split long text into short, readable paragraphs (2–3 sentences each, max ~3 paras)
List<String> _splitIntoFriendlyParagraphs(String input) {
  if (input.isEmpty) return const [];
  final normalized = input
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Split by sentence enders while keeping them
  final parts = <String>[];
  final buffer = StringBuffer();
  for (int i = 0; i < normalized.length; i++) {
    final ch = normalized[i];
    buffer.write(ch);
    if (ch == '.' || ch == '!' || ch == '?') {
      final s = buffer.toString().trim();
      if (s.isNotEmpty) parts.add(s);
      buffer.clear();
    }
  }
  final last = buffer.toString().trim();
  if (last.isNotEmpty) parts.add(last);

  // Group sentences into paragraphs of 2–3 sentences
  final paras = <String>[];
  int idx = 0;
  while (idx < parts.length && paras.length < 3) {
    final take =
        (parts.length - idx >= 3) ? 3 : ((parts.length - idx >= 2) ? 2 : 1);
    final para =
        parts.sublist(idx, (idx + take).clamp(0, parts.length)).join(' ');
    paras.add(para);
    idx += take;
  }
  return paras;
}

// Build a more readable About body: short intro + bulleted subsections
List<Widget> _buildReadableAbout(String input) {
  final widgets = <Widget>[];
  final text = input.trim();
  if (text.isEmpty) {
    widgets.add(Text(
      'Details are on the way…',
      style: GoogleFonts.raleway(color: FlowColors.textGrey),
    ));
    return widgets;
  }

  final sentences = _splitIntoSentences(text);
  if (sentences.isEmpty) {
    widgets.add(Text(
      text,
      style: GoogleFonts.raleway(color: FlowColors.textLight, height: 1.5),
    ));
    return widgets;
  }

  // Intro: first 1–2 concise sentences
  final introCount = sentences.length >= 2 ? 2 : 1;
  final intro = sentences.take(introCount).join(' ');
  widgets.add(Text(
    intro,
    style: GoogleFonts.raleway(color: FlowColors.textLight, height: 1.5),
  ));

  final rest = sentences.skip(introCount).toList();
  if (rest.isEmpty) return widgets;

  final tipsKw = <String>{
    'tip',
    'note',
    'consider',
    'keep in mind',
    'before you go',
    'avoid',
    'crowd',
    'busy',
    'season',
    'weather',
    'peak',
    'visa',
    'currency',
    'pass',
    'etiquette',
    'reservation',
    'cash',
    'card',
    'safety',
  };
  final foodKw = <String>{
    'food',
    'cuisine',
    'eat',
    'dining',
    'restaurant',
    'street food',
    'tea',
    'coffee',
    'bar',
    'drink',
    'sake',
    'wine',
    'beer',
    'market',
    'stall',
    'dish',
    'flavor',
    'taste',
    'sweet',
    'savory',
  };

  final tips = <String>[];
  final foodCulture = <String>[];
  final highlights = <String>[];

  for (final s in rest) {
    final lower = s.toLowerCase();
    if (tipsKw.any((k) => lower.contains(k))) {
      tips.add(s);
    } else if (foodKw.any((k) => lower.contains(k))) {
      foodCulture.add(s);
    } else {
      highlights.add(s);
    }
  }

  // Cap list sizes to keep it scannable
  final cappedHighlights = highlights.take(6).toList();
  final cappedFood = foodCulture.take(4).toList();
  final cappedTips = tips.take(4).toList();

  if (cappedHighlights.isNotEmpty) {
    widgets.add(const SizedBox(height: 12));
    widgets.add(const _SubTitle(label: 'Highlights'));
    widgets.add(const SizedBox(height: 6));
    widgets
        .addAll(cappedHighlights.map((e) => _BulletRow(text: _bulletize(e))));
  }

  if (cappedFood.isNotEmpty) {
    widgets.add(const SizedBox(height: 12));
    widgets.add(const _SubTitle(label: 'Food & Culture'));
    widgets.add(const SizedBox(height: 6));
    widgets.addAll(cappedFood.map((e) => _BulletRow(text: _bulletize(e))));
  }

  if (cappedTips.isNotEmpty) {
    widgets.add(const SizedBox(height: 12));
    widgets.add(const _SubTitle(label: 'Good to Know'));
    widgets.add(const SizedBox(height: 6));
    widgets.addAll(cappedTips.map((e) => _TipRow(text: _bulletize(e))));
  }

  return widgets;
}

List<String> _splitIntoSentences(String input) {
  final normalized = input
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return const [];

  final parts = <String>[];
  final buffer = StringBuffer();
  for (int i = 0; i < normalized.length; i++) {
    final ch = normalized[i];
    buffer.write(ch);
    if (ch == '.' || ch == '!' || ch == '?') {
      final s = buffer.toString().trim();
      if (s.isNotEmpty) parts.add(s);
      buffer.clear();
    }
  }
  final last = buffer.toString().trim();
  if (last.isNotEmpty) parts.add(last);
  return parts;
}

String _bulletize(String sentence) {
  var s = sentence.trim();
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  // If there are long em-dash/asides, keep the part before the dash for brevity
  final dashIdx = s.indexOf('—');
  if (dashIdx > 0 && dashIdx >= s.length * 0.35) {
    s = s.substring(0, dashIdx).trim();
  }
  // Clamp excessively long bullets
  if (s.length > 140) {
    s = s.substring(0, 137).trimRight();
    if (!s.endsWith('…')) s = s + '…';
  }
  return s;
}

// Generic card wrapper to unify section styling
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowColors.cardSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: FlowColors.cardBorderDark.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class WhyVisitSection extends StatelessWidget {
  final String destinationName;
  final String text;
  const WhyVisitSection(
      {super.key, required this.destinationName, required this.text});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(label: 'Why Visit $destinationName'),
          const SizedBox(height: 8),
          Text(
            text,
            style:
                GoogleFonts.raleway(color: FlowColors.textLight, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class KeyInsightsSection extends StatelessWidget {
  final List<String> items;
  const KeyInsightsSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final insights = _normalizeInsights(items);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'Key Insights'),
          const SizedBox(height: 10),
          ...insights.map((pair) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InsightRow(label: pair.$1, value: pair.$2),
              )),
        ],
      ),
    );
  }
}

class BreakdownSection extends StatelessWidget {
  final String geographyHistory;
  final String unique;
  final String experience;
  const BreakdownSection(
      {super.key,
      required this.geographyHistory,
      required this.unique,
      required this.experience});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'The Breakdown'),
          const SizedBox(height: 10),
          const _SubTitle(label: 'Geography & History'),
          const SizedBox(height: 6),
          Text(geographyHistory,
              style: GoogleFonts.raleway(
                  color: FlowColors.textLight, height: 1.45)),
          const SizedBox(height: 12),
          const _SubTitle(label: 'What Makes It Unique'),
          const SizedBox(height: 6),
          Text(unique,
              style: GoogleFonts.raleway(
                  color: FlowColors.textLight, height: 1.45)),
          const SizedBox(height: 12),
          const _SubTitle(label: 'The Travel Experience'),
          const SizedBox(height: 6),
          Text(experience,
              style: GoogleFonts.raleway(
                  color: FlowColors.textLight, height: 1.45)),
        ],
      ),
    );
  }
}

class DontMissSection extends StatelessWidget {
  final List<String> items;
  const DontMissSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final list = items.take(5).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'Don’t Miss These'),
          const SizedBox(height: 8),
          ...list.map((e) => _BulletRow(text: e)).toList(),
        ],
      ),
    );
  }
}

class PerfectForSection extends StatelessWidget {
  final List<String> items;
  const PerfectForSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final chips = items.take(6).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'Perfect For'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((e) => _Chip(text: e)).toList(),
          ),
        ],
      ),
    );
  }
}

class IdealDurationSection extends StatelessWidget {
  final String text;
  const IdealDurationSection({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'Ideal Trip Duration'),
          const SizedBox(height: 8),
          Text(text,
              style: GoogleFonts.raleway(
                  color: FlowColors.textLight, height: 1.45)),
        ],
      ),
    );
  }
}

class BeforeYouPlanSection extends StatelessWidget {
  final List<String> items;
  const BeforeYouPlanSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final list = items.take(5).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'Before You Plan'),
          const SizedBox(height: 8),
          ...list.map((e) => _TipRow(text: e)).toList(),
        ],
      ),
    );
  }
}

// Returns pairs of (label, value). If no colon, the whole string becomes value with a default label.
List<(String, String)> _normalizeInsights(List<String> items) {
  final out = <(String, String)>[];
  for (final raw in items) {
    final s = raw.trim();
    if (s.isEmpty) continue;
    final idx = s.indexOf(':');
    if (idx > 0 && idx < s.length - 1) {
      final label = s.substring(0, idx).trim();
      final value = s.substring(idx + 1).trim();
      out.add((label, value));
    } else {
      out.add(('Insight', s));
    }
  }
  // Always return exactly 3 items by padding generic ones if needed
  while (out.length < 3) {
    out.add(('Insight', 'Concise highlight'));
  }
  return out.take(3).toList();
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.raleway(
        color: FlowColors.textLight,
        fontWeight: FontWeight.w800,
        fontSize: 16,
        height: 1.2,
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String label;
  const _SubTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.raleway(
        color: FlowColors.textGrey,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  const _InsightRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: FlowColors.chipBgDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: FlowColors.chipBorderDark.withValues(alpha: 0.14)),
          ),
          child: Text(
            label,
            style: GoogleFonts.raleway(
              color: FlowColors.textLight,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.raleway(color: FlowColors.textGrey, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: GoogleFonts.raleway(color: FlowColors.textGrey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.raleway(
                  color: FlowColors.textLight, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String text;
  const _TipRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: FlowColors.textGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.raleway(
                  color: FlowColors.textLight, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class AgenticSteps extends StatelessWidget {
  final int currentStep; // 0..4 (4 means complete)
  const AgenticSteps({super.key, required this.currentStep});

  static const List<String> _steps = [
    'Understanding the destination context',
    'Pinpointing signature experiences and neighborhoods',
    'Weaving details into a friendly, concise flow',
    'Polishing for clarity and specificity',
  ];

  @override
  Widget build(BuildContext context) {
    final steps = List<String>.from(_steps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (i) {
        final status = _stepStatus(i, currentStep);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              _statusIcon(status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  steps[i],
                  style: GoogleFonts.raleway(
                    color: status == _StepStatus.pending
                        ? FlowColors.textGrey
                        : FlowColors.textLight,
                    fontWeight: status == _StepStatus.active
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  _StepStatus _stepStatus(int index, int current) {
    if (current <= 0) return _StepStatus.pending;
    if (index < current - 1) return _StepStatus.done;
    if (index == current - 1 && current < 4) return _StepStatus.active;
    if (current >= 4) return _StepStatus.done;
    return _StepStatus.pending;
  }

  Widget _statusIcon(_StepStatus s) {
    switch (s) {
      case _StepStatus.done:
        return const Icon(Icons.check_circle,
            size: 16, color: Colors.greenAccent);
      case _StepStatus.active:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(FlowColors.textLight),
          ),
        );
      case _StepStatus.pending:
      default:
        return const Icon(Icons.radio_button_unchecked,
            size: 16, color: FlowColors.textGrey);
    }
  }
}

enum _StepStatus { pending, active, done }

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlowColors.chipBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: FlowColors.chipBorderDark.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: GoogleFonts.raleway(
          color: FlowColors.textLight,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DaysSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String hint;
  const _DaysSelector(
      {required this.value, required this.onChanged, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FlowColors.cardSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: FlowColors.cardBorderDark.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _SquareIconButton(
              icon: Icons.remove,
              onTap: () => onChanged((value - 1).clamp(1, 21))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('$value days',
                    style: GoogleFonts.raleway(
                        color: FlowColors.textLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                const SizedBox(height: 4),
                Text(hint,
                    style: GoogleFonts.raleway(
                        color: FlowColors.textGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SquareIconButton(
              icon: Icons.add,
              onTap: () => onChanged((value + 1).clamp(1, 21))),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareIconButton({required this.icon, required this.onTap});

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
