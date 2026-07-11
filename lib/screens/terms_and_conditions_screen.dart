import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderwell/theme.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

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
          'Terms & Conditions',
          style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: AweColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Contact',
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
              'Terms & Conditions — Awe',
              style: GoogleFonts.dmSerifDisplay(fontSize: 24, color: AweColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Effective date: $_effectiveDate',
              style: GoogleFonts.ibmPlexMono(fontSize: 11, letterSpacing: 0.4, color: const Color(0xFFA08A64)),
            ),
            const SizedBox(height: 20),

            _heading('1. Overview'),
            _body('Welcome to Awe (the "App" or the "Service"). Awe is a daily wonder discovery app — each day it surfaces one extraordinary place, tradition, or natural phenomenon from around the world, alongside curated wonder collections, an atlas map, a personal wonder history, and AI-generated travel itineraries. By using the App you agree to be bound by these Terms. If you do not agree, do not use the App.'),

            _heading('2. Definitions'),
            _body('"User" or "you" means any person using the App. "Content" means AI-generated wonder descriptions, images, and other material displayed within the App. "User Data" means your account profile, liked wonders, streak, and preferences stored under your account.'),

            _heading('3. Use of the Service'),
            _body('The App lets you discover daily wonders, explore curated wonder collections (including premium collections), generate AI-powered travel itineraries from any wonder, save and revisit liked wonders, view wonder locations on an atlas map, and maintain a discovery streak. You agree not to misuse the App, interfere with its operation, scrape its content, or use it for unlawful activities.'),

            _heading('4. Accounts'),
            _body('You may sign in using Google Sign-In / Firebase Auth. You are responsible for maintaining the confidentiality of your account credentials and for all activity under your account.'),

            _heading('5. AI-generated content'),
            _body('Wonder descriptions, curiosity sparks, and other editorial content in the App are generated using Gemini AI (Google). AI outputs may be imperfect, incomplete, or occasionally inaccurate. The App is intended for curiosity and discovery — verify important details independently before making travel or safety decisions.'),

            _heading('6. Notifications'),
            _body('The App may send a daily push notification to remind you of your daily wonder. You control this permission; you can enable or disable notifications at any time in Settings or your device settings.'),

            _heading('7. Third-party services & links'),
            _body('The App integrates third-party services (Firebase, Google Sign-In, Gemini AI, Unsplash, etc.). Their terms and privacy policies apply independently. Awe is not responsible for the content or practices of third-party providers.'),

            _heading('8. Paid features & refunds'),
            _body('The App offers a free tier and a Premium subscription (unlocking all wonder collections). Purchases are processed through the platform store (App Store / Google Play) and are subject to their billing policies. Review subscription details before confirming a purchase. Contact the platform store directly for refund requests.'),

            _heading('9. Termination'),
            _body('We may suspend or terminate access for users who violate these Terms or misuse the Service. You may delete your account via the in-app flow; backups or logs may persist for a limited period as described in the Privacy Policy.'),

            _heading('10. Disclaimers'),
            _body('THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. WONDER CONTENT IS FOR EDUCATIONAL AND INSPIRATIONAL PURPOSES. TRAVEL CONDITIONS, SITE ACCESSIBILITY, AND LOCAL REGULATIONS MAY CHANGE — VERIFY CURRENT CONDITIONS BEFORE TRAVELING.'),

            _heading('11. Limitation of liability'),
            _body('TO THE MAXIMUM EXTENT PERMITTED BY LAW, AWE AND ITS DEVELOPER WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES. OUR AGGREGATE LIABILITY IS LIMITED TO THE AMOUNTS YOU PAID US IN THE LAST 12 MONTHS, IF ANY.'),

            _heading('12. Indemnification'),
            _body('You agree to indemnify and hold Awe harmless from claims, losses, liabilities, damages, and expenses arising from your breach of these Terms or your misuse of the App.'),

            _heading('13. Governing law & disputes'),
            _body('These Terms are governed by applicable law. Parties agree to the jurisdiction and courts in the region where Awe is operated.'),

            _heading('14. Changes to the Terms'),
            _body('We may update these Terms from time to time. The Effective date at the top reflects when the current version became effective. Continued use after an update constitutes acceptance. Material changes will be communicated via in-app notice or email.'),

            _heading('15. Severability & entire agreement'),
            _body('If any provision of these Terms is found invalid or unenforceable, the remainder stays in effect. These Terms constitute the entire agreement between you and Awe regarding the App.'),

            _heading('16. Contact'),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Questions about these Terms? Contact: $_contactEmail',
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
            const SizedBox(height: 24),
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

  static Future<void> _contact(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {'subject': 'Awe: terms / question'},
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
