import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_post.dart';
import 'api_service.dart';

/// Local-first cache for community channels, groups and notifications.
///
/// Server posts are cached so the last conversation can still be read offline.
/// Posts written without a server connection are kept as [CommunityPost.pending]
/// and are clearly marked in the UI rather than pretending they were delivered.
class CommunityStore extends ChangeNotifier {
  static const String _prefsKey = 'rucha_community_cache_v1';
  static const int _maxPosts = 200;
  static const int _maxNotices = 100;

  final List<CommunityPost> _feed = [];
  final Map<String, List<CommunityPost>> _clubs = {};
  final List<CommunityNotice> _notices = [];
  final Set<String> _notifiedPostIds = {};

  Future<void> _writeQueue = Future<void>.value();
  late final Future<void> _restoreFuture;
  bool _restored = false;
  bool _hasFetchedFeed = false;

  bool get isRestored => _restored;
  List<CommunityPost> get feed => List.unmodifiable(_feed);
  List<CommunityNotice> get notices => List.unmodifiable(_notices);
  int get unreadNoticeCount => _notices.where((notice) => !notice.read).length;
  int get pendingCount =>
      _feed.where((post) => post.pending).length;

  CommunityStore() {
    _restoreFuture = _restore();
  }

  List<CommunityPost> postsFor(String clubId) =>
      List.unmodifiable(_clubs[clubId] ?? const <CommunityPost>[]);

  List<CommunityPost> channelFor(String clubId) =>
      postsFor(clubId).where((post) => post.isEvent).toList();

  List<CommunityPost> groupFor(String clubId) =>
      postsFor(clubId).where((post) => post.isMessage).toList();

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _hasFetchedFeed = decoded['hasFetchedFeed'] == true;

          final feed = decoded['feed'];
          if (feed is List) {
            final loaded = feed
                .whereType<Map>()
                .map((item) => CommunityPost.fromJson(Map<String, dynamic>.from(item)))
                .where(
                  (post) =>
                      post.id.isNotEmpty &&
                      post.clubId.isNotEmpty &&
                      post.isEvent,
                )
                .toList();
            _mergeRestoredPosts(_feed, loaded);
            _sortAndTrim(_feed);
          }

          final clubs = decoded['clubs'];
          if (clubs is Map) {
            for (final entry in clubs.entries) {
              final posts = entry.value;
              if (posts is! List) continue;
              final parsed = posts
                  .whereType<Map>()
                  .map((item) => CommunityPost.fromJson(Map<String, dynamic>.from(item)))
                  .where((post) => post.id.isNotEmpty)
                  .toList();
              final clubId = entry.key.toString();
              _mergeRestoredPosts(
                _clubs.putIfAbsent(clubId, () => <CommunityPost>[]),
                parsed,
              );
              _sortAndTrim(_clubs[clubId]!);
            }
          }

          final notices = decoded['notices'];
          if (notices is List) {
            final loaded = notices
                .whereType<Map>()
                .map((item) => CommunityNotice.fromJson(Map<String, dynamic>.from(item)))
                .where((notice) => notice.id.isNotEmpty);
            for (final notice in loaded) {
              if (_notices.any((existing) => existing.id == notice.id)) continue;
              _notices.add(notice);
            }
            _sortNotices();
          }

