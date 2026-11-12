class Challenge {
  final String id;
  final String title;
  final String description;
  final String kind;
  final String mode; // 'open', 'goal', 'head_to_head'
  final double? targetKm;
  final int? targetTime;
  final double? targetElev;
  final int prizeBirr;
  final String visibility;
  final bool isJoined;
  final String? opponentName;
  final String? opponentId;
  final String? createdBy;
  final String? ownerId;
  /// Community/club this challenge belongs to, if any.
  final String? communityId;
  /// Whether this challenge is pending approval by the community owner/admin.
  final bool pendingApproval;
  /// Invite status for head-to-head: '', 'pending', 'accepted', 'declined'
  final String inviteStatus;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.mode,
    this.targetKm,
    this.targetTime,
    this.targetElev,
    this.prizeBirr = 0,
    this.visibility = 'public',
    this.isJoined = false,
    this.opponentName,
    this.opponentId,
    this.createdBy,
    this.ownerId,
    this.communityId,
    this.pendingApproval = false,
    this.inviteStatus = '',
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'route',
    mode: json['mode']?.toString() ?? 'open',
    targetKm: (json['targetKm'] as num?)?.toDouble(),
    targetTime: (json['targetTime'] as num?)?.toInt() ??
        (json['targetSeconds'] as num?)?.toInt(),
    targetElev: (json['targetElev'] as num?)?.toDouble() ??
        (json['targetElevationM'] as num?)?.toDouble(),
    prizeBirr: (json['prizeBr'] as num?)?.toInt() ??
        (json['prize'] as num?)?.toInt() ?? 0,
    visibility: json['visibility']?.toString() ?? 'public',
    isJoined: json['joined'] == true,
    opponentName: json['opponentName']?.toString(),
    opponentId: json['opponentId']?.toString(),
    createdBy: json['createdBy']?.toString() ?? json['ownerName']?.toString(),
    ownerId: json['ownerId']?.toString() ?? json['owner_id']?.toString(),
    communityId: json['communityId']?.toString() ?? json['clubId']?.toString(),
    pendingApproval: json['pendingApproval'] == true || json['pending'] == true,
    inviteStatus: json['inviteStatus']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'kind': kind,
    'mode': mode,
    if (targetKm != null) 'targetKm': targetKm,
    if (targetTime != null) 'targetSeconds': targetTime,
    if (targetElev != null) 'targetElevationM': targetElev?.toInt(),
    'prizeBr': prizeBirr,
    'visibility': visibility,
    'joined': isJoined,
    if (opponentName != null) 'opponentName': opponentName,
    if (opponentId != null) 'opponentId': opponentId,
    if (createdBy != null) 'createdBy': createdBy,
    if (ownerId != null) 'ownerId': ownerId,
    if (communityId != null) 'communityId': communityId,
    'pendingApproval': pendingApproval,
    'inviteStatus': inviteStatus,
  };
}
