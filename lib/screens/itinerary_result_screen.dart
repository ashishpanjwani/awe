import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/itinerary_repository.dart';

class ItineraryResultScreen extends StatefulWidget {
  const ItineraryResultScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<ItineraryResultScreen> createState() => _ItineraryResultScreenState();
}

class _ItineraryResultScreenState extends State<ItineraryResultScreen>
    with SingleTickerProviderStateMixin {
  late final List _days;
  late final String _destination;
  DateTime? _startDate;
  DateTime? _endDate;
  TabController? _tabController;
  int _index = 0;
  double _tabAnimationValue = 0.0;
  bool _isSaved = false; // toggles when user saves from this screen
  String? _savedId; // Firestore doc id when saved
  bool _openedFromSaved = false; // if true, show delete instead of save toggle

  @override
  void initState() {
    super.initState();
    _days = (widget.data['days'] as List?) ?? [];
    _destination = widget.data['destination'] as String? ?? 'Your Trip';
    final s = widget.data['startDate']?.toString();
    final e = widget.data['endDate']?.toString();
    _startDate = s != null ? DateTime.tryParse(s) : null;
    _endDate = e != null ? DateTime.tryParse(e) : null;
    // If navigated from Saved list, we inject a meta key '__savedId'
    final metaSavedId = widget.data['__savedId']?.toString();
    if (metaSavedId != null && metaSavedId.isNotEmpty) {
      _openedFromSaved = true;
      _isSaved = true;
      _savedId = metaSavedId;
    }
    if (_days.isNotEmpty) {
      _tabController =
          TabController(length: _days.length.clamp(1, 30), vsync: this);
      _tabController!.animation?.addListener(() {
        // Track continuous swipe progress for pill highlight
        setState(() {
          _tabAnimationValue = _tabController!.animation!.value;
        });
      });
      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) return;
        if (_index != _tabController!.index) {
          setState(() => _index = _tabController!.index);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final destination = _destination;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      appBar: AppBar(
        backgroundColor: FlowColors.primaryDark,
        elevation: 0,
        title: _TwoLineTitle(
          title: destination,
          subtitle: _formatDateRange(_startDate, _endDate),
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop()),
        centerTitle: true,
        actions: [
          if (_openedFromSaved)
            IconButton(
              tooltip: 'Delete itinerary',
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => _onDeletePressed(context),
            )
          else if ((widget.data['error'] as String?)?.isNotEmpty == true)
            SizedBox.shrink()
          else
            IconButton(
              tooltip: _isSaved ? 'Unsave itinerary' : 'Save itinerary',
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                color: Colors.white,
              ),
              onPressed: () async {
                if (_isSaved) {
                  await _onUnsavePressed(context);
                } else {
                  await _onSavePressed(context);
                }
              },
            )
        ],
        bottom: days.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                  child: _DayPillTabs(
                    labels: [
                      for (int i = 0; i < days.length; i++) 'Day ${i + 1}'
                    ],
                    index: _index,
                    progress: _tabAnimationValue,
                    onChanged: (i) {
                      setState(() => _index = i);
                      _tabController?.animateTo(i);
                    },
                  ),
                ),
              ),
      ),
      body: days.isEmpty
          ? _EmptyView(raw: widget.data)
          : TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final day in days)
                  _DayTimeline(
                    date: day['date'] as String? ?? '',
                    title: day['title'] as String? ?? '',
                    summary: day['summary'] as String? ?? '',
                    activities: (day['activities'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const [],
                  ),
              ],
            ),
    );
  }
}

extension on _ItineraryResultScreenState {
  String? _formatDateRange(DateTime? s, DateTime? e) {
    if (s == null || e == null) return null;
    String fmt(DateTime d) {
      const months = [
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
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    }

    return '${fmt(s)} - ${fmt(e)}';
  }

  Future<void> _onSavePressed(BuildContext context) async {
    final user = AuthService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save itineraries.')),
      );
      return;
    }

    final dest = _destination;
    final range = _formatDateRange(_startDate, _endDate);
    final defaultName = range == null ? '$dest Trip' : '$dest ($range)';

    final nameCtrl = TextEditingController(text: defaultName);
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: FlowColors.cardSurfaceDark,
          title: const Text('Save Itinerary',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed == null || confirmed.isEmpty) return;

