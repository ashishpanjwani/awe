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
        home: const SplashScreen(),
        routes: {
          '/itinerary': (context) => const ItineraryBuilderScreen(),
          '/loading': (context) => const LoadingScreen(),
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
        },
      ),
    );
  }
}
