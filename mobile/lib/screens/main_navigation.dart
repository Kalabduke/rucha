import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'explore_screen.dart';
import 'record_screen.dart';
import 'activities_screen.dart';
import 'gallery_screen.dart';
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
      ActivitiesScreen(onStartRecording: () => setState(() => _currentIndex = 2)),
      const GalleryScreen(),
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
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill, size: 19),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass, size: 19),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_button_checked, size: 21),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet, size: 19),
            label: 'Log',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.photo_on_rectangle, size: 19),
            label: 'Gallery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terrain, size: 19),
            label: 'Segments',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_3_fill, size: 19),
            label: 'Clubs',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.flag_fill, size: 19),
            label: 'Prizes',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_fill, size: 19),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
