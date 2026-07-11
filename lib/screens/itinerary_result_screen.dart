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
  bool _isSaved = false;
  String? _savedId;
  bool _openedFromSaved = false;

  @override
  void initState() {
    super.initState();
    _days = (widget.data['days'] as List?) ?? [];
    _destination = widget.data['destination'] as String? ?? 'Your Trip';
    final s = widget.data['startDate']?.toString();
    final e = widget.data['endDate']?.toString();
    _startDate = s != null ? DateTime.tryParse(s) : null;
    _endDate = e != null ? DateTime.tryParse(e) : null;
    final metaSavedId = widget.data['__savedId']?.toString();
    if (metaSavedId != null && metaSavedId.isNotEmpty) {
      _openedFromSaved = true;
      _isSaved = true;
      _savedId = metaSavedId;
    }
    if (_days.isNotEmpty) {
      _tabController = TabController(length: _days.length.clamp(1, 30), vsync: this);
      _tabController!.animation?.addListener(() {
        setState(() => _tabAnimationValue = _tabController!.animation!.value);
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

    return Scaffold(
      backgroundColor: AweColors.background,
      appBar: AppBar(
        backgroundColor: AweColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: _TwoLineTitle(
          title: destination,
          subtitle: _formatDateRange(_startDate, _endDate),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AweColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        actions: [
          if (_openedFromSaved)
            IconButton(
              tooltip: 'Delete itinerary',
              icon: const Icon(Icons.delete_outline, color: AweColors.accentTerracotta),
              onPressed: () => _onDeletePressed(context),
            )
          else if ((widget.data['error'] as String?)?.isNotEmpty == true)
            const SizedBox.shrink()
          else
            IconButton(
              tooltip: _isSaved ? 'Unsave itinerary' : 'Save itinerary',
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                color: _isSaved ? AweColors.accentGold : AweColors.textPrimary,
              ),
              onPressed: () async {
                if (_isSaved) {
                  await _onUnsavePressed(context);
                } else {
                  await _onSavePressed(context);
                }
              },
            ),
        ],
        bottom: days.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                  child: _DayPillTabs(
                    labels: [for (int i = 0; i < days.length; i++) 'Day ${i + 1}'],
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
                    activities: (day['activities'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
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
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Save Itinerary',
            style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: AweColors.textPrimary),
          ),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: GoogleFonts.sourceSans3(color: AweColors.textPrimary),
            cursorColor: AweColors.accentTeal,
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: GoogleFonts.sourceSans3(color: AweColors.textSecondary),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AweColors.accentTeal),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.sourceSans3(color: AweColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: Text('Save', style: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600, color: AweColors.accentTeal)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary saved')));
      setState(() {
        _isSaved = true;
        _savedId = id;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  Future<void> _onUnsavePressed(BuildContext context) async {
    final user = AuthService().currentUser;
    if (user == null || _savedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need to be signed in.')));
      return;
    }
    try {
      await ItineraryRepository.instance.delete(uid: user.id, id: _savedId!);
      if (!mounted) return;
      setState(() {
        _isSaved = false;
        _savedId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from saved itineraries')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
    }
  }

  Future<void> _onDeletePressed(BuildContext context) async {
    final user = AuthService().currentUser;
    final id = _savedId;
    if (user == null || id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing itinerary id or user')));
      return;
    }
    await _showConfirmBottomSheet(
      context,
      title: 'Delete this itinerary?',
      message: 'This will permanently remove it from your saved itineraries. You can always generate a new one later.',
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                        style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: GoogleFonts.sourceSans3(fontSize: 15, height: 1.5, color: AweColors.textBody),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: AweColors.textPrimary,
                            side: const BorderSide(color: AweColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: running ? null : () => Navigator.of(ctx).pop(),
                          child: Text('Cancel', style: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                                        const SnackBar(content: Text('Something went wrong. Please try again.')),
                                      );
                                    }
                                    setModalState(() => running = false);
                                  }
                                },
                          child: running
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                )
                              : Text(confirmLabel, style: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Empty / Error view ────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.raw});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final hasError = (raw['error'] as String?)?.isNotEmpty == true;

    if (hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/minimal_travel_error_illustration_airplane_warning_sign_gray_1763394371352.png',
                width: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                "We couldn't generate your itinerary",
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'The service looks a bit busy right now. Please try again in a little while.',
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceSans3(fontSize: 15, color: AweColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

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
              style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Please go back and try generating again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(fontSize: 15, color: AweColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Day timeline ──────────────────────────────────────────────────────────

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
    String cleanInline(String s) {
      if (s.isEmpty) return s;
      final noBreaks = s.replaceAll(RegExp(r"[\r\n]+"), ' ');
      return noBreaks.replaceAll(RegExp(r"\s{2,}"), ' ').trim();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: activities.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(
                  cleanInline(title),
                  style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
                ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  cleanInline(summary),
                  style: GoogleFonts.sourceSans3(fontSize: 14, color: AweColors.textSecondary, height: 1.5),
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
  const _TimelineTileCard({required this.activity, required this.isFirst, required this.isLast});
  final Map<String, dynamic> activity;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tod = (activity['timeOfDay'] ?? '').toString();
    String cleanInline(String s) {
      if (s.isEmpty) return s;
      final noBreaks = s.replaceAll(RegExp(r"[\r\n]+"), ' ');
      return noBreaks.replaceAll(RegExp(r"\s{2,}"), ' ').trim();
    }

    final title = cleanInline((activity['title'] ?? '').toString());
    final location = cleanInline((activity['location'] ?? '').toString());
    final notes = cleanInline((activity['notes'] ?? '').toString());
    final cost = (activity['cost'] ?? '').toString();

    return TimelineTile(
      isFirst: isFirst,
      isLast: isLast,
      alignment: TimelineAlign.manual,
      lineXY: 0.08,
      beforeLineStyle: LineStyle(color: AweColors.divider, thickness: 2),
      afterLineStyle: LineStyle(color: AweColors.divider, thickness: 2),
      indicatorStyle: IndicatorStyle(
        width: 12,
        height: 12,
        indicator: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AweColors.accentTeal,
          ),
        ),
      ),
      endChild: Container(
        margin: const EdgeInsets.only(left: 12, bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AweColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForTimeOfDay(tod), color: AweColors.accentSlate, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.sourceSans3(
                      color: AweColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (cost.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AweColors.chipBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      cost,
                      style: GoogleFonts.ibmPlexMono(color: AweColors.textSecondary, fontSize: 11),
                    ),
                  ),
              ],
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: AweColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: GoogleFonts.sourceSans3(color: AweColors.textSecondary, fontSize: 13, height: 1.4),
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
                style: GoogleFonts.sourceSans3(color: AweColors.textBody, fontSize: 14, height: 1.5),
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

// ─── App bar title ─────────────────────────────────────────────────────────

class _TwoLineTitle extends StatelessWidget {
  const _TwoLineTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: GoogleFonts.ibmPlexMono(fontSize: 11, letterSpacing: 0.3, color: AweColors.textSecondary),
          ),
      ],
    );
  }
}

// ─── Day pill tabs ─────────────────────────────────────────────────────────

class _DayPillTabs extends StatefulWidget {
  const _DayPillTabs({required this.labels, required this.index, this.progress, required this.onChanged});
  final List<String> labels;
  final int index;
  final double? progress;
  final ValueChanged<int> onChanged;

  @override
  State<_DayPillTabs> createState() => _DayPillTabsState();
}

class _DayPillTabsState extends State<_DayPillTabs> {
  final _scroll = ScrollController();
  static const double _height = 44;
  static const double _pillPadding = 4;
  static const double _tileWidth = 92;

  @override
  void didUpdateWidget(covariant _DayPillTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
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
    final effectiveLeft = (widget.progress ?? widget.index.toDouble()) * _tileWidth + _pillPadding;

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: totalWidth,
        height: _height,
        child: Stack(
          children: [
            Positioned(
              top: _pillPadding,
              bottom: _pillPadding,
              left: effectiveLeft,
              width: _tileWidth - (_pillPadding * 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular((_height - _pillPadding * 2) / 2),
                  color: AweColors.accentSlate,
                ),
              ),
            ),
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
                        style: GoogleFonts.sourceSans3(
                          color: isSelected ? Colors.white : AweColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
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
