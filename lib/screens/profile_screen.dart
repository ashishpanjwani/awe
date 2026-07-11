import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wanderwell/models/wonder_user_state.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/premium_service.dart';
import 'package:wanderwell/services/wonder_user_service.dart';
import 'package:wanderwell/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  WonderUserState _wonderState = const WonderUserState();
  StreamSubscription<bool>? _premiumSub;

  @override
  void initState() {
    super.initState();
    _loadWonderStats();
    // Rebuild immediately when a purchase is confirmed so the premium row appears
    _premiumSub = PremiumService().onPremiumActivated.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    super.dispose();
  }

  Future<void> _loadWonderStats() async {
    final state = await WonderUserService().getState();
    if (mounted) setState(() => _wonderState = state);
  }

  String _subscriptionSubtitle() {
    final svc = PremiumService();
    final type = svc.subscriptionType == 'annual' ? 'Annual' : 'Monthly';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = svc.expiryDate?.toLocal();
    if (d == null) return '$type plan';
    if (svc.isOnTrial) return '$type · trial ends ${months[d.month - 1]} ${d.day}';
    return '$type · renews ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  void _showSubscriptionSheet(BuildContext context) {
    final svc = PremiumService();
    final isAnnual = svc.subscriptionType == 'annual';
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];

    String fmtDate(DateTime? d) => d != null
        ? '${months[d.month - 1]} ${d.day}, ${d.year}'
        : 'Unknown';

    final onTrial = svc.isOnTrial && svc.expiryDate != null;
    final billingLabel = onTrial ? 'Charges applicable from' : 'Renews on';
    final billingDate = fmtDate(svc.expiryDate?.toLocal());
    final priceStr = svc.subscriptionPriceFormatted ??
        (isAnnual ? '—' : '—');
    final priceSuffix = isAnnual ? '/ year' : '/ month';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF6F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9CFBF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AweColors.accentGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspace_premium, color: AweColors.accentGold, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Awe Premium',
                      style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: AweColors.textPrimary),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Active',
                          style: GoogleFonts.ibmPlexMono(fontSize: 11, color: Color(0xFF4CAF50)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Details card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFECE3D4)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _SheetRow(label: 'Plan', value: isAnnual ? 'Annual' : 'Monthly'),
                  const Divider(height: 1, color: Color(0xFFF0E8DA)),
                  if (svc.expiryDate != null) ...[
                    _SheetRow(label: billingLabel, value: billingDate),
                    const Divider(height: 1, color: Color(0xFFF0E8DA)),
                  ],
                  _SheetRow(label: 'Price', value: '$priceStr $priceSuffix'),
                ],
              ),
            ),
            if (svc.expiryDate == null) ...[
              const SizedBox(height: 10),
              Text(
                'Billing date syncs on next app open',
                style: GoogleFonts.sourceSans3(fontSize: 12, color: const Color(0xFF9A8C70)),
              ),
            ],

            const SizedBox(height: 24),

            // Manage button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                    'https://play.google.com/store/account/subscriptions'
                    '?sku=${isAnnual ? 'awe_premium_annual' : 'awe_premium_monthly'}'
                    '&package=com.feelsgood.awe',
                  );
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AweColors.accentSlate,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Manage Subscription',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                'To cancel, tap Manage Subscription → Cancel',
                style: GoogleFonts.sourceSans3(fontSize: 12.5, color: const Color(0xFF9A8C70)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  static String _formatJoinDate(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final userName = user?.name ?? 'Guest';
    final joinDate = _formatJoinDate(user?.createdAt);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile head
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          radius: 0.7,
                          colors: [Color(0xFF7EAEC9), Color(0xFF1D4257)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF142D3C).withValues(alpha: 0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: (user?.photoUrl?.isNotEmpty ?? false)
                          ? ClipOval(
                              child: CachedNetworkImage(imageUrl: user!.photoUrl!, fit: BoxFit.cover),
                            )
                          : Center(
                              child: Text(
                                _initials(userName),
                                style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 26,
                            color: AweColors.textPrimary,
                          ),
                        ),
                        if (PremiumService().isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AweColors.accentGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PRO',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AweColors.accentGold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (joinDate.isNotEmpty)
                      Text(
                        'WANDERING SINCE ${joinDate.toUpperCase()}',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          color: const Color(0xFFA08A64),
                        ),
                      ),
                  ],
                ),
              ),

              // Stats card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFECE3D4)),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3C2D14).withValues(alpha: 0.13),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -14,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // Streak
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_fire_department, size: 15, color: const Color(0xFFC18B2C)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${_wonderState.currentStreak}',
                                      style: GoogleFonts.dmSerifDisplay(fontSize: 26, height: 1, color: AweColors.textPrimary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'DAY STREAK',
                                  style: GoogleFonts.ibmPlexMono(fontSize: 9, letterSpacing: 0.8, color: const Color(0xFF9A8C70)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'BEST ${_wonderState.longestStreak}',
                                  style: GoogleFonts.ibmPlexMono(fontSize: 9, letterSpacing: 0.4, color: const Color(0xFFC2B69E)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 1, color: const Color(0xFFECE3D4), margin: const EdgeInsets.symmetric(vertical: 14)),
                        // Wonders
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
                            child: Column(
                              children: [
                                Text(
                                  '${_wonderState.totalWondersViewed}',
                                  style: GoogleFonts.dmSerifDisplay(fontSize: 26, height: 1, color: AweColors.textPrimary),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'WONDERS',
                                  style: GoogleFonts.ibmPlexMono(fontSize: 9, letterSpacing: 0.8, color: const Color(0xFF9A8C70)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'VIEWED',
                                  style: GoogleFonts.ibmPlexMono(fontSize: 9, letterSpacing: 0.4, color: const Color(0xFFC2B69E)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 1, color: const Color(0xFFECE3D4), margin: const EdgeInsets.symmetric(vertical: 14)),
                        // Countries
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
                            child: Column(
                              children: [
                                Text(
                                  '${_wonderState.countriesDiscovered.length}',
                                  style: GoogleFonts.dmSerifDisplay(fontSize: 26, height: 1, color: AweColors.textPrimary),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'COUNTRIES',
                                  style: GoogleFonts.ibmPlexMono(fontSize: 9, letterSpacing: 0.8, color: const Color(0xFF9A8C70)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'EXPLORED',
                                  style: GoogleFonts.ibmPlexMono(fontSize: 9, letterSpacing: 0.4, color: const Color(0xFFC2B69E)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Collection card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFECE3D4)),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3C2D14).withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -16,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (!PremiumService().isPremium)
                        _CollectionRow(
                          icon: Icons.auto_awesome,
                          iconColor: AweColors.accentGold,
                          title: 'Upgrade to Premium',
                          subtitle: 'Unlock all collections & features',
                          showBorder: true,
                          onTap: () => Navigator.of(context).pushNamed('/paywall'),
                        )
                      else
                        _CollectionRow(
                          icon: Icons.workspace_premium,
                          iconColor: AweColors.accentGold,
                          title: 'Premium Active',
                          subtitle: _subscriptionSubtitle(),
                          showBorder: true,
                          onTap: () => _showSubscriptionSheet(context),
                        ),
                      _CollectionRow(
                        icon: Icons.favorite_outline,
                        iconColor: const Color(0xFFB5483D),
                        title: 'Liked Wonders',
                        subtitle: '${_wonderState.savedWonderIds.length} wonders you loved',
                        showBorder: true,
                        onTap: () => Navigator.of(context).pushNamed('/wonder/archive'),
                      ),
                      // _CollectionRow(
                      //   icon: Icons.route,
                      //   iconColor: const Color(0xFF7A6A93),
                      //   title: 'Themed Journeys',
                      //   subtitle: 'Multi-day series, hand-curated',
                      //   showBorder: true,
                      //   onTap: () => Navigator.of(context).pushNamed('/journeys'),
                      // ),
                      _CollectionRow(
                        icon: Icons.bookmark_outline,
                        iconColor: const Color(0xFFC0902F),
                        title: 'Saved Itineraries',
                        subtitle: 'Trips in progress',
                        showBorder: false,
                        onTap: () => Navigator.of(context).pushNamed('/saved_itineraries'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Settings section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    _SettingsRow(
                      label: 'Settings',
                      radiusTop: true,
                      onTap: () => Navigator.of(context).pushNamed('/settings'),
                    ),
                    const SizedBox(height: 1),
                    _SettingsRow(
                      label: 'Send feedback',
                      radiusTop: false,
                      onTap: _openFeedbackForm,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFeedbackForm() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'madebyfeelsgood@gmail.com',
      queryParameters: {'subject': 'Feedback — Awe'},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Profile] openFeedbackForm error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open mail app')),
      );
    }
  }
}

class _CollectionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool showBorder;
  final VoidCallback onTap;

  const _CollectionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.showBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(bottom: BorderSide(color: Color(0xFFF0E8DA)))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: AweColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12.5,
                      color: const Color(0xFF9A8C70),
                    ),
                  ),
                ],
              ),
            ),
            Text('>', style: TextStyle(fontSize: 21, color: const Color(0xFFCDC3B0))),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final bool radiusTop;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.label,
    required this.radiusTop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFECE3D4)),
          borderRadius: radiusTop
              ? const BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(4))
              : const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(14)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.sourceSans3(fontSize: 15, color: const Color(0xFF3A342B)),
              ),
            ),
            Text('>', style: TextStyle(fontSize: 20, color: const Color(0xFFCDC3B0))),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;

  const _SheetRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.sourceSans3(fontSize: 14.5, color: const Color(0xFF9A8C70)),
          ),
          Text(
            value,
            style: GoogleFonts.sourceSans3(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AweColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
