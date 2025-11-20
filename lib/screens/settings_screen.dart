import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wanderwell/theme.dart';
import 'package:wanderwell/widgets/cta_button.dart';
import 'package:wanderwell/services/auth_service.dart';
import 'package:wanderwell/bloc/auth_cubit.dart';
import 'package:wanderwell/screens/welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = "${info.version}+${info.buildNumber}");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService().currentUser;

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
        title: Text(
          'Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            color: FlowColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legalTile(
            context,
            icon: Icons.privacy_tip_outlined,
            label: 'Terms & Conditions',
            onTap: () => Navigator.of(context).pushNamed('/terms'),
          ),
          _legalTile(
            context,
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => Navigator.of(context).pushNamed('/privacy'),
          ),
          Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (AuthService().isLoggedIn)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _confirmDelete(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: const Text('Delete Account'),
                  ),
                ),
              Text(
                "Logged in as",
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
              Text(
                user?.email ?? 'Guest',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 8),
              Text(
                "App version: $_version",
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
              ),
              const SizedBox(height: 16),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: AuthService().isLoggedIn
                    ? CtaButton(
                        label: 'Log Out',
                        onPressed: () async {
                          try {
                            await context.read<AuthCubit>().signOut();
                          } catch (_) {
                            await AuthService().signOut();
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const WelcomeScreen()),
                            (route) => false,
                          );
                        },
                      )
                    : CtaButton(
                        label: 'Sign in with Google',
                        leadingIcon: Icons.login,
                        onPressed: () async {
                          try {
                            await context.read<AuthCubit>().signInWithGoogle();
                          } catch (_) {
                            await AuthService().signInWithGoogle();
                          }
                        },
                      ),
              ),
              SizedBox(height: 24)
            ],
          ),
        ],
      ),
    );
  }

  Widget _legalTile(BuildContext context,
      {required IconData icon, required String label, VoidCallback? onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
        Divider(color: Colors.white.withOpacity(0.05))
      ],
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
        const SnackBar(
          content: Text('Delete failed. Please sign in again and retry.'),
        ),
      );
    }
  }
}
