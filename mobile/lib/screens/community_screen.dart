import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

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

  // Search state for Finding Friends by Username
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<User> _searchResults = [];
  bool _isSearching = false;
  final Set<String> _sentRequests = {};

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
    ClubItem(
      id: 'c4',
      name: 'Bekoji Running Town Cadets',
      city: 'Bekoji',
      discipline: 'run',
      memberCount: 220,
      description: 'Future Olympic hopefuls and distance specialists at 2,810m elevation.',
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

  // Default featured athletes to show when search is empty
  final List<User> _featuredAthletes = [
    User(
      id: 'f1',
      username: 'haile_g',
      displayName: 'Haile Gebrselassie',
      city: 'Addis Ababa',
      createdAt: '2026-01-01',
    ),
    User(
      id: 'f2',
      username: 'kenenisa_b',
      displayName: 'Kenenisa Bekele',
      city: 'Bekoji · Sululta',
      createdAt: '2026-01-01',
    ),
    User(
      id: 'f3',
      username: 'derartu_t',
      displayName: 'Derartu Tulu',
      city: 'Bekoji',
      createdAt: '2026-01-01',
    ),
    User(
      id: 'f4',
      username: 'tirunesh_d',
      displayName: 'Tirunesh Dibaba',
      city: 'Addis Ababa',
      createdAt: '2026-01-01',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final auth = Provider.of<AuthService>(context, listen: false);
      final results = await auth.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _sendFriendRequest(String username) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() => _sentRequests.add(username));
    final ok = await auth.sendFriendRequest(username);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Friend request sent to @$username! 🇪🇹' : 'Request sent! 🇪🇹'),
        duration: const Duration(seconds: 2),
        backgroundColor: RuchaTheme.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentGreen)),
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentGold)),
                Expanded(child: Container(height: 2.5, color: RuchaTheme.accentRed)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Community', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: RuchaTheme.accentGreen,
          indicatorWeight: 3,
          labelColor: RuchaTheme.textPrimary,
          unselectedLabelColor: RuchaTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Social Feed'),
            Tab(text: 'Find Friends'),
            Tab(text: 'Athletic Clubs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Feed Tab
          _buildFeedTab(),

          // 2. Find Friends Tab (Search by unique username)
          _buildFindFriendsTab(),

          // 3. Clubs Tab
          _buildClubsTab(),
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    return ListView.separated(
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
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: RuchaTheme.accentGreen,
                    radius: 18,
                    child: Text(
                      item.athleteName.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.athleteName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('${item.city} · ${item.timeAgo}', style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _feedMetric('DISTANCE', '${item.distance.toStringAsFixed(1)} km'),
                  _feedMetric('TIME', RuchaConstants.formatDuration(item.duration)),
                  _feedMetric('ELEV GAIN', '+${item.elevation.round()} m'),
                ],
              ),
              const Divider(color: RuchaTheme.border, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (!item.hasGivenKudos) {
                          item.kudosCount++;
                          item.hasGivenKudos = true;
                        } else {
                          item.kudosCount--;
                          item.hasGivenKudos = false;
                        }
                      });
                    },
                    icon: Icon(
                      item.hasGivenKudos ? CupertinoIcons.flame_fill : CupertinoIcons.flame,
                      size: 18,
                      color: item.hasGivenKudos ? RuchaTheme.accentCoral : RuchaTheme.textSecondary,
                    ),
                    label: Text(
                      item.hasGivenKudos ? 'Kudos given' : 'Give Kudos',
                      style: TextStyle(
                        color: item.hasGivenKudos ? RuchaTheme.accentCoral : RuchaTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${item.kudosCount} kudos',
                    style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 2. FIND FRIENDS BY UNIQUE USERNAME
  Widget _buildFindFriendsTab() {
    final query = _searchController.text.trim();
    final displayedList = query.isNotEmpty ? _searchResults : _featuredAthletes;

    return Column(
      children: [
        // Search Header Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            color: RuchaTheme.surface,
            border: Border(bottom: BorderSide(color: RuchaTheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: RuchaTheme.accentGreen),
                  hintText: 'Search friends by @username...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: RuchaTheme.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: RuchaTheme.textSecondary),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                query.isNotEmpty
                    ? 'Search results for "@$query"'
                    : 'Search any runner by their username to add them as friend',
                style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),

        // Results or Loading Indicator
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: RuchaTheme.accentGreen),
              ),
            ),
          )
        else if (query.isNotEmpty && displayedList.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Icon(CupertinoIcons.person_crop_circle_badge_exclam, size: 48, color: RuchaTheme.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'No athlete found with username "@$query"',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Make sure the username is typed correctly, or share your own username so they can find you!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: displayedList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final user = displayedList[idx];
                final isSent = _sentRequests.contains(user.username);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: RuchaTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: RuchaTheme.accentGreen.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: RuchaTheme.accentGreen.withOpacity(0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user.displayName.isNotEmpty ? user.displayName.substring(0, 1) : '@',
                          style: const TextStyle(color: RuchaTheme.accentGreen, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName.isNotEmpty ? user.displayName : user.username,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user.username}',
                              style: const TextStyle(color: RuchaTheme.accentGold, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            if (user.city.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                user.city,
                                style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: isSent ? null : () => _sendFriendRequest(user.username),
                        icon: Icon(isSent ? CupertinoIcons.checkmark_alt : CupertinoIcons.person_badge_plus, size: 14),
                        label: Text(isSent ? 'Sent' : 'Add Friend'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSent ? RuchaTheme.surface2 : RuchaTheme.accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// 3. ATHLETIC CLUBS
  Widget _buildClubsTab() {
    return ListView.separated(
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
                      color: c.discipline == 'run' ? RuchaTheme.accentGreen.withOpacity(0.15) : RuchaTheme.accentGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.discipline.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: c.discipline == 'run' ? RuchaTheme.accentGreen : RuchaTheme.accentGold,
                      ),
                    ),
                  ),
                  Text('${c.memberCount} athletes', style: const TextStyle(color: RuchaTheme.textSecondary, fontSize: 11)),
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
