// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:wanderwell/firebase_options.dart';
import 'package:wanderwell/theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/bloc/auth_cubit.dart';
import 'package:wanderwell/widgets/app_viewport.dart';
import 'package:wanderwell/screens/splash_screen.dart';
import 'package:wanderwell/screens/home_screen.dart';
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
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/destination_service.dart';
import 'package:wanderwell/services/feature_service.dart';
import 'package:wanderwell/services/weather_service.dart';
import 'package:wanderwell/models/destination.dart';
import 'package:wanderwell/screens/destination_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[Main] Widgets binding initialized');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[Main] Firebase initialized');

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
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark, // Force dark mode for the travel theme
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
          '/itinerary': (context) => const ItineraryBuilderScreen(),
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
          '/quest': (context) => const QuestScreen(),
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

          // Support dynamic destination detail URLs like '/dest/<id>'
          if (name.startsWith('/dest/')) {
            final id = name.substring('/dest/'.length);
            return MaterialPageRoute(
              settings: RouteSettings(name: name, arguments: settings.arguments),
              builder: (_) {
                // If the caller already passed a Destination as arguments, use it.
                final args = settings.arguments;
                if (args is Map && args['destination'] != null) {
                  final dest = args['destination'];
                  if (dest is Destination) {
                    return DestinationDetailScreen(destination: dest);
                  }
                }
                // Otherwise fetch by ID (supports deep links and reloads on web).
                return _DestinationDetailRouteLoader(id: id);
              },
            );
          }
          return null;
        },
      ),
    );
  }
}

/// Loader page that fetches a Destination by id and then shows the detail screen.
class _DestinationDetailRouteLoader extends StatelessWidget {
  final String id;
  const _DestinationDetailRouteLoader({required this.id});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Destination?>(
      future: DestinationService().getDestinationById(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        final dest = snapshot.data;
        if (dest == null) {
          // Simple not-found page; you can polish this later
          return Scaffold(
            backgroundColor: FlowColors.primaryDark,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, color: Colors.white70),
                  const SizedBox(height: 12),
                  const Text('Destination not found', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          );
        }
        return DestinationDetailScreen(destination: dest);
      },
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

  @override
  void initState() {
    super.initState();
    // Initialize auth bootstrapping once.
    AuthService().initialize().whenComplete(() {
      if (mounted) setState(() => _authInitDone = true);
    });
    // Load onboarding flag
    _loadOnboarding();
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
    // While prerequisites are loading, show the Splash visual without pushing routes.
    if (!(_authInitDone && _prefsLoaded)) {
      return const SplashScreen();
    }

    // Listen to auth changes so the root swaps between Welcome and Home reactively.
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final loggedIn = snapshot.data != null || AuthService().isLoggedIn;

        // Show onboarding only for users who are not logged in and haven't completed it.
        if (!loggedIn && !_onboardingDone) {
          return OnboardingScreen(onFinished: _completeOnboarding);
        }

        return loggedIn ? const HomeScreen() : const WelcomeScreen();
      },
    );
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
