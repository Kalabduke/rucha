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
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'route',
    mode: json['mode']?.toString() ?? 'open',
    targetKm: (json['targetKm'] as num?)?.toDouble(),
    targetTime: (json['targetTime'] as num?)?.toInt(),
    targetElev: (json['targetElev'] as num?)?.toDouble(),
    prizeBirr: (json['prize'] as num?)?.toInt() ?? 0,
    visibility: json['visibility']?.toString() ?? 'public',
    isJoined: json['joined'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'kind': kind,
    'mode': mode,
    if (targetKm != null) 'targetKm': targetKm,
    if (targetTime != null) 'targetTime': targetTime,
    if (targetElev != null) 'targetElev': targetElev,
    'prize': prizeBirr,
    'visibility': visibility,
    'joined': isJoined,
  };
}
