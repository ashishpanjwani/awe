import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/bloc/wonder_map_cubit.dart';
import 'package:wanderwell/data/wonder_categories.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/theme.dart';

class WonderMapScreen extends StatefulWidget {
  const WonderMapScreen({super.key});

  @override
  State<WonderMapScreen> createState() => WonderMapScreenState();
}

class WonderMapScreenState extends State<WonderMapScreen> {
  final _cubit = WonderMapCubit()..loadViewedWonders();

  void refresh() => _cubit.loadViewedWonders();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: const _GlobeMapView(),
    );
  }
}

class _GlobeMapView extends StatefulWidget {
  const _GlobeMapView();

  @override
  State<_GlobeMapView> createState() => _GlobeMapViewState();
}

class _GlobeMapViewState extends State<_GlobeMapView>
    with SingleTickerProviderStateMixin {
  late FlutterEarthGlobeController _globeController;
  Wonder? _selectedWonder;
  bool _globeReady = false;

  @override
  void initState() {
    super.initState();
    _globeController = FlutterEarthGlobeController(
      rotationSpeed: 0.02,
      zoom: 0.6,
      isRotating: true,
      isBackgroundFollowingSphereRotation: false,
      surface: const AssetImage('assets/images/earth_blue_marble.jpg'),
      showAtmosphere: true,
      atmosphereColor: const Color(0xFFBFE0F0),
      atmosphereThickness: 0.06,
      atmosphereOpacity: 0.3,
      atmosphereBlur: 25,
    );

    _globeController.onLoaded = () {
      debugPrint('[GlobeMap] Globe loaded!');
      if (mounted) {
        setState(() => _globeReady = true);
        // Try loading points after globe is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final cubitState = context.read<WonderMapCubit>().state;
          if (cubitState is WonderMapLoaded && cubitState.wonders.isNotEmpty) {
            _loadPoints(cubitState.wonders);
          }
        });
      }
    };
    debugPrint('[GlobeMap] Controller initialized, surface loading...');
  }

  void _loadPoints(List<Wonder> wonders) {
    debugPrint('[GlobeMap] Loading ${wonders.length} wonders as pins');
    _globeController.points.clear();
    for (final wonder in wonders) {
      debugPrint('[GlobeMap]   "${wonder.title}" lat=${wonder.place.lat} lon=${wonder.place.lon}');
      if (wonder.place.lat == 0 && wonder.place.lon == 0) {
        debugPrint('[GlobeMap]   SKIPPED (0,0 coordinates)');
        continue;
      }
      final category = WonderCategory.fromString(wonder.category);
      _globeController.addPoint(
        Point(
          id: wonder.id,
          coordinates: GlobeCoordinates(wonder.place.lat, wonder.place.lon),
          isLabelVisible: false,
          style: PointStyle(
            size: 4,
            color: category.color,
          ),
          onTap: () {
            setState(() => _selectedWonder = wonder);
            _globeController.focusOnCoordinates(
              GlobeCoordinates(wonder.place.lat, wonder.place.lon),
              animate: true,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WonderMapCubit, WonderMapState>(
      listener: (context, state) {
        if (state is WonderMapLoaded && _globeReady) {
          _loadPoints(state.wonders);
        }
      },
      builder: (context, state) {
        final wonders = state is WonderMapLoaded ? state.wonders : <Wonder>[];
        final wondersCount = state is WonderMapLoaded
            ? state.userState.engagedWonderIds.length
            : 0;
        final countriesCount = state is WonderMapLoaded
            ? state.userState.countriesDiscovered.length
            : 0;

        if (state is WonderMapLoaded && _globeReady && _globeController.points.isEmpty && wonders.isNotEmpty) {
          _loadPoints(wonders);
        }

        return Scaffold(
          backgroundColor: const Color(0xFF091B26),
          body: Stack(
            children: [
              // Starfield background
              const _StarField(),
              // Globe
              Positioned.fill(
                child: FlutterEarthGlobe(
                  radius: MediaQuery.of(context).size.width * 0.42,
                  controller: _globeController,
                  alignment: Alignment.center,
                  onTap: (_) {
                    if (_selectedWonder != null) {
                      setState(() => _selectedWonder = null);
                    }
                  },
                ),
              ),
              // Title overlay (top-left)
              Positioned(
                top: MediaQuery.of(context).padding.top + 14,
                left: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR ATLAS',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 11,
                        letterSpacing: 1.8,
                        color: const Color(0xFF9FC4D8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Where you\'ve\nwandered',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 27,
                        height: 1.06,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Stats badges (top-right)
              Positioned(
                top: MediaQuery.of(context).padding.top + 34,
                right: 18,
                child: Column(
                  children: [
                    _StatBadge(value: '$countriesCount', label: 'COUNTRIES'),
                    const SizedBox(height: 9),
                    _StatBadge(value: '$wondersCount', label: 'WONDERS'),
                  ],
                ),
              ),
              // Bottom panel: legend + hint
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF091B26).withValues(alpha: 0.0),
                        const Color(0xFF091B26).withValues(alpha: 0.85),
                        const Color(0xFF091B26),
                      ],
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_globeReady)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'SPINNING UP THE GLOBE…',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 11,
                                letterSpacing: 1.6,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        if (_globeReady && _selectedWonder == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              wonders.isEmpty
                                  ? 'LIKE A WONDER TO PIN IT TO YOUR ATLAS'
                                  : 'DRAG TO SPIN · TAP A PIN',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 10,
                                letterSpacing: 1.4,
                                color: Colors.white.withValues(alpha: 0.42),
                              ),
                            ),
                          ),
                        _CategoryLegend(),
                      ],
                    ),
                  ),
                ),
              ),
              // Selected wonder info card
              if (_selectedWonder != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 84,
                  child: _WonderInfoCard(
                    wonder: _selectedWonder!,
                    onClose: () => setState(() => _selectedWonder = null),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _StarPainter(),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final rng = Random(42);
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = rng.nextDouble() * 1.2 + 0.3;
      paint.color = Colors.white.withValues(alpha: rng.nextDouble() * 0.5 + 0.15);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  const _StatBadge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 22,
              height: 1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 8.5,
              letterSpacing: 0.9,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  static const _items = [
    ('Place', Color(0xFF54A8D6)),
    ('Tradition', Color(0xFFE0805E)),
    ('Taste', Color(0xFFE2B04A)),
    ('Story', Color(0xFFA48FC4)),
    ('Sound', Color(0xFF8FB084)),
    ('Person', Color(0xFFD96A5E)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1E28).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORIES',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 8.5,
              letterSpacing: 1.4,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 16,
            runSpacing: 7,
            children: _items.map((item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.$1,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WonderInfoCard extends StatelessWidget {
  final Wonder wonder;
  final VoidCallback onClose;
  const _WonderInfoCard({required this.wonder, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final category = WonderCategory.fromString(wonder.category);

    final hasImage = wonder.imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/wonder/daily/${wonder.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: hasImage
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          category.color.withValues(alpha: 0.35),
                          category.color,
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '◆ ${category.label.toUpperCase()} · ${wonder.place.country.toUpperCase()}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 9.5,
                      letterSpacing: 1.0,
                      color: category.color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    wonder.title,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 19,
                      height: 1.12,
                      color: AweColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Read this wonder →',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AweColors.accentSlate,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '×',
                  style: TextStyle(
                    fontSize: 22,
                    color: AweColors.navInactive,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
