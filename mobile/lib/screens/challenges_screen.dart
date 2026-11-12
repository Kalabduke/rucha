import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../models/challenge.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/challenge_results.dart';
import 'challenge_run_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChallengesScreen — tabs: Public · Friends · Mine
// Features: leaderboard per challenge, kudos, create challenge
// ─────────────────────────────────────────────────────────────────────────────

class ChallengesScreen extends StatefulWidget {
  final bool embedded;
  const ChallengesScreen({super.key, this.embedded = false});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  static const _prefsKey = 'rucha_challenges_v1';
  static const _prefsJoinedKey = 'rucha_challenges_joined_v1';
  static const _prefsKudosKey = 'rucha_challenge_kudos_v1';

  late final TabController _tab;

  List<Challenge> _challenges = const [];
  Set<String> _joinedIds = {};
  Map<String, ChallengeResult> _results = const {};
  // kudos: challengeId → list of usernames who gave kudos (local)
  Map<String, List<String>> _kudos = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadChallenges();
    unawaited(_loadResults());
    unawaited(_loadKudos());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadResults() async {
    final r = await ChallengeResultStore.loadAll();
    if (!mounted) return;
    setState(() => _results = r);
  }

  Future<void> _loadKudos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKudosKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _kudos =
              decoded.map((k, v) => MapEntry(k, List<String>.from(v as List)));
        });
      }
    } catch (_) {}
  }

  Future<void> _loadChallenges() async {
    if (!_isLoading) setState(() => _isLoading = true);

    List<Challenge> local = const [];
    final joined = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          local = decoded
              .whereType<Map>()
              .map(
                  (item) => Challenge.fromJson(Map<String, dynamic>.from(item)))
              .where((c) => c.id.isNotEmpty)
              .toList();
        }
      }
      final rawJoined = prefs.getString(_prefsJoinedKey);
      if (rawJoined != null && rawJoined.isNotEmpty) {
        final decoded = jsonDecode(rawJoined);
        if (decoded is List) joined.addAll(decoded.whereType<String>());
      }
      for (final c in local) {
        if (c.isJoined) joined.add(c.id);
      }
    } catch (e) {
      debugPrint('ChallengesScreen load: $e');
    }

    if (!mounted) return;
    setState(() {
      _challenges = local;
      _joinedIds = joined;
      _isLoading = false;
    });

    final auth = context.read<AuthService>();
    if (!auth.serverOnline) return;

    final remote = await context.read<ApiService>().fetchChallenges();
    if (!mounted || remote.isEmpty) return;

    final knownIds = local.map((c) => c.id).toSet();
    final merged = <Challenge>[
      ...local,
      ...remote.where((c) => !knownIds.contains(c.id)),
    ];
    final mergedJoined = <String>{
      ...joined,
      for (final c in remote)
        if (c.isJoined) c.id,
    };
    setState(() {
      _challenges = merged;
      _joinedIds = mergedJoined;
    });
    await _persist();
  }

  Future<void> _syncChallenge(Challenge draft) async {
    final saved =
        await context.read<ApiService>().createChallenge(draft.toJson());
    if (saved == null || !mounted) return;
    setState(() {
      final i = _challenges.indexWhere((c) => c.id == draft.id);
      if (i >= 0) _challenges = List<Challenge>.from(_challenges)..[i] = saved;
      if (_joinedIds.remove(draft.id)) _joinedIds.add(saved.id);
    });
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = _challenges.map((c) {
        final m = c.toJson();
        m['joined'] = _joinedIds.contains(c.id);
        return m;
      }).toList();
      await prefs.setString(_prefsKey, jsonEncode(payload));
      await prefs.setString(_prefsJoinedKey, jsonEncode(_joinedIds.toList()));
    } catch (e) {
      debugPrint('ChallengesScreen save: $e');
    }
  }

  Future<void> _persistKudos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKudosKey, jsonEncode(_kudos));
    } catch (_) {}
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleJoin(Challenge c) async {
    final isJoined = _joinedIds.contains(c.id);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    setState(() {
      isJoined ? _joinedIds.remove(c.id) : _joinedIds.add(c.id);
    });
    await _persist();
    if (!isJoined &&
        auth.serverOnline &&
        auth.isAuthenticated &&
        !auth.isLocalAccount) {
      final u = auth.currentUser!;
      unawaited(
          api.joinChallenge(c.id, athleteId: u.id, athleteName: u.username));
    }
    if (!mounted) return;
    _toast(isJoined ? 'Left "${c.title}".' : 'Joined "${c.title}".');
  }

  Future<void> _openRunner(Challenge c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChallengeRunScreen(challenge: c)),
    );
    if (!mounted) return;
    await _loadResults();
  }

  void _giveKudos(Challenge c) {
    final auth = context.read<AuthService>();
    final me = auth.currentUser?.username ?? 'guest';
    setState(() {
      final list = List<String>.from(_kudos[c.id] ?? []);
      if (list.contains(me)) {
        list.remove(me);
      } else {
        list.add(me);
      }
      _kudos[c.id] = list;
    });
    unawaited(_persistKudos());
  }

  // ── Tabs helpers ──────────────────────────────────────────────────────────

  String? get _myId => context.read<AuthService>().currentUser?.id;
  String? get _myName => context.read<AuthService>().currentUser?.username;

  List<Challenge> get _publicChallenges => _challenges
      .where((c) => c.visibility != 'local' && c.communityId == null)
      .toList();

  List<Challenge> get _friendChallenges => _challenges
      .where((c) =>
          c.inviteStatus == 'pending' ||
          c.inviteStatus == 'accepted' ||
          (c.opponentId != null && c.opponentId == _myId) ||
          (c.opponentName != null && c.opponentName == _myName))
      .toList();

  List<Challenge> get _myChallenges => _challenges
      .where((c) =>
          _joinedIds.contains(c.id) ||
          c.ownerId == _myId ||
          c.createdBy == _myName)
      .toList();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CupertinoActivityIndicator()),
      );
    }

    final body = Column(
      children: [
        // Tab bar
        Container(
          color: RuchaTheme.surface,
          child: TabBar(
            controller: _tab,
            labelColor: RuchaTheme.accentGreen,
            unselectedLabelColor: RuchaTheme.textSecondary,
            indicatorColor: RuchaTheme.accentGreen,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: [
              Tab(text: 'Public (${_publicChallenges.length})'),
              Tab(text: 'Friends (${_friendChallenges.length})'),
              Tab(text: 'Mine (${_myChallenges.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _ChallengeList(
                challenges: _publicChallenges,
                joinedIds: _joinedIds,
                results: _results,
                kudos: _kudos,
                onJoin: _toggleJoin,
                onRun: _openRunner,
                onKudos: _giveKudos,
                myName: _myName,
                emptyMessage:
                    'No public challenges yet.\nConnect to the server or create one.',
                onRefresh: _loadChallenges,
              ),
              _ChallengeList(
                challenges: _friendChallenges,
                joinedIds: _joinedIds,
                results: _results,
                kudos: _kudos,
                onJoin: _toggleJoin,
                onRun: _openRunner,
                onKudos: _giveKudos,
                myName: _myName,
                emptyMessage:
                    'No friend challenges.\nAsk a friend to challenge you on RUCHA!',
                onRefresh: _loadChallenges,
              ),
              _ChallengeList(
                challenges: _myChallenges,
                joinedIds: _joinedIds,
                results: _results,
                kudos: _kudos,
                onJoin: _toggleJoin,
                onRun: _openRunner,
                onKudos: _giveKudos,
                myName: _myName,
                emptyMessage:
                    'You haven\'t joined any challenges yet.\nCreate one or join a public challenge.',
                onRefresh: _loadChallenges,
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: RuchaTheme.accentGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label:
            const Text('Create', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ── Create challenge sheet ─────────────────────────────────────────────────

  // ── Create challenge sheet — delegated to _CreateChallengeSheet widget ─────

  void _showCreateSheet() {
    final auth = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RuchaTheme.surface,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateChallengeSheet(
        onCreated: (challenge) {
          final canSync =
              auth.serverOnline && auth.isAuthenticated && !auth.isLocalAccount;
          setState(() {
            _challenges = [challenge, ..._challenges];
            _joinedIds.add(challenge.id);
          });
          unawaited(_persist());
          if (canSync) unawaited(_syncChallenge(challenge));
          _toast('Challenge created!');
          _tab.animateTo(2);
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          backgroundColor: RuchaTheme.surface2),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChallengeList — reusable list for each tab
// ─────────────────────────────────────────────────────────────────────────────

class _ChallengeList extends StatelessWidget {
  final List<Challenge> challenges;
  final Set<String> joinedIds;
  final Map<String, ChallengeResult> results;
  final Map<String, List<String>> kudos;
  final Future<void> Function(Challenge) onJoin;
  final Future<void> Function(Challenge) onRun;
  final void Function(Challenge) onKudos;
  final String? myName;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _ChallengeList({
    required this.challenges,
    required this.joinedIds,
    required this.results,
    required this.kudos,
    required this.onJoin,
    required this.onRun,
    required this.onKudos,
    required this.myName,
    required this.emptyMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) {
      return RefreshIndicator(
        color: RuchaTheme.accentGreen,
        onRefresh: onRefresh,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 48),
          const Icon(CupertinoIcons.flag,
              size: 48, color: RuchaTheme.textSecondary),
          const SizedBox(height: 14),
          Text(emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: RuchaTheme.textSecondary, fontSize: 13, height: 1.5)),
        ]),
      );
    }

    return RefreshIndicator(
      color: RuchaTheme.accentGreen,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: challenges.length,
        itemBuilder: (_, i) => _ChallengeCard(
          challenge: challenges[i],
          isJoined: joinedIds.contains(challenges[i].id),
          result: results[challenges[i].id],
          kudosList: kudos[challenges[i].id] ?? const [],
          myName: myName,
          onJoin: () => onJoin(challenges[i]),
          onRun: () => onRun(challenges[i]),
          onKudos: () => onKudos(challenges[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChallengeCard — single card with leaderboard preview + kudos
// ─────────────────────────────────────────────────────────────────────────────

class _ChallengeCard extends StatefulWidget {
  final Challenge challenge;
  final bool isJoined;
  final ChallengeResult? result;
  final List<String> kudosList;
  final String? myName;
  final VoidCallback onJoin;
  final VoidCallback onRun;
  final VoidCallback onKudos;

  const _ChallengeCard({
    required this.challenge,
    required this.isJoined,
    required this.result,
    required this.kudosList,
    required this.myName,
    required this.onJoin,
    required this.onRun,
    required this.onKudos,
  });

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final isDuel = c.mode == 'head_to_head' || c.kind == 'head_to_head';
    final accentC = isDuel ? RuchaTheme.accentCoral : RuchaTheme.accentGreen;
    final kindLabel =
        isDuel ? '1 VS 1 DUEL' : c.kind.toUpperCase().replaceAll('_', ' ');
    final ikindIcon =
        isDuel ? CupertinoIcons.bolt_fill : CupertinoIcons.flag_fill;

    final hasKudos = widget.kudosList.isNotEmpty;
    final iGaveKudos = widget.kudosList.contains(widget.myName ?? '');
    final hasResult = widget.result != null;
    final res = widget.result;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDuel
                ? RuchaTheme.accentCoral.withValues(alpha: 0.4)
                : RuchaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main card body ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: type badge + join badge + prize
                Row(children: [
                  _badge(kindLabel, accentC, icon: ikindIcon),
                  const SizedBox(width: 6),
                  if (widget.isJoined) _badge('JOINED', RuchaTheme.accentGreen),
                  if (c.pendingApproval)
                    _badge('PENDING', RuchaTheme.accentGold),
                  if (c.inviteStatus == 'pending')
                    _badge('INVITED', RuchaTheme.accentCoral),
                  const Spacer(),
                  if (c.prizeBirr > 0)
                    Text('Br ${c.prizeBirr}',
                        style: const TextStyle(
                            color: RuchaTheme.accentGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 10),
                Text(c.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white)),
                if (c.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(c.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: RuchaTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4)),
                ],
                const SizedBox(height: 10),
                // Stats row: distance · creator · opponent
                Wrap(spacing: 10, runSpacing: 4, children: [
                  if (c.targetKm != null)
                    _chip('🏃 ${c.targetKm!.toStringAsFixed(1)} km',
                        RuchaTheme.accentGreen),
                  if (c.createdBy != null && c.createdBy!.isNotEmpty)
                    _chip('by ${c.createdBy}', RuchaTheme.textSecondary),
                  if (isDuel && c.opponentName != null)
                    _chip('vs ${c.opponentName}', RuchaTheme.accentCoral),
                ]),
                // My best result
                if (hasResult) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: RuchaTheme.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: RuchaTheme.accentGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(CupertinoIcons.check_mark_circled_solid,
                          color: RuchaTheme.accentGreen, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'My best: ${_formatPace(res!.bestSeconds.toDouble())} · ${res.attempts} attempt${res.attempts == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: RuchaTheme.accentGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          // ── Leaderboard toggle ────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: RuchaTheme.surface2,
                border: Border(
                  top: BorderSide(color: RuchaTheme.border),
                  bottom: _expanded
                      ? BorderSide(color: RuchaTheme.border)
                      : BorderSide.none,
                ),
              ),
              child: Row(children: [
                const Icon(Icons.leaderboard_rounded,
                    size: 15, color: RuchaTheme.accentGold),
                const SizedBox(width: 6),
                const Text('Leaderboard',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: RuchaTheme.accentGold)),
                const Spacer(),
                Icon(
                    _expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 13,
                    color: RuchaTheme.textSecondary),
              ]),
            ),
          ),

          if (_expanded)
            _Leaderboard(
                challenge: c, myResult: widget.result, myName: widget.myName),

          // ── Action row: Run + Kudos + Join ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              // Run / attempt button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onRun,
                  icon: const Icon(CupertinoIcons.play_arrow_solid, size: 14),
                  label: Text(hasResult ? 'Run again' : 'Start',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentC,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Kudos
              GestureDetector(
                onTap: widget.onKudos,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: iGaveKudos
                        ? RuchaTheme.accentCoral.withValues(alpha: 0.2)
                        : RuchaTheme.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: iGaveKudos
                            ? RuchaTheme.accentCoral
                            : RuchaTheme.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        iGaveKudos
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        size: 15,
                        color: iGaveKudos
                            ? RuchaTheme.accentCoral
                            : RuchaTheme.textSecondary),
                    if (hasKudos) ...[
                      const SizedBox(width: 4),
                      Text('${widget.kudosList.length}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: iGaveKudos
                                  ? RuchaTheme.accentCoral
                                  : RuchaTheme.textSecondary)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              // Join/Leave
              GestureDetector(
                onTap: widget.onJoin,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.isJoined
                        ? RuchaTheme.accentGreen.withValues(alpha: 0.15)
                        : RuchaTheme.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: widget.isJoined
                            ? RuchaTheme.accentGreen
                            : RuchaTheme.border),
                  ),
                  child: Text(widget.isJoined ? 'Leave' : 'Join',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: widget.isJoined
                              ? RuchaTheme.accentGreen
                              : RuchaTheme.textSecondary)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  String _formatPace(double secs) {
    if (secs <= 0) return '--:--';
    final m = (secs / 60).floor();
    final s = (secs % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Leaderboard — shows participants and their best times
// ─────────────────────────────────────────────────────────────────────────────
// _Leaderboard — smart unit based on challenge kind
// ─────────────────────────────────────────────────────────────────────────────

class _Leaderboard extends StatelessWidget {
  final Challenge challenge;
  final ChallengeResult? myResult;
  final String? myName;

  const _Leaderboard({required this.challenge, this.myResult, this.myName});

  // ── kind → metric label ───────────────────────────────────────────────────
  String get _unitLabel {
    switch (challenge.kind) {
      case 'max_distance':
      case 'weekly':
        return 'km';
      case 'vertical':
        return 'm elev';
      case 'streak':
        return 'days';
      case 'distance_time':
      case 'route':
      case 'head_to_head':
      default:
        return 'finish time';
    }
  }

  // Higher value is better for distance/elev/streak; lower for time/pace
  bool get _higherIsBetter {
    switch (challenge.kind) {
      case 'max_distance':
      case 'weekly':
      case 'vertical':
      case 'streak':
        return true;
      default:
        return false;
    }
  }

  String _fmt(double v) {
    if (v <= 0) return '—';
    switch (challenge.kind) {
      case 'max_distance':
      case 'weekly':
        return '${v.toStringAsFixed(2)} km';
      case 'vertical':
        return '${v.round()} m';
      case 'streak':
        return '${v.round()} days';
      default:
        // time in seconds → MM:SS
        final m = (v / 60).floor();
        final s = (v % 60).round();
        return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = <_LbEntry>[];

    if (challenge.opponentName != null && challenge.opponentName!.isNotEmpty) {
      entries
          .add(_LbEntry(name: challenge.opponentName!, value: 0, isMe: false));
    }
    if (challenge.createdBy != null && challenge.createdBy!.isNotEmpty) {
      entries.add(_LbEntry(name: challenge.createdBy!, value: 0, isMe: false));
    }
    if (myResult != null && myName != null) {
      entries.removeWhere((e) => e.name == myName);
      entries.add(_LbEntry(
          name: myName!, value: myResult!.bestSeconds.toDouble(), isMe: true));
    }

    entries.sort((a, b) {
      if (a.value == 0 && b.value == 0) return 0;
      if (a.value == 0) return 1;
      if (b.value == 0) return -1;
      return _higherIsBetter
          ? b.value.compareTo(a.value)
          : a.value.compareTo(b.value);
    });

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No participants yet. Be the first!',
            style: const TextStyle(
                color: RuchaTheme.textSecondary, fontSize: 12, height: 1.4)),
      );
    }

    final medals = ['🥇', '🥈', '🥉'];
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        color: RuchaTheme.surface2,
        child: Row(children: [
          const Spacer(),
          Text('RANKED BY ${_unitLabel.toUpperCase()}',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: RuchaTheme.textSecondary,
                  letterSpacing: 0.6)),
        ]),
      ),
      for (int i = 0; i < entries.length; i++)
        _LbRow(
          rank: i + 1,
          entry: entries[i],
          medal: i < medals.length ? medals[i] : '${i + 1}',
          formatted: _fmt(entries[i].value),
        ),
      const SizedBox(height: 4),
    ]);
  }
}

class _LbEntry {
  final String name;
  final double value;
  final bool isMe;
  _LbEntry({required this.name, required this.value, required this.isMe});
}

class _LbRow extends StatelessWidget {
  final int rank;
  final _LbEntry entry;
  final String medal;
  final String formatted;

  const _LbRow({
    required this.rank,
    required this.entry,
    required this.medal,
    required this.formatted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: entry.isMe
            ? RuchaTheme.accentGreen.withValues(alpha: 0.08)
            : Colors.transparent,
        border: Border(
            bottom:
                BorderSide(color: RuchaTheme.border.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text(medal,
              style: TextStyle(
                  fontSize: rank <= 3 ? 16 : 12,
                  fontWeight: FontWeight.w800,
                  color: rank <= 3 ? null : RuchaTheme.textSecondary)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(entry.name,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: entry.isMe ? FontWeight.w800 : FontWeight.w500,
                  color: entry.isMe ? RuchaTheme.accentGreen : Colors.white)),
        ),
        Text(formatted,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    entry.value > 0 ? Colors.white : RuchaTheme.textSecondary)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CreateChallengeSheet — full-featured challenge creation form
//
// Challenge kinds:
//   distance_time  → Fastest to cover X km (ranked by finish time)
//   max_distance   → Most km in a time window (ranked by km)
//   weekly         → Hit a weekly km target (ranked by km)
//   vertical       → Most elevation gain in one run (ranked by m)
//   streak         → Run every day for N days (ranked by days)
//   head_to_head   → 1-vs-1 duel over X km (ranked by finish time)
// ─────────────────────────────────────────────────────────────────────────────

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
  final _opponentCtrl = TextEditingController();
  final _kmCtrl = TextEditingController(text: '5');
  final _elevCtrl = TextEditingController(text: '200');
  final _daysCtrl = TextEditingController(text: '7');
  final _prizeCtrl = TextEditingController();

  String _kind = 'distance_time';
  String _visibility = 'public'; // 'public' | 'friends'

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _opponentCtrl.dispose();
    _kmCtrl.dispose();
    _elevCtrl.dispose();
    _daysCtrl.dispose();
    _prizeCtrl.dispose();
    super.dispose();
  }

  // ── kind metadata ─────────────────────────────────────────────────────────

  static const _kinds = [
    (
      'distance_time',
      '⏱️',
      'Fastest over distance',
      'Who finishes X km the quickest? Ranked by finish time.'
    ),
    (
      'max_distance',
      '📏',
      'Most distance in a window',
      'Who runs the most km in a set time period? Ranked by km.'
    ),
    (
      'weekly',
      '📆',
      'Weekly km target',
      'Hit a weekly distance target consistently. Ranked by km.'
    ),
    (
      'vertical',
      '⛰️',
      'Climb challenge',
      'Who gains the most elevation in one run? Ranked by metres.'
    ),
    (
      'streak',
      '🔥',
      'Run streak',
      'Run every day for as many days as possible. Ranked by days.'
    ),
    (
      'head_to_head',
      '⚔️',
      '1 vs 1 duel',
      'Direct challenge against one opponent over a set distance.'
    ),
  ];

  String _kindEmoji(String k) =>
      _kinds.firstWhere((e) => e.$1 == k, orElse: () => _kinds[0]).$2;
  String _kindLabel(String k) =>
      _kinds.firstWhere((e) => e.$1 == k, orElse: () => _kinds[0]).$3;
  String _kindNote(String k) =>
      _kinds.firstWhere((e) => e.$1 == k, orElse: () => _kinds[0]).$4;

  // ── submit ────────────────────────────────────────────────────────────────

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('Give the challenge a name.');
      return;
    }

    final opponent = _opponentCtrl.text.trim().replaceAll('@', '');
    if (_kind == 'head_to_head' && opponent.isEmpty) {
      _snack('Enter your opponent\'s username.');
      return;
    }

    final auth = context.read<AuthService>();
    final u = auth.currentUser;
    final canSync =
        auth.serverOnline && auth.isAuthenticated && !auth.isLocalAccount;
    final creator = (u?.displayName.trim().isNotEmpty == true)
        ? u!.displayName.trim()
        : (u?.username ?? 'Guest');

    final km = double.tryParse(_kmCtrl.text.trim()) ?? 5.0;
    final elev = double.tryParse(_elevCtrl.text.trim()) ?? 200.0;
    final days = int.tryParse(_daysCtrl.text.trim()) ?? 7;
    final prize = int.tryParse(_prizeCtrl.text.trim()) ?? 0;

    // Build target fields per kind
    double? targetKm;
    double? targetElev;
    int? targetTime;
    switch (_kind) {
      case 'distance_time':
      case 'head_to_head':
        targetKm = km > 0 ? km : 5.0;
        break;
      case 'max_distance':
      case 'weekly':
        targetKm = km > 0 ? km : 20.0;
        break;
      case 'vertical':
        targetElev = elev > 0 ? elev : 200.0;
        break;
      case 'streak':
        targetTime = days > 0 ? days : 7; // days stored in targetTime
        break;
    }

    final challenge = Challenge(
      id: 'local_ch_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descCtrl.text.trim(),
      kind: _kind,
      mode: _kind == 'head_to_head' ? 'head_to_head' : 'open',
      targetKm: targetKm,
      targetElev: targetElev,
      targetTime: targetTime,
      prizeBirr: prize,
      visibility: canSync ? _visibility : 'local',
      opponentName: _kind == 'head_to_head' ? opponent : null,
      createdBy: creator,
      ownerId: u?.id,
      communityId: widget.communityId,
      pendingApproval: widget.communityId != null,
      isJoined: true,
    );

    Navigator.pop(context);
    widget.onCreated(challenge);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: RuchaTheme.surface2));

  // ── build ─────────────────────────────────────────────────────────────────

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
                child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                        color: RuchaTheme.border,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    RuchaTheme.accentGreen.withOpacity(0.15),
                    RuchaTheme.accentGreen.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: RuchaTheme.accentGreen.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [RuchaTheme.accentGreen, Color(0xFF00C853)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: RuchaTheme.accentGreen.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]),
                    child: const Icon(CupertinoIcons.flag_fill,
                        color: Colors.white, size: 20)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          widget.communityId != null
                              ? 'Submit to ${widget.communityName ?? "Community"}'
                              : 'Create a challenge',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 3),
                      Text(
                          widget.communityId != null
                              ? 'Needs admin approval before going live'
                              : 'Saved on device · synced when online',
                          style: const TextStyle(
                              fontSize: 11,
                              color: RuchaTheme.accentGold,
                              fontWeight: FontWeight.w600)),
                    ])),
                IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 24),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Challenge title ────────────────────────────────────────────
            _lbl('Challenge name *'),
            _tf(_titleCtrl, 'e.g. Entoto Hill Sprint · 5 km'),
            const SizedBox(height: 18),

            // ── Kind selector — visual cards ───────────────────────────────
            _lbl('Challenge type'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                for (final k in _kinds)
                  _KindCard(
                    emoji: k.$2,
                    label: k.$3,
                    selected: _kind == k.$1,
                    onTap: () => setState(() => _kind = k.$1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Kind description note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: RuchaTheme.accentGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: RuchaTheme.accentGreen.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Text(_kindEmoji(_kind), style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_kindNote(_kind),
                        style: const TextStyle(
                            color: RuchaTheme.textSecondary,
                            fontSize: 11,
                            height: 1.4))),
              ]),
            ),
            const SizedBox(height: 18),

            // ── Kind-specific target ───────────────────────────────────────
            if (_kind == 'distance_time' ||
                _kind == 'head_to_head' ||
                _kind == 'max_distance' ||
                _kind == 'weekly') ...[
              _lbl(_kind == 'max_distance' || _kind == 'weekly'
                  ? 'Target distance (km)'
                  : 'Distance to run (km)'),
              Row(children: [
                for (final preset
                    in _kind == 'max_distance' || _kind == 'weekly'
                        ? [10.0, 20.0, 42.195]
                        : [1.0, 5.0, 10.0, 21.1])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _kmCtrl.text =
                          preset == 42.195
                              ? '42.195'
                              : preset.toStringAsFixed(0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: RuchaTheme.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: RuchaTheme.border)),
                        child: Text(
                            preset == 42.195
                                ? '42.2'
                                : '${preset.toStringAsFixed(0)} km',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: RuchaTheme.textSecondary)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              _tf(_kmCtrl, '5',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  suffix: const Text('km',
                      style: TextStyle(
                          color: RuchaTheme.textSecondary, fontSize: 13))),
              const SizedBox(height: 18),
            ],

            if (_kind == 'vertical') ...[
              _lbl('Target elevation gain (m)'),
              Row(children: [
                for (final preset in [100, 200, 500, 1000])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _elevCtrl.text = '$preset'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: RuchaTheme.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: RuchaTheme.border)),
                        child: Text('$preset m',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: RuchaTheme.textSecondary)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              _tf(_elevCtrl, '200',
                  keyboardType: TextInputType.number,
                  suffix: const Text('m',
                      style: TextStyle(
                          color: RuchaTheme.textSecondary, fontSize: 13))),
              const SizedBox(height: 18),
            ],

            if (_kind == 'streak') ...[
              _lbl('Target streak (days)'),
              Row(children: [
                for (final preset in [7, 14, 30, 100])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _daysCtrl.text = '$preset'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: RuchaTheme.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: RuchaTheme.border)),
                        child: Text('$preset days',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: RuchaTheme.textSecondary)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              _tf(_daysCtrl, '7',
                  keyboardType: TextInputType.number,
                  suffix: const Text('days',
                      style: TextStyle(
                          color: RuchaTheme.textSecondary, fontSize: 13))),
              const SizedBox(height: 18),
            ],

            // ── 1v1 opponent ───────────────────────────────────────────────
            if (_kind == 'head_to_head') ...[
              _lbl('Opponent username', color: RuchaTheme.accentCoral),
              _tf(_opponentCtrl, 'username (no @)',
                  prefix: const Icon(CupertinoIcons.at,
                      size: 15, color: RuchaTheme.accentCoral)),
              const SizedBox(height: 18),
            ],

            // ── Visibility (skip for community submissions) ────────────────
            if (widget.communityId == null) ...[
              _lbl('Who can see this?'),
              Row(children: [
                Expanded(child: _visBtn('Public', '🌍', 'public')),
                const SizedBox(width: 10),
                Expanded(child: _visBtn('Friends only', '👥', 'friends')),
              ]),
              const SizedBox(height: 18),
            ],

            // ── Prize note ─────────────────────────────────────────────────
            _lbl('Prize note (optional)', color: RuchaTheme.accentGold),
            _tf(_prizeCtrl, 'e.g. 500',
                keyboardType: TextInputType.number,
                prefix: const Text('  Br ',
                    style: TextStyle(
                        color: RuchaTheme.accentGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 14))),
            const SizedBox(height: 4),
            const Text('Display only — RUCHA does not process payments.',
                style:
                    TextStyle(fontSize: 10, color: RuchaTheme.textSecondary)),
            const SizedBox(height: 18),

            // ── Description / rules ────────────────────────────────────────
            _lbl('Description / rules (optional)'),
            _tf(_descCtrl, 'Start point, any special rules…', maxLines: 3),
            const SizedBox(height: 24),

            // ── Submit ─────────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(CupertinoIcons.flag_fill, size: 16),
              label: Text(
                  widget.communityId != null
                      ? 'Submit for approval'
                      : 'Create challenge',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: RuchaTheme.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Widget _lbl(String t, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color ?? RuchaTheme.textSecondary)),
      );

  Widget _tf(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    Widget? prefix,
    Widget? suffix,
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: RuchaTheme.textSecondary.withValues(alpha: 0.6)),
          prefixIcon: prefix,
          suffix: suffix,
          filled: true,
          fillColor: RuchaTheme.surface2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RuchaTheme.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RuchaTheme.border)),
        ),
      );

  Widget _visBtn(String label, String emoji, String val) => GestureDetector(
        onTap: () => setState(() => _visibility = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _visibility == val
                ? RuchaTheme.accentGreen.withValues(alpha: 0.15)
                : RuchaTheme.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _visibility == val
                    ? RuchaTheme.accentGreen
                    : RuchaTheme.border),
          ),
          child: Center(
              child: Text('$emoji $label',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _visibility == val
                          ? Colors.white
                          : RuchaTheme.textSecondary))),
        ),
      );
}

// ── Kind selector card ────────────────────────────────────────────────────────

class _KindCard extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _KindCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    RuchaTheme.accentGreen.withOpacity(0.25),
                    RuchaTheme.accentGreen.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : RuchaTheme.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? RuchaTheme.accentGreen : RuchaTheme.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: RuchaTheme.accentGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label.split(' ').take(2).join('\n'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? Colors.white : RuchaTheme.textSecondary,
                height: 1.3,
                letterSpacing: selected ? 0.2 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
