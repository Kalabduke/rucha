import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/community_store.dart';
import '../services/tracking_service.dart';
import '../widgets/rucha_logo.dart';
import 'activities_screen.dart';
import 'challenges_screen.dart';
import 'community_screen.dart';
import 'explore_screen.dart';
import 'gallery_screen.dart';
import 'profile_screen.dart';
import 'record_screen.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final String subtitle;
  const _NavItem(this.icon, this.label, this.subtitle);
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // ── Tab definitions (order = bottom bar order) ───────────────────────────
  // Index 2 is the Record FAB — no screen change, just navigate to record.
  static const List<_NavItem> _navItems = [
    _NavItem(Icons.home_rounded, 'Home', 'Good morning, Athlete'),
    _NavItem(Icons.explore_rounded, 'Explore', 'Find your next route'),
    _NavItem(Icons.play_circle_fill_rounded, 'Record', 'Make your move'),
    _NavItem(CupertinoIcons.flag_fill, 'Challenges', 'Compete & grow'),
    _NavItem(Icons.photo_library_rounded, 'Gallery', 'Your run cards'),
    _NavItem(Icons.groups_2_rounded, 'Community', 'Better, together'),
    _NavItem(Icons.person_rounded, 'Profile', 'Make it yours'),
  ];

  void _select(int index) {
    if (index < 0 || index >= _navItems.length || index == _currentIndex) {
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final auth = context.watch<AuthService>();
    final isRecording = tracking.status == RecordingStatus.running;

    final screens = [
      // 0 – Home (Activities)
      ActivitiesScreen(onStartRecording: () => _select(2)),
      // 1 – Explore
      ExploreScreen(onStartRecording: () => _select(2)),
      // 2 – Record
      RecordScreen(onNavigateHome: () => _select(0)),
      // 3 – Challenges
      const ChallengesScreen(),
      // 4 – Gallery
      const GalleryScreen(),
      // 5 – Community
      CommunityScreen(onStartRecording: () => _select(2)),
      // 6 – Profile
      const ProfileScreen(),
    ];

    final isWide = MediaQuery.of(context).size.width >= 768;

    // ── Wide layout (tablet / desktop): slim sidebar ─────────────────────
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 220,
              decoration: const BoxDecoration(
                color: RuchaTheme.surface,
                border: Border(right: BorderSide(color: RuchaTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [
                              RuchaTheme.accentGreen,
                              RuchaTheme.accentGold,
                              RuchaTheme.accentRed,
                            ]),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            RuchaLogo(
                                size: 32, showText: false, showFlag: false),
                            SizedBox(width: 10),
                            Text('RUCHA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: RuchaTheme.border),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _navItems.length,
                      itemBuilder: (context, index) {
                        final item = _navItems[index];
                        final selected = _currentIndex == index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          child: InkWell(
                            onTap: () => _select(index),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? RuchaTheme.accent.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? RuchaTheme.accent.withOpacity(0.35)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? RuchaTheme.accent.withOpacity(0.18)
                                          : RuchaTheme.surface2,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(item.icon,
                                        size: 16,
                                        color: selected
                                            ? RuchaTheme.accent
                                            : RuchaTheme.textSecondary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(
                                    item.label,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : RuchaTheme.textSecondary,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _ServerStatusBar(auth: auth),
                ],
              ),
            ),
            Expanded(
                child: IndexedStack(index: _currentIndex, children: screens)),
          ],
        ),
      );
    }

    // ── Mobile layout: NO drawer — everything in bottom bar ──────────────
    return Scaffold(
      appBar: _currentIndex == 2
          ? null
          : AppBar(
              titleSpacing: 0,
              title: Row(
                children: [
                  const RuchaLogo(size: 28, showText: false, showFlag: false),
                  const SizedBox(width: 10),
                  Text(
                    _navItems[_currentIndex].label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      color: RuchaTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(2.0),
                child: Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      RuchaTheme.accentGreen,
                      RuchaTheme.accentGold,
                      RuchaTheme.accentRed,
                    ]),
                  ),
                ),
              ),
              actions: [
                if (isRecording)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: InkWell(
                      onTap: () => _select(2),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: RuchaTheme.accentRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: RuchaTheme.accentRed),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                size: 8, color: RuchaTheme.accentRed),
                            SizedBox(width: 5),
                            Text('LIVE',
                                style: TextStyle(
                                  color: RuchaTheme.accentRed,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(CupertinoIcons.person_crop_circle, size: 24),
                  tooltip: 'Profile',
                  onPressed: () => _select(6),
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _currentIndex == 2
          ? null
          : _RuchaBottomBar(
              currentIndex: _currentIndex,
              onSelect: _select,
              navItems: _navItems,
            ),
    );
  }
}

// ── Server status bar (wide layout only) ─────────────────────────────────────
class _ServerStatusBar extends StatelessWidget {
  final AuthService auth;
  const _ServerStatusBar({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RuchaTheme.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle,
              size: 8,
              color: auth.serverOnline
                  ? RuchaTheme.accentGreen
                  : RuchaTheme.accentGold),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
            auth.serverOnline ? 'Server connected' : 'Local mode',
            style:
                const TextStyle(fontSize: 10, color: RuchaTheme.textSecondary),
          )),
        ],
      ),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────
class _RuchaBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<_NavItem> navItems;

  const _RuchaBottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<CommunityStore>().unreadNoticeCount;

    return Container(
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        border:
            const Border(top: BorderSide(color: RuchaTheme.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 0 – Home
              _tab(0, currentIndex, navItems[0], 0, onSelect),
              // 1 – Explore
              _tab(1, currentIndex, navItems[1], 0, onSelect),
              // 2 – Record (large circle that pops above the bar)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(2),
                  child: SizedBox(
                    height: 68,
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -14),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), RuchaTheme.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: RuchaTheme.surface, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: RuchaTheme.accent.withOpacity(0.6),
                                blurRadius: 24,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 3 – Challenges
              _tab(3, currentIndex, navItems[3], 0, onSelect),
              // 4 – Gallery
              _tab(4, currentIndex, navItems[4], 0, onSelect),
              // 5 – Community
              _tab(5, currentIndex, navItems[5], unread, onSelect),
              // 6 – Profile  (accessed via AppBar icon — no bottom slot)
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int index, int current, _NavItem item, int badge,
      ValueChanged<int> onSelect) {
    return Expanded(
      child: _BottomItem(
        item: item,
        selected: current == index,
        badge: badge,
        onTap: () => onSelect(index),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _BottomItem({
    required this.item,
    required this.selected,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? RuchaTheme.accent : RuchaTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (selected)
                  Container(
                    width: 40,
                    height: 32,
                    decoration: BoxDecoration(
                      color: RuchaTheme.accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                Icon(item.icon, size: 22, color: color),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: RuchaTheme.accentRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
