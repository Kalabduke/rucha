import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/challenge.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ─── Main community screen ───────────────────────────────────────────────────

class CommunityScreen extends StatefulWidget {
  final VoidCallback? onStartRecording;
  const CommunityScreen({super.key, this.onStartRecording});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // communities
  List<Club> _clubs = [];
  bool _clubsLoading = true;

  // global challenges visible in community feed
  List<Challenge> _challenges = [];
  bool _challengesLoading = true;

  // friends
  List<User> _friends = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  bool _friendsLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadClubs(), _loadChallenges(), _loadFriends()]);
  }

  Future<void> _loadChallenges() async {
    final auth = context.read<AuthService>();
    if (!auth.serverOnline) {
      if (mounted) setState(() => _challengesLoading = false);
      return;
    }
    final challenges = await context.read<ApiService>().fetchChallenges();
    if (!mounted) return;
    setState(() {
      _challenges = challenges
          .where((c) => c.visibility == 'everyone' || c.visibility == 'public')
          .toList();
      _challengesLoading = false;
    });
  }

  Future<void> _loadClubs() async {
    final auth = context.read<AuthService>();
    if (!auth.serverOnline) {
      if (mounted) setState(() => _clubsLoading = false);
      return;
    }
    final clubs = await context.read<ApiService>().fetchClubs();
    if (!mounted) return;
    setState(() {
      _clubs = clubs;
      _clubsLoading = false;
    });
  }

  Future<void> _loadFriends() async {
    final auth = context.read<AuthService>();
    if (!auth.serverOnline || auth.isGuest || auth.isLocalAccount) {
      if (mounted) setState(() => _friendsLoading = false);
      return;
    }
    final state = await auth.friendState();
    if (!mounted) return;
    final List rawFriends = (state?['friends'] as List?) ?? [];
    final List rawIncoming = (state?['incoming'] as List?) ?? [];
    final List rawOutgoing = (state?['outgoing'] as List?) ?? [];
    setState(() {
      _friends = rawFriends
          .whereType<Map>()
          .map((m) => User.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      _incoming = rawIncoming
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      _outgoing = rawOutgoing
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      _friendsLoading = false;
    });
  }

  Future<void> _joinClub(Club club) async {
    final auth = context.read<AuthService>();
    if (!auth.serverOnline || auth.isGuest || auth.isLocalAccount) {
      _snack('Join communities with a RUCHA server account.');
      return;
    }
    final ok =
        await context.read<ApiService>().joinClub(club.id, leave: club.joined);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _clubs.indexWhere((c) => c.id == club.id);
        if (i >= 0) {
          final delta = club.joined ? -1 : 1;
          _clubs[i] = club.copyWith(
            joined: !club.joined,
            members: (club.members + delta).clamp(0, 999999),
          );
        }
      });
    }
    _snack(ok
        ? (club.joined ? 'Left ${club.name}.' : 'Joined ${club.name}.')
        : 'Could not update — check the server connection.');
  }

  Future<void> _respondFriend(String edgeId, String decision) async {
    final ok = await context
        .read<AuthService>()
        .respondFriendRequest(edgeId, decision);
    if (!mounted) return;
    if (ok) await _loadFriends();
    _snack(ok
        ? (decision == 'accept'
            ? 'Friend request accepted.'
            : 'Request declined.')
        : 'Could not respond — check the server connection.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: RuchaTheme.surface2,
      duration: const Duration(seconds: 3),
    ));
  }

  void _openCommunity(Club club) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CommunityDetailScreen(club: club),
    ));
  }

  void _openFriendDuels(User friend) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FriendDuelsScreen(friend: friend),
    ));
  }

  void _openCreateCommunity() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateCommunitySheet(
        onCreated: (club) {
          setState(() => _clubs.insert(0, club));
          _snack('${club.name} created!');
        },
      ),
    );
  }

  void _openCreateChallenge() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateChallengeSheet(
        onCreated: (challenge) {
          setState(() => _challenges.insert(0, challenge));
          _snack('Challenge "${challenge.title}" created!');
        },
      ),
    );
  }

  void _openFriendRequests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FriendRequestsSheet(
        incoming: _incoming,
        outgoing: _outgoing,
        onRespond: _respondFriend,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: RuchaTheme.accentGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCommunitiesCard(),
          const SizedBox(height: 20),
          _buildChallengesCard(),
          const SizedBox(height: 20),
          _buildFriendsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Communities card ────────────────────────────────────────────────────────

  Widget _buildCommunitiesCard() {
    final auth = context.watch<AuthService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMUNITIES',
                    style: TextStyle(
                      color: RuchaTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Find your crew or build your own.',
                    style: TextStyle(
                      color: RuchaTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            // Header buttons — Create Community + Create Challenge
            if (!auth.isGuest && !auth.isLocalAccount && auth.serverOnline)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openCreateChallenge,
                    icon: const Icon(Icons.emoji_events, size: 15),
                    label: const Text('Challenge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RuchaTheme.accentCoral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _openCreateCommunity,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Community'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RuchaTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Body
        if (!auth.serverOnline)
          _offlineCard(
            icon: CupertinoIcons.person_3,
            title: 'Communities need the RUCHA server',
            message:
                'Connect to find local crews, meet training partners and join your next challenge.',
          )
        else if (_clubsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CupertinoActivityIndicator(),
            ),
          )
        else if (_clubs.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: RuchaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: Column(
              children: [
                const Icon(CupertinoIcons.person_3,
                    size: 36, color: RuchaTheme.textSecondary),
                const SizedBox(height: 10),
                const Text(
                  'No communities yet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Be the first to create a community for your city.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                ),
                if (!auth.isGuest && !auth.isLocalAccount) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openCreateCommunity,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create a community'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: RuchaTheme.accentGreen),
                  ),
                ],
              ],
            ),
          )
        else
          ...(_clubs.length > 5 ? _clubs.sublist(0, 5) : _clubs)
              .map(_buildClubCard),
      ],
    );
  }

  Widget _buildClubCard(Club club) {
    final auth = context.read<AuthService>();
    final isOwner = auth.currentUser?.id == club.ownerId;
    final accent = _clubAccent(club.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openCommunity(club),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // colour dot + type icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_clubIcon(club.type), color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                club.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Visibility badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: club.visibility == 'friends'
                                    ? RuchaTheme.accentGold
                                        .withValues(alpha: 0.15)
                                    : RuchaTheme.accentGreen
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: club.visibility == 'friends'
                                      ? RuchaTheme.accentGold
                                          .withValues(alpha: 0.5)
                                      : RuchaTheme.accentGreen
                                          .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                club.visibility == 'friends'
                                    ? 'Friends'
                                    : 'Public',
                                style: TextStyle(
                                  color: club.visibility == 'friends'
                                      ? RuchaTheme.accentGold
                                      : RuchaTheme.accentGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (club.city.isNotEmpty) club.city,
                            '${club.members} member${club.members == 1 ? '' : 's'}',
                            if (club.ownerName.isNotEmpty)
                              'by @${club.ownerName}',
                          ].join(' · '),
                          style: const TextStyle(
                            color: RuchaTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.chevron_right,
                      size: 14, color: RuchaTheme.textSecondary),
                ],
              ),
              if (club.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  club.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  // Open button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openCommunity(club),
                      icon: const Icon(CupertinoIcons.arrow_right, size: 13),
                      label: Text(isOwner ? 'Manage' : 'Open'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RuchaTheme.textPrimary,
                        side: const BorderSide(color: RuchaTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Join / Leave button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _joinClub(club),
                      icon: Icon(
                        club.joined
                            ? CupertinoIcons.checkmark_alt
                            : Icons.group_add,
                        size: 14,
                      ),
                      label: Text(club.joined ? 'Joined' : 'Join'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: club.joined
                            ? RuchaTheme.accentGreen.withValues(alpha: 0.18)
                            : RuchaTheme.accentGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Challenges card ──────────────────────────────────────────────────────────

  Widget _buildChallengesCard() {
    final auth = context.watch<AuthService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CHALLENGES',
                      style: TextStyle(
                          color: RuchaTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  SizedBox(height: 2),
                  Text('Compete with the community.',
                      style: TextStyle(
                          color: RuchaTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (!auth.serverOnline)
          _offlineCard(
            icon: Icons.emoji_events,
            title: 'Challenges need the RUCHA server',
            message: 'Connect to see and join community challenges.',
          )
        else if (_challengesLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CupertinoActivityIndicator()))
        else if (_challenges.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: RuchaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: const Column(
              children: [
                Icon(Icons.emoji_events,
                    size: 36, color: RuchaTheme.textSecondary),
                SizedBox(height: 10),
                Text('No public challenges yet',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                SizedBox(height: 4),
                Text('Be the first to create a challenge for the community.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: RuchaTheme.textSecondary, fontSize: 12)),
              ],
            ),
          )
        else
          ...(_challenges.take(5).map(_buildChallengeCard)),
      ],
    );
  }

  Widget _buildChallengeCard(Challenge c) {
    final accent = c.visibility == 'friends'
        ? RuchaTheme.accentGold
        : RuchaTheme.accentCoral;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _ChallengeDetailScreen(challenge: c),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.emoji_events, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.visibility == 'friends'
                                    ? '👥 Friends'
                                    : '🌍 Public',
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (c.targetKm != null) ...[
                              const SizedBox(width: 6),
                              Text('${c.targetKm!.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                      color: RuchaTheme.textSecondary,
                                      fontSize: 11)),
                            ],
                            if (c.createdBy != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('by @${c.createdBy}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: RuchaTheme.textSecondary,
                                        fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right,
                      size: 14, color: RuchaTheme.textSecondary),
                ],
              ),
              if (c.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(c.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Friends card ─────────────────────────────────────────────────────────────

  Widget _buildFriendsCard() {
    final auth = context.watch<AuthService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row with Friend Requests button
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FRIENDS',
                    style: TextStyle(
                      color: RuchaTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your training partners.',
                    style: TextStyle(
                      color: RuchaTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            // Friend requests button with badge
            InkWell(
              onTap: _openFriendRequests,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _incoming.isNotEmpty
                      ? RuchaTheme.accentCoral.withValues(alpha: 0.15)
                      : RuchaTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _incoming.isNotEmpty
                        ? RuchaTheme.accentCoral.withValues(alpha: 0.5)
                        : RuchaTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.person_badge_plus,
                      size: 16,
                      color: _incoming.isNotEmpty
                          ? RuchaTheme.accentCoral
                          : RuchaTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Requests',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _incoming.isNotEmpty
                            ? RuchaTheme.accentCoral
                            : RuchaTheme.textSecondary,
                      ),
                    ),
                    if (_incoming.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: RuchaTheme.accentCoral,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_incoming.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Body
        if (!auth.serverOnline)
          _offlineCard(
            icon: CupertinoIcons.person_2,
            title: "You're offline · recording still works",
            message:
                'Connect to find training partners and accept friend requests.',
          )
        else if (_friendsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CupertinoActivityIndicator(),
            ),
          )
        else if (_friends.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: RuchaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RuchaTheme.border),
            ),
            child: Column(
              children: [
                const Icon(CupertinoIcons.person_2,
                    size: 36, color: RuchaTheme.textSecondary),
                const SizedBox(height: 10),
                const Text(
                  'No friends yet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Search for athletes by username and send a friend request.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: RuchaTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ..._friends.map(_buildFriendCard),
      ],
    );
  }

  Widget _buildFriendCard(User friend) {
    final initial = friend.displayName.isNotEmpty
        ? friend.displayName[0].toUpperCase()
        : '@';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openFriendDuels(friend),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: RuchaTheme.accentGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: RuchaTheme.accentGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName.isNotEmpty
                          ? friend.displayName
                          : friend.username,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '@${friend.username}',
                      style: const TextStyle(
                        color: RuchaTheme.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (friend.city.isNotEmpty)
                      Text(
                        friend.city,
                        style: const TextStyle(
                            color: RuchaTheme.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              ),
              // "View duels" hint
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(CupertinoIcons.bolt_horizontal_fill,
                      size: 14, color: RuchaTheme.accentGold),
                  const SizedBox(height: 2),
                  const Text(
                    'Duels',
                    style: TextStyle(
                        color: RuchaTheme.textSecondary, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.chevron_right,
                  size: 14, color: RuchaTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────

  Widget _offlineCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: RuchaTheme.textSecondary),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: RuchaTheme.textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh, size: 14),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: RuchaTheme.accentGreen,
              side: const BorderSide(color: RuchaTheme.accentGreen),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top-level helpers used by detail screens ─────────────────────────────────

Color _clubAccent(String type) {
  switch (type) {
    case 'ride':
      return RuchaTheme.accentGreen;
    case 'walk':
      return RuchaTheme.accentGold;
    case 'mixed':
      return RuchaTheme.accent;
    default:
      return RuchaTheme.accent;
  }
}

IconData _clubIcon(String type) {
  switch (type) {
    case 'ride':
      return Icons.directions_bike;
    case 'walk':
      return Icons.directions_walk;
    case 'mixed':
      return CupertinoIcons.person_3_fill;
    default:
      return Icons.directions_run;
  }
}

class _CommunityDetailScreen extends StatefulWidget {
  final Club club;
  const _CommunityDetailScreen({required this.club});

  @override
  State<_CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<_CommunityDetailScreen> {
  List<Challenge> _approved = [];
  List<Challenge> _pending = [];
  Map<String, String> _members = {};
  bool _loading = true;

  late Club _club;

  @override
  void initState() {
    super.initState();
    _club = widget.club;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    final challenges = await api.fetchClubChallenges(_club.id);
    final members = await api.fetchClubMembers(_club.id);
    if (!mounted) return;
    setState(() {
      _approved = challenges.where((c) => !c.pendingApproval).toList();
      _pending = challenges.where((c) => c.pendingApproval).toList();
      _members = members;
      _loading = false;
    });
  }

  Future<void> _respondChallenge(Challenge c, String decision) async {
    final ok =
        await context.read<ApiService>().respondChallenge(c.id, decision);
    if (!mounted) return;
    if (ok) await _load();
    _snack(ok
        ? (decision == 'approve'
            ? 'Challenge approved.'
            : 'Challenge declined.')
        : 'Could not respond — check your connection.');
  }

  void _openChallenge(Challenge c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ChallengeDetailScreen(challenge: c),
    ));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: RuchaTheme.surface2),
    );
  }

  bool get _isOwnerOrAdmin {
    final auth = context.read<AuthService>();
    return auth.currentUser?.id == _club.ownerId;
  }

  // Admin: toggle whether members can submit challenges to this community
  Future<void> _toggleChallengesDisabled() async {
    final updated =
        _club.copyWith(challengesDisabled: !_club.challengesDisabled);
    final ok = await context.read<ApiService>().updateClub(updated);
    if (!mounted) return;
    if (ok) {
      setState(() => _club = updated);
      _snack(_club.challengesDisabled
          ? 'Community challenge submissions disabled.'
          : 'Community challenge submissions re-enabled.');
    } else {
      _snack('Could not update — check your connection.');
    }
  }

  void _openSubmitCommunityChallenge() {
    if (_club.challengesDisabled && !_isOwnerOrAdmin) {
      _snack('The community admin has disabled challenge submissions.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateChallengeSheet(
        communityId: _club.id,
        communityName: _club.name,
        onCreated: (c) {
          setState(() => _pending.add(c));
          _snack('Submitted "${c.title}" for admin approval.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _clubAccent(_club.type);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubmitCommunityChallenge,
        backgroundColor: _club.challengesDisabled && !_isOwnerOrAdmin
            ? RuchaTheme.textSecondary
            : RuchaTheme.accentCoral,
        foregroundColor: Colors.white,
        icon: const Icon(CupertinoIcons.flag_fill, size: 18),
        label: const Text('Submit Challenge',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _club.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            Text(
              [
                if (_club.city.isNotEmpty) _club.city,
                '${_club.members} member${_club.members == 1 ? '' : 's'}',
              ].join(' · '),
              style: const TextStyle(
                  color: RuchaTheme.textSecondary, fontSize: 10),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Row(children: [
            Expanded(
                child: Container(height: 3, color: RuchaTheme.accentGreen)),
            Expanded(child: Container(height: 3, color: RuchaTheme.accentGold)),
            Expanded(child: Container(height: 3, color: RuchaTheme.accentRed)),
          ]),
        ),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              color: RuchaTheme.accentGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Info strip
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(_clubIcon(_club.type), color: accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _club.type.toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              if (_club.description.isNotEmpty)
                                Text(
                                  _club.description,
                                  style: const TextStyle(
                                    color: RuchaTheme.textSecondary,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _club.visibility == 'friends'
                                ? RuchaTheme.accentGold.withValues(alpha: 0.15)
                                : RuchaTheme.accentGreen
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _club.visibility == 'friends'
                                ? 'Friends only'
                                : 'Public',
                            style: TextStyle(
                              color: _club.visibility == 'friends'
                                  ? RuchaTheme.accentGold
                                  : RuchaTheme.accentGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Admin controls strip ──────────────────────────────────
                  if (_isOwnerOrAdmin) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: RuchaTheme.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: RuchaTheme.border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.admin_panel_settings_rounded,
                            size: 16, color: RuchaTheme.accentGold),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Allow challenge submissions',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700))),
                        Switch(
                          value: !(_club.challengesDisabled),
                          onChanged: (_) => _toggleChallengesDisabled(),
                          activeColor: RuchaTheme.accentGreen,
                        ),
                      ]),
                    ),
                  ],

                  // ── Challenges disabled banner (non-admin) ─────────────────
                  if (_club.challengesDisabled && !_isOwnerOrAdmin) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: RuchaTheme.accentRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: RuchaTheme.accentRed.withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(CupertinoIcons.xmark_circle,
                            size: 15, color: RuchaTheme.accentRed),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'The admin has disabled challenge submissions for this community.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: RuchaTheme.accentRed,
                                    height: 1.4))),
                      ]),
                    ),
                  ],

                  // ── Pending challenges (owner/admin only) ──────────────────
                  if (_isOwnerOrAdmin && _pending.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionHeader(
                      'PENDING APPROVAL',
                      icon: CupertinoIcons.clock,
                      color: RuchaTheme.accentGold,
                      count: _pending.length,
                    ),
                    const SizedBox(height: 8),
                    ..._pending.map((c) => _pendingChallengeCard(c)),
                  ],

                  // ── Approved challenges ────────────────────────────────────
                  const SizedBox(height: 20),
                  _sectionHeader(
                    'CHALLENGES',
                    icon: Icons.emoji_events,
                    color: RuchaTheme.accent,
                    count: _approved.length,
                  ),
                  const SizedBox(height: 8),
                  if (_approved.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: RuchaTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RuchaTheme.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.emoji_events,
                              size: 32, color: RuchaTheme.textSecondary),
                          SizedBox(height: 8),
                          Text('No challenges yet',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          SizedBox(height: 4),
                          Text(
                            'Community members can create challenges.\nThe owner approves them before they appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: RuchaTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._approved.map((c) => _approvedChallengeCard(c)),

                  // ── Members strip ──────────────────────────────────────────
                  if (_members.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionHeader(
                      'MEMBERS',
                      icon: CupertinoIcons.person_2_fill,
                      color: RuchaTheme.accentGreen,
                      count: _members.length,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: RuchaTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RuchaTheme.border),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _members.entries
                            .take(20)
                            .map((e) => _memberChip(e.value))
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String label,
      {required IconData icon, required Color color, required int count}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _pendingChallengeCard(Challenge c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RuchaTheme.accentGold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: RuchaTheme.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AWAITING APPROVAL',
                  style: TextStyle(
                    color: RuchaTheme.accentGold,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (c.createdBy != null)
                Text(
                  'by @${c.createdBy}',
                  style: const TextStyle(
                      color: RuchaTheme.textSecondary, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _respondChallenge(c, 'decline'),
                  icon: const Icon(CupertinoIcons.xmark, size: 13),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RuchaTheme.accentRed,
                    side: BorderSide(
                        color: RuchaTheme.accentRed.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _respondChallenge(c, 'approve'),
                  icon: const Icon(CupertinoIcons.checkmark_alt, size: 13),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RuchaTheme.accentGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _approvedChallengeCard(Challenge c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openChallenge(c),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RuchaTheme.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events,
                    color: RuchaTheme.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      _challengeMeta(c),
                      style: const TextStyle(
                          color: RuchaTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right,
                  size: 14, color: RuchaTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberChip(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RuchaTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RuchaTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: RuchaTheme.accentGreen.withValues(alpha: 0.3),
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: RuchaTheme.accentGreen)),
          ),
          const SizedBox(width: 6),
          Text(
            name.length > 14 ? '@${name.substring(0, 12)}…' : '@$name',
            style: const TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Challenge detail screen (leaderboard) ────────────────────────────────────

class _ChallengeDetailScreen extends StatefulWidget {
  final Challenge challenge;
  const _ChallengeDetailScreen({required this.challenge});

  @override
  State<_ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<_ChallengeDetailScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    _joined = widget.challenge.isJoined;
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loading = true);
    final rows =
        await context.read<ApiService>().fetchLeaderboard(widget.challenge.id);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _join() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final ok = await api.joinChallenge(
      widget.challenge.id,
      athleteId: auth.currentUser?.id,
      athleteName: auth.currentUser?.displayName,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _joined = true);
      await _loadLeaderboard();
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          ok ? 'Joined the challenge!' : 'Could not join — check the server.'),
      backgroundColor: RuchaTheme.surface2,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(c.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(
              c.kind.toUpperCase(),
              style: const TextStyle(
                  color: RuchaTheme.textSecondary, fontSize: 10),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Row(children: [
            Expanded(
                child: Container(height: 3, color: RuchaTheme.accentGreen)),
            Expanded(child: Container(height: 3, color: RuchaTheme.accentGold)),
            Expanded(child: Container(height: 3, color: RuchaTheme.accentRed)),
          ]),
        ),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              color: RuchaTheme.accentGreen,
              onRefresh: _loadLeaderboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Description card
                  if (c.description.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: RuchaTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RuchaTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.description,
                              style: const TextStyle(
                                  color: RuchaTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.45)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (c.targetKm != null)
                                _metaBadge(
                                    '${c.targetKm!.toStringAsFixed(1)} km',
                                    RuchaTheme.accentGreen),
                              if (c.targetTime != null)
                                _metaBadge(
                                    RuchaConstants.formatDuration(
                                        c.targetTime!),
                                    RuchaTheme.accentGold),
                              if (c.targetElev != null)
                                _metaBadge('+${c.targetElev!.round()} m',
                                    RuchaTheme.accent),
                              _metaBadge(c.kind, RuchaTheme.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Join button
                  if (!_joined)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: _join,
                        icon: const Icon(Icons.emoji_events, size: 16),
                        label: const Text('Join this challenge'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RuchaTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                  // Leaderboard
                  const Row(
                    children: [
                      Icon(Icons.emoji_events,
                          size: 15, color: RuchaTheme.accentGold),
                      SizedBox(width: 6),
                      Text(
                        'LEADERBOARD',
                        style: TextStyle(
                          color: RuchaTheme.accentGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_rows.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: RuchaTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RuchaTheme.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.emoji_events,
                              size: 32, color: RuchaTheme.textSecondary),
                          SizedBox(height: 8),
                          Text('No entries yet',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          SizedBox(height: 4),
                          Text(
                            'Join and record an activity to appear on the leaderboard.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: RuchaTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: RuchaTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RuchaTheme.border),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: const [
                                SizedBox(width: 28),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text('ATHLETE',
                                      style: TextStyle(
                                          color: RuchaTheme.textSecondary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5)),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text('RESULT',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          color: RuchaTheme.textSecondary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: RuchaTheme.border),
                          ..._rows.asMap().entries.map((entry) {
                            final i = entry.key;
                            final row = entry.value;
                            final isMe = row['me'] == true;
                            final rank =
                                (row['rank'] as num?)?.toInt() ?? (i + 1);
                            final name =
                                row['athleteName']?.toString() ?? 'Athlete';
                            final result = row['result']?.toString() ?? '—';
                            final completed = row['completed'] == true;

                            return Column(
                              children: [
                                if (i > 0)
                                  const Divider(
                                      height: 1, color: RuchaTheme.border),
                                Container(
                                  color: isMe
                                      ? RuchaTheme.accentGreen
                                          .withValues(alpha: 0.08)
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      // rank
                                      SizedBox(
                                        width: 28,
                                        child: Text(
                                          rank <= 3
                                              ? ['🥇', '🥈', '🥉'][rank - 1]
                                              : '$rank',
                                          style: TextStyle(
                                            fontSize: rank <= 3 ? 16 : 13,
                                            fontWeight: FontWeight.w800,
                                            color: isMe
                                                ? RuchaTheme.accentGreen
                                                : RuchaTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: TextStyle(
                                                  fontWeight: isMe
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isMe
                                                      ? RuchaTheme.accentGreen
                                                      : RuchaTheme.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: RuchaTheme.accentGreen
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'You',
                                                  style: TextStyle(
                                                    color:
                                                        RuchaTheme.accentGreen,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (completed) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                CupertinoIcons
                                                    .checkmark_seal_fill,
                                                size: 12,
                                                color: RuchaTheme.accentGold,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          result,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: completed
                                                ? RuchaTheme.accentGold
                                                : RuchaTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _metaBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Friend duels screen ──────────────────────────────────────────────────────

class _FriendDuelsScreen extends StatefulWidget {
  final User friend;
  const _FriendDuelsScreen({required this.friend});

  @override
  State<_FriendDuelsScreen> createState() => _FriendDuelsScreenState();
}

class _FriendDuelsScreenState extends State<_FriendDuelsScreen> {
  List<Challenge> _duels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await context.read<ApiService>().fetchChallenges();
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final myId = auth.currentUser?.id ?? '';
    // A duel is head_to_head with this friend as opponent or owner
    setState(() {
      _duels = all.where((c) {
        if (c.mode != 'head_to_head') return false;
        final friendId = widget.friend.id;
        return (c.opponentId == friendId || c.ownerId == friendId) ||
            (c.opponentId == myId || c.ownerId == myId);
      }).toList();
      _loading = false;
    });
  }

  void _openChallenge(Challenge c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ChallengeDetailScreen(challenge: c),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final initial = friend.displayName.isNotEmpty
        ? friend.displayName[0].toUpperCase()
        : '@';

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: RuchaTheme.accentGreen.withValues(alpha: 0.2),
              child: Text(initial,
                  style: const TextStyle(
                      color: RuchaTheme.accentGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  friend.displayName.isNotEmpty
                      ? friend.displayName
                      : friend.username,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15),
                ),
                Text('@${friend.username}',
                    style: const TextStyle(
                        color: RuchaTheme.accentGold, fontSize: 10)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Row(children: [
            Expanded(
                child: Container(height: 3, color: RuchaTheme.accentGreen)),
            Expanded(child: Container(height: 3, color: RuchaTheme.accentGold)),
            Expanded(child: Container(height: 3, color: RuchaTheme.accentRed)),
          ]),
        ),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile strip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RuchaTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RuchaTheme.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            RuchaTheme.accentGreen.withValues(alpha: 0.16),
                        child: Text(initial,
                            style: const TextStyle(
                                color: RuchaTheme.accentGreen,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friend.displayName.isNotEmpty
                                  ? friend.displayName
                                  : friend.username,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text('@${friend.username}',
                                style: const TextStyle(
                                    color: RuchaTheme.accentGold,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                            if (friend.city.isNotEmpty)
                              Text(friend.city,
                                  style: const TextStyle(
                                      color: RuchaTheme.textSecondary,
                                      fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Duels section
                Row(
                  children: [
                    const Icon(CupertinoIcons.bolt_horizontal_fill,
                        size: 15, color: RuchaTheme.accentGold),
                    const SizedBox(width: 6),
                    const Text(
                      'HEAD-TO-HEAD DUELS',
                      style: TextStyle(
                        color: RuchaTheme.accentGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: RuchaTheme.accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_duels.length}',
                          style: const TextStyle(
                              color: RuchaTheme.accentGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_duels.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: RuchaTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RuchaTheme.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.bolt_horizontal,
                            size: 32, color: RuchaTheme.textSecondary),
                        const SizedBox(height: 8),
                        Text(
                          'No duels with @${friend.username} yet',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Create a head-to-head challenge and invite this friend.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: RuchaTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ..._duels.map((c) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: RuchaTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  RuchaTheme.accentGold.withValues(alpha: 0.3)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openChallenge(c),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: RuchaTheme.accentGold
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      CupertinoIcons.bolt_horizontal_fill,
                                      color: RuchaTheme.accentGold,
                                      size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _challengeMeta(c),
                                        style: const TextStyle(
                                            color: RuchaTheme.textSecondary,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                // Invite status badge
                                if (c.inviteStatus.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _inviteColor(c.inviteStatus)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c.inviteStatus.toUpperCase(),
                                      style: TextStyle(
                                        color: _inviteColor(c.inviteStatus),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                const Icon(CupertinoIcons.chevron_right,
                                    size: 14, color: RuchaTheme.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      )),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  static Color _inviteColor(String status) {
    switch (status) {
      case 'accepted':
        return RuchaTheme.accentGreen;
      case 'declined':
        return RuchaTheme.accentRed;
      default:
        return RuchaTheme.accentGold;
    }
  }
}

// ─── Friend requests bottom sheet ────────────────────────────────────────────

class _FriendRequestsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> incoming;
  final List<Map<String, dynamic>> outgoing;
  final Future<void> Function(String edgeId, String decision) onRespond;

  const _FriendRequestsSheet({
    required this.incoming,
    required this.outgoing,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
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
            const Text(
              'Friend Requests',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  if (incoming.isNotEmpty) ...[
                    const Text(
                      'INCOMING',
                      style: TextStyle(
                        color: RuchaTheme.accentGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...incoming.map((edge) {
                      final edgeId = edge['id']?.toString() ?? '';
                      final name =
                          edge['requesterName']?.toString() ?? 'Athlete';
                      final initial =
                          name.isNotEmpty ? name[0].toUpperCase() : '?';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: RuchaTheme.surface2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: RuchaTheme.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: RuchaTheme.accentGreen
                                  .withValues(alpha: 0.16),
                              child: Text(initial,
                                  style: const TextStyle(
                                      color: RuchaTheme.accentGreen,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '@$name',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            // Decline
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onRespond(edgeId, 'decline');
                              },
                              icon: const Icon(CupertinoIcons.xmark,
                                  color: RuchaTheme.accentRed, size: 18),
                              tooltip: 'Decline',
                            ),
                            // Accept
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onRespond(edgeId, 'accept');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RuchaTheme.accentGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                textStyle: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                                elevation: 0,
                              ),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  if (outgoing.isNotEmpty) ...[
                    const Text(
                      'SENT',
                      style: TextStyle(
                        color: RuchaTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...outgoing.map((edge) {
                      final name =
                          edge['addresseeName']?.toString() ?? 'Athlete';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: RuchaTheme.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: RuchaTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.clock,
                                size: 15, color: RuchaTheme.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('@$name',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                            const Text('Pending',
                                style: TextStyle(
                                    color: RuchaTheme.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (incoming.isEmpty && outgoing.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: const [
                          Icon(CupertinoIcons.person_badge_plus,
                              size: 36, color: RuchaTheme.textSecondary),
                          SizedBox(height: 10),
                          Text(
                            'No pending requests',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Search for athletes by username to send a request.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: RuchaTheme.textSecondary, fontSize: 12),
                          ),
                        ],
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
}

// ─── Create community bottom sheet ───────────────────────────────────────────

class _CreateCommunitySheet extends StatefulWidget {
  final void Function(Club club) onCreated;
  const _CreateCommunitySheet({required this.onCreated});

  @override
  State<_CreateCommunitySheet> createState() => _CreateCommunitySheetState();
}

class _CreateCommunitySheetState extends State<_CreateCommunitySheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  String _city = 'Addis Ababa';
  String _type = 'run';
  String _visibility = 'public';
  String _joinPolicy = 'open';
  String _color = '#12A88A';
  bool _busy = false;
  String _error = '';

  static const _colors = [
    '#12A88A', // teal
    '#FF7A42', // coral
    '#F2B705', // gold
    '#E5484D', // red
    '#5E5CE6', // purple
    '#2AABEE', // telegram blue
    '#0B6E56', // dark green
    '#FF5A1F', // run orange
  ];

  static const _types = [
    ('run', 'Running', Icons.directions_run),
    ('walk', 'Walking', Icons.directions_walk),
    ('ride', 'Cycling', Icons.directions_bike),
    ('mixed', 'Mixed', CupertinoIcons.person_3_fill),
  ];

  static const _cities = [
    'Addis Ababa',
    'Bishoftu',
    'Hawassa',
    'Bahir Dar',
    'Gondar',
    'Mekelle',
    'Harar',
    'Bekoji',
    'Sululta',
    'Entoto Hills',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 3) {
      setState(() => _error = 'Community name must be at least 3 characters.');
      return;
    }
    if (name.length > 60) {
      setState(() => _error = 'Name must be 60 characters or fewer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final api = context.read<ApiService>();
    final club = await api.createClub({
      'name': name,
      'description': _descController.text.trim(),
      'city': _city,
      'type': _type,
      'visibility': _visibility,
      'joinPolicy': _joinPolicy,
      'color': _color,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (club != null) {
      Navigator.of(context).pop();
      widget.onCreated(club);
    } else {
      setState(() => _error =
          'Could not create the community. Check the server connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ListView(
          controller: controller,
          children: [
            // Handle
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
            // Title
            const Row(
              children: [
                Icon(CupertinoIcons.person_3_fill,
                    color: RuchaTheme.accentGreen, size: 22),
                SizedBox(width: 10),
                Text('Create a community',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 20),

            // Error
            if (_error.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RuchaTheme.accentRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: RuchaTheme.accentRed.withValues(alpha: 0.4)),
                ),
                child: Text(_error,
                    style: const TextStyle(
                        color: RuchaTheme.accentRed, fontSize: 13)),
              ),
              const SizedBox(height: 14),
            ],

            // Name
            _fieldLabel('Community name *'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'e.g. Entoto Trail Runners',
                prefixIcon: Icon(CupertinoIcons.person_3_fill, size: 18),
              ),
            ),
            const SizedBox(height: 14),

            // Description
            _fieldLabel('Description (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'What is this community about?',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Activity type
            _fieldLabel('Activity focus'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types.map((t) {
                final selected = _type == t.$1;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$3,
                          size: 14,
                          color: selected
                              ? Colors.white
                              : RuchaTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(t.$2),
                    ],
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t.$1),
                  selectedColor: RuchaTheme.accentGreen,
                  backgroundColor: RuchaTheme.surface2,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : RuchaTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                      color: selected
                          ? RuchaTheme.accentGreen
                          : RuchaTheme.border),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // City
            _fieldLabel('City'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: RuchaTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: RuchaTheme.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _city,
                  dropdownColor: RuchaTheme.surface2,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.arrow_drop_down,
                      color: RuchaTheme.textSecondary),
                  items: _cities
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _city = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Visibility
            _fieldLabel('Who can see this community?'),
            const SizedBox(height: 8),
            _toggleRow(
              optionA: ('Public', 'Anyone can find it', CupertinoIcons.globe),
              optionB: (
                'Friends only',
                'Only your friends',
                CupertinoIcons.lock
              ),
              selected: _visibility,
              valueA: 'public',
              valueB: 'friends',
              onChanged: (v) => setState(() => _visibility = v),
            ),
            const SizedBox(height: 14),

            // Join policy
            _fieldLabel('Who can join?'),
            const SizedBox(height: 8),
            _toggleRow(
              optionA: (
                'Anyone',
                'Join immediately',
                CupertinoIcons.person_add
              ),
              optionB: (
                'Approval',
                'You review requests',
                CupertinoIcons.checkmark_shield
              ),
              selected: _joinPolicy,
              valueA: 'open',
              valueB: 'approval',
              onChanged: (v) => setState(() => _joinPolicy = v),
            ),
            const SizedBox(height: 16),

            // Colour
            _fieldLabel('Community colour'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.map((hex) {
                final col = _hexColor(hex);
                final selected = _color == hex;
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: col.withValues(alpha: 0.5),
                                  blurRadius: 8)
                            ]
                          : [],
                    ),
                    child: selected
                        ? const Icon(CupertinoIcons.checkmark_alt,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Submit
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: RuchaTheme.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create community'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: RuchaTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _toggleRow({
    required (String label, String sub, IconData icon) optionA,
    required (String label, String sub, IconData icon) optionB,
    required String selected,
    required String valueA,
    required String valueB,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
            child: _toggleOption(
                optionA, selected == valueA, () => onChanged(valueA))),
        const SizedBox(width: 10),
        Expanded(
            child: _toggleOption(
                optionB, selected == valueB, () => onChanged(valueB))),
      ],
    );
  }

  Widget _toggleOption(
      (String, String, IconData) opt, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? RuchaTheme.accentGreen.withValues(alpha: 0.14)
              : RuchaTheme.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? RuchaTheme.accentGreen : RuchaTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(opt.$3,
                size: 18,
                color:
                    active ? RuchaTheme.accentGreen : RuchaTheme.textSecondary),
            const SizedBox(height: 6),
            Text(opt.$1,
                style: TextStyle(
                  color: active ? Colors.white : RuchaTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                )),
            Text(opt.$2,
                style: const TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 10,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }

  static Color _hexColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final val = int.tryParse(clean, radix: 16) ?? 0x12A88A;
    return Color(0xFF000000 | val);
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

String _challengeMeta(Challenge c) {
  final parts = <String>[];
  if (c.targetKm != null) parts.add('${c.targetKm!.toStringAsFixed(1)} km');
  if (c.targetTime != null)
    parts.add(RuchaConstants.formatDuration(c.targetTime!));
  if (c.targetElev != null) parts.add('+${c.targetElev!.round()} m');
  if (c.createdBy != null) parts.add('by @${c.createdBy}');
  return parts.join(' · ');
}

// ─── Create Challenge Sheet ───────────────────────────────────────────────────

class _CreateChallengeSheet extends StatefulWidget {
  final void Function(Challenge) onCreated;
  final String? communityId;
  final String? communityName;
  const _CreateChallengeSheet({
    required this.onCreated,
    this.communityId,
    this.communityName,
  });

  @override
  State<_CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<_CreateChallengeSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _kmCtrl = TextEditingController(text: '5');
  String _visibility = 'everyone'; // 'everyone' or 'friends'
  String _kind = 'distance_time';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give your challenge a name.')));
      return;
    }
    final km = double.tryParse(_kmCtrl.text.trim()) ?? 5.0;
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final draft = Challenge(
      id: 'local_ch_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descCtrl.text.trim(),
      kind: _kind,
      mode: 'open',
      targetKm: km > 0 ? km : 5.0,
      visibility: _visibility,
      createdBy: user?.username ?? user?.displayName ?? 'Athlete',
      ownerId: user?.id,
      communityId: widget.communityId,
      // Community challenges need admin approval before appearing publicly
      pendingApproval: widget.communityId != null,
      isJoined: true,
    );

    setState(() => _saving = true);
    final api = context.read<ApiService>();
    final saved = await api.createChallenge(draft.toJson());
    if (!mounted) return;
    setState(() => _saving = false);

    final result = saved ?? draft;
    widget.onCreated(result);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: RuchaTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RuchaTheme.accentCoral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.communityId != null
                            ? 'Submit to ${widget.communityName ?? "Community"}'
                            : 'Create a challenge',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        widget.communityId != null
                            ? 'Requires admin approval before going live'
                            : 'Visible to community or friends',
                        style: const TextStyle(
                            fontSize: 11, color: RuchaTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: RuchaTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            const Text('Challenge name *',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RuchaTheme.textSecondary)),
            const SizedBox(height: 6),
            _field(_titleCtrl, 'e.g. Run 5km under 25 minutes'),
            const SizedBox(height: 14),

            // Type
            const Text('Type',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RuchaTheme.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _kind,
              dropdownColor: RuchaTheme.surface2,
              decoration: InputDecoration(
                filled: true,
                fillColor: RuchaTheme.surface2,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: RuchaTheme.border),
                ),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'distance_time',
                    child: Text('Fastest time over distance')),
                DropdownMenuItem(
                    value: 'route', child: Text('Point-to-point route')),
                DropdownMenuItem(
                    value: 'vertical', child: Text('Vertical gain')),
                DropdownMenuItem(
                    value: 'weekly', child: Text('Weekly distance target')),
                DropdownMenuItem(
                    value: 'streak', child: Text('Consistency streak')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _kind = v);
              },
            ),
            const SizedBox(height: 14),

            // Target km
            const Text('Target distance (km)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RuchaTheme.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final km in ['1', '5', '10', '21', '42'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        _kmCtrl.text = km;
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kmCtrl.text == km
                              ? RuchaTheme.accentCoral.withOpacity(0.2)
                              : RuchaTheme.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _kmCtrl.text == km
                                ? RuchaTheme.accentCoral
                                : RuchaTheme.border,
                          ),
                        ),
                        child: Text('${km}km',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kmCtrl.text == km
                                  ? RuchaTheme.accentCoral
                                  : RuchaTheme.textSecondary,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _field(_kmCtrl, '5', keyboardType: TextInputType.number),
            const SizedBox(height: 14),

            // Visibility
            const Text('Who can see this?',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RuchaTheme.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _visBtn('🌍 Public', 'everyone')),
                const SizedBox(width: 10),
                Expanded(child: _visBtn('👥 Friends only', 'friends')),
              ],
            ),
            const SizedBox(height: 14),

            // Description
            const Text('Description / rules (optional)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RuchaTheme.textSecondary)),
            const SizedBox(height: 6),
            _field(_descCtrl, 'Start point, rules, prize...', maxLines: 2),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: RuchaTheme.accentCoral,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create challenge',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visBtn(String label, String value) {
    final selected = _visibility == value;
    final color =
        value == 'everyone' ? RuchaTheme.accentGreen : RuchaTheme.accentGold;
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : RuchaTheme.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : RuchaTheme.border),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : RuchaTheme.textSecondary,
            )),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: RuchaTheme.textSecondary.withOpacity(0.6)),
        filled: true,
        fillColor: RuchaTheme.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RuchaTheme.border),
        ),
      ),
    );
  }
}
