import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class ClubItem {
  final String id;
  final String name;
  final String city;
  final String discipline; // 'run' or 'ride'
  final int memberCount;
  final String description;
  bool isJoined;

  ClubItem({
    required this.id,
    required this.name,
    required this.city,
    required this.discipline,
    required this.memberCount,
    required this.description,
    this.isJoined = false,
  });
}

class FeedItem {
  final String athleteName;
  final String city;
  final String timeAgo;
  final String title;
  final double distance;
  final int duration;
  final double elevation;
  int kudosCount;
  bool hasGivenKudos;

  FeedItem({
    required this.athleteName,
    required this.city,
    required this.timeAgo,
    required this.title,
    required this.distance,
    required this.duration,
    required this.elevation,
    this.kudosCount = 0,
    this.hasGivenKudos = false,
  });
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<ClubItem> _clubs = [
    ClubItem(
      id: 'c1',
      name: 'Entoto Trail Striders',
      city: 'Addis Ababa',
      discipline: 'run',
      memberCount: 348,
      description: 'High-altitude weekend distance runs on the Entoto eucalyptus paths.',
      isJoined: true,
    ),
    ClubItem(
      id: 'c2',
      name: 'Bole Peloton Cycling Club',
      city: 'Addis Ababa',
      discipline: 'ride',
      memberCount: 192,
      description: 'Morning pacelines, criteriums, and Sunday endurance rides.',
    ),
    ClubItem(
      id: 'c3',
      name: 'Hawassa Lakeside Runners',
      city: 'Hawassa',
      discipline: 'run',
      memberCount: 154,
      description: 'Scenic recovery runs and sunrise tempo sessions along Lake Hawassa.',
    ),
  ];

  final List<FeedItem> _feed = [
    FeedItem(
      athleteName: 'Abebe B.',
      city: 'Addis Ababa',
      timeAgo: '2h ago',
      title: 'Sunrise Ridge Tempo Run',
      distance: 12.4,
      duration: 3480,
      elevation: 240,
      kudosCount: 14,
    ),
    FeedItem(
      athleteName: 'Selamawit T.',
      city: 'Entoto',
      timeAgo: '4h ago',
      title: 'Hill Repeats (+420m)',
      distance: 8.6,
      duration: 2700,
      elevation: 420,
      kudosCount: 22,
    ),
    FeedItem(
      athleteName: 'Dawit M.',
      city: 'Bishoftu',
      timeAgo: 'Yesterday',
      title: 'Lake Bishoftu Century Loop',
      distance: 42.0,
      duration: 5400,
      elevation: 310,
      kudosCount: 39,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: RuchaTheme.accentGreen,
          indicatorWeight: 3,
          labelColor: RuchaTheme.textPrimary,
          unselectedLabelColor: RuchaTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Social Feed'),
            Tab(text: 'Athletic Clubs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Feed Tab
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _feed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final item = _feed[idx];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RuchaTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RuchaTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Athlete Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: RuchaTheme.accentGreen,
                          child: Text(
                            item.athleteName[0],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.athleteName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('${item.city} · ${item.timeAgo}', style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),

                    // Stats Bar
                    Row(
                      children: [
                        _feedMetric('DISTANCE', '${item.distance.toStringAsFixed(1)} km'),
                        _feedMetric('TIME', RuchaConstants.formatDuration(item.duration)),
                        _feedMetric('ELEVATION', '+${item.elevation.round()} m'),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Kudos Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (item.hasGivenKudos) {
                                item.hasGivenKudos = false;
                                item.kudosCount--;
                              } else {
                                item.hasGivenKudos = true;
                                item.kudosCount++;
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                item.hasGivenKudos ? CupertinoIcons.hand_thumbsup_fill : CupertinoIcons.hand_thumbsup,
                                size: 16,
                                color: item.hasGivenKudos ? RuchaTheme.accentCoral : RuchaTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item.kudosCount} Kudos',
                                style: TextStyle(
                                  color: item.hasGivenKudos ? RuchaTheme.accentCoral : RuchaTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(CupertinoIcons.share, size: 16, color: RuchaTheme.textSecondary),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Clubs Tab
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _clubs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final c = _clubs[idx];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RuchaTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RuchaTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.discipline == 'run'
                                ? RuchaTheme.accentCoral.withOpacity(0.15)
                                : RuchaTheme.accentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.discipline.toUpperCase(),
                            style: TextStyle(
                              color: c.discipline == 'run' ? RuchaTheme.accentCoral : RuchaTheme.accentGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${c.memberCount} members',
                          style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(c.city, style: const TextStyle(color: RuchaTheme.accentGold, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(c.description, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            c.isJoined = !c.isJoined;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          foregroundColor: c.isJoined ? RuchaTheme.accentGreen : RuchaTheme.textPrimary,
                          side: BorderSide(color: c.isJoined ? RuchaTheme.accentGreen : RuchaTheme.border),
                        ),
                        child: Text(
                          c.isJoined ? 'Joined' : 'Join Club',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _feedMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}
