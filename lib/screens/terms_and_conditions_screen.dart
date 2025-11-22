import 'package:flutter/material.dart';
import 'package:wanderwell/theme.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

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
                  'By using this app, you agree to these terms. If you do not agree, please do not use the app.'),
              const SizedBox(height: 20),
              _h(context, 'Use of the Service'),
              const SizedBox(height: 8),
              const Text(
                  'This app helps you discover destinations, generate itineraries, and explore daily quests. Do not misuse the app, interfere with its operation, or access it using methods other than the interface and instructions we provide.'),
              const SizedBox(height: 20),
              _h(context, 'Accounts'),
              const SizedBox(height: 8),
              const Text(
                  'You may sign in with Google. You are responsible for maintaining the confidentiality of your account and for all activities under it.'),
              const SizedBox(height: 20),
              _h(context, 'AI‑generated content'),
              const SizedBox(height: 8),
              const Text(
                  'Parts of the app use AI models (via Firebase AI) to generate descriptions and itineraries. AI outputs may contain errors or may be incomplete. Use your own judgment and verify important details independently.'),
              const SizedBox(height: 20),
              _h(context, 'Location & weather'),
              const SizedBox(height: 8),
              const Text(
                  'If you grant permission, we use your approximate location on‑device to personalize quests and show local weather via Open‑Meteo. You can deny or revoke permission; core features still work.'),
              const SizedBox(height: 20),
              _h(context, 'Content and Intellectual Property'),
              const SizedBox(height: 8),
              const Text(
                  'The app UI, code, and original content are owned by the app’s developer. Third‑party content (e.g., Wikipedia images) remains the property of their respective owners and is used under applicable licenses.'),
              const SizedBox(height: 20),
              _h(context, 'Third‑party services'),
              const SizedBox(height: 8),
              const Text(
                  'We rely on Firebase (Auth/Firestore), Google Sign‑In, Open‑Meteo, Photon, and Wikipedia image URLs. Their terms and privacy policies apply when their services are used.'),
              const SizedBox(height: 20),
              _h(context, 'Termination'),
              const SizedBox(height: 8),
              const Text(
                  'We may suspend or terminate access if you violate these terms or misuse the service.'),
              const SizedBox(height: 20),
              _h(context, 'Disclaimers'),
              const SizedBox(height: 8),
              const Text(
                  'The service is provided “as is” without warranties of any kind. Travel conditions change; verify safety, opening hours, and requirements before you go.'),
              const SizedBox(height: 20),
              _h(context, 'Limitation of liability'),
              const SizedBox(height: 8),
              const Text(
                  'To the maximum extent permitted by law, the app and its developer will not be liable for any indirect, incidental, or consequential damages arising from your use of the app.'),
              const SizedBox(height: 20),
              _h(context, 'Changes'),
              const SizedBox(height: 8),
              const Text(
                  'We may update these terms as we improve the app. Continued use after changes means you accept the updated terms.'),
              const SizedBox(height: 20),
              _h(context, 'Contact'),
              const SizedBox(height: 8),
              const Text(
                  'Questions about these terms? Use the “Submit Feedback” option in the app to reach us.'),
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
