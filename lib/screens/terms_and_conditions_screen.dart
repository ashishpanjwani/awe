import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderwell/theme.dart';

/// Drop-in Terms & Conditions screen for Awe.
/// Effective date and contact inserted per user request.
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

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
          'Terms & Conditions',
          style: theme.textTheme.titleMedium?.copyWith(
            color: FlowColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Contact',
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
              Card(
                color: FlowColors.surfaceDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick summary', style: theme.textTheme.titleMedium?.copyWith(color: FlowColors.textLight, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('• By using Awe you accept these terms.'),
                      Text('• Use the App responsibly; verify travel details independently.'),
                      Text('• AI content is advisory — verify important facts.'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _scrollToFullTerms(context),
                            child: const Text('Read full terms'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _contact(context),
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Contact'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text('Terms & Conditions — Awe', style: theme.textTheme.titleLarge?.copyWith(color: FlowColors.textLight, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Effective date: $_effectiveDate', style: theme.textTheme.bodySmall?.copyWith(color: FlowColors.textGrey)),
              const SizedBox(height: 12),

              _h(context, '1. Overview'),
              const SizedBox(height: 8),
              const SelectableText('Welcome to Awe (the "App" or the "Service"). By using the App you agree to be bound by these Terms. If you do not agree, do not use the App.'),
              const SizedBox(height: 20),

              _h(context, '2. Definitions'),
              const SizedBox(height: 8),
              const SelectableText('“User” or “you” means any person using the App. “Content” means any text, images, itineraries, feedback, or other material submitted by users.'),
              const SizedBox(height: 20),

              _h(context, '3. Use of the Service'),
              const SizedBox(height: 8),
              const SelectableText('The App helps you discover destinations, generate itineraries, and explore daily quests. You agree not to misuse the App, interfere with its operation, or use it for unlawful activities.'),
              const SizedBox(height: 20),

              _h(context, '4. Accounts'),
              const SizedBox(height: 8),
              const SelectableText('You may sign in using Google Sign-In / Firebase Auth. You are responsible for maintaining the confidentiality of your account credentials and for all activity under your account.'),
              const SizedBox(height: 20),

              _h(context, '5. AI-generated content'),
              const SizedBox(height: 8),
              const SelectableText('Parts of the App may use AI systems (for example via Firebase AI) to generate descriptions or itineraries. AI outputs may be imperfect, incomplete, or contain errors. Use your own judgment and verify important details independently.'),
              const SizedBox(height: 20),

              _h(context, '6. User content; license to operate'),
              const SizedBox(height: 8),
              const SelectableText('By submitting Content you grant Awe a non-exclusive, worldwide, royalty-free license to use, host, store, reproduce, modify, create derivative works, communicate, publish and display such Content to operate and improve the App. You warrant you have rights to grant this license.'),
              const SizedBox(height: 20),

              _h(context, '7. Location & weather'),
              const SizedBox(height: 8),
              const SelectableText('With your permission we may use approximate location to personalise quests and fetch weather via third-party services. You may revoke location permission at any time.'),
              const SizedBox(height: 20),

              _h(context, '8. Third-party services & links'),
              const SizedBox(height: 8),
              const SelectableText('The App integrates third-party services (Firebase, Google Sign-In, Open-Meteo, Photon, Wikimedia, etc.). Their terms and privacy policies apply. Links to third-party sites are provided "as is" and Awe is not responsible for their content.'),
              const SizedBox(height: 20),

              _h(context, '9. Paid features & refunds'),
              const SizedBox(height: 8),
              const SelectableText('If the App offers paid features, purchases are subject to platform store rules and any additional terms presented at purchase. Review billing and subscription details before confirming purchases.'),
              const SizedBox(height: 20),

              _h(context, '10. Termination'),
              const SizedBox(height: 8),
              const SelectableText('We may suspend or terminate access for users who violate these Terms or misuse the Service. You may delete your account via the in-app flow; backups or logs may persist for a limited period as described in the Privacy Policy.'),
              const SizedBox(height: 20),

              _h(context, '11. Disclaimers'),
              const SizedBox(height: 8),
              const SelectableText('THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES. TRAVEL INFORMATION MAY CHANGE — VERIFY SAFETY, OPENING HOURS, AND LOCAL LAWS BEFORE TRAVELING.'),
              const SizedBox(height: 20),

              _h(context, '12. Limitation of liability'),
              const SizedBox(height: 8),
              const SelectableText('TO THE MAXIMUM EXTENT PERMITTED BY LAW, AWE AND ITS DEVELOPER WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES. OUR AGGREGATE LIABILITY IS LIMITED TO THE AMOUNTS YOU PAID US IN THE LAST 12 MONTHS, IF ANY.'),
              const SizedBox(height: 20),

              _h(context, '13. Indemnification'),
              const SizedBox(height: 8),
              const SelectableText('You agree to indemnify and hold Awe harmless from claims, losses, liabilities, damages, and expenses arising from your breach of these Terms or your use of the App.'),
              const SizedBox(height: 20),

              _h(context, '14. Governing law & disputes'),
              const SizedBox(height: 8),
              const SelectableText('These Terms are governed by applicable law. Parties agree to the jurisdiction and courts as stated in the region where Awe is operated. Please consult local law for consumer protections that may apply.'),
              const SizedBox(height: 20),

              _h(context, '15. Changes to the Terms'),
              const SizedBox(height: 8),
              const SelectableText('We may update these Terms. The Effective date at the top reflects when the Terms became effective. Continued use constitutes acceptance. Major changes will be communicated via in-app notice or email.'),
              const SizedBox(height: 20),

              _h(context, '16. Severability & entire agreement'),
              const SizedBox(height: 8),
              const SelectableText('If any provision is found invalid, the remainder remains in effect. These Terms constitute the entire agreement regarding the App.'),
              const SizedBox(height: 20),

              _h(context, '17. Contact'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: SelectableText('Questions about these Terms? Contact: $_contactEmail')),
                  TextButton(
                    onPressed: () => _contact(context),
                    child: const Text('Email us'),
                  ),
                ],
              ),

              const SizedBox(height: 40),
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

  static Future<void> _contact(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {'subject': 'Awe: terms / question'},
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open mail client.')));
    }
  }

  static void _scrollToFullTerms(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scrolled to full terms (placeholder)')));
  }
}
