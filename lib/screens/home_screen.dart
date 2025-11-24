import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/weather_service.dart';
import 'package:wanderwell/services/destination_service.dart';
import 'package:wanderwell/services/feature_service.dart';
import 'package:wanderwell/models/weather_data.dart';
import 'package:wanderwell/models/destination.dart';
import 'package:wanderwell/models/feature_card.dart';
import 'package:wanderwell/widgets/weather_card.dart';
import 'package:wanderwell/widgets/feature_grid.dart';
import 'package:wanderwell/widgets/destination_card.dart';
import 'package:wanderwell/widgets/vintage_ticket.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/services/location_service.dart';
import 'package:wanderwell/services/daily_fact_service.dart';
import 'package:wanderwell/services/daily_world_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  WeatherData? _weather;
  List<Destination> _destinations = [];
  List<Destination> _worldCards = [];
  List<FeatureCard> _features = [];
  bool _isLoading = true;
  bool _locationOff = false;
  String? _dailyFact;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Ensure animations run so content wrapped in Fade/Slide is visible
    // If we don't start these, opacity stays at 0 and the screen looks invisible.
    _fadeController.forward();
    _slideController.forward();
    _loadData();
    _loadDailyFact();
    _loadWorldCards();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadDailyFact() async {
    try {
      final text = await DailyFactService().getTodayFact();
      if (!mounted) return;
      setState(() {
        _dailyFact = text;
      });
      debugPrint('[Home] Daily fact loaded: ${text.length} chars');
    } catch (e, st) {
      debugPrint('[Home] Failed to load daily fact: $e');
      debugPrint('$st');
    }
  }

  Future<void> _loadWorldCards() async {
    try {
      final items = await DailyWorldService().getTodayWorldDestinations();
      if (!mounted) return;
      setState(() {
        _worldCards = items;
      });
      debugPrint('[Home] World cards loaded: ${items.length}');
    } catch (e, st) {
      debugPrint('[Home] Failed to load world cards: $e');
      debugPrint('$st');
    }
  }

  Future<void> _loadData() async {
    // Always load Features first (local, non-failing) so the grid is visible
    try {
      final localFeatures = await FeatureService().getFeatures();
      if (mounted) {
        setState(() {
          _features = localFeatures;
        });
      }
      debugPrint('[Home] Loaded features: ${localFeatures.length}');
    } catch (e, st) {
      debugPrint('[Home] Failed to load features: $e');
      debugPrint('$st');
    }

    // Ask for location and then load Weather and Destinations.
    try {
      // Load location (requests permission if needed). Do NOT fall back to IP.
      final location = await LocationService().getCurrentLocationWithName(allowIpFallback: false);

      WeatherData? weather;
      if (location != null) {
        _locationOff = false;
        weather = await WeatherService().fetchWeatherAt(
          location.lat,
          location.lon,
          cityName: location.name,
        );
      } else {
        // If user denied or service off, don't fabricate weather.
        _locationOff = true;
        weather = WeatherData(
          city: 'Location Off',
          temperature: 0,
          condition: '',
          iconCode: '',
          updatedAt: DateTime.now(),
          isDay: true,
        );
      }

      final destinations = await DestinationService().getPopularDestinations();

      if (mounted) {
        setState(() {
          _weather = weather;
          _destinations = destinations;
          _isLoading = false;
        });
      }
      debugPrint('[Home] Weather loaded for: ${_weather?.city}');
      debugPrint('[Home] Destinations loaded: ${_destinations.length}');
    } catch (e, st) {
      // If one fails, still end loading state so at least Features show
      debugPrint('[Home] One or more data loads failed: $e');
      debugPrint('$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enableLocation() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final location = await LocationService().getCurrentLocationWithName(allowIpFallback: false);
      WeatherData weather;
      if (location != null) {
        weather = await WeatherService().fetchWeatherAt(
          location.lat,
          location.lon,
          cityName: location.name,
        );
        _locationOff = false;
      } else {
        // Do not fetch fallback weather when location is off.
        weather = WeatherData(
          city: 'Location Off',
          temperature: 0,
          condition: '',
          iconCode: '',
          updatedAt: DateTime.now(),
          isDay: true,
        );
        _locationOff = true;
      }
      final destinations = await DestinationService().getPopularDestinations();
      if (mounted) {
        setState(() {
          _weather = weather;
          _destinations = destinations;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[Home] Enable location flow failed: $e');
      debugPrint('$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      WeatherService().refreshWeather(),
    ]);
    _loadData();
    _loadWorldCards();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(FlowColors.softTealLight),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: FlowColors.softTealLight,
              backgroundColor: FlowColors.primaryDarkVariant,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SafeArea(
                  // Temporarily bypass entrance animations to ensure content is visible
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header section with greeting
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    AuthService().getGreeting(),
                                    style: GoogleFonts.raleway(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: FlowColors.textLight,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                // Profile button / Avatar
                                GestureDetector(
                                  onTap: () {
                                    try {
                                      Navigator.of(context)
                                          .pushNamed('/profile');
                                    } catch (e) {
                                      debugPrint(
                                          '[Home] Failed to open profile: $e');
                                    }
                                  },
                                  child: _UserAvatar(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_weather != null)
                              WeatherCard(
                                weather: _weather!,
                                showEnableLocation: _locationOff,
                                onEnableLocation: _enableLocation,
                              ),
                          ],
                        ),
                      ),

                      // Feature grid section
                      if (_features.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FeatureGrid(features: _features),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Daily content: Vintage ticket fact + World Says Hi
                      if (_dailyFact != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: VintageTicket(fact: _dailyFact!),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_worldCards.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'The World Says Hi',
                            style: GoogleFonts.raleway(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: FlowColors.textLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DestinationMasonryGrid(destinations: _worldCards),
                        const SizedBox(height: 32),

                        // Promotional image with overlayed text (full-bleed, no side/bottom padding)
                        Stack(
                          children: [
                            SizedBox(
                              //height: 220,
                              width: double.infinity,
                              child: Image.asset(
                                'assets/images/Whimsical_Travel_Landscape2.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: FlowColors.cardGradientStartDark,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: FlowColors.textLight
                                          .withValues(alpha: 0.6),
                                      size: 28,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 60,
                              left: 20,
                              child: Text(
                                'Find places that\nfeel like you',
                                textAlign: TextAlign.left,
                                style: GoogleFonts.raleway(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  color: FlowColors.promoTextPaleBlue,
                                  shadows: [
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.4),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final photoUrl = user?.photoUrl;
    if (photoUrl != null && photoUrl.startsWith('http')) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FlowColors.cardBorderDark.withValues(alpha: 0.25), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: FlowColors.cardGradientStartDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        Icons.person,
        color: FlowColors.textLight,
        size: 24,
      ),
    );
  }
}
