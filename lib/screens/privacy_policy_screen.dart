import 'package:flutter/material.dart';
import 'package:wanderwell/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      appBar: AppBar(
        //backgroundColor: FlowColors.primaryDark,
        elevation: 0,
        title: Text(
          'Privacy Policy',
          style: theme.textTheme.titleLarge?.copyWith(
            color: FlowColors.textLight,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium?.copyWith(
                color: FlowColors.textGrey,
                height: 1.55,
              ) ??
              const TextStyle(color: Colors.white70, height: 1.55),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _h(context, 'Overview'),
              const SizedBox(height: 8),
              const Text(
                'We built this app to help you discover delightful travel moments. We care about your privacy. This policy explains what we collect, why, and how you can control it.',
              ),
              const SizedBox(height: 20),

              _h(context, 'What we collect'),
              const SizedBox(height: 8),
              const Text('Account (via Google Sign‑In + Firebase Auth): name, email, and optional profile photo. We store a simple user profile in Firestore to personalize your experience.'),
              const SizedBox(height: 8),
              const Text('Usage data you choose to create: saved itineraries, daily quest progress, and timestamps. These are stored in your user’s Firestore collections to sync across devices.'),
              const SizedBox(height: 8),
              const Text('Approximate location (with permission): used on‑device to personalize quests and weather. We do not persist precise latitude/longitude to Firestore in normal operation.'),
              const SizedBox(height: 8),
              const Text('Daily shared content: “Daily Fact” and “The World Says Hi” selections are stored globally in Firestore by UTC day and are not tied to your identity.'),
              const SizedBox(height: 20),

              _h(context, 'How we use data'),
              const SizedBox(height: 8),
              const Text('• Authenticate you and keep you signed in.'),
              const Text('• Sync and display saved itineraries and daily progress.'),
              const Text('• Personalize quests and show local weather when you grant location permission.'),
              const Text('• Improve reliability (basic error logs in Debug Console; no analytics SDKs).'),
              const SizedBox(height: 20),

              _h(context, 'Permissions & why'),
              const SizedBox(height: 8),
              const Text('Location: to personalize quests and fetch nearby weather. You can deny or revoke this at any time; core features still work.'),
              const SizedBox(height: 20),

              _h(context, 'Third‑party services'),
              const SizedBox(height: 8),
              const Text('Firebase (Auth & Firestore): secure sign‑in and cloud storage. Data is encrypted in transit and at rest by Firebase.'),
              const Text('Google Sign‑In: used for authentication to obtain your basic profile (name, email, photo).'),
              const Text('Open‑Meteo: provides public weather data using your approximate coordinates when available.'),
              const Text('Photon (Komoot): provides public place autocomplete suggestions for destination search.'),
              const Text('Wikipedia Commons image URLs: used to display public images for world entries.'),
              const SizedBox(height: 20),

              _h(context, 'Storage & retention'),
              const SizedBox(height: 8),
              const Text('Your itineraries and daily progress are stored under your user in Firestore. You can delete items individually in the app. When you delete your account, we delete your Firebase Auth user and attempt to remove your user profile document. Some related documents may remain temporarily (e.g., subcollections) until full cleanup is completed.'),
              const SizedBox(height: 20),

              _h(context, 'Your choices'),
              const SizedBox(height: 8),
              const Text('• Sign out anytime from Profile.'),
              const Text('• Delete Account from Profile to remove your user profile (and we will attempt to remove associated data).'),
              const Text('• Revoke location permission in your device/browser settings.'),
              const SizedBox(height: 20),

              _h(context, 'Children'),
              const SizedBox(height: 8),
              const Text('This app is not directed to children under 13. If we discover child data without verifiable parental consent, we will delete it.'),
              const SizedBox(height: 20),

              _h(context, 'Changes'),
              const SizedBox(height: 8),
              const Text('We may update this policy as we add features. We will post updates in the app.'),
              const SizedBox(height: 20),

              _h(context, 'Contact'),
              const SizedBox(height: 8),
              const Text('Questions or data requests? Use the “Submit Feedback” option in the app, or contact the developer of this app build.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _h(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        color: FlowColors.textLight,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
