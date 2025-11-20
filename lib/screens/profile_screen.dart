import 'package:flutter/material.dart';
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

  // ----- UI helpers -----
  Widget _legalTile(BuildContext context,
      {required IconData icon, required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
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
                child: Icon(icon, color: Colors.white70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    );
  }

  Future<void> _showLegalSheet(BuildContext context,
      {required String title, required String body}) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: FlowColors.primaryDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              color: FlowColors.textLight,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: FlowColors.textGrey,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlowColors.cardSurfaceDark,
        title:
            const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete your account. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (res != true) return;

    try {
      await AuthService().deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } on Exception catch (e) {
      debugPrint('[Profile] deleteAccount error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete failed. Please sign in again and retry.'),
        ),
      );
    }
  }
}
