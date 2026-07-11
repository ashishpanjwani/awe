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
      backgroundColor: AweColors.background,
      appBar: AppBar(
        backgroundColor: AweColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AweColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text(
          'Saved Itineraries',
          style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: AweColors.textPrimary),
        ),
      ),
      body: user == null
          ? const _NotSignedIn()
          : StreamBuilder<List<Itinerary>>(
              stream: ItineraryRepository.instance.streamForUser(user.id),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AweColors.accentTeal));
                }
                final items = snap.data ?? const <Itinerary>[];
                if (items.isEmpty) return const _EmptySaved();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  itemBuilder: (context, i) => _ItineraryListTile(it: items[i]),
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
    return GestureDetector(
      onTap: () {
        final payload = Map<String, dynamic>.from(it.data)..['__savedId'] = it.id;
        Navigator.of(context).pushNamed('/itinerary_result', arguments: payload);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECE3D4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3C2D14).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AweColors.accentGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bookmark, color: AweColors.accentGold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sourceSans3(
                      color: AweColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitleText(),
                    style: GoogleFonts.ibmPlexMono(
                      color: AweColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Text('>', style: TextStyle(fontSize: 21, color: const Color(0xFFCDC3B0))),
          ],
        ),
      ),
    );
  }

  String _isoToPretty(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _range(DateTime s, DateTime e) => '${_isoToPretty(s)} - ${_isoToPretty(e)}';

  int _days(DateTime s, DateTime e) => e.difference(s).inDays + 1;

  String _defaultName() => '${it.destination} (${_range(it.startDate, it.endDate)})';

  String _titleText() => it.destination.isNotEmpty ? it.destination : it.name;

  String _subtitleText() {
    final range = _range(it.startDate, it.endDate);
    final days = _days(it.startDate, it.endDate);
    final base = '$range · ${days}d';
    final def = _defaultName();
    if (it.name.isEmpty || it.name == def || it.name == it.destination) return base;
    return '$base · ${it.name}';
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: AweColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No saved itineraries yet',
              style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Save your favorite plans to revisit them anytime.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(fontSize: 15, color: AweColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: AweColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Please sign in to view saved itineraries',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
