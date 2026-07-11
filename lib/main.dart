import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wanderwell/firebase_options.dart';
import 'package:wanderwell/theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/bloc/auth_cubit.dart';
import 'package:wanderwell/widgets/app_viewport.dart';
import 'package:wanderwell/screens/splash_screen.dart';
import 'package:wanderwell/widgets/bottom_nav_shell.dart';
import 'package:wanderwell/screens/welcome_screen.dart';
import 'package:wanderwell/screens/onboarding_screen.dart';
import 'package:wanderwell/screens/itinerary_builder_screen.dart';
import 'package:wanderwell/screens/loading_screen.dart';
import 'package:wanderwell/screens/itinerary_result_screen.dart';
import 'package:wanderwell/screens/quest_screen.dart';
import 'package:wanderwell/screens/profile_screen.dart';
import 'package:wanderwell/screens/saved_itineraries_screen.dart';
import 'package:wanderwell/screens/privacy_policy_screen.dart';
import 'package:wanderwell/screens/terms_and_conditions_screen.dart';
import 'package:wanderwell/screens/settings_screen.dart';
import 'package:wanderwell/screens/wonder_archive_screen.dart';
import 'package:wanderwell/screens/paywall_screen.dart';
import 'package:wanderwell/services/premium_service.dart';
import 'package:wanderwell/screens/past_wonders_screen.dart';
import 'package:wanderwell/screens/collection_detail_screen.dart';
import 'package:wanderwell/screens/wonder_reader_screen.dart';
import 'package:wanderwell/screens/journey_list_screen.dart';
import 'package:wanderwell/screens/journey_detail_screen.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[Main] Widgets binding initialized');
  await dotenv.load(fileName: '.env');
  print('[Main] Dotenv loaded');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[Main] Firebase initialized');
  await PremiumService().initialize();
  print('[Main] PremiumService initialized');
  await NotificationService().initialize();
  print('[Main] NotificationService initialized');

  runApp(const FlowApp());
  print('[Main] runApp called');
}

class FlowApp extends StatelessWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: MaterialApp(
        title: 'Awe – Let the world surprise you',
        debugShowCheckedModeBanner: false,
        theme: aweTheme,
        themeMode: ThemeMode.light,
        // Wrap every screen in a centered, mobile-width viewport for desktop/tablet
        builder: (context, child) => AppViewport(child: child),
        // Use named routes so Flutter Web updates the URL and browser history.
        routes: {
          // Keep URL root ('/') as the Home entry. RootDecider chooses Home or Welcome without redirects.
          '/': (context) => const _RootDecider(),
          '/welcome': (context) => const WelcomeScreen(),
          '/splash': (context) => const SplashScreen(),
          // Legacy: redirect old bookmarks '/home' -> '/'
          '/home': (context) => const _LegacyHomeRedirect(),
          '/wonder/archive': (context) => const WonderArchiveScreen(),
          '/paywall': (context) => const PaywallScreen(),
          '/wonder/past': (context) => const PastWondersScreen(),
          '/journeys': (context) => const JourneyListScreen(),
          '/itinerary': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            String? initialDest;
            if (args is Map) {
              initialDest = args['destination'] as String?;
            }
            return ItineraryBuilderScreen(initialDestination: initialDest);
          },
          '/loading': (context) {
            final args = ModalRoute.of(context)!.settings.arguments;
            Future<Map<String, dynamic>>? task;
            Stream<String>? progress;
            String? initial;
            if (args is Map) {
              final m = Map<String, dynamic>.from(args as Map);
              final t = m['generateTask'];
              if (t is Future<Map<String, dynamic>>) task = t;
              final p = m['progressStream'];
              if (p is Stream<String>) progress = p;
              final i = m['initialProgressText'];
              if (i is String) initial = i;
            }
            return LoadingScreen(
              generateTask: task,
              progressStream: progress,
              initialProgressText: initial,
            );
          },
          '/itinerary_result': (context) {
            final args = ModalRoute.of(context)!.settings.arguments;
            final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
            return ItineraryResultScreen(data: map);
          },
          // '/quest': (context) => const QuestScreen(), // Quest feature temporarily disabled
          '/profile': (context) => const ProfileScreen(),
          '/saved_itineraries': (context) => const SavedItinerariesScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/terms': (context) => const TermsAndConditionsScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/onboarding': (context) => OnboardingScreen(
                onFinished: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false),
              ),
        },
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';

          if (name.startsWith('/journeys/')) {
            final id = name.substring('/journeys/'.length);
            return MaterialPageRoute(
              settings: RouteSettings(name: name),
              builder: (_) => JourneyDetailScreen(journeyId: id),
            );
          }

          if (name.startsWith('/collections/')) {
            final id = name.substring('/collections/'.length);
            return MaterialPageRoute(
              settings: RouteSettings(name: name),
              builder: (_) => CollectionDetailScreen(collectionId: id),
            );
          }

          if (name.startsWith('/wonder/read/')) {
            final id = name.substring('/wonder/read/'.length);
            return MaterialPageRoute(
              settings: RouteSettings(name: name),
              builder: (_) => WonderReaderScreen(wonderId: id, source: 'wonders'),
            );
          }

          if (name.startsWith('/wonder/daily/')) {
            final id = name.substring('/wonder/daily/'.length);
            return MaterialPageRoute(
              settings: RouteSettings(name: name),
              builder: (_) => WonderReaderScreen(wonderId: id, source: 'daily'),
            );
          }

          return null;
        },
      ),
    );
  }
}

/// Decides which root to render at '/' without changing the URL.
class _RootDecider extends StatefulWidget {
  const _RootDecider({super.key});

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  bool _authInitDone = false;
  bool _prefsLoaded = false;
  bool _onboardingDone = false;
  bool? _isLoggedIn;

  StreamSubscription<firebase_auth.User?>? _authSub;

  @override
  void initState() {
    super.initState();
    AuthService().initialize().whenComplete(() {
      if (mounted) setState(() => _authInitDone = true);
    });
    _loadOnboarding();

    // Use a subscription instead of StreamBuilder so the build method
    // only re-runs when auth state genuinely changes (login ↔ logout),
    // not on every stream re-emission during navigation transitions.
    _authSub = firebase_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      final loggedIn = user != null || AuthService().isLoggedIn;
      if (_isLoggedIn != loggedIn && mounted) {
        setState(() => _isLoggedIn = loggedIn);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_completed') ?? false;
    if (mounted) {
      setState(() {
        _prefsLoaded = true;
        _onboardingDone = done;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      setState(() => _onboardingDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(_authInitDone && _prefsLoaded)) {
      return const SplashScreen();
    }

    final loggedIn = _isLoggedIn ?? AuthService().isLoggedIn;

    if (!loggedIn && !_onboardingDone) {
      return OnboardingScreen(onFinished: _completeOnboarding);
    }

    return loggedIn ? const BottomNavShell() : const WelcomeScreen();
  }
}

/// One-time redirect for legacy '/home' bookmarks/links to '/'.
class _LegacyHomeRedirect extends StatelessWidget {
  const _LegacyHomeRedirect({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pushReplacementNamed('/');
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      }
    });
    // Render nothing while redirecting.
    return const SizedBox.shrink();
  }
}
