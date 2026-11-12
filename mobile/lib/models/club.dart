/// A running/walking/cycling community returned by the RUCHA backend.
///
/// Clubs are server data. The app never invents clubs locally; when the server
/// is unreachable the Community screen shows an honest empty state instead.
class Club {
  final String id;
  final String name;
  final String description;
  final String city;
  final String type; // 'run', 'walk', 'ride', 'mixed'
  final String color;
  final String ownerId;
  final String ownerName;
  final int members;
  final bool joined;

  /// 'public' or 'friends'
  final String visibility;

  /// 'open' (anyone joins immediately) or 'approval' (owner must accept)
  final String joinPolicy;

  /// When true, non-admin members cannot submit new challenges to this community
  final bool challengesDisabled;

  const Club({
    required this.id,
    required this.name,
    this.description = '',
    this.city = '',
    this.type = 'run',
    this.color = '#0B6E56',
    this.ownerId = '',
    this.ownerName = '',
    this.members = 0,
    this.joined = false,
    this.visibility = 'public',
    this.joinPolicy = 'open',
    this.challengesDisabled = false,
  });

  factory Club.fromJson(Map<String, dynamic> json) => Club(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        type: json['type']?.toString() ?? 'run',
        color: json['color']?.toString() ?? '#0B6E56',
        ownerId:
            json['ownerId']?.toString() ?? json['owner_id']?.toString() ?? '',
        ownerName: json['ownerName']?.toString() ?? '',
        members: (json['members'] as num?)?.toInt() ?? 0,
        joined: json['joined'] == true,
        visibility: json['visibility']?.toString() ?? 'public',
        joinPolicy: json['joinPolicy']?.toString() ??
            json['join_policy']?.toString() ??
            'open',
        challengesDisabled: json['challengesDisabled'] == true ||
            json['challenges_disabled'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'city': city,
        'type': type,
        'color': color,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'members': members,
        'joined': joined,
        'visibility': visibility,
        'joinPolicy': joinPolicy,
        'challengesDisabled': challengesDisabled,
      };

  Club copyWith({
    int? members,
    bool? joined,
    String? visibility,
    String? joinPolicy,
    bool? challengesDisabled,
  }) =>
      Club(
        id: id,
        name: name,
        description: description,
        city: city,
        type: type,
        color: color,
        ownerId: ownerId,
        ownerName: ownerName,
        members: members ?? this.members,
        joined: joined ?? this.joined,
        visibility: visibility ?? this.visibility,
        joinPolicy: joinPolicy ?? this.joinPolicy,
        challengesDisabled: challengesDisabled ?? this.challengesDisabled,
      );
}
