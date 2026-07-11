import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/services/wonder_service.dart';
import 'package:wanderwell/theme.dart';

class RelatedWonders extends StatefulWidget {
  final Wonder currentWonder;
  const RelatedWonders({super.key, required this.currentWonder});

  @override
  State<RelatedWonders> createState() => _RelatedWondersState();
}

class _RelatedWondersState extends State<RelatedWonders> {
  List<Wonder>? _related;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await WonderService().getRelatedWonders(widget.currentWonder);
    if (mounted) setState(() => _related = results);
  }

  @override
  Widget build(BuildContext context) {
    if (_related == null) return const SizedBox.shrink();
    if (_related!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Related Wonders',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22,
                  color: AweColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              itemCount: _related!.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final w = _related![index];
                return _RelatedWonderCard(
                  wonder: w,
                  onTap: () => Navigator.of(context).pushNamed('/wonder/daily/${w.id}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedWonderCard extends StatelessWidget {
  final Wonder wonder;
  final VoidCallback onTap;
  const _RelatedWonderCard({required this.wonder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = WonderCategory.fromString(wonder.category);
    final hasImage = wonder.imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 158,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 116,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: hasImage
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cat.color.withValues(alpha: 0.35),
                          cat.color.withValues(alpha: 0.9),
                        ],
                      ),
                image: hasImage
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(wonder.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '◆ ${cat.label.toUpperCase()} · ${wonder.place.country.toUpperCase()}',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 9.5,
                letterSpacing: 1.0,
                color: cat.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
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
          ],
        ),
      ),
    );
  }
}
