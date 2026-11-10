import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'explore_screen.dart';
import 'record_screen.dart';
import 'segments_screen.dart';
import 'community_screen.dart';
import 'challenges_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onStartRecording: () => setState(() => _currentIndex = 2)),
      const ExploreScreen(),
      const RecordScreen(),
      const SegmentsScreen(),
      const CommunityScreen(),
      const ChallengesScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill, size: 20),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass, size: 20),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_button_checked, size: 22),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terrain, size: 20),
            label: 'Segments',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_3_fill, size: 20),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.flag_fill, size: 20),
            label: 'Challenges',
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
