import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:wanderwell/models/destination.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/screens/destination_detail_screen.dart';
import 'package:wanderwell/widgets/animated_button.dart';

class DestinationCard extends StatelessWidget {
  final Destination destination;

  const DestinationCard({
    super.key,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      onTap: () {
        try {
          Navigator.of(context).pushNamed(
            '/dest/${destination.id}',
            arguments: {'destination': destination},
          );
        } catch (e) {
          // ignore: avoid_print
          print('Failed to open destination detail: $e');
        }
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: FlowColors.cardGradientStartDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image container
            Container(
              height: 108,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                color: FlowColors.textGrey.withValues(alpha: 0.2),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Hero(
                  tag: 'dest-image-${destination.id}',
                  child: destination.imageUrl.startsWith('http')
                      ? Image.network(
                          destination.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: FlowColors.textGrey.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.landscape,
                                size: 32,
                                color: FlowColors.textGrey,
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          destination.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: FlowColors.textGrey.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.landscape,
                                size: 32,
                                color: FlowColors.textGrey,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: GoogleFonts.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: FlowColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.country,
                    style: GoogleFonts.raleway(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: FlowColors.textLight.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DestinationScrollList extends StatelessWidget {
  final List<Destination> destinations;

  const DestinationScrollList({
    super.key,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: destinations.length,
        itemBuilder: (context, index) {
          return DestinationCard(destination: destinations[index]);
        },
      ),
    );
  }
}

/// Masonry grid variant used on Home for "The World Says Hi".
class DestinationMasonryGrid extends StatelessWidget {
  final List<Destination> destinations;
  final int maxItems;

  const DestinationMasonryGrid({super.key, required this.destinations, this.maxItems = 6});

  @override
  Widget build(BuildContext context) {
    final items = destinations.take(maxItems).toList();
    // Non-scrollable masonry grid to show a compact overview
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final d = items[index];
          // Create a gentle stagger by varying the image height
          final imageH = 110.0 + (index % 3) * 24.0; // 110, 134, 158
          return _DestinationMasonryTile(destination: d, imageHeight: imageH);
        },
      ),
    );
  }
}

class _DestinationMasonryTile extends StatelessWidget {
  final Destination destination;
  final double imageHeight;
  const _DestinationMasonryTile({required this.destination, required this.imageHeight});

  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      onTap: () {
        try {
          Navigator.of(context).pushNamed(
            '/dest/${destination.id}',
            arguments: {'destination': destination},
          );
        } catch (e) {
          // ignore: avoid_print
          print('Failed to open destination detail: $e');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: FlowColors.cardGradientStartDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: imageHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                color: FlowColors.textGrey.withValues(alpha: 0.2),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Hero(
                  tag: 'dest-image-${destination.id}',
                  child: destination.imageUrl.startsWith('http')
                      ? Image.network(
                          destination.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: FlowColors.textGrey.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.landscape,
                                size: 32,
                                color: FlowColors.textGrey,
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          destination.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: FlowColors.textGrey.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.landscape,
                                size: 32,
                                color: FlowColors.textGrey,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            // Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: GoogleFonts.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FlowColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.country,
                    style: GoogleFonts.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FlowColors.textLight.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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