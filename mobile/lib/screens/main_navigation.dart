import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'dashboard_screen.dart';
import 'explore_screen.dart';
import 'record_screen.dart';
import 'activities_screen.dart';
import 'gallery_screen.dart';
import 'segments_screen.dart';
import 'community_screen.dart';
import 'challenges_screen.dart';
import 'profile_screen.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final String amharic;

  const _NavItem(this.icon, this.label, this.amharic);
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(CupertinoIcons.house_fill, 'Home', 'ዳሽቦርድ'),
    _NavItem(CupertinoIcons.compass, 'Explore', 'አስስ'),
    _NavItem(Icons.radio_button_checked, 'Record', 'ቅረጽ'),
    _NavItem(CupertinoIcons.list_bullet, 'Log', 'እንቅስቃሴ'),
    _NavItem(CupertinoIcons.photo_on_rectangle, 'Gallery', 'ጋለሪ'),
    _NavItem(Icons.terrain, 'Segments', 'ክፍሎች'),
    _NavItem(CupertinoIcons.person_3_fill, 'Clubs', 'ማህበረሰብ'),
    _NavItem(CupertinoIcons.flag_fill, 'Prizes', 'ሽልማቶች'),
    _NavItem(CupertinoIcons.person_fill, 'Profile', 'መገለጫ'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onStartRecording: () => setState(() => _currentIndex = 2)),
      const ExploreScreen(),
      const RecordScreen(),
      ActivitiesScreen(onStartRecording: () => setState(() => _currentIndex = 2)),
      const GalleryScreen(),
      const SegmentsScreen(),
      const CommunityScreen(),
      const ChallengesScreen(),
      const ProfileScreen(),
    ];

    final isWide = MediaQuery.of(context).size.width >= 768;

    if (isWide) {
      // Desktop Sidebar layout (Fedora Linux, wide screens) matching PWA desktop design
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 230,
              decoration: const BoxDecoration(
                color: RuchaTheme.surface,
                border: Border(right: BorderSide(color: RuchaTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top brand header with Ethiopian flag tricolor
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ethiopian Flag Line (Green, Yellow, Red)
                        Row(
                          children: [
                            Expanded(child: Container(height: 3, color: RuchaTheme.accentGreen)),
                            Expanded(child: Container(height: 3, color: RuchaTheme.accentGold)),
                            Expanded(child: Container(height: 3, color: RuchaTheme.accentRed)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: RuchaTheme.accentGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(CupertinoIcons.flame_fill, size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RUCHA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'የኢትዮጵያ ሩጫ',
                                  style: TextStyle(
                                    color: RuchaTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: RuchaTheme.border, height: 1),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Text(
                      'MENU',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                        color: RuchaTheme.textSecondary,
                      ),
                    ),
                  ),
                  // Sidebar items
                  Expanded(
                    child: ListView.builder(
                      itemCount: _navItems.length,
                      itemBuilder: (context, i) {
                        final item = _navItems[i];
                        final isSelected = _currentIndex == i;
                        final isRecord = i == 2;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          child: InkWell(
                            onTap: () => setState(() => _currentIndex = i),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isRecord ? RuchaTheme.accentRed.withOpacity(0.18) : RuchaTheme.accentGreen.withOpacity(0.18))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? (isRecord ? RuchaTheme.accentRed : RuchaTheme.accentGreen)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 18,
                                    color: isSelected
                                        ? (isRecord ? RuchaTheme.accentRed : RuchaTheme.accentGreen)
                                        : RuchaTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : RuchaTheme.textSecondary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    item.amharic,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected ? RuchaTheme.accentGold : RuchaTheme.textSecondary.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Sidebar footer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: RuchaTheme.border)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: RuchaTheme.accentGreen),
                        SizedBox(width: 8),
                        Text(
                          'RUCHA Desktop v1.0.0 (Linux)',
                          style: TextStyle(fontSize: 10, color: RuchaTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout: 5 primary bottom nav tabs with 'More' drawer for full access
    const mobileIndices = [0, 1, 2, 3, 8]; // Home, Explore, Record, Log, Profile
    final mobileSelectedIdx = mobileIndices.indexOf(_currentIndex);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: mobileSelectedIdx >= 0 ? mobileSelectedIdx : 4,
        onTap: (mIndex) {
          setState(() {
            _currentIndex = mobileIndices[mIndex];
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: RuchaTheme.accentGreen,
        unselectedItemColor: RuchaTheme.textSecondary,
        backgroundColor: RuchaTheme.surface,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill, size: 20),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass, size: 20),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_button_checked, size: 24, color: RuchaTheme.accentCoral),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet, size: 20),
            label: 'Log',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_fill, size: 20),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
