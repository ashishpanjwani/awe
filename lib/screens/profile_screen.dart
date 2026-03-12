import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs_lite.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/quest_service.dart';
import 'package:wanderwell/screens/welcome_screen.dart';
import 'package:wanderwell/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _completedQuests = 0;
  int _completedMicros = 0;
  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final qs = await QuestService().completedCount(QuestEntryType.quest);
    final ms =
        await QuestService().completedCount(QuestEntryType.microAdventure);
    if (mounted) {
      setState(() {
        _completedQuests = qs;
        _completedMicros = ms;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),

      // ---- BODY (fully scrollable) ----
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 46,
              backgroundColor: FlowColors.chipSelectedDark,
              backgroundImage: (user?.photoUrl?.isNotEmpty ?? false)
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: (user?.photoUrl?.isNotEmpty ?? false)
                  ? null
                  : const Icon(Icons.person, color: Colors.white, size: 44),
            ),

            const SizedBox(height: 14),

            // Name
            Text(
              user?.name ?? "Guest",
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            // Joined On
            Text(
              user?.createdAt != null
                  ? "Joined in ${_formatJoinDate(user!.createdAt)}"
                  : (user?.email ?? "Not signed in"),
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),

            const SizedBox(height: 24),

            // ---- STATS CARD ----
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Stats',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: FlowColors.textLight,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlowColors.cardSurfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                children: [
                  _statRow(
                    icon: Icons.flag,
                    label: "Completed Quests",
                    value: "$_completedQuests",
                    iconColor: FlowColors.accentAmber,
                  ),
                  const SizedBox(height: 16),
                  _statRow(
                    icon: Icons.bolt,
                    label: "Micro Adventures",
                    value: "$_completedMicros",
                    iconColor: FlowColors.softTeal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // Saved Itineraries entry
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Collection',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: FlowColors.textLight,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () =>
                  Navigator.of(context).pushNamed('/saved_itineraries'),
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  color: FlowColors.cardSurfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: FlowColors.chipSelectedDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            const Icon(Icons.bookmark, color: Colors.white70),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Saved Itineraries',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white60),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            // Share Feedback
            TextButton(
              onPressed: _openFeedbackForm,
              style: TextButton.styleFrom(
                  backgroundColor: FlowColors.surfaceDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: Text(
                'Share Feedback',
                style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ------ HELPERS ------
  Widget _statRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }

  static String _formatJoinDate(DateTime? dt) {
    if (dt == null) return "";
    final month = _monthName(dt.month);
    return "$month ${dt.year}";
  }

  static String _monthName(int m) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return months[m - 1];
  }

  Future<void> _openFeedbackForm() async {
    const urlStr = 'https://forms.gle/GBoVb7r1L35c2Ydw9';
    final uri = Uri.parse(urlStr);
    final theme = Theme.of(context);
    try {
      await launchUrl(
        uri,
        options: LaunchOptions(
          barColor: theme.colorScheme.onPrimary,
          onBarColor: theme.colorScheme.onPrimary,
          barFixingEnabled: false,
        ),
      );
    } catch (e) {
      debugPrint('[Profile] openFeedbackForm error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open feedback form')),
      );
    }
  }
}