    final s = _startDate ?? DateTime.now();
    final e = _endDate ?? s;
    try {
      final id = await ItineraryRepository.instance.save(
        uid: user.id,
        name: confirmed,
        destination: _destination,
        startDate: s,
        endDate: e,
        data: widget.data,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itinerary saved')),
      );
      setState(() {
        _isSaved = true;
        _savedId = id;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _onUnsavePressed(BuildContext context) async {
    final user = AuthService().currentUser;
    if (user == null || _savedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in.')),
      );
      return;
    }
    try {
      await ItineraryRepository.instance.delete(uid: user.id, id: _savedId!);
      if (!mounted) return;
      setState(() {
        _isSaved = false;
        _savedId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from saved itineraries')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: $e')),
      );
    }
  }

  Future<void> _onDeletePressed(BuildContext context) async {
    final user = AuthService().currentUser;
    final id = _savedId;
    if (user == null || id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing itinerary id or user')),
      );
      return;
    }
    await _showConfirmBottomSheet(
      context,
      title: 'Delete this itinerary?',
      message:
          'This will permanently remove it from your saved itineraries. You can always generate a new one later.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline,
      iconColor: Colors.redAccent,
      onConfirm: () async {
        await ItineraryRepository.instance.delete(uid: user.id, id: id);
      },
    );
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _showConfirmBottomSheet(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
    required Color iconColor,
    required Future<void> Function() onConfirm,
  }) async {
    bool running = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: FlowColors.cardSurfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cs = theme.colorScheme;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: iconColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: FlowColors.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: FlowColors.textLight.withValues(alpha: 0.9),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            foregroundColor: FlowColors.textLight,
                            side: BorderSide(
                              color: FlowColors.cardBorderDark
                                  .withValues(alpha: 0.16),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed:
                              running ? null : () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: cs.secondary,
                            foregroundColor: cs.onSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: running
                              ? null
                              : () async {
                                  setModalState(() => running = true);
                                  try {
                                    await onConfirm();
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Something went wrong. Please try again.'),
                                        ),
                                      );
                                    }
                                    setModalState(() => running = false);
                                  }
                                },
                          child: running
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        cs.onSecondary),
                                  ),
                                )
                              : Text(confirmLabel),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.raw});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final hasError = (raw['error'] as String?)?.isNotEmpty == true;
    final errorMessage = (raw['error'] as String?) ?? '';

    if (hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Friendly illustration
              Image.asset(
                'assets/images/minimal_travel_error_illustration_airplane_warning_sign_gray_1763394371352.png',
                width: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                "We couldn't generate your itinerary",
                textAlign: TextAlign.center,
                style: GoogleFonts.raleway(
                  color: FlowColors.textLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The service looks a bit busy right now. Please try again in a little while.',
                textAlign: TextAlign.center,
                style: GoogleFonts.raleway(
                  color: FlowColors.textGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // if (errorMessage.isNotEmpty) ...[
              //   const SizedBox(height: 14),
              //   Text(
              //     errorMessage,
              //     textAlign: TextAlign.center,
              //     style: GoogleFonts.robotoMono(
              //       color: Colors.white70,
              //       fontSize: 12,
              //     ),
              //   ),
              // ],
            ],
          ),
        ),
      );
    }

    // Generic empty fallback when there are no days but also no explicit error
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/map_pin_with_warning_triangle_illustration_blue_1763394372307.png',
              width: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              'No itinerary to show yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.raleway(
                color: FlowColors.textLight,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please go back and try generating again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.raleway(
                color: FlowColors.textGrey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.date,
    required this.title,
    required this.summary,
    required this.activities,
  });

  final String date;
  final String title;
  final String summary;
  final List<Map<String, dynamic>> activities;

  @override
  Widget build(BuildContext context) {
    String _cleanInline(String s) {
      if (s.isEmpty) return s;
      // Replace any newlines or carriage returns with single spaces and
      // collapse repeated whitespace to avoid vertical text artifacts.
      final noBreaks = s.replaceAll(RegExp(r"[\r\n]+"), ' ');
      return noBreaks.replaceAll(RegExp(r"\s{2,}"), ' ').trim();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: (activities.length) + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(_cleanInline(title),
                    style: GoogleFonts.raleway(
                        color: FlowColors.textLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _cleanInline(summary),
                  style: GoogleFonts.raleway(
                    color: FlowColors.textGrey,
                    fontWeight: FontWeight.w600,
                    height: 1.45, // avoid fractional line rounding overflows
                  ),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          );
        }
        final i = idx - 1;
        return _TimelineTileCard(
          activity: activities[i],
          isFirst: i == 0,
          isLast: i == activities.length - 1,
        );
      },
    );
  }
}