          final notified = decoded['notifiedPostIds'];
          if (notified is List) {
            _notifiedPostIds.addAll(notified.whereType<String>());
          }
        }
      }
    } catch (_) {
      // A corrupt cache must never stop the app from starting.
    }
    _restored = true;
    notifyListeners();
  }

  Future<bool> refreshFeed(ApiService api, {String? viewerId}) async {
    await _restoreFuture;
    final remote = await api.fetchCommunityFeed();
    if (remote == null) return false;

    final existing = List<CommunityPost>.from(_feed);
    _feed
      ..clear()
      ..addAll(
        _mergedWithPending(existing, remote).where((post) => post.isEvent),
      );
    _sortAndTrim(_feed);

    // The first successful fetch seeds the cache without firing a burst of
    // notifications for historical joins and challenges. Later fetches surface
    // genuinely new events from other athletes.
    final shouldNotify = _hasFetchedFeed;
    final now = DateTime.now();
    for (final post in remote) {
      if (post.kind != 'join' && post.kind != 'challenge') continue;
      if (!_notifiedPostIds.add(post.id)) continue;
      if (!shouldNotify) continue;
      if (viewerId != null && viewerId.isNotEmpty && post.authorId == viewerId) {
        // Joining already creates a local notification at the moment of joining.
        continue;
      }
      if (now.difference(post.createdAt).inHours > 24) continue;
      _addNotice(
        CommunityNotice(
          id: 'notice_post_${post.id}',
          clubId: post.clubId,
          clubName: post.clubName,
          kind: post.kind,
          title: post.title,
          body: post.body,
          createdAt: post.createdAt,
        ),
      );
    }
    _hasFetchedFeed = true;
    _sortNotices();
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> refreshClub(ApiService api, String clubId) async {
    await _restoreFuture;
    final remote = await api.fetchCommunityPosts(clubId);
    if (remote == null) return false;

    final merged = _mergedWithPending(_clubs[clubId] ?? const [], remote);
    _sortAndTrim(merged);
    _clubs[clubId] = merged;

    // Keep the global feed in step so recently opened channels appear there
    // even before the next feed refresh.
    for (final post in remote) {
      _upsertFeed(post);
    }
    await _persist();
    notifyListeners();
    return true;
  }

  /// Posts to the server when [canSync] is true. On failure (or for a local
  /// account) the post is stored on this device with `pending: true`.
  Future<CommunityPost> publish(
    ApiService api,
    CommunityPost draft, {
    required bool canSync,
  }) async {
    await _restoreFuture;
    if (canSync) {
      final saved = await api.createCommunityPost(draft.toCreateJson());
      if (saved != null) {
        _upsertPost(saved);
        await _persist();
        notifyListeners();
        return saved;
      }
    }

    final local = draft.copyWith(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      pending: true,
    );
    _upsertPost(local);
    await _persist();
    notifyListeners();
    return local;
  }

  Future<void> addJoinNotice({
    required String clubId,
    required String clubName,
  }) async {
    await _restoreFuture;
    _addNotice(
      CommunityNotice(
        id: 'notice_join_${clubId}_${DateTime.now().microsecondsSinceEpoch}',
        clubId: clubId,
        clubName: clubName,
        kind: 'join',
        title: 'You joined $clubName',
        body:
            'Your community channel and group are ready. Open them to meet the '
            'group or share your next run.',
        createdAt: DateTime.now(),
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> markAllNoticesRead() async {
    await _restoreFuture;
    if (_notices.every((notice) => notice.read)) return;
    for (var i = 0; i < _notices.length; i++) {
      _notices[i] = _notices[i].copyWith(read: true);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> markNoticeRead(String id) async {
    await _restoreFuture;
    final index = _notices.indexWhere((notice) => notice.id == id);
    if (index < 0 || _notices[index].read) return;
    _notices[index] = _notices[index].copyWith(read: true);
    await _persist();
    notifyListeners();
  }

  void _addNotice(CommunityNotice notice) {
    if (_notices.any((existing) => existing.id == notice.id)) return;
    _notices.insert(0, notice);
    _sortNotices();
  }

  void _sortNotices() {
    _notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_notices.length > _maxNotices) {
      _notices.removeRange(_maxNotices, _notices.length);
    }
  }

  void _upsertPost(CommunityPost post) {
    _upsertFeed(post);
    final list = _clubs.putIfAbsent(post.clubId, () => <CommunityPost>[]);
    final index = list.indexWhere((existing) => existing.id == post.id);
    if (index >= 0) {
      list[index] = post;
    } else {
      list.add(post);
    }
    _sortAndTrim(list);
  }

  void _upsertFeed(CommunityPost post) {
    final index = _feed.indexWhere((existing) => existing.id == post.id);
    if (!post.isEvent) {
      // Group chat stays in its club; the shared feed only carries channel
      // events.
      if (index >= 0) _feed.removeAt(index);
      return;
    }
    if (index >= 0) {
      _feed[index] = post;
    } else {
      _feed.add(post);
    }
    _sortAndTrim(_feed);
  }

  void _mergeRestoredPosts(
    List<CommunityPost> target,
    Iterable<CommunityPost> restored,
  ) {
    final ids = target.map((post) => post.id).toSet();
    for (final post in restored) {
      if (ids.add(post.id)) target.add(post);
    }
  }

  List<CommunityPost> _mergedWithPending(
    List<CommunityPost> existing,
    List<CommunityPost> remote,
  ) {
    final map = <String, CommunityPost>{};
    for (final post in existing) {
      if (post.pending) map[post.id] = post;
    }
    for (final post in remote) {
      if (post.pending) continue;
      map[post.id] = post;
    }
    final out = map.values.toList();
    _sortAndTrim(out);
    return out;
  }

  void _sortAndTrim(List<CommunityPost> posts) {
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (posts.length > _maxPosts) {
      posts.removeRange(_maxPosts, posts.length);
    }
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'feed': _feed.map((post) => post.toJson()).toList(),
      'clubs': {
        for (final entry in _clubs.entries)
          entry.key: entry.value.map((post) => post.toJson()).toList(),
      },
      'notices': _notices.map((notice) => notice.toJson()).toList(),
      'notifiedPostIds': _notifiedPostIds.toList(),
      'hasFetchedFeed': _hasFetchedFeed,
    });
    _writeQueue = _writeQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, snapshot);
      } catch (_) {
        // Losing the cache is better than breaking the active session.
      }
    });
    return _writeQueue;
  }
}
