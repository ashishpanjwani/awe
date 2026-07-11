import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderwell/screens/daily_wonder_screen.dart';
import 'package:wanderwell/screens/wonder_map_screen.dart';
import 'package:wanderwell/screens/library_tab_screen.dart';
import 'package:wanderwell/screens/profile_screen.dart';
import 'package:wanderwell/services/notification_service.dart';
import 'package:wanderwell/theme.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  static int _persistedIndex = 0;
  int _currentIndex = _persistedIndex;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _atlasMuted = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(0.35);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRequestNotifications());
  }

  Future<void> _maybeRequestNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_permission_requested') ?? false) return;
    await prefs.setBool('notif_permission_requested', true);
    final granted = await NotificationService().requestPermission();
    if (granted) await NotificationService().scheduleDaily();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    final wasAtlas = _currentIndex == 1;
    final isAtlas = index == 1;

    _persistedIndex = index;
    setState(() => _currentIndex = index);

    SystemChrome.setSystemUIOverlayStyle(
      isAtlas ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    if (isAtlas && !wasAtlas) {
      _mapKey.currentState?.refresh();
      if (!_atlasMuted) {
        _audioPlayer.play(AssetSource('audio/Typewriter Clacking Music.mp3'));
      }
    } else if (!isAtlas && wasAtlas) {
      _audioPlayer.pause();
    }
  }

  void _toggleMute() {
    setState(() => _atlasMuted = !_atlasMuted);
    if (_atlasMuted) {
      _audioPlayer.pause();
    } else if (_currentIndex == 1) {
      _audioPlayer.play(AssetSource('audio/Typewriter Clacking Music.mp3'));
    }
  }

  final _mapKey = GlobalKey<WonderMapScreenState>();

  late final _screens = [
    const DailyWonderScreen(),
    WonderMapScreen(key: _mapKey),
    const LibraryTabScreen(),
    const ProfileScreen(),
  ];

  static final _tabs = [
    _NavTab(icon: FontAwesomeIcons.burst, activeIcon: FontAwesomeIcons.burst, label: 'Awe'),
    _NavTab(icon: FontAwesomeIcons.compass, activeIcon: FontAwesomeIcons.solidCompass, label: 'Atlas'),
    _NavTab(icon: FontAwesomeIcons.layerGroup, activeIcon: FontAwesomeIcons.layerGroup, label: 'Unearth'),
    _NavTab(icon: FontAwesomeIcons.user, activeIcon: FontAwesomeIcons.solidUser, label: 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: _currentIndex == 1 ? const Color(0xFF091B26) : AweColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          if (_currentIndex == 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 170,
              right: 20,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _atlasMuted ? Icons.volume_off : Icons.volume_up,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 12, top: 8, left: 24, right: 24),
        child: Container(
          height: 56,
          decoration: BoxDecoration(  
            color: _currentIndex == 1
                ? const Color(0xFF1A2E3B)
                : const Color(0xFFE8E1D5),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _currentIndex == 1
                  ? Colors.white.withValues(alpha: 0.12)
                  : AweColors.accentSlate.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isActive = _currentIndex == i;
              final onDark = _currentIndex == 1;
              return Expanded(
                flex: isActive ? 2 : 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (onDark ? Colors.white.withValues(alpha: 0.15) : AweColors.accentSlate.withValues(alpha: 0.12))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          isActive ? tab.activeIcon : tab.icon,
                          size: 20,
                          color: isActive
                              ? (onDark ? Colors.white : AweColors.accentSlate)
                              : (onDark ? Colors.white.withValues(alpha: 0.5) : AweColors.navInactive),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Text(
                            tab.label,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: onDark ? Colors.white : AweColors.accentSlate,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final FaIconData icon;
  final FaIconData activeIcon;
  final String label;
  const _NavTab({required this.icon, required this.activeIcon, required this.label});
}
