import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderwell/theme.dart';

/// Drop-in Privacy Policy screen for Awe.
/// Effective date and contact inserted per user request.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _effectiveDate = 'November 24, 2025';
  static const _contactEmail = 'heya.awe@gmail.com';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      appBar: AppBar(
        backgroundColor: FlowColors.primaryDark,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: theme.textTheme.titleMedium?.copyWith(
            color: FlowColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Contact / Data request',
            icon: const Icon(Icons.email_outlined),
            onPressed: () => _contact(context),
          ),
        ],
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
              _h(context, 'Privacy Policy — Awe'),
              const SizedBox(height: 6),
              Text('Effective date: $_effectiveDate',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: FlowColors.textGrey)),
              const SizedBox(height: 12),

              _h(context, 'Overview'),
              const SizedBox(height: 8),
              const Text(
                'Awe (“we”, “us”, “our”) provides travel exploration features and AI-generated itineraries. This policy explains what data we collect, why we collect it, and how you can control your information.',
              ),
              const SizedBox(height: 20),

              _h(context, 'Data controller & contact'),
              const SizedBox(height: 8),
              Text(
                  'Data controller: Awe / the developer of this build. For questions or data requests: $_contactEmail'),
              const SizedBox(height: 20),

              _h(context, 'What we collect'),
              const SizedBox(height: 8),
              const Text(
                  '• Account information: When you sign in with Google Sign-In (Firebase Auth) we receive your name, email, and optional profile photo. We store a simple profile document in Firestore to personalise the app.'),
              const SizedBox(height: 8),
              const Text(
                  '• User-created content: saved itineraries, daily quest progress, timestamps, and other content you explicitly create or upload. These are stored under your user document in Firestore.'),
              const SizedBox(height: 8),
              const Text(
                  '• Approximate location (optional): With your permission we use approximate location on-device to personalise quests and show local weather. We do not persist precise GPS coordinates to Firestore in normal operation. If precise coordinates are stored we will request separate consent and explain the use.'),
              const SizedBox(height: 8),
              const Text(
                  '• Daily public content: Daily Fact and The World Says Hi selections are stored globally by UTC day and are not linked to your identity.'),
              const SizedBox(height: 8),
              const Text(
                  '• Diagnostics and logs: basic error logs and anonymized diagnostics to improve reliability. We do not include third-party analytics SDKs by default.'),
              const SizedBox(height: 20),

              _h(context, 'How we use data'),
              const SizedBox(height: 8),
              const Text('• Authenticate you and keep you signed in.'),
              const Text(
                  '• Sync and display saved itineraries and daily progress.'),
              const Text(
                  '• Personalize quests and show local weather when you grant location permission.'),
              const Text(
                  '• Diagnose and fix bugs; improve reliability with minimal, anonymized logs.'),
              const Text('• Comply with legal obligations.'),
              const SizedBox(height: 20),

              _h(context, 'Legal basis (EU/EEA users)'),
              const SizedBox(height: 8),
              const Text(
                  'Where applicable, our lawful bases for processing personal data include: performance of contract (account & sync), consent (optional location features), and legitimate interests (service improvement and security), balanced against your rights.'),
              const SizedBox(height: 20),

              _h(context, 'Third-party services & processors'),
              const SizedBox(height: 8),
              const Text(
                  'We rely on third-party services to operate the app, including but not limited to:'),
              const SizedBox(height: 6),
              const Text(
                  '• Firebase (Auth & Firestore) — authentication and cloud storage.'),
              const Text(
                  '• Google Sign-In — authentication and basic profile.'),
              const Text(
                  '• Open-Meteo — public weather data (uses approximate coordinates).'),
              const Text('• Photon (Komoot) — place autocomplete suggestions.'),
              const Text(
                  '• Wikimedia Commons — public image URLs for world entries.'),
              const SizedBox(height: 8),
              const Text(
                  'These processors have their own privacy practices and may store/process data in different countries. We rely on their security controls and contractual commitments.'),
              const SizedBox(height: 20),

              _h(context, 'Data storage & transfers'),
              const SizedBox(height: 8),
              const Text(
                  'Your data is stored in Firebase (Firestore) and may be hosted in multiple countries. By using the app you consent to transfers to and processing in other jurisdictions. Data is encrypted in transit (TLS) and we rely on Firebase for encryption at rest.'),
              const SizedBox(height: 20),

              _h(context, 'Retention'),
              const SizedBox(height: 8),
              const Text(
                  'We retain your account profile and user data while your account exists and as needed to provide the service. When you delete items or delete your account, most associated data will be removed from active databases. Some backups, logs, or subcollection documents may persist for up to 30 days for technical reasons. Aggregated or anonymized data may be retained longer.'),
              const SizedBox(height: 20),

              _h(context, 'Your choices & rights'),
              const SizedBox(height: 8),
              const Text(
                  'Depending on your jurisdiction, you may have rights to access, correct, delete, or port your data, restrict or object to certain processing, and lodge a complaint with a supervisory authority.'),
              const SizedBox(height: 8),
              const Text(
                  'To exercise these rights: use the "Submit Feedback" option in the app or contact $_contactEmail. For account deletion, use the in-app Delete Account flow (see Profile). After deletion we will confirm by email and state the expected cleanup timeframe.'),
              const SizedBox(height: 20),

              _h(context, 'Location & permissions'),
              const SizedBox(height: 8),
              const Text(
                  'Location is optional. You can deny or revoke location permission in your device or browser settings. Core app features continue to work without location permission.'),
              const SizedBox(height: 20),

              _h(context, 'Children'),
              const SizedBox(height: 8),
              const Text(
                  'The app is not directed to children under 13. If we learn we have collected personal data from a child under 13 without verified parental consent, we will take steps to remove that information.'),
              const SizedBox(height: 20),

              _h(context, 'Security'),
              const SizedBox(height: 8),
              const Text(
                  'We use administrative, technical, and physical safeguards to protect personal data (for example, TLS for data in transit and Firebase security rules). However, no system is completely secure — if you suspect a breach contact $_contactEmail immediately.'),
              const SizedBox(height: 20),

              _h(context, 'Changes to this policy'),
              const SizedBox(height: 8),
              const Text(
                  'We may update this policy to reflect new features or legal requirements. We will post the updated policy in the app and update the Effective date at the top. For major changes we will notify active users by in-app notice or email.'),
              const SizedBox(height: 20),

              _h(context, 'How to contact us'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: Text(
                          'For questions, data access requests, or concerns: $_contactEmail')),
                  TextButton(
                    onPressed: () => _contact(context),
                    child: const Text('Email us'),
                  ),
                ],
              ),

              const SizedBox(height: 24),
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

  static void _scrollToFullPolicy(BuildContext context) {
    // For simplicity this placeholder triggers nothing special.
    // If you embed this screen inside a ScrollController you can implement a proper jump.
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrolled to full policy (placeholder)')));
  }

  static Future<void> _contact(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {
        'subject': 'Awe: privacy / data request',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open mail client.')));
    }
  }

  static Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This will remove your account and most associated data. Some backups or logs may remain for up to 30 days.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    // TODO: Wire this to your account deletion API / Firebase cleanup logic.
    // Example: call a Cloud Function that removes Firestore documents and associated resources,
    // then sign the user out of Firebase Auth.

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account deletion started (placeholder).')));
  }
}