class _TimelineTileCard extends StatelessWidget {
  const _TimelineTileCard(
      {required this.activity, required this.isFirst, required this.isLast});
  final Map<String, dynamic> activity;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tod = (activity['timeOfDay'] ?? '').toString();
    String _cleanInline(String s) {
      if (s.isEmpty) return s;
      final noBreaks = s.replaceAll(RegExp(r"[\r\n]+"), ' ');
      return noBreaks.replaceAll(RegExp(r"\s{2,}"), ' ').trim();
    }

    final title = _cleanInline((activity['title'] ?? '').toString());
    final location = _cleanInline((activity['location'] ?? '').toString());
    final notes = _cleanInline((activity['notes'] ?? '').toString());
    final cost = (activity['cost'] ?? '').toString();

    return TimelineTile(
      isFirst: isFirst,
      isLast: isLast,
      alignment: TimelineAlign.manual,
      lineXY: 0.08,
      beforeLineStyle: LineStyle(
        color: Colors.white.withValues(alpha: 0.14),
        thickness: 2,
      ),
      afterLineStyle: LineStyle(
        color: Colors.white.withValues(alpha: 0.14),
        thickness: 2,
      ),
      indicatorStyle: IndicatorStyle(
        width: 12,
        height: 12,
        indicator: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: FlowColors.softTealLight,
          ),
        ),
      ),
      endChild: Container(
        margin: const EdgeInsets.only(left: 12, bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlowColors.cardSurfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: FlowColors.cardBorderDark.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForTimeOfDay(tod),
                    color: FlowColors.textLight, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.raleway(
                        color: FlowColors.textLight,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                if (cost.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FlowColors.chipBgDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: FlowColors.chipBorderDark
                              .withValues(alpha: 0.14)),
                    ),
                    child: Text(cost,
                        style: GoogleFonts.raleway(
                            color: FlowColors.textGrey,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
              ],
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 16, color: FlowColors.textGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: GoogleFonts.raleway(
                        color: FlowColors.textGrey,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: GoogleFonts.raleway(
                  color: FlowColors.textLight,
                  fontWeight: FontWeight.w600,
                  height: 1.45, // reduce 1px overflow in some fonts/dpis
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForTimeOfDay(String tod) {
    switch (tod.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'morning':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.lunch_dining;
      case 'afternoon':
        return Icons.wb_twilight;
      case 'dinner':
        return Icons.dinner_dining;
      case 'evening':
        return Icons.nights_stay_outlined;
      default:
        return Icons.schedule;
    }
  }
}

class _DayPillTabs extends StatefulWidget {
  const _DayPillTabs(
      {required this.labels,
      required this.index,
      this.progress,
      required this.onChanged});
  final List<String> labels;
  final int index;
  final double? progress; // continuous progress from TabController.animation
  final ValueChanged<int> onChanged;

  @override
  State<_DayPillTabs> createState() => _DayPillTabsState();
}

class _TwoLineTitle extends StatelessWidget {
  const _TwoLineTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: FlowColors.textLight,
            fontWeight: FontWeight.w700,
            fontSize: 18, // slightly smaller for more breathing room
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: FlowColors.textGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _DayPillTabsState extends State<_DayPillTabs> {
  final _scroll = ScrollController();
  static const double _height = 44;
  static const double _pillPadding = 4;
  static const double _tileWidth = 92; // fixed per-segment width

  @override
  void didUpdateWidget(covariant _DayPillTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      // Ensure selected tab is visible
      final target = widget.index * _tileWidth;
      _scroll.animateTo(
        target.clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = widget.labels.length * _tileWidth;

    final effectiveLeft =
        (widget.progress ?? widget.index.toDouble()) * _tileWidth +
            _pillPadding;
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: totalWidth,
        height: _height,
        child: Stack(
          children: [
            // Sliding selected pill
            Positioned(
              top: _pillPadding,
              bottom: _pillPadding,
              left: effectiveLeft,
              width: _tileWidth - (_pillPadding * 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular((_height - _pillPadding * 2) / 2),
                  color: FlowColors.cardSurfaceDark,
                ),
              ),
            ),

            // Labels row
            Row(
              children: List.generate(widget.labels.length, (i) {
                final isSelected = (widget.progress == null)
                    ? i == widget.index
                    : (widget.progress!.round() == i);
                return SizedBox(
                  width: _tileWidth,
                  height: _height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onChanged(i),
                    child: Center(
                      child: Text(
                        widget.labels[i],
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: GoogleFonts.raleway(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w700,
                          fontSize: 15,
                          shadows: isSelected
                              ? [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    offset: const Offset(0, 2),
                                    blurRadius: 3,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
