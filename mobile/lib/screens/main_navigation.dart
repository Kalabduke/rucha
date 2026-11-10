import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/tracking_service.dart';
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
    _NavItem(CupertinoIcons.person_3_fill, 'Community', 'ማህበረሰብ'),
    _NavItem(CupertinoIcons.flag_fill, 'Challenges', 'ሽልማቶች'),
    _NavItem(CupertinoIcons.person_fill, 'Profile', 'መገለጫ'),
  ];

  void _showMoreHubSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: RuchaTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Text('RUCHA Hub', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
                    SizedBox(width: 8),
                    Text('የሩጫ ክፍሎች', style: TextStyle(color: RuchaTheme.accentGold, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),

                // Grid of options
                Row(
                  children: [
                    Expanded(
                      child: _buildHubSheetItem(
                        icon: CupertinoIcons.photo_on_rectangle,
                        color: RuchaTheme.accentCoral,
                        title: 'Run Card Gallery',
                        sub: 'ጋለሪ ስቱዲዮ',
                        index: 4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHubSheetItem(
                        icon: Icons.terrain,
                        color: RuchaTheme.accentGreen,
                        title: 'Segments & KOMs',
                        sub: 'የተራራ ክፍሎች',
                        index: 5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildHubSheetItem(
                        icon: CupertinoIcons.flag_fill,
                        color: RuchaTheme.accentGold,
                        title: 'Challenges & Prizes',
                        sub: 'ውድድሮችና ሽልማቶች',
                        index: 7,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHubSheetItem(
                        icon: CupertinoIcons.list_bullet,
                        color: Colors.blueAccent,
                        title: 'Training Log',
                        sub: 'የሩጫ ታሪክ',
                        index: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHubSheetItem(
                  icon: CupertinoIcons.person_fill,
                  color: Colors.purpleAccent,
                  title: 'Athlete Profile & Settings',
                  sub: 'የግል መገለጫና ማስተካከያ',
                  index: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHubSheetItem({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        setState(() => _currentIndex = index);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : RuchaTheme.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : RuchaTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isSelected ? Colors.white : RuchaTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? color : RuchaTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final auth = context.watch<AuthService>();
    final isRecording = tracking.status == RecordingStatus.running;

    final screens = [
      DashboardScreen(
        onStartRecording: () => setState(() => _currentIndex = 2),
        onNavigateTo: (idx) => setState(() => _currentIndex = idx),
      ),
      const ExploreScreen(),
      const RecordScreen(),
      ActivitiesScreen(onStartRecording: () => setState(() => _currentIndex = 2)),
      const GalleryScreen(),
      const SegmentsScreen(),
      const CommunityScreen(),
      ChallengesScreen(onStartRecording: () => setState(() => _currentIndex = 2)),
      const ProfileScreen(),
    ];

    final isWide = MediaQuery.of(context).size.width >= 768;

    if (isWide) {
      // Desktop Sidebar layout (Fedora Linux, wide screens)
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
                                    fontSize: 9,
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
                  const Divider(height: 1, color: RuchaTheme.border),
                  // Sidebar navigation items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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

    // Mobile layout: Complete navigation with Top Tricolor App Bar, Navigation Drawer, and 5-item Bottom Bar with 'More' Hub!
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: RuchaTheme.accentGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(CupertinoIcons.flame_fill, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'RUCHA',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _navItems[_currentIndex].label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: RuchaTheme.accentGreen),
                    ),
                  ],
                ),
                Text(
                  _navItems[_currentIndex].amharic,
                  style: const TextStyle(fontSize: 10, color: RuchaTheme.accentGold, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: Row(
            children: [
              Expanded(child: Container(height: 3, color: RuchaTheme.accentGreen)),
              Expanded(child: Container(height: 3, color: RuchaTheme.accentGold)),
              Expanded(child: Container(height: 3, color: RuchaTheme.accentRed)),
            ],
          ),
        ),
        actions: [
          if (isRecording)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: InkWell(
                onTap: () => setState(() => _currentIndex = 2),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RuchaTheme.accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: RuchaTheme.accentRed),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: RuchaTheme.accentRed),
                      SizedBox(width: 5),
                      Text('LIVE', style: TextStyle(color: RuchaTheme.accentRed, fontWeight: FontWeight.w900, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(CupertinoIcons.person_crop_circle, size: 24),
            tooltip: 'Profile',
            onPressed: () => setState(() => _currentIndex = 8),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: RuchaTheme.surface,
        child: Column(
          children: [
            // Drawer Header with Ethiopian Flag Strip & User Info
            Container(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              decoration: const BoxDecoration(
                color: RuchaTheme.surface2,
                border: Border(bottom: BorderSide(color: RuchaTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flag Strip
                  Row(
                    children: [
                      Expanded(child: Container(height: 3, color: RuchaTheme.accentGreen)),
                      Expanded(child: Container(height: 3, color: RuchaTheme.accentGold)),
                      Expanded(child: Container(height: 3, color: RuchaTheme.accentRed)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: RuchaTheme.accentGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.flame_fill, size: 22, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.currentUser?.displayName ?? 'RUCHA Athlete',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@${auth.currentUser?.username ?? "athlete"}',
                              style: const TextStyle(color: RuchaTheme.accentGold, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Drawer List of all 9 items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _navItems.length,
                itemBuilder: (context, i) {
                  final item = _navItems[i];
                  final isSelected = _currentIndex == i;
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected ? RuchaTheme.accentGreen : RuchaTheme.textSecondary,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : RuchaTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Text(
                      item.amharic,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? RuchaTheme.accentGold : RuchaTheme.textSecondary.withOpacity(0.6),
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: RuchaTheme.accentGreen.withOpacity(0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = i);
                    },
                  );
                },
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: RuchaTheme.border)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, size: 8, color: RuchaTheme.accentGreen),
                  SizedBox(width: 8),
                  Text('RUCHA · የኢትዮጵያ ሩጫ', style: TextStyle(fontSize: 11, color: RuchaTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex == 0
            ? 0
            : _currentIndex == 1
                ? 1
                : _currentIndex == 2
                    ? 2
                    : _currentIndex == 6
                        ? 3
                        : 4, // 4 = More Hub
        onTap: (bIndex) {
          if (bIndex == 0) {
            setState(() => _currentIndex = 0);
          } else if (bIndex == 1) {
            setState(() => _currentIndex = 1);
          } else if (bIndex == 2) {
            setState(() => _currentIndex = 2);
          } else if (bIndex == 3) {
            setState(() => _currentIndex = 6); // Community
          } else if (bIndex == 4) {
            _showMoreHubSheet(); // More Sheet gives 1-tap access to Gallery, Segments, Challenges, Log, Profile
          }
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
            icon: Icon(CupertinoIcons.person_3_fill, size: 20),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded, size: 20),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
