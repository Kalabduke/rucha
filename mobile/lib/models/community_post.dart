/// One message or event in a community channel/group.
///
/// The server publishes join notices and challenge announcements automatically,
/// while members post chat messages and share activities, milestones, journeys
/// and segments. A post with [pending] set was written while the device was
/// offline and is stored locally until it can be sent.
class CommunityPost {
  final String id;
  final String clubId;
  final String clubName;
  final String authorId;
  final String authorName;
  final String kind;
  final String title;
  final String body;
  final String activityId;
  final String challengeId;
  final String segmentId;
  final double distanceKm;
  final int durationSec;
  final int elevationM;
  final String city;
  final DateTime createdAt;
  final bool pending;

  const CommunityPost({
    required this.id,
    required this.clubId,
    this.clubName = '',
    this.authorId = '',
    this.authorName = '',
    this.kind = 'message',
    required this.title,
    this.body = '',
    this.activityId = '',
    this.challengeId = '',
    this.segmentId = '',
    this.distanceKm = 0,
    this.durationSec = 0,
    this.elevationM = 0,
    this.city = '',
    required this.createdAt,
    this.pending = false,
  });

  bool get isEvent => kind != 'message' && kind != 'chat';
  bool get isMessage => !isEvent;

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
    id: json['id']?.toString() ?? '',
    clubId: json['clubId']?.toString() ?? '',
    clubName: json['clubName']?.toString() ?? '',
    authorId: json['authorId']?.toString() ?? '',
    authorName: json['authorName']?.toString() ?? '',
    kind: _normalizeKind(json['kind']?.toString()),
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    activityId: json['activityId']?.toString() ?? '',
    challengeId: json['challengeId']?.toString() ?? '',
    segmentId: json['segmentId']?.toString() ?? '',
    distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
    elevationM: (json['elevationM'] as num?)?.toInt() ?? 0,
    city: json['city']?.toString() ?? '',
    createdAt: _parseDate(json['createdAt']),
    pending: json['pending'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clubId': clubId,
    'clubName': clubName,
    'authorId': authorId,
    'authorName': authorName,
    'kind': kind,
    'title': title,
    'body': body,
    'activityId': activityId,
    'challengeId': challengeId,
    'segmentId': segmentId,
    'distanceKm': distanceKm,
    'durationSec': durationSec,
    'elevationM': elevationM,
    'city': city,
    'createdAt': createdAt.toIso8601String(),
    'pending': pending,
  };

  /// Payload for `POST /api/community/posts`. The server owns the id, author
  /// and timestamp, so those fields are intentionally omitted.
  Map<String, dynamic> toCreateJson() => {
    'clubId': clubId,
    'kind': kind,
    'title': title,
    'body': body,
    if (activityId.isNotEmpty) 'activityId': activityId,
    if (challengeId.isNotEmpty) 'challengeId': challengeId,
    if (segmentId.isNotEmpty) 'segmentId': segmentId,
    if (distanceKm > 0) 'distanceKm': distanceKm,
    if (durationSec > 0) 'durationSec': durationSec,
    if (elevationM > 0) 'elevationM': elevationM,
    if (city.isNotEmpty) 'city': city,
  };

  CommunityPost copyWith({
    String? id,
    String? clubId,
    String? clubName,
    String? authorId,
    String? authorName,
    String? kind,
    String? title,
    String? body,
    String? activityId,
    String? challengeId,
    String? segmentId,
    double? distanceKm,
    int? durationSec,
    int? elevationM,
    String? city,
    DateTime? createdAt,
    bool? pending,
  }) => CommunityPost(
    id: id ?? this.id,
    clubId: clubId ?? this.clubId,
    clubName: clubName ?? this.clubName,
    authorId: authorId ?? this.authorId,
    authorName: authorName ?? this.authorName,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body ?? this.body,
    activityId: activityId ?? this.activityId,
    challengeId: challengeId ?? this.challengeId,
    segmentId: segmentId ?? this.segmentId,
    distanceKm: distanceKm ?? this.distanceKm,
    durationSec: durationSec ?? this.durationSec,
    elevationM: elevationM ?? this.elevationM,
    city: city ?? this.city,
    createdAt: createdAt ?? this.createdAt,
    pending: pending ?? this.pending,
  );

  static String _normalizeKind(String? value) {
    final kind = (value ?? '').trim().toLowerCase();
    switch (kind) {
      case 'chat':
        return 'message';
      case 'message':
      case 'activity':
      case 'milestone':
      case 'journey':
      case 'segment':
      case 'challenge':
      case 'join':
      case 'system':
        return kind;
      default:
        return kind.isEmpty ? 'message' : kind;
    }
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }
}

/// An in-app notification for a community event. Notifications are generated
/// locally when the athlete joins a community and when new join/challenge
/// events arrive from the server feed.
class CommunityNotice {
  final String id;
  final String clubId;
  final String clubName;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  const CommunityNotice({
    required this.id,
    required this.clubId,
    this.clubName = '',
    this.kind = 'join',
    required this.title,
    this.body = '',
    required this.createdAt,
    this.read = false,
  });

  factory CommunityNotice.fromJson(Map<String, dynamic> json) =>
      CommunityNotice(
        id: json['id']?.toString() ?? '',
        clubId: json['clubId']?.toString() ?? '',
        clubName: json['clubName']?.toString() ?? '',
        kind: json['kind']?.toString() ?? 'join',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        createdAt: CommunityPost._parseDate(json['createdAt']),
        read: json['read'] == true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clubId': clubId,
    'clubName': clubName,
    'kind': kind,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  CommunityNotice copyWith({bool? read}) => CommunityNotice(
    id: id,
    clubId: clubId,
    clubName: clubName,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
  );
}
