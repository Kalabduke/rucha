import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/activity.dart';
import '../models/community_post.dart';
import '../services/activity_store.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/community_store.dart';

/// A Telegram-style community: a read-focused channel for announcements and a
/// group conversation where members can chat and share their training.
class CommunityChannelScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String city;
  final String description;
  final bool isMember;
  final int memberCount;

  const CommunityChannelScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.city = '',
    this.description = '',
    this.isMember = false,
    this.memberCount = 0,
  });

  @override
  State<CommunityChannelScreen> createState() => _CommunityChannelScreenState();
}

class _CommunityChannelScreenState extends State<CommunityChannelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _messageController = TextEditingController();
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _refreshing = true);
    final store = context.read<CommunityStore>();
    final api = context.read<ApiService>();
    await store.refreshClub(api, widget.clubId);
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  bool get _canSync {
    final auth = context.read<AuthService>();
    return auth.serverOnline &&
        auth.isAuthenticated &&
        !auth.isGuest &&
        !auth.isLocalAccount;
  }

  String get _authorName {
    final auth = context.read<AuthService>();
    return auth.currentUser?.displayName.trim().isNotEmpty == true
        ? auth.currentUser!.displayName.trim()
        : (auth.currentUser?.username.isNotEmpty == true
              ? auth.currentUser!.username
              : 'Athlete');
  }

  String get _authorId =>
      context.read<AuthService>().currentUser?.id ?? '';

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (!widget.isMember) {
      _showMessage('Join this community before posting in its group.');
      return;
    }

    final draft = CommunityPost(
      id: '',
      clubId: widget.clubId,
      clubName: widget.clubName,
      authorId: _authorId,
      authorName: _authorName,
      kind: 'message',
      title: text,
      createdAt: DateTime.now(),
      city: widget.city,
    );
    final post = await context.read<CommunityStore>().publish(
      context.read<ApiService>(),
      draft,
      canSync: _canSync,
    );
    if (!mounted) return;
    _messageController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    _showMessage(
      post.pending
          ? 'Saved on this device only — not sent to the community.'
          : 'Posted to ${widget.clubName}.',
    );
  }

  Future<void> _openShareMenu() async {
    if (!widget.isMember) {
      _showMessage(
        'Join ${widget.clubName} before sharing with its community.',
      );
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: RuchaTheme.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Share to the channel',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Shared items appear as channel announcements for every member.',
                  style: TextStyle(
                    color: RuchaTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.directions_run, color: RuchaTheme.accentGreen),
              title: const Text('Share an activity'),
              subtitle: const Text('A run or ride recorded on this device'),
              onTap: () => Navigator.pop(sheetContext, 'activity'),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.flag_fill, color: RuchaTheme.accentGold),
              title: const Text('Share a milestone'),
              subtitle: const Text('A personal best, streak or distance goal'),
              onTap: () => Navigator.pop(sheetContext, 'milestone'),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.map, color: RuchaTheme.accentGreen),
              title: const Text('Share a journey'),
              subtitle: const Text('A route, adventure or training story'),
              onTap: () => Navigator.pop(sheetContext, 'journey'),
            ),
            ListTile(
              leading: const Icon(Icons.terrain, color: RuchaTheme.accentGold),
              title: const Text('Share a segment'),
              subtitle: const Text('A local segment and its course record'),
              onTap: () => Navigator.pop(sheetContext, 'segment'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'activity':
        await _pickActivity();
        break;
      case 'milestone':
        await _shareComposed(
          kind: 'milestone',
          heading: 'Share a milestone',
          titleHint: 'e.g. First 10K completed',
          bodyHint: 'How did it feel? Add the details your community should know.',
        );
        break;
      case 'journey':
        await _shareComposed(
          kind: 'journey',
          heading: 'Share a journey',
          titleHint: 'e.g. Entoto ridge at sunrise',
          bodyHint: 'Describe the route, the climb or the story behind it.',
        );
        break;
      case 'segment':
        await _pickSegment();
        break;
    }
  }

  Future<void> _pickActivity() async {
    final activities = context.read<ActivityStore>().activities;
    if (activities.isEmpty) {
      _showMessage('Record a run or ride before sharing an activity.');
      return;
    }
    final picked = await showModalBottomSheet<Activity>(
      context: context,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            const Text(
              'Share an activity',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...activities.take(12).map(
              (activity) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  activity.type == 'ride'
                      ? Icons.directions_bike
                      : Icons.directions_run,
                  color: activity.type == 'ride'
                      ? RuchaTheme.accentGreen
                      : RuchaTheme.accentCoral,
                ),
                title: Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${activity.distance.toStringAsFixed(1)} km · '
                  '${RuchaConstants.formatDuration(activity.duration)} · '
                  '${RuchaConstants.cities[activity.city]?.name ?? activity.city}',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.pop(sheetContext, activity),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;

    final draft = CommunityPost(
      id: '',
      clubId: widget.clubId,
      clubName: widget.clubName,
      authorId: _authorId,
      authorName: _authorName,
      kind: 'activity',
      title: picked.title,
      body:
          '${picked.type == 'ride' ? 'Ride' : 'Run'} · '
          '${picked.distance.toStringAsFixed(1)} km · '
          '${RuchaConstants.formatDuration(picked.duration)} · '
          '+${picked.elevation.round()} m climb',
      activityId: picked.id,
      distanceKm: picked.distance,
      durationSec: picked.duration,
      elevationM: picked.elevation.round(),
      city: picked.city,
      createdAt: DateTime.now(),
    );
    await _publishDraft(draft);
  }

  Future<void> _pickSegment() async {
    final segments = <Map<String, dynamic>>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('rucha_segments_v1');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          segments.addAll(
            decoded
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)),
          );
        }
      }
    } catch (_) {}
    if (!mounted) return;
    if (segments.isEmpty) {
      _showMessage(
        'Create a segment first — segments are built from your recorded GPS routes.',
      );
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: RuchaTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            const Text(
              'Share a segment',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...segments.take(20).map((segment) {
              final distance = (segment['distance'] as num?)?.toDouble() ?? 0;
              final elevation = (segment['elevationGain'] as num?)?.toDouble() ?? 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.terrain, color: RuchaTheme.accentGold),
                title: Text(
                  segment['name']?.toString() ?? 'Segment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${distance.toStringAsFixed(1)} km · +${elevation.round()} m',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.pop(sheetContext, segment),
              );
            }),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;

    final distance = (picked['distance'] as num?)?.toDouble() ?? 0;
    final elevation = (picked['elevationGain'] as num?)?.toDouble() ?? 0;
    final bestAthlete = picked['bestAthlete']?.toString() ?? '';
    final bestSec = (picked['bestSec'] as num?)?.toInt() ?? 0;
    final draft = CommunityPost(
      id: '',
      clubId: widget.clubId,
      clubName: widget.clubName,
      authorId: _authorId,
      authorName: _authorName,
      kind: 'segment',
      title: picked['name']?.toString() ?? 'Segment',
      body:
          '${distance.toStringAsFixed(1)} km · +${elevation.round()} m climb'
          '${bestAthlete.isNotEmpty ? ' · CR $bestAthlete' : ''}'
          '${bestSec > 0 ? ' ${RuchaConstants.formatDuration(bestSec)}' : ''}',
      segmentId: picked['id']?.toString() ?? '',
      distanceKm: distance,
      elevationM: elevation.round(),
      city: picked['city']?.toString() ?? widget.city,
      createdAt: DateTime.now(),
    );
    await _publishDraft(draft);
  }

  Future<void> _shareComposed({
    required String kind,
    required String heading,
    required String titleHint,
    required String bodyHint,
  }) async {
    final result = await _showComposeDialog(
      heading: heading,
      titleHint: titleHint,
      bodyHint: bodyHint,
    );
    if (!mounted || result == null) return;
    final draft = CommunityPost(
      id: '',
      clubId: widget.clubId,
      clubName: widget.clubName,
      authorId: _authorId,
      authorName: _authorName,
      kind: kind,
      title: result.title,
      body: result.body,
      city: widget.city,
      createdAt: DateTime.now(),
    );
    await _publishDraft(draft);
  }

  Future<({String title, String body})?> _showComposeDialog({
    required String heading,
    required String titleHint,
    required String bodyHint,
  }) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final result = await showDialog<({String title, String body})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: RuchaTheme.surface,
        title: Text(heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: titleHint),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: bodyHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(
                dialogContext,
                (title: title, body: bodyController.text.trim()),
              );
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
    titleController.dispose();
    bodyController.dispose();
    return result;
  }

  Future<void> _publishDraft(CommunityPost draft) async {
    final post = await context.read<CommunityStore>().publish(
      context.read<ApiService>(),
      draft,
      canSync: _canSync,
    );
    if (!mounted) return;
    _tabs.animateTo(draft.isEvent ? 0 : 1);
    _showMessage(
      post.pending
          ? 'Saved on this device only — not sent to the community.'
          : 'Shared with ${widget.clubName}.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: RuchaTheme.surface2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RuchaTheme.background,
      appBar: AppBar(
        backgroundColor: RuchaTheme.surface,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clubName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              [
                if (widget.city.isNotEmpty) widget.city,
                if (widget.memberCount > 0)
                  '${widget.memberCount} member${widget.memberCount == 1 ? '' : 's'}',
                widget.isMember ? 'Joined' : 'Channel',
              ].join(' · '),
              style: const TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share to channel',
            onPressed: _openShareMenu,
            icon: const Icon(CupertinoIcons.share, size: 18),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.refresh, size: 18),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: RuchaTheme.accentGreen,
          indicatorWeight: 3,
          labelColor: RuchaTheme.textPrimary,
          unselectedLabelColor: RuchaTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'Channel'),
            Tab(text: 'Group'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _channelTab(),
          _groupTab(),
        ],
      ),
    );
  }

  Widget _channelTab() {
    final posts = context.watch<CommunityStore>().channelFor(widget.clubId);
    return RefreshIndicator(
      color: RuchaTheme.accentGreen,
      backgroundColor: RuchaTheme.surface,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _channelIntro(),
          const SizedBox(height: 14),
          if (posts.isEmpty)
            _emptyState(
              icon: Icons.campaign,
              title: 'No announcements yet',
              message:
                  'Join notices, challenge launches and shared activities will appear here. '
                  'Members can share from the button in the top bar.',
            )
          else
            ...posts.map(_postCard),
        ],
      ),
    );
  }

  Widget _channelIntro() {
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
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: RuchaTheme.accentGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.campaign,
                  size: 18,
                  color: RuchaTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Community channel',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: RuchaTheme.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ANNOUNCEMENTS',
                  style: TextStyle(
                    color: RuchaTheme.accentGold,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.description.isNotEmpty
                ? widget.description
                : 'Updates from ${widget.clubName}, its organizers and members.',
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTab() {
    final posts = context.watch<CommunityStore>().groupFor(widget.clubId);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: RuchaTheme.accentGreen,
            backgroundColor: RuchaTheme.surface,
            onRefresh: _refresh,
            child: posts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _emptyState(
                        icon: CupertinoIcons.chat_bubble_2,
                        title: 'The group is quiet',
                        message: widget.isMember
                            ? 'Say hello, plan a meetup or share what you are training for.'
                            : 'Join this community to take part in the group conversation.',
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (context, index) => _postCard(posts[index]),
                  ),
          ),
        ),
        if (widget.isMember)
          _composer()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: RuchaTheme.surface,
            child: const Text(
              'Join this community from the Clubs tab to post in the group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: const BoxDecoration(
        color: RuchaTheme.surface,
        border: Border(top: BorderSide(color: RuchaTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Share activity, milestone, journey or segment',
              onPressed: _openShareMenu,
              icon: const Icon(
                CupertinoIcons.paperclip,
                size: 20,
                color: RuchaTheme.accentGold,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Message ${widget.clubName}...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: RuchaTheme.surface2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: _sendMessage,
              style: IconButton.styleFrom(
                backgroundColor: RuchaTheme.accentGreen,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(CupertinoIcons.arrow_up, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(CommunityPost post) {
    final meta = _kindMeta(post.kind);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RuchaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: post.pending
              ? RuchaTheme.accentGold.withValues(alpha: 0.5)
              : RuchaTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(meta.icon, size: 16, color: meta.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.label,
                      style: TextStyle(
                        color: meta.color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (post.authorName.isNotEmpty)
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          color: RuchaTheme.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _relativeTime(post.createdAt),
                style: const TextStyle(
                  color: RuchaTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (post.body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              post.body,
              style: const TextStyle(
                color: RuchaTheme.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          if (post.distanceKm > 0 || post.durationSec > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (post.distanceKm > 0)
                  _metric(
                    CupertinoIcons.location,
                    '${post.distanceKm.toStringAsFixed(1)} km',
                  ),
                if (post.durationSec > 0)
                  _metric(
                    CupertinoIcons.time,
                    RuchaConstants.formatDuration(post.durationSec),
                  ),
                if (post.elevationM > 0)
                  _metric(Icons.terrain, '+${post.elevationM} m'),
              ],
            ),
          ],
          if (post.pending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: RuchaTheme.accentGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NOT SENT · SAVED ON THIS DEVICE',
                style: TextStyle(
                  color: RuchaTheme.accentGold,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: RuchaTheme.accentGreen),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: RuchaTheme.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
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
          Icon(icon, size: 38, color: RuchaTheme.textSecondary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RuchaTheme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color, String label}) _kindMeta(String kind) {
    switch (kind) {
      case 'join':
        return (
          icon: CupertinoIcons.person_add_solid,
          color: RuchaTheme.accentGold,
          label: 'NEW MEMBER',
        );
      case 'challenge':
        return (
          icon: Icons.emoji_events,
          color: RuchaTheme.accentCoral,
          label: 'CHALLENGE',
        );
      case 'activity':
        return (
          icon: Icons.directions_run,
          color: RuchaTheme.accentGreen,
          label: 'SHARED ACTIVITY',
        );
      case 'milestone':
        return (
          icon: CupertinoIcons.flag_fill,
          color: RuchaTheme.accentGold,
          label: 'MILESTONE',
        );
      case 'journey':
        return (
          icon: CupertinoIcons.map,
          color: RuchaTheme.accentGreen,
          label: 'JOURNEY',
        );
      case 'segment':
        return (
          icon: Icons.terrain,
          color: RuchaTheme.accentGold,
          label: 'SEGMENT',
        );
      case 'system':
        return (
          icon: Icons.campaign,
          color: RuchaTheme.accentGreen,
          label: 'COMMUNITY',
        );
      default:
        return (
          icon: CupertinoIcons.chat_bubble_2_fill,
          color: RuchaTheme.textSecondary,
          label: 'MESSAGE',
        );
    }
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}
