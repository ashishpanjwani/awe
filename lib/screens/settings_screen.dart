// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/services/notification_service.dart';
import 'package:wanderwell/bloc/auth_cubit.dart';
import 'package:wanderwell/screens/welcome_screen.dart';
// import 'package:cloud_functions/cloud_functions.dart'; // Expand Collections

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _notifEnabled = false;
  // bool _expandingCollections = false; // Expand Collections

  @override
  void initState() {
    super.initState();
    _loadVersion();
    NotificationService().isEnabled().then((v) {
      if (mounted) setState(() => _notifEnabled = v);
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final granted = await NotificationService().requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable notifications in device settings')),
        );
        return;
      }
      await NotificationService().scheduleDaily();
    } else {
      await NotificationService().cancel();
    }
    if (mounted) setState(() => _notifEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

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
          'Settings',
          style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: AweColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // Notifications section
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined, size: 20, color: const Color(0xFFC0902F)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily reminder',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: AweColors.textPrimary,
                            ),
                          ),
                          Text(
                            '8:00 AM · your local time',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 12.5,
                              color: const Color(0xFF9A8C70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _notifEnabled,
                      onChanged: _toggleNotifications,
                      activeThumbColor: AweColors.accentTeal,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          // Legal section
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
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF2F6F8F),
                    label: 'Terms & Conditions',
                    showBorder: true,
                    onTap: () => Navigator.of(context).pushNamed('/terms'),
                  ),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF7A6A93),
                    label: 'Privacy Policy',
                    showBorder: false,
                    onTap: () => Navigator.of(context).pushNamed('/privacy'),
                  ),
                ],
              ),
            ),
          ),

          // ── Expand Collections (commented out — uncomment to use, then re-comment) ──
          // const SizedBox(height: 16),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 22),
          //   child: GestureDetector(
          //     onTap: _expandingCollections ? null : _expandCollections,
          //     child: Container(
          //       padding: const EdgeInsets.symmetric(vertical: 14),
          //       decoration: BoxDecoration(
          //         color: const Color(0xFF2F6F8F).withValues(alpha: 0.08),
          //         borderRadius: BorderRadius.circular(14),
          //         border: Border.all(color: const Color(0xFF2F6F8F).withValues(alpha: 0.3)),
          //       ),
          //       child: Center(
          //         child: _expandingCollections
          //             ? const SizedBox(
          //                 height: 18,
          //                 width: 18,
          //                 child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2F6F8F)),
          //               )
          //             : Text(
          //                 'Expand Collections',
          //                 style: GoogleFonts.sourceSans3(
          //                   fontSize: 14,
          //                   fontWeight: FontWeight.w600,
          //                   color: const Color(0xFF2F6F8F),
          //                 ),
          //               ),
          //       ),
          //     ),
          //   ),
          // ),
          // ─────────────────────────────────────────────────────────────────────────

          const Spacer(),

          // Bottom section
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: Column(
              children: [
                if (AuthService().isLoggedIn)
                  TextButton(
                    onPressed: () => _confirmDelete(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: Text(
                      'Delete Account',
                      style: GoogleFonts.sourceSans3(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Logged in as',
                  style: GoogleFonts.ibmPlexMono(fontSize: 11, color: AweColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? 'Guest',
                  style: GoogleFonts.ibmPlexMono(fontSize: 11, color: AweColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'App version: $_version',
                  style: GoogleFonts.ibmPlexMono(fontSize: 10, color: const Color(0xFFC2B69E)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AuthService().isLoggedIn
                      ? _AweButton(
                          label: 'Log Out',
                          onPressed: () async {
                            try {
                              await context.read<AuthCubit>().signOut();
                            } catch (_) {
                              await AuthService().signOut();
                            }
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                              (route) => false,
                            );
                          },
                        )
                      : _AweButton(
                          label: 'Sign in with Google',
                          onPressed: () async {
                            try {
                              await context.read<AuthCubit>().signInWithGoogle();
                            } catch (_) {
                              await AuthService().signInWithGoogle();
                            }
                          },
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Expand Collections method (commented out — matches button above) ──────────
  // Future<void> _expandCollections() async {
  //   setState(() => _expandingCollections = true);
  //   try {
  //     final fn = FirebaseFunctions.instance.httpsCallable(
  //       'generateCollectionWonders',
  //       options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
  //     );
  //     final result = await fn.call({'count': 3});
  //     final summary = (result.data as Map)['summary'] as List? ?? [];
  //     if (!mounted) return;
  //     final lines = summary.map((s) => '${s['collection']}: +${s['added']}').join('\n');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Done!\n$lines'), duration: const Duration(seconds: 6)),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed: $e')),
  //     );
  //   } finally {
  //     if (mounted) setState(() => _expandingCollections = false);
  //   }
  // }
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Account',
          style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: AweColors.textPrimary),
        ),
        content: Text(
          'This will permanently delete your account. This action cannot be undone.',
          style: GoogleFonts.sourceSans3(fontSize: 15, color: AweColors.textBody, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: AweColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text('Delete', style: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (res != true) return;

    try {
      await AuthService().deleteAccount();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } on Exception catch (e) {
      debugPrint('[Settings] deleteAccount error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed. Please sign in again and retry.')),
      );
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool showBorder;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
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
              child: Text(
                label,
                style: GoogleFonts.sourceSans3(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AweColors.textPrimary,
                ),
              ),
            ),
            Text('>', style: TextStyle(fontSize: 21, color: const Color(0xFFCDC3B0))),
          ],
        ),
      ),
    );
  }
}

class _AweButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _AweButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AweColors.accentSlate,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.sourceSans3(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
