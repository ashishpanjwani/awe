import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderwell/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _effectiveDate = 'July 4, 2026';
  static const _contactEmail = 'madebyfeelsgood@gmail.com';

  @override
  Widget build(BuildContext context) {
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
          'Privacy Policy',
          style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: AweColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Contact / Data request',
            icon: const Icon(Icons.email_outlined, color: AweColors.accentTeal),
            onPressed: () => _contact(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy — Awe',
              style: GoogleFonts.dmSerifDisplay(fontSize: 24, color: AweColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Effective date: $_effectiveDate',
              style: GoogleFonts.ibmPlexMono(fontSize: 11, letterSpacing: 0.4, color: const Color(0xFFA08A64)),
            ),
            const SizedBox(height: 20),

            _heading('Overview'),
            _body('Awe ("we", "us", "our") is a daily wonder discovery app that surfaces one extraordinary phenomenon, tradition, or place from around the world each day, along with curated collections, an interactive atlas, and AI-generated travel itineraries. This policy explains what data we collect, why we collect it, and how you can control your information.'),

            _heading('Data controller & contact'),
            _body('Data controller: Awe / the developer of this build. For questions or data requests: $_contactEmail'),

            _heading('What we collect'),
            _bullet('Account information: When you sign in with Google Sign-In (Firebase Auth) we receive your name, email address, and optional profile photo. We store a simple profile document in Firestore to personalise the app.'),
            _bullet('Wonder interactions: likes (saved wonders), daily viewing streak, total wonders viewed, and countries discovered through wonders. These are stored under your user document in Firestore.'),
            _bullet('Itinerary data: If you generate a travel itinerary from a wonder, the generated itinerary may be saved to your account for later access. Itineraries are stored in Firestore under your user document.'),
            _bullet('Notification token: If you enable daily notifications, we store a device push token to deliver your daily wonder reminder. You can disable notifications at any time in your device settings.'),
            _bullet('Daily public content: Daily Wonder entries are stored globally by UTC date and are not linked to your identity.'),
            _bullet('Diagnostics and logs: basic error logs and anonymised diagnostics to improve reliability. We do not include third-party analytics SDKs.'),

            _heading('How we use data'),
            _bullet('Authenticate you and keep you signed in across sessions.'),
            _bullet('Display your wonder streak, liked wonders, and countries explored.'),
            _bullet('Save and display AI-generated itineraries you create from wonders.'),
            _bullet('Deliver your daily wonder notification at your chosen time.'),
            _bullet('Diagnose and fix bugs; improve reliability with minimal, anonymised logs.'),
            _bullet('Comply with legal obligations.'),

            _heading('Legal basis (EU/EEA users)'),
            _body('Where applicable, our lawful bases for processing personal data include: performance of contract (account & sync), consent (optional notification features), and legitimate interests (service improvement and security), balanced against your rights.'),

            _heading('Third-party services & processors'),
            _body('We rely on third-party services to operate the app, including but not limited to:'),
            _bullet('Firebase (Auth & Firestore) — authentication and cloud data storage.'),
            _bullet('Google Sign-In — authentication and basic profile.'),
            _bullet('Gemini AI (Google) — AI-powered wonder content generation. Text input used for generation is not used to train Google\'s models under our API agreement.'),
            _bullet('Unsplash — public image URLs for wonder entries.'),
            _body('These processors have their own privacy practices and may store or process data in different countries.'),

            _heading('Data storage & transfers'),
            _body('Your data is stored in Firebase (Firestore) and may be hosted in multiple countries. By using the app you consent to transfers to and processing in other jurisdictions. Data is encrypted in transit (TLS) and we rely on Firebase for encryption at rest.'),

            _heading('Retention'),
            _body('We retain your account profile and user data while your account exists. When you delete your account, associated data will be removed from active databases. Some backups or logs may persist for up to 30 days.'),

            _heading('Your choices & rights'),
            _body('Depending on your jurisdiction, you may have rights to access, correct, delete, or port your data, restrict or object to certain processing, and lodge a complaint with a supervisory authority.'),
            _body('To exercise these rights: use the in-app feedback option or contact $_contactEmail. For account deletion, use the in-app Delete Account flow.'),

            _heading('Notifications'),
            _body('Daily wonder reminders are optional. You can enable or disable them in Settings, or revoke the permission in your device settings. If you disable notifications, we stop sending pushes and remove your device token.'),

            _heading('Children'),
            _body('The app is not directed to children under 13. If we learn we have collected personal data from a child under 13 without verified parental consent, we will take steps to remove that information.'),

            _heading('Security'),
            _body('We use administrative, technical, and physical safeguards to protect personal data. However, no system is completely secure — if you suspect a breach contact $_contactEmail immediately.'),

            _heading('Changes to this policy'),
            _body('We may update this policy to reflect new features or legal requirements. We will post the updated policy in the app and update the Effective date at the top.'),

            _heading('How to contact us'),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'For questions, data access requests, or concerns: $_contactEmail',
                    style: GoogleFonts.sourceSans3(fontSize: 15, height: 1.6, color: AweColors.textBody),
                  ),
                ),
                TextButton(
                  onPressed: () => _contact(context),
                  child: Text(
                    'Email us',
                    style: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600, color: AweColors.accentTeal),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.dmSerifDisplay(fontSize: 18, color: AweColors.textPrimary),
      ),
    );
  }

  Widget _body(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.sourceSans3(fontSize: 15, height: 1.6, color: AweColors.textBody),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFA08A64),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.sourceSans3(fontSize: 15, height: 1.6, color: AweColors.textBody),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _contact(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {'subject': 'Awe: privacy / data request'},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open mail app')),
      );
    }
  }
}
