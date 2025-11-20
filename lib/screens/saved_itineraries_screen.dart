import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/models/itinerary.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/itinerary_repository.dart';
import 'package:wanderwell/theme.dart';

class SavedItinerariesScreen extends StatelessWidget {
  const SavedItinerariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      appBar: AppBar(
        backgroundColor: FlowColors.primaryDark,
        elevation: 0,
        title: const Text('Saved Itineraries', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? _NotSignedIn()
          : StreamBuilder<List<Itinerary>>(
              stream: ItineraryRepository.instance.streamForUser(user.id),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? const <Itinerary>[];
                if (items.isEmpty) {
                  return _EmptySaved();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return _ItineraryListTile(it: it);
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: items.length,
                );
              },
            ),
    );
  }
}

class _ItineraryListTile extends StatelessWidget {
  const _ItineraryListTile({required this.it});
  final Itinerary it;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Inject saved id into the payload so the result screen can show delete
        final payload = Map<String, dynamic>.from(it.data)
          ..['__savedId'] = it.id;
        Navigator.of(context).pushNamed('/itinerary_result', arguments: payload);
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: FlowColors.cardSurfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlowColors.cardBorderDark.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FlowColors.chipBgDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bookmark, color: Colors.white70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_titleText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.raleway(
                          color: FlowColors.textLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleText(),
                      style: GoogleFonts.raleway(
                        color: FlowColors.textGrey,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  String _isoToPretty(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _range(DateTime s, DateTime e) => '${_isoToPretty(s)} - ${_isoToPretty(e)}';

  int _days(DateTime s, DateTime e) => e.difference(s).inDays + 1;

  String _defaultName() => '${it.destination} (${_range(it.startDate, it.endDate)})';

  String _titleText() {
    // Prefer destination as concise title to avoid duplication with range-based names
    return it.destination.isNotEmpty ? it.destination : it.name;
  }

  String _subtitleText() {
    final range = _range(it.startDate, it.endDate);
    final days = _days(it.startDate, it.endDate);
    final base = '$range • ${days}d';
    final def = _defaultName();
    if (it.name.isEmpty || it.name == def || it.name == it.destination) {
      return base;
    }
    return '$base • ${it.name}';
  }
}

class _EmptySaved extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border, size: 64, color: Colors.white38),
            const SizedBox(height: 12),
            Text('No saved itineraries yet',
                style: GoogleFonts.raleway(
                    color: FlowColors.textLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 6),
            Text('Save your favorite plans to revisit them anytime.',
                textAlign: TextAlign.center,
                style: GoogleFonts.raleway(
                  color: FlowColors.textGrey,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

class _NotSignedIn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.white38),
            const SizedBox(height: 12),
            Text('Please sign in to view saved itineraries',
                textAlign: TextAlign.center,
                style: GoogleFonts.raleway(
                  color: FlowColors.textLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                )),
          ],
        ),
      ),
    );
  }
}
